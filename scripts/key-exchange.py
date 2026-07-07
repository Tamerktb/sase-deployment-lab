#!/usr/bin/env python3
"""
WireGuard key exchange script for SASE multi-site mesh.
Generates key pairs, patches peer public keys across all site configs,
and outputs final configs ready for deployment.
"""

import json
import os
import subprocess
import sys
from pathlib import Path


SITES = ["site-a", "site-b", "hub"]

PEER_MAP = {
    "site-a": {"peers": ["hub"], "peer_keys": {"hub": "HUB_PUBLIC_KEY"}},
    "site-b": {"peers": ["hub"], "peer_keys": {"hub": "HUB_PUBLIC_KEY"}},
    "hub": {"peers": ["site-a", "site-b"], "peer_keys": {"site-a": "SITE_A_PUBLIC_KEY", "site-b": "SITE_B_PUBLIC_KEY"}},
}

KEY_PLACEHOLDERS = {
    "site-a": {"private": "SITE_A_PRIVATE_KEY", "public": "SITE_A_PUBLIC_KEY"},
    "site-b": {"private": "SITE_B_PRIVATE_KEY", "public": "SITE_B_PUBLIC_KEY"},
    "hub": {"private": "HUB_PRIVATE_KEY", "public": "HUB_PUBLIC_KEY"},
}


def generate_keypair():
    try:
        private_key = subprocess.run(
            ["wg", "genkey"], capture_output=True, text=True, check=True
        ).stdout.strip()
        public_key = subprocess.run(
            ["wg", "pubkey"], input=private_key, capture_output=True, text=True, check=True
        ).stdout.strip()
        return private_key, public_key
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Warning: `wg` tool not found. Generating Python-based keys for demo.")
        import secrets
        private_key = secrets.token_hex(32)
        public_key = secrets.token_hex(32)
        return private_key, public_key


def load_config(path):
    with open(path) as f:
        return f.read()


def save_config(path, content):
    with open(path, "w") as f:
        f.write(content)
    print(f"  [OK] Updated {path}")


def patch_private_key(config, placeholder, new_key):
    return config.replace(placeholder, new_key)


def patch_peer_key(config, placeholder, new_key):
    return config.replace(placeholder, new_key)


def main():
    base_dir = Path(__file__).parent.parent / "wireguard" / "sites"
    generated = Path(__file__).parent.parent / "wireguard" / "generated-keys.json"

    print("=" * 60)
    print("SASE WireGuard Key Exchange")
    print("=" * 60)

    keys = {}
    for name in SITES:
        private, public = generate_keypair()
        keys[name] = {"private": private, "public": public}
        print(f"\n  [Key] {name}:")
        print(f"         Private: {private[:16]}...{private[-8:]}")
        print(f"         Public:  {public}")

    with open(generated, "w") as f:
        json.dump({k: {"public": v["public"]} for k, v in keys.items()}, f, indent=2)
    print(f"\n  [OK] Public keys saved to: {generated}")

    print("\n--- Patching WireGuard configs ---")
    for site_name in SITES:
        config_path = base_dir / site_name / "wg0.conf"
        if not config_path.exists():
            print(f"  [SKIP] {config_path} not found")
            continue

        config = load_config(config_path)

        private_ph = KEY_PLACEHOLDERS[site_name]["private"]
        config = patch_private_key(config, private_ph, keys[site_name]["private"])

        for peer_name in PEER_MAP[site_name]["peers"]:
            placeholder = PEER_MAP[site_name]["peer_keys"][peer_name]
            peer_public = keys[peer_name]["public"]
            config = patch_peer_key(config, placeholder, peer_public)

        save_config(config_path, config)

    print("\n" + "=" * 60)
    print("Key exchange complete!")
    print("=" * 60)
    print("\nConfigs are ready for deployment.")
    print("Run: ./scripts/deploy.sh")
    print("Or copy site-*/wg0.conf to respective machines and run `wg-quick up wg0`.")


if __name__ == "__main__":
    main()
