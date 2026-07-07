# Scenario 2: Device Posture Check Enforcement

**Objective:** Demonstrate that only compliant devices can access SASE resources. Non-compliant devices are blocked.

## Topology
```
  Device ──► Posture Check ──► Cloudflare Access ──► App
              (WARP Client)     (Require Posture)     (Granted)
```

## Prerequisites
- Cloudflare WARP client installed on the device
- Device posture integration enabled in Cloudflare Zero Trust dashboard

## Steps

### 1. Run the Posture Checker
```bash
# Windows (Run as Administrator)
powershell -ExecutionPolicy Bypass -File posture-checks/windows-posture.ps1

# Linux
bash posture-checks/linux-posture.sh

# Cross-platform Python
python posture-checks/posture-checker.py --json
```

### 2. Intentionally Fail a Check
On Windows, disable the firewall temporarily to simulate a non-compliant device:
```powershell
# Simulate non-compliance (DO NOT DO in production)
netsh advfirewall set allprofiles state off
powershell -ExecutionPolicy Bypass -File posture-checks/windows-posture.ps1
```

### 3. Attempt Access
Try accessing the same application from Scenario 1. The posture check should fail.

### 4. Remediate and Retry
Re-enable the firewall:
```powershell
netsh advfirewall set allprofiles state on
```

Wait 60 seconds for Cloudflare to recheck posture, then refresh the application.

## Expected Results
- [ ] Compliant device: Access granted
- [ ] Non-compliant device: Access blocked with "Device not compliant" message
- [ ] After remediation: Access restored within ~60 seconds

## Posture Checks Implemented
| Check | Windows | Linux | macOS |
|-------|---------|-------|-------|
| Firewall Enabled | Windows Defender Firewall | UFW/iptables | socketfilterfw |
| Antivirus Active | Windows Defender | ClamAV | - |
| Disk Encryption | BitLocker | LUKS | FileVault |
| OS Patches | Last 60 days | < 10 pending | - |
| WARP Connected | warp-cli | warp-cli | warp-cli |
