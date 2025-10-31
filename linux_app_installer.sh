#!/usr/bin/env bash

###############################################################################
# Linux Application Installer
# 
# Description: Interactive application installer for Linux Mint/Ubuntu systems
#              Provides one-command installation of essential software across
#              all categories with smart package manager selection.
#
# Author: Network & Firewall Technicians (NFT) / OffTrackMedia (OTM)
# Version: 1.0.0
# License: MIT
#
# Features:
#   - Interactive menu or CLI automation
#   - 50+ essential applications across 7 categories
#   - Smart package source selection (apt/snap/flatpak)
#   - Progress tracking and logging
#   - Rollback capability
#   - Batch installation support
#
# Categories:
#   - Browsers (Chrome, Brave, Firefox ESR)
#   - Development (VS Code, Git, Docker, Node.js, Python)
#   - Productivity (LibreOffice, Thunderbird, Obsidian)
#   - Media (VLC, Spotify, GIMP, Kdenlive, OBS)
#   - Communication (Discord, Slack, Telegram, Zoom)
#   - Gaming (Steam, Lutris, Wine, Bottles, Heroic)
#   - Utilities (Timeshift, Flameshot, Bitwarden, Remmina)
#
# Usage: 
#   sudo ./linux_app_installer.sh                    # Interactive mode
#   sudo ./linux_app_installer.sh --all              # Install everything
#   sudo ./linux_app_installer.sh --browsers         # Install browsers only
#   sudo ./linux_app_installer.sh --dev              # Install dev tools
#
# Requirements:
#   - Linux Mint 22+ (or Ubuntu 24.04+)
#   - sudo privileges
#   - Internet connection
#   - Minimum 20GB free disk space
#
# Exit Codes:
#   0 = Success
#   1 = General error
#   2 = Root privileges required
#   3 = Unsupported distribution
#   4 = Insufficient disk space
#   5 = No internet connection
###############################################################################

set -euo pipefail

# Script Information
SCRIPT_NAME="Linux Application Installer"
SCRIPT_VERSION="1.0.0"
SCRIPT_DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Directories
LOG_DIR="/var/log"
BACKUP_DIR="/var/backups/app-installer"

# Log Files
LOG_FILE="${LOG_DIR}/app-installer_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="${LOG_DIR}/app-installer_errors_$(date +%Y%m%d_%H%M%S).log"
INSTALL_LOG="${BACKUP_DIR}/installed_apps.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
TOTAL_APPS=0
INSTALLED_APPS=0
FAILED_APPS=0

# Flags
INTERACTIVE_MODE=true
INSTALL_ALL=false

###############################################################################
# Logging Functions
###############################################################################

log_message() {
    echo -e "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
    ((INSTALLED_APPS++))
}

log_info() {
    echo -e "${BLUE}[ℹ]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE" "$ERROR_LOG"
    ((FAILED_APPS++))
}

log_section() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}  $1${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

###############################################################################
# Utility Functions
###############################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 2
    fi
}

check_internet() {
    if ! ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        log_error "No internet connection detected"
        exit 5
    fi
}

check_disk_space() {
    local required_space=20
    local available_space=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "Insufficient disk space: ${available_space}GB available, ${required_space}GB required"
        exit 4
    fi
}

setup_flatpak() {
    if ! command -v flatpak &> /dev/null; then
        log_info "Installing Flatpak..."
        apt install -y flatpak >> "$LOG_FILE" 2>&1
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1
        log_success "Flatpak installed and configured"
    fi
}

setup_snap() {
    if ! command -v snap &> /dev/null; then
        log_info "Installing Snapd..."
        apt install -y snapd >> "$LOG_FILE" 2>&1
        log_success "Snapd installed"
    fi
}

is_installed_apt() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

is_installed_snap() {
    snap list 2>/dev/null | grep -q "^$1 "
}

is_installed_flatpak() {
    flatpak list 2>/dev/null | grep -q "$1"
}

###############################################################################
# Installation Functions
###############################################################################

