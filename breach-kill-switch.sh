#!/bin/bash

################################################################################
# GhettoBoot Breach Kill Switch
# Purpose: Detect system compromise and initiate automatic lockdown + reboot
#          If breach detected: KILL EVERYTHING → LOCKDOWN → AUTO-REBOOT
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
BREACH_LOG="/var/log/breach-events.log"
KILL_SWITCH_TRIGGER="/tmp/.kill_switch_activated"
SECURE_BASE="/var/.cache/system"
LOCKDOWN_SCRIPT="/usr/local/sbin/system-lockdown.sh"
HONEYPOT_BOOT="/usr/local/sbin/honeypot-boot.sh"
BREACH_THRESHOLD=3  # Number of breach indicators to trigger kill switch

# Breach indicators counter
BREACH_SCORE=0

################################################################################
# Logging Functions
################################################################################

log_breach() {
    local severity="$1"
    local event="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$severity] $event" >> "$BREACH_LOG"
    echo -e "${RED}[BREACH-${severity}]${NC} $event"

    # Increment breach score for high severity events
    if [[ "$severity" == "CRITICAL" ]]; then
        ((BREACH_SCORE+=3))
    elif [[ "$severity" == "HIGH" ]]; then
        ((BREACH_SCORE+=2))
    elif [[ "$severity" == "MEDIUM" ]]; then
        ((BREACH_SCORE+=1))
    fi
}

log_kill_switch() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [KILL-SWITCH] $message" >> "$BREACH_LOG"
    echo -e "${RED}${BOLD}[KILL-SWITCH]${NC} $message"
}

################################################################################
# Breach Detection Checks
################################################################################

check_unauthorized_root_access() {
    log_breach "INFO" "Checking for unauthorized root access..."

    # Check for new root users or modified /etc/passwd
    if [[ -f /etc/passwd.original ]]; then
        if ! diff /etc/passwd /etc/passwd.original >/dev/null 2>&1; then
            log_breach "CRITICAL" "Unauthorized modification to /etc/passwd detected!"
            return 1
        fi
    fi

    # Check for suspicious SUID binaries
    local suspicious_suid=$(find / -perm -4000 -type f 2>/dev/null | \
        grep -vE "^/(usr/)?bin/(sudo|su|passwd|ping|mount|umount)" || true)

    if [[ -n "$suspicious_suid" ]]; then
        log_breach "HIGH" "Suspicious SUID binaries found: $suspicious_suid"
        return 1
    fi

    return 0
}

check_rootkit_indicators() {
    log_breach "INFO" "Scanning for rootkit indicators..."

    # Check for hidden processes (compare ps vs /proc)
    local ps_count=$(ps aux | wc -l)
    local proc_count=$(ls -1 /proc | grep -E '^[0-9]+$' | wc -l)

    if [[ $((proc_count - ps_count)) -gt 10 ]]; then
        log_breach "CRITICAL" "Hidden processes detected! ps:$ps_count proc:$proc_count"
        return 1
    fi

    # Check for kernel module anomalies
    if lsmod | grep -qiE "(rootkit|hidden|stealth)"; then
        log_breach "CRITICAL" "Suspicious kernel module detected!"
        return 1
    fi

    # Check for LD_PRELOAD hijacking
    if [[ -n "$LD_PRELOAD" ]]; then
        log_breach "HIGH" "LD_PRELOAD is set: $LD_PRELOAD"
        return 1
    fi

    return 0
}

check_backdoor_processes() {
    log_breach "INFO" "Checking for backdoor processes..."

    # Known backdoor patterns
    local backdoor_patterns=(
        "nc.*-l.*-e"           # Netcat backdoor
        "bash.*-i.*>&"         # Reverse shell
        "/dev/tcp/"            # TCP backdoor
        "python.*-c.*socket"   # Python reverse shell
        "perl.*-e.*socket"     # Perl backdoor
        "ncat.*--exec"         # Ncat backdoor
        "socat.*exec"          # Socat backdoor
    )

    for pattern in "${backdoor_patterns[@]}"; do
        if ps aux | grep -v grep | grep -qE "$pattern"; then
            log_breach "CRITICAL" "Backdoor process detected: $pattern"
            return 1
        fi
    done

    return 0
}

