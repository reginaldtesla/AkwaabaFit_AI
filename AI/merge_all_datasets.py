"""
Merge all YOLO datasets (original + new) into one unified training set.
Normalises class names, deduplicates, and creates train/valid/test splits.
"""
import random
import shutil
import yaml
import re
from pathlib import Path
from collections import defaultdict

AI_DIR = Path(__file__).resolve().parent
MERGED = AI_DIR / "datasets" / "merged_v2"

# ---------- datasets to include (new_raw only; bad sets removed — see excluded_from_training.json) ----------
NEW_RAW = AI_DIR / "datasets" / "new_raw"
DATASETS = {
    "ghanaian": NEW_RAW / "Ghanaian_food.yolov8",
    "food_base": NEW_RAW / "food.yolov8",
    "food_dataset": NEW_RAW / "Food_Dataset.yolov8",
    "food_dataset_2": NEW_RAW / "Food_Dataset.yolov8_2",
    "food_v2": NEW_RAW / "Food.yolov8_2",
    "food_v3": NEW_RAW / "food.yolov8_3",
    "food_v5": NEW_RAW / "Food.yolov8_5",
    "food_v6": NEW_RAW / "food.yolov8_6",
    "food_v7": NEW_RAW / "food.yolov8_7",
}

# Reject corrupted Roboflow exports (readme lines saved as class names).
_BAD_CLASS_MARKERS = (
    "roboflow",
    "auto-orientation",
    "visit https",
    "computer vision",
    "dataset was exported",
)

# ---------- class normalisation map ----------
# Maps raw class names (lowercased) to a unified label.
# Unmapped classes keep their lowercased, cleaned name.
CLASS_MAP = {
    # Ghanaian
    "banku": "banku", "fufu": "fufu", "jollof_rice": "jollof_rice",
    "jollof": "jollof", "jollof_rice": "jollof", "jollof rice": "jollof",
    "waakye": "waakye", "kenkey": "kenkey",
    "egg-and-pepper": "egg_pepper", "egg and pepper": "egg_pepper",
    "plain-rice": "rice", "plain rice": "rice",
    "hausa-koko": "hausa_koko", "nkate-cake": "nkate_cake", "kokonte": "kokonte",
    "koose": "koose",
    "kelewele": "kelewele", "gari": "gari", "shito": "shito",
    "groundnut_soup": "groundnut_soup", "groundnut soup": "groundnut_soup",
    "palm_nut_soup": "palm_nut_soup", "palm nut soup": "palm_nut_soup",
    "rice_ball": "rice_ball", "rice ball": "rice_ball",
    "rice_water": "rice_water", "rice water": "rice_water",
    "stew": "stew", "yam": "yam", "plantain": "plantain",

    # Proteins
    "chicken": "chicken", "chicken_meat": "chicken", "chicken leg - v1 2024-05-09 1-55am": "chicken",
    "fried chicken": "fried_chicken", "roast chicken": "roast_chicken",
    "boiled chicken and vegetables": "chicken",
    "beef": "beef", "beef steak": "beef_steak", "cooked_meat": "meat", "meat": "meat",
    "fish": "fish", "fried fish": "fried_fish", "salmon": "salmon",
    "sausage": "sausage", "egg": "egg", "egg sunny-side up": "egg",
    "egg roll": "egg_roll",

    # Carbs / grains
    "rice": "rice", "fried rice": "fried_rice", "fried-rice": "fried_rice",
    "pilaf": "fried_rice",
    "bread": "bread", "raisin-bread": "bread", "raisin bread": "bread",
    "roll-bread": "bread", "roll bread": "bread", "toast": "toast",
    "croissant": "croissant",
    "pasta": "pasta", "spaghetti": "pasta",
    "noodles": "noodles", "fried-noodle": "fried_noodles", "fried noodle": "fried_noodles",
    "fried-rice": "fried_rice",
    "ramen-noodle": "ramen", "ramen noodle": "ramen",
    "soba-noodle": "soba", "udon-noodle": "udon",
    "beef-noodle": "noodles", "tensin-noodle": "noodles",

    # Western fast food
    "hamburger": "burger", "burger": "burger",
    "pizza": "pizza", "hot dog": "hot_dog",
    "french fries": "french_fries", "french-fries": "french_fries",
    "chip-butty": "french_fries",
    "sandwiches": "sandwich", "sandwich": "sandwich",
    "croquette": "croquette",

    # Asian dishes
    "sushi": "sushi", "bibimbap": "bibimbap",
    "takoyaki": "takoyaki",
    "tempura-bowl": "tempura", "tempura bowl": "tempura",
    "tempura-udon": "tempura",
    "beef-curry": "curry", "beef curry": "curry",
    "chicken-n-egg-on-rice": "chicken_rice",
    "chicken-rice": "chicken_rice", "chicken rice": "chicken_rice",
    "eels-on-rice": "rice", "pork-cutlet-on-rice": "rice",
    "gratin": "gratin",
    "japanese-style-pancake": "pancake",

    # Salads / soups
    "salad": "salad", "green salad": "salad", "potato salad": "salad",
    "macaroni salad": "salad",
    "miso soup": "soup", "chinese soup": "soup",
    "japanese tofu and vegetable chowder": "soup",

    # Fruits
    "apple": "apple", "orange": "orange", "banana": "banana",
    "avocado": "avocado", "grapes": "grapes", "strawberries": "strawberries",
    "lemon": "lemon",

    # Vegetables
    "potato": "potato", "tomato": "tomato", "carrot": "carrot",
    "broccoli": "broccoli", "cucumber": "cucumber",
    "lettuce": "lettuce", "peas": "peas",
    "beans": "beans",
    "mixed vegetables": "vegetables", "veggies": "vegetables",
    "grilled eggplant": "vegetables", "sauteed spinach": "vegetables",
    "seaweed": "seaweed",

    # Dairy
    "cheese": "cheese",

    # Misc
    "tacos": "tacos",
    "sauteed spinach": "vegetables",
}


