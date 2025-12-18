# 😊 GhettoBoot Process Listing Script

A friendly command-line utility for listing and managing system processes with style!

## Features

- 😊 List all running processes
- 📊 Sort by memory or CPU usage
- 👤 Filter processes by user
- 🌳 Display process tree view
- 🎯 Simple, clean output with helpful headers

## Installation

The script is ready to use! Just make sure it's executable:

```bash
chmod +x list_processes.sh
```

## Usage

### Basic Commands

```bash
# Show all processes (default)
./list_processes.sh

# Show all processes explicitly
./list_processes.sh -a
./list_processes.sh --all

# Sort by memory usage (top 20)
./list_processes.sh -m
./list_processes.sh --memory

# Sort by CPU usage (top 20)
./list_processes.sh -c
./list_processes.sh --cpu

# Filter by specific user
./list_processes.sh -u root
./list_processes.sh --user username

# Show process tree
./list_processes.sh -t
./list_processes.sh --tree

# Show help
./list_processes.sh -h
./list_processes.sh --help
```

## Examples

```bash
# Find memory-intensive processes
./list_processes.sh -m

# See what a specific user is running
./list_processes.sh -u root

# View the entire process hierarchy
./list_processes.sh -t
```

## Output Format

Each command displays a friendly smiley face (😊) before showing results to keep things positive while managing your system!

## Requirements

- Bash shell
- Standard Unix utilities: `ps`, `grep`, `awk`
- Optional: `pstree` for enhanced tree view

## License

GhettoBoot - Because even process management should make you smile! 😊

---

*Created with love for system administrators who need their processes listed with a smile.*



# fearlessInfa Operational Audit & Command Specification

I have reviewed your lockdown specification and identified several critical gaps between stated intent and macOS reality. Below is a section-by-section audit with explicit bash commands where feasible, warnings where your model conflicts with the operating system, and clarifications on privilege boundaries.

## Section 1: Network Invariants

**Audit findings:** Your specification assumes granular network control that macOS does not expose through standard command-line interfaces. Several requirements conflict with Apple’s wireless subsystem design.

**Commands:**

Disable all Wi-Fi networks except your hotspot:

```bash
# List all configured networks
networksetup -listpreferredwirelessnetworks en0

# Remove each network (must be done individually)
networksetup -removepreferredwirelessnetwork en0 "NetworkName"

# Then re-add only your hotspot
networksetup -addpreferredwirelessnetwork en0 "YourHotspotSSID" 0 WPA2
```

Disable auto-join for networks (requires manual iteration):

```bash
# macOS does not expose a bulk disable command
# Each network must be handled via System Settings or individual commands
sudo /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport prefs DisconnectOnLogout=YES
```

**Critical gap:** macOS NetworkServiceOrder and interface binding cannot guarantee “exactly one active network path” if multiple interfaces exist. You need interface-level disablement.

Disable Bluetooth:

```bash
sudo defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -int 0
sudo killall -HUP blued
```

Disable Thunderbolt networking:

```bash
# No direct command exists. Requires manual System Settings navigation:
# System Settings > Network > [Thunderbolt Bridge] > Disable
# Or remove the kernel extension (requires SIP disabled, creates persistent risk)
```

Disable USB Ethernet adapters:

```bash
# Identify active interfaces
ifconfig | grep "^[a-z]" | cut -d: -f1

# Bring down non-essential interfaces (example for en1)
sudo ifconfig en1 down

# Make persistent across reboots by creating a launch daemon
# This requires creating a plist in /Library/LaunchDaemons/
```

**Critical failure in your model:** macOS re-enables network interfaces on boot based on hardware presence and NVRAM settings. Your “verification shows 1 active interface” requirement cannot be enforced with a single command. You need a continuous validation loop or kernel-level intervention.

Verification command:

```bash
ifconfig | grep "status: active" | wc -l
# Expected output: 1
netstat -rn | grep default
# Should show single gateway via your hotspot interface
```

## Section 2: Volume & Authority Separation

**Audit findings:** Your model misunderstands APFS volume architecture on Apple Silicon Macs. There is no “true root volume” that remains unmounted during normal operation. The Signed System Volume is always mounted and read-only by design.

**Reality check:**

- The system volume (typically mounted at `/`) is cryptographically sealed and read-only when SIP is enabled
- User data lives in `/System/Volumes/Data` which is mounted at boot
- A hidden recovery partition exists but boots a separate OS environment, not a hidden mounted volume during normal operation

