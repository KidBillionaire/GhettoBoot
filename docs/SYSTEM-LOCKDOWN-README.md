# System Lockdown Script

A comprehensive bash script for macOS that performs a complete system lockdown by killing non-essential processes, disabling execution on data volumes, and blocking external device inputs.

## Features

- **Process Termination**: Kills all non-essential processes while preserving critical system components
- **Execution Prevention**: Remounts data volumes with `noexec` flag to prevent binary execution
- **HID Lockdown**: Disables NFC and SmartCard services to prevent external device injection
- **Safety Checks**: Protects critical system processes and current shell session
- **Verification**: Provides detailed status reports after lockdown
- **Dry Run Mode**: Test the script without making actual changes

## Prerequisites

- macOS system (designed for Recovery Mode but works in normal mode)
- Root/sudo access
- Bash shell

## Usage

### Basic Usage

```bash
sudo ./system-lockdown.sh
```

### Dry Run (Test Without Changes)

```bash
sudo ./system-lockdown.sh --dry-run
```

### Custom Data Volume

```bash
sudo ./system-lockdown.sh --volume "MyVolume - Data"
```

### Kill ALL Processes (Dangerous!)

```bash
sudo ./system-lockdown.sh --kill-all
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Show what would be done without making changes |
| `--volume NAME` | Specify data volume name (default: 'Macintosh HD - Data') |
| `--allow-critical` | Keep critical system processes (default behavior) |
| `--kill-all` | Attempt to kill ALL processes including critical ones |
| `--help` | Show help message |

## Environment Variables

You can also configure the script using environment variables:

```bash
export DATA_VOLUME="MyVolume - Data"
export DRY_RUN=true
export KEEP_CRITICAL=false
sudo -E ./system-lockdown.sh
```

## What It Does

### 1. Process Termination

Kills all processes except:
- Your current shell and its parent processes
- Critical system processes (when `KEEP_CRITICAL=true`):
  - `kernel_task`
  - `launchd`
  - `kextd`
  - `syslogd`
  - `configd`
  - `notifyd`
  - `securityd`
  - `WindowServer`

### 2. Volume Remounting

Remounts the data volume with `noexec` flag to prevent execution of binaries from:
- User applications
- Downloaded files
- External drives mounted on the data volume

### 3. Service Disabling

Disables these services to prevent external device interaction:
- `com.apple.ctkicdd` - Cryptographic Token Kit
- `com.apple.nfcd` - NFC daemon
- `com.apple.cardd` - Smart card daemon
- `com.apple.PassKit` - Wallet/PassKit services

### 4. Verification

Displays:
- Count of running processes
- List of currently running processes
- Volume mount status with flags
- Disabled services status

## Safety Features

- **Root Check**: Ensures script runs with proper privileges
- **Critical Process Protection**: Prevents killing essential system processes
- **Shell Tree Preservation**: Never kills your current shell or its parents
- **User Confirmation**: Asks for confirmation before making changes (unless dry-run)
- **Detailed Logging**: Color-coded output for all operations
- **Error Handling**: Graceful handling of missing volumes or services

## Examples

### Recovery Mode Lockdown

Boot into Recovery Mode, open Terminal, and run:

```bash
sudo ./system-lockdown.sh
```

### Test Before Execution

```bash
sudo ./system-lockdown.sh --dry-run
```

### Maximum Lockdown (Use With Caution)

```bash
sudo ./system-lockdown.sh --kill-all --volume "Macintosh HD - Data"
```

### Custom Volume Name

If your data volume has a different name:

```bash
# First, list available volumes
ls /Volumes/

# Then specify the correct volume
sudo ./system-lockdown.sh --volume "Data"
```

## Important Notes

### Persistence

- **Temporary**: All changes are temporary and will be reset on reboot
- **Making Permanent**: To make changes permanent, you need to:
  - Modify system startup items
  - Configure launchd to disable services permanently
  - Set volume mount options in `/etc/fstab` (not recommended)

### Recovery

If you lock yourself out:
1. Reboot the system
2. All processes and services will restart normally
3. Volume mount flags will reset to defaults

### Risks

- **System Instability**: Killing too many processes may cause system instability
- **No Network**: You may lose network connectivity
- **No GUI**: Display server may be killed if critical processes are not protected
- **No Recovery**: If you kill your shell or its parents, you'll lose access

### Troubleshooting

**"Volume not found" error:**
```bash
# List available volumes
ls -1 /Volumes/

# Use the exact name shown
sudo ./system-lockdown.sh --volume "Exact Volume Name"
```

**"Permission denied" error:**
- Ensure you're using `sudo`
- Verify you're in Recovery Mode or have Full Disk Access

**"Service not found" warnings:**
- Normal if certain services don't exist on your system
- The script will continue with available services

## Use Cases

1. **Security Incident Response**: Quickly lock down a compromised system
2. **Forensic Analysis**: Prevent further changes while investigating
3. **Testing Environment**: Create a minimal execution environment
4. **Debugging**: Isolate process-related issues
5. **Recovery Operations**: Work in a clean environment with minimal interference

## License

This script is provided as-is for educational and security purposes.

## Warnings

⚠️ **This script is designed for emergency security situations and testing environments**

- Use at your own risk
- Test in a safe environment first
- May cause system instability
- Not intended for production systems
- Designed primarily for Recovery Mode operations

## Author

Created for system security and lockdown operations in macOS environments.
