from pathlib import Path

TEMPLATE_PATH = Path(__file__).parent / "templates" / "player.lua.tmpl"


def render_player(
    *,
    base_url: str,
    job_id: str,
    frame_count: int,
    fps: int,
    width: int,
    height: int,
    audio_duration: float,
    cache_dir: str,
) -> str:
    tmpl = TEMPLATE_PATH.read_text("utf-8")
    replacements = {
        "{{BASE_URL}}": base_url.rstrip("/"),
        "{{JOB_ID}}": job_id,
        "{{FRAME_COUNT}}": str(frame_count),
        "{{FPS}}": str(fps),
        "{{WIDTH}}": str(width),
        "{{HEIGHT}}": str(height),
        "{{AUDIO_DURATION}}": f"{audio_duration:.3f}",
        "{{CACHE_DIR}}": cache_dir,
    }
    out = tmpl
    for k, v in replacements.items():
        out = out.replace(k, v)
    return out
