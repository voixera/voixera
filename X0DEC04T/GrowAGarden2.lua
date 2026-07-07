local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/FrostyLabs1/WindUI/main/dist/wind.min.lua"))()

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    Workspace = game:GetService("Workspace"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    ReplicatedFirst = game:GetService("ReplicatedFirst"),
    Lighting = game:GetService("Lighting"),
    TweenService = game:GetService("TweenService"),
    UserInputService = game:GetService("UserInputService"),
    VirtualUser = game:GetService("VirtualUser"),
    TeleportService = game:GetService("TeleportService"),
    HttpService = game:GetService("HttpService"),
    CoreGui = game:GetService("CoreGui"),
    StarterGui = game:GetService("StarterGui")
}

local LocalPlayer = Services.Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

local ScriptData = {
    Connections = {},
    Loops = {},
    ESPObjects = {},
    MinimizeButton = nil,
    UIVisible = true,
    OriginalValues = {
        WalkSpeed = 16,
        JumpPower = 50,
        Gravity = 196.2,
        Brightness = Services.Lighting.Brightness,
        ClockTime = Services.Lighting.ClockTime,
        FogEnd = Services.Lighting.FogEnd,
        GlobalShadows = Services.Lighting.GlobalShadows
    },
    Config = {
        Main = {
            AutoHarvest = true,
            AutoPlant = true,
            AutoWater = true,
            AutoSell = true,
            AutoBuySeeds = true,
            AutoBuyGear = true,
            AutoCollectDrops = true,
            AutoQuest = false,
            AutoUpgrade = false,
            AutoRebirth = false,
            AutoClaimRewards = false,
            AutoEvent = false,
            AutoGift = false,
            AutoFertilize = false,
            SelectedSeed = "Carrot",
            SelectedGear = "Basic Watering Can"
        },
        Player = {
            WalkSpeed = 16,
            JumpPower = 50,
            Gravity = 196.2,
            Fly = false,
            FlySpeed = 50,
            NoClip = false,
            InfiniteJump = false,
            AntiAFK = false,
            Spinbot = false,
            SpinbotSpeed = 10
        },
        Visual = {
            PlayerESP = true,
            SeedESP = false,
            FruitESP = true,
            ItemESP = false,
            NPCESP = true,
            ChestESP = false,
            Tracers = false,
            Highlight = false,
            Fullbright = false
        },
        Settings = {
            AutoSave = false,
            Watermark = true,
            UIScale = 1,
            Transparency = 0
        }
    }
}

local GameCache = {
    Garden = nil,
    Shop = nil,
    NPCs = {},
    Events = {},
    Spawn = nil,
    Seeds = {},
    Gear = {},
    Plants = {},
    Drops = {},
    Remotes = {},
    PlayerList = {},
    Plots = {},
    SeedShop = nil,
    SellArea = nil
}

local function AddConnection(name, connection)
    if ScriptData.Connections[name] then
        pcall(function() ScriptData.Connections[name]:Disconnect() end)
    end
    ScriptData.Connections[name] = connection
end

local function RemoveConnection(name)
    if ScriptData.Connections[name] then
        pcall(function() ScriptData.Connections[name]:Disconnect() end)
        ScriptData.Connections[name] = nil
    end
end

local function CreateLoop(name, func, wait_time)
    if ScriptData.Loops[name] then
        ScriptData.Loops[name] = false
        task.wait(0.1)
    end
    ScriptData.Loops[name] = true
    task.spawn(function()
        while ScriptData.Loops[name] do
            local success, err = pcall(func)
            if not success then
                warn("Loop Error [" .. name .. "]:", err)
            end
            task.wait(wait_time or 0.1)
        end
    end)
end

local function StopLoop(name)
    ScriptData.Loops[name] = false
end

local function GetCharacter()
    return LocalPlayer.Character
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart()
    local char = GetCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function FindFirstDescendant(parent, name, className)
    if not parent then return nil end
    for _, descendant in ipairs(parent:GetDescendants()) do
        local nameMatch = not name or descendant.Name:lower():find(name:lower())
        local classMatch = not className or descendant:IsA(className)
        if nameMatch and classMatch then
            return descendant
        end
    end
    return nil
end

local function FindAllDescendants(parent, name, className)
    local results = {}
    if not parent then return results end
    for _, descendant in ipairs(parent:GetDescendants()) do
        local nameMatch = not name or descendant.Name:lower():find(name:lower())
        local classMatch = not className or descendant:IsA(className)
        if nameMatch and classMatch then
            table.insert(results, descendant)
        end
    end
    return results
end

local function GetRemote(name, className)
    if GameCache.Remotes[name] then
        return GameCache.Remotes[name]
    end
    
    local remote = FindFirstDescendant(Services.ReplicatedStorage, name, className)
    if not remote then
        remote = FindFirstDescendant(workspace, name, className)
    end
    
    if remote then
        GameCache.Remotes[name] = remote
    end
    
    return remote
end

local function FireRemote(remoteName, ...)
    local remote = GetRemote(remoteName, "RemoteEvent") or GetRemote(remoteName, "RemoteFunction")
    if remote then
        pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer(...)
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(...)
            end
        end)
        return true
    end
    return false
end

local function TweenToPosition(position, speed)
    local root = GetRootPart()
    if not root then return end
    
    local distance = (root.Position - position).Magnitude
    local duration = distance / (speed or 100)
    
    local tween = Services.TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(position)})
    tween:Play()
    return tween
end

local function TeleportTo(position)
    local root = GetRootPart()
    if root then
        root.CFrame = CFrame.new(position)
    end
end

local function FindPlayerPlots()
    local plots = {}
    local possibleParents = {
        workspace:FindFirstChild("PlayerPlots"),
        workspace:FindFirstChild("Plots"),
        workspace:FindFirstChild("Gardens"),
        workspace:FindFirstChild(LocalPlayer.Name)
    }
    
    for _, parent in ipairs(possibleParents) do
        if parent then
            for _, obj in ipairs(parent:GetDescendants()) do
                if obj:IsA("Model") and (obj.Name:lower():find("plot") or obj:FindFirstChild("Soil") or obj:FindFirstChild("Plant")) then
                    table.insert(plots, obj)
                end
            end
        end
    end
    
    return plots
end

