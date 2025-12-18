#!/bin/bash

################################################################################
# macOS Lockdown Script - Audited Version
# Implements fearlessInfa operational audit recommendations
#
# Critical constraints addressed:
# - Network interface reality on macOS
# - APFS volume architecture understanding
# - SIP boundaries
# - Persistent service control
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
DRY_RUN="${DRY_RUN:-false}"
HOTSPOT_SSID="${HOTSPOT_SSID:-}"
LOG_DIR="/var/log/fearless"
PROCESS_LOG="$LOG_DIR/process_monitor.log"

################################################################################
# Logging
################################################################################

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Must run as root (sudo)"
        exit 1
    fi
}

run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] $*"
        return 0
    else
        "$@"
    fi
}

################################################################################
# Section 1: Network Invariants
################################################################################

network_lockdown() {
    log_section "NETWORK INVARIANTS"

    # 1.1 Enumerate all network interfaces
    log_info "Enumerating network interfaces..."
    local interfaces=$(ifconfig | grep "^[a-z]" | cut -d: -f1)
    echo "$interfaces"

    # 1.2 Disable Bluetooth
    log_info "Disabling Bluetooth..."
    run_cmd defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -int 0
    killall -HUP blued 2>/dev/null || true
    log_success "Bluetooth disabled"

    # 1.3 Disable Wi-Fi if no hotspot specified, else configure for hotspot only
    if [[ -n "$HOTSPOT_SSID" ]]; then
        log_info "Configuring Wi-Fi for hotspot only: $HOTSPOT_SSID"

        # List and remove all preferred networks except hotspot
        local networks=$(networksetup -listpreferredwirelessnetworks en0 2>/dev/null | tail -n +2 | sed 's/^[[:space:]]*//')
        while IFS= read -r network; do
            if [[ -n "$network" && "$network" != "$HOTSPOT_SSID" ]]; then
                log_info "Removing network: $network"
                run_cmd networksetup -removepreferredwirelessnetwork en0 "$network"
            fi
        done <<< "$networks"
        log_success "Wi-Fi configured for hotspot only"
    else
        log_warning "No HOTSPOT_SSID set - Wi-Fi networks unchanged"
    fi

    # 1.4 Disable AWDL (AirDrop wireless)
    log_info "Disabling AWDL interface..."
    run_cmd ifconfig awdl0 down 2>/dev/null || true
    log_success "AWDL disabled (may re-enable automatically)"

    # 1.5 Disable non-essential interfaces
    log_info "Disabling Thunderbolt Bridge and other interfaces..."
    for iface in bridge0 en1 en2 en3 en4 en5; do
        if ifconfig "$iface" >/dev/null 2>&1; then
            run_cmd ifconfig "$iface" down 2>/dev/null || true
            log_info "Disabled: $iface"
        fi
    done

    # 1.6 Verification
    log_info "Active interfaces verification:"
    local active_count=$(ifconfig | grep "status: active" | wc -l | tr -d ' ')
    ifconfig | grep -B5 "status: active" | grep "^[a-z]" || true

    if [[ "$active_count" -le 1 ]]; then
        log_success "Network invariant: $active_count active interface(s)"
    else
        log_warning "Multiple active interfaces detected: $active_count"
    fi

    # Show default route
    log_info "Default gateway:"
    netstat -rn | grep default | head -1 || echo "No default route"
}

################################################################################
# Section 2: Volume & Authority Verification
################################################################################

volume_verification() {
    log_section "VOLUME & AUTHORITY SEPARATION"

    # 2.1 Check SIP status (enforces system volume protection)
    log_info "Checking System Integrity Protection..."
    local sip_status=$(csrutil status 2>&1)
    echo "$sip_status"

    if echo "$sip_status" | grep -q "enabled"; then
        log_success "SIP enabled - system volume is read-only and sealed"
    else
        log_warning "SIP is disabled - system volume may be writable"
    fi

    # 2.2 Show APFS volume layout
    log_info "APFS volume structure:"
    diskutil apfs list 2>/dev/null | head -30 || diskutil list

    # 2.3 Verify system volume is read-only
    log_info "Mount verification:"
    mount | grep " / " || true

    if mount | grep " / " | grep -q "read-only"; then
        log_success "Root volume is read-only"
    else
        log_info "Root volume mount status shown above"
    fi
}

################################################################################
# Section 3: Process Monitoring Setup
################################################################################

