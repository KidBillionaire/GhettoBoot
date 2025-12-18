# GhettoBoot Installation Guide

## Free Tier Edition

GhettoBoot Free Tier provides essential system utilities for process management and security operations.

## Installation Methods

### Method 1: NPM Global Install (Recommended)

Install globally to use `ghettoboot` commands from anywhere:

```bash
npm install -g ghettoboot
```

### Method 2: NPM Local Install

Install locally in your project:

```bash
npm install ghettoboot
```

Then run with npx:

```bash
npx ghettoboot processes -m
```

### Method 3: From Source

Clone the repository and install:

```bash
git clone https://github.com/KidBillionaire/GhettoBoot.git
cd GhettoBoot
npm install -g .
```

## Verify Installation

Check that GhettoBoot is installed correctly:

```bash
ghettoboot --version
```

You should see output like:
```
GhettoBoot Free Tier Edition v1.0.0
```

## Quick Start

### Process Management

```bash
# List all processes
ghettoboot processes

# Show top memory consumers
ghettoboot processes -m

# Show top CPU consumers
ghettoboot processes -c

# Filter by user
ghettoboot processes -u root
```

### System Lockdown (macOS)

**WARNING: This feature is designed for emergency security situations and Recovery Mode**

```bash
# Test lockdown without making changes
sudo ghettoboot lockdown --dry-run

# Execute lockdown (requires confirmation)
sudo ghettoboot lockdown
```

## Command Aliases

For convenience, you can also use these direct commands:

- `ghettoboot-processes` - Direct access to process tools
- `ghettoboot-lockdown` - Direct access to lockdown tools

## Platform Support

### Process Management
- Linux ✓
- macOS ✓
- BSD ✓

### System Lockdown
- macOS ✓ (Designed for Recovery Mode)
- Linux ⚠️ (Limited support)

## Requirements

- Node.js >= 14.0.0
- Bash shell
- Standard Unix utilities (ps, grep, awk)
- Root/sudo access (for lockdown features)

## Troubleshooting

### Command Not Found

If `ghettoboot` command is not found after global install:

1. Check your PATH includes npm global bin directory:
   ```bash
   npm config get prefix
   ```

2. Add npm bin to your PATH (add to ~/.bashrc or ~/.zshrc):
   ```bash
   export PATH="$(npm config get prefix)/bin:$PATH"
   ```

### Permission Denied

If you get permission errors:

```bash
# Fix permissions
chmod +x $(npm config get prefix)/lib/node_modules/ghettoboot/bin/*
```

### macOS Specific Issues

For system lockdown features, you may need to:

1. Grant Full Disk Access in System Preferences > Security & Privacy
2. Run from Recovery Mode for maximum effectiveness
3. Disable System Integrity Protection (SIP) for some features

## Uninstallation

To remove GhettoBoot:

```bash
npm uninstall -g ghettoboot
```

## Getting Help

- Run `ghettoboot help` for command help
- Check the [README](../README.md) for feature documentation
- Visit the [GitHub repository](https://github.com/KidBillionaire/GhettoBoot) for issues and support

## What's Included in Free Tier

The Free Tier edition includes:

- ✓ Process listing and management
- ✓ Memory/CPU sorting
- ✓ User filtering
- ✓ Process tree view
- ✓ System lockdown (basic)
- ✓ All core features

## License

MIT License - See LICENSE file for details
