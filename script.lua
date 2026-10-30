--====================================================
-- ZYURA FPS OPTIMIZATION V3.3
-- Client-side visual optimization
--
-- FIXES:
-- 1. Show FPS uses a SEPARATE floating ScreenGui.
-- 2. Gray Sky is optional and applied only while Boost is ON.
-- 3. Gray Sky removes the current Sky/Atmosphere temporarily
--    and applies a dense neutral-gray Atmosphere.
-- 4. ULTRA reduces excessive lighting brightness/exposure.
-- 5. Stop Boost restores saved visual properties.
--
-- Note: Roblox/executor restrictions and each experience's
-- custom lighting can affect the final result.
--====================================================

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

--====================================================
-- GUI PARENT
--====================================================

local guiParent

pcall(function()
    if typeof(gethui) == "function" then
        guiParent = gethui()
    end
end)

if not guiParent then
    guiParent = player:WaitForChild("PlayerGui")
end

local function removeOldGui(name)
    pcall(function()
        local old = guiParent:FindFirstChild(name)
        if old then
            old:Destroy()
        end
    end)
end

removeOldGui("ZyuraFPS_V32")
removeOldGui("ZyuraFPS_Monitor")

--====================================================
-- STATE
--====================================================

local boostEnabled = false
local showFPS = false
local graySkyEnabled = false
local selectedPreset = "MEDIUM"

local savedProperties = {}
local graySavedProperties = {}
local boostConnections = {}

local fpsConnection
local fpsMonitor
local fpsLabel
local grayAtmosphere

local graphicsSettings
local originalQuality

--====================================================
-- PROPERTY SAVE / RESTORE
--====================================================

local function saveAndSet(store, object, property, newValue)
    if not store[object] then
        store[object] = {}
    end

    if store[object][property] == nil then
        local success, oldValue = pcall(function()
            return object[property]
        end)

        if success then
            store[object][property] = oldValue
        end
    end

    pcall(function()
        object[property] = newValue
    end)
end

local function restoreStore(store)
    -- Restore normal properties first.
    for object, properties in pairs(store) do
        if object then
            for property, oldValue in pairs(properties) do
                if property ~= "Parent" then
                    pcall(function()
                        object[property] = oldValue
                    end)
                end
            end
        end
    end

    -- Restore original parents last.
    for object, properties in pairs(store) do
        if object and properties.Parent ~= nil then
            pcall(function()
                object.Parent = properties.Parent
            end)
        end
    end

    table.clear(store)
end

--====================================================
-- MAIN GUI
--====================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZyuraFPS_V32"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = guiParent

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(320, 365)
main.Position = UDim2.new(0.5, -160, 0.5, -182)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
main.BorderSizePixel = 0
main.Active = true
main.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = main

local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(255, 40, 180)
outline.Thickness = 2
outline.Parent = main

local function createLabel(text, position, size, textSize, color)
    local label = Instance.new("TextLabel")
    label.Size = size
    label.Position = position
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.TextSize = textSize or 14
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = main
    return label
end

local function createButton(text, position, size, color)
    local button = Instance.new("TextButton")
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = color
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 13
    button.Font = Enum.Font.GothamBold
    button.AutoButtonColor = true
    button.Parent = main

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button

    return button
end

createLabel(
    "Zyura Fps Optimization V3.2",
    UDim2.fromOffset(15, 8),
    UDim2.new(1, -30, 0, 32),
    17
)

local divider = Instance.new("Frame")
divider.Position = UDim2.fromOffset(12, 45)
divider.Size = UDim2.new(1, -24, 0, 1)
divider.BackgroundColor3 = Color3.fromRGB(255, 40, 180)
divider.BorderSizePixel = 0
divider.Parent = main

--====================================================
-- DRAG SUPPORT
--====================================================

local dragging = false
local dragStart
local startPosition
local dragInput

main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

main.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart

        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

--====================================================
-- SEPARATE FPS MONITOR GUI
-- This is NOT inside the main optimization window.
--====================================================

