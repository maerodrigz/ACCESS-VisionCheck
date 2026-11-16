from app.database import SessionLocal
from app.models.media_file import MediaFile
from app.models.ai_detection_result import AiDetectionResult
import json

db = SessionLocal()
rows = db.query(AiDetectionResult, MediaFile).join(MediaFile).all()
for ai, m in rows:
    ex = json.loads(ai.exif_metadata) if ai.exif_metadata and isinstance(ai.exif_metadata, str) else (ai.exif_metadata or {})
    is_v = ex.get("is_video") or (m.file_name or "").lower().endswith((".mp4", ".mov", ".webm"))
    if not is_v:
        continue
    be = str(ex.get("detector_backend") or "")
    tag = "waverep" if "waverep" in be else "other"
    print(f"{tag}\t{ai.id}\t{m.id}\t{ai.ai_probability:.4f}\t{ai.detection_result}\t{ai.review_status}\t{m.file_name}")
db.close()
