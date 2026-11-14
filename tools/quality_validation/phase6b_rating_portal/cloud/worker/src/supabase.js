/**
 * Minimal Supabase REST + Storage helpers (server-side only).
 * Supports:
 *   - sb_secret_...  → apikey header only (NOT Authorization Bearer / JWT)
 *   - legacy eyJ... service_role JWT → apikey + Authorization Bearer
 * Never ship these keys to the Pages frontend.
 */

export function normalizeSupabaseUrl(raw) {
  let u = String(raw || "").trim().replace(/\/$/, "");
  for (const suffix of ["/rest/v1", "/storage/v1", "/auth/v1", "/functions/v1"]) {
    if (u.toLowerCase().endsWith(suffix)) {
      u = u.slice(0, -suffix.length).replace(/\/$/, "");
    }
  }
  return u;
}

export function resolveSupabaseKey(env) {
  const secret = String(env.SUPABASE_SECRET_KEY || "").trim();
  const legacy = String(env.SUPABASE_SERVICE_ROLE_KEY || "").trim();
  return secret || legacy || "";
}

export function detectKeyKind(key) {
  if (!key) return "missing";
  if (key.startsWith("sb_secret_")) return "sb_secret";
  if (key.startsWith("sb_publishable_")) return "sb_publishable";
  if (key.startsWith("eyJ")) return "legacy_jwt";
  return "unknown";
}

/**
 * Build headers for privileged Supabase API calls.
 * New secret keys must not be sent as Bearer JWTs (Invalid Compact JWS).
 */
export function buildSupabaseAuthHeaders(key) {
  const kind = detectKeyKind(key);
  if (kind === "missing") {
    throw new Error("supabase_key_missing");
  }
  if (kind === "sb_publishable") {
    throw new Error("supabase_publishable_key_not_allowed");
  }
  if (kind === "unknown") {
    throw new Error("supabase_key_unrecognized");
  }
  if (kind === "sb_secret") {
    return { apikey: key };
  }
  // legacy_jwt
  return {
    apikey: key,
    Authorization: `Bearer ${key}`,
  };
}

export function createSupabase(env) {
  const url = normalizeSupabaseUrl(env.SUPABASE_URL || "");
  const key = resolveSupabaseKey(env);
  const bucket = env.SUPABASE_STORAGE_BUCKET || "phase6b-indval";
  const keyKind = detectKeyKind(key);
  if (!url || !key) {
    throw new Error("supabase_not_configured");
  }
  if (keyKind === "sb_publishable" || keyKind === "unknown") {
    throw new Error(`supabase_key_unsupported:${keyKind}`);
  }

  const authHeaders = buildSupabaseAuthHeaders(key);

  function jsonHeaders(extra = {}) {
    return {
      ...authHeaders,
      "Content-Type": "application/json",
      ...extra,
    };
  }

  async function rest(path, { method = "GET", body, prefer, query } = {}) {
    const qs = query ? `?${query}` : "";
    const res = await fetch(`${url}/rest/v1/${path}${qs}`, {
      method,
      headers: jsonHeaders(prefer ? { Prefer: prefer } : {}),
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    let data = null;
    if (text) {
      try {
        data = JSON.parse(text);
      } catch {
        data = text;
      }
    }
    if (!res.ok) {
      const msg = typeof data === "object" ? JSON.stringify(data) : String(data);
      throw new Error(`supabase_rest_${res.status}:${msg.slice(0, 300)}`);
    }
    return data;
  }

  return {
    url,
    bucket,
    keyKind,

    async findEvaluatorByInviteHash(hash) {
      const rows = await rest("evaluators", {
        query: `invite_token_hash=eq.${encodeURIComponent(hash)}&select=*`,
      });
      return Array.isArray(rows) && rows[0] ? rows[0] : null;
    },

    async upsertEvaluator({ evaluator_id, invite_token_hash, display_label }) {
      await rest("evaluators", {
        method: "POST",
        prefer: "resolution=merge-duplicates,return=minimal",
        body: [{ evaluator_id, invite_token_hash, display_label }],
      });
    },

    async createSession({ session_token_hash, evaluator_id, expires_at }) {
      await rest("sessions", {
        method: "POST",
        prefer: "return=minimal",
        body: [{ session_token_hash, evaluator_id, expires_at }],
      });
    },

    async getSession(session_token_hash) {
      const rows = await rest("sessions", {
        query: `session_token_hash=eq.${encodeURIComponent(session_token_hash)}&select=*`,
      });
      return Array.isArray(rows) && rows[0] ? rows[0] : null;
    },

    async touchSession(session_token_hash) {
      await rest("sessions", {
        method: "PATCH",
        query: `session_token_hash=eq.${encodeURIComponent(session_token_hash)}`,
        prefer: "return=minimal",
        body: { last_seen_at: new Date().toISOString() },
      });
    },

    async getFinalSubmission(evaluator_id) {
      const rows = await rest("final_submissions", {
        query: `evaluator_id=eq.${encodeURIComponent(evaluator_id)}&select=*`,
      });
      return Array.isArray(rows) && rows[0] ? rows[0] : null;
    },

    async getImageRating(evaluator_id, media_id) {
      const rows = await rest("image_ratings", {
        query:
          `evaluator_id=eq.${encodeURIComponent(evaluator_id)}` +
          `&media_id=eq.${encodeURIComponent(media_id)}&select=*`,
      });
      return Array.isArray(rows) && rows[0] ? rows[0] : null;
    },

    async listImageRatings(evaluator_id) {
      const rows = await rest("image_ratings", {
        query: `evaluator_id=eq.${encodeURIComponent(evaluator_id)}&select=*`,
      });
      return Array.isArray(rows) ? rows : [];
    },

    async upsertImageRating(row) {
      await rest("image_ratings", {
        method: "POST",
        prefer: "resolution=merge-duplicates,return=minimal",
        body: [row],
      });
    },

    async lockAllRatings(evaluator_id, submitted_at) {
      await rest("image_ratings", {
        method: "PATCH",
        query: `evaluator_id=eq.${encodeURIComponent(evaluator_id)}`,
        prefer: "return=minimal",
        body: { status: "locked", submitted_at },
      });
    },

    async insertFinalSubmission({ evaluator_id, submitted_at, summary_json }) {
      await rest("final_submissions", {
        method: "POST",
        prefer: "return=minimal",
        body: [{ evaluator_id, submitted_at, summary_json }],
      });
    },

    async insertEvent(event) {
      await rest("rating_events", {
        method: "POST",
        prefer: "return=minimal",
        body: [event],
      });
    },

    async listEvaluators() {
      const rows = await rest("evaluators", {
        query: "select=evaluator_id&order=evaluator_id",
      });
      return Array.isArray(rows) ? rows.map((r) => r.evaluator_id) : [];
    },

    async createSignedUrl(objectPath, expiresIn = 120) {
      const res = await fetch(
        `${url}/storage/v1/object/sign/${bucket}/${objectPath}`,
        {
          method: "POST",
          headers: jsonHeaders(),
          body: JSON.stringify({ expiresIn }),
        }
      );
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        throw new Error(
          `storage_sign_${res.status}:${JSON.stringify(data).slice(0, 200)}`
        );
      }
      const signedPath = data.signedURL || data.signedUrl || data.path;
      if (!signedPath) throw new Error("storage_sign_missing_url");
      if (String(signedPath).startsWith("http")) return signedPath;
      return `${url}/storage/v1${String(signedPath).startsWith("/") ? "" : "/"}${signedPath}`;
    },
  };
}
