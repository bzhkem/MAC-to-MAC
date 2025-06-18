#!/bin/bash

NETIF="eth0"

declare -A OUIS
OUIS=(
    [Apple]="00:17:F2  D4:F4:6F  A4:5E:60  48:3C:0C  F4:F1:5A"
    [Synology]="00:11:32  00:15:88  00:1B:57"
    [Cisco]="00:1B:54  00:0F:F7  00:25:9C"
    [Intel]="00:1B:21  3C:97:0E  00:13:E8"
    [Dell]="00:14:22  00:21:9B  28:D2:44"
    [VMware]="00:05:69  00:0C:29  00:50:56"
    [Microsoft]="00:03:FF  00:15:5D"
    [QEMU]="52:54:00"
    [RedHat]="52:54:00"
    [Google]="3C:5A:B4  94:EB:CD  54:60:09"
)

echo "Select spoofing type:"
i=1
OPTIONS=()
for vendor in "${!OUIS[@]}"; do
    echo "$i) $vendor"
    OPTIONS+=("$vendor")
    ((i++))
done
echo "$i) Custom OUI"

read -p "Enter your choice [1-$i]: " CHOICE

if [[ "$CHOICE" -eq "$i" ]]; then
    read -p "Enter your custom OUI (e.g., AA:BB:CC): " CUSTOM_OUI
    if ! [[ $CUSTOM_OUI =~ ^([A-Fa-f0-9]{2}:){2}[A-Fa-f0-9]{2}$ ]]; then
        echo "Invalid OUI format. Exiting."
        exit 1
    fi
    OUI=$CUSTOM_OUI
elif [[ "$CHOICE" -ge 1 && "$CHOICE" -lt "$i" ]]; then
    SELECTED_VENDOR="${OPTIONS[$((CHOICE - 1))]}"
    VENDOR_OUIS=(${OUIS[$SELECTED_VENDOR]})
    OUI=${VENDOR_OUIS[$RANDOM % ${#VENDOR_OUIS[@]}]}
else
    echo "Invalid selection. Exiting."
    exit 1
fi

RANDOM_MAC=$(printf '%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
MACADDR="${OUI}:${RANDOM_MAC}"

echo "Changing MAC address on $NETIF..."
echo "Spoofed MAC: $MACADDR"
sudo ip link set dev "$NETIF" down
sudo ip link set dev "$NETIF" address "$MACADDR"
sudo ip link set dev "$NETIF" up
echo "MAC address successfully changed."
