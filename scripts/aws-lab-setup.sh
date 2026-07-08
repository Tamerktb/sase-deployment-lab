#!/usr/bin/env bash
# ==========================================================================
# SASE AWS Lab — Post-Deploy WireGuard Configuration
# ==========================================================================
# After `terraform apply` finishes, run this script to:
#   1. Fetch public keys from all EC2 instances
#   2. Generate proper WireGuard configs with real endpoints
#   3. Deploy configs and activate the mesh
#
# Usage:
#   cd terraform/aws-lab
#   terraform apply   # => note the public IPs in the output
#   bash ../../scripts/aws-lab-setup.sh
#
# Prerequisites:
#   - terraform/aws-lab/terraform.tfvars with ssh_key_name set
#   - The SSH key must be loaded in ssh-agent or accessible via ~/.ssh
# ==========================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/../terraform/aws-lab" && pwd)"
SSH_KEY_NAME=$(cd "$SCRIPT_DIR" && terraform output -raw ssh_key_name 2>/dev/null || echo "")
HUB_PUB=$(cd "$SCRIPT_DIR" && terraform output -raw hub_public_ip)
SITE_A_PUB=$(cd "$SCRIPT_DIR" && terraform output -raw site_a_public_ip)
SITE_B_PUB=$(cd "$SCRIPT_DIR" && terraform output -raw site_b_public_ip)
HUB_PRIV=$(cd "$SCRIPT_DIR" && terraform output -raw hub_private_ip)
SITE_A_PRIV=$(cd "$SCRIPT_DIR" && terraform output -raw site_a_private_ip)
SITE_B_PRIV=$(cd "$SCRIPT_DIR" && terraform output -raw site_b_private_ip)

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
SSH_KEY="${HOME}/.ssh/${SSH_KEY_NAME}.pem"

echo "=== SASE AWS Lab — WireGuard Setup ==="
echo "  Hub:  ${HUB_PUB}"
echo "  Site-A: ${SITE_A_PUB}"
echo "  Site-B: ${SITE_B_PUB}"
echo ""

# ── Wait for instances to be reachable ────────────────────────────────
wait_for_ssh() {
  local ip=$1 name=$2
  echo -n "  Waiting for ${name} (${ip})..."
  for i in $(seq 1 30); do
    if ssh ${SSH_OPTS} -i "${SSH_KEY}" "ubuntu@${ip}" "echo ready" 2>/dev/null; then
      echo " OK"
      return 0
    fi
    sleep 5
  done
  echo " FAILED"
  return 1
}

wait_for_ssh "${HUB_PUB}" "Hub"
wait_for_ssh "${SITE_A_PUB}" "Site-A"
wait_for_ssh "${SITE_B_PUB}" "Site-B"
echo ""

# ── Fetch public keys ──────────────────────────────────────────────────
echo "=== Fetching public keys ==="
HUB_KEY=$(ssh ${SSH_OPTS} -i "${SSH_KEY}" "ubuntu@${HUB_PUB}" "cat /etc/wireguard/hub.pub")
SITE_A_KEY=$(ssh ${SSH_OPTS} -i "${SSH_KEY}" "ubuntu@${SITE_A_PUB}" "cat /etc/wireguard/site.pub")
SITE_B_KEY=$(ssh ${SSH_OPTS} -i "${SSH_KEY}" "ubuntu@${SITE_B_PUB}" "cat /etc/wireguard/site.pub")

echo "  Hub public key:    ${HUB_KEY:0:32}..."
echo "  Site-A public key: ${SITE_A_KEY:0:32}..."
echo "  Site-B public key: ${SITE_B_KEY:0:32}..."
echo ""

# ── Generate Hub config ────────────────────────────────────────────────
echo "=== Deploying WireGuard configs ==="

