-- ServerScript: ServerScriptService -> VoxelServer
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Базовый размер воксельного блока (1.5x1.5x1.5 studs)
local BLOCK_SIZE = 1.5
local MAX_REACH = 5.2 -- studs (максимальная дистанция взаимодействия с блоками: только рядом с котиком)

-- === БАЗА ПРЕДМЕТОВ ===
local ITEMS = {
    -- Ресурсы и блоки (Портфель)
    grass_block = {
        name = "Трава",
        max = 64,
        isBlock = true,
        blockType = "Grass",
        category = "resources",
        sprite = "rbxassetid://114424346454200",
        icon = "🌿",
        color = Color3.fromRGB(90, 175, 55),
        material = Enum.Material.Grass
    },
    wood_block = {
        name = "Дерево",
        max = 64,
        isBlock = true,
        blockType = "Wood",
        category = "resources",
        sprite = "rbxassetid://102991854156536",
        icon = "🪵",
        color = Color3.fromRGB(120, 75, 40),
        material = Enum.Material.WoodPlanks
    },
    stone_block = {
        name = "Камень",
        max = 64,
        isBlock = true,
        blockType = "Stone",
        category = "resources",
        sprite = "rbxassetid://109072643235539",
        icon = "🪨",
        color = Color3.fromRGB(135, 140, 145),
        material = Enum.Material.Slate
    },
    dirt_block = {
        name = "Земля",
        max = 64,
        isBlock = true,
        blockType = "Dirt",
        category = "resources",
        sprite = "rbxassetid://104779952223143",
        icon = "🟤",
        color = Color3.fromRGB(100, 70, 45),
        material = Enum.Material.Ground
    },
    ice_block = {
        name = "\u{041b}\u{0451}\u{0434}",
        max = 64,
        isBlock = true,
        blockType = "Ice",
        category = "resources",
        sprite = "rbxassetid://72778677331909",
        icon = "\u{1F9CA}",
        color = Color3.fromRGB(185, 225, 255),
        material = Enum.Material.Ice
    },
    water_block = {
        name = "\u{0412}\u{043e}\u{0434}\u{0430}",
        max = 64,
        isBlock = true,
        blockType = "Water",
        category = "resources",
        sprite = "rbxassetid://94567183251152",
        icon = "\u{1F4A7}",
        color = Color3.fromRGB(75, 160, 235),
        material = Enum.Material.Glass
    },
    sand_block = {
        name = "\u{041f}\u{0435}\u{0441}\u{043e}\u{043a}",
        max = 64,
        isBlock = true,
        blockType = "Sand",
        category = "resources",
        sprite = "rbxassetid://136811617960488",
        icon = "\u{23F3}",
        color = Color3.fromRGB(225, 200, 120),
        material = Enum.Material.Sand
    },
    twigs = {
        name = "\u{0412}\u{0435}\u{0442}\u{043a}\u{0438}",
        max = 64,
        isBlock = false,
        category = "resources",
        icon = "🥢",
        color = Color3.fromRGB(130, 85, 45),
        material = Enum.Material.Wood
    },
    clay = {
        name = "Глина",
        max = 64,
        isBlock = false,
        category = "resources",
        icon = "🧱",
        color = Color3.fromRGB(165, 95, 65),
        material = Enum.Material.SmoothPlastic
    },
    sand = {
        name = "Песок",
        max = 64,
        isBlock = true,
        blockType = "Sand",
        category = "resources",
        icon = "⏳",
        color = Color3.fromRGB(225, 200, 120),
        material = Enum.Material.Sand
    },
    coal = {
        name = "Уголь",
        max = 64,
        isBlock = false,
        category = "resources",
        icon = "⚫",
        color = Color3.fromRGB(40, 40, 45),
        material = Enum.Material.Basalt
    },
    ore = {
        name = "Руда",
        max = 64,
        isBlock = false,
        category = "resources",
        icon = "🪙",
        color = Color3.fromRGB(170, 175, 185),
        material = Enum.Material.Metal
    },
    bones = {
        name = "Кости",
        max = 64,
        isBlock = false,
        category = "resources",
        icon = "🦴",
        color = Color3.fromRGB(235, 230, 215),
        material = Enum.Material.SmoothPlastic
    },

    -- Еда и сбор (Корзинка)
    fish = {
        name = "Рыбка",
        max = 16,
        isBlock = false,
        category = "food",
        icon = "🐟",
        color = Color3.fromRGB(255, 140, 70),
        material = Enum.Material.SmoothPlastic
    },
    berries = {
        name = "Ягоды",
        max = 32,
        isBlock = false,
        category = "food",
        icon = "🫐",
        color = Color3.fromRGB(215, 45, 75),
        material = Enum.Material.SmoothPlastic
    },
    mushrooms = {
        name = "Грибы",
        max = 32,
        isBlock = false,
        category = "food",
        icon = "🍄",
        color = Color3.fromRGB(180, 120, 80),
        material = Enum.Material.SmoothPlastic
    },
    seeds = {
        name = "Семена",
        max = 64,
        isBlock = false,
        category = "food",
        icon = "🌱",
        color = Color3.fromRGB(200, 170, 90),
        material = Enum.Material.SmoothPlastic
    },
    leaves = {
        name = "Листья",
        max = 64,
        isBlock = false,
        category = "food",
        icon = "🍃",
        color = Color3.fromRGB(80, 160, 60),
        material = Enum.Material.Grass
    },
    flowers = {
        name = "Цветы",
        max = 64,
        isBlock = false,
        category = "food",
        icon = "🌸",
        color = Color3.fromRGB(130, 100, 210),
        material = Enum.Material.SmoothPlastic
    },

    -- Инструменты (Сумка)
    axe = {
        name = "Топор",
        max = 1,
        isBlock = false,
        category = "tools",
        icon = "🪓",
        color = Color3.fromRGB(180, 160, 140),
        material = Enum.Material.Metal
    },
    pickaxe = {
        name = "Кирка",
        max = 1,
        isBlock = false,
        category = "tools",
        icon = "⛏️",
        color = Color3.fromRGB(150, 160, 175),
        material = Enum.Material.Metal
    },
    shovel = {
        name = "Лопата",
        max = 1,
        isBlock = false,
        category = "tools",
        icon = "🪚",
        color = Color3.fromRGB(160, 150, 140),
        material = Enum.Material.Metal
    },
    rod = {
        name = "Удочка",
        max = 1,
        isBlock = false,
        category = "tools",
        icon = "🎣",
        color = Color3.fromRGB(175, 130, 85),
        material = Enum.Material.Wood
    }
}

