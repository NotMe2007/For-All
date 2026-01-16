-- pet sim 99 secret presont colector
--// Loop through all HolidayEventHiddenPresents and click them safely

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")

-- Get all presents
local container = workspace.__THINGS.HolidayEventHiddenPresents
local presents = container:GetChildren()

-- Add the special "Present" if it exists
local special = container:FindFirstChild("Present")
if special then
    table.insert(presents, 1, special)
end

-- Function to teleport and click
local function tpAndClick(present)
    local clickDetector = present:FindFirstChild("ClickDetector")
    local targetCFrame = present:IsA("Model") and present:FindFirstChildWhichIsA("BasePart") and present:FindFirstChildWhichIsA("BasePart").CFrame
        or present:IsA("BasePart") and present.CFrame

    if clickDetector and targetCFrame then
        root.CFrame = targetCFrame + Vector3.new(0, 5, 0)
        wait(0.5)
        fireclickdetector(clickDetector)
    else
        warn("Skipping invalid present:", present.Name)
    end
end

-- Loop through all presents
for i, present in ipairs(presents) do
    tpAndClick(present)
    wait(1) -- delay between each click i dont know how to do clicks good luck
end
