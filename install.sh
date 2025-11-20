#!/bin/bash
set -euo pipefail

VERSION="1.3.0"
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

# === Welcome Banner ===
clear
echo "========================================="
echo "   OS for Work Installer v$VERSION"
echo "   Local SME Workstation Setup"
echo "========================================="
log_info "Welcome! This script will install SME-friendly desktop tools."
log_info "Logs will be written to $LOGFILE"

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
        log_error "Cannot detect distribution"
        exit 1
    fi
    
    # Check if Debian-based
    if ! command -v apt >/dev/null; then
        log_error "This script requires a Debian-based distribution (apt package manager)"
        exit 1
    fi
}

# === Dependency Checks ===
check_dependencies() {
    log_step "Checking system dependencies..."
    for cmd in apt sudo; do
        if ! command -v "$cmd" >/dev/null; then
            log_error "Missing dependency: $cmd"
            exit 1
        fi
    done
    
    # Check for GUI environment (warn but don't exit)
    if [ -z "${DISPLAY:-}" ] && [ -z "${XDG_CURRENT_DESKTOP:-}" ]; then
        log_warn "No GUI environment detected. Some applications may not work properly."
    else
        log_info "GUI environment detected."
    fi
}

# === System Update ===
update_system() {
    log_step "Updating system packages..."
    sudo apt update && sudo apt -y upgrade
    sudo apt install -y curl wget  # Ensure basic tools
    log_info "System updated."
}

# === Snap Setup ===
ensure_snap_ready() {
    log_step "Setting up Snap..."
    if ! command -v snap >/dev/null; then
        log_info "Installing snapd..."
        sudo apt install -y snapd
    fi
    
    # Start and enable snapd
    if command -v systemctl >/dev/null; then
        sudo systemctl enable --now snapd.socket 2>/dev/null || true
        sudo systemctl start snapd.socket 2>/dev/null || true
        sudo systemctl enable --now snapd 2>/dev/null || true
        sudo systemctl start snapd 2>/dev/null || true
    fi
    
    # Ensure snap directory structure
    if [ ! -d /snap ] && [ -d /var/lib/snapd/snap ]; then
        sudo ln -s /var/lib/snapd/snap /snap 2>/dev/null || true
    fi
    
    # Add to PATH for current session
    export PATH="$PATH:/snap/bin"
    
    # Wait for snap to initialize
    sleep 3
    log_info "Snap setup complete."
}

# === Flatpak Setup ===
ensure_flatpak_ready() {
    log_step "Setting up Flatpak..."
    if ! command -v flatpak >/dev/null; then
        log_info "Installing flatpak..."
        sudo apt install -y flatpak
        # Add Flathub repository
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        log_info "Flatpak installed and Flathub repository added."
    else
        log_info "Flatpak already installed."
    fi
}

# === Installation Functions ===

install_productivity_suite() {
    log_step "Installing Productivity Suite..."
    sudo apt install -y \
        thunderbird \
        libreoffice \
        libreoffice-l10n-en-gb \
        hunspell-en-gb \
        gnucash \
        gimp \
        inkscape \
        keepassxc \
        veracrypt \
        deja-dup \
        git \
        vim \
        nautilus \
        filezilla
    log_info "Productivity Suite installed."
}

install_communication_suite() {
    log_step "Installing Communication Suite..."
    ensure_snap_ready
    
    # Install Element via Snap
    if ! snap list element-desktop 2>/dev/null | grep -q element-desktop; then
        sudo snap install element-desktop
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
    sudo apt install -y kmymoney
    log_info "Finance Suite installed (GnuCash + KMyMoney)."
}

install_creative_suite() {
    log_step "Installing Creative Suite..."
    sudo apt install -y \
        scribus \
        kdenlive \
        audacity \
        pdfarranger \
        darktable \
        rawtherapee
    log_info "Creative Suite installed."
}

install_security_suite() {
    log_step "Installing Security Suite..."
    sudo apt install -y \
        syncthing \
        torbrowser-launcher \
        seahorse \
        gnome-keyring
    log_info "Security Suite installed."
}

install_utilities_suite() {
    log_step "Installing Utilities Suite..."
    sudo apt install -y \
        baobab \
        htop \
        glances \
        simple-scan \
        ocrfeeder \
        gparted \
        timeshift \
        stacer
    log_info "Utilities Suite installed."
}

install_time_tracking_suite() {
    log_step "Installing Time Tracking Suite..."
    sudo apt install -y \
        gtimelog \
        ktimetracker \
        hamster-time-tracker
    log_info "Time Tracking Suite installed."
}

install_dev_tools_suite() {
    log_step "Installing Development Tools..."
    sudo apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        nodejs \
        npm \
        build-essential \
        gitk \
        meld
    
    ensure_snap_ready
    if ! snap list code 2>/dev/null | grep -q code; then
        sudo snap install code --classic
    fi
    
    log_info "Development Tools installed."
}

