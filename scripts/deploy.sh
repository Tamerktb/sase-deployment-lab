#!/bin/bash
# SASE Deployment Lab - Full Deployment Script
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "======================================"
echo " SASE Deployment Lab - Deploy"
echo "======================================"

# 1. Run tests
echo "[1/6] Running unit tests..."
cd "$PROJECT_DIR"
python3 -m pytest tests/ -v --tb=short

# 2. Generate WireGuard keys and configs
echo "[2/6] Generating WireGuard configurations..."
python3 scripts/key-exchange.py

# 3. Validate Terraform
echo "[3/6] Validating Terraform configuration..."
cd "$PROJECT_DIR/terraform"
if [ -f .terraform.lock.hcl ]; then
  terraform validate
else
  terraform init && terraform validate
fi

# 4. Deploy Docker multi-site environment
echo "[4/6] Deploying Docker multi-site environment..."
cd "$PROJECT_DIR"
docker compose up -d

# 5. Run posture checks
echo "[5/6] Running device posture checks..."
python3 "$PROJECT_DIR/posture-checks/posture_checker.py"

# 6. Verify connectivity
echo "[6/6] Verifying connectivity..."
echo ""
echo "--- Site-to-Site Ping Test ---"
echo "Site-A (10.0.1.10) -> Site-B (10.0.2.10):"
docker exec sase-site-a-web ping -c 2 -W 2 10.0.2.10 || echo "  (expected if routes not set)"
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
echo "  2. Activate tunnels: set CF_TUNNEL_TOKEN_SITEA/CF_TUNNEL_TOKEN_SITEB/CF_TUNNEL_TOKEN_HUB env vars"
echo "  3. Connect WARP client and test access"
echo "  4. Run posture checks on endpoints"
echo "  5. Deploy WireGuard configs on real hosts for encrypted site-to-site"
echo ""
echo "To teardown: ./scripts/teardown.sh"
