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
    -- Put your hosted script URL here so the script auto-loads after teleport.
    scriptSourceUrl = "",
    autoServerHop = false,
    hopOnBlacklistedBiome = false,
    hopOnNonTargetBiome = false,
    hopDelaySeconds = 2,
    maxServerHopAttempts = 10,
    blacklistedBiomes = {
        Normal = true,
        ["The Limbo"] = true,
        Limbo = true
    },
    -- Optional whitelist for auto-hop mode. Empty means disabled.
    targetBiomes = {
        -- Example: Starfall = true
    }
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

local function consolePrint(msg)
    print(msg)
end

local function shouldTargetBiome(biomeName)
    if not CONFIG.targetBiomes then
        return false
    end

    for _ in pairs(CONFIG.targetBiomes) do
        return true
    end

    return false
end

local function hasTargetBiome(biomeName)
    return CONFIG.targetBiomes and CONFIG.targetBiomes[biomeName] == true
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

local visitedServerIds = {}
local isTeleporting = false

local function fetchServerPage(cursor)
    local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true"):format(game.PlaceId)
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

local function pickServerInstanceId()
    local cursor = ""
    local pages = 0

    while pages < 6 do
        pages = pages + 1
        local servers, nextCursor, err = fetchServerPage(cursor)
        if not servers then
            return nil, err
        end

        for _, server in ipairs(servers) do
            local id = server.id
            local playing = tonumber(server.playing) or 0
            local maxPlayers = tonumber(server.maxPlayers) or 0

            if id
                and id ~= game.JobId
                and not visitedServerIds[id]
                and playing < maxPlayers then
                return id, nil
            end
        end

        if not nextCursor or nextCursor == "" then
            break
        end
        cursor = nextCursor
    end

    return nil, "No suitable server found"
end

local function hopServer(reason)
    if isTeleporting then
        return
    end

    isTeleporting = true
    queueScriptForTeleport()

    for attempt = 1, CONFIG.maxServerHopAttempts do
        local serverId, err = pickServerInstanceId()
        if serverId then
            visitedServerIds[serverId] = true
            consolePrint(("[BiomeNotifier] Hopping (%s) to %s [attempt %d/%d]"):format(
                tostring(reason or "manual"),
                serverId,
                attempt,
                CONFIG.maxServerHopAttempts
            ))

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
            consolePrint("[BiomeNotifier] Could not pick server: " .. tostring(err))
        end

        task.wait(CONFIG.hopDelaySeconds)
    end

    isTeleporting = false
    return false
end

_G.HopServer = function(reason)
    return hopServer(reason or "manual")
end

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

    -- Convert all-caps display text to title case (e.g. STARFALL -> Starfall).
    return lower:gsub("(%a)([%w_]*)", function(first, rest)
        return first:upper() .. rest
    end)
end

local function findBiomeLabel()
    local targetParentSize = UDim2.fromScale(0.3, 0.03)
    local targetChildSize = UDim2.fromScale(0, 0.7)

    for _, descendant in ipairs(MainInterface:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant.Size == targetParentSize then
            for _, child in ipairs(descendant:GetChildren()) do
                if child:IsA("TextLabel") and child.Size == targetChildSize then
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

    return ("%sNew biome detected: **%s**"):format(pingText, biomeName)
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

    local content = buildMessage(biomeName)
    local payload = {
        content = content
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

local lastBiomeName
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
    if CONFIG.blacklistedBiomes[biomeName] then
        if CONFIG.autoServerHop and CONFIG.hopOnBlacklistedBiome then
            task.spawn(function()
                hopServer("blacklisted_biome")
            end)
        end
        return
    end

    sendWebhook(biomeName)

    if CONFIG.autoServerHop
        and CONFIG.hopOnNonTargetBiome
        and shouldTargetBiome(biomeName)
        and not hasTargetBiome(biomeName) then
        task.spawn(function()
            hopServer("non_target_biome")
        end)
    end
end

local function setupReplicaListener()
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

        task.wait(CONFIG.pollInterval)
    end
end)
