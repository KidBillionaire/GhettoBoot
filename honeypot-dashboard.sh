#!/bin/bash

################################################################################
# GhettoBoot Honeypot Dashboard
# Purpose: Real-time monitoring dashboard for honeypot activity
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Log files
HONEYPOT_LOG="/var/log/honeypot-activity.log"
BREACH_LOG="/var/log/breach-events.log"
PROCESS_LOG="/var/log/honeypot-processes.log"
ALERT_LOG="/var/log/honeypot-alerts.log"

################################################################################
# Dashboard Components
################################################################################

clear_screen() {
    clear
}

print_header() {
    echo -e "${CYAN}${BOLD}"
    cat <<'EOF'
╔════════════════════════════════════════════════════════════════════════════╗
║                    GHETTOBOOT HONEYPOT DASHBOARD                           ║
║                    Real-time Attack Monitoring                             ║
╚════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${BLUE}Last updated: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""
}

show_system_status() {
    echo -e "${CYAN}${BOLD}═══ SYSTEM STATUS ═══${NC}"
    echo ""

    # Honeypot mode
    if [[ -f /tmp/.honeypot_active ]]; then
        echo -e "${YELLOW}Mode:${NC} ${YELLOW}${BOLD}HONEYPOT ACTIVE${NC} - Decoy system exposed"
    elif [[ -f /tmp/.secure_mode ]]; then
        echo -e "${GREEN}Mode:${NC} ${GREEN}${BOLD}SECURE MODE${NC} - Operating from hidden volumes"
    else
        echo -e "${BLUE}Mode:${NC} Normal"
    fi

    # Kill switch status
    if [[ -f /tmp/.kill_switch_activated ]]; then
        echo -e "${RED}Kill Switch:${NC} ${RED}${BOLD}ACTIVATED${NC}"
    else
        echo -e "${GREEN}Kill Switch:${NC} Armed and monitoring"
    fi

    # Services status
    local services=(
        "ghettoboo-honeypot-boot"
        "ghettoboot-breach-monitor"
        "ghettoboot-process-monitor"
    )

    echo ""
    echo -e "${CYAN}Services:${NC}"
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service.service" 2>/dev/null; then
            echo -e "  ${GREEN}●${NC} $service"
        else
            echo -e "  ${RED}○${NC} $service"
        fi
    done
    echo ""
}

show_attack_statistics() {
    echo -e "${CYAN}${BOLD}═══ ATTACK STATISTICS ═══${NC}"
    echo ""

    local total_events=0
    local ssh_attacks=0
    local suspicious_procs=0
    local escalation_attempts=0

    if [[ -f "$ALERT_LOG" ]]; then
        total_events=$(wc -l < "$ALERT_LOG")
        ssh_attacks=$(grep -c "SSH_" "$ALERT_LOG" 2>/dev/null || echo 0)
        suspicious_procs=$(grep -c "SUSPICIOUS_PROCESS" "$ALERT_LOG" 2>/dev/null || echo 0)
        escalation_attempts=$(grep -c "PRIVILEGE_ESCALATION" "$ALERT_LOG" 2>/dev/null || echo 0)
    fi

    printf "%-30s %s\n" "Total Security Events:" "$total_events"
    printf "%-30s %s\n" "SSH Attack Attempts:" "$ssh_attacks"
    printf "%-30s %s\n" "Suspicious Processes:" "$suspicious_procs"
    printf "%-30s %s\n" "Privilege Escalation:" "$escalation_attempts"
    echo ""
}

show_recent_alerts() {
    echo -e "${CYAN}${BOLD}═══ RECENT ALERTS (Last 10) ═══${NC}"
    echo ""

    if [[ -f "$ALERT_LOG" ]]; then
        tail -10 "$ALERT_LOG" | while read -r line; do
            if echo "$line" | grep -q "CRITICAL"; then
                echo -e "${RED}$line${NC}"
            elif echo "$line" | grep -q "HIGH"; then
                echo -e "${YELLOW}$line${NC}"
            else
                echo -e "${BLUE}$line${NC}"
            fi
        done
    else
        echo -e "${GREEN}No alerts${NC}"
    fi
    echo ""
}

