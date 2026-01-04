-- ============================================================================
-- Kill Aura Settings API - Settings Management for Kill Aura
-- ============================================================================
-- https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/killaurasettingsapi.lua
-- Manages Kill Aura settings with save/load functionality
-- Provides GUI overlay for adjusting anti-detection and combat settings
--
-- FEATURES:
-- • Kill Aura Enable/Disable toggle
-- • Anti-Detection settings (timing variance, pause chance, burst mode)
-- • Attack delay configuration
-- • Combo behavior settings
-- • Persistent settings via file storage
-- • Real-time updates to Kill Aura parameters
-- • Click-through prevention on GUI overlay
--
-- USAGE:
-- local SettingsAPI = _G.KillAuraSettingsAPI
-- SettingsAPI.show(parentFrame)  -- Show settings overlay
-- SettingsAPI.hide()             -- Hide settings overlay
-- SettingsAPI.toggle()           -- Toggle settings overlay
-- SettingsAPI.loadSettings()     -- Load saved settings
-- SettingsAPI.saveSettings()     -- Save current settings
-- ============================================================================

local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')

local _genv = getgenv()

-- ============================================================================
-- SETTINGS FILE PATH
-- ============================================================================
local ZENX_FOLDER = "ZenX WZ"
local SETTINGS_FILE = ZENX_FOLDER .. "/zenx_killaura_settings.json"

-- Ensure folder exists
local function ensureFolder()
    if isfolder and makefolder then
        pcall(function()
            if not isfolder(ZENX_FOLDER) then
                makefolder(ZENX_FOLDER)
            end
        end)
    end
end

-- ============================================================================
-- DEFAULT SETTINGS (Matching killaura.lua AntiDetection config)
-- ============================================================================
local defaultSettings = {
    -- Kill Aura state
    killAuraEnabled = false,
    
    -- Anti-Detection Configuration
    timingVariance = 0.18,              -- 18% variance on all timings
    minAttackDelay = 0.02,              -- Minimum delay between attacks
    maxAttackDelay = 0.12,              -- Maximum delay between attacks
    
    -- Human-like behavior
    pauseChance = 0.02,                 -- 2% chance to pause
    pauseMinDuration = 0.6,             -- Minimum pause duration
    pauseMaxDuration = 1.8,             -- Maximum pause duration
    
    -- Combo behavior
    comboBreakChance = 0.06,            -- 6% chance to break combo early
    
    -- Burst behavior (simulates player excitement)
    burstChance = 0.04,                 -- 4% chance to enter "burst mode"
    burstDuration = 1.5,                -- Burst mode lasts ~1.5 seconds
    burstSpeedMultiplier = 0.75,        -- During burst, delays are 75% of normal
    
    -- Ultimate settings
    ultimateEnergyThreshold = 0.98,     -- 98% energy required for ultimate
    ultimateCooldown = 35,              -- Ultimate cooldown in seconds
    
    -- Targeting
    direProblemBossTarget = false,      -- Allow targeting Dire Problem boss
}

-- Current settings (initialized with defaults)
local currentSettings = {}
for key, value in pairs(defaultSettings) do
    currentSettings[key] = value
end

-- ============================================================================
-- COLORS (Matching ZenX theme - Red accent for Kill Aura)
-- ============================================================================
local Colors = {
    bg_primary = Color3.fromRGB(15, 15, 15),
    bg_secondary = Color3.fromRGB(25, 25, 25),
    bg_overlay = Color3.fromRGB(18, 18, 18),
    bg_section = Color3.fromRGB(28, 28, 28),
    accent_main = Color3.fromRGB(255, 80, 80),       -- Red for Kill Aura
    accent_secondary = Color3.fromRGB(255, 120, 80), -- Orange accent
    accent_enabled = Color3.fromRGB(0, 255, 100),    -- Green for enabled
    accent_disabled = Color3.fromRGB(255, 50, 50),   -- Red for disabled
    text_primary = Color3.fromRGB(255, 255, 255),
    text_secondary = Color3.fromRGB(150, 150, 150),
    text_muted = Color3.fromRGB(100, 100, 100),
    border = Color3.fromRGB(45, 45, 45),
    slider_bg = Color3.fromRGB(35, 35, 35),
    slider_fill = Color3.fromRGB(255, 100, 100),
    settings_button = Color3.fromRGB(255, 80, 80),
}

-- ============================================================================
-- GUI REFERENCES
-- ============================================================================
local settingsOverlay = nil
local isVisible = false
local parentFrame = nil
local inputConnections = {} -- Track input connections for cleanup