check_network_anomalies() {
    log_breach "INFO" "Checking for network anomalies..."

    # Check for unusual listening ports
    local suspicious_ports=$(netstat -tlnp 2>/dev/null | \
        grep -E ":(4444|5555|6666|7777|8888|9999|31337)" || true)

    if [[ -n "$suspicious_ports" ]]; then
        log_breach "HIGH" "Suspicious listening ports: $suspicious_ports"
        return 1
    fi

    # Check for connections to known C2 servers (simplified check)
    local active_connections=$(netstat -tn | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1)

    # In production, check against threat intel feeds
    # For now, check for RFC1918 violations or suspicious patterns

    return 0
}

check_file_integrity() {
    log_breach "INFO" "Checking critical file integrity..."

    # Check if critical system files have been modified
    local critical_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/sudoers"
        "/etc/ssh/sshd_config"
    )

    for file in "${critical_files[@]}"; do
        if [[ -f "${file}.original" ]]; then
            if ! diff "$file" "${file}.original" >/dev/null 2>&1; then
                log_breach "CRITICAL" "Critical file modified: $file"
                return 1
            fi
        fi
    done

    # Check for webshells in common locations
    local webshells=$(find /var/www /tmp /dev/shm -type f \
        -name "*.php" -o -name "*.jsp" -o -name "*.asp" 2>/dev/null | \
        xargs grep -l "eval\|base64_decode\|exec\|system" 2>/dev/null || true)

    if [[ -n "$webshells" ]]; then
        log_breach "CRITICAL" "Potential webshells found: $webshells"
        return 1
    fi

    return 0
}

check_honeypot_compromise() {
    log_breach "INFO" "Checking if honeypot jail has been escaped..."

    # Check if processes have escaped the jail
    local escaped_procs=$(ps aux | grep "/var/honeypot/jail" | \
        grep -v "chroot" | grep -v grep || true)

    if [[ -n "$escaped_procs" ]]; then
        log_breach "CRITICAL" "Processes escaped honeypot jail!"
        return 1
    fi

    # Check if hidden volumes have been accessed
    if [[ -f "$SECURE_BASE/.accessed" ]]; then
        log_breach "CRITICAL" "Hidden volumes have been accessed!"
        return 1
    fi

    return 0
}

################################################################################
# Kill Switch Activation
################################################################################

activate_kill_switch() {
    log_kill_switch "═══════════════════════════════════════════════════════════"
    log_kill_switch "BREACH DETECTED - ACTIVATING KILL SWITCH"
    log_kill_switch "═══════════════════════════════════════════════════════════"

    # Create kill switch marker
    echo "ACTIVATED_AT=$(date +%s)" > "$KILL_SWITCH_TRIGGER"
    echo "BREACH_SCORE=$BREACH_SCORE" >> "$KILL_SWITCH_TRIGGER"

    # Step 1: KILL ALL PROCESSES
    log_kill_switch "STEP 1: Terminating all non-essential processes..."
    kill_all_processes

    # Step 2: EXECUTE SYSTEM LOCKDOWN
    log_kill_switch "STEP 2: Executing system lockdown..."
    execute_lockdown

    # Step 3: PRESERVE EVIDENCE
    log_kill_switch "STEP 3: Preserving breach evidence..."
    preserve_evidence

    # Step 4: PREPARE FOR REBOOT
    log_kill_switch "STEP 4: Preparing auto-restart configuration..."
    prepare_auto_restart

    # Step 5: INITIATE REBOOT
    log_kill_switch "STEP 5: Initiating system reboot in 10 seconds..."
    log_kill_switch "System will restart with honeypot configuration"

    # Final warning
    echo -e "${RED}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         BREACH KILL SWITCH ACTIVATED                       ║"
    echo "║         SYSTEM WILL REBOOT IN 10 SECONDS                   ║"
    echo "║         HONEYPOT WILL RESTART AUTOMATICALLY                ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    sleep 10

    # REBOOT NOW
    sync
    reboot -f
}

