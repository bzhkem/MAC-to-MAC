#!/bin/bash

#======================== COLORS =========================#
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

#======================== HEADER =========================#
echo -e "${BLUE}"
echo " __  __ _______ __  __ "
echo "|  \/  |__   __|  \/  |   HWID Spoofer"
echo "| \  / |  | |  | \  / |   (Disk/MAC/UUID/Host)"
echo "| |\/| |  | |  | |\/| |"
echo "| |  | |  | |  | |  | |     github.com/bzhkem/MAC-to-MAC"
echo "|_|  |_|  |_|  |_|  |_|"
echo -e "${NC}"
echo -e "${CYAN}MTM - Machine Trace Modifier${NC}"

#====================== OUI VENDORS ======================#
declare -A OUIS=(
    [Apple]="00:17:F2 D4:F4:6F A4:5E:60 48:3C:0C F4:F1:5A"
    [Intel]="00:1B:21 3C:97:0E 00:13:E8"
    [Cisco]="00:1B:54 00:0F:F7 00:25:9C"
    [Dell]="00:14:22 00:21:9B 28:D2:44"
    [VMware]="00:05:69 00:0C:29 00:50:56"
    [Microsoft]="00:03:FF 00:15:5D"
    [QEMU]="52:54:00"
    [HP]="3C:D9:2B 3C:97:0E"
    [Google]="3C:5A:B4 94:EB:CD 54:60:09"
    [ASUS]="00:1C:23 AC:22:0B B4:AE:2B"
    [Lenovo]="00:0A:E4"
    [Realtek]="00:E0:4C"
    [TP-Link]="50:C7:BF"
    [Broadcom]="00:10:18"
    [Huawei]="00:1E:C0 00:1F:3B 2C:F0:5D"
    [Samsung]="00:12:3F 00:16:32 00:19:5B"
    [RaspberryPi]="B8:27:EB DC:A6:32"
)

MODULE="spoof_disk_serial.ko"

#==================== KERNEL MODULE CHECK ====================#
function check_module() {
    [[ ! -f "$MODULE" ]] && {
        echo -e "${YELLOW}[!] Kernel module not built, building now...${NC}"
        make || { echo -e "${RED}[!] Build failed, cannot spoof disk serial.${NC}"; exit 1; }
    }
}

#=================== DISK SERIAL SPOOFING ===================#
function spoof_disk_serial() {
    check_module
    echo -e "${CYAN}Disks detected:${NC}"
    lsblk -dno NAME,SIZE,MODEL -e 7 | nl
    read -p "Select disk (number): " dnum
    DEV=$(lsblk -dno NAME -e 7 | sed -n "${dnum}p")
    [[ -z "$DEV" ]] && { echo -e "${RED}[!] Invalid disk selection.${NC}"; return; }
    read -p "Randomize serial? (Y/n): " r
    if [[ $r =~ ^[Yy]$|^$ ]]; then
        SERIAL=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    else
        read -p "Enter custom serial: " SERIAL
    fi
    sudo rmmod spoof_disk_serial 2>/dev/null
    sudo insmod $MODULE serial="$SERIAL" device="$DEV" && \
        echo -e "${GREEN}[✓] /dev/$DEV serial spoofed: $SERIAL${NC}"
}

function remove_disk_spoof() {
    sudo rmmod spoof_disk_serial && echo -e "${GREEN}[✓] Disk serial spoof removed.${NC}"
}

#===================== MAC ADDRESS SPOOFING ========================#
function spoof_mac() {
    echo -e "${CYAN}Available network interfaces:${NC}"
    mapfile -t IFACES < <(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
    for i in "${!IFACES[@]}"; do echo "$((i+1))) ${IFACES[i]}"; done
    read -p "Pick your interface [1-${#IFACES[@]}]: " i
    IFACE="${IFACES[$((i-1))]}"
    unset VENDORPICK
    echo -e "${CYAN}Pick a vendor or randomize MAC:${NC}"
    v=1; for vendor in "${!OUIS[@]}"; do echo "$v) $vendor"; ((v++)); done
    echo "$v) Random/Private MAC"
    read -p "Your choice [1-$v]: " vendoridx
    if [[ $vendoridx -ge 1 && $vendoridx -le ${#OUIS[@]} ]]; then
        OUI_KEY=("${!OUIS[@]}")
        PREFIXES=(${OUIS[${OUI_KEY[$((vendoridx-1))]}]})
        PREFIX="${PREFIXES[$((RANDOM % ${#PREFIXES[@]}))]}"
        OUI="$PREFIX"
    else
        OUI=$(hexdump -n 3 -e '/1 ":%02X"' /dev/urandom | sed 's/ /:/g' | cut -c2-)
    fi
    RANDOM_TAIL=$(hexdump -n 3 -e '/1 ":%02X"' /dev/urandom | sed 's/ /:/g' | cut -c2-)
    [ "$OUI" != "" ] && MAC="$OUI:$RANDOM_TAIL" || MAC="02:$RANDOM_TAIL"
    MAC=$(echo "$MAC" | tr '[:upper:]' '[:lower:]')
    sudo ip link set "$IFACE" down
    sudo ip link set "$IFACE" address "$MAC"
    sudo ip link set "$IFACE" up
    echo -e "${GREEN}[✓] $IFACE MAC changed to $MAC${NC}"
}

#============= FILESYSTEM UUIDs WITH AUTO E2FSCK ==============#
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

#========================= HOSTNAME SPOOF ==========================#
function spoof_hostname() {
    NEWNAME=$(tr -dc a-z0-9 </dev/urandom | head -c 8)
    sudo hostnamectl set-hostname "$NEWNAME"
    echo -e "${GREEN}[✓] Hostname changed to $NEWNAME${NC}"
}

#========================== STATUS MENU ===========================#
function show_status() {
    echo -e "${YELLOW}-- Current HWID Spoof State --${NC}"
    echo -e "${CYAN}Disk Serial Spoof:${NC}"
    lsmod | grep spoof_disk_serial
    dmesg | tail -n 10 | grep -i spoof
    echo -e "${CYAN}Network MACs:${NC}"
    ip -brief link | grep -v lo
    echo -e "${CYAN}Hostname:${NC}"
    hostname
    echo -e "${CYAN}Filesystem UUIDs (first 10):${NC}"
    lsblk -lnpo NAME | head -10 | xargs -I{} blkid {} 2>/dev/null | grep UUID
}

#============================ MAIN MENU ============================#
while true; do
    echo -e "\n${BLUE}========= HWID Spoofer Menu =========${NC}"
    echo "1) Spoof disk serial (kernel driver)"
    echo "2) Spoof MAC address (vendor/random)"
    echo "3) Randomize all ext2/3/4 UUIDs"
    echo "4) Randomize hostname"
    echo "5) Show status"
    echo "6) Remove disk serial spoof"
    echo "7) Exit"
    echo -e "${BLUE}=====================================${NC}"
    read -p "Choice [1-7]: " opt
    case $opt in
        1) spoof_disk_serial ;;
        2) spoof_mac ;;
        3) spoof_all_uuid ;;
        4) spoof_hostname ;;
        5) show_status ;;
        6) remove_disk_spoof ;;
        7) exit 0 ;;
        *) echo -e "${RED}[!] Invalid option.${NC}" ;;
    esac
    sleep 1
done
