-- ============================================================================
-- AUTO SELL SETTINGS API v2.0
-- ============================================================================
-- https://raw.githubusercontent.com/NotMe2007/For-All/main/PB%20WZ/autosellsettingsapi.lua
-- Provides settings overlay for Auto Sell functionality
-- Settings include: Sell rarity threshold, auto-sell toggle, keep best items,
-- anti-detection timing, level filters, and Legendary perk filtering
-- ============================================================================

local AutoSellSettingsAPI = {}

-- Services
local TweenService = game:GetService('TweenService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')

-- Get global environment
local _genv = getgenv()

-- Input connection tracking for proper cleanup
local inputConnections = {}

-- ============================================================================
-- COLOR SCHEME (Matching Main GUI)
-- ============================================================================

local Colors = {
    bg_primary = Color3.fromRGB(15, 15, 15),
    bg_secondary = Color3.fromRGB(25, 25, 25),
    bg_tertiary = Color3.fromRGB(35, 35, 35),
    accent_main = Color3.fromRGB(0, 255, 100),
    accent_secondary = Color3.fromRGB(0, 200, 255),
    accent_danger = Color3.fromRGB(255, 50, 50),
    accent_gold = Color3.fromRGB(255, 200, 0),
    accent_warning = Color3.fromRGB(255, 150, 0),
    accent_purple = Color3.fromRGB(160, 100, 255),
    text_primary = Color3.fromRGB(255, 255, 255),
    text_secondary = Color3.fromRGB(150, 150, 150),
    text_muted = Color3.fromRGB(100, 100, 100),
    border = Color3.fromRGB(40, 40, 40),
}

-- Rarity colors for visual feedback
local RarityColors = {
    Common = Color3.fromRGB(180, 180, 180),
    Uncommon = Color3.fromRGB(0, 200, 80),
    Rare = Color3.fromRGB(0, 150, 255),
    Epic = Color3.fromRGB(160, 50, 255),
    Legendary = Color3.fromRGB(255, 180, 0),
    Mythic = Color3.fromRGB(255, 50, 100),
}

-- Perk grade colors for visual feedback
local PerkGradeColors = {
    ["S+"] = Color3.fromRGB(255, 215, 0),
    ["S"] = Color3.fromRGB(255, 100, 100),
    ["A"] = Color3.fromRGB(160, 50, 255),
    ["B"] = Color3.fromRGB(0, 150, 255),
    ["C"] = Color3.fromRGB(180, 180, 180),
}

-- Rarity order (lowest to highest) - Mythic excluded from selling
local rarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- Perk grade order (best to worst) for Legendary filtering
local perkGradeOrder = { "S+", "S", "A", "B", "C" }

-- ============================================================================
-- DEFAULT SETTINGS (synced with autosell.lua) - FLATTENED for Roblox Lua
-- ============================================================================

local defaultSettings = {
    -- Core Settings
    enabled = false,
    sellThreshold = "Rare",
    keepBestCount = 1,
    sellOnPickup = false,
    sellDelay = 0.5,
    sellInterval = 30,
    
    -- Exclusion Settings
    excludeEquipped = true,
    excludeFavorites = true,
    excludePets = true,
    confirmLegendary = true,
    
    -- Level Filters
    MaxLevelToSell = 0,
    MinLevelToKeep = 0,
    
    -- Legendary Perk Filtering
    sellLegendaryIfNotPerk = false,
    legendaryMinPerkGrade = "S",
    
    -- Anti-Detection Settings (flattened with AD_ prefix)
    AD_minSellDelay = 0.3,
    AD_maxSellDelay = 0.8,
    AD_sellBatchVariance = 0.2,
    AD_jitterEnabled = true,
    AD_microPauseChance = 0.15,
    AD_microPauseMin = 0.1,
    AD_microPauseMax = 0.3,
}

-- ============================================================================
-- SETTINGS STATE
-- ============================================================================

local settingsOverlay = nil
local isVisible = false
local currentSettings = {}

-- ============================================================================
-- TWEEN HELPER
-- ============================================================================

