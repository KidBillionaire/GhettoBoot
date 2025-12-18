#!/bin/bash

################################################################################
# GhettoBoot Honeypot System Installer
# Purpose: Install and configure complete honeypot system with auto-restart
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="/usr/local/sbin"
SYSTEMD_DIR="/etc/systemd/system"

################################################################################
# Banner
################################################################################

print_banner() {
    echo -e "${CYAN}${BOLD}"
    cat <<'EOF'
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║           GHETTOBOOT HONEYPOT SYSTEM INSTALLER             ║
║                                                            ║
║  Automated honeypot with hidden volumes & auto-restart     ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

################################################################################
# Pre-installation Checks
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This installer must be run as root"
        exit 1
    fi
    log_success "Root privileges confirmed"
}

check_dependencies() {
    log_info "Checking dependencies..."

    local missing_deps=()

    # Required commands
    local required_cmds=(rsync mount umount systemctl mkfs.ext4 chroot)

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install them with: apt-get install rsync mount util-linux systemd e2fsprogs"
        exit 1
    fi

    log_success "All dependencies satisfied"
}

################################################################################
# Installation Steps
################################################################################

install_scripts() {
    log_info "Installing honeypot scripts to $INSTALL_DIR..."

    # Copy all honeypot scripts
    local scripts=(
        honeypot-boot.sh
        hidden-volume-manager.sh
        process-sandbox.sh
        breach-kill-switch.sh
        system-lockdown.sh
    )

    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            cp "$script" "$INSTALL_DIR/"
            chmod +x "$INSTALL_DIR/$script"
            log_success "Installed: $script"
        elif [[ -f "./$script" ]]; then
            cp "./$script" "$INSTALL_DIR/"
            chmod +x "$INSTALL_DIR/$script"
            log_success "Installed: $script"
        else
            log_warning "Script not found: $script (skipping)"
        fi
    done
}

create_systemd_services() {
    log_info "Creating systemd services..."

    # 1. Honeypot Boot Service (runs on startup)
    cat > "$SYSTEMD_DIR/ghettoboo-honeypot-boot.service" <<EOF
[Unit]
Description=GhettoBoot Honeypot Boot Service
Documentation=https://github.com/KidBillionaire/GhettoBoot
After=network.target local-fs.target
Before=sshd.service
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/honeypot-boot.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    log_success "Created: ghettoboo-honeypot-boot.service"

    # 2. Breach Monitor Service (continuous monitoring)
    cat > "$SYSTEMD_DIR/ghettoboot-breach-monitor.service" <<EOF
[Unit]
Description=GhettoBoot Breach Detection Monitor
Documentation=https://github.com/KidBillionaire/GhettoBoot
After=ghettoboo-honeypot-boot.service
Requires=ghettoboo-honeypot-boot.service

[Service]
Type=simple
ExecStart=$INSTALL_DIR/breach-kill-switch.sh monitor
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    log_success "Created: ghettoboot-breach-monitor.service"

    # 3. Process Sandbox Monitor Service
    cat > "$SYSTEMD_DIR/ghettoboot-process-monitor.service" <<EOF
[Unit]
Description=GhettoBoot Process Sandbox Monitor
Documentation=https://github.com/KidBillionaire/GhettoBoot
After=ghettoboo-honeypot-boot.service
Requires=ghettoboo-honeypot-boot.service

[Service]
Type=simple
ExecStart=$INSTALL_DIR/process-sandbox.sh monitor
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    log_success "Created: ghettoboot-process-monitor.service"

    # 4. Auto-Recovery Service (runs after crash/reboot)
    cat > "$SYSTEMD_DIR/ghettoboot-auto-recovery.service" <<EOF
[Unit]
Description=GhettoBoot Auto-Recovery Service
Documentation=https://github.com/KidBillionaire/GhettoBoot
DefaultDependencies=no
Before=sysinit.target shutdown.target
Conflicts=shutdown.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'if [ -f /tmp/.kill_switch_activated ]; then $INSTALL_DIR/honeypot-boot.sh; fi'
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOF
    log_success "Created: ghettoboot-auto-recovery.service"
}

configure_auto_restart() {
    log_info "Configuring automatic restart on breach..."

    # Configure kernel to reboot on panic
    if ! grep -q "kernel.panic" /etc/sysctl.conf; then
        echo "kernel.panic = 10" >> /etc/sysctl.conf
        echo "kernel.panic_on_oops = 1" >> /etc/sysctl.conf
        sysctl -p >/dev/null 2>&1
        log_success "Configured kernel auto-reboot"
    fi

    # Create reboot configuration
    mkdir -p /etc/ghettoboot
    cat > /etc/ghettoboot/restart.conf <<EOF
# GhettoBoot Auto-Restart Configuration
# These settings ensure honeypot restarts after breach

AUTO_RESTART_ENABLED=true
RESTART_DELAY_SECONDS=10
PRESERVE_EVIDENCE=true
ALERT_ON_RESTART=true
EOF
    log_success "Created restart configuration"
}

setup_log_rotation() {
    log_info "Setting up log rotation..."

    cat > /etc/logrotate.d/ghettoboot <<EOF
/var/log/honeypot*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}

/var/log/breach*.log {
    daily
    rotate 90
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}
EOF
    log_success "Configured log rotation"
}

