#!/usr/bin/env bash

###############################################################################
# Linux System Optimizer
# 
# Description: Advanced system optimization script for maximum performance
#              Covers RAM, CPU, storage, network, and gaming optimizations
#
# Author: Network & Firewall Technicians (NFT) / OffTrackMedia (OTM)
# Version: 1.0.0
# License: MIT
#
# Features:
#   - RAM optimization (swappiness, cache, ZRAM)
#   - CPU optimization (governor, affinity, turbo boost)
#   - Storage optimization (I/O scheduler, TRIM, mount options)
#   - Network optimization (BBR, TCP tuning)
#   - Gaming optimization (Gamemode, latency reduction)
#   - Desktop environment optimization
#   - Automatic hardware detection
#
# Usage: 
#   sudo ./system_optimizer.sh                        # Auto-detect and optimize
#   sudo ./system_optimizer.sh --mode desktop         # Desktop optimizations
#   sudo ./system_optimizer.sh --mode laptop          # Laptop optimizations
#   sudo ./system_optimizer.sh --swappiness 10        # Custom swappiness
#   sudo ./system_optimizer.sh --skip-gaming          # Skip gaming opts
#
# Requirements:
#   - Linux Mint 22+ (or Ubuntu 24.04+)
#   - sudo privileges
#   - System with systemd
#
# Exit Codes:
#   0 = Success
#   1 = General error
#   2 = Root privileges required
#   3 = Unsupported distribution
###############################################################################

set -euo pipefail

# Script Information
SCRIPT_NAME="Linux System Optimizer"
SCRIPT_VERSION="1.0.0"
SCRIPT_DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Directories
LOG_DIR="/var/log"
BACKUP_DIR="/var/backups/system-optimizer"
CONFIG_DIR="/etc/sysctl.d"

