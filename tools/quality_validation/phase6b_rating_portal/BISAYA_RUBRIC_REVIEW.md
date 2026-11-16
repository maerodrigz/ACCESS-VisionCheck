# Phase 6B — Modern Bisaya UI copy vs locked rubric

**Status:** Bisaya labels/prompts **updated 2026-11-14** to match locked English anchors.  
**Locked source of truth:** Phase 6A `HUMAN_RATING_RUBRIC.md`.  
**UI rule:** English rubric text remains visible beside Bisaya (prompts + tooltips).

Scale direction unchanged: **1 = poorest, 5 = best**. Higher always means better, including blur, noise, blocking, and ringing.

---

## Finalized scale labels

| Score | Locked English | Locked English anchor | Final Bisaya label | Bisaya anchor (portal) |
|---:|---|---|---|---|
| 1 | Poor | Unusable for club documentation. Defect dominates the subject. | **Grabe ang problema** | Dili magamit alang sa club documentation; depekto nag-dominate sa subject. |
| 2 | Needs improvement | Obvious defect. **A retake would normally be required.** | **Dako ang problema** | Klaro ang depekto. **Kasagaran kinahanglan og retake / usab nga kuha.** |
| 3 | Fair | Subject identifiable, but defect **clearly visible** and below a strong submission. | **Naay makita nga problema** | Makilala pa ang subject, pero **klaro gihapon ang depekto** ug ubos pa sa strong submission. |
| 4 | Good | Only minor issues. Suitable for ACCESS documentation. | **Maayo ang quality** | Gamay ra ang isyu. Angay na para sa ACCESS documentation. |
| 5 | Excellent | No meaningful defect at normal viewing and at 100% crop. | **Maayo kaayo ang quality** | Walay meaningful nga depekto sa normal view ug 100% crop. |

---

## Criterion prompt alignment

| Criterion | Restored / preserved locked meaning in Bisaya |
|---|---|
| Sharpness | **Intended subject**; fine detail/edge texture; excludes brightness/contrast/noise/blocking/ringing |
| Blur | Freedom from motion/defocus on subject; higher = less blur; vs sharpness distinction noted |
| Noise | Freedom from grain/speckle hiding subject; excludes blocking/ringing |
| Brightness | **Important/intended subject** exposure; rate subject **not** artistic background |
| Contrast | Usable tonal separation; not harsh clipping as main look |
| Blocking | Compression squares in **flat regions** (sky, walls, skin); inspect flats not only edges |
| Ringing | Halos/ghost ridges on high-contrast edges; excludes blur/blocking |
| Overall | Independent documentation usefulness; **do not force equal to mean** of seven technical scores |

---

## Residual notes (optional facilitator polish only)

These are **not** blockers for collecting ratings; meaning now tracks the locked rubric:

1. Bisaya still uses some English loanwords (`subject`, `retake`, `crop`, `documentation`, `blocking`) for precision with raters who already saw the English pilot rubric.
2. Score-circle tooltips show the full English anchor; long Bisaya anchors are also in `aria-label` / API meta.
3. If facilitators want fully Bisaya-only loanword replacements later, edit `app/criteria.py` and restart the portal **before** invites go out (do not change labels mid-collection).

**No remaining meaning conflicts** that require blocking approval before UI use. Optional wording polish only.

---

## Portal safeguards

- Circular 1–5 controls + N/A retained
- English locked prompt under each Bisaya prompt
- Banner states score 2 ≈ retake normally required; score 3 still has visible defects
- Never use 3 for unknown (use N/A)
- No fabricated ratings; no production model / freeze dataset changes
