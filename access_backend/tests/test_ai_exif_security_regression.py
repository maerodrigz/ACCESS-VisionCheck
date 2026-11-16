def test_ai_software_exif_requires_admin_review_even_with_low_probe_risk():
    from app.services.camera_provenance import CameraProvenanceResult
    from app.services.probe_provenance_policy import apply_probe_provenance_policy

    provenance = CameraProvenanceResult(
        "partial",
        reasons=["Software tag suggests AI tooling."],
        safe_fields=[
            {"key": "Make", "label": "Make", "value": "INFINIX MOBILITY LIMITED"},
            {"key": "Model", "label": "Model", "value": "Infinix X695"},
            {"key": "Software", "label": "Software", "value": "AI image generator"},
        ],
    )

    ai = {
        "verdict": "authentic",
        "probability": 0.05,
        "raw_detector_probability": 0.05,
        "risk_level": "low",
        "requires_review": False,
        "exif_metadata": {
            "has_exif": True,
            "flags": [
                {
                    "code": "ai_software_exif",
                    "label": "EXIF software indicates AI generation.",
                    "severity": "danger",
                }
            ],
            "fields": [
                {"key": "Software", "label": "Software", "value": "AI image generator"}
            ],
        },
    }

    result = apply_probe_provenance_policy(
        ai, provenance, file_name="IMG_20261021_123456.jpg"
    )

    assert result["probability"] == 0.05
    assert result["requires_review"] is True
    assert result["final_review_required"] is True

def test_strong_provenance_with_ai_exif_flag_still_requires_review():
    from app.services.camera_provenance import CameraProvenanceResult
    from app.services.probe_provenance_policy import apply_probe_provenance_policy

    provenance = CameraProvenanceResult(
        "strong",
        reasons=["Camera identity and capture timestamp present."],
        safe_fields=[
            {"key": "Make", "label": "Make", "value": "INFINIX MOBILITY LIMITED"},
            {"key": "Model", "label": "Model", "value": "Infinix X695"},
        ],
    )

    ai = {
        "verdict": "authentic",
        "probability": 0.05,
        "raw_detector_probability": 0.05,
        "risk_level": "low",
        "requires_review": False,
        "exif_metadata": {
            "has_exif": True,
            "flags": [
                {
                    "code": "ai_software_exif",
                    "label": "AI software detected.",
                    "severity": "danger",
                }
            ],
            "fields": [],
        },
    }

    result = apply_probe_provenance_policy(
        ai, provenance, file_name="IMG_20261021_123456.jpg"
    )

    assert result["requires_review"] is True
    assert result["final_review_required"] is True
    assert result["probability"] == 0.05