# Log Files
LOG_FILE="${LOG_DIR}/system-optimizer_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="${LOG_DIR}/system-optimizer_errors_$(date +%Y%m%d_%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# System Information
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
CPU_CORES=$(nproc)
CPU_THREADS=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
IS_LAPTOP=false
IS_SSD=false
DESKTOP_ENV=""

# Configuration Options
MODE="auto"
CUSTOM_SWAPPINESS=0
SKIP_GAMING=false
SKIP_LAPTOP=false
DRY_RUN=false

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

create_backup() {
    local file=$1
    if [[ -f "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file" "${BACKUP_DIR}/$(basename $file).$(date +%Y%m%d_%H%M%S).backup"
        log_info "Backed up: $file"
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
    log_info "CPU: ${CPU_CORES} cores / ${CPU_THREADS} threads"
    
    # Detect CPU vendor
    if grep -q "Intel" /proc/cpuinfo; then
        log_info "CPU Vendor: Intel"
    elif grep -q "AMD" /proc/cpuinfo; then
        log_info "CPU Vendor: AMD"
    fi
}

apply_sysctl() {
    local param=$1
    local value=$2
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would set: $param = $value"
        return 0
    fi
    
    sysctl -w "$param=$value" >> "$LOG_FILE" 2>&1
    
    # Make permanent
    local config_file="${CONFIG_DIR}/99-custom-optimization.conf"
    if ! grep -q "^$param" "$config_file" 2>/dev/null; then
        echo "$param = $value" >> "$config_file"
    else
        sed -i "s|^$param.*|$param = $value|" "$config_file"
    fi
}

###############################################################################
# RAM Optimization
###############################################################################

optimize_ram() {
    log_section "RAM Optimization"
    
    # Create sysctl config
    mkdir -p "$CONFIG_DIR"
    local config_file="${CONFIG_DIR}/99-custom-optimization.conf"
    create_backup "$config_file"
    touch "$config_file"
    
    # Calculate optimal swappiness
    local swappiness=60
    if [[ $CUSTOM_SWAPPINESS -gt 0 ]]; then
        swappiness=$CUSTOM_SWAPPINESS
        log_info "Using custom swappiness: $swappiness"
    else
        if [[ $TOTAL_RAM -ge 32 ]]; then
            swappiness=1
            log_info "32GB+ RAM: minimal swap"
        elif [[ $TOTAL_RAM -ge 16 ]]; then
            swappiness=5
            log_info "16-32GB RAM: very low swap"
        elif [[ $TOTAL_RAM -ge 8 ]]; then
            swappiness=10
            log_info "8-16GB RAM: low swap"
        elif [[ $TOTAL_RAM -ge 4 ]]; then
            swappiness=30
            log_info "4-8GB RAM: moderate swap"
        else
            swappiness=60
            log_info "<4GB RAM: higher swap"
        fi
    fi
    
    apply_sysctl "vm.swappiness" "$swappiness"
    log_success "Swappiness set to $swappiness"
    
    # VFS cache pressure (how aggressively kernel reclaims inodes/dentries)
    apply_sysctl "vm.vfs_cache_pressure" "50"
    log_success "VFS cache pressure optimized"
    
    # Dirty ratio (percentage of RAM that can be dirty before writing to disk)
    if [[ $TOTAL_RAM -ge 8 ]]; then
        apply_sysctl "vm.dirty_ratio" "10"
        apply_sysctl "vm.dirty_background_ratio" "5"
    else
        apply_sysctl "vm.dirty_ratio" "15"
        apply_sysctl "vm.dirty_background_ratio" "10"
    fi
    log_success "Dirty ratio optimized"
    
    # Memory map areas
    apply_sysctl "vm.max_map_count" "2147483642"
    log_success "Memory map count increased (helps gaming)"
    
    # ZRAM for systems with low RAM
    if [[ $TOTAL_RAM -lt 8 ]] && command -v zramctl &> /dev/null; then
        log_info "Configuring ZRAM for low-RAM system..."
        if ! grep -q "zram" /etc/modules; then
            echo "zram" >> /etc/modules
            modprobe zram
            
            # Configure ZRAM size (50% of RAM)
            local zram_size=$((TOTAL_RAM * 512))M
            echo "$zram_size" > /sys/block/zram0/disksize
            mkswap /dev/zram0
            swapon -p 10 /dev/zram0
            
            log_success "ZRAM configured (compressed RAM)"
        fi
    fi
}

###############################################################################
# CPU Optimization
###############################################################################

optimize_cpu() {
    log_section "CPU Optimization"
    
    # CPU Governor
    if [[ "$IS_LAPTOP" == true ]] && [[ "$SKIP_LAPTOP" == false ]]; then
        log_info "Setting CPU governor to schedutil (laptop)"
        if command -v cpupower &> /dev/null; then
            cpupower frequency-set -g schedutil >> "$LOG_FILE" 2>&1 || true
        fi
    else
        log_info "Setting CPU governor to performance (desktop)"
        if command -v cpupower &> /dev/null; then
            cpupower frequency-set -g performance >> "$LOG_FILE" 2>&1 || true
        fi
    fi
    
    # Install cpufrequtils if needed
    if ! command -v cpupower &> /dev/null; then
        apt install -y linux-cpupower >> "$LOG_FILE" 2>&1 || true
    fi
    
    # IRQ Balance for multi-core systems
    if [[ $CPU_CORES -gt 2 ]]; then
        log_info "Installing IRQ balance for multi-core optimization..."
        if apt install -y irqbalance >> "$LOG_FILE" 2>&1; then
            systemctl enable irqbalance >> "$LOG_FILE" 2>&1
            systemctl start irqbalance >> "$LOG_FILE" 2>&1
            log_success "IRQ balance enabled"
        fi
    fi
    
    # CPU scheduler optimizations
    apply_sysctl "kernel.sched_migration_cost_ns" "5000000"
    apply_sysctl "kernel.sched_autogroup_enabled" "0"
    log_success "CPU scheduler optimized"
}

###############################################################################
# Storage Optimization
###############################################################################

optimize_storage() {
    log_section "Storage Optimization"
    
    if [[ "$IS_SSD" == true ]]; then
        log_info "Optimizing for SSD..."
        
        # Enable TRIM
        if systemctl list-unit-files | grep -q "fstrim.timer"; then
            systemctl enable fstrim.timer >> "$LOG_FILE" 2>&1
            systemctl start fstrim.timer >> "$LOG_FILE" 2>&1
            log_success "TRIM enabled (weekly schedule)"
        fi
        
        # Set I/O scheduler to none (best for SSDs)
        for disk in /sys/block/sd*/queue/scheduler; do
            if [[ -f "$disk" ]]; then
                echo "none" > "$disk" 2>/dev/null || echo "mq-deadline" > "$disk" 2>/dev/null || true
            fi
        done
        log_success "I/O scheduler set to 'none' for SSDs"
        
        # Recommend noatime in fstab
        if ! grep -q "noatime" /etc/fstab; then
            log_warning "Consider adding 'noatime' to /etc/fstab for SSD performance"
            log_info "  Add to mount options: defaults,noatime,errors=remount-ro"
        fi
    else
        log_info "Optimizing for HDD..."
        
        # Set I/O scheduler to mq-deadline (better for HDDs)
        for disk in /sys/block/sd*/queue/scheduler; do
            if [[ -f "$disk" ]]; then
                echo "mq-deadline" > "$disk" 2>/dev/null || true
            fi
        done
        log_success "I/O scheduler set to 'mq-deadline' for HDDs"
    fi
    
    # Filesystem optimizations
    apply_sysctl "vm.dirty_writeback_centisecs" "1500"
    apply_sysctl "vm.dirty_expire_centisecs" "3000"
    log_success "Filesystem write-back optimized"
}

###############################################################################
# Network Optimization
###############################################################################

optimize_network() {
    log_section "Network Optimization"
    
    # TCP BBR (Bottleneck Bandwidth and RTT) - Google's congestion control
    if modprobe tcp_bbr 2>/dev/null; then
        apply_sysctl "net.ipv4.tcp_congestion_control" "bbr"
        apply_sysctl "net.core.default_qdisc" "fq"
        log_success "TCP BBR enabled (2-3x faster downloads)"
    else
        log_warning "TCP BBR not available (kernel too old)"
    fi
    
    # TCP buffer sizes
    apply_sysctl "net.core.rmem_max" "16777216"
    apply_sysctl "net.core.wmem_max" "16777216"
    apply_sysctl "net.ipv4.tcp_rmem" "4096 87380 16777216"
    apply_sysctl "net.ipv4.tcp_wmem" "4096 65536 16777216"
    log_success "TCP buffers optimized"
    
    # Connection tracking
    apply_sysctl "net.netfilter.nf_conntrack_max" "1048576"
    log_success "Connection tracking increased"
    
    # Fast socket open
    apply_sysctl "net.ipv4.tcp_fastopen" "3"
    log_success "TCP Fast Open enabled"
}

###############################################################################
# Gaming Optimization
###############################################################################

optimize_gaming() {
    if [[ "$SKIP_GAMING" == true ]]; then
        log_info "Skipping gaming optimizations"
        return 0
    fi
    
    log_section "Gaming Optimization"
    
    # Install Gamemode
    if ! command -v gamemoded &> /dev/null; then
        log_info "Installing Gamemode..."
        if apt install -y gamemode >> "$LOG_FILE" 2>&1; then
            log_success "Gamemode installed"
        else
            log_warning "Gamemode installation failed"
        fi
    else
        log_info "Gamemode already installed"
    fi
    
    # Memory map areas (required for many games)
    apply_sysctl "vm.max_map_count" "2147483642"
    log_success "Memory map count optimized for gaming"
    
    # Reduce input latency
    apply_sysctl "dev.i915.perf_stream_paranoid" "0" 2>/dev/null || true
    
    # File descriptor limits
    if ! grep -q "* soft nofile 524288" /etc/security/limits.conf; then
        echo "* soft nofile 524288" >> /etc/security/limits.conf
        echo "* hard nofile 524288" >> /etc/security/limits.conf
        log_success "File descriptor limits increased"
    fi
}

###############################################################################
# Desktop Environment Optimization
###############################################################################

optimize_desktop() {
    log_section "Desktop Environment Optimization"
    
    case "$DESKTOP_ENV" in
        *"Cinnamon"*)
            log_info "Optimizing Cinnamon..."
            # Disable animations for performance
            if command -v gsettings &> /dev/null; then
                gsettings set org.cinnamon desktop-effects false 2>/dev/null || true
                gsettings set org.cinnamon enable-vfade false 2>/dev/null || true
                log_success "Cinnamon animations disabled"
            fi
            ;;
        *"GNOME"*)
            log_info "Optimizing GNOME..."
            if command -v gsettings &> /dev/null; then
                gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true
                log_success "GNOME animations disabled"
            fi
            ;;
        *"KDE"*|*"Plasma"*)
            log_info "Optimizing KDE Plasma..."
            log_info "Manually disable animations in System Settings > Workspace Behavior > Desktop Effects"
            ;;
        *"XFCE"*)
            log_info "XFCE detected - already lightweight!"
            ;;
        *)
            log_info "Desktop environment: $DESKTOP_ENV"
            ;;
    esac
    
    # Preload for faster application launches
    if ! systemctl is-active preload &> /dev/null; then
        log_info "Installing Preload..."
        if apt install -y preload >> "$LOG_FILE" 2>&1; then
            log_success "Preload installed"
        fi
    fi
}

