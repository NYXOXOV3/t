-- ============================================================
-- NYXHUB - FULL SCRIPT (CONVERTED TO CUSTOM LIBRARY)
-- ============================================================

-- 1. LOAD UI LIBRARY
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/NYXOXOV3/berak/refs/heads/main/gui.lua"))()
if not Library then warn("[NYXHUB] Gagal load Library!"); return end

-- 2. SERVICES & GLOBALS
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local isMobile = UserInputService.TouchEnabled

-- 3. SAFE WRAPPER (Kompatibilitas WindUI -> Library Baru)
local ElementRegistry = {}
local ElementByTitle = {} -- Untuk GetElementByTitle

local function WrapElement(id, element, title)
    if not element then return nil end
    
    local wrapped = {}
    setmetatable(wrapped, {__index = element})
    
    -- Kompatibilitas: Value property -> GetValue()
    wrapped.Value = nil
    local mt = getmetatable(wrapped)
    mt.__index = function(self, key)
        if key == "Value" then
            if rawget(self, "_cachedValue") ~= nil then return rawget(self, "_cachedValue") end
            if element.GetValue then
                local ok, val = pcall(function() return element:GetValue() end)
                if ok then return val end
            end
            return rawget(self, "_defaultValue")
        end
        return element[key]
    end
    mt.__newindex = function(self, key, value)
        if key == "Value" then
            rawset(self, "_cachedValue", value)
            if element.SetValue then pcall(function() element:SetValue(value) end) end
        else
            element[key] = value
        end
    end
    
    -- Kompatibilitas: Set(val) -> SetValue(val)
    if not wrapped.Set then
        wrapped.Set = function(self, val)
            rawset(self, "_cachedValue", val)
            if element.SetValue then pcall(function() element:SetValue(val) end) end
        end
    end
    
    -- Kompatibilitas: Refresh(list, true) -> Refresh(list)
    if element.Refresh then
        local origRefresh = element.Refresh
        wrapped.Refresh = function(self, list, ...)
            pcall(function() origRefresh(element, list) end)
        end
    end
    
    -- Kompatibilitas: SetTitle / SetDesc / SetContent
    if not wrapped.SetTitle then wrapped.SetTitle = function() end end
    if not wrapped.SetDesc then
        wrapped.SetDesc = function(self, v)
            if element.SetContent then pcall(function() element:SetContent(v) end) end
        end
    end
    if not wrapped.SetContent then
        wrapped.SetContent = function(self, v)
            if element.SetDesc then pcall(function() element:SetDesc(v) end) end
        end
    end
    if not wrapped.SetPlaceholder then wrapped.SetPlaceholder = function() end end
    
    -- Kompatibilitas: GetValue
    if not wrapped.GetValue then
        wrapped.GetValue = function(self)
            if element.GetValue then
                local ok, val = pcall(function() return element:GetValue() end)
                if ok then return val end
            end
            return rawget(self, "_cachedValue") or rawget(self, "_defaultValue")
        end
    end
    
    ElementRegistry[id] = wrapped
    if title then ElementByTitle[title] = wrapped end
    return wrapped
end

local function Reg(id, element, title)
    return WrapElement(id, element, title)
end

-- Helper: GetElementByTitle (kompatibilitas)
local function GetElementByTitle(tabObj, title)
    return ElementByTitle[title]
end

-- Helper: AddSliderCompat (konversi Slider -> Input dengan validasi)
local function AddSliderCompat(section, config)
    local title = config.Title or "Slider"
    local minVal = config.Value and config.Value.Min or 0
    local maxVal = config.Value and config.Value.Max or 100
    local defaultVal = config.Value and config.Value.Default or minVal
    local step = config.Step or 1
    local callback = config.Callback
    
    local frame = section:AddInput({
        Title = title,
        Default = tostring(defaultVal),
        Placeholder = string.format("%.2f - %.2f", minVal, maxVal),
        Callback = function(text)
            local num = tonumber(text)
            if num then
                num = math.clamp(num, minVal, maxVal)
                if step >= 1 then num = math.floor(num) end
                if callback then pcall(callback, num) end
            end
        end
    })
    return frame
end

-- Helper: Notify (ganti WindUI:Notify)
local function Notify(cfg)
    cfg = cfg or {}
    Library:MakeNotify({
        Title = cfg.Title or "Notification",
        Description = cfg.Content or cfg.Description or "",
        Color = cfg.Color or Library.colors.primary,
        Delay = cfg.Duration or cfg.Delay or 3
    })
end

