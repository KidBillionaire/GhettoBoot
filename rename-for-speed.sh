#!/bin/bash

################################################################################
# GhettoBoot Rename for Speed
# Purpose: Rename our users/processes for INSTANT visual identification
#          Root → BrickRoot, our processes get prefix → instant spotting
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

################################################################################
# User Renaming
################################################################################

rename_root_user() {
    local new_name="${1:-BrickRoot}"

    echo -e "${CYAN}${BOLD}Renaming root user to: $new_name${NC}"
    echo -e "${YELLOW}This makes it INSTANTLY visible who we are in ps aux${NC}"
    echo ""

    # Backup first
    cp /etc/passwd /etc/passwd.pre-rename
    cp /etc/shadow /etc/shadow.pre-rename

    # Method 1: usermod (if available and safe)
    if command -v usermod &>/dev/null; then
        echo -e "${GREEN}→${NC} Using usermod..."

        # Note: Can't actually rename root with usermod in most systems
        # Instead, we'll add an alias user

        # Create BrickRoot as UID 0 (root equivalent)
        if ! grep -q "^${new_name}:" /etc/passwd; then
            echo "${new_name}:x:0:0:Brick Root:/root:/bin/bash" >> /etc/passwd
            # Copy root's password hash
            local root_hash=$(grep "^root:" /etc/shadow | cut -d: -f2-)
            echo "${new_name}:${root_hash}" >> /etc/shadow

            echo -e "${GREEN}✓ Created $new_name (UID 0)${NC}"
        fi
    fi

    # Create symlink for easy switching
    if [[ ! -f /bin/brick ]]; then
        cat > /bin/brick <<'EOFBRICK'
#!/bin/bash
# Quick switch to BrickRoot shell
exec su - BrickRoot
EOFBRICK
        chmod +x /bin/brick
        echo -e "${GREEN}✓ Created /bin/brick command${NC}"
    fi

    echo ""
    echo -e "${GREEN}${BOLD}✓ Done!${NC}"
    echo -e "${CYAN}Usage:${NC}"
    echo "  Login as: $new_name (same password as root)"
    echo "  Quick switch: brick"
    echo "  Now in ps aux you'll see $new_name instead of root!"
}

################################################################################
# Process Renaming/Tagging
################################################################################

tag_our_processes() {
    echo -e "${CYAN}${BOLD}Creating process tagging system...${NC}"

    # Create wrapper scripts that tag our processes
    mkdir -p /usr/local/bin/brick

    # Tag bash sessions
    cat > /usr/local/bin/brick/bash <<'EOF'
#!/bin/bash
# Tagged bash - shows as BrickBash in ps
exec -a BrickBash /bin/bash "$@"
EOF
    chmod +x /usr/local/bin/brick/bash

    # Tag Python
    cat > /usr/local/bin/brick/python3 <<'EOF'
#!/bin/bash
# Tagged python - shows as BrickPython
exec -a BrickPython /usr/bin/python3 "$@"
EOF
    chmod +x /usr/local/bin/brick/python3

    # Tag SSH
    cat > /usr/local/bin/brick/ssh <<'EOF'
#!/bin/bash
# Tagged SSH - shows as BrickSSH
exec -a BrickSSH /usr/bin/ssh "$@"
EOF
    chmod +x /usr/local/bin/brick/ssh

    # Tag sudo
    cat > /usr/local/bin/brick/sudo <<'EOF'
#!/bin/bash
# Tagged sudo - shows as BrickSudo
exec -a BrickSudo /usr/bin/sudo "$@"
EOF
    chmod +x /usr/local/bin/brick/sudo

    echo -e "${GREEN}✓ Created tagged wrappers in /usr/local/bin/brick/${NC}"
    echo ""
    echo -e "${CYAN}Add to PATH:${NC}"
    echo "  export PATH=\"/usr/local/bin/brick:\$PATH\""
    echo ""
    echo -e "${CYAN}Now your processes show as:${NC}"
    echo "  BrickBash, BrickPython, BrickSSH, BrickSudo"
    echo "  → Instant visual identification!"
}

################################################################################
# PS Alias for Color Coding
################################################################################