kill_all_processes() {
    # Get current shell tree to exclude
    local current_pid=$$
    local exclude_pids=($current_pid)

    while [[ $current_pid -gt 1 ]]; do
        current_pid=$(ps -o ppid= -p $current_pid | tr -d ' ')
        if [[ -n "$current_pid" && $current_pid -gt 1 ]]; then
            exclude_pids+=($current_pid)
        else
            break
        fi
    done

    log_kill_switch "Killing all processes except: ${exclude_pids[*]}"

    # Kill everything except our shell tree and critical kernel processes
    ps -eo pid,comm | tail -n +2 | while read -r pid comm; do
        # Skip excluded PIDs
        if [[ " ${exclude_pids[@]} " =~ " $pid " ]]; then
            continue
        fi

        # Skip critical kernel processes
        if [[ "$comm" =~ ^(init|systemd|kernel|kthreadd)$ ]]; then
            continue
        fi

        # KILL IT
        kill -9 "$pid" 2>/dev/null || true
    done

    log_kill_switch "Process termination complete"
}

execute_lockdown() {
    # Run the system lockdown script if available
    if [[ -x "$LOCKDOWN_SCRIPT" ]]; then
        log_kill_switch "Executing system lockdown script..."
        "$LOCKDOWN_SCRIPT" --kill-all || true
    else
        # Manual lockdown
        log_kill_switch "Manual lockdown: Remounting filesystems read-only..."

        # Remount all filesystems as read-only
        mount -o remount,ro / 2>/dev/null || true

        # Disable network
        log_kill_switch "Disabling network interfaces..."
        ip link set dev eth0 down 2>/dev/null || true
        ip link set dev wlan0 down 2>/dev/null || true
    fi
}