setup_process_monitoring() {
    log_section "PROCESS VISIBILITY & MONITORING"

    # 3.1 Create log directory
    log_info "Setting up process monitoring..."
    run_cmd mkdir -p "$LOG_DIR"

    # 3.2 Create monitoring script
    local monitor_script="$LOG_DIR/process_monitor.sh"

    if [[ "$DRY_RUN" != "true" ]]; then
        cat > "$monitor_script" << 'MONITOR_EOF'
#!/bin/bash
LOGFILE="/var/log/fearless/process_monitor.log"
while true; do
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOGFILE"
    ps aux >> "$LOGFILE"
    sleep 1
done
MONITOR_EOF
        chmod +x "$monitor_script"
        log_success "Created: $monitor_script"
    fi

    # 3.3 Create launch daemon for persistence
    local plist="/Library/LaunchDaemons/com.fearless.processmonitor.plist"

    if [[ "$DRY_RUN" != "true" ]]; then
        cat > "$plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.fearless.processmonitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>$monitor_script</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
PLIST_EOF
        log_success "Created: $plist"

        # Load the daemon
        launchctl load "$plist" 2>/dev/null || true
        log_success "Process monitor daemon loaded"
    fi

    # 3.4 Set append-only flag on log (partial protection)
    if [[ -f "$PROCESS_LOG" ]]; then
        run_cmd chflags uappnd "$PROCESS_LOG" 2>/dev/null || true
        log_info "Set append-only flag on log (root can still modify)"
    fi

    # 3.5 Current process snapshot
    log_info "Current process count: $(ps aux | wc -l | tr -d ' ')"
}

################################################################################
# Section 4: Remote Access & Control Surfaces
################################################################################

disable_remote_access() {
    log_section "REMOTE ACCESS & CONTROL SURFACES"

    # 4.1 Disable SSH
    log_info "Disabling SSH..."
    run_cmd systemsetup -setremotelogin off 2>/dev/null || true
    run_cmd launchctl disable system/com.openssh.sshd 2>/dev/null || true
    log_success "SSH disabled"

    # 4.2 Disable Screen Sharing
    log_info "Disabling Screen Sharing..."
    run_cmd launchctl disable system/com.apple.screensharing 2>/dev/null || true
    log_success "Screen Sharing disabled"

    # 4.3 Disable Remote Management (ARD)
    log_info "Disabling Apple Remote Desktop..."
    run_cmd launchctl disable system/com.apple.RemoteDesktop 2>/dev/null || true
    run_cmd /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -stop 2>/dev/null || true
    log_success "ARD disabled"

    # 4.4 Disable AirDrop
    log_info "Disabling AirDrop..."
    run_cmd defaults write com.apple.NetworkBrowser DisableAirDrop -bool YES
    log_success "AirDrop disabled"

    # 4.5 Disable Handoff and Continuity
    log_info "Disabling Handoff/Continuity..."
    defaults write ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd.plist ActivityAdvertisingAllowed -bool NO 2>/dev/null || true
    defaults write ~/Library/Preferences/ByHost/com.apple.coreservices.useractivityd.plist ActivityReceivingAllowed -bool NO 2>/dev/null || true
    log_success "Handoff disabled"

    # 4.6 Disable Universal Control
    log_info "Disabling Universal Control..."
    run_cmd defaults write com.apple.universalcontrol Disable -bool true 2>/dev/null || true
    log_success "Universal Control disabled"

    # 4.7 Disable accessibility remote features
    log_info "Disabling remote accessibility features..."
    run_cmd defaults write com.apple.Accessibility SwitchControlEnabled -bool false 2>/dev/null || true
    run_cmd defaults write com.apple.Accessibility VoiceControlEnabled -bool false 2>/dev/null || true
    log_success "Remote accessibility disabled"

    # 4.8 Verification - check listening ports
    log_info "Listening TCP ports:"
    lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | head -20 || netstat -an | grep LISTEN | head -20

    # Check for problematic services
    local bad_ports=$(lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | grep -E ":(22|5900|3283) " || true)
    if [[ -z "$bad_ports" ]]; then
        log_success "No SSH/VNC/ARD ports listening"
    else
        log_warning "Potentially dangerous ports still open:"
        echo "$bad_ports"
    fi
}

################################################################################
# Section 5: Firewall Configuration (MISSING FROM ORIGINAL)
################################################################################

