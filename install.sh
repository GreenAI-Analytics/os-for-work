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

# === Dependency Checks ===
check_dependencies() {
    log_step "Checking system dependencies..."
    for cmd in apt sudo systemctl xdg-open; do
        if ! command -v $cmd >/dev/null; then
            log_error "Missing dependency: $cmd"
            exit 1
        fi
    done
    if [ -z "${DISPLAY:-}" ] && [ -z "${XDG_CURRENT_DESKTOP:-}" ]; then
        log_error "No GUI environment detected. Please run on a desktop session."
        exit 1
    fi
    
    # Root check
    if [ "$EUID" -eq 0 ]; then
        log_error "Do not run as root. Use sudo when prompted."
        exit 1
    fi

    # OS check
    if ! grep -Eq "Ubuntu|Debian" /etc/os-release; then
        log_error "Only Debian/Ubuntu LTS supported."
        exit 1
    fi
    
    log_info "Dependencies and GUI environment verified."
}

# === System Setup ===
update_system() {
    log_step "Updating system packages..."
    sudo apt update && sudo apt -y upgrade
    log_info "System updated."
}

ensure_snap_ready() {
    if ! command -v snap >/dev/null; then
        log_step "Installing snapd..."
        sudo apt install -y snapd
    fi
    
    # Wait for snapd to be ready
    if command -v systemctl >/dev/null && systemctl is-active snapd >/dev/null 2>&1; then
        sudo systemctl enable --now snapd.socket || true
        sudo systemctl enable --now snapd || true
        sudo systemctl start snapd || true
    fi
    
    # Ensure snap directory exists
    if [ ! -d /snap ]; then
        sudo ln -s /var/lib/snapd/snap /snap 2>/dev/null || true
    fi
    
    # Add snap to PATH for current session
    export PATH="$PATH:/snap/bin"
    
    # Small delay to ensure snap is ready
    sleep 2
}

# === Installation Suites ===
install_productivity_suite() {
    log_step "Installing Productivity Suite..."
    sudo apt install -y thunderbird libreoffice libreoffice-l10n-en-gb hunspell-en-gb \
        gnucash gimp inkscape keepassxc veracrypt deja-dup git vim nautilus filezilla
    log_info "Productivity Suite installed."
}

install_communication_suite() {
    log_step "Installing Communication Suite..."
    ensure_snap_ready
    sudo snap install element-desktop
    log_info "Element Desktop installed."
    
    # Jitsi web shortcut
    local APPS_DIR="$HOME/.local/share/applications"
    mkdir -p "$APPS_DIR"
    cat > "$APPS_DIR/jitsi-meet-web.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Jitsi Meet (Web)
Exec=xdg-open https://meet.jit.si
Icon=web-browser
Terminal=false
Categories=Network;
EOF
    chmod +x "$APPS_DIR/jitsi-meet-web.desktop"
    log_info "Jitsi Meet web shortcut created."
}

install_finance_suite() {
    log_step "Installing Finance Suite..."
    sudo apt install -y kmymoney
    log_info "Finance Suite installed (GnuCash + KMyMoney)."
}

install_creative_suite() {
    log_step "Installing Creative Suite..."
    sudo apt install -y scribus kdenlive audacity pdfarranger
    log_info "Creative Suite installed (Scribus, Kdenlive, Audacity, PDF Arranger)."
}

install_security_suite() {
    log_step "Installing Security Suite..."
    sudo apt install -y syncthing torbrowser-launcher
    log_info "Security Suite installed (Syncthing + Tor Browser)."
}

install_utilities_suite() {
    log_step "Installing Utilities Suite..."
    sudo apt install -y baobab htop glances simple-scan ocrfeeder
    log_info "Utilities Suite installed."
}

install_time_tracking_suite() {
    log_step "Installing Time Tracking Suite..."
    sudo apt install -y gtimelog
    log_info "Time Tracking Suite installed."
}

install_dev_tools_suite() {
    log_step "Installing Optional Dev Tools..."
    sudo apt install -y python3 python3-pip
    ensure_snap_ready
    sudo snap install code --classic
    log_info "VS Code + Python installed."
}

# === Workplace Templates ===
setup_workspace() {
    log_step "Setting up workspace..."
    mkdir -p "$HOME/Workspace/"{Projects,Documents,ClientWork,Administrative,Archive} "$HOME/Templates"

    cat > "$HOME/Templates/Project_Plan.md" <<'EOF'
# Project Plan
- Project: [Name]
- Client: [Name]
- Timeline: [Start] - [End]
## Deliverables
- [ ] Deliverable 1
- [ ] Deliverable 2
EOF

    cat > "$HOME/Templates/Meeting_Notes.md" <<'EOF'
# Meeting Notes
Date: [Date]
Attendees: [Names]
Agenda:
- Item 1
- Item 2
Notes:
- ...
EOF

    cat > "$HOME/Templates/Business_Invoice.csv" <<'EOF'
"Invoice Number","Date","Client","Description","Quantity","Unit Price","Total","VAT","Grand Total"
EOF

    cat > "$HOME/Templates/Contract_Template.odt" <<'EOF'
Contract Template
-----------------
Parties: [Company] and [Client]
Terms:
1. ...
2. ...
EOF

    log_info "Workspace directories and templates created."
}