local function createFPSMonitor()
    if fpsMonitor then
        fpsMonitor:Destroy()
    end

    fpsMonitor = Instance.new("ScreenGui")
    fpsMonitor.Name = "ZyuraFPS_Monitor"
    fpsMonitor.ResetOnSpawn = false
    fpsMonitor.DisplayOrder = 100
    fpsMonitor.Parent = guiParent

    local panel = Instance.new("Frame")
    panel.Name = "FPSPanel"
    panel.Size = UDim2.fromOffset(125, 42)
    panel.Position = UDim2.new(1, -145, 0, 25)
    panel.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    panel.BackgroundTransparency = 0.12
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.Parent = fpsMonitor

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = panel

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 40, 180)
    stroke.Thickness = 1.5
    stroke.Parent = panel

    fpsLabel = Instance.new("TextLabel")
    fpsLabel.Name = "FPSValue"
    fpsLabel.Size = UDim2.fromScale(1, 1)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.Text = "FPS : --"
    fpsLabel.TextColor3 = Color3.fromRGB(75, 255, 125)
    fpsLabel.TextSize = 17
    fpsLabel.Font = Enum.Font.GothamBold
    fpsLabel.Parent = panel

    -- The small FPS panel can also be dragged.
    local monitorDragging = false
    local monitorStart
    local monitorPosition
    local monitorInput

    panel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            monitorDragging = true
            monitorStart = input.Position
            monitorPosition = panel.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    monitorDragging = false
                end
            end)
        end
    end)

    panel.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            monitorInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if monitorDragging and input == monitorInput then
            local delta = input.Position - monitorStart

            panel.Position = UDim2.new(
                monitorPosition.X.Scale,
                monitorPosition.X.Offset + delta.X,
                monitorPosition.Y.Scale,
                monitorPosition.Y.Offset + delta.Y
            )
        end
    end)
end

createFPSMonitor()
fpsMonitor.Enabled = false

local frameCount = 0
local elapsedTime = 0

fpsConnection = RunService.RenderStepped:Connect(function(deltaTime)
    frameCount = frameCount + 1
    elapsedTime = elapsedTime + deltaTime

    if elapsedTime >= 0.25 then
        local fps = math.floor((frameCount / elapsedTime) + 0.5)

        if fpsLabel then
            fpsLabel.Text = "FPS : " .. tostring(fps)
        end

        frameCount = 0
        elapsedTime = 0
    end
end)

--====================================================
-- CHECKBOXES
--====================================================

createLabel(
    "VISUAL OPTIONS",
    UDim2.fromOffset(15, 53),
    UDim2.new(1, -30, 0, 20),
    13,
    Color3.fromRGB(255, 90, 200)
)

local function createCheckbox(text, position, callback)
    local button = createButton(
        "[  ] " .. text,
        position,
        UDim2.fromOffset(140, 30),
        Color3.fromRGB(25, 25, 32)
    )

    local enabled = false

    local function updateVisual()
        button.Text = enabled and ("[ ✓ ] " .. text) or ("[  ] " .. text)
        button.TextColor3 = enabled
            and Color3.fromRGB(255, 85, 195)
            or Color3.fromRGB(235, 235, 235)
    end

    button.MouseButton1Click:Connect(function()
        enabled = not enabled
        updateVisual()
        callback(enabled)
    end)

    updateVisual()
    return button
end

local applyGraySky
local restoreGraySky

createCheckbox(
    "Show FPS",
    UDim2.fromOffset(15, 78),
    function(value)
        showFPS = value
        if fpsMonitor then
            fpsMonitor.Enabled = value
        end
    end
)

createCheckbox(
    "Gray Sky",
    UDim2.fromOffset(165, 78),
    function(value)
        graySkyEnabled = value

        if boostEnabled then
            if value then
                applyGraySky()
            else
                restoreGraySky()
            end
        end
    end
)

--====================================================
-- BOOST PRESETS
--====================================================

createLabel(
    "BOOST PRESET",
    UDim2.fromOffset(15, 117),
    UDim2.new(1, -30, 0, 20),
    13,
    Color3.fromRGB(255, 90, 200)
)

local presetButtons = {}

local function selectPreset(name)
    selectedPreset = name

    for presetName, button in pairs(presetButtons) do
        button.BackgroundColor3 = presetName == name
            and Color3.fromRGB(145, 30, 115)
            or Color3.fromRGB(28, 28, 35)
    end
end

for index, name in ipairs({"LOW", "MEDIUM", "ULTRA"}) do
    local button = createButton(
        name,
        UDim2.fromOffset(15 + ((index - 1) * 100), 144),
        UDim2.fromOffset(90, 32),
        Color3.fromRGB(28, 28, 35)
    )

    presetButtons[name] = button

    button.MouseButton1Click:Connect(function()
        if not boostEnabled then
            selectPreset(name)
        end
    end)
end

selectPreset("MEDIUM")

--====================================================
-- GRAY SKY V3.3
-- Target: neutral flat gray sky with a soft hazy horizon.
-- Existing Sky/Atmosphere instances are temporarily
-- detached and restored when Gray Sky is disabled.
-- If the experience continually overrides Lighting,
-- the client may still be unable to hold this appearance.
--====================================================

local graySkyChildAddedConnection
local graySkybox

