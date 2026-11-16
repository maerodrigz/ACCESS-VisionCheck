# Phase 7E — Image quality performance investigation

- Started: `2026-11-14T10:24:05.038594+00:00`
- Finished: `2026-11-14T10:26:02.158313+00:00`
- Images profiled: **5** from `C:\Users\Dell\Desktop\fresh_validation\real\own_new_photos`
- Mean megapixels: **14.338**
- Scoring behavior changed: **False**

## Phase 7D baseline (for context)

| Engine | Mean ms |
|---|---:|
| EfficientNet-B0 | 209.85 |
| MUSIQ + OpenCV | 4776.27 |
| Local OpenCV | 4888.84 |

## Local OpenCV step means (production `opencv_quality`)

| Step | Mean ms |
|---|---:|
| `full_analyze_bgr_ms` | 5057.05 |
| `full_analyze_image_bytes_ms` | 4859.07 |
| `blocking_artifacts_ms` | 4453.13 |
| `decode_oriented_bgr_ms` | 269.78 |
| `diagnostic_full_analyze_bgr_resized_1024_ms` | 257.26 |
| `diagnostic_blocking_after_resize_1024_ms` | 232.59 |
| `sharpness_laplacian_var_ms` | 158.88 |
| `noise_gaussian_residual_ms` | 136.56 |
| `brightness_contrast_ms` | 111.75 |
| `ringing_artifacts_ms` | 56.66 |
| `diagnostic_resize_1024_ms` | 14.08 |
| `diagnostic_ringing_after_resize_1024_ms` | 7.71 |
| `cvt_gray_ms` | 5.20 |
| `blur_from_sharpness_ms` | 0.00 |

## MUSIQ path split (measured / estimated)

- Client wall mean: **3617.998119996628** ms
- Worker `duration_ms` mean: **3558.1116** ms
- HTTP/transfer estimate (client − worker): **59.886519996627705** ms
- Classical resized proxy (local `classical_quality_from_bgr`): **311.2684799998533** ms
- MUSIQ+misc server estimate (worker − classical proxy): **3246.843120000147** ms
- ENET full mean (this run): **218.6546000011731** ms

## Findings

### `local_opencv_step_ranking`

Mean step times for production opencv_quality on native resolution.

- **ranked_mean_ms:** `[('full_analyze_bgr_ms', 5057.04918000265), ('full_analyze_image_bytes_ms', 4859.071240009507), ('blocking_artifacts_ms', 4453.12993999687), ('decode_oriented_bgr_ms', 269.77833999553695), ('sharpness_laplacian_var_ms', 158.87799999909475), ('noise_gaussian_residual_ms', 136.5598999953363), ('brightness_contrast_ms', 111.7456800013315), ('ringing_artifacts_ms', 56.657740008085966), ('cvt_gray_ms', 5.1990600128192455), ('blur_from_sharpness_ms', 0.0)]`

### `blocking_python_loop_dominates_local_opencv`

Production _blocking_artifacts uses nested Python loops over every 8x8 block at native resolution (no resize cap). This likely dominates local OpenCV latency.

- **blocking_mean_ms:** `4453.12993999687`
- **full_mean_ms:** `4859.071240009507`
- **share:** `0.9164570182321833`

### `native_vs_resize1024_diagnostic`

Diagnostic only: same opencv_quality.analyze_bgr after longest-side 1024 resize. Not a production scoring change; scores would need parity validation before adoption.

- **native_full_analyze_bgr_mean_ms:** `5057.04918000265`
- **resized_1024_full_analyze_bgr_mean_ms:** `257.25790000287816`
- **speedup_factor:** `19.65750781587688`

### `enet_fixed_224_input`

EfficientNet always resizes to 224x224 before the network. Wall time is largely decode/preprocess + small CNN forward — insensitive to multi-megapixel pixel loops.

- **enet_full_mean_ms:** `218.6546000011731`

### `musiq_path_split`

MUSIQ path client wall ≈ HTTP/transfer + worker duration. Worker classical uses RESIZE_CAP=1024; MUSIQ PaQ-2-PiQ scores original JPEG bytes (no client-side resize). musiq_plus_misc_server_est ≈ worker_duration - local classical_quality_from_bgr proxy.

- **client_wall_mean_ms:** `3617.998119996628`
- **worker_duration_mean_ms:** `3558.1116`
- **http_transfer_est_mean_ms:** `59.886519996627705`
- **classical_resized_proxy_mean_ms:** `311.2684799998533`
- **musiq_inference_plus_misc_est_mean_ms:** `3246.843120000147`

### `why_local_opencv_rivals_musiq_total`

Phase 7D showed local OpenCV (~4889 ms) similar to MUSIQ+OpenCV (~4776 ms). That is consistent with native-resolution Python blocking/ringing dominating local fallback, while the Docker path pays for large JPEG upload + TensorFlow MUSIQ but runs classical after a 1024 resize (cheaper classical).


## Safe optimization candidates (not implemented)

### `vectorize_or_cap_local_opencv_blocking_ringing`

- Risk: **medium**
- Preserves formulas if: NumPy/OpenCV vectorization of the same flat-block and ringing definitions, or applying an explicit documented resize cap with validated score parity vs baseline.
- Do not: Change variance threshold 8.0, block size 8, Canny 80/160, or soft_score bins just for speed.

### `align_local_opencv_with_worker_resize_cap_1024`

- Risk: **high_without_parity_tests**
- Preserves formulas if: Only after comparing native vs capped metrics/_soft_score outputs on a frozen image set; document any intentional resolution policy.
- Note: Worker classical already caps at 1024; local opencv_quality does not.

### `musiq_input_downscale_before_tf`

- Risk: **high_for_opq_values**
- Preserves formulas if: Never for criterion scores; OPQ is context-only but values would change — requires acceptance tests.
- Note: Would not change OpenCV criteria if classical stays on its own resize path.

### `avoid_double_decode_in_pipelines`

- Risk: **low**
- Preserves formulas if: Reuse decoded BGR across color heuristics + quality when already in memory.
- Note: Does not change numeric formulas.

### `keep_enet_as_fast_local_fallback`

- Risk: **none**
- Preserves formulas if: No change; architecture choice only.
- Note: Phase 7D/7C show ENET is ~20x faster than native local OpenCV on these photos.

## Constraints honored

- No scoring formula/threshold changes
- No `.env` / Flutter / deploy / ENET deletion
- PROBE/WaveRep, research datasets, DB records untouched
