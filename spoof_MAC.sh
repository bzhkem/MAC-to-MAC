#!/bin/bash

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

