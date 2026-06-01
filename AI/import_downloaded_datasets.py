"""
Extract YOLO datasets from a folder of .zip files, dedupe images by SHA-256, and
copy into AI/datasets/new_raw/ for merge_all_datasets.py.

Does NOT train. Safe to re-run (skips already-imported hashes).

Usage:
  python AI/import_downloaded_datasets.py "C:\\Users\\...\\Food dataset"
  python AI/import_downloaded_datasets.py   # default path below
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import sys
import zipfile
from pathlib import Path

AI_DIR = Path(__file__).resolve().parent
DEFAULT_SOURCE = Path(r"C:\Users\RegiTes\Downloads\Compressed\Food dataset")
STAGING = AI_DIR / "datasets" / "_zip_staging"
OUT_ROOT = AI_DIR / "datasets" / "new_raw"
HASH_INDEX = AI_DIR / "datasets" / "dedupe_index.json"
REPORT_PATH = AI_DIR / "datasets" / "import_report.json"

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            block = f.read(chunk)
            if not block:
                break
            h.update(block)
    return h.hexdigest()


def safe_name(name: str) -> str:
    return re.sub(r"[^\w.\-]+", "_", name).strip("_") or "archive"


def extract_zip(zip_path: Path, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(dest)


def find_yolo_roots(root: Path) -> list[Path]:
    """Directories that look like a YOLOv8 export (data.yaml + train|valid|test)."""
    found: list[Path] = []
    for data_yaml in root.rglob("data.yaml"):
        parent = data_yaml.parent
        if any((parent / split / "images").is_dir() for split in ("train", "valid", "test")):
            found.append(parent)
    return found


def load_hash_index() -> dict[str, str]:
    if not HASH_INDEX.exists():
        return {}
    try:
        return json.loads(HASH_INDEX.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def save_hash_index(index: dict[str, str]) -> None:
    HASH_INDEX.parent.mkdir(parents=True, exist_ok=True)
    HASH_INDEX.write_text(json.dumps(index, indent=2), encoding="utf-8")


def copy_yolo_dataset(
    ds_root: Path,
    out_name: str,
    hash_index: dict[str, str],
    stats: dict,
) -> None:
    """Copy train/valid/test images+labels; skip duplicate image hashes."""
    out_ds = OUT_ROOT / out_name
    for split in ("train", "valid", "test"):
        img_dir = ds_root / split / "images"
        lbl_dir = ds_root / split / "labels"
        if not img_dir.is_dir():
            continue

        out_img = out_ds / split / "images"
        out_lbl = out_ds / split / "labels"
        out_img.mkdir(parents=True, exist_ok=True)
        out_lbl.mkdir(parents=True, exist_ok=True)

        for img in sorted(img_dir.iterdir()):
            if not img.is_file() or img.suffix.lower() not in IMAGE_EXTS:
                continue

            digest = sha256_file(img)
            stats["images_seen"] += 1

            if digest in hash_index:
                stats["duplicates_skipped"] += 1
                continue

            prefix = f"{out_name}_{digest[:12]}"
            unique_name = f"{prefix}{img.suffix.lower()}"
            dst_img = out_img / unique_name
            dst_lbl = out_lbl / f"{prefix}.txt"

            shutil.copy2(img, dst_img)
            lbl = lbl_dir / f"{img.stem}.txt"
            if lbl.exists():
                shutil.copy2(lbl, dst_lbl)
            else:
                dst_lbl.write_text("", encoding="utf-8")

            hash_index[digest] = str(dst_img.relative_to(OUT_ROOT))
            stats["images_copied"] += 1

    # Preserve data.yaml once per output dataset
    src_yaml = ds_root / "data.yaml"
    if src_yaml.exists() and not (out_ds / "data.yaml").exists():
        shutil.copy2(src_yaml, out_ds / "data.yaml")


def main() -> None:
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SOURCE
    if not source.is_dir():
        print(f"ERROR: source folder not found: {source}")
        sys.exit(1)

    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    STAGING.mkdir(parents=True, exist_ok=True)

    hash_index = load_hash_index()
    stats = {
        "zips_found": 0,
        "zips_extracted": 0,
        "yolo_roots_found": 0,
        "images_seen": 0,
        "images_copied": 0,
        "duplicates_skipped": 0,
        "datasets_out": [],
    }

    zips = sorted(source.glob("*.zip"))
    stats["zips_found"] = len(zips)
    print(f"Source: {source}")
    print(f"ZIP files: {len(zips)}")
    print(f"Output: {OUT_ROOT}\n")

    for zpath in zips:
        staging_name = safe_name(zpath.stem)
        staging_dir = STAGING / staging_name
        marker = staging_dir / ".extracted"

        print(f"--- {zpath.name} ({zpath.stat().st_size / 1e6:.1f} MB) ---")
        if not marker.exists():
            if staging_dir.exists():
                shutil.rmtree(staging_dir)
            staging_dir.mkdir(parents=True, exist_ok=True)
            print("  Extracting...")
            try:
                extract_zip(zpath, staging_dir)
                marker.write_text("ok", encoding="utf-8")
                stats["zips_extracted"] += 1
            except zipfile.BadZipFile as e:
                print(f"  SKIP bad zip: {e}")
                continue
        else:
            print("  Already extracted (staging)")

        roots = find_yolo_roots(staging_dir)
        if not roots:
            print("  No YOLO data.yaml roots found under staging")
            continue

        for i, root in enumerate(roots):
            out_name = staging_name if len(roots) == 1 else f"{staging_name}_{i}"
            # Avoid overwriting same out_name
            base = out_name
            n = 0
            while (OUT_ROOT / out_name).exists() and not (OUT_ROOT / out_name / "data.yaml").exists():
                n += 1
                out_name = f"{base}_{n}"

            print(f"  Importing YOLO root -> new_raw/{out_name}")
            copy_yolo_dataset(root, out_name, hash_index, stats)
            stats["yolo_roots_found"] += 1
            if out_name not in stats["datasets_out"]:
                stats["datasets_out"].append(out_name)

    save_hash_index(hash_index)
    REPORT_PATH.write_text(json.dumps(stats, indent=2), encoding="utf-8")

    print(f"\n{'=' * 50}")
    print(f"ZIPs extracted (this run): {stats['zips_extracted']}")
    print(f"YOLO roots imported: {stats['yolo_roots_found']}")
    print(f"Images seen: {stats['images_seen']}")
    print(f"Unique images copied: {stats['images_copied']}")
    print(f"Duplicates skipped: {stats['duplicates_skipped']}")
    print(f"Dedupe index: {HASH_INDEX}")
    print(f"Report: {REPORT_PATH}")
    print("Done. Training NOT started — run merge_all_datasets.py when ready.")


if __name__ == "__main__":
    main()
