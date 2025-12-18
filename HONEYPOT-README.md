# 🍯 GhettoBoot Honeypot System

**Advanced honeypot defense system with hidden volumes, automatic breach detection, and kill-switch protection.**

---

## 🎯 Overview

GhettoBoot implements a sophisticated multi-layer honeypot strategy:

1. **Hidden Volume System** - Duplicate volumes hidden in innocuous directories
2. **Decoy Environment** - Visible system that attackers will target
3. **Process Sandboxing** - SSH and spawned processes get jailed automatically
4. **Breach Detection** - Continuous monitoring with automatic kill-switch
5. **Auto-Recovery** - System reboots with honeypot configs after breach
6. **WiFi Honeypot** - Fake WiFi network that traps attackers (returns smiley faces 😊)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ATTACKER VIEW                            │
│  "Normal" system with SSH, WiFi, visible volumes            │
│  ↓ Attacks come in via SSH, processes, WiFi                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  HONEYPOT LAYER                             │
│  • Process Sandbox/Jail                                     │
│  • Fake WiFi (SpectrumSetup-1A-Plus)                       │
│  • Breach Detection Running                                 │
│  • All activity logged                                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              BREACH DETECTED?                               │
│  Threshold exceeded → KILL SWITCH ACTIVATED                 │
│  → Kill all processes                                       │
│  → System lockdown                                          │
│  → Auto-reboot in 10 seconds                                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│            SECURE ENVIRONMENT                               │
│  Hidden volumes in:                                         │
│  • /var/.cache/system/.system_logs/                        │
│  • /usr/local/share/.fonts/                                │
│  • /opt/.config/                                            │
│  Real operations happen here (wave from safety! 👋)         │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/KidBillionaire/GhettoBoot.git
cd GhettoBoot

# Make scripts executable
chmod +x *.sh

# Run installer (as root)
sudo ./install-honeypot.sh
```

### Start Honeypot

```bash
# Start all honeypot services
sudo honeypot start

# View status
honeypot status

# Monitor activity
honeypot logs
```

### Start WiFi Honeypot

```bash
# Start fake WiFi network
sudo ./wifi-honeypot.sh start

# Monitor WiFi connections
sudo ./wifi-honeypot.sh connections
```

---

## 📦 Components

### 1. **honeypot-boot.sh** - Boot-Time Volume Duplication

On system startup, creates:
- Hidden volume directories in innocuous paths
- Encrypted volume images
- Mounted secure volumes
- Chroot jail for process sandboxing
- SSH honeypot configuration

**Location**: `/usr/local/sbin/honeypot-boot.sh`

**Runs**: Automatically on boot via systemd

### 2. **hidden-volume-manager.sh** - Volume Management

Manage hidden secure volumes:

```bash
# Show environment status
./hidden-volume-manager.sh status

# Enter secure mode (operate from hidden volumes)
sudo ./hidden-volume-manager.sh enter-secure

# Sync files to hidden storage
sudo ./hidden-volume-manager.sh sync /path/to/important secure/

# Create backup snapshot
sudo ./hidden-volume-manager.sh backup

# Hide access tracks
./hidden-volume-manager.sh hide-tracks
```

### 3. **process-sandbox.sh** - Process Sandboxing

Monitors and sandboxes suspicious processes:

```bash
# Setup honeypot jail
sudo ./process-sandbox.sh setup

# Start monitoring (background)
sudo ./process-sandbox.sh monitor-bg

# View alerts
./process-sandbox.sh alerts
```

**Detects**:
- Reverse shells (netcat, bash -i, /dev/tcp/)
- Privilege escalation attempts
- Suspicious network connections
- Malicious scripts

### 4. **breach-kill-switch.sh** - Automatic Breach Response

Continuous monitoring with automatic kill-switch:

```bash
# Start breach monitoring
sudo ./breach-kill-switch.sh monitor-bg

# Run breach scan
sudo ./breach-kill-switch.sh scan

