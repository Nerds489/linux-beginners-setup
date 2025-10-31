# Linux Mint Quick Start Guide
## Essential Commands & Windows→Linux Reference Card

---

## First Steps After Installation

```bash
# Update everything FIRST
sudo apt update && sudo apt upgrade -y

# Set up Timeshift backups (CRITICAL - do this now!)
sudo timeshift --create --comments "Fresh Install"

# Enable SSD TRIM (if you have SSD)
sudo systemctl enable fstrim.timer && sudo systemctl start fstrim.timer

# Install essential tools
sudo apt install htop neofetch git curl wget vim -y
```

---

## Quick Reference: Windows → Linux

| Task | Windows | Linux Mint |
|------|---------|------------|
| **File Manager** | Explorer (Win+E) | Nemo (Super+E) |
| **Task Manager** | Ctrl+Shift+Esc | Ctrl+Shift+Esc |
| **Terminal** | CMD/PowerShell | Terminal (Ctrl+Alt+T) |
| **Settings** | Control Panel | System Settings |
| **App Store** | Microsoft Store | Software Manager |
| **System Tray** | Bottom-right | Bottom-right (same!) |
| **Start Menu** | Windows key | Super key (same!) |
| **Search** | Win+S | Super, then type |
| **Screenshot** | Win+Shift+S | Shift+PrintScreen |
| **Lock Screen** | Win+L | Ctrl+Alt+L |

---

## Essential Terminal Commands

### System Management
```bash
sudo apt update              # Update package lists (like checking for updates)
sudo apt upgrade             # Install available updates
sudo apt install app-name    # Install software
sudo apt remove app-name     # Uninstall software
sudo apt autoremove          # Remove unused packages
sudo reboot                  # Restart computer
sudo shutdown -h now         # Shut down immediately
```

### File Operations
```bash
ls                  # List files (like DIR in Windows)
ls -la              # List all files including hidden
cd folder           # Change directory
cd ..               # Go up one folder
cd ~                # Go to home folder (/home/username)
pwd                 # Show current directory path
mkdir folder        # Create new folder
rm file             # Delete file
rm -r folder        # Delete folder and contents (BE CAREFUL!)
cp source dest      # Copy file
mv source dest      # Move/rename file
```

### File Viewing
```bash
cat file            # Display entire file
less file           # View file page by page (Q to quit)
head file           # Show first 10 lines
tail file           # Show last 10 lines
tail -f file        # Follow file in real-time (logs)
nano file           # Edit file (Ctrl+X to exit)
```

### System Information
```bash
free -h             # RAM usage
df -h               # Disk space usage
top                 # Running processes (Q to quit)
htop                # Better process viewer
uname -a            # System information
lsb_release -a      # Linux distribution info
lsblk               # List drives and partitions
lspci               # List PCI devices (GPU, network cards)
lsusb               # List USB devices
```

### Network
```bash
ip a                # Show IP addresses (like ipconfig)
ping google.com     # Test connectivity (Ctrl+C to stop)
speedtest-cli       # Test internet speed (install first)
sudo systemctl restart NetworkManager   # Restart network
```

### Process Management
```bash
ps aux              # List all running processes
kill PID            # Kill process by ID
killall name        # Kill all processes by name
sudo systemctl status service  # Check service status
sudo systemctl start service   # Start service
sudo systemctl stop service    # Stop service
```

---

## File System Structure

| Windows Path | Linux Equivalent | Purpose |
|--------------|------------------|---------|
| C:\ | / | Root directory |
| C:\Users\Username | /home/username | Your files |
| C:\Users\Username\Documents | ~/Documents | Documents folder |
| C:\Users\Username\Desktop | ~/Desktop | Desktop folder |
| C:\Program Files | /usr/bin, /usr/local/bin | Installed programs |
| C:\Windows | /boot, /etc, /lib | System files |
| D:\, E:\ | /mnt, /media | External drives |
| \ (backslash) | / (forward slash) | Path separator |

**Pro Tip:** `~` is shortcut for your home folder (`/home/username`)

---

## Package Manager Cheat Sheet

### APT (Advanced Package Tool)
```bash
# Search for package
apt search keyword

# Get package info
apt show package-name

# Install package
sudo apt install package-name

# Remove package (keep configs)
sudo apt remove package-name

# Remove completely (including configs)
sudo apt purge package-name

# Update package lists
sudo apt update

# Upgrade all packages
sudo apt upgrade

# Clean up
sudo apt autoremove     # Remove unused dependencies
sudo apt autoclean      # Remove old package files
```

### Snap Packages
```bash
snap find package-name       # Search
sudo snap install name       # Install
sudo snap remove name        # Remove
snap list                    # List installed
sudo snap refresh            # Update all
```

### Flatpak Packages
```bash
flatpak search name          # Search
flatpak install flathub name # Install from Flathub
flatpak uninstall name       # Remove
flatpak list                 # List installed
flatpak update               # Update all
```

---

## Common Tasks

### Install Software
```bash
# From Software Manager GUI (easiest)
Menu → Software Manager → Search → Install

# From terminal
sudo apt install package-name

# From downloaded .deb file
sudo dpkg -i package.deb
sudo apt install -f  # Fix dependencies
```

### Update System
```bash
# GUI method
Click shield icon in system tray → Install Updates

# Terminal method (faster)
sudo apt update && sudo apt upgrade -y
```

### Check Disk Space
```bash
df -h                  # Overall disk usage
du -sh /path/folder    # Specific folder size
ncdu                   # Interactive disk usage (install: sudo apt install ncdu)
```

