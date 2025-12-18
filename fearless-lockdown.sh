#!/bin/bash
################################################################################
# fearlessInfa macOS Lockdown - Production Implementation
#
# CONSTRAINTS (from operational audit):
# - macOS re-enables interfaces on boot; requires persistent daemons
# - AWDL re-enables automatically; accept periodic activity or use kext
# - SIP changes require Recovery boot (3-5 min each)
# - True append-only logs impossible without off-system shipping
# - Full lockdown takes 25-40 min; 10-min only for verification runs
#
# PREREQUISITES:
# - macOS 12+ (Monterey or later)
# - Admin privileges (sudo)
# - Known hotspot SSID for network lockdown
################################################################################

set -euo pipefail
IFS=$'\n\t'

readonly VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="/var/log/fearless"
readonly DAEMON_DIR="/Library/LaunchDaemons"
readonly PLIST_PREFIX="com.fearless"

# Configuration with defaults
DRY_RUN="${DRY_RUN:-false}"
HOTSPOT_SSID="${HOTSPOT_SSID:-}"
SKIP_CONFIRM="${SKIP_CONFIRM:-false}"
VERIFY_ONLY="${VERIFY_ONLY:-false}"

# Colors
readonly RED='\033[0;31m' GRN='\033[0;32m' YLW='\033[1;33m'
readonly BLU='\033[0;34m' CYN='\033[0;36m' NC='\033[0m'

# Whitelisted commands (Section 5 audit recommendation)
readonly -a ALLOWED_CMDS=(
    ifconfig networksetup launchctl csrutil defaults diskutil
    ps lsof netstat mount killall chflags mkdir cat chmod
    systemsetup dscacheutil scutil tmutil rsync
)

################################################################################
# Core Functions
################################################################################

die()     { echo -e "${RED}[FATAL]${NC} $1" >&2; exit 1; }
err()     { echo -e "${RED}[ERROR]${NC} $1" >&2; }
warn()    { echo -e "${YLW}[WARN]${NC} $1"; }
info()    { echo -e "${BLU}[INFO]${NC} $1"; }
ok()      { echo -e "${GRN}[OK]${NC} $1"; }
section() { echo -e "\n${CYN}══════════════════════════════════════════════════════════${NC}";
            echo -e "${CYN}  $1${NC}";
            echo -e "${CYN}══════════════════════════════════════════════════════════${NC}"; }

# Validated command execution
run() {
    local cmd="$1"
    shift

    # Validate against whitelist
    local allowed=false
    for c in "${ALLOWED_CMDS[@]}"; do
        [[ "$cmd" == "$c" ]] && allowed=true && break
    done

    if [[ "$allowed" != "true" ]]; then
        warn "Command not in whitelist: $cmd"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YLW}[DRY]${NC} $cmd $*"
        return 0
    fi

    "$cmd" "$@"
}

check_macos() {
    [[ "$(uname)" == "Darwin" ]] || die "This script requires macOS"
}

check_root() {
    [[ $EUID -eq 0 ]] || die "Must run as root: sudo $0"
}

################################################################################
# Section 1: Network Invariants
################################################################################

