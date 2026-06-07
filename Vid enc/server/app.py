import logging
import re
import shutil
import subprocess
import threading
import time
from pathlib import Path
from urllib.parse import urlparse

import imageio_ffmpeg
import yt_dlp
from flask import Flask, abort, jsonify, request, send_from_directory, Response

from . import audio, frames, jobs, lua_gen

FPS = 10
WIDTH = 256
HEIGHT = 144


def _cache_matches(meta) -> bool:
    if not meta or "cache_dir" not in meta:
        return False
    return (
        meta.get("fps") == FPS
        and meta.get("width") == WIDTH
        and meta.get("height") == HEIGHT
    )

app = Flask(__name__)
log = logging.getLogger("videnc")

_locks: dict[str, threading.Lock] = {}
_locks_master = threading.Lock()

_served_counts: dict[str, int] = {}
_served_lock = threading.Lock()


def _lock_for(job_id: str) -> threading.Lock:
    with _locks_master:
        lk = _locks.get(job_id)
        if lk is None:
            lk = threading.Lock()
            _locks[job_id] = lk
        return lk


def _client_ip() -> str:
    return (
        request.headers.get("Cf-Connecting-Ip")
        or request.headers.get("X-Forwarded-For", "").split(",")[0].strip()
        or request.remote_addr
        or "?"
    )


def _base_url() -> str:
    fwd_host = request.headers.get("X-Forwarded-Host")
    if fwd_host:
        proto = request.headers.get("X-Forwarded-Proto", "https")
        return f"{proto}://{fwd_host}"
    return request.host_url.rstrip("/")


def _safe_title(title: str, max_len: int = 40) -> str:
    if not title:
        return "video"
    s = re.sub(r"[^A-Za-z0-9_-]+", "_", title.strip())
    s = re.sub(r"_+", "_", s).strip("_")
    return s[:max_len] or "video"


_VIDEO_EXTS = {".mp4", ".webm", ".mkv", ".mov", ".flv", ".avi"}
_AUDIO_EXTS = {".m4a", ".mp3", ".ogg", ".opus", ".wav", ".aac"}
_IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp"}


def _download_video(url: str, dest_dir: Path) -> tuple[Path, dict, Path | None]:
    """Download the source media + thumbnail. Returns (media_path, info, thumb_path)."""
    dest_dir.mkdir(parents=True, exist_ok=True)
    for old in dest_dir.glob("source.*"):
        old.unlink()

    state = {"last_pct": -10}

    def _hook(d):
        if d["status"] == "downloading":
            downloaded = d.get("downloaded_bytes") or 0
            total = d.get("total_bytes") or d.get("total_bytes_estimate") or 0
            if not total:
                return
            pct = int(downloaded * 100 / total)
            if pct >= state["last_pct"] + 10:
                state["last_pct"] = pct
                log.info("  yt-dlp %3d%% (%.1f / %.1f MB)", pct, downloaded / 1e6, total / 1e6)
        elif d["status"] == "finished":
            sz = d.get("total_bytes") or d.get("downloaded_bytes") or 0
            log.info("  yt-dlp finished, %.1f MB on disk", sz / 1e6)

    opts = {
        "outtmpl": str(dest_dir / "source.%(ext)s"),
        # Falls through video preferences → audio-only as last resort. Audio-only
        # is what YT Music / podcast URLs typically resolve to.
        "format": (
            "bv*[height<=720][ext=mp4]+ba[ext=m4a]/"
            "b[height<=720][ext=mp4]/"
            "bv*[height<=720]+ba/"
            "b[height<=720]/"
            "b/"
            "bestaudio/best"
        ),
        "merge_output_format": "mp4",
        "ffmpeg_location": imageio_ffmpeg.get_ffmpeg_exe(),
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "restrictfilenames": True,
        "writethumbnail": True,
        "progress_hooks": [_hook],
        "retries": 3,
        "fragment_retries": 3,
        "socket_timeout": 30,
        "extractor_args": {
            "youtube": {
                "player_client": ["default", "tv", "ios", "web", "mweb"],
            },
        },
    }
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=True)

    media = None
    thumb = None
    for f in dest_dir.glob("source.*"):
        ext = f.suffix.lower()
        if ext in _VIDEO_EXTS or ext in _AUDIO_EXTS:
            media = f
        elif ext in _IMAGE_EXTS:
            thumb = f
    if not media:
        raise RuntimeError("yt-dlp produced no media file")
    return media, info or {}, thumb


def _has_video_stream(src: Path) -> bool:
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    proc = subprocess.run(
        [ffmpeg, "-hide_banner", "-i", str(src), "-f", "null", "-"],
        capture_output=True,
        text=True,
    )
    return bool(re.search(r"Stream #\d+:\d+.*Video:", proc.stderr))


