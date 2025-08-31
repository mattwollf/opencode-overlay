# OpenCode Gentoo Portage Overlay

This overlay provides ebuilds for [OpenCode](https://opencode.ai), an AI-powered coding agent built for the terminal.

## Overview

OpenCode is an AI coding agent that provides intelligent code assistance, completion, and generation capabilities directly in your terminal environment. This overlay builds OpenCode from source using the proper Gentoo build system integration.

## Quick Start

### Adding the Overlay

1. **Using eselect-repository (recommended):**
   ```bash
   sudo eselect repository add opencode-overlay git https://github.com/yourusername/opencode-overlay.git
   sudo emaint sync -r opencode-overlay
   ```

2. **Manual setup:**
   ```bash
   # Clone the overlay
   git clone https://github.com/yourusername/opencode-overlay.git /var/db/repos/opencode-overlay
   
   # Add to repos.conf
   sudo mkdir -p /etc/portage/repos.conf
   sudo tee /etc/portage/repos.conf/opencode-overlay.conf <<EOF
   [opencode-overlay]
   location = /var/db/repos/opencode-overlay
   masters = gentoo
   priority = 50
   auto-sync = no
   EOF
   ```

### Installing OpenCode

```bash
# Install the latest stable version
sudo emerge -av dev-util/opencode

# Or install the live version for development
sudo emerge -av =dev-util/opencode-9999
```

## Package Information

- **Category:** dev-util
- **Package:** opencode
- **Versions:** 0.5.29 (and live 9999)
- **Homepage:** https://opencode.ai
- **Repository:** https://github.com/sst/opencode

### Dependencies

**Build-time:**
- `>=dev-lang/go-1.24` - Go compiler for TUI component
- `sys-apps/bun` - Bun runtime for Node.js build

**Runtime:**
- `sys-apps/fzf` - Fuzzy finder
- `sys-apps/ripgrep` - Fast text search

### USE Flags

- `test` - Run package test suite during build

## Build Process

The ebuild handles a complex multi-language build:

1. **Dependency Installation:** Uses Bun to install Node.js dependencies
2. **Go TUI Build:** Compiles the Terminal User Interface component in Go
3. **Main Binary Build:** Uses Bun to compile the main TypeScript application to a native binary
4. **Integration:** Links both components into a single `opencode` executable

## Development

### Live Ebuild (-9999)

For development purposes, install the live version:

```bash
sudo emerge -av =dev-util/opencode-9999
```

This builds from the latest git commit and is useful for:
- Testing new features
- Development and debugging
- Contributing to the project

### Automation Scripts

The overlay includes automation scripts in the `scripts/` directory:

#### `update-ebuild.sh`
Automatically updates ebuilds to the latest GitHub release:

```bash
# Update to latest release
./scripts/update-ebuild.sh

# Update to specific version
./scripts/update-ebuild.sh -v 0.6.0

# Force update even if ebuild exists
./scripts/update-ebuild.sh -f
```

#### `test-ebuild.sh`
Comprehensive testing of ebuilds:

```bash
# Test the newest available ebuild
sudo ./scripts/test-ebuild.sh

# Test specific version
sudo ./scripts/test-ebuild.sh -v 0.5.29

# Setup overlay only (no tests)
sudo ./scripts/test-ebuild.sh --setup-only
```

### Manual Testing

```bash
# Test ebuild syntax
ebuild opencode-0.5.29.ebuild clean

# Generate manifest
ebuild opencode-0.5.29.ebuild manifest

# Test compilation without installing
ebuild opencode-0.5.29.ebuild compile

# Install to temporary directory
ebuild opencode-0.5.29.ebuild install
```

## Configuration

After installation, you may need to configure your AI provider:

1. **API Keys:** Set up your preferred AI provider (Claude, OpenAI, etc.)
2. **Configuration:** Check `~/.opencode/` for configuration files
3. **Documentation:** Visit https://opencode.ai/docs for detailed setup

## Troubleshooting

### Common Issues

1. **Bun not found:**
   ```bash
   sudo emerge -av sys-apps/bun
   ```

2. **Go version too old:**
   ```bash
   sudo emerge -av '>=dev-lang/go-1.24'
   ```

3. **Build failures:**
   - Check build log in `/var/tmp/portage/dev-util/opencode-*/temp/`
   - Ensure all dependencies are installed
   - Try the live version if stable fails

### Getting Help

- **OpenCode Issues:** https://github.com/sst/opencode/issues
- **Overlay Issues:** https://github.com/yourusername/opencode-overlay/issues
- **Gentoo Forums:** https://forums.gentoo.org/

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

### Ebuild Guidelines

- Follow Gentoo ebuild standards
- Test on multiple architectures if possible
- Update automation scripts as needed
- Maintain backward compatibility

## License

This overlay is licensed under the GPL-2, in accordance with Gentoo policies. The OpenCode software itself is licensed under the MIT license.

## Maintainer

- **Name:** Overlay Maintainer
- **Email:** maintainer@example.com
- **GitHub:** https://github.com/yourusername/opencode-overlay

---

**Note:** This overlay is community-maintained and not officially supported by the OpenCode or Gentoo teams.