-- Vid enc client: paste this into your executor.
-- Set TUNNEL (printed by start.ps1) and VIDEO_URL, then run.
--
-- This fetches a VidPlayer MODULE from the server and hands it back to you so
-- your own script stays in control. See the bottom of this file for the API.

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

-- Returns the player source string, from cache if we have a complete copy.
local function getPlayerSource()
	if _isfile(lookupPath) then
		local cacheDir = _readfile(lookupPath)
		local playerPath = "vidcache/" .. cacheDir .. "/player.lua"
		local completeFlag = "vidcache/" .. cacheDir .. "/complete.txt"
		if _isfile(playerPath) and _isfile(completeFlag) then
			print(("[Vid enc] cache hit: %s"):format(cacheDir))
			return _readfile(playerPath)
		end
	end

	print("[Vid enc] no cache, asking server to encode...")
	local okReq, raw = pcall(game.HttpGet, game, TUNNEL .. "/encode?url=" .. HS:UrlEncode(VIDEO_URL))
	if not okReq then
		error("[Vid enc] request to server failed: " .. tostring(raw))
	end

	local okJson, res = pcall(HS.JSONDecode, HS, raw)
	if not okJson then
		local snippet = tostring(raw):sub(1, 300):gsub("%s+", " ")
		error("[Vid enc] server did not return JSON (Cloudflare timeout or crash). Got: " .. snippet)
	end
	if res.error then
		error("[Vid enc] encode failed: " .. tostring(res.error))
	end

	print(("[Vid enc] %s — %d frames, %.1fs"):format(tostring(res.title or "?"), res.frame_count, res.duration))

	local playerSrc = game:HttpGet(res.playback_url)
	local cacheDir = res.cache_dir
	if not _isfolder("vidcache/" .. cacheDir) then _makefolder("vidcache/" .. cacheDir) end
	_writefile("vidcache/" .. cacheDir .. "/player.lua", playerSrc)
	_writefile(lookupPath, cacheDir)
	return playerSrc
end

-- loadstring returns a VidPlayer object; it does NOT auto-run.
local player = loadstring(getPlayerSource())()

--==================================================================
-- Configure / control however you like. Examples:
--==================================================================
-- player.Config.Scale = 4
-- player.Config.Position = UDim2.fromScale(0.25, 0.3)
-- player.Config.Volume = 0.5
-- player.Config.Looped = true
-- player.Config.ShowControls = true     -- play/pause, stop, seek bar (default on)
--
-- player.OnProgress = function(done, total, phase)
--     print(("[%s] %d/%d"):format(phase, done, total))
-- end
-- player.OnEnded = function() print("video finished") end
--
-- print("Title:", player.Info.Title, "Duration:", player.Info.Duration)

player:Run()   -- builds GUI, downloads (or loads cache), and plays

-- player:Pause()      player:Play()      player:TogglePause()
-- player:Stop()       player:Seek(30)    player:SetVolume(0.2)
-- player:Destroy()
return player
