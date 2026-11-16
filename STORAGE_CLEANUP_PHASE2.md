# ACCESS VisionCheck — Storage Cleanup Phase 2 (Read-Only)

- Generated: 2026-11-14 (local)
- Mode: **READ-ONLY** (no delete / move / modify / compress of project data)
- Inputs: `_storage_audit_raw.json` (2026-11-14T21:40+08:00), code/config/tests review, terminal Phase 1 sizes
- Companion: `STORAGE_CLEANUP_AUDIT.md` (Phase 1)
- **No cleanup was executed.** Await explicit approval.

### Snapshot caveat

After the size scan, the terminal shows `flutter clean` ran successfully. Measured sizes below for `build\` (~2555 MB) and `.dart_tool\` (~578 MB) are **pre-clean**. Those ~3.1 GB may **already be free** on disk (C: free was ~14.9 GB after clean). Do not count them again in “still recoverable.”

---

## 1. Active runtime map (evidence)

| Concern | Active setting / path | Evidence |
| --- | --- | --- |
| Quality engine | `QUALITY_ENGINE=musiq_worker` | `access_backend/.env`; `musiq_worker_client.py`; Phase 7I |
| Quality fallback | Optimized OpenCV | `media_evaluator.py` musiq path |
| Quality rollback | `QUALITY_ENGINE=enet` → `ml/efficientnet_b0_heads.pt` (15.61 MB) | `efficientnet_b0_scorer.py` |
| Photo authenticity | `AI_DETECTOR_BACKEND=probe` | `.env`; `ai_authenticity_detector.py` routes to PROBE |
| PROBE checkpoint | `...\DINOv2_best_model_step_34999.pth` (**1161.27 MB**) | Present per audit; `probe_dino_detector.py` |
| Video authenticity | `WAVEREP_ENABLED=true`; `ml/waverep/demo/weights/weights_dinov2_G4.ckpt` (**330.13 MB**) | `.env`; `waverep_g4_detector.py` |
| Production MUSIQ weights | Docker volume `musiq_tfhub_cache` (not in folder tree) | `musiq_worker/docker-compose.yml` |
| Host research TF Hub | `tools/.../official_musiq_engine_verification/cache/tfhub\...` | Research scripts only; **not** Docker volume |
| UnivFD | Wired but **not selected** | See §2 |
| Flutter | Source under `lib\`; build caches regenerable | `flutter clean` already run |

Docker daemon was **down** during Phase 1 (`docker system df` failed). Re-check before touching any Docker volume.

---

## 2. UnivFD `ViT-L-14.pt` (889.56 MB)

| Question | Answer |
| --- | --- |
| Used by active authenticity pipeline? | **No.** Live backend is `probe`. |
| Loaded at FastAPI startup when probe? | **No.** Lifespan warms PROBE only when `active_ai_detector_backend() == "probe"` (`main.py`). |
| Retained rollback like EfficientNet? | **Partial.** Switching `.env` to `AI_DETECTOR_BACKEND=univfd` still requires `fc_weights.pth` + `ViT-L-14.pt` (`dedicated_ai_detector.py`, `ml/univfd/README.txt`). Tests still cover UnivFD (`test_dedicated_ai_detector.py`). |
| Flutter dependency? | **No** direct Flutter binding to UnivFD weights. |

**Classification:** `ARCHIVE OR BACK UP FIRST` (not SAFE until you accept permanent UnivFD retirement).

| Path | Size |
| --- | --- |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\ml\univfd\ViT-L-14.pt` | **889.56 MB** |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\ml\univfd\fc_weights.pth` | (smaller; keep with backbone if archiving UnivFD as a pair) |

**Risk if deleted without archive:** cannot flip back to UnivFD offline without re-download (~890 MB CLIP).

---

## 3. Virtual environments

| Environment | Size signal | Referenced by | Classification |
| --- | --- | --- | --- |
| `access_backend\venv312\` | Torch/OpenCV present; scripts cite it heavily | Many `tools/quality_validation/*.py` shebangs/docs; primary research/backend Python | **KEEP — ACTIVE DEPENDENCY** |
| `access_mobile\.venv\` | **690.07 MB** (folder) | Unclear vs `venv312`; may be leftover root venv | **UNKNOWN — NEEDS VERIFICATION** (compare `where python` / which interpreter runs API) |
| `tools\quality_validation\.venv_musiq_phase4b\` | TF DLL alone **1007.69 MB**; whole venv likely **≫1 GB** | `run_phase4b_live_musiq.py`, Phase 4B restore docs | **ARCHIVE OR BACK UP FIRST** → then remove. Host TF blocked by Smart App Control (WinError 4551); **production MUSIQ is Docker**, not this venv |
| `access_backend\.venv_waverep_benchmark\` | Torch DLL present (size TBD; likely hundreds of MB) | **No** code/docs hits for this exact name; WaveRep verify uses generic `python scripts/waverep_linux_verify.py` | **ARCHIVE OR BACK UP FIRST** (or SAFE after confirming WaveRep runs under `venv312`) |
| `.venv_musiq_research` / `.venv_musiq_official` / `.venv_musiq_official_phase1` | May exist under tools | Older pyiqa/official TF research docs | **UNKNOWN** until `_phase2_hash_check.ps1` sizes; treat as research-only |

**`.venv_musiq_phase4b` usage evidence:** created for host TensorFlow MUSIQ when SAC still allowed TF; restore report documents TF load failure under SAC. Live app quality uses Docker worker. Reproducibility of Phase 4B **scores** lives in CSV/JSON under `workspace\phase4a_indval\machine_output\` and statistical folders — **keep those**, not necessarily the broken TF venv.

**`.venv_waverep_benchmark`:** no import/docs reference found. WaveRep **weights** (`weights_dinov2_G4.ckpt`) remain **KEEP**.

---

## 4. Duplicate MUSIQ pyiqa checkpoints (hash pending confirm)

Three identical-sized files (**103.58 MB each**), same filename `musiq_paq2piq_ckpt-364c0c84.pth` (hash fragment in name):

1. `...\koniq10k\musiq_paq2piq_benchmark\cache\torch\hub\pyiqa\musiq_paq2piq_ckpt-364c0c84.pth`
2. `...\koniq10k\musiq_paq2piq_benchmark\_smoke\cache\torch\hub\pyiqa\musiq_paq2piq_ckpt-364c0c84.pth`
3. `...\livec\output\run_livec_001\cache\torch\hub\pyiqa\musiq_paq2piq_ckpt-364c0c84.pth`

These are **pyiqa research caches**, not the Docker TF Hub PaQ-2-PiQ volume.

| Action | Classification |
| --- | --- |
| Keep one canonical copy (prefer `musiq_paq2piq_benchmark\cache\...`) | **KEEP** research cache (optional) or delete all three if pyiqa path abandoned |
| Remove the other two after SHA-256 match | **SAFE TO REMOVE AFTER APPROVAL** (~**207 MB**) |

Confirm hashes (read-only):

```powershell
cd C:\Users\Dell\Desktop\access_mobile
powershell -NoProfile -ExecutionPolicy Bypass -File .\_phase2_hash_check.ps1
```

Until hashes print identical: mark second/third as **UNKNOWN — NEEDS VERIFICATION** (size+name strongly suggest duplicates).

**Not duplicates of Docker MUSIQ.** Do not delete Docker `musiq_tfhub_cache`.

---

## 5. SPAQ ZIP archives vs extracted data

| Item | Evidence |
| --- | --- |
| ZIPs present | `SPAQ_Part_1.zip` … `Part_5.zip` ≈ **90.42 + 119.32 + 132.62 + 140.56 + 132.52 ≈ 615.4 MB** |
| Extracted | `...\spaq\extracted\SPAQ_Part_*\images\` (hash audit pairs many files with `spaq\images\`) |
| Curated research set | `SPAQ_200_INTEGRITY.md`: **200 JPEGs** in `spaq\images\`, annotations OK |

**Keep (research evidence):**

- `...\spaq\images\`
- `...\spaq\metadata\` (incl. `human_ratings_200.csv`)
- `SPAQ_200_*.md`, MOS xlsx

**Candidates:**

| Candidate | Size | Classification | Risk |
| --- | --- | --- | --- |
| `SPAQ_Part_*.zip` (all five) | ~**615 MB** | **ARCHIVE OR BACK UP FIRST**, then **SAFE TO REMOVE AFTER APPROVAL** | Lose easy re-extract of full SPAQ parts; curated 200 + metadata remain |
| `spaq\extracted\` (full part trees) | TBD (likely large; overlaps `images\` for selected 200) | **SAFE TO REMOVE AFTER APPROVAL** after confirming `images\` + metadata integrity | Only if you do not need full unfiltered part dumps |

Do **not** delete `images\` or locked rating CSVs.

---

## 6. Experimental TF Hub caches vs Docker MUSIQ

| Cache | Path | Role | Classification |
| --- | --- | --- | --- |
| Docker worker | Volume `musiq_tfhub_cache` → `/models/tfhub` | **Active** production MUSIQ | **KEEP — ACTIVE DEPENDENCY** |
| Host research TF Hub | `tools\quality_validation\workspace\datasets\koniq10k\official_musiq_engine_verification\cache\tfhub\a5e1c51ceccb5074aa6e1ed774b7ba4f4c79bbee\` (`saved_model.pb` **210.89 MB**) | Used by `run_phase4b_live_musiq.py` / Phase 1 hybrid on **host TF** (often SAC-broken) | **ARCHIVE OR BACK UP FIRST** / optional SAFE if Docker-only forever |
| `research_logs\quality_shadow\tfhub_cache` | Config default; folder ~empty (0.01 MB research_logs) | Shadow scoring off in prod | N/A |

Host TF Hub cache is **independent** of the Docker volume (different filesystem location). Deleting host cache does **not** remove Docker MUSIQ.

---

## 7. Protected (KEEP — ACTIVE / research integrity)

| Path / asset | Size (if known) | Why |
| --- | --- | --- |
| PROBE `DINOv2_best_model_step_34999.pth` | 1161.27 MB | Active authenticity |
| PROBE `experiments\probe\hf_cache\**` + `vendor_lib` sources | (inside experiments 1532 MB) | Inference deps |
| WaveRep `weights_dinov2_G4.ckpt` | 330.13 MB | `WAVEREP_ENABLED=true` |
| EfficientNet `ml\efficientnet_b0_heads.pt` | 15.61 MB | Quality rollback |
| `musiq_worker\**` + Docker image/volume | — | Active quality |
| `access_backend\app\**`, `lib\**`, `admin-web\src\**` | — | Source |
| `.env`, `.env.*`, `phase7i_local_cutover\env_backups\**` | — | Config/secrets |
| `access_backend\uploads\**` | 105.35 MB | App media (DB-linked risk) |
| Phase 6B locked ratings + stats | under `tools\...\phase4a_indval\` | Manuscript / human evidence |
| `phase6b_locked_ratings.csv`, R2/R3 locked CSVs, `phase6b_statistical_analysis\**` | — | **DO NOT DELETE** |
| `fresh_validation\`, `video_metadata_test\` | 207.65 / 16.95 MB | Experimental but used in Phase 7 smokes; REVIEW not auto-delete |
| Databases / Postgres data | — | Out of folder tree; protect |

---

## 8. Classification table (Phase 2 focus)

### SAFE TO REMOVE AFTER APPROVAL

| Path | Size | Notes |
| --- | --- | --- |
| Two of three `musiq_paq2piq_ckpt-364c0c84.pth` copies | ~**207 MB** | After SHA-256 match |
| `tools\...\spaq\extracted\` (optional) | TBD | Only if `images\`+metadata kept |
| `__pycache__`, `.pytest_cache` (scattered) | ~11+ MB backend pytest alone | Regenerable |
| UI shot / `_backup_*` / `_verify_*` screenshot folders at repo root | ~**~100 MB** combined (many 1–20 MB dirs) | Not runtime |
| `flutter_run_verbose.log` | 7.96 MB | Log |
| `_storage_audit_*.ps1/cmd` helpers | tiny | After cleanup planning done |

### ARCHIVE OR BACK UP FIRST

| Path | Size | Notes |
| --- | --- | --- |
| `ml\univfd\ViT-L-14.pt` (+ `fc_weights.pth`) | **889.56 MB** + head | Inactive; optional alternate detector |
| `tools\quality_validation\.venv_musiq_phase4b\` | **≫1 GB** (TF 1008 MB file alone) | Host TF broken under SAC; Docker replaced it |
| `access_backend\.venv_waverep_benchmark\` | TBD (~0.5–1 GB est.) | No code references found |
| `SPAQ_Part_1.zip` … `SPAQ_Part_5.zip` | ~**615 MB** | Extracted + curated 200 already on disk |
| Host `official_musiq_engine_verification\cache\tfhub\**` | ≥**211 MB** | Research-only; not Docker |

### KEEP — ACTIVE DEPENDENCY

| Path | Size |
| --- | --- |
| PROBE checkpoint | 1161.27 MB |
| WaveRep G4 ckpt | 330.13 MB |
| EfficientNet heads | 15.61 MB |
| `venv312` (until proven unused) | TBD |
| Docker MUSIQ volume/image | TBD (daemon was down) |
| Phase 6B locked human + statistical outputs | — |
| `spaq\images` + `spaq\metadata` | — |
| Source, `.env`, uploads, DB | — |

### UNKNOWN — NEEDS VERIFICATION

| Item | Why |
| --- | --- |
| Exact SHA-256 equality of 3 pyiqa MUSIQ ckpts | Run `_phase2_hash_check.ps1` |
| Whole-folder sizes for `.venv_musiq_phase4b`, `.venv_waverep_benchmark`, `spaq\extracted` | Same script |
| Root `.venv` vs `venv312` which runs API | Check process / launch scripts |
| Other musiq research venvs | May or may not exist |
| Docker reclaimable | Start Docker Desktop; `docker system df` read-only |

---

## 9. Recoverable storage (no double-counting)

Nested rule: do **not** add `tools\` (5519 MB) + children inside it.

### Already likely freed (do not re-count)

| Item | Pre-clean size |
| --- | --- |
| `build\` + `.dart_tool\` after `flutter clean` | ~**3132 MB** |

### Still recoverable if approved (additive, non-overlapping)

| Bucket | Est. MB | Confidence |
| --- | --- | --- |
| Duplicate pyiqa MUSIQ ckpts (keep 1) | ~207 | High after hash confirm |
| SPAQ ZIP archives | ~615 | High (extracted+images exist) |
| Host research TF Hub cache | ~211+ | Medium (optional archive) |
| UnivFD ViT-L-14.pt (after archive) | ~890 | High for reclaim; product decision |
| `.venv_musiq_phase4b` | ~1500–3000 (est.) | Medium until folder sized |
| `.venv_waverep_benchmark` | ~500–1000 (est.) | Medium |
| Screenshot/`_backup_*` UI folders | ~100 | High |
| **Conservative (hashes+ZIPs+UI only)** | **~0.9 GB** | High |
| **Aggressive (+ UnivFD + phase4b venv + waverep venv + host TF cache)** | **~4–6 GB** | Medium |

Phase 1 root total was ~**15.65 GB** (`access_mobile`) + 0.22 GB external media. Post-`flutter clean`, expect ~**3 GB** already returned.

---

## 10. Recommended cleanup order (commands not executed)

1. Run `_phase2_hash_check.ps1` (read-only) to lock sizes + MUSIQ SHA-256.
2. Start Docker Desktop → `docker system df` (read-only) → note `musiq_tfhub_cache`.
3. **SAFE:** delete duplicate pyiqa ckpts (2 of 3); small caches; UI shot folders; optional `spaq\extracted`.
4. **ARCHIVE then remove:** SPAQ ZIPs to external drive; UnivFD weights if retiring; `.venv_musiq_phase4b`; `.venv_waverep_benchmark` after WaveRep smoke on `venv312`.
5. Never delete PROBE / WaveRep / ENET / Phase 6B locked ratings / `spaq\images`+metadata / uploads / `.env` / Docker MUSIQ volume.

---

## 11. PowerShell (read-only) to finish measurements

```powershell
cd C:\Users\Dell\Desktop\access_mobile
powershell -NoProfile -ExecutionPolicy Bypass -File .\_phase2_hash_check.ps1

# Confirm flutter clean effect:
if (Test-Path .\build) { "build still exists" } else { "build gone" }
if (Test-Path .\.dart_tool) { ".dart_tool still exists" } else { ".dart_tool gone" }

# Docker read-only (after Docker Desktop starts):
docker system df
docker volume ls
```

---

## 12. Sign-off checklist

- [ ] SHA-256 of three MUSIQ pyiqa ckpts recorded
- [ ] Folder sizes for phase4b / waverep_benchmark / spaq\extracted recorded
- [ ] Confirmed which Python runs FastAPI (`venv312` vs `.venv`)
- [ ] Docker volume protected / measured
- [ ] User approval list selected from SAFE / ARCHIVE tables
- [ ] **No deletions until you explicitly approve**

**Awaiting your explicit approval before removing anything.**
