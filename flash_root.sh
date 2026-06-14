#!/usr/bin/env bash
# =============================================================================
# flash_root.sh
#
# Usage: flash_root.sh <path-to-patched-boot.img>
#
# Steps:
#   1. Validate arguments and tools (fastboot, adb)
#   2. Verify the .img file exists and is non-empty
#   3. Confirm the device is in Fastboot mode (or offer to reboot into it)
#   4. Identify the connected fastboot device
#   5. Flash the boot partition
#   6. Reboot the device normally
#
# Exit codes:
#   0 = success
#   1 = error
# =============================================================================

set -euo pipefail

info()    { echo "[INFO]    $*"; }
success() { echo "[SUCCESS] $*"; }
warn()    { echo "[WARN]    $*"; }
error()   { echo "[ERROR]   $*" >&2; }

# ── 1. Argument validation ────────────────────────────────────────────────────
if [[ $# -lt 1 || -z "${1}" ]]; then
  error "No boot image path provided."
  error "Usage: flash_root.sh <path-to-patched-boot.img>"
  exit 1
fi

BOOT_IMG="${1}"

info "──────────────────────────────────────"
info "  Pre-flight Checks"
info "──────────────────────────────────────"

# ── 2. Check host tools ───────────────────────────────────────────────────────
MISSING_TOOLS=()

if ! command -v fastboot &>/dev/null; then
  MISSING_TOOLS+=("fastboot")
fi
if ! command -v adb &>/dev/null; then
  MISSING_TOOLS+=("adb")
fi

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
  error "Required tool(s) not found in PATH: ${MISSING_TOOLS[*]}"
  error "Install Android Platform Tools:"
  error "  macOS : brew install --cask android-platform-tools"
  error "  Debian: sudo apt install adb fastboot"
  error "  Arch  : sudo pacman -S android-tools"
  exit 1
fi

FASTBOOT_VERSION=$(fastboot --version 2>&1 | head -n1 || echo "unknown")
success "fastboot found: ${FASTBOOT_VERSION}"

ADB_VERSION=$(adb version 2>&1 | head -n1 || echo "unknown")
success "adb found     : ${ADB_VERSION}"

# ── 3. Validate the boot image file ───────────────────────────────────────────
info "Validating boot image…"

if [[ ! -f "${BOOT_IMG}" ]]; then
  error "File not found: ${BOOT_IMG}"
  exit 1
fi

if [[ ! -r "${BOOT_IMG}" ]]; then
  error "File is not readable: ${BOOT_IMG}"
  exit 1
fi

FILE_SIZE=$(wc -c < "${BOOT_IMG}" | tr -d ' ')
if [[ "${FILE_SIZE}" -eq 0 ]]; then
  error "File is empty: ${BOOT_IMG}"
  exit 1
fi

FILE_SIZE_MB=$(awk "BEGIN { printf \"%.2f\", ${FILE_SIZE}/1048576 }")
success "Boot image    : ${BOOT_IMG}"
success "File size     : ${FILE_SIZE_MB} MB (${FILE_SIZE} bytes)"

# Sanity-check: Android boot images start with the magic bytes "ANDROID!"
MAGIC=$(dd if="${BOOT_IMG}" bs=8 count=1 2>/dev/null | cat)
if [[ "${MAGIC}" != "ANDROID!" ]]; then
  warn "File does not begin with 'ANDROID!' magic bytes."
  warn "This might not be a valid Android boot image."
  warn "Proceeding anyway — double-check your file."
else
  success "Boot image magic bytes verified (ANDROID!)."
fi

# ── 4. Detect device mode ─────────────────────────────────────────────────────
info "──────────────────────────────────────"
info "  Device Detection"
info "──────────────────────────────────────"

# Check fastboot devices
FASTBOOT_DEVICES=$(fastboot devices 2>&1)
info "fastboot devices output:"
echo "${FASTBOOT_DEVICES}" | while IFS= read -r line; do
  info "  ${line}"
done

FASTBOOT_COUNT=$(echo "${FASTBOOT_DEVICES}" \
  | grep -cE "[A-Za-z0-9_.:]+[[:space:]]+fastboot" 2>/dev/null || true)

if [[ "${FASTBOOT_COUNT}" -eq 0 ]]; then
  # Maybe the device is still in ADB mode — offer to reboot it
  info "No device found in fastboot mode. Checking ADB…"

  ADB_DEVICES=$(adb devices 2>&1)
  ADB_COUNT=$(echo "${ADB_DEVICES}" \
    | tail -n +2 \
    | grep -cE "^[A-Za-z0-9_.:]+[[:space:]]+device" 2>/dev/null || true)

  if [[ "${ADB_COUNT}" -gt 0 ]]; then
    warn "Device is in ADB mode, not fastboot mode."
    info "Rebooting device into fastboot / bootloader mode…"
    adb reboot bootloader 2>&1 | while IFS= read -r line; do info "(adb) ${line}"; done

    # Wait up to 30 seconds for the device to appear in fastboot
    info "Waiting for device to enter fastboot mode (up to 30 s)…"
    WAIT=0
    MAX_WAIT=30
    while [[ "${WAIT}" -lt "${MAX_WAIT}" ]]; do
      sleep 1
      WAIT=$(( WAIT + 1 ))
      FB=$(fastboot devices 2>&1)
      FC=$(echo "${FB}" | grep -cE "[A-Za-z0-9_.:]+[[:space:]]+fastboot" 2>/dev/null || true)
      if [[ "${FC}" -gt 0 ]]; then
        success "Device entered fastboot mode after ${WAIT}s."
        FASTBOOT_COUNT="${FC}"
        break
      fi
    done

    if [[ "${FASTBOOT_COUNT}" -eq 0 ]]; then
      error "Device did not enter fastboot mode within ${MAX_WAIT} seconds."
      error "Try manually:"
      error "  • Hold Power + Volume Down (most devices) to enter bootloader"
      error "  • Then re-run this operation"
      exit 1
    fi
  else
    error "No device found in fastboot or ADB mode."
    error "Ensure:"
    error "  • Device is connected via USB"
    error "  • Bootloader is unlocked"
    error "  • USB Debugging or Bootloader USB is enabled"
    exit 1
  fi
fi

if [[ "${FASTBOOT_COUNT}" -gt 1 ]]; then
  warn "Multiple fastboot devices found. Using the first device."
fi

# Get the serial of the first fastboot device
FASTBOOT_SERIAL=$(fastboot devices 2>/dev/null \
  | grep -E "[A-Za-z0-9_.:]+[[:space:]]+fastboot" \
  | head -n1 \
  | awk '{print $1}')

success "Fastboot device : ${FASTBOOT_SERIAL}"

# ── 5. Get device variables for confirmation ──────────────────────────────────
info "──────────────────────────────────────"
info "  Fastboot Device Info"
info "──────────────────────────────────────"

# Capture some variables for context (these are informational; failure is non-fatal)
FB_PRODUCT=$(fastboot -s "${FASTBOOT_SERIAL}" getvar product 2>&1 | grep "^product:" | sed 's/product: //' || echo "unknown")
FB_VARIANT=$(fastboot -s "${FASTBOOT_SERIAL}" getvar variant 2>&1 | grep "^variant:" | sed 's/variant: //' || echo "unknown")
FB_UNLOCKED=$(fastboot -s "${FASTBOOT_SERIAL}" getvar unlocked 2>&1 | grep "^unlocked:" | sed 's/unlocked: //' || echo "unknown")

success "Product         : ${FB_PRODUCT}"
success "Variant         : ${FB_VARIANT}"
success "Unlocked        : ${FB_UNLOCKED}"

if [[ "${FB_UNLOCKED}" == "no" ]]; then
  error "Bootloader is LOCKED. Flashing will fail."
  error "Enable OEM Unlocking:"
  error "  1. Settings → About Phone → tap Build Number 7 times"
  error "  2. Settings → Developer Options → Enable OEM Unlocking"
  error "  3. Run: fastboot oem unlock  (or fastboot flashing unlock)"
  exit 1
fi

# ── 6. Flash the boot partition ───────────────────────────────────────────────
info "──────────────────────────────────────"
info "  Flashing Boot Partition"
info "──────────────────────────────────────"
info "Target partition : boot"
info "Image            : ${BOOT_IMG}"
info "Device           : ${FASTBOOT_SERIAL}"

# Run fastboot flash and capture all output (fastboot writes to stderr)
if fastboot -s "${FASTBOOT_SERIAL}" flash boot "${BOOT_IMG}" 2>&1 | \
    while IFS= read -r line; do
      # Emit [SUCCESS] for "finished" lines, [ERROR] for "FAILED", else [INFO]
      if echo "${line}" | grep -qiE "(finished|okay|writing|sending)"; then
        echo "[SUCCESS] ${line}"
      elif echo "${line}" | grep -qiE "(FAILED|error)"; then
        echo "[ERROR]   ${line}"
      else
        echo "[INFO]    ${line}"
      fi
    done; then
  success "fastboot flash completed successfully."
else
  FLASH_EXIT=$?
  error "fastboot flash failed with exit code ${FLASH_EXIT}."
  error "Common causes:"
  error "  • Wrong image for this device/slot (A/B vs A-only)"
  error "  • Bootloader still locked"
  error "  • Corrupted .img file"
  exit 1
fi

# ── 7. Reboot the device ──────────────────────────────────────────────────────
info "──────────────────────────────────────"
info "  Rebooting Device"
info "──────────────────────────────────────"
info "Sending reboot command…"

fastboot -s "${FASTBOOT_SERIAL}" reboot 2>&1 | while IFS= read -r line; do
  info "(fastboot) ${line}"
done

success "Reboot command sent."
success "Your device is now booting. First boot may take 1–2 minutes."
info "──────────────────────────────────────"
success "Flash operation complete!"
info "──────────────────────────────────────"

exit 0
