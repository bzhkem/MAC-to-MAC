#!/bin/bash
# Auteur : Bzhkem - MTM (Machine Trace Modifier) - v2.0
# Description : Outil professionnel de spoofing disque/MAC/UUID/hostname avec interface TUI

set -euo pipefail
IFS=$'\n\t'

# === CONFIG ===
MODULE="spoof_disk_serial.ko"
LOGFILE="/var/log/mtm.log"
CONFIG_FILE="/etc/mtm.conf"
VERBOSE=0
DRY_RUN=0

declare -A OUIS=(
    [Apple]="00:17:F2 D4:F4:6F A4:5E:60 48:3C:0C F4:F1:5A"
    [Synology]="00:11:32 00:15:88 00:1B:57"
    [Cisco]="00:1B:54 00:0F:F7 00:25:9C"
    [Intel]="00:1B:21 3C:97:0E 00:13:E8"
    [Dell]="00:14:22 00:21:9B 28:D2:44"
    [VMware]="00:05:69 00:0C:29 00:50:56"
    [Microsoft]="00:03:FF 00:15:5D"
    [QEMU]="52:54:00"
    [Google]="3C:5A:B4 94:EB:CD 54:60:09"
    [ASUS]="00:1C:23 AC:22:0B B4:AE:2B"
    [Lenovo]="00:0A:E4"
    [Realtek]="00:E0:4C"
    [TP-Link]="50:C7:BF"
    [Broadcom]="00:10:18"
    [Gigabyte]="74:D0:2B"
    [Xiaomi]="64:09:80"
    [ASRock]="00:1C:42"
    [Tenda]="D8:15:0D"
    [HP]="3C:D9:2B"
    [Foxconn]="00:1E:64"
    [Apple]="00:17:F2 D4:F4:6F A4:5E:60 48:3C:0C F4:F1:5A DC:A9:04 F0:18:98 D0:AB:C5 7C:C3:A1 BC:52:B7"
    [Samsung]="00:12:3F 00:16:32 00:19:5B 00:22:6B 30:16:CF"
    [Huawei]="00:1E:C0 00:1F:3B 2C:F0:5D 68:7F:74"
    [Xiaomi]="64:09:80 40:F3:08 8C:BE:BE"
    [OnePlus]="18:74:2E 44:94:FC 80:EA:96"
    [Google]="3C:5A:B4 90:5C:44 24:D6:61"
    [LG]="00:0D:B9 00:15:99 18:F3:8B"
    [Motorola]="00:0A:88 00:0E:0A 00:12:17"
    [Sony]="00:16:AE 00:19:E0 00:25:00"
    [HTC]="00:0F:16 00:13:46 00:17:F8"
    [Nokia]="00:02:EE 00:0F:BB 3C:BD:3E"
    [Nintendo]="00:09:BF 00:1B:59 30:85:A9"
    [Realme]="04:8D:38 8C:29:B4"
    [Oppo]="AC:67:B2 3C:BD:3D"
)

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

# === Logging ===
function log() {
    local msg="$1"
    echo "$(date '+%F %T') - $msg" >> "$LOGFILE"
    (( VERBOSE )) && echo -e "$msg"
}

# === Check root ===
function check_root() {
    if [[ $EUID -ne 0 ]]; then
        dialog --msgbox "Ce script doit être lancé en root." 6 40
        exit 1
    fi
}

# === Check dependencies ===
function check_dependencies() {
    for cmd in dialog make lsblk blkid tune2fs ip; do
        if ! command -v $cmd &>/dev/null; then
            dialog --msgbox "La commande '$cmd' est requise mais absente. Installez-la." 7 50
            exit 1
        fi
    done
}

# === Banner ===
function banner() {
    clear
    echo -e "${BLUE}"
    echo " __  __ _______ __  __     __  __ _____ _____ "
    echo "|  \/  |__   __|  \/  |   |  \/  |_   _|  __ \\"
    echo "| \\  / |  | |  | \\  / |   | \\  / | | | | |__) |"
    echo "| |\\/| |  | |  | |\\/| |   | |\\/| | | | |  ___/"
    echo "| |  | |  | |  | |  | |   | |  | |_| |_| |    "
    echo "|_|  |_|  |_|  |_|  |_|   |_|  |_|_____|_|    "
    echo "             Machine Trace Modifier (MTM)"
    echo -e "${NC}"
}

