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
-- LOAD KILL AURA API
-- ============================================================================

local KillAuraAPI = nil

local function loadKillAura()
    -- Try to load from _G if already loaded
    if _G.x9m1n then
        KillAuraAPI = _G.x9m1n
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
    if _G.x7d2k then
        MagnetAPI = _G.x7d2k
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
    if _G.AutoFarmAPI then
        AutoFarmAPI = _G.AutoFarmAPI
        return true
    end
    
    -- Otherwise, try to load from pastebin via loadstring
    pcall(function()
        local script = game:HttpGet("https://pastebin.com/raw/AsGJ0SDU")
        local autoFarmFunc = loadstring(script)
        if autoFarmFunc then
            autoFarmFunc()
            if _G.AutoFarmAPI then
                AutoFarmAPI = _G.AutoFarmAPI
                return true
            end
        end
    end)
    
    return AutoFarmAPI ~= nil
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

local function tweenTextColor(obj, newColor, duration)
    local tweenInfo = TweenInfo.new(
        duration or 0.3,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.InOut
    )
    local tween = TweenService:Create(obj, tweenInfo, { TextColor3 = newColor })
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
    screenGui.Name = 'ZenXGui'
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    -- ========================================================================
    -- MAIN WINDOW FRAME
    -- ========================================================================

    local mainFrame = Instance.new('Frame')
    mainFrame.Name = 'MainFrame'
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
    titleBar.Name = 'TitleBar'
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
    contentArea.Name = 'ContentArea'
    contentArea.Size = UDim2.new(1, 0, 1, -35)
    contentArea.Position = UDim2.new(0, 0, 0, 35)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame

    -- ========================================================================
    -- AUTO FARM BUTTON
    -- ========================================================================

    local autoFarmButton = Instance.new('TextButton')
    autoFarmButton.Name = 'AutoFarmButton'
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
    killAuraButton.Name = 'KillAuraButton'
    killAuraButton.Size = UDim2.new(1, -20, 0, 50)
    killAuraButton.Position = UDim2.new(0, 10, 0, 70)
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

    -- Magnet is always enabled by default (no GUI button)

    -- ========================================================================
    -- STATE MANAGEMENT
    -- ========================================================================

    local killAuraEnabled = false
    local autoFarmEnabled = false
    local magnetEnabled = true  -- Magnet always enabled by default

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
            local oldGui = playerGui:FindFirstChild('ZenXGui')
            if oldGui then
                oldGui:Destroy()
            end
        end
    end
    
    -- Load APIs
    loadKillAura()
    loadMagnet()
    loadAutoFarm()
    
    -- Enable Magnet by default (Auto Farm starts disabled)
    if MagnetAPI then
        MagnetAPI.enable()
    end
    
    -- Create GUI
    pcall(createVapeGUI)
end)
