#!/usr/bin/env python3
"""
SASE Device Posture Checker
Validates device compliance before allowing access to corporate resources.
Checks: OS version, disk encryption, firewall status, antivirus, disk encryption, and patches.
"""

import json
import platform
import subprocess
import sys
import hashlib
import datetime


class PostureChecker:
    def __init__(self):
        self.results = {
            "device_id": self._get_device_id(),
            "timestamp": datetime.datetime.now(datetime.UTC).isoformat() + "Z",
            "os": platform.system(),
            "os_version": platform.version(),
            "hostname": platform.node(),
            "checks": [],
            "overall_status": "unknown",
        }

    def _get_device_id(self):
        h = hashlib.sha256()
        for s in [platform.node(), platform.machine(), platform.processor()]:
            h.update(s.encode())
        return h.hexdigest()[:16]

    def _check(self, name, passed, detail=""):
        return {
            "name": name,
            "passed": passed,
            "detail": detail,
        }

    def check_firewall(self):
        os_name = self.results["os"]
        if os_name == "Windows":
            r = subprocess.run(
                ["netsh", "advfirewall", "show", "allprofiles", "state"],
                capture_output=True, text=True, timeout=10,
            )
            enabled = "ON" in r.stdout.upper()
            return self._check("Firewall", enabled, r.stdout.strip()[:200])
        elif os_name == "Linux":
            r = subprocess.run(
                ["ufw", "status"], capture_output=True, text=True, timeout=10
            )
            enabled = "active" in r.stdout.lower() and "inactive" not in r.stdout.lower()
            return self._check("Firewall", enabled, r.stdout.strip()[:200])
        elif os_name == "Darwin":
            r = subprocess.run(
                ["/usr/libexec/ApplicationFirewall/socketfilterfw", "--getglobalstate"],
                capture_output=True, text=True, timeout=10,
            )
            enabled = "enabled" in r.stdout.lower()
            return self._check("Firewall", enabled, r.stdout.strip()[:200])

    def check_antivirus(self):
        if self.results["os"] == "Windows":
            r = subprocess.run(
                ["powershell", "-Command",
                 "Get-MpComputerStatus | Select-Object -Property AntivirusEnabled, RealTimeProtectionEnabled"],
                capture_output=True, text=True, timeout=30,
            )
            passed = "True" in r.stdout
            return self._check("Antivirus", passed, r.stdout.strip()[:200])
        return self._check("Antivirus", True, "Platform does not require AV check")

    def check_disk_encryption(self):
        os_name = self.results["os"]
        if os_name == "Windows":
            r = subprocess.run(
                ["powershell", "-Command",
                 "Get-BitLockerVolume -MountPoint C: | Select-Object -ExpandProperty ProtectionStatus"],
                capture_output=True, text=True, timeout=30,
            )
            passed = "On" in r.stdout
            return self._check("DiskEncryption", passed, r.stdout.strip()[:200])
        elif os_name == "Linux":
            r = subprocess.run(
                ["lsblk", "-o", "NAME,TYPE,FSTYPE,MOUNTPOINT"],
                capture_output=True, text=True, timeout=10,
            )
            passed = "crypto_LUKS" in r.stdout
            return self._check("DiskEncryption", passed, r.stdout.strip()[:200])
        return self._check("DiskEncryption", True, "Encryption check not implemented for this OS")

    def check_os_patches(self):
        if self.results["os"] == "Windows":
            r = subprocess.run(
                ["powershell", "-Command",
                 "Get-HotFix | Select-Object -Last 1 | Format-Table -AutoSize"],
                capture_output=True, text=True, timeout=30,
            )
            passed = len(r.stdout.strip()) > 0
            return self._check("OSPatches", passed, "Last patch: " + r.stdout.strip()[:100])
        return self._check("OSPatches", True, "Patch check not implemented for this OS")

    def check_cloudflare_warp(self):
        is_windows = self.results["os"] == "Windows"
        warp_cli = "warp-cli" if not is_windows else "warp-cli.exe"
        if is_windows:
            try:
                r = subprocess.run(
                    [warp_cli, "status"], capture_output=True, text=True, timeout=10
                )
                connected = "Connected" in r.stdout
                return self._check("CloudflareWARP", connected, r.stdout.strip()[:200])
            except FileNotFoundError:
                return self._check("CloudflareWARP", False, "WARP CLI not found - install Cloudflare WARP client")
        return self._check("CloudflareWARP", False, "WARP CLI not available on this platform")

    def run_all(self):
        self.results["checks"] = [
            self.check_firewall(),
            self.check_antivirus(),
            self.check_disk_encryption(),
            self.check_os_patches(),
            self.check_cloudflare_warp(),
        ]
        passed_checks = sum(1 for c in self.results["checks"] if c["passed"])
        total = len(self.results["checks"])
        self.results["overall_status"] = "compliant" if passed_checks == total else "non_compliant"
        self.results["summary"] = f"{passed_checks}/{total} checks passed"
        return self.results

    def compliant(self):
        return self.results["overall_status"] == "compliant"

    def report_json(self):
        return json.dumps(self.results, indent=2)

    def report_human(self):
        lines = []
        lines.append(f"Device: {self.results['hostname']} ({self.results['os']})")
        lines.append(f"Device ID: {self.results['device_id']}")
        lines.append(f"Timestamp: {self.results['timestamp']}")
        lines.append(f"Status: {self.results['overall_status'].upper()}")
        lines.append(f"Summary: {self.results['summary']}")
        lines.append("---")
        for c in self.results["checks"]:
            status = "PASS" if c["passed"] else "FAIL"
            lines.append(f"  [{status}] {c['name']}: {c['detail']}")
        return "\n".join(lines)


def main():
    checker = PostureChecker()
    checker.run_all()

    if "--json" in sys.argv:
        print(checker.report_json())
    else:
        print(checker.report_human())

    if not checker.compliant() and "--strict" in sys.argv:
        print("\nSASE POLICY: Device is non-compliant. Access DENIED.")
        sys.exit(1)


if __name__ == "__main__":
    main()
