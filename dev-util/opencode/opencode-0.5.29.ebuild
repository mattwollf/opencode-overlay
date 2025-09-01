# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module

DESCRIPTION="AI coding agent, built for the terminal"
HOMEPAGE="https://opencode.ai https://github.com/sst/opencode"

if [[ ${PV} == *9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/sst/opencode.git"
else
	SRC_URI="https://github.com/sst/opencode/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~arm64"
fi

LICENSE="MIT"
SLOT="0"
IUSE="test"
RESTRICT="!test? ( test )"

# Build dependencies
BDEPEND="
	>=dev-lang/go-1.24
	net-libs/nodejs[npm]
"

# Runtime dependencies  
RDEPEND="
	app-shells/fzf
	sys-apps/ripgrep
"

DEPEND="${RDEPEND}"

# Go module dependencies will be vendored
QA_FLAGS_IGNORED="usr/bin/opencode"

pkg_pretend() {
	# Check for minimum Go version
	if ! has_version ">=dev-lang/go-1.24"; then
		eerror "OpenCode requires Go 1.24 or later"
		die "Please emerge >=dev-lang/go-1.24"
	fi
	
	# Check for Node.js and npm
	if ! has_version "net-libs/nodejs"; then
		eerror "OpenCode requires Node.js runtime for building"
		die "Please emerge net-libs/nodejs"
	fi
	
	if ! command -v node >/dev/null 2>&1; then
		eerror "Node.js runtime not found in PATH"
		die "node not found in PATH"
	fi
	
	if ! command -v npm >/dev/null 2>&1; then
		eerror "npm package manager not found in PATH"
		eerror "Please ensure net-libs/nodejs was built with npm USE flag"
		die "npm not found in PATH"
	fi
}

src_unpack() {
	if [[ ${PV} == *9999 ]]; then
		git-r3_src_unpack
	else
		default
	fi
}

src_prepare() {
	default
	
	# Get version from package.json to ensure consistency
	local pkg_version
	pkg_version=$(grep '"version"' packages/opencode/package.json | cut -d'"' -f4)
	einfo "Detected package.json version: ${pkg_version}"
	
	# Apply any patches
	eapply_user
}

src_compile() {
	# Set Go build environment
	export CGO_ENABLED=0
	export GO111MODULE=on
	
	einfo "Installing Node.js dependencies..."
	npm install || die "Failed to install dependencies"
	
	# Install ts-node for TypeScript runtime support
	npm install --save-dev ts-node typescript @types/node || die "Failed to install TypeScript dependencies"
	
	# Build the Go TUI component
	einfo "Building Go TUI component..."
	cd packages/tui || die "Cannot change to packages/tui directory"
	
	local go_ldflags="-s -w -X main.Version=${PV}"
	ego build -ldflags="${go_ldflags}" -o tui cmd/opencode/main.go
	
	# Build the main Node.js binary with npm
	einfo "Building main binary with npm..."
	cd ../opencode || die "Cannot change to packages/opencode directory"
	
	# Define build-time constants
	local tui_path="$(realpath ../tui/tui)"
	export OPENCODE_TUI_PATH="${tui_path}"
	export OPENCODE_VERSION="${PV}"
	
	# Create executable wrapper script that runs TypeScript directly with Node.js
	# This avoids complex TypeScript compilation and uses Node.js's built-in support
	cat > opencode << 'EOF'
#!/usr/bin/env node

// Set environment variables
process.env.OPENCODE_TUI_PATH = process.env.OPENCODE_TUI_PATH || '';
process.env.OPENCODE_VERSION = process.env.OPENCODE_VERSION || '';

// Enable TypeScript support via ts-node or direct execution
const path = require('path');
const fs = require('fs');

const srcPath = path.join(__dirname, 'src', 'index.ts');
const jsPath = path.join(__dirname, 'src', 'index.js');

// Try to run TypeScript file directly if possible
if (fs.existsSync(srcPath)) {
    try {
        require('ts-node/register');
        require(srcPath);
    } catch (err) {
        // Fallback to JavaScript if available
        if (fs.existsSync(jsPath)) {
            require(jsPath);
        } else {
            console.error('Could not load TypeScript or JavaScript entry point');
            process.exit(1);
        }
    }
} else if (fs.existsSync(jsPath)) {
    require(jsPath);
} else {
    console.error('No entry point found');
    process.exit(1);
}
EOF

	# Set environment variables in the script
	sed -i "s|process.env.OPENCODE_TUI_PATH = process.env.OPENCODE_TUI_PATH .*|process.env.OPENCODE_TUI_PATH = '${tui_path}';|" opencode
	sed -i "s|process.env.OPENCODE_VERSION = process.env.OPENCODE_VERSION .*|process.env.OPENCODE_VERSION = '${PV}';|" opencode
	
	chmod +x opencode || die "Failed to make binary executable"
	
	einfo "Build completed successfully"
}

src_test() {
	if use test; then
		einfo "Running smoke test..."
		cd packages/opencode || die
		./opencode --version || die "Smoke test failed"
	fi
}

src_install() {
	# Install the main binary
	dobin packages/opencode/opencode
	
	# Install documentation
	dodoc README.md
	
	# Install license
	dodoc LICENSE
}

pkg_postinst() {
	elog "OpenCode has been installed successfully!"
	elog ""
	elog "To get started:"
	elog "  opencode --help"
	elog ""
	elog "For configuration and documentation, visit:"
	elog "  https://opencode.ai/docs"
	elog ""
	elog "Note: You may need to configure your AI provider API keys"
	elog "in your shell configuration or opencode config files."
}
