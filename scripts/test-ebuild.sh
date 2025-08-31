#!/usr/bin/env bash
# OpenCode Overlay - Ebuild Testing Script
# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

set -euo pipefail

# Configuration
OVERLAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="${OVERLAY_DIR}/dev-util/opencode"
PACKAGE_NAME="dev-util/opencode"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    error "$*"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root for package operations"
    fi
}

# Check dependencies
check_deps() {
    local deps=(emerge ebuild)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing dependencies: ${missing[*]}"
    fi
    
    # Check for QA tools (preferred modern tools first)
    if ! command -v pkgdev >/dev/null 2>&1 && ! command -v pkgcheck >/dev/null 2>&1 && ! command -v repoman >/dev/null 2>&1; then
        warn "No QA tools found (pkgdev, pkgcheck, or repoman). Some tests may be skipped."
    fi
}

# Setup overlay in repos.conf
setup_overlay() {
    local repos_conf="/etc/portage/repos.conf"
    local overlay_conf="${repos_conf}/opencode-overlay.conf"
    
    log "Setting up overlay configuration..."
    
    mkdir -p "$repos_conf"
    
    cat > "$overlay_conf" <<EOF
[opencode-overlay]
location = ${OVERLAY_DIR}
masters = gentoo
priority = 50
auto-sync = no
EOF
    
    log "Overlay configuration created: $overlay_conf"
}

# List available ebuilds
list_ebuilds() {
    log "Available ebuilds:"
    
    cd "$PACKAGE_DIR" || die "Cannot access package directory"
    
    local ebuilds=()
    while IFS= read -r -d '' ebuild; do
        ebuilds+=("$(basename "$ebuild")")
    done < <(find . -name "*.ebuild" -print0 | sort -z)
    
    if [[ ${#ebuilds[@]} -eq 0 ]]; then
        warn "No ebuilds found"
        return 1
    fi
    
    for ebuild in "${ebuilds[@]}"; do
        local version="${ebuild#opencode-}"
        version="${version%.ebuild}"
        echo "  - $version"
    done
}

# Validate ebuild syntax
validate_ebuild() {
    local version="$1"
    local ebuild_file="${PACKAGE_DIR}/opencode-${version}.ebuild"
    
    log "Validating ebuild syntax: opencode-${version}"
    
    if [[ ! -f "$ebuild_file" ]]; then
        die "Ebuild not found: $ebuild_file"
    fi
    
    cd "$PACKAGE_DIR" || die "Cannot access package directory"
    
    # Check ebuild syntax
    ebuild "$(basename "$ebuild_file")" clean || die "Ebuild syntax validation failed"
    
    log "Syntax validation passed"
}

# Generate manifest
generate_manifest() {
    log "Generating/updating Manifest..."
    
    cd "$PACKAGE_DIR" || die "Cannot access package directory"
    
    # Try modern tools first, then fallback to older methods
    if command -v pkgdev >/dev/null 2>&1; then
        pkgdev manifest || die "Manifest generation failed"
    elif command -v repoman >/dev/null 2>&1; then
        repoman manifest || die "Manifest generation failed"
    else
        warn "pkgdev/repoman not found, trying ebuild method"
        
        # Try with newest non-live ebuild
        local newest_ebuild
        newest_ebuild=$(ls opencode-*.ebuild | grep -v 9999 | sort -V | tail -n1 || true)
        
        if [[ -n "$newest_ebuild" ]]; then
            ebuild "$newest_ebuild" manifest || die "Manifest generation failed"
        else
            warn "No non-live ebuilds found for manifest generation"
        fi
    fi
    
    log "Manifest generation completed"
}

# Test package compilation
test_compile() {
    local version="$1"
    local clean_after="${2:-true}"
    
    log "Testing compilation: opencode-${version}"
    
    # Clean any previous attempts
    emerge --unmerge "${PACKAGE_NAME}" >/dev/null 2>&1 || true
    
    # Test pretend first
    log "Running pretend merge..."
    emerge --pretend --verbose "=${PACKAGE_NAME}-${version}" || die "Pretend merge failed"
    
    # Test actual compilation
    log "Compiling package..."
    emerge --oneshot --verbose "=${PACKAGE_NAME}-${version}" || die "Package compilation failed"
    
    log "Compilation successful!"
    
    # Test basic functionality
    if command -v opencode >/dev/null 2>&1; then
        log "Testing binary functionality..."
        opencode --version || warn "Binary version check failed"
        log "Binary test completed"
    else
        warn "opencode binary not found in PATH after installation"
    fi
    
    # Clean up if requested
    if [[ "$clean_after" == "true" ]]; then
        log "Cleaning up..."
        emerge --unmerge "${PACKAGE_NAME}" || warn "Failed to unmerge package"
    fi
}

# Run QA checks
run_qa_checks() {
    log "Running quality assurance checks..."
    
    cd "$PACKAGE_DIR" || die "Cannot access package directory"
    
    # Try modern pkgcheck first
    if command -v pkgcheck >/dev/null 2>&1; then
        log "Running pkgcheck scan..."
        if ! pkgcheck scan .; then
            warn "pkgcheck scan found issues"
        else
            log "pkgcheck scan passed"
        fi
    # Fall back to repoman for older systems
    elif command -v repoman >/dev/null 2>&1; then
        log "Running repoman checks (legacy mode)..."
        
        # Run various repoman checks
        local checks=("scan" "full")
        
        for check in "${checks[@]}"; do
            log "Running repoman $check..."
            if ! repoman "$check"; then
                warn "repoman $check found issues"
            else
                log "repoman $check passed"
            fi
        done
    else
        warn "No QA tools available (pkgcheck or repoman). Skipping QA checks."
        return
    fi
}

# Main function
main() {
    local version=""
    local skip_compile=false
    local skip_qa=false
    local setup_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--version)
                version="$2"
                shift 2
                ;;
            --skip-compile)
                skip_compile=true
                shift
                ;;
            --skip-qa|--skip-repoman)
                skip_qa=true
                shift
                ;;
            --setup-only)
                setup_only=true
                shift
                ;;
            -h|--help)
                cat <<EOF