local GRAY_SKY_ASSET = "rbxassetid://105610723516517"

local function detachSkyObject(object)
    if object == grayAtmosphere then
        return
    end

    if object:IsA("Sky") or object:IsA("Atmosphere") then
        saveAndSet(graySavedProperties, object, "Parent", nil)
    end
end

applyGraySky = function()
    if not boostEnabled or not graySkyEnabled then
        return
    end

    saveAndSet(
        graySavedProperties, Lighting, "Ambient",
        Color3.fromRGB(125, 125, 125)
    )

    saveAndSet(
        graySavedProperties, Lighting, "OutdoorAmbient",
        Color3.fromRGB(125, 125, 125)
    )

    saveAndSet(
        graySavedProperties, Lighting, "ColorShift_Top",
        Color3.fromRGB(128, 128, 128)
    )

    saveAndSet(
        graySavedProperties, Lighting, "ColorShift_Bottom",
        Color3.fromRGB(128, 128, 128)
    )

    -- Keep the scene readable; avoid making the whole map dark.
    saveAndSet(graySavedProperties, Lighting, "Brightness", 2)
    saveAndSet(graySavedProperties, Lighting, "ExposureCompensation", 0)

    -- Detach existing sky/atmosphere objects so the Zyura sky is visible.
    for _, object in ipairs(Lighting:GetChildren()) do
        detachSkyObject(object)
    end

    -- Apply the uploaded flat-gray image to all six Skybox faces.
    if not graySkybox or not graySkybox.Parent then
        graySkybox = Instance.new("Sky")
        graySkybox.Name = "ZyuraGraySkybox"
        graySkybox.SkyboxBk = GRAY_SKY_ASSET
        graySkybox.SkyboxDn = GRAY_SKY_ASSET
        graySkybox.SkyboxFt = GRAY_SKY_ASSET
        graySkybox.SkyboxLf = GRAY_SKY_ASSET
        graySkybox.SkyboxRt = GRAY_SKY_ASSET
        graySkybox.SkyboxUp = GRAY_SKY_ASSET
        graySkybox.CelestialBodiesShown = false
        graySkybox.StarCount = 0
        graySkybox.SunAngularSize = 0
        graySkybox.MoonAngularSize = 0
        graySkybox.Parent = Lighting
    end

    -- Some experiences recreate their sky at runtime.
    if not graySkyChildAddedConnection then
        graySkyChildAddedConnection = Lighting.ChildAdded:Connect(function(object)
            if object == graySkybox or object == grayAtmosphere then
                return
            end
            if boostEnabled and graySkyEnabled then
                task.defer(function()
                    if boostEnabled and graySkyEnabled and object.Parent == Lighting then
                        detachSkyObject(object)
                    end
                end)
            end
        end)
    end

    if not grayAtmosphere or not grayAtmosphere.Parent then
        grayAtmosphere = Instance.new("Atmosphere")
        grayAtmosphere.Name = "ZyuraGrayAtmosphere"
        grayAtmosphere.Color = Color3.fromRGB(142, 142, 142)
        grayAtmosphere.Decay = Color3.fromRGB(128, 128, 128)
        grayAtmosphere.Density = 0.15
        grayAtmosphere.Haze = 1
        grayAtmosphere.Glare = 0
        grayAtmosphere.Parent = Lighting
    end
end

restoreGraySky = function()
    if graySkyChildAddedConnection then
        pcall(function()
            graySkyChildAddedConnection:Disconnect()
        end)
        graySkyChildAddedConnection = nil
    end

    if grayAtmosphere then
        pcall(function()
            grayAtmosphere:Destroy()
        end)
        grayAtmosphere = nil
    end

    if graySkybox then
        pcall(function()
            graySkybox:Destroy()
        end)
        graySkybox = nil
    end

    restoreStore(graySavedProperties)
end

--====================================================
-- VISUAL OPTIMIZATION
--====================================================

local function optimizeObject(object)
    if object:IsA("BasePart") then
        saveAndSet(savedProperties, object, "CastShadow", false)

        if selectedPreset == "MEDIUM" or selectedPreset == "ULTRA" then
            saveAndSet(
                savedProperties, object, "Material",
                Enum.Material.SmoothPlastic
            )
        end

        if selectedPreset == "ULTRA" then
            saveAndSet(savedProperties, object, "Reflectance", 0)
        end
    end

    if object:IsA("ParticleEmitter")
        or object:IsA("Trail")
        or object:IsA("Beam")
        or object:IsA("Fire")
        or object:IsA("Smoke")
        or object:IsA("Sparkles") then

        saveAndSet(savedProperties, object, "Enabled", false)
    end

    if object:IsA("PostEffect") then
        saveAndSet(savedProperties, object, "Enabled", false)
    end

    if selectedPreset == "ULTRA" then
        if object:IsA("Decal") or object:IsA("Texture") then
            saveAndSet(savedProperties, object, "Transparency", 1)
        end
    end
