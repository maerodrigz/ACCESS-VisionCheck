# Phase 7G — MUSIQ cutover verification

- Cutover ready (tests only; .env NOT flipped): **True**
- Production cutover activated: **False**
- Vectorized blocking: **True**

## Gates

- `vectorized_blocking_enabled`: **True**
- `enet_weights_retained`: **True**
- `photo_musiq_online_ok`: **True**
- `photo_offline_opencv_fallback_ok`: **True**
- `rollback_enet_ok`: **True**
- `flutter_compat_labels_present`: **True**

## Blockers

- None

## Rollback

- Keep `QUALITY_ENGINE=enet` in `.env` (current) to stay on EfficientNet.
- After a future cutover, roll back by setting `QUALITY_ENGINE=enet` and restarting FastAPI.
- ENET weights: `access_backend/ml/efficientnet_b0_heads.pt` (not deleted).

## Architecture under test

1. Primary: `musiq_worker`
2. Fallback: optimized local `opencv`
3. EfficientNet inactive on musiq path; available when `QUALITY_ENGINE=enet`
