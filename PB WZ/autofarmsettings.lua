-- ============================================================================
-- Auto Farm Settings API - Complete Settings Management for Auto Farm
-- ============================================================================
-- https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/autofarmsettingsapi.lua
-- Manages Auto Farm settings with save/load functionality
-- Provides GUI overlay for adjusting all farm parameters
--
-- FEATURES:
-- • Farm Position (Above/Below) toggle
-- • Farm Height slider (0.5 increments)
-- • Farm Behind distance slider
-- • Movement Speed controls (horizontal/vertical)
-- • Anti-Detection settings
-- • Auto Dodge integration
-- • Persistent settings via file storage
-- • Real-time updates to AutoFarm parameters
-- • Click-through prevention (Active = true on all frames)
-- • Smooth animations
--
-- USAGE:
-- local SettingsAPI = _G.AutoFarmSettingsAPI
-- SettingsAPI.show()             -- Show settings overlay
-- SettingsAPI.hide()             -- Hide settings overlay
-- SettingsAPI.loadSettings()     -- Load saved settings
-- SettingsAPI.saveSettings()     -- Save current settings
--
-- COMPATIBILITY:
-- Works with: AutoFarm (_G.x4k7p), AutoDodge (_G.AutoDodgeAPI), KillAura (_G.x9m1n)
-- Does NOT control: KillAura or AutoSell (separate settings APIs)
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
local SETTINGS_FILE = ZENX_FOLDER .. "/zenx_autofarm_settings.json"

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
-- DEFAULT SETTINGS
-- ============================================================================
local defaultSettings = {
    -- Position Settings
    farmMode = "above",           -- "above" or "below"
    farmHeight = 7,               -- Height offset (0.5 increments)
    farmBehind = 14,              -- Behind distance
    groundClearance = 4,          -- Extra clearance above ground
    
    -- Movement Settings
    maxSpeed = 60,                -- Horizontal speed cap
    verticalSpeed = 35,           -- Vertical speed cap
    smoothing = 0.25,             -- Movement smoothing (0-1)
    
    -- Anti-Detection Settings
    antiDetectionEnabled = true,  -- Master toggle for anti-detection
    movementVariance = 0.18,      -- Movement variance (0-0.5)
    speedVariance = 0.12,         -- Speed variance (0-0.3)
    wobbleEnabled = true,         -- Direction wobble
    microPauseEnabled = true,     -- Random micro-pauses
    
    -- Targeting Settings
    switchTargetDistance = 100,   -- Drop/retarget beyond this
    avoidRadius = 9,              -- Radius to avoid other mobs
    clusterRadius = 40,           -- Cluster radius around target
    
    -- AutoDodge Integration
    autoDodgeEnabled = true,      -- AutoDodge on/off
    dodgeTweenSpeed = 0.2,        -- Dodge tween duration (seconds)
    
    -- World Events Integration
    worldEventsEnabled = false,   -- Auto-join world events when farming
    
    -- Pet Aura Integration
    petAuraEnabled = false,       -- Auto-use pet skills when farming
    petAuraSupportRange = 60,     -- Range for support skills (studs)
    petAuraHealThreshold = 0.5,   -- HP threshold to trigger heals (0-1)
}

-- Current settings (initialized with defaults)
local currentSettings = {}
for k, v in pairs(defaultSettings) do
    currentSettings[k] = v
end

-- ============================================================================
-- COLORS (Matching ZenX theme - Enhanced)
-- ============================================================================
local Colors = {
    -- Backgrounds
    bg_primary = Color3.fromRGB(12, 12, 12),
    bg_secondary = Color3.fromRGB(22, 22, 22),
    bg_overlay = Color3.fromRGB(18, 18, 18),
    bg_section = Color3.fromRGB(28, 28, 28),
    bg_input = Color3.fromRGB(35, 35, 35),
    
    -- Accents
    accent_main = Color3.fromRGB(0, 255, 100),
    accent_secondary = Color3.fromRGB(0, 180, 255),
    accent_warning = Color3.fromRGB(255, 180, 0),
    accent_danger = Color3.fromRGB(255, 60, 60),
    accent_purple = Color3.fromRGB(180, 100, 255),
    
    -- Text
    text_primary = Color3.fromRGB(255, 255, 255),
    text_secondary = Color3.fromRGB(140, 140, 140),
    text_muted = Color3.fromRGB(90, 90, 90),
    
    -- UI Elements
    border = Color3.fromRGB(45, 45, 45),
    slider_bg = Color3.fromRGB(40, 40, 40),
    slider_fill = Color3.fromRGB(0, 180, 255),
    toggle_on = Color3.fromRGB(0, 200, 100),
    toggle_off = Color3.fromRGB(60, 60, 60),
    settings_button = Color3.fromRGB(0, 140, 220),
}

-- ============================================================================
-- GUI REFERENCES
-- ============================================================================
local settingsOverlay = nil
local isVisible = false
local parentFrame = nil
local sliderRefs = {}  -- Store slider references for value updates

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
            valStr = '"' .. value .. '"'
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
    for key, value in string.gmatch(jsonStr, '"([^"]+)":"?([^",}]+)"?') do
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
-- FORWARD DECLARATIONS
-- ============================================================================
local applySettingsToAutoFarm
local showSettings
local hideSettings

