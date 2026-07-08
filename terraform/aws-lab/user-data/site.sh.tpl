#!/bin/bash
set -euxo pipefail

# ── Install WireGuard + cloudflared + Docker ─────────────────────
apt-get update -qq
apt-get install -y -qq wireguard docker.io python3 python3-pip nginx

# Install cloudflared
curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
dpkg -i /tmp/cloudflared.deb || apt-get install -f -y

# ── Generate WireGuard keys ───────────────────────────────────────
wg genkey | tee /etc/wireguard/site.key | wg pubkey > /etc/wireguard/site.pub
chmod 600 /etc/wireguard/site.key

SITE_PRIVATE=$(cat /etc/wireguard/site.key)

# ── Write WireGuard config (no peers yet — configured by aws-lab-setup) ─
cat > /etc/wireguard/wg0.conf <<WGEOF
[Interface]
PrivateKey = ${SITE_PRIVATE}
Address = 10.0.0.0/24  # placeholder — set by aws-lab-setup
ListenPort = 51820
DNS = 1.1.1.1, 1.0.0.1

# Peers will be added by scripts/aws-lab-setup.sh
WGEOF

chmod 600 /etc/wireguard/wg0.conf
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0 || true

# ── Start cloudflared (if token provided) ──────────────────────────
%{ if cloudflare_token != "" ~}
mkdir -p /etc/cloudflared
cat > /etc/cloudflared/tunnel.sh <<TUNNEL
#!/bin/bash
cloudflared tunnel --no-autoupdate run --token ${cloudflare_token}
TUNNEL
chmod +x /etc/cloudflared/tunnel.sh

cat > /etc/systemd/system/cloudflared.service <<SVC
[Unit]
Description=cloudflared tunnel
After=network.target

[Service]
ExecStart=/etc/cloudflared/tunnel.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
SVC

systemctl enable cloudflared
systemctl start cloudflared
%{ endif ~}

# ── Start nginx for health check ──────────────────────────────────
echo "SASE Site - $(hostname)" > /var/www/html/index.html
systemctl enable nginx
systemctl start nginx

echo "SITE_SETUP_COMPLETE"
echo "SITE_PUBLIC_KEY=$(cat /etc/wireguard/site.pub)"
