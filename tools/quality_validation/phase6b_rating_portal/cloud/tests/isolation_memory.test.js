/**
 * In-memory stand-in for Supabase + Worker authorization rules.
 * Proves evaluator isolation and post-submit lock without cloud resources.
 */
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { sha256Hex } from "../worker/src/crypto.js";
import {
  mergeRatings,
  statusForRatings,
  buildProgress,
  emptyRating,
  exportWideRows,
  toCsv,
} from "../worker/src/ratings.js";
import { CRITERION_IDS, IMAGE_IDS } from "../worker/src/rubric.js";

function createMemoryDb() {
  const evaluators = new Map();
  const sessions = new Map();
  const ratings = new Map(); // key evaluator|media
  const finals = new Map();

  return {
    async seedEvaluator(id, invitePlain) {
      evaluators.set(id, {
        evaluator_id: id,
        invite_token_hash: await sha256Hex(invitePlain),
        display_label: id,
      });
    },
    async exchange(invitePlain) {
      const hash = await sha256Hex(invitePlain);
      for (const ev of evaluators.values()) {
        if (ev.invite_token_hash === hash) {
          const token = `sess-${ev.evaluator_id}-${Math.random()}`;
          sessions.set(await sha256Hex(token), { evaluator_id: ev.evaluator_id });
          return { session_token: token, evaluator_id: ev.evaluator_id };
        }
      }
      throw new Error("invalid_invite");
    },
    async requireSession(token) {
      const s = sessions.get(await sha256Hex(token));
      if (!s) throw new Error("invalid_session");
      return s.evaluator_id;
    },
    key(eid, mid) {
      return `${eid}|${mid}`;
    },
    async save(eid, mid, incoming) {
      if (finals.has(eid)) throw new Error("final_submission_locked");
      const prev = ratings.get(this.key(eid, mid)) || emptyRating(mid);
      const merged = mergeRatings(prev.ratings, incoming);
      const row = {
        media_id: mid,
        status: statusForRatings(merged),
        ratings_json: merged,
        notes: "",
        updated_at: new Date().toISOString(),
      };
      ratings.set(this.key(eid, mid), row);
      return row;
    },
    get(eid, mid) {
      return ratings.get(this.key(eid, mid)) || null;
    },
    progress(eid) {
      const byId = {};
      for (const mid of IMAGE_IDS) {
        const row = this.get(eid, mid);
        if (row) byId[mid] = row;
      }
      return buildProgress(byId, finals.get(eid) || null);
    },
    finalize(eid) {
      if (finals.has(eid)) throw new Error("already_submitted");
      const p = this.progress(eid);
      if (p.n_complete < p.n_images) throw new Error("incomplete_ratings");
      finals.set(eid, { submitted_at: new Date().toISOString() });
      for (const mid of IMAGE_IDS) {
        const row = this.get(eid, mid);
        if (row) {
          row.status = "locked";
          ratings.set(this.key(eid, mid), row);
        }
      }
    },
  };
}

describe("server-side evaluator isolation (memory)", () => {
  it("R1 ratings are invisible to R2 session", async () => {
    const db = createMemoryDb();
    await db.seedEvaluator("R1", "invite-r1-secret");
    await db.seedEvaluator("R2", "invite-r2-secret");
    const a = await db.exchange("invite-r1-secret");
    const b = await db.exchange("invite-r2-secret");
    const e1 = await db.requireSession(a.session_token);
    const e2 = await db.requireSession(b.session_token);
    await db.save(e1, "INDVAL-001", { sharpness: 5 });
    assert.equal(db.get(e1, "INDVAL-001").ratings_json.sharpness, 5);
    assert.equal(db.get(e2, "INDVAL-001"), null);
  });

  it("blocks edits after final submit", async () => {
    const db = createMemoryDb();
    await db.seedEvaluator("R1", "invite-r1-secret");
    const a = await db.exchange("invite-r1-secret");
    const e1 = await db.requireSession(a.session_token);
    const full = Object.fromEntries(CRITERION_IDS.map((c) => [c, 3]));
    for (const mid of IMAGE_IDS) {
      await db.save(e1, mid, full);
    }
    db.finalize(e1);
    await assert.rejects(
      async () => db.save(e1, "INDVAL-001", { sharpness: 1 }),
      /final_submission_locked/
    );
  });

  it("rejects wrong invite", async () => {
    const db = createMemoryDb();
    await db.seedEvaluator("R1", "invite-r1-secret");
    await assert.rejects(() => db.exchange("wrong"), /invalid_invite/);
  });

  it("export csv only includes caller-selected evaluator rows content", async () => {
    const db = createMemoryDb();
    await db.seedEvaluator("R1", "invite-r1-secret");
    await db.seedEvaluator("R2", "invite-r2-secret");
    const a = await db.exchange("invite-r1-secret");
    const e1 = await db.requireSession(a.session_token);
    await db.save(e1, "INDVAL-002", { sharpness: 2, blur: 2 });
    const csv = toCsv(
      exportWideRows(["R1"], (eid, mid) => {
        const row = db.get(eid, mid);
        if (!row) return emptyRating(mid);
        return {
          media_id: mid,
          status: row.status,
          ratings: row.ratings_json,
          notes: "",
          updated_at: row.updated_at,
        };
      })
    );
    assert.match(csv, /INDVAL-002,R1,photo,2,2/);
    assert.doesNotMatch(csv, /,R2,/);
  });
});
