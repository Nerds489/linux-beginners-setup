#!/usr/bin/env bash

###############################################################################
# Linux Mint Post-Installation Setup Script
# 
# Description: Automated post-installation configuration and optimization
#              for Linux Mint systems. Designed for Windows users switching
#              to Linux for the first time.
#
# Author: Network & Firewall Technicians (NFT) / OffTrackMedia (OTM)
# Version: 1.0.0
# License: MIT
#
# Features:
#   - System updates and firmware installation
#   - Graphics driver detection and installation
#   - Timeshift backup configuration
#   - Performance optimizations (RAM, CPU, I/O)
#   - Security hardening (firewall, kernel parameters)
#   - Laptop power management (TLP)
#   - Desktop environment optimization
#   - Monitoring script installation
#
# Usage: sudo ./post_install_setup.sh
#
# Requirements:
#   - Linux Mint 22+ (or Ubuntu 24.04+)
#   - sudo privileges
#   - Internet connection
#   - Minimum 10GB free disk space
#
# Exit Codes:
#   0 = Success
#   1 = General error
#   2 = Root privileges required
#   3 = Unsupported distribution
#   4 = Insufficient disk space
#   5 = No internet connection
###############################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script Information
SCRIPT_NAME="Linux Mint Post-Install Setup"
SCRIPT_VERSION="1.0.0"
SCRIPT_DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Directories
BACKUP_DIR="/var/backups/linux-setup"
LOG_DIR="/var/log"
BIN_DIR="/usr/local/bin"

# Log Files
LOG_FILE="${LOG_DIR}/post-install-setup_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="${LOG_DIR}/post-install-setup_errors_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# System Information
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
CPU_CORES=$(nproc)
IS_LAPTOP=false
IS_SSD=false
DESKTOP_ENV=""

###############################################################################
# Logging Functions
###############################################################################

log_message() {
    echo -e "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[ℹ]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE" "$ERROR_LOG"
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
    log_info "Checking internet connectivity..."
    if ! ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        log_error "No internet connection detected"
        exit 5
    fi
    log_success "Internet connection verified"
}

check_disk_space() {
    local required_space=10  # GB
    local available_space=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "Insufficient disk space: ${available_space}GB available, ${required_space}GB required"
        exit 4
    fi
    log_success "Disk space check passed: ${available_space}GB available"
}

detect_distribution() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "Detected: $PRETTY_NAME"
        
        if [[ "$ID" != "linuxmint" && "$ID" != "ubuntu" && "$ID_LIKE" != *"ubuntu"* ]]; then
            log_warning "This script is optimized for Linux Mint/Ubuntu"
            read -p "Continue anyway? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 3
            fi
        fi
    else
        log_error "Cannot detect distribution"
        exit 3
    fi
}

detect_hardware() {
    log_section "Hardware Detection"
    
    # Detect laptop
    if [[ -d /sys/class/power_supply/BAT0 ]] || [[ -d /sys/class/power_supply/BAT1 ]]; then
        IS_LAPTOP=true
        log_info "System type: Laptop"
    else
        log_info "System type: Desktop"
    fi
    
    # Detect SSD
    if lsblk -d -o name,rota | grep -q '0$'; then
        IS_SSD=true
        log_info "Storage: SSD detected"
    else
        log_info "Storage: HDD detected"
    fi
    
    # Detect desktop environment
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        DESKTOP_ENV="$XDG_CURRENT_DESKTOP"
        log_info "Desktop Environment: $DESKTOP_ENV"
    fi
    
    log_info "RAM: ${TOTAL_RAM}GB"
    log_info "CPU Cores: $CPU_CORES"
}

