#!/bin/bash

################################################################################
# GhettoBoot Obfuscation Deploy
# Purpose: Rename EVERYTHING to look innocuous
#          Attacker finds scripts? They see "leads.csv" not "hidden-volume"
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

################################################################################
# Obfuscated File Names (look like boring system files)
################################################################################

declare -A OBFUSCATED_NAMES=(
    # Scripts → Innocent names
    ["honeypot-boot.sh"]="system-cache-init.sh"
    ["hidden-volume-manager.sh"]="disk-maintenance.sh"
    ["process-sandbox.sh"]="cpu-scheduler.sh"
    ["breach-kill-switch.sh"]="kernel-watchdog.sh"
    ["wifi-honeypot.sh"]="network-discovery.sh"
    ["fast-baseline.sh"]="system-snapshot.sh"
    ["fast-kill.sh"]="process-optimizer.sh"
    ["rename-for-speed.sh"]="user-profile-setup.sh"
    ["pre-shutdown.sh"]="service-cleanup.sh"
    ["honeypot-dashboard.sh"]="system-monitor.sh"

    # Directories → Innocent names
    ["/var/.cache/system"]="/var/cache/.thumbnails"
    ["/var/ghettoboot"]="/var/lib/systemd/.journal"
    ["/var/honeypot"]="/var/cache/fontconfig"
    [".system_logs"]="leads.csv"  # GENIUS - looks like data file!

    # Log files → Generic names
    ["honeypot-activity.log"]="sysstat.log"
    ["breach-events.log"]="kernel-events.log"
    ["honeypot-alerts.log"]="system-notices.log"
    ["wifi-honeypot.log"]="network-manager.log"
    ["fast-kill.log"]="process-reaper.log"
)

################################################################################
# Create Obfuscated Deployment
################################################################################

