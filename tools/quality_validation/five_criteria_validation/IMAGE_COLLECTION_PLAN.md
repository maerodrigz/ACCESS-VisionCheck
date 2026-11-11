# Image collection plan — Five Classical criteria validation

**Status:** Plan only. **Do not download images until approved.**

---

## 1. Targets

| Split | Count | ID prefix |
|-------|------:|-----------|
| Calibration (discussion) | 12–16 | `FCCAL-##` |
| Calibration (independent practice) | 6 | `FCCAL-P#` |
| Validation | **40** (acceptable 36–48) | `FC001`–`FC040` |
| Reserve | 8–10 | `FCRES-##` |

---

## 2. Hard exclusions

Do **not** include:

- Frozen ACCESS pilot-30 (`PILOT-*` / Run 002 join IDs)
- Noise/Ringing validation `NR001`–`NR015`
- Images previously used to choose Classical v2 / Blocking v3 thresholds
- SPAQ-200 evaluation subset files if they were used for Classical model **selection** (prefer fully new Commons / open-license documentation photos)
- Synthetic unit-test ladders as validation items

---

## 3. Content mix (validation, approximate)

| Content family | Approx. share | Why |
|----------------|--------------:|-----|
| Daylight outdoor / venue | 25% | Sharpness / contrast baseline |
| Indoor event / mixed light | 25% | Brightness + blur risk |
| Night / low light | 15% | Brightness under + softness |
| Text / signage / edges | 15% | Sharpness + blocking on flats near edges |
| Smooth sky / wall / skin flats | 20% | Blocking severity + contrast flats |

Every image still receives all five stratum tags (facilitator).

---

## 4. Severity balance (validation)

Aim for roughly **20–30%** of images in each of `clean / mild / moderate / severe` for Sharpness, Blur, and Blocking.

**Brightness (required):** include both under- and over-exposure. Suggested minimum among 40:

| brightness_stratum | Min count |
|--------------------|----------:|
| clean | 8 |
| under_mild | 6 |
| under_severe | 4 |
| over_mild | 6 |
| over_severe | 4 |

**Blocking (required):** at least **8** images planned as `moderate` or `severe` (visible blocks at 100%), and at least **8** planned `clean`. Do not ship a pack that is almost all clean flats.

**Contrast:** mix flat and harsh; avoid all mid “punchy OK” photos.

Images may be severe on one criterion and clean on another (preferred).

---

## 5. Licensing and provenance

Prefer Wikimedia Commons / CC-licensed event-like photos with recorded:

- source URL / title  
- license  
- download date  
- SHA-256  
- `previously_used_in_eval_sets=no` (confirm against pilot + NR manifests)

Store facilitator notes in `facilitator/` when collection launches (not created until approval).

---

## 6. Manifest schema

Use `templates/five_criteria_image_manifest.example.csv` → working `five_criteria_image_manifest.csv`.

Required columns include: `media_id`, `split`, five `*_stratum` fields, `content_tag`, license fields, `sha256`, `exclude_reason`.

---

## 7. What this plan does not do yet

- No downloads  
- No integrity script runs on empty folders  
- No machine pre-scoring of candidates for selection  

After approval, follow `COLLECTION_CHECKLIST.md`.