local function FindPlants()
    local plants = {}
    local plots = FindPlayerPlots()
    
    for _, plot in ipairs(plots) do
        for _, obj in ipairs(plot:GetDescendants()) do
            if obj:IsA("Model") and obj.Name:lower():find("plant") then
                table.insert(plants, obj)
            end
        end
    end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("plant") and obj:FindFirstChild("Stem") then
            table.insert(plants, obj)
        end
    end
    
    return plants
end

local function UpdateGameCache()
    task.spawn(function()
        GameCache.Garden = workspace:FindFirstChild("Garden") or 
                          workspace:FindFirstChild("PlayerGarden") or 
                          workspace:FindFirstChild("PlayerPlots") or
                          workspace:FindFirstChild(LocalPlayer.Name)
        
        GameCache.Shop = workspace:FindFirstChild("Shop") or 
                        workspace:FindFirstChild("Store") or 
                        FindFirstDescendant(workspace, "shop", "Model")
        
        GameCache.SeedShop = workspace:FindFirstChild("SeedShop") or 
                            FindFirstDescendant(workspace, "seed", "Model")
        
        GameCache.SellArea = workspace:FindFirstChild("SellArea") or 
                            workspace:FindFirstChild("Sell") or
                            FindFirstDescendant(workspace, "sell", "Model")
        
        GameCache.Spawn = workspace:FindFirstChild("SpawnLocation") or 
                         workspace:FindFirstChild("Spawn")
        
        GameCache.Plots = FindPlayerPlots()
        GameCache.Plants = FindPlants()
        
        GameCache.NPCs = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and obj.Name:lower():find("npc") then
                table.insert(GameCache.NPCs, obj)
            end
        end
        
        GameCache.Drops = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name:lower():find("drop") or obj.Name:lower():find("coin") or obj.Name:lower():find("money")) then
                table.insert(GameCache.Drops, obj)
            end
        end
    end)
end

local function CreateESP(object, text, color)
    if not object or not object:IsA("BasePart") and not object:IsA("Model") then return end
    
    local key = tostring(object)
    if ScriptData.ESPObjects[key] then return end
    
    local targetPart = object
    if object:IsA("Model") then
        targetPart = object:FindFirstChild("HumanoidRootPart") or 
                    object:FindFirstChild("Head") or 
                    object:FindFirstChildWhichIsA("BasePart")
    end
    
    if not targetPart then return end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_" .. text
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Parent = targetPart
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = billboard
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Text = text or object.Name
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = frame
    
    ScriptData.ESPObjects[key] = billboard
    
    if targetPart:IsA("BasePart") then
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Highlight"
        highlight.FillColor = color or Color3.fromRGB(255, 255, 255)
        highlight.OutlineColor = color or Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Parent = object
        ScriptData.ESPObjects[key .. "_highlight"] = highlight
    end
    
    return billboard
end

local function RemoveESP(object)
    local key = tostring(object)
    if ScriptData.ESPObjects[key] then
        pcall(function() ScriptData.ESPObjects[key]:Destroy() end)
        ScriptData.ESPObjects[key] = nil
    end
    if ScriptData.ESPObjects[key .. "_highlight"] then
        pcall(function() ScriptData.ESPObjects[key .. "_highlight"]:Destroy() end)
        ScriptData.ESPObjects[key .. "_highlight"] = nil
    end
end

local function ClearAllESP()
    for _, esp in pairs(ScriptData.ESPObjects) do
        pcall(function() esp:Destroy() end)
    end
    ScriptData.ESPObjects = {}
end

local function SaveConfig(profileName)
    profileName = profileName or "default"
    local fileName = "X0DEC04T_GrowAGarden2_" .. profileName .. ".json"
    
    local success, result = pcall(function()
        return Services.HttpService:JSONEncode(ScriptData.Config)
    end)
    
    if success and writefile then
        writefile(fileName, result)
        return true
    end
    return false
end

local function LoadConfig(profileName)
    profileName = profileName or "default"
    local fileName = "X0DEC04T_GrowAGarden2_" .. profileName .. ".json"
    
    if isfile and isfile(fileName) and readfile then
        local success, result = pcall(function()
            return Services.HttpService:JSONDecode(readfile(fileName))
        end)
        
        if success and result then
            for category, settings in pairs(result) do
                if ScriptData.Config[category] then
                    for setting, value in pairs(settings) do
                        ScriptData.Config[category][setting] = value
                    end
                end
            end
            return true
        end
    end
    return false
end

local function Notify(title, message, duration, type_str)
    pcall(function()
        WindUI:Notify({
            Title = title,
            Content = message,
            Duration = duration or 3
        })
    end)
end

local function CreateMinimizeButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "X0DEC04T_MinimizeButton"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    if gethui then
        screenGui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(screenGui)
        screenGui.Parent = Services.CoreGui
    else
        screenGui.Parent = Services.CoreGui
    end
    
    local button = Instance.new("TextButton")
    button.Name = "MinimizeButton"
    button.Size = UDim2.new(0, 60, 0, 60)
    button.Position = UDim2.new(1, -80, 0, 20)
    button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    button.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = button
    
    local logo = Instance.new("TextLabel")
    logo.Size = UDim2.new(1, 0, 1, 0)
    logo.BackgroundTransparency = 1
    logo.Text = "X0D"
    logo.TextColor3 = Color3.fromRGB(255, 255, 255)
    logo.TextScaled = true
    logo.Font = Enum.Font.GothamBold
    logo.Parent = button
    
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(138, 43, 226)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(75, 0, 130))
    }
    gradient.Rotation = 45
    gradient.Parent = button
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(138, 43, 226)
    stroke.Thickness = 2
    stroke.Parent = button
    
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://6014261993"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.5
    shadow.ZIndex = -1
    shadow.Parent = button
    
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = button.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                local delta = input.Position - dragStart
                button.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end
    end)
    
    button.MouseButton1Click:Connect(function()
        if not dragging then
            ScriptData.UIVisible = not ScriptData.UIVisible
            
            if Window and Window.Root then
                Window.Root.Visible = ScriptData.UIVisible
            end
            
            local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local tween = Services.TweenService:Create(button, tweenInfo, {
                Rotation = ScriptData.UIVisible and 0 or 180
            })
            tween:Play()
        end
    end)
    
    button.MouseEnter:Connect(function()
        local tween = Services.TweenService:Create(button, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 70, 0, 70)
        })
        tween:Play()
    end)
    
    button.MouseLeave:Connect(function()
        local tween = Services.TweenService:Create(button, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 60, 0, 60)
        })
        tween:Play()
    end)
    
    ScriptData.MinimizeButton = screenGui
    return screenGui
