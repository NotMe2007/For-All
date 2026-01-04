-- ============================================================================
-- Place Detector API - World Zero Location Detection
-- ============================================================================
-- Provides detection and information about current place/world/dungeon/tower
-- Based on World Zero/Features/checking placeId.lua
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/placeid.lua"))()
--
-- FEATURES:
-- • Comprehensive place ID database
-- • Dungeon/Tower/Lobby detection
-- • World number extraction
-- • Discord webhook reporting for unknown places
--
-- PERFORMANCE:
-- • Fast lookup tables
-- • Cached detection results
-- • Efficient pattern matching
--
-- SECURITY:
-- • Protected HTTP requests
-- • Safe webhook reporting
-- • Session-based duplicate prevention
-- ============================================================================

-- Service caching for performance
local _genv = getgenv()
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ============================================================================
-- DISCORD WEBHOOK CONFIG
-- ============================================================================

local WEBHOOK_URL = "https://discord.com/api/webhooks/1453037059743813864/GO0CLU8zFOPYEiOKuiyf90nLyF2fbBDtkNdLWue3cgBDPcOVlazyJdnIZU9eDoujFDK0"

-- Track reported places this session to avoid spam
if not _genv.ReportedPlaces then
    _genv.ReportedPlaces = {}
end

-- ============================================================================
-- PLACE ID MAPS
-- ============================================================================

local dungeonId = {
    -- ===== Tutorial =====
    [107701891477606] = 'Tutorial Dungeon',
	-- ===== WORLD 1 =====
	[2978696440] = 'Crabby Crusade (1-1)', 
	[4310476380] = 'Scarecrow Defense (1-2)', 
	[4310464656] = 'Dire Problem (1-3)',
	[4310478830] = 'Kingslayer (1-4)',
	[3383444582] = 'Gravetower Dungeon (1-5)',
	
	-- ===== WORLD 2 =====
	[3885726701] = 'Temple of Ruin (2-1)',
	[3994953548] = 'Mama Trauma (2-2)',
	[4050468028] = "Volcano's Shadow (2-3)",
	[3165900886] = 'Volcano Dungeon (2-4)',
	
	-- ===== WORLD 3 =====
	[4465988196] = 'Mountain Pass (3-1)',
	[4465989351] = 'Winter Cavern (3-2)',
	[4465989998] = 'Winter Dungeon (3-3)',

	-- ===== WORLD 4 =====
	[4646473427] = 'Scrap Canyon (4-1)',
	[4646475342] = 'Deserted Burrowmine (4-2)',
	[4646475570] = 'Pyramid Dungeon (4-3)',
	
	-- ===== WORLD 5 =====
	[6386112652] = 'Konoh Heartlands (5-1)',
	[11465541043] = 'Dungeon 5-2',
	
	-- ===== WORLD 6 =====
	[6510862058] = 'Atlantic Atoll (6-1)',
	[6510862652] = 'Dungeon 6-1',
	[11533444995] = 'Dungeon 6-2',
	
	-- ===== WORLD 7 =====
	[6847034886] = 'Mezuvia Skylands (7-1)',
	[11644048314] = 'Dungeon 7-2',
	
	-- ===== WORLD 8 =====
	[9944263348] = 'Dungeon 8-1',
	[10014664329] = 'Dungeon 8-2',
	
	-- ===== WORLD 9 =====
	[10651527284] = 'Dungeon 9-1',
	[10727165164] = 'Dungeon 9-2',
	
	-- ===== WORLD 10 =====
	[14914700740] = 'Dungeon 10-1',
	[14914855930] = 'Dungeon 10-2',
	
	-- ===== SPECIAL EVENTS & LOCATIONS =====
	[7450070300] = 'ToPEvent',
	[7499642980] = 'Market',
	[18567064955] = 'Vane Event Hub',
	[18567068844] = 'Vane Event Arena',
	[18725910956] = 'LIVE TestingPlace',
	[7554079804562] = 'Kraken Arena',
	[8137988282544] = 'Valentines Event Arena',
	[8765650799195] = 'Valentines Event Hub',
	[8137988287895544] = 'Valentines Event Arena 2',
	[9388908534225] = 'Graffiti Beach',
	[10211805987017] = 'Hunt 2025 Arena',
	[10770189147706] = 'Dungeon H1 Tutorial Ver',
	[10961960834199] = 'Alien Invasion',
	[14463030678625] = 'Kensai666s Place',
	[12564586793057] = 'Kraken Cove',
	[13817936582742] = 'Zero Arena',
	[139316833473171] = 'Guild Hub',
	[4526768588] = 'Santa Claus Dungeon Event',
	[4526768266] = 'holiday event hub'
}

local towerId = {
	-- ===== STANDARD TOWERS =====
	[5703353651] = 'Prison Tower',
	[6075085184] = 'Atlantis Tower',
	[7071564842] = 'Mezuvian Tower',
	[10089770465] = 'Oasis Tower',
	[10795158121] = 'Aether Tower',
	[15121292578] = 'Arcane Tower',
	
	-- ===== SPECIAL TOWERS =====
	[13988110964] = 'Infinite Tower',
	[14400549310] = 'Celestial Tower'
}

