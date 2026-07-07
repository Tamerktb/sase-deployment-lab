#!/bin/bash
# SASE Deployment Lab - Verification Script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo "  [PASS] $1"; }
fail() { FAILED=$((FAILED + 1)); echo "  [FAIL] $1"; }

echo "======================================"
echo " SASE Deployment Lab - Verification"
echo "======================================"
echo ""

# 1. Docker containers
echo "--- Docker Containers ---"
for container in sase-site-a-web sase-site-a-api sase-site-b-web sase-site-b-db sase-hub-monitor sase-wg-hub sase-posture-gateway; do
    if docker ps --format '{{.Names}}' | grep -q "^$container$"; then
        pass "$container is running"
    else
        fail "$container is not running"
    fi
done

# 2. Network connectivity
echo ""
echo "--- Network Connectivity ---"
docker exec sase-site-a-web ping -c 1 -W 2 10.0.1.20 &>/dev/null && pass "Site-A intra-site connectivity" || fail "Site-A intra-site connectivity"
docker exec sase-site-b-web ping -c 1 -W 2 10.0.2.20 &>/dev/null && pass "Site-B intra-site connectivity" || fail "Site-B intra-site connectivity"

# 3. HTTP accessibility
echo ""
echo "--- HTTP Endpoints ---"
curl -sf http://localhost:9090 > /dev/null && pass "Hub Monitor (localhost:9090)" || fail "Hub Monitor (localhost:9090)"

# 4. Posture checker
echo ""
echo "--- Device Posture ---"
if python3 "$PROJECT_DIR/posture-checks/posture-checker.py" --json | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d['overall_status']=='compliant' else 1)" 2>/dev/null; then
    pass "Posture check passed"
else
    fail "Posture check failed (expected if not on configured device)"
fi

# 5. WireGuard configs exist
echo ""
echo "--- WireGuard Configs ---"
for site in hub site-a site-b; do
    if [ -f "$PROJECT_DIR/wireguard/sites/$site/wg0.conf" ]; then
        pass "WireGuard config for $site"
    else
        fail "WireGuard config for $site"
    fi
done

# 6. Terraform valid
echo ""
echo "--- Terraform ---"
cd "$PROJECT_DIR/terraform"
if terraform fmt -check -diff 2>/dev/null; then
    pass "Terraform formatting"
else
    fail "Terraform formatting"
fi
if terraform validate 2>/dev/null; then
    pass "Terraform validation"
else
    fail "Terraform validation"
fi

# Summary
echo ""
echo "======================================"
echo " Results: $PASSED passed, $FAILED failed"
echo "======================================"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