end

UpdateGameCache()

local Window = WindUI:CreateWindow({
    Title = "X0DEC04T Hub",
    Subtitle = "Grow a Garden 2",
    Icon = "rbxassetid://10734950",
    Author = "X0DEC04T",
    Folder = "X0DEC04THub",
    Size = UDim2.fromOffset(580, 460),
    KeySystem = false,
    Transparent = false
})

CreateMinimizeButton()

local MainTab = Window:CreateTab({
    Name = "Main",
    Icon = "rbxassetid://10734950",
    Visible = true
})

local PlayerTab = Window:CreateTab({
    Name = "Player",
    Icon = "rbxassetid://10747372",
    Visible = true
})

local TeleportTab = Window:CreateTab({
    Name = "Teleport",
    Icon = "rbxassetid://10723407",
    Visible = true
})

local VisualTab = Window:CreateTab({
    Name = "Visual",
    Icon = "rbxassetid://10734896",
    Visible = true
})

local MiscTab = Window:CreateTab({
    Name = "Misc",
    Icon = "rbxassetid://10734949",
    Visible = true
})

local SettingsTab = Window:CreateTab({
    Name = "Settings",
    Icon = "rbxassetid://10734952",
    Visible = true
})

local CreditsTab = Window:CreateTab({
    Name = "Credits",
    Icon = "rbxassetid://10747373",
    Visible = true
})

local FarmingSection = MainTab:CreateSection({
    Name = "🌱 Farming Features",
    Side = "Left"
})

FarmingSection:CreateToggle({
    Name = "Auto Harvest",
    Flag = "AutoHarvest",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoHarvest = value
        if value then
            Notify("Auto Harvest", "Enabled", 2, "success")
            CreateLoop("AutoHarvest", function()
                UpdateGameCache()
                local plants = FindPlants()
                
                for _, plant in ipairs(plants) do
                    if plant then
                        local isReady = plant:FindFirstChild("Ready") or plant:FindFirstChild("Harvestable") or plant:FindFirstChild("Grown")
                        
                        if isReady and isReady.Value == true then
                            local clickDetector = FindFirstDescendant(plant, nil, "ClickDetector")
                            if clickDetector then
                                fireclickdetector(clickDetector)
                            end
                            
                            local proximityPrompt = FindFirstDescendant(plant, nil, "ProximityPrompt")
                            if proximityPrompt then
                                fireproximityprompt(proximityPrompt)
                            end
                            
                            FireRemote("HarvestPlant", plant)
                            FireRemote("Harvest", plant)
                            FireRemote("harvest", plant)
                        end
                    end
                end
            end, 0.3)
        else
            Notify("Auto Harvest", "Disabled", 2, "info")
            StopLoop("AutoHarvest")
        end
    end
})

FarmingSection:CreateToggle({
    Name = "Auto Plant",
    Flag = "AutoPlant",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoPlant = value
        if value then
            Notify("Auto Plant", "Enabled", 2, "success")
            CreateLoop("AutoPlant", function()
                UpdateGameCache()
                
                for _, plot in ipairs(GameCache.Plots) do
                    if plot then
                        local isEmpty = plot:FindFirstChild("Empty") or plot:FindFirstChild("Available")
                        local hasPlant = FindFirstDescendant(plot, "plant", "Model")
                        
                        if (isEmpty and isEmpty.Value == true) or (not hasPlant) then
                            local clickDetector = FindFirstDescendant(plot, nil, "ClickDetector")
                            if clickDetector then
                                fireclickdetector(clickDetector)
                            end
                            
                            local proximityPrompt = FindFirstDescendant(plot, nil, "ProximityPrompt")
                            if proximityPrompt then
                                fireproximityprompt(proximityPrompt)
                            end
                            
                            FireRemote("PlantSeed", plot, ScriptData.Config.Main.SelectedSeed)
                            FireRemote("Plant", plot, ScriptData.Config.Main.SelectedSeed)
                            FireRemote("plant", plot)
                        end
                    end
                end
            end, 0.5)
        else
            Notify("Auto Plant", "Disabled", 2, "info")
            StopLoop("AutoPlant")
        end
    end
})

FarmingSection:CreateToggle({
    Name = "Auto Water",
    Flag = "AutoWater",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoWater = value
        if value then
            Notify("Auto Water", "Enabled", 2, "success")
            CreateLoop("AutoWater", function()
                local plants = FindPlants()
                
                for _, plant in ipairs(plants) do
                    if plant then
                        local needsWater = plant:FindFirstChild("NeedsWater") or plant:FindFirstChild("Watered")
                        
                        if (needsWater and needsWater.Value == true) or not needsWater then
                            local clickDetector = FindFirstDescendant(plant, nil, "ClickDetector")
                            if clickDetector then
                                fireclickdetector(clickDetector)
                            end
                            
                            local proximityPrompt = FindFirstDescendant(plant, nil, "ProximityPrompt")
                            if proximityPrompt then
                                fireproximityprompt(proximityPrompt)
                            end
                            
                            FireRemote("WaterPlant", plant)
                            FireRemote("Water", plant)
                            FireRemote("water", plant)
                        end
                    end
                end
            end, 0.5)
        else
            Notify("Auto Water", "Disabled", 2, "info")
            StopLoop("AutoWater")
        end
    end
})

FarmingSection:CreateToggle({
    Name = "Auto Fertilize",
    Flag = "AutoFertilize",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoFertilize = value
        if value then
            Notify("Auto Fertilize", "Enabled", 2, "success")
            CreateLoop("AutoFertilize", function()
                local plants = FindPlants()
                
                for _, plant in ipairs(plants) do
                    if plant then
                        FireRemote("FertilizePlant", plant)
                        FireRemote("Fertilize", plant)
                        FireRemote("fertilize", plant)
                        FireRemote("UseFertilizer", plant)
                    end
                end
            end, 1)
        else
            Notify("Auto Fertilize", "Disabled", 2, "info")
            StopLoop("AutoFertilize")
        end
    end
})

local ShopSection = MainTab:CreateSection({
    Name = "🛒 Shop & Economy",
    Side = "Left"
})

