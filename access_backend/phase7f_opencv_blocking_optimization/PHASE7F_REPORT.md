# Phase 7F — OpenCV blocking vectorization

- Parity passed: **True**
- Optimized path activated: **True**
- Images: **10**
- Abs tolerance: `1e-12`

## Benchmark (measured)

- Blocking loop mean: **4865.383389996714** ms
- Blocking vectorized mean: **130.36396999668796** ms
- Blocking speedup: **37.32153439420666** x
- Full analyze (loop blocking) mean: **5303.138289996423** ms
- Full analyze (vectorized blocking) mean: **586.2163499987219** ms
- Full analyze speedup: **9.046384137883539** x

- Phase 7E blocking baseline mean: 4453.13 ms
- Phase 7E full OpenCV baseline mean: 4859.07 ms

## Notes

- No production resize/downsample.
- Loop reference retained as `_blocking_artifacts_loop_reference`.
- MUSIQ worker, authenticity, Flutter, XP, DB, `.env` untouched.
