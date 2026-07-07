import json
import sys
import os
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "posture-checks"))

from posture_checker import PostureChecker


def test_device_id_stable():
    c1 = PostureChecker()
    c2 = PostureChecker()
    assert c1.results["device_id"] == c2.results["device_id"]


def test_device_id_format():
    c = PostureChecker()
    assert len(c.results["device_id"]) == 16


def test_initial_state():
    c = PostureChecker()
    assert c.results["overall_status"] == "unknown"
    assert c.results["checks"] == []


@patch("posture_checker.subprocess.run")
def test_check_firewall_windows(mock_run):
    mock_run.return_value = MagicMock(stdout="ON", returncode=0)
    c = PostureChecker()
    c.results["os"] = "Windows"
    result = c.check_firewall()
    assert result["passed"] is True
    assert result["name"] == "Firewall"


@patch("posture_checker.subprocess.run")
def test_check_firewall_windows_off(mock_run):
    mock_run.return_value = MagicMock(stdout="OFF", returncode=0)
    c = PostureChecker()
    c.results["os"] = "Windows"
    result = c.check_firewall()
    assert result["passed"] is False


@patch("posture_checker.subprocess.run")
def test_check_firewall_linux_ufw(mock_run):
    mock_run.return_value = MagicMock(stdout="Status: active", returncode=0)
    c = PostureChecker()
    c.results["os"] = "Linux"
    result = c.check_firewall()
    assert result["passed"] is True


@patch("posture_checker.subprocess.run")
def test_check_firewall_linux_inactive(mock_run):
    mock_run.return_value = MagicMock(stdout="Status: inactive", returncode=0)
    c = PostureChecker()
    c.results["os"] = "Linux"
    result = c.check_firewall()
    assert result["passed"] is False


@patch("posture_checker.subprocess.run")
def test_check_antivirus_windows_ok(mock_run):
    mock_run.return_value = MagicMock(stdout="True True", returncode=0)
    c = PostureChecker()
    c.results["os"] = "Windows"
    result = c.check_antivirus()
    assert result["passed"] is True


@patch("posture_checker.subprocess.run")
def test_check_antivirus_windows_fail(mock_run):
    mock_run.return_value = MagicMock(stdout="False False", returncode=0)
    c = PostureChecker()
    c.results["os"] = "Windows"
    result = c.check_antivirus()
    assert result["passed"] is False


def test_check_antivirus_non_windows():
    c = PostureChecker()
    c.results["os"] = "Linux"
    result = c.check_antivirus()
    assert result["passed"] is True


@patch("posture_checker.subprocess.run")
def test_check_disk_encryption_windows_ok(mock_run):
    mock_run.return_value = MagicMock(stdout="On", returncode=0)
    c = PostureChecker()
    c.results["os"] = "Windows"
    result = c.check_disk_encryption()
    assert result["passed"] is True


@patch("posture_checker.subprocess.run")
def test_check_disk_encryption_windows_off(mock_run):
    mock_run.return_value = MagicMock(stdout="Off", returncode=0)
    c = PostureChecker()
    c.results["os"] = "Windows"
    result = c.check_disk_encryption()
    assert result["passed"] is False


@patch("posture_checker.subprocess.run")
def test_check_disk_encryption_linux_luks(mock_run):
    mock_run.return_value = MagicMock(stdout="crypto_LUKS", returncode=0)
    c = PostureChecker()
    c.results["os"] = "Linux"
    result = c.check_disk_encryption()
    assert result["passed"] is True


@patch("posture_checker.subprocess.run")
def test_check_disk_encryption_linux_no_luks(mock_run):
    mock_run.return_value = MagicMock(stdout="ext4", returncode=0)
    c = PostureChecker()
    c.results["os"] = "Linux"
    result = c.check_disk_encryption()
    assert result["passed"] is False


def test_check_disk_encryption_unsupported_os():
    c = PostureChecker()
    c.results["os"] = "Darwin"
    result = c.check_disk_encryption()
    assert result["passed"] is True


@patch("posture_checker.subprocess.run")
def test_warp_disconnected(mock_run):
    mock_run.side_effect = FileNotFoundError()
    c = PostureChecker()
    c.results["os"] = "Windows"
    result = c.check_cloudflare_warp()
    assert result["passed"] is False


@patch("posture_checker.subprocess.run")
def test_run_all_creates_checks(mock_run):
    mock_run.return_value = MagicMock(stdout="ON", returncode=0)
    c = PostureChecker()
    results = c.run_all()
    assert len(results["checks"]) == 5
    assert "overall_status" in results
    assert "summary" in results


@patch("posture_checker.subprocess.run")
def test_run_all_compliant(mock_run):
    mock_run.side_effect = [
        MagicMock(stdout="ON", returncode=0),          # firewall
        MagicMock(stdout="True", returncode=0),          # antivirus
        MagicMock(stdout="On", returncode=0),            # disk encryption
        MagicMock(stdout="Security Update KB123456", returncode=0),  # os patches
        MagicMock(stdout="Connected: true", returncode=0),            # warp
    ]
    c = PostureChecker()
    c.run_all()
    assert c.compliant() is True
    assert c.results["overall_status"] == "compliant"


@patch("posture_checker.subprocess.run")
def test_report_json_valid(mock_run):
    mock_run.side_effect = [
        MagicMock(stdout="ON", returncode=0),
        MagicMock(stdout="True", returncode=0),
        MagicMock(stdout="On", returncode=0),
        MagicMock(stdout="Security Update KB123456", returncode=0),
        MagicMock(stdout="Connected: true", returncode=0),
    ]
    c = PostureChecker()
    c.run_all()
    report = json.loads(c.report_json())
    assert report["device_id"] == c.results["device_id"]
    assert report["overall_status"] == "compliant"
    assert len(report["checks"]) == 5


@patch("posture_checker.subprocess.run")
def test_report_human_contains_status(mock_run):
    mock_run.return_value = MagicMock(stdout="ON", returncode=0)
    c = PostureChecker()
    c.run_all()
    report = c.report_human()
    assert "COMPLIANT" in report
    assert "Device:" in report


def test_compliant_default():
    c = PostureChecker()
    assert c.compliant() is False


@patch("posture_checker.subprocess.run")
def test_firewall_platform_darwin(mock_run):
    mock_run.return_value = MagicMock(stdout="Firewall is enabled", returncode=0)
    c = PostureChecker()
    c.results["os"] = "Darwin"
    result = c.check_firewall()
    assert result["passed"] is True


@patch("posture_checker.subprocess.run")
def test_firewall_darwin_disabled(mock_run):
    mock_run.return_value = MagicMock(stdout="Firewall is disabled", returncode=0)
    c = PostureChecker()
    c.results["os"] = "Darwin"
    result = c.check_firewall()
    assert result["passed"] is False


@patch("posture_checker.subprocess.run")
def test_warp_connected(mock_run):
    mock_run.return_value = MagicMock(stdout="Connected: true", returncode=0)
    c = PostureChecker()
    c.results["os"] = "Windows"
    result = c.check_cloudflare_warp()
    assert result["passed"] is True


@patch("posture_checker.subprocess.run")
def test_warp_on_linux(mock_run):
    c = PostureChecker()
    c.results["os"] = "Linux"
    result = c.check_cloudflare_warp()
    assert result["passed"] is False
