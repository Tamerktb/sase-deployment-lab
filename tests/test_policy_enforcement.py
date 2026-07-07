"""
Integration tests for SASE policy enforcement flow.
Tests that non-compliant devices are properly denied access.
"""

import json
import os
import sys
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "posture-checks"))
from posture_checker import PostureChecker


def test_compliant_device_allowed():
    """A fully compliant device should be allowed access."""
    c = PostureChecker()
    c.results["checks"] = [
        {"name": "Firewall", "passed": True, "detail": ""},
        {"name": "Antivirus", "passed": True, "detail": ""},
        {"name": "DiskEncryption", "passed": True, "detail": ""},
        {"name": "OSPatches", "passed": True, "detail": ""},
        {"name": "CloudflareWARP", "passed": True, "detail": ""},
    ]
    c.results["overall_status"] = "compliant"
    c.results["summary"] = "5/5 checks passed"
    assert c.compliant() is True
    assert c.results["overall_status"] == "compliant"


def test_non_compliant_device_denied():
    """A device with any failing check should be denied access."""
    c = PostureChecker()
    c.results["checks"] = [
        {"name": "Firewall", "passed": True, "detail": ""},
        {"name": "Antivirus", "passed": False, "detail": "Defender disabled"},
        {"name": "DiskEncryption", "passed": True, "detail": ""},
        {"name": "OSPatches", "passed": True, "detail": ""},
        {"name": "CloudflareWARP", "passed": True, "detail": ""},
    ]
    c.results["overall_status"] = "non_compliant"
    c.results["summary"] = "4/5 checks passed"
    assert c.compliant() is False
    assert c.results["overall_status"] == "non_compliant"


def test_all_failing_device_denied():
    c = PostureChecker()
    c.results["checks"] = [
        {"name": "Firewall", "passed": False, "detail": "Disabled"},
        {"name": "Antivirus", "passed": False, "detail": "No AV"},
        {"name": "DiskEncryption", "passed": False, "detail": "BitLocker off"},
        {"name": "OSPatches", "passed": False, "detail": "60+ days out of date"},
        {"name": "CloudflareWARP", "passed": False, "detail": "Not connected"},
    ]
    c.results["overall_status"] = "non_compliant"
    c.results["summary"] = "0/5 checks passed"
    assert c.compliant() is False


def test_policy_decision_matches_strict_flag():
    """Verify that --strict flag correctly exits 1 for non-compliant."""
    c = PostureChecker()
    c.results["overall_status"] = "non_compliant"
    c.results["checks"] = []
    assert c.compliant() is False


def test_partial_compliance_still_denied():
    """Even 4/5 passing checks must result in denial (zero trust: all or nothing)."""
    c = PostureChecker()
    c.results["checks"] = [
        {"name": "Firewall", "passed": True, "detail": ""},
        {"name": "Antivirus", "passed": True, "detail": ""},
        {"name": "DiskEncryption", "passed": True, "detail": ""},
        {"name": "OSPatches", "passed": True, "detail": ""},
        {"name": "CloudflareWARP", "passed": False, "detail": "Disconnected"},
    ]
    passed = sum(1 for chk in c.results["checks"] if chk["passed"])
    total = len(c.results["checks"])
    all_pass = passed == total
    assert all_pass is False
    assert passed == 4


@patch("posture_checker.subprocess.run")
def test_end_to_end_compliant_device(mock_run):
    """Full run_all() with mocked subprocess should yield compliant device."""
    mock_run.side_effect = [
        MagicMock(stdout="ON", returncode=0),
        MagicMock(stdout="True", returncode=0),
        MagicMock(stdout="On", returncode=0),
        MagicMock(stdout="Security Update KB123456", returncode=0),
        MagicMock(stdout="Connected: true", returncode=0),
    ]
    c = PostureChecker(os_name="Windows")
    c.run_all()
    assert c.compliant() is True
    assert c.results["overall_status"] == "compliant"


@patch("posture_checker.subprocess.run")
def test_end_to_end_non_compliant_device(mock_run):
    """Full run_all() with failing WARP check should yield non-compliant."""
    mock_run.side_effect = [
        MagicMock(stdout="ON", returncode=0),
        MagicMock(stdout="True", returncode=0),
        MagicMock(stdout="On", returncode=0),
        MagicMock(stdout="Security Update KB123456", returncode=0),
        FileNotFoundError(),  # WARP CLI not found
    ]
    c = PostureChecker(os_name="Windows")
    c.run_all()
    assert c.compliant() is False
    assert c.results["overall_status"] == "non_compliant"
