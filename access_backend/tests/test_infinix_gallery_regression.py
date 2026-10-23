def test_infinix_gallery_quality_adjustment_low_risk():
    from app.services.camera_provenance import CameraProvenanceResult
    from app.services.probe_provenance_policy import apply_probe_provenance_policy

    provenance = CameraProvenanceResult(
        "partial",
        reasons=["Camera metadata retained after phone quality adjustment."],
        safe_fields=[
            {"key": "Make", "label": "Make", "value": "INFINIX MOBILITY LIMITED"},
            {"key": "Model", "label": "Model", "value": "Infinix X695"},
            {"key": "Software", "label": "Software", "value": "Infinix Gallery"},
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
            "flags": [],
            "fields": [
                {"key": "Software", "label": "Software", "value": "Infinix Gallery"}
            ],
        },
    }
    result = apply_probe_provenance_policy(
        ai, provenance, file_name="IMG_20261021_123456.jpg"
    )
    assert result["probability"] == 0.05
    assert result["requires_review"] is False
    assert result["provenance_policy_outcome"] == "low_ai_risk"