create_backup_configs() {
    log_info "Creating backup of critical system files..."

    local backup_files=(
        /etc/passwd
        /etc/shadow
        /etc/group
        /etc/sudoers
        /etc/ssh/sshd_config
    )

    for file in "${backup_files[@]}"; do
        if [[ -f "$file" && ! -f "${file}.original" ]]; then
            cp "$file" "${file}.original"
            log_success "Backed up: $file"
        fi
    done
}

################################################################################
# Enable Services
################################################################################

enable_services() {
    log_info "Enabling systemd services..."

    local services=(
        ghettoboo-honeypot-boot.service
        ghettoboot-breach-monitor.service
        ghettoboot-process-monitor.service
        ghettoboot-auto-recovery.service
    )

    systemctl daemon-reload

    for service in "${services[@]}"; do
        if systemctl enable "$service" 2>/dev/null; then
            log_success "Enabled: $service"
        else
            log_warning "Could not enable: $service"
        fi
    done
}

################################################################################
# Post-Installation
################################################################################

create_management_commands() {
    log_info "Creating management commands..."

    # Create honeypot management command
    cat > /usr/local/bin/honeypot <<EOF
#!/bin/bash
# GhettoBoot Honeypot Management Command

case "\$1" in
    status)
        echo "=== Honeypot System Status ==="
        systemctl status ghettoboo-honeypot-boot.service --no-pager
        echo ""
        $INSTALL_DIR/hidden-volume-manager.sh status
        ;;
    start)
        systemctl start ghettoboo-honeypot-boot.service
        systemctl start ghettoboot-breach-monitor.service
        systemctl start ghettoboot-process-monitor.service
        echo "Honeypot services started"
        ;;
    stop)
        systemctl stop ghettoboot-breach-monitor.service
        systemctl stop ghettoboot-process-monitor.service
        echo "Honeypot monitoring stopped"
        ;;
    restart)
        systemctl restart ghettoboo-honeypot-boot.service
        systemctl restart ghettoboot-breach-monitor.service
        systemctl restart ghettoboot-process-monitor.service
        echo "Honeypot services restarted"
        ;;
    logs)
        tail -f /var/log/honeypot*.log /var/log/breach*.log
        ;;
    alerts)
        $INSTALL_DIR/breach-kill-switch.sh status
        ;;
    secure)
        $INSTALL_DIR/hidden-volume-manager.sh enter-secure
        ;;
    *)
        echo "Usage: honeypot {status|start|stop|restart|logs|alerts|secure}"
        echo ""
        echo "Commands:"
        echo "  status    - Show honeypot system status"
        echo "  start     - Start honeypot services"
        echo "  stop      - Stop honeypot monitoring"
        echo "  restart   - Restart all services"
        echo "  logs      - Tail honeypot logs"
        echo "  alerts    - Show breach alerts"
        echo "  secure    - Enter secure mode"
        ;;
esac
EOF
    chmod +x /usr/local/bin/honeypot
    log_success "Created: 'honeypot' management command"
}

show_installation_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}           INSTALLATION COMPLETE!${NC}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Installed Components:${NC}"
    echo "  ✓ Honeypot boot system"
    echo "  ✓ Hidden volume manager"
    echo "  ✓ Process sandbox/jail"
    echo "  ✓ Breach detection & kill switch"
    echo "  ✓ Auto-restart configuration"
    echo "  ✓ Systemd services"
    echo ""
    echo -e "${CYAN}Services Enabled:${NC}"
    echo "  ✓ ghettoboo-honeypot-boot.service    - Runs on every boot"
    echo "  ✓ ghettoboot-breach-monitor.service  - Continuous breach detection"
    echo "  ✓ ghettoboot-process-monitor.service - Process sandboxing"
    echo "  ✓ ghettoboot-auto-recovery.service   - Auto-recovery after breach"
    echo ""
    echo -e "${CYAN}Management Commands:${NC}"
    echo "  $ honeypot status        - Show system status"
    echo "  $ honeypot start         - Start services"
    echo "  $ honeypot logs          - View logs"
    echo "  $ honeypot alerts        - Check breach alerts"
    echo "  $ honeypot secure        - Enter secure mode"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Review configuration in /etc/ghettoboot/"
    echo "  2. Start honeypot: systemctl start ghettoboo-honeypot-boot"
    echo "  3. Monitor logs: journalctl -fu ghettoboot-breach-monitor"
    echo "  4. Test breach detection: $INSTALL_DIR/breach-kill-switch.sh scan"
    echo ""
    echo -e "${RED}${BOLD}IMPORTANT:${NC}"
    echo "  - System will AUTO-REBOOT if breach detected"
    echo "  - Hidden volumes will be created in /var/.cache/system/"
    echo "  - Attackers will be sandboxed in /var/honeypot/jail/"
    echo "  - All activity is logged to /var/log/honeypot-*.log"
    echo ""
}

################################################################################
# Main Installation
################################################################################

main() {
    print_banner

    log_info "Starting GhettoBoot Honeypot installation..."
    echo ""

    # Pre-installation
    check_root
    check_dependencies
    echo ""

    # Installation
    install_scripts
    create_systemd_services
    configure_auto_restart
    setup_log_rotation
    create_backup_configs
    enable_services
    create_management_commands
    echo ""

    # Post-installation
    show_installation_summary
}

main "$@"