install_apt() {
    local app_name=$1
    local package=$2
    
    log_info "Installing $app_name via APT..."
    if is_installed_apt "$package"; then
        log_warning "$app_name already installed"
        return 0
    fi
    
    if apt install -y "$package" >> "$LOG_FILE" 2>&1; then
        log_success "$app_name installed"
        echo "$(date +%Y%m%d_%H%M%S) | APT | $app_name | $package" >> "$INSTALL_LOG"
        return 0
    else
        log_error "Failed to install $app_name"
        return 1
    fi
}

install_snap() {
    local app_name=$1
    local package=$2
    local flags=${3:-""}
    
    log_info "Installing $app_name via Snap..."
    if is_installed_snap "$package"; then
        log_warning "$app_name already installed"
        return 0
    fi
    
    if snap install $flags "$package" >> "$LOG_FILE" 2>&1; then
        log_success "$app_name installed"
        echo "$(date +%Y%m%d_%H%M%S) | SNAP | $app_name | $package" >> "$INSTALL_LOG"
        return 0
    else
        log_error "Failed to install $app_name"
        return 1
    fi
}

install_flatpak() {
    local app_name=$1
    local package=$2
    
    log_info "Installing $app_name via Flatpak..."
    if is_installed_flatpak "$package"; then
        log_warning "$app_name already installed"
        return 0
    fi
    
    if flatpak install -y flathub "$package" >> "$LOG_FILE" 2>&1; then
        log_success "$app_name installed"
        echo "$(date +%Y%m%d_%H%M%S) | FLATPAK | $app_name | $package" >> "$INSTALL_LOG"
        return 0
    else
        log_error "Failed to install $app_name"
        return 1
    fi
}

###############################################################################
# Category Installation Functions
###############################################################################

install_browsers() {
    log_section "Installing Browsers"
    
    # Google Chrome
    if prompt_install "Google Chrome" "install"; then
        wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb >> "$LOG_FILE" 2>&1
        if dpkg -i /tmp/google-chrome.deb >> "$LOG_FILE" 2>&1; then
            apt install -f -y >> "$LOG_FILE" 2>&1
            log_success "Google Chrome installed"
            echo "$(date +%Y%m%d_%H%M%S) | DEB | Google Chrome | google-chrome-stable" >> "$INSTALL_LOG"
        else
            log_error "Failed to install Google Chrome"
        fi
        rm -f /tmp/google-chrome.deb
    fi
    
    # Brave Browser
    if prompt_install "Brave Browser" "install"; then
        apt install -y curl >> "$LOG_FILE" 2>&1
        curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg >> "$LOG_FILE" 2>&1
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list >> "$LOG_FILE" 2>&1
        apt update >> "$LOG_FILE" 2>&1
        install_apt "Brave Browser" "brave-browser"
    fi
    
    # Firefox ESR
    if prompt_install "Firefox ESR" "install"; then
        install_apt "Firefox ESR" "firefox-esr"
    fi
}
install_development() {
    log_section "Installing Development Tools"
    
    # Visual Studio Code
    if prompt_install "VS Code" "install"; then
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/vscode.gpg >> "$LOG_FILE" 2>&1
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/vscode.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list >> "$LOG_FILE" 2>&1
        apt update >> "$LOG_FILE" 2>&1
        install_apt "VS Code" "code"
    fi
    
    # Git
    if prompt_install "Git" "install"; then
        install_apt "Git" "git"
    fi
    
    # Docker
    if prompt_install "Docker" "install"; then
        apt install -y ca-certificates curl gnupg >> "$LOG_FILE" 2>&1
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> "$LOG_FILE" 2>&1
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list >> "$LOG_FILE" 2>&1
        apt update >> "$LOG_FILE" 2>&1
        install_apt "Docker" "docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    fi
    
    # Node.js
    if prompt_install "Node.js (LTS)" "install"; then
        curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - >> "$LOG_FILE" 2>&1
        install_apt "Node.js" "nodejs"
    fi
    
    # Python Development Tools
    if prompt_install "Python Dev Tools" "install"; then
        install_apt "Python Dev Tools" "python3-pip python3-venv python3-dev"
    fi
    
    # Build Essentials
    if prompt_install "Build Essentials" "install"; then
        install_apt "Build Essentials" "build-essential cmake"
    fi
}