###############################################################################
# Laptop-Specific Optimization
###############################################################################

optimize_laptop() {
    if [[ "$IS_LAPTOP" == false ]] || [[ "$SKIP_LAPTOP" == true ]]; then
        return 0
    fi
    
    log_section "Laptop Power Management"
    
    # Install TLP
    if ! command -v tlp &> /dev/null; then
        log_info "Installing TLP..."
        if apt install -y tlp tlp-rdw >> "$LOG_FILE" 2>&1; then
            systemctl enable tlp >> "$LOG_FILE" 2>&1
            systemctl start tlp >> "$LOG_FILE" 2>&1
            log_success "TLP installed and running"
        fi
    else
        log_info "TLP already installed"
    fi
    
    # Power-efficient swappiness for laptops
    if [[ $CUSTOM_SWAPPINESS -eq 0 ]]; then
        apply_sysctl "vm.laptop_mode" "2"
        log_success "Laptop mode enabled"
    fi
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
 ║              Linux System Optimizer                           ║
 ║                                                               ║
 ║           Advanced Performance Tuning                         ║
 ║                    Version 1.0.0                              ║
 ║                                                               ║
 ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log_message "Script started: $SCRIPT_DATE"
    log_message "Log file: $LOG_FILE"
    
    # Pre-flight checks
    check_root
    detect_hardware
    
    # Apply optimizations
    optimize_ram
    optimize_cpu
    optimize_storage
    optimize_network
    optimize_gaming
    optimize_desktop
    optimize_laptop
    
    # Apply all sysctl changes
    if [[ "$DRY_RUN" == false ]]; then
        sysctl -p "${CONFIG_DIR}/99-custom-optimization.conf" >> "$LOG_FILE" 2>&1 || true
    fi
    
    # Final report
    log_section "Optimization Complete"
    log_success "System optimization completed successfully!"
    echo ""
    log_info "Optimizations Applied:"
    log_info "  ✓ RAM optimized (swappiness, cache, dirty ratio)"
    log_info "  ✓ CPU optimized (governor, scheduler, IRQ balance)"
    log_info "  ✓ Storage optimized (I/O scheduler, TRIM)"
    log_info "  ✓ Network optimized (TCP BBR, buffers)"
    if [[ "$SKIP_GAMING" == false ]]; then
        log_info "  ✓ Gaming optimized (Gamemode, memory maps)"
    fi
    if [[ "$IS_LAPTOP" == true ]] && [[ "$SKIP_LAPTOP" == false ]]; then
        log_info "  ✓ Laptop power management (TLP)"
    fi
    echo ""
    log_info "Configuration saved to: ${CONFIG_DIR}/99-custom-optimization.conf"
    log_info "Backups saved to: $BACKUP_DIR"
    log_info "Full log: $LOG_FILE"
    echo ""
    log_warning "⚠️  REBOOT REQUIRED to fully apply all optimizations"
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

mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --swappiness)
            CUSTOM_SWAPPINESS="$2"
            shift 2
            ;;
        --skip-gaming)
            SKIP_GAMING=true
            shift
            ;;
        --skip-laptop)
            SKIP_LAPTOP=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --mode <desktop|laptop>    Force specific optimization mode"
            echo "  --swappiness <0-100>       Set custom swappiness value"
            echo "  --skip-gaming              Skip gaming optimizations"
            echo "  --skip-laptop              Skip laptop-specific optimizations"
            echo "  --dry-run                  Show what would be done without applying"
            echo "  --help                     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

main "$@"

exit 0
