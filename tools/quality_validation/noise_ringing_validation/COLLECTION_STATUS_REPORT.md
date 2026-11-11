# Noise/Ringing preliminary collection status

- Collection date: 2026-11-09
- Target slots: 15 (`NR001`–`NR015`)
- Images ready: **15/15**
- Missing slots: (none)
- Integrity checker: **passed** (`check_collection_integrity.py`)
- Manifest: `noise_ringing_image_manifest.csv`
- Facilitator notes (hidden from raters): `facilitator/collection_notes.csv`
- Human sheets: `ratings/R1_noise_ringing_ratings.csv`, `R2_…`, `R3_…` (blank Noise/Ringing)
- Evaluator guide: `HUMAN_EVALUATION_INSTRUCTIONS.md`

## Collection mix (planning targets only — not ground truth)

| Bucket | IDs |
|--------|-----|
| Relatively clean | NR001, NR002, NR003 |
| Low-light / sensor noise candidates | NR004, NR005, NR006 |
| Moderate/strong noise candidates | NR007, NR008, NR009 |
| Possible ringing / hard-edge candidates | NR010, NR011, NR012 |
| Mixed / ambiguous | NR013, NR014, NR015 |

These buckets guided source selection only. Raters must not see them. Do not treat them as labels.

## Provenance

All files are real photographs from **Wikimedia Commons** with license/artist metadata taken from the Commons API. SHA-256 recorded in the manifest. Confirmed disjoint from the frozen ACCESS pilot / SPAQ / KonIQ local evaluation lists (Commons originals; not copied from those packs).

Some downloads used Commons **2560px thumbnails** when originals were rate-limited (`download_variant=thumb2560`). These remain real-photo derivatives, not synthetic degradations.

## Notes / limitations

- **NR007** is comparatively small (1000×667). Still openable; prefer 100% crops carefully.
- Wikimedia rate limits delayed acquisition; collector now adopts on-disk files and does not delete good files on retry failure.
- **Do not** run machine–human validation until human ratings are complete.
- **Do not** claim Noise/Ringing detectors are validated from this pack alone.

## Re-check

```powershell
access_backend\venv312\Scripts\python.exe tools\quality_validation\noise_ringing_validation\check_collection_integrity.py
```
