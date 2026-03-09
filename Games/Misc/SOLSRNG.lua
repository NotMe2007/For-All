repeat
    task.wait()
until game:IsLoaded() and game.Players.LocalPlayer

_G.BiomeCheck = true

local CONFIG = {
    webhookUrl = "https://discord.com/api/webhooks/1476734912559190148/sXSvFZ0LjXZRMegN9U_kNOnzQLaxW51CHpyA5dWfP-Hh6f-IjVGsERbRuc1pkb87ubvM",
    pingUser = true,
    discordUserId = "USERID",
    pollInterval = 0.5,

    teleportTimeout = 15,
    reexecuteScript = true,
    scriptSourceUrl = "https://raw.githubusercontent.com/NotMe2007/For-All/refs/heads/main/Games/Misc/SOLSRNG.lua",

    autoServerHop = true,
    hopOnBlacklistedBiome = false,
    hopOnNonTargetBiome = true,
    nonTargetHopDelaySeconds = 5,
    preferOldestServers = true,
    oldestServerPagesToScan = 8,
    fallbackServerPagesToScan = 3,
    avoidFriendServers = true,
    friendServerPagesToScan = 3,
    clearVisitedIfNoServer = true,
    noServerRetryCooldown = 2,
    hopDelaySeconds = 2,
    maxServerHopAttempts = 10,

    shareServerJoinLinks = true,

    blacklistedBiomes = {
        Normal = true,
        ["The Limbo"] = true,
        Limbo = true
    },

    targetBiomes = {
        Glitched = true,
    },

    autoPressPlayAfterHop = true,
    playAutoStartTimeout = 20,
    playClickRetryInterval = 1,
    notifyOnlyTargetBiomes = true,
    useReplicaListener = false,
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local MainInterface = PlayerGui:WaitForChild("MainInterface")

local requestFn = (syn and syn.request)
    or http_request
    or request
    or (fluxus and fluxus.request)

local queueOnTeleportFn = queue_on_teleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)
    or (krnl and krnl.queue_on_teleport)

local visitedServerIds = {}
local isTeleporting = false
local lastBiomeName
local currentBiomeName
local nonTargetSince
local lastNoServerLogAt = 0

local function consolePrint(msg)
    print(msg)
end

local function hasAnyTargetBiome()
    for _ in pairs(CONFIG.targetBiomes or {}) do
        return true
    end
    return false
end

local function hasTargetBiome(biomeName)
    return CONFIG.targetBiomes and CONFIG.targetBiomes[biomeName] == true
end

local function getServerJoinLinks(instanceId)
    local pid = game.PlaceId
    local jobId = instanceId or game.JobId
    return {
        deepLink = ("roblox://placeID=%d&gameInstanceId=%s"):format(pid, jobId),
        webLink = ("https://www.roblox.com/games/%d?gameInstanceId=%s"):format(pid, jobId)
    }
end

