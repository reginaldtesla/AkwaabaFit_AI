"""
Find image files that duplicate content already kept in new_raw (per dedupe_index.json),
write a report, and optionally delete them.

Safe canonical copies live under AI/datasets/new_raw/ only.

Usage:
  python AI/list_and_remove_duplicates.py              # report only
  python AI/list_and_remove_duplicates.py --delete     # delete reported files
  python AI/list_and_remove_duplicates.py --delete-staging  # remove entire _zip_staging
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

AI_DIR = Path(__file__).resolve().parent
HASH_INDEX = AI_DIR / "datasets" / "dedupe_index.json"
OUT_ROOT = AI_DIR / "datasets" / "new_raw"
STAGING = AI_DIR / "datasets" / "_zip_staging"
REPORT = AI_DIR / "datasets" / "duplicates_report.json"
DOWNLOADS = Path(r"C:\Users\RegiTes\Downloads\Compressed\Food dataset")

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


def load_index() -> dict[str, str]:
    if not HASH_INDEX.exists():
        print(f"Missing {HASH_INDEX} — run import_downloaded_datasets.py first.")
        sys.exit(1)
    return json.loads(HASH_INDEX.read_text(encoding="utf-8"))


def canonical_paths(index: dict[str, str]) -> set[Path]:
    return {(OUT_ROOT / rel).resolve() for rel in index.values()}


def scan_tree(root: Path, index: dict[str, str], keep: set[Path]) -> list[dict]:
    dupes: list[dict] = []
    if not root.is_dir():
        return dupes
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in IMAGE_EXTS:
            continue
        resolved = path.resolve()
        if resolved in keep:
            continue
        try:
            digest = sha256_file(path)
        except OSError as e:
            dupes.append({"path": str(path), "error": str(e)})
            continue
        if digest not in index:
            continue
        dupes.append(
            {
                "path": str(path),
                "sha256": digest,
                "kept_at": str(OUT_ROOT / index[digest]),
                "size_bytes": path.stat().st_size,
            }
        )
    return dupes


def delete_files(entries: list[dict]) -> tuple[int, int]:
    deleted = 0
    bytes_freed = 0
    for entry in entries:
        if "error" in entry:
            continue
        p = Path(entry["path"])
        if not p.is_file():
            continue
        size = p.stat().st_size
        p.unlink()
        bytes_freed += size
        deleted += 1
        lbl = p.parent.parent / "labels" / f"{p.stem}.txt"
        if lbl.is_file():
            lbl.unlink()
    return deleted, bytes_freed


def zip_duplicates(folder: Path) -> list[dict]:
    """Identical ZIP archives (same SHA-256) in the downloads folder."""
    by_hash: dict[str, list[Path]] = {}
    if not folder.is_dir():
        return []
    for z in sorted(folder.glob("*.zip")):
        try:
            h = sha256_file(z)
        except OSError:
            continue
        by_hash.setdefault(h, []).append(z)
    groups = []
    for h, paths in by_hash.items():
        if len(paths) < 2:
            continue
        keep = paths[0]
        for extra in paths[1:]:
            groups.append(
                {
                    "path": str(extra),
                    "sha256": h,
                    "kept_at": str(keep),
                    "size_bytes": extra.stat().st_size,
                    "type": "zip_archive",
                }
            )
    return groups


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--delete", action="store_true", help="Delete duplicate image files")
    parser.add_argument(
        "--delete-staging",
        action="store_true",
        help="Remove entire AI/datasets/_zip_staging tree",
    )
    parser.add_argument("--delete-zip-dupes", action="store_true", help="Delete duplicate ZIP files in Downloads")
    args = parser.parse_args()

    index = load_index()
    keep = canonical_paths(index)

    image_dupes = scan_tree(STAGING, index, keep)
    zip_dupes = zip_duplicates(DOWNLOADS)

    report = {
        "canonical_images_in_new_raw": len(index),
        "duplicate_images_in_staging": len(image_dupes),
        "duplicate_zip_archives_in_downloads": len(zip_dupes),
        "staging_duplicate_bytes": sum(e.get("size_bytes", 0) for e in image_dupes),
        "zip_duplicate_bytes": sum(e.get("size_bytes", 0) for e in zip_dupes),
        "image_duplicates": image_dupes,
        "zip_duplicates": zip_dupes,
    }
    REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")

    print(f"Canonical unique images (new_raw): {len(index)}")
    print(f"Duplicate images in staging: {len(image_dupes)}")
    print(f"  (~{report['staging_duplicate_bytes'] / 1e9:.2f} GB)")
    print(f"Identical ZIP files in Downloads: {len(zip_dupes)}")
    if zip_dupes:
        print(f"  (~{report['zip_duplicate_bytes'] / 1e9:.2f} GB)")
    print(f"Full list: {REPORT}")

    if args.delete and image_dupes:
        n, freed = delete_files(image_dupes)
        print(f"Deleted {n} duplicate images from staging ({freed / 1e9:.2f} GB)")

    if args.delete_zip_dupes and zip_dupes:
        n = 0
        freed = 0
        for entry in zip_dupes:
            p = Path(entry["path"])
            if p.is_file():
                freed += p.stat().st_size
                p.unlink()
                n += 1
        print(f"Deleted {n} duplicate ZIP(s) from Downloads ({freed / 1e9:.2f} GB)")

    if args.delete_staging and STAGING.is_dir():
        import shutil

        size = sum(f.stat().st_size for f in STAGING.rglob("*") if f.is_file())
        shutil.rmtree(STAGING)
        print(f"Removed staging folder ({size / 1e9:.2f} GB): {STAGING}")

    if not any([args.delete, args.delete_staging, args.delete_zip_dupes]):
        print("\nRe-run with --delete (staging images), --delete-zip-dupes, and/or --delete-staging to remove.")


if __name__ == "__main__":
    main()
