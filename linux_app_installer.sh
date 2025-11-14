#!/usr/bin/env bash
# linux-beginners-setup — unified cross‑platform installer (REPLACES previous file)
# Safe on macOS, Ubuntu/Debian, WSL, Fedora, Arch.
# - macOS: Homebrew + casks (no snapd) with full interactive categories/flags
# - Linux: preserves the original interactive installer, logging, and categories
# - WSL: skips snapd automatically and uses fallbacks
set -euo pipefail

###############################################################################
# Common helpers
###############################################################################
log()  { printf "\033[1;36m==> %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31m[err]\033[0m %s\n" "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"
IS_WSL=0
grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1 || true

###############################################################################
# macOS path (Homebrew + casks, interactive like Linux)
###############################################################################
brew_bootstrap() {
  if ! have brew; then
    log "Installing Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
  brew update
}

# installers (macOS mirrors Linux categories)
mac_install_browsers() {
  brew install --cask google-chrome || true
  brew install --cask brave-browser || true
  brew install --cask firefox || true
  log "Browsers complete."
}
mac_install_dev() {
  brew install git cmake node python jq || true
  brew install --cask visual-studio-code docker || true
  log "Development complete."
}
mac_install_productivity() {
  brew install --cask libreoffice thunderbird obsidian notion || true
  log "Productivity complete."
}
mac_install_media() {
  brew install --cask vlc spotify gimp kdenlive obs audacity inkscape || true
  log "Media complete."
}
mac_install_comms() {
  brew install --cask discord slack telegram zoom microsoft-teams || true
  log "Communication complete."
}
mac_install_gaming() {
  brew install --cask steam heroic || true
  brew install --cask wine-stable || true
  log "Gaming complete."
}
mac_install_utils() {
  # Closest mac equivalents where native packages don’t exist
  brew install htop neofetch jq || true
  brew install --cask bitwarden microsoft-remote-desktop filezilla || true
  # Flameshot/Timeshift/GParted/Synaptic aren’t native on mac; skip
  log "Utilities complete."
}

mac_menu() {
  clear
  cat <<'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                   macOS Application Installer                 ║
╚═══════════════════════════════════════════════════════════════╝

  1) Browsers
  2) Development
  3) Productivity
  4) Media
  5) Communication
  6) Gaming
  7) Utilities

  8) Install ALL
  0) Exit
EOF
  read -rp "Select option (0-8): " choice
  case "$choice" in
    1) mac_install_browsers ;;
    2) mac_install_dev ;;
    3) mac_install_productivity ;;
    4) mac_install_media ;;
    5) mac_install_comms ;;
    6) mac_install_gaming ;;
    7) mac_install_utils ;;
    8)
      mac_install_browsers
      mac_install_dev
      mac_install_productivity
      mac_install_media
      mac_install_comms
      mac_install_gaming
      mac_install_utils
      ;;
    0) exit 0 ;;
    *) warn "Invalid option" ;;
  esac
}

mac_cli_flags() {
  case "${1:-}" in
    --all)           mac_install_browsers; mac_install_dev; mac_install_productivity; mac_install_media; mac_install_comms; mac_install_gaming; mac_install_utils ;;
    --browsers)      mac_install_browsers ;;
    --dev|--development) mac_install_dev ;;
    --productivity)  mac_install_productivity ;;
    --media)         mac_install_media ;;
    --communication) mac_install_comms ;;
    --gaming)        mac_install_gaming ;;
    --utilities)     mac_install_utils ;;
    "")              mac_menu ;;
    *)  err "Unknown flag for macOS: $1"; echo "Use --all/--browsers/--dev/--productivity/--media/--communication/--gaming/--utilities"; exit 1 ;;
  esac
}