def normalise(name: str) -> str:
    key = name.strip().lower()
    if key in CLASS_MAP:
        return CLASS_MAP[key]
    cleaned = re.sub(r"[^a-z0-9]+", "_", key).strip("_")
    return cleaned


def load_yaml_classes(yaml_path: Path) -> list[str]:
    with open(yaml_path, encoding="utf-8") as f:
        data = yaml.safe_load(f)
    return data.get("names", [])


def dataset_is_trainable(ds_root: Path) -> bool:
    yaml_path = ds_root / "data.yaml"
    if not yaml_path.exists():
        return False
    names = load_yaml_classes(yaml_path)
    if not names:
        return False
    joined = " ".join(str(n).lower() for n in names)
    if any(m in joined for m in _BAD_CLASS_MARKERS):
        return False
    train_imgs = ds_root / "train" / "images"
    if train_imgs.is_dir() and any(train_imgs.iterdir()):
        return True
    for split in ("valid", "test"):
        d = ds_root / split / "images"
        if d.is_dir() and any(d.iterdir()):
            return True
    return False


def process_dataset(ds_name, ds_root, unified_names, name_to_id, split_counts):
    yaml_path = ds_root / "data.yaml"
    if not yaml_path.exists():
        print(f"  SKIP {ds_name}: no data.yaml")
        return

    raw_names = load_yaml_classes(yaml_path)
    old_to_new = {}
    for i, raw in enumerate(raw_names):
        normed = normalise(raw)
        if normed not in name_to_id:
            name_to_id[normed] = len(unified_names)
            unified_names.append(normed)
        old_to_new[i] = name_to_id[normed]

    for split in ("train", "valid", "test"):
        img_dir = ds_root / split / "images"
        lbl_dir = ds_root / split / "labels"
        if not img_dir.exists():
            continue

        out_img = MERGED / split / "images"
        out_lbl = MERGED / split / "labels"
        out_img.mkdir(parents=True, exist_ok=True)
        out_lbl.mkdir(parents=True, exist_ok=True)

        count = 0
        for img in img_dir.iterdir():
            if img.suffix.lower() not in (".jpg", ".jpeg", ".png", ".bmp", ".webp"):
                continue

            lbl = lbl_dir / (img.stem + ".txt")
            unique = f"{ds_name}_{img.name}"
            dst_img = out_img / unique
            dst_lbl = out_lbl / (f"{ds_name}_{img.stem}.txt")

            if dst_img.exists():
                continue

            shutil.copy2(img, dst_img)

            if lbl.exists():
                new_lines = []
                with open(lbl, encoding="utf-8") as f:
                    for line in f:
                        parts = line.strip().split()
                        if len(parts) < 5:
                            continue
                        old_id = int(parts[0])
                        if old_id in old_to_new:
                            parts[0] = str(old_to_new[old_id])
                            new_lines.append(" ".join(parts[:5]))
                with open(dst_lbl, "w", encoding="utf-8") as f:
                    f.write("\n".join(new_lines) + "\n" if new_lines else "")
            else:
                dst_lbl.write_text("")

            count += 1

        split_counts[split] += count
        if count:
            print(f"  {ds_name}/{split}: {count} images")


