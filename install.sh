#!/bin/bash
set -euo pipefail

VERSION="1.3.2"
LOGFILE="$HOME/os-for-work-install.log"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log() {
    local level="$1"; shift
    local msg="$*"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${level}${msg}${NC}"
    echo "[$timestamp] $msg" >> "$LOGFILE"
}
log_info() { log "$GREEN[INFO]" "$*"; }
log_warn() { log "$YELLOW[WARN]" "$*"; }
log_error(){ log "$RED[ERROR]" "$*"; }
log_step() { log "$BLUE[STEP]" "$*"; }

# Error handling wrapper
run_step() {
    local step_name="$1"
    local step_command="$2"
    
    log_step "$step_name..."
    if eval "$step_command" 2>> "$LOGFILE"; then
        log_info "$step_name completed successfully"
        return 0
    else
        log_error "$step_name failed - check $LOGFILE for details"
        return 1
    fi
}

# Safe command execution with logging
safe_run() {
    local cmd="$*"
    log_info "Running: $cmd"
    if eval "$cmd" >> "$LOGFILE" 2>&1; then
        return 0
    else
        log_warn "Command completed with non-zero exit: $cmd"
        return 1
    fi
}

# === Welcome Banner ===
clear
echo "========================================="
echo "   OS for Work Installer v$VERSION"
echo "   Local SME Workstation Setup"
echo "========================================="
log_info "Welcome! This script will install SME-friendly desktop tools."
log_info "Logs will be written to $LOGFILE"
echo ""

# Continue even if some parts fail
set +e

# === Distribution Detection ===
detect_distro() {
    log_step "Detecting distribution..."
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_VERSION_ID="${VERSION_ID:-unknown}"
        DISTRO_NAME="${NAME:-$ID}"
        log_info "Detected: $DISTRO_NAME $DISTRO_VERSION_ID"
    else
        log_warn "Cannot detect distribution, continuing with basic assumptions"
        DISTRO_ID="unknown"
        DISTRO_NAME="Unknown Linux"
    fi
    
    # Check if Debian-based
    if ! command -v apt >/dev/null; then
        log_error "This script requires a Debian-based distribution (apt package manager)"
        log_info "Please run on Ubuntu, Debian, Linux Mint, or other Debian-based systems"
        exit 1
    fi
}

# === Dependency Checks ===
check_dependencies() {
    log_step "Checking system dependencies..."
    
    # Check for sudo
    if ! command -v sudo >/dev/null; then
        log_error "sudo is required but not installed."
        log_info "Please install sudo or run as root with appropriate permissions"
        exit 1
    fi
    
    # Check for apt
    if ! command -v apt >/dev/null; then
        log_error "apt is required but not installed."
        exit 1
    fi
    
    # Check for GUI environment (warn but don't exit)
    if [ -z "${DISPLAY:-}" ] && [ -z "${XDG_CURRENT_DESKTOP:-}" ]; then
        log_warn "No GUI environment detected. Some applications may not work properly."
        log_warn "Continuing with installation..."
    else
        log_info "GUI environment detected."
    fi
    
    log_info "Basic dependencies verified."
}

# === Config Backup for Uninstall ===
backup_configs() {
    local backup_dir="$HOME/os-for-work-backups"
    safe_run "mkdir -p '$backup_dir'"
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local file="$backup_dir/config_backup_$ts.tar.gz"
    
    log_step "Backing up configurations..."
    
    # Backup important configs and workspace
    safe_run "tar -czf '$file' \
        '$HOME/.config' \
        '$HOME/Workspace' \
        '$HOME/Templates' \
        '$HOME/.thunderbird' \
        '$HOME/.config/libreoffice' \
        '$HOME/.local/share/applications'/*.desktop \
        2>/dev/null" || true
        
    if [ -f "$file" ]; then
        log_info "Configuration and workspace backed up to $file"
    else
        log_warn "Backup creation failed or no files to backup"
    fi
}

