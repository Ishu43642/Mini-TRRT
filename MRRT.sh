#!/data/data/com.termux/files/usr/bin/bash

# ================= COLORS =================
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

# ================= GLOBAL =================
USB_STATUS="USB NOT CONNECTED"
USB_COLOR="$RED"

# ================= UTILS =================
pause() { read -p "Press Enter to continue..." ; }
sleep_return() { sleep 4; }

progress_bar() {
    echo -ne "${GREEN}["
    for i in {1..20}; do echo -ne "█"; sleep 0.03; done
    echo -e "]${NC}"
}

# ================= CHECKS =================
check_termux_api() {
    command -v termux-usb >/dev/null 2>&1 || pkg install termux-api -y
}

check_termux_adb() {
    if ! command -v termux-adb >/dev/null || ! command -v termux-fastboot >/dev/null; then
        echo -e "${RED}termux-adb / termux-fastboot not found!${NC}"
      echo -e "${GREEN} ⬇️  Installing Using install adb.sh installer${NC}"
        bash installadb.sh
        
    fi
}

start_adb_server() {
    termux-adb start-server >/dev/null 2>&1
}

# ================= USB =================
scan_usb() {
    termux-usb -r >/dev/null 2>&1
    if termux-usb -l 2>/dev/null | grep -q "/dev/bus/usb"; then
        USB_STATUS="USB CONNECTED"
        USB_COLOR="$YELLOW"
    else
        USB_STATUS="USB NOT CONNECTED"
        USB_COLOR="$RED"
    fi
}

# ================= DEVICE STATE =================
adb_state() {
    termux-adb devices 2>/dev/null | awk 'NR>1 {print $2}'
}

adb_connected()    { adb_state | grep -q '^device$'; }
adb_recovery()     { adb_state | grep -q '^recovery$'; }
adb_sideload()     { adb_state | grep -q '^sideload$'; }
adb_unauthorized() { adb_state | grep -q '^unauthorized$'; }

fastboot_connected() {
    termux-fastboot devices 2>/dev/null | grep -q fastboot
}

connection_type() {
    if adb_sideload; then
        echo -e "${CYAN}RECOVERY (SIDELOAD)${NC}"
    elif adb_recovery; then
        echo -e "${CYAN}RECOVERY MODE${NC}"
    elif adb_connected; then
        echo -e "${GREEN}ADB MODE${NC}"
    elif adb_unauthorized; then
        echo -e "${YELLOW}ADB UNAUTHORIZED${NC}"
    elif fastboot_connected; then
        echo -e "${BLUE}FASTBOOT MODE${NC}"
    else
        echo -e "${RED}DISCONNECTED${NC}"
    fi
}

# ================= FASTBOOT WAIT =================
wait_fastboot() {
    for i in {1..5}; do
        fastboot_connected && return 0
        sleep 1
    done
    echo -e "${RED}Fastboot device not found. Returning to menu.${NC}"
    sleep_return
    return 1
}

# ================= UI =================
draw_main_menu() {
    scan_usb
    clear
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${CYAN}  💠 MiNi ROOT RECOVERY TOOL 💠${NC}      ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} USB  : ${USB_COLOR}${USB_STATUS}    ${NC}             ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} MODE : $(connection_type)                 ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}1. Flash Boot / Init / Vendor Boot  ${NC} ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}2. Flash Vbmeta ${NC}                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}3. Direct Boot ${NC}                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}4. ADB ZIP Sideload ${NC}                 ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}5. Reboot Options ${NC}                   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${RED}6. Exit ${NC}                             ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
}

draw_boot_menu() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${CYAN}  Flash Boot Partitions${NC}              ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}1. boot  ${NC}                            ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}2. init_boot  ${NC}                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}3. vendor_boot  ${NC}                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${YELLOW}4. Back  ${NC}                            ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo -ne "${YELLOW}Select option [1-4]: ${NC}"
}
# ================= FLASH =================
flash_partition() {
    part=$1
    wait_fastboot || return
    echo -ne "${GREEN}Enter image path: ${NC}"
    read img
    [ ! -f "$img" ] && echo -e "${RED}File not found${NC}" && pause && return
    progress_bar
    termux-fastboot flash "$part" "$img"
    pause
}

boot_flash_menu() {
    while true; do
        draw_boot_menu
        read c
        case $c in
            1) flash_partition boot ;;
            2) flash_partition init_boot ;;
            3) flash_partition vendor_boot ;;
            4) break ;;
            *) echo -e "${RED}Invalid option${NC}" ; pause ;;
        esac
    done
}

direct_boot() {
    wait_fastboot || return
    echo -ne "${GREEN}Enter image path: ${NC}"
    read img
    [ ! -f "$img" ] && echo -e "${RED}File not found${NC}" && pause && return
    progress_bar
    termux-fastboot boot "$img"
    pause
}

flash_vbmeta() {
    wait_fastboot || return

    echo -ne "${GREEN}Enter vbmeta image path: ${NC}"
    read vb
    [ ! -f "$vb" ] && echo -e "${RED}File not found!${NC}" && pause && return

    slot=$(termux-fastboot getvar current-slot 2>&1 | grep -o '[ab]')
    [ -z "$slot" ] && slot=""

    progress_bar

    if [ -n "$slot" ]; then
        termux-fastboot flash --disable-verity --disable-verification vbmeta_${slot} "$vb" || \
        termux-fastboot flash --disable-verity --disable-verification vbmeta "$vb"
    else
        termux-fastboot flash --disable-verity --disable-verification vbmeta "$vb"
    fi

    pause
}

# ================= SIDELOAD =================
adb_sideload_zip() {
    if ! adb_recovery && ! adb_sideload; then
        echo -e "${RED}Device not in recovery / sideload mode${NC}"
        pause
        return
    fi
    echo -ne "${GREEN}Enter ZIP path: ${NC}"
    read zip
    [ ! -f "$zip" ] && echo -e "${RED}ZIP not found${NC}" && pause && return
     progress_bar
    termux-adb sideload "$zip"
    pause
}

# ================= REBOOT =================
reboot_menu() {
    while true; do
        clear
        echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${NC} ${CYAN}   ♻️  Reboot Options${NC}                 ${BLUE}║${NC}"
        echo -e "${BLUE}╠══════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} ${GREEN}  1. Reboot System${NC}                   ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${GREEN}  2. Reboot Recovery${NC}                 ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${GREEN}  3. Reboot Bootloader${NC}               ${BLUE}║${NC}"
        echo -e "${BLUE}║${NC} ${YELLOW}  4. Back${NC}                            ${BLUE}║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
        echo -ne "${YELLOW}Select option [1-4]: ${NC}"

        read r
        case $r in
            1) termux-adb reboot || termux-fastboot reboot ; sleep_return ;;
            2) termux-adb reboot recovery ; sleep_return ;;
            3) termux-adb reboot bootloader || termux-fastboot reboot-bootloader ; sleep_return ;;
            4) break ;;
            *) echo -e "${RED}Invalid option!${NC}" ; pause ;;
        esac
    done
}
# ================= MAIN =================
check_termux_api
check_termux_adb
start_adb_server

while true; do
    draw_main_menu
    echo -ne "${YELLOW}Select option [1-6]: ${NC}"
    read ch
    case $ch in
        1) boot_flash_menu ;;
        2) flash_vbmeta ;;
        3) direct_boot ;;
        4) adb_sideload_zip ;;
        5) reboot_menu ;;
        6) exit 0 ;;
    esac
done