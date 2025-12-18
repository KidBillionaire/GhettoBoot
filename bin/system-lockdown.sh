#!/bin/bash

################################################################################
# System Lockdown Script
# Purpose: Kill all non-essential processes, disable execution, and lock down
#          external device inputs (NFC/SmartCard)
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DATA_VOLUME="${DATA_VOLUME:-Macintosh HD - Data}"
DRY_RUN="${DRY_RUN:-false}"
KEEP_CRITICAL="${KEEP_CRITICAL:-true}"

# Critical processes to exclude (in addition to current shell and parents)
CRITICAL_PROCS=(
    "kernel_task"
    "launchd"
    "kextd"
    "syslogd"
    "configd"
    "notifyd"
    "securityd"
    "WindowServer"
)

################################################################################
# Helper Functions
################################################################################

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
    echo -e "${RED}"
    echo "═══════════════════════════════════════════════════════════"
    echo "           SYSTEM LOCKDOWN SCRIPT"
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    log_success "Running with root privileges"
}

get_current_shell_tree() {
    local current_pid=$$
    local pid_list=()

    # Get current PID and all parent PIDs
    pid_list+=($current_pid)

    while [[ $current_pid -gt 1 ]]; do
        current_pid=$(ps -o ppid= -p $current_pid | tr -d ' ')
        if [[ -n "$current_pid" && $current_pid -gt 1 ]]; then
            pid_list+=($current_pid)
        else
            break
        fi
    done

    echo "${pid_list[@]}"
}

is_critical_process() {
    local proc_name=$1
    for critical in "${CRITICAL_PROCS[@]}"; do
        if [[ "$proc_name" == *"$critical"* ]]; then
            return 0
        fi
    done
    return 1
}

################################################################################
# Main Functions
################################################################################

kill_all_processes() {
    log_info "Step 1: Killing all non-essential processes..."

    # Get PIDs to exclude (current shell tree)
    local exclude_pids=($(get_current_shell_tree))
    log_info "Excluding current shell tree: ${exclude_pids[*]}"

    # Build exclusion pattern
    local exclude_pattern=""
    for pid in "${exclude_pids[@]}"; do
        exclude_pattern="$exclude_pattern|^$pid "
    done
    exclude_pattern="${exclude_pattern:1}"  # Remove leading pipe

    # Get all PIDs except excluded ones
    local pids_to_kill=()
    while IFS= read -r line; do
        local pid=$(echo "$line" | awk '{print $2}')
        local cmd=$(echo "$line" | awk '{for(i=8;i<=NF;i++) printf $i" "; print ""}')

        # Skip if in exclusion list
        if echo "$line" | grep -Eq "$exclude_pattern"; then
            continue
        fi

        # Skip critical processes if enabled
        if [[ "$KEEP_CRITICAL" == "true" ]] && is_critical_process "$cmd"; then
            log_warning "Keeping critical process: $pid ($cmd)"
            continue
        fi

        pids_to_kill+=($pid)
    done < <(ps -ef | tail -n +2)

    # Kill processes
    local killed_count=0
    for pid in "${pids_to_kill[@]}"; do
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "Would kill PID: $pid"
        else
            if kill -9 "$pid" 2>/dev/null; then
                ((killed_count++))
            fi
        fi
    done

    log_success "Killed $killed_count processes"
}

remount_noexec() {
    log_info "Step 2: Remounting data volume with noexec flag..."

    local volume_path="/Volumes/$DATA_VOLUME"

    # Check if volume exists
    if [[ ! -d "$volume_path" ]]; then
        log_warning "Volume not found at: $volume_path"
        log_info "Available volumes:"
        ls -1 /Volumes/
        log_warning "Skipping remount step. Set DATA_VOLUME environment variable to specify correct volume."
        return 1
    fi

    # Check if volume is mounted
    if ! mount | grep -q "$volume_path"; then
        log_warning "Volume not currently mounted. Attempting to mount..."
        if [[ "$DRY_RUN" != "true" ]]; then
            diskutil mount "$DATA_VOLUME" || {
                log_error "Failed to mount volume"
                return 1
            }
        fi
    fi

    # Remount with noexec
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would remount: $volume_path with noexec"
    else
        if mount -u -o noexec "$volume_path" 2>/dev/null; then
            log_success "Remounted $volume_path with noexec"
        else
            log_warning "Failed to remount with noexec (may not be supported on this volume)"
        fi
    fi
}

