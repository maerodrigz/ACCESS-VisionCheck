/** WebCrypto helpers for Workers / Node tests. */

export async function sha256Hex(value) {
  const data = new TextEncoder().encode(String(value));
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function randomToken(bytes = 32) {
  const arr = new Uint8Array(bytes);
  crypto.getRandomValues(arr);
  let s = "";
  for (const b of arr) s += String.fromCharCode(b);
  // base64url
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

export function timingSafeEqual(a, b) {
  const aa = String(a || "");
  const bb = String(b || "");
  if (aa.length !== bb.length) return false;
  let out = 0;
  for (let i = 0; i < aa.length; i++) out |= aa.charCodeAt(i) ^ bb.charCodeAt(i);
  return out === 0;
}
