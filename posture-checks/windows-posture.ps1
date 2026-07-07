# SASE Device Posture Check - Windows
# Run as Administrator to check all controls

$Checks = @()

Write-Host "=== SASE Device Posture Check (Windows) ===" -ForegroundColor Cyan
Write-Host ""

# 1. Firewall Status
$fw = Get-NetFirewallProfile -Profile Domain, Public, Private
$fwEnabled = ($fw | Where-Object { $_.Enabled -eq $true }).Count
$Checks += [PSCustomObject]@{
    Check   = "Windows Firewall"
    Status  = if ($fwEnabled -ge 2) { "PASS" } else { "FAIL" }
    Detail  = "$fwEnabled of 3 profiles enabled"
}

# 2. Antivirus / Defender
$mp = Get-MpComputerStatus
$avStatus = $mp.AntivirusEnabled -and $mp.RealTimeProtectionEnabled
$Checks += [PSCustomObject]@{
    Check   = "Antivirus (Defender)"
    Status  = if ($avStatus) { "PASS" } else { "FAIL" }
    Detail  = "Antivirus: $($mp.AntivirusEnabled), Real-time: $($mp.RealTimeProtectionEnabled)"
}

# 3. BitLocker
try {
    $bl = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
    $blProtected = $bl.ProtectionStatus -eq 1
} catch {
    $blProtected = $false
}
$Checks += [PSCustomObject]@{
    Check   = "BitLocker Encryption"
    Status  = if ($blProtected) { "PASS" } else { "FAIL" }
    Detail  = "Drive C: protection is $($bl.ProtectionStatus)"
}

# 4. OS Patches
$lastPatch = Get-HotFix | Select-Object -Last 1
$daysSincePatch = [math]::Round(((Get-Date) - $lastPatch.InstalledOn).TotalDays)
$patchOK = $daysSincePatch -le 60
$Checks += [PSCustomObject]@{
    Check   = "OS Patches"
    Status  = if ($patchOK) { "PASS" } else { "FAIL" }
    Detail  = "Last patch: $($lastPatch.InstalledOn) ($daysSincePatch days ago)"
}

# 5. WARP Client
try {
    $warp = & "warp-cli" status 2>$null
    $warpOK = $warp -match "Connected"
} catch {
    $warpOK = $false
}
$Checks += [PSCustomObject]@{
    Check   = "Cloudflare WARP"
    Status  = if ($warpOK) { "PASS" } else { "FAIL" }
    Detail  = if ($warpOK) { "WARP Connected" } else { "WARP not connected" }
}

# 6. Disk Space
$disk = Get-PSDrive -Name C
$diskOK = ($disk.Free / $disk.Used) -gt 0.1
$Checks += [PSCustomObject]@{
    Check   = "Disk Space (>10% free)"
    Status  = if ($diskOK) { "PASS" } else { "FAIL" }
    Detail  = "$([math]::Round($disk.Free/1GB,1)) GB free of $([math]::Round(($disk.Used+$disk.Free)/1GB,1)) GB"
}

Write-Host "Check`t`tStatus`tDetail" -ForegroundColor Yellow
Write-Host "-----`t`t------`t------" -ForegroundColor Yellow
$passed = 0
foreach ($c in $Checks) {
    $color = if ($c.Status -eq "PASS") { "Green" } else { "Red" }
    Write-Host "$($c.Check)`t`t$($c.Status)`t$($c.Detail)" -ForegroundColor $color
    if ($c.Status -eq "PASS") { $passed++ }
}

Write-Host ""
Write-Host "Result: $passed/$($Checks.Count) checks passed" -ForegroundColor $(if ($passed -eq $Checks.Count) { "Green" } else { "Red" })
Write-Host "Overall: $(if ($passed -eq $Checks.Count) { 'COMPLIANT' } else { 'NON-COMPLIANT' })" -ForegroundColor $(if ($passed -eq $Checks.Count) { "Green" } else { "Red" })

if ($passed -ne $Checks.Count) {
    Write-Host "`nSASE POLICY: Remediate failing checks before accessing corporate resources." -ForegroundColor Yellow
}
