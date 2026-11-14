/** Locked Phase 6B rubric wrapper. Data auto-generated from app/criteria.py. */
import { RUBRIC } from "./rubric_data.js";

export const CRITERIA = RUBRIC.criteria;
export const SCALE_LABELS = RUBRIC.scale_labels;
export const CRITERION_IDS = RUBRIC.criterion_ids;
export const IMAGE_IDS = RUBRIC.image_ids;
export const N_IMAGES = RUBRIC.n_images;

export function metaPayload() {
  return {
    criteria: CRITERIA,
    scale_labels: Object.fromEntries(
      Object.entries(SCALE_LABELS).map(([k, v]) => [Number(k), v])
    ),
    na_label: RUBRIC.na_label || {
      code: "N/A",
      bisaya: "Dili applicable",
      en: "Cannot judge. Do not guess. Never use 3 as unknown.",
    },
    n_images: N_IMAGES,
    image_ids: IMAGE_IDS,
    notes: [
      "Higher always means better quality, including blur/noise/blocking/ringing.",
      "Score 2: obvious defect; a retake would normally be required (locked rubric).",
      "Score 3: subject identifiable but defect clearly visible; below a strong submission.",
      "Overall is independent of the mean of the seven technical scores.",
      "N/A is allowed when a criterion cannot be judged. Never use 3 for unknown.",
      "Machine scores and source identities are not available in this portal.",
    ],
  };
}
