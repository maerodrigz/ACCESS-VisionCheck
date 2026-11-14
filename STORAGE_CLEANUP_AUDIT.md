# ACCESS VisionCheck — Safe Storage Cleanup Audit

- Generated: 2026-11-14 (local)
- Mode: **READ-ONLY** (no deletes, moves, compress, or mutations of project data)
- Scope roots:
  - `C:\Users\Dell\Desktop\access_mobile`
  - `C:\Users\Dell\Desktop\fresh_validation`
  - `C:\Users\Dell\Desktop\video_metadata_test`
- Agent Shell size measurement: **unavailable this session**
- Exact byte sizes for Top 20: **PENDING** until you run the CMD block below (writes `_storage_audit_raw.json` only)

**No files were deleted.** Wait for your explicit approval before any cleanup.

---

## How to complete measured sizes (Windows CMD)

Run this once, then reopen this file / re-ask the agent to merge numbers from `_storage_audit_raw.json`:

```bat
cd /d C:\Users\Dell\Desktop\access_mobile
powershell -NoProfile -ExecutionPolicy Bypass -File ".\_storage_audit_scan.ps1"
docker system df
docker system df -v
docker images
docker volume ls
```

Or: `C:\Users\Dell\Desktop\access_mobile\_run_storage_audit.cmd`

Docker commands above are **read-only**. Do **not** run `docker system prune`, `volume prune`, `image prune`, or delete WSL/Docker virtual disks.

---

## Executive summary

