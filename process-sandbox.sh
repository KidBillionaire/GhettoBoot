#!/bin/bash

################################################################################
# GhettoBoot Process Sandbox
# Purpose: Intercept and sandbox suspicious processes into honeypot jail
#          Route SSH attacks and privilege escalation attempts to decoy
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
JAIL_DIR="/var/honeypot/jail"
HONEYPOT_LOG="/var/log/honeypot-activity.log"
PROCESS_LOG="/var/log/honeypot-processes.log"
ALERT_LOG="/var/log/honeypot-alerts.log"
SANDBOX_GROUP="honeypot"

################################################################################
# Logging Functions
################################################################################

log_event() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$HONEYPOT_LOG"
}

log_process() {
    local pid="$1"
    local user="$2"
    local command="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] PID:$pid USER:$user CMD:$command" >> "$PROCESS_LOG"
}

log_alert() {
    local alert_type="$1"
    local details="$2"
    local alert="[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $alert_type - $details"
    echo "$alert" >> "$ALERT_LOG"
    echo -e "${RED}[ALERT]${NC} $alert_type: $details"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_event "INFO" "$1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log_event "SUCCESS" "$1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log_event "WARNING" "$1"
}

################################################################################
# Jail Management
################################################################################

setup_jail_environment() {
    log_info "Setting up honeypot jail environment..."

    # Create jail directory structure
    mkdir -p "$JAIL_DIR"/{bin,lib,lib64,usr/{bin,lib,lib64},dev,etc,var,tmp,proc,home}

    # Copy essential binaries for realistic environment
    local bins=(
        bash sh ls cat echo pwd cd mkdir rm cp mv
        grep sed awk ps top kill id whoami
        uname hostname date touch chmod chown
        netstat ss wget curl ping ssh
    )

    for bin in "${bins[@]}"; do
        local bin_path=$(which "$bin" 2>/dev/null)
        if [[ -n "$bin_path" && -f "$bin_path" ]]; then
            cp "$bin_path" "$JAIL_DIR/bin/" 2>/dev/null || true

            # Copy library dependencies
            ldd "$bin_path" 2>/dev/null | grep -o '/[^ ]*' | while read -r lib; do
                if [[ -f "$lib" ]]; then
                    local lib_dir=$(dirname "$lib")
                    mkdir -p "$JAIL_DIR$lib_dir"
                    cp -n "$lib" "$JAIL_DIR$lib" 2>/dev/null || true
                fi
            done
        fi
    done

    # Create device nodes
    mknod -m 666 "$JAIL_DIR/dev/null" c 1 3 2>/dev/null || true
    mknod -m 666 "$JAIL_DIR/dev/zero" c 1 5 2>/dev/null || true
    mknod -m 444 "$JAIL_DIR/dev/random" c 1 8 2>/dev/null || true
    mknod -m 444 "$JAIL_DIR/dev/urandom" c 1 9 2>/dev/null || true
    mknod -m 666 "$JAIL_DIR/dev/tty" c 5 0 2>/dev/null || true

    # Create fake system files
    cat > "$JAIL_DIR/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
admin:x:1000:1000:Admin User:/home/admin:/bin/bash
EOF

    cat > "$JAIL_DIR/etc/shadow" <<'EOF'
root:!:19000:0:99999:7:::
daemon:*:19000:0:99999:7:::
www-data:*:19000:0:99999:7:::
nobody:*:19000:0:99999:7:::
admin:$6$fake$fakehashfakehashfakehashfakehashfakehashfakehash:19000:0:99999:7:::
EOF
    chmod 640 "$JAIL_DIR/etc/shadow"

    cat > "$JAIL_DIR/etc/group" <<'EOF'
root:x:0:
daemon:x:1:
www-data:x:33:
nogroup:x:65534:
admin:x:1000:
EOF

    # Create fake hostname
    echo "production-server-01" > "$JAIL_DIR/etc/hostname"

    # Create fake network info
    cat > "$JAIL_DIR/etc/hosts" <<'EOF'
127.0.0.1   localhost
127.0.1.1   production-server-01
::1         localhost ip6-localhost ip6-loopback
EOF

    # Create fake SSH config
    mkdir -p "$JAIL_DIR/etc/ssh"
    cat > "$JAIL_DIR/etc/ssh/sshd_config" <<'EOF'
Port 22
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
EOF

    # Create honeypot home directory
    mkdir -p "$JAIL_DIR/home/admin"/{.ssh,Documents,Downloads}

    # Create decoy files
    cat > "$JAIL_DIR/home/admin/.bash_history" <<'EOF'
ls -la
cd /var/www
cat config.php
sudo su
whoami
uname -a
ps aux
netstat -tulpn
EOF

    # Create fake credentials file (honeypot bait)
    cat > "$JAIL_DIR/home/admin/.credentials" <<'EOF'
# Database credentials
DB_HOST=localhost
DB_USER=admin
DB_PASS=Change_Me_123
DB_NAME=production_db

# API Keys (DO NOT SHARE)
API_KEY=fake_api_key_12345
SECRET_TOKEN=fake_secret_token_67890
EOF
    chmod 600 "$JAIL_DIR/home/admin/.credentials"

    # Create fake SSH keys (bait)
    mkdir -p "$JAIL_DIR/home/admin/.ssh"
    cat > "$JAIL_DIR/home/admin/.ssh/id_rsa" <<'EOF'
-----BEGIN RSA PRIVATE KEY-----
THIS IS A FAKE HONEYPOT SSH KEY
DO NOT USE IN REAL SYSTEMS
THIS KEY IS MONITORED
-----END RSA PRIVATE KEY-----
EOF
    chmod 600 "$JAIL_DIR/home/admin/.ssh/id_rsa"

    # Set permissions
    chown -R root:root "$JAIL_DIR"
    chmod 755 "$JAIL_DIR"
    chmod 1777 "$JAIL_DIR/tmp"

    log_success "Honeypot jail environment created"
}