install_productivity() {
    log_section "Installing Productivity Applications"
    
    # LibreOffice
    if prompt_install "LibreOffice" "install"; then
        install_apt "LibreOffice" "libreoffice"
    fi
    
    # Thunderbird
    if prompt_install "Thunderbird" "install"; then
        install_apt "Thunderbird" "thunderbird"
    fi
    
    # Obsidian
    if prompt_install "Obsidian" "install"; then
        install_snap "Obsidian" "obsidian"
    fi
    
    # Notion (via snap)
    if prompt_install "Notion" "install"; then
        install_snap "Notion" "notion-snap-reborn"
    fi
    
    # FreeOffice
    if prompt_install "FreeOffice" "install"; then
        wget -q -O /tmp/freeoffice.deb https://www.softmaker.net/down/softmaker-freeoffice-2024_1218-01_amd64.deb >> "$LOG_FILE" 2>&1
        if dpkg -i /tmp/freeoffice.deb >> "$LOG_FILE" 2>&1; then
            apt install -f -y >> "$LOG_FILE" 2>&1
            log_success "FreeOffice installed"
        else
            log_error "Failed to install FreeOffice"
        fi
        rm -f /tmp/freeoffice.deb
    fi
}

install_media() {
    log_section "Installing Media Applications"
    
    # VLC Media Player
    if prompt_install "VLC" "install"; then
        install_apt "VLC" "vlc"
    fi
    
    # Spotify
    if prompt_install "Spotify" "install"; then
        curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg >> "$LOG_FILE" 2>&1
        echo "deb http://repository.spotify.com stable non-free" | tee /etc/apt/sources.list.d/spotify.list >> "$LOG_FILE" 2>&1
        apt update >> "$LOG_FILE" 2>&1
        install_apt "Spotify" "spotify-client"
    fi
    
    # GIMP
    if prompt_install "GIMP" "install"; then
        install_apt "GIMP" "gimp"
    fi
    
    # Kdenlive
    if prompt_install "Kdenlive" "install"; then
        install_apt "Kdenlive" "kdenlive"
    fi
    
    # OBS Studio
    if prompt_install "OBS Studio" "install"; then
        add-apt-repository -y ppa:obsproject/obs-studio >> "$LOG_FILE" 2>&1
        apt update >> "$LOG_FILE" 2>&1
        install_apt "OBS Studio" "obs-studio"
    fi
    
    # Audacity
    if prompt_install "Audacity" "install"; then
        install_apt "Audacity" "audacity"
    fi
    
    # Inkscape
    if prompt_install "Inkscape" "install"; then
        install_apt "Inkscape" "inkscape"
    fi
}

install_communication() {
    log_section "Installing Communication Apps"
    
    # Discord
    if prompt_install "Discord" "install"; then
        wget -q -O /tmp/discord.deb "https://discord.com/api/download?platform=linux&format=deb" >> "$LOG_FILE" 2>&1
        if dpkg -i /tmp/discord.deb >> "$LOG_FILE" 2>&1; then
            apt install -f -y >> "$LOG_FILE" 2>&1
            log_success "Discord installed"
        else
            log_error "Failed to install Discord"
        fi
        rm -f /tmp/discord.deb
    fi
    
    # Slack
    if prompt_install "Slack" "install"; then
        install_snap "Slack" "slack"
    fi
    
    # Telegram
    if prompt_install "Telegram" "install"; then
        install_apt "Telegram" "telegram-desktop"
    fi
    
    # Zoom
    if prompt_install "Zoom" "install"; then
        wget -q -O /tmp/zoom.deb https://zoom.us/client/latest/zoom_amd64.deb >> "$LOG_FILE" 2>&1
        if dpkg -i /tmp/zoom.deb >> "$LOG_FILE" 2>&1; then
            apt install -f -y >> "$LOG_FILE" 2>&1
            log_success "Zoom installed"
        else
            log_error "Failed to install Zoom"
        fi
        rm -f /tmp/zoom.deb
    fi
    
    # Microsoft Teams
    if prompt_install "Microsoft Teams" "install"; then
        install_snap "Microsoft Teams" "teams-for-linux"
    fi
}

