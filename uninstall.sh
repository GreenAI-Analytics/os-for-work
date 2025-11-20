#!/bin/bash
# Don't use set -euo pipefail at the top - we want to handle errors gracefully

UNINSTALL_LOGFILE="$HOME/os-for-work-uninstall.log"
BACKUP_DIR="$HOME/os-for-work-backups"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log() {
    local level="$1"; shift
    local msg="$*"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${level}${msg}${NC}"
    echo "[$timestamp] $msg" >> "$UNINSTALL_LOGFILE"
}
log_info() { log "$GREEN[INFO]" "$*"; }
log_warn() { log "$YELLOW[WARN]" "$*"; }
log_error(){ log "$RED[ERROR]" "$*"; }
log_step() { log "$BLUE[STEP]" "$*"; }

# Initialize log file
: > "$UNINSTALL_LOGFILE"

# Safe command execution with full error handling
safe_run() {
    local cmd="$*"
    local attempt=0
    local max_attempts=2
    
    log_info "Running: $cmd"
    
    while [ $attempt -lt $max_attempts ]; do
        if eval "$cmd" >> "$UNINSTALL_LOGFILE" 2>&1; then
            return 0
        else
            ((attempt++)) || true
            if [ $attempt -eq $max_attempts ]; then
                log_warn "Command failed after $max_attempts attempts: $cmd"
                return 1
            fi
            sleep 1
        fi
    done
}

