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
	sys-apps/bun
"

# Runtime dependencies  
RDEPEND="
	sys-apps/fzf
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
	
	# Check for Bun
	if ! has_version "sys-apps/bun"; then
		eerror "OpenCode requires Bun runtime for building"
		die "Please emerge sys-apps/bun"
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
	bun install || die "Failed to install dependencies"
	
	# Build the Go TUI component
	einfo "Building Go TUI component..."
	cd packages/tui || die "Cannot change to packages/tui directory"
	
	local go_ldflags="-s -w -X main.Version=${PV}"
	ego build -ldflags="${go_ldflags}" -o tui cmd/opencode/main.go
	
	# Build the main Node.js binary with Bun
	einfo "Building main binary with Bun..."
	cd ../opencode || die "Cannot change to packages/opencode directory"
	
	# Define build-time constants
	local tui_path="$(realpath ../tui/tui)"
	local build_args=(
		--define "OPENCODE_TUI_PATH='${tui_path}'"
		--define "OPENCODE_VERSION='${PV}'"
		--compile
		--target=bun-linux-x64
		--outfile=opencode
		./src/index.ts
	)
	
	bun build "${build_args[@]}" || die "Failed to build main binary"
	
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