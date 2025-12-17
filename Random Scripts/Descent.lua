while true do
    local folder = game.Workspace:FindFirstChild("ItemDrops")
    if folder then
        for _, object in ipairs(folder:GetChildren()) do
            if object:IsA("Model") then
                -- Only add a Highlight if it doesn't already exist
                if not object:FindFirstChildOfClass("Highlight") then
                    local highlight = Instance.new("Highlight")
                    highlight.Parent = object
                end
            end
        end
    end

    -- FullBright Script for Player View
    local Lighting = game:GetService("Lighting")

    local function enableFullBright()
        Lighting.Brightness = 2
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.new(1, 1, 1) -- pure white ambient light
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)

        -- Remove Atmosphere and Sky if they exist
        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmosphere then
            atmosphere:Destroy()
        end

        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky then
            sky:Destroy()
        end
    end

    -- Run once at start
    enableFullBright()

    -- Wait 10 seconds before running again
    task.wait(10)
end