#!/bin/bash
# SASE Deployment Lab - Full Deployment Script
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "======================================"
echo " SASE Deployment Lab - Deploy"
echo "======================================"

# 1. Generate WireGuard keys and configs
echo "[1/5] Generating WireGuard configurations..."
cd "$PROJECT_DIR/wireguard"
python3 generate-configs.py

# 2. Validate Terraform
echo "[2/5] Validating Terraform configuration..."
cd "$PROJECT_DIR/terraform"
terraform fmt -check -diff
terraform validate

# 3. Deploy Docker multi-site environment
echo "[3/5] Deploying Docker multi-site environment..."
cd "$PROJECT_DIR"
docker compose up -d --build

# 4. Run posture checks
echo "[4/5] Running device posture checks..."
python3 "$PROJECT_DIR/posture-checks/posture_checker.py"

# 5. Verify connectivity
echo "[5/5] Verifying connectivity..."
echo ""
echo "--- Site-to-Site Ping Test ---"
echo "Site-A (10.0.1.10) -> Hub (10.0.0.10):"
docker exec sase-site-a-web ping -c 2 -W 2 10.0.0.10 || echo "  (expected if routes not set)"
echo ""
echo "--- Hub Access ---"
echo "Hub Monitor: http://localhost:9090"

echo ""
echo "======================================"
echo " Deployment complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. Apply Terraform: cd terraform && terraform apply"
echo "  2. Connect WARP client and test access"
echo "  3. Run posture checks on endpoints"
echo "  4. Verify split-tunneling behavior"
echo ""
echo "To teardown: ./scripts/teardown.sh"
