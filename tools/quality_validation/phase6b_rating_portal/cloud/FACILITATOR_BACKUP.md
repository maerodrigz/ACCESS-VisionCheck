# Facilitator backup & Free-tier pause guidance

## Backup

1. Export CSV after meaningful progress:

```powershell
curl.exe -fsS -H "X-Facilitator-Token: $env:FACILITATOR_TOKEN" `
  "https://YOUR-WORKER.workers.dev/api/facilitator/export.csv?evaluator_id=R1" -o ratings_R1.csv
```

2. Keep offline copies outside Supabase (Drive / encrypted USB).
3. Local Phase 6A `rater_pack/images` remains the image master; Storage is a deploy copy.
4. Free Supabase has no PITR — CSV is the recovery path for human scores.

## Inactivity pause

Supabase Free may pause after ~7 days idle. Before the study goes quiet:

- Calendar reminder to open Worker `/api/health` weekly, or
- Upgrade research project to Pro, or  
- Accept that you must unpause manually before raters continue.

After unpause: verify health, one invite exchange, one signed image load, then notify evaluators.