-- ============================================================================
-- JSON HELPERS
-- ============================================================================
local function encodeJSON(data)
    local success, result = pcall(function()
        local HttpService = game:GetService("HttpService")
        return HttpService:JSONEncode(data)
    end)
    if success then return result end
    
    -- Fallback: manual encode for simple data
    local parts = {}
    for key, value in pairs(data) do
        local valStr
        if type(value) == "string" then
            valStr = '"' .. tostring(value):gsub('"', '\\"') .. '"'
        elseif type(value) == "number" then
            valStr = tostring(value)
        elseif type(value) == "boolean" then
            valStr = tostring(value)
        else
            valStr = '"' .. tostring(value) .. '"'
        end
        table.insert(parts, '"' .. key .. '":' .. valStr)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function decodeJSON(jsonStr)
    local success, result = pcall(function()
        local HttpService = game:GetService("HttpService")
        return HttpService:JSONDecode(jsonStr)
    end)
    if success then return result end
    
    -- Fallback: simple manual parse
    local data = {}
    for key, value in string.gmatch(jsonStr, '"([^"]+)"%s*:%s*([^,}]+)') do
        value = value:match('^%s*(.-)%s*$')
        value = value:gsub('^"', ''):gsub('"$', '')
        local numVal = tonumber(value)
        if value == "true" then
            data[key] = true
        elseif value == "false" then
            data[key] = false
        elseif numVal then
            data[key] = numVal
        else
            data[key] = value
        end
    end
    return data
end

-- ============================================================================
-- APPLY SETTINGS TO KILL AURA
-- ============================================================================
local function applySettingsToKillAura()
    -- Apply to global AntiDetection config if available
    local antiDetection = _genv.KillAuraAntiDetection
    if antiDetection then
        antiDetection.timingVariance = currentSettings.timingVariance
        antiDetection.minAttackDelay = currentSettings.minAttackDelay
        antiDetection.maxAttackDelay = currentSettings.maxAttackDelay
        antiDetection.pauseChance = currentSettings.pauseChance
        antiDetection.pauseMinDuration = currentSettings.pauseMinDuration
        antiDetection.pauseMaxDuration = currentSettings.pauseMaxDuration
        antiDetection.comboBreakChance = currentSettings.comboBreakChance
        antiDetection.burstChance = currentSettings.burstChance
        antiDetection.burstDuration = currentSettings.burstDuration
        antiDetection.burstSpeedMultiplier = currentSettings.burstSpeedMultiplier
    end
    
    -- Apply Dire Problem boss targeting
    _genv.DireProblemBossTarget = currentSettings.direProblemBossTarget
    
    -- Apply Kill Aura enabled state
    local killAura = _G.x9m1n or _G.killAura or _genv.x9m1n or _genv.killAura
    if killAura then
        if currentSettings.killAuraEnabled then
            if not killAura.running then
                pcall(function() killAura.start() end)
            end
        else
            if killAura.running then
                pcall(function() killAura.stop() end)
            end
        end
    end
end

-- ============================================================================
-- SETTINGS PERSISTENCE
-- ============================================================================
local function saveSettings()
    if not writefile then
        warn("[KillAuraSettings] writefile not available - cannot save settings")
        return false
    end
    
    ensureFolder()
    
    local success, err = pcall(function()
        local jsonStr = encodeJSON(currentSettings)
        writefile(SETTINGS_FILE, jsonStr)
    end)
    
    if success then
        return true
    else
        warn("[KillAuraSettings] ⚠️ Failed to save settings: " .. tostring(err))
        return false
    end
end

local function loadSettings()
    if not readfile or not isfile then
        warn("[KillAuraSettings] readfile/isfile not available - using defaults")
        return false
    end
    
    local success, result = pcall(function()
        if isfile(SETTINGS_FILE) then
            local content = readfile(SETTINGS_FILE)
            if content and content ~= "" then
                local decoded = decodeJSON(content)
                if decoded then
                    for key, defaultValue in pairs(defaultSettings) do
                        if decoded[key] ~= nil then
                            if type(defaultValue) == "number" then
                                currentSettings[key] = tonumber(decoded[key]) or defaultValue
                            elseif type(defaultValue) == "boolean" then
                                currentSettings[key] = decoded[key] == true
                            else
                                currentSettings[key] = decoded[key]
                            end
                        end
                    end
                    return true
                end
            end
        end
        return false
    end)
    
    if success and result then
        applySettingsToKillAura()
        return true
    else
        return false
    end
end