# Check status
./breach-kill-switch.sh status
```

**When Breach Detected**:
1. **KILL** all non-essential processes
2. **LOCKDOWN** system (remount read-only, disable network)
3. **PRESERVE** evidence (logs, process dumps, network state)
4. **REBOOT** system in 10 seconds
5. **RESTART** honeypot automatically

**Detection Methods**:
- Unauthorized root access
- Rootkit indicators (hidden processes, suspicious kernel modules)
- Backdoor processes
- Network anomalies
- File integrity violations
- Honeypot jail escapes

### 5. **wifi-honeypot.sh** - WiFi Trap

Fake WiFi network that traps attackers:

```bash
# Start WiFi honeypot
sudo ./wifi-honeypot.sh start

# Show connected devices
sudo ./wifi-honeypot.sh connections

# View logs
sudo ./wifi-honeypot.sh logs
```

**Features**:
- Fake SSID: `SpectrumSetup-1A-Plus` (looks like router setup)
- Open network (no password - looks inviting!)
- DHCP/DNS server
- **NO INTERNET ACCESS** - attackers get nothing
- All HTTP requests return **smiley faces 😊**
- Fake login pages, API responses, config pages
- All connections logged

### 6. **honeypot-dashboard.sh** - Real-Time Monitoring

Interactive dashboard for monitoring:

```bash
# Launch interactive dashboard
./honeypot-dashboard.sh

# Generate text report
./honeypot-dashboard.sh report
```

**Dashboard shows**:
- System status (honeypot active, kill switch status)
- Attack statistics (SSH attacks, suspicious processes, escalation attempts)
- Recent alerts
- Active threats
- Honeypot captures
- Hidden volume status

---

## 🔧 Configuration

### Environment Variables

```bash
# Hidden volume base directory
export SECURE_BASE_DIR="/var/.cache/system"

# WiFi honeypot SSID
export FAKE_SSID="SpectrumSetup-1A-Plus"

# WiFi interface
export HONEYPOT_INTERFACE="wlan0"

# Breach threshold (number of indicators to trigger kill switch)
export BREACH_THRESHOLD=3
```

### Systemd Services

Installed services:
- `ghettoboo-honeypot-boot.service` - Runs on every boot
- `ghettoboot-breach-monitor.service` - Continuous breach detection
- `ghettoboot-process-monitor.service` - Process sandboxing
- `ghettoboot-auto-recovery.service` - Auto-recovery after breach

```bash
# Check service status
systemctl status ghettoboo-honeypot-boot
systemctl status ghettoboot-breach-monitor

# View logs
journalctl -fu ghettoboot-breach-monitor
```

---

## 📊 Monitoring & Logs

### Log Files

| Log File | Purpose |
|----------|---------|
| `/var/log/honeypot-activity.log` | General honeypot events |
| `/var/log/breach-events.log` | Breach detection events |
| `/var/log/honeypot-processes.log` | Captured suspicious processes |
| `/var/log/honeypot-alerts.log` | Security alerts |
| `/var/log/wifi-honeypot.log` | WiFi honeypot activity |
| `/var/log/wifi-connections.log` | WiFi connection attempts |

### Viewing Logs

```bash
# Tail all honeypot logs
tail -f /var/log/honeypot*.log

# View breach events
tail -f /var/log/breach-events.log

# WiFi activity
tail -f /var/log/wifi-honeypot.log
```

---

## 🎯 Usage Scenarios

### Scenario 1: SSH Attack

1. Attacker connects via SSH
2. SSH configured to route to chroot jail
3. Attacker gets limited environment with fake files
4. All commands logged
5. If privilege escalation attempted → breach score increases
6. If threshold exceeded → **KILL SWITCH ACTIVATED**

### Scenario 2: Process Injection

1. Attacker spawns malicious process (e.g., reverse shell)
2. Process monitor detects suspicious patterns
3. Process sandboxed/isolated
4. Alert logged
5. Breach score increases
6. If threshold exceeded → **KILL SWITCH ACTIVATED**

### Scenario 3: WiFi Attack

1. Attacker scans and finds "SpectrumSetup-1A-Plus" (open network)
2. Connects thinking it's vulnerable router
3. Gets DHCP lease (fake)
4. Tries to access internet → **BLOCKED**
5. Tries to access admin panel → **Gets smiley faces 😊**
6. All activity logged
7. Attacker wastes time, learns nothing

### Scenario 4: Breach Detected

1. Multiple breach indicators detected
2. Breach score exceeds threshold (default: 3)
3. **KILL SWITCH ACTIVATED**:
   - All processes killed
   - System locked down
   - Evidence preserved
   - 10 second warning
   - **REBOOT**
4. System restarts with honeypot configuration
5. Honeypot automatically reinstated
6. Logs preserved for analysis

---

## 🛡️ Security Features

### Defense in Depth

1. **Isolation** - Attackers sandboxed from real system
2. **Deception** - Hidden volumes appear as normal directories
3. **Detection** - Continuous monitoring for breach indicators
4. **Response** - Automatic kill-switch and reboot
5. **Recovery** - Auto-restart with honeypot intact

### Secure Operations

While honeypot is active, use secure mode for real work:

```bash
# Enter secure mode
sudo ./hidden-volume-manager.sh enter-secure

