# Start food model training (train_env + chunked train_loop).
# Scheduled for 2026-06-02 via register_training_schedule.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
. (Join-Path $PSScriptRoot "train_env.ps1")
& (Join-Path $PSScriptRoot "train_loop.ps1")