**Your requirement “Execution volume has no write path to true root” is already enforced by SIP.** No additional commands needed, but your conceptual model needs correction.

To verify system volume integrity:

```bash
csrutil status
# Should show: System Integrity Protection status: enabled

diskutil apfs list
# Review volume roles and mount points

sudo fs_usage | grep -i "Volumes/Data"
# Monitor write operations to understand separation
```

**Commands for creating an authority backup volume:**

```bash
# Create encrypted APFS volume on external drive
diskutil apfs addVolume disk2 APFS "AuthorityVault" -encrypted -passphrase "YourStrongPassphrase"

# Mount and populate
mkdir /Volumes/AuthorityVault/identity
mkdir /Volumes/AuthorityVault/recovery_procedures
# Copy your materials here

# Unmount
diskutil unmount /Volumes/AuthorityVault
```

## Section 3: Process Visibility & Live Monitoring

**Commands:**

Continuous process monitoring:

```bash
# Create monitoring script
cat > ~/monitor_processes.sh << 'EOF'
#!/bin/bash
LOGFILE="/var/log/process_monitor.log"
while true; do
    echo "=== $(date) ===" >> "$LOGFILE"
    ps aux >> "$LOGFILE"
    sleep 1
done
EOF

chmod +x ~/monitor_processes.sh

# Run in background (does not survive reboot)
nohup ~/monitor_processes.sh &

# For persistence, create launch daemon
sudo tee /Library/LaunchDaemons/com.fearless.processmonitor.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.fearless.processmonitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/YOUR_USERNAME/monitor_processes.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

sudo launchctl load /Library/LaunchDaemons/com.fearless.processmonitor.plist
```

**Critical gap:** Your specification says “append-only log” but provides no mechanism to prevent log tampering. On macOS, this requires either immutable flags (which can be removed with root) or shipping logs off-system immediately.

Make log append-only (partial protection):

```bash
sudo chflags uappnd /var/log/process_monitor.log
# User append-only. Root can still modify. Not true append-only.
```

## Section 4: Remote Access & Control Surfaces

**Commands:**

Disable SSH:

```bash
sudo systemsetup -setremotelogin off
sudo launchctl disable system/com.openssh.sshd
```

Disable Screen Sharing:

```bash
sudo launchctl disable system/com.apple.screensharing
sudo defaults write /var/db/launchd.db/com.apple.launchd/overrides.plist com.apple.screensharing -dict Disabled -bool true
```

Disable Handoff and Continuity:

```bash
# These require changes in System Settings GUI
# No comprehensive command-line interface exists
# Partial control via defaults:
defaults write ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd.plist ActivityAdvertisingAllowed -bool NO
defaults write ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd.plist ActivityReceivingAllowed -bool NO
```

Disable AirDrop:

```bash
defaults write com.apple.NetworkBrowser DisableAirDrop -bool YES
sudo ifconfig awdl0 down
# Note: awdl0 may re-enable on its own
```

Disable Universal Control:

```bash
defaults write com.apple.universalcontrol Disable -bool true
```

Disable accessibility features:

```bash
# Switch Control
sudo defaults write com.apple.Accessibility SwitchControlEnabled -bool false

# Voice Control  
sudo defaults write com.apple.Accessibility VoiceControlEnabled -bool false
```

**Verification:**

```bash
# Check for listening ports
sudo lsof -iTCP -sTCP:LISTEN -n -P

# Should show minimal services, no SSH on 22, no VNC on 5900

# Check launchd services
sudo launchctl list | grep -E "(ssh|screen|remote)"
# Should show disabled or absent
```

**Critical gap:** macOS continuously re-enables AWDL (Apple Wireless Direct Link) for system services. Your requirement conflicts with OS design. You would need kernel extension intervention or accept periodic AWDL activity.

## Section 5: Command Discipline

**Audit finding:** This section is procedural guidance, not technically auditable. However, your specification would benefit from a pre-approved command whitelist.

**Implementation suggestion:**

```bash
# Create command validation wrapper
cat > ~/validate_command.sh << 'EOF'
#!/bin/bash
ALLOWED_COMMANDS=(
    "ifconfig"
    "networksetup"
    "launchctl"
    "csrutil"
    "defaults"
    "diskutil"
    "ps"
    "lsof"
)

COMMAND=$(echo "$1" | awk '{print $1}')
if [[ " ${ALLOWED_COMMANDS[@]} " =~ " ${COMMAND} " ]]; then
    eval "$@"
else
    echo "Command not in whitelist. Rejected."
    exit 1
fi
EOF

chmod +x ~/validate_command.sh
```

