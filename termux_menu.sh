#!/usr/bin/env bash
# =============================================================================
# termux_menu.sh
#
# A simple interactive CLI menu for Awesome Android Root Helper.
# Designed to run inside Termux on Android — no Electron/display needed.
#
# Usage:
#   chmod +x termux_menu.sh
#   bash termux_menu.sh
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${RESET}    $*"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}    $*"; }
error()   { echo -e "${RED}[ERROR]${RESET}   $*"; }
divider() { echo -e "${DIM}────────────────────────────────────────${RESET}"; }

# ── Resolve script directory (works even if called from another path) ─────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_CHECK="${SCRIPT_DIR}/scripts/device_check.sh"
FLASH_SCRIPT="${SCRIPT_DIR}/scripts/flash_root.sh"

# ── Ensure scripts are executable ─────────────────────────────────────────────
chmod +x "${DEVICE_CHECK}" "${FLASH_SCRIPT}" 2>/dev/null || true

# ── Check for adb ─────────────────────────────────────────────────────────────
check_deps() {
  local missing=()
  command -v adb      &>/dev/null || missing+=("adb")
  command -v fastboot &>/dev/null || missing+=("fastboot")

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing tools: ${missing[*]}"
    echo ""
    echo -e "  Install with: ${CYAN}pkg install android-tools${RESET}"
    echo ""
    exit 1
  fi
}

# ── Header banner ─────────────────────────────────────────────────────────────
print_header() {
  clear
  echo ""
  echo -e "${BOLD}${GREEN}  🤖  Awesome Android Root Helper${RESET}"
  echo -e "${DIM}  Termux CLI Edition — $(adb version 2>/dev/null | head -n1 | sed 's/Android Debug Bridge /adb /')${RESET}"
  divider
  echo ""
}

# ── Main menu ─────────────────────────────────────────────────────────────────
show_menu() {
  echo -e "  ${BOLD}What would you like to do?${RESET}"
  echo ""
  echo -e "  ${CYAN}1)${RESET} 🔍  Check Device Status"
  echo -e "  ${CYAN}2)${RESET} ⚡  Flash Patched Boot Image"
  echo -e "  ${CYAN}3)${RESET} 📋  List Connected Devices (adb devices)"
  echo -e "  ${CYAN}4)${RESET} 🔄  Reboot Device into Bootloader"
  echo -e "  ${CYAN}5)${RESET} 🔄  Reboot Device Normally"
  echo -e "  ${CYAN}6)${RESET} 🐚  Open ADB Shell"
  echo -e "  ${CYAN}q)${RESET} ✕   Quit"
  echo ""
}

# ── Action: flash with file path prompt ──────────────────────────────────────
do_flash() {
  echo ""
  echo -e "${YELLOW}  Enter the full path to your patched boot image:${RESET}"
  echo -e "  ${DIM}Example: /sdcard/Download/patched_boot.img${RESET}"
  echo ""
  read -rp "  Path: " IMG_PATH

  # Trim whitespace and quotes
  IMG_PATH="${IMG_PATH//\'/}"
  IMG_PATH="${IMG_PATH//\"/}"
  IMG_PATH="${IMG_PATH// /}"

  if [[ -z "${IMG_PATH}" ]]; then
    warn "No path entered. Returning to menu."
    return
  fi

  echo ""
  divider
  bash "${FLASH_SCRIPT}" "${IMG_PATH}"
  divider
}

# ── Action: reboot to bootloader ──────────────────────────────────────────────
do_reboot_bootloader() {
  echo ""
  warn "This will reboot your device into the bootloader/fastboot mode."
  read -rp "  Are you sure? (y/N): " confirm
  if [[ "${confirm,,}" == "y" ]]; then
    info "Rebooting to bootloader…"
    adb reboot bootloader 2>&1
    success "Reboot command sent."
  else
    info "Cancelled."
  fi
}

# ── Action: normal reboot ─────────────────────────────────────────────────────
do_reboot_normal() {
  echo ""
  info "Rebooting device normally…"
  adb reboot 2>&1 || fastboot reboot 2>&1 || error "Could not reboot. Is a device connected?"
}

# ── Main loop ─────────────────────────────────────────────────────────────────
main() {
  check_deps

  while true; do
    print_header
    show_menu
    read -rp "  Your choice: " choice
    echo ""
    divider

    case "${choice}" in
      1)
        echo ""
        bash "${DEVICE_CHECK}"
        ;;
      2)
        do_flash
        ;;
      3)
        echo ""
        info "Connected devices:"
        adb devices -l 2>&1
        ;;
      4)
        do_reboot_bootloader
        ;;
      5)
        do_reboot_normal
        ;;
      6)
        echo ""
        info "Opening ADB shell. Type 'exit' to return to the menu."
        divider
        adb shell || error "Could not open ADB shell. Is a device connected?"
        ;;
      q|Q|quit|exit)
        echo ""
        echo -e "  ${DIM}Bye!${RESET}"
        echo ""
        exit 0
        ;;
      *)
        warn "Unknown option '${choice}'. Please enter 1–6 or q."
        ;;
    esac

    echo ""
    divider
    read -rp "  Press Enter to return to the menu…" _
  done
}

main
