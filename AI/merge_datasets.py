"""
Merge two Roboflow YOLOv8 datasets into one unified dataset.

Source datasets:
  - ghanaian_food_yolov8: 16 Ghanaian classes, ~5700 images
  - food_yolov8:          7 international classes, ~3100 images

Output: AI/datasets/merged/  with train/valid/test splits and a unified data.yaml
"""
import shutil
import random
import yaml
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "datasets"
OUT = ROOT / "merged"

SOURCES = {
    "ghanaian": ROOT / "ghanaian_food_yolov8",
    "international": ROOT / "food_yolov8",
}

# We also pull the small v1 kenkey set into training (extra augmented kenkey images).
EXTRA_SOURCES = {
    "v1_kenkey": ROOT / "ghanaian_food_v1",
}

VALID_RATIO = 0.15
TEST_RATIO = 0.05


def load_classes(data_yaml: Path) -> list[str]:
    with open(data_yaml) as f:
        cfg = yaml.safe_load(f)
    return [c.lower().strip() for c in cfg["names"]]


def normalise_class_name(name: str) -> str:
    """Unify naming across datasets."""
    mapping = {
        "chicken leg - v1 2024-05-09 1-55am": "chicken",
        "cooked_meat": "meat",
        "plain-rice": "rice",
        "egg-and-pepper": "egg-pepper",
        "fried plantain": "plantain",
        "boiled egg": "boiled-egg",
    }
    return mapping.get(name.lower().strip(), name.lower().strip())


def main():
    # 1. Build unified class list
    all_classes_set: set[str] = set()
    dataset_class_lists: dict[str, list[str]] = {}

    for key, src in {**SOURCES, **EXTRA_SOURCES}.items():
        raw = load_classes(src / "data.yaml")
        normalised = [normalise_class_name(c) for c in raw]
        dataset_class_lists[key] = normalised
        all_classes_set.update(normalised)

    unified_classes = sorted(all_classes_set)
    class_to_idx = {c: i for i, c in enumerate(unified_classes)}
    print(f"Unified classes ({len(unified_classes)}): {unified_classes}")

    # 2. Collect all (image, label) pairs, remapping class indices
    all_pairs: list[tuple[Path, Path, str]] = []  # (img, lbl, source_key)

    for key, src in {**SOURCES, **EXTRA_SOURCES}.items():
        old_classes = dataset_class_lists[key]
        old_to_new = {i: class_to_idx[c] for i, c in enumerate(old_classes)}

        for split_dir in (src / "train", src / "valid", src / "test"):
            img_dir = split_dir / "images"
            lbl_dir = split_dir / "labels"
            if not img_dir.exists():
                continue
            for img_path in sorted(img_dir.iterdir()):
                if img_path.suffix.lower() not in (".jpg", ".jpeg", ".png", ".bmp", ".webp"):
                    continue
                lbl_path = lbl_dir / (img_path.stem + ".txt")
                if not lbl_path.exists():
                    continue
                all_pairs.append((img_path, lbl_path, key))

    print(f"Total image-label pairs: {len(all_pairs)}")

    # 3. Shuffle and split
    random.seed(42)
    random.shuffle(all_pairs)
    n = len(all_pairs)
    n_test = int(n * TEST_RATIO)
    n_valid = int(n * VALID_RATIO)
    splits = {
        "test": all_pairs[:n_test],
        "valid": all_pairs[n_test : n_test + n_valid],
        "train": all_pairs[n_test + n_valid :],
    }
    for s, pairs in splits.items():
        print(f"  {s}: {len(pairs)} images")

    # 4. Copy files, remapping labels
    for split_name, pairs in splits.items():
        img_out = OUT / split_name / "images"
        lbl_out = OUT / split_name / "labels"
        img_out.mkdir(parents=True, exist_ok=True)
        lbl_out.mkdir(parents=True, exist_ok=True)

        for idx, (img_path, lbl_path, src_key) in enumerate(pairs):
            old_classes = dataset_class_lists[src_key]
            old_to_new = {i: class_to_idx[c] for i, c in enumerate(old_classes)}

            # Unique filename to avoid collisions across datasets
            stem = f"{src_key}_{idx:06d}"
            suffix = img_path.suffix
            shutil.copy2(img_path, img_out / f"{stem}{suffix}")

            # Remap label indices
            new_lines = []
            for line in lbl_path.read_text().strip().splitlines():
                parts = line.strip().split()
                if len(parts) < 5:
                    continue
                old_cls = int(parts[0])
                if old_cls not in old_to_new:
                    continue
                new_cls = old_to_new[old_cls]
                new_lines.append(f"{new_cls} {' '.join(parts[1:])}")
            (lbl_out / f"{stem}.txt").write_text("\n".join(new_lines) + "\n")

    # 5. Write data.yaml
    data_yaml = {
        "path": str(OUT.resolve()),
        "train": "train/images",
        "val": "valid/images",
        "test": "test/images",
        "nc": len(unified_classes),
        "names": unified_classes,
    }
    with open(OUT / "data.yaml", "w") as f:
        yaml.dump(data_yaml, f, default_flow_style=False, sort_keys=False)

    print(f"\nMerged dataset written to: {OUT}")
    print(f"data.yaml classes: {unified_classes}")


if __name__ == "__main__":
    main()
