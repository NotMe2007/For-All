from pathlib import Path

TEMPLATE_PATH = Path(__file__).parent / "templates" / "player.lua.tmpl"


def _lua_string(s: str) -> str:
    """Escape a Python string so it is safe inside a Lua double-quoted literal."""
    if s is None:
        return ""
    return (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", " ")
        .replace("\n", " ")
    )


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
    title: str = "video",
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
        "{{TITLE}}": _lua_string(title),
    }
    out = tmpl
    for k, v in replacements.items():
        out = out.replace(k, v)
    return out
