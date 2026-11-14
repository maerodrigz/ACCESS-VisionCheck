/**
 * Phase 6B Cloudflare Worker API.
 * Secrets (SUPABASE_SECRET_KEY / legacy service_role, FACILITATOR_TOKEN)
 * stay in Worker env — never in Pages.
 */

import { sha256Hex, randomToken, timingSafeEqual } from "./crypto.js";
import {
  createSupabase,
  detectKeyKind,
  normalizeSupabaseUrl,
  resolveSupabaseKey,
} from "./supabase.js";
import { metaPayload, IMAGE_IDS } from "./rubric.js";
import {
  emptyRating,
  rowToRating,
  mergeRatings,
  statusForRatings,
  buildProgress,
  exportWideRows,
  toCsv,
} from "./ratings.js";

const SESSION_TTL_HOURS = 72;
const SIGNED_URL_TTL_SEC = 120;

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders(),
      ...extraHeaders,
    },
  });
}

function text(body, status = 200, contentType = "text/plain; charset=utf-8") {
  return new Response(body, {
    status,
    headers: { "Content-Type": contentType, ...corsHeaders() },
  });
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "Content-Type, Authorization, X-Session-Token, X-Facilitator-Token",
    "Access-Control-Allow-Methods": "GET,PUT,POST,OPTIONS",
  };
}

function sessionTokenFrom(request) {
  const h = request.headers.get("X-Session-Token");
  if (h) return h.trim();
  const auth = request.headers.get("Authorization") || "";
  if (auth.toLowerCase().startsWith("bearer ")) return auth.slice(7).trim();
  return "";
}

function facilitatorTokenFrom(request) {
  const h = request.headers.get("X-Facilitator-Token");
  if (h) return h.trim();
  const auth = request.headers.get("Authorization") || "";
  if (auth.toLowerCase().startsWith("bearer ")) return auth.slice(7).trim();
  return "";
}

async function requireEvaluator(request, db) {
  const token = sessionTokenFrom(request);
  if (!token) return { error: json({ detail: "missing_session" }, 401) };
  const hash = await sha256Hex(token);
  const session = await db.getSession(hash);
  if (!session) return { error: json({ detail: "invalid_session" }, 401) };
  if (session.expires_at && new Date(session.expires_at).getTime() < Date.now()) {
    return { error: json({ detail: "session_expired" }, 401) };
  }
  await db.touchSession(hash);
  return { session, evaluator_id: session.evaluator_id };
}

function requireFacilitator(request, env) {
  const expected = (env.FACILITATOR_TOKEN || "").trim();
  if (!expected) return { error: json({ detail: "facilitator_token_not_configured" }, 503) };
  const got = facilitatorTokenFrom(request);
  if (!got || !timingSafeEqual(got, expected)) {
    return { error: json({ detail: "facilitator_forbidden" }, 403) };
  }
  return { ok: true };
}

async function progressFor(db, evaluatorId) {
  const rows = await db.listImageRatings(evaluatorId);
  const byId = Object.fromEntries(rows.map((r) => [r.media_id, r]));
  const finalSub = await db.getFinalSubmission(evaluatorId);
  return buildProgress(byId, finalSub);
}

