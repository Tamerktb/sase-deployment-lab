#!/bin/bash
# Hub site setup script for SASE WireGuard mesh
set -euo pipefail

echo "[SASE] Setting up WireGuard Hub (site-a)..."
echo "========================================"

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)."
  exit 1
fi

# Install WireGuard if missing
if ! command -v wg-quick &>/dev/null; then
  echo "[SASE] Installing WireGuard..."
  apt-get update && apt-get install -y wireguard
fi

CONFIG_DIR="$(dirname "$0")"
CONFIG_FILE="$CONFIG_DIR/wg0.conf"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[SASE] ERROR: $CONFIG_FILE not found. Run generate-configs.py first."
  exit 1
fi

cp "$CONFIG_FILE" /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf

# Enable IP forwarding for site-to-site routing
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

wg-quick up wg0
systemctl enable wg-quick@wg0

echo "[SASE] Hub WireGuard interface is up."
echo "       Check status: wg show"
echo "       Hub address:  $(ip -4 addr show wg0 | grep inet | awk '{print $2}')"
