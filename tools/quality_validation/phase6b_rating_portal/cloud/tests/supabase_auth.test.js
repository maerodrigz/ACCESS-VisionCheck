import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  buildSupabaseAuthHeaders,
  detectKeyKind,
  normalizeSupabaseUrl,
  resolveSupabaseKey,
} from "../worker/src/supabase.js";

describe("Supabase URL normalize", () => {
  it("strips /rest/v1 and trailing slashes", () => {
    assert.equal(
      normalizeSupabaseUrl("https://abc.supabase.co/rest/v1/"),
      "https://abc.supabase.co"
    );
    assert.equal(
      normalizeSupabaseUrl("https://abc.supabase.co/storage/v1"),
      "https://abc.supabase.co"
    );
  });
});

describe("sb_secret_ auth headers", () => {
  it("uses apikey only (no Bearer)", () => {
    const h = buildSupabaseAuthHeaders("sb_secret_example_value");
    assert.equal(h.apikey, "sb_secret_example_value");
    assert.equal(h.Authorization, undefined);
    assert.equal(detectKeyKind("sb_secret_example_value"), "sb_secret");
  });

  it("uses Bearer for legacy JWT", () => {
    const jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.sig";
    const h = buildSupabaseAuthHeaders(jwt);
    assert.equal(h.apikey, jwt);
    assert.equal(h.Authorization, `Bearer ${jwt}`);
    assert.equal(detectKeyKind(jwt), "legacy_jwt");
  });

  it("rejects publishable keys", () => {
    assert.throws(
      () => buildSupabaseAuthHeaders("sb_publishable_nope"),
      /publishable/
    );
  });

  it("prefers SUPABASE_SECRET_KEY over legacy env", () => {
    const key = resolveSupabaseKey({
      SUPABASE_SECRET_KEY: "sb_secret_new",
      SUPABASE_SERVICE_ROLE_KEY: "eyJlegacy",
    });
    assert.equal(key, "sb_secret_new");
  });
});
