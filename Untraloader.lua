-- Universal loader: choose which script to run based on place id.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local WORLD_ZERO_LOADER_URL = "https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/Main.lua"
local WORLD_ZERO_PLACE_MAP_URL = "https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/placeid.lua"
local DESCENT_LOADER_URL = "https://raw.githubusercontent.com/NotMe2007/For-All/main/Random%20Scripts/Descent.lua"

-- Add Descent place ids here when known; name-based detection is used as a fallback.
local DESCENT_PLACE_IDS = {
	[1542822519] = true,
}

local function safeLoadstringFromUrl(url)
	local ok, content = pcall(game.HttpGet, game, url)
	if not ok then
		warn("Untraloader: failed to fetch " .. url .. " (" .. tostring(content) .. ")")
		return nil
	end

	local chunkOk, chunk = pcall(loadstring, content)
	if not chunkOk then
		warn("Untraloader: failed to compile script from " .. url .. " (" .. tostring(chunk) .. ")")
		return nil
	end

	local runOk, result = pcall(chunk)
	if not runOk then
		warn("Untraloader: failed to execute script from " .. url .. " (" .. tostring(result) .. ")")
		return nil
	end

	return result
end

local function buildWorldZeroSet()
	local placeModule = safeLoadstringFromUrl(WORLD_ZERO_PLACE_MAP_URL)
	if type(placeModule) ~= "table" or type(placeModule.getAllPlaceIds) ~= "function" then
		warn("Untraloader: could not load World Zero place list; skipping World Zero detection.")
		return {}
	end

	local ok, maps = pcall(placeModule.getAllPlaceIds)
	if not ok or type(maps) ~= "table" then
		warn("Untraloader: failed to read World Zero place list (" .. tostring(maps) .. ")")
		return {}
	end

	local ids = {}
	local function ingest(map)
		if type(map) ~= "table" then
			return
		end
		for id in pairs(map) do
			ids[id] = true
		end
	end

	ingest(maps.dungeons)
	ingest(maps.towers)
	ingest(maps.lobbies)

	return ids
end

local function isDescent(placeId)
	if DESCENT_PLACE_IDS[placeId] then
		return true
	end

	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, placeId)
	if ok and type(info) == "table" and type(info.Name) == "string" then
		local lowerName = string.lower(info.Name)
		if lowerName:find("descent") then
			return true
		end
	end

	return false
end

local function loadWorldZero()
	safeLoadstringFromUrl(WORLD_ZERO_LOADER_URL)
end

local function loadDescent()
	safeLoadstringFromUrl(DESCENT_LOADER_URL)
end

local placeId = game.PlaceId
local worldZeroIds = buildWorldZeroSet()

if worldZeroIds[placeId] then
	loadWorldZero()
elseif isDescent(placeId) then
	loadDescent()
else
	warn("Untraloader: place id " .. tostring(placeId) .. " not recognized; no script loaded.")
end
