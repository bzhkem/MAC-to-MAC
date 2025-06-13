#!/bin/bash
NETIF="eth0"
APPLE_OUIS=( "00:17:F2" "D4:F4:6F" "A4:5E:60" "48:3C:0C" "F4:F1:5A" )
OUI=${APPLE_OUIS[$RANDOM % ${#APPLE_OUIS[@]}]}
RANDOM_MAC=$(printf '%02X:%02X:%02X' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
MACADDR="${OUI}:${RANDOM_MAC}"
echo "Changement MAC sur $NETIF..."
echo "New spoofed Apple MAC: $MACADDR"
sudo ip link set dev $NETIF down
sudo ip link set dev $NETIF address $MACADDR
sudo ip link set dev $NETIF up
