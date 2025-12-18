#!/bin/bash

################################################################################
# GhettoBoot Pre-Shutdown
# Purpose: Kill non-essentials BEFORE attack to reduce attack surface
#          Run this to go into "battle mode" - minimal processes only
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

################################################################################
# Non-Essential Services to Kill
################################################################################

# Services to stop (bloat that attackers can abuse)
NON_ESSENTIAL_SERVICES=(
    "bluetooth"
    "cups"              # Printing
    "avahi-daemon"      # Network discovery
    "ModemManager"
    "apache2"           # If not needed
    "nginx"             # If not needed
    "mysql"             # If not needed
    "postgresql"        # If not needed
    "docker"            # If not needed
    "snapd"
    "packagekit"
    "fwupd"
    "accounts-daemon"
    "colord"
    "udisks2"
)

# Process patterns to kill (desktop bloat)
NON_ESSENTIAL_PATTERNS=(
    "gnome-"
    "kde-"
    "evolution"
    "thunderbird"
    "firefox"
    "chrome"
    "slack"
    "discord"
    "spotify"
    "steam"
    "dropbox"
)

################################################################################
# Battle Mode
################################################################################

enter_battle_mode() {
    echo -e "${RED}${BOLD}"
    cat <<'EOF'
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║              ENTERING BATTLE MODE                          ║
║                                                            ║
║  Killing all non-essential processes                       ║
║  Minimal attack surface                                    ║
║  Maximum performance                                       ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    local killed_services=0
    local killed_processes=0

    # 1. Stop non-essential services
    echo -e "${CYAN}[1/3] Stopping non-essential services...${NC}"
    for service in "${NON_ESSENTIAL_SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "${YELLOW}  → Stopping $service${NC}"
            systemctl stop "$service" 2>/dev/null && ((killed_services++)) || true
        fi
    done
    echo -e "${GREEN}  ✓ Stopped $killed_services services${NC}"
    echo ""

    # 2. Kill non-essential processes
    echo -e "${CYAN}[2/3] Killing non-essential processes...${NC}"
    for pattern in "${NON_ESSENTIAL_PATTERNS[@]}"; do
        local procs=$(pgrep -f "$pattern" 2>/dev/null || true)
        if [[ -n "$procs" ]]; then
            echo -e "${YELLOW}  → Killing $pattern processes${NC}"
            pkill -9 -f "$pattern" 2>/dev/null && ((killed_processes++)) || true
        fi
    done
    echo -e "${GREEN}  ✓ Killed processes matching $killed_processes patterns${NC}"
    echo ""

    # 3. Drop caches (free up memory)
    echo -e "${CYAN}[3/3] Dropping caches...${NC}"
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo -e "${GREEN}  ✓ Caches dropped${NC}"
    echo ""

    # Show results
    echo -e "${GREEN}${BOLD}✓ BATTLE MODE ACTIVE${NC}"
    echo ""
    show_battle_stats
}

################################################################################
# Show stats
################################################################################

show_battle_stats() {
    echo -e "${CYAN}System Status:${NC}"
    echo ""

    # Process count
    local proc_count=$(ps aux --no-headers | wc -l)
    echo -e "  Running processes: ${BOLD}$proc_count${NC}"

    # Memory
    local mem_free=$(free -h | awk '/^Mem:/ {print $4}')
    echo -e "  Free memory: ${BOLD}$mem_free${NC}"

    # CPU load
    local load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    echo -e "  Load average: ${BOLD}$load${NC}"

    echo ""
    echo -e "${YELLOW}System ready for rapid response${NC}"
}

################################################################################
# Restore mode
################################################################################

exit_battle_mode() {
    echo -e "${GREEN}Exiting battle mode...${NC}"

    # Restart services
    for service in "${NON_ESSENTIAL_SERVICES[@]}"; do
        if systemctl list-unit-files | grep -q "^$service"; then
            systemctl start "$service" 2>/dev/null || true
        fi
    done

    echo -e "${GREEN}✓ Services restored${NC}"
}

################################################################################
# Minimal mode - even more extreme
################################################################################

minimal_mode() {
    echo -e "${RED}${BOLD}MINIMAL MODE - Keeping ONLY critical processes${NC}"

    # This goes even further - stops everything except:
    # - Current shell
    # - Kernel
    # - Init
    # - SSH (if we need remote access)
    # - Network basics

    read -p "This is EXTREME. Continue? (type YES): " confirm
    if [[ "$confirm" != "YES" ]]; then
        echo "Cancelled"
        return
    fi

    # Enter battle mode first
    enter_battle_mode

    # Then kill even more
    echo ""
    echo -e "${RED}Killing additional processes...${NC}"

    # Stop all systemd services except critical
    systemctl list-units --type=service --state=running | grep "\.service" | \
        awk '{print $1}' | while read -r service; do

        # Keep critical services
        if echo "$service" | grep -qE "(ssh|network|system|dbus|login)"; then
            continue
        fi

        echo -e "${YELLOW}  → Stopping $service${NC}"
        systemctl stop "$service" 2>/dev/null || true
    done

    echo ""
    echo -e "${RED}${BOLD}✓ MINIMAL MODE ACTIVE${NC}"
    echo -e "${YELLOW}Only critical processes running${NC}"
    show_battle_stats
}

################################################################################
# Quick kill list
################################################################################

show_kill_list() {
    echo -e "${CYAN}${BOLD}Non-Essential Process Kill List:${NC}"
    echo ""

    echo -e "${YELLOW}Services to stop:${NC}"
    for service in "${NON_ESSENTIAL_SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "${GREEN}  ✓ $service (running - will stop)${NC}"
        else
            echo -e "  ○ $service (not running)"
        fi
    done

    echo ""
    echo -e "${YELLOW}Process patterns to kill:${NC}"
    for pattern in "${NON_ESSENTIAL_PATTERNS[@]}"; do
        local count=$(pgrep -fc "$pattern" 2>/dev/null || echo 0)
        if [[ $count -gt 0 ]]; then
            echo -e "${GREEN}  ✓ $pattern ($count processes - will kill)${NC}"
        else
            echo -e "  ○ $pattern (none running)"
        fi
    done
}

################################################################################
# Main
################################################################################

show_help() {
    cat <<EOF
Pre-Shutdown - Battle Mode Preparation

Usage: $0 [COMMAND]

Commands:
    battle              Enter battle mode (kill non-essentials)
    minimal             Minimal mode (EXTREME - keep only critical)
    exit                Exit battle mode (restore services)

    list                Show what will be killed
    stats               Show current system stats

    help                Show this help

Battle Mode:
    - Stops non-essential services (bluetooth, cups, etc.)
    - Kills desktop apps (browsers, slack, etc.)
    - Drops caches
    - Minimal attack surface
    - Fast performance

Minimal Mode:
    - Even more extreme
    - Stops ALL non-critical services
    - Absolute minimal process count
    - Use before expected attack

Examples:
    $0 battle           # Enter battle mode
    $0 list             # See what will be killed
    $0 exit             # Restore normal mode

EOF
}

main() {
    local command="${1:-help}"

    case "$command" in
        battle|fight|war)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            enter_battle_mode
            ;;
        minimal|extreme)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            minimal_mode
            ;;
        exit|restore|normal)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            exit_battle_mode
            ;;
        list|show)
            show_kill_list
            ;;
        stats|status)
            show_battle_stats
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
