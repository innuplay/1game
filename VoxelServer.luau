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
    twigs = {
        name = "Ветки",
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
        isBlock = false,
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
    Grass = { Color = Color3.fromRGB(135, 145, 45),  Material = Enum.Material.Grass,      HP = 1, DropId = "grass_block" },
    Wood  = { Color = Color3.fromRGB(110, 68, 38),   Material = Enum.Material.WoodPlanks, HP = 1, DropId = "wood_block" },
    Stone = { Color = Color3.fromRGB(122, 128, 138), Material = Enum.Material.Slate,      HP = 1, DropId = "stone_block" },
    Dirt  = { Color = Color3.fromRGB(98, 64, 38),    Material = Enum.Material.Ground,     HP = 1, DropId = "dirt_block" }
}

-- === ВРЕМЕНА ГОДА (ОСЕНЬ, ЗИМА, ВЕСНА, ЛЕТО) ===
local SEASON_CONFIGS = {
    autumn = {
        name = "Осень",
        grassColor = Color3.fromRGB(135, 145, 45),
    },
    winter = {
        name = "Зима",
        grassColor = Color3.fromRGB(225, 235, 245),
    },
    spring = {
        name = "Весна",
        grassColor = Color3.fromRGB(75, 185, 50),
    },
    summer = {
        name = "Лето",
        grassColor = Color3.fromRGB(68, 168, 48),
    }
}
local currentSeason = "autumn"

-- === НАСТРОЙКА ОСВЕЩЕНИЯ (МЯГКИЙ КОНТРАСТ, БЕЗ СЛЕПЯЩИХ БЛИКОВ) ===
local Lighting = game:GetService("Lighting")
Lighting.Brightness = 1.6
Lighting.OutdoorAmbient = Color3.fromRGB(115, 125, 135)
Lighting.Ambient = Color3.fromRGB(90, 95, 105)
Lighting.ColorShift_Top = Color3.fromRGB(255, 245, 230)
Lighting.ClockTime = 14
Lighting.GeographicLatitude = 41.7
Lighting.ExposureCompensation = 0

local function applyBlockTextures(part, blockType)
    local cfg = BLOCK_CONFIG[blockType] or BLOCK_CONFIG.Grass
    part.Color = cfg.Color
    part.Material = cfg.Material

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

