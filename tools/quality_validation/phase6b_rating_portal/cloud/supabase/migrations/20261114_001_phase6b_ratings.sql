-- Phase 6B research ratings schema (separate Supabase project from production ACCESS).
-- Version: 20261114_001
-- Apply via Supabase SQL editor or CLI. Do not run against production ACCESS DB.

create extension if not exists pgcrypto;

create table if not exists evaluators (
  evaluator_id text primary key check (evaluator_id in ('R1', 'R2', 'R3')),
  invite_token_hash text not null unique,
  display_label text not null,
  created_at timestamptz not null default now()
);

create table if not exists sessions (
  session_token_hash text primary key,
  evaluator_id text not null references evaluators (evaluator_id) on delete cascade,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create index if not exists sessions_evaluator_id_idx on sessions (evaluator_id);

create table if not exists image_ratings (
  evaluator_id text not null references evaluators (evaluator_id) on delete cascade,
  media_id text not null check (media_id ~ '^INDVAL-[0-9]{3}$'),
  status text not null default 'in_progress'
    check (status in ('empty', 'partial', 'complete', 'in_progress', 'locked')),
  ratings_json jsonb not null default '{}'::jsonb,
  notes text not null default '',
  updated_at timestamptz not null default now(),
  submitted_at timestamptz,
  primary key (evaluator_id, media_id)
);

create table if not exists rating_events (
  id bigserial primary key,
  evaluator_id text not null,
  media_id text not null default '',
  criterion text,
  rating integer,
  event_type text not null,
  created_at timestamptz not null default now()
);

create index if not exists rating_events_evaluator_idx
  on rating_events (evaluator_id, created_at desc);

create table if not exists final_submissions (
  evaluator_id text primary key references evaluators (evaluator_id) on delete cascade,
  submitted_at timestamptz not null default now(),
  summary_json jsonb not null
);

-- Defense in depth: deny all direct PostgREST access with anon/authenticated keys.
-- The Cloudflare Worker uses the service_role key and enforces evaluator_id filters in code.
alter table evaluators enable row level security;
alter table sessions enable row level security;
alter table image_ratings enable row level security;
alter table rating_events enable row level security;
alter table final_submissions enable row level security;

-- No policies for anon/authenticated => no client direct access.
-- Service role bypasses RLS (Worker only).

comment on table evaluators is 'Phase 6B invite hashes only; never expose plaintext tokens';
comment on table image_ratings is 'Per-evaluator INDVAL ratings; isolated by evaluator_id';
