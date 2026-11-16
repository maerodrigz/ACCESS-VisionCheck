# MUSIQ worker — model and training-data license notes

**Do not publicly deploy until counsel reviews commercial use.**

## Weights artifact used by this worker

| Item | Value |
|------|-------|
| Handle | `https://tfhub.dev/google/musiq/paq2piq/1` |
| Kaggle page | `google/musiq` → TensorFlow2 / paq2piq / 1 |
| Declared license on TF Hub / Kaggle | **Apache License 2.0** |
| Declared output range | **[0, 100]** |
| Model id in API | `tfhub:google/musiq/paq2piq/1` |
| Signature (verified on Colab) | input `image_bytes_tensor` (`tf.string`) → `output_0` (`tf.float32`) |

This is the official Google MUSIQ PaQ-2-PiQ SavedModel export. It is **not** the pyiqa `.pth` (PolyForm-Noncommercial).

## Source code (google-research musiq)

Apache 2.0 covers the research Python sources. That does **not** automatically license every checkpoint in GCS.

## GCS npz checkpoints

`gs://gresearch/musiq/paq2piq_ckpt.npz` and siblings have **no** LICENSE/NOTICE object in the bucket listing. This worker **does not** download or ship those `.npz` files.

## Training-data caveat (important)

PaQ-2-PiQ / FLIVE upstream dataset/code (`baidut/PaQ-2-PiQ`) is labeled **CC BY-NC-SA 4.0**. That is a separate training-data term. The TF Hub Apache label on the export does not erase counsel’s need to review **commercial** use of a model trained on NC-SA data.

## ACCESS policy for this phase

- Research and private backend-to-worker inference of the TF Hub Apache-labeled SavedModel is in scope for staging.
- Do not embed weights into the Flutter app or public CDN without legal sign-off.
- Keep `QUALITY_ENGINE=enet` until cutover is explicitly approved.