# === Load config file if exists ===
function load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        log "[Config] Loaded config file $CONFIG_FILE"
    fi
}

# === Check module and compile if missing ===
function check_module() {
    if [[ ! -f "$MODULE" ]]; then
        log "[*] Module $MODULE introuvable, compilation en cours..."
        make || {
            dialog --msgbox "Erreur compilation module kernel." 7 40
            log "[ERROR] Compilation module kernel échouée."
            exit 1
        }
        log "[✓] Compilation réussie."
    fi
}

# === Load kernel module ===
function load_module() {
    local serial=$1
    local device=$2

    if lsmod | grep -q spoof_disk_serial; then
        if ! dialog --yesno "Le module est déjà chargé. Voulez-vous le décharger avant ?" 7 50; then
            return 1
        fi
        sudo rmmod spoof_disk_serial
        log "[*] Module spoof_disk_serial déchargé."
    fi

    if (( DRY_RUN )); then
        dialog --msgbox "DRY-RUN: Chargement module avec serial='$serial' sur device='$device' (non appliqué)" 8 60
        log "[DRY RUN] Chargement module spoof_disk_serial (serial=$serial device=$device)"
        return 0
    fi

    sudo insmod "$MODULE" serial="$serial" device="$device" && {
        dialog --msgbox "Module chargé avec succès sur /dev/$device (serial=$serial)" 7 60
        log "[✓] Module chargé: /dev/$device serial=$serial"
        return 0
    } || {
        dialog --msgbox "Erreur lors du chargement du module." 7 40
        log "[ERROR] Chargement module échoué"
        return 1
    }
}

# === Menu: spoof disk serial ===
function spoof_disk_serial() {
    check_module
    local devices
    devices=($(lsblk -dno NAME,SIZE -e 7))
    local menu_list=()
    local idx=1
    for dev in "${devices[@]}"; do
        menu_list+=("$idx" "$dev")
        ((idx++))
    done

    local choice
    choice=$(dialog --menu "Sélectionnez un disque:" 15 50 6 "${menu_list[@]}" 3>&1 1>&2 2>&3) || return

    local device=$(echo "${devices[$((choice-1))]}" | awk '{print $1}')
    if [[ -z "$device" ]]; then
        dialog --msgbox "Disque invalide sélectionné." 6 40
        return
    fi

    local serial
    if dialog --yesno "Voulez-vous générer un numéro de série aléatoire ?" 7 50; then
        serial=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    else
        serial=$(dialog --inputbox "Entrez un numéro de série personnalisé (16 caractères max):" 8 60 3>&1 1>&2 2>&3)
        [[ -z "$serial" ]] && { dialog --msgbox "Numéro de série invalide." 6 40; return; }
    fi

    load_module "$serial" "$device"
}