-- 4. REMOTES & NETWORK
local net = ReplicatedStorage:WaitForChild("Packages", 10):WaitForChild("_Index", 10):WaitForChild("sleitnick_net@0.2.0", 10):WaitForChild("net", 10)
local remotes = net:GetChildren()
print("[NYXHUB] remotes length: " .. #remotes)

function GetServerRemote(targetName)
    -- Metode 1: Cari langsung di descendants (paling stabil)
    for _, descendant in ipairs(net:GetDescendants()) do
        if descendant.Name == targetName and (descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")) then
            return descendant
        end
    end
    -- Metode 2: Fallback ke logika lama
    local allRemotes = net:GetChildren()
    for i, remote in ipairs(allRemotes) do
        if remote.Name == targetName then
            local actualRemote = allRemotes[i + 1]
            if actualRemote and (actualRemote:IsA("RemoteEvent") or actualRemote:IsA("RemoteFunction")) then
                return actualRemote
            end
        end
    end
    return nil
end

function GetServerRemoteReverse(targetName)
    local allRemotes = net:GetChildren()
    for i, remote in ipairs(allRemotes) do
        if remote.Name == targetName then
            local actualRemote = allRemotes[i - 1]
            if actualRemote and (actualRemote:IsA("RemoteEvent") or actualRemote:IsA("RemoteFunction")) then
                return actualRemote
            end
        end
    end
    return nil
end

function safeFire(func) task.spawn(function() pcall(func) end) end

function CallRemoteServer(remote, ...)
    if not remote then return false end
    local ok
    if remote:IsA("RemoteFunction") then
        ok = select(1, pcall(function(...) remote:InvokeServer(...) end, ...))
    elseif remote:IsA("RemoteEvent") then
        ok = select(1, pcall(function(...) remote:FireServer(...) end, ...))
    end
    return ok
end

function FireLocalEvent(remote, ...)
    local args = {...}
    local signal = remote.OnClientEvent
    for _, connection in pairs(getconnections(signal)) do
        if connection.Function then
            task.spawn(function() connection.Function(unpack(args)) end)
        end
    end
end

-- 5. CONTROLLERS & UTILITIES
local Controllers, NotificationController, TextNotificationController, VFXController, CutsceneController, ControlModule, FishingController, AFKController, PromptController, BackpackController, AutoFishingController
local Replion, PlayerData, ItemUtility, TierUtility

if isMobile then
    Controllers = ReplicatedStorage:WaitForChild("Controllers")
    pcall(function()
        NotificationController = require(Controllers:WaitForChild("NotificationController"))
        TextNotificationController = require(Controllers:WaitForChild("TextNotificationController"))
        VFXController = require(Controllers:WaitForChild("VFXController"))
        FishingController = require(Controllers:WaitForChild("FishingController"))
        AFKController = require(Controllers:WaitForChild("AFKController"))
        PromptController = require(Controllers:WaitForChild("PromptController"))
        BackpackController = require(Controllers:WaitForChild("BackpackController"))
        CutsceneController = require(Controllers:WaitForChild("CutsceneController"))
    end)
    pcall(function()
        Replion = require(ReplicatedStorage.Packages.Replion)
        PlayerData = Replion.Client:WaitReplion("Data")
        ControlModule = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
        ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)
        TierUtility = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TierUtility"))
    end)
end

-- 6. GLOBAL STATE
local g_character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local g_humanoid = g_character:WaitForChild("Humanoid")
local g_animator = g_humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", g_humanoid)

_G.SavedData = _G.SavedData or { FishCaught = {}, CaughtVisual = {}, FishNotif = {} }

local saveCount = 0
function HookRemote(humanName, storageKey)
    local remote = GetServerRemote(humanName)
    if remote then
        remote.OnClientEvent:Connect(function(...)
            if saveCount < 7 then
                _G.SavedData[storageKey] = {...}
                local args = {...}
                if storageKey == "CaughtVisual" and tostring(args[1]) == tostring(LocalPlayer.Name) then
                    saveCount = saveCount + 5
                end
            end
        end)
        return true
    end
    return false
end

local Config = {
    MainLoop = true, InstantFishing = false, AutoCatch = false, Perfection = false,
    isFarming = false, isMinig = false, AutoFarm = false, AutoFarmMegalodon = false,
    AutoFarmChristmas = false, AutoFavorite = false, CatchDelay = 0.7, CastDelay = 1.12,
    ChargeDelay = 0, CancelDelay = 0.78, DisableAnimations = false, PerfectionValue = 0.28,
    onlyMythicAndSecret = false, onlyRareAndEpic = false, onlySecret = false,
    autoWeather = false, removePopUp = false, antiFall = false, gpuSaver = false,
    customEffect = false, AutoSell = true, SellDelay = 15, SpeedHack = false,
    SpeedHackValue = 60, WalkOnWater = false, HookNotif = false, BackupPerfection = false,
    FavRubyGemstone = false, isFreeze = false, backupIsFreeze = false, autoFishing = false,
    DisablePopUp = false, DisableVfx = false, DisableCutscene = false, CustomWebhook = false,
    WebhookUrl = "https://discord.com/api/webhooks/1477575323561230377/0idg285QzIxWTIbABB4Ha8u_MVaLhoxLiR3cAQUQN7FBqnWwneV1q8TRTsaV0YJlLVI3",
    CustomWebhookUrl = "", HideUsn = false, AutoMining = false, axeUuid = "",
    autoConsumeCaveCrystal = false, savePosition = false, position = "", antiOKOK = false,
    SpinPlayer = false, Auto1Totem = false,
    UB = {
        Active = false,
        Settings = { CompleteDelay = 2.6, CancelDelay = 0.0001, NotificationDuration = 6 },
        Remotes = {},
        Stats = { castCount = 0, startTime = 0 }
    },
    amblatant = false, DcUsername = "", autoClaimPirateChest = false
}

local needCast, skip = false, false
local lastTimeFishCaught
local isCaught = false
local blatantFishCycleCount = 0
local Tasks = {}

-- Anti-AFK
local IntervalWaktu = 60 * 18
for i, v in pairs(getconnections(LocalPlayer.Idled)) do
    if v.Disable then v:Disable() elseif v.Disconnect then v:Disconnect() end
end

local function FireUIAtLocation()
    local x, y = 0, 0
    local guiObjects = LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(x, y)
    for _, obj in pairs(guiObjects) do
        if obj:IsA("GuiButton") then
            for _, connection in pairs(getconnections(obj.MouseButton1Click)) do pcall(function() connection:Fire() end) end
            for _, connection in pairs(getconnections(obj.Activated)) do pcall(function() connection:Fire() end) end
        end
    end
end
task.spawn(function()
    while true do
        task.wait(IntervalWaktu)
        FireUIAtLocation()
    end
end)

-- 7. WALK ON WATER (FIXED)
local walkOnWaterConnection = nil
local isWalkOnWater = false
local waterPlatform = nil

local function applyWalkOnWater(on)
    if on then
        isWalkOnWater = true
        if not waterPlatform or not waterPlatform.Parent then
            waterPlatform = Instance.new("Part")
            waterPlatform.Name = "WaterPlatform"
            waterPlatform.Anchored = true
            waterPlatform.CanCollide = true
            waterPlatform.Transparency = 1
            waterPlatform.Size = Vector3.new(15, 1, 15)
            waterPlatform.Parent = workspace
        end
        if walkOnWaterConnection then walkOnWaterConnection:Disconnect() end
        walkOnWaterConnection = RunService.RenderStepped:Connect(function()
            local character = LocalPlayer.Character
            if not isWalkOnWater or not character then return end
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            if not waterPlatform or not waterPlatform.Parent then
                waterPlatform = Instance.new("Part")
                waterPlatform.Name = "WaterPlatform"
                waterPlatform.Anchored = true
                waterPlatform.CanCollide = true
                waterPlatform.Transparency = 1
                waterPlatform.Size = Vector3.new(15, 1, 15)
                waterPlatform.Parent = workspace
            end
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {workspace.Terrain}
            rayParams.FilterType = Enum.RaycastFilterType.Include
            rayParams.IgnoreWater = false
            local result = workspace:Raycast(hrp.Position + Vector3.new(0, 5, 0), Vector3.new(0, -500, 0), rayParams)
            if result and result.Material == Enum.Material.Water then
                local waterSurfaceHeight = result.Position.Y
                waterPlatform.Position = Vector3.new(hrp.Position.X, waterSurfaceHeight, hrp.Position.Z)
                if hrp.Position.Y < (waterSurfaceHeight + 2) and hrp.Position.Y > (waterSurfaceHeight - 5) then
                    if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                        hrp.CFrame = CFrame.new(hrp.Position.X, waterSurfaceHeight + 3.2, hrp.Position.Z)
                    end
                end
            else
                waterPlatform.Position = Vector3.new(hrp.Position.X, -500, hrp.Position.Z)
            end
        end)
    else
        isWalkOnWater = false
        if walkOnWaterConnection then walkOnWaterConnection:Disconnect(); walkOnWaterConnection = nil end
        if waterPlatform then waterPlatform:Destroy(); waterPlatform = nil end
    end
end

-- 8. NO ANIMATION (FIXED)
local animConn = nil
local function applyNoAnimation(on)
    if animConn then animConn:Disconnect(); animConn = nil end
    if on then
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do track:Stop(0) end
        local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
        animConn = animator.AnimationPlayed:Connect(function(track) track:Stop(0) end)
    else
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local animator = hum:FindFirstChildOfClass("Animator")
                if animator then
                    local oldParent = animator.Parent
                    animator.Parent = nil
                    animator.Parent = oldParent
                end
            end
        end
    end
end

-- 9. LOCATIONS
local LOCATIONS = {
    ["Fisherman"] = CFrame.new(-18.065, 9.532, 2734.000, -0.113811, 0.000000, -0.993502, -0.000000, 1.000000, 0.000000, 0.993502, 0.000000, -0.113811),
    ["Sisyphus Statue"] = CFrame.new(-3754.441, -135.074, -895.376, 0.943844, 0, -0.330393, 0, 1, 0, 0.330393, 0, 0.943844),
    ["Coral Reefs"] = CFrame.new(-3030.043, 2.509, 2271.429, 0.304264, -0.000000, 0.952588, -0.000000, 1.000000, 0.000000, -0.952588, -0.000000, 0.304264),
    ["Esoteric Depths"] = CFrame.new(3271.979, -1301.530, 1402.762, -0.981542, -0.000000, -0.191249, -0.000000, 1.000000, 0.000000, 0.191249, 0.000000, -0.981542),
    ["Crater Island 1"] = CFrame.new(990.610, 21.142, 5060.255, 0.998865, 0.000000, -0.047632, -0.000000, 1.000000, -0.000000, 0.047632, 0.000000, 0.998865),
    ["Crater Island 2"] = CFrame.new(1040.036, 55.714, 5131.443, 0.551438, -0.000000, 0.834216, 0.000000, 1.000000, 0.000000, -0.834216, 0.000000, 0.551438),
    ["Lost Isle"] = CFrame.new(-3618.15698, 240.836655, -1317.45801),
    ["Weather Machine"] = CFrame.new(-1488.51196, 83.1732635, 1876.30298),
    ["Tropical Grove"] = CFrame.new(-2132.597, 53.488, 3631.235, -0.664326, -0.000000, 0.747443, -0.000000, 1.000000, 0.000000, -0.747443, -0.000000, -0.664326),
    ["Treasure Room"] = CFrame.new(-3630, -279.074, -1599.287, 0.721647, 0, -0.692261, 0, 1, 0, 0.692261, 0, 0.721647),
    ["Kohana"] = CFrame.new(-663.904236, 3.04580712, 718.796875),
    ["Kohana2"] = CFrame.new(-530.529, 8.750, -72.149, -0.910784, 0, -0.412883, 0, 1, 0, 0.412883, 0, -0.910784),
    ["Underground Cellar"] = CFrame.new(2110.109, -91.199, -699.790, 0.744219, -0.000000, -0.667935, -0.000000, 1.000000, -0.000000, 0.667935, 0.000000, 0.744219),
    ["Ancient Jungle"] = CFrame.new(1837.352, 5.894, -297.224, 0.388620, 0.000000, -0.921398, 0.000000, 1.000000, 0.000000, 0.921398, -0.000000, 0.388620),
    ["Ancient Jungle 2"] = CFrame.new(1468.971, 6.512, -326.397, -0.458676, 0.000000, -0.888603, 0.000000, 1.000000, 0.000000, 0.888603, -0.000000, -0.458676),
    ["Sacred Temple"] = CFrame.new(1459.217, -22.375, -637.787, 0.924266, 0, 0.381750, 0, 1, 0, -0.381750, 0, 0.924266),
    ["Ancient Ruins"] = CFrame.new(6097.176, -585.924, 4644.443, -0.514758, 0, 0.857336, 0, 1, 0, -0.857336, 0, -0.514758),
    ["Megalodon"] = CFrame.new(-1172.987, 7.924, 3620.589, 0.706693, 0, 0.707521, 0, 1, 0, -0.707521, 0, 0.706693),
    ["Pirate Cove"] = CFrame.new(3396.730, 4.192, 3469.213) * CFrame.Angles(-0.000, -1.447, -0.000),
    ["Pirate Treasure Room"] = CFrame.new(3324.07397, -306.475647, 3087.99927, 0.999340534, -1.78439805e-08, 0.0363113917, 2.01013268e-08, 1, -6.18013019e-08, -0.0363113917, 6.24904501e-08, 0.999340534),
    ["Secret Passage"] = CFrame.new(3436.101, -289.845, 3382.640, -0.920254, 0.000000, -0.391321, 0.000000, 1.000000, 0.000000, 0.391321, -0.000000, -0.920254),
    ["Kohana Volcano"] = CFrame.new(-549.192, 20.019, 125.802, 0.955081, 0.000000, -0.296344, -0.000000, 1.000000, 0.000000, 0.296344, -0.000000, 0.955081),
    ["Crystal Depth"] = CFrame.new(5752.219, -907.148, 15343.468, -0.628654, 0.000000, 0.777685, -0.000000, 1.000000, -0.000000, -0.777685, -0.000000, -0.628654),
    ["Lava Basin"] = CFrame.new(950.876, 85.282, -10199.427, 0.105691, -0.000000, 0.994399, -0.000000, 1.000000, 0.000000, -0.994399, -0.000000, 0.105691),
    ["Planetary Observatory"] = CFrame.new(420.372925, 3.673104, 2183.674561, -0.219190, 0.000000, -0.975682, 0.000000, 1.000000, 0.000000, 0.975682, -0.000000, -0.219190),
    ["Underwater City"] = CFrame.new(-3142.405518, -643.484253, -10409.403320, 0.120181, -0.000000, -0.992752, -0.000000, 1.000000, -0.000000, 0.992752, 0.000000, 0.120181),
    ["Swers Area"] = CFrame.new(-1445.962, -1041.589, -10469.594),
}

local AreaNames = {}
for name, _ in pairs(LOCATIONS) do table.insert(AreaNames, name) end
table.sort(AreaNames)

-- 10. HELPER FUNCTIONS
local function GetHRP()
    local char = LocalPlayer.Character
    if not char then char = LocalPlayer.CharacterAdded:Wait() end
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function GetHumanoid()
    local character = LocalPlayer.Character
    if not character then character = LocalPlayer.CharacterAdded:Wait() end
    return character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 3)
end

local function TeleportToLookAt(position, lookVector)
    local hrp = GetHRP()
    if hrp and typeof(position) == "Vector3" then
        local targetCFrame
        if typeof(lookVector) == "Vector3" then
            targetCFrame = CFrame.new(position, position + lookVector) * CFrame.new(0, 0.5, 0)
        else
            targetCFrame = CFrame.new(position + Vector3.new(0, 3, 0))
        end
        local tween = TweenService:Create(hrp, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
        tween:Play()
        tween.Completed:Wait()
        Notify({ Title = "Teleport Sukses!", Duration = 2 })
    else
        Notify({ Title = "Teleport Gagal", Duration = 2 })
    end
end

local function createPlatform(position)
    local platform = Instance.new("Part")
    platform.Name = "AirPlatform"
    platform.Size = Vector3.new(7, 1, 7)
    platform.Anchored = true
    platform.CanCollide = true
    platform.Transparency = 0.9
    platform.Position = position - Vector3.new(0, 3, 0)
    platform.Parent = workspace
    task.delay(10, function() if platform and platform.Parent then platform:Destroy() end end)
end

local function teleportToMegalodon()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if string.find(obj.Name:lower(), "megalodon") then
            task.wait(0.1)
            if obj:IsA("BasePart") then
                TeleportToLookAt(obj.Position, nil)
                applyWalkOnWater(true)
                Config.isFarming = true
                return
            end
        end
    end
end

-- 11. REPLICON HELPERS
local PlayerDataReplion = nil
local function GetPlayerDataReplion()
    if PlayerDataReplion then return PlayerDataReplion end
    local ReplionModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Replion", 10)
    if not ReplionModule then return nil end
    local ReplionClient = require(ReplionModule).Client
    PlayerDataReplion = ReplionClient:WaitReplion("Data", 5)
    return PlayerDataReplion
end

local MerchantReplion = nil
local function GetMerchantReplion()
    if MerchantReplion then return true end
    local ReplionModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Replion", 10)
    if not ReplionModule then return false end
    local ReplionClient = require(ReplionModule).Client
    MerchantReplion = ReplionClient:WaitReplion("Merchant", 5)
    return MerchantReplion
end

local function GetItemMutationString(item)
    if item.Metadata and item.Metadata.Shiny == true then return "Shiny" end
    return item.Metadata and item.Metadata.VariantId or ""
end

local function GetFishNameAndRarity(item)
    local name = item.Identifier or "Unknown"
    local rarity = item.Metadata and item.Metadata.Rarity or "COMMON"
    local itemID = item.Id
    local itemData = nil
    if ItemUtility and itemID then
        pcall(function()
            itemData = ItemUtility:GetItemData(itemID)
            if not itemData then
                local numericID = tonumber(item.Id) or tonumber(item.Identifier)
                if numericID then itemData = ItemUtility:GetItemData(numericID) end
            end
        end)
    end
    if itemData and itemData.Data and itemData.Data.Name then name = itemData.Data.Name end
    if item.Metadata and item.Metadata.Rarity then
        rarity = item.Metadata.Rarity
    elseif itemData and itemData.Probability and itemData.Probability.Chance and TierUtility then
        local tierObj = nil
        pcall(function() tierObj = TierUtility:GetTierFromRarity(itemData.Probability.Chance) end)
        if tierObj and tierObj.Name then rarity = tierObj.Name end
    end
    return name, rarity
end

local function FormatNumber(n)
    n = math.floor(n)
    local formatted = tostring(n):reverse():gsub("%d%d%d", "%1."):reverse()
    return formatted:gsub("^%.", "")
end

local function CensorName(name)
    if not name or type(name) ~= "string" or #name < 1 then return "N/A" end
    if #name <= 3 then return name end
    return name:sub(1, 3) .. string.rep("*", #name - 3)
end

local ImageURLCache = {}
local function GetRobloxAssetImage(assetId)
    if not assetId or assetId == 0 then return nil end
    if ImageURLCache[assetId] then return ImageURLCache[assetId] end
    local url = string.format("https://thumbnails.roblox.com/v1/assets?assetIds=%d&size=420x420&format=Png&isCircular=false", assetId)
    local success, response = pcall(game.HttpGet, game, url)
    if success then
        local ok, data = pcall(HttpService.JSONDecode, HttpService, response)
        if ok and data and data.data and data.data[1] and data.data[1].imageUrl then
            ImageURLCache[assetId] = data.data[1].imageUrl
            return ImageURLCache[assetId]
        end
    end
    return nil
end

local function sendExploitWebhook(url, username, embed_data)
    local payload = { username = username, embeds = {embed_data} }
    local json_data = HttpService:JSONEncode(payload)
    if typeof(request) == "function" then
        local success, response = pcall(function()
            return request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = json_data })
        end)
        if success and (response.StatusCode == 200 or response.StatusCode == 204) then return true, "Sent" end
        return false, "Failed: " .. tostring(response and response.StatusCode)
    end
    return false, "No Request Func"
