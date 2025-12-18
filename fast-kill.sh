#!/bin/bash

################################################################################
# GhettoBoot Fast Kill
# Purpose: INSTANT KILL - No bullshit, just murder everything that's not ours
#          Optimized for SPEED - sub-second execution
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

BASELINE_PROCESSES="/var/ghettoboot/baseline/processes.baseline"
KILL_LOG="/var/log/fast-kill.log"

################################################################################
# FAST KILL - Kill anything not in baseline
################################################################################

fast_kill_unknowns() {
    echo -e "${RED}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║              FAST KILL ENGAGED                             ║"
    echo "║         KILLING ALL UNKNOWN PROCESSES                      ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    if [[ ! -f "$BASELINE_PROCESSES" ]]; then
        echo -e "${RED}ERROR: No baseline! Run fast-baseline.sh create first${NC}"
        exit 1
    fi

    local killed=0
    local current_shell=$$

    # Get current process list
    ps aux --no-headers | while read -r line; do
        local pid=$(echo "$line" | awk '{print $2}')
        local cmd=$(echo "$line" | awk '{print $11}')
        local user=$(echo "$line" | awk '{print $1}')

        # Skip current shell
        [[ $pid -eq $current_shell ]] && continue

        # Skip kernel threads
        [[ $cmd == "["* ]] && continue

        # Check if in baseline
        if ! grep -q "^${pid}:" "$BASELINE_PROCESSES" 2>/dev/null; then
            echo -e "${RED}✗ KILLING${NC} PID:$pid USER:$user CMD:$cmd"

            # LOG IT
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] KILLED PID:$pid USER:$user CMD:$cmd" >> "$KILL_LOG"

            # KILL IT (no mercy)
            kill -9 "$pid" 2>/dev/null && ((killed++)) || true
        fi
    done

    echo ""
    echo -e "${GREEN}${BOLD}Killed $killed unknown processes${NC}"
}

################################################################################
# ULTRA FAST KILL - Kill by PID list (from fast-baseline diff)
################################################################################

ultra_fast_kill() {
    echo -e "${RED}${BOLD}ULTRA FAST KILL MODE${NC}"

    # Get PIDs of new processes (FAST - one liner)
    local new_pids=$(comm -13 "$BASELINE_PROCESSES" <(ps aux --no-headers | awk '{print $2":"$11}' | sort) | cut -d: -f1)

    if [[ -z "$new_pids" ]]; then
        echo -e "${GREEN}No unknown processes to kill${NC}"
        return
    fi

    echo -e "${RED}Killing PIDs: $new_pids${NC}"

    # KILL THEM ALL (one shot)
    echo "$new_pids" | xargs -r kill -9 2>/dev/null

    # Count
    local killed=$(echo "$new_pids" | wc -w)
    echo -e "${GREEN}✓ Killed $killed processes${NC}"
}

################################################################################
# NUKE MODE - Kill everything except our shell and critical
################################################################################

nuke_mode() {
    echo -e "${RED}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                   ☢ NUKE MODE ☢                            ║"
    echo "║         KILLING EVERYTHING (EXCEPT CRITICAL)               ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${YELLOW}This will kill EVERYTHING except:${NC}"
    echo "  - Current shell"
    echo "  - Kernel threads"
    echo "  - init/systemd"
    echo ""
    read -p "Continue? (type YES): " confirm

    if [[ "$confirm" != "YES" ]]; then
        echo "Aborted"
        return
    fi

    local current_shell=$$
    local killed=0

    ps aux --no-headers | while read -r line; do
        local pid=$(echo "$line" | awk '{print $2}')
        local cmd=$(echo "$line" | awk '{print $11}')

        # Skip current shell and parents
        [[ $pid -eq $current_shell ]] && continue
        [[ $pid -eq 1 ]] && continue  # init
        [[ $cmd == "["* ]] && continue  # kernel threads

        echo -e "${RED}☢${NC} Killing PID:$pid CMD:$cmd"
        kill -9 "$pid" 2>/dev/null && ((killed++)) || true
    done

    echo ""
    echo -e "${RED}${BOLD}☢ NUKED $killed processes${NC}"
}

################################################################################
# SMART KILL - Kill by pattern (fast)
################################################################################

kill_by_pattern() {
    local pattern="$1"

    if [[ -z "$pattern" ]]; then
        echo "Usage: $0 kill-pattern <pattern>"
        echo "Example: $0 kill-pattern 'python.*reverse'"
        exit 1
    fi

    echo -e "${RED}Killing processes matching: $pattern${NC}"

    local killed=0
    ps aux | grep -v grep | grep -E "$pattern" | while read -r line; do
        local pid=$(echo "$line" | awk '{print $2}')
        local cmd=$(echo "$line" | awk '{print $11}')

        echo -e "${RED}✗${NC} PID:$pid CMD:$cmd"
        kill -9 "$pid" 2>/dev/null && ((killed++)) || true
    done

    echo -e "${GREEN}Killed $killed processes${NC}"
}

################################################################################
# INSTANT VISUAL KILL - Show unknowns and offer to kill
################################################################################