HUB_CONFIG=$(cat <<HUB
[Interface]
PrivateKey = /etc/wireguard/hub.key
Address = 10.0.0.1/24
ListenPort = 51820
DNS = 1.1.1.1, 1.0.0.1

# Site-A (Amman)
[Peer]
PublicKey = ${SITE_A_KEY}
AllowedIPs = 10.0.1.0/24
Endpoint = ${SITE_A_PUB}:51820
PersistentKeepalive = 25

# Site-B (Dubai)
[Peer]
PublicKey = ${SITE_B_KEY}
AllowedIPs = 10.0.2.0/24
Endpoint = ${SITE_B_PUB}:51820
PersistentKeepalive = 25
HUB
)

ssh ${SSH_OPTS} -i "${SSH_KEY}" "ubuntu@${HUB_PUB}" "tee /etc/wireguard/wg0.conf > /dev/null" <<<"${HUB_CONFIG}"
ssh ${SSH_OPTS} -i "${SSH_KEY}" "ubuntu@${HUB_PUB}" "sudo systemctl restart wg-quick@wg0"
echo "  [OK] Hub config deployed"

# ── Generate Site-A config ─────────────────────────────────────────────
SITE_A_CONFIG=$(cat <<SITEA
[Interface]
PrivateKey = /etc/wireguard/site.key
Address = 10.0.1.1/24
ListenPort = 51820
DNS = 1.1.1.1, 1.0.0.1

# Hub
[Peer]
PublicKey = ${HUB_KEY}
AllowedIPs = 10.0.0.0/24
Endpoint = ${HUB_PUB}:51820
PersistentKeepalive = 25
SITEA
)

ssh ${SSH_OPTS} -i "${SSH_KEY}" "ubuntu@${SITE_A_PUB}" "tee /etc/wireguard/wg0.conf > /dev/null" <<<"${SITE_A_CONFIG}"
ssh ${SSH_OPTS} -i "${SSH_KEY}" "ubuntu@${SITE_A_PUB}" "sudo systemctl restart wg-quick@wg0"
echo "  [OK] Site-A config deployed"

# ── Generate Site-B config ─────────────────────────────────────────────
SITE_B_CONFIG=$(cat <<SITEB
[Interface]
PrivateKey = /etc/wireguard/site.key
Address = 10.0.2.1/24
ListenPort = 51820
DNS = 1.1.1.1, 1.0.0.1

# Hub
[Peer]
PublicKey = ${HUB_KEY}
AllowedIPs = 10.0.0.0/24
Endpoint = ${HUB_PUB}:51820
PersistentKeepalive = 25
SITEB
)

ssh ${SSH_OPTS} -i "${SSH_KEY}" "ubuntu@${SITE_B_PUB}" "tee /etc/wireguard/wg0.conf > /dev/null" <<<"${SITE_B_CONFIG}"
ssh ${SSH_OPTS} -i "${SSH_KEY}" "ubuntu@${SITE_B_PUB}" "sudo systemctl restart wg-quick@wg0"
echo "  [OK] Site-B config deployed"

# ── Verify ─────────────────────────────────────────────────────────────
echo ""
echo "=== Verifying the mesh ==="
sleep 3
echo "  Hub → Site-A: $(ssh ${SSH_OPTS} -i "${SSH_KEY}" "ubuntu@${HUB_PUB}" "ping -c 1 -W 2 10.0.1.1" 2>&1 | grep -c '1 received' || echo "FAIL")"
echo "  Hub → Site-B: $(ssh ${SSH_OPTS} -i "${SSH_KEY}" "ubuntu@${HUB_PUB}" "ping -c 1 -W 2 10.0.2.1" 2>&1 | grep -c '1 received' || echo "FAIL")"
echo "  Site-A → Hub: $(ssh ${SSH_OPTS} -i "${SSH_KEY}" "ubuntu@${SITE_A_PUB}" "ping -c 1 -W 2 10.0.0.1" 2>&1 | grep -c '1 received' || echo "FAIL")"
echo "  Site-B → Hub: $(ssh ${SSH_OPTS} -i "${SSH_KEY}" "ubuntu@${SITE_B_PUB}" "ping -c 1 -W 2 10.0.0.1" 2>&1 | grep -c '1 received' || echo "FAIL")"

echo ""
echo "=== Done ==="
echo "WireGuard encrypted mesh is LIVE on AWS."
echo "Run 'terraform destroy -auto-approve' to tear down."
