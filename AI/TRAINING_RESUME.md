# Food model training — paused until 2 June 2026

Training was **stopped** on 2026-05-27. Partial progress (if any) is in:

- `runs/detect/food_model_v2/weights/` (`last.pt`, `last_resumable.pt`)
- `runs/detect/food_model_v2/results.csv`

## Start on **Tuesday, 2 June 2026**

**Option A — manual (recommended)**

1. Plug in laptop, disable sleep.
2. Open PowerShell:

```powershell
cd C:\Apache24\htdocs\AkwaabaFitAIProject\AI
.\start_training.ps1
```

**Option B — Windows Task Scheduler**

Run once (Admin PowerShell if prompted):

```powershell
cd C:\Apache24\htdocs\AkwaabaFitAIProject\AI
.\register_training_schedule.ps1
```

Default start: **2 June 2026, 08:00** local time.

## Expected duration

~**3–4 days** continuous GPU time for 200 epochs (RTX 4050, ~17.5k images).

## When finished

```powershell
.\venv\Scripts\python.exe train.py finalize
```