# === Menu: spoof MAC ===
function spoof_mac() {
    local ifaces=()
    mapfile -t ifaces < <(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
    local menu_list=()
    local idx=1
    for iface in "${ifaces[@]}"; do
        menu_list+=("$idx" "$iface")
        ((idx++))
    done

    local choice
    choice=$(dialog --menu "Sélectionnez une interface réseau:" 15 50 6 "${menu_list[@]}" 3>&1 1>&2 2>&3) || return
    local iface="${ifaces[$((choice-1))]}"

    local oui_keys=("${!OUIS[@]}")
    local oui_menu=()
    idx=1
    for key in "${oui_keys[@]}"; do
        oui_menu+=("$idx" "$key")
        ((idx++))
    done

    local oui_choice
    oui_choice=$(dialog --menu "Sélectionnez un constructeur OUI:" 15 50 6 "${oui_menu[@]}" 3>&1 1>&2 2>&3) || return
    local prefix="${OUIS[${oui_keys[$((oui_choice-1))]}]}"

    local random_part
    random_part=$(hexdump -n 3 -e '/1 ":%02X"' /dev/urandom)
    local mac="$prefix$random_part"

    if (( DRY_RUN )); then
        dialog --msgbox "DRY-RUN: MAC $iface changé en $mac (non appliqué)" 7 60
        log "[DRY RUN] Spoof MAC $iface => $mac"
        return
    fi

    sudo ip link set "$iface" down
    sudo ip link set "$iface" address "$mac"
    sudo ip link set "$iface" up

    dialog --msgbox "MAC spoofée sur $iface : $mac" 7 50
    log "[✓] Spoof MAC $iface => $mac"
}

# === Menu: spoof UUID ext2/3/4 ===
function spoof_all_uuid() {
    local parts=()
    mapfile -t parts < <(lsblk -lnpo NAME,TYPE | awk '$2=="part"{print $1}')

    local changed=0
    for p in "${parts[@]}"; do
        local fstype
        fstype=$(blkid -o value -s TYPE "$p" 2>/dev/null || echo "")
        if [[ "$fstype" =~ ext[234] ]]; then
            if (( DRY_RUN )); then
                log "[DRY RUN] UUID randomisé sur $p"
            else
                sudo tune2fs -U random "$p"
                changed=1
                log "[✓] UUID randomisé sur $p"
            fi
        fi
    done

    if (( changed == 0 )) && (( DRY_RUN == 0 )); then
        dialog --msgbox "Aucune partition ext2/3/4 détectée pour modification." 7 50
    else
        dialog --msgbox "UUIDs randomisés avec succès." 7 40
    fi
}

# === Menu: change hostname ===
function spoof_hostname() {
    local newhost
    newhost=$(tr -dc a-z0-9 </dev/urandom | head -c 8)

    if (( DRY_RUN )); then
        dialog --msgbox "DRY-RUN: Nouveau hostname = $newhost (non appliqué)" 7 50
        log "[DRY RUN] Hostname changé en $newhost"
        return
    fi

    sudo hostnamectl set-hostname "$newhost"
    dialog --msgbox "Hostname modifié en : $newhost" 7 40
    log "[✓] Hostname modifié => $newhost"
}

# === Menu: retirer spoof disque ===
function remove_disk_spoof() {
    if ! lsmod | grep -q spoof_disk_serial; then
        dialog --msgbox "Le module spoof_disk_serial n'est pas chargé." 6 50
        return
    fi

    if dialog --yesno "Confirmez-vous le retrait du spoof disque ?" 7 50; then
        if (( DRY_RUN )); then
            dialog --msgbox "DRY-RUN: Module spoof_disk_serial retiré (non appliqué)" 7 50
            log "[DRY RUN] Retrait module spoof_disk_serial"
            return
        fi
        sudo rmmod spoof_disk_serial
        dialog --msgbox "Module spoof_disk_serial retiré avec succès." 7 50
        log "[✓] Module spoof_disk_serial retiré"
    else
        dialog --msgbox "Suppression annulée." 5 40
    fi
}

# === Afficher état actuel ===
function show_status() {
    local mod_state
    mod_state=$(lsmod | grep spoof || echo "(aucun module spoof chargé)")

    local ifaces
    ifaces=$(ip -brief link | grep -v lo)

    local hostname
    hostname=$(hostname)

    local uuids
    uuids=$(blkid | grep UUID | head -n 5 || echo "Aucune partition détectée")

    dialog --msgbox "Modules chargés:\n$mod_state\n\nInterfaces réseau:\n$ifaces\n\nHostname:\n$hostname\n\nUUIDs (extrait):\n$uuids" 20 70
}

# === Menu principal ===
function main_menu() {
    while true; do
        local choice
        choice=$(dialog --clear --title "MTM - Machine Trace Modifier" \
            --menu "Choisissez une action :" 15 60 8 \
            1 "Spoof Disk Serial" \
            2 "Spoof MAC Address" \
            3 "Spoof All ext2/3/4 UUIDs" \
            4 "Change Hostname" \
            5 "Remove Disk Spoof Module" \
            6 "Show Status" \
            7 "Toggle Dry Run Mode (Current: $([ $DRY_RUN -eq 1 ] && echo ON || echo OFF))" \
            0 "Exit" 3>&1 1>&2 2>&3) || break

        case "$choice" in
            1) spoof_disk_serial ;;
            2) spoof_mac ;;
            3) spoof_all_uuid ;;
            4) spoof_hostname ;;
            5) remove_disk_spoof ;;
            6) show_status ;;
            7) 
                ((DRY_RUN = 1 - DRY_RUN))
                dialog --msgbox "Mode Dry Run: $([ $DRY_RUN -eq 1 ] && echo ON || echo OFF)" 6 40
                ;;
            0) break ;;
            *) dialog --msgbox "Option invalide." 5 40 ;;
        esac
    done
}

# === MAIN ===
check_root
check_dependencies
load_config
banner
main_menu
clear