instant_visual_kill() {
    echo -e "${CYAN}${BOLD}UNKNOWN PROCESSES:${NC}"
    echo ""

    if [[ ! -f "$BASELINE_PROCESSES" ]]; then
        echo -e "${RED}No baseline!${NC}"
        exit 1
    fi

    # Show unknowns with line numbers
    local count=0
    local pids=()

    ps aux --no-headers | while read -r line; do
        local pid=$(echo "$line" | awk '{print $2}')
        local cmd=$(echo "$line" | awk '{print $11}')

        if ! grep -q "^${pid}:" "$BASELINE_PROCESSES" 2>/dev/null; then
            ((count++))
            pids+=($pid)
            echo -e "${RED}$count)${NC} $line"
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo -e "${GREEN}No unknown processes!${NC}"
        return
    fi

    echo ""
    echo -e "${YELLOW}Found $count unknown processes${NC}"
    read -p "Kill all? (y/n): " answer

    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        ultra_fast_kill
    else
        echo "Cancelled"
    fi
}

################################################################################
# KILLSWITCH - Instant system lockdown
################################################################################

killswitch() {
    echo -e "${RED}${BOLD}"
    cat <<'EOF'
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║              ⚠ KILLSWITCH ACTIVATED ⚠                      ║
║                                                            ║
║    1. Kill all unknown processes                           ║
║    2. Lock down network                                    ║
║    3. Remount read-only                                    ║
║    4. Disable execution                                    ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    # 1. KILL UNKNOWNS
    echo -e "${RED}[1/4] Killing unknown processes...${NC}"
    ultra_fast_kill

    # 2. NETWORK LOCKDOWN
    echo -e "${RED}[2/4] Locking down network...${NC}"
    iptables -P INPUT DROP 2>/dev/null || true
    iptables -P FORWARD DROP 2>/dev/null || true
    iptables -P OUTPUT DROP 2>/dev/null || true
    ip link set dev eth0 down 2>/dev/null || true
    ip link set dev wlan0 down 2>/dev/null || true

    # 3. REMOUNT READ-ONLY
    echo -e "${RED}[3/4] Remounting filesystems read-only...${NC}"
    mount -o remount,ro / 2>/dev/null || true

    # 4. DISABLE EXECUTION
    echo -e "${RED}[4/4] Disabling execution on data volumes...${NC}"
    mount -o remount,noexec /home 2>/dev/null || true
    mount -o remount,noexec /tmp 2>/dev/null || true

    echo ""
    echo -e "${GREEN}${BOLD}✓ KILLSWITCH COMPLETE${NC}"
    echo -e "${YELLOW}System locked down. Reboot to restore.${NC}"
}

################################################################################
# Quick stats
################################################################################

show_stats() {
    echo -e "${CYAN}${BOLD}QUICK STATS${NC}"
    echo ""

    if [[ ! -f "$BASELINE_PROCESSES" ]]; then
        echo -e "${RED}No baseline!${NC}"
        exit 1
    fi

    local baseline_count=$(wc -l < "$BASELINE_PROCESSES")
    local current_count=$(ps aux --no-headers | wc -l)
    local diff=$((current_count - baseline_count))

    echo -e "${CYAN}Baseline processes:${NC} $baseline_count"
    echo -e "${CYAN}Current processes:${NC} $current_count"

    if [[ $diff -gt 0 ]]; then
        echo -e "${RED}Unknown processes:${NC} ${RED}${BOLD}+$diff${NC}"
    else
        echo -e "${GREEN}Unknown processes:${NC} 0"
    fi

    # Check kill log
    if [[ -f "$KILL_LOG" ]]; then
        local kills=$(wc -l < "$KILL_LOG")
        echo -e "${CYAN}Total kills:${NC} $kills"
        echo ""
        echo -e "${CYAN}Recent kills (last 10):${NC}"
        tail -10 "$KILL_LOG" 2>/dev/null | while read -r line; do
            echo -e "${YELLOW}  → $line${NC}"
        done
    fi
}

################################################################################
# Main
################################################################################

show_help() {
    cat <<EOF
Fast Kill - Instant process termination

Usage: $0 [COMMAND]

Commands:
    kill                Kill all unknown processes (safe mode)
    ultra               Ultra fast kill (optimized)
    nuke                NUKE MODE - kill everything (dangerous!)
    visual              Show unknowns and offer to kill

    kill-pattern <pat>  Kill by regex pattern
    killswitch          Full system lockdown + kill

    stats               Show quick statistics
    log                 Show kill log

    help                Show this help

Examples:
    $0 kill                         # Kill unknowns
    $0 ultra                        # Fast kill
    $0 kill-pattern 'nc.*-e'        # Kill netcat backdoors
    $0 killswitch                   # Full lockdown

Speed:
    - Ultra fast kill: <0.5 seconds
    - Uses pre-computed baseline
    - No complex lookups
    - Instant detection → instant death

EOF
}

main() {
    local command="${1:-help}"

    if [[ $EUID -ne 0 && "$command" != "help" && "$command" != "stats" && "$command" != "log" ]]; then
        echo -e "${RED}Must run as root${NC}"
        exit 1
    fi

    case "$command" in
        kill|fast)
            fast_kill_unknowns
            ;;
        ultra|fastest)
            ultra_fast_kill
            ;;
        nuke|killall)
            nuke_mode
            ;;
        visual|show)
            instant_visual_kill
            ;;
        kill-pattern|pattern)
            kill_by_pattern "$2"
            ;;
        killswitch|lockdown)
            killswitch
            ;;
        stats|status)
            show_stats
            ;;
        log)
            if [[ -f "$KILL_LOG" ]]; then
                tail -50 "$KILL_LOG"
            else
                echo "No kills logged yet"
            fi
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
