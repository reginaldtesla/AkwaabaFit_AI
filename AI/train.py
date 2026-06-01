"""
Train YOLOv8n (nano) on the merged v2 food dataset.

Usage:
  python AI/train.py              # fresh or resume (full 200 epochs unless chunked)
  python AI/train.py finalize     # val + ONNX export from best.pt (after training done)

Chunked laptop runs (clean exit, then auto-resume via train_loop.ps1):
  set AKWAABA_CHUNK_EPOCHS=5      # each process trains at most 5 epoch indices then exits
"""
from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path
import gc
import torch
from ultralytics import YOLO
from ultralytics.utils import RANK

torch.backends.cudnn.benchmark = False
# Avoid rare Windows validation hangs / internal errors on some laptop drivers.
torch.backends.cudnn.enabled = False

AI_DIR = Path(__file__).resolve().parent
HARDWARE_PROFILE = AI_DIR / "hardware_profile.json"
DATA_YAML = AI_DIR / "datasets" / "merged_v2" / "data.yaml"
PROJECT = str(AI_DIR / "runs" / "detect")
NAME = "food_model_v2"


def _hw_training_defaults() -> dict:
    """Values from hardware_profile.json (Regi laptop: RTX 4050 6GB, 16GB RAM)."""
    if not HARDWARE_PROFILE.exists():
        return {}
    try:
        data = json.loads(HARDWARE_PROFILE.read_text(encoding="utf-8"))
        return data.get("training") or {}
    except (json.JSONDecodeError, OSError):
        return {}


_HW = _hw_training_defaults()

EPOCHS = int(_HW.get("epochs", 200))
IMG_SIZE = int(os.environ.get("AKWAABA_IMG_SIZE", str(_HW.get("imgsz", 416))))
# RTX 4050 6GB: batch=2 for yolov8n@416; use AKWAABA_BATCH=1 if OOM
BATCH = int(os.environ.get("AKWAABA_BATCH", str(_HW.get("batch", 2))))
# 16GB RAM + Windows: workers>0 often spikes RAM during DataLoader spawn
WORKERS = int(os.environ.get("AKWAABA_WORKERS", str(_HW.get("workers", 0))))
FRACTION = float(os.environ.get("AKWAABA_FRACTION", str(_HW.get("fraction", 1.0))))
# disk cache: fast repeat epochs without filling 16GB RAM (needs free disk on C:)
_CACHE = os.environ.get("AKWAABA_CACHE", str(_HW.get("cache", "disk")))

# Each Python process trains at most this many epoch steps when resuming (0 = disabled).
# Set via train_env.ps1 / train_loop.ps1 (recommended 5 on this laptop). Default off for one-shot train.py.
_CHUNK = int(os.environ.get("AKWAABA_CHUNK_EPOCHS", "0"))
# Drop optimizer/scaler from last.pt before resume (fixes recurring cuBLAS backward crashes on this laptop).
_FRESH_OPTIMIZER = os.environ.get("AKWAABA_FRESH_OPTIMIZER", "1") != "0"
# Set AKWAABA_DEVICE=cpu if GPU keeps failing after a reboot (slow but stable).
_DEVICE = os.environ.get("AKWAABA_DEVICE", str(_HW.get("device", "0")))

# Low-RAM / small-GPU laptop defaults (must match on resume or checkpoint restores batch=4 + mosaic).
_TRAIN_OVERRIDES = dict(
    workers=WORKERS,
    batch=BATCH,
    mosaic=0.0,
    amp=False,
    plots=False,
    deterministic=False,
    val=False,
    device=_DEVICE,
    cache=_CACHE if _CACHE not in ("0", "false", "False", "") else False,
)


def _is_resumable_checkpoint(pt: Path) -> bool:
    if not pt.exists():
        return False
    ckpt = torch.load(pt, map_location="cpu", weights_only=False)
    return int(ckpt.get("epoch", -1)) >= 0 and ckpt.get("optimizer") is not None


def _resume_checkpoint_path(weights_dir: Path) -> Path | None:
    """Prefer last_resumable.pt — Ultralytics final_eval strips optimizer from last.pt after each run."""
    last_pt = weights_dir / "last.pt"
    resumable = weights_dir / "last_resumable.pt"
    if resumable.exists() and _is_resumable_checkpoint(resumable):
        return resumable
    if last_pt.exists() and _is_resumable_checkpoint(last_pt):
        return last_pt
    return last_pt if last_pt.exists() else None


def _warn_if_not_resumable(pt: Path) -> None:
    if _is_resumable_checkpoint(pt):
        return
    print(
        "  [checkpoint] WARNING: checkpoint is not resumable (epoch/optimizer stripped after last run). "
        "Ultralytics will show 1/200 but still load model weights from the file. "
        "Chunk restarts will resume correctly after this fix once a full epoch is saved.",
        flush=True,
    )