# === Desktop Shortcuts ===
create_desktop_shortcuts() {
    log_step "Creating desktop shortcuts..."
    local DESKTOP_DIR="$HOME/Desktop"
    mkdir -p "$DESKTOP_DIR"
    
    # Productivity Center shortcut
    cat > "$DESKTOP_DIR/Productivity-Center.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=🚀 Productivity Center
Comment=Launch Office, Email, and Business Apps
Exec=libreoffice
Icon=libreoffice-main
Terminal=false
StartupNotify=true
Categories=Office;
EOF
    
    # Workspace shortcut
    cat > "$DESKTOP_DIR/Workspace.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=📁 Open Workspace
Comment=Open your business workspace
Exec=nautilus $HOME/Workspace
Icon=folder
Terminal=false
StartupNotify=true
Categories=Utility;
EOF
    
    chmod +x "$DESKTOP_DIR"/*.desktop
    log_info "Desktop shortcuts created!"
}

# === Config Backup for Uninstall ===
backup_configs() {
    local backup_dir="$HOME/os-for-work-backups"
    mkdir -p "$backup_dir"
    local ts=$(date +%Y%m%d_%H%M%S)
    local file="$backup_dir/config_backup_$ts.tar.gz"
    tar -czf "$file" "$HOME/.config" "$HOME/Workspace" 2>/dev/null || true
    log_info "Configuration and workspace backed up to $file"
}

# === Uninstall Option ===
uninstall_all() {
    log_warn "This will remove all installed SME tools and shortcuts."
    read -p "Are you sure? (y/N): " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { log_info "Uninstall cancelled."; return; }

    backup_configs

    # Remove only installed packages to avoid errors
    local packages=(
        thunderbird libreoffice gnucash gimp inkscape keepassxc veracrypt 
        deja-dup filezilla kmymoney scribus kdenlive audacity pdfarranger 
        syncthing torbrowser-launcher baobab htop glances simple-scan 
        ocrfeeder gtimelog
    )
    
    for pkg in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii  $pkg "; then
            sudo apt remove --purge -y "$pkg" || true
        fi
    done
    
    # Remove snaps if they exist
    sudo snap remove element-desktop 2>/dev/null || true
    sudo snap remove code 2>/dev/null || true

    rm -f ~/Desktop/*.desktop ~/.local/share/applications/jitsi-meet-web.desktop
    log_info "Uninstall complete. Configs backed up."
}

# === Post-install Summary ===
show_summary() {
    log_info "=== Installation Summary ==="
    echo "- Productivity: LibreOffice, Thunderbird, GnuCash, GIMP, Inkscape, KeePassXC, VeraCrypt, Deja Dup"
    echo "- Communication: Element (Snap), Jitsi (Web)"
    echo "- Finance: KMyMoney"
    echo "- Creative: Scribus, Kdenlive, Audacity, PDF Arranger"
    echo "- Security: Syncthing, Tor Browser"
    echo "- Utilities: Baobab, htop, Glances, Simple Scan, OCRFeeder"
    echo "- Time Tracking: gtimelog"
    echo "- Optional Dev Tools: VS Code, Python3"
    echo "- Workspace: ~/Workspace + ~/Templates"
    echo "- Desktop Shortcuts: Productivity Center, Workspace"
    log_warn "Log out/in for Snap PATH changes."
    log_info "Need team features? Check out our Business Hub for multi-user solutions!"
}

# === Install Everything ===
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
    log_info "🎉 Installation complete! Check $LOGFILE for details."
}

# === Main Menu ===
show_menu() {
    clear
    echo "========================================="
    echo "   OS for Work - Installation Menu"
    echo "========================================="
    echo "1) Install Everything"
    echo "2) Setup Workspace Only" 
    echo "3) Uninstall All"
    echo "4) Show Summary"
    echo "5) Exit"
    echo "========================================="
}

main() {
    check_dependencies
    
    while true; do
        show_menu
        read -p "Choose option [1-5]: " choice
        case $choice in
            1) install_everything ;;
            2) setup_workspace ;;
            3) uninstall_all ;;
            4) show_summary ;;
            5) log_info "Exiting."; exit 0 ;;
            *) log_error "Invalid option." ;;
        esac
        read -p "Press Enter to continue..."
    done
}

# === Script Entry Point ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