local function tweenColor(obj, newColor, duration)
    if not obj then return nil end
    if not obj.Parent then return nil end
    local tweenInfo = TweenInfo.new(
        duration or 0.15,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(obj, tweenInfo, { BackgroundColor3 = newColor })
    tween:Play()
    return tween
end

local function tweenTransparency(obj, newTransparency, duration)
    if not obj then return nil end
    if not obj.Parent then return nil end
    local tweenInfo = TweenInfo.new(
        duration or 0.15,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(obj, tweenInfo, { BackgroundTransparency = newTransparency })
    tween:Play()
    return tween
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Initialize settings
local function initSettings()
    for key, value in pairs(defaultSettings) do
        if _genv["AutoSell_" .. key] == nil then
            _genv["AutoSell_" .. key] = value
        end
        currentSettings[key] = _genv["AutoSell_" .. key]
    end
end

-- Save settings to genv
local function saveToGenv()
    for key, value in pairs(currentSettings) do
        _genv["AutoSell_" .. key] = value
    end
end

-- Get rarity index
local function getRarityIndex(rarity)
    for i, r in ipairs(rarityOrder) do
        if r == rarity then return i end
    end
    return 1
end

-- Get display text for rarity
local function getRarityDisplayText(rarity)
    if rarity == "Common" then
        return "Common"
    else
        return rarity .. " & Below"
    end
end

-- Get perk grade index
local function getPerkGradeIndex(grade)
    for i, g in ipairs(perkGradeOrder) do
        if g == grade then return i end
    end
    return 2
end

-- ============================================================================
-- SETTINGS FILE PERSISTENCE
-- ============================================================================

local ZENX_FOLDER = "ZenX WZ"
local SETTINGS_FILE = ZENX_FOLDER .. "/zenx_autosell_settings.json"

local function ensureFolder()
    if isfolder and makefolder then
        pcall(function()
            if not isfolder(ZENX_FOLDER) then
                makefolder(ZENX_FOLDER)
            end
        end)
    end
end

local function saveSettingsToFile()
    if not writefile then return false end
    
    ensureFolder()
    
    local success = pcall(function()
        local HttpService = game:GetService("HttpService")
        local jsonStr = HttpService:JSONEncode(currentSettings)
        writefile(SETTINGS_FILE, jsonStr)
    end)
    
    return success
end

local function loadSettingsFromFile()
    if not readfile then return false end
    if not isfile then return false end
    
    local success = pcall(function()
        if isfile(SETTINGS_FILE) then
            local content = readfile(SETTINGS_FILE)
            if content and content ~= "" then
                local HttpService = game:GetService("HttpService")
                local decoded = HttpService:JSONDecode(content)
                if decoded then
                    for key, value in pairs(decoded) do
                        if defaultSettings[key] ~= nil then
                            currentSettings[key] = value
                        end
                    end
                    saveToGenv()
                end
            end
        end
    end)
    
    return success
end

-- ============================================================================
-- UI COMPONENT FACTORY
-- ============================================================================

local function createSectionHeader(parent, text, yPos, icon)
    local header = Instance.new('TextLabel')
    header.Name = 'Section_' .. text:gsub(' ', '')
    header.Size = UDim2.new(1, -20, 0, 22)
    header.Position = UDim2.new(0, 10, 0, yPos)
    header.BackgroundTransparency = 1
    header.TextColor3 = Colors.accent_secondary
    header.TextSize = 12
    header.Font = Enum.Font.GothamBold
    if icon then
        header.Text = icon .. ' ' .. text
    else
        header.Text = text
    end
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.ZIndex = 113
    header.Parent = parent
    return header
end

local function createToggle(parent, name, labelText, yPos, getValue, setValue)
    local label = Instance.new('TextLabel')
    label.Name = name .. '_Label'
    label.Size = UDim2.new(0.7, 0, 0, 28)
    label.Position = UDim2.new(0, 10, 0, yPos)
    label.BackgroundTransparency = 1
    label.TextColor3 = Colors.text_primary
    label.TextSize = 11
    label.Font = Enum.Font.GothamBold
    label.Text = labelText
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 113
    label.Parent = parent

    local toggleBg = Instance.new('Frame')
    toggleBg.Name = name .. '_Bg'
    toggleBg.Size = UDim2.new(0, 44, 0, 22)
    toggleBg.Position = UDim2.new(1, -54, 0, yPos + 3)
    if getValue() then
        toggleBg.BackgroundColor3 = Colors.accent_main
    else
        toggleBg.BackgroundColor3 = Colors.bg_tertiary
    end
    toggleBg.BorderSizePixel = 0
    toggleBg.Active = true
    toggleBg.ZIndex = 114
    toggleBg.Parent = parent

    local toggleBgCorner = Instance.new('UICorner')
    toggleBgCorner.CornerRadius = UDim.new(1, 0)
    toggleBgCorner.Parent = toggleBg

    local toggleKnob = Instance.new('Frame')
    toggleKnob.Name = 'Knob'
    toggleKnob.Size = UDim2.new(0, 18, 0, 18)
    if getValue() then
        toggleKnob.Position = UDim2.new(1, -20, 0.5, -9)
    else
        toggleKnob.Position = UDim2.new(0, 2, 0.5, -9)
    end
    toggleKnob.BackgroundColor3 = Colors.text_primary
    toggleKnob.BorderSizePixel = 0
    toggleKnob.ZIndex = 115
    toggleKnob.Parent = toggleBg

    local toggleKnobCorner = Instance.new('UICorner')
    toggleKnobCorner.CornerRadius = UDim.new(1, 0)
    toggleKnobCorner.Parent = toggleKnob

    local toggleBtn = Instance.new('TextButton')
    toggleBtn.Name = name .. '_Btn'
    toggleBtn.Size = UDim2.new(1, 0, 1, 0)
    toggleBtn.Position = UDim2.new(0, 0, 0, 0)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Text = ''
    toggleBtn.ZIndex = 116
    toggleBtn.Parent = toggleBg

    toggleBtn.MouseButton1Click:Connect(function()
        local newValue = not getValue()
        setValue(newValue)
        
        if newValue then
            tweenColor(toggleBg, Colors.accent_main, 0.15)
        else
            tweenColor(toggleBg, Colors.bg_tertiary, 0.15)
        end
        
        local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local targetPos
        if newValue then
            targetPos = UDim2.new(1, -20, 0.5, -9)
        else
            targetPos = UDim2.new(0, 2, 0.5, -9)
        end
        TweenService:Create(toggleKnob, tweenInfo, { Position = targetPos }):Play()
        
        saveToGenv()
    end)

    return { bg = toggleBg, knob = toggleKnob, btn = toggleBtn, label = label }
end

local function createSlider(parent, name, labelText, yPos, minVal, maxVal, getValue, setValue, formatFunc, color)
    if not color then color = Colors.accent_secondary end
    if not formatFunc then formatFunc = function(v) return tostring(v) end end
    
    local label = Instance.new('TextLabel')
    label.Name = name .. '_Label'
    label.Size = UDim2.new(0.6, 0, 0, 20)
    label.Position = UDim2.new(0, 10, 0, yPos)
    label.BackgroundTransparency = 1
    label.TextColor3 = Colors.text_primary
    label.TextSize = 11
    label.Font = Enum.Font.GothamBold
    label.Text = labelText
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 113
    label.Parent = parent

    local valueLabel = Instance.new('TextLabel')
    valueLabel.Name = name .. '_Value'
    valueLabel.Size = UDim2.new(0.35, 0, 0, 20)
    valueLabel.Position = UDim2.new(0.6, 0, 0, yPos)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3 = color
    valueLabel.TextSize = 11
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Text = formatFunc(getValue())
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.ZIndex = 113
    valueLabel.Parent = parent

    local sliderBg = Instance.new('Frame')
    sliderBg.Name = name .. '_SliderBg'
    sliderBg.Size = UDim2.new(1, -20, 0, 14)
    sliderBg.Position = UDim2.new(0, 10, 0, yPos + 22)
    sliderBg.BackgroundColor3 = Colors.bg_tertiary
    sliderBg.BorderSizePixel = 0
    sliderBg.Active = true
    sliderBg.ZIndex = 113
    sliderBg.Parent = parent

    local sliderBgCorner = Instance.new('UICorner')
    sliderBgCorner.CornerRadius = UDim.new(0, 7)
    sliderBgCorner.Parent = sliderBg

    local percentage = (getValue() - minVal) / (maxVal - minVal)

    local sliderFill = Instance.new('Frame')
    sliderFill.Name = 'Fill'
    sliderFill.Size = UDim2.new(math.clamp(percentage, 0, 1), 0, 1, 0)
    sliderFill.Position = UDim2.new(0, 0, 0, 0)
    sliderFill.BackgroundColor3 = color
    sliderFill.BorderSizePixel = 0
    sliderFill.ZIndex = 114
    sliderFill.Parent = sliderBg

    local sliderFillCorner = Instance.new('UICorner')
    sliderFillCorner.CornerRadius = UDim.new(0, 7)
    sliderFillCorner.Parent = sliderFill

    local knob = Instance.new('Frame')
    knob.Name = 'Knob'
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(math.clamp(percentage, 0, 1), -9, 0.5, -9)
    knob.BackgroundColor3 = Colors.text_primary
    knob.BorderSizePixel = 0
    knob.Active = true
    knob.ZIndex = 115
    knob.Parent = sliderBg

    local knobCorner = Instance.new('UICorner')
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local dragging = false

    local function updateSlider(inputPos)
        local sliderAbsPos = sliderBg.AbsolutePosition
        local sliderAbsSize = sliderBg.AbsoluteSize
        local relativeX = math.clamp((inputPos.X - sliderAbsPos.X) / sliderAbsSize.X, 0, 1)
        
        local value = minVal + (relativeX * (maxVal - minVal))
        
        if maxVal - minVal >= 10 then
            value = math.floor(value + 0.5)
        else
            value = math.floor(value * 100 + 0.5) / 100
        end
        value = math.clamp(value, minVal, maxVal)
        
        setValue(value)
        
        local pct = (value - minVal) / (maxVal - minVal)
        sliderFill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
        knob.Position = UDim2.new(math.clamp(pct, 0, 1), -9, 0.5, -9)
        valueLabel.Text = formatFunc(value)
        
        saveToGenv()
    end

    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateSlider(input.Position)
        elseif input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateSlider(input.Position)
        end
    end)

    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        elseif input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)

    local slider = {}
    slider.bg = sliderBg
    slider.fill = sliderFill
    slider.knob = knob
    slider.label = label
    slider.valueLabel = valueLabel
    slider.isDragging = function() return dragging end
    slider.setDragging = function(v) dragging = v end
    slider.update = updateSlider
    
    return slider
