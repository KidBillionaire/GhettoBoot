#!/bin/bash

################################################################################
# GhettoBoot Honeypot - Boot-Time Volume Duplication
# Purpose: Create hidden duplicate volumes on boot for secure operations
#          while leaving decoy system exposed to attackers
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
SECURE_BASE_DIR="${SECURE_BASE_DIR:-/var/.cache/system}"
HIDDEN_VOLUME_NAME="${HIDDEN_VOLUME_NAME:-.system_logs}"
DECOY_MARKER="/tmp/.honeypot_active"
LOG_FILE="/var/log/honeypot-boot.log"

################################################################################
# Logging Functions
################################################################################

log_secure() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo -e "${CYAN}[SECURE]${NC} $1"
}

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE"
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" >> "$LOG_FILE"
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" >> "$LOG_FILE"
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_FILE"
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════"
    echo "        HONEYPOT BOOT - HIDDEN VOLUME SYSTEM"
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

################################################################################
# Security Checks
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    log_success "Running with root privileges"
}

################################################################################
# Hidden Volume Management
################################################################################

create_hidden_directories() {
    log_info "Creating hidden directory structure..."

    # Create innocuous-looking base directories
    local hidden_paths=(
        "$SECURE_BASE_DIR"
        "/usr/local/share/.fonts"
        "/opt/.config"
        "/var/cache/.thumbnails"
    )

    for path in "${hidden_paths[@]}"; do
        if [[ ! -d "$path" ]]; then
            mkdir -p "$path"
            chmod 700 "$path"
            log_success "Created hidden path: $path"
        fi
    done

    # Create the main hidden volume directory
    local hidden_vol="$SECURE_BASE_DIR/$HIDDEN_VOLUME_NAME"
    if [[ ! -d "$hidden_vol" ]]; then
        mkdir -p "$hidden_vol"
        chmod 700 "$hidden_vol"
        log_success "Created hidden volume: $hidden_vol"
    fi

    echo "$hidden_vol"
}

duplicate_system_volume() {
    local source_path="$1"
    local dest_path="$2"

    log_info "Duplicating system volume from $source_path to $dest_path"

    # Create volume snapshot/duplicate
    if [[ -d "$source_path" ]]; then
        # Use rsync for efficient duplication with exclusions
        rsync -aAX \
            --exclude='/dev/*' \
            --exclude='/proc/*' \
            --exclude='/sys/*' \
            --exclude='/tmp/*' \
            --exclude='/run/*' \
            --exclude='/mnt/*' \
            --exclude='/media/*' \
            --exclude='/lost+found' \
            "$source_path/" "$dest_path/" 2>/dev/null || {
            log_warning "Partial duplication (some files may be inaccessible)"
        }

        log_success "Volume duplication complete"
    else
        log_error "Source path not found: $source_path"
        return 1
    fi
}

create_volume_image() {
    local hidden_vol="$1"
    local image_size="${2:-4G}"

    log_info "Creating encrypted volume image..."

    local image_path="$hidden_vol/secure.img"

    # Create sparse file
    if [[ ! -f "$image_path" ]]; then
        dd if=/dev/zero of="$image_path" bs=1M count=0 seek=4096 2>/dev/null
        log_success "Created volume image: $image_path"

        # Format as ext4
        mkfs.ext4 -F "$image_path" >/dev/null 2>&1
        log_success "Formatted volume image"
    fi

    echo "$image_path"
}

mount_hidden_volume() {
    local image_path="$1"
    local mount_point="$2"

    log_info "Mounting hidden volume..."

    if [[ ! -d "$mount_point" ]]; then
        mkdir -p "$mount_point"
    fi

    # Check if already mounted
    if mount | grep -q "$mount_point"; then
        log_warning "Volume already mounted at $mount_point"
        return 0
    fi

    # Mount the volume
    mount -o loop,noatime "$image_path" "$mount_point" 2>/dev/null || {
        log_error "Failed to mount hidden volume"
        return 1
    }

    chmod 700 "$mount_point"
    log_success "Hidden volume mounted at $mount_point"
}

################################################################################
# Honeypot Setup
################################################################################

setup_honeypot_markers() {
    log_info "Setting up honeypot markers..."

    # Create decoy marker
    echo "HONEYPOT_ACTIVE=$(date +%s)" > "$DECOY_MARKER"
    chmod 600 "$DECOY_MARKER"

    # Create decoy SSH banner
    cat > /etc/ssh/sshd_banner_honeypot <<'EOF'
################################################################################
#                   AUTHORIZED ACCESS ONLY                                     #
#         This system is monitored. Unauthorized access is prohibited.         #
################################################################################
EOF

    log_success "Honeypot markers created"
}

