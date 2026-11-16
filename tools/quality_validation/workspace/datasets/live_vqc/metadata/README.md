# LIVE-VQC metadata (place official files here)

Official study: 585 unique videos, crowdsourced MOS.

Download page: https://live.ece.utexas.edu/research/LIVEVQC/  
(also listed from https://www.colorado.edu/lab/live/live-video-quality-challenge-vqc-database)

Literature describes MOS on a **continuous 0–100** scale. The bundled MATLAB `data.mat` variable names are **not** frozen in this repo. After you download `data.mat`, run:

```powershell
python tools/quality_validation/research_preview.py --dataset live_vqc --inspect-only
```

That prints actual MAT keys / CSV headers. Copy them into `templates/import_mapping.live_vqc.example.json` (replace `REPLACE_WITH_*`). Do not guess names.

MOS is aggregate. Do not treat it as three ACCESS raters or as criterion scores.
