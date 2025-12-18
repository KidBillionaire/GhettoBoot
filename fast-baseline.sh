#!/bin/bash

################################################################################
# GhettoBoot Fast Baseline System
# Purpose: SPEED OPTIMIZED - Pre-define our processes for instant detection
#          No complex lookups - just fast diffs
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Fast baseline files
BASELINE_DIR="/var/ghettoboot/baseline"
BASELINE_PROCESSES="$BASELINE_DIR/processes.baseline"
BASELINE_USERS="$BASELINE_DIR/users.baseline"
BASELINE_NETWORK="$BASELINE_DIR/network.baseline"
BASELINE_FILES="$BASELINE_DIR/files.baseline"

################################################################################
# Fast Baseline Creation
################################################################################

create_baseline() {
    echo -e "${CYAN}${BOLD}Creating fast baseline...${NC}"

    mkdir -p "$BASELINE_DIR"

    # 1. PROCESS BASELINE (just PIDs and command names - FAST)
    echo -e "${GREEN}→${NC} Snapshotting processes..."
    ps aux --no-headers | awk '{print $2":"$11}' | sort > "$BASELINE_PROCESSES"

    # 2. USER BASELINE
    echo -e "${GREEN}→${NC} Snapshotting users..."
    cut -d: -f1 /etc/passwd | sort > "$BASELINE_USERS"

    # 3. NETWORK BASELINE (listening ports)
    echo -e "${GREEN}→${NC} Snapshotting network..."
    netstat -tlnp 2>/dev/null | grep LISTEN | awk '{print $4}' | sort > "$BASELINE_NETWORK"

    # 4. CRITICAL FILES CHECKSUM (fast - only critical files)
    echo -e "${GREEN}→${NC} Checksumming critical files..."
    {
        md5sum /etc/passwd 2>/dev/null
        md5sum /etc/shadow 2>/dev/null
        md5sum /etc/sudoers 2>/dev/null
        md5sum /etc/ssh/sshd_config 2>/dev/null
    } | sort > "$BASELINE_FILES"

    # Save timestamp
    date +%s > "$BASELINE_DIR/timestamp"

    echo -e "${GREEN}${BOLD}✓ Baseline created ($(date))${NC}"
    echo -e "${CYAN}Baseline files:${NC}"
    ls -lh "$BASELINE_DIR"
}

################################################################################
# FAST DIFF - Instant Detection
################################################################################

fast_diff_processes() {
    echo -e "${CYAN}${BOLD}=== PROCESS DIFF (FAST) ===${NC}"

    if [[ ! -f "$BASELINE_PROCESSES" ]]; then
        echo -e "${RED}No baseline! Run: $0 create${NC}"
        return 1
    fi

    # Current processes
    local current_procs=$(mktemp)
    ps aux --no-headers | awk '{print $2":"$11}' | sort > "$current_procs"

    # FAST DIFF - what's new?
    local new_procs=$(comm -13 "$BASELINE_PROCESSES" "$current_procs")

    if [[ -z "$new_procs" ]]; then
        echo -e "${GREEN}✓ No new processes${NC}"
    else
        echo -e "${RED}${BOLD}⚠ NEW PROCESSES DETECTED:${NC}"
        echo "$new_procs" | while IFS=: read -r pid cmd; do
            # Get full details ONLY for suspicious ones (fast)
            local user=$(ps -p "$pid" -o user= 2>/dev/null)
            echo -e "${RED}  PID:$pid USER:$user CMD:$cmd${NC}"
        done
    fi

    rm -f "$current_procs"
}

fast_diff_users() {
    echo -e "${CYAN}${BOLD}=== USER DIFF (FAST) ===${NC}"

    if [[ ! -f "$BASELINE_USERS" ]]; then
        echo -e "${RED}No baseline!${NC}"
        return 1
    fi

    local current_users=$(mktemp)
    cut -d: -f1 /etc/passwd | sort > "$current_users"

    local new_users=$(comm -13 "$BASELINE_USERS" "$current_users")

    if [[ -z "$new_users" ]]; then
        echo -e "${GREEN}✓ No new users${NC}"
    else
        echo -e "${RED}${BOLD}⚠ NEW USERS DETECTED:${NC}"
        echo "$new_users" | while read -r user; do
            echo -e "${RED}  → $user${NC}"
        done
    fi

    rm -f "$current_users"
}

fast_diff_network() {
    echo -e "${CYAN}${BOLD}=== NETWORK DIFF (FAST) ===${NC}"

    if [[ ! -f "$BASELINE_NETWORK" ]]; then
        echo -e "${RED}No baseline!${NC}"
        return 1
    fi

    local current_net=$(mktemp)
    netstat -tlnp 2>/dev/null | grep LISTEN | awk '{print $4}' | sort > "$current_net"

    local new_ports=$(comm -13 "$BASELINE_NETWORK" "$current_net")

    if [[ -z "$new_ports" ]]; then
        echo -e "${GREEN}✓ No new listening ports${NC}"
    else
        echo -e "${RED}${BOLD}⚠ NEW LISTENING PORTS:${NC}"
        echo "$new_ports" | while read -r port; do
            echo -e "${RED}  → $port${NC}"
        done
    fi

    rm -f "$current_net"
}

