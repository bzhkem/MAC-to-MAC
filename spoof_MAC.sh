#!/bin/bash

RED='\033[0;31m'
NC='\033[0m'

MODULE="spoof_disk_serial.ko"

declare -A OUIS
OUIS=(
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

function check_module() {
  [[ ! -f "$MODULE" ]] && { echo "Building kernel module..."; make || { echo "Build failed!"; exit 1; }; }
}

function rand_mac_tail() {
  hexdump -n 3 -e '/1 ":%02X"' /dev/urandom | sed 's/^://'
}

function pick_mac_vendor() {
  echo "Choose a MAC vendor prefix for realism:"
  for i in "${!MAC_OUIS[@]}"; do
    echo "$((i+1))) ${MAC_OUIS[$i]}"
  done
  echo "$(( ${#MAC_OUIS[@]}+1 ))) Random MAC (private)"
  read -p "Select [1-$((${#MAC_OUIS[@]}+1))]: " mac_choice
  if [[ $mac_choice -ge 1 && $mac_choice -le ${#MAC_OUIS[@]} ]]; then
    vendor_prefix=$(echo "${MAC_OUIS[$((mac_choice-1))]}" | awk '{print $1}')
    mac="$vendor_prefix$(rand_mac_tail)"
    echo "$mac"
  else
    mac="02$(od -An -N5 -tx1 /dev/urandom | tr -d " \n" | sed 's/\(..\)/:\1/g; s/^://')"
    echo "$mac"
  fi
}

function spoof_mac() {
echo "Interfaces réseau détectées :"
mapfile -t INTERFACES < <(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")

i=1
for iface in "${INTERFACES[@]}"; do
    echo "$i) $iface"
    ((i++))
done

read -p "Choisissez une interface à modifier [1-${#INTERFACES[@]}]: " IFACE_INDEX

if [[ $IFACE_INDEX -lt 1 || $IFACE_INDEX -gt ${#INTERFACES[@]} ]]; then
    echo -e "${RED}Choix invalide. Sortie.${NC}"
    exit 1
fi

NETIF="${INTERFACES[$((IFACE_INDEX - 1))]}"
echo "Interface sélectionnée: $NETIF"
echo

echo "Choisissez le type de spoofing MAC :"
OPTIONS=()
i=1
for vendor in "${!OUIS[@]}"; do
    echo "$i) $vendor"
    OPTIONS+=("$vendor")
    ((i++))
done
echo "$i) OUI personnalisé"

read -p "Votre choix [1-$i] : " VENDOR_CHOICE

if [[ "$VENDOR_CHOICE" -eq "$i" ]]; then
    read -p "Entrez un OUI personnalisé (format XX:XX:XX) : " CUSTOM_OUI
    if ! [[ $CUSTOM_OUI =~ ^([A-Fa-f0-9]{2}:){2}[A-Fa-f0-9]{2}$ ]]; then
        echo -e "${RED}Format OUI invalide. Sortie.${NC}"
        exit 1
    fi
    OUI="$CUSTOM_OUI"
elif [[ "$VENDOR_CHOICE" -ge 1 && "$VENDOR_CHOICE" -lt "$i" ]]; then
    SELECTED_VENDOR="${OPTIONS[$((VENDOR_CHOICE - 1))]}"
    VENDOR_OUIS=(${OUIS[$SELECTED_VENDOR]})
    OUI=${VENDOR_OUIS[$RANDOM % ${#VENDOR_OUIS[@]}]}
else
    echo -e "${RED}Sélection invalide. Sortie.${NC}"
    exit 1
fi

RANDOM_PART=$(printf '%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
MACADDR="${OUI}:${RANDOM_PART}"

echo
echo "Changement de l’adresse MAC sur $NETIF..."
echo "Nouvelle adresse MAC spoofée : $MACADDR"

sudo ip link set dev "$NETIF" down
sudo ip link set dev "$NETIF" address "$MACADDR"
sudo ip link set dev "$NETIF" up

echo "Adresse MAC changée avec succès."
}

function spoof_disk_serial() {
  check_module
  echo "---- Disk Devices ----"
  lsblk -dno NAME,SIZE -e 7 | nl
  read -p "Number to spoof: " dnum
  DEV=$(lsblk -dno NAME -e 7 | sed -n "${dnum}p")
  [[ -z "$DEV" ]] && { echo "Invalid disk selection!"; return; }
  read -p "Randomize serial (Y/n)? " rserial
  if [[ $rserial =~ ^[Yy]$|^$ ]]; then
    SERIAL=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    echo "Generated serial: $SERIAL"
  else
    read -p "Enter custom serial: " SERIAL
  fi
  sudo rmmod spoof_disk_serial 2>/dev/null
  sudo insmod $MODULE serial="$SERIAL" device="$DEV" && echo "Spoofed /dev/$DEV!"
}

function remove_disk_spoof() {
  sudo rmmod spoof_disk_serial 2>/dev/null && echo "Disk serial spoof removed!"
}

function spoof_all_uuid() {
  echo "---- Filesystem UUIDs (ext2/3/4 only) ----"
  for part in $(lsblk -lnpo NAME,TYPE | awk '$2=="part"{print $1}'); do
    fs=$(blkid -o value -s TYPE "$part" 2>/dev/null)
    [[ "$fs" =~ ext[234] ]] || continue
    sudo tune2fs -U random "$part" && echo "$part UUID => randomized"
  done
}

function spoof_hostname() {
  NEW_HOST=$(tr -dc a-z0-9 </dev/urandom | head -c 8)
  sudo hostnamectl set-hostname "$NEW_HOST"
  echo "Hostname set to $NEW_HOST (relog may be needed)."
}

function show_status() {
  echo "-- Disk Serial Spoof: --"
  lsmod | grep spoof_disk_serial && sudo dmesg | tail -n 10 | grep disk-serial-spoofer
  echo "-- MAC addresses: --"
  ip link | awk '/link\/ether/ {print $2,$9}'
  echo "-- Hostname: --"
  hostnamectl status | grep "Static hostname"
  echo "-- Filesystem UUIDs (first 10): --"
  lsblk -lnpo NAME | head -10 | xargs -I{} blkid {} 2>/dev/null | grep UUID
}

while true; do
  echo
  echo "========== HWID Spoofer Menu =========="
  echo "1) Spoof disk serial !MAINTENANCE! (kernel mod, random/custom)"
  echo "2) Spoof MAC address (pick vendor, randomize)"
  echo "3) Randomize all ext2/3/4 UUIDs"
  echo "4) Randomize hostname"
  echo "5) Show current spoofed info"
  echo "6) Remove disk serial spoof"
  echo "7) Exit"
  echo "======================================="
  read -p "Select an option [1-7]: " opt
  case $opt in
    1) spoof_disk_serial ;;
    2) spoof_mac ;;
    3) spoof_all_uuid ;;
    4) spoof_hostname ;;
    5) show_status ;;
    6) remove_disk_spoof ;;
    7) exit 0 ;;
    *) echo "Invalid option" ;;
  esac
done
