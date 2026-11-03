"""Operator-maintained manifest for shared-dev grandfather capture (maintenance only)."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class SharedDevCaptureExpectations:
    approved_member_count: int
    would_capture_count: int
    target_user_id: int
    target_ranking_id: int
    computed_tier_v1: str
    admin_override_count: int
    users_skill_level_id: int | None = None
    total_points: int | None = None


@dataclass(frozen=True)
class SharedDevCaptureManifest:
    shared_development_mode: bool
    backup_dump_path: Path
    baseline_json_path: Path
    expected: SharedDevCaptureExpectations
    expected_database_role: str = "postgres"
    min_backup_bytes: int = 1024

    @staticmethod
    def load(path: Path) -> SharedDevCaptureManifest:
        raw = json.loads(path.read_text(encoding="utf-8"))
        if not raw.get("shared_development_mode"):
            raise ValueError("manifest must set shared_development_mode=true")
        exp = raw.get("expected") or {}
        return SharedDevCaptureManifest(
            shared_development_mode=True,
            backup_dump_path=Path(raw["backup_dump_path"]),
            baseline_json_path=Path(raw["baseline_json_path"]),
            expected=SharedDevCaptureExpectations(
                approved_member_count=int(exp["approved_member_count"]),
                would_capture_count=int(exp["would_capture_count"]),
                target_user_id=int(exp["target_user_id"]),
                target_ranking_id=int(exp["target_ranking_id"]),
                computed_tier_v1=str(exp["computed_tier_v1"]),
                admin_override_count=int(exp["admin_override_count"]),
                users_skill_level_id=exp.get("users_skill_level_id"),
                total_points=exp.get("total_points"),
            ),
            expected_database_role=str(raw.get("expected_database_role", "postgres")),
            min_backup_bytes=int(raw.get("min_backup_bytes", 1024)),
        )
