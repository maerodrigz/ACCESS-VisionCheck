# Image supply checklist (NR001–NR015)

Use this if automated Commons downloads are incomplete due to rate limits or missing files.

For each missing ID, place a **real photograph** at `images/NR0xx.jpg` (or `.png`), then re-run:

```powershell
access_backend\venv312\Scripts\python.exe tools\quality_validation\noise_ringing_validation\collect_open_license_images.py
access_backend\venv312\Scripts\python.exe tools\quality_validation\noise_ringing_validation\check_collection_integrity.py
```

Or manually update `noise_ringing_image_manifest.csv` with provenance + SHA-256 (never invent licenses).

| ID | Target bucket (planning only) | Suggested content | Status |
|----|-------------------------------|-------------------|--------|
| NR001 | clean | daylight architecture/landscape | see status report |
| NR002 | clean | daylight landscape | see status report |
| NR003 | clean | daylight monument/building | see status report |
| NR004 | low_light_noise | night / high-ISO, mild grain possible | see status report |
| NR005 | low_light_noise | night street | see status report |
| NR006 | low_light_noise | night street / indoor low light | see status report |
| NR007 | moderate_strong_noise | stronger night noise | see status report |
| NR008 | moderate_strong_noise | night landscape shadows | see status report |
| NR009 | moderate_strong_noise | night sky / deep shadows | see status report |
| NR010 | possible_ringing | neon/signage hard edges | see status report |
| NR011 | possible_ringing | lit tower/building edges | see status report |
| NR012 | possible_ringing | night structure edges | see status report |
| NR013 | mixed_ambiguous | compression/JPEG confuser | see status report |
| NR014 | mixed_ambiguous | texture/bokeh confuser | see status report |
| NR015 | mixed_ambiguous | night architecture mixed | see status report |

**Do not** reuse frozen pilot, SPAQ-200, KonIQ, or prior detector-development images.  
**Do not** invent provenance.  
**Do not** expose this checklist’s bucket column to raters.
