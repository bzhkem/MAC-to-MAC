#!/bin/bash

#======================== COLORS ========================#
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

#======================== HEADER ========================#
echo -e "${BLUE}"
echo " __  __ _______ __  __ "
echo "|  \/  |__   __|  \/  |"
echo "| \  / |  | |  | \  / |"
echo "| |\/| |  | |  | |\/| |"
echo "| |  | |  | |  | |  | |"
echo "|_|  |_|  |_|  |_|  |_|"
echo -e "${NC}"
echo -e "${CYAN}MTM - Machine Trace Modifier${NC}"

#====================== OUI VENDORS ======================#
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

MODULE="spoof_disk_serial.ko"

#==================== CHECK MODULE =====================#
function check_module() {
    [[ ! -f "$MODULE" ]] && { 
        echo -e "${YELLOW}[!] Compilation du module...${NC}"
        make || { echo -e "${RED}[ERREUR] Compilation échouée.${NC}"; exit 1; }
    }
}

#=================== SPOOF DISK SERIAL ===================#
function spoof_disk_serial() {
    check_module
    echo -e "${CYAN}[*] Disques détectés :${NC}"
    lsblk -dno NAME,SIZE -e 7 | nl
    read -p "Sélectionnez le disque (numéro) : " dnum
    DEV=$(lsblk -dno NAME -e 7 | sed -n "${dnum}p")
    [[ -z "$DEV" ]] && { echo -e "${RED}[!] Disque invalide.${NC}"; return; }

    read -p "Randomiser le serial ? (Y/n): " r
    if [[ $r =~ ^[Yy]$|^$ ]]; then
        SERIAL=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    else
        read -p "Entrer le serial personnalisé : " SERIAL
    fi

    sudo rmmod spoof_disk_serial 2>/dev/null
    sudo insmod $MODULE serial="$SERIAL" device="$DEV" && \
    echo -e "${GREEN}[✓] Spoof appliqué à /dev/$DEV => $SERIAL${NC}"
}

#===================== SPOOF MAC ======================#
function spoof_mac() {
    echo -e "${CYAN}[*] Interfaces réseau disponibles :${NC}"
    mapfile -t IFACES < <(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
    for i in "${!IFACES[@]}"; do echo "$((i+1))) ${IFACES[i]}"; done
    read -p "Choix interface [1-${#IFACES[@]}]: " i
    IFACE="${IFACES[$((i-1))]}"

    echo -e "${CYAN}[*] Sélection constructeur (OUI) :${NC}"
    k=1
    for vendor in "${!OUIS[@]}"; do echo "$k) $vendor"; ((k++)); done
    read -p "Choix [1-${#OUIS[@]}]: " j
    OUI_KEY=("${!OUIS[@]}")
    PREFIX="${OUIS[${OUI_KEY[$((j-1))]}]}"

    RANDOM_PART=$(hexdump -n 3 -e '/1 ":%02X"' /dev/urandom)
    MAC="${PREFIX}${RANDOM_PART}"
    sudo ip link set "$IFACE" down
    sudo ip link set "$IFACE" address "$MAC"
    sudo ip link set "$IFACE" up
    echo -e "${GREEN}[✓] MAC de $IFACE changée => $MAC${NC}"
}

#==================== SPOOF UUIDs ====================#
function spoof_all_uuid() {
    echo -e "${CYAN}Randomizing UUIDs for all ext2/3/4 partitions...${NC}"
    for part in $(lsblk -lnpo NAME,TYPE | awk '$2=="part"{print $1}'); do
        fstype=$(blkid -o value -s TYPE "$part" 2>/dev/null)
        [[ "$fstype" =~ ext[234] ]] || continue

        mountpoint=$(lsblk -no MOUNTPOINT "$part")
        if [[ -n "$mountpoint" ]]; then
            # Don't change UUID on mounted partitions!
            echo -e "${YELLOW}[!] Partition $part is mounted on $mountpoint -- skipping.${NC}"
            continue
        fi

        echo -e "${CYAN}[*] Running e2fsck on $part...${NC}"
        sudo e2fsck -y -f "$part"
        if [[ $? -eq 0 ]]; then
            sudo tune2fs -U random "$part" && \
            echo -e "${GREEN}[✓] $part UUID randomized.${NC}"
        else
            echo -e "${RED}[!] e2fsck failed on $part. Skipping UUID change.${NC}"
        fi
    done
}

#==================== SPOOF HOSTNAME ===================#
function spoof_hostname() {
    NEW=$(tr -dc a-z0-9 </dev/urandom | head -c 8)
    sudo hostnamectl set-hostname "$NEW"
    echo -e "${GREEN}[✓] Hostname changé => $NEW${NC}"
}

#==================== REMOVE DISK SPOOF ================#
function remove_disk_spoof() {
    sudo rmmod spoof_disk_serial && echo -e "${GREEN}[✓] Spoof disque retiré.${NC}"
}

#==================== SHOW STATUS =======================#
function show_status() {
    echo -e "${YELLOW}-- État actuel --${NC}"
    echo -e "${CYAN}Modules actifs:${NC}"
    lsmod | grep spoof
    echo -e "${CYAN}Interfaces réseau:${NC}"
    ip -brief link | grep -v lo
    echo -e "${CYAN}Hostname:${NC}"
    hostname
    echo -e "${CYAN}UUIDs (partitions):${NC}"
    blkid | grep UUID | head -n 5
}

#====================== MAIN MENU =======================#
while true; do
    echo -e "\n${BLUE}========= MENU MTM =========${NC}"
    echo "1) Spoof Disque (Serial)"
    echo "2) Spoof Adresse MAC"
    echo "3) Randomiser UUID (ext2/3/4)"
    echo "4) Modifier le Hostname"
    echo "5) État actuel"
    echo "6) Retirer spoof disque"
    echo "7) Quitter"
    echo -e "${BLUE}============================${NC}"
    read -p "Choix [1-7]: " opt
    case $opt in
        1) spoof_disk_serial ;;
        2) spoof_mac ;;
        3) spoof_all_uuid ;;
        4) spoof_hostname ;;
        5) show_status ;;
        6) remove_disk_spoof ;;
        7) exit 0 ;;
        *) echo -e "${RED}[!] Choix invalide${NC}" ;;
    esac
    sleep 1

done