async function getRatingView(db, evaluatorId, mediaId) {
  const row = await db.getImageRating(evaluatorId, mediaId);
  return rowToRating(row) || emptyRating(mediaId);
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      if (path === "/api/health" && request.method === "GET") {
        const keyKind = detectKeyKind(resolveSupabaseKey(env));
        const urlConfigured = Boolean(normalizeSupabaseUrl(env.SUPABASE_URL || ""));
        return json({
          status: "ok",
          service: "phase6b-rating-portal-worker",
          version: "1.1.0",
          persistence: "supabase_postgres",
          musiq_worker_required: false,
          production_quality_engine_untouched: true,
          storage_bucket: env.SUPABASE_STORAGE_BUCKET || "phase6b-indval",
          supabase_url_configured: urlConfigured,
          supabase_key_kind: keyKind, // never returns the key value
          supabase_auth_mode:
            keyKind === "sb_secret"
              ? "apikey_header_only"
              : keyKind === "legacy_jwt"
                ? "apikey_and_bearer_jwt"
                : "unconfigured_or_unsupported",
        });
      }

      if (path === "/api/meta" && request.method === "GET") {
        return json(metaPayload());
      }

      const db = createSupabase(env);

      if (path === "/api/auth/exchange" && request.method === "POST") {
        const body = await request.json();
        const invite = String(body.invite_token || "").trim();
        if (invite.length < 8) return json({ detail: "invalid_invite" }, 401);
        const hash = await sha256Hex(invite);
        const evaluator = await db.findEvaluatorByInviteHash(hash);
        if (!evaluator) return json({ detail: "invalid_invite" }, 401);
        const sessionPlain = randomToken(32);
        const expires = new Date(Date.now() + SESSION_TTL_HOURS * 3600 * 1000).toISOString();
        await db.createSession({
          session_token_hash: await sha256Hex(sessionPlain),
          evaluator_id: evaluator.evaluator_id,
          expires_at: expires,
        });
        const progress = await progressFor(db, evaluator.evaluator_id);
        return json({
          session_token: sessionPlain,
          evaluator_id: evaluator.evaluator_id,
          display_label: evaluator.display_label,
          final_submitted: progress.final_submitted,
          progress: {
            n_complete: progress.n_complete,
            n_images: progress.n_images,
          },
        });
      }

      if (path === "/api/me" && request.method === "GET") {
        const auth = await requireEvaluator(request, db);
        if (auth.error) return auth.error;
        const progress = await progressFor(db, auth.evaluator_id);
        return json({
          evaluator_id: auth.evaluator_id,
          display_label: auth.evaluator_id,
          progress,
        });
      }

      if (path === "/api/progress" && request.method === "GET") {
        const auth = await requireEvaluator(request, db);
        if (auth.error) return auth.error;
        return json(await progressFor(db, auth.evaluator_id));
      }

      const ratingMatch = path.match(/^\/api\/ratings\/(INDVAL-\d{3})$/);
      if (ratingMatch && request.method === "GET") {
        const auth = await requireEvaluator(request, db);
        if (auth.error) return auth.error;
        const mediaId = ratingMatch[1];
        if (!IMAGE_IDS.includes(mediaId)) return json({ detail: "unknown_media" }, 404);
        return json(await getRatingView(db, auth.evaluator_id, mediaId));
      }

      if (ratingMatch && request.method === "PUT") {
        const auth = await requireEvaluator(request, db);
        if (auth.error) return auth.error;
        const mediaId = ratingMatch[1];
        if (!IMAGE_IDS.includes(mediaId)) return json({ detail: "unknown_media" }, 404);
        const finalSub = await db.getFinalSubmission(auth.evaluator_id);
        if (finalSub) return json({ detail: "final_submission_locked" }, 409);
        const body = await request.json();
        if (body.media_id !== mediaId) return json({ detail: "media_id_mismatch" }, 400);
        const existing = await getRatingView(db, auth.evaluator_id, mediaId);
        let merged;
        try {
          merged = mergeRatings(existing.ratings, body.ratings || {});
        } catch (e) {
          return json({ detail: String(e.message || e) }, 400);
        }
        const status = statusForRatings(merged);
        const now = new Date().toISOString();
        await db.upsertImageRating({
          evaluator_id: auth.evaluator_id,
          media_id: mediaId,
          status,
          ratings_json: merged,
          notes: body.notes || "",
          updated_at: now,
          submitted_at: null,
        });
        await db.insertEvent({
          evaluator_id: auth.evaluator_id,
          media_id: mediaId,
          criterion: null,
          rating: null,
          event_type: "autosave",
          created_at: now,
        });
        const saved = await getRatingView(db, auth.evaluator_id, mediaId);
        const progress = await progressFor(db, auth.evaluator_id);
        return json({ saved, progress });
      }

      if (path === "/api/submit" && request.method === "POST") {
        const auth = await requireEvaluator(request, db);
        if (auth.error) return auth.error;
        if (await db.getFinalSubmission(auth.evaluator_id)) {
          return json({ detail: "already_submitted" }, 409);
        }
        const progress = await progressFor(db, auth.evaluator_id);
        if (progress.n_complete < progress.n_images) {
          return json({ detail: "incomplete_ratings" }, 400);
        }
        const now = new Date().toISOString();
        const summary = {
          n_images: progress.n_images,
          n_complete: progress.n_complete,
          submitted_at: now,
        };
        await db.insertFinalSubmission({
          evaluator_id: auth.evaluator_id,
          submitted_at: now,
          summary_json: summary,
        });
        await db.lockAllRatings(auth.evaluator_id, now);
        await db.insertEvent({
          evaluator_id: auth.evaluator_id,
          media_id: "",
          criterion: null,
          rating: null,
          event_type: "final_submit",
          created_at: now,
        });
        return json({ ok: true, summary });
      }

      const imageMatch = path.match(/^\/api\/images\/(INDVAL-\d{3})\.jpg$/);
      if (imageMatch && request.method === "GET") {
        const auth = await requireEvaluator(request, db);
        if (auth.error) return auth.error;
        const mediaId = imageMatch[1];
        if (!IMAGE_IDS.includes(mediaId)) return json({ detail: "unknown_media" }, 404);
        const signed = await db.createSignedUrl(`${mediaId}.jpg`, SIGNED_URL_TTL_SEC);
        return json({
          media_id: mediaId,
          url: signed,
          expires_in: SIGNED_URL_TTL_SEC,
          mode: "supabase_signed_url",
        });
      }

      if (path === "/api/facilitator/status" && request.method === "GET") {
        const fac = requireFacilitator(request, env);
        if (fac.error) return fac.error;
        const out = {};
        for (const eid of ["R1", "R2", "R3"]) {
          out[eid] = await progressFor(db, eid);
        }
        return json({ evaluators: out });
      }

      if (path === "/api/facilitator/export.csv" && request.method === "GET") {
        const fac = requireFacilitator(request, env);
        if (fac.error) return fac.error;
        const only = url.searchParams.get("evaluator_id");
        if (only && !["R1", "R2", "R3"].includes(only)) {
          return json({ detail: "bad_evaluator_id" }, 400);
        }
        const evals = only ? [only] : ["R1", "R2", "R3"];
        const cache = {};
        for (const eid of evals) {
          const rows = await db.listImageRatings(eid);
          cache[eid] = Object.fromEntries(
            rows.map((r) => [r.media_id, rowToRating(r) || emptyRating(r.media_id)])
          );
        }
        const wide = exportWideRows(evals, (eid, mid) => cache[eid][mid] || emptyRating(mid));
        const csv = toCsv(wide);
        const name = `ratings_${only || "ALL"}.csv`;
        return new Response(csv, {
          status: 200,
          headers: {
            "Content-Type": "text/csv; charset=utf-8",
            "Content-Disposition": `attachment; filename="${name}"`,
            ...corsHeaders(),
          },
        });
      }

      // Invite deep-link helper: Worker can redirect to Pages with token fragment.
      const inviteMatch = path.match(/^\/r\/([^/]+)$/);
      if (inviteMatch && request.method === "GET") {
        const pages = (env.PAGES_BASE_URL || "").replace(/\/$/, "");
        if (!pages) {
          return text(
            "Set PAGES_BASE_URL to the Cloudflare Pages origin. Invite token received.",
            200
          );
        }
        const tok = decodeURIComponent(inviteMatch[1]);
        return Response.redirect(`${pages}/?invite=${encodeURIComponent(tok)}`, 302);
      }

      return json({ detail: "not_found" }, 404);
    } catch (err) {
      const msg = String(err && err.message ? err.message : err);
      const status = msg.includes("supabase_not_configured") ? 503 : 500;
      return json({ detail: msg }, status);
    }
  },
};
