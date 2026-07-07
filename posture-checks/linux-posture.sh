#!/bin/bash
# SASE Device Posture Check - Linux
set -eu

PASSED=0
TOTAL=0

green() { printf "\033[32m%s\033[0m\n" "$1"; }
red()   { printf "\033[31m%s\033[0m\n" "$1"; }
check() {
    TOTAL=$((TOTAL + 1))
    local name="$1" result="$2" detail="$3"
    if [ "$result" = "pass" ]; then
        PASSED=$((PASSED + 1))
        printf "[PASS] %s: %s\n" "$name" "$detail"
    else
        printf "[FAIL] %s: %s\n" "$name" "$detail"
    fi
}

echo "=== SASE Device Posture Check (Linux) ==="
echo ""

# 1. UFW Firewall
if command -v ufw &>/dev/null; then
    ufw_status=$(ufw status | head -1)
    if echo "$ufw_status" | grep -qi "active"; then
        check "Firewall (UFW)" "pass" "$ufw_status"
    else
        check "Firewall (UFW)" "fail" "$ufw_status"
    fi
elif command -v iptables &>/dev/null; then
    if iptables -L -n | grep -q "Chain"; then
        check "Firewall (iptables)" "pass" "iptables rules present"
    else
        check "Firewall (iptables)" "fail" "no iptables rules"
    fi
else
    check "Firewall" "fail" "No firewall detected"
fi

# 2. Disk Encryption (LUKS)
if command -v cryptsetup &>/dev/null && lsblk -o TYPE 2>/dev/null | grep -q "crypt"; then
    check "Disk Encryption (LUKS)" "pass" "LUKS encrypted volume detected"
else
    check "Disk Encryption (LUKS)" "fail" "No LUKS encrypted volume found"
fi

# 3. Disk Space (>10% free)
disk_free=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
disk_free_pct=$((100 - disk_free))
if [ "$disk_free_pct" -ge 10 ]; then
    check "Disk Space" "pass" "${disk_free_pct}% free on /"
else
    check "Disk Space" "fail" "Only ${disk_free_pct}% free on /"
fi

# 4. ClamAV (if installed)
if command -v clamscan &>/dev/null; then
    check "Antivirus (ClamAV)" "pass" "ClamAV installed"
else
    check "Antivirus (ClamAV)" "info" "ClamAV not installed (optional)"
    PASSED=$((PASSED + 1))
fi

# 5. System updates (apt)
if command -v apt-get &>/dev/null; then
    updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable || true)
    if [ "$updates" -le 10 ]; then
        check "System Updates" "pass" "$updates pending updates"
    else
        check "System Updates" "fail" "$updates pending updates (threshold: 10)"
    fi
else
    check "System Updates" "info" "apt not available, skipping"
    PASSED=$((PASSED + 1))
fi

# 6. SSH config (check for key-based auth)
if [ -f /etc/ssh/sshd_config ]; then
    if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
        check "SSH Security" "pass" "Password auth disabled"
    else
        check "SSH Security" "warn" "Password auth may be enabled"
        PASSED=$((PASSED + 1))
    fi
fi

echo ""
printf "Result: %s/%s checks passed\n" "$PASSED" "$TOTAL"
if [ "$PASSED" -eq "$TOTAL" ]; then
    green "Overall: COMPLIANT"
else
    red "Overall: NON-COMPLIANT"
    echo "SASE POLICY: Remediate failing checks before accessing corporate resources."
fi