################################################################################
# Process Interception
################################################################################

detect_suspicious_process() {
    local pid="$1"
    local cmdline=$(cat /proc/"$pid"/cmdline 2>/dev/null | tr '\0' ' ')

    # Suspicious patterns
    local suspicious_patterns=(
        "nc -l"                    # Netcat listener
        "bash -i"                  # Interactive bash
        "/dev/tcp/"                # Reverse shell
        "python.*pty"              # PTY spawn
        "perl.*socket"             # Perl socket
        "ruby.*socket"             # Ruby socket
        "php.*eval"                # PHP eval
        "wget.*chmod.*x"           # Download and execute
        "curl.*bash"               # Curl to bash
        "base64.*decode"           # Base64 obfuscation
        "nmap"                     # Port scanning
        "sqlmap"                   # SQL injection
        "metasploit"               # Exploitation framework
        "msfvenom"                 # Payload generation
    )

    for pattern in "${suspicious_patterns[@]}"; do
        if echo "$cmdline" | grep -qiE "$pattern"; then
            return 0  # Suspicious
        fi
    done

    return 1  # Not suspicious
}

monitor_processes() {
    log_info "Starting process monitoring..."

    while true; do
        # Monitor all processes
        for pid in /proc/[0-9]*; do
            pid=$(basename "$pid")

            # Skip kernel threads and our own process
            if [[ $pid -eq $$ ]] || [[ ! -f "/proc/$pid/cmdline" ]]; then
                continue
            fi

            # Get process info
            local cmdline=$(cat /proc/"$pid"/cmdline 2>/dev/null | tr '\0' ' ')
            local user=$(stat -c '%U' /proc/"$pid" 2>/dev/null)

            # Check if suspicious
            if detect_suspicious_process "$pid"; then
                log_alert "SUSPICIOUS_PROCESS" "PID:$pid USER:$user CMD:$cmdline"
                log_process "$pid" "$user" "$cmdline"

                # Option: Kill and restart in jail (advanced)
                # sandbox_process "$pid"
            fi
        done

        sleep 2
    done
}

sandbox_process() {
    local pid="$1"

    log_warning "Attempting to sandbox process $pid..."

    # Get process details
    local user=$(stat -c '%U' /proc/"$pid" 2>/dev/null)
    local cmdline=$(cat /proc/"$pid"/cmdline 2>/dev/null | tr '\0' ' ')

    log_alert "SANDBOXING" "Moving process $pid to jail: $cmdline"

    # Advanced: Use cgroups and namespaces to isolate
    # This is a simplified version - production would use containers

    # Create cgroup for process isolation
    local cgroup="/sys/fs/cgroup/honeypot/jail_$pid"
    if [[ -d /sys/fs/cgroup ]]; then
        mkdir -p "$cgroup"

        # Limit resources
        echo "$pid" > "$cgroup/cgroup.procs"
        echo "50M" > "$cgroup/memory.max" 2>/dev/null || true
        echo "10000" > "$cgroup/cpu.max" 2>/dev/null || true

        log_success "Process $pid isolated in cgroup"
    fi
}

################################################################################
# SSH Attack Detection
################################################################################

