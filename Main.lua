-- ============================================================================
-- ZenX GUI - Kill Aura + Magnet Controller + Auto Farm
-- ============================================================================
-- Modern dark theme with neon accents, smooth animations, and sleek design
-- Loads the Kill Aura API and Magnet API
-- loadstring(game:HttpGet("https://pastebin.com/raw/fb7KjgU0"))()
-- ============================================================================

-- ============================================================================
-- ANTI-DETECTION PATCH (Run FIRST)
-- ============================================================================

pcall(function()
    local ReplicatedStorage = game:GetService('ReplicatedStorage')
    
    -- Disable MedalClipper
    pcall(function()
        local util = ReplicatedStorage:FindFirstChild('Util')
        if util then
            local medalClipper = util:FindFirstChild('MedalClipper')
            if medalClipper then
                if medalClipper:FindFirstChild('TriggerClip') then
                    medalClipper.TriggerClip:Destroy()
                end
                pcall(function()
                    local mockModule = require(medalClipper)
                    if mockModule and mockModule.TriggerClip then
                        mockModule.TriggerClip = function() end
                    end
                end)
            end
        end
    end)
    
    -- Disable entire Promise module
    pcall(function()
        local util = ReplicatedStorage:FindFirstChild('Util')
        if util then
            local promiseUtil = util:FindFirstChild('Promise')
            if promiseUtil then
                for _, child in ipairs(promiseUtil:GetChildren()) do
                    pcall(function() child:Destroy() end)
                end
                promiseUtil:Destroy()
            end
        end
    end)
    
    -- Disable Client.Streaming
    pcall(function()
        local client = ReplicatedStorage:FindFirstChild('Client')
        if client then
            local streaming = client:FindFirstChild('Streaming')
            if streaming then
                streaming:Destroy()
            end
        end
    end)
end)

-- Block debug.traceback from being used in detection
pcall(function()
    local originalTraceback = debug.traceback
    debug.traceback = function()
        return ""
    end
end)

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')

-- ============================================================================
-- RANDOMIZED NAMING (Anti-Detection)
-- ============================================================================

