# Linux Mint HOWTO Guide
## Detailed Step-by-Step Procedures

---

## Table of Contents

1. [Creating Installation Media](#creating-installation-media)
2. [Dual Boot Setup (Windows + Linux)](#dual-boot-setup)
3. [Post-Installation Optimization](#post-installation-optimization)
4. [Gaming Configuration](#gaming-configuration)
5. [Development Environment Setup](#development-environment-setup)
6. [Network Configuration](#network-configuration)
7. [Backup and Recovery](#backup-and-recovery)
8. [Troubleshooting Procedures](#troubleshooting-procedures)

---

## Creating Installation Media

### Method 1: Using Rufus (Windows)

**Requirements:**
- USB drive (8GB minimum)
- Rufus application
- Linux Mint ISO file

**Steps:**

1. **Download Linux Mint ISO**
   ```
   Visit: https://linuxmint.com/download.php
   Choose: Cinnamon Edition 64-bit
   Size: ~2.8GB
   ```

2. **Download Rufus**
   ```
   Visit: https://rufus.ie
   Download: Rufus 4.x (latest)
   No installation required
   ```

3. **Create Bootable USB**
   - Insert USB drive (will be erased!)
   - Open Rufus
   - Device: Select your USB drive
   - Boot selection: Click SELECT → Choose Linux Mint ISO
   - Partition scheme: GPT (for UEFI) or MBR (for BIOS/Legacy)
   - File system: Leave default
   - Click START
   - Choose "ISO Image mode" if prompted
   - Wait 5-10 minutes

4. **Verify USB Creation**
   - USB should show "Linux Mint" label
   - Size should match ISO (~2.8GB used)

### Method 2: Using Etcher (Cross-Platform)

**Steps:**

1. Download Etcher from balena.io/etcher
2. Open Etcher
3. Select Image: Choose Linux Mint ISO
4. Select Target: Choose USB drive
5. Click Flash
6. Wait for completion and verification

---

## Dual Boot Setup

### Pre-Installation Steps

**1. Backup Windows Data**
```
Critical folders:
- C:\Users\[YourName]\Documents
- C:\Users\[YourName]\Pictures
- C:\Users\[YourName]\Desktop
- Browser bookmarks and passwords
- Game saves (Documents or AppData\Local)
```

**2. Record Windows Product Key**
```
Method 1: Settings → System → About → Product ID
Method 2: Run: wmic path softwarelicensing service get OA3xOriginalProductKey
```

**3. Disable Fast Startup (Windows)**
```
Control Panel → Power Options → Choose what power buttons do
→ Uncheck "Turn on fast startup" → Save
```

**4. Disable BitLocker (If Enabled)**
```
Control Panel → BitLocker Drive Encryption → Turn off BitLocker
Wait for decryption to complete (may take hours)
```

### Partitioning

**Option A: Let Linux Installer Handle It**
- Choose "Install alongside Windows"
- Use slider to allocate space
- Recommended: 50GB minimum for Linux

**Option B: Manual Partitioning (Advanced)**

**Partition Scheme:**