create_ps_alias() {
    echo -e "${CYAN}${BOLD}Creating smart ps alias...${NC}"

    cat > /usr/local/bin/psfast <<'EOFPS'
#!/bin/bash
# Fast PS with color coding
# Green = Brick* (ours)
# Red = everything else (SUSPICIOUS)

ps aux --no-headers | while read -r line; do
    if echo "$line" | grep -qE "Brick|BrickRoot"; then
        echo -e "\033[0;32m✓ $line\033[0m"
    else
        echo -e "\033[0;31m✗ $line\033[0m"
    fi
done | head -50
EOFPS

    chmod +x /usr/local/bin/psfast

    echo -e "${GREEN}✓ Created psfast command${NC}"
    echo ""
    echo -e "${CYAN}Usage:${NC} psfast"
    echo "  Green = Brick* processes (ours)"
    echo "  Red = everything else (CHECK THESE!)"
}

################################################################################
# Create .bashrc additions
################################################################################

create_bashrc_additions() {
    cat > /tmp/ghettoboot-bashrc.sh <<'EOFBASH'
# GhettoBoot Speed Additions
# Add these to your .bashrc for instant visual ID

# Colored prompt with BrickRoot
export PS1='\[\033[01;32m\]BrickRoot\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Fast aliases
alias p='psfast'
alias pk='sudo fast-kill.sh ultra'
alias pc='sudo fast-baseline.sh check'
alias pw='sudo fast-baseline.sh watch'

# PATH for tagged processes
export PATH="/usr/local/bin/brick:$PATH"

# Quick functions
kp() {
    # Kill by pattern
    sudo fast-kill.sh kill-pattern "$1"
}

whatsnew() {
    # What's new since baseline
    sudo fast-baseline.sh diff-procs
}
EOFBASH

    echo -e "${GREEN}✓ Created bashrc additions: /tmp/ghettoboot-bashrc.sh${NC}"
    echo ""
    echo -e "${CYAN}Add to .bashrc:${NC}"
    echo "  cat /tmp/ghettoboot-bashrc.sh >> ~/.bashrc"
    echo "  source ~/.bashrc"
}

################################################################################
# Visual Cheat Sheet
################################################################################

create_cheat_sheet() {
    cat > /usr/local/bin/cheat <<'EOFCHEAT'
#!/bin/bash
# GhettoBoot Quick Reference

cat <<'EOF'
╔════════════════════════════════════════════════════════════╗
║            GHETTOBOOT QUICK REFERENCE                      ║
╚════════════════════════════════════════════════════════════╝

INSTANT CHECKS (< 1 second)
────────────────────────────────────────────────────────────
  psfast              Color-coded process list (green=ours)
  pc                  Quick baseline check
  whatsnew            What's new since baseline

INSTANT KILLS
────────────────────────────────────────────────────────────
  pk                  Kill all unknowns (ultra fast)
  kp <pattern>        Kill by pattern (e.g., kp "nc.*-e")
  fast-kill.sh nuke   NUKE EVERYTHING (careful!)

MONITORING
────────────────────────────────────────────────────────────
  pw                  Watch mode (continuous 2sec checks)
  honeypot logs       View honeypot activity
  honeypot alerts     Check breach alerts

BASELINE
────────────────────────────────────────────────────────────
  fast-baseline.sh create     Create baseline (do first!)
  fast-baseline.sh check      Quick check
  fast-baseline.sh watch      Continuous monitoring

VISUAL ID
────────────────────────────────────────────────────────────
  Brick* processes    = OURS (good)
  Everything else     = CHECK IT (suspicious)
  BrickRoot user      = You
  root user           = ATTACKER?

EMERGENCY
────────────────────────────────────────────────────────────
  fast-kill.sh killswitch     Full lockdown + kill
  breach-kill-switch.sh       Manual breach response

SPEED TIPS
────────────────────────────────────────────────────────────
  - Create baseline BEFORE any attack
  - Use psfast for instant visual
  - pk = instant kill unknowns
  - No complex lookups = FAST response

EOF
EOFCHEAT

    chmod +x /usr/local/bin/cheat

    echo -e "${GREEN}✓ Created cheat sheet: cheat${NC}"
    echo -e "${CYAN}Run: cheat (to see quick reference)${NC}"
}