def _sanitize_checkpoint(last_pt: Path) -> None:
    """Drop only GradScaler state. Keep optimizer — removing it forces Ultralytics to start at 1/200."""
    if not _FRESH_OPTIMIZER or not last_pt.exists():
        return
    ckpt = torch.load(last_pt, map_location="cpu", weights_only=False)
    if ckpt.get("scaler") is None:
        return
    ckpt["scaler"] = None
    torch.save(ckpt, last_pt)
    print(f"  [checkpoint] Cleared scaler in {last_pt.name} (optimizer kept for resume)", flush=True)


def _force_laptop_train_args(trainer):
    """Ultralytics resume restores train_args from last.pt and only merges a small allowlist.

    Must force data/project/name/epochs here — otherwise resume can fall back to coco8.yaml and wrong totals.
    """
    trainer.args.data = str(DATA_YAML)
    trainer.args.project = PROJECT
    trainer.args.name = NAME
    trainer.args.exist_ok = True
    trainer.args.epochs = EPOCHS
    trainer.args.fraction = FRACTION
    trainer.args.imgsz = IMG_SIZE
    trainer.args.batch = BATCH
    trainer.args.workers = WORKERS
    trainer.args.amp = False
    trainer.args.deterministic = False
    trainer.args.val = False
    trainer.args.device = _DEVICE
    if _CACHE not in ("0", "false", "False", ""):
        trainer.args.cache = _CACHE
    if hasattr(trainer.args, "mosaic"):
        trainer.args.mosaic = 0.0


def _stabilize_gpu_trainer(trainer):
    """Fresh disabled GradScaler + CUDA sync after resume (stale scaler/optimizer GPU state causes cuBLAS failures)."""
    trainer.amp = False
    trainer.scaler = (
        torch.amp.GradScaler("cuda", enabled=False)
        if hasattr(torch.amp, "GradScaler")
        else torch.cuda.amp.GradScaler(enabled=False)
    )
    if trainer.device.type == "cuda":
        torch.cuda.empty_cache()
        torch.cuda.synchronize()
    print("  [gpu] amp=False, GradScaler reset, CUDA cache cleared", flush=True)


def save_last_after_train(trainer):
    """Write last.pt after the train loop, before validation (default Ultralytics save is after val)."""
    if RANK not in {-1, 0}:
        return
    if not (trainer.args.save or trainer.epoch + 1 >= trainer.epochs):
        return
    print(f"\n  [checkpoint] Saving last.pt after train (epoch {trainer.epoch + 1})...", flush=True)
    if trainer.save_model():
        trainer.run_callbacks("on_model_save")
        if _CHUNK > 0:
            src = Path(trainer.last)
            shutil.copy2(src, src.parent / "last_resumable.pt")
    print("  [checkpoint] Done.", flush=True)


def _patch_skip_final_eval_when_chunked() -> None:
    """Ultralytics final_eval() strips optimizer and sets epoch=-1, which breaks train_loop resume."""
    if _CHUNK <= 0:
        return
    from ultralytics.engine.trainer import BaseTrainer

    if getattr(BaseTrainer, "_akwaaba_skip_final_eval", False):
        return

    def _skip_final_eval(self):
        print(
            "  [chunk] Skipping final_eval (no optimizer strip / no end-of-run val) so next chunk can resume.",
            flush=True,
        )

    BaseTrainer.final_eval = _skip_final_eval
    BaseTrainer._akwaaba_skip_final_eval = True


def flush_gpu(trainer):
    """Release leaked CUDA memory after every epoch."""
    gc.collect()
    torch.cuda.empty_cache()
    torch.cuda.ipc_collect()
    used = torch.cuda.memory_reserved() / 1e9
    print(f"  [GPU cleanup] reserved={used:.3f} GB")


def _stop_after_chunk_epochs(trainer):
    """Exit cleanly after N epochs — do NOT pass epochs=cap to train() (that breaks totals and dataset)."""
    if _CHUNK <= 0:
        return
    if trainer.epoch + 1 >= trainer.start_epoch + _CHUNK:
        trainer.stop = True
        print(
            f"  [chunk] stopping after {_CHUNK} epochs (completed epoch {trainer.epoch + 1}/{EPOCHS})",
            flush=True,
        )


def _checkpoint_epoch(last_pt: Path) -> int:
    if not last_pt.exists():
        return -1
    return int(torch.load(last_pt, map_location="cpu", weights_only=False).get("epoch", -1))


def _training_complete(pt: Path | None) -> bool:
    """True when all EPOCHS are done (checkpoint epoch is 0-based: 199 => 200/200)."""
    if pt is None or not pt.exists():
        return False
    return _checkpoint_epoch(pt) + 1 >= EPOCHS


