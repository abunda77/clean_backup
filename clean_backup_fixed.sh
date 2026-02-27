#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -eo pipefail

# --- Configuration ---
BACKUP_DIR="/home/clp/backups"
LOG_FILE="${LOG_FILE:-/home/alwyzon/clean_backup.log}"
CLEAN_BACKUP_STATS_FILE="$(mktemp -t clean_backup_stats.XXXXXX 2>/dev/null || printf '/tmp/clean_backup_stats.%s' "$$")"

trap 'rm -f "$CLEAN_BACKUP_STATS_FILE"' EXIT

# Enhanced logging function with multiple fallback mechanisms
write_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] $message"
    
    # Priority 1: Write to syslog (most reliable in cron)
    if logger -t clean_backup "$message" 2>/dev/null; then
        return 0
    fi
    
    # Priority 2: Write directly to log file
    if echo "$log_entry" >> "$LOG_FILE" 2>/dev/null; then
        return 0
    fi
    
    # Priority 3: Try with sudo
    if echo "$log_entry" | sudo tee -a "$LOG_FILE" > /dev/null 2>&1; then
        return 0
    fi
    
    # Priority 4: Create log file first with sudo
    if sudo touch "$LOG_FILE" 2>/dev/null && sudo chmod 664 "$LOG_FILE" 2>/dev/null; then
        if echo "$log_entry" | sudo tee -a "$LOG_FILE" > /dev/null 2>&1; then
            return 0
        fi
    fi
    
    # Priority 5: Fallback to /tmp
    local fallback_log="/tmp/clean_backup_fallback.log"
    if echo "$log_entry" >> "$fallback_log" 2>/dev/null; then
        return 0
    fi
    
    # Priority 6: Last resort - write to stderr
    echo "$log_entry" >&2
    return 1
}

# Ensure script runs with correct environment setup
setup_environment() {
    # Ensure full PATH for cron compatibility
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    
    # Ensure HOME is defined
    if [ -z "$HOME" ]; then
        export HOME="/home/alwyzon"
    fi
    
    # Log environment info
    write_log "Script started - User: $(whoami), UID: $(id -u), HOME: $HOME"
    write_log "PATH: $PATH"
    write_log "LOG_FILE: $LOG_FILE"
    write_log "BACKUP_DIR: $BACKUP_DIR"
}

# Initialize log file with enhanced error handling
init_log_file() {
    # Always try to write to syslog as indicator that script started
    logger -t clean_backup "Script initialization started" 2>/dev/null || true
    
    if [ ! -f "$LOG_FILE" ]; then
        # Try creating log file without sudo first
        if ! touch "$LOG_FILE" 2>/dev/null; then
            # If failed, try with sudo
            if ! sudo touch "$LOG_FILE" 2>/dev/null; then
                # If still failed, use fallback location
                LOG_FILE="/tmp/clean_backup.log"
                touch "$LOG_FILE" 2>/dev/null || {
                    write_log "Failed to create any log file, using syslog only"
                }
            fi
        fi
        
        # Set permissions if file was created successfully
        if [ -f "$LOG_FILE" ]; then
            chmod 664 "$LOG_FILE" 2>/dev/null || sudo chmod 664 "$LOG_FILE" 2>/dev/null || true
        fi
    fi
    
    write_log "Log file initialized: $LOG_FILE"
}

# ===================================================================================
# COLOR DEFINITIONS AND TERMINAL ANIMATIONS FOR DARK THEME
# ===================================================================================

# Color definitions optimized for dark terminal backgrounds
RED='\033[1;31m'          # Bright Red
GREEN='\033[1;32m'        # Bright Green
YELLOW='\033[1;33m'       # Bright Yellow
BLUE='\033[1;34m'         # Bright Blue
MAGENTA='\033[1;35m'      # Bright Magenta
CYAN='\033[1;36m'         # Bright Cyan
WHITE='\033[1;37m'        # Bright White
GRAY='\033[0;90m'         # Dark Gray
BOLD='\033[1m'            # Bold text
NC='\033[0m'              # No Color (reset)

# Unicode symbols for enhanced visual feedback
CHECKMARK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${CYAN}➤${NC}"
STAR="${YELLOW}★${NC}"
GEAR="${BLUE}⚙${NC}"
ROCKET="${MAGENTA}🚀${NC}"

# Check if script is running in an interactive terminal or via cron
is_interactive() {
    [ -t 0 ] && [ -t 1 ]
}