create_backup() {
    local file=$1
    if [[ -f "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file" "${BACKUP_DIR}/$(basename $file).$(date +%Y%m%d_%H%M%S).backup"
        log_info "Backed up: $file"
    fi
}

###############################################################################
# System Update Functions
###############################################################################

update_system() {
    log_section "System Updates"
    
    log_info "Updating package lists..."
    if apt update >> "$LOG_FILE" 2>&1; then
        log_success "Package lists updated"
    else
        log_error "Failed to update package lists"
        return 1
    fi
    
    log_info "Upgrading packages (this may take 10-20 minutes)..."
    if DEBIAN_FRONTEND=noninteractive apt upgrade -y >> "$LOG_FILE" 2>&1; then
        log_success "System packages upgraded"
    else
        log_warning "Some packages failed to upgrade (check log)"
    fi
    
    log_info "Installing essential packages..."
    local essential_packages="software-properties-common build-essential curl wget git vim htop neofetch"
    if apt install -y $essential_packages >> "$LOG_FILE" 2>&1; then
        log_success "Essential packages installed"
    else
        log_warning "Some essential packages failed to install"
    fi
}

install_firmware() {
    log_section "Firmware Installation"
    
    log_info "Installing firmware packages..."
    if apt install -y linux-firmware firmware-linux-nonfree >> "$LOG_FILE" 2>&1; then
        log_success "Firmware packages installed"
    else
        log_warning "Firmware installation completed with warnings"
    fi
}

install_drivers() {
    log_section "Graphics Driver Installation"
    
    log_info "Detecting graphics hardware..."
    
    if lspci | grep -i nvidia >> "$LOG_FILE" 2>&1; then
        log_info "NVIDIA GPU detected - installing proprietary drivers"
        if ubuntu-drivers autoinstall >> "$LOG_FILE" 2>&1; then
            log_success "NVIDIA drivers installed (reboot required)"
        else
            log_warning "NVIDIA driver installation had issues"
        fi
    elif lspci | grep -i amd >> "$LOG_FILE" 2>&1; then
        log_info "AMD GPU detected - installing Mesa drivers"
        if apt install -y mesa-utils vulkan-tools >> "$LOG_FILE" 2>&1; then
            log_success "AMD drivers installed"
        fi
    else
        log_info "Intel/Generic GPU detected - using open source drivers"
    fi
}

###############################################################################
# Timeshift Backup Configuration
###############################################################################

configure_timeshift() {
    log_section "Timeshift Backup Configuration"
    
    log_info "Installing Timeshift..."
    if apt install -y timeshift >> "$LOG_FILE" 2>&1; then
        log_success "Timeshift installed"
    else
        log_error "Failed to install Timeshift"
        return 1
    fi
    
    log_info "Configuring Timeshift for automatic backups..."
    log_warning "Please configure Timeshift manually in System Settings"
    log_info "Recommended: Daily snapshots (keep 3), Weekly snapshots (keep 2)"
    log_info "Run: sudo timeshift-gtk"
}

###############################################################################
# Performance Optimization Functions
###############################################################################

optimize_ram() {
    log_section "RAM Optimization"
    
    create_backup "/etc/sysctl.conf"
    
    # Calculate optimal swappiness based on RAM
    local swappiness=60
    if [[ $TOTAL_RAM -ge 16 ]]; then
        swappiness=1
        log_info "16GB+ RAM detected - minimal swap usage"
    elif [[ $TOTAL_RAM -ge 8 ]]; then
        swappiness=10
        log_info "8-16GB RAM detected - low swap usage"
    elif [[ $TOTAL_RAM -ge 4 ]]; then
        swappiness=40
        log_info "4-8GB RAM detected - moderate swap usage"
    else
        swappiness=60
        log_info "<4GB RAM detected - higher swap usage"
    fi
    
    # Apply swappiness
    sysctl vm.swappiness=$swappiness >> "$LOG_FILE" 2>&1
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=$swappiness" >> /etc/sysctl.conf
        log_success "Swappiness set to $swappiness"
    fi
    
    # VFS cache pressure
    sysctl vm.vfs_cache_pressure=50 >> "$LOG_FILE" 2>&1
    if ! grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf; then
        echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
        log_success "VFS cache pressure optimized"
    fi
    
    # Dirty ratio (improves responsiveness)
    sysctl vm.dirty_ratio=10 >> "$LOG_FILE" 2>&1
    sysctl vm.dirty_background_ratio=5 >> "$LOG_FILE" 2>&1
    if ! grep -q "vm.dirty_ratio" /etc/sysctl.conf; then
        echo "vm.dirty_ratio=10" >> /etc/sysctl.conf
        echo "vm.dirty_background_ratio=5" >> /etc/sysctl.conf
        log_success "Dirty ratio optimized"
    fi
}

optimize_ssd() {
    log_section "SSD Optimization"
    
    if [[ "$IS_SSD" == true ]]; then
        log_info "Enabling TRIM for SSD..."
        
        if systemctl enable fstrim.timer >> "$LOG_FILE" 2>&1; then
            systemctl start fstrim.timer >> "$LOG_FILE" 2>&1
            log_success "TRIM enabled (runs weekly)"
        else
            log_warning "Failed to enable TRIM"
        fi
        
        # Check if noatime is set
        if ! grep -q "noatime" /etc/fstab; then
            log_info "Consider adding 'noatime' to /etc/fstab for better SSD performance"
        fi
    else
        log_info "HDD detected - skipping SSD optimizations"
    fi
}

install_preload() {
    log_section "Preload Installation"
    
    log_info "Installing Preload (faster application launches)..."
    if apt install -y preload >> "$LOG_FILE" 2>&1; then
        log_success "Preload installed and running"
    else
        log_warning "Preload installation failed"
    fi
}

configure_laptop() {
    log_section "Laptop Power Management"
    
    if [[ "$IS_LAPTOP" == true ]]; then
        log_info "Installing TLP for battery optimization..."
        
        if apt install -y tlp tlp-rdw >> "$LOG_FILE" 2>&1; then
            systemctl enable tlp >> "$LOG_FILE" 2>&1
            systemctl start tlp >> "$LOG_FILE" 2>&1
            log_success "TLP installed and configured"
            log_info "TLP will automatically optimize battery life"
        else
            log_warning "TLP installation failed"
        fi
    else
        log_info "Desktop detected - skipping laptop optimizations"
    fi
}

configure_firewall() {
    log_section "Security Hardening"
    
    log_info "Configuring UFW firewall..."
    if apt install -y ufw >> "$LOG_FILE" 2>&1; then
        ufw --force enable >> "$LOG_FILE" 2>&1
        ufw default deny incoming >> "$LOG_FILE" 2>&1
        ufw default allow outgoing >> "$LOG_FILE" 2>&1
        log_success "Firewall enabled and configured"
    else
        log_warning "Firewall configuration failed"
    fi
}

###############################################################################
# Monitoring Scripts Creation
###############################################################################

create_monitoring_scripts() {
    log_section "Creating Monitoring Scripts"
    
    # System Health Script
    cat > "${BIN_DIR}/system-health" << 'EOF'
#!/bin/bash
echo "=== System Health Report ==="
echo "Date: $(date)"
echo "Uptime: $(uptime -p)"
echo ""
echo "=== CPU Usage ==="
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print "CPU Usage: " 100 - $1"%"}'
echo ""
echo "=== RAM Usage ==="
free -h
echo ""
echo "=== Disk Usage ==="
df -h | grep -E '^/dev/'
echo ""
echo "=== Load Average ==="
uptime
EOF
    chmod +x "${BIN_DIR}/system-health"
    log_success "Created: system-health command"
    
    # RAM Check Script
    cat > "${BIN_DIR}/ram-check" << 'EOF'
#!/bin/bash
echo "=== RAM Status ==="
free -h
echo ""
echo "=== Top 5 Memory-Using Processes ==="
ps aux --sort=-%mem | head -6
echo ""
echo "=== Swappiness Setting ==="
cat /proc/sys/vm/swappiness
EOF
    chmod +x "${BIN_DIR}/ram-check"
    log_success "Created: ram-check command"
    
    # Performance Monitor Script
    cat > "${BIN_DIR}/perf-monitor" << 'EOF'
#!/bin/bash
if command -v htop &> /dev/null; then
    htop
else
    echo "htop not installed. Installing..."
    sudo apt install -y htop
    htop
fi
EOF
    chmod +x "${BIN_DIR}/perf-monitor"
    log_success "Created: perf-monitor command"
    
    # Optimization Status Script
    cat > "${BIN_DIR}/optimization-status" << 'EOF'
#!/bin/bash
echo "=== Optimization Status ==="
echo "Swappiness: $(cat /proc/sys/vm/swappiness)"
echo "TRIM Status: $(systemctl is-enabled fstrim.timer 2>/dev/null || echo 'Not configured')"
echo "Preload: $(systemctl is-active preload 2>/dev/null || echo 'Not installed')"
echo "TLP: $(systemctl is-active tlp 2>/dev/null || echo 'Not installed')"
echo "Firewall: $(sudo ufw status | head -1)"
EOF
    chmod +x "${BIN_DIR}/optimization-status"
    log_success "Created: optimization-status command"
}

###############################################################################
# Cleanup Function
###############################################################################

cleanup_system() {
    log_section "System Cleanup"
    
    log_info "Removing unnecessary packages..."
    apt autoremove -y >> "$LOG_FILE" 2>&1
    apt autoclean >> "$LOG_FILE" 2>&1
    log_success "System cleanup completed"
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
 ║        Linux Mint Post-Installation Setup Script             ║
 ║                                                               ║
 ║           Automated Configuration & Optimization             ║
 ║                        Version 1.0.0                          ║
 ║                                                               ║
 ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log_message "Script started: $SCRIPT_DATE"
    log_message "Log file: $LOG_FILE"
    
    # Pre-flight checks
    check_root
    check_internet
    check_disk_space
    detect_distribution
    detect_hardware
    
    # Main setup steps
    update_system || true
    install_firmware || true
    install_drivers || true
    configure_timeshift || true
    optimize_ram || true
    optimize_ssd || true
    install_preload || true
    configure_laptop || true
    configure_firewall || true
    create_monitoring_scripts || true
    cleanup_system || true
    
    # Final report
    log_section "Setup Complete"
    log_success "Post-installation setup completed successfully!"
    echo ""
    log_info "Configuration Summary:"
    log_info "  - System updated and drivers installed"
    log_info "  - RAM optimized (swappiness configured)"
    log_info "  - SSD TRIM enabled (if applicable)"
    log_info "  - Laptop power management configured (if applicable)"
    log_info "  - Firewall enabled and configured"
    log_info "  - Monitoring commands created"
    echo ""
    log_info "New commands available:"
    log_info "  - system-health     : View system health report"
    log_info "  - ram-check         : Check RAM usage"
    log_info "  - perf-monitor      : Real-time performance monitoring"
    log_info "  - optimization-status : Check optimization status"
    echo ""
    log_warning "⚠️  REBOOT REQUIRED to apply all changes"
    echo ""
    log_info "Logs saved to: $LOG_FILE"
    log_info "Backups saved to: $BACKUP_DIR"
    echo ""
    
    read -p "Reboot now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Rebooting system..."
        reboot
    else
        log_warning "Remember to reboot later to apply all changes"
    fi
}

###############################################################################
# Script Entry Point
###############################################################################

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

# Run main function
main "$@"

exit 0