end

--====================================================
-- ROBLOX GRAPHICS QUALITY (BEST EFFORT)
--====================================================

local function setGraphicsLow()
    pcall(function()
        graphicsSettings = UserSettings():GetService("UserGameSettings")
        originalQuality = graphicsSettings.SavedQualityLevel
        graphicsSettings.SavedQualityLevel =
            Enum.SavedQualitySetting.QualityLevel1
    end)
end

local function restoreGraphics()
    if graphicsSettings and originalQuality then
        pcall(function()
            graphicsSettings.SavedQualityLevel = originalQuality
        end)
    end

    graphicsSettings = nil
    originalQuality = nil
end

--====================================================
-- PRESET LIGHTING
-- ULTRA uses restrained lighting values to avoid glare.
--====================================================

local function applyPresetLighting()
    if selectedPreset == "ULTRA" then
        saveAndSet(
            savedProperties, Lighting, "Brightness", 1.5
        )
        saveAndSet(
            savedProperties, Lighting, "ExposureCompensation", -0.2
        )
    elseif selectedPreset == "MEDIUM" then
        saveAndSet(
            savedProperties, Lighting, "Brightness", 2
        )
    end
    -- LOW leaves brightness/exposure unchanged.
end

--====================================================
-- START BOOST
--====================================================

local function startBoost()
    boostEnabled = true

    local success, err = pcall(function()
        setGraphicsLow()

        saveAndSet(
            savedProperties, Lighting, "GlobalShadows", false
        )

        applyPresetLighting()

        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            saveAndSet(
                savedProperties, terrain, "Decoration", false
            )
        end

        for _, object in ipairs(game:GetDescendants()) do
            optimizeObject(object)
        end

        boostConnections.DescendantAdded =
            game.DescendantAdded:Connect(function(object)
                if boostEnabled then
                    optimizeObject(object)
                end
            end)

        if graySkyEnabled then
            applyGraySky()
        end
    end)

    if not success then
        warn("[ZYURA FPS] Boost error: " .. tostring(err))
        boostEnabled = false

        restoreGraySky()
        restoreStore(savedProperties)
        restoreGraphics()
    end

    return success
end

--====================================
- STOP BOOST
--====================================================

local function stopBoost()
    boostEnabled = false

    for _, connection in pairs(boostConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(boostConnections)

    restoreGraySky()
    restoreStore(savedProperties)
    restoreGraphics()
end

--====================================================
-- START / STOP BUTTON
--====================================================

local boostButton = createButton(
    "START BOOST",
    UDim2.fromOffset(15, 195),
    UDim2.new(1, -30, 0, 43),
    Color3.fromRGB(20, 155, 65)
)

local statusLabel = createLabel(
    "STATUS : OPTIMIZATION OFF",
    UDim2.fromOffset(15, 248),
    UDim2.new(1, -30, 0, 22),
    12,
    Color3.fromRGB(175, 175, 175)
)

boostButton.MouseButton1Click:Connect(function()
    if not boostEnabled then
        local success = startBoost()

        if success then
            boostButton.Text = "STOP BOOST"
            boostButton.BackgroundColor3 = Color3.fromRGB(190, 35, 55)
            statusLabel.Text = "STATUS : BOOST ACTIVE"
            statusLabel.TextColor3 = Color3.fromRGB(60, 255, 110)
        else
            boostButton.Text = "START BOOST"
            boostButton.BackgroundColor3 = Color3.fromRGB(20, 155, 65)
            statusLabel.Text = "STATUS : BOOST ERROR"
            statusLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
        end
    else
        stopBoost()

        boostButton.Text = "START BOOST"
        boostButton.BackgroundColor3 = Color3.fromRGB(20, 155, 65)
        statusLabel.Text = "STATUS : OPTIMIZATION OFF"
        statusLabel.TextColor3 = Color3.fromRGB(175, 175, 175)
    end
end)

--====================================================
-- CLEANUP
--====================================================

screenGui.Destroying:Connect(function()
    if boostEnabled then
        stopBoost()
    end

    if fpsConnection then
        fpsConnection:Disconnect()
        fpsConnection = nil
    end

    if fpsMonitor then
        fpsMonitor:Destroy()
        fpsMonitor = nil
    end
end)

print("[ZYURA FPS V3.3] Loaded successfully!")