local BLOCK_CONFIG = {
    Grass = { Color = Color3.fromRGB(135, 145, 45),  Material = Enum.Material.Grass,      HP = 2, DropId = "grass_block" },
    Wood  = { Color = Color3.fromRGB(110, 68, 38),   Material = Enum.Material.WoodPlanks, HP = 4, DropId = "wood_block" },
    Stone = { Color = Color3.fromRGB(122, 128, 138), Material = Enum.Material.Slate,      HP = 5, DropId = "stone_block" },
    Dirt  = { Color = Color3.fromRGB(98, 64, 38),    Material = Enum.Material.Ground,     HP = 3, DropId = "dirt_block" },
    Sand  = { Color = Color3.fromRGB(225, 200, 120), Material = Enum.Material.Sand,       HP = 2, DropId = "sand_block" },
    Ice   = { Color = Color3.fromRGB(185, 225, 255), Material = Enum.Material.Ice,        HP = 2, DropId = "ice_block", Transparency = 0.22, Reflectance = 0.4, CastShadow = false, CanCollide = true },
    Water = { Color = Color3.fromRGB(75, 160, 235),  Material = Enum.Material.Glass,      HP = 1, DropId = "water_block", Transparency = 0.35, Reflectance = 0.3, CastShadow = false, CanCollide = false }
}

-- === ВРЕМЕНА ГОДА (ОСЕНЬ, ЗИМА, ВЕСНА, ЛЕТО) ===
local SEASON_CONFIGS = {
    autumn = {
        name = "\u{041e}\u{0441}\u{0435}\u{043d}\u{044c}",
        grassColor = Color3.fromRGB(135, 145, 45),
    },
    winter = {
        name = "\u{0417}\u{0438}\u{043c}\u{0430}",
        grassColor = Color3.fromRGB(225, 235, 245),
    },
    spring = {
        name = "\u{0412}\u{0435}\u{0441}\u{043d}\u{0430}",
        grassColor = Color3.fromRGB(75, 185, 50),
    },
    summer = {
        name = "\u{041b}\u{0435}\u{0442}\u{043e}",
        grassColor = Color3.fromRGB(68, 168, 48),
    }
}
local currentSeason = "autumn"
local SEASON_ORDER = { "autumn", "winter", "spring", "summer" }
local DAY_CYCLE_SECONDS = 300
local serverInGameTime = 14.0
local lastServerTime = 14.0

-- === РћРЎР’Р•Р©Р•РќРР• Р РќР•Р‘Рћ (РЎРѕР»РЅС†Рµ, Р›СѓРЅР°, 5-РјРёРЅСѓС‚РЅС‹Рµ СЃСѓС‚РєРё) ===
local Lighting = game:GetService("Lighting")
Lighting.Brightness = 2.0
Lighting.OutdoorAmbient = Color3.fromRGB(120, 130, 140)
Lighting.Ambient = Color3.fromRGB(85, 90, 100)
Lighting.ColorShift_Top = Color3.fromRGB(255, 245, 225)
Lighting.ClockTime = 14
Lighting.GeographicLatitude = 41.7
Lighting.ExposureCompensation = 0.05
Lighting.ShadowSoftness = 0.35

local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
sky.Name = "Sky"
sky.CelestialBodiesShown = true
sky.SunTextureId = "rbxassetid://6196665106"
sky.MoonTextureId = "rbxassetid://6444320592"
sky.SunAngularSize = 8
sky.MoonAngularSize = 8
sky.StarCount = 3000
sky.Parent = Lighting

local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmo.Glare = 0.35
atmo.Haze = 0.15
atmo.Density = 0.30
atmo.Parent = Lighting

local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
sunRays.Intensity = 0.25
sunRays.Spread = 0.75
sunRays.Parent = Lighting

local function applyBlockTextures(part, blockType)
    local cfg = BLOCK_CONFIG[blockType] or BLOCK_CONFIG.Grass
    part.Color = cfg.Color
    part.Material = cfg.Material
    if cfg.Transparency then part.Transparency = cfg.Transparency end
    if cfg.Reflectance then part.Reflectance = cfg.Reflectance end
    if cfg.CastShadow ~= nil then part.CastShadow = cfg.CastShadow end
    if cfg.CanCollide ~= nil then part.CanCollide = cfg.CanCollide end

    -- Удаляем текстуры и декали для чистого и ровного воксельного рельефа
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("Texture") or child:IsA("Decal") then
            child:Destroy()
        end
    end
end

-- Инициализация папок и ремоута
local worldFolder = Workspace:FindFirstChild("VoxelWorld")
if not worldFolder then
    worldFolder = Instance.new("Folder")
    worldFolder.Name = "VoxelWorld"
    worldFolder.Parent = Workspace
end

local lootFolder = Workspace:FindFirstChild("VoxelLoot")
if not lootFolder then
    lootFolder = Instance.new("Folder")
    lootFolder.Name = "VoxelLoot"
    lootFolder.Parent = Workspace
end

local voxelRemote = ReplicatedStorage:FindFirstChild("VoxelRemote")
if not voxelRemote then
    voxelRemote = Instance.new("RemoteEvent")
    voxelRemote.Name = "VoxelRemote"
    voxelRemote.Parent = ReplicatedStorage
end

local function getCanopyColor(treeType, seasonId)
    seasonId = seasonId or currentSeason
    if seasonId == "spring" then
        return (treeType == "Sakura") and Color3.fromRGB(255, 185, 215) or Color3.fromRGB(255, 240, 248)
    elseif seasonId == "autumn" then
        return (treeType == "Sakura") and Color3.fromRGB(215, 95, 30) or Color3.fromRGB(235, 165, 35)
    elseif seasonId == "winter" then
        return Color3.fromRGB(230, 240, 250)
    else
        return Color3.fromRGB(60, 165, 50)
    end
end

local function applySeason(seasonId)
    local sCfg = SEASON_CONFIGS[seasonId]
    if not sCfg then return end
    currentSeason = seasonId
    BLOCK_CONFIG.Grass.Color = sCfg.grassColor
    ITEMS.grass_block.color = sCfg.grassColor

    -- Перекрашиваем блоки травы и крон цветущих деревьев
    for _, block in ipairs(worldFolder:GetChildren()) do
        if block:GetAttribute("BlockType") == "Grass" then
            local isCanopy = (block:GetAttribute("IsCanopy") == true)
            if isCanopy then
                local treeType = block:GetAttribute("TreeType")
                if not treeType then
                    treeType = (block.Position.X > 0) and "Apple" or "Sakura"
                    block:SetAttribute("TreeType", treeType)
                end
                block:SetAttribute("IsCanopy", true)
                block.Color = getCanopyColor(treeType, seasonId)
            else
                block.Color = sCfg.grassColor
            end
        end
    end

    -- Оповещаем всех клиентов о смене сезона
    voxelRemote:FireAllClients("SeasonChanged", {
        season = currentSeason,
        seasonName = sCfg.name,
        time = serverInGameTime
    })
end

local function snapToGrid(pos, size)
    return Vector3.new(
        math.floor(pos.X / size + 0.5) * size,
        math.floor(pos.Y / size + 0.5) * size,
        math.floor(pos.Z / size + 0.5) * size
    )
end

