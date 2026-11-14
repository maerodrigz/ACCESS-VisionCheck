"""Locked Phase 6A criteria + plain-language Bisaya UI copy.

English anchors match HUMAN_RATING_RUBRIC.md (Phase 6A rater pack).
Bisaya is a conversational aid; English remains visible in the portal UI.
Score values stay 1-5 and N/A. Do not change criterion ids or rating direction.
"""

from __future__ import annotations

CRITERIA = (
    {
        "id": "sharpness",
        "en_name": "Sharpness",
        "bisaya_name": "Kaklaro sa detalye",
        "bisaya_prompt": (
            "Tan-awa ang importanteng subject. Klaro ba ang gagmay nga detalye, "
            "sama sa buhok, tela, letra, o dahon? Ayaw i-rate dinhi ang kahayag, "
            "contrast, noise, blocks, o edge halo."
        ),
        "bisaya_low": "1: Nahanaw ang detalye. Dili klaro ang subject.",
        "bisaya_high": "5: Klaro kaayo ang gagmay nga detalye.",
        "en_prompt": (
            "How much fine detail and edge texture remain in the intended subject?"
        ),
        "higher_means": "more fine detail / micro-contrast on the subject",
    },
    {
        "id": "blur",
        "en_name": "Blur",
        "bisaya_name": "Pagkalabo",
        "bisaya_prompt": (
            "Naay blur ba tungod sa lihok o sayop nga focus? Mas gamay ang blur, "
            "mas taas ang score. Kung soft o streaked ang edges tungod sa lihok "
            "o focus, i-rate kini isip blur (dili sharpness)."
        ),
        "bisaya_low": "1: Grabe ang blur. Dili klaro ang subject.",
        "bisaya_high": "5: Walay blur. Klaro ang focus.",
        "en_prompt": (
            "How free is the subject of motion smear or defocus (out-of-focus) blur? "
            "Higher = less blur (clearer focus)."
        ),
        "higher_means": "fewer motion / defocus blur defects",
    },
    {
        "id": "noise",
        "en_name": "Noise",
        "bisaya_name": "Mga tuldok-tuldok",
        "bisaya_prompt": (
            "Naay mga tuldok, grain, o speckles ba nga nagtakuban sa picture? "
            "Mas limpyo, mas taas ang score. Ayaw i-apil ang JPEG squares "
            "(blocks) o edge halo."
        ),
        "bisaya_low": "1: Daghan kaayo ang tuldok-tuldok / grain.",
        "bisaya_high": "5: Limpyo. Halos walay noise.",
        "en_prompt": (
            "How free is the image of grain, speckle, or chroma splotches that hide "
            "the subject? Higher = cleaner."
        ),
        "higher_means": "fewer noise defects",
    },
    {
        "id": "brightness",
        "en_name": "Brightness",
        "bisaya_name": "Kahayag",
        "bisaya_prompt": (
            "Maayo ba ang kahayag sa importanteng subject? Dili ba sobra ngitngit "
            "o sobra hayag nga mawala ang detalye? I-rate ang subject, "
            "dili ang artistic background."
        ),
        "bisaya_low": "1: Sobra ngitngit o sobra hayag. Mawala ang detalye.",
        "bisaya_high": "5: Just right ang kahayag sa subject.",
        "en_prompt": (
            "Is the important subject well exposed? Rate the subject, not the "
            "artistic background."
        ),
        "higher_means": "better subject exposure",
    },
    {
        "id": "contrast",
        "en_name": "Contrast",
        "bisaya_name": "Kalahi-an sa hayag ug ngitngit",
        "bisaya_prompt": (
            "Klaro ba ang kalahi-an sa hayag ug ngitngit tali sa subject ug palibot? "
            "Kung luspad kaayo / foggy, o grabe ka dark/bright ang hitsura, "
            "ubos ang score."
        ),
        "bisaya_low": "1: Luspad / flat, o sobra ka harsh ang contrast.",
        "bisaya_high": "5: Maayo ang kalahi-an. Klaro ang subject.",
        "en_prompt": (
            "Is there usable tonal separation between subject and surroundings, "
            "without harsh clipping as the main look?"
        ),
        "higher_means": "clearer usable tonal separation",
    },
    {
        "id": "blocking_artifacts",
        "en_name": "Blocking artifacts",
        "bisaya_name": "Mga kuwadrado",
        "bisaya_prompt": (
            "Makita ba ang compression squares / blocky parts sa flat areas "
            "sama sa langit (sky), bungbong (walls), o panit (skin)? "
            "Tan-awa ang flat regions, dili lang ang edges. Mas gamay ang blocks, "
            "mas taas ang score."
        ),
        "bisaya_low": "1: Klaro kaayo ang mga kuwadrado / blocks.",
        "bisaya_high": "5: Walay makita nga blocks.",
        "en_prompt": (
            "Are compression squares visible in flat areas (sky, walls, skin)? "
            "Inspect flat regions, not only edges. Higher = fewer blocks."
        ),
        "higher_means": "fewer compression block defects",
    },
    {
        "id": "ringing_artifacts",
        "en_name": "Ringing artifacts",
        "bisaya_name": "Anino sa edges",
        "bisaya_prompt": (
            "Naay halo, ghost line, o doble nga outline ba palibot sa sharp edges? "
            "Mas limpyo ang edges, mas taas ang score. Ayaw i-apil ang blur o blocks."
        ),
        "bisaya_low": "1: Klaro ang halo / ghost sa edges.",
        "bisaya_high": "5: Limpyo ang edges. Walay halo.",
        "en_prompt": (
            "Are there halos or ghost ridges along high-contrast edges "
            "(sharpening or codec ringing)? Higher = cleaner edges."
        ),
        "higher_means": "fewer ringing / halo defects",
    },
    {
        "id": "overall_visual_quality",
        "en_name": "Overall visual quality",
        "bisaya_name": "Kinatibuk-ang quality",
        "bisaya_prompt": (
            "Base sa imong nakita, maayo ba ang picture para sa documentation? "
            "I-rate kini separately. Ayaw pugsang i-equal sa average sa pito "
            "ka technical scores."
        ),
        "bisaya_low": "1: Dili magamit para sa documentation.",
        "bisaya_high": "5: Maayo kaayo para sa documentation.",
        "en_prompt": (
            "Independent impression of documentation usefulness. "
            "Do not force this to equal the mean of the seven technical scores."
        ),
        "higher_means": "better overall documentation usefulness",
    },
)