local lobbyId = {
	-- ===== MAIN MENU =====
	[2727067538] = 'Main menu',
	
	-- ===== WORLD LOBBIES =====
	[4310463616] = 'World 1',
	[4310463940] = 'World 2',
	[4465987684] = 'World 3',
	[4646472003] = 'World 4',
	[5703355191] = 'World 5',
	[6075083204] = 'World 6',
	[6847035264] = 'World 7',
	[9944262922] = 'World 8',
	[10651517727] = 'World 9',
	[14914684761] = 'World 10'
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function findInMap(map, placeId)
	for id, name in pairs(map) do
		if placeId == id then 
			return true, name 
		end
	end
	return false, nil
end

local function getWorldNumber(locationName)
	if not locationName then return nil end
	local worldNum = locationName:match("World (%d+)")
	if worldNum then return tonumber(worldNum) end
	local dungeonNum = locationName:match("%((%d+)%-")
	if dungeonNum then return tonumber(dungeonNum) end
	return nil
end

-- ============================================================================
-- DISCORD WEBHOOK REPORTING
-- ============================================================================

local function sendDiscordWebhook(placeId)
	-- Check if already reported this session
	if _genv.ReportedPlaces[placeId] then
		return false, "Already reported this session"
	end
	
	-- Mark as reported
	_genv.ReportedPlaces[placeId] = true
	
	local player = Players.LocalPlayer
	local username = player and player.Name or "Unknown"
	local userId = player and player.UserId or 0
	
	local embed = {
		title = "🆕 New World Zero Place Detected!",
		description = string.format("**PlaceId:** `%d`\n**GameId:** `%d`\n**Reporter:** %s (%d)", 
			placeId, 
			game.GameId,
			username,
			userId
		),
		color = 0xFF6B00, -- Orange color
		timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
		footer = {
			text = "ZenX Place Detector"
		}
	}
	
	local payload = {
		embeds = {embed},
		username = "World Zero Place Detector",
		avatar_url = "https://tr.rbxcdn.com/38ab39bef3aeb73ac49b4a8b0c30813f/150/150/Image/Png"
	}
	
	local success = pcall(function()
		local jsonData = HttpService:JSONEncode(payload)
		local headers = {["Content-Type"] = "application/json"}
		
		request({
			Url = WEBHOOK_URL,
			Method = "POST",
			Headers = headers,
			Body = jsonData
		})
	end)
	
	return success, success and "Webhook sent successfully" or "Failed to send webhook"
end

-- ============================================================================
-- API FUNCTIONS
-- ============================================================================

local PlaceAPI = {}

function PlaceAPI.isLobby(placeId)
	placeId = placeId or game.PlaceId
	return findInMap(lobbyId, placeId)
end

function PlaceAPI.isDungeon(placeId)
	placeId = placeId or game.PlaceId
	return findInMap(dungeonId, placeId)
end

function PlaceAPI.isTower(placeId)
	placeId = placeId or game.PlaceId
	return findInMap(towerId, placeId)
end

function PlaceAPI.getCurrentPlaceId()
	return game.PlaceId
end

function PlaceAPI.detect(placeId)
	placeId = placeId or game.PlaceId
	
	local inLobby, lobbyName = PlaceAPI.isLobby(placeId)
	if inLobby then 
		return {
			type = 'lobby',
			name = lobbyName,
			world = getWorldNumber(lobbyName),
			placeId = placeId,
			isLobby = true,
			isDungeon = false,
			isTower = false
		}
	end
	
	local inDungeon, dungeonName = PlaceAPI.isDungeon(placeId)
	if inDungeon then 
		return {
			type = 'dungeon',
			name = dungeonName,
			world = getWorldNumber(dungeonName),
			placeId = placeId,
			isLobby = false,
			isDungeon = true,
			isTower = false
		}
	end
	
	local inTower, towerName = PlaceAPI.isTower(placeId)
	if inTower then 
		return {
			type = 'tower',
			name = towerName,
			world = nil,
			placeId = placeId,
			isLobby = false,
			isDungeon = false,
			isTower = true
		}
	end
	
	-- Unknown place detected - report to Discord webhook
	pcall(function()
		sendDiscordWebhook(placeId)
	end)
	
	return {
		type = 'unknown',
		name = nil,
		world = nil,
		placeId = placeId,
		isLobby = false,
		isDungeon = false,
		isTower = false
	}
end

function PlaceAPI.getCurrent()
	return PlaceAPI.detect(game.PlaceId)
end

function PlaceAPI.waitForType(targetType, timeout)
	timeout = timeout or 60
	local startTime = tick()
	
	while tick() - startTime < timeout do
		local current = PlaceAPI.getCurrent()
		if current.type == targetType then
			return true, current
		end
		task.wait(1)
	end
	
	return false, nil
end

function PlaceAPI.waitForWorld(worldNumber, timeout)
	timeout = timeout or 60
	local startTime = tick()
	
	while tick() - startTime < timeout do
		local current = PlaceAPI.getCurrent()
		if current.world == worldNumber then
			return true, current
		end
		task.wait(1)
	end
	
	return false, nil
end

function PlaceAPI.getAllPlaceIds()
	return {
		dungeons = dungeonId,
		towers = towerId,
		lobbies = lobbyId
	}
end

function PlaceAPI.getPlaceIdByName(name)
	for id, placeName in pairs(dungeonId) do
		if placeName:lower():find(name:lower()) then
			return id, placeName, 'dungeon'
		end
	end
	for id, placeName in pairs(towerId) do
		if placeName:lower():find(name:lower()) then
			return id, placeName, 'tower'
		end
	end
	for id, placeName in pairs(lobbyId) do
		if placeName:lower():find(name:lower()) then
			return id, placeName, 'lobby'
		end
	end
	return nil, nil, nil
end

-- ============================================================================
-- GLOBAL REGISTRATION
-- ============================================================================

_G.x5n3d = PlaceAPI
_G.PlaceAPI = PlaceAPI
getgenv().x5n3d = PlaceAPI
getgenv().PlaceAPI = PlaceAPI

-- Store current location on load
_genv.currentPlace = PlaceAPI.getCurrent()

-- ============================================================================
-- EXPORT
-- ============================================================================

return PlaceAPI
