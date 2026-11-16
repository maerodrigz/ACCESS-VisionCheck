-- ACCESS VisionCheck
-- Migration: media_evaluations_nullable_scores
-- Purpose: allow failed quality evaluations to store NULL scores
--          instead of invented placeholders such as 0.5.
-- Scope: ALTER media_evaluations only. No data rewrites.
-- Safe to re-run: PostgreSQL DROP NOT NULL on an already-nullable column is a no-op.

BEGIN;

ALTER TABLE media_evaluations ALTER COLUMN sharpness_score DROP NOT NULL;
ALTER TABLE media_evaluations ALTER COLUMN brightness_score DROP NOT NULL;
ALTER TABLE media_evaluations ALTER COLUMN contrast_score DROP NOT NULL;
ALTER TABLE media_evaluations ALTER COLUMN blur_score DROP NOT NULL;
ALTER TABLE media_evaluations ALTER COLUMN noise_score DROP NOT NULL;
ALTER TABLE media_evaluations ALTER COLUMN overall_score DROP NOT NULL;

COMMIT;
