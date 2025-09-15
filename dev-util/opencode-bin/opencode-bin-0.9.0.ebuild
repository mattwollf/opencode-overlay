# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="AI coding agent, built for the terminal (binary package)"
HOMEPAGE="https://opencode.ai https://github.com/sst/opencode"

# Remove -bin suffix for upstream version
MY_PV="${PV}"
MY_P="${PN%-bin}-${MY_PV}"

SRC_URI="
	amd64? ( https://github.com/sst/opencode/releases/download/v${MY_PV}/opencode-linux-x64.zip -> ${MY_P}-linux-x64.zip )
	arm64? ( https://github.com/sst/opencode/releases/download/v${MY_PV}/opencode-linux-arm64.zip -> ${MY_P}-linux-arm64.zip )
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# Runtime dependencies - only what the binary actually needs
RDEPEND="
	app-shells/fzf
	sys-apps/ripgrep
"

DEPEND=""

# No build dependencies needed for binary package
BDEPEND="app-arch/unzip"

# Binary package - no compilation needed
QA_PREBUILT="usr/bin/opencode"

S="${WORKDIR}"

src_unpack() {
	default
	# The binary is extracted directly to the working directory
}

src_install() {
	# Install the binary
	dobin opencode
	
	# Create simple documentation
	cat > "${T}"/README-binary.md << EOF
# OpenCode Binary Package

This is the binary distribution of OpenCode, an AI coding agent built for the terminal.

## Installation Notes

This binary package was installed using the pre-built binaries from the official
OpenCode GitHub releases. 

## Configuration

You may need to configure your AI provider API keys in your shell configuration 
or OpenCode config files.

## More Information

For full documentation and configuration options, visit:
- Website: https://opencode.ai
- Documentation: https://opencode.ai/docs
- GitHub: https://github.com/sst/opencode

EOF
	
	dodoc "${T}"/README-binary.md
}

pkg_postinst() {
	elog "OpenCode binary has been installed successfully!"
	elog ""
	elog "This is the binary distribution of OpenCode."
	elog ""
	elog "To get started:"
	elog "  opencode --help"
	elog ""
	elog "For configuration and documentation, visit:"
	elog "  https://opencode.ai/docs"
	elog ""
	elog "Note: You may need to configure your AI provider API keys"
	elog "in your shell configuration or OpenCode config files."
}