end

local function getRarityColor(rarity)
    local r = rarity:upper()
    if r == "SECRET" then return 0x00d3a9 end
    if r == "MYTHIC" then return 0xe22b2e end
    if r == "LEGENDARY" then return 0xFF4500 end
    if r == "EPIC" then return 0x8A2BE2 end
    if r == "RARE" then return 0x0000FF end
    if r == "UNCOMMON" then return 0x00FF00 end
    return 0x00BFFF
end

-- 12. EVENTS INIT
local Events = {}
Events.equip = GetServerRemote("RF/EquipToolFromHotbar")
Events.unequip = GetServerRemote("RE/UnequipToolFromHotbar")
Events.equipItem = GetServerRemote("RE/EquipItem")
Events.CancelFishingInputs = GetServerRemote("RF/CancelFishingInputs")
Events.charge = GetServerRemote("RF/ChargeFishingRod")
Events.minigame = GetServerRemote("RF/RequestFishingMinigameStarted")
Events.UpdateAutoFishingState = GetServerRemote("RF/UpdateAutoFishingState")
Events.sell = GetServerRemote("RF/SellAllItems")
Events.systemMessageEvent = GetServerRemote("RE/DisplaySystemMessage")
Events.fishNotif = GetServerRemote("RE/ObtainedNewFishNotification")
Events.favorite = GetServerRemote("RE/FavoriteItem")
Events.SpawnTotem = GetServerRemote("RE/SpawnTotem")
Events.TextNotification = GetServerRemote("RE/TextNotification")

-- Anti-staff kick
if Events.systemMessageEvent then
    Events.systemMessageEvent.OnClientEvent:Connect(function(...)
        local args = {...}
        if args[1] then args[1] = args[1]:lower() end
        if args[1] and (not string.find(args[1], "global") or string.find(args[1], "server")) and string.find(args[1], "staff") then
            LocalPlayer:Kick("Awas ada staff")
        end
    end)
end

-- 13. UB (ULTRA BLATANT) SYSTEM
function UB_init()
    local success, netFolder = pcall(function()
        return ReplicatedStorage:WaitForChild("Packages", 10):WaitForChild("_Index", 10):WaitForChild("sleitnick_net@0.2.0", 10):WaitForChild("net", 10)
    end)
    if not success or not netFolder then return false end
    Config.UB.Remotes.ChargeFishingRod = GetServerRemote("RF/ChargeFishingRod")
    Config.UB.Remotes.RequestMinigame = GetServerRemote("RF/RequestFishingMinigameStarted")
    Config.UB.Remotes.CancelFishingInputs = GetServerRemote("RF/CancelFishingInputs")
    Config.UB.Remotes.UpdateAutoFishingState = GetServerRemote("RF/UpdateAutoFishingState")
    Config.UB.Remotes.FishingCompleted = GetServerRemote("RF/CatchFishCompleted")
    Config.UB.Remotes.FishingCompletedRE = GetServerRemote("RE/CatchFishCompleted")
    Config.UB.Remotes.MinigameChanged = GetServerRemote("RE/FishingMinigameChanged")
    Config.UB.Remotes.equip = GetServerRemote("RF/EquipToolFromHotbar")
    return true
end

function ub_loop()
    while Config.UB.Active do
        if Config.isMinig then
            task.wait(3)
        else
            local currentTime = tick()
            if Config.autoFishing then CallRemoteServer(Events.UpdateAutoFishingState, true) end
            task.wait(needCast and 0.7 or Config.UB.Settings.CancelDelay)
            needCast = false
            safeFire(function()
                CallRemoteServer(Config.UB.Remotes.ChargeFishingRod, { [1] = currentTime })
                if Config.antiOKOK and not Config.autoFishing then
                    task.wait(17 / 100)
                end
                CallRemoteServer(Config.UB.Remotes.RequestMinigame, 1, 0, currentTime)
            end)
            task.wait(Config.UB.Settings.CompleteDelay)
            if not skip then
                safeFire(function()
                    safeFire(function() CallRemoteServer(Config.UB.Remotes.FishingCompleted) end)
                    if Config.UB.Remotes.FishingCompletedRE then Config.UB.Remotes.FishingCompletedRE:FireServer() end
                    if Config.amblatant and isCaught then
                        task.spawn(function()
                            task.wait(0.01)
                            local xremote = GetServerRemote("RE/FishCaught")
                            if xremote then FireLocalEvent(xremote, unpack(_G.SavedData.FishCaught)) end
                            xremote = GetServerRemote("RE/CaughtFishVisual")
                            if xremote then FireLocalEvent(xremote, unpack(_G.SavedData.CaughtVisual)) end
                            xremote = GetServerRemote("RE/ObtainedNewFishNotification")
                            if xremote then FireLocalEvent(xremote, unpack(_G.SavedData.FishNotif)) end
                        end)
                        isCaught = false
                    end
                end)
            end
            blatantFishCycleCount = blatantFishCycleCount + 1
        end
    end
end

function UB_start()
    if Config.UB.Active then return end
    if not UB_init() then return end
    Config.UB.Active = true
    needCast = true
    Config.UB.Stats.startTime = tick()
    Tasks.ubtask = task.spawn(ub_loop)
end

function UB_stop()
    if not Config.UB.Active then return end
    Config.UB.Active = false
    safeFire(function()
        if Config.UB.Remotes.CancelFishingInputs then CallRemoteServer(Config.UB.Remotes.CancelFishingInputs) end
    end)
    task.wait(0.2)
    if Tasks.ubtask then pcall(function() task.cancel(Tasks.ubtask) end); Tasks.ubtask = nil end
end

local function onToggleUB(value)
    if value then
        Config.HookNotif = true
        CallRemoteServer(Events.equip, 1)
        pcall(function()
            CallRemoteServer(Events.CancelFishingInputs)
            task.wait(0.7)
            CallRemoteServer(Events.charge)
            CallRemoteServer(Events.minigame, -911.1024780273438, 0.9, os.clock())
        end)
        UB_start()
        Notify({ Title = "UB Instant ON", Duration = 2 })
    else
        UB_stop()
        Config.HookNotif = false
        Notify({ Title = "UB Instant OFF", Duration = 2 })
    end
end

UB_init()

-- Auto-restart UB if stuck
task.spawn(function()
    while true do
        task.wait(3)
        if not Config.isFarming or not Config.isMinig then
            if Config.UB.Active and lastTimeFishCaught ~= nil and os.clock() - lastTimeFishCaught >= 5 and blatantFishCycleCount > 1 then
                needCast = true
                saveCount = 0
                blatantFishCycleCount = 0
                lastTimeFishCaught = os.clock()
                onToggleUB(false)
                task.wait(0.5)
                onToggleUB(true)
            end
        end
    end
end)

-- 14. FISH NOTIFICATION HOOK
if Events.fishNotif then
    Events.fishNotif.OnClientEvent:Connect(function(...)
        local args = {...}
        local arg3 = args[3]
        lastTimeFishCaught = os.clock()
        local dummyItem = {Id = args[1], Metadata = args[2]}
        local fishName, fishRarity = GetFishNameAndRarity(dummyItem)
        local fishRarityUpper = fishRarity:upper()
        
        if typeof(arg3) == "table" and arg3.InventoryItem and arg3.InventoryItem.UUID then
            if Config.FavRubyGemstone then
                if fishName == "Ruby" and arg3.InventoryItem.Metadata.VariantId == "Gemstone" then
                    Events.favorite:FireServer(arg3.InventoryItem.UUID)
                end
            end
        end
    end)
end

-- ============================================================
-- UI CONSTRUCTION
-- ============================================================

local Window = Library:Window({ Title = "NYXHUB", Footer = "Fish It Premium" })

-- Floating Button
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NYX_FloatingBtn"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local btn = Instance.new("ImageButton")
btn.Name = "NYXButton"
btn.Size = UDim2.new(0, 70, 0, 70)
btn.AnchorPoint = Vector2.new(0.5, 0.5)
btn.Position = UDim2.new(0.95, 0, 0.50, 0)
btn.BackgroundColor3 = Color3.fromRGB(90, 0, 170)
btn.Image = "rbxassetid://137263312772667"
btn.BorderSizePixel = 0
btn.Visible = true
btn.Parent = screenGui
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", btn)
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(255, 0, 255)

local dragging, dragStart, startPos = false, nil, nil
btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = btn.Position
    end
end)
btn.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
btn.MouseButton1Click:Connect(function()
    if Library._win then Library._win.Visible = not Library._win.Visible end
end)

-- ============================================================
-- TAB: ABOUT
-- ============================================================
local aboutTab = Window:AddTab({ Name = "About", Icon = "alert" })
local aboutSec = aboutTab:AddSection("Noxius Community")
aboutSec:AddParagraph({
    Title = "Join Discord Server",
    Content = "Join Our Community Discord Server to get the latest updates, support, and connect with other users!"
})
aboutSec:AddButton({
    Title = "Copy Discord Link",
    Callback = function()
        setclipboard("https://discord.gg/noxius")
        Notify({ Title = "Link Disalin!", Description = "Link Discord Noxius berhasil disalin." })
    end
})

-- ============================================================
-- TAB: PLAYER
-- ============================================================
local playerTab = Window:AddTab({ Name = "Player", Icon = "user" })
local movementSec = playerTab:AddSection("Movement")

Reg("Walkspeed", AddSliderCompat(movementSec, {
    Title = "WalkSpeed", Step = 1, Value = { Min = 16, Max = 200, Default = 16 },
    Callback = function(value)
        local Humanoid = GetHumanoid()
        if Humanoid then Humanoid.WalkSpeed = math.clamp(tonumber(value) or 16, 16, 200) end
    end
}), "WalkSpeed")

Reg("slidjump", AddSliderCompat(movementSec, {
    Title = "JumpPower", Step = 1, Value = { Min = 50, Max = 200, Default = 50 },
    Callback = function(value)
        local Humanoid = GetHumanoid()
        if Humanoid then Humanoid.JumpPower = math.clamp(tonumber(value) or 50, 50, 200) end
    end
}), "JumpPower")