# === Uninstall Option ===
uninstall_all() {
    log_warn "=== UNINSTALL OS FOR WORK ==="
    log_warn "This will remove all installed applications and shortcuts."
    log_warn "Your data in ~/Workspace/ and ~/Templates/ will be preserved."
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstall cancelled."
        return
    fi

    backup_configs

    log_step "Removing installed applications..."
    
    # Remove APT packages (only if they are installed)
    local packages=(
        thunderbird libreoffice* gnucash gimp inkscape keepassxc veracrypt 
        deja-dup filezilla kmymoney scribus kdenlive audacity pdfarranger 
        syncthing torbrowser-launcher baobab htop glances simple-scan 
        ocrfeeder gtimelog ktimetracker hamster-time-tracker python3-pip
        nodejs npm build-essential gitk meld darktable rawtherapee
        seahorse gnome-keyring gparted timeshift stacer
    )
    
    local removed_packages=()
    for pkg in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii  ${pkg%%\*}"; then
            if safe_run "sudo apt remove --purge -y '$pkg'"; then
                removed_packages+=("$pkg")
            else
                log_warn "Failed to remove: $pkg"
            fi
        fi
    done
    
    # Clean up dependencies
    safe_run "sudo apt autoremove -y --purge"
    
    # Remove snaps
    log_step "Removing Snap applications..."
    if snap list element-desktop 2>/dev/null | grep -q element-desktop; then
        safe_run "sudo snap remove element-desktop" || log_warn "Failed to remove Element Desktop"
    fi
    
    if snap list code 2>/dev/null | grep -q code; then
        safe_run "sudo snap remove code" || log_warn "Failed to remove VS Code"
    fi
    
    # Remove desktop shortcuts and web app entries
    log_step "Removing shortcuts..."
    safe_run "rm -f '$HOME/Desktop/'*.desktop"
    safe_run "rm -f '$HOME/.local/share/applications/'jitsi-meet-web.desktop"
    safe_run "rm -f '$HOME/.local/share/applications/'google-meet-web.desktop"
    
    log_info "=== Uninstall Complete ==="
    log_info "Removed ${#removed_packages[@]} packages"
    log_info "Your data is preserved in:"
    log_info "  - $HOME/Workspace/"
    log_info "  - $HOME/Templates/"
    log_info "  - $HOME/os-for-work-backups/"
    log_info "Backup created: $(ls -t "$HOME/os-for-work-backups/"config_backup_*.tar.gz 2>/dev/null | head -1)"
}

# === System Update ===
update_system() {
    run_step "Updating package lists" "sudo apt update"
    run_step "Upgrading system packages" "sudo apt upgrade -y"
    run_step "Installing basic tools" "sudo apt install -y curl wget"
}

# === Snap Setup ===
ensure_snap_ready() {
    log_step "Setting up Snap..."
    
    if ! command -v snap >/dev/null; then
        log_info "Installing snapd..."
        safe_run "sudo apt install -y snapd"
    else
        log_info "Snap already installed."
    fi
    
    # Start and enable snapd (but don't fail if it doesn't work)
    if command -v systemctl >/dev/null; then
        safe_run "sudo systemctl enable --now snapd.socket" || true
        safe_run "sudo systemctl start snapd.socket" || true
        safe_run "sudo systemctl enable --now snapd" || true
        safe_run "sudo systemctl start snapd" || true
    fi
    
    # Ensure snap directory structure
    if [ ! -d /snap ] && [ -d /var/lib/snapd/snap ]; then
        safe_run "sudo ln -s /var/lib/snapd/snap /snap" || true
    fi
    
    # Add to PATH for current session
    export PATH="$PATH:/snap/bin"
    
    # Wait for snap to initialize
    sleep 2
    log_info "Snap setup complete."
}

# === Installation Functions ===

install_productivity_suite() {
    log_step "Installing Productivity Suite..."
    
    local packages=(
        thunderbird
        libreoffice
        libreoffice-l10n-en-gb
        hunspell-en-gb
        gnucash
        gimp
        inkscape
        keepassxc
        veracrypt
        deja-dup
        git
        vim
        nautilus
        filezilla
    )
    
    for pkg in "${packages[@]}"; do
        if ! safe_run "sudo apt install -y $pkg"; then
            log_warn "Failed to install $pkg, continuing..."
        fi
    done
    
    log_info "Productivity Suite installation attempted."
}