# === Workplace Templates ===
setup_workspace() {
    log_step "Setting up workspace..."
    mkdir -p "$HOME/Workspace/"{Projects,Documents,ClientWork,Administrative,Archive} "$HOME/Templates"

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

    # Business Invoice Template
    cat > "$HOME/Templates/Business_Invoice.csv" <<'EOF'
"Invoice Number","Date","Client","Description","Quantity","Unit Price","Total","VAT","Grand Total"
"INV-001","$(date +%Y-%m-%d)","Client Name","Service Description","1","100.00","100.00","20.00","120.00"
EOF

    # Quick Reference Template
    cat > "$HOME/Templates/Quick_Reference.md" <<'EOF'
# Quick Reference
## Communication
- Email: Thunderbird
- Team Chat: Element
- Video Calls: Jitsi Meet / Google Meet
## Productivity
- Office Suite: LibreOffice
- Finance: GnuCash / KMyMoney
- Time Tracking: gtimelog
## File Management
- Cloud Sync: Nextcloud (optional)
- Local Sync: Syncthing
- Encryption: VeraCrypt
EOF

    log_info "Workspace directories and templates created."
}

# === Desktop Shortcuts ===
create_desktop_shortcuts() {
    log_step "Creating desktop shortcuts..."
    local DESKTOP_DIR="$HOME/Desktop"
    mkdir -p "$DESKTOP_DIR"
    
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

    # Time Tracking Shortcut
    cat > "$DESKTOP_DIR/Time-Tracking.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=⏱️ Time Tracking
Comment=Launch time tracking application
Exec=gtimelog
Icon=gtimelog
Terminal=false
Categories=Office;
EOF

    chmod +x "$DESKTOP_DIR"/*.desktop
    log_info "Desktop shortcuts created."
}

# === Config Backup for Uninstall ===
backup_configs() {
    local backup_dir="$HOME/os-for-work-backups"
    mkdir -p "$backup_dir"
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local file="$backup_dir/config_backup_$ts.tar.gz"
    
    # Backup important configs and workspace
    tar -czf "$file" \
        "$HOME/.config" \
        "$HOME/Workspace" \
        "$HOME/Templates" \
        "$HOME/.thunderbird" \
        "$HOME/.config/libreoffice" \
        2>/dev/null || true
        
    log_info "Configuration and workspace backed up to $file"
}

# === Uninstall Option ===
uninstall_all() {
    log_warn "This will remove all installed SME tools and shortcuts."
    read -p "Are you sure? (y/N): " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { log_info "Uninstall cancelled."; return; }

    backup_configs

    # Remove APT packages
    local packages=(
        thunderbird libreoffice gnucash gimp inkscape keepassxc veracrypt 
        deja-dup filezilla kmymoney scribus kdenlive audacity pdfarranger 
        syncthing torbrowser-launcher baobab htop glances simple-scan 
        ocrfeeder gtimelog ktimetracker hamster-time-tracker python3-pip
        nodejs npm build-essential gitk meld darktable rawtherapee
        seahorse gnome-keyring gparted timeshift stacer
    )
    
    for pkg in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii  $pkg "; then
            sudo apt remove --purge -y "$pkg" 2>/dev/null || true
        fi
    done
    
    # Clean up dependencies
    sudo apt autoremove -y --purge
    
    # Remove snaps
    sudo snap remove element-desktop 2>/dev/null || true
    sudo snap remove code 2>/dev/null || true
    
    # Remove desktop shortcuts and web app entries
    rm -f \
        "$HOME/Desktop/"*.desktop \
        "$HOME/.local/share/applications/"jitsi-meet-web.desktop \
        "$HOME/.local/share/applications/"google-meet-web.desktop
    
    log_info "Uninstall complete. Configs backed up to os-for-work-backups/"
}

# === Post-install Summary ===
show_summary() {
    log_info "=== Installation Complete ==="
    echo ""
    echo "📦 Installed Suites:"
    echo "  ✅ Productivity: LibreOffice, Thunderbird, GnuCash, GIMP, Inkscape"
    echo "  ✅ Communication: Element, Jitsi Meet, Google Meet"
    echo "  ✅ Finance: KMyMoney"
    echo "  ✅ Creative: Scribus, Kdenlive, Audacity, Darktable"
    echo "  ✅ Security: Syncthing, Tor Browser, Encryption tools"
    echo "  ✅ Utilities: System monitoring, scanning, backup tools"
    echo "  ✅ Time Tracking: gtimelog, Hamster, KTimeTracker"
    echo "  ✅ Development: VS Code, Python, Node.js, Git"
    echo ""
    echo "📁 Your Workspace:"
    echo "  Location: $HOME/Workspace/"
    echo "  Templates: $HOME/Templates/"
    echo "  Shortcuts: Created on Desktop"
    echo ""
    echo "🔧 Next Steps:"
    echo "  1. Configure Thunderbird with your email accounts"
    echo "  2. Set up GnuCash or KMyMoney for business finances"
    echo "  3. Explore the templates in ~/Templates/"
    echo "  4. Log out and back in for Snap applications to appear"
    echo ""
    echo "💼 Need team features or server setup?"
    echo "   Visit: https://your-company.com/business-hub"
    echo ""
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
    echo "6) Uninstall All"
    echo "7) Show Summary"
    echo "8) Exit"
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
            *) log_error "Invalid option." ;;
        esac
        read -p "Press Enter to continue..."
    done
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