end

local function createNumberInput(parent, name, labelText, yPos, getValue, setValue, minVal, maxVal)
    if not minVal then minVal = 0 end
    if not maxVal then maxVal = 999 end
    
    local label = Instance.new('TextLabel')
    label.Name = name .. '_Label'
    label.Size = UDim2.new(0.55, 0, 0, 28)
    label.Position = UDim2.new(0, 10, 0, yPos)
    label.BackgroundTransparency = 1
    label.TextColor3 = Colors.text_primary
    label.TextSize = 11
    label.Font = Enum.Font.GothamBold
    label.Text = labelText
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 113
    label.Parent = parent

    local inputBox = Instance.new('TextBox')
    inputBox.Name = name .. '_Input'
    inputBox.Size = UDim2.new(0.35, 0, 0, 28)
    inputBox.Position = UDim2.new(0.6, 0, 0, yPos)
    inputBox.BackgroundColor3 = Colors.bg_tertiary
    inputBox.BorderSizePixel = 0
    inputBox.TextColor3 = Colors.text_primary
    inputBox.PlaceholderText = '0'
    inputBox.PlaceholderColor3 = Colors.text_muted
    inputBox.Text = tostring(getValue())
    inputBox.TextSize = 12
    inputBox.Font = Enum.Font.GothamBold
    inputBox.ClearTextOnFocus = false
    inputBox.ZIndex = 114
    inputBox.Parent = parent

    local inputCorner = Instance.new('UICorner')
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = inputBox

    inputBox.FocusLost:Connect(function()
        local num = tonumber(inputBox.Text)
        if num and num >= minVal and num <= maxVal then
            setValue(math.floor(num))
            inputBox.Text = tostring(math.floor(num))
        else
            inputBox.Text = tostring(getValue())
        end
        saveToGenv()
    end)

    return { label = label, input = inputBox }