monitor_ssh_connections() {
    log_info "Monitoring SSH connections..."

    # Monitor SSH logs for attack patterns
    if [[ -f /var/log/auth.log ]]; then
        tail -f /var/log/auth.log | while read -r line; do
            # Failed login attempts
            if echo "$line" | grep -q "Failed password"; then
                local user=$(echo "$line" | grep -oP "for \K\w+")
                local ip=$(echo "$line" | grep -oP "from \K[\d\.]+")
                log_alert "SSH_BRUTE_FORCE" "Failed login for $user from $ip"
            fi

            # Successful logins from unknown IPs
            if echo "$line" | grep -q "Accepted password"; then
                local user=$(echo "$line" | grep -oP "for \K\w+")
                local ip=$(echo "$line" | grep -oP "from \K[\d\.]+")

                # Check if IP is in whitelist
                if ! grep -q "$ip" /etc/ssh/whitelist_ips 2>/dev/null; then
                    log_alert "SSH_UNAUTHORIZED" "Login accepted for $user from unknown IP $ip"
                fi
            fi

            # Command execution detection
            if echo "$line" | grep -qE "(sudo|su |pkexec)"; then
                log_alert "PRIVILEGE_ESCALATION" "$(echo "$line" | grep -oE "(sudo|su |pkexec).*")"
            fi
        done
    fi
}

################################################################################
# Network Attack Detection
################################################################################

monitor_network_activity() {
    log_info "Monitoring network activity..."

    while true; do
        # Check for unusual connections
        netstat -tnp 2>/dev/null | grep ESTABLISHED | while read -r line; do
            local remote_ip=$(echo "$line" | awk '{print $5}' | cut -d: -f1)
            local pid=$(echo "$line" | awk '{print $7}' | cut -d/ -f1)

            # Check if connection to known bad IPs (simplified)
            # In production, integrate with threat intelligence feeds

            # Log all external connections from jailed processes
            if [[ -n "$pid" ]] && ps -p "$pid" -o cgroup | grep -q "honeypot"; then
                log_alert "JAILED_NETWORK" "Jailed process $pid connected to $remote_ip"
            fi
        done

        sleep 5
    done
}

################################################################################
# Alert Dashboard
################################################################################

show_alerts() {
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}           HONEYPOT ALERTS - LAST 24 HOURS${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    if [[ -f "$ALERT_LOG" ]]; then
        # Show recent alerts
        tail -50 "$ALERT_LOG" | while read -r alert; do
            if echo "$alert" | grep -q "SUSPICIOUS_PROCESS"; then
                echo -e "${YELLOW}$alert${NC}"
            elif echo "$alert" | grep -q "SSH_"; then
                echo -e "${RED}$alert${NC}"
            else
                echo "$alert"
            fi
        done
    else
        echo "No alerts found"
    fi

    echo ""
    echo -e "${CYAN}═══ Alert Summary ═══${NC}"
    if [[ -f "$ALERT_LOG" ]]; then
        echo "Total alerts: $(wc -l < "$ALERT_LOG")"
        echo "SSH attacks: $(grep -c "SSH_" "$ALERT_LOG" 2>/dev/null || echo 0)"
        echo "Suspicious processes: $(grep -c "SUSPICIOUS_PROCESS" "$ALERT_LOG" 2>/dev/null || echo 0)"
        echo "Privilege escalation: $(grep -c "PRIVILEGE_ESCALATION" "$ALERT_LOG" 2>/dev/null || echo 0)"
    fi
    echo ""
}

################################################################################
# Main Commands
################################################################################

show_help() {
    cat <<EOF
Process Sandbox - Honeypot process interception and sandboxing

Usage: $0 [COMMAND]

Commands:
    setup               Setup honeypot jail environment
    monitor             Start monitoring processes (foreground)
    monitor-bg          Start monitoring in background
    monitor-ssh         Monitor SSH connections
    monitor-network     Monitor network activity
    alerts              Show recent honeypot alerts
    stop                Stop all monitoring

    help                Show this help message

Examples:
    $0 setup            # Initialize jail environment
    $0 monitor-bg       # Start background monitoring
    $0 alerts           # View recent alerts

EOF
}

main() {
    local command="${1:-help}"

    case "$command" in
        setup)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            setup_jail_environment
            ;;
        monitor)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            monitor_processes
            ;;
        monitor-bg)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            nohup "$0" monitor > /var/log/honeypot-monitor.log 2>&1 &
            log_success "Process monitoring started in background (PID: $!)"
            ;;
        monitor-ssh)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            monitor_ssh_connections
            ;;
        monitor-network)
            if [[ $EUID -ne 0 ]]; then
                echo "Must run as root"
                exit 1
            fi
            monitor_network_activity
            ;;
        alerts)
            show_alerts
            ;;
        stop)
            pkill -f "process-sandbox.sh monitor" || true
            log_success "Stopped honeypot monitoring"
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
