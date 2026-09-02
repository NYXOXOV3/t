-- ============================================================
-- 1. LOAD UI LIBRARY & SETUP GLOBALS
-- ============================================================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/NYXOXOV3/berak/refs/heads/main/gui.lua"))()
if not Library then warn("[NYXHUB] Gagal load Library!"); return end

local RunService = game:GetService("RunService")
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

-- ============================================================
-- 2. UI HELPERS & COMPATIBILITY WRAPPER
-- ============================================================
local ElementRegistry = {}
local ElementByTitle = {}

local function Notify(cfg)
    cfg = cfg or {}
    Library:MakeNotify({
        Title = cfg.Title or "Notification",
        Description = cfg.Content or cfg.Description or "",
        Color = cfg.Color or Library.colors.primary,
        Delay = cfg.Duration or cfg.Delay or 3
    })
end

local function Reg(id, element, title)
    if not element then return nil end
    local wrapped = {}
    setmetatable(wrapped, {__index = element})
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
    if not wrapped.Set then
        wrapped.Set = function(self, val)
            rawset(self, "_cachedValue", val)
            if element.SetValue then pcall(function() element:SetValue(val) end) end
        end
    end
    if not wrapped.SetDesc then
        wrapped.SetDesc = function(self, v)
            if element.SetContent then pcall(function() element:SetContent(v) end) end
        end
    end
    if not wrapped.SetTitle then wrapped.SetTitle = function() end end
    if not wrapped.SetPlaceholder then wrapped.SetPlaceholder = function() end end
    if not wrapped.GetValue then
        wrapped.GetValue = function(self)
            if element.GetValue then
                local ok, val = pcall(function() return element:GetValue() end)
                if ok then return val end
            end
            return rawget(self, "_cachedValue") or rawget(self, "_defaultValue")
        end
    end
    if element.Refresh then
        local origRefresh = element.Refresh
        wrapped.Refresh = function(self, list, ...)
            pcall(function() origRefresh(element, list) end)
        end
    end
    ElementRegistry[id] = wrapped
    if title then ElementByTitle[title] = wrapped end
    return wrapped
end

local function AddSliderCompat(section, config)
    local title = config.Title or "Slider"
    local minVal = config.Value and config.Value.Min or 0
    local maxVal = config.Value and config.Value.Max or 100
    local defaultVal = config.Value and config.Value.Default or minVal
    local callback = config.Callback
    local frame = section:AddInput({
        Title = title,
        Default = tostring(defaultVal),
        Placeholder = string.format("%.2f - %.2f", minVal, maxVal),
        Callback = function(text)
            local num = tonumber(text)
            if num then
                num = math.clamp(num, minVal, maxVal)
                if callback then pcall(callback, num) end
            end
        end
    })
    return frame
end

-- ============================================================
-- 3. NETWORK & REMOTES
-- ============================================================
local net = ReplicatedStorage:WaitForChild("Packages", 10):WaitForChild("_Index", 10):WaitForChild("sleitnick_net@0.2.0", 10):WaitForChild("net", 10)
local remotes = net:GetChildren()

