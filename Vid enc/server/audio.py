import subprocess
from pathlib import Path

import imageio_ffmpeg


def extract_audio(video_path: Path, out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.exists():
        out_path.unlink()
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    cmd = [
        ffmpeg,
        "-hide_banner",
        "-loglevel", "error",
        "-y",
        "-i", str(video_path),
        "-vn",
        "-c:a", "libvorbis",
        "-q:a", "4",
        "-ar", "44100",
        str(out_path),
    ]
    subprocess.run(cmd, check=True)


def probe_duration(video_path: Path) -> float:
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    proc = subprocess.run(
        [ffmpeg, "-hide_banner", "-i", str(video_path), "-f", "null", "-"],
        capture_output=True,
        text=True,
    )
    for raw in proc.stderr.splitlines():
        line = raw.strip()
        if line.startswith("Duration:"):
            ts = line.split("Duration:", 1)[1].split(",", 1)[0].strip()
            if ts == "N/A":
                return 0.0
            h, m, s = ts.split(":")
            return int(h) * 3600 + int(m) * 60 + float(s)
    return 0.0
