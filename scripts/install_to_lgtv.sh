#!/bin/bash
set -e

IPK_PATH="dist/com.nungu.einthusantv_1.0.0_all.ipk"

if [ ! -f "$IPK_PATH" ]; then
  echo "Error: $IPK_PATH not found. Run packaging first."
  exit 1
fi

echo "========================================="
echo "   Nungu TV - LG webOS TV Installer      "
echo "========================================="
echo ""
echo "1. Turn on your LG TV and make sure it is on the same Wi-Fi as this Mac."
echo "2. Open the 'Developer Mode' app on your TV."
echo "3. Turn 'Dev Mode Status' ON and 'Key Server' ON."
echo ""

read -p "Enter your LG TV IP Address (shown on TV screen): " TV_IP
read -p "Enter Passphrase (6-character code on TV screen): " PASSPHRASE

DEVICE_NAME="lgtv"

echo ""
echo "-> Registering LG TV ($TV_IP)..."
npx -p @webosose/ares-cli ares-setup-device -r $DEVICE_NAME 2>/dev/null || true
npx -p @webosose/ares-cli ares-setup-device -a $DEVICE_NAME -i "username=prisoner" -i "host=$TV_IP" -i "port=9922"

echo "-> Fetching SSH Dev Key from TV..."
echo "$PASSPHRASE" | npx -p @webosose/ares-cli ares-novacom --getkey -d $DEVICE_NAME

echo "-> Installing Nungu TV package to your LG TV..."
npx -p @webosose/ares-cli ares-install -d $DEVICE_NAME "$IPK_PATH"

echo "-> Launching Nungu TV on your LG TV..."
npx -p @webosose/ares-cli ares-launch -d $DEVICE_NAME com.nungu.einthusantv || true

echo ""
echo "========================================="
echo "  SUCCESS! Nungu TV installed on your TV!"
echo "========================================="
