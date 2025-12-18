#!/bin/bash

################################################################################
# GhettoBoot Hidden Volume Manager
# Purpose: Manage hidden secure volumes and provide secure environment access
#          Switch between decoy and secure environments
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
SECURE_BASE_DIR="/var/.cache/system"
HIDDEN_VOLUME_NAME=".system_logs"
SECURE_MOUNT="$SECURE_BASE_DIR/secure"
HONEYPOT_MARKER="/tmp/.honeypot_active"
SECURE_MARKER="/tmp/.secure_mode"

################################################################################
# Utility Functions
################################################################################

log_secure() {
    echo -e "${CYAN}[SECURE]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════"
    echo "         HIDDEN VOLUME MANAGER"
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

################################################################################
# Volume Status Functions
################################################################################

get_environment_status() {
    echo -e "${MAGENTA}═══ Environment Status ═══${NC}"
    echo ""

    # Check if honeypot is active
    if [[ -f "$HONEYPOT_MARKER" ]]; then
        echo -e "${YELLOW}Mode:${NC} Honeypot Active (Decoy System)"
        echo -e "${YELLOW}Status:${NC} Attackers are being sandboxed"
        cat "$HONEYPOT_MARKER"
    elif [[ -f "$SECURE_MARKER" ]]; then
        echo -e "${GREEN}Mode:${NC} Secure Environment"
        echo -e "${GREEN}Status:${NC} Operating from hidden volumes"
        cat "$SECURE_MARKER"
    else
        echo -e "${BLUE}Mode:${NC} Normal (No honeypot active)"
    fi
    echo ""

    # Check mount status
    echo -e "${MAGENTA}═══ Volume Mounts ═══${NC}"
    if mount | grep -q "$SECURE_MOUNT"; then
        echo -e "${GREEN}✓${NC} Hidden volume mounted at: $SECURE_MOUNT"
        df -h "$SECURE_MOUNT" | tail -1
    else
        echo -e "${RED}✗${NC} Hidden volume not mounted"
    fi
    echo ""

    # List hidden volume contents
    if [[ -d "$SECURE_MOUNT" ]]; then
        echo -e "${MAGENTA}═══ Hidden Volume Contents ═══${NC}"
        du -sh "$SECURE_MOUNT"/* 2>/dev/null | head -10 || echo "Volume is empty"
    fi
    echo ""
}

list_hidden_volumes() {
    log_info "Scanning for hidden volumes..."
    echo ""

    local found=0

    # Check main hidden directory
    if [[ -d "$SECURE_BASE_DIR" ]]; then
        echo -e "${CYAN}Hidden base directory:${NC} $SECURE_BASE_DIR"
        find "$SECURE_BASE_DIR" -maxdepth 2 -type d -name ".*" 2>/dev/null | while read -r dir; do
            echo "  → $dir ($(du -sh "$dir" 2>/dev/null | cut -f1))"
            ((found++))
        done
    fi

    # Check for volume images
    echo ""
    echo -e "${CYAN}Volume images:${NC}"
    find "$SECURE_BASE_DIR" -name "*.img" 2>/dev/null | while read -r img; do
        local size=$(du -sh "$img" 2>/dev/null | cut -f1)
        echo "  → $img ($size)"
        ((found++))
    done

    if [[ $found -eq 0 ]]; then
        log_warning "No hidden volumes found"
    fi
}

################################################################################
# Volume Operations
################################################################################

mount_secure_volume() {
    log_info "Mounting secure hidden volume..."

    local image_path="$SECURE_BASE_DIR/$HIDDEN_VOLUME_NAME/secure.img"

    if [[ ! -f "$image_path" ]]; then
        log_error "Volume image not found: $image_path"
        log_info "Run honeypot-boot.sh first to create hidden volumes"
        exit 1
    fi

    # Create mount point
    mkdir -p "$SECURE_MOUNT"

    # Check if already mounted
    if mount | grep -q "$SECURE_MOUNT"; then
        log_warning "Volume already mounted"
        return 0
    fi

    # Mount
    if mount -o loop,noatime "$image_path" "$SECURE_MOUNT"; then
        log_success "Mounted hidden volume at $SECURE_MOUNT"
    else
        log_error "Failed to mount volume"
        exit 1
    fi
}

unmount_secure_volume() {
    log_info "Unmounting secure volume..."

    if ! mount | grep -q "$SECURE_MOUNT"; then
        log_warning "Volume not mounted"
        return 0
    fi

    if umount "$SECURE_MOUNT"; then
        log_success "Unmounted secure volume"
    else
        log_error "Failed to unmount volume"
        exit 1
    fi
}

################################################################################
# Environment Switching
################################################################################

enter_secure_mode() {
    log_secure "Entering secure mode..."

    # Mount secure volume if not mounted
    if ! mount | grep -q "$SECURE_MOUNT"; then
        mount_secure_volume
    fi

    # Create secure marker
    echo "SECURE_MODE_ACTIVE=$(date +%s)" > "$SECURE_MARKER"
    echo "USER=$(whoami)" >> "$SECURE_MARKER"
    echo "SESSION_ID=$$" >> "$SECURE_MARKER"

    # Change to secure environment
    cd "$SECURE_MOUNT"

    log_success "═══════════════════════════════════════════════════════════"
    log_success "Secure mode activated"
    log_success "═══════════════════════════════════════════════════════════"
    log_secure "Working directory: $SECURE_MOUNT"
    log_secure "All operations will use hidden volumes"
    log_secure "Decoy system remains active for attackers"
    echo ""
    log_warning "To exit secure mode: exit or run with --exit-secure"
}

exit_secure_mode() {
    log_info "Exiting secure mode..."

    if [[ -f "$SECURE_MARKER" ]]; then
        rm -f "$SECURE_MARKER"
        log_success "Secure mode deactivated"
    else
        log_warning "Not currently in secure mode"
    fi

    cd /
}

switch_to_decoy() {
    log_warning "Switching to decoy environment..."

    # Ensure honeypot marker exists
    if [[ ! -f "$HONEYPOT_MARKER" ]]; then
        echo "HONEYPOT_ACTIVE=$(date +%s)" > "$HONEYPOT_MARKER"
    fi

    # Remove secure marker
    rm -f "$SECURE_MARKER"

    log_success "Switched to decoy environment"
    log_warning "This environment may be compromised - use for honeypot only"
}

################################################################################
# Backup and Sync
################################################################################

sync_to_hidden() {
    local source="$1"
    local dest_subdir="${2:-.}"

    if [[ -z "$source" ]]; then
        log_error "Usage: $0 --sync-to-hidden <source> [destination_subdir]"
        exit 1
    fi

    log_info "Syncing $source to hidden volume..."

    if ! mount | grep -q "$SECURE_MOUNT"; then
        log_error "Hidden volume not mounted. Mount it first."
        exit 1
    fi

    local dest="$SECURE_MOUNT/$dest_subdir"
    mkdir -p "$dest"

    if rsync -av --progress "$source" "$dest/"; then
        log_success "Sync complete: $source → $dest"
    else
        log_error "Sync failed"
        exit 1
    fi
}

create_backup_snapshot() {
    log_info "Creating backup snapshot of hidden volume..."

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$SECURE_BASE_DIR/backups"
    local backup_file="$backup_dir/snapshot_$timestamp.tar.gz"

    mkdir -p "$backup_dir"

    if [[ -d "$SECURE_MOUNT" ]]; then
        tar czf "$backup_file" -C "$SECURE_MOUNT" . 2>/dev/null
        log_success "Snapshot created: $backup_file"
        log_info "Size: $(du -sh "$backup_file" | cut -f1)"
    else
        log_error "Secure mount not available"
        exit 1
    fi
}

################################################################################
# Security Operations
################################################################################

hide_volume_tracks() {
    log_secure "Hiding volume access tracks..."

    # Clear bash history of volume paths
    if [[ -f ~/.bash_history ]]; then
        sed -i.bak "/$(echo "$SECURE_BASE_DIR" | sed 's/\//\\\//g')/d" ~/.bash_history
        log_success "Cleared volume paths from bash history"
    fi

    # Clear recent file access
    if [[ -d ~/.local/share/recently-used.xbel ]]; then
        rm -f ~/.local/share/recently-used.xbel
        log_success "Cleared recent file access"
    fi

    # Clear command logs
    > /var/log/lastlog 2>/dev/null || true

    log_success "Access tracks hidden"
}

################################################################################
# Main Command Handler
################################################################################

show_help() {
    cat <<EOF
Hidden Volume Manager - Manage secure hidden volumes and environments

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    status              Show environment and volume status
    list                List all hidden volumes
    mount               Mount secure hidden volume
    unmount             Unmount secure volume

    enter-secure        Enter secure mode (operate from hidden volumes)
    exit-secure         Exit secure mode
    switch-decoy        Switch to decoy environment

    sync <source> [dest]    Sync files to hidden volume
    backup              Create snapshot backup of hidden volume
    hide-tracks         Remove access logs and history

    help                Show this help message

Examples:
    $0 status                       # Check current environment
    $0 enter-secure                 # Enter secure operating mode
    $0 sync /etc/important secure/  # Sync files to hidden volume
    $0 backup                       # Create backup snapshot

EOF
}

main() {
    local command="${1:-status}"

    print_banner

    case "$command" in
        status)
            get_environment_status
            ;;
        list)
            list_hidden_volumes
            ;;
        mount)
            check_root
            mount_secure_volume
            ;;
        unmount)
            check_root
            unmount_secure_volume
            ;;
        enter-secure)
            check_root
            enter_secure_mode
            exec bash
            ;;
        exit-secure)
            exit_secure_mode
            ;;
        switch-decoy)
            check_root
            switch_to_decoy
            ;;
        sync)
            check_root
            sync_to_hidden "$2" "$3"
            ;;
        backup)
            check_root
            create_backup_snapshot
            ;;
        hide-tracks)
            hide_volume_tracks
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
