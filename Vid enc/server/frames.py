import subprocess
from pathlib import Path

import imageio_ffmpeg


def extract_frames(video_path: Path, out_dir: Path, fps: int, width: int, height: int) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    for stale in out_dir.glob("*.jpg"):
        stale.unlink()
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    pattern = str(out_dir / "%05d.jpg")
    cmd = [
        ffmpeg,
        "-hide_banner",
        "-loglevel", "error",
        "-y",
        "-i", str(video_path),
        "-vf", f"fps={fps},scale={width}:{height}",
        "-q:v", "5",
        pattern,
    ]
    subprocess.run(cmd, check=True)
    return len(list(out_dir.glob("*.jpg")))


def extract_frames_from_image(image_path: Path, out_dir: Path, duration: float, fps: int, width: int, height: int) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    for stale in out_dir.glob("*.jpg"):
        stale.unlink()
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    pattern = str(out_dir / "%05d.jpg")
    cmd = [
        ffmpeg,
        "-hide_banner",
        "-loglevel", "error",
        "-y",
        "-loop", "1",
        "-i", str(image_path),
        "-t", f"{max(duration, 0.5):.3f}",
        "-vf", f"fps={fps},scale={width}:{height}:force_original_aspect_ratio=decrease,pad={width}:{height}:(ow-iw)/2:(oh-ih)/2:color=black",
        "-q:v", "5",
        pattern,
    ]
    subprocess.run(cmd, check=True)
    return len(list(out_dir.glob("*.jpg")))