preserve_evidence() {
    local evidence_dir="$SECURE_BASE/breach-evidence-$(date +%Y%m%d-%H%M%S)"

    mkdir -p "$evidence_dir" 2>/dev/null || return

    log_kill_switch "Preserving evidence to: $evidence_dir"

    # Copy logs
    cp -r /var/log/* "$evidence_dir/" 2>/dev/null || true

    # Dump process list
    ps auxf > "$evidence_dir/processes.txt" 2>/dev/null || true

    # Dump network connections
    netstat -tulpn > "$evidence_dir/netstat.txt" 2>/dev/null || true
    ss -tulpn > "$evidence_dir/ss.txt" 2>/dev/null || true

    # Dump loaded modules
    lsmod > "$evidence_dir/lsmod.txt" 2>/dev/null || true

    # Copy modified files
    find /etc -type f -mtime -1 -exec cp {} "$evidence_dir/etc-modified/" \; 2>/dev/null || true

    log_kill_switch "Evidence preserved"
}

prepare_auto_restart() {
    log_kill_switch "Configuring auto-restart with honeypot..."

    # Create systemd service to run honeypot on boot
    cat > /etc/systemd/system/honeypot-auto-restart.service <<EOF
[Unit]
Description=GhettoBoot Honeypot Auto-Restart
After=network.target
DefaultDependencies=no
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=$HONEYPOT_BOOT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Enable the service
    systemctl enable honeypot-auto-restart.service 2>/dev/null || true

    # Set kernel parameters to auto-reboot on panic
    echo "kernel.panic = 10" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1 || true

    log_kill_switch "Auto-restart configured"
}

################################################################################
# Monitoring Loop
################################################################################

continuous_monitoring() {
    log_breach "INFO" "Starting continuous breach monitoring..."

    while true; do
        BREACH_SCORE=0

        # Run all breach detection checks
        check_unauthorized_root_access || true
        check_rootkit_indicators || true
        check_backdoor_processes || true
        check_network_anomalies || true
        check_file_integrity || true
        check_honeypot_compromise || true

        # Check if breach threshold exceeded
        if [[ $BREACH_SCORE -ge $BREACH_THRESHOLD ]]; then
            log_breach "CRITICAL" "Breach threshold exceeded! Score: $BREACH_SCORE"
            activate_kill_switch
            # If we reach here, reboot failed - try again
            sleep 5
            reboot -f
        fi

        # Wait before next check
        sleep 30
    done
}

################################################################################
# Main Commands
################################################################################

show_status() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}        BREACH DETECTION STATUS${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    if [[ -f "$KILL_SWITCH_TRIGGER" ]]; then
        echo -e "${RED}Status: KILL SWITCH ACTIVATED${NC}"
        cat "$KILL_SWITCH_TRIGGER"
    else
        echo -e "${GREEN}Status: Active Monitoring${NC}"
    fi

    echo ""
    echo -e "${CYAN}Recent Breach Events (last 20):${NC}"
    if [[ -f "$BREACH_LOG" ]]; then
        tail -20 "$BREACH_LOG"
    else
        echo "No events logged"
    fi
    echo ""
}

run_scan() {
    echo -e "${CYAN}Running one-time breach detection scan...${NC}"
    echo ""

    BREACH_SCORE=0

    check_unauthorized_root_access || true
    check_rootkit_indicators || true
    check_backdoor_processes || true
    check_network_anomalies || true
    check_file_integrity || true
    check_honeypot_compromise || true

    echo ""
    echo -e "${CYAN}═══ Scan Results ═══${NC}"
    echo "Breach Score: $BREACH_SCORE / $BREACH_THRESHOLD"

    if [[ $BREACH_SCORE -ge $BREACH_THRESHOLD ]]; then
        echo -e "${RED}CRITICAL: Breach threshold exceeded!${NC}"
        echo "Run with --activate-kill-switch to initiate lockdown and reboot"
    elif [[ $BREACH_SCORE -gt 0 ]]; then
        echo -e "${YELLOW}WARNING: Suspicious activity detected${NC}"
    else
        echo -e "${GREEN}SAFE: No breach indicators found${NC}"
    fi
    echo ""
}

show_help() {
    cat <<EOF
Breach Kill Switch - Automatic breach detection and system lockdown

Usage: $0 [COMMAND]

Commands:
    monitor             Start continuous breach monitoring (foreground)
    monitor-bg          Start monitoring in background
    scan                Run one-time breach detection scan
    status              Show kill switch status and recent events

    activate            Manually activate kill switch (DANGEROUS!)
    stop                Stop background monitoring

    help                Show this help message

Description:
    This script continuously monitors for system compromise.
    If breach detected: KILLS ALL PROCESSES → LOCKDOWN → AUTO-REBOOT
    System automatically restarts with honeypot configuration.

Breach Detection:
    - Unauthorized root access
    - Rootkit indicators
    - Backdoor processes
    - Network anomalies
    - File integrity violations
    - Honeypot jail escapes

Examples:
    $0 monitor-bg       # Start background monitoring
    $0 scan             # Run breach detection scan
    $0 status           # Check current status

EOF
}

main() {
    local command="${1:-help}"

    case "$command" in
        monitor)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            continuous_monitoring
            ;;
        monitor-bg)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            nohup "$0" monitor > /var/log/breach-monitor.log 2>&1 &
            echo -e "${GREEN}Breach monitoring started in background (PID: $!)${NC}"
            ;;
        scan)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            run_scan
            ;;
        status)
            show_status
            ;;
        activate|--activate-kill-switch)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            echo -e "${RED}WARNING: This will kill all processes and reboot the system!${NC}"
            read -p "Are you sure? (type 'YES' to confirm): " confirm
            if [[ "$confirm" == "YES" ]]; then
                activate_kill_switch
            else
                echo "Cancelled"
            fi
            ;;
        stop)
            pkill -f "breach-kill-switch.sh monitor" || true
            echo "Stopped breach monitoring"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