-- ============================================================================
-- TWEEN HELPER
-- ============================================================================
local function tweenProperty(obj, props, duration)
    if not obj or not obj.Parent then return nil end
    local tweenInfo = TweenInfo.new(
        duration or 0.2,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(obj, tweenInfo, props)
    tween:Play()
    return tween
end

-- ============================================================================
-- CLEANUP INPUT CONNECTIONS
-- ============================================================================
local function cleanupConnections()
    for _, conn in ipairs(inputConnections) do
        if conn and typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    inputConnections = {}
end

-- ============================================================================
-- CREATE SECTION HEADER
-- ============================================================================
local function createSectionHeader(parent, text, yPosition)
    local header = Instance.new('Frame')
    header.Name = text:gsub('%s+', '') .. '_Header'
    header.Size = UDim2.new(1, -20, 0, 24)
    header.Position = UDim2.new(0, 10, 0, yPosition)
    header.BackgroundColor3 = Colors.bg_section
    header.BorderSizePixel = 0
    header.Active = true  -- Block click-through
    header.ZIndex = 113
    header.Parent = parent
    
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = header
    
    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Colors.accent_secondary
    label.TextSize = 11
    label.Font = Enum.Font.GothamBold
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 114
    label.Parent = header
    
    return header
end

-- ============================================================================
-- CREATE TOGGLE BUTTON
-- ============================================================================
local function createToggle(parent, labelText, initialValue, yPosition, onValueChanged)
    local toggleContainer = Instance.new('Frame')
    toggleContainer.Name = labelText:gsub('%s+', '') .. '_Toggle'
    toggleContainer.Size = UDim2.new(1, -20, 0, 32)
    toggleContainer.Position = UDim2.new(0, 10, 0, yPosition)
    toggleContainer.BackgroundTransparency = 1
    toggleContainer.Active = true  -- Block click-through
    toggleContainer.ZIndex = 113
    toggleContainer.Parent = parent
    
    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Colors.text_primary
    label.TextSize = 11
    label.Font = Enum.Font.Gotham
    label.Text = labelText
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 114
    label.Parent = toggleContainer
    
    local toggleBg = Instance.new('Frame')
    toggleBg.Name = 'ToggleBg'
    toggleBg.Size = UDim2.new(0, 44, 0, 22)
    toggleBg.Position = UDim2.new(1, -44, 0.5, -11)
    toggleBg.BackgroundColor3 = initialValue and Colors.accent_enabled or Colors.slider_bg
    toggleBg.BorderSizePixel = 0
    toggleBg.Active = true
    toggleBg.ZIndex = 114
    toggleBg.Parent = toggleContainer
    
    local bgCorner = Instance.new('UICorner')
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = toggleBg
    
    local knob = Instance.new('Frame')
    knob.Name = 'Knob'
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = initialValue and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Colors.text_primary
    knob.BorderSizePixel = 0
    knob.ZIndex = 115
    knob.Parent = toggleBg
    
    local knobCorner = Instance.new('UICorner')
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    
    local currentValue = initialValue
    
    local clickArea = Instance.new('TextButton')
    clickArea.Name = 'ClickArea'
    clickArea.Size = UDim2.new(1, 0, 1, 0)
    clickArea.Position = UDim2.new(0, 0, 0, 0)
    clickArea.BackgroundTransparency = 1
    clickArea.Text = ''
    clickArea.AutoButtonColor = false
    clickArea.ZIndex = 116
    clickArea.Parent = toggleBg
    
    clickArea.MouseButton1Click:Connect(function()
        currentValue = not currentValue
        
        if currentValue then
            tweenProperty(toggleBg, {BackgroundColor3 = Colors.accent_enabled}, 0.15)
            tweenProperty(knob, {Position = UDim2.new(1, -20, 0.5, -9)}, 0.15)
        else
            tweenProperty(toggleBg, {BackgroundColor3 = Colors.slider_bg}, 0.15)
            tweenProperty(knob, {Position = UDim2.new(0, 2, 0.5, -9)}, 0.15)
        end
        
        if onValueChanged then
            onValueChanged(currentValue)
        end
    end)
    
    return {
        container = toggleContainer,
        getValue = function() return currentValue end,
        setValue = function(val)
            currentValue = val
            if currentValue then
                toggleBg.BackgroundColor3 = Colors.accent_enabled
                knob.Position = UDim2.new(1, -20, 0.5, -9)
            else
                toggleBg.BackgroundColor3 = Colors.slider_bg
                knob.Position = UDim2.new(0, 2, 0.5, -9)
            end
        end
    }
end

-- ============================================================================
-- CREATE SLIDER COMPONENT (with click-through prevention)
-- ============================================================================
local function createSlider(parent, labelText, minVal, maxVal, increment, initialValue, yPosition, onValueChanged, formatFunc)
    local sliderContainer = Instance.new('Frame')
    sliderContainer.Name = labelText:gsub('%s+', '') .. '_Container'
    sliderContainer.Size = UDim2.new(1, -20, 0, 44)
    sliderContainer.Position = UDim2.new(0, 10, 0, yPosition)
    sliderContainer.BackgroundTransparency = 1
    sliderContainer.Active = true  -- Block click-through
    sliderContainer.ZIndex = 113
    sliderContainer.Parent = parent
    
    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.new(0.65, 0, 0, 16)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Colors.text_primary
    label.TextSize = 11
    label.Font = Enum.Font.Gotham
    label.Text = labelText
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 114
    label.Parent = sliderContainer
    
    local displayValue = formatFunc and formatFunc(initialValue) or tostring(initialValue)
    local valueLabel = Instance.new('TextLabel')
    valueLabel.Name = 'Value'
    valueLabel.Size = UDim2.new(0.35, 0, 0, 16)
    valueLabel.Position = UDim2.new(0.65, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3 = Colors.accent_main
    valueLabel.TextSize = 11
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Text = displayValue
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.ZIndex = 114
    valueLabel.Parent = sliderContainer
    
    local sliderBg = Instance.new('Frame')
    sliderBg.Name = 'SliderBg'
    sliderBg.Size = UDim2.new(1, 0, 0, 12)
    sliderBg.Position = UDim2.new(0, 0, 0, 22)
    sliderBg.BackgroundColor3 = Colors.slider_bg
    sliderBg.BorderSizePixel = 0
    sliderBg.Active = true
    sliderBg.ZIndex = 114
    sliderBg.Parent = sliderContainer
    
    local bgCorner = Instance.new('UICorner')
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = sliderBg
    
    local sliderFill = Instance.new('Frame')
    sliderFill.Name = 'Fill'
    local percentage = (initialValue - minVal) / (maxVal - minVal)
    sliderFill.Size = UDim2.new(math.clamp(percentage, 0, 1), 0, 1, 0)
    sliderFill.Position = UDim2.new(0, 0, 0, 0)
    sliderFill.BackgroundColor3 = Colors.slider_fill
    sliderFill.BorderSizePixel = 0
    sliderFill.ZIndex = 115
    sliderFill.Parent = sliderBg
    
    local fillCorner = Instance.new('UICorner')
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = sliderFill
    
    local knob = Instance.new('Frame')
    knob.Name = 'Knob'
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(math.clamp(percentage, 0, 1), -8, 0.5, -8)
    knob.BackgroundColor3 = Colors.text_primary
    knob.BorderSizePixel = 0
    knob.Active = true
    knob.ZIndex = 116
    knob.Parent = sliderBg
    
    local knobCorner = Instance.new('UICorner')
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    
    local isDragging = false
    local currentValue = initialValue
    
    local function updateSlider(inputPos)
        local sliderAbsPos = sliderBg.AbsolutePosition
        local sliderAbsSize = sliderBg.AbsoluteSize
        
        if sliderAbsSize.X == 0 then return end
        
        local relativeX = math.clamp((inputPos.X - sliderAbsPos.X) / sliderAbsSize.X, 0, 1)
        
        local rawValue = minVal + (relativeX * (maxVal - minVal))
        local snappedValue = math.floor(rawValue / increment + 0.5) * increment
        snappedValue = math.clamp(snappedValue, minVal, maxVal)
        snappedValue = math.floor(snappedValue * 1000 + 0.5) / 1000
        
        currentValue = snappedValue
        
        local newPercentage = (snappedValue - minVal) / (maxVal - minVal)
        sliderFill.Size = UDim2.new(math.clamp(newPercentage, 0, 1), 0, 1, 0)
        knob.Position = UDim2.new(math.clamp(newPercentage, 0, 1), -8, 0.5, -8)
        valueLabel.Text = formatFunc and formatFunc(snappedValue) or tostring(snappedValue)
        
        if onValueChanged then
            onValueChanged(snappedValue)
        end
    end
    
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            updateSlider(input.Position)
        end
    end)
    
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
        end
    end)
    
    local moveConn = UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input.Position)
        end
    end)
    table.insert(inputConnections, moveConn)
    
    local endConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)
    table.insert(inputConnections, endConn)
    
    return {
        container = sliderContainer,
        getValue = function() return currentValue end,
        setValue = function(val)
            currentValue = math.clamp(val, minVal, maxVal)
            local newPercentage = (currentValue - minVal) / (maxVal - minVal)
            sliderFill.Size = UDim2.new(math.clamp(newPercentage, 0, 1), 0, 1, 0)
            knob.Position = UDim2.new(math.clamp(newPercentage, 0, 1), -8, 0.5, -8)
            valueLabel.Text = formatFunc and formatFunc(currentValue) or tostring(currentValue)
        end
    }