show_active_threats() {
    echo -e "${CYAN}${BOLD}═══ ACTIVE THREATS ═══${NC}"
    echo ""

    # Check for processes in honeypot jail
    local jailed_procs=$(ps aux | grep "/var/honeypot/jail" | grep -v grep | wc -l)

    if [[ $jailed_procs -gt 0 ]]; then
        echo -e "${YELLOW}Sandboxed processes: $jailed_procs${NC}"
        ps aux | grep "/var/honeypot/jail" | grep -v grep | head -5
    else
        echo -e "${GREEN}No active threats detected${NC}"
    fi
    echo ""

    # Check for suspicious network connections
    local suspicious_conns=$(netstat -tn 2>/dev/null | grep ESTABLISHED | \
        grep -vE "(127.0.0.1|::1)" | wc -l)

    if [[ $suspicious_conns -gt 0 ]]; then
        echo -e "${YELLOW}Active external connections: $suspicious_conns${NC}"
    fi
    echo ""
}

show_honeypot_captures() {
    echo -e "${CYAN}${BOLD}═══ HONEYPOT CAPTURES (Last 5) ═══${NC}"
    echo ""

    if [[ -f "$PROCESS_LOG" ]]; then
        tail -5 "$PROCESS_LOG" | while read -r line; do
            echo -e "${MAGENTA}→${NC} $line"
        done
    else
        echo "No captures yet"
    fi
    echo ""
}

show_volume_status() {
    echo -e "${CYAN}${BOLD}═══ HIDDEN VOLUMES ═══${NC}"
    echo ""

    if mount | grep -q "/var/.cache/system/secure"; then
        local usage=$(df -h /var/.cache/system/secure | tail -1 | awk '{print $5}')
        echo -e "${GREEN}●${NC} Hidden volume mounted (Usage: $usage)"
    else
        echo -e "${YELLOW}○${NC} Hidden volume not mounted"
    fi

    # Check if hidden directories exist
    if [[ -d /var/.cache/system/.system_logs ]]; then
        local size=$(du -sh /var/.cache/system/.system_logs 2>/dev/null | cut -f1)
        echo -e "  Secure storage: $size"
    fi
    echo ""
}

show_footer() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Commands: [q]uit | [r]efresh | [a]lerts | [l]ogs | [s]tatus${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
}

################################################################################
# Interactive Dashboard
################################################################################

run_interactive_dashboard() {
    local refresh_interval=5

    while true; do
        clear_screen
        print_header
        show_system_status
        show_attack_statistics
        show_recent_alerts
        show_active_threats
        show_honeypot_captures
        show_volume_status
        show_footer

        # Wait for input or timeout
        read -t $refresh_interval -n 1 key

        case "$key" in
            q|Q)
                echo ""
                echo "Exiting dashboard..."
                exit 0
                ;;
            r|R)
                continue
                ;;
            a|A)
                show_detailed_alerts
                read -p "Press Enter to continue..."
                ;;
            l|L)
                show_live_logs
                ;;
            s|S)
                show_detailed_status
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

show_detailed_alerts() {
    clear_screen
    echo -e "${RED}${BOLD}═══ DETAILED ALERTS ═══${NC}"
    echo ""

    if [[ -f "$ALERT_LOG" ]]; then
        tail -50 "$ALERT_LOG" | less -R
    else
        echo "No alerts found"
    fi
}

show_live_logs() {
    clear_screen
    echo -e "${CYAN}${BOLD}═══ LIVE LOGS (Ctrl+C to exit) ═══${NC}"
    echo ""

    tail -f "$HONEYPOT_LOG" "$BREACH_LOG" "$ALERT_LOG" 2>/dev/null
}