disable_hid_services() {
    log_info "Step 3: Disabling NFC and SmartCard services..."

    local services=(
        "system/com.apple.ctkicdd"
        "system/com.apple.nfcd"
        "system/com.apple.cardd"
        "system/com.apple.PassKit"
    )

    for service in "${services[@]}"; do
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "Would disable: $service"
        else
            if launchctl disable "$service" 2>/dev/null; then
                log_success "Disabled: $service"
            else
                log_warning "Could not disable: $service (may not exist)"
            fi
        fi
    done
}

verify_lockdown() {
    log_info "Step 4: Verifying lockdown status..."
    echo ""

    # Count running processes
    local process_count=$(ps -ax | wc -l)
    log_info "Total running processes: $process_count"
    echo ""

    # Show running processes
    log_info "Running processes:"
    echo "───────────────────────────────────────────────────────────"
    ps -ax -o pid,user,command | head -20
    echo "───────────────────────────────────────────────────────────"
    echo ""

    # Check volume mount options
    if mount | grep "/Volumes/$DATA_VOLUME" | grep -q "noexec"; then
        log_success "Data volume is mounted with noexec"
    else
        log_warning "Data volume is NOT mounted with noexec"
    fi
    echo ""

    # Check disabled services
    log_info "Checking disabled services..."
    launchctl print-disabled system 2>/dev/null | grep -E "(nfcd|ctkicdd|cardd|PassKit)" || log_info "No HID services found in disabled list"
}

################################################################################
# Main Execution
################################################################################

main() {
    print_banner

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                log_warning "DRY RUN MODE - No changes will be made"
                shift
                ;;
            --volume)
                DATA_VOLUME="$2"
                shift 2
                ;;
            --allow-critical)
                KEEP_CRITICAL=true
                shift
                ;;
            --kill-all)
                KEEP_CRITICAL=false
                log_warning "Will attempt to kill ALL processes (dangerous!)"
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --dry-run           Show what would be done without making changes"
                echo "  --volume NAME       Specify data volume name (default: 'Macintosh HD - Data')"
                echo "  --allow-critical    Keep critical system processes (default)"
                echo "  --kill-all          Attempt to kill ALL processes (dangerous!)"
                echo "  --help              Show this help message"
                echo ""
                echo "Environment Variables:"
                echo "  DATA_VOLUME         Data volume name"
                echo "  DRY_RUN             Set to 'true' for dry run"
                echo "  KEEP_CRITICAL       Set to 'false' to kill critical processes"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Check root privileges
    check_root

    echo ""
    log_warning "This script will:"
    echo "  1. Kill all non-essential processes"
    echo "  2. Remount data volume with noexec"
    echo "  3. Disable NFC/SmartCard services"
    echo "  4. Lock down the system"
    echo ""

    if [[ "$DRY_RUN" != "true" ]]; then
        read -p "Continue? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_info "Aborted by user"
            exit 0
        fi
    fi

    echo ""

    # Execute lockdown steps
    kill_all_processes
    echo ""

    remount_noexec
    echo ""

    disable_hid_services
    echo ""

    verify_lockdown

    echo ""
    log_success "System lockdown complete!"
    echo ""
    log_warning "Note: Reboot will restore normal operation"
    log_info "To make changes permanent, modify startup items and system settings"
}

# Run main function
main "$@"
