# Re-export v1 weights for Flutter (opset 12 — required by mobile onnxruntime).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvPy = Join-Path $root "venv\Scripts\python.exe"
$pt = Join-Path $root "runs\detect\food_model\weights\best.pt"
$dest = Join-Path $root "..\Mobile\assets\models\food_v1.onnx"

if (-not (Test-Path $pt)) {
    Write-Error "Missing $pt — train v1 first or run: python train.py finalize"
}

& $venvPy -c @"
from pathlib import Path
from ultralytics import YOLO
pt = Path(r'$pt')
out = YOLO(str(pt)).export(format='onnx', imgsz=416, opset=12, simplify=True)
print('Wrote', out)
"@

Copy-Item -Force (Join-Path $root "runs\detect\food_model\weights\best.onnx") $dest
Write-Host "Copied to $dest — restart flutter run (full restart, not hot reload)."
