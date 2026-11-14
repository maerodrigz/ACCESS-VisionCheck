/** Rating domain logic (shared by Worker and tests). */

import { CRITERION_IDS, IMAGE_IDS } from "./rubric.js";

export function emptyRating(mediaId) {
  return {
    media_id: mediaId,
    status: "empty",
    ratings: {},
    notes: "",
    updated_at: null,
    submitted_at: null,
  };
}

export function rowToRating(row) {
  if (!row) return null;
  const ratings =
    typeof row.ratings_json === "string"
      ? JSON.parse(row.ratings_json || "{}")
      : row.ratings_json || {};
  return {
    media_id: row.media_id,
    status: row.status || "empty",
    ratings,
    notes: row.notes || "",
    updated_at: row.updated_at || null,
    submitted_at: row.submitted_at || null,
  };
}

export function countFilled(ratings) {
  let n = 0;
  for (const c of CRITERION_IDS) {
    const v = ratings?.[c];
    if (v === "N/A" || v === 1 || v === 2 || v === 3 || v === 4 || v === 5) n += 1;
  }
  return n;
}

export function mergeRatings(existing, incoming) {
  const merged = { ...(existing || {}) };
  for (const [key, val] of Object.entries(incoming || {})) {
    if (!CRITERION_IDS.includes(key)) {
      throw new Error(`unknown_criterion:${key}`);
    }
    if (val === null || val === "") {
      delete merged[key];
      continue;
    }
    if (val === "N/A") {
      merged[key] = "N/A";
      continue;
    }
    const iv = Number(val);
    if (![1, 2, 3, 4, 5].includes(iv)) throw new Error("rating_out_of_range");
    merged[key] = iv;
  }
  return merged;
}

export function statusForRatings(merged) {
  const filled = countFilled(merged);
  if (filled === CRITERION_IDS.length) return "complete";
  if (filled > 0) return "partial";
  return "empty";
}

export function buildProgress(imageRowsById, finalSubmission) {
  let complete = 0;
  let partial = 0;
  const images = IMAGE_IDS.map((mid) => {
    const row = imageRowsById[mid];
    const ratings = row
      ? typeof row.ratings_json === "string"
        ? JSON.parse(row.ratings_json || "{}")
        : row.ratings_json || {}
      : {};
    const filled = countFilled(ratings);
    let status = row?.status || "empty";
    if (filled === CRITERION_IDS.length) {
      status = status === "locked" ? "locked" : "complete";
      complete += 1;
    } else if (filled > 0) {
      status = "partial";
      partial += 1;
    } else {
      status = "empty";
    }
    return {
      media_id: mid,
      status,
      filled_criteria: filled,
      total_criteria: CRITERION_IDS.length,
    };
  });
  return {
    n_images: IMAGE_IDS.length,
    n_complete: complete,
    n_partial: partial,
    n_empty: IMAGE_IDS.length - complete - partial,
    final_submitted: !!finalSubmission,
    final_submitted_at: finalSubmission?.submitted_at || null,
    images,
  };
}

export function exportWideRows(evaluatorIds, getRatingFn) {
  const rows = [];
  for (const eid of evaluatorIds) {
    for (const mid of IMAGE_IDS) {
      const rec = getRatingFn(eid, mid) || emptyRating(mid);
      const ratings = rec.ratings || {};
      rows.push({
        media_id: mid,
        rater_id: eid,
        media_type: "photo",
        sharpness: ratings.sharpness ?? "",
        blur: ratings.blur ?? "",
        noise: ratings.noise ?? "",
        brightness: ratings.brightness ?? "",
        contrast: ratings.contrast ?? "",
        blocking_artifacts: ratings.blocking_artifacts ?? "",
        ringing_artifacts: ratings.ringing_artifacts ?? "",
        flickering: "N/A",
        motion_stability: "N/A",
        overall_visual_quality: ratings.overall_visual_quality ?? "",
        notes: rec.notes || "",
        updated_at: rec.updated_at || "",
        image_status: rec.status || "",
      });
    }
  }
  return rows;
}

export function toCsv(rows) {
  const fields = [
    "media_id",
    "rater_id",
    "media_type",
    "sharpness",
    "blur",
    "noise",
    "brightness",
    "contrast",
    "blocking_artifacts",
    "ringing_artifacts",
    "flickering",
    "motion_stability",
    "overall_visual_quality",
    "notes",
    "updated_at",
    "image_status",
  ];
  const esc = (v) => {
    const s = String(v ?? "");
    if (/[",\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
    return s;
  };
  const lines = [fields.join(",")];
  for (const row of rows) lines.push(fields.map((f) => esc(row[f])).join(","));
  return lines.join("\n") + "\n";
}
