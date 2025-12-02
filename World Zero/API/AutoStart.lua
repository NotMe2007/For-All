-- Auto Start Dungeon/Tower
-- Automatically starts dungeons or towers based on player level
-- https://pastebin.com/raw/JyknFgp2

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

-- Configuration via getgenv
local _genv = getgenv()
if _genv.AutoStartEnabled == nil then
    _genv.AutoStartEnabled = false
end
if _genv.AutoStartMode == nil then
    _genv.AutoStartMode = 'Dungeon'  -- 'Dungeon' or 'Tower'
end
if _genv.AutoStartCustomId == nil then
    _genv.AutoStartCustomId = nil  -- nil = auto-select by level, or set specific ID
end

-- Custom wait using Heartbeat
local function wait(sec)
    sec = tonumber(sec)
    if sec and sec > 0 then
        local t0 = os.clock()
        while os.clock() - t0 < sec do
            RunService.Heartbeat:Wait()
        end
    else
        RunService.Heartbeat:Wait()
    end
end

-- Get player
local plr = Players.LocalPlayer
if not plr then
    warn('[AutoStart] Player not found')
    return
end

-- Get player level
local function GetPlayerLevel()
    local level = 0
    pcall(function()
        -- Try LocalPlayer.Data.Level first
        if plr and plr:FindFirstChild('Data') then
            local data = plr.Data
            if data:FindFirstChild('Level') then
                level = data.Level.Value
                return
            end
        end
        
        -- Fallback to ReplicatedStorage.Profiles
        if ReplicatedStorage and ReplicatedStorage:FindFirstChild('Profiles') then
            local profile = ReplicatedStorage.Profiles:FindFirstChild(plr.Name)
            if profile and profile:FindFirstChild('Level') then
                level = profile.Level.Value
            end
        end
    end)
    return level
end

-- Start dungeon/tower
local function StartRaid(raidId)
    pcall(function()
        if ReplicatedStorage and ReplicatedStorage:FindFirstChild('Shared') then
            local teleport = ReplicatedStorage.Shared:FindFirstChild('Teleport')
            if teleport and teleport:FindFirstChild('StartRaid') then
                teleport.StartRaid:FireServer(raidId, 1)
                print('[AutoStart] Started raid ID:', raidId)
            else
                warn('[AutoStart] StartRaid remote not found')
            end
        end
    end)
end

-- Auto select dungeon by level
local function AutoSelectDungeon(level)
    local id
    if level >= 90 then id = 26
    elseif level >= 75 then id = 25
    elseif level >= 60 then id = 24
    elseif level >= 55 then id = 18
    elseif level >= 50 then id = 19
    elseif level >= 45 then id = 20
    elseif level >= 40 then id = 16
    elseif level >= 35 then id = 15
    elseif level >= 30 then id = 14
    elseif level >= 26 then id = 7
    elseif level >= 22 then id = 13
    elseif level >= 18 then id = 12
    elseif level >= 15 then id = 11
    elseif level >= 12 then id = 6
    elseif level >= 10 then id = 4
    elseif level >= 7 then id = 2
    elseif level >= 4 then id = 3
    else id = 1
    end
    return id
end

-- Auto select tower by level
local function AutoSelectTower(level)
    local id
    if level >= 90 then id = 27
    elseif level >= 70 then id = 23
    elseif level >= 60 then id = 21
    else id = 21  -- Default to lowest tower
    end
    return id
end

-- Main start function
local function StartDungeonOrTower()
    if not _genv.AutoStartEnabled then return end
    
    local level = GetPlayerLevel()
    if level == 0 then
        warn('[AutoStart] Could not get player level')
        return
    end
    
    local raidId
    if _genv.AutoStartCustomId then
        -- Use custom ID if specified
        raidId = _genv.AutoStartCustomId
    else
        -- Auto-select based on mode and level
        if _genv.AutoStartMode == 'Tower' then
            raidId = AutoSelectTower(level)
        else
            raidId = AutoSelectDungeon(level)
        end
    end
    
    if raidId then
        StartRaid(raidId)
    end
end

-- API for control
local AutoStartAPI = {}

function AutoStartAPI.enable()
    _genv.AutoStartEnabled = true
end

function AutoStartAPI.disable()
    _genv.AutoStartEnabled = false
end

function AutoStartAPI.toggle()
    _genv.AutoStartEnabled = not _genv.AutoStartEnabled
end

function AutoStartAPI.setMode(mode)
    if mode == 'Dungeon' or mode == 'Tower' then
        _genv.AutoStartMode = mode
    end
end

function AutoStartAPI.setCustomId(id)
    _genv.AutoStartCustomId = id
end

function AutoStartAPI.startNow()
    StartDungeonOrTower()
end

_G.AutoStartAPI = AutoStartAPI