end

-- ============================================================================
-- CREATE SETTINGS OVERLAY
-- ============================================================================

local function createSettingsOverlay(parentFrame)
    -- Cleanup existing
    if settingsOverlay and settingsOverlay.Parent then
        for _, conn in ipairs(inputConnections) do
            if conn then
                pcall(function() conn:Disconnect() end)
            end
        end
        inputConnections = {}
        settingsOverlay:Destroy()
    end
    
    initSettings()
    loadSettingsFromFile()
    
    -- Main overlay frame - HIGH ZIndex and Active for click blocking
    settingsOverlay = Instance.new('Frame')
    settingsOverlay.Name = 'AutoSellSettingsOverlay'
    settingsOverlay.Size = UDim2.new(1, 0, 1, 0)
    settingsOverlay.Position = UDim2.new(0, 0, 0, 0)
    settingsOverlay.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    settingsOverlay.BackgroundTransparency = 0
    settingsOverlay.BorderSizePixel = 0
    settingsOverlay.Visible = false
    settingsOverlay.Active = true
    settingsOverlay.Selectable = true
    settingsOverlay.ZIndex = 100
    settingsOverlay.Parent = parentFrame

    local overlayCorner = Instance.new('UICorner')
    overlayCorner.CornerRadius = UDim.new(0, 8)
    overlayCorner.Parent = settingsOverlay

    -- Header
    local header = Instance.new('Frame')
    header.Name = 'Header'
    header.Size = UDim2.new(1, 0, 0, 38)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Colors.bg_secondary
    header.BorderSizePixel = 0
    header.Active = true
    header.ZIndex = 110
    header.Parent = settingsOverlay

    local headerCorner = Instance.new('UICorner')
    headerCorner.CornerRadius = UDim.new(0, 8)
    headerCorner.Parent = header

    local title = Instance.new('TextLabel')
    title.Name = 'Title'
    title.Size = UDim2.new(1, -50, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Colors.accent_gold
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.Text = '💲 Auto Sell Settings'
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 111
    title.Parent = header

    local closeBtn = Instance.new('TextButton')
    closeBtn.Name = 'CloseBtn'
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -36, 0, 3)
    closeBtn.BackgroundColor3 = Colors.accent_danger
    closeBtn.BorderSizePixel = 0
    closeBtn.TextColor3 = Colors.text_primary
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = 'X'
    closeBtn.ZIndex = 112
    closeBtn.Parent = header

    local closeBtnCorner = Instance.new('UICorner')
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        AutoSellSettingsAPI.hide()
    end)

    closeBtn.MouseEnter:Connect(function()
        tweenColor(closeBtn, Color3.fromRGB(255, 80, 80), 0.1)
    end)

    closeBtn.MouseLeave:Connect(function()
        tweenColor(closeBtn, Colors.accent_danger, 0.1)
    end)

    -- Content ScrollingFrame
    local content = Instance.new('ScrollingFrame')
    content.Name = 'Content'
    content.Size = UDim2.new(1, 0, 1, -38)
    content.Position = UDim2.new(0, 0, 0, 38)
    content.BackgroundTransparency = 1
    content.Active = true
    content.ZIndex = 110
    content.ScrollBarThickness = 4
    content.ScrollBarImageColor3 = Colors.accent_gold
    content.CanvasSize = UDim2.new(0, 0, 0, 920)
    content.ScrollingDirection = Enum.ScrollingDirection.Y
    content.BorderSizePixel = 0
    content.Parent = settingsOverlay

    local yOffset = 10
    local sliders = {}

    -- ========================================================================
    -- SECTION: Core Settings
    -- ========================================================================
    
    createSectionHeader(content, 'Core Settings', yOffset, '⚙️')
    yOffset = yOffset + 28

    -- Sell Threshold (Rarity Slider)
    local thresholdSlider = createSlider(
        content, 'SellThreshold', 'Auto Sell Rarity', yOffset,
        1, 5,
        function() return getRarityIndex(currentSettings.sellThreshold) end,
        function(v)
            local idx = math.clamp(math.floor(v + 0.5), 1, 5)
            currentSettings.sellThreshold = rarityOrder[idx]
        end,
        function(v)
            local idx = math.clamp(math.floor(v + 0.5), 1, 5)
            return getRarityDisplayText(rarityOrder[idx])
        end,
        RarityColors[currentSettings.sellThreshold]
    )
    table.insert(sliders, thresholdSlider)
    yOffset = yOffset + 46

    -- Keep Best Count
    local keepSlider = createSlider(
        content, 'KeepBest', 'Keep Best Items', yOffset,
        1, 10,
        function() return currentSettings.keepBestCount end,
        function(v) currentSettings.keepBestCount = math.floor(v) end,
        function(v) return tostring(math.floor(v)) end,
        Colors.accent_secondary
    )
    table.insert(sliders, keepSlider)
    yOffset = yOffset + 46

    -- Sell Delay
    local delaySlider = createSlider(
        content, 'SellDelay', 'Base Sell Delay (sec)', yOffset,
        0.1, 3.0,
        function() return currentSettings.sellDelay end,
        function(v) currentSettings.sellDelay = v end,
        function(v) return string.format("%.1f", v) end,
        Colors.accent_warning
    )
    table.insert(sliders, delaySlider)
    yOffset = yOffset + 46

    -- Sell Interval
    local intervalSlider = createSlider(
        content, 'SellInterval', 'Auto-Sell Interval (sec)', yOffset,
        5, 120,
        function() return currentSettings.sellInterval end,
        function(v) currentSettings.sellInterval = math.floor(v) end,
        function(v) return tostring(math.floor(v)) end,
        Colors.accent_purple
    )
    table.insert(sliders, intervalSlider)
    yOffset = yOffset + 50

    -- ========================================================================
    -- SECTION: Toggle Options
    -- ========================================================================
    
    createSectionHeader(content, 'Exclusion Settings', yOffset, '🛡️')
    yOffset = yOffset + 28

    createToggle(content, 'SellOnPickup', 'Sell on Pickup', yOffset,
        function() return currentSettings.sellOnPickup end,
        function(v) currentSettings.sellOnPickup = v end
    )
    yOffset = yOffset + 32

    createToggle(content, 'ExcludeEquipped', 'Exclude Equipped Items', yOffset,
        function() return currentSettings.excludeEquipped end,
        function(v) currentSettings.excludeEquipped = v end
    )
    yOffset = yOffset + 32

    createToggle(content, 'ExcludeFavorites', 'Exclude Favorites', yOffset,
        function() return currentSettings.excludeFavorites end,
        function(v) currentSettings.excludeFavorites = v end
    )
    yOffset = yOffset + 32

    createToggle(content, 'ExcludePets', 'Never Sell Pets', yOffset,
        function() return currentSettings.excludePets end,
        function(v) currentSettings.excludePets = v end
    )
    yOffset = yOffset + 32

    createToggle(content, 'ConfirmLegendary', 'Confirm Legendary+', yOffset,
        function() return currentSettings.confirmLegendary end,
        function(v) currentSettings.confirmLegendary = v end
    )
    yOffset = yOffset + 38

    -- ========================================================================
    -- SECTION: Level Filters
    -- ========================================================================
    
    createSectionHeader(content, 'Level Filters', yOffset, '📊')
    yOffset = yOffset + 28

    local levelNote = Instance.new('TextLabel')
    levelNote.Size = UDim2.new(1, -20, 0, 16)
    levelNote.Position = UDim2.new(0, 10, 0, yOffset)
    levelNote.BackgroundTransparency = 1
    levelNote.TextColor3 = Colors.text_muted
    levelNote.TextSize = 9
    levelNote.Font = Enum.Font.Gotham
    levelNote.Text = '(Set to 0 to disable filter)'
    levelNote.TextXAlignment = Enum.TextXAlignment.Left
    levelNote.ZIndex = 113
    levelNote.Parent = content
    yOffset = yOffset + 22

    createNumberInput(content, 'MaxLevelToSell', 'Max Level to Sell', yOffset,
        function() return currentSettings.MaxLevelToSell end,
        function(v) currentSettings.MaxLevelToSell = v end,
        0, 999
    )
    yOffset = yOffset + 34

    createNumberInput(content, 'MinLevelToKeep', 'Min Level to Keep', yOffset,
        function() return currentSettings.MinLevelToKeep end,
        function(v) currentSettings.MinLevelToKeep = v end,
        0, 999
    )
    yOffset = yOffset + 42

    -- ========================================================================
    -- SECTION: Legendary Perk Filter
    -- ========================================================================
    
    createSectionHeader(content, 'Legendary Perk Filter', yOffset, '⭐')
    yOffset = yOffset + 28

    local perkToggle = createToggle(content, 'SellLegendaryBadPerk', 'Sell Legendary w/ Bad Perks', yOffset,
        function() return currentSettings.sellLegendaryIfNotPerk end,
        function(v)
            currentSettings.sellLegendaryIfNotPerk = v
            local perkSection = content:FindFirstChild('PerkGradeSection')
            if perkSection then
                perkSection.Visible = v
            end
        end
    )
    yOffset = yOffset + 36

    -- Perk grade section (collapsible)
    local perkSection = Instance.new('Frame')
    perkSection.Name = 'PerkGradeSection'
    perkSection.Size = UDim2.new(1, 0, 0, 80)
    perkSection.Position = UDim2.new(0, 0, 0, yOffset)
    perkSection.BackgroundTransparency = 1
    perkSection.Visible = currentSettings.sellLegendaryIfNotPerk
    perkSection.ZIndex = 112
    perkSection.Parent = content

    local perkGradeSlider = createSlider(
        perkSection, 'MinPerkGrade', 'Keep if Perk >=', 0,
        1, 5,
        function() return getPerkGradeIndex(currentSettings.legendaryMinPerkGrade) end,
        function(v)
            local idx = math.clamp(math.floor(v + 0.5), 1, 5)
            currentSettings.legendaryMinPerkGrade = perkGradeOrder[idx]
        end,
        function(v)
            local idx = math.clamp(math.floor(v + 0.5), 1, 5)
            return perkGradeOrder[idx]
        end,
        PerkGradeColors[currentSettings.legendaryMinPerkGrade]
    )
    table.insert(sliders, perkGradeSlider)

    local perkDesc = Instance.new('TextLabel')
    perkDesc.Size = UDim2.new(1, -20, 0, 30)
    perkDesc.Position = UDim2.new(0, 10, 0, 44)
    perkDesc.BackgroundTransparency = 1
    perkDesc.TextColor3 = Colors.text_muted
    perkDesc.TextSize = 9
    perkDesc.Font = Enum.Font.Gotham
    perkDesc.Text = 'S+ = Perfect | S = Near-perfect | A = Good | B = Decent | C = Poor'
    perkDesc.TextXAlignment = Enum.TextXAlignment.Left
    perkDesc.TextWrapped = true
    perkDesc.ZIndex = 113
    perkDesc.Parent = perkSection

    yOffset = yOffset + 90

    -- ========================================================================
    -- SECTION: Anti-Detection
    -- ========================================================================
    
    createSectionHeader(content, 'Anti-Detection Timing', yOffset, '🔒')
    yOffset = yOffset + 28

    -- Min Sell Delay
    local minDelaySlider = createSlider(
        content, 'ADMinDelay', 'Min Delay (sec)', yOffset,
        0.1, 1.0,
        function() return currentSettings.AD_minSellDelay end,
        function(v) currentSettings.AD_minSellDelay = v end,
        function(v) return string.format("%.2f", v) end,
        Colors.accent_main
    )
    table.insert(sliders, minDelaySlider)
    yOffset = yOffset + 44

    -- Max Sell Delay
    local maxDelaySlider = createSlider(
        content, 'ADMaxDelay', 'Max Delay (sec)', yOffset,
        0.3, 2.0,
        function() return currentSettings.AD_maxSellDelay end,
        function(v) currentSettings.AD_maxSellDelay = v end,
        function(v) return string.format("%.2f", v) end,
        Colors.accent_main
    )
    table.insert(sliders, maxDelaySlider)
    yOffset = yOffset + 44

    -- Batch Variance
    local varianceSlider = createSlider(
        content, 'ADBatchVar', 'Batch Variance (%)', yOffset,
        0, 50,
        function() return currentSettings.AD_sellBatchVariance * 100 end,
        function(v) currentSettings.AD_sellBatchVariance = v / 100 end,
        function(v) return string.format("%.0f%%", v) end,
        Colors.accent_secondary
    )
    table.insert(sliders, varianceSlider)
    yOffset = yOffset + 48

    -- Jitter Enabled
    createToggle(content, 'ADJitter', 'Enable Micro-Jitter', yOffset,
        function() return currentSettings.AD_jitterEnabled end,
        function(v) currentSettings.AD_jitterEnabled = v end
    )
    yOffset = yOffset + 34

    -- Micro Pause Chance
    local pauseChanceSlider = createSlider(
        content, 'ADPauseChance', 'Pause Chance (%)', yOffset,
        0, 50,
        function() return currentSettings.AD_microPauseChance * 100 end,
        function(v) currentSettings.AD_microPauseChance = v / 100 end,
        function(v) return string.format("%.0f%%", v) end,
        Colors.accent_warning
    )
    table.insert(sliders, pauseChanceSlider)
    yOffset = yOffset + 44

    -- Micro Pause Min
    local pauseMinSlider = createSlider(
        content, 'ADPauseMin', 'Pause Min (sec)', yOffset,
        0.05, 0.5,
        function() return currentSettings.AD_microPauseMin end,
        function(v) currentSettings.AD_microPauseMin = v end,
        function(v) return string.format("%.2f", v) end,
        Colors.accent_purple
    )
    table.insert(sliders, pauseMinSlider)
    yOffset = yOffset + 44

    -- Micro Pause Max
    local pauseMaxSlider = createSlider(
        content, 'ADPauseMax', 'Pause Max (sec)', yOffset,
        0.1, 1.0,
        function() return currentSettings.AD_microPauseMax end,
        function(v) currentSettings.AD_microPauseMax = v end,
        function(v) return string.format("%.2f", v) end,
        Colors.accent_purple
    )
    table.insert(sliders, pauseMaxSlider)
    yOffset = yOffset + 52

    -- ========================================================================
    -- SAVE BUTTON
    -- ========================================================================

    local saveBtn = Instance.new('TextButton')
    saveBtn.Name = 'SaveBtn'
    saveBtn.Size = UDim2.new(1, -20, 0, 40)
    saveBtn.Position = UDim2.new(0, 10, 0, yOffset)
    saveBtn.BackgroundColor3 = Colors.accent_main
    saveBtn.BorderSizePixel = 0
    saveBtn.TextColor3 = Colors.bg_primary
    saveBtn.TextSize = 13
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.Text = '💾 Save Settings'
    saveBtn.ZIndex = 113
    saveBtn.Parent = content

    local saveBtnCorner = Instance.new('UICorner')
    saveBtnCorner.CornerRadius = UDim.new(0, 8)
    saveBtnCorner.Parent = saveBtn

    saveBtn.MouseButton1Click:Connect(function()
        local success = saveSettingsToFile()
        if success then
            saveBtn.Text = '✓ Saved!'
            tweenColor(saveBtn, Color3.fromRGB(0, 200, 80), 0.1)
            task.delay(1.5, function()
                if saveBtn and saveBtn.Parent then
                    saveBtn.Text = '💾 Save Settings'
                    tweenColor(saveBtn, Colors.accent_main, 0.2)
                end
            end)
        else
            saveBtn.Text = 'X Save Failed!'
            tweenColor(saveBtn, Colors.accent_danger, 0.1)
            task.delay(1.5, function()
                if saveBtn and saveBtn.Parent then
                    saveBtn.Text = '💾 Save Settings'
                    tweenColor(saveBtn, Colors.accent_main, 0.2)
                end
            end)
        end
    end)

    saveBtn.MouseEnter:Connect(function()
        tweenColor(saveBtn, Color3.fromRGB(0, 220, 90), 0.1)
    end)

    saveBtn.MouseLeave:Connect(function()
        tweenColor(saveBtn, Colors.accent_main, 0.1)
    end)

    yOffset = yOffset + 50

    -- Update canvas size
    -- Update canvas size with extra padding at bottom for visibility
    content.CanvasSize = UDim2.new(0, 0, 0, yOffset + 60)

    -- ========================================================================
    -- GLOBAL INPUT HANDLING FOR SLIDERS
    -- ========================================================================

    local inputChangedConn = UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            for _, slider in ipairs(sliders) do
                if slider.isDragging() then
                    slider.update(input.Position)
                    break
                end
            end
        elseif input.UserInputType == Enum.UserInputType.Touch then
            for _, slider in ipairs(sliders) do
                if slider.isDragging() then
                    slider.update(input.Position)
                    break
                end
            end
        end
    end)
    table.insert(inputConnections, inputChangedConn)

    local inputEndedConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            for _, slider in ipairs(sliders) do
                slider.setDragging(false)
            end
        elseif input.UserInputType == Enum.UserInputType.Touch then
            for _, slider in ipairs(sliders) do
                slider.setDragging(false)
            end
        end
    end)
    table.insert(inputConnections, inputEndedConn)

    return settingsOverlay
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function AutoSellSettingsAPI.show(parentFrame)
    -- Auto-create standalone GUI if no parent provided
    if not parentFrame then
        local player = Players.LocalPlayer
        if player then
            local playerGui = player:FindFirstChild('PlayerGui')
            if playerGui then
                local existingGui = playerGui:FindFirstChild('AutoSellSettingsGui')
                if existingGui then
                    parentFrame = existingGui:FindFirstChild('SettingsContainer')
                else
                    local screenGui = Instance.new('ScreenGui')
                    screenGui.Name = 'AutoSellSettingsGui'
                    screenGui.ResetOnSpawn = false
                    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
                    screenGui.DisplayOrder = 999  -- High display order to be on top
                    screenGui.Parent = playerGui
                    
                    local container = Instance.new('Frame')
                    container.Name = 'SettingsContainer'
                    container.Size = UDim2.new(1, 0, 1, 0)
                    container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                    container.BackgroundTransparency = 0.5  -- Semi-transparent backdrop
                    container.Active = true  -- CRITICAL: Block clicks to GUIs below
                    container.Parent = screenGui
                    
                    parentFrame = container
                end
            end
        end
    end
    
    if not settingsOverlay then
        createSettingsOverlay(parentFrame)
    elseif not settingsOverlay.Parent then
        createSettingsOverlay(parentFrame)
    end
    
    if settingsOverlay then
        -- Close other settings overlays to prevent conflicts
        pcall(function()
            if _G.KillAuraSettingsAPI and _G.KillAuraSettingsAPI.isVisible and _G.KillAuraSettingsAPI.isVisible() then
                _G.KillAuraSettingsAPI.hide()
            end
            if _G.AutoFarmSettingsAPI and _G.AutoFarmSettingsAPI.isVisible and _G.AutoFarmSettingsAPI.isVisible() then
                _G.AutoFarmSettingsAPI.hide()
            end
        end)
        
        local mainFrame = settingsOverlay.Parent
        if mainFrame then
            for _, child in ipairs(mainFrame:GetChildren()) do
                -- Hide content areas (ScrollingFrame or Frame with 'Content' in name)
                if (child:IsA('ScrollingFrame') or child:IsA('Frame')) and child.Name:find('Content') then
                    child.Visible = false
                elseif child:IsA('Frame') and child.Name ~= 'AutoSellSettingsOverlay' and child.Name ~= 'Header' then
                    child.Visible = false
                end
            end
        end
        
        settingsOverlay.Visible = true
        settingsOverlay.BackgroundTransparency = 1
        tweenTransparency(settingsOverlay, 0, 0.2)
        isVisible = true
    end