end

-- ============================================================================
-- FORMAT FUNCTIONS
-- ============================================================================
local function formatPercent(value)
    return string.format("%.0f%%", value * 100)
end

local function formatSeconds(value)
    return string.format("%.2fs", value)
end

local function formatMultiplier(value)
    return string.format("%.2fx", value)
end

-- ============================================================================
-- SHOW / HIDE SETTINGS (Forward declarations)
-- ============================================================================
local showSettings, hideSettings, toggleSettings

-- ============================================================================
-- CREATE SETTINGS OVERLAY
-- ============================================================================
local function createSettingsOverlay(parent)
    cleanupConnections()
    if settingsOverlay then
        settingsOverlay:Destroy()
        settingsOverlay = nil
    end
    
    parentFrame = parent
    
    -- Main overlay frame (blocks all clicks behind it)
    settingsOverlay = Instance.new('Frame')
    settingsOverlay.Name = 'KillAuraSettingsOverlay'
    settingsOverlay.Size = UDim2.new(1, 0, 1, 0)
    settingsOverlay.Position = UDim2.new(0, 0, 0, 0)
    settingsOverlay.BackgroundColor3 = Colors.bg_overlay
    settingsOverlay.BackgroundTransparency = 0
    settingsOverlay.BorderSizePixel = 0
    settingsOverlay.Visible = false
    settingsOverlay.Active = true        -- CRITICAL: Block click-through
    settingsOverlay.Selectable = true    -- Extra safety for click-through
    settingsOverlay.ZIndex = 100
    settingsOverlay.Parent = parent
    
    local overlayCorner = Instance.new('UICorner')
    overlayCorner.CornerRadius = UDim.new(0, 8)
    overlayCorner.Parent = settingsOverlay
    
    -- Header
    local header = Instance.new('Frame')
    header.Name = 'Header'
    header.Size = UDim2.new(1, 0, 0, 36)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Colors.bg_secondary
    header.BorderSizePixel = 0
    header.Active = true
    header.ZIndex = 101
    header.Parent = settingsOverlay
    
    local headerCorner = Instance.new('UICorner')
    headerCorner.CornerRadius = UDim.new(0, 8)
    headerCorner.Parent = header
    
    local title = Instance.new('TextLabel')
    title.Name = 'Title'
    title.Size = UDim2.new(1, -45, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Colors.accent_main
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.Text = '⚔️ Kill Aura Settings'
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 102
    title.Parent = header
    
    local closeBtn = Instance.new('TextButton')
    closeBtn.Name = 'Close'
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -32, 0, 4)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    closeBtn.BorderSizePixel = 0
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = 'X'
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 102
    closeBtn.Parent = header
    
    local closeBtnCorner = Instance.new('UICorner')
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        hideSettings()
    end)
    
    closeBtn.MouseEnter:Connect(function()
        tweenProperty(closeBtn, {BackgroundColor3 = Color3.fromRGB(255, 80, 80)}, 0.1)
    end)
    
    closeBtn.MouseLeave:Connect(function()
        tweenProperty(closeBtn, {BackgroundColor3 = Colors.accent_disabled}, 0.1)
    end)
    
    -- Content area with scrolling
    local content = Instance.new('ScrollingFrame')
    content.Name = 'Content'
    content.Size = UDim2.new(1, 0, 1, -86)
    content.Position = UDim2.new(0, 0, 0, 36)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 4
    content.ScrollBarImageColor3 = Colors.slider_fill
    content.CanvasSize = UDim2.new(0, 0, 0, 600)
    content.ScrollingDirection = Enum.ScrollingDirection.Y
    content.ClipsDescendants = true
    content.Active = true
    content.ZIndex = 101
    content.Parent = settingsOverlay
    
    local yOffset = 10
    
    -- ========================================================================
    -- ANTI-DETECTION SECTION
    -- ========================================================================
    createSectionHeader(content, '🛡️ ANTI-DETECTION', yOffset)
    yOffset = yOffset + 30
    
    local timingVarianceSlider = createSlider(
        content, 'Timing Variance',
        0.05, 0.40, 0.01,
        currentSettings.timingVariance,
        yOffset,
        function(value)
            currentSettings.timingVariance = value
            applySettingsToKillAura()
        end,
        formatPercent
    )
    yOffset = yOffset + 50
    
    local pauseChanceSlider = createSlider(
        content, 'Pause Chance',
        0, 0.10, 0.005,
        currentSettings.pauseChance,
        yOffset,
        function(value)
            currentSettings.pauseChance = value
            applySettingsToKillAura()
        end,
        formatPercent
    )
    yOffset = yOffset + 50
    
    local comboBreakSlider = createSlider(
        content, 'Combo Break Chance',
        0, 0.15, 0.01,
        currentSettings.comboBreakChance,
        yOffset,
        function(value)
            currentSettings.comboBreakChance = value
            applySettingsToKillAura()
        end,
        formatPercent
    )
    yOffset = yOffset + 60
    
    -- ========================================================================
    -- ATTACK TIMING SECTION
    -- ========================================================================
    createSectionHeader(content, '⏱️ ATTACK TIMING', yOffset)
    yOffset = yOffset + 30
    
    local minDelaySlider = createSlider(
        content, 'Min Attack Delay',
        0, 0.10, 0.005,
        currentSettings.minAttackDelay,
        yOffset,
        function(value)
            currentSettings.minAttackDelay = value
            applySettingsToKillAura()
        end,
        formatSeconds
    )
    yOffset = yOffset + 50
    
    local maxDelaySlider = createSlider(
        content, 'Max Attack Delay',
        0.05, 0.25, 0.01,
        currentSettings.maxAttackDelay,
        yOffset,
        function(value)
            currentSettings.maxAttackDelay = value
            applySettingsToKillAura()
        end,
        formatSeconds
    )
    yOffset = yOffset + 60
    
    -- ========================================================================
    -- BURST MODE SECTION
    -- ========================================================================
    createSectionHeader(content, '💥 BURST MODE', yOffset)
    yOffset = yOffset + 30
    
    local burstChanceSlider = createSlider(
        content, 'Burst Activation Chance',
        0, 0.15, 0.01,
        currentSettings.burstChance,
        yOffset,
        function(value)
            currentSettings.burstChance = value
            applySettingsToKillAura()
        end,
        formatPercent
    )
    yOffset = yOffset + 50
    
    local burstDurationSlider = createSlider(
        content, 'Burst Duration',
        0.5, 3.0, 0.1,
        currentSettings.burstDuration,
        yOffset,
        function(value)
            currentSettings.burstDuration = value
            applySettingsToKillAura()
        end,
        formatSeconds
    )
    yOffset = yOffset + 50
    
    local burstSpeedSlider = createSlider(
        content, 'Burst Speed Multiplier',
        0.5, 1.0, 0.05,
        currentSettings.burstSpeedMultiplier,
        yOffset,
        function(value)
            currentSettings.burstSpeedMultiplier = value
            applySettingsToKillAura()
        end,
        formatMultiplier
    )
    yOffset = yOffset + 60
    
    -- ========================================================================
    -- PAUSE BEHAVIOR SECTION
    -- ========================================================================
    createSectionHeader(content, '⏸️ PAUSE BEHAVIOR', yOffset)
    yOffset = yOffset + 30
    
    local pauseMinSlider = createSlider(
        content, 'Min Pause Duration',
        0.2, 1.5, 0.1,
        currentSettings.pauseMinDuration,
        yOffset,
        function(value)
            currentSettings.pauseMinDuration = value
            applySettingsToKillAura()
        end,
        formatSeconds
    )
    yOffset = yOffset + 50
    
    local pauseMaxSlider = createSlider(
        content, 'Max Pause Duration',
        0.5, 3.0, 0.1,
        currentSettings.pauseMaxDuration,
        yOffset,
        function(value)
            currentSettings.pauseMaxDuration = value
            applySettingsToKillAura()
        end,
        formatSeconds
    )
    yOffset = yOffset + 20
    
    -- Update canvas size with extra padding at bottom for visibility
    content.CanvasSize = UDim2.new(0, 0, 0, yOffset + 60)
    
    -- ========================================================================
    -- BOTTOM BUTTONS
    -- ========================================================================
    local buttonContainer = Instance.new('Frame')
    buttonContainer.Name = 'ButtonContainer'
    buttonContainer.Size = UDim2.new(1, 0, 0, 50)
    buttonContainer.Position = UDim2.new(0, 0, 1, -50)
    buttonContainer.BackgroundColor3 = Colors.bg_secondary
    buttonContainer.BorderSizePixel = 0
    buttonContainer.Active = true
    buttonContainer.ZIndex = 101
    buttonContainer.Parent = settingsOverlay
    
    -- Save button
    local saveBtn = Instance.new('TextButton')
    saveBtn.Name = 'SaveBtn'
    saveBtn.Size = UDim2.new(0.48, -5, 0, 36)
    saveBtn.Position = UDim2.new(0, 10, 0.5, -18)
    saveBtn.BackgroundColor3 = Colors.accent_enabled
    saveBtn.BorderSizePixel = 0
    saveBtn.TextColor3 = Colors.bg_primary
    saveBtn.TextSize = 12
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.Text = '💾 Save Settings'
    saveBtn.AutoButtonColor = false
    saveBtn.ZIndex = 102
    saveBtn.Parent = buttonContainer
    
    local saveBtnCorner = Instance.new('UICorner')
    saveBtnCorner.CornerRadius = UDim.new(0, 6)
    saveBtnCorner.Parent = saveBtn
    
    saveBtn.MouseButton1Click:Connect(function()
        local success = saveSettings()
        if success then
            saveBtn.Text = '✅ Saved!'
            tweenProperty(saveBtn, {BackgroundColor3 = Color3.fromRGB(0, 200, 80)}, 0.1)
            task.delay(1.5, function()
                if saveBtn and saveBtn.Parent then
                    saveBtn.Text = '💾 Save Settings'
                    tweenProperty(saveBtn, {BackgroundColor3 = Colors.accent_enabled}, 0.2)
                end
            end)
        else
            saveBtn.Text = '❌ Failed!'
            tweenProperty(saveBtn, {BackgroundColor3 = Colors.accent_disabled}, 0.1)
            task.delay(1.5, function()
                if saveBtn and saveBtn.Parent then
                    saveBtn.Text = '💾 Save Settings'
                    tweenProperty(saveBtn, {BackgroundColor3 = Colors.accent_enabled}, 0.2)
                end
            end)
        end
    end)
    
    saveBtn.MouseEnter:Connect(function()
        tweenProperty(saveBtn, {BackgroundColor3 = Color3.fromRGB(0, 220, 100)}, 0.1)
    end)
    
    saveBtn.MouseLeave:Connect(function()
        tweenProperty(saveBtn, {BackgroundColor3 = Colors.accent_enabled}, 0.1)
    end)
    
    -- Reset button
    local resetBtn = Instance.new('TextButton')
    resetBtn.Name = 'ResetBtn'
    resetBtn.Size = UDim2.new(0.48, -5, 0, 36)
    resetBtn.Position = UDim2.new(0.52, 0, 0.5, -18)
    resetBtn.BackgroundColor3 = Colors.slider_bg
    resetBtn.BorderSizePixel = 0
    resetBtn.TextColor3 = Colors.text_primary
    resetBtn.TextSize = 12
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.Text = '🔄 Reset Defaults'
    resetBtn.AutoButtonColor = false
    resetBtn.ZIndex = 102
    resetBtn.Parent = buttonContainer
    
    local resetBtnCorner = Instance.new('UICorner')
    resetBtnCorner.CornerRadius = UDim.new(0, 6)
    resetBtnCorner.Parent = resetBtn
    
    resetBtn.MouseButton1Click:Connect(function()
        for key, value in pairs(defaultSettings) do
            currentSettings[key] = value
        end
        
        timingVarianceSlider.setValue(currentSettings.timingVariance)
        pauseChanceSlider.setValue(currentSettings.pauseChance)
        comboBreakSlider.setValue(currentSettings.comboBreakChance)
        minDelaySlider.setValue(currentSettings.minAttackDelay)
        maxDelaySlider.setValue(currentSettings.maxAttackDelay)
        burstChanceSlider.setValue(currentSettings.burstChance)
        burstDurationSlider.setValue(currentSettings.burstDuration)
        burstSpeedSlider.setValue(currentSettings.burstSpeedMultiplier)
        pauseMinSlider.setValue(currentSettings.pauseMinDuration)
        pauseMaxSlider.setValue(currentSettings.pauseMaxDuration)
        
        applySettingsToKillAura()
        
        resetBtn.Text = '✅ Reset!'
        tweenProperty(resetBtn, {BackgroundColor3 = Colors.accent_secondary}, 0.1)
        task.delay(1, function()
            if resetBtn and resetBtn.Parent then
                resetBtn.Text = '🔄 Reset Defaults'
                tweenProperty(resetBtn, {BackgroundColor3 = Colors.slider_bg}, 0.2)
            end
        end)
    end)
    
    resetBtn.MouseEnter:Connect(function()
        tweenProperty(resetBtn, {BackgroundColor3 = Colors.border}, 0.1)
    end)
    
    resetBtn.MouseLeave:Connect(function()
        tweenProperty(resetBtn, {BackgroundColor3 = Colors.slider_bg}, 0.1)
    end)
    
    return settingsOverlay
