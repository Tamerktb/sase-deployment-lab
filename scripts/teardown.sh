#!/bin/bash
# SASE Deployment Lab - Teardown Script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "======================================"
echo " SASE Deployment Lab - Teardown"
echo "======================================"

# 1. Tear down Docker environment
echo "[1/4] Stopping Docker multi-site environment..."
cd "$PROJECT_DIR"
docker compose down --volumes --remove-orphans

# 2. Destroy Terraform resources
echo "[2/4] Destroying Terraform-managed Cloudflare resources..."
if [ -f "$PROJECT_DIR/terraform/terraform.tfstate" ]; then
    cd "$PROJECT_DIR/terraform"
    terraform destroy -auto-approve
else
    echo "  No Terraform state found. Skipping."
fi

# 3. Stop WireGuard interfaces
echo "[3/4] Stopping WireGuard interfaces..."
for iface in /etc/wireguard/wg*.conf; do
    name=$(basename "$iface" .conf)
    if ip link show "$name" &>/dev/null; then
        wg-quick down "$name" 2>/dev/null || true
        echo "  Stopped: $name"
    fi
done

# 4. Clean up generated files
echo "[4/4] Cleaning up generated files..."
rm -f "$PROJECT_DIR/wireguard/generated-keys.json"
echo "  Removed: generated-keys.json"

echo ""
echo "======================================"
echo " Teardown complete!"
echo "======================================"
echo ""
echo "Note: Cloudflare WARP clients on endpoints"
echo "must be disconnected manually: warp-cli disconnect"