def _train_kwargs(*, resume: bool) -> dict:
    kw = dict(
        data=str(DATA_YAML),
        epochs=EPOCHS,
        imgsz=IMG_SIZE,
        project=PROJECT,
        name=NAME,
        exist_ok=True,
        patience=30,
        fraction=FRACTION,
        **_TRAIN_OVERRIDES,
    )
    if resume:
        kw["resume"] = True
    return kw


def _register_callbacks(model: YOLO) -> None:
    model.add_callback("on_pretrain_routine_start", _force_laptop_train_args)
    model.add_callback("on_train_start", _stabilize_gpu_trainer)
    model.add_callback("on_train_epoch_end", save_last_after_train)
    model.add_callback("on_train_epoch_end", _stop_after_chunk_epochs)
    model.add_callback("on_train_epoch_end", flush_gpu)
    model.add_callback("on_val_end", flush_gpu)


def finalize_only() -> None:
    best_pt = Path(PROJECT) / NAME / "weights" / "best.pt"
    if not best_pt.exists():
        print(f"ERROR: {best_pt} not found. Train first.")
        return
    best_model = YOLO(str(best_pt))
    metrics = best_model.val(data=str(DATA_YAML), imgsz=IMG_SIZE)
    print(f"\nmAP50: {metrics.box.map50:.4f}")
    print(f"mAP50-95: {metrics.box.map:.4f}")
    best_model.export(format="onnx", imgsz=IMG_SIZE, opset=12, simplify=True)
    print(f"\nONNX model exported alongside best.pt (opset 12 for mobile onnxruntime)")
    print("Done!")


def main() -> None:
    if not DATA_YAML.exists():
        print("ERROR: merged data.yaml not found. Run merge_all_datasets.py first.")
        return

    if torch.cuda.is_available():
        torch.cuda.empty_cache()
        torch.cuda.synchronize()

    if HARDWARE_PROFILE.exists():
        print(f"Hardware profile: {HARDWARE_PROFILE.name}", flush=True)
    print(
        f"Speed settings: batch={BATCH}, workers={WORKERS}, imgsz={IMG_SIZE}, "
        f"fraction={FRACTION}, cache={_TRAIN_OVERRIDES.get('cache', False)}, "
        f"device={_DEVICE}, chunk_epochs={_CHUNK or 'off'}",
        flush=True,
    )

    weights_dir = Path(PROJECT) / NAME / "weights"
    last_pt = weights_dir / "last.pt"
    resume_pt = _resume_checkpoint_path(weights_dir)

    if resume_pt is not None and _training_complete(resume_pt):
        print(f"Training already complete ({EPOCHS}/{EPOCHS} epochs). Running finalize...", flush=True)
        finalize_only()
        return

    if resume_pt is not None:
        _warn_if_not_resumable(resume_pt)
        _sanitize_checkpoint(resume_pt)
        if resume_pt != last_pt and _is_resumable_checkpoint(resume_pt):
            shutil.copy2(resume_pt, last_pt)
        ep = _checkpoint_epoch(resume_pt) + 1
        print(f"Resuming from checkpoint: {resume_pt} (device={_DEVICE}, at epoch {ep}/{EPOCHS})")
        if _CHUNK > 0:
            print(f"  Chunk mode: up to {_CHUNK} epochs this run, then train_loop restarts.", flush=True)
        _patch_skip_final_eval_when_chunked()
        model = YOLO(str(last_pt))
        _register_callbacks(model)
        model.train(**_train_kwargs(resume=_is_resumable_checkpoint(last_pt)))
    else:
        print("Starting fresh training...")
        _patch_skip_final_eval_when_chunked()
        model = YOLO("yolov8n.pt")
        _register_callbacks(model)
        model.train(**_train_kwargs(resume=False))

    # Mid-course chunk exit: skip slow full val/export until all 200 epochs are done.
    if _CHUNK > 0 and _checkpoint_epoch(last_pt) + 1 < EPOCHS:
        print(
            "\nChunk mode: skipped automatic full val/export on this exit. "
            "When training is finished, run: python train.py finalize",
            flush=True,
        )
        return

    best_pt = Path(PROJECT) / NAME / "weights" / "best.pt"
    best_model = YOLO(str(best_pt))
    metrics = best_model.val(data=str(DATA_YAML), imgsz=IMG_SIZE)
    print(f"\nmAP50: {metrics.box.map50:.4f}")
    print(f"mAP50-95: {metrics.box.map:.4f}")

    best_model.export(format="onnx", imgsz=IMG_SIZE, opset=12, simplify=True)
    print(f"\nONNX model exported alongside best.pt (opset 12 for mobile onnxruntime)")
    print("Done!")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1].lower() == "finalize":
        finalize_only()
    else:
        main()