end

function AutoSellSettingsAPI.hide()
    if settingsOverlay and settingsOverlay.Visible then
        isVisible = false
        
        local function cleanupOverlay()
            if settingsOverlay then
                settingsOverlay.Visible = false
                settingsOverlay.BackgroundTransparency = 0  -- Reset for next show
                
                local mainFrame = settingsOverlay.Parent
                if mainFrame then
                    for _, child in ipairs(mainFrame:GetChildren()) do
                        -- Restore content areas, but skip ALL settings overlays
                        local isSettingsOverlay = child.Name == 'AutoSellSettingsOverlay' or 
                                                  child.Name == 'KillAuraSettingsOverlay' or 
                                                  child.Name == 'AutoFarmSettingsOverlay' or
                                                  child.Name == 'Header'
                        if not isSettingsOverlay then
                            if (child:IsA('ScrollingFrame') or child:IsA('Frame')) and child.Name:find('Content') then
                                child.Visible = true
                            elseif child:IsA('Frame') then
                                child.Visible = true
                            end
                        end
                    end
                end
            end
        end
        
        local tween = tweenTransparency(settingsOverlay, 1, 0.15)
        if tween then
            tween.Completed:Connect(cleanupOverlay)
        else
            -- Fallback: if tween fails, immediately cleanup
            cleanupOverlay()
        end
    end