-- ============================================================================
-- SETTINGS PERSISTENCE
-- ============================================================================
local function saveSettings()
    if not writefile then
        warn("[AutoFarmSettings] writefile not available - cannot save settings")
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
        warn("[AutoFarmSettings] ⚠️ Failed to save settings: " .. tostring(err))
        return false
    end
end

local function loadSettings()
    if not readfile or not isfile then
        warn("[AutoFarmSettings] readfile/isfile not available - using defaults")
        return false
    end
    
    local success, result = pcall(function()
        if isfile(SETTINGS_FILE) then
            local content = readfile(SETTINGS_FILE)
            if content and content ~= "" then
                local decoded = decodeJSON(content)
                if decoded then
                    -- Apply loaded settings (with defaults fallback)
                    for key, defaultVal in pairs(defaultSettings) do
                        if decoded[key] ~= nil then
                            if type(defaultVal) == "number" then
                                currentSettings[key] = tonumber(decoded[key]) or defaultVal
                            elseif type(defaultVal) == "boolean" then
                                currentSettings[key] = decoded[key] == true or decoded[key] == "true"
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
        applySettingsToAutoFarm()
        return true
    else
        return false
    end
end

-- ============================================================================
-- APPLY SETTINGS TO AUTO FARM & RELATED SYSTEMS
-- ============================================================================
applySettingsToAutoFarm = function()
    -- Position Settings
    if currentSettings.farmMode == "below" then
        _genv.AutoFarmHoverHeight = -math.abs(currentSettings.farmHeight)
    else
        _genv.AutoFarmHoverHeight = math.abs(currentSettings.farmHeight)
    end
    _genv.AutoFarmBehindDistance = currentSettings.farmBehind
    _genv.AutoFarmGroundClearance = currentSettings.groundClearance
    
    -- Movement Settings
    _genv.AutoFarmMaxSpeed = currentSettings.maxSpeed
    _genv.AutoFarmVerticalSpeed = currentSettings.verticalSpeed
    _genv.AutoFarmSmoothing = currentSettings.smoothing
    
    -- Targeting Settings
    _genv.AutoFarmSwitchTargetDistance = currentSettings.switchTargetDistance
    _genv.AutoFarmAvoidRadius = currentSettings.avoidRadius
    _genv.AutoFarmNearbyClusterRadius = currentSettings.clusterRadius
    
    -- Anti-Detection (applied to AutoFarm's AntiDetection table if available)
    pcall(function()
        local autoFarm = _G.x4k7p or _G.autoFarm
        if autoFarm and autoFarm.setAntiDetection then
            autoFarm.setAntiDetection({
                enabled = currentSettings.antiDetectionEnabled,
                movementVariance = currentSettings.movementVariance,
                speedVariance = currentSettings.speedVariance,
                wobbleEnabled = currentSettings.wobbleEnabled,
                microPauseEnabled = currentSettings.microPauseEnabled,
            })
        end
    end)
    
    -- AutoDodge Integration
    pcall(function()
        local autoDodge = _G.AutoDodgeAPI or _G.x6p9t or getgenv().AutoDodgeAPI
        if autoDodge then
            -- Set tween duration
            if autoDodge.SetTweenDuration then
                autoDodge:SetTweenDuration(currentSettings.dodgeTweenSpeed)
            elseif autoDodge.setTweenDuration then
                autoDodge.setTweenDuration(currentSettings.dodgeTweenSpeed)
            end
            
            -- Enable/Disable
            if currentSettings.autoDodgeEnabled then
                if autoDodge.enable then
                    autoDodge.enable()
                elseif autoDodge.EnableAutoDodge then
                    autoDodge:EnableAutoDodge()
                end
            else
                if autoDodge.disable then
                    autoDodge.disable()
                elseif autoDodge.DisableAutoDodge then
                    autoDodge:DisableAutoDodge()
                end
            end
        end
    end)
    
    -- World Events Integration
    _genv.AutoFarmWorldEvents = currentSettings.worldEventsEnabled
    
    -- Pet Aura Integration
    _genv.AutoFarmPetAura = currentSettings.petAuraEnabled
    _genv.PetAuraSupportRange = currentSettings.petAuraSupportRange
    _genv.PetAuraHealThreshold = currentSettings.petAuraHealThreshold
    
    -- Apply to Pet Aura API if loaded
    pcall(function()
        local petAura = _G.x8p3q or _G.PetAuraAPI
        if petAura then
            -- Apply settings
            if petAura.setSupportRange then
                petAura.setSupportRange(currentSettings.petAuraSupportRange)
            end
            if petAura.setHealThreshold then
                petAura.setHealThreshold(currentSettings.petAuraHealThreshold)
            end
            
            -- Enable/Disable based on setting AND autofarm state
            if currentSettings.petAuraEnabled and _genv.AutoFarmEnabled then
                if petAura.enable then
                    petAura.enable()
                end
            else
                if petAura.disable then
                    petAura.disable()
                end
            end
        end
    end)
end

-- ============================================================================
-- TWEEN HELPER
-- ============================================================================
local function tweenProperty(obj, props, duration)
    if not obj or not obj.Parent then return nil end
    local tweenInfo = TweenInfo.new(
        duration or 0.2,
        Enum.EasingStyle.Quint,
        Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(obj, tweenInfo, props)
    tween:Play()
    return tween
end

-- ============================================================================
-- CREATE SECTION HEADER
-- ============================================================================
local function createSectionHeader(parent, text, yPosition, icon)
    local header = Instance.new('Frame')
    header.Name = text .. '_Header'
    header.Size = UDim2.new(1, -16, 0, 28)
    header.Position = UDim2.new(0, 8, 0, yPosition)
    header.BackgroundColor3 = Colors.bg_section
    header.BorderSizePixel = 0
    header.Active = true  -- Prevents click-through
    header.ZIndex = 52
    header.Parent = parent
    
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = header
    
    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Colors.accent_secondary
    label.TextSize = 11
    label.Font = Enum.Font.GothamBold
    label.Text = (icon or "📁") .. "  " .. text:upper()
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 53
    label.Parent = header
    
    return header
end

-- ============================================================================
-- CREATE SLIDER COMPONENT (Enhanced with knob animation)
-- ============================================================================
local function createSlider(parent, labelText, minVal, maxVal, increment, initialValue, yPosition, onValueChanged)
    local sliderContainer = Instance.new('Frame')
    sliderContainer.Name = labelText:gsub(" ", "") .. '_Container'
    sliderContainer.Size = UDim2.new(1, -16, 0, 48)
    sliderContainer.Position = UDim2.new(0, 8, 0, yPosition)
    sliderContainer.BackgroundTransparency = 1
    sliderContainer.Active = true  -- Prevents click-through
    sliderContainer.ZIndex = 52
    sliderContainer.Parent = parent
    
    -- Label
    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.new(0.65, 0, 0, 18)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Colors.text_primary
    label.TextSize = 11
    label.Font = Enum.Font.GothamMedium
    label.Text = labelText
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 53
    label.Parent = sliderContainer
    
    -- Value display with background
    local valueBg = Instance.new('Frame')
    valueBg.Name = 'ValueBg'
    valueBg.Size = UDim2.new(0, 50, 0, 18)
    valueBg.Position = UDim2.new(1, -50, 0, 0)
    valueBg.BackgroundColor3 = Colors.bg_input
    valueBg.BorderSizePixel = 0
    valueBg.Active = true
    valueBg.ZIndex = 53
    valueBg.Parent = sliderContainer
    
    local valueBgCorner = Instance.new('UICorner')
    valueBgCorner.CornerRadius = UDim.new(0, 4)
    valueBgCorner.Parent = valueBg
    
    local valueLabel = Instance.new('TextLabel')
    valueLabel.Name = 'Value'
    valueLabel.Size = UDim2.new(1, 0, 1, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3 = Colors.accent_secondary
    valueLabel.TextSize = 10
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Text = tostring(initialValue)
    valueLabel.ZIndex = 54
    valueLabel.Parent = valueBg
    
    -- Slider background
    local sliderBg = Instance.new('Frame')
    sliderBg.Name = 'SliderBg'
    sliderBg.Size = UDim2.new(1, 0, 0, 12)
    sliderBg.Position = UDim2.new(0, 0, 0, 24)
    sliderBg.BackgroundColor3 = Colors.slider_bg
    sliderBg.BorderSizePixel = 0
    sliderBg.Active = true  -- IMPORTANT: Prevents click-through
    sliderBg.ZIndex = 53
    sliderBg.Parent = sliderContainer
    
    local bgCorner = Instance.new('UICorner')
    bgCorner.CornerRadius = UDim.new(0, 6)
    bgCorner.Parent = sliderBg
    
    -- Slider fill
    local sliderFill = Instance.new('Frame')
    sliderFill.Name = 'Fill'
    local percentage = math.clamp((initialValue - minVal) / (maxVal - minVal), 0, 1)
    sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
    sliderFill.Position = UDim2.new(0, 0, 0, 0)
    sliderFill.BackgroundColor3 = Colors.slider_fill
    sliderFill.BorderSizePixel = 0
    sliderFill.ZIndex = 54
    sliderFill.Parent = sliderBg
    
    local fillCorner = Instance.new('UICorner')
    fillCorner.CornerRadius = UDim.new(0, 6)
    fillCorner.Parent = sliderFill
    
    -- Slider knob
    local knob = Instance.new('Frame')
    knob.Name = 'Knob'
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(percentage, -8, 0.5, -8)
    knob.BackgroundColor3 = Colors.text_primary
    knob.BorderSizePixel = 0
    knob.Active = true  -- IMPORTANT: Prevents click-through
    knob.ZIndex = 55
    knob.Parent = sliderBg
    
    local knobCorner = Instance.new('UICorner')
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    
    -- Knob shadow/glow
    local knobStroke = Instance.new('UIStroke')
    knobStroke.Color = Colors.accent_secondary
    knobStroke.Thickness = 2
    knobStroke.Transparency = 0.5
    knobStroke.Parent = knob
    
    -- Slider interaction
    local isDragging = false
    local currentValue = initialValue
    
    local function updateSlider(inputPos)
        local sliderAbsPos = sliderBg.AbsolutePosition
        local sliderAbsSize = sliderBg.AbsoluteSize
        
        local relativeX = math.clamp((inputPos.X - sliderAbsPos.X) / sliderAbsSize.X, 0, 1)
        
        -- Calculate value with increment snapping
        local rawValue = minVal + (relativeX * (maxVal - minVal))
        local snappedValue = math.floor(rawValue / increment + 0.5) * increment
        snappedValue = math.clamp(snappedValue, minVal, maxVal)
        
        -- Round to avoid floating point issues
        snappedValue = math.floor(snappedValue * 1000 + 0.5) / 1000
        
        currentValue = snappedValue
        
        -- Update visuals
        local newPercentage = (snappedValue - minVal) / (maxVal - minVal)
        sliderFill.Size = UDim2.new(math.clamp(newPercentage, 0, 1), 0, 1, 0)
        knob.Position = UDim2.new(math.clamp(newPercentage, 0, 1), -8, 0.5, -8)
        valueLabel.Text = tostring(snappedValue)
        
        -- Callback
        if onValueChanged then
            onValueChanged(snappedValue)
        end
    end
    
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            updateSlider(input.Position)
            tweenProperty(knob, {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(knob.Position.X.Scale, -10, 0.5, -10)}, 0.1)
        end
    end)
    
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            tweenProperty(knob, {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(knob.Position.X.Scale, -10, 0.5, -10)}, 0.1)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input.Position)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if isDragging then
                isDragging = false
                local currentPercentage = (currentValue - minVal) / (maxVal - minVal)
                tweenProperty(knob, {Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(currentPercentage, -8, 0.5, -8)}, 0.1)
            end
        end
    end)
    
    return {
        container = sliderContainer,
        getValue = function() return currentValue end,
        setValue = function(val)
            currentValue = val
            local newPercentage = (val - minVal) / (maxVal - minVal)
            sliderFill.Size = UDim2.new(math.clamp(newPercentage, 0, 1), 0, 1, 0)
            knob.Position = UDim2.new(math.clamp(newPercentage, 0, 1), -8, 0.5, -8)
            valueLabel.Text = tostring(val)
        end
    }
end

-- ============================================================================
-- CREATE TOGGLE COMPONENT
-- ============================================================================
local function createToggle(parent, labelText, initialValue, yPosition, onValueChanged)
    local toggleContainer = Instance.new('Frame')
    toggleContainer.Name = labelText:gsub(" ", "") .. '_Container'
    toggleContainer.Size = UDim2.new(1, -16, 0, 32)
    toggleContainer.Position = UDim2.new(0, 8, 0, yPosition)
    toggleContainer.BackgroundTransparency = 1
    toggleContainer.Active = true  -- Prevents click-through
    toggleContainer.ZIndex = 52
    toggleContainer.Parent = parent
    
    -- Label
    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Colors.text_primary
    label.TextSize = 11
    label.Font = Enum.Font.GothamMedium
    label.Text = labelText
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.ZIndex = 53
    label.Parent = toggleContainer
    
    -- Toggle background
    local toggleBg = Instance.new('Frame')
    toggleBg.Name = 'ToggleBg'
    toggleBg.Size = UDim2.new(0, 44, 0, 22)
    toggleBg.Position = UDim2.new(1, -48, 0.5, -11)
    toggleBg.BackgroundColor3 = initialValue and Colors.toggle_on or Colors.toggle_off
    toggleBg.BorderSizePixel = 0
    toggleBg.Active = true  -- IMPORTANT: Prevents click-through
    toggleBg.ZIndex = 53
    toggleBg.Parent = toggleContainer
    
    local bgCorner = Instance.new('UICorner')
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = toggleBg
    
    -- Toggle knob
    local toggleKnob = Instance.new('Frame')
    toggleKnob.Name = 'Knob'
    toggleKnob.Size = UDim2.new(0, 18, 0, 18)
    toggleKnob.Position = initialValue and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    toggleKnob.BackgroundColor3 = Colors.text_primary
    toggleKnob.BorderSizePixel = 0
    toggleKnob.ZIndex = 54
    toggleKnob.Parent = toggleBg
    
    local knobCorner = Instance.new('UICorner')
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = toggleKnob
    
    local currentValue = initialValue
    
    local function updateToggle(newValue)
        currentValue = newValue
        if newValue then
            tweenProperty(toggleBg, {BackgroundColor3 = Colors.toggle_on}, 0.15)
            tweenProperty(toggleKnob, {Position = UDim2.new(1, -20, 0.5, -9)}, 0.15)
        else
            tweenProperty(toggleBg, {BackgroundColor3 = Colors.toggle_off}, 0.15)
            tweenProperty(toggleKnob, {Position = UDim2.new(0, 2, 0.5, -9)}, 0.15)
        end
        if onValueChanged then
            onValueChanged(newValue)
        end
    end
    
    -- Make clickable
    local clickBtn = Instance.new('TextButton')
    clickBtn.Name = 'ClickArea'
    clickBtn.Size = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ''
    clickBtn.ZIndex = 55
    clickBtn.Parent = toggleContainer
    
    clickBtn.MouseButton1Click:Connect(function()
        updateToggle(not currentValue)
    end)
    
    return {
        container = toggleContainer,
        getValue = function() return currentValue end,
        setValue = function(val)
            updateToggle(val)
        end
    }
end

-- ============================================================================
-- CREATE DUAL BUTTON TOGGLE (e.g., Above/Below)
-- ============================================================================
local function createDualToggle(parent, labelText, option1, option2, initialValue, yPosition, onValueChanged)
    local container = Instance.new('Frame')
    container.Name = labelText:gsub(" ", "") .. '_Container'
    container.Size = UDim2.new(1, -16, 0, 44)
    container.Position = UDim2.new(0, 8, 0, yPosition)
    container.BackgroundTransparency = 1
    container.Active = true  -- Prevents click-through
    container.ZIndex = 52
    container.Parent = parent
    
    -- Label
    local label = Instance.new('TextLabel')
    label.Name = 'Label'
    label.Size = UDim2.new(1, 0, 0, 16)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Colors.text_primary
    label.TextSize = 11
    label.Font = Enum.Font.GothamMedium
    label.Text = labelText
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 53
    label.Parent = container
    
    -- Option 1 button
    local btn1 = Instance.new('TextButton')
    btn1.Name = 'Option1'
    btn1.Size = UDim2.new(0.48, 0, 0, 24)
    btn1.Position = UDim2.new(0, 0, 0, 18)
    btn1.BackgroundColor3 = initialValue == option1.value and Colors.accent_main or Colors.slider_bg
    btn1.BorderSizePixel = 0
    btn1.TextColor3 = initialValue == option1.value and Colors.bg_primary or Colors.text_primary
    btn1.TextSize = 10
    btn1.Font = Enum.Font.GothamBold
    btn1.Text = option1.text
    btn1.ZIndex = 53
    btn1.Parent = container
    
    local btn1Corner = Instance.new('UICorner')
    btn1Corner.CornerRadius = UDim.new(0, 6)
    btn1Corner.Parent = btn1
    
    -- Option 2 button
    local btn2 = Instance.new('TextButton')
    btn2.Name = 'Option2'
    btn2.Size = UDim2.new(0.48, 0, 0, 24)
    btn2.Position = UDim2.new(0.52, 0, 0, 18)
    btn2.BackgroundColor3 = initialValue == option2.value and Colors.accent_main or Colors.slider_bg
    btn2.BorderSizePixel = 0
    btn2.TextColor3 = initialValue == option2.value and Colors.bg_primary or Colors.text_primary
    btn2.TextSize = 10
    btn2.Font = Enum.Font.GothamBold
    btn2.Text = option2.text
    btn2.ZIndex = 53
    btn2.Parent = container
    
    local btn2Corner = Instance.new('UICorner')
    btn2Corner.CornerRadius = UDim.new(0, 6)
    btn2Corner.Parent = btn2
    
    local currentValue = initialValue
    
    local function updateButtons()
        if currentValue == option1.value then
            tweenProperty(btn1, {BackgroundColor3 = Colors.accent_main, TextColor3 = Colors.bg_primary}, 0.12)
            tweenProperty(btn2, {BackgroundColor3 = Colors.slider_bg, TextColor3 = Colors.text_primary}, 0.12)
        else
            tweenProperty(btn1, {BackgroundColor3 = Colors.slider_bg, TextColor3 = Colors.text_primary}, 0.12)
            tweenProperty(btn2, {BackgroundColor3 = Colors.accent_main, TextColor3 = Colors.bg_primary}, 0.12)
        end
    end
    
    btn1.MouseButton1Click:Connect(function()
        currentValue = option1.value
        updateButtons()
        if onValueChanged then onValueChanged(currentValue) end
    end)
    
    btn2.MouseButton1Click:Connect(function()
        currentValue = option2.value
        updateButtons()
        if onValueChanged then onValueChanged(currentValue) end
    end)
    
    return {
        container = container,
        getValue = function() return currentValue end,
        setValue = function(val)
            currentValue = val
            updateButtons()
        end
    }
end

-- ============================================================================
-- CREATE SETTINGS OVERLAY
-- ============================================================================
local function createSettingsOverlay(parent)
    if settingsOverlay then
        settingsOverlay:Destroy()
        settingsOverlay = nil
    end
    
    parentFrame = parent
    
    -- Main overlay frame - IMPORTANT: Active = true prevents click-through
    settingsOverlay = Instance.new('Frame')
    settingsOverlay.Name = 'AutoFarmSettingsOverlay'
    settingsOverlay.Size = UDim2.new(1, 0, 1, 0)
    settingsOverlay.Position = UDim2.new(0, 0, 0, 0)
    settingsOverlay.BackgroundColor3 = Colors.bg_overlay
    settingsOverlay.BackgroundTransparency = 0
    settingsOverlay.BorderSizePixel = 0
    settingsOverlay.Visible = false
    settingsOverlay.Active = true  -- CRITICAL: Prevents click-through
    settingsOverlay.ZIndex = 50
    settingsOverlay.Parent = parent
    
    local overlayCorner = Instance.new('UICorner')
    overlayCorner.CornerRadius = UDim.new(0, 8)
    overlayCorner.Parent = settingsOverlay
    
    -- Header
    local header = Instance.new('Frame')
    header.Name = 'Header'
    header.Size = UDim2.new(1, 0, 0, 40)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Colors.bg_secondary
    header.BorderSizePixel = 0
    header.Active = true
    header.ZIndex = 51
    header.Parent = settingsOverlay
    
    local headerCorner = Instance.new('UICorner')
    headerCorner.CornerRadius = UDim.new(0, 8)
    headerCorner.Parent = header
    
    -- Title
    local title = Instance.new('TextLabel')
    title.Name = 'Title'
    title.Size = UDim2.new(1, -50, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Colors.accent_secondary
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.Text = '⚙️ Auto Farm Settings'
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 52
    title.Parent = header
    
    -- Close button
    local closeBtn = Instance.new('TextButton')
    closeBtn.Name = 'Close'
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -36, 0.5, -16)
    closeBtn.BackgroundColor3 = Colors.accent_danger
    closeBtn.BorderSizePixel = 0
    closeBtn.TextColor3 = Colors.text_primary
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = '✕'
    closeBtn.ZIndex = 52
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
        tweenProperty(closeBtn, {BackgroundColor3 = Colors.accent_danger}, 0.1)
    end)
    
    -- Content area with scrolling
    local content = Instance.new('ScrollingFrame')
    content.Name = 'Content'
    content.Size = UDim2.new(1, -8, 1, -90)
    content.Position = UDim2.new(0, 4, 0, 42)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 8
    content.ScrollBarImageColor3 = Colors.slider_fill
    content.ScrollBarImageTransparency = 0
    content.TopImage = "rbxassetid://7658241732"
    content.MidImage = "rbxassetid://7658241732"
    content.BottomImage = "rbxassetid://7658241732"
    content.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    content.CanvasSize = UDim2.new(0, 0, 0, 720)  -- Will be adjusted based on content
    content.ScrollingDirection = Enum.ScrollingDirection.Y
    content.ClipsDescendants = true
    content.Active = true  -- Prevents click-through
    content.ZIndex = 51
    content.Parent = settingsOverlay
    
    local yPos = 8
    
    -- ========================================================================
    -- SECTION: POSITION SETTINGS
    -- ========================================================================
    createSectionHeader(content, "Position", yPos, "📍")
    yPos = yPos + 36
    
    -- Farm Mode (Above/Below)
    local modeToggle = createDualToggle(
        content, "Farm Position",
        {text = "⬆️ Above", value = "above"},
        {text = "⬇️ Below", value = "below"},
        currentSettings.farmMode,
        yPos,
        function(value)
            currentSettings.farmMode = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 52
    
    -- Farm Height
    local heightSlider = createSlider(content, "Farm Height", 0.5, 25, 0.5, 
        math.abs(currentSettings.farmHeight), yPos,
        function(value)
            currentSettings.farmHeight = value
            applySettingsToAutoFarm()
        end
    )
    sliderRefs.height = heightSlider
    yPos = yPos + 54
    
    -- Farm Behind Distance
    local behindSlider = createSlider(content, "Behind Distance", 1, 40, 0.5,
        currentSettings.farmBehind, yPos,
        function(value)
            currentSettings.farmBehind = value
            applySettingsToAutoFarm()
        end
    )
    sliderRefs.behind = behindSlider
    yPos = yPos + 54
    
    -- Ground Clearance
    local clearanceSlider = createSlider(content, "Ground Clearance", 1, 15, 0.5,
        currentSettings.groundClearance, yPos,
        function(value)
            currentSettings.groundClearance = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 60
    
    -- ========================================================================
    -- SECTION: MOVEMENT SETTINGS
    -- ========================================================================
    createSectionHeader(content, "Movement", yPos, "🏃")
    yPos = yPos + 36
    
    -- Max Speed (Horizontal)
    local speedSlider = createSlider(content, "Max Speed", 20, 120, 5,
        currentSettings.maxSpeed, yPos,
        function(value)
            currentSettings.maxSpeed = value
            applySettingsToAutoFarm()
        end
    )
    sliderRefs.speed = speedSlider
    yPos = yPos + 54
    
    -- Vertical Speed
    local vertSpeedSlider = createSlider(content, "Vertical Speed", 10, 80, 5,
        currentSettings.verticalSpeed, yPos,
        function(value)
            currentSettings.verticalSpeed = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 54
    
    -- Smoothing
    local smoothingSlider = createSlider(content, "Movement Smoothing", 0.05, 0.5, 0.05,
        currentSettings.smoothing, yPos,
        function(value)
            currentSettings.smoothing = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 60
    
    -- ========================================================================
    -- SECTION: ANTI-DETECTION
    -- ========================================================================
    createSectionHeader(content, "Anti-Detection", yPos, "🛡️")
    yPos = yPos + 36
    
    -- Anti-Detection Master Toggle
    local antiDetectToggle = createToggle(content, "Enable Anti-Detection",
        currentSettings.antiDetectionEnabled, yPos,
        function(value)
            currentSettings.antiDetectionEnabled = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 38
    
    -- Movement Variance
    local moveVarSlider = createSlider(content, "Movement Variance", 0, 0.4, 0.02,
        currentSettings.movementVariance, yPos,
        function(value)
            currentSettings.movementVariance = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 54
    
    -- Speed Variance
    local speedVarSlider = createSlider(content, "Speed Variance", 0, 0.25, 0.01,
        currentSettings.speedVariance, yPos,
        function(value)
            currentSettings.speedVariance = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 42
    
    -- Wobble Toggle
    local wobbleToggle = createToggle(content, "Direction Wobble",
        currentSettings.wobbleEnabled, yPos,
        function(value)
            currentSettings.wobbleEnabled = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 38
    
    -- Micro-Pause Toggle
    local pauseToggle = createToggle(content, "Random Micro-Pauses",
        currentSettings.microPauseEnabled, yPos,
        function(value)
            currentSettings.microPauseEnabled = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 46
    
    -- ========================================================================
    -- SECTION: AUTO DODGE
    -- ========================================================================
    createSectionHeader(content, "Auto Dodge Integration", yPos, "⚡")
    yPos = yPos + 36
    
    -- Auto Dodge Toggle
    local dodgeToggle = createToggle(content, "Enable Auto Dodge",
        currentSettings.autoDodgeEnabled, yPos,
        function(value)
            currentSettings.autoDodgeEnabled = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 38
    
    -- Dodge Tween Speed
    local dodgeSpeedSlider = createSlider(content, "Dodge Speed (seconds)", 0.1, 0.5, 0.02,
        currentSettings.dodgeTweenSpeed, yPos,
        function(value)
            currentSettings.dodgeTweenSpeed = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 60
    
    -- ========================================================================
    -- SECTION: WORLD EVENTS
    -- ========================================================================
    createSectionHeader(content, "World Events", yPos, "🌍")
    yPos = yPos + 36
    
    -- World Events Toggle
    local worldEventsToggle = createToggle(content, "Auto-Join World Events",
        currentSettings.worldEventsEnabled, yPos,
        function(value)
            currentSettings.worldEventsEnabled = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 38
    
    -- ========================================================================
    -- SECTION: PET AURA
    -- ========================================================================
    createSectionHeader(content, "Pet Aura", yPos, "🐾")
    yPos = yPos + 36
    
    -- Pet Aura Toggle
    local petAuraToggle = createToggle(content, "Enable Pet Aura",
        currentSettings.petAuraEnabled, yPos,
        function(value)
            currentSettings.petAuraEnabled = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 38
    
    -- Pet Aura Support Range
    local petSupportRangeSlider = createSlider(content, "Support Range (studs)", 20, 100, 5,
        currentSettings.petAuraSupportRange, yPos,
        function(value)
            currentSettings.petAuraSupportRange = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 60
    
    -- Pet Aura Heal Threshold
    local petHealThresholdSlider = createSlider(content, "Heal HP Threshold (%)", 0.1, 1.0, 0.05,
        currentSettings.petAuraHealThreshold, yPos,
        function(value)
            currentSettings.petAuraHealThreshold = value
            applySettingsToAutoFarm()
        end
    )
    yPos = yPos + 60
    
    -- Update canvas size based on content with extra padding for visibility
    content.CanvasSize = UDim2.new(0, 0, 0, yPos + 60)
    
    -- ========================================================================
    -- BOTTOM BUTTONS
    -- ========================================================================
    local buttonContainer = Instance.new('Frame')
    buttonContainer.Name = 'ButtonContainer'
    buttonContainer.Size = UDim2.new(1, -16, 0, 40)
    buttonContainer.Position = UDim2.new(0, 8, 1, -46)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Active = true
    buttonContainer.ZIndex = 52
    buttonContainer.Parent = settingsOverlay
    
    -- Save Button
    local saveBtn = Instance.new('TextButton')
    saveBtn.Name = 'SaveBtn'
    saveBtn.Size = UDim2.new(0.48, 0, 1, 0)
    saveBtn.Position = UDim2.new(0, 0, 0, 0)
    saveBtn.BackgroundColor3 = Colors.accent_main
    saveBtn.BorderSizePixel = 0
    saveBtn.TextColor3 = Colors.bg_primary
    saveBtn.TextSize = 12
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.Text = '💾 Save Settings'
    saveBtn.ZIndex = 53
    saveBtn.Parent = buttonContainer
    
    local saveBtnCorner = Instance.new('UICorner')
    saveBtnCorner.CornerRadius = UDim.new(0, 6)
    saveBtnCorner.Parent = saveBtn
    
    saveBtn.MouseButton1Click:Connect(function()
        local success = saveSettings()
        if success then
            saveBtn.Text = '✅ Saved!'
            tweenProperty(saveBtn, {BackgroundColor3 = Color3.fromRGB(0, 180, 80)}, 0.1)
            task.delay(1.5, function()
                if saveBtn and saveBtn.Parent then
                    saveBtn.Text = '💾 Save Settings'
                    tweenProperty(saveBtn, {BackgroundColor3 = Colors.accent_main}, 0.2)
                end
            end)
        else
            saveBtn.Text = '❌ Failed'
            tweenProperty(saveBtn, {BackgroundColor3 = Colors.accent_danger}, 0.1)
            task.delay(1.5, function()
                if saveBtn and saveBtn.Parent then
                    saveBtn.Text = '💾 Save Settings'
                    tweenProperty(saveBtn, {BackgroundColor3 = Colors.accent_main}, 0.2)
                end
            end)
        end
    end)
    
    saveBtn.MouseEnter:Connect(function()
        tweenProperty(saveBtn, {BackgroundColor3 = Color3.fromRGB(0, 220, 100)}, 0.1)
    end)
    
    saveBtn.MouseLeave:Connect(function()
        tweenProperty(saveBtn, {BackgroundColor3 = Colors.accent_main}, 0.1)
    end)
    
    -- Reset Button
    local resetBtn = Instance.new('TextButton')
    resetBtn.Name = 'ResetBtn'
    resetBtn.Size = UDim2.new(0.48, 0, 1, 0)
    resetBtn.Position = UDim2.new(0.52, 0, 0, 0)
    resetBtn.BackgroundColor3 = Colors.accent_warning
    resetBtn.BorderSizePixel = 0
    resetBtn.TextColor3 = Colors.bg_primary
    resetBtn.TextSize = 12
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.Text = '🔄 Reset Defaults'
    resetBtn.ZIndex = 53
    resetBtn.Parent = buttonContainer
    
    local resetBtnCorner = Instance.new('UICorner')
    resetBtnCorner.CornerRadius = UDim.new(0, 6)
    resetBtnCorner.Parent = resetBtn
    
    resetBtn.MouseButton1Click:Connect(function()
        -- Reset to defaults
        for k, v in pairs(defaultSettings) do
            currentSettings[k] = v
        end
        applySettingsToAutoFarm()
        
        -- Recreate overlay to update sliders
        createSettingsOverlay(parentFrame)
        showSettings()
        
        resetBtn.Text = '✅ Reset!'
        task.delay(1, function()
            if resetBtn and resetBtn.Parent then
                resetBtn.Text = '🔄 Reset Defaults'
            end
        end)
    end)
    
    resetBtn.MouseEnter:Connect(function()
        tweenProperty(resetBtn, {BackgroundColor3 = Color3.fromRGB(255, 200, 50)}, 0.1)
    end)
    
    resetBtn.MouseLeave:Connect(function()
        tweenProperty(resetBtn, {BackgroundColor3 = Colors.accent_warning}, 0.1)
    end)
    
    return settingsOverlay
end

-- ============================================================================
-- SHOW / HIDE SETTINGS
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
                screenGui.Name = 'AutoFarmSettingsGui'
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
            if _G.KillAuraSettingsAPI and _G.KillAuraSettingsAPI.isVisible and _G.KillAuraSettingsAPI.isVisible() then
                _G.KillAuraSettingsAPI.hide()
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
                    local isSettingsOverlay = child.Name == 'AutoFarmSettingsOverlay' or 
                                              child.Name == 'KillAuraSettingsOverlay' or 
                                              child.Name == 'AutoSellSettingsOverlay' or
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

local function toggleSettings(parentFrame)
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
-- CREATE SETTINGS BUTTON (⚙️)
-- ============================================================================
local function createSettingsButton(parentButton, contentArea, mainFrame)
    local settingsBtn = Instance.new('TextButton')
    settingsBtn.Name = 'AutoFarmSettingsBtn'
    settingsBtn.Size = UDim2.new(0, 32, 0, 32)
    settingsBtn.Position = UDim2.new(1, -42, 0, parentButton.Position.Y.Offset + 8)
    settingsBtn.BackgroundColor3 = Colors.settings_button
    settingsBtn.BorderSizePixel = 0
    settingsBtn.TextColor3 = Colors.text_primary
    settingsBtn.TextSize = 15
    settingsBtn.Font = Enum.Font.GothamBold
    settingsBtn.Text = '⚙️'
    settingsBtn.ZIndex = 10
    settingsBtn.Parent = contentArea
    
    local btnCorner = Instance.new('UICorner')
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = settingsBtn
    
    -- Glow effect
    local btnStroke = Instance.new('UIStroke')
    btnStroke.Color = Colors.accent_secondary
    btnStroke.Thickness = 1
    btnStroke.Transparency = 0.7
    btnStroke.Parent = settingsBtn
    
    -- Create the overlay on the main frame
    createSettingsOverlay(mainFrame)
    
    settingsBtn.MouseButton1Click:Connect(function()
        toggleSettings()
    end)
    
    settingsBtn.MouseEnter:Connect(function()
        tweenProperty(settingsBtn, {BackgroundColor3 = Color3.fromRGB(0, 180, 255)}, 0.1)
        tweenProperty(btnStroke, {Transparency = 0.3}, 0.1)
    end)
    
    settingsBtn.MouseLeave:Connect(function()
        tweenProperty(settingsBtn, {BackgroundColor3 = Colors.settings_button}, 0.1)
        tweenProperty(btnStroke, {Transparency = 0.7}, 0.1)
    end)
    
    return settingsBtn
end

-- ============================================================================
-- API EXPORT
-- ============================================================================
local AutoFarmSettingsAPI = {
    -- Core functions
    show = showSettings,
    hide = hideSettings,
    toggle = toggleSettings,
    
    -- Settings management
    loadSettings = loadSettings,
    saveSettings = saveSettings,
    applySettings = applySettingsToAutoFarm,
    
    -- GUI creation
    createSettingsButton = createSettingsButton,
    createSettingsOverlay = createSettingsOverlay,
    
    -- Current settings accessor
    getSettings = function()
        local copy = {}
        for k, v in pairs(currentSettings) do
            copy[k] = v
        end
        return copy
    end,
    
    setSettings = function(settings)
        if type(settings) ~= "table" then return end
        for key, value in pairs(settings) do
            if defaultSettings[key] ~= nil then
                currentSettings[key] = value
            end
        end
        applySettingsToAutoFarm()
    end,
    
    -- Individual setters for convenience
    setSpeed = function(speed)
        currentSettings.maxSpeed = tonumber(speed) or currentSettings.maxSpeed
        applySettingsToAutoFarm()
    end,
    
    setHeight = function(height)
        currentSettings.farmHeight = tonumber(height) or currentSettings.farmHeight
        applySettingsToAutoFarm()
    end,
    
    setBehind = function(distance)
        currentSettings.farmBehind = tonumber(distance) or currentSettings.farmBehind
        applySettingsToAutoFarm()
    end,
    
    setAntiDetection = function(enabled)
        currentSettings.antiDetectionEnabled = enabled == true
        applySettingsToAutoFarm()
    end,
    
    -- State check
    isVisible = function() return isVisible end,
    
    -- Get default settings
    getDefaults = function()
        local copy = {}
        for k, v in pairs(defaultSettings) do
            copy[k] = v
        end
        return copy
    end,
}

-- Export to globals
_G.AutoFarmSettingsAPI = AutoFarmSettingsAPI
getgenv().AutoFarmSettingsAPI = AutoFarmSettingsAPI

-- Load saved settings on API load
loadSettings()

return AutoFarmSettingsAPI