################################################################################
# All-in-one setup
################################################################################

setup_all() {
    echo -e "${CYAN}${BOLD}"
    echo "═══════════════════════════════════════════════════════════"
    echo "        SETTING UP FAST OPERATIONAL MODE"
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${NC}"

    rename_root_user "BrickRoot"
    echo ""

    tag_our_processes
    echo ""

    create_ps_alias
    echo ""

    create_bashrc_additions
    echo ""

    create_cheat_sheet
    echo ""

    echo -e "${GREEN}${BOLD}✓ SETUP COMPLETE!${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. cat /tmp/ghettoboot-bashrc.sh >> ~/.bashrc"
    echo "  2. source ~/.bashrc"
    echo "  3. sudo fast-baseline.sh create"
    echo "  4. Run: cheat (for quick reference)"
    echo ""
    echo -e "${YELLOW}Now you can:${NC}"
    echo "  • Login as BrickRoot (same password)"
    echo "  • Run 'psfast' to see color-coded processes"
    echo "  • Run 'pc' for instant checks"
    echo "  • Run 'pk' to kill unknowns instantly"
}

################################################################################
# Show current setup
################################################################################

show_status() {
    echo -e "${CYAN}${BOLD}Current Setup Status:${NC}"
    echo ""

    # Check BrickRoot user
    if grep -q "^BrickRoot:" /etc/passwd; then
        echo -e "${GREEN}✓${NC} BrickRoot user exists"
    else
        echo -e "${RED}✗${NC} BrickRoot user not created"
    fi

    # Check tagged wrappers
    if [[ -d /usr/local/bin/brick ]]; then
        echo -e "${GREEN}✓${NC} Tagged process wrappers installed"
        ls /usr/local/bin/brick/ 2>/dev/null | sed 's/^/    → /'
    else
        echo -e "${RED}✗${NC} Tagged wrappers not installed"
    fi

    # Check psfast
    if [[ -f /usr/local/bin/psfast ]]; then
        echo -e "${GREEN}✓${NC} psfast command available"
    else
        echo -e "${RED}✗${NC} psfast not installed"
    fi

    # Check cheat
    if [[ -f /usr/local/bin/cheat ]]; then
        echo -e "${GREEN}✓${NC} cheat command available"
    else
        echo -e "${RED}✗${NC} cheat not installed"
    fi

    # Check bashrc additions
    if [[ -f /tmp/ghettoboot-bashrc.sh ]]; then
        echo -e "${GREEN}✓${NC} Bashrc additions created"
        echo -e "${YELLOW}    Add to .bashrc:${NC} cat /tmp/ghettoboot-bashrc.sh >> ~/.bashrc"
    fi
}

################################################################################
# Main
################################################################################

show_help() {
    cat <<EOF
Rename for Speed - Instant visual identification

Usage: $0 [COMMAND]

Commands:
    setup               Setup everything (recommended)
    status              Show current setup status

    rename-root [name]  Rename root user (default: BrickRoot)
    tag-processes       Create tagged process wrappers
    ps-alias            Create psfast color-coded ps
    bashrc              Create bashrc additions
    cheat               Create cheat sheet

    help                Show this help

Why rename?
    - BrickRoot vs root → instant visual ID
    - BrickBash, BrickPython → know it's ours
    - ps aux shows Brick* = green (ours)
    - Everything else = red (CHECK IT!)

Examples:
    $0 setup            # Do everything
    $0 status           # Check setup

EOF
}

main() {
    local command="${1:-help}"

    case "$command" in
        setup|all)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            setup_all
            ;;
        status|check)
            show_status
            ;;
        rename-root|rename)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            rename_root_user "$2"
            ;;
        tag-processes|tag)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            tag_our_processes
            ;;
        ps-alias|ps)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            create_ps_alias
            ;;
        bashrc|bash)
            create_bashrc_additions
            ;;
        cheat|reference)
            create_cheat_sheet
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