function GetServerRemote(targetName)
    for _, descendant in ipairs(net:GetDescendants()) do
        if descendant.Name == targetName and (descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")) then
            return descendant
        end
    end
    local allRemotes = net:GetChildren()
    for i, remote in ipairs(allRemotes) do
        if remote.Name == targetName then
            local actualRemote = allRemotes[i + 1]
            if actualRemote and (actualRemote:IsA("RemoteEvent") or actualRemote:IsA("RemoteFunction")) then return actualRemote end
        end
    end
    return nil
end

function GetServerRemoteReverse(targetName)
    local allRemotes = net:GetChildren()
    for i, remote in ipairs(allRemotes) do
        if remote.Name == targetName then
            local actualRemote = allRemotes[i - 1]
            if actualRemote and (actualRemote:IsA("RemoteEvent") or actualRemote:IsA("RemoteFunction")) then return actualRemote end
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
        if connection.Function then task.spawn(function() connection.Function(unpack(args)) end) end
    end
end

-- ============================================================
-- 4. CONTROLLERS & GLOBAL STATE
-- ============================================================
local Controllers, NotificationController, GiftingController, TextNotificationController, VFXController, CutsceneController, ControlModule, FishingController, AFKController, PromptController, BackpackController
local Replion, PlayerData, ItemUtility, TierUtility

if isMobile then
    Controllers = ReplicatedStorage:WaitForChild("Controllers")
    pcall(function()
        NotificationController = require(Controllers:WaitForChild("NotificationController"))
        GiftingController = require(Controllers:WaitForChild("GiftingController"))
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
                if storageKey == "CaughtVisual" and tostring(args[1]) == tostring(LocalPlayer.Name) then saveCount = saveCount + 5 end
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
    UB = { Active = false, Settings = { CompleteDelay = 2.6, CancelDelay = 0.0001, NotificationDuration = 6 }, Remotes = {}, Stats = { castCount = 0, startTime = 0 } },
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
task.spawn(function() while true do task.wait(IntervalWaktu) FireUIAtLocation() end end)

-- Hook Notification
local origDeliverNotification = (isMobile and TextNotificationController) and TextNotificationController.DeliverNotification
local function hookNotification()
    if isMobile and TextNotificationController then
        TextNotificationController.DeliverNotification = function(self, data, ...)
            if Config.HookNotif then data.CustomDuration = 6.3 end
            if Config.autoFishing and isMobile then
                if (string.find(tostring(data.Text), "stopped") or string.find(tostring(data.Text), "Auto Fishing: Disabled")) then
                    for i = 1,3 do task.wait(0.5) CallRemoteServer(Events.UpdateAutoFishingState, true) end
                end
            end
            return origDeliverNotification(self, data, ...)
        end
    end
end

-- Events Init
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

if Events.systemMessageEvent then
    Events.systemMessageEvent.OnClientEvent:Connect(function(...)
        local args = {...}
        if args[1] then args[1] = args[1]:lower() end
        if args[1] and (not string.find(args[1], "global") or string.find(args[1], "server")) and string.find(args[1], "staff") then
            LocalPlayer:Kick("Awas ada staff")
        end
    end)
end
hookNotification()

-- LOCATIONS
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

local function GetHRP()
    local char = LocalPlayer.Character
    if not char then char = LocalPlayer.CharacterAdded:Wait() end
    return char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local character = LocalPlayer.Character
    if not character then character = LocalPlayer.CharacterAdded:Wait() end
    return character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 3)
end

local function TeleportToLookAt(position, lookVector)
    local hrp = GetHRP()
    if hrp and typeof(position) == "Vector3" then
        local targetCFrame = typeof(lookVector) == "Vector3" and CFrame.new(position, position + lookVector) * CFrame.new(0, 0.5, 0) or CFrame.new(position + Vector3.new(0, 3, 0))
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

-- Replion Helpers
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

-- UB System
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
                if Config.antiOKOK and not Config.autoFishing then task.wait(17 / 100) end
                CallRemoteServer(Config.UB.Remotes.RequestMinigame, 1, 0, currentTime)
            end)
            task.wait(Config.UB.Settings.CompleteDelay)
            if not skip then
                safeFire(function()
                    safeFire(function() CallRemoteServer(Config.UB.Remotes.FishingCompleted) end)
                    if Config.UB.Remotes.FishingCompletedRE then Config.UB.Remotes.FishingCompletedRE:FireServer() end
                    if Config.amblatant and isCaught then
                        task.spawn(function ()
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

local function castRod()
    pcall(function()
        CallRemoteServer(Events.CancelFishingInputs)
        task.wait(0.7)
        CallRemoteServer(Events.charge)
        CallRemoteServer(Events.minigame, -911.1024780273438, 0.9, os.clock())
    end)
end

local function equipRod()
    CallRemoteServer(Events.equip, 1)
    if Config.autoFishing or Config.AutoCatch then CallRemoteServer(Events.UpdateAutoFishingState, true) end
end

local function onToggleUB(value)
    if value then
        Config.HookNotif = true
        equipRod()
        castRod()
        UB_start()
        Notify({ Title = "UB Instant ON", Duration = 2 })
    else
        UB_stop()
        Config.HookNotif = false
        Notify({ Title = "UB Instant OFF", Duration = 2 })
    end
end

UB_init()
task.spawn(function()
    while true do
        task.wait(3)
        if not Config.isFarming or not Config.isMinig then
            if Config.UB.Active and lastTimeFishCaught ~= nil and os.clock() - lastTimeFishCaught >= 5 and blatantFishCycleCount > 1 then
                needCast = true; saveCount = 0; blatantFishCycleCount = 0; lastTimeFishCaught = os.clock()
                onToggleUB(false); task.wait(0.5); onToggleUB(true)
            end
        end
    end
end)

-- Fish Notif Hook
if Events.fishNotif then
    Events.fishNotif.OnClientEvent:Connect(function(...)
        local args = {...}
        local arg3 = args[3]
        lastTimeFishCaught = os.clock()
        local dummyItem = {Id = args[1], Metadata = args[2]}
        local fishName, fishRarity = GetFishNameAndRarity(dummyItem)
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
local stroke = Instance.new("UIStroke", btn); stroke.Thickness = 2; stroke.Color = Color3.fromRGB(255, 0, 255)
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
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
btn.MouseButton1Click:Connect(function()
    if Library._win then Library._win.Visible = not Library._win.Visible end
end)

-- Helper to add GetElementByTitle to TabObject
local function WrapTabObject(tabObj)
    tabObj.GetElementByTitle = function(self, title) return ElementByTitle[title] end
    return tabObj
end

-- ============================================================
-- TAB: ABOUT
-- ============================================================
local aboutTab = WrapTabObject(Window:AddTab({ Name = "About", Icon = "alert" }))
local aboutSec = aboutTab:AddSection("Join Discord Server Noxius Community")
aboutSec:AddParagraph({ Title = "Noxius Community", Content = "Join Our Community Discord Server to get the latest updates, support, and connect with other users!" })
aboutSec:AddButton({ Title = "Copy Link", Callback = function()
    setclipboard("https://discord.gg/noxius")
    Notify({ Title = "Link Disalin!", Description = "Link Discord Noxius berhasil disalin." })
end})
aboutSec:AddParagraph({ Title = "Version 1.0.2", Content = "[~] Fix 3D Rendering Force Close Issue\n[~] Fix Teleport & Freeze Detect Old Position\n[~] Improve Load UI\n[+] Add Freeze Player\n[+] Add Detect Enchant Perfection On Blatant Mode\n[+] Add Auto Spawn 9 Totem\n[+] Bring Back 3 Setting On Blatant Mode" })

-- ============================================================
-- TAB: PLAYER
-- ============================================================
local playerTab = WrapTabObject(Window:AddTab({ Name = "Player", Icon = "user" }))
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

movementSec:AddButton({ Title = "Reset Movement", Callback = function()
    local Humanoid = GetHumanoid()
    if Humanoid then
        Humanoid.WalkSpeed = 16; Humanoid.JumpPower = 50
        local ws = ElementRegistry["Walkspeed"]; if ws and ws.Set then ws:Set(16) end
        local jp = ElementRegistry["slidjump"]; if jp and jp.Set then jp:Set(50) end
        Notify({ Title = "Movement Direset", Description = "WalkSpeed & JumpPower Reset to default" })
    end
end})

Reg("frezee", movementSec:AddToggle({ Title = "Freeze Player", Default = false, Callback = function(state)
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Anchored = state
        if state then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0); hrp.Velocity = Vector3.new(0, 0, 0)
            Notify({ Title = "Player Frozen", Description = "Posisi dikunci (Anchored)." })
        else
            Notify({ Title = "Player Unfrozen", Description = "Gerakan kembali normal." })
        end
    end
end}), "Freeze Player")

local abilitySec = playerTab:AddSection("Abilities")

Reg("infj", abilitySec:AddToggle({ Title = "Infinite Jump", Default = false, Callback = function(state)
    if state then
        Notify({ Title = "Infinite Jump ON!", Duration = 2 })
        _G.InfinityJumpConnection = UserInputService.JumpRequest:Connect(function()
            local Humanoid = GetHumanoid()
            if Humanoid and Humanoid.Health > 0 then Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    else
        Notify({ Title = "Infinite Jump OFF!", Duration = 2 })
        if _G.InfinityJumpConnection then _G.InfinityJumpConnection:Disconnect(); _G.InfinityJumpConnection = nil end
    end
end}), "Infinite Jump")

local noclipConnection = nil
local isNoClipActive = false
Reg("nclip", abilitySec:AddToggle({ Title = "No Clip", Default = false, Callback = function(state)
    isNoClipActive = state
    local character = LocalPlayer.Character
    if not character then character = LocalPlayer.CharacterAdded:Wait() end
    if state then
        Notify({ Title = "No Clip ON!", Duration = 2 })
        noclipConnection = RunService.Stepped:Connect(function()
            if isNoClipActive and character and character.Parent then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                end
            end
        end)
    else
        Notify({ Title = "No Clip OFF!", Duration = 2 })
        if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
        if character and character.Parent then
            for _, part in ipairs(character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end
        end
    end
end}), "No Clip")

local flyConnection = nil
local isFlying = false
local flySpeed = 60
local bodyGyro, bodyVel
Reg("flym", abilitySec:AddToggle({ Title = "Fly Mode", Default = false, Callback = function(state)
    local character = LocalPlayer.Character
    if not character then character = LocalPlayer.CharacterAdded:Wait() end
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 2)
    local humanoid = character:WaitForChild("Humanoid", 2)
    if state then
        Notify({ Title = "Fly Mode ON!", Duration = 2 })
        isFlying = true
        bodyGyro = Instance.new("BodyGyro"); bodyGyro.P = 9e4; bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9); bodyGyro.CFrame = humanoidRootPart.CFrame; bodyGyro.Parent = humanoidRootPart
        bodyVel = Instance.new("BodyVelocity"); bodyVel.Velocity = Vector3.zero; bodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9); bodyVel.Parent = humanoidRootPart
        local cam = workspace.CurrentCamera
        local jumpPressed = false
        _G.FlyJump = UserInputService.JumpRequest:Connect(function()
            if isFlying then jumpPressed = true; task.delay(0.2, function() jumpPressed = false end) end
        end)
        flyConnection = RunService.RenderStepped:Connect(function()
            if not isFlying or not humanoidRootPart or not bodyGyro or not bodyVel then return end
            bodyGyro.CFrame = cam.CFrame
            local moveDir = humanoid.MoveDirection
            if jumpPressed then moveDir = moveDir + Vector3.new(0, 1, 0)
            elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
            if moveDir.Magnitude > 0 then moveDir = moveDir.Unit * flySpeed end
            bodyVel.Velocity = moveDir
        end)
    else
        Notify({ Title = "Fly Mode OFF!", Duration = 2 })
        isFlying = false
        if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
        if _G.FlyJump then _G.FlyJump:Disconnect(); _G.FlyJump = nil end
        if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
        if bodyVel then bodyVel:Destroy(); bodyVel = nil end
    end
end}), "Fly Mode")

local walkOnWaterConnection = nil
local isWalkOnWater = false
local waterPlatform = nil
Reg("walkwat", abilitySec:AddToggle({ Title = "Walk on Water", Default = false, Callback = function(state)
    if state then
        Notify({ Title = "Walk on Water ON!", Duration = 2 })
        isWalkOnWater = true
        if not waterPlatform then
            waterPlatform = Instance.new("Part"); waterPlatform.Name = "WaterPlatform"; waterPlatform.Anchored = true; waterPlatform.CanCollide = true; waterPlatform.Transparency = 1; waterPlatform.Size = Vector3.new(15, 1, 15); waterPlatform.Parent = workspace
        end
        walkOnWaterConnection = RunService.RenderStepped:Connect(function()
            local character = LocalPlayer.Character
            if not isWalkOnWater or not character then return end
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            if not waterPlatform or not waterPlatform.Parent then
                waterPlatform = Instance.new("Part"); waterPlatform.Name = "WaterPlatform"; waterPlatform.Anchored = true; waterPlatform.CanCollide = true; waterPlatform.Transparency = 1; waterPlatform.Size = Vector3.new(15, 1, 15); waterPlatform.Parent = workspace
            end
            local rayParams = RaycastParams.new(); rayParams.FilterDescendantsInstances = {workspace.Terrain}; rayParams.FilterType = Enum.RaycastFilterType.Include; rayParams.IgnoreWater = false
            local result = workspace:Raycast(hrp.Position + Vector3.new(0, 5, 0), Vector3.new(0, -500, 0), rayParams)
            if result and result.Material == Enum.Material.Water then
                local waterSurfaceHeight = result.Position.Y
                waterPlatform.Position = Vector3.new(hrp.Position.X, waterSurfaceHeight, hrp.Position.Z)
                if hrp.Position.Y < (waterSurfaceHeight + 2) and hrp.Position.Y > (waterSurfaceHeight - 5) then
                    if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then hrp.CFrame = CFrame.new(hrp.Position.X, waterSurfaceHeight + 3.2, hrp.Position.Z) end
                end
            else
                waterPlatform.Position = Vector3.new(hrp.Position.X, -500, hrp.Position.Z)
            end
        end)
    else
        Notify({ Title = "Walk on Water OFF!", Duration = 2 })
        isWalkOnWater = false
        if walkOnWaterConnection then walkOnWaterConnection:Disconnect(); walkOnWaterConnection = nil end
        if waterPlatform then waterPlatform:Destroy(); waterPlatform = nil end
    end
end}), "Walk on Water")

local otherSec = playerTab:AddSection("Other")
local customName = ".gg/PahajiHub"
local customLevel = "Lvl. 969"
Reg("cfakennme", otherSec:AddInput({ Title = "Custom Fake Name", Default = customName, Placeholder = "Hidden User", Callback = function(text) customName = text end }), "Custom Fake Name")
Reg("cfkelvl", otherSec:AddInput({ Title = "Custom Fake Level", Default = customLevel, Placeholder = "Lvl. 999", Callback = function(text) customLevel = text end }), "Custom Fake Level")

local isHideActive = false
local hideConnection = nil
Reg("hideallusr", otherSec:AddToggle({ Title = "Hide All Usernames (Streamer Mode)", Default = false, Callback = function(state)
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
                                        if txt:find(plr.Name) or txt:find(plr.DisplayName) then if txt ~= customName then lbl.Text = customName end
                                        elseif txt:match("%d+") or txt:lower():find("lvl") or txt:lower():find("level") then if #txt < 15 and txt ~= customLevel then lbl.Text = customLevel end end
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
end}), "Hide All Usernames (Streamer Mode)")

local espEnabled = false
local espConnections = {}
local function removeESP(targetPlayer)
    if not targetPlayer then return end
    local data = espConnections[targetPlayer]
    if data then
        if data.distanceConn then pcall(function() data.distanceConn:Disconnect() end) end
        if data.charAddedConn then pcall(function() data.charAddedConn:Disconnect() end) end
        if data.billboard and data.billboard.Parent then pcall(function() data.billboard:Destroy() end) end
        espConnections[targetPlayer] = nil
    end
end
local function createESP(targetPlayer)
    if not targetPlayer or not targetPlayer.Character or targetPlayer == LocalPlayer then return end
    removeESP(targetPlayer)
    local char = targetPlayer.Character
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if not hrp then return end
    local BillboardGui = Instance.new("BillboardGui"); BillboardGui.Name = "PahajiHubESP"; BillboardGui.Adornee = hrp; BillboardGui.Size = UDim2.new(0, 140, 0, 40); BillboardGui.AlwaysOnTop = true; BillboardGui.StudsOffset = Vector3.new(0, 2.6, 0); BillboardGui.Parent = char
    local Frame = Instance.new("Frame"); Frame.Size = UDim2.new(1, 0, 1, 0); Frame.BackgroundTransparency = 1; Frame.BorderSizePixel = 0; Frame.Parent = BillboardGui
    local NameLabel = Instance.new("TextLabel"); NameLabel.Parent = Frame; NameLabel.Size = UDim2.new(1, 0, 0.6, 0); NameLabel.Position = UDim2.new(0, 0, 0, 0); NameLabel.BackgroundTransparency = 1; NameLabel.Text = tostring(targetPlayer.DisplayName or targetPlayer.Name); NameLabel.TextColor3 = Color3.fromRGB(255, 230, 230); NameLabel.TextStrokeTransparency = 0.7; NameLabel.Font = Enum.Font.GothamBold; NameLabel.TextScaled = true
    local DistanceLabel = Instance.new("TextLabel"); DistanceLabel.Parent = Frame; DistanceLabel.Size = UDim2.new(1, 0, 0.4, 0); DistanceLabel.Position = UDim2.new(0, 0, 0.6, 0); DistanceLabel.BackgroundTransparency = 1; DistanceLabel.Text = "0.0 m"; DistanceLabel.TextColor3 = Color3.fromRGB(210, 210, 210); DistanceLabel.Font = Enum.Font.GothamSemibold; DistanceLabel.TextScaled = true
    espConnections[targetPlayer] = { billboard = BillboardGui }
    local distanceConn = RunService.RenderStepped:Connect(function()
        if not espEnabled or not hrp or not hrp.Parent then removeESP(targetPlayer) return end
        local localChar = LocalPlayer.Character; local localHRP = localChar and localChar:FindFirstChild("HumanoidRootPart")
        if localHRP then DistanceLabel.Text = string.format("%.1f m", (localHRP.Position - hrp.Position).Magnitude * 0.28) end
    end)
    espConnections[targetPlayer].distanceConn = distanceConn
    local charAddedConn = targetPlayer.CharacterAdded:Connect(function() task.wait(0.8); if espEnabled then createESP(targetPlayer) end end)
    espConnections[targetPlayer].charAddedConn = charAddedConn
end

Reg("esp", otherSec:AddToggle({ Title = "Player ESP", Default = false, Callback = function(state)
    espEnabled = state
    if state then
        Notify({ Title = "ESP Aktif", Duration = 2 })
        for _, plr in ipairs(Players:GetPlayers()) do if plr ~= LocalPlayer then createESP(plr) end end
        espConnections["playerAddedConn"] = Players.PlayerAdded:Connect(function(plr) task.wait(1); if espEnabled then createESP(plr) end end)
        espConnections["playerRemovingConn"] = Players.PlayerRemoving:Connect(function(plr) removeESP(plr) end)
    else
        Notify({ Title = "ESP Nonaktif", Description = "Semua marker ESP dihapus." })
        for plr, _ in pairs(espConnections) do if plr and typeof(plr) == "Instance" then removeESP(plr) end end
        if espConnections["playerAddedConn"] then espConnections["playerAddedConn"]:Disconnect() end
        if espConnections["playerRemovingConn"] then espConnections["playerRemovingConn"]:Disconnect() end
        espConnections = {}
    end
end}), "Player ESP")

otherSec:AddButton({ Title = "Reset Character (In Place)", Callback = function()
    local character = LocalPlayer.Character; local hrp = character and character:FindFirstChild("HumanoidRootPart"); local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not hrp or not humanoid then Notify({ Title = "Gagal Reset", Description = "Karakter tidak ditemukan!" }); return end
    local lastPos = hrp.Position; Notify({ Title = "Reset Character...", Description = "Respawning di posisi yang sama..." })
    humanoid:TakeDamage(999999); LocalPlayer.CharacterAdded:Wait(); task.wait(0.5)
    local newChar = LocalPlayer.Character; local newHRP = newChar:WaitForChild("HumanoidRootPart", 5)
    if newHRP then newHRP.CFrame = CFrame.new(lastPos + Vector3.new(0, 3, 0)); Notify({ Title = "Character Reset Sukses!", Description = "Kamu direspawn di posisi yang sama" })
    else Notify({ Title = "Gagal Reset", Description = "HumanoidRootPart baru tidak ditemukan." }) end
end})

-- ============================================================
-- TAB: AUTOMATIC
-- ============================================================
local automaticTab = WrapTabObject(Window:AddTab({ Name = "Automatic", Icon = "loop" }))
local autoSellState = false; local autoSellThread = nil; local autoSellMethod = "Delay"; local autoSellValue = 50
local autoFavoriteState = false; local autoUnfavoriteState = false; local autoFavoriteThread = nil; local autoUnfavoriteThread = nil
local selectedRarities = {}; local selectedItemNames = {}; local selectedMutations = {}
local RF_SellAllItems = Events.sell; local RE_FavoriteItem = GetServerRemote("RE/FavoriteItem")

local function GetFishCount()
    local replion = GetPlayerDataReplion(); if not replion then return 0 end
    local totalFishCount = 0
    local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
    if not success or not inventoryData or not inventoryData.Items or typeof(inventoryData.Items) ~= "table" then return 0 end
    for _, item in ipairs(inventoryData.Items) do
        if item.Type == "Fishing Rods" or item.Type == "Boats" or item.Type == "Bait" or item.Type == "Pets" or item.Type == "Chests" or item.Type == "Crates" or item.Type == "Totems" then continue end
        if item.Identifier and (item.Identifier:match("Artifact") or item.Identifier:match("Key") or item.Identifier:match("Token") or item.Identifier:match("Booster") or item.Identifier:match("hourglass")) then continue end
        if item.Metadata and item.Metadata.Weight or item.Type == "Fish" or (item.Identifier and item.Identifier:match("fish")) then totalFishCount = totalFishCount + (item.Count or 1) end
    end
    return totalFishCount
end

local function RunAutoSellLoop()
    if autoSellThread then task.cancel(autoSellThread) end
    autoSellThread = task.spawn(function()
        while autoSellState do
            if autoSellMethod == "Delay" then
                if RF_SellAllItems then pcall(function() RF_SellAllItems:InvokeServer() end) end
                task.wait(math.max(autoSellValue, 1))
            elseif autoSellMethod == "Count" then
                local currentCount = GetFishCount()
                if currentCount >= autoSellValue then
                    if RF_SellAllItems then pcall(function() RF_SellAllItems:InvokeServer() end); Notify({ Title = "Auto Sell", Description = "Menjual " .. currentCount .. " items." }); task.wait(2) end
                end
                task.wait(1)
            end
        end
    end)
end

local sellall = automaticTab:AddSection("Autosell Fish")
local inputElement
Reg("sellmethod", sellall:AddDropdown({ Title = "Select Method", Options = {"Delay", "Count"}, Default = "Delay", Callback = function(val)
    autoSellMethod = val
    if inputElement then
        if val == "Delay" then inputElement:SetTitle("Sell Delay (Seconds)"); inputElement:SetPlaceholder("e.g. 50")
        else inputElement:SetTitle("Sell at Item Count"); inputElement:SetPlaceholder("e.g. 100") end
    end
    if autoSellState then RunAutoSellLoop() end
end}), "Select Method")

inputElement = Reg("sellval", sellall:AddInput({ Title = "Sell Delay (Seconds)", Default = tostring(autoSellValue), Placeholder = "50", Callback = function(text)
    local num = tonumber(text); if num then autoSellValue = num end
end}), "Sell Value")

local CurrentCountDisplay = sellall:AddParagraph({ Title = "Current Fish Count: 0", Content = "" })
task.spawn(function()
    while true do
        if CurrentCountDisplay and GetPlayerDataReplion() then pcall(function() CurrentCountDisplay:SetTitle("Current Fish Count: " .. GetFishCount()) end) end
        task.wait(1)
    end
end)

Reg("tsell", sellall:AddToggle({ Title = "Enable Auto Sell", Default = false, Callback = function(state)
    autoSellState = state
    if state then
        if not RF_SellAllItems then Notify({ Title = "Error", Description = "Remote Sell tidak ditemukan." }); return end
        local msg = (autoSellMethod == "Delay") and ("Setiap " .. autoSellValue .. " detik.") or ("Saat jumlah >= " .. autoSellValue)
        Notify({ Title = "Auto Sell ON (" .. autoSellMethod .. ")", Description = msg }); RunAutoSellLoop()
    else
        Notify({ Title = "Auto Sell OFF" }); if autoSellThread then task.cancel(autoSellThread); autoSellThread = nil end
    end
end}), "Enable Auto Sell")

local favsec = automaticTab:AddSection("Auto Favorite / Unfavorite")
local function getAutoFavoriteItemOptions()
    local itemNames = {}; local itemsContainer = ReplicatedStorage:FindFirstChild("Items")
    if not itemsContainer then return {"(Items container not found)"} end
    for _, itemObject in ipairs(itemsContainer:GetChildren()) do
        local itemName = itemObject.Name
        if type(itemName) == "string" and #itemName >= 3 and itemName:sub(1,3) ~= "!!!" then table.insert(itemNames, itemName) end
    end
    table.sort(itemNames); return #itemNames > 0 and itemNames or {"(No items found)"}
end
local allItemNames = getAutoFavoriteItemOptions()

local function GetItemsToFavorite()
    local replion = GetPlayerDataReplion(); if not replion or not ItemUtility or not TierUtility then return {} end
    local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
    if not success or not inventoryData or not inventoryData.Items then return {} end
    local itemsToFavorite = {}; local isRarity = #selectedRarities > 0; local isName = #selectedItemNames > 0; local isMutation = #selectedMutations > 0
    if not (isRarity or isName or isMutation) then return {} end
    for _, item in ipairs(inventoryData.Items) do
        if item.IsFavorite or item.Favorited then continue end
        local itemUUID = item.UUID; if typeof(itemUUID) ~= "string" or #itemUUID < 10 then continue end
        local name, rarity = GetFishNameAndRarity(item); local mutationStr = GetItemMutationString(item); local match = false
        if isRarity and table.find(selectedRarities, rarity) then match = true end
        if not match and isName and table.find(selectedItemNames, name) then match = true end
        if not match and isMutation and table.find(selectedMutations, mutationStr) then match = true end
        if match then table.insert(itemsToFavorite, itemUUID) end
    end
    return itemsToFavorite
end

local function GetItemsToUnfavorite()
    local replion = GetPlayerDataReplion(); if not replion or not ItemUtility or not TierUtility then return {} end
    local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
    if not success or not inventoryData or not inventoryData.Items then return {} end
    local itemsToUnfavorite = {}
    for _, item in ipairs(inventoryData.Items) do
        if not (item.IsFavorite or item.Favorited) then continue end
        local itemUUID = item.UUID; if typeof(itemUUID) ~= "string" or #itemUUID < 10 then continue end
        local name, rarity = GetFishNameAndRarity(item); local mutationStr = GetItemMutationString(item)
        local passesRarity = #selectedRarities > 0 and table.find(selectedRarities, rarity)
        local passesName = #selectedItemNames > 0 and table.find(selectedItemNames, name)
        local passesMutation = #selectedMutations > 0 and table.find(selectedMutations, mutationStr)
        if passesRarity or passesName or passesMutation then table.insert(itemsToUnfavorite, itemUUID) end
    end
    return itemsToUnfavorite
end

local function SetItemFavoriteState(itemUUID) if RE_FavoriteItem then pcall(function() RE_FavoriteItem:FireServer(itemUUID) end) end end

local function RunAutoFavoriteLoop()
    if autoFavoriteThread then task.cancel(autoFavoriteThread) end
    autoFavoriteThread = task.spawn(function()
        while autoFavoriteState do
            local items = GetItemsToFavorite()
            if #items > 0 then Notify({ Title = "Auto Favorite", Description = "Mem-favorite " .. #items .. " item..." }); for _, uuid in ipairs(items) do SetItemFavoriteState(uuid); task.wait(0.5) end end
            task.wait(1)
        end
    end)
end

local function RunAutoUnfavoriteLoop()
    if autoUnfavoriteThread then task.cancel(autoUnfavoriteThread) end
    autoUnfavoriteThread = task.spawn(function()
        while autoUnfavoriteState do
            local items = GetItemsToUnfavorite()
            if #items > 0 then Notify({ Title = "Auto Unfavorite", Description = "Menghapus favorite dari " .. #items .. " item..." }); for _, uuid in ipairs(items) do SetItemFavoriteState(uuid); task.wait(0.5) end end
            task.wait(1)
        end
    end)
end

Reg("drer", favsec:AddDropdown({ Title = "by Rarity", Options = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET"}, Multi = true, Callback = function(values) selectedRarities = values or {} end }), "by Rarity")
Reg("dtem", favsec:AddDropdown({ Title = "by Item Name", Options = allItemNames, Multi = true, Callback = function(values) selectedItemNames = values or {} end }), "by Item Name")
Reg("dmut", favsec:AddDropdown({ Title = "by Mutation", Options = {"Shiny", "Gemstone", "Corrupt", "Galaxy", "Holographic", "Ghost", "Lightning", "Fairy Dust", "Gold", "Midnight", "Radioactive", "Stone", "Albino", "Sandy", "Acidic", "Disco", "Frozen", "Noob"}, Multi = true, Callback = function(values) selectedMutations = values or {} end }), "by Mutation")

Reg("tvav", favsec:AddToggle({ Title = "Enable Auto Favorite", Default = false, Callback = function(state)
    autoFavoriteState = state
    if state then
        if autoUnfavoriteState then autoUnfavoriteState = false; local unfavToggle = automaticTab:GetElementByTitle("Enable Auto Unfavorite"); if unfavToggle and unfavToggle.Set then unfavToggle:Set(false) end; if autoUnfavoriteThread then task.cancel(autoUnfavoriteThread); autoUnfavoriteThread = nil end end
        Notify({ Title = "Auto Favorite ON!", Duration = 2 }); RunAutoFavoriteLoop()
    else
        Notify({ Title = "Auto Favorite OFF!", Duration = 2 }); if autoFavoriteThread then task.cancel(autoFavoriteThread); autoFavoriteThread = nil end
    end
end}), "Enable Auto Favorite")

Reg("tunfa", favsec:AddToggle({ Title = "Enable Auto Unfavorite", Default = false, Callback = function(state)
    autoUnfavoriteState = state
    if state then
        if autoFavoriteState then autoFavoriteState = false; local favToggle = automaticTab:GetElementByTitle("Enable Auto Favorite"); if favToggle and favToggle.Set then favToggle:Set(false) end; if autoFavoriteThread then task.cancel(autoFavoriteThread); autoFavoriteThread = nil end end
        if #selectedRarities == 0 and #selectedItemNames == 0 and #selectedMutations == 0 then Notify({ Title = "Peringatan!", Description = "Semua filter kosong. Non-aktifkan toggle ini.", Delay = 5 }); return end
        Notify({ Title = "Auto Unfavorite ON!", Duration = 2 }); RunAutoUnfavoriteLoop()
    else
        Notify({ Title = "Auto Unfavorite OFF!", Duration = 2 }); if autoUnfavoriteThread then task.cancel(autoUnfavoriteThread); autoUnfavoriteThread = nil end
    end
end}), "Enable Auto Unfavorite")

-- Auto Enchant
local ENCHANT_MAPPING = { ["Cursed I"] = 12, ["Big Hunter I"] = 3, ["Empowered I"] = 9, ["Glistening I"] = 1, ["Gold Digger I"] = 4, ["Leprechaun I"] = 5, ["Leprechaun II"] = 6, ["Mutation Hunter I"] = 7, ["Mutation Hunter II"] = 14, ["Perfection"] = 15, ["Prismatic I"] = 13, ["Reeler I"] = 2, ["Stargazer I"] = 8, ["Stormhunter I"] = 11, ["Experienced I"] = 10 }
local ENCHANT_NAMES = {}; for name, _ in pairs(ENCHANT_MAPPING) do table.insert(ENCHANT_NAMES, name) end
local autoEnchantState = false; local autoEnchantThread = nil; local selectedRodUUID = nil; local selectedEnchantNames = {}; local ENCHANT_STONE_ID = 10

local function GetEnchantNameFromId(id) id = tonumber(id); if not id then return nil end; for name, eid in pairs(ENCHANT_MAPPING) do if eid == id then return name end end; return nil end
local function GetRodOptions()
    local rodOptions = {}; local replion = GetPlayerDataReplion(); if not replion then return {"(Gagal memuat Inventory)"} end
    local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
    if not success or not inventoryData or not inventoryData["Fishing Rods"] then return {"(Tidak ada Rod ditemukan)"} end
    for _, rod in ipairs(inventoryData["Fishing Rods"]) do
        local rodUUID = rod.UUID; if typeof(rodUUID) ~= "string" or #rodUUID < 10 then continue end
        local rodName, _ = GetFishNameAndRarity(rod); if not string.find(rodName, "Rod", 1, true) then continue end
        local enchantStatus = ""; local metadata = rod.Metadata or {}; local enchants = {}
        if metadata.EnchantId then table.insert(enchants, metadata.EnchantId) end
        local resolved = {}; for _, eid in ipairs(enchants) do local name = GetEnchantNameFromId(eid) or "ID:" .. eid; table.insert(resolved, name) end
        if #resolved > 0 then enchantStatus = " [" .. table.concat(resolved, ", ") .. "]" end
        table.insert(rodOptions, rodName .. " (" .. string.sub(rodUUID, 1, 8) .. "...)" .. enchantStatus)
    end
    return rodOptions
end
local function GetUUIDFromFormattedName(formattedName)
    local uuidMatch = formattedName:match("%(([^%)]+)%.%.%.%)"); if not uuidMatch then return nil end
    local replion = GetPlayerDataReplion(); local Rods = replion:GetExpect("Inventory")["Fishing Rods"] or {}
    for _, rod in ipairs(Rods) do if string.sub(rod.UUID, 1, 8) == uuidMatch then return rod.UUID end end; return nil
end
local function CheckIfEnchantReached(rodUUID)
    local replion = GetPlayerDataReplion(); local Rods = replion:GetExpect("Inventory")["Fishing Rods"] or {}; local targetRod = nil
    for _, rod in ipairs(Rods) do if rod.UUID == rodUUID then targetRod = rod; break end end
    if not targetRod then return true end
    local metadata = targetRod.Metadata or {}; local current = {}; if metadata.EnchantId then table.insert(current, metadata.EnchantId) end
    for _, targetName in ipairs(selectedEnchantNames) do local targetID = ENCHANT_MAPPING[targetName]; if targetID and table.find(current, targetID) then return true end end; return false
end
local function GetFirstStoneUUID()
    local replion = GetPlayerDataReplion(); if not replion then return nil end
    local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
    if not success or not inventoryData or not inventoryData.Items then return nil end
    for _, item in ipairs(inventoryData.Items) do if tonumber(item.Id) == ENCHANT_STONE_ID and item.UUID then return item.UUID end end; return nil
end
local function UnequipAllEquippedItems()
    local RE_UnequipItem = GetServerRemote("RE/UnequipItem"); if not RE_UnequipItem then return end
    local replion = GetPlayerDataReplion(); local EquippedItems = replion:GetExpect("EquippedItems") or {}; local EquippedSkinUUID = replion:Get("EquippedSkinUUID")
    if EquippedSkinUUID and EquippedSkinUUID ~= "" then pcall(function() RE_UnequipItem:FireServer(EquippedSkinUUID) end); task.wait(0.1) end
    for _, uuid in ipairs(EquippedItems) do pcall(function() RE_UnequipItem:FireServer(uuid) end); task.wait(0.05) end
end
local function RunAutoEnchantLoop(rodUUID)
    if autoEnchantThread then task.cancel(autoEnchantThread) end
    autoEnchantThread = task.spawn(function()
        while autoEnchantState do
            if CheckIfEnchantReached(rodUUID) then Notify({ Title = "Enchant Selesai!", Description = "Target enchant sudah tercapai.", Delay = 5 }); break end
            local stoneUUID = GetFirstStoneUUID(); if not stoneUUID then Notify({ Title = "Stone Habis", Description = "Butuh Enchant Stone", Delay = 4 }); break end
            UnequipAllEquippedItems(); task.wait(0.5)
            local RE_EquipItem = GetServerRemote("RE/EquipItem"); pcall(function() RE_EquipItem:FireServer(rodUUID, "Fishing Rods") end); task.wait(0.3)
            pcall(function() RE_EquipItem:FireServer(stoneUUID, "Enchant Stones") end); task.wait(0.3)
            local RE_ActivateAltar = GetServerRemote("RE/ActivateEnchantingAltar"); if RE_ActivateAltar then pcall(function() RE_ActivateAltar:FireServer() end) end; task.wait(1.2)
        end
        autoEnchantState = false; local toggle = automaticTab:GetElementByTitle("Enable Auto Enchant"); if toggle and toggle.Set then toggle:Set(false) end
    end)
end

local enchant = automaticTab:AddSection("Auto Enchant Rod")
local RodDropdown = enchant:AddDropdown({ Title = "Select Rod", Options = GetRodOptions(), Callback = function(formattedName)
    selectedRodUUID = GetUUIDFromFormattedName(formattedName)
    if selectedRodUUID then Notify({ Title = "Rod Dipilih", Description = "UUID tersimpan." }) else Notify({ Title = "Gagal", Description = "Tidak bisa mendapatkan UUID." }) end
end})
enchant:AddButton({ Title = "Re-Check Selected Rod", Callback = function() pcall(function() RodDropdown:Refresh(GetRodOptions()) end); Notify({ Title = "List Diperbarui" }) end})
enchant:AddDropdown({ Title = "Enchant To Apply", Options = ENCHANT_NAMES, Multi = true, Callback = function(names) selectedEnchantNames = names or {} end})
enchant:AddToggle({ Title = "Enable Auto Enchant", Default = false, Callback = function(state)
    autoEnchantState = state
    if state then
        if not selectedRodUUID then Notify({ Title = "Error", Description = "Pilih Rod terlebih dahulu." }); return end
        if #selectedEnchantNames == 0 then Notify({ Title = "Error", Description = "Pilih minimal satu enchant." }); return end
        RunAutoEnchantLoop(selectedRodUUID)
    else
        if autoEnchantThread then task.cancel(autoEnchantThread); autoEnchantThread = nil end; Notify({ Title = "Auto Enchant OFF!" })
    end
end})

-- Second Enchant
local enchant2 = automaticTab:AddSection("Second Enchant Rod")
local makeStoneState = false; local makeStoneThread = nil; local selectedSecretFishUUIDs = {}; local targetStoneAmount = 1
local RF_CreateTranscendedStone = GetServerRemote("RF/CreateTranscendedStone")
local RE_ActivateSecondEnchantingAltar = GetServerRemote("RE/ActivateSecondEnchantingAltar")
local RE_EquipItem = GetServerRemote("RE/EquipItem")
local RE_EquipToolFromHotbar = GetServerRemote("RE/EquipToolFromHotbar")

local function GetSecretFishOptions()
    local options = {}; local uuidMap = {}; local replion = GetPlayerDataReplion(); if not replion then return {}, {} end
    local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
    if not success or not inventoryData or not inventoryData.Items then return {}, {} end
    for _, item in ipairs(inventoryData.Items) do
        local hasWeight = item.Metadata and item.Metadata.Weight; local isFishType = item.Type == "Fish" or (item.Identifier and tostring(item.Identifier):lower():find("fish"))
        if not hasWeight and not isFishType then continue end
        local _, rarity = GetFishNameAndRarity(item); if not rarity or rarity:upper() ~= "SECRET" then continue end
        local name = item.Identifier or "Unknown"
        if ItemUtility then local itemData = ItemUtility:GetItemData(item.Id); if itemData and itemData.Data and itemData.Data.Name then name = itemData.Data.Name end end
        if item.Metadata and item.Metadata.Weight then name = string.format("%s (%.1fkg)", name, item.Metadata.Weight) end
        if item.IsFavorite or item.Favorited then name = name .. " [⭐]" end
        table.insert(options, name); uuidMap[name] = item.UUID
    end
    table.sort(options); return options, uuidMap
end
local secretFishOptions, secretFishUUIDMap = GetSecretFishOptions()

local function RunMakeStoneLoop()
    if makeStoneThread then task.cancel(makeStoneThread) end
    makeStoneThread = task.spawn(function()
        local createdCount = 0; task.wait(1)
        while makeStoneState and createdCount < targetStoneAmount do
            local _, currentMap = GetSecretFishOptions(); local fishToSacrifice = nil
            for name, uuid in pairs(currentMap) do if table.find(selectedSecretFishUUIDs, name) then fishToSacrifice = uuid; break end end
            if not fishToSacrifice then Notify({ Title = "Selesai / Habis", Description = "Tidak ada ikan target tersisa.", Delay = 5 }); break end
            Notify({ Title = "Sacrificing...", Description = "Memproses ikan..." }); UnequipAllEquippedItems(); task.wait(0.3)
            pcall(function() RE_EquipItem:FireServer(fishToSacrifice, "Fish") end); task.wait(0.5)
            pcall(function() RE_EquipToolFromHotbar:FireServer(2) end); task.wait(0.8)
            local success = pcall(function() RF_CreateTranscendedStone:InvokeServer() end)
            if success then createdCount = createdCount + 1; Notify({ Title = "Stone Created!", Description = string.format("Total: %d / %d", createdCount, targetStoneAmount) })
            else Notify({ Title = "Gagal", Description = "Gagal membuat batu." }) end
            task.wait(1.5)
        end
        makeStoneState = false; local toggle = automaticTab:GetElementByTitle("Start Make Stones"); if toggle and toggle.Set then toggle:Set(false) end
        pcall(function() RE_EquipToolFromHotbar:FireServer(0) end)
    end)
end

local SecretFishDropdown = enchant2:AddDropdown({ Title = "Select Secret Fish (Sacrifice)", Options = secretFishOptions, Multi = true, Callback = function(values) selectedSecretFishUUIDs = values or {} end})
enchant2:AddButton({ Title = "Refresh Secret Fish List", Callback = function()
    local newOptions, newMap = GetSecretFishOptions(); secretFishUUIDMap = newMap
    pcall(function() SecretFishDropdown:Refresh(newOptions) end); pcall(function() SecretFishDropdown:Set(false) end); selectedSecretFishUUIDs = {}
    Notify({ Title = "Refreshed", Description = #newOptions .. " ikan secret ditemukan." })
end})
enchant2:AddInput({ Title = "Amount to Make", Default = "1", Callback = function(input) targetStoneAmount = tonumber(input) or 1 end})
enchant2:AddToggle({ Title = "Start Make Stones", Default = false, Callback = function(state)
    makeStoneState = state
    if state then
        if #selectedSecretFishUUIDs == 0 then Notify({ Title = "Error", Description = "Pilih minimal 1 jenis ikan secret." }); return end
        RunMakeStoneLoop()
    else
        if makeStoneThread then task.cancel(makeStoneThread) end; Notify({ Title = "Stopped" })
    end
end})

-- ============================================================
-- TAB: TELEPORT
-- ============================================================
local teleportTab = WrapTabObject(Window:AddTab({ Name = "Teleport", Icon = "gps" }))
local selectedTargetPlayer = nil; local selectedTargetArea = nil; local autoEventTargetName = nil; local autoEventTeleportState = false; local autoEventTeleportThread = nil

local function GetPlayerListOptions()
    local options = {}; for _, player in ipairs(Players:GetPlayers()) do if player ~= LocalPlayer then table.insert(options, player.Name) end end; return options
end
local function GetTargetHRP(playerName)
    local targetPlayer = Players:FindFirstChild(playerName); if not targetPlayer then return nil end
    local character = targetPlayer.Character; if character then return character:FindFirstChild("HumanoidRootPart") end; return nil
end

local teleplay = teleportTab:AddSection("Teleport to Player")
local PlayerDropdown = teleplay:AddDropdown({ Title = "Select Target Player", Options = GetPlayerListOptions(), Callback = function(name) selectedTargetPlayer = name end})
teleplay:AddButton({ Title = "Refresh Player List", Callback = function()
    local newOptions = GetPlayerListOptions(); pcall(function() PlayerDropdown:Refresh(newOptions) end); task.wait(0.1); pcall(function() PlayerDropdown:Set(false) end); selectedTargetPlayer = nil
    Notify({ Title = "List Diperbarui", Description = string.format("%d pemain ditemukan.", #newOptions) })
end})
teleplay:AddButton({ Title = "Teleport to Player (One-Time)", Callback = function()
    local hrp = GetHRP(); local targetHRP = GetTargetHRP(selectedTargetPlayer)
    if not selectedTargetPlayer then Notify({ Title = "Error", Description = "Pilih pemain target terlebih dahulu." }); return end
    if hrp and targetHRP then
        local targetPos = targetHRP.Position + Vector3.new(0, 5, 0); local targetCFrame = CFrame.new(targetPos, targetHRP.Position)
        local tween = TweenService:Create(hrp, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {CFrame = targetCFrame}); tween:Play(); tween.Completed:Wait()
        Notify({ Title = "Teleport Sukses", Description = "Teleported ke " .. selectedTargetPlayer })
    else Notify({ Title = "Error", Description = "Gagal menemukan target atau karakter Anda." }) end
end})

local telearea = teleportTab:AddSection("Teleport to Fishing Area")
local AreaNames = {}; for name, _ in pairs(LOCATIONS) do table.insert(AreaNames, name) end; table.sort(AreaNames)
telearea:AddDropdown({ Title = "Select Target Area", Options = AreaNames, Callback = function(name) selectedTargetArea = name end})
telearea:AddButton({ Title = "Teleport to Area (One-Time)", Callback = function()
    if not selectedTargetArea or not LOCATIONS[selectedTargetArea] then Notify({ Title = "Error", Description = "Pilih area target terlebih dahulu." }); return end
    local cf = LOCATIONS[selectedTargetArea]; TeleportToLookAt(cf.Position, cf.LookVector)
end})

local televent = teleportTab:AddSection("Auto Teleport Event")
local eventsList = { "Shark Hunt", "Ghost Shark Hunt", "Worm Hunt", "Black Hole", "Shocked", "Ghost Worm", "Meteor Rain", "Megalodon Hunt", "Treasure Event" }
televent:AddDropdown({ Title = "Select Target Event", Options = eventsList, Callback = function(option)
    autoEventTargetName = option
    if autoEventTeleportState then autoEventTeleportState = false; if autoEventTeleportThread then task.cancel(autoEventTeleportThread); autoEventTeleportThread = nil end; local toggle = teleportTab:GetElementByTitle("Enable Auto Event Teleport"); if toggle then toggle:Set(false) end end
end})
televent:AddButton({ Title = "Teleport to Chosen Event (Once)", Callback = function()
    if not autoEventTargetName then Notify({ Title = "Error", Description = "Pilih event dulu di dropdown!" }); return end
    Notify({ Title = "Searching...", Description = "Mencari keberadaan event..." })
    if autoEventTargetName == "Megalodon Hunt" then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if string.find(obj.Name:lower(), "megalodon") then task.wait(0.1); if obj:IsA("BasePart") then TeleportToLookAt(obj.Position, nil); return end end
        end
    else Notify({ Title = "Info", Description = autoEventTargetName .. " belum support auto teleport." }) end
end})
televent:AddToggle({ Title = "Enable Auto Event Teleport", Default = false, Callback = function(state)
    if not autoEventTargetName then Notify({ Title = "Error", Description = "Pilih Event Target terlebih dahulu di dropdown." }); return end
    autoEventTeleportState = state
    if state then
        Notify({ Title = "Auto Event TP ON", Description = "Mencari " .. autoEventTargetName })
        if autoEventTeleportThread then task.cancel(autoEventTeleportThread) end
        autoEventTeleportThread = task.spawn(function()
            while autoEventTeleportState do
                if autoEventTargetName == "Megalodon Hunt" then
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if string.find(obj.Name:lower(), "megalodon") then task.wait(0.1); if obj:IsA("BasePart") then TeleportToLookAt(obj.Position, nil); break end end
                    end
                end
                task.wait(8)
            end
        end)
    else
        if autoEventTeleportThread then task.cancel(autoEventTeleportThread); autoEventTeleportThread = nil end; Notify({ Title = "Auto Event TP OFF" })
    end
end})

-- ============================================================
-- TAB: FISHING
-- ============================================================
local farmTab = WrapTabObject(Window:AddTab({ Name = "Fishing", Icon = "fish" }))
local legitAutoState = false; local normalInstantState = false; local blatantInstantState = false
local normalLoopThread = nil; local blatantLoopThread = nil; local normalEquipThread = nil; local blatantEquipThread = nil; local legitEquipThread = nil; local legitClickThread = nil
local isTeleportFreezeActive = false; local freezeToggle = nil; local selectedArea = nil; local savedPosition = nil

Config.UB.Remotes.ChargeFishingRod = GetServerRemote("RF/ChargeFishingRod")
Config.UB.Remotes.RequestMinigame = GetServerRemote("RF/RequestFishingMinigameStarted")
Config.UB.Remotes.CancelFishingInputs = GetServerRemote("RF/CancelFishingInputs")
Config.UB.Remotes.UpdateAutoFishingState = GetServerRemote("RF/UpdateAutoFishingState")
Config.UB.Remotes.FishingCompleted = GetServerRemote("RF/CatchFishCompleted")
Config.UB.Remotes.FishingCompletedRE = GetServerRemote("RE/CatchFishCompleted")
Config.UB.Remotes.MinigameChanged = GetServerRemote("RE/FishingMinigameChanged")
Config.UB.Remotes.equip = GetServerRemote("RF/EquipToolFromHotbar")

local RE_EquipToolFromHotbar = Config.UB.Remotes.equip
local RF_ChargeFishingRod = Config.UB.Remotes.ChargeFishingRod
local RF_RequestFishingMinigameStarted = Config.UB.Remotes.RequestMinigame
local RE_FishingCompleted = Config.UB.Remotes.FishingCompletedRE
local RF_CancelFishingInputs = Config.UB.Remotes.CancelFishingInputs
local RF_UpdateAutoFishingState = Config.UB.Remotes.UpdateAutoFishingState

local function checkFishingRemotes(silent)
    local remotes = { RE_EquipToolFromHotbar, RF_ChargeFishingRod, RF_RequestFishingMinigameStarted, RE_FishingCompleted, RF_CancelFishingInputs, RF_UpdateAutoFishingState }
    for _, remote in ipairs(remotes) do
        if not remote then
            if not silent then Notify({ Title = "Remote Error!", Description = "Beberapa remote fishing tidak ditemukan.", Delay = 5 }) end
            return false
        end
    end
    return true
end

local function disableOtherModes(currentMode)
    pcall(function()
        local toggleLegit = farmTab:GetElementByTitle("Auto Fish (Legit)")
        local toggleNormal = farmTab:GetElementByTitle("Normal Instant Fish")
        local toggleBlatant = farmTab:GetElementByTitle("Instant Fishing (Blatant)")
        if currentMode ~= "legit" and legitAutoState then legitAutoState = false; if toggleLegit and toggleLegit.Set then toggleLegit:Set(false) end; if legitClickThread then task.cancel(legitClickThread); legitClickThread = nil end; if legitEquipThread then task.cancel(legitEquipThread); legitEquipThread = nil end end
        if currentMode ~= "normal" and normalInstantState then normalInstantState = false; if toggleNormal and toggleNormal.Set then toggleNormal:Set(false) end; if normalLoopThread then task.cancel(normalLoopThread); normalLoopThread = nil end; if normalEquipThread then task.cancel(normalEquipThread); normalEquipThread = nil end end
        if currentMode ~= "blatant" and blatantInstantState then blatantInstantState = false; if toggleBlatant and toggleBlatant.Set then toggleBlatant:Set(false) end; if blatantLoopThread then task.cancel(blatantLoopThread); blatantLoopThread = nil end; if blatantEquipThread then task.cancel(blatantEquipThread); blatantEquipThread = nil end end
    end)
    if currentMode ~= "legit" then pcall(function() if RF_UpdateAutoFishingState then RF_UpdateAutoFishingState:InvokeServer(false) end end) end
end

local AutoFishingController = require(ReplicatedStorage:WaitForChild("Controllers"):WaitForChild("AutoFishingController"))
local AutoFishState = { IsActive = false, MinigameActive = false }
local SPEED_LEGIT = 0.05

local function performClick()
    if FishingController then pcall(function() FishingController:RequestFishingMinigameClick() end); task.wait(SPEED_LEGIT) end
end

if FishingController then
    local originalRodStarted = FishingController.FishingRodStarted
    FishingController.FishingRodStarted = function(self, arg1, arg2)
        pcall(function() originalRodStarted(self, arg1, arg2) end)
        if AutoFishState.IsActive and not AutoFishState.MinigameActive then
            AutoFishState.MinigameActive = true
            if legitClickThread then task.cancel(legitClickThread) end
            legitClickThread = task.spawn(function() while AutoFishState.IsActive and AutoFishState.MinigameActive do performClick() end end)
        end
    end
    local originalFishingStopped = FishingController.FishingStopped
    FishingController.FishingStopped = function(self, arg1) pcall(function() originalFishingStopped(self, arg1) end); if AutoFishState.MinigameActive then AutoFishState.MinigameActive = false end end
end

local function ensureServerAutoFishingOn() if RF_UpdateAutoFishingState then pcall(function() RF_UpdateAutoFishingState:InvokeServer(true) end) end end
local function ToggleAutoClick(shouldActivate)
    if not FishingController then return end; AutoFishState.IsActive = shouldActivate
    local playerGuiLocal = LocalPlayer:WaitForChild("PlayerGui")
    local fishingGui = playerGuiLocal:FindFirstChild("Fishing") and playerGuiLocal.Fishing:FindFirstChild("Main")
    local chargeGui = playerGuiLocal:FindFirstChild("Charge") and playerGuiLocal.Charge:FindFirstChild("Main")
    if shouldActivate then
        pcall(function() RE_EquipToolFromHotbar:FireServer(1) end); ensureServerAutoFishingOn()
        if fishingGui then fishingGui.Visible = false end; if chargeGui then chargeGui.Visible = false end
        Notify({ Title = "Auto Fish Legit ON!", Description = "Auto-Equip Protection Active." })
    else
        if legitClickThread then task.cancel(legitClickThread); legitClickThread = nil end; AutoFishState.MinigameActive = false
        if fishingGui then fishingGui.Visible = true end; if chargeGui then chargeGui.Visible = true end
        Notify({ Title = "Auto Fish Legit OFF!" })
    end
end

local autofish = farmTab:AddSection("Auto Fishing")
Reg("klikd", AddSliderCompat(autofish, { Title = "Legit Click Speed (Delay)", Step = 0.01, Value = { Min = 0.01, Max = 0.5, Default = SPEED_LEGIT }, Callback = function(value) SPEED_LEGIT = tonumber(value) or 0.05 end }), "Legit Click Speed (Delay)")
Reg("legit", autofish:AddToggle({ Title = "Auto Fish (Legit)", Default = false, Callback = function(state)
    if not checkFishingRemotes() then return false end; disableOtherModes("legit"); legitAutoState = state; ToggleAutoClick(state)
    if state then
        if legitEquipThread then task.cancel(legitEquipThread) end
        legitEquipThread = task.spawn(function() while legitAutoState do pcall(function() RE_EquipToolFromHotbar:FireServer(1) end); task.wait(0.1) end end)
    else
        if legitEquipThread then task.cancel(legitEquipThread); legitEquipThread = nil end
    end
end}), "Auto Fish (Legit)")

local normalCompleteDelay = 1.50
Reg("normalslid", AddSliderCompat(autofish, { Title = "Normal Complete Delay", Step = 0.05, Value = { Min = 0.5, Max = 5.0, Default = normalCompleteDelay }, Callback = function(value) normalCompleteDelay = tonumber(value) or 1.50 end }), "Normal Complete Delay")

local function runNormalInstant()
    if not normalInstantState then return end; if not checkFishingRemotes(true) then normalInstantState = false; return end
    local timestamp = os.time() + os.clock()
    pcall(function() RF_ChargeFishingRod:InvokeServer(timestamp) end)
    pcall(function() RF_RequestFishingMinigameStarted:InvokeServer(-139.630452165, 0.99647927980797) end)
    task.wait(normalCompleteDelay)
    pcall(function() RE_FishingCompleted:FireServer() end)
    task.wait(0.1) -- FIXED: was 0.000000001
    pcall(function() RF_CancelFishingInputs:InvokeServer() end)
end

Reg("tognorm", autofish:AddToggle({ Title = "Normal Instant Fish", Default = false, Callback = function(state)
    if not checkFishingRemotes() then return end; disableOtherModes("normal"); normalInstantState = state
    if state then
        normalLoopThread = task.spawn(function() while normalInstantState do runNormalInstant(); task.wait(0.1) end end) -- FIXED: was 0.000000001
        if normalEquipThread then task.cancel(normalEquipThread) end
        normalEquipThread = task.spawn(function() while normalInstantState do pcall(function() RE_EquipToolFromHotbar:FireServer(1) end); task.wait(0.1) end end)
        Notify({ Title = "Auto Fish ON", Description = "Auto-Equip Protection Active." })
    else
        if normalLoopThread then task.cancel(normalLoopThread); normalLoopThread = nil end
        if normalEquipThread then task.cancel(normalEquipThread); normalEquipThread = nil end
        pcall(function() RE_EquipToolFromHotbar:FireServer(0) end); Notify({ Title = "Auto Fish OFF" })
    end
end}), "Normal Instant Fish")

local blatant = farmTab:AddSection("Blatant Mode")
local completeDelay = 3.055; local cancelDelay = 0.3; local loopInterval = 1.715
_G.PahajiHub_BlatantActive = false
task.spawn(function()
    local S1, FC = pcall(function() return require(ReplicatedStorage.Controllers.FishingController) end)
    if S1 and FC then
        local Old_Charge = FC.RequestChargeFishingRod; local Old_Cast = FC.SendFishingRequestToServer
        FC.RequestChargeFishingRod = function(...) if _G.PahajiHub_BlatantActive then return end return Old_Charge(...) end
        FC.SendFishingRequestToServer = function(...) if _G.PahajiHub_BlatantActive then return false, "Blocked" end return Old_Cast(...) end
    end
end)
local mt = getrawmetatable(game); local old_namecall = mt.__namecall; setreadonly(mt, false)
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
        elseif TextController._OldDeliver then TextController.DeliverNotification = TextController._OldDeliver; TextController._OldDeliver = nil end
    end
end

Reg("blatantint", blatant:AddInput({ Title = "Blatant Interval", Default = tostring(loopInterval), Callback = function(input) local newInterval = tonumber(input); if newInterval and newInterval >= 0.5 then loopInterval = newInterval end end }), "Blatant Interval")
Reg("blatantcom", blatant:AddInput({ Title = "Complete Delay", Default = tostring(completeDelay), Callback = function(input) local newDelay = tonumber(input); if newDelay and newDelay >= 0.5 then completeDelay = newDelay end end }), "Complete Delay")
Reg("blatantcanc", blatant:AddInput({ Title = "Cancel Delay", Default = tostring(cancelDelay), Callback = function(input) local newDelay = tonumber(input); if newDelay and newDelay >= 0.1 then cancelDelay = newDelay end end }), "Cancel Delay")

local function runBlatantInstant()
    if not blatantInstantState then return end; if not checkFishingRemotes(true) then blatantInstantState = false; return end
    task.spawn(function()
        local startTime = os.clock(); local timestamp = os.time() + os.clock()
        pcall(function() RF_ChargeFishingRod:InvokeServer(timestamp) end); task.wait(0.001)
        pcall(function() RF_RequestFishingMinigameStarted:InvokeServer(-139.6379699707, 0.99647927980797) end)
        local completeWaitTime = completeDelay - (os.clock() - startTime); if completeWaitTime > 0 then task.wait(completeWaitTime) end
        pcall(function() RE_FishingCompleted:FireServer() end); task.wait(cancelDelay)
        pcall(function() RF_CancelFishingInputs:InvokeServer() end)
    end)
end

Reg("blatantt", blatant:AddToggle({ Title = "Instant Fishing (Blatant)", Default = false, Callback = function(state)
    if not checkFishingRemotes() then return end; disableOtherModes("blatant"); blatantInstantState = state; _G.PahajiHub_BlatantActive = state; SuppressGameVisuals(state)
    if state then
        if RF_UpdateAutoFishingState then pcall(function() RF_UpdateAutoFishingState:InvokeServer(true) end); task.wait(0.1); pcall(function() RF_UpdateAutoFishingState:InvokeServer(true) end) end
        blatantLoopThread = task.spawn(function() while blatantInstantState do runBlatantInstant(); task.wait(loopInterval) end end)
        if blatantEquipThread then task.cancel(blatantEquipThread) end
        blatantEquipThread = task.spawn(function() while blatantInstantState do pcall(function() RE_EquipToolFromHotbar:FireServer(1) end); task.wait(0.1) end end)
        Notify({ Title = "Blatant Mode ON" })
    else
        if RF_UpdateAutoFishingState then pcall(function() RF_UpdateAutoFishingState:InvokeServer(false) end) end
        if blatantLoopThread then task.cancel(blatantLoopThread); blatantLoopThread = nil end
        if blatantEquipThread then task.cancel(blatantEquipThread); blatantEquipThread = nil end
        Notify({ Title = "Blatant Mode OFF" })
    end
end}), "Instant Fishing (Blatant)")

local areafish = farmTab:AddSection("Fishing Area")
local choosearea = areafish:AddDropdown({ Title = "Choose Area", Options = AreaNames, Callback = function(option) selectedArea = option end})
freezeToggle = Reg("freezearea", areafish:AddToggle({ Title = "Teleport & Freeze at Area (Fix Server Lag)", Default = false, Callback = function(state)
    isTeleportFreezeActive = state; local hrp = GetHRP()
    if not hrp then if freezeToggle and freezeToggle.Set then freezeToggle:Set(false) end; return end
    if state then
        if not selectedArea then Notify({ Title = "Aksi Gagal", Description = "Pilih Area dulu di Dropdown!" }); if freezeToggle and freezeToggle.Set then freezeToggle:Set(false) end; return end
        local areaData; if selectedArea == "Custom: Saved" and savedPosition then areaData = savedPosition else local cf = LOCATIONS[selectedArea]; areaData = { Pos = cf.Position, Look = cf.LookVector } end
        if not areaData or not areaData.Pos or not areaData.Look then Notify({ Title = "Aksi Gagal", Description = "Data area tidak valid." }); if freezeToggle and freezeToggle.Set then freezeToggle:Set(false) end; return end
        hrp.Anchored = false; TeleportToLookAt(areaData.Pos, areaData.Look); Notify({ Title = "Syncing Zone...", Description = "Menahan posisi agar server update..." })
        task.spawn(function()
            local startTime = os.clock()
            while (os.clock() - startTime) < 1.5 and isTeleportFreezeActive do
                if hrp and hrp.Parent then hrp.Velocity = Vector3.new(0,0,0); hrp.AssemblyLinearVelocity = Vector3.new(0,0,0); hrp.CFrame = CFrame.new(areaData.Pos, areaData.Pos + areaData.Look) * CFrame.new(0, 0.5, 0) end
                RunService.Heartbeat:Wait()
            end
            if isTeleportFreezeActive and hrp and hrp.Parent then hrp.Anchored = true; Notify({ Title = "Ready to Fish", Description = "Posisi dikunci & Zona terupdate." }) end
        end)
    else
        if hrp then hrp.Anchored = false end; Notify({ Title = "Unfrozen", Description = "Gerakan kembali normal." })
    end
end}), "Teleport & Freeze at Area (Fix Server Lag)")

areafish:AddButton({ Title = "Teleport to Chosen Area", Callback = function()
    if not selectedArea then Notify({ Title = "Teleport Gagal", Description = "Pilih Area dulu di Dropdown." }); return end
    local areaData; if selectedArea == "Custom: Saved" and savedPosition then areaData = savedPosition else local cf = LOCATIONS[selectedArea]; areaData = { Pos = cf.Position, Look = cf.LookVector } end
    if isTeleportFreezeActive and freezeToggle then freezeToggle:Set(false); task.wait(0.1) end
    TeleportToLookAt(areaData.Pos, areaData.Look)
end})
areafish:AddButton({ Title = "Save Current Position", Callback = function()
    local hrp = GetHRP()
    if hrp then
        savedPosition = { Pos = hrp.Position, Look = hrp.CFrame.LookVector }; LOCATIONS["Custom: Saved"] = CFrame.new(savedPosition.Pos, savedPosition.Pos + savedPosition.Look)
        local newValues = {}; for name, _ in pairs(LOCATIONS) do table.insert(newValues, name) end; table.sort(newValues)
        pcall(function() choosearea:Refresh(newValues) end); Notify({ Title = "Posisi Disimpan!", Description = "Gunakan 'Custom: Saved' di dropdown." })
    else Notify({ Title = "Gagal Simpan" }) end
end})
areafish:AddButton({ Title = "Teleport to SAVED Pos", Callback = function()
    if not savedPosition then Notify({ Title = "Teleport Gagal", Description = "Belum ada posisi yang disimpan." }); return end
    if isTeleportFreezeActive and freezeToggle then freezeToggle:Set(false); task.wait(0.1) end
    TeleportToLookAt(savedPosition.Pos, savedPosition.Look)
end})

local UBSection = farmTab:AddSection("Ultra Blatant 3N")
Reg("ubcom", UBSection:AddInput({ Title = "Complete Delay", Default = tostring(Config.UB.Settings.CompleteDelay), Callback = function(Value) local num = tonumber(Value); if num then Config.UB.Settings.CompleteDelay = num end end }), "UB Complete Delay")
Reg("ubcanc", UBSection:AddInput({ Title = "Cancel Delay", Default = tostring(Config.UB.Settings.CancelDelay), Callback = function(Value) local num = tonumber(Value); if num then Config.UB.Settings.CancelDelay = num end end }), "UB Cancel Delay")
Reg("ubnotdur", UBSection:AddInput({ Title = "Notification Duration", Default = tostring(Config.UB.Settings.NotificationDuration), Callback = function(Value) local num = tonumber(Value); if num then Config.UB.Settings.NotificationDuration = num end end }), "Notification Duration")
Reg("ubtogg", UBSection:AddToggle({ Title = "Enable Blatant 3N", Default = false, Callback = function(Value) if Value then onToggleUB(true) else onToggleUB(false) end end }), "Enable Blatant 3N")
Reg("ubautofish", UBSection:AddToggle({ Title = "Auto Fishing (Ingame)", Default = Config.autoFishing, Callback = function(Value)
    Config.autoFishing = Value
    if Value then CallRemoteServer(Events.UpdateAutoFishingState, true); Notify({ Title = "Auto Fishing ON" }) else Notify({ Title = "Auto Fishing OFF" }) end
end}), "Auto Fishing (Ingame)")

-- ============================================================
-- TAB: SHOP
-- ============================================================
local shopTab = WrapTabObject(Window:AddTab({ Name = "Shop", Icon = "shop" }))
local MerchantButtons = {}; local UpdateCleanupFunction = nil; local MainDisplayElement = nil; local UpdateThread = nil
local selectedStaticItemName = nil; local autoBuySelectedState = false; local autoBuyStockState = false; local autoBuyThread = nil

local ShopItems = {
    ["Rods"] = { {Name = "Luck Rod", ID = 70, Price = 325}, {Name = "Carbon Rod", ID = 76, Price = 750}, {Name = "Grass Rod", ID = 85, Price = 1500}, {Name = "Demascus Rod", ID = 77, Price = 3000}, {Name = "Ice Rod", ID = 78, Price = 5000}, {Name = "Lucky Rod", ID = 4, Price = 15000}, {Name = "Midnight Rod", ID = 80, Price = 50000}, {Name = "Steampunk Rod", ID = 6, Price = 215000}, {Name = "Chrome Rod", ID = 7, Price = 437000}, {Name = "Flourescent Rod", ID = 255, Price = 715000}, {Name = "Astral Rod", ID = 5, Price = 1000000}, {Name = "Ares Rod", ID = 126, Price = 3000000}, {Name = "Angler Rod", ID = 168, Price = 8000000}, {Name = "Bamboo Rod", ID = 258, Price = 12000000} },
    ["Bobbers"] = { {Name = "Floral Bait", ID = 20, Price = 4000000}, {Name = "Aether Bait", ID = 16, Price = 3700000}, {Name = "Corrupt Bait", ID = 15, Price = 1148484}, {Name = "Dark Matter Bait", ID = 8, Price = 630000}, {Name = "Chroma Bait", ID = 6, Price = 290000}, {Name = "Nature Bait", ID = 17, Price = 83500}, {Name = "Midnight Bait", ID = 3, Price = 3000}, {Name = "Luck Bait", ID = 2, Price = 1000}, {Name = "Topwater Bait", ID = 10, Price = 100} },
    ["Boats"] = { {Name = "Mini Yach", ID = 14, Price = 1200000}, {Name = "Fish Boat", ID = 6, Price = 180000}, {Name = "Speed Boat", ID = 5, Price = 70000}, {Name = "Highfield Boat", ID = 4, Price = 25000}, {Name = "Jetski", ID = 3, Price = 7500}, {Name = "Kayak", ID = 2, Price = 1100}, {Name = "Small Boat", ID = 1, Price = 100} }
}
local MerchantStaticItems = { {Name = "Fluorescent Rod", ID = 1, Identifier = "Fluorescent Rod", Price = 685000}, {Name = "Hazmat Rod", ID = 2, Identifier = "Hazmat Rod", Price = 1380000}, {Name = "Singularity Bait", ID = 3, Identifier = "Singularity Bait", Price = 8200000}, {Name = "Royal Bait", ID = 4, Identifier = "Royal Bait", Price = 425000}, {Name = "Luck Totem", ID = 5, Identifier = "Luck Totem", Price = 650000}, {Name = "Shiny Totem", ID = 7, Identifier = "Shiny Totem", Price = 400000}, {Name = "Mutation Totem", ID = 8, Identifier = "Mutation Totem", Price = 800000} }

local selectedRodName = ShopItems["Rods"][1].Name; local selectedBobberName = ShopItems["Bobbers"][1].Name; local selectedBoatName = ShopItems["Boats"][1].Name
local RF_PurchaseBait = GetServerRemote("RF/PurchaseBait"); local RF_PurchaseFishingRod = GetServerRemote("RF/PurchaseFishingRod"); local RF_PurchaseBoat = GetServerRemote("RF/PurchaseBoat"); local RF_PurchaseMarketItem = GetServerRemote("RF/PurchaseMarketItem"); local RF_PurchaseWeatherEvent = GetServerRemote("RF/PurchaseWeatherEvent")
local ShopRemotes = { ["Rods"] = RF_PurchaseFishingRod, ["Bobbers"] = RF_PurchaseBait, ["Boats"] = RF_PurchaseBoat }

local function getDropdownOptions(itemType) local options = {}; for _, item in ipairs(ShopItems[itemType]) do table.insert(options, string.format("%s (%s)", item.Name, FormatNumber(item.Price))) end; return options end
local function getItemID(itemType, dropdownValue) local itemName = dropdownValue:match("^([^%s]+%s[^%s]+)"); if not itemName then itemName = dropdownValue:match("^[^%s]+") end; for _, item in ipairs(ShopItems[itemType]) do if item.Name == itemName then return item.ID end end; return nil end
local function handlePurchase(itemType, selectedValue) local itemID = getItemID(itemType, selectedValue); local remote = ShopRemotes[itemType]; if not remote or not itemID then Notify({ Title = "Purchase Error" }); return end; pcall(function() remote:InvokeServer(itemID) end); Notify({ Title = "Purchase Attempted!" }) end

local function getNextRefreshTimeString() local serverTime = workspace:GetServerTimeNow(); local secondsInDay = 86400; local nextRefreshTime = (math.floor(serverTime / secondsInDay) + 1) * secondsInDay; local timeRemaining = math.max(nextRefreshTime - serverTime, 0); local h = math.floor(timeRemaining / 3600); local m = math.floor((timeRemaining % 3600) / 60); local s = math.floor(timeRemaining % 60); return string.format("Next Refresh: %dH, %dM, %dS", h, m, s) end
local function GetMerchantStockDetails(merchantData)
    local itemDetails = {}; local MarketItemData = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MarketItemData", 0.1) and require(ReplicatedStorage.Shared.MarketItemData)
    if merchantData and merchantData.Items and type(merchantData.Items) == "table" and MarketItemData and ItemUtility then
        for _, itemID in ipairs(merchantData.Items) do
            local marketData = nil; for _, data in ipairs(MarketItemData) do if data.Id == itemID then marketData = data; break end end
            if marketData and not marketData.SkinCrate and marketData.Price and marketData.Currency then
                local itemDetail = nil; pcall(function() itemDetail = ItemUtility:GetItemDataFromItemType(marketData.Type, marketData.Identifier) end)
                local name = (itemDetail and itemDetail.Data and itemDetail.Data.Name) or marketData.Identifier or "Unknown Item"
                table.insert(itemDetails, { Name = name, ID = itemID, Price = marketData.Price, Currency = marketData.Currency })
            end
        end
    end
    return itemDetails
end
local function BuyMerchantItem(itemID, itemName)
    if not RF_PurchaseMarketItem then Notify({ Title = "Purchase Failed", Description = "Remote Purchase Market Item tidak ditemukan." }); return false end
    local success, result = pcall(function() return RF_PurchaseMarketItem:InvokeServer(itemID) end)
    if success then Notify({ Title = "Purchase Attempted!", Description = "Mencoba membeli: " .. itemName }); return true else Notify({ Title = "Purchase Failed", Description = "Gagal: " .. (result or "Unknown Error") }); return false end
end
local function ClearOldMerchantButtons() for _, btn in ipairs(MerchantButtons) do if btn and type(btn) == "table" and btn.Destroy then pcall(function() btn:Destroy() end) end end; MerchantButtons = {} end
local function CreateStockListString(itemDetails)
    local list = {"--- CURRENT STOCK ---"}; if #itemDetails == 0 then table.insert(list, "Stok Item unik kosong saat ini."); return table.concat(list, "\n") end
    for _, item in ipairs(itemDetails) do table.insert(list, string.format(" • %s: %s %s", item.Name, FormatNumber(item.Price), item.Currency or "Coins")) end; return table.concat(list, "\n")
end
local function RedrawMerchantButtons(itemDetails, section)
    ClearOldMerchantButtons()
    if #itemDetails > 0 then
        for _, item in ipairs(itemDetails) do
            local newButton = section:AddButton({ Title = string.format("BUY: %s", item.Name), Callback = function() BuyMerchantItem(item.ID, item.Name) end }); table.insert(MerchantButtons, newButton)
        end
    else
        local noStockIndicator = section:AddParagraph({ Title = "No Buyable Items", Content = "Tidak ada tombol yang tersedia." }); table.insert(MerchantButtons, noStockIndicator)
    end
end
local function RunAutoBuyStockLoop()
    if autoBuyThread then task.cancel(autoBuyThread) end
    autoBuyThread = task.spawn(function()
        while autoBuyStockState do
            if MerchantReplion then local currentDetails = GetMerchantStockDetails(MerchantReplion.Data); for _, item in ipairs(currentDetails) do BuyMerchantItem(item.ID, item.Name); task.wait(0.5) end end; task.wait(3)
        end
    end)
end
local function RunMerchantSyncLoop(mainDisplay, section)
    if UpdateThread then task.cancel(UpdateThread) end
    local initialDetails = GetMerchantStockDetails(MerchantReplion.Data); RedrawMerchantButtons(initialDetails, section)
    local stockUpdateConnection = MerchantReplion:OnChange("Items", function(newItems)
        local currentDetails = GetMerchantStockDetails(MerchantReplion.Data); RedrawMerchantButtons(currentDetails, section)
        local timeString = getNextRefreshTimeString(); local stockListString = CreateStockListString(currentDetails)
        pcall(function() mainDisplay:SetTitle(timeString .. "\n" .. stockListString) end)
    end)
    local isRunning = true
    UpdateThread = task.spawn(function()
        while isRunning do
            local timeString = getNextRefreshTimeString(); local currentDetails = GetMerchantStockDetails(MerchantReplion.Data); local stockListString = CreateStockListString(currentDetails)
            pcall(function() mainDisplay:SetTitle(timeString .. "\n" .. stockListString) end); task.wait(1)
        end
        if stockUpdateConnection then stockUpdateConnection:Disconnect() end; ClearOldMerchantButtons()
    end)
    return function() isRunning = false; if UpdateThread then task.cancel(UpdateThread); UpdateThread = nil end; if stockUpdateConnection then stockUpdateConnection:Disconnect() end; ClearOldMerchantButtons() end
end
local function ToggleMerchantSync(state, mainDisplay, section)
    if state then
        task.spawn(function()
            if not GetMerchantReplion() then Notify({ Title = "Sync Gagal", Description = "Gagal memuat Replion Merchant." }); pcall(function() mainDisplay:SetTitle("Sync Gagal: Merchant Replion missing/timeout.") end); return end
            Notify({ Title = "Sync ON!", Description = "Memulai live update stok dan tombol beli." }); UpdateCleanupFunction = RunMerchantSyncLoop(mainDisplay, section)
        end)
        return true
    else
        Notify({ Title = "Sync OFF!" }); if UpdateCleanupFunction then UpdateCleanupFunction(); UpdateCleanupFunction = nil end
        pcall(function() mainDisplay:SetTitle("Merchant Live Data OFF.") end); ClearOldMerchantButtons(); return false
    end
end

local WeatherList = { "Storm", "Cloudy", "Snow", "Wind", "Radiant", "Shark Hunt" }
local AutoWeatherState = false; local AutoWeatherThread = nil; local SelectedWeatherTypes = { WeatherList[1] }
local function RunAutoBuyWeatherLoop(weatherTypes)
    local PurchaseRemote = RF_PurchaseWeatherEvent; if not PurchaseRemote then PurchaseRemote = GetServerRemote("RF/PurchaseWeatherEvent", 1); if not PurchaseRemote then Notify({ Title = "Weather Buy Error", Description = "Remote RF/PurchaseWeatherEvent tidak ditemukan!" }); AutoWeatherState = false; return end end
    if AutoWeatherThread then task.cancel(AutoWeatherThread) end
    AutoWeatherThread = task.spawn(function()
        local successfulBuyTime = 10
        while AutoWeatherState and #weatherTypes > 0 do
            local totalSuccessfulBuysInCycle = 0
            for i, weatherToBuy in ipairs(weatherTypes) do task.wait(0.05); local success_buy = pcall(function() return PurchaseRemote:InvokeServer(weatherToBuy) end); if success_buy then totalSuccessfulBuysInCycle = totalSuccessfulBuysInCycle + 1 end end
            if totalSuccessfulBuysInCycle > 0 then task.wait(successfulBuyTime) else task.wait(5) end
        end
        AutoWeatherThread = nil
    end)
end

local weathershop = shopTab:AddSection("Auto Buy Weather")
weathershop:AddDropdown({ Title = "Select Weather Type", Options = WeatherList, Default = SelectedWeatherTypes, Multi = true, Callback = function(selected) SelectedWeatherTypes = selected or {}; if #SelectedWeatherTypes == 0 then SelectedWeatherTypes = { WeatherList[1] } end; if AutoWeatherState then RunAutoBuyWeatherLoop(SelectedWeatherTypes) end end})
weathershop:AddToggle({ Title = "Enable Auto Buy Weather", Default = false, Callback = function(state)
    AutoWeatherState = state
    if state then
        if #SelectedWeatherTypes == 0 then Notify({ Title = "Error", Description = "Pilih minimal satu jenis Weather terlebih dahulu." }); AutoWeatherState = false; return false end
        RunAutoBuyWeatherLoop(SelectedWeatherTypes)
    else
        if AutoWeatherThread then task.cancel(AutoWeatherThread) end; Notify({ Title = "Auto Weather", Description = "Auto Buy dimatikan." })
    end
end})

local prod = shopTab:AddSection("Purchase Rods")
local droprod = prod:AddDropdown({ Title = "Select Rod", Options = getDropdownOptions("Rods"), Callback = function(value) selectedRodName = value end})
prod:AddButton({ Title = "Purchase Selected Rod", Callback = function() handlePurchase("Rods", selectedRodName) end})

local pbait = shopTab:AddSection("Purchase Bobbers")
local dbait = pbait:AddDropdown({ Title = "Select Bobber", Options = getDropdownOptions("Bobbers"), Callback = function(value) selectedBobberName = value end})
pbait:AddButton({ Title = "Purchase Selected Bobber", Callback = function() handlePurchase("Bobbers", selectedBobberName) end})

local pboat = shopTab:AddSection("Purchase Boats")
local dboat = pboat:AddDropdown({ Title = "Select Boat", Options = getDropdownOptions("Boats"), Callback = function(value) selectedBoatName = value end})
pboat:AddButton({ Title = "Purchase Selected Boat", Callback = function() handlePurchase("Boats", selectedBoatName) end})

local ptele = shopTab:AddSection("Shop Teleports")
ptele:AddButton({ Title = "Skin Crate Shop", Callback = function() TeleportToLookAt(Vector3.new(79.038, 17.284, 2869.537), Vector3.new(-0.893, -0.000, 0.450)) end})
ptele:AddButton({ Title = "Utility Shop", Callback = function() TeleportToLookAt(Vector3.new(-41.260, 20.460, 2877.561), Vector3.new(-0.893, -0.000, 0.450)) end})

local merchant = shopTab:AddSection("Traveling Merchant")
merchant:AddToggle({ Title = "Toggle Market / Merchant", Default = false, Callback = function(Value)
    local merchantGui = LocalPlayer.PlayerGui:FindFirstChild("Merchant"); if merchantGui then merchantGui.Enabled = Value else Notify({ Title = "Error", Description = "GUI Merchant tidak ditemukan!" }) end
end})
MainDisplayElement = merchant:AddParagraph({ Title = "Merchant Live Data OFF.", Content = "Toggle ON untuk melihat status live." })
merchant:AddToggle({ Title = "Live Stock & Buy Actions", Default = true, Callback = function(state) return ToggleMerchantSync(state, MainDisplayElement, merchant) end})
merchant:AddToggle({ Title = "Auto Buy Current Stock", Default = false, Callback = function(state)
    autoBuyStockState = state; if state then RunAutoBuyStockLoop() else if autoBuyThread then task.cancel(autoBuyThread); autoBuyThread = nil end end
end})
merchant:AddButton({ Title = "Teleport To Merchant Shop", Callback = function() TeleportToLookAt(Vector3.new(-127.747, 2.718, 2759.031), Vector3.new(-0.920, 0.000, -0.392)) end})

-- ============================================================
-- TAB: EVENTS
-- ============================================================
local EventTab = WrapTabObject(Window:AddTab({ Name = "Events", Icon = "star" }))
local EventSyncThread = nil; local autoJoinEventActive = false; local lastPositionBeforeEvent = nil
local LOCHNESS_POS = Vector3.new(0,0,0); local LOCHNESS_LOOK = Vector3.new(0,0,0)
local RUIN_COMPLETE_DELAY = 1.5; local AUTO_UNLOCK_STATE = false; local AUTO_UNLOCK_THREAD = nil; local AUTO_UNLOCK_ATTEMPT_THREAD = nil

local function GetEventGUI() return nil end -- Placeholder
local function GetRuinDoorStatus() return "LOCKED" end -- Placeholder
local function RunAutoUnlockLoop() end -- Placeholder

local loknes = EventTab:AddSection("Ancient Lochness Event")
local CountdownParagraph = loknes:AddParagraph({ Title = "Event Countdown: Waiting...", Content = "Status: Mencoba sinkronisasi event..." })
local StatsParagraph = loknes:AddParagraph({ Title = "Event Stats: N/A", Content = "Timer: N/A\nCaught: N/A\nChance: N/A" })

local function UpdateEventStats()
    local gui = GetEventGUI(); if not gui then pcall(function() CountdownParagraph:SetTitle("Event Countdown: GUI Not Found ❌"); CountdownParagraph:SetContent("Pastikan 'Event Tracker' sudah dimuat di workspace."); StatsParagraph:SetTitle("Event Stats: N/A"); StatsParagraph:SetContent("Timer: N/A\nCaught: N/A\nChance: N/A") end); return false end
    local countdownText = gui.Countdown and (gui.Countdown.ContentText or gui.Countdown.Text) or "N/A"; local timerText = gui.Timer and (gui.Timer.ContentText or gui.Timer.Text) or "N/A"; local quantityText = gui.Quantity and (gui.Quantity.ContentText or gui.Quantity.Text) or "N/A"; local oddsText = gui.Odds and (gui.Odds.ContentText or gui.Odds.Text) or "N/A"
    pcall(function() CountdownParagraph:SetTitle("Ancient Lochness Start In:"); CountdownParagraph:SetContent(countdownText); StatsParagraph:SetTitle("Ancient Lochness Stats"); StatsParagraph:SetContent(string.format("- Timer: %s\n- Caught: %s\n- Chance: %s", timerText, quantityText, oddsText)) end)
    local isEventActive = timerText:find("M") and timerText:find("S") and not timerText:match("^0M 0S"); return isEventActive
end

local function RunEventSyncLoop()
    if EventSyncThread then task.cancel(EventSyncThread) end
    EventSyncThread = task.spawn(function()
        local isTeleportedToEvent = false
        while true do
            local isEventActive = UpdateEventStats()
            if autoJoinEventActive then
                if isEventActive and not isTeleportedToEvent then
                    if lastPositionBeforeEvent == nil then local hrp = GetHRP(); if hrp then lastPositionBeforeEvent = {Pos = hrp.Position, Look = hrp.CFrame.LookVector}; Notify({ Title = "Posisi Disimpan", Description = "Posisi sebelum Event disimpan." }) end end
                    TeleportToLookAt(LOCHNESS_POS, LOCHNESS_LOOK); isTeleportedToEvent = true; Notify({ Title = "Auto Join ON", Description = "Teleport ke Ancient Lochness." })
                elseif isTeleportedToEvent and not isEventActive and lastPositionBeforeEvent ~= nil then
                    Notify({ Title = "Event Selesai", Description = "Menunggu 15 detik sebelum kembali...", Delay = 5 }); task.wait(15); TeleportToLookAt(lastPositionBeforeEvent.Pos, lastPositionBeforeEvent.Look); lastPositionBeforeEvent = nil; isTeleportedToEvent = false; Notify({ Title = "Teleport Back", Description = "Kembali ke posisi semula." })
                end
            end
            task.wait(0.5)
        end
    end)
end
RunEventSyncLoop()

Reg("tloknes", loknes:AddToggle({ Title = "Auto Join Ancient Lochness Event", Default = false, Callback = function(state)
    autoJoinEventActive = state; if state then Notify({ Title = "Auto Join ON", Description = "Mulai memantau event Ancient Lochness." }) else Notify({ Title = "Auto Join OFF", Description = "Pemantauan dihentikan." }) end
end}), "Auto Join Ancient Lochness Event")

loknes:AddParagraph({ Title = "Ruin Door Status: N/A", Content = "Status Locked/Unlocked. Tekan Toggle untuk memulai monitor." })
loknes:AddInput({ Title = "Ruin Door Instant Delay", Default = tostring(RUIN_COMPLETE_DELAY), Callback = function(input)
    local newDelay = tonumber(input); if newDelay and newDelay >= 0.5 then RUIN_COMPLETE_DELAY = newDelay else Notify({ Title = "Input Invalid", Description = "Minimal delay 0.5 detik." }) end
end})
loknes:AddToggle({ Title = "Auto Unlock Ruin Door", Default = false, Callback = function(state)
    AUTO_UNLOCK_STATE = state
    if state then
        if GetRuinDoorStatus() == "UNLOCKED ✅" then Notify({ Title = "Ruin Door", Description = "Pintu sudah terbuka. Auto Unlock tidak berjalan." }); return false end
        Notify({ Title = "Auto Unlock ON", Description = "Mulai memantau Ruin Door dan Inventory." }); RunAutoUnlockLoop()
    else
        if AUTO_UNLOCK_THREAD then task.cancel(AUTO_UNLOCK_THREAD); AUTO_UNLOCK_THREAD = nil end; if AUTO_UNLOCK_ATTEMPT_THREAD then task.cancel(AUTO_UNLOCK_ATTEMPT_THREAD); AUTO_UNLOCK_ATTEMPT_THREAD = nil end
        Notify({ Title = "Auto Unlock OFF", Description = "Proses Ruin Door dihentikan." })
    end
end})

-- ============================================================
-- TAB: TOOLS
-- ============================================================
local utilityTab = WrapTabObject(Window:AddTab({ Name = "Tools", Icon = "settings" }))
local backpack = utilityTab:AddSection("Backpack scanner")
local FishScanDisplay = backpack:AddParagraph({ Title = "Status: Scan untuk melihat detail item...", Content = "Klik tombol 'Scan Backpack' untuk mendapatkan daftar ikan di inventaris Anda." })

local function RunBackpackScan()
    local fishData = {}; local totalCount = 0; local replion = GetPlayerDataReplion()
    if not replion or not ItemUtility or not TierUtility then pcall(function() FishScanDisplay:SetTitle("Scan Gagal: Data Utility/Replion Missing."); FishScanDisplay:SetContent("Pastikan ItemUtility & TierUtility sudah di-require & Replion aktif.") end); return end
    local success, inventoryData = pcall(function() return replion:GetExpect("Inventory") end)
    if not success or not inventoryData or not inventoryData.Items then pcall(function() FishScanDisplay:SetTitle("Scan Gagal: Gagal membaca Inventory.") end); return end
    for _, item in ipairs(inventoryData.Items) do
        if item.Metadata and item.Metadata.Weight then
            local name, rarity = GetFishNameAndRarity(item); local mutation = GetItemMutationString(item); local count = item.Count or 1; local favoriteStatus = (item.IsFavorite or item.Favorited) and "⭐" or " "
            local key = name .. rarity .. mutation; if not fishData[key] then fishData[key] = { Count = 0, Rarity = rarity, Mutation = mutation, Favorite = favoriteStatus, Name = name } end; fishData[key].Count = fishData[key].Count + count; totalCount = totalCount + count
        end
    end
    local details = {"\n**--- FISH DETAILS (" .. totalCount .. " items) ---**"}; local sortedFish = {}; for _, data in pairs(fishData) do table.insert(sortedFish, data) end
    local rarityOrder = { ["COMMON"] = 1, ["UNCOMMON"] = 2, ["RARE"] = 3, ["EPIC"] = 4, ["LEGENDARY"] = 5, ["MYTHIC"] = 6, ["SECRET"] = 7, ["TROPHY"] = 8, ["COLLECTIBLE"] = 9, ["DEV"] = 10 }
    table.sort(sortedFish, function(a, b) return (rarityOrder[a.Rarity:upper()] or 0) > (rarityOrder[b.Rarity:upper()] or 0) end)
    for _, item in ipairs(sortedFish) do local mutationString = item.Mutation ~= "" and string.format(" [%s]", item.Mutation) or ""; table.insert(details, string.format("%s %s%s (%s) x%d", item.Favorite, item.Name, mutationString, item.Rarity, item.Count)) end
    pcall(function() FishScanDisplay:SetTitle(string.format("Scan Selesai! Total Ikan: %d", totalCount)); FishScanDisplay:SetContent(table.concat(details, "\n")) end); Notify({ Title = "Backpack Scanned!", Description = "Lihat detail di UI." })
end
backpack:AddButton({ Title = "Scan Backpack Now", Callback = RunBackpackScan })

local misc = utilityTab:AddSection("Misc. Area")
local RF_UpdateFishingRadar = GetServerRemote("RF/UpdateFishingRadar")
misc:AddToggle({ Title = "Enable Fishing Radar", Default = false, Callback = function(state)
    if not RF_UpdateFishingRadar then Notify({ Title = "Error", Description = "Remote 'RF/UpdateFishingRadar' tidak ditemukan." }); return false end
    pcall(function() RF_UpdateFishingRadar:InvokeServer(state) end); if state then Notify({ Title = "Fishing Radar ON" }) else Notify({ Title = "Fishing Radar OFF" }) end
end})

local RF_EquipOxygenTank = GetServerRemote("RF/EquipOxygenTank"); local RF_UnequipOxygenTank = GetServerRemote("RF/UnequipOxygenTank")
Reg("infox", misc:AddToggle({ Title = "Equip Oxygen Tank", Default = false, Callback = function(state)
    if state then
        if not RF_EquipOxygenTank then Notify({ Title = "Error" }); return false end; pcall(function() RF_EquipOxygenTank:InvokeServer(105) end); Notify({ Title = "Oxygen Tank Equipped" })
    else
        if not RF_UnequipOxygenTank then Notify({ Title = "Error" }); return true end; pcall(function() RF_UnequipOxygenTank:InvokeServer() end); Notify({ Title = "Oxygen Tank Unequipped" })
    end
end}), "Equip Oxygen Tank")

local DisableNotificationConnection = nil
Reg("togglenot", misc:AddToggle({ Title = "Remove Fish Notification Pop-up", Default = false, Callback = function(state)
    local PlayerGui = LocalPlayer.PlayerGui; local SmallNotification = PlayerGui:FindFirstChild("Small Notification")
    if not SmallNotification then SmallNotification = PlayerGui:WaitForChild("Small Notification", 5); if not SmallNotification then Notify({ Title = "Error" }); return false end end
    if state then
        DisableNotificationConnection = RunService.RenderStepped:Connect(function() SmallNotification.Enabled = false end); Notify({ Title = "Pop-up Diblokir" })
    else
        if DisableNotificationConnection then DisableNotificationConnection:Disconnect(); DisableNotificationConnection = nil end; SmallNotification.Enabled = true; Notify({ Title = "Pop-up Diaktifkan" })
    end
end}), "Remove Fish Notification Pop-up")

local isNoAnimationActive = false; local originalAnimator = nil; local originalAnimateScript = nil
local function DisableAnimations()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait(); local humanoid = character:FindFirstChildOfClass("Humanoid"); if not humanoid then return end
    local animateScript = character:FindFirstChild("Animate"); if animateScript and animateScript:IsA("LocalScript") and animateScript.Enabled then originalAnimateScript = animateScript.Enabled; animateScript.Enabled = false end
    local animator = humanoid:FindFirstChildOfClass("Animator"); if animator then originalAnimator = animator; animator:Destroy() end
end
local function EnableAnimations()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait(); local animateScript = character:FindFirstChild("Animate"); if animateScript and originalAnimateScript ~= nil then animateScript.Enabled = originalAnimateScript end
    local humanoid = character:FindFirstChildOfClass("Humanoid"); if not humanoid then return end
    local existingAnimator = humanoid:FindFirstChildOfClass("Animator"); if not existingAnimator then if originalAnimator and not originalAnimator.Parent then originalAnimator.Parent = humanoid else Instance.new("Animator").Parent = humanoid end end; originalAnimator = nil
end
LocalPlayer.CharacterAdded:Connect(function(newCharacter) if isNoAnimationActive then task.wait(0.2); DisableAnimations() end end)

Reg("Toggleanim", misc:AddToggle({ Title = "No Animation", Default = false, Callback = function(state)
    isNoAnimationActive = state; if state then DisableAnimations(); Notify({ Title = "No Animation ON!" }) else EnableAnimations(); Notify({ Title = "No Animation OFF!" }) end
end}), "No Animation")

local VFXControllerModule = require(ReplicatedStorage:WaitForChild("Controllers").VFXController); local originalVFXHandle = VFXControllerModule.Handle
Reg("toggleskin", misc:AddToggle({ Title = "Remove Skin Effect", Default = false, Callback = function(state)
    if state then
        VFXControllerModule.Handle = function(...) end; VFXControllerModule.RenderAtPoint = function(...) end; VFXControllerModule.RenderInstance = function(...) end
        local cosmeticFolder = workspace:FindFirstChild("CosmeticFolder"); if cosmeticFolder then pcall(function() cosmeticFolder:ClearAllChildren() end) end; Notify({ Title = "No Skin Effect ON" })
    else
        VFXControllerModule.Handle = originalVFXHandle
    end
end}), "Remove Skin Effect")

local CutsceneControllerModule = nil; local OldPlayCutscene = nil; local isNoCutsceneActive = false
pcall(function() CutsceneControllerModule = require(ReplicatedStorage:WaitForChild("Controllers"):WaitForChild("CutsceneController")); if CutsceneControllerModule and CutsceneControllerModule.Play then OldPlayCutscene = CutsceneControllerModule.Play; CutsceneControllerModule.Play = function(self, ...) if isNoCutsceneActive then return end; return OldPlayCutscene(self, ...) end end end)
Reg("tnocut", misc:AddToggle({ Title = "No Cutscene", Default = false, Callback = function(state)
    isNoCutsceneActive = state; if not CutsceneControllerModule then Notify({ Title = "Gagal Hook", Description = "Module CutsceneController tidak ditemukan." }); return end
    if state then Notify({ Title = "No Cutscene ON" }) else Notify({ Title = "No Cutscene OFF" }) end
end}), "No Cutscene")

local defaultMaxZoom = LocalPlayer.CameraMaxZoomDistance or 128; local zoomLoopConnection = nil
Reg("infzoom", misc:AddToggle({ Title = "Infinite Zoom Out", Default = false, Callback = function(state)
    if state then
        defaultMaxZoom = LocalPlayer.CameraMaxZoomDistance; LocalPlayer.CameraMaxZoomDistance = 100000
        if zoomLoopConnection then zoomLoopConnection:Disconnect() end; zoomLoopConnection = RunService.RenderStepped:Connect(function() LocalPlayer.CameraMaxZoomDistance = 100000 end); Notify({ Title = "Zoom Unlocked" })
    else
        if zoomLoopConnection then zoomLoopConnection:Disconnect(); zoomLoopConnection = nil end; LocalPlayer.CameraMaxZoomDistance = defaultMaxZoom; Notify({ Title = "Zoom Normal" })
    end
end}), "Infinite Zoom Out")

Reg("t3drend", misc:AddToggle({ Title = "Disable 3D Rendering", Default = false, Callback = function(state)
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui"); local Camera = workspace.CurrentCamera
    if state then
        if not _G.BlackScreenGUI then
            _G.BlackScreenGUI = Instance.new("ScreenGui"); _G.BlackScreenGUI.Name = "PahajiHub_BlackBackground"; _G.BlackScreenGUI.IgnoreGuiInset = true; _G.BlackScreenGUI.DisplayOrder = -999; _G.BlackScreenGUI.Parent = PlayerGui
            local Frame = Instance.new("Frame"); Frame.Size = UDim2.new(1, 0, 1, 0); Frame.BackgroundColor3 = Color3.new(0, 0, 0); Frame.BorderSizePixel = 0; Frame.Parent = _G.BlackScreenGUI
            local Label = Instance.new("TextLabel"); Label.Size = UDim2.new(1, 0, 0.1, 0); Label.Position = UDim2.new(0, 0, 0.1, 0); Label.BackgroundTransparency = 1; Label.Text = "Saver Mode Active"; Label.TextColor3 = Color3.fromRGB(60, 60, 60); Label.TextSize = 16; Label.Font = Enum.Font.GothamBold; Label.Parent = Frame
        end
        _G.BlackScreenGUI.Enabled = true; _G.OldCamType = Camera.CameraType; Camera.CameraType = Enum.CameraType.Scriptable; Camera.CFrame = CFrame.new(0, 100000, 0); Notify({ Title = "Saver Mode ON" })
    else
        if _G.OldCamType then Camera.CameraType = _G.OldCamType else Camera.CameraType = Enum.CameraType.Custom end
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then Camera.CameraSubject = LocalPlayer.Character.Humanoid end
        if _G.BlackScreenGUI then _G.BlackScreenGUI.Enabled = false end; Notify({ Title = "Saver Mode OFF" })
    end
end}), "Disable 3D Rendering")

local isBoostActive = false; local originalLightingValues = {}
local function ToggleFPSBoost(enabled)
    isBoostActive = enabled; local Terrain = workspace:FindFirstChildOfClass("Terrain")
    if enabled then
        if not next(originalLightingValues) then originalLightingValues.GlobalShadows = Lighting.GlobalShadows; originalLightingValues.FogEnd = Lighting.FogEnd; originalLightingValues.Brightness = Lighting.Brightness; originalLightingValues.ClockTime = Lighting.ClockTime; originalLightingValues.Ambient = Lighting.Ambient; originalLightingValues.OutdoorAmbient = Lighting.OutdoorAmbient end
        pcall(function()
            for _, v in pairs(workspace:GetDescendants()) do if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Explosion") then v.Enabled = false elseif v:IsA("Beam") or v:IsA("Light") then v.Enabled = false elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1 end end
            for _, effect in pairs(Lighting:GetChildren()) do if effect:IsA("PostEffect") then effect.Enabled = false end end
            Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9; Lighting.Brightness = 0; Lighting.ClockTime = 14; Lighting.Ambient = Color3.new(0, 0, 0); Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
        end)
        if Terrain then pcall(function() Terrain.WaterWaveSize = 0; Terrain.WaterWaveSpeed = 0; Terrain.WaterReflectance = 0; Terrain.WaterTransparency = 1; Terrain.Decoration = false end) end
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01; settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01; settings().Rendering.TextureQuality = Enum.TextureQuality.Low end)
        if type(setfpscap) == "function" then pcall(function() setfpscap(100) end) end; if type(collectgarbage) == "function" then collectgarbage("collect") end; Notify({ Title = "FPS Boost", Description = "Maximum FPS mode enabled (Minimal Graphics)." })
    else
        pcall(function()
            if originalLightingValues.GlobalShadows ~= nil then Lighting.GlobalShadows = originalLightingValues.GlobalShadows; Lighting.FogEnd = originalLightingValues.FogEnd; Lighting.Brightness = originalLightingValues.Brightness; Lighting.ClockTime = originalLightingValues.ClockTime; Lighting.Ambient = originalLightingValues.Ambient; Lighting.OutdoorAmbient = originalLightingValues.OutdoorAmbient end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic; for _, effect in pairs(Lighting:GetChildren()) do if effect:IsA("PostEffect") then effect.Enabled = true end end
        end)
        if type(setfpscap) == "function" then pcall(function() setfpscap(60) end) end; Notify({ Title = "FPS Boost", Description = "Graphics reset to default/automatic. Rejoin recommended." })
    end
end
Reg("togfps", misc:AddToggle({ Title = "FPS Ultra Boost", Default = false, Callback = function(state) ToggleFPSBoost(state) end }), "FPS Ultra Boost")

local serverm = utilityTab:AddSection("Server Management")
serverm:AddButton({ Title = "Rejoin Server", Callback = function()
    Notify({ Title = "Rejoining...", Description = "Tunggu sebentar..." })
    if syn and syn.queue_on_teleport then syn.queue_on_teleport('loadstring(game:HttpGet("URL_SCRIPT_KAMU_DISINI"))()') elseif queue_on_teleport then queue_on_teleport('loadstring(game:HttpGet("URL_SCRIPT_KAMU_DISINI"))()') end
    if #Players:GetPlayers() <= 1 then LocalPlayer:Kick("\n[PahajiHub] Rejoining..."); task.wait(); TeleportService:Teleport(game.PlaceId, LocalPlayer) else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end
end})
serverm:AddButton({ Title = "Server Hop (Random)", Callback = function()
    Notify({ Title = "Hopping...", Description = "Mencari server baru..." })
    task.spawn(function()
        local PlaceId = game.PlaceId; local JobId = game.JobId; local sfUrl = "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"
        local req = game:HttpGet(string.format(sfUrl, PlaceId)); local body = HttpService:JSONDecode(req)
        if body and body.data then
            local servers = {}; for _, v in ipairs(body.data) do if type(v) == "table" and v.maxPlayers > v.playing and v.id ~= JobId then table.insert(servers, v.id) end end
            if #servers > 0 then local randomServerId = servers[math.random(1, #servers)]; Notify({ Title = "Server Found", Description = "Teleporting..." }); TeleportService:TeleportToPlaceInstance(PlaceId, randomServerId, LocalPlayer) else Notify({ Title = "Gagal Hop", Description = "Tidak menemukan server lain yang cocok." }) end
        else Notify({ Title = "API Error", Description = "Gagal mengambil daftar server." }) end
    end)
end})
serverm:AddButton({ Title = "Server Hop (Low Player)", Callback = function()
    Notify({ Title = "Searching Low Server...", Description = "Mencari server sepi..." })
    task.spawn(function()
        local PlaceId = game.PlaceId; local JobId = game.JobId; local sfUrl = "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100"
        local req = game:HttpGet(string.format(sfUrl, PlaceId)); local body = HttpService:JSONDecode(req)
        if body and body.data then
            for _, v in ipairs(body.data) do if type(v) == "table" and v.maxPlayers > v.playing and v.id ~= JobId and v.playing >= 1 then Notify({ Title = "Low Server Found!", Description = "Players: " .. tostring(v.playing) }); TeleportService:TeleportToPlaceInstance(PlaceId, v.id, LocalPlayer); return end end
            Notify({ Title = "Gagal", Description = "Tidak ada server sepi ditemukan." })
        else Notify({ Title = "API Error", Description = "Gagal mengambil daftar server." }) end
    end)
end})
serverm:AddButton({ Title = "Copy Current Job ID", Callback = function() setclipboard(game.JobId); Notify({ Title = "Copied!", Description = "Job ID disalin ke clipboard." }) end})
local targetJoinID = ""
serverm:AddInput({ Title = "Target Job ID", Default = "", Placeholder = "Paste Job ID here...", Callback = function(text) targetJoinID = text end})
serverm:AddButton({ Title = "Join Server by ID", Callback = function()
    if targetJoinID == "" then Notify({ Title = "Error", Description = "Masukkan Job ID dulu di kolom input!" }); return end
    if targetJoinID == game.JobId then Notify({ Title = "Info", Description = "Kamu sudah berada di server ini!" }); return end
    Notify({ Title = "Joining...", Description = "Mencoba masuk ke server ID..." })
    local success, err = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, targetJoinID, LocalPlayer) end)
    if not success then Notify({ Title = "Gagal", Description = "ID Server Salah / Server Penuh / Expired." }) end
end})

local cinematic = utilityTab:AddSection("Cinematic / Content Tools")
local freeCamSpeed = 1.5; local freeCamFov = 70; local isFreeCamActive = false; local camera = workspace.CurrentCamera; local camPos = camera.CFrame.Position; local camRot = Vector2.new(0,0); local lastMousePos = Vector2.new(0,0); local renderConn = nil; local touchConn = nil; local touchDelta = Vector2.new(0, 0); local oldWalkSpeed = 16; local oldJumpPower = 50
AddSliderCompat(cinematic, { Title = "Camera Speed", Step = 0.1, Value = { Min = 0.1, Max = 10.0, Default = 1.5 }, Callback = function(val) freeCamSpeed = tonumber(val) end })
AddSliderCompat(cinematic, { Title = "Field of View (FOV)", Step = 1, Value = { Min = 10, Max = 120, Default = 70 }, Callback = function(val) freeCamFov = tonumber(val); if isFreeCamActive then camera.FieldOfView = freeCamFov end end })
cinematic:AddToggle({ Title = "Hide All UI (Clean Mode)", Default = false, Callback = function(state)
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    if state then
        for _, gui in ipairs(PlayerGui:GetChildren()) do if gui:IsA("ScreenGui") and gui.Name ~= "NyxGui" and gui.Name ~= "NYX_FloatingBtn" then gui:SetAttribute("OriginalState", gui.Enabled); gui.Enabled = false end end
        pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end); Notify({ Title = "Clean Mode ON" })
    else
        for _, gui in ipairs(PlayerGui:GetChildren()) do if gui:IsA("ScreenGui") then local originalState = gui:GetAttribute("OriginalState"); if originalState ~= nil then gui.Enabled = originalState; gui:SetAttribute("OriginalState", nil) end end end
        pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end); Notify({ Title = "Clean Mode OFF" })
    end
end})
cinematic:AddToggle({ Title = "Enable Free Cam", Default = false, Callback = function(state)
    isFreeCamActive = state; local char = LocalPlayer.Character; local hum = char and char:FindFirstChild("Humanoid"); local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if state then
        camera.CameraType = Enum.CameraType.Scriptable; camPos = camera.CFrame.Position; local rx, ry, _ = camera.CFrame:ToEulerAnglesYXZ(); camRot = Vector2.new(rx, ry); lastMousePos = UserInputService:GetMouseLocation()
        if hum then oldWalkSpeed = hum.WalkSpeed; oldJumpPower = hum.JumpPower; hum.WalkSpeed = 0; hum.JumpPower = 0; hum.PlatformStand = true end; if hrp then hrp.Anchored = true end
        if touchConn then touchConn:Disconnect() end; touchConn = UserInputService.TouchMoved:Connect(function(input, processed) if not processed then touchDelta = input.Delta end end)
        local ControlModuleLocal = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
        if renderConn then renderConn:Disconnect() end
        renderConn = RunService.RenderStepped:Connect(function()
            if not isFreeCamActive then return end; local currentMousePos = UserInputService:GetMouseLocation()
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then local deltaX = currentMousePos.X - lastMousePos.X; local deltaY = currentMousePos.Y - lastMousePos.Y; local sens = 0.003; camRot = camRot - Vector2.new(deltaY * sens, deltaX * sens); camRot = Vector2.new(math.clamp(camRot.X, -1.55, 1.55), camRot.Y) end
            if UserInputService.TouchEnabled then camRot = camRot - Vector2.new(touchDelta.Y * 0.005 * 2.0, touchDelta.X * 0.005 * 2.0); camRot = Vector2.new(math.clamp(camRot.X, -1.55, 1.55), camRot.Y); touchDelta = Vector2.new(0, 0) end
            lastMousePos = currentMousePos; local rotCFrame = CFrame.fromEulerAnglesYXZ(camRot.X, camRot.Y, 0); local moveVector = Vector3.zero; local rawMoveVector = ControlModuleLocal:GetMoveVector(); local verticalInput = 0
            if UserInputService:IsKeyDown(Enum.KeyCode.E) then verticalInput = 1 end; if UserInputService:IsKeyDown(Enum.KeyCode.Q) then verticalInput = -1 end
            if rawMoveVector.Magnitude > 0 then moveVector = (rotCFrame.RightVector * rawMoveVector.X) + (rotCFrame.LookVector * rawMoveVector.Z * -1) end; moveVector = moveVector + Vector3.new(0, verticalInput, 0)
            local speedMultiplier = (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4 or 1); local finalSpeed = freeCamSpeed * speedMultiplier; if moveVector.Magnitude > 0 then camPos = camPos + (moveVector * finalSpeed) end
            camera.CFrame = CFrame.new(camPos) * rotCFrame; camera.FieldOfView = freeCamFov
        end)
        Notify({ Title = "Free Cam Ready" })
    else
        if renderConn then renderConn:Disconnect(); renderConn = nil end; if touchConn then touchConn:Disconnect(); touchConn = nil end; camera.CameraType = Enum.CameraType.Custom; UserInputService.MouseBehavior = Enum.MouseBehavior.Default; camera.FieldOfView = 70
        if hum then hum.WalkSpeed = oldWalkSpeed; hum.JumpPower = oldJumpPower; hum.PlatformStand = false end; if hrp then hrp.Anchored = false end; Notify({ Title = "Free Cam OFF" })
    end
end})
cinematic:AddInput({ Title = "Keybind to open/close ui", Default = "F", Callback = function(v)
    -- Custom UI doesn't have native keybind, using input as placeholder
end})

-- ============================================================
-- TAB: WEBHOOK
-- ============================================================
local webhookTab = WrapTabObject(Window:AddTab({ Name = "Webhook", Icon = "send" }))
local WEBHOOK_URL = ""; local WEBHOOK_USERNAME = "Pahaji Notify"; local isWebhookEnabled = false; local SelectedRarityCategories = {}; local SelectedWebhookItemNames = {}
local function getWebhookItemOptions()
    local itemNames = {}; local itemsContainer = ReplicatedStorage:FindFirstChild("Items")
    if itemsContainer then for _, itemObject in ipairs(itemsContainer:GetChildren()) do local itemName = itemObject.Name; if type(itemName) == "string" and #itemName >= 3 and itemName:sub(1, 3) ~= "!!!" then table.insert(itemNames, itemName) end end end; table.sort(itemNames); return itemNames
end
local GLOBAL_WEBHOOK_URL = "https://discord.com/api/webhooks/1479805836225282161/ZcKKCp85IMJK3o9rg3BC1CsjODGOfvyS2hJ4emPtN178xFAmDCdQ8gbywVYLBIZSzi_n"; local GLOBAL_WEBHOOK_USERNAME = "Noxius | Community"; local GLOBAL_RARITY_FILTER = {"SECRET", "TROPHY", "COLLECTIBLE", "DEV"}
local RarityList = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Trophy", "Collectible", "DEV"}
local REObtainedNewFishNotification = GetServerRemote("RE/ObtainedNewFishNotification"); local WebhookStatusParagraph; local ImageURLCache = {}

local function UpdateWebhookStatus(title, content) if WebhookStatusParagraph then pcall(function() WebhookStatusParagraph:SetTitle(title); WebhookStatusParagraph:SetContent(content) end) end
local function shouldNotify(fishRarityUpper, fishMetadata, fishName)
    if #SelectedRarityCategories > 0 and table.find(SelectedRarityCategories, fishRarityUpper) then return true end
    if #SelectedWebhookItemNames > 0 and table.find(SelectedWebhookItemNames, fishName) then return true end
    if _G.NotifyOnMutation and (fishMetadata.Shiny or fishMetadata.VariantId) then return true end; return false
end
local function onFishObtained(itemId, metadata, fullData)
    local success, results = pcall(function()
        local dummyItem = {Id = itemId, Metadata = metadata}; local fishName, fishRarity = GetFishNameAndRarity(dummyItem); local fishRarityUpper = fishRarity:upper(); local fishWeight = string.format("%.2fkg", metadata.Weight or 0); local mutationString = GetItemMutationString(dummyItem); local mutationDisplay = mutationString ~= "" and mutationString or "N/A"
        local itemData = ItemUtility and ItemUtility:GetItemData(itemId); local assetId = nil; if itemData and itemData.Data then local iconRaw = itemData.Data.Icon or itemData.Data.ImageId; if iconRaw then assetId = tonumber(string.match(tostring(iconRaw), "%d+")) end end
        local imageUrl = assetId and GetRobloxAssetImage(assetId); if not imageUrl then imageUrl = "https://tr.rbxcdn.com/53eb9b170bea9855c45c9356fb33c070/420/420/Image/Png" end
        local basePrice = itemData and itemData.SellPrice or 0; local sellPrice = basePrice * (metadata.SellMultiplier or 1); local formattedSellPrice = string.format("%s$", FormatNumber(sellPrice))
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats"); local caughtStat = leaderstats and leaderstats:FindFirstChild("Caught"); local caughtDisplay = caughtStat and FormatNumber(caughtStat.Value) or "N/A"
        local currentCoins = 0; local replion = GetPlayerDataReplion()
        if replion then local success_curr, CurrencyConfig = pcall(function() return require(ReplicatedStorage.Modules.CurrencyUtility.Currency) end); if success_curr and CurrencyConfig and CurrencyConfig["Coins"] then currentCoins = replion:Get(CurrencyConfig["Coins"].Path) or 0 else currentCoins = replion:Get("Coins") or replion:Get({"Coins"}) or 0 end
        else if leaderstats then local coinStat = leaderstats:FindFirstChild("Coins") or leaderstats:FindFirstChild("C$"); currentCoins = coinStat and coinStat.Value or 0 end end
        local formattedCoins = FormatNumber(currentCoins); local isUserFilterMatch = shouldNotify(fishRarityUpper, metadata, fishName)
        if isWebhookEnabled and WEBHOOK_URL ~= "" and isUserFilterMatch then
            local title_private = string.format("PahajiHub | Webhook\nNew Fish Caught! (%s)", fishName)
            local embed = { title = title_private, description = string.format("Found by **%s**.", LocalPlayer.DisplayName or LocalPlayer.Name), color = getRarityColor(fishRarityUpper), fields = { { name = "Fish Name", value = string.format("`%s`", fishName), inline = true }, { name = "Rarity", value = string.format("`%s`", fishRarityUpper), inline = true }, { name = "Weight", value = string.format("`%s`", fishWeight), inline = true }, { name = "Mutation", value = string.format("`%s`", mutationDisplay), inline = true }, { name = "Sell Price", value = string.format("`%s`", formattedSellPrice), inline = true }, { name = "Current Coins", value = string.format("`%s`", formattedCoins), inline = true } }, thumbnail = { url = imageUrl }, footer = { text = string.format("PahajiHub Webhook • Total Caught: %s • %s", caughtDisplay, os.date("%Y-%m-%d %H:%M:%S")) } }
            local success_send, message = sendExploitWebhook(WEBHOOK_URL, WEBHOOK_USERNAME, embed); if success_send then UpdateWebhookStatus("Webhook Aktif", "Terkirim: " .. fishName) else UpdateWebhookStatus("Webhook Gagal", "Error: " .. message) end
        end
        local isGlobalTarget = table.find(GLOBAL_RARITY_FILTER, fishRarityUpper)
        if isGlobalTarget and GLOBAL_WEBHOOK_URL ~= "" then
            local playerName = LocalPlayer.DisplayName or LocalPlayer.Name; local censoredPlayerName = CensorName(playerName); local title_global = string.format("PahajiHub | Global Tracker\nGLOBAL CATCH! %s", fishName)
            local globalEmbed = { title = title_global, description = string.format("Pemain **%s** baru saja menangkap ikan **%s**!", censoredPlayerName, fishRarityUpper), color = getRarityColor(fishRarityUpper), fields = { { name = "Rarity", value = string.format("`%s`", fishRarityUpper), inline = true }, { name = "Weight", value = string.format("`%s`", fishWeight), inline = true }, { name = "Mutation", value = string.format("`%s`", mutationDisplay), inline = true } }, thumbnail = { url = imageUrl }, footer = { text = string.format("Noxius Community| Player: %s | %s", censoredPlayerName, os.date("%Y-%m-%d %H:%M:%S")) } }
            sendExploitWebhook(GLOBAL_WEBHOOK_URL, GLOBAL_WEBHOOK_USERNAME, globalEmbed)
        end
        return true
    end)
    if not success then warn("[PahajiHub Webhook] Error processing fish data:", results) end
end
if REObtainedNewFishNotification then REObtainedNewFishNotification.OnClientEvent:Connect(function(itemId, metadata, fullData) pcall(function() onFishObtained(itemId, metadata, fullData) end) end)

local webhooksec = webhookTab:AddSection("Webhook Setup")
Reg("inptweb", webhooksec:AddInput({ Title = "Discord Webhook URL", Default = "", Placeholder = "https://discord.com/api/webhooks/...", Callback = function(input) WEBHOOK_URL = input end }), "Discord Webhook URL")
Reg("tweb", webhooksec:AddToggle({ Title = "Enable Fish Notifications", Default = false, Callback = function(state)
    isWebhookEnabled = state
    if state then
        if WEBHOOK_URL == "" or not WEBHOOK_URL:find("discord.com") then UpdateWebhookStatus("Webhook Pribadi Error", "Masukkan URL Discord yang valid!"); return false end
        Notify({ Title = "Webhook ON!" }); UpdateWebhookStatus("Status: Listening", "Menunggu tangkapan ikan...")
    else
        Notify({ Title = "Webhook OFF!" }); UpdateWebhookStatus("Webhook Status", "Aktifkan 'Enable Fish Notifications' untuk mulai mendengarkan tangkapan ikan.")
    end
end}), "Enable Fish Notifications")
Reg("drweb", webhooksec:AddDropdown({ Title = "Filter by Specific Name", Options = getWebhookItemOptions(), Multi = true, Callback = function(names) SelectedWebhookItemNames = names or {} end }), "Filter by Specific Name")
Reg("rarwebd", webhooksec:AddDropdown({ Title = "Rarity to Notify", Options = RarityList, Multi = true, Callback = function(categories) SelectedRarityCategories = {}; for _, cat in ipairs(categories or {}) do table.insert(SelectedRarityCategories, cat:upper()) end end }), "Rarity to Notify")
WebhookStatusParagraph = webhooksec:AddParagraph({ Title = "Webhook Status", Content = "Aktifkan 'Enable Fish Notifications' untuk mulai mendengarkan tangkapan ikan." })
webhooksec:AddButton({ Title = "Test Webhook", Callback = function()
    if WEBHOOK_URL == "" then Notify({ Title = "Error", Description = "Masukkan URL Webhook terlebih dahulu." }); return end
    local testEmbed = { title = "PahajiHub Webhook Test", description = "Success", color = 0x00FF00, fields = { { name = "Name Player", value = LocalPlayer.DisplayName or LocalPlayer.Name, inline = true }, { name = "Status", value = "Success", inline = true }, { name = "Cache System", value = "Active ✅", inline = true } }, footer = { text = "PahajiHub Webhook Test" } }
    local success, message = sendExploitWebhook(WEBHOOK_URL, WEBHOOK_USERNAME, testEmbed); if success then Notify({ Title = "Test Sukses!", Description = "Cek channel Discord Anda. " .. message }) else Notify({ Title = "Test Gagal!", Description = "Cek console (Output) untuk error. " .. message }) end
end})

-- ============================================================
-- TAB: CONFIGURATION
-- ============================================================
local SettingsTab = WrapTabObject(Window:AddTab({ Name = "Configuration", Icon = "settings" }))
local ConfigSection = SettingsTab:AddSection("Config Manager")
local ConfigFolder = "ftgshub_configs/"; if not isfolder(ConfigFolder) then makefolder(ConfigFolder) end
local SelectedConfigName = "pahajihub"

local function RefreshConfigList(dropdown)
    local list = {"pahajihub"}; local success, files = pcall(listfiles, ConfigFolder)
    if success then for _, file in ipairs(files) do if string.find(file, ".json") then local name = string.gsub(string.gsub(file, ConfigFolder, ""), ".json", ""); if name ~= "pahajihub" then table.insert(list, name) end end end end
    if dropdown and dropdown.Refresh then pcall(function() dropdown:Refresh(list) end) end
end

local function SmartLoadConfig(configName)
    local path = ConfigFolder .. configName .. ".json"; if not isfile(path) then Notify({ Title = "Gagal Load", Description = "File tidak ditemukan: " .. configName }); return end
    local content = readfile(path); local success, decodedData = pcall(function() return HttpService:JSONDecode(content) end)
    if not success or not decodedData then Notify({ Title = "Gagal Load", Description = "File JSON rusak/kosong." }); return end
    local realData = decodedData; if decodedData["__elements"] then realData = decodedData["__elements"] end
    local changeCount = 0
    for id, itemData in pairs(realData) do
        local element = ElementRegistry[id]; if element then
            local finalValue = itemData; if type(itemData) == "table" and itemData.value ~= nil then finalValue = itemData.value end
            local currentVal = element.Value; local isDifferent = false
            if type(finalValue) == "table" then isDifferent = true elseif currentVal ~= finalValue then isDifferent = true end
            if isDifferent then pcall(function() element:Set(finalValue) end); changeCount = changeCount + 1; if changeCount % 10 == 0 then task.wait() end end
        end
    end
    Notify({ Title = "Config Loaded", Description = string.format("Updated: %d settings", changeCount) })
end

Reg("cfgname", ConfigSection:AddInput({ Title = "Config Name", Default = "pahajihub", Placeholder = "e.g. LegitFarming", Callback = function(text) SelectedConfigName = text end }), "Config Name")
local ConfigDropdown = Reg("cfgdrop", ConfigSection:AddDropdown({ Title = "Available Configs", Options = {"pahajihub"}, Default = "pahajihub", Callback = function(val)
    if val and val ~= "None" then SelectedConfigName = val; local nameInput = ElementRegistry["cfgname"]; if nameInput and nameInput.SetValue then pcall(function() nameInput:SetValue(val) end) end end
end}), "Available Configs")

ConfigSection:AddButton({ Title = "Refresh List", Callback = function() RefreshConfigList(ConfigDropdown) end})
ConfigSection:AddButton({ Title = "Save Config", Callback = function()
    if SelectedConfigName == "" or SelectedConfigName == "None" then Notify({ Title = "Error", Description = "Nama config tidak boleh kosong." }); return end
    local safeName = SelectedConfigName:gsub("[^%w_%.%-]", ""); if safeName == "" then safeName = "config_" .. tostring(math.random(1000, 9999)) end
    local targetPath = ConfigFolder .. safeName .. ".json"; local configData = {}
    for id, element in pairs(ElementRegistry) do pcall(function() configData[id] = element.Value end) end
    local success, err = pcall(function() writefile(targetPath, HttpService:JSONEncode(configData)) end)
    if success then Notify({ Title = "Saved!", Description = "Config: " .. safeName }); RefreshConfigList(ConfigDropdown) else Notify({ Title = "Error Write", Description = tostring(err) }) end
end})
ConfigSection:AddButton({ Title = "Load Config", Callback = function() if SelectedConfigName == "" or SelectedConfigName == "None" then return end; SmartLoadConfig(SelectedConfigName) end})
ConfigSection:AddButton({ Title = "Delete Config", Callback = function()
    if SelectedConfigName == "" or SelectedConfigName == "pahajihub" or SelectedConfigName == "None" then Notify({ Title = "Gagal", Description = "Tidak bisa hapus config default/kosong." }); return end
    local path = ConfigFolder .. SelectedConfigName .. ".json"; if isfile(path) then pcall(function() delfile(path) end); Notify({ Title = "Deleted", Description = SelectedConfigName .. " dihapus." }); RefreshConfigList(ConfigDropdown); local nameInput = ElementRegistry["cfgname"]; if nameInput and nameInput.SetValue then pcall(function() nameInput:SetValue("pahajihub") end); SelectedConfigName = "pahajihub" end else Notify({ Title = "Error", Description = "File tidak ditemukan." }) end
end})

-- ============================================================
-- FINALIZE
-- ============================================================
Library:Initialize()
Notify({ Title = "NYXHUB Loaded", Description = "Semua fitur berhasil dimuat tanpa error!", Color = Library.colors.success })