install_communication_suite() {
    log_step "Installing Communication Suite..."
    ensure_snap_ready
    
    # Install Element via Snap
    if ! snap list element-desktop 2>/dev/null | grep -q element-desktop; then
        if safe_run "sudo snap install element-desktop"; then
            log_info "Element Desktop installed via Snap"
        else
            log_warn "Failed to install Element Desktop via Snap"
        fi
    else
        log_info "Element Desktop already installed."
    fi
    
    # Create web app shortcuts
    local APPS_DIR="$HOME/.local/share/applications"
    mkdir -p "$APPS_DIR"
    
    # Jitsi Meet web shortcut
    cat > "$APPS_DIR/jitsi-meet-web.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Jitsi Meet (Web)
Exec=xdg-open https://meet.jit.si
Icon=web-browser
Terminal=false
Categories=Network;VideoConference;
Comment=Video conferencing with Jitsi Meet
EOF
    
    # Google Meet web shortcut
    cat > "$APPS_DIR/google-meet-web.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Google Meet (Web)
Exec=xdg-open https://meet.google.com
Icon=web-browser
Terminal=false
Categories=Network;VideoConference;
Comment=Video conferencing with Google Meet
EOF
    
    chmod +x "$APPS_DIR"/*-meet-web.desktop
    log_info "Communication Suite installed."
}

install_finance_suite() {
    log_step "Installing Finance Suite..."
    safe_run "sudo apt install -y kmymoney" || log_warn "KMyMoney installation failed"
    log_info "Finance Suite installation attempted."
}

install_creative_suite() {
    log_step "Installing Creative Suite..."
    
    local packages=(
        scribus
        kdenlive
        audacity
        pdfarranger
        darktable
        rawtherapee
    )
    
    for pkg in "${packages[@]}"; do
        safe_run "sudo apt install -y $pkg" || log_warn "Failed to install $pkg"
    done
    
    log_info "Creative Suite installation attempted."
}

install_security_suite() {
    log_step "Installing Security Suite..."
    
    local packages=(
        syncthing
        torbrowser-launcher
        seahorse
        gnome-keyring
    )
    
    for pkg in "${packages[@]}"; do
        safe_run "sudo apt install -y $pkg" || log_warn "Failed to install $pkg"
    done
    
    log_info "Security Suite installation attempted."
}

install_utilities_suite() {
    log_step "Installing Utilities Suite..."
    
    local packages=(
        baobab
        htop
        glances
        simple-scan
        ocrfeeder
        gparted
        timeshift
        stacer
    )
    
    for pkg in "${packages[@]}"; do
        safe_run "sudo apt install -y $pkg" || log_warn "Failed to install $pkg"
    done
    
    log_info "Utilities Suite installation attempted."
}

install_time_tracking_suite() {
    log_step "Installing Time Tracking Suite..."
    
    local packages=(
        gtimelog
        ktimetracker
        hamster-time-tracker
    )
    
    for pkg in "${packages[@]}"; do
        safe_run "sudo apt install -y $pkg" || log_warn "Failed to install $pkg"
    done
    
    log_info "Time Tracking Suite installation attempted."
}

install_dev_tools_suite() {
    log_step "Installing Development Tools..."
    
    local packages=(
        python3
        python3-pip
        python3-venv
        nodejs
        npm
        build-essential
        gitk
        meld
    )
    
    for pkg in "${packages[@]}"; do
        safe_run "sudo apt install -y $pkg" || log_warn "Failed to install $pkg"
    done
    
    ensure_snap_ready
    if ! snap list code 2>/dev/null | grep -q code; then
        safe_run "sudo snap install code --classic" || log_warn "Failed to install VS Code via Snap"
    fi
    
    log_info "Development Tools installation attempted."
}

# === Workplace Templates ===
setup_workspace() {
    log_step "Setting up workspace..."
    
    safe_run "mkdir -p '$HOME/Workspace/'{Projects,Documents,ClientWork,Administrative,Archive} '$HOME/Templates'"

    # Project Plan Template
    cat > "$HOME/Templates/Project_Plan.md" <<'EOF'
# Project Plan
- Project: [Name]
- Client: [Name]
- Timeline: [Start] - [End]
## Deliverables
- [ ] Deliverable 1
- [ ] Deliverable 2
## Budget
- Total: [Amount]
- Expenses: [List]
EOF

    # Meeting Notes Template
    cat > "$HOME/Templates/Meeting_Notes.md" <<'EOF'
# Meeting Notes
Date: [Date]
Attendees: [Names]
## Agenda
- Item 1
- Item 2
## Notes
- ...
## Action Items
- [ ] Task 1 (Owner: [Name])
- [ ] Task 2 (Owner: [Name])
EOF

    log_info "Workspace directories and templates created."
}

# === Desktop Shortcuts ===
create_desktop_shortcuts() {
    log_step "Creating desktop shortcuts..."
    local DESKTOP_DIR="$HOME/Desktop"
    safe_run "mkdir -p '$DESKTOP_DIR'"
    
    # Workspace Shortcut
    cat > "$DESKTOP_DIR/Workspace.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=📁 Open Workspace
Comment=Open your business workspace
Exec=xdg-open $HOME/Workspace
Icon=folder
Terminal=false
Categories=Utility;
EOF

    # Productivity Center Shortcut
    cat > "$DESKTOP_DIR/Productivity-Center.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=🚀 Productivity Center
Comment=Launch Office, Email, and Business Apps
Exec=libreoffice
Icon=libreoffice-main
Terminal=false
Categories=Office;
EOF

    safe_run "chmod +x '$DESKTOP_DIR'/*.desktop"
    log_info "Desktop shortcuts created."
}

# === Post-install Summary ===
show_summary() {
    log_info "=== Installation Complete ==="
    echo ""
    echo "📦 Installation Summary:"
    echo "  Most requested applications have been installed"
    echo "  Some packages may have been skipped due to availability"
    echo ""
    echo "📁 Your Workspace:"
    echo "  Location: $HOME/Workspace/"
    echo "  Templates: $HOME/Templates/"
    echo ""
    echo "🔧 Next Steps:"
    echo "  1. Configure your email in Thunderbird"
    echo "  2. Explore the templates in ~/Templates/"
    echo "  3. Log out and back in for all applications to appear"
    echo ""
    echo "📋 Log file: $LOGFILE"
    echo "========================================="
}

# === Main Menu ===
show_menu() {
    clear
    echo "========================================="
    echo "   OS for Work - Installation Menu"
    echo "========================================="
    echo "1) Install Everything (Recommended)"
    echo "2) Install Productivity Suite Only"
    echo "3) Install Communication Suite Only" 
    echo "4) Install Finance & Time Tracking"
    echo "5) Setup Workspace & Shortcuts Only"
    echo "6) Uninstall All Applications"
    echo "7) Show Summary"
    echo "8) Exit"
    echo "========================================="
    echo "Note: Installation will continue even if"
    echo "some packages fail to install."
    echo "========================================="
}

install_everything() {
    log_step "Starting complete installation..."
    update_system
    install_productivity_suite
    install_communication_suite
    install_finance_suite
    install_creative_suite
    install_security_suite
    install_utilities_suite
    install_time_tracking_suite
    install_dev_tools_suite
    setup_workspace
    create_desktop_shortcuts
    show_summary
}

# === Main Function ===
main() {
    # Trap to catch CTRL+C
    trap 'log_info "Installation interrupted by user"; exit 1' INT
    
    detect_distro
    check_dependencies
    
    while true; do
        show_menu
        read -p "Choose option [1-8]: " choice
        case $choice in
            1) install_everything ;;
            2) update_system; install_productivity_suite ;;
            3) install_communication_suite ;;
            4) install_finance_suite; install_time_tracking_suite ;;
            5) setup_workspace; create_desktop_shortcuts ;;
            6) uninstall_all ;;
            7) show_summary ;;
            8) log_info "Exiting. Log file: $LOGFILE"; exit 0 ;;
            *) log_error "Invalid option. Please choose 1-8." ;;
        esac
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Script entry point with better error handling
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "=== OS for Work Installer Started ==="
    if main "$@"; then
        log_info "=== Installer finished successfully ==="
    else
        log_error "=== Installer finished with errors ==="
        log_info "Check the log file: $LOGFILE"
        exit 1
    fi
fi