end

-- ============================================================================
-- SHOW / HIDE SETTINGS (Implementations)
-- ============================================================================
showSettings = function()
    -- Auto-create overlay if it doesn't exist (standalone mode)
    if not settingsOverlay then
        local player = Players.LocalPlayer
        if player then
            local playerGui = player:FindFirstChild('PlayerGui')
            if playerGui then
                -- Create a standalone ScreenGui for settings
                local screenGui = Instance.new('ScreenGui')
                screenGui.Name = 'KillAuraSettingsGui'
                screenGui.ResetOnSpawn = false
                screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
                screenGui.DisplayOrder = 999  -- High display order to be on top
                screenGui.Parent = playerGui
                
                -- Create a container frame to hold the overlay (blocks clicks to GUIs below)
                local container = Instance.new('Frame')
                container.Name = 'SettingsContainer'
                container.Size = UDim2.new(1, 0, 1, 0)
                container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                container.BackgroundTransparency = 0.5  -- Semi-transparent backdrop
                container.Active = true  -- CRITICAL: Block clicks to GUIs below
                container.Parent = screenGui
                
                createSettingsOverlay(container)
            end
        end
    end
    
    if settingsOverlay then
        -- Close other settings overlays to prevent conflicts
        pcall(function()
            if _G.AutoFarmSettingsAPI and _G.AutoFarmSettingsAPI.isVisible and _G.AutoFarmSettingsAPI.isVisible() then
                _G.AutoFarmSettingsAPI.hide()
            end
            if _G.AutoSellSettingsAPI and _G.AutoSellSettingsAPI.isVisible and _G.AutoSellSettingsAPI.isVisible() then
                _G.AutoSellSettingsAPI.hide()
            end
        end)
        
        -- Hide content area if parent has one (for main GUI integration)
        if parentFrame then
            for _, child in ipairs(parentFrame:GetChildren()) do
                if child:IsA('ScrollingFrame') and child.Name:find('Content') then
                    child.Visible = false
                    break
                end
            end
        end
        
        settingsOverlay.Visible = true
        isVisible = true
        settingsOverlay.BackgroundTransparency = 1
        tweenProperty(settingsOverlay, {BackgroundTransparency = 0}, 0.2)
    end
