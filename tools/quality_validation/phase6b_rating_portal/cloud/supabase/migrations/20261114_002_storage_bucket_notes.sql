-- Phase 6B storage notes (manual / dashboard complementary steps).
-- Version: 20261114_002
--
-- Create a PRIVATE bucket named: phase6b-indval
-- Object keys: INDVAL-001.jpg … INDVAL-100.jpg
-- Do NOT enable public access.
--
-- Recommended via Dashboard → Storage → New bucket → Public: OFF
-- Or Management API with service role (see cloud/scripts/upload_indval_images.ps1).
--
-- Storage RLS: leave default deny for anon. Only service_role creates signed URLs
-- after the Worker validates an evaluator session.
--
-- This file intentionally contains no destructive DDL. Bucket creation is
-- environment-specific and must be done by the facilitator during setup.

select 'Apply bucket creation outside SQL if required; see DEPLOY_CLOUDFLARE_SUPABASE.md'
  as phase6b_storage_note;
