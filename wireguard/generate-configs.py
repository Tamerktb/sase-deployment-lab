#!/usr/bin/env python3
"""
WireGuard multi-site configuration generator for SASE deployment.
Generates keys and configs for site-a, site-b, and the hub.
"""

import os
import subprocess
import json
from pathlib import Path

SITES = {
    "site-a": {
        "address": "10.0.1.1/24",
        "dns": ["1.1.1.1", "1.0.0.1"],
        "endpoint": "site-a.sase.example.com:51820",
        "peers": [
            {"public_key": "HUB_PUBLIC_KEY", "endpoint": "hub.sase.example.com:51820", "allowed_ips": ["10.0.0.0/24", "10.0.2.0/24"]}
        ],
    },
    "site-b": {
        "address": "10.0.2.1/24",
        "dns": ["1.1.1.1", "1.0.0.1"],
        "endpoint": "site-b.sase.example.com:51820",
        "peers": [
            {"public_key": "HUB_PUBLIC_KEY", "endpoint": "hub.sase.example.com:51820", "allowed_ips": ["10.0.0.0/24", "10.0.1.0/24"]}
        ],
    },
    "hub": {
        "address": "10.0.0.1/24",
        "dns": ["1.1.1.1", "1.0.0.1"],
        "listen_port": 51820,
        "peers": [
            {"public_key": "SITE_A_PUBLIC_KEY", "allowed_ips": ["10.0.1.0/24"]},
            {"public_key": "SITE_B_PUBLIC_KEY", "allowed_ips": ["10.0.2.0/24"]},
        ],
    },
}

def generate_keypair():
    """Generate a WireGuard key pair using wg tool."""
    try:
        private_key = subprocess.run(
            ["wg", "genkey"], capture_output=True, text=True, check=True
        ).stdout.strip()
        public_key = subprocess.run(
            ["wg", "pubkey"], input=private_key, capture_output=True, text=True, check=True
        ).stdout.strip()
        return private_key, public_key
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Warning: `wg` tool not found. Generating placeholder keys.")
        return "PRIVATE_KEY_PLACEHOLDER", "PUBLIC_KEY_PLACEHOLDER"


def render_config(name, config, private_key):
    """Render a WireGuard config file content."""
    lines = ["[Interface]"]
    lines.append(f"PrivateKey = {private_key}")
    lines.append(f"Address = {config['address']}")
    dns_line = ", ".join(config["dns"])
    lines.append(f"DNS = {dns_line}")
    if name == "hub":
        lines.append(f"ListenPort = {config['listen_port']}")
    lines.append("")

    for peer in config["peers"]:
        lines.append("[Peer]")
        lines.append(f"PublicKey = {peer['public_key']}")
        if "endpoint" in peer:
            lines.append(f"Endpoint = {peer['endpoint']}")
        lines.append(f"AllowedIPs = {', '.join(peer['allowed_ips'])}")
        lines.append("PersistentKeepalive = 25")
        lines.append("")

    return "\n".join(lines)


def main():
    base_dir = Path(__file__).parent / "sites"
    keys = {}

    print("Generating WireGuard configurations for SASE multi-site deployment...")
    print("=" * 60)

    for name, config in SITES.items():
        site_dir = base_dir / name
        site_dir.mkdir(parents=True, exist_ok=True)

        private_key, public_key = generate_keypair()
        keys[name] = public_key

        config_text = render_config(name, config, private_key)

        config_path = site_dir / "wg0.conf"
        with open(config_path, "w") as f:
            f.write(config_text)
        print(f"  [OK] {name} -> {config_path}")
        print(f"       Public Key: {public_key}")

    keys_path = base_dir.parent / "generated-keys.json"
    with open(keys_path, "w") as f:
        json.dump(keys, f, indent=2)
    print(f"\nPublic keys saved to: {keys_path}")
    print("\nNOTE: Replace placeholder public keys in wg0.conf files")
    print("      after running this generator on each site.")

    print("\nTo apply: copy site-*/wg0.conf to the respective site and run `wg-quick up wg0`")


if __name__ == "__main__":
    main()
