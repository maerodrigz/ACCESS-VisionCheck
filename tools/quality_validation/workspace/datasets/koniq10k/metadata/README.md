# KonIQ-10k metadata (place official files here)

Official scores file: `koniq10k_scores_and_distributions.tab` (CSV also accepted).

Documented headers (MMSP Konstanz / DaRUS):

- `image_name`
- `c1` … `c5` (counts per ACR category, not individual rater IDs)
- `c_total`
- `MOS` (5-point ACR mean)
- `SD`
- `MOS_zscore` (user-normalized scores; **not** the 1–5 ACR MOS)

Source: https://database.mmsp-kn.de/koniq-10k-database.html  
DaRUS: https://doi.org/10.18419/DARUS-2435

`MOS` is an **aggregate** Mean Opinion Score. Do not treat it as three ACCESS human raters. Do not expand it into Sharpness/Blur/Noise criteria.