## Section 6: SIP Handling

**Commands:**

Check SIP status:

```bash
csrutil status
```

To disable SIP (requires Recovery mode boot, cannot be done from normal operation):

```bash
# 1. Reboot into Recovery: hold power button until "Loading startup options"
# 2. Select Options > Continue
# 3. Terminal from menu bar
csrutil disable
reboot
```

To re-enable SIP (same Recovery mode procedure):

```bash
csrutil enable
reboot
```

**Critical constraint:** Your ten-minute time budget conflicts with any workflow requiring SIP changes, as each toggle requires a full Recovery boot cycle adding approximately three to five minutes per operation.

## Section 7: Reboot Doctrine

**Command for immediate reboot:**

```bash
sudo shutdown -r now
```

**For emergency situations with no logging:**

```bash
sudo halt
# Or force immediate shutdown:
sudo /sbin/shutdown -h now
```

## Section 8: Backup & Recovery

**Commands for encrypted backup to external volume:**

```bash
# Time Machine to encrypted volume (GUI required for initial setup)
# Command-line equivalent for subsequent backups:
tmutil startbackup

# Manual rsync-based backup
sudo rsync -aAXv --delete \
    --exclude='/System' \
    --exclude='/Library/Caches' \
    --exclude='/private/var/folders' \
    / /Volumes/BackupDrive/system_backup_$(date +%Y%m%d)/

# Create recovery documentation
cat > /Volumes/AuthorityVault/recovery_procedures/rebuild.txt << 'EOF'
1. Boot into Recovery (hold power button)
2. Disk Utility > Erase execution volume
3. Reinstall macOS
4. Run hardening script from AuthorityVault
5. Verify network invariants
6. Resume operations
EOF
```

## Critical Missing Elements

Your specification lacks:

1. **Firewall configuration:** No mention of macOS Application Firewall or packet filter (pf) rules
1. **DNS hardening:** No controls on DNS resolution or prevention of DNS leakage
1. **Time synchronization:** NTP can be attack vector, no controls specified
1. **Kernel extension policy:** No specification for third-party kexts or system extensions
1. **Launch agent/daemon inventory:** No baseline of expected persistent processes
1. **File integrity monitoring:** No mechanism to detect unauthorized changes to critical system files beyond SIP

## Ten-Minute Checklist Viability Assessment

**Verdict:** Not achievable as specified. The following operations alone exceed ten minutes:

- Any SIP state change: three to five minutes per reboot cycle
- Network interface enumeration and selective disablement with verification: two to four minutes
- Launch daemon creation and verification: one to two minutes
- Backup creation: five to twenty minutes depending on data volume

A realistic timeline for full implementation is twenty-five to forty minutes, assuming no troubleshooting and expert-level execution speed.

## Recommended Next Action

You should decide whether to revise your time budget, reduce scope to truly achievable ten-minute operations, or accept that fearlessInfa requires a longer initial setup window with ten-minute verification capability for subsequent checks.​​​​​​​​​​​​​​​​



Below is a structured technical review of the script, focusing on correctness on modern macOS, security posture, failure modes, and concrete remediation steps. This is written as if the script were intended for a real incident-response or “panic lockdown” scenario.

⸻

Executive Summary

The script is conceptually aligned with a “containment” objective, but on modern macOS (11+ through Sequoia):
	•	Several operations will not behave as intended due to SIP, the sealed system volume, launchd semantics, and APFS behavior.
	•	The process-killing logic is dangerously overbroad and can deadlock or kernel-panic the system rather than cleanly isolating it.
	•	noexec remounting of Macintosh HD – Data is largely ineffective for preventing execution.
	•	Disabling NFC / SmartCard services via launchctl disable system/... is insufficient and sometimes a no-op.
	•	The script risks leaving the machine in an undefined, unstable state without actually achieving strong execution denial.

This is not a criticism of intent; the threat model simply does not match macOS’s modern security architecture.

⸻

High-Risk Issues (Must Address)

1. Process Termination Strategy Is Unsafe

Problems
	•	ps -ef | tail -n +2 + regex PID exclusion is race-prone.
	•	Killing processes like cfprefsd, powerd, UserEventAgent, or loginwindow can:
	•	Freeze the GUI
	•	Break TCC
	•	Cause spontaneous reboot
	•	kill -9 bypasses cleanup and can corrupt state.

