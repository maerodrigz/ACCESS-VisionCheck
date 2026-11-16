# Phase 7D — Quality engine performance benchmark

- Started: `2026-11-14T10:14:35.850582+00:00`
- Finished: `2026-11-14T10:17:08.161942+00:00`
- Measured evaluations per engine: **10** (warmup=2)
- Images: `C:\Users\Dell\Desktop\fresh_validation\real\own_new_photos`

## Comparison (measured)

| Evaluator | Ready | OK | Mean ms | Median ms | P95 ms | Init ms | Process RSS mean MB | Process CPU mean % | Docker CPU mean % | Docker mem |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| EfficientNet-B0 (local PyTorch) | True | 10 | 209.85 | 211.22 | 249.35 | 6169.28 | n/a | n/a | n/a | n/a |
| MUSIQ + OpenCV (Docker worker) | True | 10 | 4776.27 | 4651.86 | 5966.88 | 108.47 | n/a | n/a | 4.09 | 3.602GiB / 7.646GiB |
| OpenCV-only (local fallback) | True | 10 | 4888.84 | 5133.62 | 5229.48 | 7382.57 | n/a | n/a | n/a | n/a |

## Resource separation

- FastAPI/benchmark process RSS after: `None` MB
- System RAM after: `{"total_mb": null, "used_mb": null, "available_mb": null, "percent": null}`
- Docker worker stats after: `{"container": "musiq_worker-musiq-worker-1", "raw": "musiq_worker-musiq-worker-1\t0.20%\t3.602GiB / 7.646GiB\t47.11%", "cpu_perc_str": "0.20%", "mem_usage_str": "3.602GiB / 7.646GiB", "mem_perc_str": "47.11%", "cpu_percent": 0.2}`

## Recommendation

- **Architecture:** QUALITY_ENGINE=musiq_worker with fallback EfficientNet-B0 then local OpenCV
- **Fastest mean latency:** `efficientnet_b0`
- **Rationale:** Fastest mean latency among successful engines: EfficientNet-B0 (local PyTorch) (209.8 ms). MUSIQ path adds Docker worker RAM/CPU separate from the FastAPI process; worker mem sample=3.602GiB / 7.646GiB, worker CPU mean%=4.094. Keep MUSIQ OPQ as overall perceptual context only; individual 1-5 criteria remain classical OpenCV (adapter) + FastAPI color/temporal. Retain EfficientNet-B0 checkpoint as rollback/fallback; do not delete. MUSIQ P95 (5967 ms) is >5x ENET P95 (249 ms); consider keeping enet default for latency-sensitive paths or raise worker timeout/capacity. OpenCV-only is the lightest local fallback (mean 4888.842110006954 ms); required when both worker and ENET are unavailable.

## Notes

- MUSIQ OPQ is overall perceptual context only; it is not an individual OpenCV criterion score.
- Phase 6B research datasets were not modified.
- `.env`, Flutter, authenticity, DB records, and production scoring config were not modified.
- EfficientNet-B0 checkpoint was not deleted.