show_detailed_status() {
    clear_screen
    echo -e "${CYAN}${BOLD}═══ DETAILED SYSTEM STATUS ═══${NC}"
    echo ""

    echo -e "${YELLOW}Service Status:${NC}"
    systemctl status ghettoboo-honeypot-boot.service --no-pager --lines=5 2>/dev/null || echo "Not running"
    echo ""

    echo -e "${YELLOW}Resource Usage:${NC}"
    df -h | grep -E "(Filesystem|/var)"
    echo ""
    free -h
    echo ""

    echo -e "${YELLOW}Network Connections:${NC}"
    netstat -tn | grep ESTABLISHED | head -10
    echo ""
}

################################################################################
# Static Report Mode
################################################################################

generate_report() {
    local report_file="honeypot-report-$(date +%Y%m%d-%H%M%S).txt"

    cat > "$report_file" <<EOF
═══════════════════════════════════════════════════════════
         GHETTOBOOT HONEYPOT REPORT
         Generated: $(date '+%Y-%m-%d %H:%M:%S')
═══════════════════════════════════════════════════════════

SYSTEM STATUS
─────────────────────────────────────────────────────────
$(if [[ -f /tmp/.honeypot_active ]]; then echo "Mode: HONEYPOT ACTIVE"; else echo "Mode: Normal"; fi)
$(if [[ -f /tmp/.kill_switch_activated ]]; then echo "Kill Switch: ACTIVATED"; else echo "Kill Switch: Armed"; fi)

ATTACK STATISTICS
─────────────────────────────────────────────────────────
Total Events: $(wc -l < "$ALERT_LOG" 2>/dev/null || echo 0)
SSH Attacks: $(grep -c "SSH_" "$ALERT_LOG" 2>/dev/null || echo 0)
Suspicious Processes: $(grep -c "SUSPICIOUS_PROCESS" "$ALERT_LOG" 2>/dev/null || echo 0)
Privilege Escalation: $(grep -c "PRIVILEGE_ESCALATION" "$ALERT_LOG" 2>/dev/null || echo 0)

RECENT ALERTS (Last 20)
─────────────────────────────────────────────────────────
$(tail -20 "$ALERT_LOG" 2>/dev/null || echo "No alerts")

CAPTURED PROCESSES (Last 20)
─────────────────────────────────────────────────────────
$(tail -20 "$PROCESS_LOG" 2>/dev/null || echo "No captures")

SYSTEM LOGS (Last 30 lines)
─────────────────────────────────────────────────────────
$(tail -30 "$HONEYPOT_LOG" 2>/dev/null || echo "No logs")

═══════════════════════════════════════════════════════════
                    END OF REPORT
═══════════════════════════════════════════════════════════
EOF

    echo "Report generated: $report_file"
}

################################################################################
# Main
################################################################################

show_help() {
    cat <<EOF
Honeypot Dashboard - Real-time monitoring and reporting

Usage: $0 [COMMAND]

Commands:
    dashboard           Launch interactive dashboard (default)
    report              Generate static text report
    status              Show quick status summary
    alerts              Show recent alerts
    stats               Show attack statistics

    help                Show this help message

Examples:
    $0                  # Launch interactive dashboard
    $0 report           # Generate report file
    $0 alerts           # View alerts

Interactive Controls:
    q - Quit
    r - Refresh now
    a - Detailed alerts
    l - Live logs
    s - Detailed status

EOF
}

main() {
    local command="${1:-dashboard}"

    case "$command" in
        dashboard|watch|monitor)
            run_interactive_dashboard
            ;;
        report)
            generate_report
            ;;
        status)
            clear_screen
            print_header
            show_system_status
            show_attack_statistics
            ;;
        alerts)
            show_recent_alerts
            ;;
        stats)
            show_attack_statistics
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
