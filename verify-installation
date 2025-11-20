#!/bin/bash
set -euo pipefail

VERIFY_LOGFILE="$HOME/os-for-work-verify.log"
INSTALL_LOGFILE="$HOME/os-for-work-install.log"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log() {
    local level="$1"; shift
    local msg="$*"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${level}${msg}${NC}"
    echo "[$timestamp] $msg" >> "$VERIFY_LOGFILE"
}
log_info() { log "$GREEN[INFO]" "$*"; }
log_warn() { log "$YELLOW[WARN]" "$*"; }
log_error(){ log "$RED[ERROR]" "$*"; }
log_step() { log "$BLUE[STEP]" "$*"; }
log_success() { log "$GREEN[✓]" "$*"; }
log_fail() { log "$RED[✗]" "$*"; }

# === Welcome ===
clear
echo "========================================="
echo "   OS for Work - Installation Verifier"
echo "========================================="
log_info "Verifying installation completeness..."
log_info "Verification log: $VERIFY_LOGFILE"

# Counters for summary
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Verification functions
check_command() {
    local cmd="$1"
    local name="$2"
    local critical="${3:-true}"
    
    ((TOTAL_CHECKS++))
    if command -v "$cmd" >/dev/null 2>&1; then
        log_success "$name is installed"
        ((PASSED_CHECKS++))
        return 0
    else
        if [[ "$critical" == "true" ]]; then
            log_fail "$name is NOT installed"
            ((FAILED_CHECKS++))
        else
            log_warn "$name is NOT installed (optional)"
            ((WARNING_CHECKS++))
        fi
        return 1
    fi
}

check_package() {
    local pkg="$1"
    local name="$2"
    
    ((TOTAL_CHECKS++))
    if dpkg -l | grep -q "^ii  $pkg "; then
        log_success "$name (APT package) is installed"
        ((PASSED_CHECKS++))
        return 0
    else
        log_fail "$name (APT package) is NOT installed"
        ((FAILED_CHECKS++))
        return 1
    fi
}

check_snap() {
    local snap="$1"
    local name="$2"
    
    ((TOTAL_CHECKS++))
    if snap list 2>/dev/null | grep -q "^$snap "; then
        log_success "$name (Snap) is installed"
        ((PASSED_CHECKS++))
        return 0
    else
        log_fail "$name (Snap) is NOT installed"
        ((FAILED_CHECKS++))
        return 1
    fi
}

check_directory() {
    local dir="$1"
    local name="$2"
    
    ((TOTAL_CHECKS++))
    if [ -d "$dir" ]; then
        log_success "$name directory exists: $dir"
        ((PASSED_CHECKS++))
        return 0
    else
        log_fail "$name directory missing: $dir"
        ((FAILED_CHECKS++))
        return 1
    fi
}

check_file() {
    local file="$1"
    local name="$2"
    
    ((TOTAL_CHECKS++))
    if [ -f "$file" ]; then
        log_success "$name exists: $file"
        ((PASSED_CHECKS++))
        return 0
    else
        log_fail "$name missing: $file"
        ((FAILED_CHECKS++))
        return 1
    fi
}

check_desktop_file() {
    local file="$1"
    local name="$2"
    
    ((TOTAL_CHECKS++))
    if [ -f "$file" ] && [ -x "$file" ]; then
        log_success "$name desktop shortcut exists and is executable"
        ((PASSED_CHECKS++))
        return 0
    elif [ -f "$file" ] && [ ! -x "$file" ]; then
        log_warn "$name desktop shortcut exists but is not executable"
        ((WARNING_CHECKS++))
        return 1
    else
        log_fail "$name desktop shortcut missing: $file"
        ((FAILED_CHECKS++))
        return 1
    fi
}