ShopSection:CreateToggle({
    Name = "Auto Sell",
    Flag = "AutoSell",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoSell = value
        if value then
            Notify("Auto Sell", "Enabled", 2, "success")
            CreateLoop("AutoSell", function()
                FireRemote("SellProduce")
                FireRemote("Sell")
                FireRemote("sell")
                FireRemote("SellItems")
                
                if GameCache.SellArea then
                    local root = GetRootPart()
                    if root and GameCache.SellArea:IsA("BasePart") then
                        local oldPos = root.CFrame
                        root.CFrame = GameCache.SellArea.CFrame
                        task.wait(0.2)
                        root.CFrame = oldPos
                    end
                end
            end, 2)
        else
            Notify("Auto Sell", "Disabled", 2, "info")
            StopLoop("AutoSell")
        end
    end
})

ShopSection:CreateToggle({
    Name = "Auto Buy Seeds",
    Flag = "AutoBuySeeds",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoBuySeeds = value
        if value then
            Notify("Auto Buy Seeds", "Enabled", 2, "success")
            CreateLoop("AutoBuySeeds", function()
                FireRemote("BuySeed", ScriptData.Config.Main.SelectedSeed)
                FireRemote("PurchaseSeed", ScriptData.Config.Main.SelectedSeed)
                FireRemote("buy", "seed", ScriptData.Config.Main.SelectedSeed)
            end, 3)
        else
            Notify("Auto Buy Seeds", "Disabled", 2, "info")
            StopLoop("AutoBuySeeds")
        end
    end
})

ShopSection:CreateToggle({
    Name = "Auto Buy Gear",
    Flag = "AutoBuyGear",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoBuyGear = value
        if value then
            Notify("Auto Buy Gear", "Enabled", 2, "success")
            CreateLoop("AutoBuyGear", function()
                FireRemote("BuyGear", ScriptData.Config.Main.SelectedGear)
                FireRemote("PurchaseGear", ScriptData.Config.Main.SelectedGear)
                FireRemote("buy", "gear", ScriptData.Config.Main.SelectedGear)
            end, 3)
        else
            Notify("Auto Buy Gear", "Disabled", 2, "info")
            StopLoop("AutoBuyGear")
        end
    end
})

local AutomationSection = MainTab:CreateSection({
    Name = "⚡ Automation",
    Side = "Right"
})

AutomationSection:CreateToggle({
    Name = "Auto Collect Drops",
    Flag = "AutoCollectDrops",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoCollectDrops = value
        if value then
            Notify("Auto Collect", "Enabled", 2, "success")
            CreateLoop("AutoCollectDrops", function()
                UpdateGameCache()
                local root = GetRootPart()
                
                if root then
                    for _, drop in ipairs(GameCache.Drops) do
                        if drop and drop:IsA("BasePart") and drop.Parent then
                            pcall(function()
                                drop.CFrame = root.CFrame
                            end)
                        end
                    end
                end
            end, 0.1)
        else
            Notify("Auto Collect", "Disabled", 2, "info")
            StopLoop("AutoCollectDrops")
        end
    end
})

AutomationSection:CreateToggle({
    Name = "Auto Quest",
    Flag = "AutoQuest",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoQuest = value
        if value then
            Notify("Auto Quest", "Enabled", 2, "success")
            CreateLoop("AutoQuest", function()
                FireRemote("AcceptQuest")
                FireRemote("Quest")
                FireRemote("quest")
                FireRemote("CompleteQuest")
                FireRemote("TurnInQuest")
            end, 2)
        else
            Notify("Auto Quest", "Disabled", 2, "info")
            StopLoop("AutoQuest")
        end
    end
})

AutomationSection:CreateToggle({
    Name = "Auto Upgrade",
    Flag = "AutoUpgrade",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoUpgrade = value
        if value then
            Notify("Auto Upgrade", "Enabled", 2, "success")
            CreateLoop("AutoUpgrade", function()
                FireRemote("Upgrade")
                FireRemote("upgrade")
                FireRemote("UpgradeTool")
                FireRemote("UpgradePlot")
            end, 3)
        else
            Notify("Auto Upgrade", "Disabled", 2, "info")
            StopLoop("AutoUpgrade")
        end
    end
})

AutomationSection:CreateToggle({
    Name = "Auto Rebirth",
    Flag = "AutoRebirth",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoRebirth = value
        if value then
            Notify("Auto Rebirth", "Enabled", 2, "success")
            CreateLoop("AutoRebirth", function()
                FireRemote("Rebirth")
                FireRemote("rebirth")
                FireRemote("Prestige")
            end, 5)
        else
            Notify("Auto Rebirth", "Disabled", 2, "info")
            StopLoop("AutoRebirth")
        end
    end
})

AutomationSection:CreateToggle({
    Name = "Auto Claim Rewards",
    Flag = "AutoClaimRewards",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoClaimRewards = value
        if value then
            Notify("Auto Claim", "Enabled", 2, "success")
            CreateLoop("AutoClaimRewards", function()
                FireRemote("ClaimReward")
                FireRemote("Claim")
                FireRemote("claim")
                FireRemote("ClaimDaily")
                FireRemote("ClaimAchievement")
            end, 2)
        else
            Notify("Auto Claim", "Disabled", 2, "info")
            StopLoop("AutoClaimRewards")
        end
    end
})

AutomationSection:CreateToggle({
    Name = "Auto Event",
    Flag = "AutoEvent",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoEvent = value
        if value then
            Notify("Auto Event", "Enabled", 2, "success")
            CreateLoop("AutoEvent", function()
                FireRemote("JoinEvent")
                FireRemote("Event")
                FireRemote("event")
            end, 2)
        else
            Notify("Auto Event", "Disabled", 2, "info")
            StopLoop("AutoEvent")
        end
    end
})

AutomationSection:CreateToggle({
    Name = "Auto Gift",
    Flag = "AutoGift",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoGift = value
        if value then
            Notify("Auto Gift", "Enabled", 2, "success")
            CreateLoop("AutoGift", function()
                local gifts = FindAllDescendants(workspace, "gift", "Model")
                
                for _, gift in ipairs(gifts) do
                    if gift then
                        local clickDetector = FindFirstDescendant(gift, nil, "ClickDetector")
                        if clickDetector then
                            fireclickdetector(clickDetector)
                        end
                        
                        local proximityPrompt = FindFirstDescendant(gift, nil, "ProximityPrompt")
                        if proximityPrompt then
                            fireproximityprompt(proximityPrompt)
                        end
                        
                        FireRemote("OpenGift", gift)
                        FireRemote("ClaimGift", gift)
                    end
                end
            end, 1)
        else
            Notify("Auto Gift", "Disabled", 2, "info")
            StopLoop("AutoGift")
        end
    end
})