local function generateRandomName(prefix)
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    local length = math.random(8, 12)
    local result = prefix or ''
    for i = 1, length do
        local rand = math.random(1, #chars)
        result = result .. chars:sub(rand, rand)
    end
    return result
end

-- Generate unique names for this session
local GUI_NAME = generateRandomName('Gui_')
local MAIN_FRAME_NAME = generateRandomName('Frame_')
local TITLE_BAR_NAME = generateRandomName('Title_')
local CONTENT_NAME = generateRandomName('Content_')
local BTN1_NAME = generateRandomName('Btn_')
local BTN2_NAME = generateRandomName('Btn_')

-- Randomized global keys
local KILL_AURA_KEY = generateRandomName('k')
local MAGNET_KEY = generateRandomName('m')
local AUTOFARM_KEY = generateRandomName('a')
local CHEST_KEY = generateRandomName('c')
local PLACE_KEY = generateRandomName('p')

-- ============================================================================
-- LOAD PLACE DETECTION API
-- ============================================================================

local PlaceAPI = nil

local function loadPlaceAPI()
    -- Try to load from _G if already loaded
    if _G[PLACE_KEY] then
        PlaceAPI = _G[PLACE_KEY]
        return true
    end
    if _G.x5n3d then
        PlaceAPI = _G.x5n3d
        _G[PLACE_KEY] = PlaceAPI
        return true
    end
    
    -- Otherwise, try to load from pastebin via loadstring
    pcall(function()
        local script = game:HttpGet("https://pastebin.com/raw/3fC7kawP")
        local placeFunc = loadstring(script)
        if placeFunc then
            placeFunc()
            if _G.x5n3d then
                PlaceAPI = _G.x5n3d
                _G[PLACE_KEY] = PlaceAPI
                return true
            end
        end
    end)
    
    return PlaceAPI ~= nil
end

-- Attempt late-load of PlaceAPI if it wasn't available initially
local function checkAndLoadPlaceAPI()
    if PlaceAPI == nil and _G.x5n3d then
        PlaceAPI = _G.x5n3d
        updateLocation()
    end
end

-- ============================================================================
-- PLACEID AND LOCATION DETECTION
-- ============================================================================

local PLACE_ID = game.PlaceId
local currentLocation = nil

local function updateLocation()
    if PlaceAPI then
        currentLocation = PlaceAPI.getCurrent()
    end
end

local function isDungeon()
    if currentLocation then
        return currentLocation.isDungeon
    end
    return false
end

local function isWorldOrTower()
    if currentLocation then
        return currentLocation.isLobby or currentLocation.isTower
    end
    return true -- Default to enabled
end

-- ============================================================================
-- LOAD KILL AURA API
-- ============================================================================

local KillAuraAPI = nil

local function loadKillAura()
    -- Try to load from _G if already loaded
    if _G[KILL_AURA_KEY] then
        KillAuraAPI = _G[KILL_AURA_KEY]
        return true
    end
    if _G.x9m1n then
        KillAuraAPI = _G.x9m1n
        _G[KILL_AURA_KEY] = KillAuraAPI
        return true
    end
    
    -- Otherwise, try to load from pastebin via loadstring
    pcall(function()
        local script = game:HttpGet("https://pastebin.com/raw/VfQixNh3")
        local killAuraFunc = loadstring(script)
        if killAuraFunc then
            killAuraFunc()
            if _G.x9m1n then
                KillAuraAPI = _G.x9m1n
                _G[KILL_AURA_KEY] = KillAuraAPI
                return true
            end
        end
    end)
    
    return KillAuraAPI ~= nil
end

-- ============================================================================
-- LOAD MAGNET API
-- ============================================================================

local MagnetAPI = nil

local function loadMagnet()
    -- Try to load from _G if already loaded
    if _G[MAGNET_KEY] then
        MagnetAPI = _G[MAGNET_KEY]
        return true
    end
    if _G.x7d2k then
        MagnetAPI = _G.x7d2k
        _G[MAGNET_KEY] = MagnetAPI
        return true
    end
    
    -- Otherwise, try to load from pastebin via loadstring
    pcall(function()
        local script = game:HttpGet("https://pastebin.com/raw/HZQuvwpQ")
        local magnetFunc = loadstring(script)
        if magnetFunc then
            magnetFunc()
            if _G.x7d2k then
                MagnetAPI = _G.x7d2k
                _G[MAGNET_KEY] = MagnetAPI
                return true
            end
        end
    end)
    
    return MagnetAPI ~= nil
end

-- ============================================================================
-- LOAD AUTO FARM API
-- ============================================================================

local AutoFarmAPI = nil

local function loadAutoFarm()
    -- Try to load from _G if already loaded
    if _G[AUTOFARM_KEY] then
        AutoFarmAPI = _G[AUTOFARM_KEY]
        return true
    end
    if _G.x4k7p then
        AutoFarmAPI = _G.x4k7p
        _G[AUTOFARM_KEY] = AutoFarmAPI
        return true
    end
    
    -- Otherwise, try to load from pastebin via loadstring
    pcall(function()
        local script = game:HttpGet("https://pastebin.com/raw/AsGJ0SDU")
        local autoFarmFunc = loadstring(script)
        if autoFarmFunc then
            autoFarmFunc()
            if _G.x4k7p then
                AutoFarmAPI = _G.x4k7p
                _G[AUTOFARM_KEY] = AutoFarmAPI
                return true
            end
        end
    end)
    
    return AutoFarmAPI ~= nil
end

-- ============================================================================
-- LOAD CHEST COLLECTOR API
-- ============================================================================

local ChestAPI = nil

local function loadChestCollector()
    -- Try to load from _G if already loaded
    if _G[CHEST_KEY] then
        ChestAPI = _G[CHEST_KEY]
        return true
    end
    if _G.x2m8q then
        ChestAPI = _G.x2m8q
        _G[CHEST_KEY] = ChestAPI
        return true
    end
    
    -- Otherwise, try to load from pastebin via loadstring
    pcall(function()
        local script = game:HttpGet("https://pastebin.com/raw/9282RzYC")
        local chestFunc = loadstring(script)
        if chestFunc then
            chestFunc()
            if _G.x2m8q then
                ChestAPI = _G.x2m8q
                _G[CHEST_KEY] = ChestAPI
                return true
            end
        end
    end)
    
    return ChestAPI ~= nil
end

-- ============================================================================
-- COLOR SCHEME (Vape v4 Style)
-- ============================================================================

local Colors = {
    bg_primary = Color3.fromRGB(15, 15, 15),      -- Almost black
    bg_secondary = Color3.fromRGB(25, 25, 25),    -- Slightly lighter
    accent_main = Color3.fromRGB(0, 255, 100),    -- Neon green
    accent_secondary = Color3.fromRGB(0, 200, 255), -- Neon cyan
    accent_danger = Color3.fromRGB(255, 50, 50),  -- Neon red
    text_primary = Color3.fromRGB(255, 255, 255), -- White
    text_secondary = Color3.fromRGB(150, 150, 150), -- Gray
    border = Color3.fromRGB(40, 40, 40),          -- Dark gray border
}

-- ============================================================================
-- TWEEN ANIMATION HELPER
-- ============================================================================

local function tweenColor(obj, newColor, duration)
    local tweenInfo = TweenInfo.new(
        duration or 0.3,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.InOut
    )
    local tween = TweenService:Create(obj, tweenInfo, { BackgroundColor3 = newColor })
    tween:Play()
    return tween
end

-- ============================================================================
-- CREATE VAPE V4 STYLE GUI
-- ============================================================================

local function createVapeGUI()
    local plr = Players.LocalPlayer
    if not plr then return end

    local playerGui = plr:FindFirstChild('PlayerGui')
    if not playerGui then return end

    -- Create ScreenGui container
    local screenGui = Instance.new('ScreenGui')
    screenGui.Name = GUI_NAME
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    -- ========================================================================
    -- MAIN WINDOW FRAME
    -- ========================================================================

    local mainFrame = Instance.new('Frame')
    mainFrame.Name = MAIN_FRAME_NAME
    mainFrame.Size = UDim2.new(0, 250, 0, 170)
    mainFrame.Position = UDim2.new(0.5, -125, 0, 20)
    mainFrame.BackgroundColor3 = Colors.bg_primary
    mainFrame.BorderColor3 = Colors.border
    mainFrame.BorderSizePixel = 2
    mainFrame.Active = true -- allow input capture
    pcall(function() mainFrame.Draggable = true end) -- legacy draggable fallback
    mainFrame.Parent = screenGui

    -- Add corner radius effect with UICorner
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame

    -- ========================================================================
    -- TITLE BAR
    -- ========================================================================

    local titleBar = Instance.new('Frame')
    titleBar.Name = TITLE_BAR_NAME
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Colors.bg_secondary
    titleBar.BorderColor3 = Colors.border
    titleBar.BorderSizePixel = 0
    titleBar.Active = true
    titleBar.Parent = mainFrame

    local titleCorner = Instance.new('UICorner')
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar

    -- Title Text
    local titleLabel = Instance.new('TextLabel')
    titleLabel.Name = 'Title'
    titleLabel.Size = UDim2.new(1, -40, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Colors.accent_main
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = 'ZenX'
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    -- ========================================================================
    -- DRAGGING (TitleBar drag moves MainFrame)
    -- ========================================================================

    local dragging = false
    local dragStart
    local startPos

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- ========================================================================
    -- CONTENT AREA
    -- ========================================================================

    local contentArea = Instance.new('Frame')
    contentArea.Name = CONTENT_NAME
    contentArea.Size = UDim2.new(1, 0, 1, -35)
    contentArea.Position = UDim2.new(0, 0, 0, 35)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame

    -- ========================================================================
    -- AUTO FARM BUTTON
    -- ========================================================================

    local autoFarmButton = Instance.new('TextButton')
    autoFarmButton.Name = BTN1_NAME
    autoFarmButton.Size = UDim2.new(1, -20, 0, 50)
    autoFarmButton.Position = UDim2.new(0, 10, 0, 10)
    autoFarmButton.BackgroundColor3 = Colors.accent_danger
    autoFarmButton.BorderColor3 = Colors.border
    autoFarmButton.BorderSizePixel = 1
    autoFarmButton.TextColor3 = Colors.text_primary
    autoFarmButton.TextSize = 14
    autoFarmButton.Font = Enum.Font.GothamBold
    autoFarmButton.Text = '🚀 AUTO FARM'
    autoFarmButton.Parent = contentArea

    local autoFarmCorner = Instance.new('UICorner')
    autoFarmCorner.CornerRadius = UDim.new(0, 6)
    autoFarmCorner.Parent = autoFarmButton

    -- ========================================================================
    -- KILL AURA BUTTON
    -- ========================================================================

    local killAuraButton = Instance.new('TextButton')
    killAuraButton.Name = BTN2_NAME
    killAuraButton.Size = UDim2.new(1, -20, 0, 50)
    killAuraButton.Position = UDim2.new(0, 10, 0, 70)
    killAuraButton.BackgroundColor3 = Colors.accent_danger
    killAuraButton.BorderColor3 = Colors.border
    killAuraButton.BorderSizePixel = 1
    killAuraButton.TextColor3 = Colors.text_primary
    killAuraButton.TextSize = 14
    killAuraButton.Font = Enum.Font.GothamBold
    killAuraButton.Text = '⚔ KILL AURA'
    killAuraButton.Parent = contentArea

    local killAuraCorner = Instance.new('UICorner')
    killAuraCorner.CornerRadius = UDim.new(0, 6)
    killAuraCorner.Parent = killAuraButton

    -- Magnet is always enabled by default (no GUI button)
    -- Chest Collector is auto-enabled based on PlaceID (no button)

    -- ========================================================================
    -- STATE MANAGEMENT
    -- ========================================================================

    local killAuraEnabled = false
    local autoFarmEnabled = false
    local magnetEnabled = true  -- Magnet always enabled by default
    -- Chest collector auto-managed by PlaceID
    
    -- Function to update title text
    local function updateTitleText()
        local newTitle = 'ZenX'
        if currentLocation and currentLocation.name then
            newTitle = 'ZenX | ' .. currentLocation.name
        else
            newTitle = 'ZenX | ID: ' .. tostring(PLACE_ID)
        end
        if titleLabel.Text ~= newTitle then
            titleLabel.Text = newTitle
        end
    end
    
    -- Set initial title
    updateTitleText()
    
    -- Update title whenever location changes
    task.spawn(function()
        local lastLocationCheck = currentLocation
        while titleLabel.Parent do
            task.wait(1)
            checkAndLoadPlaceAPI()
            if currentLocation ~= lastLocationCheck then
                updateTitleText()
                lastLocationCheck = currentLocation
            end
        end
    end)

    -- ========================================================================
    -- KILL AURA BUTTON INTERACTIONS
    -- ========================================================================

    killAuraButton.MouseButton1Click:Connect(function()
        killAuraEnabled = not killAuraEnabled

        if killAuraEnabled then
            tweenColor(killAuraButton, Colors.accent_main, 0.2)
            if KillAuraAPI then
                KillAuraAPI:start()
            end
        else
            tweenColor(killAuraButton, Colors.accent_danger, 0.2)
            if KillAuraAPI then
                KillAuraAPI:stop()
            end
        end
    end)

    killAuraButton.MouseEnter:Connect(function()
        if killAuraEnabled then
            tweenColor(killAuraButton, Color3.fromRGB(0, 200, 80), 0.15)
        else
            tweenColor(killAuraButton, Color3.fromRGB(220, 30, 30), 0.15)
        end
    end)

    killAuraButton.MouseLeave:Connect(function()
        if killAuraEnabled then
            tweenColor(killAuraButton, Colors.accent_main, 0.15)
        else
            tweenColor(killAuraButton, Colors.accent_danger, 0.15)
        end
    end)

    -- ========================================================================
    -- AUTO FARM BUTTON INTERACTIONS
    -- ========================================================================

    autoFarmButton.MouseButton1Click:Connect(function()
        autoFarmEnabled = not autoFarmEnabled

        if autoFarmEnabled then
            tweenColor(autoFarmButton, Colors.accent_main, 0.2)
            if AutoFarmAPI then
                AutoFarmAPI.enable()
            end
        else
            tweenColor(autoFarmButton, Colors.accent_danger, 0.2)
            if AutoFarmAPI then
                AutoFarmAPI.disable()
            end
        end
    end)

    autoFarmButton.MouseEnter:Connect(function()
        if autoFarmEnabled then
            tweenColor(autoFarmButton, Color3.fromRGB(0, 200, 80), 0.15)
        else
            tweenColor(autoFarmButton, Color3.fromRGB(220, 30, 30), 0.15)
        end
    end)

    autoFarmButton.MouseLeave:Connect(function()
        if autoFarmEnabled then
            tweenColor(autoFarmButton, Colors.accent_main, 0.15)
        else
            tweenColor(autoFarmButton, Colors.accent_danger, 0.15)
        end
    end)

    -- ========================================================================
    -- MAGNET BUTTON INTERACTIONS
    -- ========================================================================

    -- Magnet is always enabled, no button interactions needed

    -- ========================================================================
    -- RETURN STATE FOR EXTERNAL ACCESS
    -- ========================================================================

    return {
        screenGui = screenGui,
        mainFrame = mainFrame,
        killAuraButton = killAuraButton,
        autoFarmButton = autoFarmButton,
    }
end

-- ============================================================================
-- INITIALIZE
-- ============================================================================

spawn(function()
    wait(1)
    
    -- Cleanup: Disable Kill Aura if running and remove old GUI
    if KillAuraAPI and KillAuraAPI.running then
        KillAuraAPI:stop()
    end
    
    -- Cleanup: Disable Magnet if running
    if MagnetAPI then
        MagnetAPI.disable()
    end
    
    -- Cleanup: Disable Auto Farm if running
    if AutoFarmAPI then
        AutoFarmAPI.disable()
    end
    
    -- Remove old GUI if exists
    local plr = Players.LocalPlayer
    if plr then
        local playerGui = plr:FindFirstChild('PlayerGui')
        if playerGui then
            -- Clean up any GUI with pattern matching
            for _, gui in ipairs(playerGui:GetChildren()) do
                if gui:IsA('ScreenGui') and (gui.Name:match('^Gui_') or gui.Name == 'ZenXGui') then
                    gui:Destroy()
                end
            end
        end
    end
    
    -- Load APIs
    loadPlaceAPI()
    updateLocation()
    loadKillAura()
    loadMagnet()
    loadAutoFarm()
    loadChestCollector()
    
    -- Enable Magnet by default (Auto Farm starts disabled)
    if MagnetAPI then
        MagnetAPI.enable()
    end
    
    -- Auto-enable Chest Collector based on PlaceID
    if ChestAPI then
        if isWorldOrTower() then
            -- Enable for world/tower
            ChestAPI.enable()
        else
            -- Disable for dungeon
            ChestAPI.disable()
        end
    end
    
    -- Create GUI
    pcall(createVapeGUI)
end)