# Now in secure environment
cd /var/.cache/system/secure

# Work safely while attackers play in honeypot
# ... do important work ...

# Exit secure mode
exit
```

---

## 🔍 Forensics & Analysis

After a breach, evidence is preserved in:
```
/var/.cache/system/breach-evidence-YYYYMMDD-HHMMSS/
├── processes.txt          # Process dump at breach time
├── netstat.txt           # Network connections
├── ss.txt                # Socket statistics
├── lsmod.txt             # Loaded kernel modules
└── etc-modified/         # Modified config files
```

---

## ⚙️ Advanced Configuration

### Customizing Breach Detection

Edit `/usr/local/sbin/breach-kill-switch.sh`:

```bash
# Change breach threshold
BREACH_THRESHOLD=5  # Default: 3

# Add custom detection patterns
suspicious_patterns+=(
    "your-custom-pattern"
)
```

### Customizing WiFi Honeypot

```bash
# Different SSID
export FAKE_SSID="FreePublicWiFi"

# Custom responses
# Edit /tmp/honeypot-http-server.py
```

### Customizing Jail Environment

Add more fake files to `/var/honeypot/jail/`:
```bash
# Fake database credentials
echo "DB_PASS=fake123" > /var/honeypot/jail/home/admin/.env

# Fake SSH keys
ssh-keygen -t rsa -f /var/honeypot/jail/home/admin/.ssh/id_rsa -N ""
```

---

## 🎓 Management Commands

The installer creates a `honeypot` command for easy management:

```bash
honeypot status        # Show system status
honeypot start         # Start all services
honeypot stop          # Stop monitoring
honeypot restart       # Restart services
honeypot logs          # Tail logs
honeypot alerts        # Show breach alerts
honeypot secure        # Enter secure mode
```

---

## 🐛 Troubleshooting

### Honeypot not starting
```bash
# Check dependencies
apt-get install rsync mount util-linux systemd e2fsprogs

# Check systemd services
systemctl status ghettoboo-honeypot-boot
journalctl -xe
```

### WiFi honeypot fails
```bash
# Check dependencies
apt-get install hostapd dnsmasq iptables

# Check interface name
ip link show

# Update interface name
export HONEYPOT_INTERFACE="wlan1"  # or your interface
```

### Hidden volumes not mounting
```bash
# Check if image exists
ls -la /var/.cache/system/.system_logs/secure.img

# Try manual mount
sudo mount -o loop /var/.cache/system/.system_logs/secure.img /var/.cache/system/secure
```

---

## 📋 System Requirements

- Linux (Debian/Ubuntu recommended)
- Root access
- WiFi adapter supporting AP mode (for WiFi honeypot)
- At least 4GB free disk space
- Python 3 (for WiFi HTTP server)

---

## ⚠️ Important Notes

1. **Auto-Reboot**: System WILL automatically reboot if breach detected
2. **No Internet**: WiFi honeypot blocks all internet access for connected devices
3. **Logs**: All activity is logged - review regularly
4. **Secure Mode**: Use secure mode for actual work while honeypot is active
5. **Testing**: Test in safe environment before production deployment

---

## 📄 License

GhettoBoot - Because even your defense should make attackers smile! 😊

Created with ❤️ for system administrators who take security seriously (but not too seriously).

---

## 🤝 Contributing

Contributions welcome! Please test thoroughly before submitting PRs.

---

## 📞 Support

For issues, questions, or feature requests:
- GitHub Issues: https://github.com/KidBillionaire/GhettoBoot/issues

---

**Remember**: The best defense is a good honeypot! 🍯

Wave at attackers from your secure hidden volumes while they play in the sandbox! 👋😊
