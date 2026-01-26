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
sleep_return() { sleep 2; }

progress_bar() {
    echo -ne "${GREEN}["
    for i in {1..20}; do echo -ne "█"; sleep 0.03; done
    echo -e "]${NC}"
}

ask_yes_no() {
    read -p "$1 (y/n): " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

# ================= CHECKS =================
check_termux_api() {
    command -v termux-usb >/dev/null 2>&1 || pkg install termux-api -y
}

check_termux_adb() {
    if ! command -v termux-adb >/dev/null || ! command -v termux-fastboot >/dev/null; then
        echo -e "${RED}termux-adb / termux-fastboot not found!${NC}"
        echo -e "${GREEN}Installing adb...${NC}"
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

# ================= FASTBOOT =================
wait_fastboot() {
    local retry=0
    local max=5

    while [ $retry -lt $max ]; do
        if fastboot_connected; then
            return 0
        fi
        retry=$((retry + 1))
        echo -e "${YELLOW}Waiting for fastboot device... ($retry/$max)${NC}"
        sleep 1
    done

    echo -e "${RED}Fastboot device not found. Returning to menu.${NC}"
    pause
    return 1
}

# ================= SLOT LOGIC =================
is_ab_device() {
    termux-fastboot getvar slot-count 2>&1 | grep -q "2"
}

get_active_slot() {
    if is_ab_device; then
        termux-fastboot getvar current-slot 2>&1 \
        | sed 's/.*://g' | tr -d '[:space:]'
    fi
}
get_inactive_slot() {
    local a=$(get_active_slot)
    [ "$a" = "a" ] && echo "b"
    [ "$a" = "b" ] && echo "a"
}

# ================= VBMETA =================
flash_vbmeta_smart() {
    wait_fastboot || return

    read -p "Enter vbmeta image path: " vb
    [ ! -f "$vb" ] && echo -e "${RED}File not found${NC}" && pause && return

    if ! is_ab_device; then
        echo -e "${YELLOW}Single-slot device detected${NC}"
        progress_bar
        termux-fastboot flash \
          --disable-verity --disable-verification \
          vbmeta "$vb"
        pause
        return
    fi

    local active=$(get_active_slot)
    local inactive=$(get_inactive_slot)

    echo -e "${GREEN}A/B device detected${NC}"
    echo -e "${CYAN}Active slot  : $active${NC}"
    echo -e "${CYAN}Inactive slot: $inactive${NC}"

    progress_bar
    termux-fastboot flash \
      --disable-verity --disable-verification \
      "vbmeta_${active}" "$vb"

    if ask_yes_no "Flash vbmeta to INACTIVE slot?"; then
        progress_bar
        termux-fastboot flash \
          --disable-verity --disable-verification \
          "vbmeta_${inactive}" "$vb"
    fi

    pause
}

flash_vbmeta_slot() {
    local slot="$1"
    read -p "Enter vbmeta image path: " vb
    [ ! -f "$vb" ] && echo -e "${RED}File not found${NC}" && return
    progress_bar
    termux-fastboot flash --disable-verity --disable-verification "vbmeta_${slot}" "$vb"
}

flash_recovery_smart() {
    wait_fastboot || return

    read -p "Enter recovery image path: " img
    if [ ! -f "$img" ]; then
        echo -e "${RED}Recovery image not found!${NC}"
        pause
        return
    fi

    # ---------- SINGLE SLOT ----------
    if ! is_ab_device; then
        echo -e "${YELLOW}Single-slot (A-only) device detected${NC}"
        progress_bar
        termux-fastboot flash recovery "$img"

        if ask_yes_no "Flash vbmeta?"; then
            flash_vbmeta_smart
        fi

        pause
        return
    fi

    # ---------- A/B DEVICE ----------
    local active=$(get_active_slot)
    local inactive=$(get_inactive_slot)

    echo -e "${GREEN}A/B device detected${NC}"
    echo -e "${CYAN}Active slot  : $active${NC}"
    echo -e "${CYAN}Inactive slot: $inactive${NC}"

    # Flash active slot
    progress_bar
    termux-fastboot flash "recovery_${active}" "$img"

    # Ask inactive slot
    if ask_yes_no "Flash recovery to INACTIVE slot?"; then
        progress_bar
        termux-fastboot flash "recovery_${inactive}" "$img"
    fi

    # vbmeta active
    if ask_yes_no "Flash vbmeta to ACTIVE slot?"; then
        flash_vbmeta_slot "$active"
    fi

    # vbmeta inactive
    if ask_yes_no "Flash vbmeta to INACTIVE slot?"; then
        flash_vbmeta_slot "$inactive"
    fi

    pause
}
# ================= SMART FLASH =================
flash_partition_smart() {
    local part="$1"
    wait_fastboot || return

    read -p "Enter ${part} image path: " img
    [ ! -f "$img" ] && echo -e "${RED}File not found${NC}" && pause && return

    if ! is_ab_device; then
        echo -e "${YELLOW}Single-slot device detected${NC}"
        progress_bar
        termux-fastboot flash "$part" "$img"

        if ask_yes_no "Flash vbmeta?"; then
            flash_vbmeta_smart
        fi
        pause
        return
    fi

    local active=$(get_active_slot)
    local inactive=$(get_inactive_slot)

    echo -e "${GREEN}A/B device detected${NC}"
    echo -e "${CYAN}Active slot  : $active${NC}"
    echo -e "${CYAN}Inactive slot: $inactive${NC}"

    progress_bar
    termux-fastboot flash "${part}_${active}" "$img"

    if ask_yes_no "Flash ${part} to INACTIVE slot?"; then
        progress_bar
        termux-fastboot flash "${part}_${inactive}" "$img"
    fi

    if ask_yes_no "Flash vbmeta to ACTIVE slot?"; then
        flash_vbmeta_slot "$active"
    fi

    if ask_yes_no "Flash vbmeta to INACTIVE slot?"; then
        flash_vbmeta_slot "$inactive"
    fi

    pause
}

#==============sideload===============
adb_sideload_zip() {
    # Device must be in recovery or sideload
    if ! adb_recovery && ! adb_sideload; then
        echo -e "${RED}Device not in recovery / sideload mode${NC}"
        pause
        return
    fi

    read -p "Enter ZIP path: " zip
    if [ ! -f "$zip" ]; then
        echo -e "${RED}ZIP file not found!${NC}"
        pause
        return
    fi

    echo -e "${CYAN}Starting ADB sideload...${NC}"
    progress_bar
    termux-adb sideload "$zip"

    echo -e "${GREEN}Sideload finished${NC}"
    pause
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
    echo -e "${BLUE}║${NC} ${GREEN}2. Flash Recovery ${NC}                   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}3. Flash Vbmeta ${NC}                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}4. Direct Boot ${NC}                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}5. ADB ZIP Sideload ${NC}                 ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}6. Reboot Options ${NC}                   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${RED}7. Exit ${NC}                             ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
}

boot_flash_menu() {
    while true; do
        clear
        echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${CYAN}  Flash Boot Partitions${NC}              ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}1. boot  ${NC}                            ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}2. init_boot  ${NC}                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}3. vendor_boot  ${NC}                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${YELLOW}4. Back  ${NC}                            ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    
        read -p "Select: " c
        case $c in
            1) flash_partition_smart boot ;;
            2) flash_partition_smart init_boot ;;
            3) flash_partition_smart vendor_boot ;;
            4) break ;;
        esac
    done
}

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
        read -p "Select: " r

        case $r in
            1)
                if adb_connected; then
                    termux-adb reboot
                elif wait_fastboot; then
                    termux-fastboot reboot
                else
                    echo -e "${RED}No device connected${NC}"
                fi
                pause
                ;;
            2)
                if adb_connected; then
                    termux-adb reboot recovery
                  elif wait_fastboot; then
                    termux-fastboot reboot recovery 
                else
                    echo -e "${RED}device not connected${NC}"
                fi
                pause
                ;;
            3)
                if adb_connected; then
                    termux-adb reboot bootloader
                elif wait_fastboot; then
                    termux-fastboot reboot-bootloader
                else
                    echo -e "${RED}No device connected${NC}"
                fi
                pause
                ;;
            4) break ;;
            *) echo -e "${RED}Invalid option${NC}" ; pause ;;
        esac
    done
}

# ================= MAIN =================
check_termux_api
check_termux_adb
start_adb_server

while true; do
    draw_main_menu
    read -p "Select option: " ch
    case $ch in
        1) boot_flash_menu ;;
        2) flash_recovery_smart ;;
        3) flash_vbmeta_smart ;;
        4) wait_fastboot && read -p "Image path: " img && termux-fastboot boot "$img" && pause ;;
        5) adb_sideload_zip ;;
        6) reboot_menu ;;
        7) exit 0 ;;
    esac
done