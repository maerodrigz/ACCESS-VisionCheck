# MUSIQ worker real runtime verification — 2026-11-13

**Result: BLOCKED before build/run.** No end-to-end live inference was performed. Mocked unit tests are **not** treated as success.

## 1. Docker / WSL availability

| Check | Result |
|-------|--------|
| `docker` on PATH | **Not found** |
| Docker Desktop install paths | **Missing** (`Program Files\Docker`, LocalAppData\Docker) |
| `podman` | **Not found** |
| `docker compose` | **N/A** (Docker absent) |
| WSL default version | **2** |
| `WSLService` | Running / Automatic |
| Installed WSL distributions | **None** (`wsl -l -v` → no distributions) |
| Smart App Control / CI policy | **Not modified** (per instructions) |

## 2. Model load /ready / evaluate / client

| Step | Result |
|------|--------|
| `docker compose up --build` | **Not run** (Docker unavailable) |
| TensorFlow 2.21 inside Linux container | **Not verified** |
| `GET /ready` MUSIQ loaded | **Not verified** |
| Real JPG `POST /v1/evaluate` | **Not verified** |
| FastAPI client vs real worker | **Not verified** |
| Startup time / CPU latency / peak RAM | **Not measured** |

## 3. Production engine unchanged

| Check | Result |
|-------|--------|
| `QUALITY_ENGINE` default in `config.py` | `enet` |
| `.env.example` | `QUALITY_ENGINE=enet` |
| `access_backend/.env` MUSIQ/QUALITY lines | No override found (no `QUALITY_ENGINE`/`MUSIQ_WORKER` entries) |
| `media_evaluator.preferred_quality_engine` | Still EfficientNet-B0 first |
| Production scores / XP / feedback / AI detection | **Unchanged** (worker path not activated) |
| Hosting purchased / remote deploy | **No** |
| Hybrid production scoring enabled | **No** |

## 4. Blocker

**Primary blocker:** Docker Desktop is not installed on this Windows host, and WSL2 has no Linux distribution. The MUSIQ worker image cannot be built or started here without installing system software.

Windows-native TensorFlow remains separately blocked by Code Integrity / Smart App Control (WinError 4551 on `_dtypes.pyd`). That path was **not** used or altered for this verification.

## 5. Recommended next deployment step

1. **With operator approval**, install either:
   - Docker Desktop for Windows (enables Linux containers; typically needs WSL2 backend), **or**
   - A WSL2 distro (e.g. Ubuntu) plus Docker Engine inside WSL / Docker Desktop.
2. Re-run this verification on the same machine:
   ```bash
   cd musiq_worker
   # set MUSIQ_WORKER_TOKEN in .env
   docker compose up --build
   curl http://127.0.0.1:8080/ready
   curl -H "Authorization: Bearer $TOKEN" -F media_type=photo -F file=@sample.jpg \
     http://127.0.0.1:8080/v1/evaluate
   ```
3. Then point staging backend (`QUALITY_ENGINE=enet` still) at `MUSIQ_WORKER_URL=http://127.0.0.1:8080` and run the real `musiq_worker_client.evaluate_bytes` smoke.
4. Only after live `/ready` + finite MUSIQ score: consider low-cost Linux cloud hosting. Do not cut over production quality engine yet.

## 6. Errors

- `docker`: command not recognized
- `wsl -l -v`: no installed distributions