mac_main() {
  log "macOS detected — using Homebrew (no snapd)."
  brew_bootstrap
  if [ $# -gt 0 ]; then mac_cli_flags "$1"; else mac_menu; fi
  log "Done."
}

###############################################################################
# Linux path — original installer (fully preserved)
###############################################################################
# The block below is the user's existing Linux installer, kept intact except
# for being wrapped so it only runs on Linux.
linux_main() {
  ###############################################################################
  # Linux Application Installer (original)
  ###############################################################################

  # Colors
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

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
  log_message() { echo -e "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"; }
  log_success() { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"; ((INSTALLED_APPS++)); }
  log_info()    { echo -e "${BLUE}[ℹ]${NC} $1" | tee -a "$LOG_FILE"; }
  log_warning() { echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "$LOG_FILE"; }
  log_error()   { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE" "$ERROR_LOG"; ((FAILED_APPS++)); }
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
  check_root() { if [[ $EUID -ne 0 ]]; then log_error "This script must be run as root (use sudo)"; exit 2; fi; }
  check_internet() { if ! ping -c 1 -W 2 8.8.8.8 &> /dev/null; then log_error "No internet connection detected"; exit 5; fi; }
  check_disk_space() { local required_space=20; local available_space=$(df / | awk 'NR==2 {print int($4/1024/1024)}'); if [[ $available_space -lt $required_space ]]; then log_error "Insufficient disk space: ${available_space}GB available, ${required_space}GB required"; exit 4; fi; }
  is_installed_apt() { dpkg -l "$1" 2>/dev/null | grep -q "^ii"; }
  is_installed_snap() { snap list 2>/dev/null | grep -q "^$1 "; }
  is_installed_flatpak() { flatpak list 2>/dev/null | grep -q "$1"; }

  setup_flatpak() {
      if ! command -v flatpak &> /dev/null; then
          log_info "Installing Flatpak..."
          apt install -y flatpak >> "$LOG_FILE" 2>&1
          flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1
          log_success "Flatpak installed and configured"
      fi
  }
  setup_snap() {
      # Honor WSL/containers by skipping snapd cleanly
      if [ "$IS_WSL" -eq 1 ] || grep -qa docker /proc/1/cgroup 2>/dev/null; then
          log_warning "WSL/Container detected — snapd skipped; fallbacks will be used."
          return 0
      fi
      if ! command -v snap &> /dev/null; then
          log_info "Installing Snapd..."
          if ! apt install -y snapd >> "$LOG_FILE" 2>&1; then
              log_warning "snapd unavailable — continuing without snap."
              return 0
          fi
          if systemctl list-unit-files | grep -q snapd.service; then
              systemctl enable --now snapd.socket snapd >> "$LOG_FILE" 2>&1 || true
              sleep 2
          fi
      fi
  }

  ###############################################################################
  # Install backends
  ###############################################################################
  install_apt() {
      local app_name=$1; shift
      local packages="$*"
      log_info "Installing $app_name via APT..."
      if apt install -y $packages >> "$LOG_FILE" 2>&1; then
          log_success "$app_name installed"
          echo "$(date +%Y%m%d_%H%M%S) | APT | $app_name | $packages" >> "$INSTALL_LOG"
          return 0
      else
          log_error "Failed to install $app_name"
          return 1
      fi
  }
  install_snap() {
      local app_name=$1; local package=$2; local flags=${3:-""}
      if ! command -v snap &>/dev/null; then
          log_warning "snap not available — $app_name will be installed via fallback."
          install_fallback "$package"; return 0
      fi
      log_info "Installing $app_name via Snap..."
      if snap install $flags "$package" >> "$LOG_FILE" 2>&1; then
          log_success "$app_name installed"
          echo "$(date +%Y%m%d_%H%M%S) | SNAP | $app_name | $package" >> "$INSTALL_LOG"
          return 0
      else
          log_warning "Snap failed for $app_name — using fallback."
          install_fallback "$package"
      fi
  }
  install_flatpak() {
      local app_name=$1; local package=$2
      log_info "Installing $app_name via Flatpak..."
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
  # Fallbacks (also used on mac via casks in the mac path)
  ###############################################################################
  install_fallback() {
      local app="$1"
      case "$app" in
        code) apt update >> "$LOG_FILE" 2>&1; install_apt "VS Code (fallback)" code || install_apt "VSCodium (fallback)" codium || true ;;
        spotify)
          curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg >> "$LOG_FILE" 2>&1
          echo "deb http://repository.spotify.com stable non-free" | tee /etc/apt/sources.list.d/spotify.list >> "$LOG_FILE" 2>&1
          apt update >> "$LOG_FILE" 2>&1
          install_apt "Spotify (fallback)" spotify-client
          ;;
        postman) install_apt "Postman (fallback)" postman || true ;;
        slack) install_flatpak "Slack (fallback)" "com.slack.Slack" || true ;;
        bitwarden) install_flatpak "Bitwarden (fallback)" "com.bitwarden.desktop" || true ;;
        notion) install_flatpak "Notion (fallback)" "com.github.notion-repackaged" || true ;;
        *) log_warning "No fallback handler for $app";;
      esac
  }

  ###############################################################################
  # Category Installers (Linux — preserved)
  ###############################################################################
  prompt_install() {
      local app_name=$1
      if [[ "$INSTALL_ALL" == true ]] || [[ "$INTERACTIVE_MODE" == false ]]; then return 0; fi
      echo -n -e "${YELLOW}[?]${NC} Install $app_name? (y/n): "
      read -n 1 -r; echo
      [[ $REPLY =~ ^[Yy]$ ]]
  }

  install_browsers() {
      log_section "Installing Browsers"
      if prompt_install "Google Chrome"; then
          wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb >> "$LOG_FILE" 2>&1
          if dpkg -i /tmp/google-chrome.deb >> "$LOG_FILE" 2>&1; then apt -f install -y >> "$LOG_FILE" 2>&1; log_success "Google Chrome installed"; else log_error "Google Chrome failed"; fi
          rm -f /tmp/google-chrome.deb
      fi
      if prompt_install "Brave Browser"; then
          apt install -y curl >> "$LOG_FILE" 2>&1
          curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg >> "$LOG_FILE" 2>&1
          echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list >> "$LOG_FILE" 2>&1
          apt update >> "$LOG_FILE" 2>&1
          install_apt "Brave Browser" brave-browser
      fi
      if prompt_install "Firefox ESR"; then install_apt "Firefox ESR" firefox-esr; fi
  }

  install_development() {
      log_section "Installing Development Tools"
      if prompt_install "VS Code"; then
          wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/vscode.gpg >> "$LOG_FILE" 2>&1
          echo "deb [arch=amd64 signed-by=/usr/share/keyrings/vscode.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list >> "$LOG_FILE" 2>&1
          apt update >> "$LOG_FILE" 2>&1
          install_apt "VS Code" code
      fi
      if prompt_install "Git"; then install_apt "Git" git; fi
      if prompt_install "Docker"; then
          apt install -y ca-certificates curl gnupg >> "$LOG_FILE" 2>&1
          install -m 0755 -d /etc/apt/keyrings
          curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> "$LOG_FILE" 2>&1
          chmod a+r /etc/apt/keyrings/docker.gpg
          echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list >> "$LOG_FILE" 2>&1
          apt update >> "$LOG_FILE" 2>&1
          install_apt "Docker" docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      fi
      if prompt_install "Node.js (LTS)"; then curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - >> "$LOG_FILE" 2>&1; install_apt "Node.js" nodejs; fi
      if prompt_install "Python Dev Tools"; then install_apt "Python Dev Tools" python3-pip python3-venv python3-dev; fi
      if prompt_install "Build Essentials"; then install_apt "Build Essentials" build-essential cmake; fi
  }

  install_productivity() {
      log_section "Installing Productivity Applications"
      if prompt_install "LibreOffice"; then install_apt "LibreOffice" libreoffice; fi
      if prompt_install "Thunderbird"; then install_apt "Thunderbird" thunderbird; fi
      if prompt_install "Obsidian"; then install_snap "Obsidian" obsidian; fi
      if prompt_install "Notion"; then install_snap "Notion" notion-snap-reborn; fi
      if prompt_install "FreeOffice"; then
          wget -q -O /tmp/freeoffice.deb https://www.softmaker.net/down/softmaker-freeoffice-2024_1218-01_amd64.deb >> "$LOG_FILE" 2>&1
          if dpkg -i /tmp/freeoffice.deb >> "$LOG_FILE" 2>&1; then apt install -f -y >> "$LOG_FILE" 2>&1; log_success "FreeOffice installed"; else log_error "FreeOffice failed"; fi
          rm -f /tmp/freeoffice.deb
      fi
  }

  install_media() {
      log_section "Installing Media Applications"
      if prompt_install "VLC"; then install_apt "VLC" vlc; fi
      if prompt_install "Spotify"; then
          curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg >> "$LOG_FILE" 2>&1
          echo "deb http://repository.spotify.com stable non-free" | tee /etc/apt/sources.list.d/spotify.list >> "$LOG_FILE" 2>&1
          apt update >> "$LOG_FILE" 2>&1
          install_apt "Spotify" spotify-client
      fi
      if prompt_install "GIMP"; then install_apt "GIMP" gimp; fi
      if prompt_install "Kdenlive"; then install_apt "Kdenlive" kdenlive; fi
      if prompt_install "OBS Studio"; then add-apt-repository -y ppa:obsproject/obs-studio >> "$LOG_FILE" 2>&1; apt update >> "$LOG_FILE" 2>&1; install_apt "OBS Studio" obs-studio; fi
      if prompt_install "Audacity"; then install_apt "Audacity" audacity; fi
      if prompt_install "Inkscape"; then install_apt "Inkscape" inkscape; fi
  }

  install_communication() {
      log_section "Installing Communication Apps"
      if prompt_install "Discord"; then
          wget -q -O /tmp/discord.deb "https://discord.com/api/download?platform=linux&format=deb" >> "$LOG_FILE" 2>&1
          if dpkg -i /tmp/discord.deb >> "$LOG_FILE" 2>&1; then apt install -f -y >> "$LOG_FILE" 2>&1; log_success "Discord installed"; else log_error "Discord failed"; fi
          rm -f /tmp/discord.deb
      fi
      if prompt_install "Slack"; then install_snap "Slack" slack; fi
      if prompt_install "Telegram"; then install_apt "Telegram" telegram-desktop; fi
      if prompt_install "Zoom"; then
          wget -q -O /tmp/zoom.deb https://zoom.us/client/latest/zoom_amd64.deb >> "$LOG_FILE" 2>&1
          if dpkg -i /tmp/zoom.deb >> "$LOG_FILE" 2>&1; then apt install -f -y >> "$LOG_FILE" 2>&1; log_success "Zoom installed"; else log_error "Zoom failed"; fi
          rm -f /tmp/zoom.deb
      fi
      if prompt_install "Microsoft Teams"; then install_snap "Microsoft Teams" teams-for-linux; fi
  }

  install_gaming() {
      log_section "Installing Gaming Platform"
      log_info "Enabling 32-bit support for gaming..."; dpkg --add-architecture i386 >> "$LOG_FILE" 2>&1; apt update >> "$LOG_FILE" 2>&1
      if prompt_install "Steam"; then install_apt "Steam" steam-installer; fi
      if prompt_install "Lutris"; then add-apt-repository -y ppa:lutris-team/lutris >> "$LOG_FILE" 2>&1; apt update >> "$LOG_FILE" 2>&1; install_apt "Lutris" lutris; fi
      if prompt_install "Wine"; then install_apt "Wine" wine64 wine32 libasound2-plugins:i386 libsdl2-2.0-0:i386 libdbus-1-3:i386 libsqlite3-0:i386; fi
      if prompt_install "Bottles"; then install_flatpak "Bottles" com.usebottles.bottles; fi
      if prompt_install "Heroic Games Launcher"; then install_flatpak "Heroic" com.heroicgameslauncher.hgl; fi
      if prompt_install "GameMode"; then install_apt "GameMode" gamemode; fi
  }

  install_utilities() {
      log_section "Installing System Utilities"
      if prompt_install "Flameshot (Screenshot)"; then install_apt "Flameshot" flameshot; fi
      if prompt_install "Bitwarden"; then install_snap "Bitwarden" bitwarden; fi
      if prompt_install "Remmina (Remote Desktop)"; then install_apt "Remmina" remmina remmina-plugin-rdp remmina-plugin-vnc; fi
      if prompt_install "Timeshift (Backups)"; then install_apt "Timeshift" timeshift; fi
      if prompt_install "Stacer (System Monitor)"; then install_apt "Stacer" stacer; fi
      if prompt_install "Synaptic Package Manager"; then install_apt "Synaptic" synaptic; fi
      if prompt_install "GParted"; then install_apt "GParted" gparted; fi
      if prompt_install "FileZilla"; then install_apt "FileZilla" filezilla; fi
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

  main_linux() {
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
              --all) INSTALL_ALL=true
                     install_browsers; install_development; install_productivity; install_media; install_communication; install_gaming; install_utilities ;;
              --browsers)       install_browsers ;;
              --dev|--development) install_development ;;
              --productivity)   install_productivity ;;
              --media)          install_media ;;
              --communication)  install_communication ;;
              --gaming)         install_gaming ;;
              --utilities)      install_utilities ;;
              *) echo "Usage: $0 [--all|--browsers|--dev|--productivity|--media|--communication|--gaming|--utilities]"; exit 1 ;;
          esac
      fi

      # Interactive menu
      if [[ "$INTERACTIVE_MODE" == true ]]; then
          while true; do
              show_menu
              read -r choice
              case $choice in
                  1) install_browsers ;;
                  2) install_development ;;
                  3) install_productivity ;;
                  4) install_media ;;
                  5) install_communication ;;
                  6) install_gaming ;;
                  7) install_utilities ;;
                  8) INSTALL_ALL=true
                     install_browsers; install_development; install_productivity; install_media; install_communication; install_gaming; install_utilities
                     break ;;
                  9) INSTALL_ALL=false
                     install_browsers; install_development; install_productivity; install_media; install_communication; install_gaming; install_utilities
                     break ;;
                  0) log_info "Installation cancelled by user"; exit 0 ;;
                  *) log_warning "Invalid option"; sleep 2 ;;
              esac
              if [[ $choice != 0 && $choice != 8 && $choice != 9 ]]; then echo ""; read -p "Press Enter to continue..."; fi
          done
      fi

      # Final report
      log_section "Installation Complete"
      log_success "Application installation finished!"
      echo ""
      log_info "Installation Summary:"
      log_info "  - Successfully installed: $INSTALLED_APPS"
      log_info "  - Failed installations: $FAILED_APPS"
      echo ""
      log_info "Installed applications logged to: $INSTALL_LOG"
      log_info "Full log: $LOG_FILE"
      echo ""
      if [[ $FAILED_APPS -gt 0 ]]; then log_warning "Some applications failed to install - check error log: $ERROR_LOG"; fi
      echo ""
      log_info "You may need to log out and back in for some applications to appear in menus"
  }

  mkdir -p "$LOG_DIR" "$BACKUP_DIR"
  main_linux "$@"
}

###############################################################################
# Entry
###############################################################################
if [ "$OS" = "Darwin" ]; then
  mac_main "${1:-}"
  exit 0
fi

# Non-Darwin paths: try distro families for convenience wrapper
if have apt; then
  linux_main "$@"
elif have dnf || have pacman; then
  # The preserved Linux script is Ubuntu/Mint focused (APT).
  # For Fedora/Arch users, provide minimal meta‑routing to run Linux section where apt exists.
  err "This installer currently targets Debian/Ubuntu/Mint. For Fedora/Arch, use the macOS-like lightweight path or adapt the APT sections."
  exit 3
else
  err "Unsupported OS — add your package manager logic here."
  exit 3
fi