local MovementSection = PlayerTab:CreateSection({
    Name = "🏃 Movement",
    Side = "Left"
})

MovementSection:CreateSlider({
    Name = "WalkSpeed",
    Flag = "WalkSpeed",
    Min = 16,
    Max = 200,
    Value = 16,
    Callback = function(value)
        ScriptData.Config.Player.WalkSpeed = value
        local humanoid = GetHumanoid()
        if humanoid then
            humanoid.WalkSpeed = value
        end
    end
})

MovementSection:CreateSlider({
    Name = "JumpPower",
    Flag = "JumpPower",
    Min = 50,
    Max = 300,
    Value = 50,
    Callback = function(value)
        ScriptData.Config.Player.JumpPower = value
        local humanoid = GetHumanoid()
        if humanoid then
            humanoid.JumpPower = value
            humanoid.UseJumpPower = true
        end
    end
})

MovementSection:CreateSlider({
    Name = "Gravity",
    Flag = "Gravity",
    Min = 0,
    Max = 196.2,
    Value = 196.2,
    Callback = function(value)
        ScriptData.Config.Player.Gravity = value
        workspace.Gravity = value
    end
})

local FlightSection = PlayerTab:CreateSection({
    Name = "✈️ Flight",
    Side = "Left"
})

FlightSection:CreateToggle({
    Name = "Fly",
    Flag = "Fly",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Player.Fly = value
        if value then
            Notify("Fly", "Enabled - Use WASD + Space/Shift", 3, "success")
            local flySpeed = ScriptData.Config.Player.FlySpeed
            
            CreateLoop("Fly", function()
                local root = GetRootPart()
                local humanoid = GetHumanoid()
                
                if root and humanoid then
                    local bodyVelocity = root:FindFirstChild("FlyVelocity")
                    if not bodyVelocity then
                        bodyVelocity = Instance.new("BodyVelocity")
                        bodyVelocity.Name = "FlyVelocity"
                        bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
                        bodyVelocity.Parent = root
                    end
                    
                    local moveDirection = humanoid.MoveDirection
                    local velocity = Vector3.new(0, 0, 0)
                    
                    if moveDirection.Magnitude > 0 then
                        velocity = velocity + (moveDirection * flySpeed)
                    end
                    
                    if Services.UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                        velocity = velocity + Vector3.new(0, flySpeed, 0)
                    end
                    
                    if Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                        velocity = velocity - Vector3.new(0, flySpeed, 0)
                    end
                    
                    bodyVelocity.Velocity = velocity
                else
                    StopLoop("Fly")
                end
            end, 0.01)
        else
            Notify("Fly", "Disabled", 2, "info")
            StopLoop("Fly")
            local root = GetRootPart()
            if root then
                local bodyVelocity = root:FindFirstChild("FlyVelocity")
                if bodyVelocity then
                    bodyVelocity:Destroy()
                end
            end
        end
    end
})

FlightSection:CreateSlider({
    Name = "Fly Speed",
    Flag = "FlySpeed",
    Min = 10,
    Max = 200,
    Value = 50,
    Callback = function(value)
        ScriptData.Config.Player.FlySpeed = value
    end
})

local AbilitiesSection = PlayerTab:CreateSection({
    Name = "💪 Abilities",
    Side = "Right"
})

AbilitiesSection:CreateToggle({
    Name = "NoClip",
    Flag = "NoClip",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Player.NoClip = value
        if value then
            Notify("NoClip", "Enabled", 2, "success")
            CreateLoop("NoClip", function()
                local char = GetCharacter()
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end, 0.1)
        else
            Notify("NoClip", "Disabled", 2, "info")
            StopLoop("NoClip")
            local char = GetCharacter()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
})

AbilitiesSection:CreateToggle({
    Name = "Infinite Jump",
    Flag = "InfiniteJump",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Player.InfiniteJump = value
        if value then
            Notify("Infinite Jump", "Enabled", 2, "success")
            AddConnection("InfiniteJump", Services.UserInputService.JumpRequest:Connect(function()
                local humanoid = GetHumanoid()
                if humanoid and ScriptData.Config.Player.InfiniteJump then
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end))
        else
            Notify("Infinite Jump", "Disabled", 2, "info")
            RemoveConnection("InfiniteJump")
        end
    end
})

AbilitiesSection:CreateToggle({
    Name = "Anti AFK",
    Flag = "AntiAFK",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Player.AntiAFK = value
        if value then
            Notify("Anti AFK", "Enabled", 2, "success")
            AddConnection("AntiAFK", LocalPlayer.Idled:Connect(function()
                Services.VirtualUser:CaptureController()
                Services.VirtualUser:ClickButton2(Vector2.new())
            end))
        else
            Notify("Anti AFK", "Disabled", 2, "info")
            RemoveConnection("AntiAFK")
        end
    end
})

AbilitiesSection:CreateToggle({
    Name = "Spinbot",
    Flag = "Spinbot",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Player.Spinbot = value
        if value then
            Notify("Spinbot", "Enabled", 2, "success")
            local angle = 0
            CreateLoop("Spinbot", function()
                local root = GetRootPart()
                if root then
                    angle = angle + ScriptData.Config.Player.SpinbotSpeed
                    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(angle), 0)
                end
            end, 0.01)
        else
            Notify("Spinbot", "Disabled", 2, "info")
            StopLoop("Spinbot")
        end
    end
})

AbilitiesSection:CreateSlider({
    Name = "Spinbot Speed",
    Flag = "SpinbotSpeed",
    Min = 1,
    Max = 50,
    Value = 10,
    Callback = function(value)
        ScriptData.Config.Player.SpinbotSpeed = value
    end
})

AbilitiesSection:CreateButton({
    Name = "Reset Character",
    Callback = function()
        local char = GetCharacter()
        if char then
            local humanoid = GetHumanoid()
            if humanoid then
                humanoid.Health = 0
                Notify("Reset", "Character reset", 2, "info")
            end
        end
    end
})

local LocationsSection = TeleportTab:CreateSection({
    Name = "📍 Locations",
    Side = "Left"
})

