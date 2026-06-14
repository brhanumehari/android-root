#!/usr/bin/env bash
# =============================================================================
# device_check.sh
#
# Checks:
#   1. That 'adb' is installed on the host
#   2. That exactly one device is connected over ADB
#   3. The device model via getprop ro.product.model
#   4. The Android version via getprop ro.build.version.release
#   5. Bootloader lock status via getprop ro.boot.verifiedbootstate
#   6. USB debugging state
#
# Exit codes:
#   0 = all checks passed
#   1 = error / device not found / adb missing
# =============================================================================

set -euo pipefail

# ── Colour helpers (stripped to plain text since output goes to the Electron
#    terminal renderer which handles its own styling) ────────────────────────
info()    { echo "[INFO]    $*"; }
success() { echo "[SUCCESS] $*"; }
warn()    { echo "[WARN]    $*"; }
error()   { echo "[ERROR]   $*" >&2; }

# ── 1. Verify ADB is installed ───────────────────────────────────────────────
info "Checking host prerequisites…"

if ! command -v adb &>/dev/null; then
  error "adb not found in PATH."
  error "Install Android Platform Tools:"
  error "  macOS : brew install --cask android-platform-tools"
  error "  Debian: sudo apt install adb"
  error "  Arch  : sudo pacman -S android-tools"
  exit 1
fi

ADB_VERSION=$(adb version | head -n1)
success "adb found: ${ADB_VERSION}"

# ── 2. Start / verify the ADB daemon ─────────────────────────────────────────
info "Starting ADB server (if not already running)…"
adb start-server 2>&1 | while IFS= read -r line; do
  info "(adb) ${line}"
done

# ── 3. List connected devices ─────────────────────────────────────────────────
info "Scanning for connected devices…"

DEVICE_LIST=$(adb devices 2>&1)
echo "${DEVICE_LIST}" | while IFS= read -r line; do
  info "${line}"
done

# Count lines that represent actual devices (not the header, not empties)
DEVICE_COUNT=$(echo "${DEVICE_LIST}" \
  | tail -n +2 \
  | grep -cE "^[A-Za-z0-9_.:]+[[:space:]]+(device|recovery|sideload|bootloader)" 2>/dev/null || true)

if [[ "${DEVICE_COUNT}" -eq 0 ]]; then
  error "No devices detected in ADB mode."
  error "Ensure:"
  error "  • The device is connected via USB"
  error "  • USB Debugging is enabled in Developer Options"
  error "  • You have authorised this computer on the device"
  exit 1
fi

if [[ "${DEVICE_COUNT}" -gt 1 ]]; then
  warn "Multiple devices found (${DEVICE_COUNT}). Using the first available device."
  warn "Set ANDROID_SERIAL to target a specific device."
fi

# ── 4. Wait for ADB to be ready ───────────────────────────────────────────────
info "Waiting for device to be fully ready…"
if ! adb wait-for-device 2>&1; then
  error "Timed out waiting for device."
  exit 1
fi

# ── 5. Fetch device properties ────────────────────────────────────────────────
info "──────────────────────────────────────"
info "  Device Information"
info "──────────────────────────────────────"

SERIAL=$(adb get-serialno 2>&1 || echo "unknown")
success "Serial number     : ${SERIAL}"

MODEL=$(adb shell getprop ro.product.model 2>&1 | tr -d '\r')
if [[ -z "${MODEL}" ]]; then
  warn "Could not retrieve device model."
else
  success "Model             : ${MODEL}"
fi

BRAND=$(adb shell getprop ro.product.brand 2>&1 | tr -d '\r')
success "Brand             : ${BRAND}"

ANDROID_VER=$(adb shell getprop ro.build.version.release 2>&1 | tr -d '\r')
success "Android version   : ${ANDROID_VER}"

SDK_VER=$(adb shell getprop ro.build.version.sdk 2>&1 | tr -d '\r')
success "SDK level         : ${SDK_VER}"

BUILD_ID=$(adb shell getprop ro.build.id 2>&1 | tr -d '\r')
success "Build ID          : ${BUILD_ID}"

# ── 6. Bootloader lock status ─────────────────────────────────────────────────
info "──────────────────────────────────────"
info "  Bootloader & Security"
info "──────────────────────────────────────"

# ro.boot.verifiedbootstate: green = locked, orange = unlocked, red = failed
VBS=$(adb shell getprop ro.boot.verifiedbootstate 2>&1 | tr -d '\r')
if [[ -z "${VBS}" ]]; then
  # Older devices may not have this prop; fall back to ro.boot.flash.locked
  VBS=$(adb shell getprop ro.boot.flash.locked 2>&1 | tr -d '\r')
  if [[ "${VBS}" == "1" ]]; then
    VBS="green"
  elif [[ "${VBS}" == "0" ]]; then
    VBS="orange"
  fi
fi

case "${VBS}" in
  green)
    warn "Bootloader status : LOCKED (verifiedbootstate=green)"
    warn "You must unlock the bootloader before flashing."
    warn "Typically: Settings → Developer Options → OEM Unlocking"
    ;;
  orange)
    success "Bootloader status : UNLOCKED (verifiedbootstate=orange)"
    success "You can flash a custom boot image."
    ;;
  yellow)
    warn "Bootloader status : CUSTOM (verifiedbootstate=yellow)"
    warn "A custom key is being used to verify the boot image."
    ;;
  red)
    error "Bootloader status : FAILED (verifiedbootstate=red)"
    error "The boot image failed verification. The device may be compromised."
    ;;
  *)
    warn "Bootloader status : UNKNOWN (verifiedbootstate='${VBS}')"
    warn "Could not determine lock status. Check manually."
    ;;
esac

# ── 7. Check SELinux enforcing mode ──────────────────────────────────────────
SELINUX=$(adb shell getenforce 2>/dev/null | tr -d '\r' || echo "unavailable")
success "SELinux mode      : ${SELINUX}"

# ── 8. Check root access ──────────────────────────────────────────────────────
info "──────────────────────────────────────"
info "  Root Access Check"
info "──────────────────────────────────────"

# Try 'id' as root; this will succeed on rooted devices
ROOT_ID=$(adb shell "su -c 'id' 2>/dev/null" 2>&1 | tr -d '\r' || true)
if echo "${ROOT_ID}" | grep -q "uid=0"; then
  success "Root access       : AVAILABLE (su works, uid=0)"
else
  WHOAMI=$(adb shell whoami 2>/dev/null | tr -d '\r' || echo "unknown")
  warn "Root access       : NOT AVAILABLE (running as '${WHOAMI}')"
  info "Flash a Magisk-patched boot image to gain root."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
info "──────────────────────────────────────"
success "Device check complete."
info "──────────────────────────────────────"

exit 0