-- Create GUI
local function createGUI()
    local playerGui = plr:FindFirstChild('PlayerGui')
    if not playerGui then return end
    
    -- Create ScreenGui
    local screenGui = Instance.new('ScreenGui')
    screenGui.Name = 'AutoStartGui'
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Create main frame
    local mainFrame = Instance.new('Frame')
    mainFrame.Name = 'MainFrame'
    mainFrame.Size = UDim2.new(0, 200, 0, 180)
    mainFrame.Position = UDim2.new(0, 10, 0, 320)
    mainFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    mainFrame.BorderSizePixel = 1
    mainFrame.BorderColor3 = Color3.new(0.4, 0.4, 0.4)
    mainFrame.Parent = screenGui
    
    -- Create title
    local titleLabel = Instance.new('TextLabel')
    titleLabel.Name = 'Title'
    titleLabel.Size = UDim2.new(1, 0, 0, 30)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundColor3 = Color3.new(0.08, 0.08, 0.08)
    titleLabel.BorderSizePixel = 0
    titleLabel.TextColor3 = Color3.new(1, 0.5, 0)
    titleLabel.TextSize = 14
    titleLabel.Text = 'Auto Start'
    titleLabel.Parent = mainFrame
    
    -- Create mode toggle button
    local modeButton = Instance.new('TextButton')
    modeButton.Name = 'ModeButton'
    modeButton.Size = UDim2.new(1, -10, 0, 30)
    modeButton.Position = UDim2.new(0, 5, 0, 35)
    modeButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.5)
    modeButton.BorderSizePixel = 1
    modeButton.BorderColor3 = Color3.new(0.4, 0.4, 0.4)
    modeButton.TextColor3 = Color3.new(1, 1, 1)
    modeButton.TextSize = 12
    modeButton.Text = 'Mode: Dungeon'
    modeButton.Parent = mainFrame
    
    -- Create start button
    local startButton = Instance.new('TextButton')
    startButton.Name = 'StartButton'
    startButton.Size = UDim2.new(1, -10, 0, 35)
    startButton.Position = UDim2.new(0, 5, 0, 70)
    startButton.BackgroundColor3 = Color3.new(0, 0.6, 0)
    startButton.BorderSizePixel = 1
    startButton.BorderColor3 = Color3.new(0.4, 0.4, 0.4)
    startButton.TextColor3 = Color3.new(1, 1, 1)
    startButton.TextSize = 12
    startButton.Text = 'Start Now'
    startButton.Parent = mainFrame
    
    -- Create toggle auto button
    local toggleButton = Instance.new('TextButton')
    toggleButton.Name = 'ToggleButton'
    toggleButton.Size = UDim2.new(1, -10, 0, 35)
    toggleButton.Position = UDim2.new(0, 5, 0, 110)
    toggleButton.BackgroundColor3 = Color3.new(0.6, 0, 0)
    toggleButton.BorderSizePixel = 1
    toggleButton.BorderColor3 = Color3.new(0.4, 0.4, 0.4)
    toggleButton.TextColor3 = Color3.new(1, 1, 1)
    toggleButton.TextSize = 12
    toggleButton.Text = 'Auto: Disabled'
    toggleButton.Parent = mainFrame
    
    -- Create status label
    local statusLabel = Instance.new('TextLabel')
    statusLabel.Name = 'Status'
    statusLabel.Size = UDim2.new(1, -10, 0, 25)
    statusLabel.Position = UDim2.new(0, 5, 0, 150)
    statusLabel.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
    statusLabel.BorderSizePixel = 1
    statusLabel.BorderColor3 = Color3.new(0.3, 0.3, 0.3)
    statusLabel.TextColor3 = Color3.new(1, 1, 0)
    statusLabel.TextSize = 10
    statusLabel.Text = 'Level: 0'
    statusLabel.Parent = mainFrame
    
    -- Mode button click handler
    modeButton.MouseButton1Click:Connect(function()
        if _genv.AutoStartMode == 'Dungeon' then
            AutoStartAPI.setMode('Tower')
            modeButton.Text = 'Mode: Tower'
            modeButton.BackgroundColor3 = Color3.new(0.5, 0.2, 0.2)
        else
            AutoStartAPI.setMode('Dungeon')
            modeButton.Text = 'Mode: Dungeon'
            modeButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.5)
        end
    end)
    
    -- Start button click handler
    startButton.MouseButton1Click:Connect(function()
        AutoStartAPI.startNow()
        startButton.BackgroundColor3 = Color3.new(0, 0.8, 0)
        task.wait(0.3)
        startButton.BackgroundColor3 = Color3.new(0, 0.6, 0)
    end)
    
    -- Toggle button click handler
    toggleButton.MouseButton1Click:Connect(function()
        AutoStartAPI.toggle()
        if _genv.AutoStartEnabled then
            toggleButton.Text = 'Auto: Enabled'
            toggleButton.BackgroundColor3 = Color3.new(0, 0.6, 0)
            titleLabel.TextColor3 = Color3.new(0, 1, 0)
        else
            toggleButton.Text = 'Auto: Disabled'
            toggleButton.BackgroundColor3 = Color3.new(0.6, 0, 0)
            titleLabel.TextColor3 = Color3.new(1, 0.5, 0)
        end
    end)
    
    -- Update status periodically
    spawn(function()
        while true do
            task.wait(1)
            local level = GetPlayerLevel()
            statusLabel.Text = 'Level: ' .. level
        end
    end)
end

-- GUI creation disabled - now integrated into Main.lua tabbed interface
-- spawn(function()
--     task.wait(1)
--     pcall(createGUI)
-- end)

return AutoStartAPI
