"""Move 10% of merged train images into valid/ (required by Ultralytics)."""
import random
import shutil
from pathlib import Path

MERGED = Path(__file__).resolve().parent / "datasets" / "merged_v2"
TRAIN_IMG = MERGED / "train" / "images"
TRAIN_LBL = MERGED / "train" / "labels"
VALID_IMG = MERGED / "valid" / "images"
VALID_LBL = MERGED / "valid" / "labels"

VALID_IMG.mkdir(parents=True, exist_ok=True)
VALID_LBL.mkdir(parents=True, exist_ok=True)

images = [p for p in TRAIN_IMG.iterdir() if p.is_file()]
n_val = max(500, len(images) // 10)
random.seed(42)
val_pick = set(random.sample(images, min(n_val, len(images))))

for img in val_pick:
    shutil.move(img, VALID_IMG / img.name)
    lbl = TRAIN_LBL / f"{img.stem}.txt"
    if lbl.is_file():
        shutil.move(lbl, VALID_LBL / lbl.name)

print(f"train images: {len(list(TRAIN_IMG.iterdir()))}")
print(f"valid images: {len(list(VALID_IMG.iterdir()))}")
