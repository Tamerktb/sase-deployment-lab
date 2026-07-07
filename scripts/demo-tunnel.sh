#!/bin/bash
# SASE Quick Tunnel Demo — creates a public Cloudflare Tunnel to local Hub Monitor
# No Cloudflare account required. Uses cloudflared's --url quick tunnel.
#
# Prerequisites: Docker containers must be running (make run)
# Usage: bash scripts/demo-tunnel.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo " SASE Quick Tunnel Demo"
echo "=========================================="
echo ""
echo "This creates a public URL that tunnels to your local Hub Monitor."
echo "No Cloudflare account needed — cloudflared creates an ephemeral tunnel."
echo ""

# Check that hub-monitor is running
if ! docker ps --format '{{.Names}}' | grep -q "^sase-hub-monitor$"; then
  echo "ERROR: sase-hub-monitor is not running."
  echo "Run 'make run' first."
  exit 1
fi

HUB_IP=$(docker inspect sase-hub-monitor --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "Hub Monitor internal IP: $HUB_IP"
echo ""

echo "Starting cloudflared tunnel..."
echo "Once connected, open the URL shown below in your browser."
echo "Press Ctrl+C to stop the tunnel."
echo ""
echo "=========================================="

# Use host.docker.internal to reach host from container, or direct IP
if docker ps --format '{{.Names}}' | grep -q "^sase-hub-monitor$"; then
  # Tunnel to the Docker container directly via the mesh network
  docker run --rm --network sase-deployment-lab_sase_mesh \
    cloudflare/cloudflared:latest tunnel --url "http://${HUB_IP}:80"
else
  echo "ERROR: Hub monitor not reachable."
  exit 1
fi
