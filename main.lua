--[[
    NiCH HUB v4.0 — TOTAL REWORK (NYXGUI)
    Struktur baru 4 halaman: MAIN / FAVORIT / TELEPORT / SHOP
    - WindUI: tidak ada. gui.lua (NYXGUI) murni.
    - Webhook luar: dihapus total dari script.
    - Semua fitur sesuai spek baruser.
]]

function LPH_NO_VIRTUALIZE(f) return f end

-- ============================================================
-- LOAD LIBRARY
-- ============================================================
local success, Library = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/NYXOXOV3/berak/refs/heads/main/gui.lua"))()
end)
if not success or not Library then
    warn("[NiCH] Gagal load gui.lua!")
    return
end

local function Notify(title, desc, delaySec)
    Library:MakeNotify({
        Title       = title,
        Description = desc or "",
        Delay       = delaySec or 3,
    })
end

-- ============================================================
-- SERVICES
-- ============================================================
local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")

local isMobile = UserInputService.TouchEnabled

-- ============================================================
-- NET REMOTES
-- ============================================================
local ReplicatedPackages = ReplicatedStorage:WaitForChild("Packages", 10)
local netFolder
pcall(function()
    netFolder = ReplicatedPackages:WaitForChild("_Index", 10)
        :WaitForChild("sleitnick_net@0.2.0", 10):WaitForChild("net", 10)
end)

local function GetServerRemote(targetName)
    if not netFolder then return nil end
    local allRemotes = netFolder:GetChildren()
    for i, remote in ipairs(allRemotes) do
        if remote.Name == targetName then
            return allRemotes[i + 1] or allRemotes[i - 1]
        end
    end
    return nil
end

