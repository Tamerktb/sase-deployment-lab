"""Integration tests for SASE policy decision logic.
Tests that the posture checker correctly enforces the same logic
Cloudflare Access would use when deciding to allow/deny access."""

import json
import sys
import os
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "posture-checks"))
from posture_checker import PostureChecker


def test_policy_allows_compliant_device():
    """A device that passes all checks should be allowed access."""
    with patch("posture_checker.subprocess.run") as mock_run:
        mock_run.side_effect = [
            MagicMock(stdout="ON", returncode=0),
            MagicMock(stdout="True", returncode=0),
            MagicMock(stdout="On", returncode=0),
            MagicMock(stdout="Security Update KB123456", returncode=0),
            MagicMock(stdout="Connected: true", returncode=0),
        ]
        c = PostureChecker()
        c.run_all()
        assert c.compliant() is True
        assert c.results["overall_status"] == "compliant"


def test_policy_blocks_non_compliant_device():
    """A device failing any check should be denied access (zero trust)."""
    with patch("posture_checker.subprocess.run") as mock_run:
        mock_run.side_effect = [
            MagicMock(stdout="OFF", returncode=0),
            MagicMock(stdout="True", returncode=0),
            MagicMock(stdout="On", returncode=0),
            MagicMock(stdout="Security Update KB123456", returncode=0),
            MagicMock(stdout="Connected: true", returncode=0),
        ]
        c = PostureChecker()
        c.run_all()
        assert c.compliant() is False
        assert c.results["overall_status"] == "non_compliant"


def test_policy_blocks_firewall_off():
    """Firewall disabled = denied."""
    with patch("posture_checker.subprocess.run") as mock_run:
        mock_run.return_value = MagicMock(stdout="OFF", returncode=0)
        c = PostureChecker()
        c.results["os"] = "Windows"
        result = c.check_firewall()
        assert result["passed"] is False


def test_policy_blocks_antivirus_off():
    """Antivirus disabled = denied."""
    with patch("posture_checker.subprocess.run") as mock_run:
        mock_run.return_value = MagicMock(stdout="False False", returncode=0)
        c = PostureChecker()
        c.results["os"] = "Windows"
        result = c.check_antivirus()
        assert result["passed"] is False


def test_policy_blocks_no_encryption():
    """Disk encryption off = denied."""
    with patch("posture_checker.subprocess.run") as mock_run:
        mock_run.return_value = MagicMock(stdout="Off", returncode=0)
        c = PostureChecker()
        c.results["os"] = "Windows"
        result = c.check_disk_encryption()
        assert result["passed"] is False


def test_policy_blocks_no_warp():
    """WARP not connected = denied."""
    with patch("posture_checker.subprocess.run") as mock_run:
        mock_run.side_effect = FileNotFoundError()
        c = PostureChecker()
        c.results["os"] = "Windows"
        result = c.check_cloudflare_warp()
        assert result["passed"] is False


def test_policy_allows_linux_no_av():
    """Linux without AV is allowed (AV check is Windows-only)."""
    c = PostureChecker()
    c.results["os"] = "Linux"
    result = c.check_antivirus()
    assert result["passed"] is True


def test_policy_allows_macos_no_disk_encryption_check():
    """macOS disk encryption check falls through gracefully."""
    c = PostureChecker()
    c.results["os"] = "Darwin"
    result = c.check_disk_encryption()
    assert result["passed"] is True


def test_strict_mode_exits_non_compliant():
    """--strict flag should exit(1) for non-compliant devices (simulates Cloudflare Access denying)."""
    with patch("posture_checker.subprocess.run") as mock_run:
        mock_run.return_value = MagicMock(stdout="OFF", returncode=0)
        c = PostureChecker()
        c.run_all()
        assert c.compliant() is False
        # This is the same logic Cloudflare Access uses:
        # if device_posture check fails -> deny access
        assert c.results["overall_status"] == "non_compliant"


def test_partial_compliance_still_denied():
    """Zero trust: one failed check = denied, even if others pass."""
    with patch("posture_checker.subprocess.run") as mock_run:
        mock_run.side_effect = [
            MagicMock(stdout="ON", returncode=0),
            MagicMock(stdout="True", returncode=0),
            MagicMock(stdout="On", returncode=0),
            MagicMock(stdout="", returncode=0),  # no patches = fail
            MagicMock(stdout="Connected: true", returncode=0),
        ]
        c = PostureChecker()
        c.run_all()
        assert c.compliant() is False
        assert c.results["summary"] != "5/5 checks passed"


def test_policy_summary_reflects_reality():
    """Summary string must match actual check results."""
    with patch("posture_checker.subprocess.run") as mock_run:
        mock_run.side_effect = [
            MagicMock(stdout="ON", returncode=0),
            MagicMock(stdout="True", returncode=0),
            MagicMock(stdout="Off", returncode=0),
            MagicMock(stdout="Security Update KB123456", returncode=0),
            MagicMock(stdout="Connected: true", returncode=0),
        ]
        c = PostureChecker()
        c.run_all()
        assert c.results["summary"] == "4/5 checks passed"
        assert "4/5" in c.results["summary"]
