# Offline human evaluation webpage (Noise & Ringing)

Research-only UI for independent ratings of `NR001`–`NR015`.

## Startup (required for reliable local images)

Serve the parent `noise_ringing_validation/` folder so both `eval_web/` and `images/` are reachable:

```powershell
cd c:\Users\Dell\Desktop\access_mobile
access_backend\venv312\Scripts\python.exe -m http.server 8766 --bind 127.0.0.1 --directory tools\quality_validation\noise_ringing_validation
```

Open:

**http://127.0.0.1:8766/eval_web/**

Images load from `http://127.0.0.1:8766/images/NR001.jpg` (and NR002–NR015).

Stop with Ctrl+C.

## Privacy between evaluators

Use a **separate browser profile** or device for each of R1, R2, and R3.  
`localStorage` is per-origin and per-profile; it is not secure isolation on a shared profile.

## Features

- One image at a time with Fit / 100% / 200% zoom and pan
- Independent R1/R2/R3 sessions
- Autosave + resume
- Export CSV only when all 15 images have both Noise and Ringing scores
- No machine scores, strata, or facilitator collection notes

## Export

Downloads `R1_noise_ringing_ratings.csv` (or R2/R3) with columns matching the existing rating templates.

## Tests

```powershell
cd c:\Users\Dell\Desktop\access_mobile
access_backend\venv312\Scripts\python.exe -m pytest tools\quality_validation\noise_ringing_validation\eval_web\tests\ -v
```