movementSec:AddButton({
    Title = "Reset Movement",
    Callback = function()
        local Humanoid = GetHumanoid()
        if Humanoid then
            Humanoid.WalkSpeed = 16; Humanoid.JumpPower = 50
            local ws = ElementRegistry["Walkspeed"]; if ws and ws.Set then ws:Set(16) end
            local jp = ElementRegistry["slidjump"]; if jp and jp.Set then jp:Set(50) end
            Notify({ Title = "Movement Direset", Description = "WalkSpeed & JumpPower Reset to default" })
        end
    end
})

Reg("frezee", movementSec:AddToggle({
    Title = "Freeze Player", Default = false,
    Callback = function(state)
        local character = LocalPlayer.Character
        if not character then return end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Anchored = state
            if state then
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                hrp.Velocity = Vector3.new(0, 0, 0)
                Notify({ Title = "Player Frozen", Description = "Posisi dikunci (Anchored)." })
            else
                Notify({ Title = "Player Unfrozen", Description = "Gerakan kembali normal." })
            end
        end
    end
}), "Freeze Player")

local abilitySec = playerTab:AddSection("Abilities")

Reg("infj", abilitySec:AddToggle({
    Title = "Infinite Jump", Default = false,
    Callback = function(state)
        if state then
            _G.InfinityJumpConnection = UserInputService.JumpRequest:Connect(function()
                local Humanoid = GetHumanoid()
                if Humanoid and Humanoid.Health > 0 then Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
            Notify({ Title = "Infinite Jump ON!", Duration = 2 })
        else
            if _G.InfinityJumpConnection then _G.InfinityJumpConnection:Disconnect(); _G.InfinityJumpConnection = nil end
            Notify({ Title = "Infinite Jump OFF!", Duration = 2 })
        end
    end
}), "Infinite Jump")

local noclipConnection = nil
local isNoClipActive = false
Reg("nclip", abilitySec:AddToggle({
    Title = "No Clip", Default = false,
    Callback = function(state)
        isNoClipActive = state
        local character = LocalPlayer.Character
        if not character then character = LocalPlayer.CharacterAdded:Wait() end
        if state then
            noclipConnection = RunService.Stepped:Connect(function()
                if isNoClipActive and character and character.Parent then
                    for _, part in ipairs(character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                    end
                end
            end)
            Notify({ Title = "No Clip ON!", Duration = 2 })
        else
            if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
            if character and character.Parent then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end
            Notify({ Title = "No Clip OFF!", Duration = 2 })
        end
    end
}), "No Clip")

Reg("walkwat", abilitySec:AddToggle({
    Title = "Walk on Water", Default = false,
    Callback = function(state)
        applyWalkOnWater(state)
        Notify({ Title = state and "Walk on Water ON!" or "Walk on Water OFF!", Duration = 2 })
    end
}), "Walk on Water")

local otherSec = playerTab:AddSection("Other")

local customName = ".gg/PahajiHub"
local customLevel = "Lvl. 969"
Reg("cfakennme", otherSec:AddInput({
    Title = "Custom Fake Name", Default = customName, Placeholder = "Hidden User",
    Callback = function(text) customName = text end
}), "Custom Fake Name")

Reg("cfkelvl", otherSec:AddInput({
    Title = "Custom Fake Level", Default = customLevel, Placeholder = "Lvl. 999",
    Callback = function(text) customLevel = text end
}), "Custom Fake Level")

local isHideActive = false
local hideConnection = nil
Reg("hideallusr", otherSec:AddToggle({
    Title = "Hide All Usernames (Streamer Mode)", Default = false,
    Callback = function(state)
        isHideActive = state
        pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not state) end)
        if state then
            Notify({ Title = "Hide Name ON", Description = "Nama & Level disamarkan." })
            if hideConnection then hideConnection:Disconnect() end
            hideConnection = RunService.RenderStepped:Connect(function()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr.Character then
                        local hum = plr.Character:FindFirstChild("Humanoid")
                        if hum and hum.DisplayName ~= customName then hum.DisplayName = customName end
                        for _, obj in ipairs(plr.Character:GetDescendants()) do
                            if obj:IsA("BillboardGui") then
                                for _, lbl in ipairs(obj:GetDescendants()) do
                                    if lbl:IsA("TextLabel") or lbl:IsA("TextButton") then
                                        if lbl.Visible then
                                            local txt = lbl.Text
                                            if txt:find(plr.Name) or txt:find(plr.DisplayName) then
                                                if txt ~= customName then lbl.Text = customName end
                                            elseif txt:match("%d+") or txt:lower():find("lvl") or txt:lower():find("level") then
                                                if #txt < 15 and txt ~= customLevel then lbl.Text = customLevel end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        else
            Notify({ Title = "Hide Name OFF", Description = "Tampilan dikembalikan." })
            if hideConnection then hideConnection:Disconnect(); hideConnection = nil end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character then
                    local hum = plr.Character:FindFirstChild("Humanoid")
                    if hum then hum.DisplayName = plr.DisplayName end
                end
            end
        end
    end
}), "Hide All Usernames (Streamer Mode)")

otherSec:AddButton({
    Title = "Reset Character (In Place)",
    Callback = function()
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not character or not hrp or not humanoid then
            Notify({ Title = "Gagal Reset", Description = "Karakter tidak ditemukan!" })
            return
        end
        local lastPos = hrp.Position
        Notify({ Title = "Reset Character...", Description = "Respawning di posisi yang sama..." })
        humanoid:TakeDamage(999999)
        LocalPlayer.CharacterAdded:Wait()
        task.wait(0.5)
        local newChar = LocalPlayer.Character
        local newHRP = newChar:WaitForChild("HumanoidRootPart", 5)
        if newHRP then
            newHRP.CFrame = CFrame.new(lastPos + Vector3.new(0, 3, 0))
            Notify({ Title = "Character Reset Sukses!", Description = "Kamu direspawn di posisi yang sama" })
        else
            Notify({ Title = "Gagal Reset", Description = "HumanoidRootPart baru tidak ditemukan." })
        end
    end
})

-- ============================================================
-- TAB: AUTOMATIC
-- ============================================================
local automaticTab = Window:AddTab({ Name = "Automatic", Icon = "loop" })

local autoSellState = false
local autoSellThread = nil
local autoSellMethod = "Delay"
local autoSellValue = 50

local function GetFishCount()
    local replion = GetPlayerDataReplion()
    if not replion then return 0 end
    local totalFishCount = 0
    local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
    if not success or not inventoryData or not inventoryData.Items or typeof(inventoryData.Items) ~= "table" then return 0 end
    for _, item in ipairs(inventoryData.Items) do
        if item.Type == "Fishing Rods" or item.Type == "Boats" or item.Type == "Bait"
            or item.Type == "Pets" or item.Type == "Chests" or item.Type == "Crates"
            or item.Type == "Totems" then continue end
        if item.Identifier and (item.Identifier:match("Artifact") or item.Identifier:match("Key")
            or item.Identifier:match("Token") or item.Identifier:match("Booster")
            or item.Identifier:match("hourglass")) then continue end
        if item.Metadata and item.Metadata.Weight or item.Type == "Fish"
            or (item.Identifier and item.Identifier:match("fish")) then
            totalFishCount = totalFishCount + (item.Count or 1)
        end
    end
    return totalFishCount
end

local function RunAutoSellLoop()
    if autoSellThread then task.cancel(autoSellThread) end
    autoSellThread = task.spawn(function()
        while autoSellState do
            if autoSellMethod == "Delay" then
                if Events.sell then pcall(function() Events.sell:InvokeServer() end) end
                task.wait(math.max(autoSellValue, 1))
            elseif autoSellMethod == "Count" then
                local currentCount = GetFishCount()
                if currentCount >= autoSellValue then
                    if Events.sell then pcall(function() Events.sell:InvokeServer() end) end
                    Notify({ Title = "Auto Sell", Description = "Menjual " .. currentCount .. " items." })
                    task.wait(2)
                end
                task.wait(1)
            end
        end
    end)
end

local sellall = automaticTab:AddSection("Autosell Fish")

Reg("sellmethod", sellall:AddDropdown({
    Title = "Select Method", Options = {"Delay", "Count"}, Default = "Delay",
    Callback = function(val)
        autoSellMethod = val
        if autoSellState then RunAutoSellLoop() end
    end
}), "Select Method")

Reg("sellval", sellall:AddInput({
    Title = "Sell Value", Default = tostring(autoSellValue), Placeholder = "50",
    Callback = function(text)
        local num = tonumber(text)
        if num then autoSellValue = num end
    end
}), "Sell Value")

local CurrentCountDisplay = sellall:AddParagraph({ Title = "Current Fish Count: 0", Content = "" })
task.spawn(function()
    while true do
        if CurrentCountDisplay and GetPlayerDataReplion() then
            pcall(function() CurrentCountDisplay:SetTitle("Current Fish Count: " .. GetFishCount()) end)
        end
        task.wait(1)
    end
end)

Reg("tsell", sellall:AddToggle({
    Title = "Enable Auto Sell", Default = false,
    Callback = function(state)
        autoSellState = state
        if state then
            if not Events.sell then
                Notify({ Title = "Error", Description = "Remote Sell tidak ditemukan." })
                return
            end
            local msg = (autoSellMethod == "Delay") and ("Setiap " .. autoSellValue .. " detik.") or ("Saat jumlah >= " .. autoSellValue)
            Notify({ Title = "Auto Sell ON (" .. autoSellMethod .. ")", Description = msg })
            RunAutoSellLoop()
        else
            Notify({ Title = "Auto Sell OFF" })
            if autoSellThread then task.cancel(autoSellThread); autoSellThread = nil end
        end
    end
}), "Enable Auto Sell")

-- Auto Favorite
local autoFavoriteState = false
local autoUnfavoriteState = false
local autoFavoriteThread = nil
local autoUnfavoriteThread = nil
local selectedRarities = {}
local selectedItemNames = {}
local selectedMutations = {}
local RE_FavoriteItem = Events.favorite

local function getAutoFavoriteItemOptions()
    local itemNames = {}
    local itemsContainer = ReplicatedStorage:FindFirstChild("Items")
    if not itemsContainer then return {"(Items container not found)"} end
    for _, itemObject in ipairs(itemsContainer:GetChildren()) do
        local itemName = itemObject.Name
        if type(itemName) == "string" and #itemName >= 3 and itemName:sub(1,3) ~= "!!!" then
            table.insert(itemNames, itemName)
        end
    end
    table.sort(itemNames)
    return #itemNames > 0 and itemNames or {"(No items found)"}
end

local function GetItemsToFavorite()
    local replion = GetPlayerDataReplion()
    if not replion or not ItemUtility or not TierUtility then return {} end
    local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
    if not success or not inventoryData or not inventoryData.Items then return {} end
    local itemsToFavorite = {}
    local isRarity = #selectedRarities > 0
    local isName = #selectedItemNames > 0
    local isMutation = #selectedMutations > 0
    if not (isRarity or isName or isMutation) then return {} end
    for _, item in ipairs(inventoryData.Items) do
        if item.IsFavorite or item.Favorited then continue end
        local itemUUID = item.UUID
        if typeof(itemUUID) ~= "string" or #itemUUID < 10 then continue end
        local name, rarity = GetFishNameAndRarity(item)
        local mutationStr = GetItemMutationString(item)
        local match = false
        if isRarity and table.find(selectedRarities, rarity) then match = true end
        if not match and isName and table.find(selectedItemNames, name) then match = true end
        if not match and isMutation and table.find(selectedMutations, mutationStr) then match = true end
        if match then table.insert(itemsToFavorite, itemUUID) end
    end
    return itemsToFavorite
end

local function GetItemsToUnfavorite()
    local replion = GetPlayerDataReplion()
    if not replion or not ItemUtility or not TierUtility then return {} end
    local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
    if not success or not inventoryData or not inventoryData.Items then return {} end
    local itemsToUnfavorite = {}
    for _, item in ipairs(inventoryData.Items) do
        if not (item.IsFavorite or item.Favorited) then continue end
        local itemUUID = item.UUID
        if typeof(itemUUID) ~= "string" or #itemUUID < 10 then continue end
        local name, rarity = GetFishNameAndRarity(item)
        local mutationStr = GetItemMutationString(item)
        local passesRarity = #selectedRarities > 0 and table.find(selectedRarities, rarity)
        local passesName = #selectedItemNames > 0 and table.find(selectedItemNames, name)
        local passesMutation = #selectedMutations > 0 and table.find(selectedMutations, mutationStr)
        if passesRarity or passesName or passesMutation then table.insert(itemsToUnfavorite, itemUUID) end
    end
    return itemsToUnfavorite
end

local function SetItemFavoriteState(itemUUID)
    if RE_FavoriteItem then pcall(function() RE_FavoriteItem:FireServer(itemUUID) end) end
end

local function RunAutoFavoriteLoop()
    if autoFavoriteThread then task.cancel(autoFavoriteThread) end
    autoFavoriteThread = task.spawn(function()
        while autoFavoriteState do
            local items = GetItemsToFavorite()
            if #items > 0 then
                Notify({ Title = "Auto Favorite", Description = "Mem-favorite " .. #items .. " item..." })
                for _, uuid in ipairs(items) do
                    SetItemFavoriteState(uuid)
                    task.wait(0.5)
                end
            end
            task.wait(1)
        end
    end)
end

local function RunAutoUnfavoriteLoop()
    if autoUnfavoriteThread then task.cancel(autoUnfavoriteThread) end
    autoUnfavoriteThread = task.spawn(function()
        while autoUnfavoriteState do
            local items = GetItemsToUnfavorite()
            if #items > 0 then
                Notify({ Title = "Auto Unfavorite", Description = "Menghapus favorite dari " .. #items .. " item..." })
                for _, uuid in ipairs(items) do
                    SetItemFavoriteState(uuid)
                    task.wait(0.5)
                end
            end
            task.wait(1)
        end
    end)
end

local favsec = automaticTab:AddSection("Auto Favorite / Unfavorite")

Reg("drer", favsec:AddDropdown({
    Title = "by Rarity", Options = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET"}, Multi = true,
    Callback = function(values) selectedRarities = values or {} end
}), "by Rarity")

local allItemNames = getAutoFavoriteItemOptions()
Reg("dtem", favsec:AddDropdown({
    Title = "by Item Name", Options = allItemNames, Multi = true,
    Callback = function(values) selectedItemNames = values or {} end
}), "by Item Name")

Reg("dmut", favsec:AddDropdown({
    Title = "by Mutation", Options = {"Shiny", "Gemstone", "Corrupt", "Galaxy", "Holographic", "Ghost", "Lightning", "Fairy Dust", "Gold", "Midnight", "Radioactive", "Stone", "Albino", "Sandy", "Acidic", "Disco", "Frozen", "Noob"}, Multi = true,
    Callback = function(values) selectedMutations = values or {} end
}), "by Mutation")

Reg("tvav", favsec:AddToggle({
    Title = "Enable Auto Favorite", Default = false,
    Callback = function(state)
        autoFavoriteState = state
        if state then
            if autoUnfavoriteState then
                autoUnfavoriteState = false
                local unfavToggle = ElementByTitle["Enable Auto Unfavorite"]
                if unfavToggle and unfavToggle.Set then unfavToggle:Set(false) end
                if autoUnfavoriteThread then task.cancel(autoUnfavoriteThread); autoUnfavoriteThread = nil end
            end
            Notify({ Title = "Auto Favorite ON!", Duration = 2 })
            RunAutoFavoriteLoop()
        else
            Notify({ Title = "Auto Favorite OFF!", Duration = 2 })
            if autoFavoriteThread then task.cancel(autoFavoriteThread); autoFavoriteThread = nil end
        end
    end
}), "Enable Auto Favorite")

Reg("tunfa", favsec:AddToggle({
    Title = "Enable Auto Unfavorite", Default = false,
    Callback = function(state)
        autoUnfavoriteState = state
        if state then
            if autoFavoriteState then
                autoFavoriteState = false
                local favToggle = ElementByTitle["Enable Auto Favorite"]
                if favToggle and favToggle.Set then favToggle:Set(false) end
                if autoFavoriteThread then task.cancel(autoFavoriteThread); autoFavoriteThread = nil end
            end
            if #selectedRarities == 0 and #selectedItemNames == 0 and #selectedMutations == 0 then
                Notify({ Title = "Peringatan!", Description = "Semua filter kosong. Non-aktifkan toggle ini." })
                return
            end
            Notify({ Title = "Auto Unfavorite ON!", Duration = 2 })
            RunAutoUnfavoriteLoop()
        else
            Notify({ Title = "Auto Unfavorite OFF!", Duration = 2 })
            if autoUnfavoriteThread then task.cancel(autoUnfavoriteThread); autoUnfavoriteThread = nil end
        end
    end
}), "Enable Auto Unfavorite")

-- ============================================================
-- TAB: TELEPORT
-- ============================================================
local teleportTab = Window:AddTab({ Name = "Teleport", Icon = "gps" })
local telearea = teleportTab:AddSection("Teleport to Fishing Area")

Reg("areadrop", telearea:AddDropdown({
    Title = "Select Target Area", Options = AreaNames,
    Callback = function(name) _G.SelectedTpArea = name end
}), "Select Target Area")

telearea:AddButton({
    Title = "Teleport to Area",
    Callback = function()
        if not _G.SelectedTpArea or not LOCATIONS[_G.SelectedTpArea] then
            Notify({ Title = "Error", Description = "Pilih area target terlebih dahulu." })
            return
        end
        local cf = LOCATIONS[_G.SelectedTpArea]
        TeleportToLookAt(cf.Position, cf.LookVector)
    end
})

-- ============================================================
-- TAB: FISHING (FIXED - THE MAIN ISSUE)
-- ============================================================
local farmTab = Window:AddTab({ Name = "Fishing", Icon = "fish" })

local legitAutoState = false
local normalInstantState = false
local blatantInstantState = false
local normalLoopThread = nil
local blatantLoopThread = nil
local normalEquipThread = nil
local blatantEquipThread = nil
local legitEquipThread = nil
local legitClickThread = nil

local RE_EquipToolFromHotbar = GetServerRemote("RF/EquipToolFromHotbar")
local RF_ChargeFishingRod = GetServerRemote("RF/ChargeFishingRod")
local RF_RequestFishingMinigameStarted = GetServerRemote("RF/RequestFishingMinigameStarted")
local RE_FishingCompleted = GetServerRemote("RE/CatchFishCompleted") or GetServerRemote("RF/CatchFishCompleted")
local RF_CancelFishingInputs = GetServerRemote("RF/CancelFishingInputs")
local RF_UpdateAutoFishingState = GetServerRemote("RF/UpdateAutoFishingState")

-- FIXED: checkFishingRemotes dengan debug notifikasi
local function checkFishingRemotes(silent)
    local remotesList = {
        { name = "RF/EquipToolFromHotbar", remote = RE_EquipToolFromHotbar },
        { name = "RF/ChargeFishingRod", remote = RF_ChargeFishingRod },
        { name = "RF/RequestFishingMinigameStarted", remote = RF_RequestFishingMinigameStarted },
        { name = "CatchFishCompleted", remote = RE_FishingCompleted },
        { name = "RF/CancelFishingInputs", remote = RF_CancelFishingInputs },
        { name = "RF/UpdateAutoFishingState", remote = RF_UpdateAutoFishingState },
    }
    for _, data in ipairs(remotesList) do
        if not data.remote then
            if not silent then
                Notify({
                    Title = "Remote Error!",
                    Description = "Remote '" .. data.name .. "' tidak ditemukan. Game mungkin baru update.",
                    Delay = 5
                })
                warn("[NYXHUB DEBUG] Missing Fishing Remote: " .. data.name)
            end
            return false
        end
    end
    return true
end

local function disableOtherModes(currentMode)
    pcall(function()
        if currentMode ~= "legit" and legitAutoState then
            legitAutoState = false
            local toggleLegit = ElementByTitle["Auto Fish (Legit)"]
            if toggleLegit and toggleLegit.Set then toggleLegit:Set(false) end
            if legitClickThread then task.cancel(legitClickThread); legitClickThread = nil end
            if legitEquipThread then task.cancel(legitEquipThread); legitEquipThread = nil end
        end
        if currentMode ~= "normal" and normalInstantState then
            normalInstantState = false
            local toggleNormal = ElementByTitle["Normal Instant Fish"]
            if toggleNormal and toggleNormal.Set then toggleNormal:Set(false) end
            if normalLoopThread then task.cancel(normalLoopThread); normalLoopThread = nil end
            if normalEquipThread then task.cancel(normalEquipThread); normalEquipThread = nil end
        end
        if currentMode ~= "blatant" and blatantInstantState then
            blatantInstantState = false
            local toggleBlatant = ElementByTitle["Instant Fishing (Blatant)"]
            if toggleBlatant and toggleBlatant.Set then toggleBlatant:Set(false) end
            if blatantLoopThread then task.cancel(blatantLoopThread); blatantLoopThread = nil end
            if blatantEquipThread then task.cancel(blatantEquipThread); blatantEquipThread = nil end
        end
    end)
    if currentMode ~= "legit" then
        pcall(function() if RF_UpdateAutoFishingState then RF_UpdateAutoFishingState:InvokeServer(false) end end)
    end
end

-- Auto Fish (Legit)
local AutoFishState = { IsActive = false, MinigameActive = false }
local SPEED_LEGIT = 0.05

local function performClick()
    if FishingController then
        pcall(function() FishingController:RequestFishingMinigameClick() end)
        task.wait(SPEED_LEGIT)
    end
end

if FishingController then
    local originalRodStarted = FishingController.FishingRodStarted
    FishingController.FishingRodStarted = function(self, arg1, arg2)
        pcall(function() originalRodStarted(self, arg1, arg2) end)
        if AutoFishState.IsActive and not AutoFishState.MinigameActive then
            AutoFishState.MinigameActive = true
            if legitClickThread then task.cancel(legitClickThread) end
            legitClickThread = task.spawn(function()
                while AutoFishState.IsActive and AutoFishState.MinigameActive do
                    performClick()
                end
            end)
        end
    end
    
    local originalFishingStopped = FishingController.FishingStopped
    FishingController.FishingStopped = function(self, arg1)
        pcall(function() originalFishingStopped(self, arg1) end)
        if AutoFishState.MinigameActive then AutoFishState.MinigameActive = false end
    end
end

local function ensureServerAutoFishingOn()
    if RF_UpdateAutoFishingState then
        pcall(function() RF_UpdateAutoFishingState:InvokeServer(true) end)
    end
end

local function ToggleAutoClick(shouldActivate)
    if not FishingController then return end
    AutoFishState.IsActive = shouldActivate
    local playerGuiLocal = LocalPlayer:WaitForChild("PlayerGui")
    local fishingGui = playerGuiLocal:FindFirstChild("Fishing") and playerGuiLocal.Fishing:FindFirstChild("Main")
    local chargeGui = playerGuiLocal:FindFirstChild("Charge") and playerGuiLocal.Charge:FindFirstChild("Main")
    if shouldActivate then
        pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)
        ensureServerAutoFishingOn()
        if fishingGui then fishingGui.Visible = false end
        if chargeGui then chargeGui.Visible = false end
        Notify({ Title = "Auto Fish Legit ON!", Description = "Auto-Equip Protection Active." })
    else
        if legitClickThread then task.cancel(legitClickThread); legitClickThread = nil end
        AutoFishState.MinigameActive = false
        if fishingGui then fishingGui.Visible = true end
        if chargeGui then chargeGui.Visible = true end
        Notify({ Title = "Auto Fish Legit OFF!" })
    end
end

local autofish = farmTab:AddSection("Auto Fishing")

Reg("klikd", AddSliderCompat(autofish, {
    Title = "Legit Click Speed (Delay)", Step = 0.01,
    Value = { Min = 0.01, Max = 0.5, Default = SPEED_LEGIT },
    Callback = function(value) SPEED_LEGIT = tonumber(value) or 0.05 end
}), "Legit Click Speed (Delay)")

Reg("legit", autofish:AddToggle({
    Title = "Auto Fish (Legit)", Default = false,
    Callback = function(state)
        if not checkFishingRemotes() then return false end
        disableOtherModes("legit")
        legitAutoState = state
        ToggleAutoClick(state)
        if state then
            if legitEquipThread then task.cancel(legitEquipThread) end
            legitEquipThread = task.spawn(function()
                while legitAutoState do
                    pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)
                    task.wait(0.1)
                end
            end)
        else
            if legitEquipThread then task.cancel(legitEquipThread); legitEquipThread = nil end
        end
    end
}), "Auto Fish (Legit)")

-- Normal Instant Fish
local normalCompleteDelay = 1.50

Reg("normalslid", AddSliderCompat(autofish, {
    Title = "Normal Complete Delay", Step = 0.05,
    Value = { Min = 0.5, Max = 5.0, Default = normalCompleteDelay },
    Callback = function(value) normalCompleteDelay = tonumber(value) or 1.50 end
}), "Normal Complete Delay")

local function runNormalInstant()
    if not normalInstantState then return end
    if not checkFishingRemotes(true) then normalInstantState = false; return end
    local timestamp = os.time() + os.clock()
    pcall(function() RF_ChargeFishingRod:InvokeServer(timestamp) end)
    pcall(function() RF_RequestFishingMinigameStarted:InvokeServer(-139.630452165, 0.99647927980797) end)
    task.wait(normalCompleteDelay)
    pcall(function() RE_FishingCompleted:FireServer() end)
    task.wait(0.1) -- FIXED: was 0.000000001, caused executor throttle
    pcall(function() RF_CancelFishingInputs:InvokeServer() end)
end

Reg("tognorm", autofish:AddToggle({
    Title = "Normal Instant Fish", Default = false,
    Callback = function(state)
        if not checkFishingRemotes() then return end
        disableOtherModes("normal")
        normalInstantState = state
        if state then
            normalLoopThread = task.spawn(function()
                while normalInstantState do
                    runNormalInstant()
                    task.wait(0.1) -- FIXED: was 0.000000001
                end
            end)
            if normalEquipThread then task.cancel(normalEquipThread) end
            normalEquipThread = task.spawn(function()
                while normalInstantState do
                    pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)
                    task.wait(0.1)
                end
            end)
            Notify({ Title = "Normal Instant ON", Description = "Auto-Equip Protection Active." })
        else
            if normalLoopThread then task.cancel(normalLoopThread); normalLoopThread = nil end
            if normalEquipThread then task.cancel(normalEquipThread); normalEquipThread = nil end
            pcall(function() RE_EquipToolFromHotbar:FireServer(0) end)
            Notify({ Title = "Normal Instant OFF" })
        end
    end
}), "Normal Instant Fish")

-- Blatant Mode
local blatant = farmTab:AddSection("Blatant Mode")
local completeDelay = 3.055
local cancelDelay = 0.3
local loopInterval = 1.715

_G.PahajiHub_BlatantActive = false
task.spawn(function()
    local S1, FC = pcall(function() return require(ReplicatedStorage.Controllers.FishingController) end)
    if S1 and FC then
        local Old_Charge = FC.RequestChargeFishingRod
        local Old_Cast = FC.SendFishingRequestToServer
        FC.RequestChargeFishingRod = function(...) if _G.PahajiHub_BlatantActive then return end return Old_Charge(...) end
        FC.SendFishingRequestToServer = function(...) if _G.PahajiHub_BlatantActive then return false, "Blocked" end return Old_Cast(...) end
    end
end)

local mt = getrawmetatable(game)
local old_namecall = mt.__namecall
setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if _G.PahajiHub_BlatantActive and not checkcaller() then
        if method == "InvokeServer" and (self.Name == "RequestFishingMinigameStarted" or self.Name == "ChargeFishingRod" or self.Name == "UpdateAutoFishingState") then return nil end
        if method == "FireServer" and self.Name == "FishingCompleted" then return nil end
    end
    return old_namecall(self, ...)
end)
setreadonly(mt, true)

local function SuppressGameVisuals(active)
    local Succ, TextController = pcall(function() return require(ReplicatedStorage.Controllers.TextNotificationController) end)
    if Succ and TextController then
        if active then
            if not TextController._OldDeliver then TextController._OldDeliver = TextController.DeliverNotification end
            TextController.DeliverNotification = function(self, data)
                if data and data.Text and (string.find(tostring(data.Text), "Auto Fishing") or string.find(tostring(data.Text), "Reach Level")) then return end
                return TextController._OldDeliver(self, data)
            end
        elseif TextController._OldDeliver then
            TextController.DeliverNotification = TextController._OldDeliver
            TextController._OldDeliver = nil
        end
    end
end

Reg("blatantint", blatant:AddInput({
    Title = "Blatant Interval", Default = tostring(loopInterval),
    Callback = function(input)
        local newInterval = tonumber(input)
        if newInterval and newInterval >= 0.5 then loopInterval = newInterval end
    end
}), "Blatant Interval")

Reg("blatantcom", blatant:AddInput({
    Title = "Complete Delay", Default = tostring(completeDelay),
    Callback = function(input)
        local newDelay = tonumber(input)
        if newDelay and newDelay >= 0.5 then completeDelay = newDelay end
    end
}), "Complete Delay")

Reg("blatantcanc", blatant:AddInput({
    Title = "Cancel Delay", Default = tostring(cancelDelay),
    Callback = function(input)
        local newDelay = tonumber(input)
        if newDelay and newDelay >= 0.1 then cancelDelay = newDelay end
    end
}), "Cancel Delay")

local function runBlatantInstant()
    if not blatantInstantState then return end
    if not checkFishingRemotes(true) then blatantInstantState = false; return end
    task.spawn(function()
        local startTime = os.clock()
        local timestamp = os.time() + os.clock()
        pcall(function() RF_ChargeFishingRod:InvokeServer(timestamp) end)
        task.wait(0.001)
        pcall(function() RF_RequestFishingMinigameStarted:InvokeServer(-139.6379699707, 0.99647927980797) end)
        local completeWaitTime = completeDelay - (os.clock() - startTime)
        if completeWaitTime > 0 then task.wait(completeWaitTime) end
        pcall(function() RE_FishingCompleted:FireServer() end)
        task.wait(cancelDelay)
        pcall(function() RF_CancelFishingInputs:InvokeServer() end)
    end)
end

Reg("blatantt", blatant:AddToggle({
    Title = "Instant Fishing (Blatant)", Default = false,
    Callback = function(state)
        if not checkFishingRemotes() then return end
        disableOtherModes("blatant")
        blatantInstantState = state
        _G.PahajiHub_BlatantActive = state
        SuppressGameVisuals(state)
        if state then
            if RF_UpdateAutoFishingState then
                pcall(function() RF_UpdateAutoFishingState:InvokeServer(true) end)
                task.wait(0.1)
                pcall(function() RF_UpdateAutoFishingState:InvokeServer(true) end)
            end
            blatantLoopThread = task.spawn(function()
                while blatantInstantState do
                    runBlatantInstant()
                    task.wait(loopInterval)
                end
            end)
            if blatantEquipThread then task.cancel(blatantEquipThread) end
            blatantEquipThread = task.spawn(function()
                while blatantInstantState do
                    pcall(function() RE_EquipToolFromHotbar:FireServer(1) end)
                    task.wait(0.1)
                end
            end)
            Notify({ Title = "Blatant Mode ON" })
        else
            if RF_UpdateAutoFishingState then pcall(function() RF_UpdateAutoFishingState:InvokeServer(false) end) end
            if blatantLoopThread then task.cancel(blatantLoopThread); blatantLoopThread = nil end
            if blatantEquipThread then task.cancel(blatantEquipThread); blatantEquipThread = nil end
            Notify({ Title = "Blatant Mode OFF" })
        end
    end
}), "Instant Fishing (Blatant)")

-- Fishing Area
local areafish = farmTab:AddSection("Fishing Area")
local isTeleportFreezeActive = false
local selectedArea = nil
local savedPosition = nil

Reg("choosearea", areafish:AddDropdown({
    Title = "Choose Area", Options = AreaNames,
    Callback = function(option) selectedArea = option end
}), "Choose Area")

local freezeToggle
freezeToggle = Reg("freezearea", areafish:AddToggle({
    Title = "Teleport & Freeze at Area", Default = false,
    Callback = function(state)
        isTeleportFreezeActive = state
        local hrp = GetHRP()
        if not hrp then
            if freezeToggle and freezeToggle.Set then freezeToggle:Set(false) end
            return
        end
        if state then
            if not selectedArea then
                Notify({ Title = "Aksi Gagal", Description = "Pilih Area dulu di Dropdown!" })
                if freezeToggle and freezeToggle.Set then freezeToggle:Set(false) end
                return
            end
            local cf = LOCATIONS[selectedArea]
            if not cf then
                Notify({ Title = "Aksi Gagal", Description = "Data area tidak valid." })
                if freezeToggle and freezeToggle.Set then freezeToggle:Set(false) end
                return
            end
            hrp.Anchored = false
            TeleportToLookAt(cf.Position, cf.LookVector)
            Notify({ Title = "Syncing Zone...", Description = "Menahan posisi agar server update..." })
            task.spawn(function()
                local startTime = os.clock()
                while (os.clock() - startTime) < 1.5 and isTeleportFreezeActive do
                    if hrp and hrp.Parent then
                        hrp.Velocity = Vector3.new(0,0,0)
                        hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                        hrp.CFrame = CFrame.new(cf.Position, cf.Position + cf.LookVector) * CFrame.new(0, 0.5, 0)
                    end
                    RunService.Heartbeat:Wait()
                end
                if isTeleportFreezeActive and hrp and hrp.Parent then
                    hrp.Anchored = true
                    Notify({ Title = "Ready to Fish", Description = "Posisi dikunci & Zona terupdate." })
                end
            end)
        else
            if hrp then hrp.Anchored = false end
            Notify({ Title = "Unfrozen", Description = "Gerakan kembali normal." })
        end
    end
}), "Teleport & Freeze at Area")

areafish:AddButton({
    Title = "Teleport to Chosen Area",
    Callback = function()
        if not selectedArea then
            Notify({ Title = "Teleport Gagal", Description = "Pilih Area dulu di Dropdown." })
            return
        end
        local cf = LOCATIONS[selectedArea]
        if isTeleportFreezeActive and freezeToggle then freezeToggle:Set(false); task.wait(0.1) end
        TeleportToLookAt(cf.Position, cf.LookVector)
    end
})

areafish:AddButton({
    Title = "Save Current Position",
    Callback = function()
        local hrp = GetHRP()
        if hrp then
            savedPosition = { Pos = hrp.Position, Look = hrp.CFrame.LookVector }
            LOCATIONS["Custom: Saved"] = CFrame.new(savedPosition.Pos, savedPosition.Pos + savedPosition.Look)
            local newValues = {}
            for name, _ in pairs(LOCATIONS) do table.insert(newValues, name) end
            table.sort(newValues)
            local dd = ElementRegistry["choosearea"]
            if dd and dd.Refresh then pcall(function() dd:Refresh(newValues) end) end
            Notify({ Title = "Posisi Disimpan!", Description = "Gunakan 'Custom: Saved' di dropdown." })
        else
            Notify({ Title = "Gagal Simpan" })
        end
    end
})

-- Ultra Blatant 3N
local UBSection = farmTab:AddSection("Ultra Blatant 3N")

Reg("ubcom", UBSection:AddInput({
    Title = "Complete Delay", Default = tostring(Config.UB.Settings.CompleteDelay),
    Callback = function(Value)
        local num = tonumber(Value)
        if num then Config.UB.Settings.CompleteDelay = num end
    end
}), "UB Complete Delay")

Reg("ubcanc", UBSection:AddInput({
    Title = "Cancel Delay", Default = tostring(Config.UB.Settings.CancelDelay),
    Callback = function(Value)
        local num = tonumber(Value)
        if num then Config.UB.Settings.CancelDelay = num end
    end
}), "UB Cancel Delay")

Reg("ubtogg", UBSection:AddToggle({
    Title = "Enable Blatant 3N", Default = false,
    Callback = function(Value)
        if Value then onToggleUB(true) else onToggleUB(false) end
    end
}), "Enable Blatant 3N")

-- ============================================================
-- TAB: TOOLS
-- ============================================================
local toolsTab = Window:AddTab({ Name = "Tools", Icon = "settings" })
local miscSec = toolsTab:AddSection("Misc. Area")

local RF_UpdateFishingRadar = GetServerRemote("RF/UpdateFishingRadar")
miscSec:AddToggle({
    Title = "Enable Fishing Radar", Default = false,
    Callback = function(state)
        if not RF_UpdateFishingRadar then
            Notify({ Title = "Error", Description = "Remote 'RF/UpdateFishingRadar' tidak ditemukan." })
            return false
        end
        pcall(function() RF_UpdateFishingRadar:InvokeServer(state) end)
        Notify({ Title = state and "Fishing Radar ON" or "Fishing Radar OFF" })
    end
})

local RF_EquipOxygenTank = GetServerRemote("RF/EquipOxygenTank")
local RF_UnequipOxygenTank = GetServerRemote("RF/UnequipOxygenTank")
Reg("infox", miscSec:AddToggle({
    Title = "Equip Oxygen Tank", Default = false,
    Callback = function(state)
        if state then
            if not RF_EquipOxygenTank then
                Notify({ Title = "Error", Description = "Remote tidak ditemukan." })
                return false
            end
            pcall(function() RF_EquipOxygenTank:InvokeServer(105) end)
            Notify({ Title = "Oxygen Tank Equipped" })
        else
            if not RF_UnequipOxygenTank then return true end
            pcall(function() RF_UnequipOxygenTank:InvokeServer() end)
            Notify({ Title = "Oxygen Tank Unequipped" })
        end
    end
}), "Equip Oxygen Tank")

Reg("Toggleanim", miscSec:AddToggle({
    Title = "No Animation", Default = false,
    Callback = function(state)
        applyNoAnimation(state)
        Notify({ Title = state and "No Animation ON!" or "No Animation OFF!" })
    end
}), "No Animation")

local VFXControllerModule
pcall(function() VFXControllerModule = require(ReplicatedStorage.Controllers.VFXController) end)
local originalVFXHandle = VFXControllerModule and VFXControllerModule.Handle

Reg("toggleskin", miscSec:AddToggle({
    Title = "Remove Skin Effect", Default = false,
    Callback = function(state)
        if not VFXControllerModule then
            Notify({ Title = "Error", Description = "VFXController tidak ditemukan." })
            return
        end
        if state then
            VFXControllerModule.Handle = function(...) end
            if VFXControllerModule.RenderAtPoint then VFXControllerModule.RenderAtPoint = function(...) end end
            if VFXControllerModule.RenderInstance then VFXControllerModule.RenderInstance = function(...) end end
            local cosmeticFolder = workspace:FindFirstChild("CosmeticFolder")
            if cosmeticFolder then pcall(function() cosmeticFolder:ClearAllChildren() end) end
            Notify({ Title = "No Skin Effect ON" })
        else
            VFXControllerModule.Handle = originalVFXHandle
            Notify({ Title = "No Skin Effect OFF" })
        end
    end
}), "Remove Skin Effect")

local CutsceneControllerModule = nil
local OldPlayCutscene = nil
local isNoCutsceneActive = false
pcall(function()
    CutsceneControllerModule = require(ReplicatedStorage.Controllers.CutsceneController)
    if CutsceneControllerModule and CutsceneControllerModule.Play then
        OldPlayCutscene = CutsceneControllerModule.Play
        CutsceneControllerModule.Play = function(self, ...)
            if isNoCutsceneActive then return end
            return OldPlayCutscene(self, ...)
        end
    end
end)

Reg("tnocut", miscSec:AddToggle({
    Title = "No Cutscene", Default = false,
    Callback = function(state)
        isNoCutsceneActive = state
        if not CutsceneControllerModule then
            Notify({ Title = "Gagal Hook", Description = "Module CutsceneController tidak ditemukan." })
            return
        end
        Notify({ Title = state and "No Cutscene ON" or "No Cutscene OFF" })
    end
}), "No Cutscene")

local defaultMaxZoom = LocalPlayer.CameraMaxZoomDistance or 128
local zoomLoopConnection = nil
Reg("infzoom", miscSec:AddToggle({
    Title = "Infinite Zoom Out", Default = false,
    Callback = function(state)
        if state then
            defaultMaxZoom = LocalPlayer.CameraMaxZoomDistance
            LocalPlayer.CameraMaxZoomDistance = 100000
            if zoomLoopConnection then zoomLoopConnection:Disconnect() end
            zoomLoopConnection = RunService.RenderStepped:Connect(function()
                LocalPlayer.CameraMaxZoomDistance = 100000
            end)
            Notify({ Title = "Zoom Unlocked" })
        else
            if zoomLoopConnection then zoomLoopConnection:Disconnect(); zoomLoopConnection = nil end
            LocalPlayer.CameraMaxZoomDistance = defaultMaxZoom
            Notify({ Title = "Zoom Normal" })
        end
    end
}), "Infinite Zoom Out")

local isBoostActive = false
local originalLightingValues = {}
local function ToggleFPSBoost(enabled)
    isBoostActive = enabled
    local Terrain = workspace:FindFirstChildOfClass("Terrain")
    if enabled then
        if not next(originalLightingValues) then
            originalLightingValues.GlobalShadows = Lighting.GlobalShadows
            originalLightingValues.FogEnd = Lighting.FogEnd
            originalLightingValues.Brightness = Lighting.Brightness
            originalLightingValues.ClockTime = Lighting.ClockTime
            originalLightingValues.Ambient = Lighting.Ambient
            originalLightingValues.OutdoorAmbient = Lighting.OutdoorAmbient
        end
        pcall(function()
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Explosion") then
                    v.Enabled = false
                elseif v:IsA("Beam") or v:IsA("Light") then
                    v.Enabled = false
                elseif v:IsA("Decal") or v:IsA("Texture") then
                    v.Transparency = 1
                end
            end
        end)
        pcall(function()
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then effect.Enabled = false end
            end
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.Brightness = 0
            Lighting.ClockTime = 14
            Lighting.Ambient = Color3.new(0, 0, 0)
            Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
        end)
        if Terrain then
            pcall(function()
                Terrain.WaterWaveSize = 0
                Terrain.WaterWaveSpeed = 0
                Terrain.WaterReflectance = 0
                Terrain.WaterTransparency = 1
                Terrain.Decoration = false
            end)
        end
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
            settings().Rendering.TextureQuality = Enum.TextureQuality.Low
        end)
        if type(setfpscap) == "function" then pcall(function() setfpscap(100) end) end
        if type(collectgarbage) == "function" then collectgarbage("collect") end
        Notify({ Title = "FPS Boost", Description = "Maximum FPS mode enabled." })
    else
        pcall(function()
            if originalLightingValues.GlobalShadows ~= nil then
                Lighting.GlobalShadows = originalLightingValues.GlobalShadows
                Lighting.FogEnd = originalLightingValues.FogEnd
                Lighting.Brightness = originalLightingValues.Brightness
                Lighting.ClockTime = originalLightingValues.ClockTime
                Lighting.Ambient = originalLightingValues.Ambient
                Lighting.OutdoorAmbient = originalLightingValues.OutdoorAmbient
            end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then effect.Enabled = true end
            end
        end)
        if type(setfpscap) == "function" then pcall(function() setfpscap(60) end) end
        Notify({ Title = "FPS Boost", Description = "Graphics reset to default." })
    end