# Display spinner animation (interactive mode only)
spinner() {
    # Skip spinner in non-interactive mode (cron)
    if ! is_interactive; then
        return 0
    fi
    
    local pid=$1
    local delay=0.08
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while ps -p $pid > /dev/null; do
        printf "\r${CYAN}%s${NC} " "${spinstr:$i:1}"
        i=$(( (i+1) % ${#spinstr} ))
        sleep $delay
    done
    printf "\r   \r" # Clear spinner
}

format_bytes() {
    local bytes=${1:-0}
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec --suffix=B "$bytes"
    else
        echo "${bytes} B"
    fi
}

# Display progress bar with percentage (interactive mode only)
show_progress_bar() {
    # Skip progress bar in non-interactive mode (cron)
    if ! is_interactive; then
        write_log "Progress: $2"
        return 0
    fi
    
    local duration=$1
    local msg=$2
    local width=40
    
    echo -e "${CYAN}${msg}${NC}"
    for ((i=0; i<=duration; i++)); do
        local progress=$((i * width / duration))
        local bar=$(printf "%*s" $progress | tr ' ' '█')
        local spaces=$(printf "%*s" $((width - progress)))
        local percent=$((i * 100 / duration))
        
        printf "\r${GREEN}${bar}${GRAY}${spaces}${NC} ${YELLOW}${percent}%%${NC}"
        sleep 0.1
    done
    printf "\n"
}

# Display message with typing effect (interactive mode only)
type_message() {
    # Skip typing effect in non-interactive mode (cron)
    if ! is_interactive; then
        echo "$1"
        return 0
    fi
    
    local message=$1
    local delay=${2:-0.03}
    
    for ((i=0; i<${#message}; i++)); do
        printf "%s" "${message:$i:1}"
        sleep $delay
    done
    printf "\n"
}

# Wrapper function to execute tasks with visual feedback
do_task() {
    local description="$1"
    local command="$2"
    local exit_code=0

    # Log task start
    write_log "Starting task: $description"

    # Non-interactive mode: execute directly without spinner
    if ! is_interactive; then
        if eval "$command"; then
            write_log "Task completed successfully: $description"
            return 0
        else
            exit_code=$?
            write_log "Task failed: $description (exit code: $exit_code)"
            return $exit_code
        fi
    fi

    # Interactive mode: display spinner
    printf "${ARROW} %-60s" "$description"

    # Run command in background, suppress output to avoid interfering with spinner
    eval "$command" &> /dev/null &
    
    # Run spinner while command executes in background
    spinner $!

    # Wait for command completion and capture exit status
    wait $! || exit_code=$?

    # Print status based on exit code with visual indicators
    if [ $exit_code -eq 0 ]; then
        echo -e "[${GREEN}${BOLD} ✓ DONE ${NC}]"
        write_log "Task completed successfully: $description"
    else
        echo -e "[${RED}${BOLD} ✗ FAILED ${NC}]"
        write_log "Task failed: $description (exit code: $exit_code)"
        return $exit_code
    fi
}

# Specialized cleanup functions for complex operations
clean_netdata() {
    if systemctl is-active --quiet netdata; then
        sudo systemctl stop netdata
        sudo rm -rf /var/cache/netdata/*
        sudo systemctl start netdata
        write_log "Netdata cache cleaned successfully"
    else
        write_log "Netdata is not running, skipping cache cleanup"
    fi
}

clean_backups() {
    local stats_file="$CLEAN_BACKUP_STATS_FILE"

    if [ ! -d "$BACKUP_DIR" ]; then
        {
            echo "status=missing"
        } > "$stats_file"
        write_log "Backup directory not found: $BACKUP_DIR"
        return 0
    fi
    
    cd "$BACKUP_DIR" || return 1
    
    local before_bytes=$(du -sb . 2>/dev/null | awk '{print $1}')
    if [ -z "$before_bytes" ]; then
        before_bytes=0
    fi

    # Count folders before deletion
    local folder_count=$(find . -mindepth 1 -maxdepth 1 -type d | wc -l)
    local removed_count=0
    
    write_log "Found $folder_count backup folders to clean"
    
    if [ $folder_count -gt 0 ]; then
        # Remove folders one by one
        find . -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d '' folder; do
            folder_name=$(basename "$folder")
            write_log "Removing backup folder: $folder_name"
            rm -rf "$folder"
            sleep 0.1  # Small delay for visual effect (interactive mode only)
        done
        removed_count=$folder_count
    fi

    local after_bytes=$(du -sb . 2>/dev/null | awk '{print $1}')
    if [ -z "$after_bytes" ]; then
        after_bytes=0
    fi

    local deleted_bytes=$((before_bytes - after_bytes))
    if [ "$deleted_bytes" -lt 0 ]; then
        deleted_bytes=0
    fi

    cat <<EOF > "$stats_file"
status=ok
before=$before_bytes
after=$after_bytes
deleted=$deleted_bytes
folders_removed=$removed_count
EOF
    
    write_log "Backup cleanup completed - removed $removed_count folders, freed $(format_bytes $deleted_bytes)"
}

report_backup_stats() {
    local stats_file="$CLEAN_BACKUP_STATS_FILE"

    if [ ! -f "$stats_file" ]; then
        return
    fi

    local status="" before="0" after="0" deleted="0" folders_removed="0"

    while IFS='=' read -r key value; do
        case "$key" in
            status) status="$value" ;;
            before) before="$value" ;;
            after) after="$value" ;;
            deleted) deleted="$value" ;;
            folders_removed) folders_removed="$value" ;;
        esac
    done < "$stats_file"

    rm -f "$stats_file"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [ "$status" = "missing" ]; then
        if is_interactive; then
            echo -e "${YELLOW}⚠️  Backup directory not found: ${WHITE}${BACKUP_DIR}${NC}"
        fi
        write_log "Backup directory missing: $BACKUP_DIR"
        return
    fi

    local before_hr=$(format_bytes "$before")
    local after_hr=$(format_bytes "$after")
    local deleted_hr=$(format_bytes "$deleted")

    if is_interactive; then
        echo -e "\n${CYAN}📈 Backup Cleanup Statistics:${NC}"
        echo -e "${GRAY}   Size before cleanup: ${WHITE}${before_hr}${NC}"
        echo -e "${GRAY}   Size after cleanup:  ${WHITE}${after_hr}${NC}"
        echo -e "${GRAY}   Space recovered:     ${GREEN}${deleted_hr}${NC}"
        echo -e "${GRAY}   Folders removed:     ${WHITE}${folders_removed}${NC}\n"
    fi

    write_log "Backup cleanup - before: $before_hr ($before B), after: $after_hr ($after B), freed: $deleted_hr ($deleted B), folders removed: $folders_removed"
}

# ===================================================================================
# MAIN EXECUTION
# ===================================================================================

# Setup environment and logging
setup_environment
init_log_file

# Log script start
write_log "=== CLEAN BACKUP SCRIPT STARTED ==="

# Startup animation (interactive mode only)
if is_interactive; then
    clear
    echo -e "${MAGENTA}${BOLD}"
    type_message "🚀 Initializing System Maintenance Protocol..." 0.04
    sleep 0.3

    # Professional header with system information
    # Note: Variables declared without 'local' since this is outside a function
    _header_hostname=$(hostname)
    _header_os=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Linux")
    _header_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "\n${MAGENTA}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${BOLD}${WHITE}              🧹 SYSTEM MAINTENANCE & OPTIMIZATION                ${NC}${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${CYAN}                        Version 2.2 Professional                  ${NC}${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╠══════════════════════════════════════════════════════════════════╣${NC}"
    printf "${MAGENTA}║${GRAY}  Host: ${WHITE}%-56s${MAGENTA}║${NC}\n" "$_header_hostname"
    printf "${MAGENTA}║${GRAY}  OS:   ${WHITE}%-56s${MAGENTA}║${NC}\n" "$_header_os"
    printf "${MAGENTA}║${GRAY}  Time: ${WHITE}%-56s${MAGENTA}║${NC}\n" "$_header_time"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════╝${NC}\n"

    # Initial loading simulation with information
    show_progress_bar 15 "⚡ Preparing system scan and cleanup modules..."
    echo
    
    # Display disk usage information before cleanup
    echo -e "${CYAN}📊 System Status Overview:${NC}"
    echo -e "${GRAY}$(df -h / | awk 'NR==2 {printf "   Root Filesystem: %s used of %s (%s available)\n", $3, $2, $4}')${NC}"
    echo -e "${GRAY}$(free -h | awk '/^Mem:/ {printf "   Memory: %s used of %s (%s available)\n", $3, $2, $7}')${NC}\n"
    
    # Cleanup temporary header variables
    unset _header_hostname _header_os _header_time
else
    write_log "Running in non-interactive mode (cron)"
fi

# --- SECTION 1: SYSTEM-LEVEL CLEANUP ---
if is_interactive; then
    echo -e "\n${YELLOW}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${YELLOW}${BOLD}┃  ${GEAR}  PHASE 1: SYSTEM MAINTENANCE                           ${YELLOW}┃${NC}"
    echo -e "${YELLOW}${BOLD}┃  ${GRAY}System-wide cleanup operations requiring elevated access   ${YELLOW}┃${NC}"
    echo -e "${YELLOW}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
fi

do_task "Removing orphaned package dependencies" "sudo apt autoremove -y"
do_task "Cleaning APT package cache" "sudo apt clean"

# Cleanup /tmp and /var/tmp - only files older than 7 days that are not in use
do_task "Purging stale temporary files from /tmp (>7 days old)" "sudo find /tmp -maxdepth 1 -type f -mtime +7 -delete 2>/dev/null || true"
do_task "Removing empty directories from /tmp" "sudo find /tmp -maxdepth 1 -type d -empty -delete 2>/dev/null || true"
do_task "Purging stale temporary files from /var/tmp (>7 days old)" "sudo find /var/tmp -maxdepth 1 -type f -mtime +7 -delete 2>/dev/null || true"
do_task "Removing empty directories from /var/tmp" "sudo find /var/tmp -maxdepth 1 -type d -empty -delete 2>/dev/null || true"

# Limit journal system size
do_task "Rotating and vacuuming system journal (max 100MB)" "sudo journalctl --vacuum-size=100M"

# Clear system log files - use nullglob to prevent literal string iteration when no matches exist
if [ -d "/var/log" ]; then
    # Save nullglob state then enable it
    _old_nullglob=$(shopt -p nullglob 2>/dev/null || echo "")
    shopt -s nullglob
    
    logfiles=(/var/log/*.log)
    if [ ${#logfiles[@]} -gt 0 ]; then
        for logfile in "${logfiles[@]}"; do
            if [ -f "$logfile" ] && [ -w "$logfile" ]; then
                do_task "Truncating log file: $(basename "$logfile")" "sudo truncate -s 0 '$logfile'"
            fi
        done
    fi
    
    # Restore nullglob state
    eval "$_old_nullglob" 2>/dev/null || shopt -u nullglob 2>/dev/null || true
fi

if [ -d "/var/cache/netdata" ]; then
    do_task "Cleaning Netdata cache" "clean_netdata"
fi

# --- SECTION 2: USER ENVIRONMENT CLEANUP ---
if is_interactive; then
    echo -e "\n${BLUE}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${BLUE}${BOLD}┃  👤  PHASE 2: USER ENVIRONMENT MAINTENANCE                  ${BLUE}┃${NC}"
    echo -e "${BLUE}${BOLD}┃  ${GRAY}Cleaning user cache and temporary files                    ${BLUE}┃${NC}"
    echo -e "${BLUE}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
fi

do_task "Clearing user cache directory (~/.cache)" "rm -rf ~/.cache/*"

# --- SECTION 3: BACKUP DIRECTORY MANAGEMENT ---
if is_interactive; then
    echo -e "\n${GREEN}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${GREEN}${BOLD}┃  📁  PHASE 3: BACKUP DIRECTORY OPTIMIZATION                 ${GREEN}┃${NC}"
    echo -e "${GREEN}${BOLD}┃  ${GRAY}Managing backup storage at: ${CYAN}${BACKUP_DIR}${GREEN}┃${NC}"
    echo -e "${GREEN}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
fi

do_task "Removing old backup folders from $BACKUP_DIR" "clean_backups"
report_backup_stats

# Footer with completion animation (interactive mode only)
if is_interactive; then
    # Calculate final statistics
    _footer_end_time=$(date '+%Y-%m-%d %H:%M:%S')
    _footer_disk=$(df -h / | awk 'NR==2 {print $5}')
    
    echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║${WHITE}                 ✨  MAINTENANCE COMPLETED  ✨                     ${NC}${GREEN}║${NC}"
    echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}${BOLD}║  ${CYAN}All system cleanup operations executed successfully           ${GREEN}┃${NC}"
    echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════════════╣${NC}"
    printf "${GREEN}${BOLD}║${GRAY}  Completion Time: ${WHITE}%-47s${GREEN}┃${NC}\n" "$_footer_end_time"
    printf "${GREEN}${BOLD}║${GRAY}  Disk Usage: ${WHITE}%-52s${GREEN}┃${NC}\n" "$_footer_disk"
    printf "${GREEN}${BOLD}║${GRAY}  Log File: ${WHITE}%-54s${GREEN}┃${NC}\n" "$LOG_FILE"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}💡 Pro Tip:${NC} ${GRAY}Schedule this script via cron for automated maintenance.${NC}"
    echo -e "${GRAY}   Example: 0 2 * * 0 /path/to/clean_backup_fixed.sh > /dev/null 2>&1${NC}\n"
    
    # Cleanup temporary footer variables
    unset _footer_end_time _footer_disk
fi

# Log script completion
write_log "=== CLEAN BACKUP SCRIPT COMPLETED SUCCESSFULLY ==="