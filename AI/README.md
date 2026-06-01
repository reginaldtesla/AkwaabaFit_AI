# Food model training

The mobile app ships with a bundled ONNX scanner. This folder is only needed to **retrain** or export a new model.

## Your machine (auto-detected)

| Component | Spec |
|-----------|------|
| CPU | Intel Core i7-14700HX (20 cores / 28 threads) |
| RAM | 16 GB DDR5 |
| GPU | NVIDIA GeForce RTX 4050 Laptop (**6 GB** VRAM) |
| Disk | ~140 GB free on `C:` |

Training defaults live in `hardware_profile.json` and are applied via `train_env.ps1` (batch **2**, imgsz **416**, workers **0**, full dataset **fraction=1**, **disk** cache, **5-epoch chunks** in `train_loop.ps1`).

## Setup

```powershell
cd AI
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu124
```

Use the venv Python for training (CUDA build). System Python 3.14 alone is not recommended for Ultralytics yet.

## Workflow

1. **Import downloaded ZIPs** (extract + dedupe by image hash, no training):
   ```powershell
   python AI/import_downloaded_datasets.py "C:\Users\RegiTes\Downloads\Compressed\Food dataset"
   ```
   Output: `AI/datasets/new_raw/` (per-dataset folders). Duplicates tracked in `AI/datasets/dedupe_index.json`.

   **Excluded from training** (removed or never imported): see `AI/datasets/excluded_from_training.json`.
   Usable folders in `new_raw/`: 9 YOLO sets (~19.5k images after removing empty/corrupt/redundant sources).

2. **Merge** into one training set:
   ```powershell
   python AI/merge_all_datasets.py
   ```
   Output: `AI/datasets/merged_v2/data.yaml`

3. **Train** (only when you are ready):
   ```powershell
   . .\AI\train_env.ps1          # loads GPU/RAM-tuned env vars
   .\AI\train_loop.ps1           # recommended on this laptop (auto-resume every 5 epochs)
   # OR one-shot: python AI/train.py
   python AI/train.py finalize
   ```

   **Smoke test** (fast, ~25% of images): `$env:AKWAABA_FRACTION='0.25'; python AI/train.py`

   **If CUDA OOM:** `$env:AKWAABA_BATCH='1'`

   **If GPU driver crashes:** `$env:AKWAABA_DEVICE='cpu'` (very slow)

4. **Export for Flutter**: `.\AI\export_mobile_onnx.ps1` → copy ONNX + labels into `Mobile/assets/models/`.

Training outputs (`runs/`, large `datasets/`, `venv/`) are gitignored. The 13GB Ghanaian ZIP may take a long time to extract.
