#!/bin/bash
# SASE Deployment Lab — Real VPS Deployment (AWS EC2 / DigitalOcean)
# Run this on a fresh Ubuntu 24.04 VM to deploy the full stack.
set -eu

echo "======================================"
echo " SASE Deployment Lab — VPS Install"
echo "======================================"

# 1. Install dependencies
echo "[1/6] Installing system dependencies..."
sudo apt-get update -q
sudo apt-get install -y -q docker.io docker-compose-v2 python3 python3-pip wireguard

# 2. Clone the repo
echo "[2/6] Cloning SASE deployment lab..."
cd /opt
sudo git clone https://github.com/Tamerktb/sase-deployment-lab.git
cd sase-deployment-lab

# 3. Generate WireGuard keys
echo "[3/6] Generating WireGuard keys..."
python3 scripts/key-exchange.py

# 4. Deploy Docker stack
echo "[4/6] Deploying Docker multi-site environment..."
sudo docker compose up -d

# 5. Enable IP forwarding for WireGuard
echo "[5/6] Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# 6. Bring up WireGuard interfaces on this host
echo "[6/6] Bringing up WireGuard interfaces..."
for site in hub site-a site-b; do
    CONF="/opt/sase-deployment-lab/wireguard/sites/$site/wg0.conf"
    if [ -f "$CONF" ]; then
        sudo cp "$CONF" "/etc/wireguard/${site}.conf"
        sudo chmod 600 "/etc/wireguard/${site}.conf"
        sudo wg-quick up "${site}" 2>/dev/null || echo "  [WARN] Could not bring up $site (expected if kernel module missing)"
    fi
done

echo ""
echo "======================================"
echo " Deployment complete!"
echo "======================================"
echo ""
echo " Services:"
echo "   Hub Monitor:  http://$(curl -s ifconfig.me):9090"
echo "   Grafana:      http://$(curl -s ifconfig.me):3000"
echo "   Prometheus:   http://$(curl -s ifconfig.me):9091"
echo ""
echo " Next steps:"
echo "   1. Point your domain's DNS to $(curl -s ifconfig.me)"
echo "   2. Run: cd /opt/sase-deployment-lab/terraform && terraform apply"
echo "   3. Set CF_TUNNEL_TOKEN_* env vars and restart Docker:"
echo "      docker compose up -d"
echo ""
echo " WireGuard mesh is active on real interfaces:"
sudo wg show 2>/dev/null || echo "  (wg show failed — check kernel module)"
