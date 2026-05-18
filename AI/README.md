# Food model training

The mobile app ships with a bundled ONNX scanner. This folder is only needed to **retrain** or export a new model.

## Setup

```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

## Workflow

1. Place or merge datasets (see `merge_datasets.py`, `merge_all_datasets.py`).
2. Run `python train.py` or use `Train_Food_Model_Colab.ipynb`.
3. Export for Flutter: `export_mobile_onnx.ps1` → copy ONNX + labels into the mobile assets models folder.

Training outputs (`runs/`, large `datasets/`, `venv/`) are gitignored and were removed from typical project copies to save space.