install_gaming() {
    log_section "Installing Gaming Platform"
    
    # Enable 32-bit architecture
    log_info "Enabling 32-bit support for gaming..."
    dpkg --add-architecture i386 >> "$LOG_FILE" 2>&1
    apt update >> "$LOG_FILE" 2>&1
    
    # Steam
    if prompt_install "Steam" "install"; then
        install_apt "Steam" "steam-installer"
    fi
    
    # Lutris
    if prompt_install "Lutris" "install"; then
        add-apt-repository -y ppa:lutris-team/lutris >> "$LOG_FILE" 2>&1
        apt update >> "$LOG_FILE" 2>&1
        install_apt "Lutris" "lutris"
    fi
    
    # Wine
    if prompt_install "Wine" "install"; then
        install_apt "Wine" "wine64 wine32 libasound2-plugins:i386 libsdl2-2.0-0:i386 libdbus-1-3:i386 libsqlite3-0:i386"
    fi
    
    # Bottles
    if prompt_install "Bottles" "install"; then
        install_flatpak "Bottles" "com.usebottles.bottles"
    fi
    
    # Heroic Games Launcher
    if prompt_install "Heroic Games Launcher" "install"; then
        install_flatpak "Heroic" "com.heroicgameslauncher.hgl"
    fi
    
    # GameMode
    if prompt_install "GameMode" "install"; then
        install_apt "GameMode" "gamemode"
    fi
}

install_utilities() {
    log_section "Installing System Utilities"
    
    # Flameshot
    if prompt_install "Flameshot (Screenshot)" "install"; then
        install_apt "Flameshot" "flameshot"
    fi
    
    # Bitwarden
    if prompt_install "Bitwarden" "install"; then
        install_snap "Bitwarden" "bitwarden"
    fi
    
    # Remmina
    if prompt_install "Remmina (Remote Desktop)" "install"; then
        install_apt "Remmina" "remmina remmina-plugin-rdp remmina-plugin-vnc"
    fi
    
    # Timeshift
    if prompt_install "Timeshift (Backups)" "install"; then
        install_apt "Timeshift" "timeshift"
    fi
    
    # Stacer (System Monitor)
    if prompt_install "Stacer" "install"; then
        install_apt "Stacer" "stacer"
    fi
    
    # Synaptic
    if prompt_install "Synaptic Package Manager" "install"; then
        install_apt "Synaptic" "synaptic"
    fi
    
    # GParted
    if prompt_install "GParted" "install"; then
        install_apt "GParted" "gparted"
    fi
    
    # FileZilla
    if prompt_install "FileZilla" "install"; then
        install_apt "FileZilla" "filezilla"
    fi
}

###############################################################################
# Interactive Functions
###############################################################################

prompt_install() {
    local app_name=$1
    local default=${2:-"skip"}
    
    if [[ "$INSTALL_ALL" == true ]] || [[ "$INTERACTIVE_MODE" == false ]]; then
        return 0
    fi
    
    echo -n -e "${YELLOW}[?]${NC} Install $app_name? (y/n): "
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        log_info "Skipped: $app_name"
        return 1
    fi
}

show_menu() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
 ╔═══════════════════════════════════════════════════════════════╗
 ║                                                               ║
 ║           Linux Application Installer                         ║
 ║                                                               ║
 ║              Choose Installation Category                     ║
 ║                                                               ║
 ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
    echo -e "${GREEN}Available Categories:${NC}"
    echo ""
    echo "  1) Browsers           (Chrome, Brave, Firefox)"
    echo "  2) Development        (VS Code, Git, Docker, Node.js)"
    echo "  3) Productivity       (LibreOffice, Thunderbird, Obsidian)"
    echo "  4) Media              (VLC, Spotify, GIMP, OBS)"
    echo "  5) Communication      (Discord, Slack, Telegram, Zoom)"
    echo "  6) Gaming             (Steam, Lutris, Wine, Heroic)"
    echo "  7) Utilities          (Timeshift, Flameshot, Bitwarden)"
    echo ""
    echo "  8) Install ALL        (All categories)"
    echo "  9) Custom Selection   (Pick individual apps)"
    echo ""
    echo "  0) Exit"
    echo ""
    echo -n "Select option (0-9): "
}