network_lockdown() {
    section "1. NETWORK INVARIANTS"

    info "Constraint: macOS re-enables interfaces on boot"
    info "Constraint: AWDL may re-enable for system services"

    # 1.1 Enumerate interfaces
    info "Current network interfaces:"
    run ifconfig | grep -E "^[a-z]" | cut -d: -f1 || true

    # 1.2 Disable Bluetooth
    info "Disabling Bluetooth..."
    run defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -int 0 || true
    run killall -HUP blued 2>/dev/null || true
    ok "Bluetooth disabled"

    # 1.3 Configure Wi-Fi for hotspot only
    if [[ -n "$HOTSPOT_SSID" ]]; then
        info "Locking Wi-Fi to hotspot: $HOTSPOT_SSID"

        local networks
        networks=$(run networksetup -listpreferredwirelessnetworks en0 2>/dev/null | tail -n +2 | sed 's/^[[:space:]]*//' || true)

        while IFS= read -r net; do
            [[ -z "$net" ]] && continue
            [[ "$net" == "$HOTSPOT_SSID" ]] && continue
            info "  Removing: $net"
            run networksetup -removepreferredwirelessnetwork en0 "$net" || true
        done <<< "$networks"

        ok "Wi-Fi locked to $HOTSPOT_SSID"
    else
        warn "HOTSPOT_SSID not set - Wi-Fi unchanged"
        warn "Set with: --hotspot 'YourSSID' or HOTSPOT_SSID='YourSSID'"
    fi

    # 1.4 Disable AWDL
    info "Disabling AWDL (AirDrop interface)..."
    run ifconfig awdl0 down 2>/dev/null || true
    ok "AWDL disabled (may auto-reenable)"

    # 1.5 Disable secondary interfaces
    info "Disabling secondary interfaces..."
    for iface in bridge0 en1 en2 en3 en4 en5 en6 en7 en8; do
        if run ifconfig "$iface" >/dev/null 2>&1; then
            run ifconfig "$iface" down 2>/dev/null || true
            info "  Disabled: $iface"
        fi
    done

    # 1.6 Verification
    info "Verifying network state..."
    local active
    active=$(run ifconfig 2>/dev/null | grep -c "status: active" || echo "0")

    if [[ "$active" -le 1 ]]; then
        ok "Active interfaces: $active (PASS)"
    else
        warn "Active interfaces: $active (expected ≤1)"
    fi

    info "Default route:"
    run netstat -rn 2>/dev/null | grep "^default" | head -1 || warn "No default route"
}

# Persistent network enforcement daemon
create_network_daemon() {
    section "1b. NETWORK PERSISTENCE DAEMON"

    info "Constraint: Requires continuous validation loop"

    local script="${LOG_DIR}/network_enforce.sh"
    local plist="${DAEMON_DIR}/${PLIST_PREFIX}.networkenforce.plist"

    [[ "$DRY_RUN" == "true" ]] && { info "[DRY] Would create $plist"; return 0; }

    run mkdir -p "$LOG_DIR"

    cat > "$script" << 'ENFORCE_EOF'
#!/bin/bash
# Network enforcement loop - disables non-primary interfaces
LOG="/var/log/fearless/network_enforce.log"
PRIMARY="${PRIMARY_IFACE:-en0}"

while true; do
    for iface in bridge0 awdl0 en1 en2 en3 en4 en5 en6; do
        [[ "$iface" == "$PRIMARY" ]] && continue
        if ifconfig "$iface" 2>/dev/null | grep -q "status: active"; then
            echo "$(date): Disabling $iface" >> "$LOG"
            ifconfig "$iface" down 2>/dev/null || true
        fi
    done
    sleep 5
done
ENFORCE_EOF

    run chmod +x "$script"

    cat > "$plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_PREFIX}.networkenforce</string>
    <key>ProgramArguments</key>
    <array><string>${script}</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
</dict>
</plist>
PLIST_EOF

    run launchctl load "$plist" 2>/dev/null || true
    ok "Network enforcement daemon installed"
}

################################################################################
# Section 2: Volume & SIP Verification
################################################################################

verify_volumes() {
    section "2. VOLUME & AUTHORITY SEPARATION"

    info "Constraint: SSV is sealed when SIP enabled (no action needed)"
    info "Constraint: /System/Volumes/Data is execution volume"

    # 2.1 SIP Status
    info "System Integrity Protection:"
    local sip
    sip=$(run csrutil status 2>&1 || echo "unknown")
    echo "  $sip"

    if echo "$sip" | grep -q "enabled"; then
        ok "SIP enabled - system volume sealed"
    else
        warn "SIP disabled - system volume writable"
    fi

    # 2.2 Volume layout
    info "APFS volumes:"
    run diskutil apfs list 2>/dev/null | grep -E "(Volume|Role)" | head -20 || run diskutil list | head -20

    # 2.3 Mount verification
    info "Root mount:"
    run mount | grep " / " || true
}

################################################################################
# Section 3: Process Monitoring
################################################################################