LocationsSection:CreateButton({
    Name = "🏪 Teleport to Shop",
    Callback = function()
        UpdateGameCache()
        if GameCache.Shop then
            local targetPart = GameCache.Shop:FindFirstChild("HumanoidRootPart") or GameCache.Shop:FindFirstChildWhichIsA("BasePart")
            if targetPart then
                TeleportTo(targetPart.Position + Vector3.new(0, 5, 0))
                Notify("Teleport", "Teleported to Shop", 2, "success")
            end
        else
            Notify("Error", "Shop not found", 3, "error")
        end
    end
})

LocationsSection:CreateButton({
    Name = "🌻 Teleport to Garden",
    Callback = function()
        UpdateGameCache()
        if GameCache.Garden then
            local targetPart = GameCache.Garden:FindFirstChild("HumanoidRootPart") or GameCache.Garden:FindFirstChildWhichIsA("BasePart")
            if targetPart then
                TeleportTo(targetPart.Position + Vector3.new(0, 5, 0))
                Notify("Teleport", "Teleported to Garden", 2, "success")
            end
        else
            Notify("Error", "Garden not found", 3, "error")
        end
    end
})

LocationsSection:CreateButton({
    Name = "🏠 Teleport to Spawn",
    Callback = function()
        UpdateGameCache()
        if GameCache.Spawn then
            TeleportTo(GameCache.Spawn.Position + Vector3.new(0, 5, 0))
            Notify("Teleport", "Teleported to Spawn", 2, "success")
        else
            Notify("Error", "Spawn not found", 3, "error")
        end
    end
})

LocationsSection:CreateButton({
    Name = "👤 Teleport to NPCs",
    Callback = function()
        UpdateGameCache()
        if #GameCache.NPCs > 0 then
            local npc = GameCache.NPCs[1]
            local targetPart = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
            if targetPart then
                TeleportTo(targetPart.Position + Vector3.new(5, 0, 0))
                Notify("Teleport", "Teleported to NPC", 2, "success")
            end
        else
            Notify("Error", "No NPCs found", 3, "error")
        end
    end
})

LocationsSection:CreateButton({
    Name = "🎉 Teleport to Events",
    Callback = function()
        local events = FindAllDescendants(workspace, "event", "Model")
        if #events > 0 then
            local event = events[1]
            local targetPart = event:FindFirstChildWhichIsA("BasePart")
            if targetPart then
                TeleportTo(targetPart.Position + Vector3.new(0, 5, 0))
                Notify("Teleport", "Teleported to Event", 2, "success")
            end
        else
            Notify("Error", "No events found", 3, "error")
        end
    end
})

local PlayersSection = TeleportTab:CreateSection({
    Name = "👥 Players",
    Side = "Right"
})

local selectedPlayer = nil
local playerDropdown

local function UpdatePlayerList()
    local playerNames = {}
    GameCache.PlayerList = {}
    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerNames, player.Name)
            GameCache.PlayerList[player.Name] = player
        end
    end
    return playerNames
end

playerDropdown = PlayersSection:CreateDropdown({
    Name = "Select Player",
    Flag = "SelectedPlayer",
    List = UpdatePlayerList(),
    Callback = function(value)
        selectedPlayer = value
    end
})

PlayersSection:CreateButton({
    Name = "🔄 Refresh Players",
    Callback = function()
        if playerDropdown and playerDropdown.UpdateList then
            playerDropdown:UpdateList(UpdatePlayerList())
        end
        Notify("Success", "Player list refreshed", 2, "success")
    end
})

PlayersSection:CreateButton({
    Name = "➡️ Teleport to Player",
    Callback = function()
        if selectedPlayer and GameCache.PlayerList[selectedPlayer] then
            local player = GameCache.PlayerList[selectedPlayer]
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                TeleportTo(player.Character.HumanoidRootPart.Position + Vector3.new(5, 0, 0))
                Notify("Success", "Teleported to " .. selectedPlayer, 2, "success")
            else
                Notify("Error", "Player character not found", 3, "error")
            end
        else
            Notify("Error", "Please select a player", 3, "error")
        end
    end
})

local ESPSection = VisualTab:CreateSection({
    Name = "👁️ ESP",
    Side = "Left"
})

