# Chunked auto-restart training — tuned for Regi's RTX 4050 / 16GB RAM laptop.
# Run from repo root or AI folder:
#   .\AI\train_loop.ps1

$ErrorActionPreference = "Stop"
$AiDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $AiDir "train_env.ps1")

$python = if ($env:AKWAABA_PYTHON) { $env:AKWAABA_PYTHON } else { "python" }
$script = Join-Path $AiDir "train.py"
$csv = Join-Path $AiDir "runs\detect\food_model_v2\results.csv"
$weights = Join-Path $AiDir "runs\detect\food_model_v2\weights"

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