end

function AutoSellSettingsAPI.toggle(parentFrame)
    if isVisible then
        AutoSellSettingsAPI.hide()
    else
        AutoSellSettingsAPI.show(parentFrame)
    end
end

function AutoSellSettingsAPI.isVisible()
    return isVisible
end

function AutoSellSettingsAPI.getSettings()
    return currentSettings
end

function AutoSellSettingsAPI.getSetting(key)
    return currentSettings[key]
end

function AutoSellSettingsAPI.setSetting(key, value)
    if currentSettings[key] ~= nil then
        currentSettings[key] = value
        saveToGenv()
        return true
    end
    return false
end

function AutoSellSettingsAPI.loadSettings()
    initSettings()
    return loadSettingsFromFile()
end

function AutoSellSettingsAPI.saveSettings()
    return saveSettingsToFile()
end

function AutoSellSettingsAPI.destroy()
    for _, conn in ipairs(inputConnections) do
        if conn then
            pcall(function() conn:Disconnect() end)
        end
    end
    inputConnections = {}
    
    if settingsOverlay then
        settingsOverlay:Destroy()
        settingsOverlay = nil
    end
    isVisible = false
end

-- Initialize on load
initSettings()
loadSettingsFromFile()

-- Store in global
_G.AutoSellSettingsAPI = AutoSellSettingsAPI
getgenv().AutoSellSettingsAPI = AutoSellSettingsAPI

return AutoSellSettingsAPI