def main():
    if MERGED.exists():
        shutil.rmtree(MERGED)

    unified_names: list[str] = []
    name_to_id: dict[str, int] = {}
    split_counts = defaultdict(int)

    for ds_name, ds_root in DATASETS.items():
        if not ds_root.is_dir():
            print(f"  SKIP {ds_name}: missing {ds_root}")
            continue
        if not dataset_is_trainable(ds_root):
            print(f"  SKIP {ds_name}: not trainable (empty or bad labels)")
            continue
        print(f"Processing {ds_name} ...")
        process_dataset(ds_name, ds_root, unified_names, name_to_id, split_counts)

    data_yaml = {
        "path": str(MERGED),
        "train": "train/images",
        "val": "valid/images",
        "test": "test/images",
        "nc": len(unified_names),
        "names": unified_names,
    }
    with open(MERGED / "data.yaml", "w", encoding="utf-8") as f:
        yaml.dump(data_yaml, f, default_flow_style=False)

    print(f"\n{'='*50}")
    print(f"Unified classes: {len(unified_names)}")
    for i, n in enumerate(unified_names):
        print(f"  {i:3d}: {n}")
    print(f"\nImages: train={split_counts['train']}, "
          f"valid={split_counts['valid']}, test={split_counts['test']}, "
          f"total={sum(split_counts.values())}")
    print(f"Output: {MERGED}")
    _hold_out_valid_split()
    print("Done!")


def _hold_out_valid_split(val_fraction: float = 0.1, min_val: int = 500) -> None:
    """Ultralytics requires valid/images; hold out from train after merge."""
    train_img = MERGED / "train" / "images"
    train_lbl = MERGED / "train" / "labels"
    valid_img = MERGED / "valid" / "images"
    valid_lbl = MERGED / "valid" / "labels"
    valid_img.mkdir(parents=True, exist_ok=True)
    valid_lbl.mkdir(parents=True, exist_ok=True)

    images = [p for p in train_img.iterdir() if p.is_file()]
    n_val = max(min_val, int(len(images) * val_fraction))
    random.seed(42)
    picked = set(random.sample(images, min(n_val, len(images))))
    for img in picked:
        dst = valid_img / img.name
        if dst.exists():
            continue
        shutil.move(img, dst)
        lbl = train_lbl / f"{img.stem}.txt"
        if lbl.is_file():
            shutil.move(lbl, valid_lbl / lbl.name)
    print(f"Valid hold-out: {len(list(valid_img.iterdir()))} images")


if __name__ == "__main__":
    main()