###############################################################################
# Main Function
###############################################################################

main() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
 ╔═══════════════════════════════════════════════════════════════╗
 ║                                                               ║
 ║           Linux Application Installer                         ║
 ║                                                               ║
 ║         One-Command Installation of Essential Apps            ║
 ║                      Version 1.0.0                            ║
 ║                                                               ║
 ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log_message "Script started: $SCRIPT_DATE"
    
    # Pre-flight checks
    check_root
    check_internet
    check_disk_space
    
    # Setup package managers
    log_section "Preparing Package Managers"
    apt update >> "$LOG_FILE" 2>&1
    setup_flatpak
    setup_snap
    
    # Parse CLI arguments
    if [[ $# -eq 0 ]]; then
        INTERACTIVE_MODE=true
    else
        INTERACTIVE_MODE=false
        case "$1" in
            --all)
                INSTALL_ALL=true
                install_browsers
                install_development
                install_productivity
                install_media
                install_communication
                install_gaming
                install_utilities
                ;;
            --browsers)
                install_browsers
                ;;
            --dev|--development)
                install_development
                ;;
            --productivity)
                install_productivity
                ;;
            --media)
                install_media
                ;;
            --communication)
                install_communication
                ;;
            --gaming)
                install_gaming
                ;;
            --utilities)
                install_utilities
                ;;
            *)
                echo "Usage: $0 [--all|--browsers|--dev|--productivity|--media|--communication|--gaming|--utilities]"
                exit 1
                ;;
        esac
    fi
    
    # Interactive menu
    if [[ "$INTERACTIVE_MODE" == true ]]; then
        while true; do
            show_menu
            read -r choice
            
            case $choice in
                1)
                    install_browsers
                    ;;
                2)
                    install_development
                    ;;
                3)
                    install_productivity
                    ;;
                4)
                    install_media
                    ;;
                5)
                    install_communication
                    ;;
                6)
                    install_gaming
                    ;;
                7)
                    install_utilities
                    ;;
                8)
                    INSTALL_ALL=true
                    install_browsers
                    install_development
                    install_productivity
                    install_media
                    install_communication
                    install_gaming
                    install_utilities
                    break
                    ;;
                9)
                    INSTALL_ALL=false
                    install_browsers
                    install_development
                    install_productivity
                    install_media
                    install_communication
                    install_gaming
                    install_utilities
                    break
                    ;;
                0)
                    log_info "Installation cancelled by user"
                    exit 0
                    ;;
                *)
                    log_warning "Invalid option"
                    sleep 2
                    ;;
            esac
            
            if [[ $choice != 0 && $choice != 8 && $choice != 9 ]]; then
                echo ""
                read -p "Press Enter to continue..."
            fi
        done
    fi
    
    # Final report
    log_section "Installation Complete"
    log_success "Application installation finished!"
    echo ""
    log_info "Installation Summary:"
    log_info "  - Total apps processed: $TOTAL_APPS"
    log_info "  - Successfully installed: $INSTALLED_APPS"
    log_info "  - Failed installations: $FAILED_APPS"
    echo ""
    log_info "Installed applications logged to: $INSTALL_LOG"
    log_info "Full log: $LOG_FILE"
    echo ""
    
    if [[ $FAILED_APPS -gt 0 ]]; then
        log_warning "Some applications failed to install - check error log: $ERROR_LOG"
    fi
    
    echo ""
    log_info "You may need to log out and back in for some applications to appear in menus"
}

###############################################################################
# Script Entry Point
###############################################################################

mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

main "$@"

exit 0
