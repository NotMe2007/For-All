-- Vid enc client: paste this into your executor.
-- Fill in TUNNEL with the URL printed by start.ps1, and VIDEO_URL with the video you want to play.

local TUNNEL = "https://your-custom-trycloudflare.com/"
local VIDEO_URL = "https://your-video-link.com/"

local HS = game:GetService("HttpService")

local _writefile = writefile
local _readfile = readfile
local _isfile = isfile or function() return false end
local _isfolder = isfolder or function() return false end
local _makefolder = makefolder or function() end

if not _writefile or not _readfile or not _isfile then
	error("[Vid enc] Executor must expose writefile / readfile / isfile")
end

local function trimSlash(s)
	if s:sub(-1) == "/" then return s:sub(1, -2) end
	return s
end
TUNNEL = trimSlash(TUNNEL)

if not _isfolder("vidcache") then _makefolder("vidcache") end
if not _isfolder("vidcache/_lookup") then _makefolder("vidcache/_lookup") end

local function urlKey(url)
	local s = url:gsub("[^%w]", "_")
	if #s > 100 then s = s:sub(1, 100) end
	return s
end

local lookupPath = "vidcache/_lookup/" .. urlKey(VIDEO_URL) .. ".txt"

if _isfile(lookupPath) then
	local cacheDir = _readfile(lookupPath)
	local playerPath = "vidcache/" .. cacheDir .. "/player.lua"
	local completeFlag = "vidcache/" .. cacheDir .. "/complete.txt"
	if _isfile(playerPath) and _isfile(completeFlag) then
		print(("[Vid enc] cache hit: %s  (playing offline)"):format(cacheDir))
		loadstring(_readfile(playerPath))()
		return
	end
end

print("[Vid enc] no cache, asking server to encode...")
local raw = game:HttpGet(TUNNEL .. "/encode?url=" .. HS:UrlEncode(VIDEO_URL))
local res = HS:JSONDecode(raw)
if res.error then
	error("[Vid enc] encode failed: " .. tostring(res.error))
end

print(("[Vid enc] %s — %d frames, %.1fs"):format(tostring(res.title or "?"), res.frame_count, res.duration))

local playerSrc = game:HttpGet(res.playback_url)
local cacheDir = res.cache_dir
if not _isfolder("vidcache/" .. cacheDir) then _makefolder("vidcache/" .. cacheDir) end
_writefile("vidcache/" .. cacheDir .. "/player.lua", playerSrc)
_writefile(lookupPath, cacheDir)

loadstring(playerSrc)()
