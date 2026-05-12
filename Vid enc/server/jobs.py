import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JOBS_DIR = ROOT / "jobs"


def job_id_for(url: str) -> str:
    return hashlib.sha256(url.encode("utf-8")).hexdigest()[:12]


def job_dir(job_id: str) -> Path:
    return JOBS_DIR / job_id


def frames_dir(job_id: str) -> Path:
    return job_dir(job_id) / "frames"


def audio_path(job_id: str) -> Path:
    return job_dir(job_id) / "audio.ogg"


def meta_path(job_id: str) -> Path:
    return job_dir(job_id) / "meta.json"


def player_path(job_id: str) -> Path:
    return job_dir(job_id) / "player.lua"


def read_meta(job_id: str):
    p = meta_path(job_id)
    if not p.exists():
        return None
    return json.loads(p.read_text("utf-8"))


def write_meta(job_id: str, meta: dict) -> None:
    meta_path(job_id).parent.mkdir(parents=True, exist_ok=True)
    meta_path(job_id).write_text(json.dumps(meta, indent=2), "utf-8")


def is_complete(job_id: str) -> bool:
    meta = read_meta(job_id)
    if not meta or "cache_dir" not in meta:
        return False
    fdir = frames_dir(job_id)
    if not (audio_path(job_id).exists() and fdir.exists()):
        return False
    return len(list(fdir.glob("*.jpg"))) == meta.get("frame_count", -1)