end

hideSettings = function()
    if settingsOverlay then
        local tween = tweenProperty(settingsOverlay, {BackgroundTransparency = 1}, 0.15)
        
        local function onHideComplete()
            if settingsOverlay then
                settingsOverlay.Visible = false
            end
            -- Restore content area visibility, but skip ALL settings overlays
            if parentFrame then
                for _, child in ipairs(parentFrame:GetChildren()) do
                    local isSettingsOverlay = child.Name == 'KillAuraSettingsOverlay' or 
                                              child.Name == 'AutoSellSettingsOverlay' or 
                                              child.Name == 'AutoFarmSettingsOverlay' or
                                              child.Name == 'Header'
                    if not isSettingsOverlay and child:IsA('ScrollingFrame') and child.Name:find('Content') then
                        child.Visible = true
                        break
                    end
                end
            end
        end
        
        if tween then
            tween.Completed:Connect(onHideComplete)
        else
            onHideComplete()
        end
        isVisible = false
    end
end

toggleSettings = function(parentFrame)
    if isVisible then
        hideSettings()
    else
        -- If parentFrame provided and no overlay exists, create overlay in that parent
        if parentFrame and not settingsOverlay then
            createSettingsOverlay(parentFrame)
        end
        showSettings()
    end
end

-- ============================================================================
-- CREATE SETTINGS BUTTON
-- ============================================================================
local function createSettingsButton(parentButton, contentArea, mainFrame)
    local settingsBtn = Instance.new('TextButton')
    settingsBtn.Name = 'KillAuraSettingsBtn'
    settingsBtn.Size = UDim2.new(0, 30, 0, 30)
    settingsBtn.Position = UDim2.new(1, -40, 0, parentButton.Position.Y.Offset + 10)
    settingsBtn.BackgroundColor3 = Colors.settings_button
    settingsBtn.BorderSizePixel = 0
    settingsBtn.TextColor3 = Colors.text_primary
    settingsBtn.TextSize = 14
    settingsBtn.Font = Enum.Font.GothamBold
    settingsBtn.Text = '⚙️'
    settingsBtn.AutoButtonColor = false
    settingsBtn.ZIndex = 5
    settingsBtn.Parent = contentArea
    
    local btnCorner = Instance.new('UICorner')
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = settingsBtn
    
    createSettingsOverlay(mainFrame)
    
    settingsBtn.MouseButton1Click:Connect(function()
        toggleSettings()
    end)
    
    settingsBtn.MouseEnter:Connect(function()
        tweenProperty(settingsBtn, {BackgroundColor3 = Color3.fromRGB(255, 120, 120)}, 0.1)
    end)
    
    settingsBtn.MouseLeave:Connect(function()
        tweenProperty(settingsBtn, {BackgroundColor3 = Colors.settings_button}, 0.1)
    end)
    
    return settingsBtn
