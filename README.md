# GhettoBoot - Free Tier Edition

[![npm version](https://img.shields.io/npm/v/ghettoboot.svg)](https://www.npmjs.com/package/ghettoboot)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)](https://github.com/KidBillionaire/GhettoBoot)

Lightweight, powerful system utilities for process management and security operations. Built for system administrators, DevOps engineers, and security professionals who need quick, reliable tools.

## Features

### Process Management
- List and monitor all running processes
- Sort by memory or CPU usage
- Filter processes by user
- Display process tree hierarchy
- Clean, readable output with helpful headers

### System Security
- Comprehensive system lockdown for macOS
- Process termination with safety checks
- Volume remounting with execution prevention
- HID device lockdown (NFC/SmartCard)
- Dry-run mode for testing

## Installation

### Quick Install (NPM)

```bash
npm install -g ghettoboot
```

### Verify Installation

```bash
ghettoboot --version
```

For detailed installation instructions, see [INSTALLATION.md](docs/INSTALLATION.md)

## Quick Start

### Process Management

```bash
# List all processes
ghettoboot processes

# Show top 20 memory consumers
ghettoboot processes -m

# Show top 20 CPU consumers
ghettoboot processes -c

# Filter by specific user
ghettoboot processes -u root

# Display process tree
ghettoboot processes -t
```

### System Lockdown (macOS Only)

**WARNING: Use with extreme caution. Designed for emergency security situations and Recovery Mode.**

```bash
# Test without making changes
sudo ghettoboot lockdown --dry-run

# Execute lockdown (prompts for confirmation)
sudo ghettoboot lockdown

# Custom data volume
sudo ghettoboot lockdown --volume "Macintosh HD - Data"
```

## Command Reference

### Main Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `ghettoboot processes` | `ps` | Process management tools |
| `ghettoboot lockdown` | `lock` | System security lockdown |
| `ghettoboot version` | `-v` | Show version info |
| `ghettoboot help` | `-h` | Show help message |

### Direct Access

- `ghettoboot-processes` - Direct process tool access
- `ghettoboot-lockdown` - Direct lockdown tool access

## Process Management Options

```bash
-a, --all       Show all processes (default)
-m, --memory    Sort by memory usage (highest first)
-c, --cpu       Sort by CPU usage (highest first)
-u, --user      Filter by specific user
-t, --tree      Show process tree hierarchy
-h, --help      Show help message
```

## System Lockdown Options

```bash
--dry-run           Test without making changes
--volume NAME       Specify data volume name
--allow-critical    Keep critical system processes (default)
--kill-all          Kill ALL processes (dangerous!)
--help              Show detailed help
```

## Use Cases

### For System Administrators
- Quick process diagnostics
- Resource usage monitoring
- User activity tracking
- Emergency system lockdown

### For DevOps Engineers
- CI/CD process monitoring
- Resource optimization
- Security hardening
- Incident response

### For Security Professionals
- Forensic analysis preparation
- Malware containment
- System isolation
- Security incident response

## Platform Support

| Feature | Linux | macOS | BSD |
|---------|-------|-------|-----|
| Process Management | ✓ | ✓ | ✓ |
| System Lockdown | ⚠️ | ✓ | ⚠️ |

## Requirements

- Node.js >= 14.0.0
- Bash shell
- Standard Unix utilities (ps, grep, awk)
- Root/sudo access (for lockdown features)
- macOS (for full lockdown features)

## Examples

### Find Memory Leaks

```bash
# Monitor memory usage over time
watch -n 2 ghettoboot processes -m
```

### Security Incident Response

```bash
# 1. Test the lockdown first
sudo ghettoboot lockdown --dry-run

# 2. Execute lockdown to contain threat
sudo ghettoboot lockdown

# 3. Verify lockdown status
ghettoboot processes -a
```

### User Activity Monitoring

```bash
# See what a specific user is running
ghettoboot processes -u username

# Monitor all user processes
for user in $(users | tr ' ' '\n' | sort -u); do
    echo "=== $user ==="
    ghettoboot processes -u $user
done
```

## Documentation

- [Installation Guide](docs/INSTALLATION.md) - Detailed installation instructions
- [System Lockdown Guide](docs/SYSTEM-LOCKDOWN-README.md) - Complete lockdown documentation

## Safety & Warnings

### Process Management
- Read-only operations
- No system modifications
- Safe for production use

### System Lockdown
⚠️ **CRITICAL WARNINGS**
- Designed for emergency situations
- May cause system instability
- Can terminate critical processes
- Effects persist until reboot
- Test with `--dry-run` first
- Best used in Recovery Mode

## Free Tier vs Pro (Coming Soon)

### Free Tier (Current)
- ✓ All process management features
- ✓ Basic system lockdown
- ✓ All core functionality
- ✓ Open source
- ✓ Community support

### Pro (Future)
- Advanced monitoring dashboards
- Automated response scripts
- Multi-system management
- Priority support
- Custom integrations

## Contributing

We welcome contributions! This is an open-source project.

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details

## Support

- GitHub Issues: [Report bugs or request features](https://github.com/KidBillionaire/GhettoBoot/issues)
- Documentation: Check the `docs/` folder
- Community: Share your use cases and scripts

## Credits

Created with care for system administrators who need reliable tools that work.

---

**GhettoBoot** - Because system management should be simple, powerful, and accessible to everyone.