ESPSection:CreateToggle({
    Name = "Player ESP",
    Flag = "PlayerESP",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Visual.PlayerESP = value
        if value then
            Notify("Player ESP", "Enabled", 2, "success")
            CreateLoop("PlayerESP", function()
                for _, player in ipairs(Services.Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        if not ScriptData.ESPObjects[tostring(player.Character)] then
                            CreateESP(player.Character, player.Name, Color3.fromRGB(255, 0, 0))
                        end
                    end
                end
            end, 1)
        else
            Notify("Player ESP", "Disabled", 2, "info")
            StopLoop("PlayerESP")
            for _, player in ipairs(Services.Players:GetPlayers()) do
                if player.Character then
                    RemoveESP(player.Character)
                end
            end
        end
    end
})

ESPSection:CreateToggle({
    Name = "Seed ESP",
    Flag = "SeedESP",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Visual.SeedESP = value
        if value then
            Notify("Seed ESP", "Enabled", 2, "success")
            CreateLoop("SeedESP", function()
                local seeds = FindAllDescendants(workspace, "seed", "Model")
                for _, seed in ipairs(seeds) do
                    if not ScriptData.ESPObjects[tostring(seed)] then
                        CreateESP(seed, "Seed", Color3.fromRGB(0, 255, 0))
                    end
                end
            end, 1)
        else
            Notify("Seed ESP", "Disabled", 2, "info")
            StopLoop("SeedESP")
        end
    end
})

ESPSection:CreateToggle({
    Name = "Fruit ESP",
    Flag = "FruitESP",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Visual.FruitESP = value
        if value then
            Notify("Fruit ESP", "Enabled", 2, "success")
            CreateLoop("FruitESP", function()
                local fruits = FindAllDescendants(workspace, "fruit", "Model")
                for _, fruit in ipairs(fruits) do
                    if not ScriptData.ESPObjects[tostring(fruit)] then
                        CreateESP(fruit, "Fruit", Color3.fromRGB(255, 165, 0))
                    end
                end
            end, 1)
        else
            Notify("Fruit ESP", "Disabled", 2, "info")
            StopLoop("FruitESP")
        end
    end
})

ESPSection:CreateToggle({
    Name = "Item ESP",
    Flag = "ItemESP",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Visual.ItemESP = value
        if value then
            Notify("Item ESP", "Enabled", 2, "success")
            CreateLoop("ItemESP", function()
                local items = FindAllDescendants(workspace, "item", "Model")
                for _, item in ipairs(items) do
                    if not ScriptData.ESPObjects[tostring(item)] then
                        CreateESP(item, "Item", Color3.fromRGB(0, 255, 255))
                    end
                end
            end, 1)
        else
            Notify("Item ESP", "Disabled", 2, "info")
            StopLoop("ItemESP")
        end
    end
})

ESPSection:CreateToggle({
    Name = "NPC ESP",
    Flag = "NPCESP",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Visual.NPCESP = value
        if value then
            Notify("NPC ESP", "Enabled", 2, "success")
            CreateLoop("NPCESP", function()
                UpdateGameCache()
                for _, npc in ipairs(GameCache.NPCs) do
                    if not ScriptData.ESPObjects[tostring(npc)] then
                        CreateESP(npc, "NPC", Color3.fromRGB(255, 255, 0))
                    end
                end
            end, 1)
        else
            Notify("NPC ESP", "Disabled", 2, "info")
            StopLoop("NPCESP")
        end
    end
})

ESPSection:CreateToggle({
    Name = "Chest ESP",
    Flag = "ChestESP",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Visual.ChestESP = value
        if value then
            Notify("Chest ESP", "Enabled", 2, "success")
            CreateLoop("ChestESP", function()
                local chests = FindAllDescendants(workspace, "chest", "Model")
                for _, chest in ipairs(chests) do
                    if not ScriptData.ESPObjects[tostring(chest)] then
                        CreateESP(chest, "Chest", Color3.fromRGB(255, 215, 0))
                    end
                end
            end, 1)
        else
            Notify("Chest ESP", "Disabled", 2, "info")
            StopLoop("ChestESP")
        end
    end
})

local RenderSection = VisualTab:CreateSection({
    Name = "🎨 Rendering",
    Side = "Right"
})

RenderSection:CreateToggle({
    Name = "Fullbright",
    Flag = "Fullbright",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Visual.Fullbright = value
        if value then
            Notify("Fullbright", "Enabled", 2, "success")
            Services.Lighting.Brightness = 2
            Services.Lighting.ClockTime = 14
            Services.Lighting.FogEnd = 100000
            Services.Lighting.GlobalShadows = false
            Services.Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        else
            Notify("Fullbright", "Disabled", 2, "info")
            Services.Lighting.Brightness = ScriptData.OriginalValues.Brightness
            Services.Lighting.ClockTime = ScriptData.OriginalValues.ClockTime
            Services.Lighting.FogEnd = ScriptData.OriginalValues.FogEnd
            Services.Lighting.GlobalShadows = ScriptData.OriginalValues.GlobalShadows
        end
    end
})

RenderSection:CreateButton({
    Name = "Remove Fog",
    Callback = function()
        Services.Lighting.FogEnd = 100000
        for _, effect in ipairs(Services.Lighting:GetChildren()) do
            if effect:IsA("Atmosphere") or effect:IsA("BlurEffect") or effect:IsA("ColorCorrectionEffect") then
                effect:Destroy()
            end
        end
        Notify("Success", "Fog removed", 2, "success")
    end
})

RenderSection:CreateButton({
    Name = "FPS Boost",
    Callback = function()
        local decalsyeeted = true
        local g = game
        local w = g.Workspace
        local l = g.Lighting
        local t = w.Terrain
        
        t.WaterWaveSize = 0
        t.WaterWaveSpeed = 0
        t.WaterReflectance = 0
        t.WaterTransparency = 0
        l.GlobalShadows = false
        l.FogEnd = 9e9
        l.Brightness = 0
        
        settings().Rendering.QualityLevel = "Level01"
        
        for _, v in pairs(g:GetDescendants()) do
            if v:IsA("Part") or v:IsA("Union") or v:IsA("CornerWedgePart") or v:IsA("TrussPart") then
                v.Material = "Plastic"
                v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") and decalsyeeted then
                v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                v.Lifetime = NumberRange.new(0)
            elseif v:IsA("Explosion") then
                v.BlastPressure = 1
                v.BlastRadius = 1
            elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
                v.Enabled = false
            elseif v:IsA("MeshPart") then
                v.Material = "Plastic"
                v.Reflectance = 0
            end
        end
        
        for _, e in pairs(l:GetChildren()) do
            if e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect") or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") then
                e.Enabled = false
            end
        end
        
        Notify("Success", "FPS Boost applied", 2, "success")
    end
})

RenderSection:CreateButton({
    Name = "Destroy Effects",
    Callback = function()
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                v:Destroy()
            end
        end
        Notify("Success", "Effects destroyed", 2, "success")
    end
})

local ServerSection = MiscTab:CreateSection({
    Name = "🌐 Server",
    Side = "Left"
})

ServerSection:CreateButton({
    Name = "Server Hop",
    Callback = function()
        Notify("Server Hop", "Finding new server...", 3, "info")
        
        local function serverHop()
            local req = request or http_request or (syn and syn.request)
            if not req then
                Notify("Error", "Exploit not supported", 3, "error")
                return
            end
            
            local response = req({
                Url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100", game.PlaceId),
                Method = "GET"
            })
            
            local body = Services.HttpService:JSONDecode(response.Body)
            local servers = {}
            
            if body and body.data then
                for _, server in ipairs(body.data) do
                    if server.playing < server.maxPlayers and server.id ~= game.JobId then
                        table.insert(servers, server)
                    end
                end
            end
            
            if #servers > 0 then
                local randomServer = servers[math.random(1, #servers)]
                Services.TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer.id, LocalPlayer)
            else
                Notify("Error", "No servers found", 3, "error")
            end
        end
        
        pcall(serverHop)
    end
})

ServerSection:CreateButton({
    Name = "Rejoin",
    Callback = function()
        Services.TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
})

ServerSection:CreateButton({
    Name = "Copy JobId",
    Callback = function()
        if setclipboard then
            setclipboard(game.JobId)
            Notify("Success", "JobId copied to clipboard", 2, "success")
        else
            Notify("Error", "Clipboard not supported", 3, "error")
        end
    end
})

ServerSection:CreateButton({
    Name = "Copy PlaceId",
    Callback = function()
        if setclipboard then
            setclipboard(tostring(game.PlaceId))
            Notify("Success", "PlaceId copied to clipboard", 2, "success")
        else
            Notify("Error", "Clipboard not supported", 3, "error")
        end
    end
})

local GameSection = MiscTab:CreateSection({
    Name = "🎮 Game",
    Side = "Right"
})

GameSection:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            if gui.Name ~= "WindUI" and gui.Name ~= "X0DEC04T_MinimizeButton" then
                gui:Destroy()
            end
        end
        Notify("Success", "UI destroyed", 2, "success")
    end
})

