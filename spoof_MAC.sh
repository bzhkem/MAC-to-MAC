#!/bin/bash

BLUE='\033[1;34m'
NC='\033[0m'

echo -e "${BLUE} __  __ _______ __  __ "
echo -e "|  \\/  |__   __|  \\/  | "
echo -e "| \\  / |  | |  | \\  / |"
echo -e "| |\\/| |  | |  | |\\/| |"
echo -e "| |  | |  | |  | |  | |"
echo -e "|_|  |_|  |_|  |_|  |_|${NC}"
 
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

echo "Interfaces réseau détectées :"
mapfile -t INTERFACES < <(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")

i=1
for iface in "${INTERFACES[@]}"; do
    echo "$i) $iface"
    ((i++))
done

read -p "Choisissez une interface à modifier [1-${#INTERFACES[@]}]: " IFACE_INDEX

if [[ $IFACE_INDEX -lt 1 || $IFACE_INDEX -gt ${#INTERFACES[@]} ]]; then
    echo "Choix invalide. Sortie."
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
        echo "Format OUI invalide. Sortie."
        exit 1
    fi
    OUI="$CUSTOM_OUI"
elif [[ "$VENDOR_CHOICE" -ge 1 && "$VENDOR_CHOICE" -lt "$i" ]]; then
    SELECTED_VENDOR="${OPTIONS[$((VENDOR_CHOICE - 1))]}"
    VENDOR_OUIS=(${OUIS[$SELECTED_VENDOR]})
    OUI=${VENDOR_OUIS[$RANDOM % ${#VENDOR_OUIS[@]}]}
else
    echo "Sélection invalide. Sortie."
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

