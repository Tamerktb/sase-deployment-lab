#!/bin/bash
set -euxo pipefail

# ── Install WireGuard + cloudflared + Docker ─────────────────────
apt-get update -qq
apt-get install -y -qq wireguard docker.io python3 python3-pip nginx

# Install cloudflared
curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
dpkg -i /tmp/cloudflared.deb || apt-get install -f -y

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# ── Generate WireGuard keys ───────────────────────────────────────
wg genkey | tee /etc/wireguard/hub.key | wg pubkey > /etc/wireguard/hub.pub
chmod 600 /etc/wireguard/hub.key

HUB_PRIVATE=$(cat /etc/wireguard/hub.key)

# ── Write WireGuard config (no peers yet — configured by aws-lab-setup) ─
cat > /etc/wireguard/wg0.conf <<WGEOF
[Interface]
PrivateKey = ${HUB_PRIVATE}
Address = 10.0.0.1/24
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
echo "SASE Hub - $(hostname)" > /var/www/html/index.html
systemctl enable nginx
systemctl start nginx

# ── Posture metrics endpoint ───────────────────────────────────────
cat > /etc/systemd/system/posture-metrics.service <<SVC
[Unit]
Description=SASE Posture Metrics
After=network.target

[Service]
ExecStart=/usr/bin/python3 -m http.server 8000 --directory /var/www/html
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target
SVC

systemctl enable posture-metrics
systemctl start posture-metrics

echo "HUB_SETUP_COMPLETE"
echo "HUB_PUBLIC_KEY=$(cat /etc/wireguard/hub.pub)"