configure_firewall() {
    log_section "FIREWALL CONFIGURATION"

    # 5.1 Enable Application Firewall
    log_info "Enabling Application Firewall..."
    run_cmd /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    log_success "Application Firewall enabled"

    # 5.2 Enable stealth mode
    log_info "Enabling stealth mode..."
    run_cmd /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
    log_success "Stealth mode enabled"

    # 5.3 Block all incoming (except essential)
    log_info "Blocking all incoming connections..."
    run_cmd /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on
    log_success "Incoming connections blocked"

    # 5.4 Firewall status
    log_info "Firewall status:"
    /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
    /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
}

################################################################################
# Section 6: DNS Hardening (MISSING FROM ORIGINAL)
################################################################################

harden_dns() {
    log_section "DNS HARDENING"

    # 6.1 Show current DNS
    log_info "Current DNS configuration:"
    scutil --dns | grep "nameserver" | head -5

    # 6.2 Set secure DNS (Cloudflare/Quad9)
    log_info "Consider setting secure DNS servers manually:"
    echo "  networksetup -setdnsservers Wi-Fi 1.1.1.1 9.9.9.9"

    # 6.3 Flush DNS cache
    log_info "Flushing DNS cache..."
    run_cmd dscacheutil -flushcache 2>/dev/null || true
    run_cmd killall -HUP mDNSResponder 2>/dev/null || true
    log_success "DNS cache flushed"
}

################################################################################
# Section 7: HID/NFC/SmartCard Lockdown
################################################################################

disable_hid_services() {
    log_section "HID/NFC/SMARTCARD SERVICES"

    local services=(
        "system/com.apple.ctkicdd"
        "system/com.apple.nfcd"
        "system/com.apple.cardd"
        "system/com.apple.PassKit"
    )

    for service in "${services[@]}"; do
        run_cmd launchctl disable "$service" 2>/dev/null || true
        log_info "Disabled: $service"
    done

    log_success "HID services disabled"
}

################################################################################
# Section 8: Verification Summary
################################################################################

verification_summary() {
    log_section "VERIFICATION SUMMARY"

    echo ""
    echo "Quick verification commands to run manually:"
    echo "─────────────────────────────────────────────"
    echo "  ifconfig | grep 'status: active' | wc -l   # Should be 1"
    echo "  netstat -rn | grep default                  # Single gateway"
    echo "  csrutil status                              # SIP enabled"
    echo "  lsof -iTCP -sTCP:LISTEN -n -P              # Minimal ports"
    echo "  launchctl list | grep -E '(ssh|screen)'    # Should be empty"
    echo ""

    # Summary counts
    log_info "System State:"
    echo "  Active interfaces: $(ifconfig | grep 'status: active' | wc -l | tr -d ' ')"
    echo "  Running processes: $(ps aux | wc -l | tr -d ' ')"
    echo "  Listening ports:   $(lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | wc -l | tr -d ' ')"
}

################################################################################
# Main
################################################################################

print_banner() {
    echo -e "${RED}"
    echo "================================================================"
    echo "     macOS LOCKDOWN - AUDITED VERSION"
    echo "     Based on fearlessInfa Operational Audit"
    echo "================================================================"
    echo -e "${NC}"
}

main() {
    print_banner

    # Parse args
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                log_warning "DRY RUN MODE"
                shift ;;
            --hotspot)
                HOTSPOT_SSID="$2"
                shift 2 ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --dry-run          Show commands without executing"
                echo "  --hotspot SSID     Configure Wi-Fi for this hotspot only"
                echo "  --help             Show this help"
                echo ""
                echo "Environment:"
                echo "  HOTSPOT_SSID       Hotspot network name"
                echo "  DRY_RUN=true       Enable dry run mode"
                exit 0 ;;
            *)
                log_error "Unknown: $1"
                exit 1 ;;
        esac
    done

    check_root

    echo ""
    log_warning "This will lock down the system. Continue? (yes/no)"

    if [[ "$DRY_RUN" != "true" ]]; then
        read -r response
        if [[ "$response" != "yes" ]]; then
            log_info "Aborted"
            exit 0
        fi
    fi

    # Execute all lockdown sections
    network_lockdown
    volume_verification
    setup_process_monitoring
    disable_remote_access
    configure_firewall
    harden_dns
    disable_hid_services
    verification_summary

    echo ""
    log_success "LOCKDOWN COMPLETE"
    log_warning "Reboot will restore some settings. Create launch daemons for persistence."
}

main "$@"
