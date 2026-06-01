# Register a one-time Windows task to start training on 2 June 2026 at 08:00 (local time).
# Run once from an elevated PowerShell if Register-ScheduledTask fails:
#   powershell -ExecutionPolicy Bypass -File .\AI\register_training_schedule.ps1

$TaskName = "AkwaabaFit_FoodModel_Training"
$StartScript = Join-Path $PSScriptRoot "start_training.ps1"
$StartAt = Get-Date "2026-06-02T08:00:00"

if (-not (Test-Path $StartScript)) {
    Write-Error "Missing $StartScript"
    exit 1
}

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File `"$StartScript`"" `
    -WorkingDirectory $PSScriptRoot

$trigger = New-ScheduledTaskTrigger -Once -At $StartAt

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Days 14)

try {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Description "AkwaabaFit YOLO food model training (auto-started 2026-06-02)" | Out-Null
    $registered = $true
} catch {
    $registered = $false
    Write-Warning "Register-ScheduledTask failed ($($_.Exception.Message)). Trying schtasks..."
    $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$StartScript`""
    schtasks /Create /TN $TaskName /TR $tr /SC ONCE /SD 06/02/2026 /ST 08:00 /F | Out-Host
    if ($LASTEXITCODE -eq 0) { $registered = $true }
}

if (-not $registered) {
    Write-Host "Could not register automatically. On 2026-06-02 run manually:" -ForegroundColor Yellow
    Write-Host "  .\start_training.ps1"
    exit 1
}

Write-Host "Scheduled task registered: $TaskName" -ForegroundColor Green
Write-Host "  Starts: $($StartAt.ToString('dddd, dd MMMM yyyy HH:mm')) (local time)"
Write-Host "  Script: $StartScript"
Write-Host ""
Write-Host "To start manually on that day instead:"
Write-Host "  cd $PSScriptRoot"
Write-Host "  .\start_training.ps1"
Write-Host ""
Write-Host "To remove the schedule:"
Write-Host "  Unregister-ScheduledTask -TaskName $TaskName -Confirm:`$false"
