## Split-Tunneling Configurations

Two files for two independent traffic paths — **not** both used at once.

| File | Path | When to use |
|------|------|-------------|
| `cloudflare-split-tunnel.json` | Remote User → WARP → Cloudflare Gateway | You use Cloudflare WARP for remote access |
| `wireguard-split-tunnel.conf` | Site-to-Site WireGuard mesh | You use WireGuard as your site VPN (no WARP) |

- If a user is connected via WARP, the WARP client handles split-tunneling natively — the WireGuard config does not apply.
- If you're using WireGuard for site-to-site (not WARP), the WireGuard config routes only corporate subnets through the tunnel.
