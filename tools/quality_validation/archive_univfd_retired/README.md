# UnivFD — archived / retired

UnivFD (CLIP ViT-L/14 + fc_weights) was permanently removed from ACCESS VisionCheck
production authenticity detection (2026-11).

## Production path now
- Photos: PROBE-DINOv2 (AI_DETECTOR_BACKEND=probe)
- Practice videos: WaveRep G4 when WAVEREP_ENABLED=true

## Removed from tree
- access_backend/app/services/univfd/
- access_backend/ml/univfd/fc_weights.pth
- access_backend/ml/univfd/ViT-L-14.pt (~890 MB)

Historical evaluation rows may still store detector_backend=univfd; UIs label them historical.