| Area | Classification | Notes |
| --- | --- | --- |
| FastAPI / Flutter / admin-web source | **DO NOT DELETE** | Application code |
| `.env`, DB, migrations, credentials | **DO NOT DELETE** | Config / secrets / schema |
| `ml/efficientnet_b0_heads.pt` | **DO NOT DELETE** | Rollback quality engine (`QUALITY_ENGINE=enet`) |
| PROBE checkpoint + HF DINOv2 cache | **DO NOT DELETE** | Active `AI_DETECTOR_BACKEND=probe` |
| WaveRep module + expected G4 checkpoint path | **DO NOT DELETE** | `WAVEREP_ENABLED=true` in local `.env` |
| MUSIQ worker image / TF Hub Docker volume | **DO NOT DELETE** | Live `QUALITY_ENGINE=musiq_worker` |
| `ml/univfd/fc_weights.pth` (+ missing backbone) | **REVIEW FIRST** | Alternate detector; not active backend but still wired |
| `fresh_validation\` experimental media | **REVIEW FIRST** | Research / Phase 7 test inputs |
| `video_metadata_test\` | **REVIEW FIRST** | Single real phone MP4 used in Phase 7H |
| `tools\quality_validation\` assets | **REVIEW FIRST** / protect ratings | Large tree (9000+ files); Phase 6B locked human ratings are **DO NOT DELETE** |
| `tools\...\machine_output\musiq_live_docker_*` | **REVIEW FIRST** | Regenerable MUSIQ batch outputs; keep until manuscript needs settle |
| `access_backend\uploads\` | **REVIEW FIRST** | May be referenced by DB rows |
| `__pycache__` / `.pytest_cache` / build caches | **SAFE TO DELETE** | Regenerable |
| Phase 7D–7I JSON/MD reports | **REVIEW FIRST** | Small; keep until cutover sign-off |
| Desktop sibling copies (`access_mobile_backups`, `access_mobile_quality_qa`, `waverep_testing`) | **OUT OF SCOPE** but **REVIEW FIRST** | Often larger than in-repo trees; not deleted here |

---

## Model usage verification (code + config)

| Asset | Path | Referenced by | Current role | Verdict |
| --- | --- | --- | --- | --- |
| EfficientNet-B0 heads | `access_backend\ml\efficientnet_b0_heads.pt` | `app/services/efficientnet_b0_scorer.py` (`_WEIGHTS_PATH`); Phase 7G/7I rollback gates | Inactive while `QUALITY_ENGINE=musiq_worker`; **required for rollback** | **DO NOT DELETE** |
| MUSIQ PaQ-2-PiQ | Docker worker `musiq_worker` + TF Hub volume `musiq_tfhub_cache` | `musiq_worker/docker-compose.yml`; `app/services/musiq_worker_client.py`; local `.env` `QUALITY_ENGINE=musiq_worker` | **Primary quality engine** | **DO NOT DELETE** |
| OpenCV quality (vectorized) | Code only (`app/services/opencv_quality.py`) | Fallback on MUSIQ path | Fallback | N/A (code) |
| PROBE DINOv2 heads | Expected: `access_backend\experiments\probe\modelscope_cache\models\shuinishaojiu--PROBE-AIGI-Detection\snapshots\master\DINOv2_best_model_step_34999.pth` | `app/services/probe_dino_detector.py` (`DEFAULT_CHECKPOINT`); `AI_DETECTOR_BACKEND=probe` | **Active authenticity backend** | **DO NOT DELETE** if present; restore from backup if missing |
| PROBE HF backbone cache | `access_backend\experiments\probe\hf_cache\models--facebook--dinov2-with-registers-large\` | Loaded with PROBE inference | Required companion cache | **DO NOT DELETE** |
| PROBE vendor_lib | `access_backend\experiments\probe\vendor_lib\` | `probe_dino_detector._ensure_probe_sys_path` | Runtime import path | **DO NOT DELETE** (source); `__pycache__` under it is SAFE) |
| WaveRep G4 checkpoint | Expected: `access_backend\ml\waverep\demo\weights\weights_dinov2_G4.ckpt` | `app/config.py` `WAVEREP_CHECKPOINT_PATH`; `waverep_g4_detector.py`; `.env` has `WAVEREP_ENABLED=true` | Video authenticity when enabled | **DO NOT DELETE** path/module; locate checkpoint if missing |
| WaveRep Python module | `access_backend\ml\waverep\` | Detector import path | Required scaffolding | **DO NOT DELETE** |
| UnivFD head | `access_backend\ml\univfd\fc_weights.pth` | `dedicated_ai_detector.py` when backend=`univfd` | Alternate; not selected (`probe` active) | **REVIEW FIRST** (keep unless you permanently drop UnivFD) |
| UnivFD CLIP backbone | Expected: `access_backend\ml\univfd\ViT-L-14.pt` | Same | **Not found in tree** | N/A / reinstall if re-enabling UnivFD |

**Rule applied:** inactive ≠ deletable. EfficientNet is inactive on the MUSIQ path but is the documented rollback. UnivFD is inactive but still import-wired.

### Probe checkpoint presence (static)

- Inside `access_mobile\access_backend\experiments\probe\modelscope_cache\`: **no checkpoint files found** by inventory.
- Copies exist **outside** scope (do not delete without review):
  - `C:\Users\Dell\Desktop\access_mobile_backups\pre_integration_20261109_212128\access_mobile_project\access_backend\experiments\probe\modelscope_cache\models\shuinishaojiu--PROBE-AIGI-Detection\snapshots\master\DINOv2_best_model_step_34999.pth`
  - `C:\Users\Dell\Desktop\access_mobile_quality_qa\access_backend\experiments\probe\modelscope_cache\models\shuinishaojiu--PROBE-AIGI-Detection\snapshots\master\DINOv2_best_model_step_34999.pth`
- If authenticity works on this laptop, the live checkpoint may be elsewhere via `PROBE_CHECKPOINT_PATH` or was restored after inventory; treat any `DINOv2_best_model_step_34999.pth` as **protected**.

---

## Top 20 largest folders/files

**Status: PENDING measured ranks.** After `_storage_audit_scan.ps1`, paste/merge the `children` + `largest_files` arrays here.

### Expected heavy hitters (qualitative, pre-measure)

1. `access_backend\experiments\probe\vendor_lib\` — huge vendored tree (9000+ files observed)
2. `access_backend\experiments\probe\hf_cache\` — DINOv2 HF blobs
3. Docker MUSIQ image + `musiq_tfhub_cache` volume (outside folder tree; see Docker section)
4. `tools\quality_validation\` — assets + outputs
5. `fresh_validation\` — real + AI image sets (~100 media files indexed)
6. Flutter/Android build products if present (`.dart_tool`, `build`, `android\.gradle`) — often large when present
7. `admin-web\node_modules` if present
8. `access_backend\uploads\` — practice media + profiles
9. `video_metadata_test\VID_20260629_181454.mp4`
10. Phase 7 report folders (usually small vs models)

---

## SAFE TO DELETE (regenerable caches / temp)

Delete only after approval. Reclaim estimate: **unknown until size scan**; typically hundreds of MB to a few GB depending on Python/Flutter caches.

| Path | Why safe |
| --- | --- |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\**\__pycache__\` | Bytecode cache |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\.pytest_cache\` | Test cache |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\.mypy_cache\` | Type cache (if present) |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\.ruff_cache\` | Lint cache (if present) |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\experiments\probe\vendor_lib\**\__pycache__\` | Regenerable; keep `.py` sources |
| `C:\Users\Dell\Desktop\access_mobile\.dart_tool\` | Flutter tool cache (if present; regenerable via `flutter pub get`) |
| `C:\Users\Dell\Desktop\access_mobile\build\` | Flutter build output (if present) |
| `C:\Users\Dell\Desktop\access_mobile\android\app\build\` | Android build (if present) |
| `C:\Users\Dell\Desktop\access_mobile\android\.gradle\` | Gradle project cache (if present; may slow next build) |
| `C:\Users\Dell\Desktop\access_mobile\admin-web\dist\` | Vite build output (if present) |
| `C:\Users\Dell\Desktop\access_mobile\_storage_audit_raw.json` | Audit artifact (after you no longer need it) |
| `C:\Users\Dell\Desktop\access_mobile\_storage_audit_scan.ps1` | Audit helper script |
| `C:\Users\Dell\Desktop\access_mobile\_run_storage_audit.cmd` | Audit helper script |

**Not listed as safe:** Docker volumes, model weights, `uploads\`, research media, `.env*`, databases.

---

## REVIEW FIRST (manual decision)

### Experimental / validation media

| Path | Notes |
| --- | --- |
| `C:\Users\Dell\Desktop\fresh_validation\real\own_new_photos\` | Real photos; used by Phase 7B/7G/7I smoke defaults |
| `C:\Users\Dell\Desktop\fresh_validation\real\verified_external\` | External real set |
| `C:\Users\Dell\Desktop\fresh_validation\ai\chatgpt\` | AI samples |
| `C:\Users\Dell\Desktop\fresh_validation\ai\gemini\` | AI samples |
| `C:\Users\Dell\Desktop\fresh_validation\ai\pixlr\` | AI samples |
| `C:\Users\Dell\Desktop\fresh_validation\ai\canva\` | AI samples |
| `C:\Users\Dell\Desktop\video_metadata_test\VID_20260629_181454.mp4` | Real phone video; Phase 7H input |
| `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\video_four_criteria_validation\assets\*.mp4` | Short validation clips (incl. `01_baseline_neutral.mp4`) |
| `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\video_four_criteria_validation\out\` | Prior validation JSON/evidence |
| `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\phase4a_indval\machine_output\` | MUSIQ live Docker run CSVs/JSONL (often regenerable) |
| `C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\.pytest_cache\` and portal `__pycache__` | Prefer SAFE cache cleanup inside tools |

### Runtime uploads (DB may reference)

| Path | Notes |
| --- | --- |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\uploads\videos\` | Practice videos on disk |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\uploads\images\` | Uploaded images |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\uploads\profiles\` | Profile avatars |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\uploads\branding\access_logo.jpg` | Branding asset — prefer keep |

