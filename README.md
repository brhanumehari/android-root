# 🤖 Awesome Android Root Helper

> A production-ready **Electron.js desktop app** (Linux, macOS, Windows) and **Termux CLI** (Android) for ADB/Fastboot Android rooting operations — real-time terminal output, native file picker, zero command-line knowledge required.

![Linux/macOS](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-blue?style=flat-square)
![Windows](https://img.shields.io/badge/platform-Windows%2010%2F11-0078D4?style=flat-square&logo=windows)
![Android Termux](https://img.shields.io/badge/platform-Android%20Termux-3DDC84?style=flat-square&logo=android&logoColor=white)
![Electron](https://img.shields.io/badge/Electron-28-47848F?style=flat-square&logo=electron)
![Node](https://img.shields.io/badge/Node.js-18%2B-339933?style=flat-square&logo=node.js)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)

---

## ✨ Features

- **Device Status Check** — Connects via ADB and reports device model, brand, Android version, SDK level, bootloader lock state, SELinux mode, and root access availability.
- **Boot Image Flashing** — Opens a native file picker to select a Magisk-patched `.img`, auto-reboots the device into fastboot mode if needed, validates the bootloader is unlocked, flashes the boot partition, and issues a reboot.
- **Live Terminal Stream** — Every line of `stdout`/`stderr` from the Bash scripts is streamed to the in-app terminal in real time via Electron IPC — the UI never freezes.
- **Color-coded Output** — Terminal lines are styled by severity: info (white), success (green), warning (yellow), error (red).
- **Robust Error Handling** — Checks for missing tools (`adb`, `fastboot`), disconnected devices, empty files, wrong magic bytes, locked bootloaders, and more — with clear, actionable messages.
- **Secure Architecture** — `contextIsolation: true`, `nodeIntegration: false`; the renderer process has zero direct Node.js access.
- **Dark UI** — GitHub-inspired dark theme built with plain HTML/CSS — no heavy UI framework needed.
- **Termux CLI Mode** — On Android, runs the core Bash scripts directly with a colour-coded interactive menu.

---

## 📸 App Preview

```
┌─────────────────────────────────────────────────────────────┐
│ 🤖  Awesome Android Root Helper      ADB / Fastboot Tool    │
├─────────────────────────────────────────────────────────────┤
│ ● Ready — connect your Android device via USB               │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────┐  ┌──────────────────────────────┐ │
│  │ 🔍 Device Status     │  │ ⚡ Flash Patched Boot        │ │
│  │                      │  │                              │ │
│  │ Checks ADB, model,   │  │ Select a Magisk-patched .img │ │
│  │ Android version &    │  │ and flash it via fastboot.   │ │
│  │ bootloader status.   │  │                              │ │
│  │  [▶ Check Device]    │  │  [📂 Select & Flash Boot]    │ │
│  └──────────────────────┘  └──────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ bash — terminal output                        ↓ ✕      │ │
│  │ › [RUN]     bash device_check.sh                       │ │
│  │ › [INFO]    Checking host prerequisites…               │ │
│  │ ✔ [SUCCESS] adb found: Android Debug Bridge 34.0.4     │ │
│  │ ✔ [SUCCESS] Model   : Pixel 7                          │ │
│  │ ✔ [SUCCESS] Bootloader: UNLOCKED (orange)              │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Project Structure

```
awesome-android-root-helper/
├── package.json          # npm manifest & Electron dependency
├── main.js               # Electron main process — window, IPC, script runner
├── preload.js            # Secure contextBridge (renderer ↔ main)
├── index.html            # Dark-themed UI (HTML + CSS)
├── renderer.js           # Frontend logic — buttons, terminal, IPC listeners
├── termux_menu.sh        # Android/Termux interactive CLI menu
└── scripts/
    ├── device_check.sh   # ADB device info & bootloader status
    └── flash_root.sh     # Fastboot boot partition flash & reboot
```

---

## ⚙️ Prerequisites

### Android Device (all platforms)

1. **Enable Developer Options**: Settings → About Phone → tap *Build Number* 7 times.
2. **Enable USB Debugging**: Settings → Developer Options → USB Debugging ✔
3. **Enable OEM Unlocking**: Settings → Developer Options → OEM Unlocking ✔ *(required for flashing)*
4. Connect via USB and **authorise** this computer when prompted on the device.

---

## 🚀 Installation & Running

Jump to your platform:

- [🐧 Linux](#-linux)
- [🪟 Windows](#-windows)
- [🍎 macOS](#-macos)
- [📱 Android (Termux)](#-android-termux)

---

### 🐧 Linux

#### 1. Node.js 18+

**Ubuntu / Debian:**
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

**Arch Linux:**
```bash
sudo pacman -S nodejs npm
```

**Fedora:**
```bash
sudo dnf install nodejs npm
```

**Any distro (via nvm — recommended):**
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install --lts
```

#### 2. Android Platform Tools (ADB + Fastboot)

**Ubuntu / Debian:**
```bash
sudo apt update && sudo apt install adb fastboot
```

**Arch Linux:**
```bash
sudo pacman -S android-tools
```

**Fedora:**
```bash
sudo dnf install android-tools
```

**Manual install (any distro — latest version):**
```bash
wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip
unzip platform-tools-latest-linux.zip
echo 'export PATH="$HOME/platform-tools:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 3. udev Rules (USB Permissions)

Without udev rules, `adb devices` may show "no permissions". Fix:

```bash
# Ubuntu / Debian (easiest)
sudo apt install android-sdk-platform-tools-common

# Or manually (works on all distros)
sudo tee /etc/udev/rules.d/51-android.rules << 'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"  # Google
SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="plugdev"  # Samsung
SUBSYSTEM=="usb", ATTR{idVendor}=="22b8", MODE="0666", GROUP="plugdev"  # Motorola
SUBSYSTEM=="usb", ATTR{idVendor}=="0bb4", MODE="0666", GROUP="plugdev"  # HTC
SUBSYSTEM=="usb", ATTR{idVendor}=="2916", MODE="0666", GROUP="plugdev"  # OnePlus
SUBSYSTEM=="usb", ATTR{idVendor}=="1004", MODE="0666", GROUP="plugdev"  # LG
SUBSYSTEM=="usb", ATTR{idVendor}=="0489", MODE="0666", GROUP="plugdev"  # Xiaomi
EOF

sudo chmod a+r /etc/udev/rules.d/51-android.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
sudo usermod -aG plugdev $USER
# Log out and back in for the group change to take effect
```

#### 4. Clone & Run

```bash
git clone https://github.com/brhanumehari/android-root.git
cd android-root
npm install
npm start
```

---

### 🪟 Windows

#### 1. Node.js 18+

Download and install **Node.js 18 LTS or higher** from [nodejs.org](https://nodejs.org/en/download).

```cmd
node --version
npm --version
```

#### 2. Git

Download from [git-scm.com](https://git-scm.com/download/win) and install with default options.

#### 3. Android Platform Tools (ADB + Fastboot)

**Option A — Google's official ZIP (recommended):**
1. Download from [developer.android.com/studio/releases/platform-tools](https://developer.android.com/studio/releases/platform-tools)
2. Extract to `C:\platform-tools`
3. Add to PATH:
   - Press `Win + S` → search *"Environment Variables"*
   - Under *System Variables* → select `Path` → click **Edit**
   - Click **New** → enter `C:\platform-tools` → click **OK** on all dialogs
4. Open a new Command Prompt and verify:
```cmd
adb version
fastboot --version
```

**Option B — Chocolatey:**
```powershell
# Run PowerShell as Administrator
choco install adb
```

#### 4. Install OEM USB Drivers

| Brand | Driver |
|-------|--------|
| Google Pixel | [Google USB Driver](https://developer.android.com/studio/run/win-usb) |
| Samsung | [Samsung USB Driver](https://developer.samsung.com/mobile/android-usb-driver.html) |
| Other | Search `[brand] USB driver Windows` |

#### 5. Clone & Run

Open **Command Prompt** or **PowerShell**:

```cmd
git clone https://github.com/brhanumehari/android-root.git
cd android-root
npm install
npm start
```

---

### 🍎 macOS

#### 1. Android Platform Tools (ADB + Fastboot)

```bash
# Homebrew (recommended)
brew install --cask android-platform-tools
```

#### 2. Clone & Run

```bash
git clone https://github.com/brhanumehari/android-root.git
cd android-root
npm install
npm start
```

---

### 📱 Android (Termux)

> Electron requires a display server that Termux doesn't have, so on Android the core Bash scripts run directly inside a colour-coded CLI menu.

#### 1. Install Termux

> ⚠️ **Use F-Droid, not the Play Store.** The Play Store version is outdated and abandoned.

Download from **[f-droid.org/packages/com.termux](https://f-droid.org/packages/com.termux/)**

#### 2. Install Required Packages

```bash
pkg update && pkg upgrade -y
pkg install -y git android-tools bash
```

#### 3. Clone & Run

```bash
git clone https://github.com/brhanumehari/android-root.git
cd android-root
chmod +x scripts/*.sh termux_menu.sh
bash termux_menu.sh
```

#### 4. Termux Connection Scenarios

**Scenario A — Root a DIFFERENT device via OTG (most common):**
Connect the target device to your phone using an OTG USB adapter. Your phone running Termux acts as the host.

**Scenario B — Check your OWN device (read-only):**
ADB local mode works for reading device info. You cannot flash your own device while it is running Termux.

**Scenario C — ADB over Wi-Fi (Android 11+, no cable needed):**
```bash
# On target device: Settings → Developer Options → Wireless Debugging → Pair device
adb pair 192.168.1.XXX:PAIRING_PORT   # enter the 6-digit code
adb connect 192.168.1.XXX:5555
adb devices
```

#### Termux Menu

```
  🤖  Awesome Android Root Helper
  Termux CLI Edition — adb 34.0.4
────────────────────────────────────────

  1)  🔍  Check Device Status
  2)  ⚡  Flash Patched Boot Image
  3)  📋  List Connected Devices (adb devices)
  4)  🔄  Reboot Device into Bootloader
  5)  🔄  Reboot Device Normally
  6)  🐚  Open ADB Shell
  q)  ✕   Quit
```

You can also run scripts directly without the menu:

```bash
bash scripts/device_check.sh
bash scripts/flash_root.sh /sdcard/Download/patched_boot.img
```

If Termux can't read `/sdcard`, run `termux-setup-storage` and accept the permission prompt. Your files will be at `~/storage/downloads/`.

---

## 🔧 How to Use

### Check Device Status
1. Connect your Android device via USB.
2. Click **▶ Check Device Status** (or choose option 1 in Termux).
3. The terminal streams: serial number, model, Android version, bootloader lock state, SELinux mode, root status.

### Flash a Patched Boot Image
1. Patch your stock `boot.img` using the **Magisk** app on your device → save the patched file.
2. Transfer the patched `.img` to your computer (or phone's storage for Termux).
3. Click **📂 Select & Flash Boot Image** (or choose option 2 in Termux and enter the file path).
4. The app automatically reboots to fastboot, flashes, and reboots back.

---

## 🔬 How It Works

### Secure IPC Architecture (Desktop)

```
Renderer (index.html / renderer.js)
        │  window.androidHelper.checkDevice()
        │  window.androidHelper.flashBoot()
        ▼
  preload.js  ──  contextBridge  ──►  ipcRenderer.send(...)
        │
        ▼
  main.js  (ipcMain.on)
        │  child_process.spawn('bash', ['scripts/device_check.sh'])
        │  stdout.on('data') → webContents.send('terminal:line', ...)
        ▼
  Renderer receives streamed lines → appends to terminal DOM
```

- **`contextIsolation: true`** — renderer and preload run in separate V8 contexts.
- **`nodeIntegration: false`** — renderer cannot access Node.js APIs directly.
- Only 5 named functions are exposed via `contextBridge` — no raw IPC access.
- Uses `cross-spawn` (not `exec`) to stream `stdout`/`stderr` line by line without buffering.

### `scripts/device_check.sh`

1. Verifies `adb` is in `PATH`.
2. Starts the ADB daemon (`adb start-server`).
3. Counts connected devices; warns on multiple, errors on zero.
4. Fetches: serial, model, brand, Android version, SDK level, build ID.
5. Reads `ro.boot.verifiedbootstate` (green/orange/yellow/red); falls back to `ro.boot.flash.locked` on older devices.
6. Checks SELinux enforcing mode.
7. Attempts `su -c 'id'` to confirm root access.

### `scripts/flash_root.sh`

1. Validates argument and tool availability (`adb`, `fastboot`).
2. Checks the `.img` file exists, is readable, non-empty, and starts with `ANDROID!` magic bytes.
3. Detects fastboot devices; if none found, reboots into bootloader via `adb reboot bootloader` and polls for up to 30 seconds.
4. Reads `fastboot getvar unlocked` — exits early with instructions if the bootloader is locked.
5. Runs `fastboot flash boot <file>` with per-line output classification.
6. Issues `fastboot reboot` to boot back into the OS.

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl/Cmd + L` | Clear terminal |
| `End` | Scroll terminal to bottom |

---

## 🛠️ Troubleshooting

### General

**"adb not found in PATH"**
Install Android Platform Tools (see your platform's section above) and ensure the install directory is on your `PATH`. Open a new terminal window after making changes.

**"No devices detected in ADB mode"**
- Ensure USB Debugging is enabled.
- Try a different USB cable or port.
- Run `adb devices` in your terminal and accept the authorisation prompt on the device screen.

**"Bootloader is LOCKED"**
You must unlock the bootloader manually before flashing:
```bash
adb reboot bootloader
fastboot flashing unlock   # Modern devices
fastboot oem unlock        # Older devices
```
Follow the on-screen prompts on the device (use Volume keys to select, Power to confirm). The device will factory reset.

**"File does not begin with ANDROID! magic bytes"**
You selected the wrong file. Export the patched `boot.img` directly from the Magisk app after patching.

**"Device does not enter fastboot after `adb reboot bootloader`"**
Hold the hardware key combination for your device (commonly **Power + Volume Down**) until the bootloader screen appears.

---

### Linux-specific

**`adb: no permissions` or `insufficient permissions`**
udev rules are missing or your user is not in the `plugdev` group. Follow the [udev rules section](#3-udev-rules-usb-permissions) and log out and back in.

**`adb devices` shows device but app can't connect**
```bash
adb kill-server && adb start-server
```

**Electron window doesn't open / `ENOENT` error**
```bash
rm -rf node_modules package-lock.json
npm install && npm start
```

**`libgbm.so.1: cannot open shared object file` on Ubuntu**
```bash
sudo apt install libgbm1
```

**Sandboxing error on some Linux distros**
```bash
npx electron --no-sandbox .
```

---

### Windows-specific

**`'adb' is not recognized`**
`C:\platform-tools` is not on your PATH. Re-follow the PATH setup steps, then open a **new** Command Prompt window.

**Device not detected / `adb devices` shows empty**
- Try a data cable (not charge-only).
- Install the OEM USB driver for your device brand (see table in Windows section above).
- In Device Manager, check for unknown devices under *Other Devices*.

**Windows Defender / antivirus blocks the app**
This is a false positive common with Electron apps. Add the project folder to your antivirus exclusions.

**PowerShell execution policy error during `npm install`**
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

---

### Termux-specific

**`adb: error: no devices/emulators found`**
- Check the OTG cable and adapter.
- Accept the USB Debugging authorisation popup on the target device.
- Try: `adb kill-server && adb start-server`

**`permission denied` running scripts**
```bash
chmod +x scripts/*.sh termux_menu.sh
```

**`fastboot: no devices found` after `adb reboot bootloader`**
Wait 10–15 seconds, then try `fastboot devices`. If still empty, unplug and replug the OTG cable.

**Can't read files from `/sdcard`**
```bash
termux-setup-storage   # Accept the permission prompt
ls ~/storage/downloads/
```

**OTG adapter not detected**
Not all phones support OTG host mode. Check your phone's specs. Some phones need OTG enabled in settings (Developer Options or Battery settings).

---

## ⚠️ Warnings & Disclaimers

- Flashing a custom boot image **may void your warranty**.
- Always **back up your data** before flashing anything.
- Use a Magisk-patched boot image that matches your **exact** device model, Android version, and build number. Using the wrong image can brick your device.
- This tool does **not** unlock your bootloader — you must do that manually before using the flash feature.
- The authors are not responsible for bricked devices, lost data, or any damage caused by use of this software.

---

## 📄 License

[MIT](LICENSE) © 2024 brhanumehari
