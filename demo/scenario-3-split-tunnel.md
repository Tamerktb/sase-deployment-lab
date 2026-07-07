# Scenario 3: Split-Tunneling for Multi-Site Connectivity

**Objective:** Demonstrate that only corporate traffic is routed through the SASE tunnel while internet traffic bypasses it, enabling low-latency access to cloud/SaaS applications.

## Topology
```
  Site-A (Amman) ──WireGuard──► Hub (AWS) ◄──WireGuard── Site-B (Dubai)
       |                              |
  10.0.1.0/24                   10.0.0.0/24            10.0.2.0/24
       |                              |
   [Internal Apps]              [Monitoring]          [Databases]
```

## Split-Tunnel Behavior
```
  Corporate Traffic (10.0.0.0/8) ──► WireGuard Tunnel ──► SASE Mesh
  Internet Traffic (0.0.0.0/0)   ──► Direct Route     ──► ISP
```

## Steps

### 1. Deploy Docker Multi-Site Environment
```bash
cd ..
docker compose up -d
docker compose ps
```

### 2. Verify Site-to-Site Connectivity
```bash
# From Site-A, ping Site-B
docker exec sase-site-a-web ping -c 3 10.0.2.10

# From Site-B, ping Hub
docker exec sase-site-b-web ping -c 3 10.0.0.10

# From Hub, verify all sites are reachable
docker exec sase-hub-monitor ping -c 3 10.0.1.10
docker exec sase-hub-monitor ping -c 3 10.0.2.10
```

### 3. Test Split-Tunneling via WireGuard
```bash
# Apply the split-tunnel configuration
wg-quick up ./split-tunneling/wireguard-split-tunnel.conf

# Verify only corporate traffic goes through tunnel
tcpdump -i wg-split -n
# You should see only 10.0.0.0/8 traffic

# Verify internet traffic bypasses tunnel
curl -I https://cloudflare.com
# This goes directly to ISP, NOT through the tunnel
```

### 4. Simulate Cloudflare Split-Tunnel via WARP
```bash
# Configure Cloudflare split tunnel
warp-cli set-custom-endpoint <gateway-ip>

# Enable split tunnel for corp subnets only
# Via Dashboard: Zero Trust > Settings > Network > Split Tunnels
```

## Expected Results
- [ ] Site-A can reach Site-B internal services
- [ ] Site-B can reach Hub monitoring
- [ ] Internet traffic bypasses the VPN tunnel
- [ ] Inter-site traffic is encrypted via WireGuard
- [ ] Cloudflare Gateway policies apply to corporate traffic only

## Verification Matrix
| From | To | Expected Route | Encrypted |
|------|----|---------------|-----------|
| Site-A (10.0.1.0/24) | Site-B (10.0.2.0/24) | Via Hub | Yes (WireGuard) |
| Site-B (10.0.2.0/24) | Hub (10.0.0.0/24) | Direct | Yes (WireGuard) |
| Any Site | internet (e.g., 1.1.1.1) | ISP Direct | No (split) |
| Any Site | Cloudflare Gateway | WARP | Yes (WARP) |