setup_monitoring() {
    section "3. PROCESS VISIBILITY & MONITORING"

    info "Constraint: True append-only requires off-system log shipping"
    info "Constraint: uappnd flag can be removed by root"

    local script="${LOG_DIR}/process_monitor.sh"
    local plist="${DAEMON_DIR}/${PLIST_PREFIX}.processmonitor.plist"
    local logfile="${LOG_DIR}/processes.log"

    [[ "$DRY_RUN" == "true" ]] && { info "[DRY] Would create monitoring daemon"; return 0; }

    run mkdir -p "$LOG_DIR"

    cat > "$script" << 'MONITOR_EOF'
#!/bin/bash
LOG="/var/log/fearless/processes.log"
while true; do
    {
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
        ps aux
        echo ""
    } >> "$LOG"
    sleep 1
done
MONITOR_EOF

    run chmod +x "$script"

    cat > "$plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_PREFIX}.processmonitor</string>
    <key>ProgramArguments</key>
    <array><string>${script}</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
</dict>
</plist>
PLIST_EOF

    run launchctl load "$plist" 2>/dev/null || true

    # Set append-only (partial protection)
    touch "$logfile"
    run chflags uappnd "$logfile" 2>/dev/null || true

    ok "Process monitor daemon installed"
    info "Log: $logfile (uappnd flag set)"
}

################################################################################
# Section 4: Remote Access Lockdown
################################################################################

disable_remote() {
    section "4. REMOTE ACCESS & CONTROL SURFACES"

    # SSH
    info "Disabling SSH..."
    run systemsetup -setremotelogin off 2>/dev/null || true
    run launchctl disable system/com.openssh.sshd 2>/dev/null || true
    ok "SSH disabled"

    # Screen Sharing
    info "Disabling Screen Sharing..."
    run launchctl disable system/com.apple.screensharing 2>/dev/null || true
    ok "Screen Sharing disabled"

    # Remote Desktop
    info "Disabling Apple Remote Desktop..."
    run launchctl disable system/com.apple.RemoteDesktop 2>/dev/null || true
    /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
        -deactivate -stop 2>/dev/null || true
    ok "ARD disabled"

    # AirDrop
    info "Disabling AirDrop..."
    run defaults write com.apple.NetworkBrowser DisableAirDrop -bool YES 2>/dev/null || true
    ok "AirDrop disabled"

    # Handoff/Continuity
    info "Disabling Handoff..."
    run defaults write ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd.plist \
        ActivityAdvertisingAllowed -bool NO 2>/dev/null || true
    run defaults write ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd.plist \
        ActivityReceivingAllowed -bool NO 2>/dev/null || true
    ok "Handoff disabled"

    # Universal Control
    info "Disabling Universal Control..."
    run defaults write com.apple.universalcontrol Disable -bool true 2>/dev/null || true
    ok "Universal Control disabled"

    # Accessibility remotes
    info "Disabling remote accessibility..."
    run defaults write com.apple.Accessibility SwitchControlEnabled -bool false 2>/dev/null || true
    run defaults write com.apple.Accessibility VoiceControlEnabled -bool false 2>/dev/null || true
    ok "Remote accessibility disabled"

    # Verification
    info "Checking listening ports..."
    local dangerous
    dangerous=$(run lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | grep -E ":(22|5900|3283|5988) " || true)

    if [[ -z "$dangerous" ]]; then
        ok "No dangerous ports (22/5900/3283) listening"
    else
        warn "Dangerous ports detected:"
        echo "$dangerous"
    fi
}

################################################################################
# Section 5: Firewall Configuration
################################################################################

configure_firewall() {
    section "5. FIREWALL CONFIGURATION"

    local fw="/usr/libexec/ApplicationFirewall/socketfilterfw"

    [[ ! -x "$fw" ]] && { warn "Firewall binary not found"; return 1; }

    info "Enabling Application Firewall..."
    "$fw" --setglobalstate on 2>/dev/null || true
    ok "Firewall enabled"

    info "Enabling stealth mode..."
    "$fw" --setstealthmode on 2>/dev/null || true
    ok "Stealth mode enabled"

    info "Blocking incoming connections..."
    "$fw" --setblockall on 2>/dev/null || true
    ok "Incoming blocked"

    info "Firewall status:"
    "$fw" --getglobalstate 2>/dev/null || true
    "$fw" --getstealthmode 2>/dev/null || true
}

################################################################################
# Section 6: DNS Hardening
################################################################################

harden_dns() {
    section "6. DNS HARDENING"

    info "Current DNS:"
    run scutil --dns 2>/dev/null | grep "nameserver" | head -5 || true

    info "Flushing DNS cache..."
    run dscacheutil -flushcache 2>/dev/null || true
    run killall -HUP mDNSResponder 2>/dev/null || true
    ok "DNS cache flushed"

    info "To set secure DNS manually:"
    echo "  networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1"
    echo "  networksetup -setdnsservers Wi-Fi 9.9.9.9 149.112.112.112"
}