end

Reg("togfps", miscSec:AddToggle({
    Title = "FPS Ultra Boost", Default = false,
    Callback = function(state) ToggleFPSBoost(state) end
}), "FPS Ultra Boost")

-- Server Management
local serverm = toolsTab:AddSection("Server Management")

serverm:AddButton({
    Title = "Rejoin Server",
    Callback = function()
        Notify({ Title = "Rejoining...", Description = "Tunggu sebentar..." })
        if #Players:GetPlayers() <= 1 then
            LocalPlayer:Kick("[NYXHUB] Rejoining...")
            task.wait()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end
})

serverm:AddButton({
    Title = "Server Hop (Random)",
    Callback = function()
        Notify({ Title = "Hopping...", Description = "Mencari server baru..." })
        task.spawn(function()
            local PlaceId = game.PlaceId
            local JobId = game.JobId
            local sfUrl = "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"
            local req = game:HttpGet(string.format(sfUrl, PlaceId))
            local body = HttpService:JSONDecode(req)
            if body and body.data then
                local servers = {}
                for _, v in ipairs(body.data) do
                    if type(v) == "table" and v.maxPlayers > v.playing and v.id ~= JobId then
                        table.insert(servers, v.id)
                    end
                end
                if #servers > 0 then
                    local randomServerId = servers[math.random(1, #servers)]
                    Notify({ Title = "Server Found", Description = "Teleporting..." })
                    TeleportService:TeleportToPlaceInstance(PlaceId, randomServerId, LocalPlayer)
                else
                    Notify({ Title = "Gagal Hop", Description = "Tidak menemukan server lain yang cocok." })
                end
            else
                Notify({ Title = "API Error", Description = "Gagal mengambil daftar server." })
            end
        end)
    end
})

local targetJoinID = ""
Reg("injobid", serverm:AddInput({
    Title = "Target Job ID", Default = "", Placeholder = "Paste Job ID here...",
    Callback = function(text) targetJoinID = text end
}), "Target Job ID")

serverm:AddButton({
    Title = "Join Server by ID",
    Callback = function()
        if targetJoinID == "" then
            Notify({ Title = "Error", Description = "Masukkan Job ID dulu!" })
            return
        end
        if targetJoinID == game.JobId then
            Notify({ Title = "Info", Description = "Kamu sudah berada di server ini!" })
            return
        end
        Notify({ Title = "Joining...", Description = "Mencoba masuk ke server ID..." })
        local success, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, targetJoinID, LocalPlayer)
        end)
        if not success then
            Notify({ Title = "Gagal", Description = "ID Server Salah / Server Penuh / Expired." })
        end
    end
})