### Phase 7 verification artifacts (small; keep until sign-off)

| Path |
| --- |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\phase7d_performance_benchmark\` |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\phase7e_performance_investigation\` |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\phase7f_opencv_blocking_optimization\` |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\phase7g_musiq_cutover_verification\` |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\phase7h_video_authenticity_verification\` |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\phase7i_local_cutover\` (except do not casually delete `env_backups\` until cutover settled) |

### Alternate / possibly unused weights

| Path | Notes |
| --- | --- |
| `C:\Users\Dell\Desktop\access_mobile\access_backend\ml\univfd\fc_weights.pth` | Only if you permanently abandon UnivFD |
| Missing `ViT-L-14.pt` | Not present; nothing to delete |

### Duplicate datasets (hash scan pending)

Run the PowerShell audit to fill `duplicate_groups` in `_storage_audit_raw.json`. Likely duplicate classes to review:

- Same photo present under `fresh_validation` and copied into research/out folders
- Desktop full-tree clones: `access_mobile_backups\...` vs live `access_mobile\...` (PROBE checkpoint already seen duplicated on Desktop)

---

## DO NOT DELETE (protected)

| Path / resource | Reason |
| --- | --- |
| `access_mobile\lib\**`, `access_mobile\access_backend\app\**`, `access_mobile\admin-web\src\**` | Source |
| `access_mobile\access_backend\.env` and `.env.*` | Secrets / runtime config |
| `access_mobile\access_backend\phase7i_local_cutover\env_backups\.env.pre_phase7i_*` | Cutover rollback copies of `.env` |
| PostgreSQL data / DB dumps you still need | Databases |
| Alembic/migrations / `create_tables` scripts | Schema |
| `access_backend\ml\efficientnet_b0_heads.pt` | ENET rollback |
| Any `DINOv2_best_model_step_34999.pth` | PROBE authenticity |
| `access_backend\experiments\probe\hf_cache\**` | PROBE backbone cache |
| `access_backend\experiments\probe\vendor_lib\**\*.py` (and non-cache sources) | PROBE runtime |
| `access_backend\ml\waverep\**` (module) + `...\weights_dinov2_G4.ckpt` if present | WaveRep |
| `access_mobile\musiq_worker\**` | Worker source/compose |
| Docker image `access-musiq-worker:local` and volume `musiq_tfhub_cache` | Live MUSIQ |
| Human ratings / manuscript validation CSVs under `tools\quality_validation` and research evidence | Research integrity |
| Especially: `tools\quality_validation\workspace\phase4a_indval\phase6b_locked_ratings.csv`, `phase6b_R2_locked_ratings.csv.csv`, `phase6b_R3_locked_ratings.csv.csv`, `phase6b_statistical_analysis\**` | Phase 6B evidence |
| `tools\quality_validation\phase6b_rating_portal\.env.cloud_secrets` | Secrets |
| Flutter assets required by app (logos under `assets\`, etc.) | App resources |

---

## Docker disk usage (read-only)

**Not measured in this session.** Run:

```bat
docker system df
docker system df -v
docker images
docker volume ls
docker ps -a
```

**Protect:**

- Image: `access-musiq-worker:local` (from `musiq_worker\docker-compose.yml`)
- Volume: `musiq_tfhub_cache` (TF Hub PaQ-2-PiQ cache; expensive to re-download)

**Do not run:** `docker system prune`, `docker volume prune`, `docker image prune`, WSL `ext4.vhdx` deletion.

---

## Estimated reclaimable storage

| Bucket | Estimate | Confidence |
| --- | --- | --- |
| SAFE caches (`__pycache__`, pytest, Flutter/Android build) | TBD after scan (often 0.5–5+ GB if builds exist) | Low until measured |
| REVIEW media (`fresh_validation` + tools assets + uploads) | TBD (media-dependent) | Low |
| OUT-OF-SCOPE Desktop clones (`access_mobile_backups`, `access_mobile_quality_qa`, `waverep_testing`) | Often **multi-GB**; largest realistic win | Medium (known duplicate PROBE trees) |
| Docker unused images/containers | TBD via `docker system df` | — |
| **Total safe-without-review** | **Caches only** until you approve REVIEW items | — |

---

## Suggested cleanup order (after your approval)

1. SAFE caches only (`__pycache__`, `.pytest_cache`, Flutter/Android build dirs if present).
2. Run size scan; target largest REVIEW folders with copies elsewhere.
3. Consider Desktop **out-of-scope** duplicates (`access_mobile_backups`, `access_mobile_quality_qa`) only after confirming live PROBE/WaveRep/ENET still work.
4. Never auto-delete Docker MUSIQ volume or active checkpoints.

---

## Duplicate hash status

- Practical SHA-256 grouping is implemented in `_storage_audit_scan.ps1` for media under `fresh_validation`, `video_metadata_test`, `tools`, and `uploads` (100KB–80MB files).
- **Results pending** until that script is run.

---

## Audit helpers created (not project runtime)

These were added only to support this audit; safe to delete after you finish cleanup planning:

- `C:\Users\Dell\Desktop\access_mobile\_storage_audit_scan.ps1`
- `C:\Users\Dell\Desktop\access_mobile\_run_storage_audit.cmd`
- `C:\Users\Dell\Desktop\access_mobile\STORAGE_CLEANUP_AUDIT.md` (this file — keep until cleanup done)

---

## Sign-off

- [ ] Size scan completed (`_storage_audit_raw.json` exists)
- [ ] Docker `system df` captured
- [ ] User approved SAFE list
- [ ] User approved any REVIEW deletions
- [ ] Protected models verified present after cleanup

**Awaiting your explicit approval before deleting anything.**
