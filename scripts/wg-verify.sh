#!/bin/bash
# SASE WireGuard Handshake Verification
# Checks if WireGuard peers are actually connected (handshake established).
# Run this on a host with WireGuard installed and configs deployed.
#
# Usage: bash scripts/wg-verify.sh [site-name]
#   site-name: hub, site-a, site-b (default: all)

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo "  [PASS] $1"; }
fail() { FAILED=$((FAILED + 1)); echo "  [FAIL] $1"; }

echo "======================================"
echo " SASE WireGuard Handshake Check"
echo "======================================"
echo ""

# If running inside Docker, check the wireguard container
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^sase-wg-hub$"; then
  echo "--- Docker WireGuard Hub ---"
  WG_SHOW=$(docker exec sase-wg-hub wg show 2>/dev/null || echo "")

  if [ -z "$WG_SHOW" ]; then
    fail "WireGuard not running inside container (expected — Docker doesn't route through it)"
    echo ""
    echo "NOTE: WireGuard inside Docker lacks kernel modules for actual encryption."
    echo "      To verify real handshakes, deploy configs on a Linux host:"
    echo "        1. Copy wireguard/sites/<site>/wg0.conf to /etc/wireguard/wg0.conf"
    echo "        2. wg-quick up wg0"
    echo "        3. wg show"
    echo ""
else
    echo "$WG_SHOW"
    PEER_COUNT=$(echo "$WG_SHOW" | grep -c "peer:" || true)
    HANDSHAKE_COUNT=$(echo "$WG_SHOW" | grep -c "latest handshake" || true)

    if [ "$HANDSHAKE_COUNT" -gt 0 ]; then
      pass "$HANDSHAKE_COUNT/$PEER_COUNT peers have established handshakes"
    else
      fail "No handshakes established"
    fi
  fi

  # Check config file exists and has real keys (not placeholders)
  echo ""
  echo "--- WireGuard Config Integrity ---"
  for site in hub site-a site-b; do
    CONFIG="$PROJECT_DIR/wireguard/sites/$site/wg0.conf"
    if [ -f "$CONFIG" ]; then
      if grep -q "PRIVATE_KEY\|PUBLIC_KEY" "$CONFIG" 2>/dev/null; then
        fail "$site config still has placeholder keys — run 'make keygen' first"
      else
        pass "$site config has real keys"
      fi
    else
      fail "$site config not found"
    fi
  done
else
  echo "--- Host WireGuard Check ---"
  if command -v wg &>/dev/null; then
    WG_SHOW=$(wg show 2>/dev/null || echo "No WireGuard interfaces")
    echo "$WG_SHOW"
    echo ""
    if echo "$WG_SHOW" | grep -q "latest handshake"; then
      pass "Active WireGuard handshakes detected"
    else
      fail "No WireGuard handshakes (expected if not connected to peers)"
    fi
  else
    fail "WireGuard tools not installed on this host"
  fi
fi

echo ""
echo "======================================"
echo " Results: $PASSED passed, $FAILED failed"
echo "======================================"