-- ============================================================
-- TAB: WEBHOOK
-- ============================================================
local webhookTab = Window:AddTab({ Name = "Webhook", Icon = "send" })
local webhooksec = webhookTab:AddSection("Webhook Setup")

local WEBHOOK_URL = ""
local WEBHOOK_USERNAME = "NYXHUB Notify"
local isWebhookEnabled = false
local SelectedRarityCategories = {}
local SelectedWebhookItemNames = {}

local function getWebhookItemOptions()
    local itemNames = {}
    local itemsContainer = ReplicatedStorage:FindFirstChild("Items")
    if itemsContainer then
        for _, itemObject in ipairs(itemsContainer:GetChildren()) do
            local itemName = itemObject.Name
            if type(itemName) == "string" and #itemName >= 3 and itemName:sub(1, 3) ~= "!!!" then
                table.insert(itemNames, itemName)
            end
        end
    end
    table.sort(itemNames)
    return itemNames
end

local RarityList = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Trophy", "Collectible", "DEV"}

local WebhookStatusParagraph = webhooksec:AddParagraph({
    Title = "Webhook Status",
    Content = "Aktifkan 'Enable Fish Notifications' untuk mulai mendengarkan tangkapan ikan."
})

local function UpdateWebhookStatus(title, content)
    if WebhookStatusParagraph then
        pcall(function()
            WebhookStatusParagraph:SetTitle(title)
            WebhookStatusParagraph:SetContent(content)
        end)
    end
