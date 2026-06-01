# AkwaabaFit - training environment tuned for THIS machine (see hardware_profile.json).
# Usage (PowerShell, before train.py or train_loop.ps1):
#   . .\AI\train_env.ps1

$ErrorActionPreference = "Stop"
$AiDir = $PSScriptRoot
$ProfilePath = Join-Path $AiDir "hardware_profile.json"

if (-not (Test-Path $ProfilePath)) {
    Write-Warning "hardware_profile.json not found; using safe laptop defaults."
    $t = @{ batch = 2; imgsz = 416; workers = 0; fraction = 1.0; cache = "disk"; device = "0"; chunk_epochs = 5 }
} else {
    $hw = Get-Content $ProfilePath -Raw | ConvertFrom-Json
    $t = $hw.training
    Write-Host "=== Training env: $($hw.machine_label) ===" -ForegroundColor Green
    Write-Host "  GPU: $($hw.gpu.name) ($($hw.gpu.vram_mib) MiB) | RAM: $($hw.ram_gb) GB | CPU: $($hw.cpu.model)"
}

# Only set if not already overridden in the shell session
if (-not $env:AKWAABA_DEVICE)     { $env:AKWAABA_DEVICE = [string]$t.device }
if (-not $env:AKWAABA_BATCH)      { $env:AKWAABA_BATCH = [string]$t.batch }
if (-not $env:AKWAABA_IMG_SIZE)   { $env:AKWAABA_IMG_SIZE = [string]$t.imgsz }
if (-not $env:AKWAABA_WORKERS)    { $env:AKWAABA_WORKERS = [string]$t.workers }
if (-not $env:AKWAABA_FRACTION)   { $env:AKWAABA_FRACTION = [string]$t.fraction }
if (-not $env:AKWAABA_CACHE)      { $env:AKWAABA_CACHE = [string]$t.cache }
if (-not $env:AKWAABA_CHUNK_EPOCHS) { $env:AKWAABA_CHUNK_EPOCHS = [string]$t.chunk_epochs }
if (-not $env:AKWAABA_FRESH_OPTIMIZER) {
    $env:AKWAABA_FRESH_OPTIMIZER = if ($t.fresh_optimizer) { "1" } else { "0" }
}

Write-Host "  AKWAABA_DEVICE=$env:AKWAABA_DEVICE batch=$env:AKWAABA_BATCH imgsz=$env:AKWAABA_IMG_SIZE workers=$env:AKWAABA_WORKERS"
Write-Host "  fraction=$env:AKWAABA_FRACTION cache=$env:AKWAABA_CACHE chunk_epochs=$env:AKWAABA_CHUNK_EPOCHS"
Write-Host "  Override any variable in this shell before training if you need a smoke test (e.g. set AKWAABA_FRACTION=0.25)."

# Python: prefer project venv when present
$venvPy = Join-Path $AiDir "venv\Scripts\python.exe"
if (Test-Path $venvPy) {
    $env:AKWAABA_PYTHON = $venvPy
} else {
    $env:AKWAABA_PYTHON = "python"
    Write-Host '  Note: AI\venv not found. Run: python -m venv venv; pip install -r requirements.txt' -ForegroundColor Yellow
}