# English labels/anchors locked from HUMAN_RATING_RUBRIC.md.
# Bisaya short labels are plain conversational aids (same 1-5 meaning).
SCALE_LABELS = {
    1: {
        "en": "Poor",
        "bisaya": "Dili gyud maayo",
        "en_anchor": (
            "Unusable for club documentation on this criterion. "
            "The defect dominates the subject."
        ),
        "bisaya_anchor": (
            "Dili magamit para sa club documentation niining criterion. "
            "Ang problema maoy nag-dominate sa subject."
        ),
    },
    2: {
        "en": "Needs improvement",
        "bisaya": "Dili kaayo maayo",
        "en_anchor": (
            "Obvious defect. A retake would normally be required."
        ),
        "bisaya_anchor": (
            "Klaro ang problema. Kasagaran kinahanglan og retake / usab nga kuha."
        ),
    },
    3: {
        "en": "Fair",
        "bisaya": "Sakto-sakto lang",
        "en_anchor": (
            "The subject is identifiable, but the defect is clearly visible "
            "and below a strong submission."
        ),
        "bisaya_anchor": (
            "Makilala pa ang subject, pero klaro gihapon ang depekto "
            "ug ubos pa sa strong submission."
        ),
    },
    4: {
        "en": "Good",
        "bisaya": "Maayo",
        "en_anchor": (
            "Only minor issues. Suitable for ACCESS documentation."
        ),
        "bisaya_anchor": (
            "Gamay ra ang isyu. Angay na para sa ACCESS documentation."
        ),
    },
    5: {
        "en": "Excellent",
        "bisaya": "Maayo kaayo",
        "en_anchor": (
            "No meaningful defect on this criterion at normal viewing and at 100% crop."
        ),
        "bisaya_anchor": (
            "Walay importanteng problema niining criterion sa normal view "
            "ug sa 100% crop."
        ),
    },
}

# Shown in the evaluator UI scale guide (N/A is not a numeric score).
NA_LABEL = {
    "code": "N/A",
    "bisaya": "Dili applicable",
    "en": "Cannot judge. Do not guess. Never use 3 as unknown.",
}

CRITERION_IDS = tuple(c["id"] for c in CRITERIA)
IMAGE_IDS = tuple(f"INDVAL-{i:03d}" for i in range(1, 101))
