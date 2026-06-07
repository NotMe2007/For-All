# Vid enc — Full Documentation

Play any video (YouTube, YT Music, direct mp4, …) inside a Roblox executor.
A small local server downloads and re-encodes the video into image frames + an
audio file; a generated Lua **module** streams those into Roblox and gives your
script a clean player API to control.

- [1. What it is](#1-what-it-is)
- [2. How it works](#2-how-it-works)
- [3. Setup](#3-setup)
- [4. Everyday use](#4-everyday-use)
- [5. HTTP API reference](#5-http-api-reference)
- [6. Lua player API (`VidPlayer`)](#6-lua-player-api-vidplayer)
- [7. Caching](#7-caching)
- [8. Tuning quality](#8-tuning-quality)
- [9. Troubleshooting](#9-troubleshooting)
- [10. Limits & security](#10-limits--security)

---

## 1. What it is

Roblox can't decode mp4. So the work is split between a **server** (does the
heavy lifting on your PC) and a **Lua client** (runs in the executor):

| Piece | Lives in | Job |
| --- | --- | --- |
| Encoder server | `server/` (Python + Flask + ffmpeg + yt-dlp) | URL → frames + audio |
| Public tunnel | `cloudflared` (auto-downloaded) | exposes the server over HTTPS |
| Player module | generated `player.lua` | downloads + plays in Roblox |
| Client snippet | `scripts/client.lua` | what you paste into the executor |

---

## 2. How it works

```
your executor                     your PC (server)
-------------                     ----------------
client.lua
  │  GET /encode?url=...
  ├────────────────────────────▶  yt-dlp downloads the video (+ thumbnail)
  │                               ffmpeg → frames/00001.jpg ... (10 fps, 256x144)
  │                               ffmpeg → audio.ogg
  │                               render player.lua from template
  │  ◀──────── JSON {job_id, playback_url, frame_count, duration, ...}
  │
  │  GET /play/<job_id>  ─────▶   returns the VidPlayer module source
  │  loadstring(...)()           returns a VidPlayer object (no auto-run)
  │
  │  player:Run()
  │    GET /jobs/<id>/frames/00001.jpg ... (one request per frame)
  │    GET /jobs/<id>/audio.ogg
  │    writefile() each to vidcache/<name>/
  │    getcustomasset() → ImageLabels + Sound
  │    GET /done/<job_id>  ───▶   server deletes the job folder (client has it now)
  │
  └─ plays: Sound.TimePosition drives which frame ImageLabel is Visible
```

**Sync model.** The audio is the master clock. Every `RenderStepped` the player
computes `frame = floor(Sound.TimePosition * FPS) + 1` and shows that frame. If
frame downloads or rendering ever stutter, audio stays correct and the picture
catches up — no drift.

**Anti-flicker.** Instead of rewriting one `ImageLabel.Image` each frame (which
flashes black while a texture decodes), the player creates **one ImageLabel per
frame** with its texture preloaded, then only toggles `.Visible`. Nothing is
ever mid-decode at display time.

**Audio-only sources (YT Music).** If the downloaded media has no video stream,
the server builds a static video from the track's thumbnail for the audio's
duration — so a song plays with its cover art shown.

---

## 3. Setup

One prerequisite: the **`py` launcher** (ships with the python.org installer).
`python` on this machine is a Microsoft Store stub; everything uses `py`.

Everything else is automatic on first run of `scripts/start.ps1`:

1. creates `.venv` (via `py -m venv`)
2. `pip install -r requirements.txt` (ffmpeg is bundled inside `imageio-ffmpeg`)
3. `pip install -U yt-dlp` (keeps up with YouTube's frequent changes)
4. downloads `cloudflared.exe` into `.tools/` if not already on PATH
5. starts Flask on `127.0.0.1:8765` and a Cloudflare quick tunnel over it

```powershell
cd "C:\Users\Timmie\OneDrive\Documents\GitHub\For-All\Vid enc"
.\scripts\start.ps1
```

Watch for:

```
==================================================
 Public URL:  https://something.trycloudflare.com
==================================================
```

That URL is also written to `current_tunnel.txt`. **It changes every restart.**

---

## 4. Everyday use

1. Start the server (`scripts/start.ps1`), copy the printed tunnel URL.
2. Open `scripts/client.lua`, set:
   ```lua
   local TUNNEL = "https://something.trycloudflare.com"
   local VIDEO_URL = "https://youtu.be/<id>"
   ```
3. Paste the whole file into your executor and run.

First run for a URL: the server encodes (download + frame split — takes a bit),
then the client downloads every frame. Subsequent runs of the same URL play
straight from the executor's local cache with no server call.

---

## 5. HTTP API reference

Base = the tunnel URL.

### `GET /encode?url=<video_url>`
Download + encode (or reuse cache), then return job info. Synchronous: the
response comes back only when encoding is done. Same URL = same `job_id`, so
repeats are instant.

Response:
```json
{
  "job_id": "8b3c5d1f2a90",
  "playback_url": "https://.../play/8b3c5d1f2a90",
  "frame_count": 1800,
  "duration": 182.4,
  "fps": 10,
  "width": 256,
  "height": 144,
  "has_video": true,
  "title": "Never Gonna Give You Up",
  "cache_dir": "Never_Gonna_Give_You_Up_8b3c5d",
  "loadstring_line": "loadstring(game:HttpGet(\"https://.../play/8b3c5d1f2a90\"))()"
}
```
On failure: `{ "error": "<message>", "job_id": "..." }` with HTTP 500.

### `GET /play/<job_id>`
Returns the `VidPlayer` module source as `text/plain`. This is the
`loadstring(...)` target.

### `GET /jobs/<job_id>/meta.json`
Full metadata for the job.

### `GET /jobs/<job_id>/frames/<NNNNN>.jpg`
A single frame (1-based, zero-padded to 5 digits).

### `GET /jobs/<job_id>/audio.ogg`
The extracted audio (Vorbis in Ogg).

### `GET /done/<job_id>`
Deletes the job's folder on the server. The player calls this automatically once
it has finished downloading everything. Returns `{ "ok": true, "removed": bool }`.

### `GET /healthz`
Returns `ok`. Used to check the tunnel is alive.

---

## 6. Lua player API (`VidPlayer`)

`loadstring(game:HttpGet(playback_url))()` **returns a VidPlayer object** and
does nothing else until you tell it to. Your main script drives it.

```lua
local player = loadstring(game:HttpGet(playback_url))()
player.Config.Scale = 4
player.OnEnded = function() print("done") end
player:Run()
```

### `player.Info` (read-only)
| Field | Meaning |
| --- | --- |
| `JobId` | server job id |
| `Title` | video title |
| `FrameCount` | number of frames |
| `Fps` | frames per second |
| `Duration` | audio length in seconds |
| `Width`, `Height` | frame resolution |
| `CacheDir` | local folder under `vidcache/` |

### `player.Config` (edit before `:Run()`/`:Play()`)
| Field | Default | Meaning |
| --- | --- | --- |
| `Parent` | `nil` | explicit ScreenGui parent (overrides the next option) |
| `ParentToCoreGui` | `true` | try `CoreGui`, fall back to `PlayerGui` |
| `Scale` | `3` | each frame drawn at `Width*Scale` × `Height*Scale` |
| `Position` | center | `UDim2` window position |
| `AnchorPoint` | `(0.5,0.5)` | window anchor |
| `Volume` | `1` | 0–1 |
| `Looped` | `false` | repeat when finished |
| `AutoPlay` | `true` | `:Run()` plays immediately when true |
| `ShowControls` | `true` | bottom bar: play/pause, stop, seek, time |
| `Draggable` | `true` | drag the video area to move the window |

### `player` events (assign a function)
| Event | Signature | Fires |
| --- | --- | --- |
| `OnProgress` | `(done, total, phase)` | during load; `phase` = `"download"`/`"cache"`/`"prepare"` |
| `OnLoaded` | `()` | after all media is on disk |
| `OnFrame` | `(index)` | when the visible frame changes |
| `OnEnded` | `()` | when playback reaches the end |
| `OnStateChanged` | `(state)` | `"playing"`/`"paused"`/`"stopped"`/`"destroyed"` |

### `player` methods
| Method | Effect |
| --- | --- |
| `:Run()` | build GUI + load + (if `AutoPlay`) play. The usual entry point. |
| `:Prepare()` | build GUI + load, but don't play. Yields. |
| `:Load()` | download/cache frames + audio only. Yields. |
| `:Play()` | play (or resume if paused) |
| `:Pause()` | pause |
| `:Resume()` | alias for `:Play()` |
| `:TogglePause()` | pause ⇄ play |
| `:Stop()` | stop and reset to the first frame |
| `:Seek(seconds)` | jump to a time |
| `:SetVolume(v)` | set volume 0–1 |
| `:Destroy()` | stop, disconnect, remove the GUI and Sound |
| `:IsCached()` | `true` if every frame + audio is already on disk |

All control methods return `self`, so you can chain: `player:Load():Play()`.

### `player.Instances` (the actual GUI objects, for custom styling)
`Gui`, `Window`, `Stage`, `Status`, `CloseButton`, and when controls are on:
`ControlBar`, `PlayButton`, `StopButton`, `SeekBar`, `SeekFill`, `TimeLabel`.
Tweak them directly, e.g.:
```lua
player:Prepare()
player.Instances.Window.Position = UDim2.fromScale(0.8, 0.2)
player.Instances.SeekFill.BackgroundColor3 = Color3.fromRGB(255, 0, 80)
player:Play()
```

### Full example
```lua
local player = loadstring(game:HttpGet(playback_url))()

player.Config.Scale = 4
player.Config.Volume = 0.6
player.OnProgress = function(done, total, phase)
    print(("[%s] %d / %d"):format(phase, done, total))
end
player.OnEnded = function()
    print("finished:", player.Info.Title)
    player:Destroy()
end

player:Run()
```

---

## 7. Caching

**Two layers, both keyed so repeats are free:**

- **Server** (`jobs/<job_id>/`): `job_id = sha256(url)[:12]`. Re-encoding the same
  URL is skipped. If `fps`/resolution changed since last time, it re-encodes.
  After a client confirms download via `/done`, the server **deletes** the job
  folder to save space.
- **Client** (`vidcache/` in the executor's workspace):
  - `vidcache/_lookup/<url>.txt` maps a video URL → its cache folder name.
  - `vidcache/<name>/frames/NNNNN.jpg`, `audio.ogg`, `player.lua`,
    `complete.txt`.
  - `complete.txt` is written only after a full download; the client treats a
    cache as valid only when it exists, and the player still re-checks every
    individual frame file (`:IsCached()`), re-downloading any that are missing.

**To force a re-download:** delete the relevant `vidcache/<name>/` folder (and
its `vidcache/_lookup/<url>.txt`) in the executor's workspace. Deleting all of
`vidcache/` resets everything.

---

## 8. Tuning quality

Set in `server/app.py`:
```python
FPS = 10
WIDTH = 256
HEIGHT = 144
```
Higher = smoother/sharper but more frames to download and more `ImageLabel`
instances in Roblox. Rough cost: `frames ≈ FPS × duration_seconds`. Changing any
of these makes the server re-encode existing URLs on next request (the cache
check compares fps/size).

---

## 9. Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `Could not resolve host: CHANGE-ME...` | `TUNNEL` in client.lua still a placeholder. Paste the real URL. |
| `server did not return JSON ...` | Cloudflare 524 timeout (encode took too long) or server crashed. Check the server console; try a shorter video. |
| `This video is not available` | Real YouTube restriction (private/region/deleted) **or** outdated yt-dlp. `start.ps1` auto-upgrades yt-dlp each run; restart it. Try another video to confirm the pipeline. |
| Playing an old/flickering version | Stale client cache. Delete `vidcache/` in the executor workspace. |
| `Executor must expose writefile + getcustomasset` | Your executor lacks file APIs. Use a modern one (Solara, Wave, Hydrogen, …). |
| Black flashes between frames | Should be gone (per-frame labels + preload). If a giant video, lower `FPS`. |
| `cloudflared not found` and download fails | Network blocked the GitHub download. Install manually and put `cloudflared.exe` on PATH or in `.tools/`. |

Server logs (in the `start.ps1` console) show every request with the client IP,
yt-dlp progress every 10%, per-stage timing, frames served, and `/done` cleanup.

---

## 10. Limits & security

- **No auth.** Anyone with the tunnel URL can submit encode jobs and read
  outputs. It's a personal tool — don't share the URL.
- **Quick Tunnel URL is ephemeral** — changes on every restart.
- **Server disk**: jobs auto-delete after the client downloads them, but a job
  that's encoded and never played stays in `jobs/`. Delete `jobs/` to clear.
- **Long videos** create many `ImageLabel`s (≈ `FPS × seconds`). Fine for typical
  clips; for 10-minute+ videos lower the FPS.
- yt-dlp can't bypass genuinely unavailable / members-only / age-gated content.