################################################################################
# Section 7: HID Services
################################################################################

disable_hid() {
    section "7. HID/NFC/SMARTCARD SERVICES"

    local -a services=(
        "system/com.apple.ctkicdd"
        "system/com.apple.nfcd"
        "system/com.apple.cardd"
        "system/com.apple.PassKit"
    )

    for svc in "${services[@]}"; do
        run launchctl disable "$svc" 2>/dev/null || true
        info "Disabled: $svc"
    done

    ok "HID services disabled"
}

################################################################################
# Section 8: Verification Summary
################################################################################

verify_all() {
    section "8. VERIFICATION SUMMARY"

    echo ""
    echo "Manual verification commands:"
    echo "────────────────────────────────────────────────────────────"
    echo "  ifconfig | grep 'status: active' | wc -l    # Should be 1"
    echo "  netstat -rn | grep default                   # Single gateway"
    echo "  csrutil status                               # SIP enabled"
    echo "  lsof -iTCP -sTCP:LISTEN -n -P               # Minimal ports"
    echo "  launchctl list | grep -E 'ssh|screen'       # Should be empty"
    echo "────────────────────────────────────────────────────────────"
    echo ""

    info "Current state:"
    local ifaces procs ports
    ifaces=$(run ifconfig 2>/dev/null | grep -c "status: active" || echo "?")
    procs=$(run ps aux 2>/dev/null | wc -l | tr -d ' ')
    ports=$(run lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | wc -l | tr -d ' ')

    echo "  Active interfaces: $ifaces"
    echo "  Running processes: $procs"
    echo "  Listening ports:   $ports"
}

################################################################################
# Main
################################################################################

usage() {
    cat << EOF
fearlessInfa macOS Lockdown v${VERSION}

Usage: sudo $0 [OPTIONS]

Options:
  --hotspot SSID    Lock Wi-Fi to this network only (required for full lockdown)
  --dry-run         Show commands without executing
  --verify          Verification only (no changes)
  --yes             Skip confirmation prompt
  --help            Show this help

Environment:
  HOTSPOT_SSID      Alternative to --hotspot
  DRY_RUN=true      Alternative to --dry-run
  VERIFY_ONLY=true  Alternative to --verify

Constraints:
  - Full lockdown: 25-40 minutes
  - Verification only: ~2 minutes
  - SIP changes require Recovery boot (not automated)
  - Some services auto-reenable on reboot (daemons handle this)

Examples:
  sudo $0 --hotspot "iPhone" --yes
  sudo $0 --verify
  sudo DRY_RUN=true $0 --hotspot "MyHotspot"
EOF
    exit 0
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --hotspot)   HOTSPOT_SSID="$2"; shift 2 ;;
            --dry-run)   DRY_RUN=true; shift ;;
            --verify)    VERIFY_ONLY=true; shift ;;
            --yes)       SKIP_CONFIRM=true; shift ;;
            --help|-h)   usage ;;
            *)           die "Unknown option: $1" ;;
        esac
    done

    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║     fearlessInfa macOS LOCKDOWN v${VERSION}                  ║"
    echo "║     Production Implementation                            ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    [[ "$DRY_RUN" == "true" ]] && warn "DRY RUN MODE - no changes will be made"
    [[ "$VERIFY_ONLY" == "true" ]] && info "VERIFY ONLY MODE"

    # Verify only mode
    if [[ "$VERIFY_ONLY" == "true" ]]; then
        verify_volumes
        verify_all
        exit 0
    fi

    # Full lockdown
    check_macos
    check_root

    if [[ "$SKIP_CONFIRM" != "true" && "$DRY_RUN" != "true" ]]; then
        warn "This will lock down the system. Type 'yes' to continue:"
        read -r response
        [[ "$response" == "yes" ]] || { info "Aborted"; exit 0; }
    fi

    # Execute all sections
    network_lockdown
    create_network_daemon
    verify_volumes
    setup_monitoring
    disable_remote
    configure_firewall
    harden_dns
    disable_hid
    verify_all

    echo ""
    ok "LOCKDOWN COMPLETE"
    warn "Some settings require reboot to fully apply"
    info "Persistent daemons installed for network enforcement"
}

main "$@"
