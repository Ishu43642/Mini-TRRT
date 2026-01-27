#!/data/data/com.termux/files/usr/bin/bash

# ================= COLORS =================
RED="$(printf '\033[31m')"
GREEN="$(printf '\033[32m')"
YELLOW="$(printf '\033[33m')"
BLUE="$(printf '\033[34m')"
PURPLE="$(printf '\033[35m')"
CYAN="$(printf '\033[36m')"
WHITE="$(printf '\033[97m')"
RESET="$(printf '\033[0m')"

clear

# ================= SPLASH HEADER =================
printf "%s\n" "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
printf "%s\n" "┃      ★ Repair A2Z Root Tool ★              ┃"
printf "%s\n" "┃          Android Edition                   ┃"
printf "%s\n" "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RESET}"

sleep 0.5

# ================= ASCII LOGO =================
printf "%s\n" "${GREEN}"
printf "    ████████╗██████╗   ██████╗   ████████╗\n"
printf "    ╚══██╔══╝██╔══██╗  ██╔══██╗  ╚══██╔══╝\n"
printf "       ██║   ██████╔╝  ██████╔╝     ██║  \n"
printf "       ██║   ██╔══██╗  ██╔══██╗     ██║   \n"
printf "       ██║   ██║  ██║  ██║  ██║     ██║   \n"
printf "       ╚═╝   ╚═╝  ╚═╝  ╚═╝  ╚═╝     ╚═╝   \n"
printf " Mini  Termux - Root - Recovery - Tool\n"
printf "%s\n" "${RESET}"

sleep 2

# ================= STATUS TEXT =================
printf "%s* Initializing environment...%s\n" "$YELLOW" "$RESET"
sleep 0.4
printf "%s* Checking Termux environment...%s\n" "$YELLOW" "$RESET"
sleep 0.4
printf "%s* Preparing ADB/Fastboot interface...%s\n" "$YELLOW" "$RESET"
sleep 0.4
printf "%s* Loading UI Engine...%s\n" "$YELLOW" "$RESET"
sleep 0.4

printf "\n%sLoading Repair A2Z Presents...%s\n" "$CYAN" "$RESET"
printf "%s*Mini Termux Root Recovery Tool*....%s\n\n" "$CYAN" "$RESET"

# ================= PROGRESS BAR =================
i=0
while [ "$i" -le 100 ]; do
    bars=$(expr "$i" / 5)
    spaces=$(expr 20 - "$bars")

    printf "["
    j=0
    while [ "$j" -lt "$bars" ]; do
        printf "█"
        j=$(expr "$j" + 1)
    done

    j=0
    while [ "$j" -lt "$spaces" ]; do
        printf " "
        j=$(expr "$j" + 1)
    done

    printf "] %s%%\r" "$i"
    sleep 0.15
    i=$(expr "$i" + 15)
done

printf "\n"
sleep 0.5

# ================= FOOTER =================
printf "%s\n" "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
printf "%s\n" "┃  Developed By : Repair A2Z                   ┃"
printf "%s\n" "┃  YouTube      : @repaira2z                   ┃"
printf "%s\n" "┃  Instagram    : dineshpatel43642             ┃"
printf "%s\n" "┃  Telegram     : RepairA2Z / group            ┃"
printf "%s\n" "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RESET}"

sleep 1

./MRRT.sh