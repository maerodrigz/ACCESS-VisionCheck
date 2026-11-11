# ACCESS VisionCheck — Media Quality Evaluation Sandbox

**Research-only local tool.** Not connected to the production FastAPI backend,
database, Flutter app, or any external service.

## What it does

Side-by-side comparison of **two engines** on one uploaded photograph:

| Engine | Role |
|--------|------|
| **A — EfficientNet-B0** | Production baseline (read-only import of `efficientnet_b0_scorer` + production `_soft_score`). Never silently substituted with OpenCV. |
| **B — Experimental Classical Combined v1** | Research detectors (Sharpness/Blur/Brightness/Contrast v2, Blocking v3, Noise/Ringing v2). |

Both show all seven criteria with scores (or N/A), engine identity, limitations, and **separate runtimes**.

Expandable **Why this score?** sections add classical measurements (with units),
plain-language interpretation, detector limitations, and engine disagreement notes.
Diagnostic-only stats never change badges. EfficientNet shows only continuous head
outputs plus the production badge mapping — no fabricated internal reasoning.

## Starting the server

```powershell
cd c:\Users\Dell\Desktop\access_mobile
access_backend\venv312\Scripts\python.exe tools\quality_validation\sandbox\server.py
```

Open **http://127.0.0.1:8765/**

```powershell
# Optional:
... server.py --port 9000
... server.py --host 0.0.0.0 --port 8765
```

## Running tests

```powershell
cd c:\Users\Dell\Desktop\access_mobile
access_backend\venv312\Scripts\python.exe -m pytest tools\quality_validation\sandbox\tests\ -v
```

## Engine B composition

| Criterion | Version | Validation status |
|---|---|---|
| Sharpness | v2 | Adopted research (SPAQ rho=0.75) |
| Blur | v2 | Adopted research (pilot rho=0.82) |
| Noise | **v2** | **UNVALIDATED** (pilot rho=-0.25) |
| Brightness | v2 | Adopted research |
| Contrast | v2 | Adopted research |
| Blocking | **v3** | Lightweight synthetic PASS only |
| Ringing | **v2** | **UNVALIDATED** (pilot rho=-0.40) |

Noise v3/v4 and Ringing v3/v4 are optional checkboxes only. Noise v4 and Ringing v4 **REGRESSED** on the frozen pilot and are not promoted.

## Strict constraints

- No production FastAPI / Flutter / DB / weight file changes.
- No SPAQ-200 or frozen pilot re-runs from this sandbox.
- No threshold tuning of experimental engines.
- Uploads held in memory only.
- Multipart parsing uses `email.parser` (Python 3.13-safe; no `cgi`).
- Video evaluation is intentionally out of scope for this phase.

## Files

```
tools/quality_validation/sandbox/
  __init__.py
  evaluator.py       # dual-engine wrapper (read-only ENET + classical)
  diagnostics.py     # supplementary measurements + explanations (no score changes)
  server.py          # stdlib HTTP server
  index.html         # side-by-side UI + Why this score?
  README.md
  tests/
    __init__.py
    test_sandbox.py
```
