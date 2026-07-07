#!/bin/bash
# Site-B (Dubai) setup script for SASE WireGuard mesh
set -euo pipefail

echo "[SASE] Setting up WireGuard Site-B (Dubai)..."
echo "============================================="

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)."
  exit 1
fi

if ! command -v wg-quick &>/dev/null; then
  echo "[SASE] Installing WireGuard..."
  apt-get update && apt-get install -y wireguard
fi

CONFIG_DIR="$(dirname "$0")"
CONFIG_FILE="$CONFIG_DIR/wg0.conf"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[SASE] ERROR: $CONFIG_FILE not found."
  exit 1
fi

cp "$CONFIG_FILE" /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf

wg-quick up wg0
systemctl enable wg-quick@wg0

echo "[SASE] Site-B WireGuard interface is up."
echo "       Site-B address: 10.0.2.1"
echo "       Check status: wg show"
