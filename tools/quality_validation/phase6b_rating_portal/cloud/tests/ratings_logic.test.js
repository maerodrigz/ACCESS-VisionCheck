import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  mergeRatings,
  statusForRatings,
  buildProgress,
  exportWideRows,
  toCsv,
  emptyRating,
  countFilled,
} from "../worker/src/ratings.js";
import { CRITERION_IDS, IMAGE_IDS } from "../worker/src/rubric.js";
import { sha256Hex, timingSafeEqual } from "../worker/src/crypto.js";

describe("rubric integrity", () => {
  it("keeps eight criteria and 100 images", () => {
    assert.equal(CRITERION_IDS.length, 8);
    assert.equal(IMAGE_IDS.length, 100);
    assert.equal(IMAGE_IDS[0], "INDVAL-001");
    assert.equal(IMAGE_IDS[99], "INDVAL-100");
  });
});

describe("mergeRatings + isolation shape", () => {
  it("merges valid scores and rejects out of range", () => {
    const m = mergeRatings({}, { sharpness: 4, blur: "N/A" });
    assert.equal(m.sharpness, 4);
    assert.equal(m.blur, "N/A");
    assert.throws(() => mergeRatings({}, { sharpness: 9 }), /rating_out_of_range/);
    assert.throws(() => mergeRatings({}, { not_a_field: 1 }), /unknown_criterion/);
  });

  it("status transitions", () => {
    assert.equal(statusForRatings({}), "empty");
    assert.equal(statusForRatings({ sharpness: 3 }), "partial");
    const full = Object.fromEntries(CRITERION_IDS.map((c) => [c, 3]));
    assert.equal(statusForRatings(full), "complete");
    assert.equal(countFilled(full), 8);
  });
});

describe("progress + final lock semantics", () => {
  it("builds progress without leaking other evaluators", () => {
    const rows = {
      "INDVAL-001": {
        media_id: "INDVAL-001",
        status: "partial",
        ratings_json: { sharpness: 2 },
      },
    };
    const p = buildProgress(rows, null);
    assert.equal(p.n_partial, 1);
    assert.equal(p.n_complete, 0);
    assert.equal(p.final_submitted, false);
    const locked = buildProgress(rows, { submitted_at: "2026-01-01T00:00:00Z" });
    assert.equal(locked.final_submitted, true);
  });
});

describe("CSV consensus compatibility", () => {
  it("emits Phase 6A wide header and N/A temporal fields", () => {
    const rows = exportWideRows(["R1"], (eid, mid) => {
      if (mid === "INDVAL-001") {
        return {
          media_id: mid,
          status: "complete",
          ratings: Object.fromEntries(CRITERION_IDS.map((c) => [c, 4])),
          notes: "",
          updated_at: "t",
        };
      }
      return emptyRating(mid);
    });
    const csv = toCsv(rows);
    assert.match(csv, /^media_id,rater_id,media_type,sharpness/);
    assert.match(csv, /INDVAL-001,R1,photo,4/);
    assert.match(csv, /,N\/A,N\/A,/);
    assert.equal(rows.length, 100);
  });
});

describe("crypto", () => {
  it("hashes and compares", async () => {
    const a = await sha256Hex("invite-token-example");
    const b = await sha256Hex("invite-token-example");
    assert.equal(a, b);
    assert.equal(a.length, 64);
    assert.equal(timingSafeEqual("abc", "abc"), true);
    assert.equal(timingSafeEqual("abc", "abd"), false);
  });
});