Critical omission
You are not excluding:
	•	launchservicesd
	•	amfid
	•	taskgated
	•	trustd
	•	opendirectoryd
	•	diskarbitrationd
	•	powerd
	•	UserEventAgent
	•	loginwindow

Killing these defeats your own later steps.

Recommendation
Replace “kill everything” with deny-new-execution:

launchctl bootout system /System/Library/LaunchDaemons

or (safer):

launchctl print system | awk '/pid =/ {print $3}'

…and selectively boot out user and third-party jobs only.

⸻

2. noexec on APFS Data Volume Is Largely Ineffective

Reality
	•	APFS ignores noexec for:
	•	Signed binaries
	•	dyld-loaded Mach-O
	•	Already mapped pages
	•	Most execution occurs from:
	•	/System/Volumes/Preboot
	•	Shared dyld cache
	•	In-memory mappings

Net effect
You may prevent ./script.sh, but not:
	•	launchd jobs
	•	Already-running malware
	•	Signed binaries

Recommendation
If execution denial is the goal:
	•	Disable userland execution via policy, not mount flags:

chmod -R a-x /Applications
chmod -R a-x /Library/LaunchAgents
chmod -R a-x /Library/LaunchDaemons


	•	Or place the system into single-user / recovery containment, which is what Apple actually supports.

⸻

3. launchctl disable Is Not a Strong Control

Problems
	•	launchctl disable system/foo:
	•	Is reversible at reboot
	•	Often overridden by MDM / SIP
	•	Does not stop already-running services

Specifically
	•	com.apple.nfcd is supervised by hardware state
	•	PassKit is not a simple daemon
	•	ctkicdd is often respawned

Recommendation
If NFC / SmartCard suppression is required:

launchctl bootout system /System/Library/LaunchDaemons/com.apple.nfcd.plist

And additionally:

defaults write /Library/Preferences/com.apple.security.smartcard Disabled -bool true

(Still not guaranteed without MDM.)

⸻

4. SIP / SSV Constraints Are Ignored

The script assumes root == authority. On modern macOS:
	•	SIP blocks:
	•	bootout of many system daemons
	•	Modification of sealed system files
	•	SSV makes /System immutable even as root

Implication
This script behaves very differently depending on:
	•	SIP enabled vs disabled
	•	Intel vs Apple Silicon
	•	Interactive login vs recovery

You should explicitly detect and warn:

csrutil status | grep -q enabled && log_warning "SIP is enabled; lockdown will be partial"


⸻

Medium-Risk Issues

Process Matching Logic

if [[ "$proc_name" == *"$critical"* ]]

	•	Substring matching is unsafe.
	•	A malicious process named kernel_task_helper would be spared.

Use exact command path matching or PID ancestry instead.

⸻

Exclusion Pattern Is Fragile

exclude_pattern="$exclude_pattern|^$pid "

	•	ps -ef formatting is not stable across macOS versions.
	•	PID reuse can cause false exclusions.

⸻

set -e With kill -9

One failed kill (EPERM, ESRCH) can terminate the entire script unexpectedly.

⸻

What This Script Actually Achieves Today

Goal	Result
Kill malware	Maybe, briefly
Prevent new execution	Largely no
Disable NFC	Partially
Survive reboot	No
Preserve system stability	No


⸻

Recommended Re-Architecture (If You Keep This)

If the goal is emergency containment, do this instead:
	1.	Network isolation

ifconfig en0 down
pfctl -e
pfctl -f /etc/pf.conf


	2.	Boot out user and third-party launch jobs

launchctl bootout user/$(id -u) /
launchctl bootout system /Library/LaunchDaemons


	3.	Lock session

/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend


	4.	Force reboot into recovery

shutdown -r now



That aligns with Apple’s actual security model.

⸻

Final Assessment

This script is dangerous but not decisive. It risks destabilizing the OS without delivering strong execution or hardware-input lockdown. With modern macOS, containment must work with launchd, SIP boundaries, and APFS—not against them.

If you want, I can:
	•	Rewrite this as a macOS-correct containment script
	•	Produce a threat-model-aligned lockdown matrix
	•	Convert this into an MDM-compliant profile strategy
	•	Harden it specifically for Apple Silicon + SIP enabled

State your target environment and threat model, and I will optimize accordingly.