def _do_encode(url: str, job_id: str) -> dict:
    job_dir = jobs.job_dir(job_id)
    job_dir.mkdir(parents=True, exist_ok=True)
    log.info("encode start: job=%s url=%s", job_id, url)
    t0 = time.time()

    src, info, thumb = _download_video(url, job_dir)
    title = info.get("title") or info.get("id") or "video"
    safe = _safe_title(str(title))
    cache_dir = f"{safe}_{job_id[:6]}"
    log.info("  title=%r  cache_dir=%s", title, cache_dir)

    duration = audio.probe_duration(src)
    log.info("  duration=%.1fs", duration)

    has_video = _has_video_stream(src)
    log.info("  has_video=%s  thumb=%s", has_video, thumb.name if thumb else None)

    log.info("  extracting frames @ %dfps %dx%d ...", FPS, WIDTH, HEIGHT)
    t1 = time.time()
    if has_video:
        n_frames = frames.extract_frames(src, jobs.frames_dir(job_id), FPS, WIDTH, HEIGHT)
    elif thumb:
        log.info("  audio-only source — using thumbnail as static video")
        n_frames = frames.extract_frames_from_image(
            thumb, jobs.frames_dir(job_id), duration, FPS, WIDTH, HEIGHT
        )
    else:
        raise RuntimeError("source has no video stream and no thumbnail")
    log.info("  %d frames in %.1fs", n_frames, time.time() - t1)

    log.info("  extracting audio ...")
    t2 = time.time()
    audio.extract_audio(src, jobs.audio_path(job_id))
    log.info("  audio in %.1fs", time.time() - t2)

    meta = {
        "frame_count": n_frames,
        "fps": FPS,
        "width": WIDTH,
        "height": HEIGHT,
        "audio_duration": duration,
        "source_url": url,
        "title": str(title),
        "safe_title": safe,
        "cache_dir": cache_dir,
        "has_video": has_video,
    }
    jobs.write_meta(job_id, meta)
    try:
        src.unlink()
    except OSError:
        pass
    if thumb:
        try:
            thumb.unlink()
        except OSError:
            pass
    log.info("encode done: job=%s total=%.1fs", job_id, time.time() - t0)
    return meta


@app.before_request
def _log_request():
    if request.path == "/healthz":
        return
    ip = _client_ip()
    ua = request.headers.get("User-Agent", "?")
    log.info("→ %s %s  from %s  [%s]", request.method, request.path, ip, ua[:80])


@app.route("/healthz")
def healthz():
    return "ok"


@app.route("/encode")
def encode():
    url = request.args.get("url", "").strip()
    if not url:
        return jsonify({"error": "missing url param"}), 400
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https"):
        return jsonify({"error": "url must be http(s)"}), 400

    job_id = jobs.job_id_for(url)
    base = _base_url()

    with _lock_for(job_id):
        existing_meta = jobs.read_meta(job_id)
        if not (jobs.is_complete(job_id) and _cache_matches(existing_meta)):
            if existing_meta and not _cache_matches(existing_meta):
                log.info("encode redo: job=%s settings changed (fps/size)", job_id)
            try:
                _do_encode(url, job_id)
            except Exception as exc:
                log.exception("encode failed for %s", url)
                return jsonify({"error": str(exc), "job_id": job_id}), 500
        else:
            log.info("encode skip: job=%s already cached", job_id)

        meta = jobs.read_meta(job_id) or {}
        lua = lua_gen.render_player(
            base_url=base,
            job_id=job_id,
            frame_count=meta["frame_count"],
            fps=meta["fps"],
            width=meta["width"],
            height=meta["height"],
            audio_duration=meta["audio_duration"],
            cache_dir=meta["cache_dir"],
            title=meta.get("title", "video"),
        )
        jobs.player_path(job_id).write_text(lua, "utf-8")

    with _served_lock:
        _served_counts[job_id] = 0

    playback_url = f"{base}/play/{job_id}"
    return jsonify({
        "job_id": job_id,
        "playback_url": playback_url,
        "frame_count": meta["frame_count"],
        "duration": meta["audio_duration"],
        "fps": meta["fps"],
        "width": meta["width"],
        "height": meta["height"],
        "has_video": meta.get("has_video", True),
        "title": meta.get("title"),
        "cache_dir": meta["cache_dir"],
        "loadstring_line": f'loadstring(game:HttpGet("{playback_url}"))()',
    })


@app.route("/play/<job_id>")
def play(job_id):
    p = jobs.player_path(job_id)
    if not p.exists():
        abort(404)
    return Response(p.read_text("utf-8"), mimetype="text/plain")


@app.route("/jobs/<job_id>/meta.json")
def meta_route(job_id):
    if not jobs.meta_path(job_id).exists():
        abort(404)
    return send_from_directory(jobs.job_dir(job_id), "meta.json", mimetype="application/json")


@app.route("/jobs/<job_id>/frames/<name>")
def frame_route(job_id, name):
    fdir = jobs.frames_dir(job_id)
    if not fdir.exists():
        abort(404)
    with _served_lock:
        c = _served_counts.get(job_id, 0) + 1
        _served_counts[job_id] = c
    meta = jobs.read_meta(job_id) or {}
    total = meta.get("frame_count", 0)
    if total and (c == 1 or c % 25 == 0 or c == total):
        log.info("  served frame %d/%d for job=%s to %s", c, total, job_id, _client_ip())
    return send_from_directory(fdir, name, mimetype="image/jpeg")


@app.route("/jobs/<job_id>/audio.ogg")
def audio_route(job_id):
    if not jobs.audio_path(job_id).exists():
        abort(404)
    log.info("  served audio for job=%s to %s", job_id, _client_ip())
    return send_from_directory(jobs.job_dir(job_id), "audio.ogg", mimetype="audio/ogg")


@app.route("/done/<job_id>")
def done(job_id):
    d = jobs.job_dir(job_id)
    existed = d.exists()
    if existed:
        shutil.rmtree(d, ignore_errors=True)
    with _served_lock:
        _served_counts.pop(job_id, None)
    log.info("/done job=%s (existed=%s) from %s", job_id, existed, _client_ip())
    return jsonify({"ok": True, "removed": existed})


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%H:%M:%S",
    )
    logging.getLogger("werkzeug").setLevel(logging.WARNING)
    log.info("Vid enc server starting on http://127.0.0.1:8765 ...")
    app.run(host="127.0.0.1", port=8765, threaded=True)