fast_diff_files() {
    echo -e "${CYAN}${BOLD}=== FILE INTEGRITY (FAST) ===${NC}"

    if [[ ! -f "$BASELINE_FILES" ]]; then
        echo -e "${RED}No baseline!${NC}"
        return 1
    fi

    local current_files=$(mktemp)
    {
        md5sum /etc/passwd 2>/dev/null
        md5sum /etc/shadow 2>/dev/null
        md5sum /etc/sudoers 2>/dev/null
        md5sum /etc/ssh/sshd_config 2>/dev/null
    } | sort > "$current_files"

    if diff -q "$BASELINE_FILES" "$current_files" >/dev/null; then
        echo -e "${GREEN}✓ Critical files unchanged${NC}"
    else
        echo -e "${RED}${BOLD}⚠ CRITICAL FILES MODIFIED:${NC}"
        diff "$BASELINE_FILES" "$current_files" | grep "^<\|^>" | while read -r line; do
            echo -e "${RED}  $line${NC}"
        done
    fi

    rm -f "$current_files"
}

################################################################################
# INSTANT CHECK - All diffs at once (FAST)
################################################################################

instant_check() {
    echo -e "${CYAN}${BOLD}"
    echo "═══════════════════════════════════════════════════════════"
    echo "         INSTANT SECURITY CHECK (FAST MODE)"
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${NC}"

    if [[ ! -d "$BASELINE_DIR" ]]; then
        echo -e "${RED}No baseline exists! Create one first:${NC}"
        echo "  sudo $0 create"
        exit 1
    fi

    local baseline_age=$(($(date +%s) - $(cat "$BASELINE_DIR/timestamp")))
    echo -e "${CYAN}Baseline age: $((baseline_age / 60)) minutes${NC}"
    echo ""

    fast_diff_processes
    echo ""
    fast_diff_users
    echo ""
    fast_diff_network
    echo ""
    fast_diff_files
    echo ""

    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Check completed in <1 second${NC}"
}

################################################################################
# Watch mode - continuous fast checks
################################################################################

watch_mode() {
    echo -e "${CYAN}Starting continuous monitoring (2 second intervals)...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""

    while true; do
        clear
        instant_check
        sleep 2
    done
}

################################################################################
# Pre-define our known processes (manual whitelist)
################################################################################

define_known_processes() {
    cat > "$BASELINE_DIR/known_processes.list" <<'EOF'
# GhettoBoot Known Good Processes
# These are OUR processes - everything else is suspicious

# System critical
systemd
init
kthreadd
ksoftirqd
kworker
rcu_sched
migration
watchdog

# Our services
honeypot-boot
breach-monitor
process-sandbox
sshd
NetworkManager

# Shell/terminal
bash
sh
zsh
screen
tmux

# Monitoring
top
htop
ps
netstat

# Our renamed user processes (prefix with BrickRoot)
# Add your custom processes here
EOF

    echo -e "${GREEN}✓ Created known process list: $BASELINE_DIR/known_processes.list${NC}"
    echo -e "${YELLOW}Edit this file to add your known processes${NC}"
}

################################################################################
# Export for quick visual inspection
################################################################################

visual_check() {
    echo -e "${CYAN}${BOLD}QUICK VISUAL CHECK${NC}"
    echo ""

    # Show ALL processes but highlight unknowns in RED
    ps aux --no-headers | while read -r line; do
        local cmd=$(echo "$line" | awk '{print $11}')
        local pid=$(echo "$line" | awk '{print $2}')

        # Check if in baseline
        if grep -q "^${pid}:" "$BASELINE_PROCESSES" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $line"
        else
            echo -e "${RED}✗${NC} $line"
        fi
    done | head -50
}

################################################################################
# Main
################################################################################

show_help() {
    cat <<EOF
Fast Baseline System - Instant threat detection

Usage: $0 [COMMAND]

Commands:
    create              Create baseline (do this first!)
    check               Run instant security check (FAST)
    watch               Continuous monitoring (2 sec intervals)
    visual              Visual process check (green=known, red=new)

    diff-procs          Diff processes only
    diff-users          Diff users only
    diff-network        Diff network only
    diff-files          Diff files only

    define              Create known process list
    rebuild             Rebuild baseline from scratch

    help                Show this help

Speed Optimization:
    - No complex algorithms, just fast diffs
    - Pre-computed baselines
    - Instant detection (<1 second)
    - Perfect for rapid response

Workflow:
    1. sudo $0 create           # Create baseline BEFORE attack
    2. sudo $0 check            # Instant check anytime
    3. sudo $0 watch            # Monitor continuously

EOF
}

main() {
    local command="${1:-help}"

    case "$command" in
        create|baseline)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            create_baseline
            ;;
        check|scan)
            instant_check
            ;;
        watch|monitor)
            watch_mode
            ;;
        visual|show)
            visual_check
            ;;
        diff-procs|procs)
            fast_diff_processes
            ;;
        diff-users|users)
            fast_diff_users
            ;;
        diff-network|network)
            fast_diff_network
            ;;
        diff-files|files)
            fast_diff_files
            ;;
        define)
            define_known_processes
            ;;
        rebuild)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            rm -rf "$BASELINE_DIR"
            create_baseline
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