local function createBlock(blockType, position, isDynamic)
    local cfg = BLOCK_CONFIG[blockType] or BLOCK_CONFIG.Grass
    local snappedPos = snapToGrid(position, BLOCK_SIZE)

    for _, existing in ipairs(worldFolder:GetChildren()) do
        if existing:IsA("BasePart") and (existing.Position - snappedPos).Magnitude < 0.2 then
            return nil
        end
    end

    local part = Instance.new("Part")
    part.Name = "Voxel_" .. blockType
    part.Size = Vector3.new(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
    part.Position = snappedPos
    part.Anchored = true
    part.Material = cfg.Material
    part.Color = cfg.Color
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    if cfg.Transparency then part.Transparency = cfg.Transparency end
    if cfg.Reflectance then part.Reflectance = cfg.Reflectance end
    if cfg.CastShadow ~= nil then part.CastShadow = cfg.CastShadow end
    if cfg.CanCollide ~= nil then part.CanCollide = cfg.CanCollide end

    part:SetAttribute("BlockType", blockType)
    part:SetAttribute("HP", cfg.HP)
    part:SetAttribute("MaxHP", cfg.HP)
    part:SetAttribute("IsDynamic", isDynamic or false)

    part.Parent = worldFolder
    applyBlockTextures(part, blockType)
    return part
end

-- === ИНВЕНТАРЬ ИГРОКОВ (Server-side) ===
-- 1..4   = Хотбар котёнка (4 слота спрайтов: Дерево, Земля, Камень, Трава)
-- 10..29 = Портфель (Ресурсы и блоки: 20 слотов)
-- 30..44 = Корзинка (Еда и сбор: 15 слотов)
-- 45..54 = Сумка (Инструменты: 10 слотов)
local MAX_SLOTS = 54
local HOTBAR_SLOTS = 6
local playerInventories = {}

local function getOrCreateInventory(player)
    local userId = player.UserId
    if not playerInventories[userId] then
        playerInventories[userId] = {
            activeSlot = 0, -- При старте строительный блок не выбран
            slots = {
                -- Активный хотбар спрайтов (1..4): Дерево, Земля, Камень, Трава
                [1] = { id = "dirt_block",  count = 32, max = 64 },
                [2] = { id = "sand_block",  count = 32, max = 64 },
                [3] = { id = "water_block", count = 32, max = 64 },
                [4] = { id = "grass_block", count = 32, max = 64 },
                [5] = { id = "stone_block", count = 16, max = 64 },
                [6] = { id = "wood_block",  count = 24, max = 64 },

                -- Portfolio: Resources and blocks
                [10] = { id = "dirt_block",  count = 32, max = 64 },
                [11] = { id = "sand_block",  count = 32, max = 64 },
                [12] = { id = "water_block", count = 32, max = 64 },
                [13] = { id = "grass_block", count = 32, max = 64 },
                [14] = { id = "stone_block", count = 16, max = 64 },
                [15] = { id = "wood_block",  count = 24, max = 64 },

                -- Корзинка: Еда и урожай (30..44)
                [30] = { id = "mushrooms",  count = 5,  max = 32 },
                [31] = { id = "leaves",     count = 8,  max = 64 },
                [32] = { id = "flowers",    count = 5,  max = 64 },
                [33] = { id = "seeds",      count = 24, max = 64 },
                [34] = { id = "fish",       count = 8,  max = 16 },
                [35] = { id = "berries",    count = 10, max = 32 },

                -- Сумка: Инструменты (45..54)
                [45] = { id = "shovel",     count = 1,  max = 1 },
                [46] = { id = "rod",        count = 1,  max = 1 },
                [47] = { id = "axe",        count = 1,  max = 1 },
                [48] = { id = "pickaxe",    count = 1,  max = 1 },
            }
        }
    end
    return playerInventories[userId]
end

local function syncPlayerInventory(player)
    local inv = getOrCreateInventory(player)
    local cleanSlots = {}
    for i = 1, MAX_SLOTS do
        local s = inv.slots[i]
        if s and s.id and s.count and s.count > 0 then
            cleanSlots[tostring(i)] = {
                id = s.id,
                count = s.count,
                max = s.max or 64
            }
        end
    end

    voxelRemote:FireClient(player, "InventoryUpdate", {
        slots = cleanSlots,
        activeSlot = inv.activeSlot,
        itemsDef = ITEMS
    })

    local char = player.Character
    if char then
        local activeItem = inv.activeSlot and inv.slots[inv.activeSlot]
        if activeItem and activeItem.count > 0 then
            char:SetAttribute("HeldItemId", activeItem.id)
            char:SetAttribute("HeldItemCount", activeItem.count)
        else
            char:SetAttribute("HeldItemId", "")
            char:SetAttribute("HeldItemCount", 0)
        end
    end
end

local function addItemToInventory(player, itemId, amount)
    local inv = getOrCreateInventory(player)
    local itemDef = ITEMS[itemId]
    if not itemDef then return false end

    local remaining = amount or 1
    local cat = itemDef.category or "resources"
    local catStart, catEnd = 10, 29
    if cat == "food" then
        catStart, catEnd = 30, 44
    elseif cat == "tools" then
        catStart, catEnd = 45, 54
    end

    -- 1. Сначала дополняем существующие стеки в хотбаре
    for i = 1, HOTBAR_SLOTS do
        local slot = inv.slots[i]
        if slot and slot.id == itemId and slot.count < slot.max then
            local space = slot.max - slot.count
            local addCount = math.min(space, remaining)
            slot.count = slot.count + addCount
            remaining = remaining - addCount
            if remaining <= 0 then break end
        end
    end

    -- 2. Дополняем существующие стеки в соответствующей сумке
    if remaining > 0 then
        for i = catStart, catEnd do
            local slot = inv.slots[i]
            if slot and slot.id == itemId and slot.count < slot.max then
                local space = slot.max - slot.count
                local addCount = math.min(space, remaining)
                slot.count = slot.count + addCount
                remaining = remaining - addCount
                if remaining <= 0 then break end
            end
        end
    end

    -- 3. Если осталось, ищем первый свободный слот в целевой сумке
    if remaining > 0 then
        for i = catStart, catEnd do
            if not inv.slots[i] then
                local addCount = math.min(itemDef.max, remaining)
                inv.slots[i] = {
                    id = itemId,
                    count = addCount,
                    max = itemDef.max
                }
                remaining = remaining - addCount
                if remaining <= 0 then break end
            end
        end
    end

    -- 4. Если целевая сумка полна, ищем любой свободный слот в других сумках
    if remaining > 0 then
        for i = 10, MAX_SLOTS do
            if not inv.slots[i] then
                local addCount = math.min(itemDef.max, remaining)
                inv.slots[i] = {
                    id = itemId,
                    count = addCount,
                    max = itemDef.max
                }
                remaining = remaining - addCount
                if remaining <= 0 then break end
            end
        end
    end

    syncPlayerInventory(player)
    return remaining < amount
end

local function removeItemFromSlot(player, slotIndex, amount)
    local inv = getOrCreateInventory(player)
    local slot = inv.slots[slotIndex]
    if not slot then return false end

    slot.count = slot.count - (amount or 1)
    if slot.count <= 0 then
        inv.slots[slotIndex] = nil
    end

    syncPlayerInventory(player)
    return true
end

local function moveOrSwapSlots(player, fromSlot, toSlot)
    local inv = getOrCreateInventory(player)
    if fromSlot < 1 or fromSlot > MAX_SLOTS or toSlot < 1 or toSlot > MAX_SLOTS then return end
    if fromSlot == toSlot then return end

    local itemFrom = inv.slots[fromSlot]
    local itemTo = inv.slots[toSlot]

    if itemFrom and itemTo and itemFrom.id == itemTo.id then
        local space = itemTo.max - itemTo.count
        if space > 0 then
            local moveCount = math.min(space, itemFrom.count)
            itemTo.count = itemTo.count + moveCount
            itemFrom.count = itemFrom.count - moveCount
            if itemFrom.count <= 0 then
                inv.slots[fromSlot] = nil
            end
        else
            inv.slots[toSlot] = itemFrom
            inv.slots[fromSlot] = itemTo
        end
    else
        inv.slots[toSlot] = itemFrom
        inv.slots[fromSlot] = itemTo
    end

    syncPlayerInventory(player)
end

-- Сортировка предметов в активной сумке
local function sortInventory(player, containerType)
    local inv = getOrCreateInventory(player)
    local startIdx, endIdx = 10, 29
    if containerType == "basket" then
        startIdx, endIdx = 30, 44
    elseif containerType == "toolbag" then
        startIdx, endIdx = 45, 54
    end

    local items = {}
    for i = startIdx, endIdx do
        if inv.slots[i] then
            table.insert(items, inv.slots[i])
            inv.slots[i] = nil
        end
    end

    local combined = {}
    for _, item in ipairs(items) do
        local matched = false
        for _, c in ipairs(combined) do
            if c.id == item.id and c.count < c.max then
                local space = c.max - c.count
                local add = math.min(space, item.count)
                c.count = c.count + add
                item.count = item.count - add
                if item.count <= 0 then
                    matched = true
                    break
                end
            end
        end
        if item.count > 0 then
            table.insert(combined, item)
        end
    end

    table.sort(combined, function(a, b) return a.id < b.id end)
    for idx, item in ipairs(combined) do
        local s = startIdx + idx - 1
        if s <= endIdx then
            inv.slots[s] = item
        end
    end

    syncPlayerInventory(player)
end

-- === ДРОП ЛУТА И АВТОМАТИЧЕСКИЙ СБОР КУБИКОВ ===
local function spawnLootDrop(itemId, position, targetPlayer)
    local itemDef = ITEMS[itemId]
    if not itemDef then return end

    local dropPart = Instance.new("Part")
    dropPart.Name = "LootDrop_" .. itemId
    dropPart.Size = Vector3.new(0.35, 0.35, 0.35)
    dropPart.Color = itemDef.color
    dropPart.Material = itemDef.material
    dropPart.Anchored = true
    dropPart.CanCollide = false
    dropPart.CastShadow = false

    local spawnPos = position + Vector3.new(math.random(-2, 2) * 0.1, 0.35, math.random(-2, 2) * 0.1)
    dropPart.Position = spawnPos

    dropPart:SetAttribute("ItemId", itemId)
    dropPart:SetAttribute("BaseY", spawnPos.Y)
    dropPart:SetAttribute("SpawnTick", tick())
    if targetPlayer then
        dropPart:SetAttribute("TargetUserId", targetPlayer.UserId)
    end
    dropPart.Parent = lootFolder

    game:GetService("Debris"):AddItem(dropPart, 90)
    return dropPart
end

RunService.Heartbeat:Connect(function(dt)
    -- Продвижение внутриигрового времени на сервере: 1 игровые сутки (24ч) = 720 секунд (12 минут реального времени)
    serverInGameTime = (serverInGameTime + dt * (24 / DAY_CYCLE_SECONDS)) % 24
    if serverInGameTime < lastServerTime and lastServerTime >= 23.0 and serverInGameTime < 2.0 then
        -- 1 игровые сутки завершились! Автоматический переход к следующему времени года: Осень -> Зима -> Весна -> Лето -> Осень...
        local nextSeason = "autumn"
        for i, s in ipairs(SEASON_ORDER) do
            if s == currentSeason then
                nextSeason = SEASON_ORDER[(i % #SEASON_ORDER) + 1]
                break
            end
        end
        applySeason(nextSeason)
    end
    lastServerTime = serverInGameTime

    local now = tick()
    local drops = lootFolder:GetChildren()
    local players = Players:GetPlayers()

    for _, drop in ipairs(drops) do
        if drop:IsA("BasePart") and drop.Parent == lootFolder then
            local itemId = drop:GetAttribute("ItemId")
            local itemDef = itemId and ITEMS[itemId]
            local targetUserId = drop:GetAttribute("TargetUserId")

            -- Ищем ближайшего игрока или целевого котика (кто разрушил блок)
            local targetHrp = nil
            local targetPlr = nil
            local minDist = 999

            for _, player in ipairs(players) do
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = (hrp.Position - drop.Position).Magnitude
                    -- Если это котик, который сломал блок — увеличенный радиус магнита (до 15 стад), иначе 9 стад
                    local maxAttractDist = (targetUserId == player.UserId) and 15.0 or 9.0
                    if dist <= maxAttractDist and dist < minDist then
                        minDist = dist
                        targetHrp = hrp
                        targetPlr = player
                    end
                end
            end

            if targetHrp and targetPlr then
                -- Магнитное притяжение кубика прямо к котику
                local direction = (targetHrp.Position - drop.Position)
                local dist = direction.Magnitude

                if dist <= 1.8 then
                    -- Кубик долетел до лапок котика — автоматически собираем в инвентарь!
                    local picked = addItemToInventory(targetPlr, itemId, 1)
                    if picked then
                        -- Всплывающее уведомление на экране (+1 Трава)
                        if itemDef then
                            voxelRemote:FireClient(targetPlr, "ItemPickedUp", {
                                name = itemDef.name or itemId,
                                count = 1
                            })
                        end

                        -- Красивый золотистый визуальный всплеск сбора
                        local p = Instance.new("Part")
                        p.Size = Vector3.new(0.25, 0.25, 0.25)
                        p.Position = drop.Position
                        p.Anchored = true
                        p.CanCollide = false
                        p.Material = Enum.Material.Neon
                        p.Color = Color3.fromRGB(255, 245, 170)
                        p.Parent = Workspace
                        local tw = TweenService:Create(p, TweenInfo.new(0.18), {
                            Position = targetHrp.Position,
                            Size = Vector3.new(0.04, 0.04, 0.04),
                            Transparency = 1
                        })
                        tw:Play()
                        tw.Completed:Connect(function() p:Destroy() end)

                        drop:Destroy()
                    end
                else
                    -- Кубик плавно и быстро летит по воздуху прямо в лапки котика
                    local speed = math.clamp(16 + (15 - dist) * 1.5, 14, 28)
                    local step = math.min(dist, speed * dt)
                    drop.Position = drop.Position + (direction.Unit * step)
                    drop.Orientation = drop.Orientation + Vector3.new(dt * 360, dt * 540, 0)
                end
            else
                -- Если игроков рядом нет — мягко покачивается над землей
                local baseY = drop:GetAttribute("BaseY") or drop.Position.Y
                local spawnTick = drop:GetAttribute("SpawnTick") or 0
                local elapsed = now - spawnTick
                drop.Position = Vector3.new(drop.Position.X, baseY + math.sin(elapsed * 3.5) * 0.10, drop.Position.Z)
                drop.Orientation = Vector3.new(0, (elapsed * 90) % 360, 0)
            end
        end
    end
end)

-- === ГЕНЕРАЦИЯ БОЛЬШОЙ УЮТНОЙ ПОЛЯНЫ ===
local function generateWorld()
    for _, child in ipairs(worldFolder:GetChildren()) do
        child:Destroy()
    end

    local oldPondBasin = Workspace:FindFirstChild("PondBasin")
    if oldPondBasin then
        oldPondBasin:Destroy()
    end

    local BASE_Y = 0
    local CLEARING_RADIUS = 28 -- РџСЂРѕСЃС‚РѕСЂРЅР°СЏ Р¶РёРІРѕРїРёСЃРЅР°СЏ РїРѕР»СЏРЅР° (РґРёР°РјРµС‚СЂ ~84 СЃС‚Р°РґР°)

    -- Р’СЃРїРѕРјРѕРіР°С‚РµР»СЊРЅР°СЏ С„СѓРЅРєС†РёСЏ РґР»СЏ РїСЂРѕРІРµСЂРєРё Р±Р»РёР·РѕСЃС‚Рё Рє РѕС‚СЂРµР·РєСѓ (РґР»СЏ С‚СЂРѕРїРёРЅРѕРє)
    local function distToSegment(px, pz, ax, az, bx, bz)
        local abx = bx - ax
        local abz = bz - az
        local apx = px - ax
        local apz = pz - az
        local lenSq = abx * abx + abz * abz
        if lenSq == 0 then return math.sqrt(apx * apx + apz * apz) end
        local t = math.clamp((apx * abx + apz * abz) / lenSq, 0, 1)
        local nx = ax + t * abx
        local nz = az + t * abz
        local dx = px - nx
        local dz = pz - nz
        return math.sqrt(dx * dx + dz * dz)
    end

    local function isPath(x, z)
        if distToSegment(x, z, 0, 0, 5, 2) < 1.1 then return true end
        if distToSegment(x, z, 5, 2, 9, 5) < 1.1 then return true end
        if distToSegment(x, z, 9, 5, 12, 6) < 1.1 then return true end

        if distToSegment(x, z, 0, 0, -5, -5) < 1.1 then return true end
        if distToSegment(x, z, -5, -5, -9, -9) < 1.1 then return true end

        if distToSegment(x, z, 0, 0, 7, -6) < 1.1 then return true end
        if distToSegment(x, z, 7, -6, 13, -11) < 1.1 then return true end

        if distToSegment(x, z, 0, 0, -2, 8) < 1.1 then return true end
        if distToSegment(x, z, -2, 8, -4, 14) < 1.1 then return true end

        return false
    end

    -- 1. Р РµР»СЊРµС„, С…РѕР»РјС‹, РѕР·РµСЂРѕ Рё СЂРѕРґРЅРёРє
    for x = -CLEARING_RADIUS - 4, CLEARING_RADIUS + 4 do
        for z = -CLEARING_RADIUS - 4, CLEARING_RADIUS + 4 do
            local dist = math.sqrt(x*x + z*z)
            local angle = math.atan2(z, x)
            local wobble = math.sin(angle * 3) * 2.8 + math.cos(angle * 5) * 1.6 + math.sin(angle * 2) * 1.2
            local maxDist = CLEARING_RADIUS + wobble

            if dist <= maxDist then
                local wx = x * BLOCK_SIZE
                local wz = z * BLOCK_SIZE

                local lakeDist = math.sqrt(((x - 13) / 1.15)^2 + ((z - 8) / 0.95)^2)
                local springDist = math.sqrt((x + 18)^2 + (z - 5)^2)

                if lakeDist <= 4.6 then
                    createBlock("Water", Vector3.new(wx, BASE_Y, wz), false)
                    createBlock("Sand",  Vector3.new(wx, BASE_Y - BLOCK_SIZE, wz), false)
                    createBlock("Stone", Vector3.new(wx, BASE_Y - BLOCK_SIZE * 2, wz), false)
                elseif springDist <= 2.3 then
                    createBlock("Water", Vector3.new(wx, BASE_Y, wz), false)
                    createBlock("Sand",  Vector3.new(wx, BASE_Y - BLOCK_SIZE, wz), false)
                    createBlock("Stone", Vector3.new(wx, BASE_Y - BLOCK_SIZE * 2, wz), false)
                else
                    local dHill1 = math.sqrt((x + 13)^2 + (z + 13)^2)
                    local dHill2 = math.sqrt((x - 16)^2 + (z + 14)^2)
                    local dHill3 = math.sqrt(((x + 5) / 1.35)^2 + ((z - 18) / 0.95)^2)

                    local hillTier = 0
                    if dHill1 <= 3.8 then
                        hillTier = 2
                    elseif dHill1 <= 7.2 then
                        hillTier = 1
                    elseif dHill2 <= 2.5 then
                        hillTier = 2
                    elseif dHill2 <= 5.4 then
                        hillTier = 1
                    elseif dHill3 <= 4.8 then
                        hillTier = 1
                    end

                    local surfaceType = "Grass"
                    if lakeDist <= 5.8 then
                        surfaceType = ((x + z) % 2 == 0) and "Sand" or "Dirt"
                    elseif springDist <= 3.4 then
                        surfaceType = "Dirt"
                    elseif isPath(x, z) then
                        surfaceType = "Dirt"
                    end

                    local topY = BASE_Y + hillTier * BLOCK_SIZE
                    createBlock(surfaceType, Vector3.new(wx, topY, wz), false)

                    for h = hillTier - 1, 0, -1 do
                        createBlock("Dirt", Vector3.new(wx, BASE_Y + h * BLOCK_SIZE, wz), false)
                    end

                    createBlock("Dirt",  Vector3.new(wx, BASE_Y - BLOCK_SIZE, wz), false)
                    createBlock("Stone", Vector3.new(wx, BASE_Y - BLOCK_SIZE * 2, wz), false)
                end
            end
        end
    end

    -- 2. Р’СЃРїРѕРјРѕРіР°С‚РµР»СЊРЅР°СЏ С„СѓРЅРєС†РёСЏ РґР»СЏ РіРµРЅРµСЂР°С†РёРё Р°РєРєСѓСЂР°С‚РЅРѕРіРѕ РІРѕРєСЃРµР»СЊРЅРѕРіРѕ РґРµСЂРµРІС†Р°
    local function spawnVoxelTree(bx, bz, trunkHeight, treeType, baseY)
        baseY = baseY or BASE_Y
        local posX = bx * BLOCK_SIZE
        local posZ = bz * BLOCK_SIZE

        for dx = -1, 1 do
            for dz = -1, 1 do
                if math.abs(dx) + math.abs(dz) <= 1 then
                    createBlock("Dirt", Vector3.new(posX + dx * BLOCK_SIZE, baseY, posZ + dz * BLOCK_SIZE), false)
                end
            end
        end

        for h = 1, trunkHeight do
            createBlock("Wood", Vector3.new(posX, baseY + h * BLOCK_SIZE, posZ), false)
        end

        local topY = baseY + trunkHeight * BLOCK_SIZE
        for dx = -1, 1 do
            for dz = -1, 1 do
                local blk = createBlock("Grass", Vector3.new(posX + dx * BLOCK_SIZE, topY, posZ + dz * BLOCK_SIZE), false)
                if blk then
                    blk:SetAttribute("IsCanopy", true)
                    blk:SetAttribute("TreeType", treeType or "Sakura")
                end
                if math.abs(dx) + math.abs(dz) <= 1 then
                    local topBlk = createBlock("Grass", Vector3.new(posX + dx * BLOCK_SIZE, topY + BLOCK_SIZE, posZ + dz * BLOCK_SIZE), false)
                    if topBlk then
                        topBlk:SetAttribute("IsCanopy", true)
                        topBlk:SetAttribute("TreeType", treeType or "Sakura")
                    end
                end
            end
        end
        if trunkHeight >= 4 then
            local peakBlk = createBlock("Grass", Vector3.new(posX, topY + BLOCK_SIZE * 2, posZ), false)
            if peakBlk then
                peakBlk:SetAttribute("IsCanopy", true)
                peakBlk:SetAttribute("TreeType", treeType or "Sakura")
            end
        end
    end

    -- РЎР°РєСѓСЂС‹
    spawnVoxelTree(-13, -13, 4, "Sakura", BASE_Y + BLOCK_SIZE * 2)
    spawnVoxelTree(-18, -10, 3, "Sakura", BASE_Y + BLOCK_SIZE)
    spawnVoxelTree(-21, -4, 4, "Sakura", BASE_Y)
    spawnVoxelTree(-16, 9, 3, "Sakura", BASE_Y)
    spawnVoxelTree(-11, 10, 4, "Sakura", BASE_Y)
    spawnVoxelTree(-15, 14, 3, "Sakura", BASE_Y)
    spawnVoxelTree(8, 14, 4, "Sakura", BASE_Y)
    spawnVoxelTree(3, -11, 3, "Sakura", BASE_Y)

    -- РЇР±Р»РѕРЅРё
    spawnVoxelTree(16, -14, 4, "Apple", BASE_Y + BLOCK_SIZE * 2)
    spawnVoxelTree(11, -8, 3, "Apple", BASE_Y)
    spawnVoxelTree(21, -6, 4, "Apple", BASE_Y)
    spawnVoxelTree(3, -20, 4, "Apple", BASE_Y)
    spawnVoxelTree(-6, -20, 3, "Apple", BASE_Y)
    spawnVoxelTree(21, 10, 3, "Apple", BASE_Y)
    spawnVoxelTree(15, 17, 4, "Apple", BASE_Y)
    spawnVoxelTree(-5, 19, 3, "Apple", BASE_Y + BLOCK_SIZE)

    -- 3. РљР°РјРЅРё Рё СЃРєР°Р»С‹
    local function spawnBoulder(bx, bz, height, baseY)
        baseY = baseY or BASE_Y
        local posX = bx * BLOCK_SIZE
        local posZ = bz * BLOCK_SIZE
        height = height or 1

        createBlock("Stone", Vector3.new(posX, baseY + BLOCK_SIZE, posZ), false)
        createBlock("Stone", Vector3.new(posX + BLOCK_SIZE, baseY + BLOCK_SIZE, posZ), false)
        createBlock("Stone", Vector3.new(posX, baseY + BLOCK_SIZE, posZ + BLOCK_SIZE), false)
        if height >= 2 then
            createBlock("Stone", Vector3.new(posX, baseY + BLOCK_SIZE * 2, posZ), false)
        end
        createBlock("Dirt", Vector3.new(posX - BLOCK_SIZE, baseY, posZ), false)
        createBlock("Dirt", Vector3.new(posX, baseY, posZ - BLOCK_SIZE), false)
    end

    createBlock("Stone", Vector3.new(-2 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, -23 * BLOCK_SIZE), false)
    createBlock("Stone", Vector3.new(-1 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, -23 * BLOCK_SIZE), false)
    createBlock("Stone", Vector3.new(0 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, -23 * BLOCK_SIZE), false)
    createBlock("Stone", Vector3.new(0 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE * 2, -23 * BLOCK_SIZE), false)
    createBlock("Stone", Vector3.new(1 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, -23 * BLOCK_SIZE), false)
    createBlock("Stone", Vector3.new(2 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, -22 * BLOCK_SIZE), false)
    createBlock("Stone", Vector3.new(3 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, -22 * BLOCK_SIZE), false)

    spawnBoulder(-18, -16, 2, BASE_Y + BLOCK_SIZE)
    spawnBoulder(-9, -17, 1, BASE_Y + BLOCK_SIZE)
    spawnBoulder(-16, -7, 1, BASE_Y)

    spawnBoulder(-21, 5, 2, BASE_Y)
    spawnBoulder(-16, 3, 1, BASE_Y)
    spawnBoulder(-19, 7, 1, BASE_Y)

    spawnBoulder(18, 5, 2, BASE_Y)
    spawnBoulder(17, 12, 1, BASE_Y)
    spawnBoulder(9, 4, 1, BASE_Y)

    createBlock("Stone", Vector3.new(10 * BLOCK_SIZE, BASE_Y, 7 * BLOCK_SIZE), false)
    createBlock("Stone", Vector3.new(10 * BLOCK_SIZE, BASE_Y, 8 * BLOCK_SIZE), false)
    createBlock("Stone", Vector3.new(11 * BLOCK_SIZE, BASE_Y, 9 * BLOCK_SIZE), false)

    spawnBoulder(13, -18, 1, BASE_Y + BLOCK_SIZE)
    spawnBoulder(20, -11, 2, BASE_Y)

    spawnBoulder(-9, 18, 1, BASE_Y + BLOCK_SIZE)
    spawnBoulder(0, 20, 2, BASE_Y)

    spawnBoulder(-6, 4, 1, BASE_Y)
    spawnBoulder(6, -3, 1, BASE_Y)
    spawnBoulder(-11, -3, 1, BASE_Y)
    spawnBoulder(22, 1, 1, BASE_Y)
    spawnBoulder(-20, 15, 1, BASE_Y)
    spawnBoulder(4, 18, 1, BASE_Y)

    -- 4. РџРµРЅРµС‡РєРё Рё Р±СЂРµРІРЅС‹С€РєРё
    createBlock("Wood", Vector3.new(-6 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, -9 * BLOCK_SIZE), false)
    createBlock("Wood", Vector3.new(-5 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, -9 * BLOCK_SIZE), false)
    createBlock("Wood", Vector3.new(-4 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, -9 * BLOCK_SIZE), false)

    createBlock("Wood", Vector3.new(16 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, 2 * BLOCK_SIZE), false)
    createBlock("Wood", Vector3.new(17 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, 2 * BLOCK_SIZE), false)
    createBlock("Wood", Vector3.new(18 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, 2 * BLOCK_SIZE), false)

    createBlock("Wood", Vector3.new(-12 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, 1 * BLOCK_SIZE), false)
    createBlock("Wood", Vector3.new(5 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, -6 * BLOCK_SIZE), false)
    createBlock("Wood", Vector3.new(18 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, -11 * BLOCK_SIZE), false)
    createBlock("Wood", Vector3.new(-3 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, 14 * BLOCK_SIZE), false)
    createBlock("Wood", Vector3.new(12 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, 14 * BLOCK_SIZE), false)

    -- 5. РћР±РЅРѕРІР»СЏРµРј SpringFishingPond РґР»СЏ РѕР·РµСЂР°
    local pondPart = Workspace:FindFirstChild("SpringFishingPond")
    if not pondPart then
        pondPart = Instance.new("Part")
        pondPart.Name = "SpringFishingPond"
        pondPart.Anchored = true
        pondPart.CanCollide = false
        pondPart.Material = Enum.Material.Glass
        pondPart.Color = Color3.fromRGB(45, 160, 230)
        pondPart.Parent = Workspace
    end
    pondPart.Position = Vector3.new(13 * BLOCK_SIZE, -0.1, 8 * BLOCK_SIZE)
    pondPart.Size = Vector3.new(16.5, 1.2, 15.0)
    pondPart.Transparency = 0.95
    pondPart.CanCollide = false
end

if #worldFolder:GetChildren() == 0 then
    generateWorld()
else
    -- РћР±РЅРѕРІР»СЏРµРј РјР°С‚РµСЂРёР°Р»С‹, С‚РµРєСЃС‚СѓСЂС‹ Рё СЂР°Р·РјРµС‡Р°РµРј РєСЂРѕРЅС‹ С†РІРµС‚СѓС‰РёС… РґРµСЂРµРІСЊРµРІ
    for _, block in ipairs(worldFolder:GetChildren()) do
        if block:IsA("BasePart") then
            local bType = block:GetAttribute("BlockType")
            if bType and BLOCK_CONFIG[bType] then
                applyBlockTextures(block, bType)
                local bCfg = BLOCK_CONFIG[bType]
                block:SetAttribute("HP", bCfg.HP)
                block:SetAttribute("MaxHP", bCfg.HP)
            end
            if bType == "Grass" and (block:GetAttribute("IsCanopy") == true) then
                local treeType = block:GetAttribute("TreeType")
                if not treeType then
                    local isApple = (block.Position.X > 0)
                    treeType = isApple and "Apple" or "Sakura"
                    block:SetAttribute("TreeType", treeType)
                end
            end
        end
    end
    applySeason(currentSeason)
end

-- === ЧАСТИЦЫ ===
-- === Р§РђРЎРўРР¦Р« ===
local function spawnBreakParticles(position, color, isBreak, optMaterial, isSphere)
    local count = isBreak and 6 or 3
    for _ = 1, count do
        local chip = Instance.new("Part")
        if isSphere then
            chip.Shape = Enum.PartType.Ball
        end
        local s = math.random(12, 18) * 0.01
        chip.Size = Vector3.new(s, s, s)
        chip.Color = color or Color3.fromRGB(150, 150, 150)
        chip.Material = optMaterial or Enum.Material.Plastic
        if optMaterial == Enum.Material.Glass then
            chip.Transparency = 0.35
        end
        chip.CanCollide = false
        chip.CanQuery = false
        chip.CanTouch = false
        chip.CastShadow = false
        chip.Anchored = false
        chip.Position = position + Vector3.new(
            (math.random() - 0.5) * 0.4,
            (math.random() - 0.5) * 0.3,
            (math.random() - 0.5) * 0.4
        )
        chip.Velocity = Vector3.new(
            (math.random() - 0.5) * 10,
            math.random(5, 11),
            (math.random() - 0.5) * 10
        )
        chip.Parent = Workspace
        game:GetService("Debris"):AddItem(chip, 0.4)
    end
end

-- Спавн игроков
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(0, 5.0, 0)
        end
        task.wait(0.2)
        syncPlayerInventory(player)
        voxelRemote:FireClient(player, "SeasonChanged", {
            season = currentSeason,
            seasonName = SEASON_CONFIGS[currentSeason].name,
            time = serverInGameTime
        })
    end)
    task.wait(0.4)
    syncPlayerInventory(player)
    voxelRemote:FireClient(player, "SeasonChanged", {
        season = currentSeason,
        seasonName = SEASON_CONFIGS[currentSeason].name,
        time = serverInGameTime
    })
end)

for _, pl in ipairs(Players:GetPlayers()) do
    task.spawn(function()
        task.wait(0.5)
        syncPlayerInventory(pl)
    end)
end

local playerLastHitTime = {}

-- === ОБРАБОТКА ДЕЙСТВИЙ ИГРОКА ===
voxelRemote.OnServerEvent:Connect(function(player, action, data)
    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local inv = getOrCreateInventory(player)

    if action == "FishPond" then
        -- Р’РµСЃРµРЅРЅСЏСЏ СЂС‹Р±Р°Р»РєР°: РїРѕРІС‹С€РµРЅРЅС‹Р№ С€Р°РЅСЃ СѓР»РѕРІР° РІРµСЃРЅРѕР№ (75%), РІ РґСЂСѓРіРёРµ СЃРµР·РѕРЅС‹ 40%
        local successChance = (currentSeason == "spring") and 75 or 40
        local roll = math.random(1, 100)
        local pondPos = rootPart.Position + (rootPart.CFrame.LookVector * 2.5)

        if roll <= successChance then
            -- РЈСЃРїРµС€РЅС‹Р№ СѓР»РѕРІ!
            addItemToInventory(player, "fish", 1)
            character:SetAttribute("HeldItemId", "fish")
            character:SetAttribute("HeldItemCount", 1)

            -- Р—РІРѕРЅРєРёР№ РІСЃРїР»РµСЃРє РІРѕРґС‹
            spawnBreakParticles(pondPos, Color3.fromRGB(190, 235, 255), false, Enum.Material.Glass, true)

            voxelRemote:FireClient(player, "ItemPickedUp", {
                name = (currentSeason == "spring") and "\u{0412}\u{0435}\u{0441}\u{0435}\u{043d}\u{043d}\u{044f}\u{044f} \u{0440}\u{044b}\u{0431}\u{043a}\u{0430} \u{1F41F}\u{2728}" or "\u{0420}\u{044b}\u{0431}\u{043a}\u{0430} \u{1F41F}",
                count = 1
            })
        else
            -- Р С‹Р±РєР° СЃРѕСЂРІР°Р»Р°СЃСЊ СЃ РєСЂСЋС‡РєР° СЃ Р»РµРіРєРёРј РІСЃРїР»РµСЃРєРѕРј
            spawnBreakParticles(pondPos, Color3.fromRGB(190, 235, 255), false, Enum.Material.Glass, true)
            voxelRemote:FireClient(player, "ItemPickedUp", {
                name = "Рыбка вильнула хвостом и уплыла... 💦",
                count = 0
            })
        end

    elseif action == "Hit" then
        local block = data.Block
        if not (block and block:IsDescendantOf(worldFolder)) then return end

        local dist = (rootPart.Position - block.Position).Magnitude
        if dist > MAX_REACH then return end

        local nowHit = os.clock()
        local lastHit = playerLastHitTime[player] or 0
        if nowHit - lastHit < 0.18 then
            return -- Защита от дублирования сетевых пакетов за один клик
        end
        playerLastHitTime[player] = nowHit

        local bType = block:GetAttribute("BlockType") or "Grass"
        local cfg = BLOCK_CONFIG[bType] or BLOCK_CONFIG.Grass

        local hp = block:GetAttribute("HP")
        if hp == nil or hp <= 0 then
            hp = cfg.HP
        end
        hp = hp - 1
        block:SetAttribute("HP", hp)
        block:SetAttribute("MaxHP", cfg.HP)

        -- РЎР±СЂРѕСЃ HP Рє РјР°РєСЃРёРјСѓРјСѓ, РµСЃР»Рё РєРѕС‚РёРє РїРµСЂРµСЃС‚Р°Р» РєРѕРїР°С‚СЊ СЌС‚РѕС‚ Р±Р»РѕРє РЅР° 8 СЃРµРєСѓРЅРґ
        local hitTimestamp = os.clock()
        block:SetAttribute("LastHitTime", hitTimestamp)
        task.delay(8, function()
            if block and block.Parent and block:GetAttribute("LastHitTime") == hitTimestamp then
                block:SetAttribute("HP", cfg.HP)
            end
        end)

        if hp <= 0 then
            local bType = block:GetAttribute("BlockType") or "Grass"
            local cfg = BLOCK_CONFIG[bType] or BLOCK_CONFIG.Grass
            local blockPos = block.Position

            spawnBreakParticles(blockPos, block.Color, true, block.Material, block.Name:find("Water") ~= nil)
            block:Destroy()

            if cfg.DropId then
                spawnLootDrop(cfg.DropId, blockPos, player)
            end
            if math.random(1, 100) <= 15 then
                spawnLootDrop("fish", blockPos + Vector3.new(0, 0.4, 0), player)
            end

            voxelRemote:FireClient(player, "BlockDestroyed", { Position = blockPos })
        else
            spawnBreakParticles(block.Position, block.Color, false, block.Material, block.Name:find("Water") ~= nil)
            local origSize = block.Size
            local shrinkTween = TweenService:Create(block, TweenInfo.new(0.06), {
                Size = origSize * 0.94
            })
            shrinkTween:Play()
            shrinkTween.Completed:Connect(function()
                if block and block.Parent then
                    TweenService:Create(block, TweenInfo.new(0.08), { Size = origSize }):Play()
                end
            end)
            voxelRemote:FireClient(player, "BlockHit", { Block = block, HP = hp, MaxHP = block:GetAttribute("MaxHP") })
        end

    elseif action == "Place" then
        local targetBlock = data.TargetBlock or data.targetBlock
        local normal = data.Normal or data.normal or Vector3.new(0, 1, 0)
        local slotIndex = data.Slot or data.slot or inv.activeSlot

        local slotItem = inv.slots[slotIndex]
        if not slotItem or slotItem.count <= 0 then return end

        local itemDef = ITEMS[slotItem.id]
        if not (itemDef and itemDef.isBlock) then return end

        if not (targetBlock and targetBlock:IsDescendantOf(worldFolder)) then return end

        local dist = (rootPart.Position - targetBlock.Position).Magnitude
        if dist > MAX_REACH then return end

        local newPos = snapToGrid(targetBlock.Position + (normal * BLOCK_SIZE), BLOCK_SIZE)
        local distNew = (rootPart.Position - newPos).Magnitude
        if distNew > MAX_REACH + 0.8 then return end

        for _, pl in ipairs(Players:GetPlayers()) do
            local ch = pl.Character
            local rp = ch and ch:FindFirstChild("HumanoidRootPart")
            if rp then
                local delta = rp.Position - newPos
                local overlapH = BLOCK_SIZE * 0.75
                local overlapV = BLOCK_SIZE * 0.85
                if math.abs(delta.X) < overlapH and
                   math.abs(delta.Y) < overlapV and
                   math.abs(delta.Z) < overlapH then
                    return
                end
            end
        end

        local newBlock = createBlock(itemDef.blockType, newPos, true)
        if newBlock then
            if itemDef.blockType == "Grass" then
                local isHigh = (newPos.Y >= 2.0)
                local targetIsWood = targetBlock and (targetBlock:GetAttribute("BlockType") == "Wood")
                local targetIsCanopy = targetBlock and targetBlock:GetAttribute("IsCanopy")

                if isHigh or targetIsWood or targetIsCanopy then
                    local treeType = targetBlock and targetBlock:GetAttribute("TreeType")
                    if not treeType then
                        for _, other in ipairs(worldFolder:GetChildren()) do
                            if other:IsA("BasePart") and other:GetAttribute("IsCanopy") then
                                if (other.Position - newPos).Magnitude <= 3.8 then
                                    treeType = other:GetAttribute("TreeType")
                                    if treeType then break end
                                end
                            end
                        end
                    end
                    if not treeType then
                        treeType = (newPos.X > 0) and "Apple" or "Sakura"
                    end

                    newBlock:SetAttribute("IsCanopy", true)
                    newBlock:SetAttribute("TreeType", treeType)
                    newBlock.Color = getCanopyColor(treeType, currentSeason)
                else
                    local sCfg = SEASON_CONFIGS[currentSeason]
                    if sCfg then
                        newBlock.Color = sCfg.grassColor
                    end
                end
            end

            removeItemFromSlot(player, slotIndex, 1)
            spawnBreakParticles(newPos, newBlock.Color, false, newBlock.Material, newBlock.Name:find("Water") ~= nil)
            voxelRemote:FireClient(player, "BlockPlaced", { Block = newBlock })
        end

    elseif action == "SelectSlot" then
        local slot = tonumber(data.slot)
        if slot and slot >= 0 and slot <= 9 then
            inv.activeSlot = (slot == 0) and nil or slot
            syncPlayerInventory(player)
        end

    elseif action == "MoveItem" then
        local fromSlot = tonumber(data.fromSlot)
        local toSlot = tonumber(data.toSlot)
        if fromSlot and toSlot then
            moveOrSwapSlots(player, fromSlot, toSlot)
        end

    elseif action == "SortInventory" then
        sortInventory(player, data and data.containerType or "backpack")

    elseif action == "SetSeason" then
        if data and data.season and SEASON_CONFIGS[data.season] then
            applySeason(data.season)
        end
    elseif action == "SetTime" then
        if data and data.time then
            serverInGameTime = (tonumber(data.time) or 12) % 24
            lastServerTime = serverInGameTime
            voxelRemote:FireAllClients("TimeChanged", { time = serverInGameTime })
        end
    end
end)