# === Main Verification ===
verify_installation() {
    log_step "Starting comprehensive verification..."
    
    # Check installation log exists
    if [ -f "$INSTALL_LOGFILE" ]; then
        log_info "Found installation log: $INSTALL_LOGFILE"
    else
        log_warn "Installation log not found. Was the installer run?"
    fi
    
    # === Productivity Suite ===
    log_step "Verifying Productivity Suite..."
    check_command "thunderbird" "Thunderbird (Email)"
    check_command "libreoffice" "LibreOffice"
    check_command "gnucash" "GnuCash"
    check_command "gimp" "GIMP"
    check_command "inkscape" "Inkscape"
    check_command "keepassxc" "KeePassXC"
    check_command "veracrypt" "VeraCrypt"
    check_command "deja-dup" "Deja Dup Backup"
    check_command "nautilus" "Nautilus File Manager"
    check_command "filezilla" "FileZilla FTP Client"
    
    # === Communication Suite ===
    log_step "Verifying Communication Suite..."
    check_snap "element-desktop" "Element Desktop"
    check_file "$HOME/.local/share/applications/jitsi-meet-web.desktop" "Jitsi Meet Web Shortcut"
    check_file "$HOME/.local/share/applications/google-meet-web.desktop" "Google Meet Web Shortcut"
    
    # === Finance Suite ===
    log_step "Verifying Finance Suite..."
    check_command "kmymoney" "KMyMoney"
    
    # === Creative Suite ===
    log_step "Verifying Creative Suite..."
    check_command "scribus" "Scribus"
    check_command "kdenlive" "Kdenlive"
    check_command "audacity" "Audacity"
    check_command "pdfarranger" "PDF Arranger"
    check_command "darktable" "Darktable" "false"
    check_command "rawtherapee" "RawTherapee" "false"
    
    # === Security Suite ===
    log_step "Verifying Security Suite..."
    check_command "syncthing" "Syncthing"
    check_command "torbrowser-launcher" "Tor Browser Launcher"
    
    # === Utilities Suite ===
    log_step "Verifying Utilities Suite..."
    check_command "baobab" "Disk Usage Analyzer"
    check_command "htop" "HTop System Monitor"
    check_command "glances" "Glances System Monitor"
    check_command "simple-scan" "Simple Scan"
    check_command "ocrfeeder" "OCR Feeder"
    check_command "gparted" "GParted" "false"
    check_command "timeshift" "Timeshift" "false"
    check_command "stacer" "Stacer" "false"
    
    # === Time Tracking Suite ===
    log_step "Verifying Time Tracking Suite..."
    check_command "gtimelog" "GTimeLog"
    check_command "ktimetracker" "KTimeTracker" "false"
    check_command "hamster-time-tracker" "Hamster Time Tracker" "false"
    
    # === Development Tools ===
    log_step "Verifying Development Tools..."
    check_command "python3" "Python 3"
    check_command "code" "VS Code"
    check_command "node" "Node.js" "false"
    check_command "npm" "NPM" "false"
    check_command "git" "Git"
    check_command "meld" "Meld Diff Tool"
    
    # === Workspace Structure ===
    log_step "Verifying Workspace Structure..."
    check_directory "$HOME/Workspace" "Main Workspace"
    check_directory "$HOME/Workspace/Projects" "Projects Directory"
    check_directory "$HOME/Workspace/Documents" "Documents Directory"
    check_directory "$HOME/Workspace/ClientWork" "ClientWork Directory"
    check_directory "$HOME/Workspace/Administrative" "Administrative Directory"
    check_directory "$HOME/Workspace/Archive" "Archive Directory"
    check_directory "$HOME/Templates" "Templates Directory"
    
    # Check template files
    check_file "$HOME/Templates/Project_Plan.md" "Project Plan Template"
    check_file "$HOME/Templates/Meeting_Notes.md" "Meeting Notes Template"
    check_file "$HOME/Templates/Business_Invoice.csv" "Business Invoice Template"
    
    # === Desktop Shortcuts ===
    log_step "Verifying Desktop Shortcuts..."
    check_desktop_file "$HOME/Desktop/Workspace.desktop" "Workspace Shortcut"
    check_desktop_file "$HOME/Desktop/Productivity-Center.desktop" "Productivity Center Shortcut"
    
    # === System Integration ===
    log_step "Verifying System Integration..."
    check_command "snap" "Snap Package Manager"
    check_command "systemctl" "Systemd" "false"
    
    # Check if GUI applications can run (basic test)
    if [ -n "${DISPLAY:-}" ]; then
        log_step "Testing GUI application availability..."
        if command -v libreoffice >/dev/null; then
            if libreoffice --version >/dev/null 2>&1; then
                log_success "LibreOffice starts successfully"
            else
                log_warn "LibreOffice found but may have startup issues"
            fi
        fi
    fi
}