-- FIX (lama): RF/* kadang RemoteFunction, kadang RemoteEvent -> deteksi otomatis
function CallRemoteServer(remote, ...)
    if not remote then return false end
    local ok
    if remote:IsA("RemoteFunction") then
        ok = select(1, pcall(function(...) remote:InvokeServer(...) end, ...))
    elseif remote:IsA("RemoteEvent") then
        ok = select(1, pcall(function(...) remote:FireServer(...) end, ...))
    else
        ok = select(1, pcall(function(...) remote:InvokeServer(...) end, ...))
        if not ok then
            ok = select(1, pcall(function(...) remote:FireServer(...) end, ...))
        end
    end
    return ok
end

function FireLocalEvent(remote, ...)
    if not remote then return end
    local args = {...}
    local ok, conns = pcall(getconnections, remote.OnClientEvent)
    if ok and conns then
        for _, connection in pairs(conns) do
            if connection.Function then
                task.spawn(function()
                    pcall(connection.Function, unpack(args))
                end)
            end
        end
    end
end

-- ============================================================
-- STATE
-- ============================================================
local Config = {
    -- support features
    NoFishingAnim      = false,
    AutoEquipRod       = false,
    BypassRadar        = false,
    LockPosition       = false,
    ShowRealPing       = false,
    DisableCutscene    = false,
    DisableFishNotif   = false,
    DisableSkinEffect  = false,
    WalkOnWater        = false,
    AutoDivingGear     = false,
    HideOtherPlayers   = false,
    DisableAbilityVfx  = false,
    -- fishing modes
    StabilResult       = false,
    LegitFishing       = false,
    LegitShakeDelay    = 0.25,
    LegitClickSpeed    = 1.0,
    InstantFishing     = false,
    InstantCompleteDelay = 1.0,
    FastReel           = false,
    FastReelInterval   = 0.30,
    FastReelComplete   = 3.7,
    FastReelCancel     = 0.20,
    FastReelBeta       = false,
    BetaCompleteDelay  = 3.2,
    BetaCancelDelay    = 0.18,
    -- favorit
    AutoFavEnabled     = false,
    AutoFavRuby        = false,
    -- teleport
    AutoTpOnSpawn      = false,
    EventPriority      = "First Found",
    -- shop
    AutoSellEnabled    = false,
    AutoSellMode       = "Timer",
    AutoSellValue      = 60,
}

local Tasks = {}
local Conns = {}
local lastTimeFishCaught = nil

_G.NiCHSaved = _G.NiCHSaved or {
    FishCaught   = {},
    CaughtVisual = {},
    FishNotif    = {},
}
local SavedData = _G.NiCHSaved

-- PERFECT MINIGAME COORDS (dari script asli, terbukti)
local PERFECT_X = 1.2854545116425

-- ============================================================
-- CORE HELPERS
-- ============================================================
local Events = {}
Events.equip              = GetServerRemote("RF/EquipToolFromHotbar")
Events.unequip            = GetServerRemote("RE/UnequipToolFromHotbar")
Events.equipItem          = GetServerRemote("RE/EquipItem")
Events.cancel             = GetServerRemote("RF/CancelFishingInputs")
Events.charge             = GetServerRemote("RF/ChargeFishingRod")
Events.minigame           = GetServerRemote("RF/RequestFishingMinigameStarted")
Events.autoFishState      = GetServerRemote("RF/UpdateAutoFishingState")
Events.completed          = GetServerRemote("RF/CatchFishCompleted")
Events.completedRE        = GetServerRemote("RE/CatchFishCompleted")
-- FIX #1 dari audit sebelumnya: dulu Events.fishing tidak pernah diassign
Events.fishing            = Events.completed or GetServerRemote("RF/FishingCompleted")
Events.favorite           = GetServerRemote("RE/FavoriteItem")
Events.sell               = GetServerRemote("RF/SellAllItems")
Events.fishNotif          = GetServerRemote("RE/ObtainedNewFishNotification")
Events.spawnTotem         = GetServerRemote("RE/SpawnTotem")

local function getCharacter()
    return LocalPlayer.Character
end

local function getHrp()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function getAnimator()
    local char = getCharacter()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    return hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
end

local function equipRod()
    CallRemoteServer(Events.equip, 1)
end

local function chargeRod(t)
    CallRemoteServer(Events.charge, t or os.clock())
end

local function fireMinigame(x, y, t)
    CallRemoteServer(Events.minigame, x or PERFECT_X, y or 1, t or os.clock())
end

local function fireCompleted()
    CallRemoteServer(Events.completed)
    if Events.completedRE and Events.completedRE:IsA("RemoteEvent") then
        pcall(function() Events.completedRE:FireServer() end)
    else
        CallRemoteServer(Events.completedRE)
    end
end

local function cancelInputs()
    CallRemoteServer(Events.cancel)
end

local function sellAll()
    if not Events.sell then return end
    pcall(function()
        if Events.sell:IsA("RemoteFunction") then
            Events.sell:InvokeServer()
        else
            Events.sell:FireServer()
        end
    end)
end

-- ============================================================
-- PLAYER DATA (Replion)
-- ============================================================
local PlayerData = nil
local ItemUtility = nil

task.spawn(function()
    pcall(function()
        local Replion = require(ReplicatedStorage:WaitForChild("Packages", 10):WaitForChild("Replion", 10))
        PlayerData = Replion.Client:WaitReplion("Data", 15)
    end)
end)
task.spawn(function()
    pcall(function()
        ItemUtility = require(ReplicatedStorage:WaitForChild("Shared", 10):WaitForChild("ItemUtility", 10))
    end)
end)

local function getInventoryItems()
    if not PlayerData then return {} end
    local ok, inv = pcall(function() return PlayerData:GetExpect("Inventory") end)
    if not ok or not inv or not inv.Items then return {} end
    return inv.Items
end

local function getItemInfo(item)
    local name = tostring(item.ItemName or item.Identifier or ("ID:" .. tostring(item.Id)))
    local rarity = (item.Metadata and item.Metadata.Rarity) or "COMMON"
    local variant = (item.Metadata and item.Metadata.VariantId) or ""
    if ItemUtility then
        pcall(function()
            local data = ItemUtility.GetItemData and ItemUtility:GetItemData(item.Id)
            if data and data.Data and data.Data.Name then
                name = data.Data.Name
            end
            if (not item.Metadata or not item.Metadata.Rarity) and data and data.Probability then
                rarity = rarity or "COMMON"
            end
        end)
    end
    return name, tostring(rarity), tostring(variant)
end

-- ============================================================
-- SUPPORT FEATURES IMPLEMENTATION
-- ============================================================

-- [1] NO FISHING ANIMATION + [DISABLE SKIN EFFECT] share satu hook animator
local animConn = nil
local FISHING_ANIM_KEYWORDS = {
    "FishCaught", "ReelStart", "RodThrow", "ReelingIdle",
    "ReelIntermission", "Cast", "Fishing", "Reel"
}
local function isFishingAnim(name)
    for _, kw in ipairs(FISHING_ANIM_KEYWORDS) do
        if string.find(name, kw) then return true end
    end
    return false
end

local function applyAnimationHook(char)
    if animConn then animConn:Disconnect() animConn = nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
    animConn = animator.AnimationPlayed:Connect(function(track)
        local animName = track.Animation and track.Animation.Name or ""
        if Config.NoFishingAnim and isFishingAnim(animName) then
            track:Stop(0)
            return
        end
        if Config.DisableSkinEffect then
            -- efek skin = animasi prefix "Skin - xxx"; blok selain default
            if string.find(animName, " - ") then
                track:Stop(0)
                return
            end
        end
    end)
end

if getCharacter() then applyAnimationHook(getCharacter()) end
table.insert(Conns, LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.6)
    applyAnimationHook(char)
    -- auto equip rod on spawn
    if Config.AutoEquipRod then
        task.wait(0.5)
        equipRod()
    end
    -- auto tp saved location on spawn
    if _G.NiCH_SaveLocation and Config.AutoTpOnSpawn then
        task.wait(0.8)
        local hrp = getHrp()
        if hrp then
            hrp.CFrame = _G.NiCH_SaveLocation + Vector3.new(0, 3, 0)
        end
    end
end))

-- [2] AUTO EQUIP ROD toggle langsung equip
local function doAutoEquipRod(on)
    if on then equipRod() end
end

-- [3] BYPASS RADAR: blokir remote radar/anticheat umum
local radarBlocked = {}
local function applyBypassRadar(on)
    if not on then return end
    local candidates = {
        "RE/RadarUpdate", "RF/RadarPing", "RE/RadarDetect",
        "RE/AnticheatFlag", "RF/ReportExploit", "RE/DetectionLog",
    }
    for _, name in ipairs(candidates) do
        if not radarBlocked[name] then
            local remote = GetServerRemote(name)
            if remote then
                local ok, conns = pcall(getconnections, remote.OnClientEvent)
                if ok and conns then
                    for _, c in ipairs(conns) do
                        pcall(function() if c.Disable then c:Disable() end end)
                    end
                end
                radarBlocked[name] = true
            end
        end
    end
end

-- [4] LOCK POSITION: simpan CFrame saat ON, tahan tiap Heartbeat
local lockCFrame = nil
local lockConn = nil
local function applyLockPosition(on)
    if on then
        local hrp = getHrp()
        if not hrp then return end
        lockCFrame = hrp.CFrame
        if lockConn then lockConn:Disconnect() end
        lockConn = RunService.Heartbeat:Connect(function()
            local h = getHrp()
            if h and lockCFrame then
                h.CFrame = lockCFrame
            end
        end)
    else
        if lockConn then lockConn:Disconnect() lockConn = nil end
        lockCFrame = nil
    end
end

-- [5] SHOW REAL PING PANEL
local pingGui = nil

local function CreateStreePanel()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Stats = game:GetService("Stats")
    local UserInputService = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    local player = Players.LocalPlayer

    local gui = Instance.new("ScreenGui")
    gui.Name = "StreeMiniPanel"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Enabled = false
    gui.Parent = CoreGui

    -- Frame utama (lebih compact)
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 220, 0, 60)
    main.Position = UDim2.new(0.5, -110, 0, 10) -- Posisi di atas tengah
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    main.BackgroundTransparency = 0.2
    main.BorderSizePixel = 0
    main.Active = true
    main.Parent = gui

    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", main)
    stroke.Color = Color3.fromRGB(140, 0, 255)
    stroke.Thickness = 1.5

    -- Stats Container
    local statsFrame = Instance.new("Frame", main)
    statsFrame.Position = UDim2.new(0, 8, 0, 6)
    statsFrame.Size = UDim2.new(1, -16, 1, -12)
    statsFrame.BackgroundTransparency = 1

    local layout = Instance.new("UIListLayout", statsFrame)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 6)

    local function makeStat()
        local box = Instance.new("Frame")
        box.Size = UDim2.new(0, 48, 1, 0)
        box.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
        box.BackgroundTransparency = 0.3
        box.BorderSizePixel = 0
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)

        local label = Instance.new("TextLabel", box)
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 10
        label.TextWrapped = true
        label.TextColor3 = Color3.fromRGB(200, 200, 220)

        box.Parent = statsFrame
        return label
    end

    local pingLabel  = makeStat()
    local fpsLabel   = makeStat()
    local timeLabel  = makeStat()

    -- Draggable (seluruh panel bisa di-drag)
    local dragging = false
    local dragStart, startPos

    main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X, 
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- FPS Counter
    local frames = 0
    local fps = 0
    local last = tick()

    RunService.RenderStepped:Connect(function()
        frames += 1
        if tick() - last >= 1 then
            fps = frames
            frames = 0
            last = tick()
        end
    end)

    local function getPing()
        local net = Stats:FindFirstChild("Network")
        if net and net:FindFirstChild("ServerStatsItem") then
            local item = net.ServerStatsItem:FindFirstChild("Data Ping")
            if item then return math.floor(item:GetValue()) end
        end
        return 0
    end

    local sessionStartTime = tick()

    local function formatTime(seconds)
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        local secs = math.floor(seconds % 60)
        if hours > 0 then
            return string.format("%02d:%02d:%02d", hours, mins, secs)
        else
            return string.format("%02d:%02d", mins, secs)
        end
    end

    local function color(label, v, y, r)
        if v >= r then
            label.TextColor3 = Color3.fromRGB(255, 80, 80)
        elseif v >= y then
            label.TextColor3 = Color3.fromRGB(255, 220, 0)
        else
            label.TextColor3 = Color3.fromRGB(0, 255, 120)
        end
    end

    -- Update Loop
    task.spawn(function()
        while gui.Parent do
            local ping = getPing()
            local elapsed = tick() - sessionStartTime
            local timerText = formatTime(elapsed)

            pingLabel.Text  = "PING\n" .. ping
            fpsLabel.Text   = "FPS\n" .. fps
            timeLabel.Text  = "TIME\n" .. timerText

            color(pingLabel, ping, 120, 200)
            color(fpsLabel, fps, 40, 90)

            task.wait(0.5) -- Update lebih cepat
        end
    end)

    return gui
end

local function applyShowPing(on)
    if on then
        if not pingGui then
            pingGui = CreateStreePanel()
        end
        pingGui.Enabled = true
    else
        if pingGui then
            pingGui.Enabled = false
        end
    end
end

-- [6] DISABLE CUTSCENE: hook CutsceneController kalau ketemu
local cutsceneHooked = false
local function applyDisableCutscene(on)
    if not on or cutsceneHooked then return end
    task.spawn(function()
        pcall(function()
            local Controllers = ReplicatedStorage:FindFirstChild("Controllers")
            local cc = Controllers and Controllers:FindFirstChild("CutsceneController")
            if cc then
                local mod = require(cc)
                if mod and mod.Play then
                    local oldPlay = mod.Play
                    mod.Play = function(self, ...)
                    if Config.DisableCutscene then return end
                    return oldPlay(self, ...)
                end
                    cutsceneHooked = true
                end
            end
        end)
    end)
end

-- [7] DISABLE OBTAINED FISH NOTIFICATION: matikan listener lokal
local notifConnsToggled = false
local function applyDisableFishNotif(on)
    if not Events.fishNotif then return end
    local ok, conns = pcall(getconnections, Events.fishNotif.OnClientEvent)
    if not ok or not conns then return end
    for _, c in ipairs(conns) do
        pcall(function()
            if on and c.Disable then c:Disable()
            elseif not on and c.Enable then c:Enable() end
        end)
    end
    notifConnsToggled = on
end

-- [8] WALK ON WATER: platform mengikuti kaki
local wowPlatform = nil
local wowThread = nil
local function ensureWowPlatform(pos)
    if wowPlatform and wowPlatform.Parent then
        wowPlatform.Position = pos - Vector3.new(0, 5, 0)
        return
    end
    wowPlatform = Instance.new("Part")
    wowPlatform.Name = "NiCH_WoW"
    wowPlatform.Size = Vector3.new(15, 1, 15)
    wowPlatform.Anchored = true
    wowPlatform.CanCollide = true
    wowPlatform.Transparency = 1
    wowPlatform.Position = pos - Vector3.new(0, 5, 0)
    wowPlatform.Parent = workspace
end

local function applyWalkOnWater(on)
    if on then
        if wowThread then task.cancel(wowThread) end
        wowThread = task.spawn(function()
            while Config.WalkOnWater do
                local hrp = getHrp()
                if hrp and hrp.Position.Y < 5 then
                    ensureWowPlatform(hrp.Position)
                end
                task.wait(0.2)
            end
        end)
    else
        if wowThread then task.cancel(wowThread) wowThread = nil end
        if wowPlatform then pcall(function() wowPlatform:Destroy() end) wowPlatform = nil end
    end
end

-- [9] AUTO EQUIP DIVING GEAR: cari item "Diving" di inventory
local function applyAutoDivingGear(on)
    if not on then return end
    task.spawn(function()
        for _, item in ipairs(getInventoryItems()) do
            local name = getItemInfo(item)
            if string.find(string.lower(name), "diving") then
                if Events.equipItem then
                    pcall(function()
                        Events.equipItem:FireServer(item.UUID, "Gears")
                    end)
                    Notify("Diving Gear", "Equipped: " .. name, 3)
                    return
                end
            end
        end
        Notify("Diving Gear", "Tidak ada diving gear di inventory!", 3)
    end)
end

-- [10] HIDE OTHER PLAYERS
local hidePlayersConn = nil
local function applyHidePlayers(on)
    if on then
        if hidePlayersConn then hidePlayersConn:Disconnect() end
        hidePlayersConn = RunService.RenderStepped:Connect(function()
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    for _, part in ipairs(plr.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.LocalTransparencyModifier = 1
                        elseif part:IsA("Decal") then
                            part.LocalTransparencyModifier = 1
                        end
                    end
                end
            end
        end)
    else
        if hidePlayersConn then hidePlayersConn:Disconnect() hidePlayersConn = nil end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                for _, part in ipairs(plr.Character:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("Decal") then
                        part.LocalTransparencyModifier = 0
                    end
                end
            end
        end
    end
end

-- [11] DISABLE ABILITY VFX
local vfxConn = nil
local function isVfxObject(obj)
    local parent = obj.Parent
    while parent and parent ~= workspace do
        local n = string.lower(parent.Name)
        if string.find(n, "vfx") or string.find(n, "ability") or string.find(n, "effect") then
            return true
        end
        parent = parent.Parent
    end
    return false
end

local function applyDisableVfx(on)
    if on then
        -- sweep awal
        for _, obj in ipairs(workspace:GetDescendants()) do
            if (obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")) and isVfxObject(obj) then
                obj.Enabled = false
            end
        end
        if vfxConn then vfxConn:Disconnect() end
        vfxConn = workspace.DescendantAdded:Connect(function(obj)
            if (obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")) and isVfxObject(obj) then
                obj.Enabled = false
            end
        end)
    else
        if vfxConn then vfxConn:Disconnect() vfxConn = nil end
        -- restore: sweep ulang, enable lagi
        for _, obj in ipairs(workspace:GetDescendants()) do
            if (obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")) and isVfxObject(obj) then
                obj.Enabled = true
            end
        end
    end
end

-- ============================================================
-- FISHING MODE LOOPS
-- ============================================================

-- STABIL RESULT GOOD/PERFECT: dipakai bareng mode apapun.
-- Loop yang kena pengaruh: instant/fast reel/beta memakai koordinat perfect.

-- LEGIT FISHING: simulasi klik manusia (jeda acak sekitar shake delay)
local function legitLoop()
    while Config.LegitFishing do
        local char = getCharacter()
        if not char then task.wait(1)
        else
            equipRod()
            task.wait(0.4)
            cancelInputs()
            task.wait(0.3 + math.random() * 0.1)
            chargeRod(os.clock())
            task.wait(Config.LegitShakeDelay + math.random() * 0.05)
            -- klik speed: semakin besar makin cepat resolve
            local jitter = (math.random() * 0.08) / math.max(0.5, tonumber(Config.LegitClickSpeed) or 1)
            fireMinigame(PERFECT_X - jitter * 2, 0.92 + math.random() * 0.06)
            task.wait(math.max(0.6, Config.InstantCompleteDelay))
            if Config.StabilResult then
                fireCompleted()
            end
            task.wait(math.max(0.4, 1.6 / math.max(0.5, tonumber(Config.LegitClickSpeed) or 1)))
        end
    end
end

-- INSTANT FISHING: charge -> perfect -> complete delay -> completed
local function instantLoop()
    while Config.InstantFishing do
        equipRod()
        task.wait(0.25)
        cancelInputs()
        task.wait(0.2)
        chargeRod(os.clock())
        task.wait(0.28)
        fireMinigame(PERFECT_X, 1)
        task.wait(math.max(0.3, tonumber(Config.InstantCompleteDelay) or 1))
        fireCompleted()
        lastTimeFishCaught = os.clock()
        task.wait(0.15)
    end
end

-- INSTANT FAST REEL (UB klasik): interval + complete + cancel delay
local function fastReelLoop()
    while Config.FastReel do
        task.wait(tonumber(Config.FastReelCancel) or 0.2)
        chargeRod(os.clock())
        task.wait(0.05)
        fireMinigame(1, 0, os.clock())
        task.wait(math.max(0.5, tonumber(Config.FastReelComplete) or 3.7))
        fireCompleted()
        lastTimeFishCaught = os.clock()
        task.wait(tonumber(Config.FastReelInterval) or 0.3)
    end
end

-- INSTANT FAST REEL BETA: self-healing (recast kalau stale), tanpa interval fix
local betaCycle = 0
local function fastReelBetaLoop()
    while Config.FastReelBeta do
        local stale = (lastTimeFishCaught == nil)
            or (os.clock() - lastTimeFishCaught >= 8)
        cancelInputs()
        task.wait(math.max(0.1, tonumber(Config.BetaCancelDelay) or 0.18))
        chargeRod(os.clock())
        if stale then
            task.wait(0.17) -- kompensasi saat server lambat
        end
        fireMinigame(stale and 1 or PERFECT_X, stale and 0 or 1, os.clock())
        task.wait(math.max(0.5, tonumber(Config.BetaCompleteDelay) or 3.2))
        if not Config.StabilResult then
            -- tanpa stabil: tetap complete, tapi variasikan supaya tidak monoton
            if math.random() < 0.12 then
                task.wait(0.25)
            end
        end
        fireCompleted()
        lastTimeFishCaught = os.clock()
        betaCycle = betaCycle + 1
        task.wait(0.12)
    end
end

local function startLoop(key, fn)
    if Tasks[key] then pcall(function() task.cancel(Tasks[key]) end) Tasks[key] = nil end
    Tasks[key] = task.spawn(fn)
end

local function stopLoop(key)
    if Tasks[key] then
        pcall(function() task.cancel(Tasks[key]) end)
        Tasks[key] = nil
    end
end

-- ANTI-AFK
for _, v in pairs(getconnections(LocalPlayer.Idled)) do
    if v.Disable then v:Disable() elseif v.Disconnect then v:Disconnect() end
end

-- ============================================================
-- DATA UNTUK DROPDOWN DINAMIS
-- ============================================================
local LOCATIONS = {
    ["Fisherman"]           = CFrame.new(-18.065, 9.532, 2734.000),
    ["Sisyphus Statue"]     = CFrame.new(-3754.441, -135.074, -895.376),
    ["Coral Reefs"]         = CFrame.new(-3030.043, 2.509, 2271.429),
    ["Esoteric Depths"]     = CFrame.new(3271.979, -1301.530, 1402.762),
    ["Crater Island 1"]     = CFrame.new(990.610, 21.142, 5060.255),
    ["Crater Island 2"]     = CFrame.new(1040.036, 55.714, 5131.443),
    ["Lost Isle"]           = CFrame.new(-3618.157, 240.837, -1317.458),
    ["Weather Machine"]     = CFrame.new(-1488.512, 83.173, 1876.303),
    ["Tropical Grove"]      = CFrame.new(-2132.597, 53.488, 3631.235),
    ["Treasure Room"]       = CFrame.new(-3630.000, -279.074, -1599.287),
    ["Kohana"]              = CFrame.new(-663.904, 3.046, 718.797),
    ["Kohana 2"]            = CFrame.new(-530.529, 8.750, -72.149),
    ["Underground Cellar"]  = CFrame.new(2110.109, -91.199, -699.790),
    ["Ancient Jungle"]      = CFrame.new(1837.352, 5.894, -297.224),
    ["Ancient Jungle 2"]    = CFrame.new(1468.971, 6.512, -326.397),
    ["Sacred Temple"]       = CFrame.new(1459.217, -22.375, -637.787),
    ["Ancient Ruins"]       = CFrame.new(6097.176, -585.924, 4644.443),
    ["Megalodon Zone"]      = CFrame.new(-1172.987, 7.924, 3620.589),
    ["Pirate Cove"]         = CFrame.new(3396.730, 4.192, 3469.213),
    ["Pirate Treasure Room"]= CFrame.new(3324.074, -306.476, 3087.999),
    ["Secret Passage"]      = CFrame.new(3436.101, -289.845, 3382.640),
    ["Kohana Volcano"]      = CFrame.new(-549.192, 20.019, 125.802),
    ["Crystal Depth"]       = CFrame.new(5752.219, -907.148, 15343.468),
    ["Lava Basin"]          = CFrame.new(950.876, 85.282, -10199.427),
    ["Planetary Observatory"] = CFrame.new(420.373, 3.673, 2183.675),
    ["Underwater City"]     = CFrame.new(-3142.406, -643.484, -10409.403),
    ["Enchant Altar"]       = CFrame.new(3234.837, -1302.855, 1398.391),
}

local EVENT_KEYWORDS = {
    ["Megalodon Hunt"]   = "megalodon",
    ["Shark Hunt"]       = "shark",
    ["Christmas Event"]  = "christmas",
    ["Kraken Event"]     = "kraken",
}

local STATIC_RARITIES = { "COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC", "SECRET", "LIMITED" }
local STATIC_VARIANTS = { "Rainbow", "Golden", "Shiny", "Crystalized", "Gemstone", "Frozen", "Electric" }

local function collectNames()
    local names, seen = {}, {}
    for _, item in ipairs(getInventoryItems()) do
        local name = getItemInfo(item)
        if not seen[name] then
            seen[name] = true
            names[#names + 1] = name
            if #names >= 200 then break end
        end
    end
    table.sort(names)
    return names
end

local function collectVariants()
    local found, seen = {}, {}
    for _, item in ipairs(getInventoryItems()) do
        local v = (item.Metadata and item.Metadata.VariantId) or ""
        if v ~= "" and not seen[v] then
            seen[v] = true
            found[#found + 1] = v
        end
    end
    for _, v in ipairs(STATIC_VARIANTS) do
        if not seen[v] then
            seen[v] = true
            found[#found + 1] = v
        end
    end
    table.sort(found)
    return found
end

local function collectFavorites()
    local names, variants, rarities = {}, {}, {}
    local nSeen, vSeen, rSeen = {}, {}, {}
    for _, item in ipairs(getInventoryItems()) do
        local meta = item.Metadata
        if meta and meta.Favorite then
            local name, rarity, variant = getItemInfo(item)
            if not nSeen[name] then nSeen[name] = true names[#names + 1] = name end
            if variant ~= "" and not vSeen[variant] then vSeen[variant] = true variants[#variants + 1] = variant end
            if not rSeen[rarity] then rSeen[rarity] = true rarities[#rarities + 1] = rarity end
        end
    end
    table.sort(names) table.sort(variants) table.sort(rarities)
    return names, variants, rarities
end

local function collectPlayers()
    local out = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            out[#out + 1] = plr.DisplayName
        end
    end
    table.sort(out)
    return out
end

local function collectNpcs()
    local npcs, seen = {}, {}
    local myChar = getCharacter()
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") and model ~= myChar then
            local isPlayerChar = false
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character == model then isPlayerChar = true break end
            end
            if not isPlayerChar and not seen[model.Name] then
                seen[model.Name] = true
                npcs[#npcs + 1] = model.Name
            end
            if #npcs >= 80 then break end
        end
    end
    table.sort(npcs)
    return npcs
end

local function scanActiveEvents()
    local active = {}
    local lowered = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local n = string.lower(obj.Name)
            for eventName, kw in pairs(EVENT_KEYWORDS) do
                if string.find(n, kw, 1, true) then
                    lowered[eventName] = true
                end
            end
        end
        if #lowered >= 2 then break end
    end
    for eventName in pairs(lowered) do
        active[#active + 1] = eventName
    end
    return active
end

local function findEventModel(eventName)
    local kw = EVENT_KEYWORDS[eventName]
    if not kw then return nil end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and string.find(string.lower(obj.Name), kw, 1, true) then
            local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if pp then return pp.Position end
        end
    end
    return nil
end

-- ============================================================
-- FAVORIT ENGINE
-- ============================================================
local favSelection = { names = {}, variants = {}, rarities = {} }

local function matchSelection(name, rarity, variant, selNames, selVariants, selRarities)
    local nameOk    = (#selNames == 0)
    local varOk     = (#selVariants == 0)
    local rarOk     = (#selRarities == 0)
    for _, n in ipairs(selNames) do
        if n == name then nameOk = true break end
    end
    for _, v in ipairs(selVariants) do
        if v == variant then varOk = true break end
    end
    for _, r in ipairs(selRarities) do
        if string.upper(r) == string.upper(rarity) then rarOk = true break end
    end
    return nameOk and varOk and rarOk
end

local function favoriteUuid(uuid)
    if Events.favorite and Events.favorite:IsA("RemoteEvent") then
        pcall(function() Events.favorite:FireServer(uuid) end)
    end
end

-- auto favorit watcher: hook fishNotif sekali, filter dinamis
do
    local notifRemote = Events.fishNotif
    if notifRemote then
        notifRemote.OnClientEvent:Connect(function(...)
            local args = {...}
            local arg3 = args[3]
            lastTimeFishCaught = os.clock()

            local invItem = (typeof(arg3) == "table" and arg3.InventoryItem) or nil
            if not invItem or not invItem.UUID then return end

            local name, rarity, variant = getItemInfo(invItem)

            -- FIX #3/#4 lama: semua akses metadata lewat variabel ter-guard
            if Config.AutoFavRuby and name == "Ruby" and variant == "Gemstone" then
                favoriteUuid(invItem.UUID)
            end

            if Config.AutoFavEnabled then
                local selN = favSelection.names or {}
                local selV = favSelection.variants or {}
                local selR = favSelection.rarities or {}
                if matchSelection(name, rarity, variant, selN, selV, selR) then
                    favoriteUuid(invItem.UUID)
                end
            end
        end)
    end
end

local function unfavoriteSelected(selNames, selVariants, selRarities)
    local count = 0
    for _, item in ipairs(getInventoryItems()) do
        local meta = item.Metadata
        if meta and meta.Favorite and item.UUID then
            local name, rarity, variant = getItemInfo(item)
            if matchSelection(name, rarity, variant, selNames or {}, selVariants or {}, selRarities or {}) then
                favoriteUuid(item.UUID) -- toggle off
                count = count + 1
                task.wait(0.05)
            end
        end
    end
    return count
end

-- ============================================================
-- TELEPORT ENGINE
-- ============================================================
local function teleportCf(cf)
    local hrp = getHrp()
    if not hrp then return end
    hrp.CFrame = cf + Vector3.new(0, 3, 0)
end

local function teleportToPlayer(displayName)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.DisplayName == displayName and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local me = getHrp()
                if me then me.CFrame = hrp.CFrame + Vector3.new(0, 2, 0) end
                return true
            end
        end
    end
    return false
end

local function teleportToNpc(name)
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model.Name == name then
            local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if pp then
                teleportCf(CFrame.new(pp.Position))
                return true
            end
        end
    end
    return false
end

-- auto teleport event loop
task.spawn(function()
    while true do
        task.wait(10)
        if Config.AutoTeleEvent then
            local active = scanActiveEvents()
            local target = nil
            if #active == 1 then
                target = active[1]
            elseif #active > 1 then
                if Config.EventPriority == "Random" then
                    target = active[math.random(#active)]
                else
                    target = active[1]
                end
            end
            if target then
                local pos = findEventModel(target)
                if pos then
                    local hrp = getHrp()
                    if hrp and (hrp.Position - pos).Magnitude > 60 then
                        teleportCf(CFrame.new(pos))
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- SHOP ENGINE
-- ============================================================
task.spawn(function()
    while true do
        task.wait(2)
        if Config.AutoSellEnabled then
            if Config.AutoSellMode == "Timer" then
                local interval = math.max(10, tonumber(Config.AutoSellValue) or 60)
                local now = os.clock()
                if not _G.NiCH_LastSell or (now - _G.NiCH_LastSell) >= interval then
                    sellAll()
                    _G.NiCH_LastSell = now
                end
            else -- ByCount
                local targetCount = math.max(1, tonumber(Config.AutoSellValue) or 10)
                local count = #getInventoryItems()
                if count >= targetCount then
                    sellAll()
                end
            end
        end
    end
end)

local MERCHANT_OPEN_CANDIDATES = {
    "RF/OpenMerchant", "RE/OpenMerchant", "RF/OpenMerchantShop",
    "RE/OpenMerchantUI", "RF/TalkToMerchant",
}
local MERCHANT_CLOSE_CANDIDATES = {
    "RF/CloseMerchant", "RE/CloseMerchant", "RE/CloseMerchantUI",
}

local function tryRemotes(candidates, actionLabel)
    for _, name in ipairs(candidates) do
        local remote = GetServerRemote(name)
        if remote then
            local ok = CallRemoteServer(remote)
            if ok then
                Notify("Merchant", actionLabel .. " OK via " .. name, 2)
                return true
            end
        end
    end
    Notify("Merchant", actionLabel .. " gagal — remote tidak ditemukan", 3)
    return false
end

-- ============================================================
-- BUILD UI
-- ============================================================
local Window = Library:Window({
    Title    = "NYX",
    Subtitle = "NYX v4.0 — Rework",
})

------------------------------------------------------------
-- PAGE MAIN
------------------------------------------------------------
do
    local Page = Window:AddTab({ Name = "Main", Icon = "fish" })

    local secSupport = Page:AddSection("Support Features")
    secSupport:AddToggle({ Title = "No Fishing Animation", Default = false,
        Callback = function(v) Config.NoFishingAnim = v end })
    secSupport:AddToggle({ Title = "Auto Equip Rod", Default = false,
        Callback = function(v)
            Config.AutoEquipRod = v
            doAutoEquipRod(v)
        end })
    secSupport:AddToggle({ Title = "Bypass Radar", Default = false,
        Callback = function(v)
            Config.BypassRadar = v
            applyBypassRadar(v)
        end })
    secSupport:AddToggle({ Title = "Lock Position", Default = false,
        Callback = function(v)
            Config.LockPosition = v
            applyLockPosition(v)
        end })
    secSupport:AddToggle({ Title = "Show Real Ping Panel", Default = false,
        Callback = function(v)
            Config.ShowRealPing = v
            applyShowPing(v)
        end })
    secSupport:AddToggle({ Title = "Disable Cutscene", Default = false,
        Callback = function(v)
            Config.DisableCutscene = v
            applyDisableCutscene(v)
        end })
    secSupport:AddToggle({ Title = "Disable Obtained Fish Notification", Default = false,
        Callback = function(v)
            Config.DisableFishNotif = v
            applyDisableFishNotif(v)
        end })
    secSupport:AddToggle({ Title = "Disable Skin Effect", Default = false,
        Callback = function(v) Config.DisableSkinEffect = v end })
    secSupport:AddToggle({ Title = "Walk On Water", Default = false,
        Callback = function(v)
            Config.WalkOnWater = v
            applyWalkOnWater(v)
        end })
    secSupport:AddToggle({ Title = "Auto Equip Diving Gear", Default = false,
        Callback = function(v)
            Config.AutoDivingGear = v
            applyAutoDivingGear(v)
        end })
    secSupport:AddToggle({ Title = "Hide Other Player", Default = false,
        Callback = function(v)
            Config.HideOtherPlayers = v
            applyHidePlayers(v)
        end })
    secSupport:AddToggle({ Title = "Disable Ability VFX", Default = false,
        Callback = function(v)
            Config.DisableAbilityVfx = v
            applyDisableVfx(v)
        end })

    local secStabil = Page:AddSection("Stabil Result Good / Perfect")
    secStabil:AddToggle({ Title = "Enable Stabil Result", Default = false,
        Callback = function(v) Config.StabilResult = v end })

    local secLegit = Page:AddSection("Legit Fishing")
    secLegit:AddInput({ Title = "Shake Delay (detik)", Default = tostring(Config.LegitShakeDelay),
        Callback = function(v)
            local n = tonumber(v)
            if n and n > 0 then Config.LegitShakeDelay = n end
        end })
    secLegit:AddInput({ Title = "Click Speed (x)", Default = tostring(Config.LegitClickSpeed),
        Callback = function(v)
            local n = tonumber(v)
            if n and n >= 0.5 and n <= 5 then Config.LegitClickSpeed = n end
        end })
    secLegit:AddToggle({ Title = "Enable Legit Fishing", Default = false,
        Callback = function(v)
            Config.LegitFishing = v
            if v then
                Config.InstantFishing = false
                Config.FastReel = false
                Config.FastReelBeta = false
                startLoop("legit", legitLoop)
                Notify("Legit Fishing", "ON — mode lain dimatikan", 2)
            else
                stopLoop("legit")
            end
        end })

    local secInstant = Page:AddSection("Instant Fishing")
    secInstant:AddInput({ Title = "Complete Delay (detik)", Default = tostring(Config.InstantCompleteDelay),
        Callback = function(v)
            local n = tonumber(v)
            if n and n >= 0.3 then Config.InstantCompleteDelay = n end
        end })
    secInstant:AddToggle({ Title = "Enable Instant Fishing", Default = false,
        Callback = function(v)
            Config.InstantFishing = v
            if v then
                Config.LegitFishing = false
                Config.FastReel = false
                Config.FastReelBeta = false
                startLoop("instant", instantLoop)
                Notify("Instant Fishing", "ON", 2)
            else
                stopLoop("instant")
            end
        end })

    local secUB = Page:AddSection("Instant Fast Reel (UB)")
    secUB:AddInput({ Title = "Blatant Interval (detik)", Default = tostring(Config.FastReelInterval),
        Callback = function(v)
            local n = tonumber(v)
            if n and n >= 0 then Config.FastReelInterval = n end
        end })
    secUB:AddInput({ Title = "Complete Delay (detik)", Default = tostring(Config.FastReelComplete),
        Callback = function(v)
            local n = tonumber(v)
            if n and n >= 0.5 then Config.FastReelComplete = n end
        end })
    secUB:AddInput({ Title = "Cancel Delay (detik)", Default = tostring(Config.FastReelCancel),
        Callback = function(v)
            local n = tonumber(v)
            if n and n >= 0.05 then Config.FastReelCancel = n end
        end })
    secUB:AddToggle({ Title = "Enable Instant Fast Reel", Default = false,
        Callback = function(v)
            Config.FastReel = v
            if v then
                Config.LegitFishing = false
                Config.InstantFishing = false
                Config.FastReelBeta = false
                startLoop("ub", fastReelLoop)
                Notify("Fast Reel", "ON — mode lain dimatikan", 2)
            else
                stopLoop("ub")
            end
        end })

    local secBeta = Page:AddSection("Instant Fast Reel Beta")
    secBeta:AddInput({ Title = "Complete Delay (detik)", Default = tostring(Config.BetaCompleteDelay),
        Callback = function(v)
            local n = tonumber(v)
            if n and n >= 0.5 then Config.BetaCompleteDelay = n end
        end })
    secBeta:AddInput({ Title = "Cancel Delay (detik)", Default = tostring(Config.BetaCancelDelay),
        Callback = function(v)
            local n = tonumber(v)
            if n and n >= 0.05 then Config.BetaCancelDelay = n end
        end })
    secBeta:AddToggle({ Title = "Enable Instant Beta", Default = false,
        Callback = function(v)
            Config.FastReelBeta = v
            if v then
                Config.LegitFishing = false
                Config.InstantFishing = false
                Config.FastReel = false
                startLoop("beta", fastReelBetaLoop)
                Notify("Fast Reel Beta", "ON — self-healing aktif", 2)
            else
                stopLoop("beta")
            end
        end })
end

------------------------------------------------------------
-- PAGE FAVORIT
------------------------------------------------------------
do
    local Page = Window:AddTab({ Name = "Favorit", Icon = "star" })

    local secAuto = Page:AddSection("Auto Favorit")
    local ddFavName = secAuto:AddDropdown({
        Title = "Filter Name", Options = collectNames(),
        Multi = true, Callback = function(v) favSelection.names = v or {} end })
    local ddFavVariant = secAuto:AddDropdown({
        Title = "Filter Variant", Options = collectVariants(),
        Multi = true, Callback = function(v) favSelection.variants = v or {} end })
    local ddFavRarity = secAuto:AddDropdown({
        Title = "Filter Rarity", Options = STATIC_RARITIES,
        Multi = true, Callback = function(v) favSelection.rarities = v or {} end })
    secAuto:AddToggle({ Title = "Enable Auto Favorit", Default = false,
        Callback = function(v)
            Config.AutoFavEnabled = v
            Notify("Auto Favorit", v and "ON — ikan baru sesuai filter auto difavorit" or "OFF", 2)
        end })
    secAuto:AddButton({ Title = "Refresh Filter List",
        Callback = function()
            ddFavName:SetOptions(collectNames())
            ddFavVariant:SetOptions(collectVariants())
            Notify("Favorit", "Filter list di-refresh dari inventory", 2)
        end })

    local secUnfav = Page:AddSection("Un-Favorite")
    local ddUnName = secUnfav:AddDropdown({
        Title = "UnFav Name", Options = collectNames(),
        Multi = true, NoSave = true, Callback = function(v) _G.UnSel_Name = v or {} end })
    local ddUnVariant = secUnfav:AddDropdown({
        Title = "UnFav Variant", Options = collectVariants(),
        Multi = true, NoSave = true, Callback = function(v) _G.UnSel_Variant = v or {} end })
    local ddUnRarity = secUnfav:AddDropdown({
        Title = "UnFav Rarity", Options = STATIC_RARITIES,
        Multi = true, NoSave = true, Callback = function(v) _G.UnSel_Rarity = v or {} end })
    secUnfav:AddButton({ Title = "Un-Favorite Selected",
        Callback = function()
            task.spawn(function()
                local count = unfavoriteSelected(_G.UnSel_Name, _G.UnSel_Variant, _G.UnSel_Rarity)
                Notify("Un-Favorite", ("%d item di-unfavorite"):format(count), 3)
            end)
        end })
    secUnfav:AddButton({ Title = "Refresh List Item",
        Callback = function()
            local n, v, r = collectFavorites()
            ddUnName:SetOptions(#n > 0 and n or collectNames())
            ddUnVariant:SetOptions(#v > 0 and v or collectVariants())
            ddUnRarity:SetOptions(#r > 0 and r or STATIC_RARITIES)
            Notify("Un-Favorite", "List item favorit di-refresh", 2)
        end })

    local secRuby = Page:AddSection("Auto Favorit Ruby")
    secRuby:AddToggle({ Title = "Auto Favorite Ruby (Gemstone)", Default = false,
        Callback = function(v)
            Config.AutoFavRuby = v
            Notify("Ruby Gemstone", v and "ON — semua Ruby Gemstone auto difavorit" or "OFF", 2)
        end })
end

------------------------------------------------------------
-- PAGE TELEPORT
------------------------------------------------------------
do
    local Page = Window:AddTab({ Name = "Teleport", Icon = "gps" })

    local islandNames = {}
    for name in pairs(LOCATIONS) do islandNames[#islandNames + 1] = name end
    table.sort(islandNames)

    local secIsland = Page:AddSection("Teleport To Island")
    local ddIsland = secIsland:AddDropdown({
        Title = "Select Island", Options = islandNames,
        Callback = function(v) _G.Tp_Island = v end })
    secIsland:AddButton({ Title = "Teleport",
        Callback = function()
            if _G.Tp_Island and LOCATIONS[_G.Tp_Island] then
                teleportCf(LOCATIONS[_G.Tp_Island])
                Notify("Teleport", "Ke " .. _G.Tp_Island, 2)
            else
                Notify("Teleport", "Pilih island dulu!", 2)
            end
        end })

    local secPlayer = Page:AddSection("Teleport To Player")
    local ddPlayer = secPlayer:AddDropdown({
        Title = "Select Player", Options = collectPlayers(), NoSave = true,
        Callback = function(v) _G.Tp_Player = v end })
    secPlayer:AddButton({ Title = "Teleport To Selected Player",
        Callback = function()
            if _G.Tp_Player and teleportToPlayer(_G.Tp_Player) then
                Notify("Teleport", "Ke player " .. _G.Tp_Player, 2)
            else
                Notify("Teleport", "Player tidak ketemu / sudah keluar", 2)
            end
        end })
    secPlayer:AddButton({ Title = "Refresh Player List",
        Callback = function()
            ddPlayer:SetOptions(collectPlayers())
            Notify("Teleport", "Player list di-refresh", 2)
        end })

    local secSave = Page:AddSection("Save Location")
    secSave:AddButton({ Title = "Save Current Location",
        Callback = function()
            local hrp = getHrp()
            if hrp then
                _G.NiCH_SaveLocation = hrp.CFrame
                pcall(function()
                    Library.ConfigSystem.Set("Teleport.SavePos", {
                        hrp.CFrame.X, hrp.CFrame.Y, hrp.CFrame.Z,
                    })
                end)
                Notify("Save Location", "Posisi tersimpan!", 2)
            end
        end })
    secSave:AddButton({ Title = "Teleport To Saved Location",
        Callback = function()
            if _G.NiCH_SaveLocation then
                teleportCf(_G.NiCH_SaveLocation)
                Notify("Save Location", "TP ke posisi tersimpan", 2)
            else
                -- coba restore dari config
                local saved = Library.ConfigSystem.Get("Teleport.SavePos", nil)
                if type(saved) == "table" and #saved >= 3 then
                    _G.NiCH_SaveLocation = CFrame.new(saved[1], saved[2], saved[3])
                    teleportCf(_G.NiCH_SaveLocation)
                    Notify("Save Location", "TP ke posisi dari config", 2)
                else
                    Notify("Save Location", "Belum ada lokasi tersimpan!", 2)
                end
            end
        end })
    secSave:AddButton({ Title = "Reset Saved Location",
        Callback = function()
            _G.NiCH_SaveLocation = nil
            pcall(function() Library.ConfigSystem.Set("Teleport.SavePos", nil) end)
            Notify("Save Location", "Reset OK", 2)
        end })
    secSave:AddToggle({ Title = "Auto TP To Saved On Spawn", Default = false,
        Callback = function(v) Config.AutoTpOnSpawn = v end })

    local secEvent = Page:AddSection("Event Teleport")
    local eventNames = {}
    for name in pairs(EVENT_KEYWORDS) do eventNames[#eventNames + 1] = name end
    table.sort(eventNames)
    secEvent:AddDropdown({
        Title = "Select Event", Options = eventNames,
        Callback = function(v) _G.Tp_Event = v end })
    secEvent:AddDropdown({
        Title = "Priority Event", Options = { "First Found", "Random" },
        Callback = function(v) Config.EventPriority = v end })
    secEvent:AddButton({ Title = "Refresh Event List",
        Callback = function()
            local active = scanActiveEvents()
            Notify("Event", #active > 0 and ("Aktif: " .. table.concat(active, ", ")) or "Tidak ada event aktif", 3)
        end })
    secEvent:AddButton({ Title = "Teleport To Event Now",
        Callback = function()
            local name = _G.Tp_Event
            if not name then
                Notify("Event", "Pilih event dulu!", 2)
                return
            end
            local pos = findEventModel(name)
            if pos then
                teleportCf(CFrame.new(pos))
                Notify("Event", "TP ke " .. name, 2)
            else
                Notify("Event", name .. " tidak terdeteksi di server ini", 3)
            end
        end })
    secEvent:AddToggle({ Title = "Auto Teleport Event", Default = false,
        Callback = function(v) Config.AutoTeleEvent = v end })

    local secNpc = Page:AddSection("Teleport To NPC")
    local ddNpc = secNpc:AddDropdown({
        Title = "Select NPC", Options = collectNpcs(), NoSave = true,
        Callback = function(v) _G.Tp_Npc = v end })
    secNpc:AddButton({ Title = "Teleport To NPC",
        Callback = function()
            if _G.Tp_Npc and teleportToNpc(_G.Tp_Npc) then
                Notify("NPC", "TP ke " .. _G.Tp_Npc, 2)
            else
                Notify("NPC", "NPC tidak ketemu", 2)
            end
        end })
    secNpc:AddButton({ Title = "Refresh NPC List",
        Callback = function()
            ddNpc:SetOptions(collectNpcs())
            Notify("NPC", "NPC list di-refresh", 2)
        end })
end

------------------------------------------------------------
-- PAGE SHOP
------------------------------------------------------------
do
    local Page = Window:AddTab({ Name = "Shop", Icon = "shop" })

    local secSell = Page:AddSection("Auto Sell")
    secSell:AddButton({ Title = "Sell All Now",
        Callback = function()
            sellAll()
            Notify("Shop", "SellAll dikirim!", 2)
        end })
    secSell:AddDropdown({
        Title = "Mode", Options = { "Timer", "ByCount" },
        Callback = function(v) Config.AutoSellMode = v end })
    secSell:AddInput({ Title = "Value (detik / jumlah ikan)", Default = "60",
        Callback = function(v)
            local n = tonumber(v)
            if n and n >= 1 then Config.AutoSellValue = n end
        end })
    secSell:AddToggle({ Title = "Enable Auto Sell", Default = false,
        Callback = function(v)
            Config.AutoSellEnabled = v
            _G.NiCH_LastSell = nil
            Notify("Auto Sell", v and ("ON — mode " .. Config.AutoSellMode) or "OFF", 2)
        end })

    local secMerchant = Page:AddSection("Remote Merchant")
    secMerchant:AddButton({ Title = "Open Merchant UI",
        Callback = function() tryRemotes(MERCHANT_OPEN_CANDIDATES, "Open") end })
    secMerchant:AddButton({ Title = "Close Merchant UI",
        Callback = function() tryRemotes(MERCHANT_CLOSE_CANDIDATES, "Close") end })
end

Notify("NiCH HUB v4.0", "Rework loaded: Main / Favorit / Teleport / Shop", 4)
print("[NiCH] v4.0 rework loaded.")