local ConfigSection = SettingsTab:CreateSection({
    Name = "💾 Configuration",
    Side = "Left"
})

local profileName = "default"

ConfigSection:CreateTextbox({
    Name = "Profile Name",
    Flag = "ProfileName",
    Value = "default",
    Placeholder = "Enter profile name...",
    Callback = function(value)
        profileName = value ~= "" and value or "default"
    end
})

ConfigSection:CreateButton({
    Name = "Save Config",
    Callback = function()
        if SaveConfig(profileName) then
            Notify("Success", "Config saved: " .. profileName, 2, "success")
        else
            Notify("Error", "Failed to save config", 3, "error")
        end
    end
})

ConfigSection:CreateButton({
    Name = "Load Config",
    Callback = function()
        if LoadConfig(profileName) then
            Notify("Success", "Config loaded: " .. profileName, 2, "success")
        else
            Notify("Warning", "No config found for: " .. profileName, 3, "warning")
        end
    end
})

ConfigSection:CreateToggle({
    Name = "Auto Save Config",
    Flag = "AutoSaveConfig",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Settings.AutoSave = value
        if value then
            Notify("Auto Save", "Enabled (every 60s)", 2, "success")
            CreateLoop("AutoSave", function()
                SaveConfig(profileName)
            end, 60)
        else
            Notify("Auto Save", "Disabled", 2, "info")
            StopLoop("AutoSave")
        end
    end
})

local UISection = SettingsTab:CreateSection({
    Name = "⚙️ UI Settings",
    Side = "Right"
})

UISection:CreateToggle({
    Name = "Watermark",
    Flag = "Watermark",
    Value = true,
    Callback = function(value)
        ScriptData.Config.Settings.Watermark = value
    end
})

UISection:CreateSlider({
    Name = "UI Scale",
    Flag = "UIScale",
    Min = 0.5,
    Max = 1.5,
    Value = 1,
    Callback = function(value)
        ScriptData.Config.Settings.UIScale = value
    end
})

UISection:CreateSlider({
    Name = "Transparency",
    Flag = "Transparency",
    Min = 0,
    Max = 1,
    Value = 0,
    Callback = function(value)
        ScriptData.Config.Settings.Transparency = value
    end
})

local CreditsSection = CreditsTab:CreateSection({
    Name = "👨‍💻 Credits",
    Side = "Left"
})

CreditsSection:CreateLabel({
    Text = "━━━━━━━━━━━━━━━━━━━━"
})

CreditsSection:CreateLabel({
    Text = "X0DEC04T Hub"
})

CreditsSection:CreateLabel({
    Text = "Version: 1.0.0"
})

CreditsSection:CreateLabel({
    Text = "━━━━━━━━━━━━━━━━━━━━"
})

CreditsSection:CreateLabel({
    Text = ""
})

CreditsSection:CreateLabel({
    Text = "Created by: X0DEC04T"
})

CreditsSection:CreateLabel({
    Text = "UI Library: WindUI"
})

CreditsSection:CreateLabel({
    Text = "Game: Grow a Garden 2"
})

CreditsSection:CreateLabel({
    Text = ""
})

CreditsSection:CreateButton({
    Name = "Join Discord",
    Callback = function()
        if setclipboard then
            setclipboard("discord.gg/x0dec04t")
            Notify("Success", "Discord link copied!", 3, "success")
        else
            Notify("Info", "discord.gg/x0dec04t", 5, "info")
        end
    end
})

CreditsSection:CreateLabel({
    Text = ""
})

CreditsSection:CreateLabel({
    Text = "Thank you for using X0DEC04T Hub!"
})

AddConnection("CharacterAdded", LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    
    if ScriptData.Config.Player.WalkSpeed ~= ScriptData.OriginalValues.WalkSpeed then
        humanoid.WalkSpeed = ScriptData.Config.Player.WalkSpeed
    end
    
    if ScriptData.Config.Player.JumpPower ~= ScriptData.OriginalValues.JumpPower then
        humanoid.JumpPower = ScriptData.Config.Player.JumpPower
        humanoid.UseJumpPower = true
    end
    
    AddConnection("HumanoidDied", humanoid.Died:Connect(function()
        if ScriptData.Config.Player.Fly then
            local root = character:FindFirstChild("HumanoidRootPart")
            if root then
                local bodyVelocity = root:FindFirstChild("FlyVelocity")
                if bodyVelocity then
                    bodyVelocity:Destroy()
                end
            end
        end
    end))
end))

AddConnection("ChildAdded", workspace.ChildAdded:Connect(function(child)
    task.wait(0.1)
    UpdateGameCache()
end))

task.spawn(function()
    while task.wait(10) do
        UpdateGameCache()
    end
end)

LoadConfig("default")

Notify("X0DEC04T Hub", "Successfully loaded for Grow a Garden 2!", 5, "success")
Notify("Info", "Look for the X0D button to toggle UI", 3, "info")

local function Cleanup()
    for name, connection in pairs(ScriptData.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    
    for name, _ in pairs(ScriptData.Loops) do
        ScriptData.Loops[name] = false
    end
    
    ClearAllESP()
    
    workspace.Gravity = ScriptData.OriginalValues.Gravity
    Services.Lighting.Brightness = ScriptData.OriginalValues.Brightness
    Services.Lighting.ClockTime = ScriptData.OriginalValues.ClockTime
    Services.Lighting.FogEnd = ScriptData.OriginalValues.FogEnd
    Services.Lighting.GlobalShadows = ScriptData.OriginalValues.GlobalShadows
    
    local humanoid = GetHumanoid()
    if humanoid then
        humanoid.WalkSpeed = ScriptData.OriginalValues.WalkSpeed
        humanoid.JumpPower = ScriptData.OriginalValues.JumpPower
    end
end

Services.Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        Cleanup()
    end
end)