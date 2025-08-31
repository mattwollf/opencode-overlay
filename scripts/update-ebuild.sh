#!/usr/bin/env bash
# OpenCode Overlay - Automated Ebuild Update Script
# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

set -euo pipefail

# Configuration
GITHUB_REPO="sst/opencode"
OVERLAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="${OVERLAY_DIR}/dev-util/opencode"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}"

# Colors for output (disabled in non-TTY environments)
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

log() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    error "$*"
    exit 1
}

# Check dependencies
check_deps() {
    local deps=(curl jq git)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing dependencies: ${missing[*]}"
    fi
}

# Get latest release from GitHub
get_latest_release() {
    log "Fetching latest release from GitHub..."
    
    local release_data
    release_data=$(curl -s "${GITHUB_API}/releases/latest" || die "Failed to fetch release data")
    
    local tag_name
    tag_name=$(echo "$release_data" | jq -r '.tag_name' | sed 's/^v//')
    
    if [[ "$tag_name" == "null" || -z "$tag_name" ]]; then
        die "Failed to parse release tag"
    fi
    
    echo "$tag_name"
}

# Check if ebuild already exists for version
ebuild_exists() {
    local version="$1"
    [[ -f "${PACKAGE_DIR}/opencode-${version}.ebuild" ]]
}

# Create new ebuild from template
create_ebuild() {
    local version="$1"
    local template="${PACKAGE_DIR}/opencode-0.5.29.ebuild"
    local new_ebuild="${PACKAGE_DIR}/opencode-${version}.ebuild"
    
    if [[ ! -f "$template" ]]; then
        die "Template ebuild not found: $template"
    fi
    
    log "Creating ebuild for version ${version}..."
    
    # Copy template and update version-specific parts
    cp "$template" "$new_ebuild"
    
    # Update any version-specific content if needed
    # (Currently the ebuild uses ${PV} so no changes needed)
    
    log "Created: $(basename "$new_ebuild")"
}

# Generate manifest for the package
generate_manifest() {
    log "Generating Manifest..."
    
    cd "$PACKAGE_DIR" || die "Cannot change to package directory"
    
    # Use repoman or ebuild to generate manifest
    if command -v repoman >/dev/null 2>&1; then
        repoman manifest || warn "repoman manifest failed, trying alternative method"
    elif command -v ebuild >/dev/null 2>&1; then
        # Find the newest ebuild file
        local newest_ebuild
        newest_ebuild=$(ls opencode-*.ebuild | grep -v 9999 | sort -V | tail -n1)
        
        if [[ -n "$newest_ebuild" ]]; then
            ebuild "$newest_ebuild" manifest || warn "ebuild manifest failed"
        fi
    else
        warn "No manifest generation tool found (repoman or ebuild)"
    fi
}

# Update git repository
update_git() {
    local version="$1"
    local message="dev-util/opencode: bump to ${version}"
    
    cd "$OVERLAY_DIR" || die "Cannot change to overlay directory"
    
    # Check if this is a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        warn "Not a git repository, skipping git operations"
        return
    fi
    
    log "Updating git repository..."
    
    # Add files to staging area
    if ! git add "dev-util/opencode/" >/dev/null 2>&1; then
        warn "git add failed"
        return
    fi
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log "No changes to commit"
        return
    fi
    
    # Commit the changes
    log "Committing changes..."
    if git commit -m "$message" >/dev/null 2>&1; then
        log "Successfully committed: $message"
    else
        warn "git commit failed"
        return
    fi
}

# Main function
main() {
    local force=false
    local skip_git=false
    local version=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force=true
                shift
                ;;
            --skip-git)
                skip_git=true
                shift
                ;;
            --no-color)
                NO_COLOR=1
                # Reset color variables
                RED=''
                GREEN=''
                YELLOW=''
                BLUE=''
                NC=''
                shift
                ;;
            -v|--version)
                version="$2"
                shift 2
                ;;
            -h|--help)
                cat <<EOF
Usage: $0 [OPTIONS]

Update OpenCode ebuild to the latest version.

OPTIONS:
    -f, --force      Force update even if ebuild exists
    -v, --version    Specify version instead of auto-detecting
    --skip-git       Skip git operations
    --no-color       Disable colored output
    -h, --help       Show this help

EXAMPLES:
    $0                    # Update to latest GitHub release
    $0 -v 0.6.0          # Update to specific version
    $0 -f                # Force update even if ebuild exists
    $0 --no-color        # Run without colored output (for CI)
EOF
                exit 0
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done
    
    # Check dependencies
    check_deps
    
    # Determine version
    if [[ -z "$version" ]]; then
        version=$(get_latest_release)
    fi
    
    log "Target version: ${version}"
    
    # Check if ebuild already exists
    if ebuild_exists "$version" && [[ "$force" != true ]]; then
        log "Ebuild for version ${version} already exists"
        log "Use --force to recreate it"
        exit 0
    fi
    
    # Create ebuild
    create_ebuild "$version"
    
    # Generate manifest
    generate_manifest
    
    # Update git
    if [[ "$skip_git" != true ]]; then
        update_git "$version"
    fi
    
    log "Update completed successfully!"
    log ""
    log "Next steps:"
    log "1. Test the ebuild: emerge -av =dev-util/opencode-${version}"
    log "2. Push to overlay repository if satisfied"
}

# Run main function
main "$@"