Usage: $0 [OPTIONS]

Test OpenCode ebuild functionality and quality.

OPTIONS:
    -v, --version      Test specific version (default: newest available)
    --skip-compile     Skip compilation test
    --skip-qa          Skip QA checks (pkgcheck/repoman)
    --skip-repoman     Alias for --skip-qa (legacy compatibility)
    --setup-only       Only setup overlay, don't run tests
    -h, --help         Show this help

EXAMPLES:
    $0                    # Test newest available ebuild
    $0 -v 0.5.29         # Test specific version
    $0 --setup-only      # Only setup overlay configuration
EOF
                exit 0
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done
    
    # Check root privileges
    check_root
    
    # Check dependencies
    check_deps
    
    # Setup overlay
    setup_overlay
    
    if [[ "$setup_only" == "true" ]]; then
        log "Overlay setup completed"
        exit 0
    fi
    
    # List available ebuilds
    list_ebuilds
    
    # Determine version to test
    if [[ -z "$version" ]]; then
        cd "$PACKAGE_DIR" || die "Cannot access package directory"
        version=$(ls opencode-*.ebuild | grep -v 9999 | sed 's/opencode-//;s/.ebuild$//' | sort -V | tail -n1)
        
        if [[ -z "$version" ]]; then
            die "No ebuilds found to test"
        fi
        
        log "Auto-selected version: $version"
    fi
    
    # Validate ebuild
    validate_ebuild "$version"
    
    # Generate manifest
    generate_manifest
    
    # Run QA checks
    if [[ "$skip_qa" != "true" ]]; then
        run_qa_checks
    fi
    
    # Test compilation
    if [[ "$skip_compile" != "true" ]]; then
        test_compile "$version"
    fi
    
    log ""
    log "All tests completed successfully!"
    log ""
    log "Package: ${PACKAGE_NAME}-${version}"
    log "Overlay: ${OVERLAY_DIR}"
}

# Run main function
main "$@"