# === Generate Report ===
generate_report() {
    log_step "Generating verification report..."
    
    local success_rate=0
    if [ $TOTAL_CHECKS -gt 0 ]; then
        success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    fi
    
    echo ""
    echo "========================================="
    echo "         VERIFICATION REPORT"
    echo "========================================="
    echo "Total checks performed: $TOTAL_CHECKS"
    echo "✅ Passed: $PASSED_CHECKS"
    echo "❌ Failed: $FAILED_CHECKS"
    echo "⚠️  Warnings: $WARNING_CHECKS"
    echo "📊 Success rate: $success_rate%"
    echo ""
    
    if [ $FAILED_CHECKS -eq 0 ] && [ $WARNING_CHECKS -eq 0 ]; then
        log_success "🎉 Installation is COMPLETELY SUCCESSFUL!"
        echo ""
        echo "All essential components are installed and ready."
    elif [ $FAILED_CHECKS -eq 0 ]; then
        log_success "✅ Installation is SUCCESSFUL!"
        echo ""
        echo "All essential components are installed."
        echo "Some optional components are missing (see warnings above)."
    elif [ $FAILED_CHECKS -lt $((TOTAL_CHECKS / 4)) ]; then
        log_warn "⚠️  Installation is MOSTLY SUCCESSFUL"
        echo ""
        echo "Most essential components are installed."
        echo "Some components failed (see errors above)."
    else
        log_error "❌ Installation has ISSUES"
        echo ""
        echo "Many components failed to install."
        echo "Please check the errors above and consider re-running the installer."
    fi
    
    echo ""
    echo "📋 Detailed log: $VERIFY_LOGFILE"
    
    # Show next steps based on results
    if [ $FAILED_CHECKS -gt 0 ]; then
        echo ""
        echo "🔧 Recommended actions:"
        echo "1. Check internet connection"
        echo "2. Run 'sudo apt update' and try installer again"
        echo "3. Check specific package availability in repositories"
        echo "4. Consult installation log: $INSTALL_LOGFILE"
    fi
    
    echo "========================================="
}

# === Quick Check Option ===
quick_verify() {
    log_step "Running quick verification..."
    
    local quick_checks=(
        "thunderbird:Thunderbird"
        "libreoffice:LibreOffice" 
        "gnucash:GnuCash"
        "code:VS Code"
        "element-desktop:Element Desktop:snap"
    )
    
    local quick_total=0
    local quick_passed=0
    
    for check in "${quick_checks[@]}"; do
        IFS=':' read -r cmd name type <<< "$check"
        ((quick_total++))
        
        case "${type:-cmd}" in
            "cmd")
                if command -v "$cmd" >/dev/null; then
                    log_success "$name is installed"
                    ((quick_passed++))
                else
                    log_fail "$name is NOT installed"
                fi
                ;;
            "snap")
                if snap list 2>/dev/null | grep -q "^$cmd "; then
                    log_success "$name is installed"
                    ((quick_passed++))
                else
                    log_fail "$name is NOT installed"
                fi
                ;;
        esac
    done
    
    echo ""
    echo "Quick check: $quick_passed/$quick_total essential applications installed"
}

# === Menu ===
show_menu() {
    clear
    echo "========================================="
    echo "   OS for Work - Verification Menu"
    echo "========================================="
    echo "1) Full Comprehensive Verification"
    echo "2) Quick Essential Check" 
    echo "3) Check Specific Component"
    echo "4) View Installation Log"
    echo "5) View Verification Log"
    echo "6) Exit"
    echo "========================================="
}

check_specific_component() {
    echo ""
    echo "Available components to check:"
    echo "1) Thunderbird"
    echo "2) LibreOffice"
    echo "3) GnuCash"
    echo "4) Element Desktop"
    echo "5) VS Code"
    echo "6) Workspace Structure"
    echo "7) All Desktop Shortcuts"
    echo ""
    read -p "Choose component [1-7]: " choice
    
    case $choice in
        1) check_command "thunderbird" "Thunderbird" ;;
        2) check_command "libreoffice" "LibreOffice" ;;
        3) check_command "gnucash" "GnuCash" ;;
        4) check_snap "element-desktop" "Element Desktop" ;;
        5) check_command "code" "VS Code" ;;
        6) 
            check_directory "$HOME/Workspace" "Workspace"
            check_directory "$HOME/Templates" "Templates"
            ;;
        7)
            check_desktop_file "$HOME/Desktop/Workspace.desktop" "Workspace"
            check_desktop_file "$HOME/Desktop/Productivity-Center.desktop" "Productivity Center"
            ;;
        *) log_error "Invalid choice" ;;
    esac
}

# === Main Function ===
main() {
    while true; do
        show_menu
        read -p "Choose option [1-6]: " choice
        case $choice in
            1) 
                TOTAL_CHECKS=0; PASSED_CHECKS=0; FAILED_CHECKS=0; WARNING_CHECKS=0
                verify_installation
                generate_report
                ;;
            2) quick_verify ;;
            3) check_specific_component ;;
            4) 
                if [ -f "$INSTALL_LOGFILE" ]; then
                    less "$INSTALL_LOGFILE"
                else
                    log_error "Installation log not found: $INSTALL_LOGFILE"
                fi
                ;;
            5) 
                if [ -f "$VERIFY_LOGFILE" ]; then
                    less "$VERIFY_LOGFILE"
                else
                    log_error "Verification log not found. Run a verification first."
                fi
                ;;
            6) log_info "Exiting verifier"; exit 0 ;;
            *) log_error "Invalid option" ;;
        esac
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