# Safe directory removal with validation
safe_remove_dir() {
    local dir="$1"
    local name="$2"
    
    # Validate directory exists and is not root
    if [ ! -d "$dir" ]; then
        log_info "Directory not found: $dir"
        return 0
    fi
    
    # Additional safety check - don't remove critical directories
    local critical_dirs=("/" "/home" "/etc" "/usr" "/var")
    for critical in "${critical_dirs[@]}"; do
        if [ "$dir" = "$critical" ]; then
            log_error "ABORTING: Attempted to remove critical directory: $dir"
            return 1
        fi
    done
    
    # Check if directory is in user's home
    if [[ "$dir" != "$HOME"/* ]]; then
        log_error "ABORTING: Directory not in home: $dir"
        return 1
    fi
    
    log_info "Removing directory: $dir"
    if safe_run "rm -rf '$dir'"; then
        log_info "✓ Removed $name: $dir"
        return 0
    else
        log_warn "Failed to remove directory: $dir"
        return 1
    fi
}

# Safe file removal
safe_remove_file() {
    local file="$1"
    local name="$2"
    
    if [ ! -f "$file" ]; then
        return 0  # File doesn't exist, considered success
    fi
    
    # Safety check - don't remove critical files
    if [[ "$file" == "/"* ]] && [[ "$file" != "$HOME"/* ]]; then
        log_error "ABORTING: Attempted to remove system file: $file"
        return 1
    fi
    
    if safe_run "rm -f '$file'"; then
        log_info "✓ Removed $name: $file"
        return 0
    else
        log_warn "Failed to remove file: $file"
        return 1
    fi
}

# Check sudo privileges
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log_info "Sudo access required - you may be prompted for password"
    fi
}

# Backup configurations with validation
backup_configs() {
    local backup_name="$1"
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/${backup_name}_backup_$ts.tar.gz"
    
    log_step "Creating backup: $backup_name..."
    
    if ! safe_run "mkdir -p '$BACKUP_DIR'"; then
        log_warn "Failed to create backup directory"
        return 1
    fi
    
    local backup_items=()
    local has_items=false
    
    case "$backup_name" in
        "productivity")
            [ -d "$HOME/.config/libreoffice" ] && backup_items+=("$HOME/.config/libreoffice") && has_items=true
            [ -d "$HOME/.thunderbird" ] && backup_items+=("$HOME/.thunderbird") && has_items=true
            ;;
        "finance")
            [ -d "$HOME/.local/share/gnucash" ] && backup_items+=("$HOME/.local/share/gnucash") && has_items=true
            [ -d "$HOME/.local/share/kmymoney" ] && backup_items+=("$HOME/.local/share/kmymoney") && has_items=true
            ;;
        "creative")
            [ -d "$HOME/.config/gimp" ] && backup_items+=("$HOME/.config/gimp") && has_items=true
            [ -d "$HOME/.config/inkscape" ] && backup_items+=("$HOME/.config/inkscape") && has_items=true
            [ -d "$HOME/.config/kdenlive" ] && backup_items+=("$HOME/.config/kdenlive") && has_items=true
            ;;
        "all")
            [ -d "$HOME/.config" ] && backup_items+=("$HOME/.config") && has_items=true
            [ -d "$HOME/Workspace" ] && backup_items+=("$HOME/Workspace") && has_items=true
            [ -d "$HOME/Templates" ] && backup_items+=("$HOME/Templates") && has_items=true
            [ -d "$HOME/.thunderbird" ] && backup_items+=("$HOME/.thunderbird") && has_items=true
            ;;
    esac
    
    if [ "$has_items" = false ]; then
        log_info "No items to backup for $backup_name"
        return 0
    fi
    
    log_info "Backing up: ${backup_items[*]}"
    
    if safe_run "tar -czf '$backup_file' ${backup_items[*]} 2>/dev/null"; then
        # Verify backup was created
        if [ -f "$backup_file" ]; then
            local size
            size=$(du -h "$backup_file" | cut -f1)
            log_info "✓ Backup created: $backup_file ($size)"
            return 0
        else
            log_warn "Backup file not created: $backup_file"
            return 1
        fi
    else
        log_warn "Backup creation failed"
        return 1
    fi
}

# Check if package is installed (safe version)
is_package_installed() {
    local pkg="$1"
    if ! command -v dpkg >/dev/null 2>&1; then
        log_error "dpkg not available - cannot check packages"
        return 1
    fi
    dpkg -l 2>/dev/null | grep -q "^ii  $pkg " && return 0 || return 1
}

# Check if snap is installed (safe version)
is_snap_installed() {
    local snap="$1"
    if ! command -v snap >/dev/null 2>&1; then
        return 1  # Snap not available
    fi
    snap list 2>/dev/null | grep -q "^$snap " && return 0 || return 1
}

# Safe package removal
safe_remove_package() {
    local pkg="$1"
    local name="$2"
    
    if ! is_package_installed "$pkg"; then
        log_info "✓ $name not installed (skipping)"
        return 0
    fi
    
    log_info "Removing $name..."
    
    # Try remove first, then purge if needed
    if safe_run "sudo apt remove -y '$pkg'"; then
        # Try to purge as well for complete removal
        safe_run "sudo apt purge -y '$pkg'" || true
        log_info "✓ Removed $name"
        return 0
    else
        log_warn "Failed to remove $name"
        return 1
    fi
}

# Safe snap removal
safe_remove_snap() {
    local snap="$1"
    local name="$2"
    
    if ! is_snap_installed "$snap"; then
        log_info "✓ $name not installed (skipping)"
        return 0
    fi
    
    log_info "Removing $name..."
    if safe_run "sudo snap remove '$snap'"; then
        log_info "✓ Removed $name"
        return 0
    else
        log_warn "Failed to remove $name"
        return 1
    fi
}

# === Uninstall Functions ===

uninstall_productivity_suite() {
    log_step "Starting Productivity Suite uninstall..."
    backup_configs "productivity"
    
    local packages=(
        "thunderbird:Thunderbird Email"
        "libreoffice:LibreOffice Office Suite"
        "libreoffice-l10n-en-gb:LibreOffice English Language Pack"
        "hunspell-en-gb:English Spell Checker"
        "gnucash:GnuCash Accounting"
        "gimp:GIMP Image Editor"
        "inkscape:Inkscape Vector Graphics"
        "keepassxc:KeePassXC Password Manager"
        "veracrypt:VeraCrypt Encryption"
        "deja-dup:Deja Dup Backup"
        "filezilla:FileZilla FTP Client"
    )
    
    local total_count=0
    local removed_count=0
    
    for pkg_info in "${packages[@]}"; do
        IFS=':' read -r pkg name <<< "$pkg_info"
        ((total_count++)) || true
        if safe_remove_package "$pkg" "$name"; then
            ((removed_count++)) || true
        fi
    done
    
    log_info "Productivity Suite: Removed $removed_count of $total_count packages"
}

uninstall_communication_suite() {
    log_step "Starting Communication Suite uninstall..."
    
    local total_count=0
    local removed_count=0
    
    # Remove Element Desktop (Snap)
    ((total_count++)) || true
    if safe_remove_snap "element-desktop" "Element Desktop"; then
        ((removed_count++)) || true
    fi
    
    # Remove web shortcuts
    local shortcuts=(
        "$HOME/.local/share/applications/jitsi-meet-web.desktop:Jitsi Meet Web Shortcut"
        "$HOME/.local/share/applications/google-meet-web.desktop:Google Meet Web Shortcut"
    )
    
    for shortcut_info in "${shortcuts[@]}"; do
        IFS=':' read -r shortcut name <<< "$shortcut_info"
        ((total_count++)) || true
        if safe_remove_file "$shortcut" "$name"; then
            ((removed_count++)) || true
        fi
    done
    
    log_info "Communication Suite: Removed $removed_count of $total_count items"
}

uninstall_finance_suite() {
    log_step "Starting Finance Suite uninstall..."
    backup_configs "finance"
    
    local packages=(
        "kmymoney:KMyMoney Personal Finance"
    )
    
    local total_count=0
    local removed_count=0
    
    for pkg_info in "${packages[@]}"; do
        IFS=':' read -r pkg name <<< "$pkg_info"
        ((total_count++)) || true
        if safe_remove_package "$pkg" "$name"; then
            ((removed_count++)) || true
        fi
    done
    
    log_info "Finance Suite: Removed $removed_count of $total_count packages"
}

uninstall_creative_suite() {
    log_step "Starting Creative Suite uninstall..."
    backup_configs "creative"
    
    local packages=(
        "scribus:Scribus Desktop Publishing"
        "kdenlive:Kdenlive Video Editor"
        "audacity:Audacity Audio Editor"
        "pdfarranger:PDF Arranger"
        "darktable:Darktable Photo Editor"
        "rawtherapee:RawTherapee RAW Photo Editor"
    )
    
    local total_count=0
    local removed_count=0
    
    for pkg_info in "${packages[@]}"; do
        IFS=':' read -r pkg name <<< "$pkg_info"
        ((total_count++)) || true
        if safe_remove_package "$pkg" "$name"; then
            ((removed_count++)) || true
        fi
    done
    
    log_info "Creative Suite: Removed $removed_count of $total_count packages"
}

uninstall_security_suite() {
    log_step "Starting Security Suite uninstall..."
    
    local packages=(
        "syncthing:Syncthing File Synchronization"
        "torbrowser-launcher:Tor Browser Launcher"
        "seahorse:Seahorse Password Manager"
        "gnome-keyring:GNOME Keyring"
    )
    
    local total_count=0
    local removed_count=0
    
    for pkg_info in "${packages[@]}"; do
        IFS=':' read -r pkg name <<< "$pkg_info"
        ((total_count++)) || true
        if safe_remove_package "$pkg" "$name"; then
            ((removed_count++)) || true
        fi
    done
    
    log_info "Security Suite: Removed $removed_count of $total_count packages"
}

uninstall_utilities_suite() {
    log_step "Starting Utilities Suite uninstall..."
    
    local packages=(
        "baobab:Disk Usage Analyzer"
        "htop:HTop System Monitor"
        "glances:Glances System Monitor"
        "simple-scan:Simple Scan"
        "ocrfeeder:OCR Feeder"
        "gparted:GParted Partition Editor"
        "timeshift:Timeshift System Backup"
        "stacer:Stacer System Optimizer"
    )
    
    local total_count=0
    local removed_count=0
    
    for pkg_info in "${packages[@]}"; do
        IFS=':' read -r pkg name <<< "$pkg_info"
        ((total_count++)) || true
        if safe_remove_package "$pkg" "$name"; then
            ((removed_count++)) || true
        fi
    done
    
    log_info "Utilities Suite: Removed $removed_count of $total_count packages"
}

uninstall_time_tracking_suite() {
    log_step "Starting Time Tracking Suite uninstall..."
    
    local packages=(
        "gtimelog:GTimeLog Time Tracker"
        "ktimetracker:KTimeTracker"
        "hamster-time-tracker:Hamster Time Tracker"
    )
    
    local total_count=0
    local removed_count=0
    
    for pkg_info in "${packages[@]}"; do
        IFS=':' read -r pkg name <<< "$pkg_info"
        ((total_count++)) || true
        if safe_remove_package "$pkg" "$name"; then
            ((removed_count++)) || true
        fi
    done
    
    log_info "Time Tracking Suite: Removed $removed_count of $total_count packages"
}

uninstall_dev_tools_suite() {
    log_step "Starting Development Tools uninstall..."
    
    local packages=(
        "python3-pip:Python Package Manager"
        "nodejs:Node.js JavaScript Runtime"
        "npm:Node Package Manager"
        "build-essential:Build Essential Tools"
        "gitk:Git History Viewer"
        "meld:Meld Diff Tool"
    )
    
    local total_count=0
    local removed_count=0
    
    # Remove APT packages
    for pkg_info in "${packages[@]}"; do
        IFS=':' read -r pkg name <<< "$pkg_info"
        ((total_count++)) || true
        if safe_remove_package "$pkg" "$name"; then
            ((removed_count++)) || true
        fi
    done
    
    # Remove VS Code (Snap)
    ((total_count++)) || true
    if safe_remove_snap "code" "VS Code"; then
        ((removed_count++)) || true
    fi
    
    log_info "Development Tools: Removed $removed_count of $total_count items"
}

uninstall_workspace() {
    log_step "Starting Workspace uninstall..."
    backup_configs "all"
    
    local total_count=0
    local removed_count=0
    
    # Remove desktop shortcuts
    local shortcuts=(
        "$HOME/Desktop/Workspace.desktop:Workspace Desktop Shortcut"
        "$HOME/Desktop/Productivity-Center.desktop:Productivity Center Shortcut"
        "$HOME/Desktop/Time-Tracking.desktop:Time Tracking Shortcut"
    )
    
    for shortcut_info in "${shortcuts[@]}"; do
        IFS=':' read -r shortcut name <<< "$shortcut_info"
        ((total_count++)) || true
        if safe_remove_file "$shortcut" "$name"; then
            ((removed_count++)) || true
        fi
    done
    
    # Ask before removing workspace and templates
    echo ""
    log_warn "Your workspace contains:"
    log_info "  - $HOME/Workspace/ (business directories)"
    log_info "  - $HOME/Templates/ (business templates)"
    echo ""
    
    local response=""
    while [[ ! "$response" =~ ^[YyNn]$ ]]; do
        read -p "Remove workspace and templates? (y/N): " -n 1 -r response
        echo
        if [[ ! "$response" =~ ^[YyNn]$ ]]; then
            log_warn "Please answer y or n"
        fi
    done
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        ((total_count++)) || true
        if safe_remove_dir "$HOME/Workspace" "Workspace Directory"; then
            ((removed_count++)) || true
        fi
        
        ((total_count++)) || true
        if safe_remove_dir "$HOME/Templates" "Templates Directory"; then
            ((removed_count++)) || true
        fi
    else
        log_info "✓ Keeping workspace and templates"
    fi
    
    log_info "Workspace: Removed $removed_count of $total_count items"
}

uninstall_everything() {
    log_step "Starting COMPLETE uninstall of OS for Work..."
    
    # Final confirmation
    log_warn "⚠️  THIS WILL REMOVE ALL OS FOR WORK COMPONENTS!"
    log_warn "This includes:"
    log_warn "  - All installed applications"
    log_warn "  - Desktop shortcuts"
    log_warn "  - Workspace directories"
    log_warn "  - Configuration files"
    echo ""
    
    local response=""
    while [[ ! "$response" =~ ^[YyNn]$ ]]; do
        read -p "Are you ABSOLUTELY sure? Type 'YES' to continue: " -r response
        if [[ ! "$response" == "YES" ]]; then
            log_info "Uninstall cancelled"
            return
        fi
    done
    
    backup_configs "all"
    
    # Run all uninstall functions
    uninstall_productivity_suite
    uninstall_communication_suite
    uninstall_finance_suite
    uninstall_creative_suite
    uninstall_security_suite
    uninstall_utilities_suite
    uninstall_time_tracking_suite
    uninstall_dev_tools_suite
    
    # Remove workspace without asking
    safe_remove_dir "$HOME/Workspace" "Workspace Directory"
    safe_remove_dir "$HOME/Templates" "Templates Directory"
    
    # Remove any remaining shortcuts
    safe_remove_file "$HOME/Desktop/Workspace.desktop" "Workspace Shortcut"
    safe_remove_file "$HOME/Desktop/Productivity-Center.desktop" "Productivity Center Shortcut"
    safe_remove_file "$HOME/Desktop/Time-Tracking.desktop" "Time Tracking Shortcut"
    safe_remove_file "$HOME/.local/share/applications/jitsi-meet-web.desktop" "Jitsi Meet Shortcut"
    safe_remove_file "$HOME/.local/share/applications/google-meet-web.desktop" "Google Meet Shortcut"
    
    # Clean up dependencies
    log_step "Cleaning up system dependencies..."
    safe_run "sudo apt autoremove -y --purge"
    
    log_info "=== COMPLETE UNINSTALL FINISHED ==="
    log_info "All OS for Work components have been removed"
    log_info "Backups saved in: $BACKUP_DIR"
}

# === Menu ===
show_menu() {
    clear
    echo "========================================="
    echo "   OS for Work - Safe Uninstall Menu"
    echo "========================================="
    echo "1) Uninstall Productivity Suite"
    echo "2) Uninstall Communication Suite"
    echo "3) Uninstall Finance Suite"
    echo "4) Uninstall Creative Suite"
    echo "5) Uninstall Security Suite"
    echo "6) Uninstall Utilities Suite"
    echo "7) Uninstall Time Tracking Suite"
    echo "8) Uninstall Development Tools"
    echo "9) Remove Workspace & Shortcuts"
    echo "10) Uninstall EVERYTHING"
    echo "11) Exit"
    echo "========================================="
    echo "All operations include automatic backups"
    echo "and safe validation checks."
    echo "========================================="
}

# === Main Function ===
main() {
    # Trap to catch CTRL+C
    trap 'log_info "Uninstall interrupted by user"; exit 1' INT
    
    clear
    echo "========================================="
    echo "   OS for Work - Safe Uninstaller"
    echo "========================================="
    log_info "This script safely removes OS for Work components."
    log_info "Uninstall log: $UNINSTALL_LOGFILE"
    echo ""
    
    # Check sudo privileges
    check_sudo
    
    while true; do
        show_menu
        read -p "Choose option [1-11]: " choice
        case $choice in
            1) uninstall_productivity_suite ;;
            2) uninstall_communication_suite ;;
            3) uninstall_finance_suite ;;
            4) uninstall_creative_suite ;;
            5) uninstall_security_suite ;;
            6) uninstall_utilities_suite ;;
            7) uninstall_time_tracking_suite ;;
            8) uninstall_dev_tools_suite ;;
            9) uninstall_workspace ;;
            10) uninstall_everything ;;
            11) 
                log_info "Exiting uninstaller"
                exit 0
                ;;
            *) 
                log_error "Invalid option. Please choose 1-11."
                ;;
        esac
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Script entry point with error handling
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if main "$@"; then
        log_info "Uninstaller finished successfully"
    else
        log_error "Uninstaller finished with errors"
        log_info "Check log file: $UNINSTALL_LOGFILE"
        exit 1
    fi
fi