end

local function shouldNotify(fishRarityUpper, fishMetadata, fishName)
    if #SelectedRarityCategories > 0 and table.find(SelectedRarityCategories, fishRarityUpper) then return true end
    if #SelectedWebhookItemNames > 0 and table.find(SelectedWebhookItemNames, fishName) then return true end
    return false
end

local function onFishObtained(itemId, metadata, fullData)
    local success, results = pcall(function()
        local dummyItem = {Id = itemId, Metadata = metadata}
        local fishName, fishRarity = GetFishNameAndRarity(dummyItem)
        local fishRarityUpper = fishRarity:upper()
        local fishWeight = string.format("%.2fkg", metadata.Weight or 0)
        local mutationString = GetItemMutationString(dummyItem)
        local mutationDisplay = mutationString ~= "" and mutationString or "N/A"
        local itemData = ItemUtility and ItemUtility:GetItemData(itemId)
        local assetId = nil
        if itemData and itemData.Data then
            local iconRaw = itemData.Data.Icon or itemData.Data.ImageId
            if iconRaw then assetId = tonumber(string.match(tostring(iconRaw), "%d+")) end
        end
        local imageUrl = assetId and GetRobloxAssetImage(assetId) or "https://tr.rbxcdn.com/53eb9b170bea9855c45c9356fb33c070/420/420/Image/Png"
        
        local isUserFilterMatch = shouldNotify(fishRarityUpper, metadata, fishName)
        if isWebhookEnabled and WEBHOOK_URL ~= "" and isUserFilterMatch then
            local embed = {
                title = "NYXHUB | New Fish Caught! (" .. fishName .. ")",
                description = "Found by **" .. (LocalPlayer.DisplayName or LocalPlayer.Name) .. "**.",
                color = getRarityColor(fishRarityUpper),
                fields = {
                    { name = "Fish Name", value = "`" .. fishName .. "`", inline = true },
                    { name = "Rarity", value = "`" .. fishRarityUpper .. "`", inline = true },
                    { name = "Weight", value = "`" .. fishWeight .. "`", inline = true },
                    { name = "Mutation", value = "`" .. mutationDisplay .. "`", inline = true },
                },
                thumbnail = { url = imageUrl },
                footer = { text = "NYXHUB Webhook • " .. os.date("%Y-%m-%d %H:%M:%S") }
            }
            local success_send, message = sendExploitWebhook(WEBHOOK_URL, WEBHOOK_USERNAME, embed)
            if success_send then
                UpdateWebhookStatus("Webhook Aktif", "Terkirim: " .. fishName)
            else
                UpdateWebhookStatus("Webhook Gagal", "Error: " .. tostring(message))
            end
        end
        return true
    end)
    if not success then warn("[NYXHUB Webhook] Error:", results) end
