$python = "c:\Apache24\htdocs\AkwaabaFitAIProject\AI\venv\Scripts\python.exe"
$script = "c:\Apache24\htdocs\AkwaabaFitAIProject\AI\train.py"
$csv = "c:\Apache24\htdocs\AkwaabaFitAIProject\AI\runs\detect\food_model_v2\results.csv"
$weights = "c:\Apache24\htdocs\AkwaabaFitAIProject\AI\runs\detect\food_model_v2\weights"

# Train at most this many epoch indices per Python process, then exit cleanly and restart (reduces hangs / zombies).
$env:AKWAABA_CHUNK_EPOCHS = "5"
# Fresh optimizer each resume (fixes cuBLAS backward crashes from stale checkpoint optimizer state).
$env:AKWAABA_FRESH_OPTIMIZER = "1"
# Small speed boost (restart train_loop to apply). If OOM/crash, set AKWAABA_BATCH=1
$env:AKWAABA_BATCH = "2"
$env:AKWAABA_CACHE = "disk"
# If RAM spikes, keep workers at 0. If CPU is the bottleneck, try: $env:AKWAABA_WORKERS = "2"
if (-not $env:AKWAABA_WORKERS) { $env:AKWAABA_WORKERS = "0" }
# Use CPU only if GPU still crashes after reboot: $env:AKWAABA_DEVICE = "cpu"
if (-not $env:AKWAABA_DEVICE) { $env:AKWAABA_DEVICE = "0" }

function Stop-OrphanTrainPy {
    $killed = 0
    Get-CimInstance Win32_Process -Filter "name='python.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*AkwaabaFitAIProject*AI*train.py*' } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            $killed++
        }
    if ($killed -gt 0) {
        Write-Host "Stopped $killed stray train.py process(es)." -ForegroundColor DarkYellow
        Start-Sleep -Seconds 2
    }
}

function Get-MaxEpochFromCsv {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    $max = 0
    Get-Content $Path | Select-Object -Skip 1 | ForEach-Object {
        if ($_ -match '^(\d+),') {
            $e = [int]$Matches[1]
            if ($e -gt $max) { $max = $e }
        }
    }
    return $max
}

function Backup-ResumableCheckpoint {
    param([string]$WeightsDir)
    $src = Join-Path $WeightsDir "last_resumable.pt"
    if (-not (Test-Path $src)) { $src = Join-Path $WeightsDir "last.pt" }
    if (-not (Test-Path $src)) { return }
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $bak = Join-Path $WeightsDir "last_resumable.$stamp.bak.pt"
    Copy-Item $src $bak -Force
    Write-Host "  [backup] $bak" -ForegroundColor DarkCyan
}

Write-Host "=== AUTO-RESTART TRAINING (chunked) ===" -ForegroundColor Green
Write-Host "AKWAABA_CHUNK_EPOCHS=$env:AKWAABA_CHUNK_EPOCHS | Press Ctrl+C to stop."
Write-Host "When fully trained, run: $python $script finalize" -ForegroundColor Cyan

for ($i = 1; $i -le 500; $i++) {
    Stop-OrphanTrainPy

    $epoch = Get-MaxEpochFromCsv $csv
    Write-Host "`n--- Run $i | Max epoch in CSV: $epoch ---" -ForegroundColor Yellow

    if ($epoch -ge 200) {
        Write-Host "Training complete ($epoch/200 epochs). Running finalize (val + ONNX)..." -ForegroundColor Green
        & $python $script finalize
        break
    }

    Backup-ResumableCheckpoint $weights

    & $python $script

    Start-Sleep -Seconds 5

    $newEpoch = Get-MaxEpochFromCsv $csv
    Write-Host "  Progress: max epoch $epoch -> $newEpoch" -ForegroundColor Cyan
}