create_obfuscated_install() {
    local deploy_dir="./deploy-obfuscated"

    echo -e "${CYAN}Creating obfuscated deployment...${NC}"

    mkdir -p "$deploy_dir"

    # Copy ALL files first
    cp *.sh *.md "$deploy_dir/" 2>/dev/null || true

    # Obfuscate EVERYTHING in ALL files (not just script names)
    echo -e "${YELLOW}Obfuscating all strings in all files...${NC}"

    for file in "$deploy_dir"/*; do
        if [[ -f "$file" ]]; then
            # Replace ALL suspicious paths and strings
            sed -i "s|/var/\.cache/system|/var/cache/.thumbnails|g" "$file"
            sed -i "s|/var/ghettoboot|/var/lib/systemd/.journal|g" "$file"
            sed -i "s|/var/honeypot|/var/cache/fontconfig|g" "$file"
            sed -i "s|/var/log/honeypot|/var/log/cache|g" "$file"
            sed -i "s|\.system_logs|leads.csv|g" "$file"

            # Replace log file names
            sed -i "s|honeypot-activity\.log|sysstat.log|g" "$file"
            sed -i "s|honeypot-boot\.log|cache-init.log|g" "$file"
            sed -i "s|breach-events\.log|kernel-events.log|g" "$file"
            sed -i "s|honeypot-alerts\.log|system-notices.log|g" "$file"
            sed -i "s|wifi-honeypot\.log|network-manager.log|g" "$file"
            sed -i "s|honeypot-monitor\.log|cache-monitor.log|g" "$file"
            sed -i "s|honeypot-processes\.log|process-events.log|g" "$file"
            sed -i "s|fast-kill\.log|process-reaper.log|g" "$file"

            # Replace suspicious words (case-insensitive)
            sed -i "s/honeypot/cache/gI" "$file"
            sed -i "s/breach/event/gI" "$file"
            sed -i "s/kill-switch/recovery/gI" "$file"
            sed -i "s/killswitch/recovery/gI" "$file"
            sed -i "s/hidden volume/data store/gI" "$file"
            sed -i "s/hidden-volume/data-store/gI" "$file"
            sed -i "s/decoy/primary/g" "$file"
            sed -i "s/attacker/user/g" "$file"
            sed -i "s/attack/access/g" "$file"
            sed -i "s/HONEYPOT/CACHE/g" "$file"
            sed -i "s/HIDDEN/DATA/g" "$file"

            # Replace marker files
            sed -i "s|\.honeypot_active|\.cache_initialized|g" "$file"
            sed -i "s|\.kill_switch_activated|\.recovery_initiated|g" "$file"
            sed -i "s|\.secure_mode|\.data_mode|g" "$file"

            # Replace service names
            sed -i "s|ghettoboo-honeypot|system-cache-manager|g" "$file"
            sed -i "s|ghettoboot-breach|system-event-monitor|g" "$file"
            sed -i "s|ghettoboot-process|process-scheduler|g" "$file"
            sed -i "s|ghettoboot-auto-recovery|system-auto-recovery|g" "$file"
        fi
    done

    # Now rename the actual script files
    for original in "${!OBFUSCATED_NAMES[@]}"; do
        if [[ -f "$deploy_dir/$original" ]]; then
            local obf_name="${OBFUSCATED_NAMES[$original]}"
            mv "$deploy_dir/$original" "$deploy_dir/$obf_name" 2>/dev/null || true
            echo -e "${GREEN}✓${NC} $original → $obf_name"
        fi
    done

    # Remove any remaining non-obfuscated files
    rm -f "$deploy_dir/obfuscate-deployment.sh" 2>/dev/null || true

    # Create obfuscated installer
    cat > "$deploy_dir/install.sh" <<'EOFINSTALL'
#!/bin/bash
# System Maintenance Tools Installer
# Installs various system optimization and monitoring utilities

set -e

echo "Installing system maintenance utilities..."

INSTALL_DIR="/usr/local/sbin"

# Install scripts
for script in *.sh; do
    if [[ "$script" != "install.sh" ]]; then
        cp "$script" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/$script"
        echo "Installed: $script"
    fi
done

# Create aliases (obfuscated)
cat > /tmp/system-tools.sh <<'EOFBASH'
# System Tools Aliases
alias sc='sudo system-snapshot.sh check'      # System check
alias pk='sudo process-optimizer.sh ultra'    # Process kill
alias sw='sudo system-snapshot.sh watch'      # System watch
alias sm='sudo system-monitor.sh'             # System monitor

# Quick functions
ko() {
    sudo process-optimizer.sh kill-pattern "$1"
}

snap() {
    sudo system-snapshot.sh create
}
EOFBASH

echo ""
echo "Installation complete!"
echo ""
echo "Add to .bashrc:"
echo "  cat /tmp/system-tools.sh >> ~/.bashrc"
echo ""
echo "Quick commands:"
echo "  sc    - System check"
echo "  pk    - Kill unknowns"
echo "  sw    - Watch mode"
EOFINSTALL

    chmod +x "$deploy_dir/install.sh"

    echo ""
    echo -e "${GREEN}${BOLD}✓ Obfuscated deployment created: $deploy_dir/${NC}"
    echo ""
    echo -e "${YELLOW}What attacker sees:${NC}"
    echo "  system-cache-init.sh        (boring system file)"
    echo "  disk-maintenance.sh         (looks like cleanup)"
    echo "  cpu-scheduler.sh            (system optimization)"
    echo "  kernel-watchdog.sh          (standard monitoring)"
    echo "  leads.csv                   (data file - not volume!)"
    echo ""
    echo -e "${CYAN}To deploy:${NC}"
    echo "  cd $deploy_dir"
    echo "  sudo ./install.sh"
}

################################################################################
# Create Decoy Scripts (honeypot for the honeypot)
################################################################################

create_decoy_scripts() {
    local deploy_dir="./deploy-obfuscated"

    echo -e "${CYAN}Creating decoy scripts...${NC}"

    # Fake "honeypot" script that does nothing
    cat > "$deploy_dir/honeypot-trap.sh" <<'EOFDECOY'
#!/bin/bash
# Fake honeypot script - if attacker runs this, we know they found it
echo "Initializing honeypot system..."
sleep 2
echo "Honeypot active on port 8080"
echo "Logging to /var/log/honeypot.log"

# Actually, log that someone ran this
echo "[$(date)] DECOY SCRIPT EXECUTED - Attacker found fake honeypot!" >> /var/log/decoy-trap.log
EOFDECOY

    chmod +x "$deploy_dir/honeypot-trap.sh"

    # Fake "admin" credentials (decoy)
    cat > "$deploy_dir/.admin-backup" <<'EOFCREDS'
# BACKUP ADMIN CREDENTIALS
# DO NOT COMMIT TO GIT
admin_user=administrator
admin_pass=Backup_Pass_2024!
db_host=localhost
db_name=production_db
EOFCREDS

    echo -e "${GREEN}✓${NC} Created decoy scripts"
    echo -e "${YELLOW}  If attacker runs honeypot-trap.sh → we know they found it${NC}"
    echo -e "${YELLOW}  If they try .admin-backup creds → fake credentials${NC}"
}

################################################################################
# Obfuscate Command Names
################################################################################

create_obfuscated_aliases() {
    cat > /tmp/obfuscated-commands.sh <<'EOFALIAS'
# System Management Aliases (obfuscated)
# These look like normal system admin commands

# Baseline/Check
alias sc='sudo system-snapshot.sh check'           # System check
alias sr='sudo system-snapshot.sh create'          # System refresh
alias sw='sudo system-snapshot.sh watch'           # System watch

# Kill
alias pk='sudo process-optimizer.sh ultra'         # Process kill
alias ko='sudo process-optimizer.sh kill-pattern'  # Kill operator
alias kn='sudo process-optimizer.sh nuke'          # Kill nuclear

# Monitoring
alias sm='sudo system-monitor.sh'                  # System monitor
alias ss='sudo system-snapshot.sh status'          # System status

# Maintenance
alias mc='sudo disk-maintenance.sh status'         # Maintenance check
alias ms='sudo disk-maintenance.sh enter-secure'   # Maintenance secure

# Quick functions
ko() {
    # Kill operator - kill by pattern
    sudo process-optimizer.sh kill-pattern "$1"
}

whatsnew() {
    # What's new in system
    sudo system-snapshot.sh diff-procs
}

# Hidden volume access (obfuscated)
export SECURE_DATA="/var/cache/.thumbnails/leads.csv"
alias datacheck='sudo disk-maintenance.sh status'
alias datasync='sudo disk-maintenance.sh sync'

EOFALIAS

    echo -e "${GREEN}✓${NC} Created obfuscated command aliases"
    echo -e "${CYAN}Usage: cat /tmp/obfuscated-commands.sh >> ~/.bashrc${NC}"
}

################################################################################
# Encode Critical Strings
################################################################################

create_encoded_config() {
    cat > ./deploy-obfuscated/.config <<EOF
# System Configuration (Base64 encoded)
# Decode with: echo \$VAR | base64 -d

SECURE_BASE=$(echo "/var/cache/.thumbnails" | base64)
HIDDEN_VOL=$(echo "leads.csv" | base64)
BASELINE_DIR=$(echo "/var/lib/systemd/.journal" | base64)
JAIL_DIR=$(echo "/var/cache/fontconfig" | base64)
EOF

    echo -e "${GREEN}✓${NC} Created encoded configuration"
}

################################################################################
# Show What Attacker Will See
################################################################################

show_attacker_view() {
    echo ""
    echo -e "${RED}${BOLD}═══ ATTACKER'S VIEW ═══${NC}"
    echo ""
    echo -e "${YELLOW}If attacker compromises system and runs 'ls':${NC}"
    echo ""
    cat <<EOF
drwxr-xr-x  /var/cache/.thumbnails/         (System cache - boring)
-rw-r--r--  leads.csv                        (Data file - looks like data)
-rwxr-xr-x  system-cache-init.sh             (System startup script)
-rwxr-xr-x  disk-maintenance.sh              (Disk cleanup)
-rwxr-xr-x  cpu-scheduler.sh                 (CPU optimization)
-rwxr-xr-x  kernel-watchdog.sh               (Kernel monitoring)
-rwxr-xr-x  network-discovery.sh             (Network tools)
-rwxr-xr-x  system-snapshot.sh               (System backup)
-rwxr-xr-x  process-optimizer.sh             (Process management)
EOF
    echo ""
    echo -e "${GREEN}Looks like normal system maintenance tools! 👍${NC}"
    echo ""
    echo -e "${YELLOW}If attacker tries to find honeypot:${NC}"
    echo "  $ grep -r 'honeypot' /var/"
    echo "  → Nothing found (all obfuscated!)"
    echo ""
    echo -e "${YELLOW}If attacker looks for hidden volumes:${NC}"
    echo "  $ find / -name '*hidden*'"
    echo "  → Nothing found"
    echo ""
    echo -e "${YELLOW}What they see instead:${NC}"
    echo "  leads.csv  (looks like a boring CSV data file)"
    echo "  .thumbnails/ (looks like image cache)"
    echo ""
}

################################################################################
# Test Obfuscation
################################################################################

test_obfuscation() {
    echo -e "${CYAN}${BOLD}Testing obfuscation effectiveness...${NC}"
    echo ""

    local deploy_dir="./deploy-obfuscated"

    if [[ ! -d "$deploy_dir" ]]; then
        echo -e "${RED}Run 'deploy' first${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Searching for suspicious strings in obfuscated files...${NC}"
    echo ""

    # Test searches attacker would do
    local suspicious_terms=(
        "honeypot"
        "breach"
        "kill-switch"
        "hidden.*volume"
        "attacker"
        "decoy"
        "GhettoBoot"
    )

    local found=0

    for term in "${suspicious_terms[@]}"; do
        echo -n "  Testing: grep -r '$term' ... "
        local results=$(grep -ri "$term" "$deploy_dir" 2>/dev/null | wc -l)

        if [[ $results -eq 0 ]]; then
            echo -e "${GREEN}✓ Not found${NC}"
        else
            echo -e "${RED}✗ Found $results matches${NC}"
            ((found++))
        fi
    done

    echo ""
    if [[ $found -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ OBFUSCATION SUCCESSFUL${NC}"
        echo -e "${GREEN}Attacker will NOT find suspicious strings${NC}"
    else
        echo -e "${RED}${BOLD}⚠ OBFUSCATION INCOMPLETE${NC}"
        echo -e "${YELLOW}Some suspicious strings remain - review manually${NC}"
    fi

    echo ""
    echo -e "${CYAN}What obfuscated files contain:${NC}"
    echo "  'cache' instead of 'honeypot'"
    echo "  'event' instead of 'breach'"
    echo "  'recovery' instead of 'kill-switch'"
    echo "  'data store' instead of 'hidden volume'"
    echo "  'user' instead of 'attacker'"
    echo ""
    echo -e "${GREEN}Safe to deploy!${NC}"
}

################################################################################
# Main
################################################################################

show_help() {
    cat <<EOF
Obfuscate Deployment - Make everything look innocuous

Usage: $0 [COMMAND]

Commands:
    deploy              Create obfuscated deployment
    test                Test obfuscation (verify no suspicious strings)
    decoys              Add decoy scripts
    aliases             Create obfuscated command aliases
    show                Show what attacker will see
    all                 Do everything

    help                Show this help

Why Obfuscate?
    If attacker finds your scripts, they'll:
    - grep -r "honeypot" / (find everything!)
    - Understand your strategy
    - Run your tools against you
    - Find hidden volumes

Obfuscation Strategy:
    FILES:
      honeypot-boot.sh → system-cache-init.sh
      hidden-volume-manager → disk-maintenance.sh
      .system_logs → leads.csv (looks like data!)

    PATHS (in ALL files):
      /var/honeypot → /var/cache/fontconfig
      /var/.cache/system → /var/cache/.thumbnails

    STRINGS (in ALL files):
      "honeypot" → "cache"
      "breach" → "event"
      "kill-switch" → "recovery"
      "hidden volume" → "data store"
      "attacker" → "user"

    Result:
      grep -r "honeypot" / → Nothing found
      find / -name "*hidden*" → Nothing found
      Attacker sees: Boring system files
      Reality: Combat-ready cache system

EOF
}

main() {
    local command="${1:-help}"

    case "$command" in
        deploy|create)
            create_obfuscated_install
            ;;
        test|verify)
            test_obfuscation
            ;;
        decoys|trap)
            create_decoy_scripts
            ;;
        aliases|commands)
            create_obfuscated_aliases
            ;;
        config|encode)
            create_encoded_config
            ;;
        show|view)
            show_attacker_view
            ;;
        all)
            create_obfuscated_install
            create_decoy_scripts
            create_obfuscated_aliases
            create_encoded_config
            test_obfuscation
            show_attacker_view
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