end

-- ============================================================================
-- GET SKILL COOLDOWN (for killaura.lua integration)
-- ============================================================================
local function getSkillCooldown(className, skillName)
    local customCooldowns = _genv.KillAuraCustomCooldowns
    if customCooldowns and customCooldowns[className] and customCooldowns[className][skillName] then
        return customCooldowns[className][skillName]
    end
    return nil
end

-- ============================================================================
-- API EXPORT
-- ============================================================================
local KillAuraSettingsAPI = {
    -- Core functions
    show = showSettings,
    hide = hideSettings,
    toggle = toggleSettings,
    
    -- Settings management
    loadSettings = loadSettings,
    saveSettings = saveSettings,
    applySettings = applySettingsToKillAura,
    
    -- GUI creation
    createSettingsButton = createSettingsButton,
    createSettingsOverlay = createSettingsOverlay,
    
    -- Current settings accessor
    getSettings = function()
        local copy = {}
        for key, value in pairs(currentSettings) do
            copy[key] = value
        end
        return copy
    end,
    
    setSettings = function(settings)
        for key, value in pairs(settings) do
            if defaultSettings[key] ~= nil then
                currentSettings[key] = value
            end
        end
        applySettingsToKillAura()
    end,
    
    -- Get specific setting
    getSetting = function(key)
        return currentSettings[key]
    end,
    
    -- Set specific setting
    setSetting = function(key, value)
        if defaultSettings[key] ~= nil then
            currentSettings[key] = value
            applySettingsToKillAura()
        end
    end,
    
    -- Skill cooldown helper for killaura.lua
    getSkillCooldown = getSkillCooldown,
    
    -- State check
    isVisible = function() return isVisible end,
    
    -- Cleanup
    destroy = function()
        cleanupConnections()
        if settingsOverlay then
            settingsOverlay:Destroy()
            settingsOverlay = nil
        end
        isVisible = false
    end,
}

-- Export to global
_G.KillAuraSettingsAPI = KillAuraSettingsAPI
getgenv().KillAuraSettingsAPI = KillAuraSettingsAPI

-- Load saved settings on API load
loadSettings()

return KillAuraSettingsAPI
