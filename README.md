# SASE Deployment Lab

A simulated **Secure Access Service Edge (SASE)** deployment combining **Cloudflare Zero Trust** with **WireGuard** for a multi-site mesh network. Implements identity-based access policies, device posture checks, and split-tunneling across three simulated sites.

## Architecture

![SASE Deployment Lab Architecture](architecture.png)

*Diagram generated with [Diagrams](https://diagrams.mingrammer.com/) — code in [`scripts/generate-architecture-diagram.py`](scripts/generate-architecture-diagram.py)*

## Features

| Feature | Implementation | Technology |
|---------|---------------|------------|
| **Identity-Based Access** | SSO + email domain policies for internal apps | Cloudflare Access (Terraform) |
| **Device Posture Checks** | Firewall, AV, disk encryption, patch compliance | Python + PowerShell + Bash scripts |
| **Split-Tunneling** | Corporate traffic via tunnel, internet direct | WireGuard + Cloudflare Gateway |
| **Multi-Site Mesh** | Site-to-site encrypted connectivity | WireGuard hub-and-spoke |
| **DNS/HTTP Filtering** | Block malware, phishing, high-risk categories | Cloudflare Gateway |
| **Local Demo Environment** | Simulated 3-site network in containers | Docker Compose |

## Project Structure

```
sase-deployment-lab/
├── terraform/              # Cloudflare Zero Trust as Code
│   ├── main.tf             # Provider setup
│   ├── variables.tf        # Site definitions and configuration
│   ├── access.tf           # Access policies and groups
│   ├── gateway.tf          # DNS/HTTP filtering rules
│   ├── tunnel.tf           # Cloudflare Tunnel + routing
│   └── outputs.tf          # Deployment outputs
├── wireguard/              # Multi-site WireGuard mesh
│   ├── generate-configs.py # Key pair + config generator
│   └── sites/
│       ├── hub/            # Central hub (AWS eu-central-1)
│       ├── site-a/         # Site-A (Amman, Jordan)
│       └── site-b/         # Site-B (Dubai, UAE)
├── posture-checks/         # Device compliance verification
│   ├── posture-checker.py  # Cross-platform checker
│   ├── windows-posture.ps1 # Windows-specific checks
│   └── linux-posture.sh    # Linux-specific checks
├── split-tunneling/        # Split-tunnel configurations
│   ├── cloudflare-split-tunnel.json
│   └── wireguard-split-tunnel.conf
├── demo/                   # Demo scenario guides
│   ├── scenario-1-basic-access.md
│   ├── scenario-2-posture-check.md
│   └── scenario-3-split-tunnel.md
├── scripts/                # Deployment automation
│   ├── deploy.sh
│   ├── teardown.sh
│   └── verify.sh
└── docker-compose.yml      # Local 3-site simulation
```

## Quick Start

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.6
- [Docker](https://docs.docker.com/get-docker/) + Docker Compose
- [WireGuard](https://www.wireguard.com/install/) (for split-tunnel testing)
- [Cloudflare WARP](https://developers.cloudflare.com/warp-client/) client (for posture checks)
- Cloudflare API token with Zero Trust permissions

### 1. Deploy Local Multi-Site Environment

```bash
# Start the simulated 3-site network
docker compose up -d

# Verify all containers are running
docker compose ps
```

### 2. Configure Cloudflare Zero Trust

```bash
cd terraform

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
cloudflare_api_token = "your-api-token"
zone_id             = "your-zone-id"
domain              = "sase.example.com"
EOF

# Deploy
terraform init
terraform apply -auto-approve
```

### 3. Run Device Posture Checks

```bash
# Cross-platform
python3 posture-checks/posture-checker.py --json

# Windows (as Administrator)
powershell -ExecutionPolicy Bypass -File posture-checks/windows-posture.ps1

# Linux
bash posture-checks/linux-posture.sh
```

### 4. Test Split-Tunneling

```bash
# Apply split-tunnel WireGuard config
wg-quick up split-tunneling/wireguard-split-tunnel.conf

# Verify only corp traffic goes through tunnel
tcpdump -i wg-split -n
```

## Demo Scenarios

| Scenario | Description | Time |
|----------|-------------|------|
| **1 - Basic Access** | User authenticates via SSO and accesses internal apps | 10 min |
| **2 - Posture Check** | Non-compliant device is blocked; compliant device passes | 15 min |
| **3 - Split-Tunnel** | Multi-site inter-site traffic + internet bypass verification | 15 min |

## Security Considerations

- Replace all placeholder WireGuard keys (`SITE_A_PUBLIC_KEY`, `HUB_PRIVATE_KEY`, etc.) with actual generated keys before production use
- The posture checker does **not** store or transmit any sensitive data — results are printed to stdout
- Terraform state files contain API tokens — add `terraform.tfstate` to `.gitignore` (already configured)
- For production deployments, enable Cloudflare Gateway logs and set up alerting

## License

MIT
