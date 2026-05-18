"""
Auto-restart training loop.
Keeps resuming from checkpoint whenever training crashes.
Just run this and leave it — it handles everything.

Usage:
  python AI/train_loop.py
"""
import subprocess
import sys
import time
from pathlib import Path

AI_DIR = Path(__file__).resolve().parent
TRAIN_SCRIPT = str(AI_DIR / "train.py")
PYTHON = sys.executable
RESULTS_CSV = AI_DIR / "runs" / "detect" / "food_model_v2" / "results.csv"
MAX_RETRIES = 200

def get_last_epoch():
    if not RESULTS_CSV.exists():
        return 0
    lines = RESULTS_CSV.read_text().strip().split("\n")
    if len(lines) < 2:
        return 0
    try:
        return int(lines[-1].split(",")[0])
    except (ValueError, IndexError):
        return 0

def main():
    print("=" * 60)
    print("AUTO-RESTART TRAINING LOOP")
    print("This will keep resuming training after each crash.")
    print("Press Ctrl+C to stop.")
    print("=" * 60)

    for attempt in range(1, MAX_RETRIES + 1):
        epoch_before = get_last_epoch()
        print(f"\n--- Attempt {attempt} | Starting from epoch {epoch_before} ---")

        result = subprocess.run(
            [PYTHON, TRAIN_SCRIPT],
            cwd=str(AI_DIR),
        )

        epoch_after = get_last_epoch()

        if result.returncode == 0:
            print("\n" + "=" * 60)
            print("TRAINING COMPLETED SUCCESSFULLY!")
            print("=" * 60)
            break

        if epoch_after > epoch_before:
            print(f"\n  Crashed but made progress: epoch {epoch_before} -> {epoch_after}")
        else:
            print(f"\n  Crashed with no progress (still epoch {epoch_after})")

        print("  Waiting 10 seconds before restart...")
        time.sleep(10)

    print(f"\nFinal epoch: {get_last_epoch()}")


if __name__ == "__main__":
    main()