local function applySeason(seasonId)
    local sCfg = SEASON_CONFIGS[seasonId]
    if not sCfg then return end
    currentSeason = seasonId
    BLOCK_CONFIG.Grass.Color = sCfg.grassColor
    ITEMS.grass_block.color = sCfg.grassColor

    -- Перекрашиваем все существующие блоки травы в мире под выбранный сезон
    for _, block in ipairs(worldFolder:GetChildren()) do
        if block:GetAttribute("BlockType") == "Grass" then
            block.Color = sCfg.grassColor
        end
    end

    -- Оповещаем всех клиентов о смене сезона
    voxelRemote:FireAllClients("SeasonChanged", {
        season = currentSeason,
        seasonName = sCfg.name
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
local HOTBAR_SLOTS = 4
local playerInventories = {}

local function getOrCreateInventory(player)
    local userId = player.UserId
    if not playerInventories[userId] then
        playerInventories[userId] = {
            activeSlot = 0, -- При старте строительный блок не выбран
            slots = {
                -- Активный хотбар спрайтов (1..4): Дерево, Земля, Камень, Трава
                [1] = { id = "wood_block",  count = 24, max = 64 },
                [2] = { id = "dirt_block",  count = 32, max = 64 },
                [3] = { id = "stone_block", count = 16, max = 64 },
                [4] = { id = "grass_block", count = 32, max = 64 },

                -- Портфель: Ресурсы и блоки в пиксель-арт стилистике (10..29)
                [10] = { id = "wood_block",  count = 24, max = 64 },
                [11] = { id = "dirt_block",  count = 32, max = 64 },
                [12] = { id = "stone_block", count = 16, max = 64 },
                [13] = { id = "grass_block", count = 32, max = 64 },

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

    local BASE_Y = 0
    local CLEARING_RADIUS = 18 -- Просторная поляна (радиус 18 блоков ~ 27 стадов, диаметр 54 стада)

    -- 1. Создаем просторный многослойный ландшафт поляны с естественными живыми краями
    for x = -CLEARING_RADIUS - 2, CLEARING_RADIUS + 2 do
        for z = -CLEARING_RADIUS - 2, CLEARING_RADIUS + 2 do
            local dist = math.sqrt(x*x + z*z)
            local angle = math.atan2(z, x)
            -- Мягкие гармонические волны по краям, чтобы поляна была живой и органичной
            local edgeWobble = math.sin(angle * 4) * 1.8 + math.cos(angle * 3) * 1.3
            local maxDist = CLEARING_RADIUS + edgeWobble

            if dist <= maxDist then
                local worldX = x * BLOCK_SIZE
                local worldZ = z * BLOCK_SIZE

                -- Верхний слой: мягкая сочная трава
                createBlock("Grass", Vector3.new(worldX, BASE_Y, worldZ), false)
                -- Подповерхностный слой: плодородная земля
                createBlock("Dirt", Vector3.new(worldX, BASE_Y - BLOCK_SIZE, worldZ), false)
                -- Коренной слой: крепкий камень
                createBlock("Stone", Vector3.new(worldX, BASE_Y - BLOCK_SIZE * 2, worldZ), false)

                -- Уютный холмик в северо-западном углу поляны (ступенька +1 блок для прыжков)
                local hillDist = math.sqrt((x + 10)^2 + (z + 10)^2)
                if hillDist <= 4.2 then
                    createBlock("Grass", Vector3.new(worldX, BASE_Y + BLOCK_SIZE, worldZ), false)
                end
            end
        end
    end

    -- Вспомогательная функция для генерации аккуратного воксельного деревца
    local function spawnVoxelTree(bx, bz, trunkHeight)
        local posX = bx * BLOCK_SIZE
        local posZ = bz * BLOCK_SIZE
        -- Ствол из древесины
        for h = 1, trunkHeight do
            createBlock("Wood", Vector3.new(posX, BASE_Y + h * BLOCK_SIZE, posZ), false)
        end
        -- Пушистая лиственная крона (из блоков листвы/травы)
        local topY = BASE_Y + trunkHeight * BLOCK_SIZE
        for dx = -1, 1 do
            for dz = -1, 1 do
                createBlock("Grass", Vector3.new(posX + dx * BLOCK_SIZE, topY, posZ + dz * BLOCK_SIZE), false)
                if math.abs(dx) + math.abs(dz) <= 1 then
                    createBlock("Grass", Vector3.new(posX + dx * BLOCK_SIZE, topY + BLOCK_SIZE, posZ + dz * BLOCK_SIZE), false)
                end
            end
        end
    end

    -- 2. Расставляем деревья по периметру поляны (центр остаётся свободным для бега котика)
    spawnVoxelTree(-9, -6, 3)
    spawnVoxelTree(10, -8, 3)
    spawnVoxelTree(-10, 8, 3)
    spawnVoxelTree(9, 7, 3)
    spawnVoxelTree(2, -12, 3)
    spawnVoxelTree(-5, 12, 3)

    -- 3. Каменные валуны для добычи ресурсов
    local function spawnBoulder(bx, bz)
        local posX = bx * BLOCK_SIZE
        local posZ = bz * BLOCK_SIZE
        createBlock("Stone", Vector3.new(posX, BASE_Y + BLOCK_SIZE, posZ), false)
        createBlock("Stone", Vector3.new(posX + BLOCK_SIZE, BASE_Y + BLOCK_SIZE, posZ), false)
        createBlock("Stone", Vector3.new(posX, BASE_Y + BLOCK_SIZE, posZ + BLOCK_SIZE), false)
    end
    spawnBoulder(7, 3)
    spawnBoulder(-7, -2)
    spawnBoulder(4, -8)
    spawnBoulder(-6, 7)

    -- 4. Пенечки и бревнышки
    createBlock("Wood", Vector3.new(-4 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, 3 * BLOCK_SIZE), false)
    createBlock("Wood", Vector3.new(5 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, -3 * BLOCK_SIZE), false)
    createBlock("Wood", Vector3.new(6 * BLOCK_SIZE, BASE_Y + BLOCK_SIZE, -3 * BLOCK_SIZE), false)
end

if #worldFolder:GetChildren() == 0 then
    generateWorld()
else
    -- Обновляем материалы и цвета на всех существующих блоках воксельного мира
    for _, block in ipairs(worldFolder:GetChildren()) do
        if block:IsA("BasePart") then
            local bType = block:GetAttribute("BlockType")
            if bType and BLOCK_CONFIG[bType] then
                applyBlockTextures(block, bType)
            end
        end
    end
end

-- === ЧАСТИЦЫ ===
local function spawnBreakParticles(position, color, isBreak)
    for _ = 1, (isBreak and 8 or 4) do
        local chip = Instance.new("Part")
        chip.Size = Vector3.new(0.2, 0.2, 0.2)
        chip.Color = color
        chip.Material = Enum.Material.Plastic
        chip.CanCollide = false
        chip.Anchored = false
        chip.Position = position + Vector3.new(
            math.random(-5, 5) * 0.1,
            math.random(0, 5) * 0.1,
            math.random(-5, 5) * 0.1
        )
        chip.Velocity = Vector3.new(
            math.random(-8, 8),
            math.random(6, 14),
            math.random(-8, 8)
        )
        chip.Parent = Workspace
        game:GetService("Debris"):AddItem(chip, 0.6)
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
            seasonName = SEASON_CONFIGS[currentSeason].name
        })
    end)
    task.wait(0.4)
    syncPlayerInventory(player)
    voxelRemote:FireClient(player, "SeasonChanged", {
        season = currentSeason,
        seasonName = SEASON_CONFIGS[currentSeason].name
    })
end)

for _, pl in ipairs(Players:GetPlayers()) do
    task.spawn(function()
        task.wait(0.5)
        syncPlayerInventory(pl)
    end)
end

-- === ОБРАБОТКА ДЕЙСТВИЙ ИГРОКА ===
voxelRemote.OnServerEvent:Connect(function(player, action, data)
    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local inv = getOrCreateInventory(player)

    if action == "Hit" then
        local block = data.Block
        if not (block and block:IsDescendantOf(worldFolder)) then return end

        local dist = (rootPart.Position - block.Position).Magnitude
        if dist > MAX_REACH then return end

        local hp = block:GetAttribute("HP") or 1
        hp = hp - 1
        block:SetAttribute("HP", hp)

        if hp <= 0 then
            local bType = block:GetAttribute("BlockType") or "Grass"
            local cfg = BLOCK_CONFIG[bType] or BLOCK_CONFIG.Grass
            local blockPos = block.Position

            spawnBreakParticles(blockPos, block.Color, true)
            block:Destroy()

            if cfg.DropId then
                spawnLootDrop(cfg.DropId, blockPos, player)
            end
            if math.random(1, 100) <= 15 then
                spawnLootDrop("fish", blockPos + Vector3.new(0, 0.4, 0), player)
            end

            voxelRemote:FireClient(player, "BlockDestroyed", { Position = blockPos })
        else
            spawnBreakParticles(block.Position, block.Color, false)
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
            removeItemFromSlot(player, slotIndex, 1)
            spawnBreakParticles(newPos, newBlock.Color, false)
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
    end
end)