local function normalizeBiomeName(rawText)
    if typeof(rawText) ~= "string" then
        return nil
    end

    local text = rawText:gsub("^%s*%[%s*", ""):gsub("%s*%]%s*$", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return nil
    end

    local lower = text:lower()
    if lower == "the limbo" then
        return "The Limbo"
    end

    return lower:gsub("(%a)([%w_]*)", function(first, rest)
        return first:upper() .. rest
    end)
end

local function findBiomeLabel()
    local parentSize = UDim2.fromScale(0.3, 0.03)
    local childSize = UDim2.fromScale(0, 0.7)

    for _, descendant in ipairs(MainInterface:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant.Size == parentSize then
            for _, child in ipairs(descendant:GetChildren()) do
                if child:IsA("TextLabel") and child.Size == childSize then
                    return child
                end
            end
        end
    end

    return nil
end

local biomeLabel = findBiomeLabel()

local function buildMessage(biomeName)
    local pingText = ""
    if CONFIG.pingUser and CONFIG.discordUserId ~= "" and CONFIG.discordUserId ~= "USERID" then
        pingText = ("<@%s> "):format(CONFIG.discordUserId)
    end

    local message = ("%sNew biome detected: **%s**"):format(pingText, biomeName)
    if CONFIG.shareServerJoinLinks then
        local links = getServerJoinLinks(game.JobId)
        message = message
            .. "\nServer Instance: `" .. game.JobId .. "`"
            .. "\nJoin (roblox://): " .. links.deepLink
            .. "\nJoin (web): " .. links.webLink
    end

    return message
end

local function sendWebhook(biomeName)
    if not requestFn then
        consolePrint("[BiomeNotifier] request/http_request not found, cannot send webhook.")
        return
    end
    if CONFIG.webhookUrl == "" then
        consolePrint("[BiomeNotifier] webhook URL is empty.")
        return
    end

    local payload = {
        content = buildMessage(biomeName)
    }

    local ok, response = pcall(function()
        return requestFn({
            Url = CONFIG.webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end)

    if ok then
        consolePrint(("[BiomeNotifier] Sent webhook for %s"):format(biomeName))
    else
        consolePrint(("[BiomeNotifier] Webhook failed for %s: %s"):format(biomeName, tostring(response)))
    end
end

local function findPlayButton()
    for _, v in ipairs(PlayerGui:GetDescendants()) do
        local isButton = v:IsA("TextButton") or v:IsA("ImageButton")
        if isButton and v.Visible and v.Active then
            local text = v:IsA("TextButton") and (v.Text or "") or (v.Name or "")
            local lowerText = text:lower()
            local lowerName = (v.Name or ""):lower()
            local parentPath = v:GetFullName():lower()

            -- Restrict auto-click to loading/menu play buttons to avoid random UI buttons.
            local isLikelyLoadingButton = parentPath:find("loading", 1, true)
                or parentPath:find("mainmenu", 1, true)
                or parentPath:find("testloading", 1, true)

            if (lowerText == "play" or lowerName:find("play", 1, true)) and isLikelyLoadingButton then
                return v
            end
        end
    end

    return nil
end

local function autoPressPlayIfNeeded()
    if not CONFIG.autoPressPlayAfterHop then
        return
    end
    -- If biomeLabel already exists, the player is already in-game; no play button needed.
    if biomeLabel then
        return
    end
    if Player:GetAttribute("PlayBegin") then
        return
    end

    local deadline = tick() + CONFIG.playAutoStartTimeout
    while tick() < deadline and not Player:GetAttribute("PlayBegin") do
        local playButton = findPlayButton()
        if playButton then
            pcall(function()
                playButton:Activate()
            end)
            consolePrint("[BiomeNotifier] Attempted Play button click.")
        end

        task.wait(CONFIG.playClickRetryInterval)
    end

    if Player:GetAttribute("PlayBegin") then
        consolePrint("[BiomeNotifier] PlayBegin confirmed.")
    else
        consolePrint("[BiomeNotifier] PlayBegin not confirmed within timeout.")
    end
end

local function queueScriptForTeleport()
    if not CONFIG.reexecuteScript then
        return
    end

    if not queueOnTeleportFn then
        consolePrint("[BiomeNotifier] queue_on_teleport not found on this executor.")
        return
    end

    local queuedCode
    if CONFIG.scriptSourceUrl ~= "" then
        queuedCode = ("loadstring(game:HttpGet(%q))()"):format(CONFIG.scriptSourceUrl)
    else
        consolePrint("[BiomeNotifier] scriptSourceUrl is empty, queueing only global flag.")
        queuedCode = "_G.BiomeCheck=true"
    end

    local ok, err = pcall(queueOnTeleportFn, queuedCode)
    if ok then
        consolePrint("[BiomeNotifier] Script queued for teleport.")
    else
        consolePrint("[BiomeNotifier] Failed to queue on teleport: " .. tostring(err))
    end
end

local function httpGet(url)
    if requestFn then
        local ok, response = pcall(function()
            return requestFn({
                Url = url,
                Method = "GET"
            })
        end)

        if ok and response and (response.Body or response.body) then
            return true, response.Body or response.body
        end
    end

    if game.HttpGet then
        local ok, body = pcall(function()
            return game:HttpGet(url)
        end)
        if ok then
            return true, body
        end
    end

    return false, "No HTTP method available"
end

local function fetchServerPage(serverType, sortOrder, cursor)
    local url = ("https://games.roblox.com/v1/games/%d/servers/%s?sortOrder=%s&limit=100&excludeFullGames=true"):format(
        game.PlaceId,
        serverType,
        sortOrder
    )
    if cursor and cursor ~= "" then
        url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
    end

    local ok, bodyOrError = httpGet(url)
    if not ok then
        return nil, nil, bodyOrError
    end

    local decodeOk, decoded = pcall(function()
        return HttpService:JSONDecode(bodyOrError)
    end)

    if not decodeOk or not decoded then
        return nil, nil, "Failed to decode server list"
    end

    return decoded.data or {}, decoded.nextPageCursor, nil
end

local function collectServers(serverType, sortOrder, maxPages)
    local cursor = ""
    local collected = {}

    for _ = 1, maxPages do
        local servers, nextCursor, err = fetchServerPage(serverType, sortOrder, cursor)
        if not servers then
            return collected, err
        end

        for _, server in ipairs(servers) do
            table.insert(collected, server)
        end

        if not nextCursor or nextCursor == "" then
            break
        end
        cursor = nextCursor
    end

    return collected, nil
end

local function mergeServers(target, incoming)
    local seen = {}
    for _, s in ipairs(target) do
        if s.id then
            seen[s.id] = true
        end
    end

    for _, s in ipairs(incoming) do
        if s.id and not seen[s.id] then
            table.insert(target, s)
            seen[s.id] = true
        end
    end
end

local function resetVisitedServers()
    visitedServerIds = {}
end

local function collectFriendServerIdSet()
    local set = {}
    if not CONFIG.avoidFriendServers then
        return set
    end

    local friendServers, _ = collectServers("Friend", "Asc", CONFIG.friendServerPagesToScan)
    for _, server in ipairs(friendServers) do
        if server.id then
            set[server.id] = true
        end
    end

    return set
end

local function pickServerInstanceId()
    local serverPool = {}
    local friendServerIds = collectFriendServerIdSet()
    local oldest, oldestErr = collectServers("Public", "Asc", CONFIG.oldestServerPagesToScan)
    local newest, newestErr = collectServers("Public", "Desc", CONFIG.fallbackServerPagesToScan)

    if CONFIG.preferOldestServers then
        mergeServers(serverPool, oldest)
        mergeServers(serverPool, newest)
    else
        mergeServers(serverPool, newest)
        mergeServers(serverPool, oldest)
    end

    for _, server in ipairs(serverPool) do
        local id = server.id

        if id
            and id ~= game.JobId
            and not friendServerIds[id]
            and not visitedServerIds[id] then
            return id, nil
        end
    end

    if CONFIG.clearVisitedIfNoServer and next(visitedServerIds) ~= nil then
        resetVisitedServers()
        for _, server in ipairs(serverPool) do
            local id = server.id
            if id and id ~= game.JobId and not friendServerIds[id] then
                return id, nil
            end
        end
    end

    return nil, tostring(oldestErr or newestErr or "No suitable server found")
end

local function hopServer(reason)
    if isTeleporting then
        return false
    end

    isTeleporting = true
    queueScriptForTeleport()

    for attempt = 1, CONFIG.maxServerHopAttempts do
        local serverId, err = pickServerInstanceId()
        if serverId then
            visitedServerIds[serverId] = true
            local links = getServerJoinLinks(serverId)

            consolePrint(("[BiomeNotifier] Hopping (%s) to %s [attempt %d/%d]"):format(
                tostring(reason or "manual"),
                serverId,
                attempt,
                CONFIG.maxServerHopAttempts
            ))

            if CONFIG.shareServerJoinLinks then
                consolePrint("[BiomeNotifier] Share link (roblox://): " .. links.deepLink)
                consolePrint("[BiomeNotifier] Share link (web): " .. links.webLink)
            end

            local tpOk, tpErr = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, Player)
            end)

            if tpOk then
                task.delay(CONFIG.teleportTimeout, function()
                    isTeleporting = false
                end)
                return true
            end

            consolePrint("[BiomeNotifier] Teleport failed: " .. tostring(tpErr))
        else
            local now = tick()
            if now - lastNoServerLogAt >= CONFIG.noServerRetryCooldown then
                consolePrint("[BiomeNotifier] Could not pick server: " .. tostring(err))
                lastNoServerLogAt = now
            end
        end

        task.wait(CONFIG.hopDelaySeconds)
    end

    isTeleporting = false
    return false
end

_G.HopServer = function(reason)
    return hopServer(reason or "manual")
end

task.spawn(autoPressPlayIfNeeded)

TeleportService.TeleportInitFailed:Connect(function(failedPlayer, teleportResult, errorMessage)
    if failedPlayer ~= Player then
        return
    end

    isTeleporting = false
    consolePrint(("[BiomeNotifier] TeleportInitFailed (%s): %s"):format(
        tostring(teleportResult),
        tostring(errorMessage)
    ))
end)

local function handleBiomeChange(rawBiome)
    if not _G.BiomeCheck then
        return
    end

    local biomeName = normalizeBiomeName(rawBiome)
    if not biomeName then
        return
    end
    if biomeName == lastBiomeName then
        return
    end

    lastBiomeName = biomeName
    currentBiomeName = biomeName

    if hasAnyTargetBiome() and not hasTargetBiome(biomeName) then
        nonTargetSince = nonTargetSince or tick()
    else
        nonTargetSince = nil
    end

    if CONFIG.blacklistedBiomes[biomeName] then
        if CONFIG.autoServerHop and CONFIG.hopOnBlacklistedBiome then
            task.spawn(function()
                hopServer("blacklisted_biome")
            end)
        end
        return
    end

    if not CONFIG.notifyOnlyTargetBiomes or not hasAnyTargetBiome() or hasTargetBiome(biomeName) then
        sendWebhook(biomeName)
    end

    if CONFIG.autoServerHop
        and CONFIG.hopOnNonTargetBiome
        and hasAnyTargetBiome()
        and not hasTargetBiome(biomeName)
        and nonTargetSince
        and tick() - nonTargetSince >= CONFIG.nonTargetHopDelaySeconds then
        task.spawn(function()
            hopServer("non_target_biome_timeout")
        end)
    end
end

local function setupReplicaListener()
    if not CONFIG.useReplicaListener then
        return false
    end

    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if not modules then
        return false
    end

    local utilityModule = modules:FindFirstChild("Utility")
    if not utilityModule then
        return false
    end

    local ok, utility = pcall(require, utilityModule)
    if not ok or not utility or not utility.Replica then
        return false
    end

    local getServerReplica = utility.Replica.GetServerReplica
    if typeof(getServerReplica) ~= "function" then
        return false
    end

    local replica = getServerReplica()
    if not replica then
        return false
    end

    local data = replica.Data
    if data and data.BiomeName then
        handleBiomeChange(data.BiomeName)
    elseif data and data.Biome then
        handleBiomeChange(data.Biome)
    end

    if typeof(replica.ListenToChange) == "function" then
        replica:ListenToChange("BiomeName", function(newBiomeName)
            handleBiomeChange(newBiomeName)
        end)
        replica:ListenToChange("Biome", function(newBiome)
            handleBiomeChange(newBiome)
        end)
    end

    consolePrint("[BiomeNotifier] Using ServerReplica biome listener.")
    return true
end

local hasReplicaListener = setupReplicaListener()
if not hasReplicaListener then
    consolePrint("[BiomeNotifier] Replica unavailable, falling back to GUI text polling.")
end

if biomeLabel then
    biomeLabel:GetPropertyChangedSignal("Text"):Connect(function()
        handleBiomeChange(biomeLabel.Text)
    end)
    handleBiomeChange(biomeLabel.Text)
end

task.spawn(function()
    while _G.BiomeCheck do
        if not biomeLabel or not biomeLabel.Parent then
            biomeLabel = findBiomeLabel()
            if biomeLabel then
                handleBiomeChange(biomeLabel.Text)
            end
        end

        if biomeLabel then
            handleBiomeChange(biomeLabel.Text)
        end

        if CONFIG.autoServerHop
            and CONFIG.hopOnNonTargetBiome
            and hasAnyTargetBiome()
            and currentBiomeName
            and not hasTargetBiome(currentBiomeName)
            and nonTargetSince
            and tick() - nonTargetSince >= CONFIG.nonTargetHopDelaySeconds then
            task.spawn(function()
                hopServer("non_target_biome_timer")
            end)
        end

        task.wait(CONFIG.pollInterval)
    end
end)