configure_ssh_honeypot() {
    log_info "Configuring SSH honeypot routing..."

    # Backup original sshd_config
    if [[ -f /etc/ssh/sshd_config && ! -f /etc/ssh/sshd_config.pre_honeypot ]]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.pre_honeypot
        log_success "Backed up SSH configuration"
    fi

    # Create honeypot SSH configuration
    cat > /etc/ssh/sshd_config.d/99-honeypot.conf <<'EOF'
# Honeypot SSH Configuration
# Route suspicious connections to restricted environment

# Enable chroot jail for specific users
Match Group honeypot
    ChrootDirectory /var/honeypot/jail
    ForceCommand /bin/bash --noprofile --norc
    PermitTTY yes
    X11Forwarding no
    AllowTcpForwarding no

# Log all commands
Match All
    AcceptEnv LANG LC_*
EOF

    log_success "SSH honeypot configuration created"
}

create_chroot_jail() {
    local jail_dir="/var/honeypot/jail"

    log_info "Creating chroot jail for honeypot..."

    if [[ ! -d "$jail_dir" ]]; then
        mkdir -p "$jail_dir"/{bin,lib,lib64,usr,dev,etc,var,tmp,proc}

        # Copy essential binaries
        local bins=(bash ls cat echo ps grep netstat id)
        for bin in "${bins[@]}"; do
            local bin_path=$(which "$bin" 2>/dev/null)
            if [[ -n "$bin_path" ]]; then
                cp "$bin_path" "$jail_dir/bin/"

                # Copy library dependencies
                ldd "$bin_path" 2>/dev/null | grep -o '/[^ ]*' | while read -r lib; do
                    if [[ -f "$lib" ]]; then
                        mkdir -p "$jail_dir$(dirname "$lib")"
                        cp "$lib" "$jail_dir$lib" 2>/dev/null || true
                    fi
                done
            fi
        done

        # Setup device nodes
        mknod -m 666 "$jail_dir/dev/null" c 1 3 2>/dev/null || true
        mknod -m 666 "$jail_dir/dev/zero" c 1 5 2>/dev/null || true
        mknod -m 666 "$jail_dir/dev/random" c 1 8 2>/dev/null || true

        # Create fake /etc/passwd
        cat > "$jail_dir/etc/passwd" <<'EOFPASSWD'
root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:nobody:/nonexistent:/bin/false
EOFPASSWD

        chmod -R 755 "$jail_dir"
        log_success "Chroot jail created at $jail_dir"
    else
        log_warning "Chroot jail already exists"
    fi
}

################################################################################
# Process Monitoring Setup
################################################################################

setup_process_monitor() {
    log_info "Setting up process monitoring..."

    cat > /usr/local/bin/honeypot-monitor.sh <<'EOF'
#!/bin/bash
# Monitor processes and route suspicious ones to honeypot

HONEYPOT_LOG="/var/log/honeypot-activity.log"

log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$HONEYPOT_LOG"
}

# Monitor for suspicious process patterns
while true; do
    # Check for unusual SSH connections
    ss -tnp | grep :22 | while read -r line; do
        if echo "$line" | grep -v "127.0.0.1" >/dev/null; then
            log_event "SSH connection detected: $line"
        fi
    done

    # Check for privilege escalation attempts
    ps aux | grep -E "(sudo|su |pkexec)" | grep -v grep | while read -r proc; do
        log_event "Privilege escalation attempt: $proc"
    done

    sleep 5
done
EOF

    chmod +x /usr/local/bin/honeypot-monitor.sh
    log_success "Process monitor script created"
}

################################################################################
# Main Execution
################################################################################

main() {
    print_banner
    check_root

    log_info "Initializing honeypot boot sequence..."

    # Create hidden directory structure
    local hidden_vol=$(create_hidden_directories)

    # Create encrypted volume image
    local image_path=$(create_volume_image "$hidden_vol")

    # Mount hidden volume
    local secure_mount="$SECURE_BASE_DIR/secure"
    mount_hidden_volume "$image_path" "$secure_mount"

    # Setup honeypot markers
    setup_honeypot_markers

    # Configure SSH honeypot
    configure_ssh_honeypot

    # Create chroot jail
    create_chroot_jail

    # Setup process monitoring
    setup_process_monitor

    log_success "═══════════════════════════════════════════════════════════"
    log_success "Honeypot boot sequence complete!"
    log_success "═══════════════════════════════════════════════════════════"
    log_secure "Hidden volumes: $secure_mount"
    log_secure "Decoy system active - attackers will be sandboxed"
    log_secure "Monitor honeypot activity: tail -f /var/log/honeypot-activity.log"
}

# Execute
main "$@"
