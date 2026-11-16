-- Example only. Replace hashes with SHA-256 of your real invite tokens.
-- Generate tokens with: python scripts/generate_secrets.py
-- Hash in PowerShell:
--   [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes("TOKEN"))).Replace("-","").ToLower()

-- insert into evaluators (evaluator_id, invite_token_hash, display_label) values
--   ('R1', '<sha256 of R1 invite>', 'R1'),
--   ('R2', '<sha256 of R2 invite>', 'R2'),
--   ('R3', '<sha256 of R3 invite>', 'R3')
-- on conflict (evaluator_id) do update
--   set invite_token_hash = excluded.invite_token_hash,
--       display_label = excluded.display_label;

select 'Replace this example with real invite hashes before applying' as notice;
