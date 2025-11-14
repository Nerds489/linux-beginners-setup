#!/usr/bin/env bash
# linux-beginners-setup — cross-platform installer
# Safe on macOS, Ubuntu/Debian, WSL, Fedora, Arch.

set -euo pipefail

log()  { printf "\033[1;36m==> %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31m[err]\033[0m %s\n" "$*" >&2; }

OS="$(uname -s)"
IS_WSL=0
grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1 || true

have() { command -v "$1" >/dev/null 2>&1; }

APT_PKGS=(curl git htop vim neofetch)
DNF_PKGS=(curl git htop vim neofetch)
PAC_PKGS=(curl git htop vim neofetch)
BREW_PKGS=(curl git htop vim neofetch)

SNAP_APPS=(code spotify postman)

install_fallback() {
  app="$1"
  case "$app" in
    code)
      if [ "$OS" = "Darwin" ]; then
        brew install --cask visual-studio-code
      elif have apt; then
        sudo apt-get update -y
        sudo apt-get install -y code || sudo apt-get install -y codium || true
      elif have dnf; then
        sudo dnf install -y code || sudo dnf install -y codium || true
      elif have pacman; then
        sudo pacman -Sy --noconfirm code || sudo pacman -Sy --noconfirm vscodium-bin || true
      fi
      ;;
    spotify)
      if [ "$OS" = "Darwin" ]; then
        brew install --cask spotify
      elif have apt; then
        curl -fsSL https://download.spotify.com/debian/pubkey_5E3C45D7B312C643.gpg | \
          sudo gpg --dearmor -o /usr/share/keyrings/spotify.gpg
        echo "deb [signed-by=/usr/share/keyrings/spotify.gpg] http://repository.spotify.com stable non-free" | \
          sudo tee /etc/apt/sources.list.d/spotify.list >/dev/null
        sudo apt-get update -y && sudo apt-get install -y spotify-client || true
      elif have dnf; then
        sudo dnf copr enable -y kwizart/spotify || true
        sudo dnf install -y spotify || true
      elif have pacman; then
        yay -S --noconfirm spotify || true
      fi
      ;;
    postman)
      if [ "$OS" = "Darwin" ]; then
        brew install --cask postman
      elif have apt; then
        sudo apt-get install -y postman || true
      elif have dnf; then
        sudo dnf install -y postman || true
      elif have pacman; then
        yay -S --noconfirm postman-bin || true
      fi
      ;;
    *)
      warn "No fallback handler for $app"
      ;;
  esac
}

install_macos() {
  log "macOS detected — using Homebrew."
  if ! have brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
  brew update
  brew install "${BREW_PKGS[@]}" || true

  # Snap apps use fallback silently on mac
  for app in "${SNAP_APPS[@]}"; do install_fallback "$app"; done
}

install_ubuntu_debian() {
  log "Ubuntu/Debian detected."
  sudo apt-get update -y
  sudo apt-get install -y "${APT_PKGS[@]}"

  if [ "$IS_WSL" -eq 1 ]; then
    warn "WSL detected — snapd skipped."
    for app in "${SNAP_APPS[@]}"; do install_fallback "$app"; done
    return
  fi

  if have snap; then
    log "snapd already installed."
  else
    log "Installing snapd…"
    if ! sudo apt-get install -y snapd; then
      warn "snapd unavailable — using fallbacks."
      for app in "${SNAP_APPS[@]}"; do install_fallback "$app"; done
      return
    fi
    if systemctl list-unit-files | grep -q snapd.service; then
      sudo systemctl enable --now snapd.socket snapd
      sleep 2
    fi
  fi

  for app in "${SNAP_APPS[@]}"; do
    if snap install "$app" --classic; then
      log "Installed snap: $app"
    else
      warn "Snap failed: $app — using fallback."
      install_fallback "$app"
    fi
  done
}

install_fedora() {
  log "Fedora detected."
  sudo dnf install -y "${DNF_PKGS[@]}"
  for app in "${SNAP_APPS[@]}"; do install_fallback "$app"; done
}

install_arch() {
  log "Arch detected."
  sudo pacman -Sy --noconfirm "${PAC_PKGS[@]}"
  for app in "${SNAP_APPS[@]}"; do install_fallback "$app"; done
}

if [ "$OS" = "Darwin" ]; then
  install_macos
elif have apt; then
  install_ubuntu_debian
elif have dnf; then
  install_fedora
elif have pacman; then
  install_arch
else
  err "Unsupported OS — add your package manager logic here."
  exit 1
fi

log "All done."
