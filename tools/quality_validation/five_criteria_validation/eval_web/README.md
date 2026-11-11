# Offline human evaluation webpage — Five Classical criteria

Research-only UI for independent ratings of planned IDs `FC001`–`FC040`.  
**Separate copy** of the Noise/Ringing eval_web pattern. Does **not** modify the NR study.

Images are empty until collection is approved.

## Startup (after images exist)

Serve the parent `five_criteria_validation/` folder:

```powershell
cd c:\Users\Dell\Desktop\access_mobile
access_backend\venv312\Scripts\python.exe -m http.server 8767 --bind 127.0.0.1 --directory tools\quality_validation\five_criteria_validation
```

Open **http://127.0.0.1:8767/eval_web/**

Use port **8767** (or any free port) so it does not collide with an NR eval server on 8766.

## Privacy

Use a **separate browser profile** or device for each of R1, R2, and R3.

## Features

- Fit / 100% / 200% zoom + pan  
- Five required criteria: Sharpness, Blur, Brightness, Contrast, Blocking  
- Autosave + resume + CSV export when complete  
- No machine scores or stratum tags  

## Export

Downloads `R#_five_criteria_ratings.csv` matching the human rating template columns.