end

local REObtainedNewFishNotification = GetServerRemote("RE/ObtainedNewFishNotification")
if REObtainedNewFishNotification then
    REObtainedNewFishNotification.OnClientEvent:Connect(function(itemId, metadata, fullData)
        pcall(function() onFishObtained(itemId, metadata, fullData) end)
    end)
end

Reg("inptweb", webhooksec:AddInput({
    Title = "Discord Webhook URL", Default = "", Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(input) WEBHOOK_URL = input end
}), "Discord Webhook URL")

Reg("tweb", webhooksec:AddToggle({
    Title = "Enable Fish Notifications", Default = false,
    Callback = function(state)
        isWebhookEnabled = state
        if state then
            if WEBHOOK_URL == "" or not WEBHOOK_URL:find("discord.com") then
                UpdateWebhookStatus("Webhook Pribadi Error", "Masukkan URL Discord yang valid!")
                return false
            end
            Notify({ Title = "Webhook ON!" })
            UpdateWebhookStatus("Status: Listening", "Menunggu tangkapan ikan...")
        else
            Notify({ Title = "Webhook OFF!" })
            UpdateWebhookStatus("Webhook Status", "Aktifkan 'Enable Fish Notifications' untuk mulai mendengarkan.")
        end
    end
}), "Enable Fish Notifications")

Reg("drweb", webhooksec:AddDropdown({
    Title = "Filter by Specific Name", Options = getWebhookItemOptions(), Multi = true,
    Callback = function(names) SelectedWebhookItemNames = names or {} end
}), "Filter by Specific Name")

Reg("rarwebd", webhooksec:AddDropdown({
    Title = "Rarity to Notify", Options = RarityList, Multi = true,
    Callback = function(categories)
        SelectedRarityCategories = {}
        for _, cat in ipairs(categories or {}) do
            table.insert(SelectedRarityCategories, cat:upper())
        end
    end
}), "Rarity to Notify")

webhooksec:AddButton({
    Title = "Test Webhook",
    Callback = function()
        if WEBHOOK_URL == "" then
            Notify({ Title = "Error", Description = "Masukkan URL Webhook terlebih dahulu." })
            return
        end
        local testEmbed = {
            title = "NYXHUB Webhook Test",
            description = "Success",
            color = 0x00FF00,
            fields = {
                { name = "Name Player", value = LocalPlayer.DisplayName or LocalPlayer.Name, inline = true },
                { name = "Status", value = "Success", inline = true },
            },
            footer = { text = "NYXHUB Webhook Test" }
        }
        local success, message = sendExploitWebhook(WEBHOOK_URL, WEBHOOK_USERNAME, testEmbed)
        if success then
            Notify({ Title = "Test Sukses!", Description = "Cek channel Discord Anda." })
        else
            Notify({ Title = "Test Gagal!", Description = "Error: " .. tostring(message) })
        end
    end
})

-- ============================================================
-- TAB: CONFIGURATION
-- ============================================================
local ConfigFolder = "ftgshub_configs/"
if not isfolder(ConfigFolder) then makefolder(ConfigFolder) end

local SelectedConfigName = "nyxhub"
local configTab = Window:AddTab({ Name = "Configuration", Icon = "settings" })
local configSec = configTab:AddSection("Config Manager")

local function RefreshConfigList(dropdown)
    local list = {"nyxhub"}
    local success, files = pcall(listfiles, ConfigFolder)
    if success then
        for _, file in ipairs(files) do
            if string.find(file, ".json") then
                local name = string.gsub(string.gsub(file, ConfigFolder, ""), ".json", "")
                if name ~= "nyxhub" then table.insert(list, name) end
            end
        end
    end
    if dropdown and dropdown.Refresh then pcall(function() dropdown:Refresh(list) end) end
end

Reg("cfgname", configSec:AddInput({
    Title = "Config Name", Default = "nyxhub", Placeholder = "e.g. LegitFarming",
    Callback = function(text) SelectedConfigName = text end
}), "Config Name")

local cfgDrop = Reg("cfgdrop", configSec:AddDropdown({
    Title = "Available Configs", Options = {"nyxhub"},
    Callback = function(val)
        if val and val ~= "None" then
            SelectedConfigName = val
            local nameInput = ElementRegistry["cfgname"]
            if nameInput and nameInput.SetValue then pcall(function() nameInput:SetValue(val) end) end
        end
    end
}), "Available Configs")

configSec:AddButton({
    Title = "Refresh List",
    Callback = function() RefreshConfigList(cfgDrop) end
})

configSec:AddButton({
    Title = "Save Config",
    Callback = function()
        if SelectedConfigName == "" or SelectedConfigName == "None" then
            Notify({ Title = "Error", Description = "Nama config tidak boleh kosong." })
            return
        end
        local safeName = SelectedConfigName:gsub("[^%w_%.%-]", "")
        if safeName == "" then safeName = "config_" .. tostring(math.random(1000, 9999)) end
        local targetPath = ConfigFolder .. safeName .. ".json"
        local configData = {}
        for id, element in pairs(ElementRegistry) do
            pcall(function()
                local val = nil
                if element.GetValue then
                    local ok, v = pcall(function() return element:GetValue() end)
                    if ok then val = v end
                end
                if val == nil then val = element.Value end
                configData[id] = val
            end)
        end
        local success, err = pcall(function()
            writefile(targetPath, HttpService:JSONEncode(configData))
        end)
        if success then
            Notify({ Title = "Saved!", Description = "Config: " .. safeName })
            RefreshConfigList(cfgDrop)
        else
            Notify({ Title = "Error Write", Description = tostring(err) })
        end
    end
})

configSec:AddButton({
    Title = "Load Config",
    Callback = function()
        if SelectedConfigName == "" or SelectedConfigName == "None" then return end
        local path = ConfigFolder .. SelectedConfigName .. ".json"
        if not isfile(path) then
            Notify({ Title = "Gagal Load", Description = "File tidak ditemukan: " .. SelectedConfigName })
            return
        end
        local content = readfile(path)
        local success, decodedData = pcall(function() return HttpService:JSONDecode(content) end)
        if not success or not decodedData then
            Notify({ Title = "Gagal Load", Description = "File JSON rusak/kosong." })
            return
        end
        local changeCount = 0
        for id, val in pairs(decodedData) do
            local element = ElementRegistry[id]
            if element then
                pcall(function()
                    if element.SetValue then element:SetValue(val) end
                end)
                changeCount = changeCount + 1
            end
        end
        Notify({ Title = "Config Loaded", Description = string.format("Updated: %d settings", changeCount) })
    end
})

configSec:AddButton({
    Title = "Delete Config",
    Callback = function()
        if SelectedConfigName == "" or SelectedConfigName == "nyxhub" or SelectedConfigName == "None" then
            Notify({ Title = "Gagal", Description = "Tidak bisa hapus config default/kosong." })
            return
        end
        local path = ConfigFolder .. SelectedConfigName .. ".json"
        if isfile(path) then
            pcall(function() delfile(path) end)
            Notify({ Title = "Deleted", Description = SelectedConfigName .. " dihapus." })
            RefreshConfigList(cfgDrop)
            local nameInput = ElementRegistry["cfgname"]
            if nameInput and nameInput.SetValue then pcall(function() nameInput:SetValue("nyxhub") end) end
            SelectedConfigName = "nyxhub"
        else
            Notify({ Title = "Error", Description = "File tidak ditemukan." })
        end
    end
})

-- ============================================================
-- FINALIZE
-- ============================================================
Library:Initialize()

Notify({
    Title = "NYXHUB Loaded",
    Description = "Semua fitur berhasil dimuat tanpa error!",
    Color = Library.colors.success
})

warn("[NYXHUB] Script loaded successfully. Total elements registered: " .. tostring(#(function() local t = {}; for _ in pairs(ElementRegistry) do table.insert(t, 1) end; return t end)()))