### Find Files
```bash
find /path -name "filename"           # Search by name
locate filename                       # Fast search (update: sudo updatedb)
grep "text" file                      # Search inside files
grep -r "text" /path                  # Recursive search in folder
```

### Permissions
```bash
chmod +x file         # Make file executable
chmod 755 file        # Full permissions for owner, read/execute for others
chmod 644 file        # Read/write for owner, read-only for others
chown user:group file # Change owner
sudo chown -R $USER:$USER folder  # Take ownership of folder
```

---

## Emergency Procedures

### System Won't Boot
1. Boot from USB install media
2. Choose "Start Linux Mint" (don't install)
3. Open Timeshift
4. Select a snapshot
5. Click "Restore"
6. Reboot

### System Frozen
```bash
# Magic SysRq keys (safer than hard restart)
Alt + SysRq + R  # Take keyboard control
Alt + SysRq + E  # Kill all processes
Alt + SysRq + I  # Kill remaining processes
Alt + SysRq + S  # Sync disks
Alt + SysRq + U  # Unmount filesystems
Alt + SysRq + B  # Reboot

# Mnemonic: "Reboot Even If System Utterly Broken"
```

### Out of Disk Space
```bash
# Clean package cache
sudo apt clean && sudo apt autoremove

# Remove old kernels
sudo apt autoremove --purge

# Find large files
sudo du -h /home | sort -rh | head -20

# Visual disk usage
sudo apt install baobab
baobab
```

### Forgot Password
1. Reboot and hold Shift to enter GRUB
2. Select "Advanced options for Linux Mint"
3. Select recovery mode
4. Select "root" (drop to root shell)
5. `passwd username` to reset password
6. `exit` and `reboot`

---

## Performance Optimization Quick Commands

```bash
# Check swappiness (should be 10-40 for 8GB+ RAM)
cat /proc/sys/vm/swappiness

# Set swappiness temporarily
sudo sysctl vm.swappiness=10

# Set swappiness permanently
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf

# Enable TRIM for SSD
sudo systemctl enable fstrim.timer

# Install Preload (faster app launches)
sudo apt install preload

# Check what's using RAM
free -h
ps aux --sort=-%mem | head

# Check what's using CPU
top
# Press P to sort by CPU, M to sort by memory, Q to quit
```

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open Terminal | Ctrl+Alt+T |
| Lock Screen | Ctrl+Alt+L |
| Take Screenshot | PrintScreen |
| Screenshot Area | Shift+PrintScreen |
| Show Desktop | Ctrl+Alt+D |
| Switch Windows | Alt+Tab |
| Close Window | Alt+F4 |
| Force Quit App | Ctrl+Alt+Esc (click window) |
| Open Run Dialog | Alt+F2 |
| Logout | Ctrl+Alt+Del |

---

## Essential Software (One-Line Installs)

```bash
# Browsers
sudo apt install google-chrome-stable brave-browser firefox

# Development
sudo apt install git vim code sublime-text docker.io nodejs npm python3-pip

# Media
sudo apt install vlc spotify-client gimp kdenlive obs-studio audacity

# Productivity
sudo apt install libreoffice thunderbird obsidian

# Communication
sudo apt install discord slack telegram-desktop

# Utilities
sudo apt install timeshift flameshot keepassxc htop neofetch
```

---

## Troubleshooting One-Liners

```bash
# WiFi not working
sudo systemctl restart NetworkManager

# Sound not working
systemctl --user restart pulseaudio

# Bluetooth not working
sudo systemctl restart bluetooth

# Update issues
sudo apt update --fix-missing && sudo apt install -f

# Broken packages
sudo dpkg --configure -a && sudo apt install -f

# Reset to default settings
rm -rf ~/.config/[application-name]

# Check system logs
journalctl -xe
# or
dmesg | tail
```

---

## Pro Tips

1. **Tab Completion** - Press Tab while typing commands to auto-complete
2. **Command History** - Use Up Arrow to see previous commands
3. **Ctrl+C** - Stop any running command
4. **Ctrl+L** - Clear terminal screen (same as `clear`)
5. **Ctrl+A** - Go to start of line
6. **Ctrl+E** - Go to end of line
7. **!!** - Repeat last command (useful: `sudo !!`)
8. **man command** - Read manual for any command
9. **tldr command** - Simple examples (install: `sudo apt install tldr`)

---

## Getting Help

```bash
man command           # Full manual
command --help        # Quick help
tldr command          # Simple examples with explanations
apropos keyword       # Find commands related to keyword
```

**Online Resources:**
- Linux Mint Forums: forums.linuxmint.com
- Ask Ubuntu: askubuntu.com (works for Mint)
- Reddit: r/linuxmint, r/linux4noobs
- Arch Wiki: wiki.archlinux.org (excellent documentation)

---

## When Things Go Wrong

**Remember:** With Timeshift enabled, you literally cannot permanently break your system. Worst case: restore a snapshot.

**Golden Rules:**
1. ❌ Never run `sudo rm -rf /`
2. ✅ Always update before installing: `sudo apt update`
3. ✅ Read before running random internet commands
4. ✅ Take a Timeshift snapshot before major changes
5. ✅ Google error messages (someone solved it already)

---

## Quick Aliases (Make Life Easier)

Add these to `~/.bashrc`:

```bash
alias update='sudo apt update && sudo apt upgrade -y'
alias clean='sudo apt autoremove -y && sudo apt autoclean'
alias install='sudo apt install'
alias remove='sudo apt remove'
alias search='apt search'
alias ll='ls -la'
alias ..='cd ..'
alias ...='cd ../..'
alias please='sudo'
```

Then run: `source ~/.bashrc`

Now you can use: `update`, `install firefox`, `clean`, etc.

---

**You've got this! 🐧**
