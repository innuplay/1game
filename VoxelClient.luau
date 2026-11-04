-- LocalScript: StarterPlayer -> StarterPlayerScripts -> VoxelClient
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local voxelRemote = ReplicatedStorage:WaitForChild("VoxelRemote")
local worldFolder = Workspace:WaitForChild("VoxelWorld")

-- Компактный размер блоков (1.5x1.5x1.5 studs)
local BLOCK_SIZE = 1.5
local MAX_INTERACTION_DISTANCE = 4.2 -- studs (максимальная дистанция взаимодействия: только рядом с котиком)

local function snapToGrid(pos, size)
    return Vector3.new(
        math.floor(pos.X / size + 0.5) * size,
        math.floor(pos.Y / size + 0.5) * size,
        math.floor(pos.Z / size + 0.5) * size
    )
end

-- Локальное состояние инвентаря
local currentInventorySlots = {}
local activeHotbarSlot = nil -- По умолчанию строительный объект не выбран
local settingsModalRef = nil
local mapModalRef = nil
local notebookModalRef = nil
local seasonWidgetRef = nil
local vitalityFrameRef = nil
local hudContainerRef = nil
local backpackBtnRef = nil
local itemsDefinition = {}

local selectedBackpackSlot = nil
local isBackpackOpen = false

-- === ИНТЕРФЕЙС (GUI) ===
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:FindFirstChild("VoxelBackpackGui") or Instance.new("ScreenGui")
screenGui.Name = "VoxelBackpackGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- === ДИНАМИЧЕСКИЙ КАСТОМНЫЙ КУРСОР МЫШИ (ЛАПКА И ПРЕДМЕТЫ-РУКИ) ===
-- Отображается ВЕЗДЕ: в мире, над кнопками, слотами и инвентарем без переключения на системную стрелку
local CURSORS = {
    paw       = "rbxassetid://122151686047697",
    paw_black = "rbxassetid://122151686047697",
    paw_white = "rbxassetid://140384836139208",
    wood      = "rbxassetid://89025202129773",
    stone     = "rbxassetid://71254227847223",
    grass     = "rbxassetid://137250626647209",
    dirt      = "rbxassetid://92809404994132",
    water     = "rbxassetid://140670080649685",
    sand      = "rbxassetid://140675465145697",
}

local ITEM_TO_CURSOR = {
    wood_block  = CURSORS.wood,
    stone_block = CURSORS.stone,
    grass_block = CURSORS.grass,
    dirt_block  = CURSORS.dirt,
    water_block = CURSORS.water,
    sand_block  = CURSORS.sand,
    wood        = CURSORS.wood,
    stone       = CURSORS.stone,
    grass       = CURSORS.grass,
    dirt        = CURSORS.dirt,
    water       = CURSORS.water,
    sand        = CURSORS.sand,
}

local NUM_HOTBAR_SLOTS = 6
local SLOT_SIZE = 54
local SLOT_GAP = 8
local TOTAL_HOTBAR_WIDTH = (NUM_HOTBAR_SLOTS * SLOT_SIZE) + ((NUM_HOTBAR_SLOTS - 1) * SLOT_GAP)

local HOTBAR_SLOT_DEFS = {
    [1] = { id = "dirt_block",  sprite = "rbxassetid://104779952223143", name = "\u{0417}\u{0435}\u{043c}\u{043b}\u{044f}",  icon = "\u{1F7EB}" },
    [2] = { id = "sand_block",  sprite = "rbxassetid://136811617960488", name = "\u{041f}\u{0435}\u{0441}\u{043e}\u{043a}",  icon = "\u{23F3}" },
    [3] = { id = "water_block", sprite = "rbxassetid://94567183251152",  name = "\u{0412}\u{043e}\u{0434}\u{0430}",   icon = "\u{1F4A7}" },
    [4] = { id = "grass_block", sprite = "rbxassetid://114424346454200", name = "\u{0422}\u{0440}\u{0430}\u{0432}\u{0430}",  icon = "\u{1F33F}" },
    [5] = { id = "stone_block", sprite = "rbxassetid://109072643235539", name = "\u{041a}\u{0430}\u{043c}\u{0435}\u{043d}\u{044c}", icon = "\u{1FAA8}" },
    [6] = { id = "wood_block",  sprite = "rbxassetid://102991854156536", name = "\u{0414}\u{0435}\u{0440}\u{0435}\u{0432}\u{043e}", icon = "\u{1FA95}" },
}

local cursorGui = playerGui:FindFirstChild("CustomCursorGui") or Instance.new("ScreenGui")
cursorGui.Name = "CustomCursorGui"
cursorGui.ResetOnSpawn = false
cursorGui.IgnoreGuiInset = true
cursorGui.DisplayOrder = 1000000
cursorGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local cursorImage = cursorGui:FindFirstChild("CursorImage") or Instance.new("ImageLabel")
cursorImage.Name = "CursorImage"
cursorImage.Size = UDim2.new(0, 32, 0, 32)
cursorImage.Position = UDim2.new(0, 0, 0, 0)
cursorImage.BackgroundTransparency = 1
cursorImage.Image = CURSORS.paw
cursorImage.ScaleType = Enum.ScaleType.Fit
cursorImage.ZIndex = 1000000
cursorImage.Active = false
cursorImage.Selectable = false
cursorImage.Parent = cursorGui
cursorGui.Parent = playerGui

UserInputService.MouseIconEnabled = false

local function isInsideGui(gui, mPos)
    if not (gui and gui.Visible) then return false end
    local absPos = gui.AbsolutePosition
    local absSize = gui.AbsoluteSize
    return (mPos.X >= absPos.X and mPos.X <= absPos.X + absSize.X and
            mPos.Y >= absPos.Y and mPos.Y <= absPos.Y + absSize.Y)
end

local function isPointerOverUIOrSystem(mPos)
    if mPos.X < 0 or mPos.Y < 0 then
        return false
    end

    -- 1. РњРѕРґР°Р»СЊРЅС‹Рµ РѕРєРЅР° (РµСЃР»Рё РѕС‚РєСЂС‹С‚С‹):
    if isBackpackOpen then return true end
    if settingsModalRef and settingsModalRef.Visible then return true end
    if mapModalRef and mapModalRef.Visible then return true end
    if notebookModalRef and notebookModalRef.Visible then return true end

    -- 2. РњРµРЅСЋ CoreGui (С‚РѕР»СЊРєРѕ РєРѕРјРїР°РєС‚РЅР°СЏ Р·РѕРЅР° РІ Р»РµРІРѕРј РІРµСЂС…РЅРµРј СѓРіР»Сѓ):
    if mPos.X <= 220 and mPos.Y <= 50 then
        return true
    end

    -- 3. Р§Р°СЃС‹ Рё РїРѕРіРѕРґР° (РІ РїСЂР°РІРѕРј РІРµСЂС…РЅРµРј СѓРіР»Сѓ):
    if seasonWidgetRef and isInsideGui(seasonWidgetRef, mPos) then
        return true
    end

    -- 4. РџР°РЅРµР»СЊ РїРѕРєР°Р·Р°С‚РµР»РµР№ (СЃР»РµРІР° РІРЅРёР·Сѓ):
    if vitalityFrameRef and isInsideGui(vitalityFrameRef, mPos) then
        return true
    end

    -- 5. РҐРѕС‚Р±Р°СЂ (РїРѕ С†РµРЅС‚СЂСѓ РІРЅРёР·Сѓ):
    if hudContainerRef and isInsideGui(hudContainerRef, mPos) then
        return true
    end

    -- 6. РљРЅРѕРїРєР° СЂСЋРєР·Р°РєР° [E] (РІ РїСЂР°РІРѕРј РЅРёР¶РЅРµРј СѓРіР»Сѓ):
    if backpackBtnRef and isInsideGui(backpackBtnRef, mPos) then
        return true
    end

    return false
end

local function getDesiredCursor(mPos)
    -- РџСЂРё РЅР°РІРµРґРµРЅРёРё РЅР° СЌР»РµРјРµРЅС‚С‹ РёРЅС‚РµСЂС„РµР№СЃР° -> Р°РєРєСѓСЂР°С‚РЅР°СЏ С‡РµСЂРЅР°СЏ Р»Р°РїРєР°:
    if isPointerOverUIOrSystem(mPos) then
        return CURSORS.paw
    end

    -- Р’ РёРіСЂРѕРІРѕРј РјРёСЂРµ: РµСЃР»Рё РІС‹Р±СЂР°РЅ СЃР»РѕС‚ С…РѕС‚Р±Р°СЂР° 1..4 -> РєСЂР°СЃРёРІС‹Р№ РєСѓСЂСЃРѕСЂ РІС‹Р±СЂР°РЅРЅРѕРіРѕ Р±Р»РѕРєР°!
    if activeHotbarSlot and activeHotbarSlot >= 1 and activeHotbarSlot <= 6 then
        local slotDef = HOTBAR_SLOT_DEFS and HOTBAR_SLOT_DEFS[activeHotbarSlot]
        local activeItem = currentInventorySlots and currentInventorySlots[activeHotbarSlot]
        local itemId = (activeItem and activeItem.id) or (slotDef and slotDef.id)
        if itemId then
            local blockCursor = ITEM_TO_CURSOR[itemId]
            if blockCursor then
                return blockCursor
            end
        end
    end

    -- РџРѕ СѓРјРѕР»С‡Р°РЅРёСЋ -> Р°РєРєСѓСЂР°С‚РЅР°СЏ С‡РµСЂРЅР°СЏ Р»Р°РїРєР°:
    return CURSORS.paw
end

local function updateCustomCursor()
    local mPos = UserInputService:GetMouseLocation()
    local isPressed = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)

    local targetIcon = getDesiredCursor(mPos)
    if cursorImage.Image ~= targetIcon then
        cursorImage.Image = targetIcon
    end

    -- Р’РµСЂС…РЅСЏСЏ СЃРёСЃС‚РµРјРЅР°СЏ РїРѕР»РѕСЃР° Roblox CoreGui (X <= 220 and Y <= 48):
    local isOverCoreGuiBar = (mPos.X <= 220 and mPos.Y <= 48)
    if isOverCoreGuiBar then
        UserInputService.MouseIconEnabled = true
        cursorImage.Visible = false
    else
        UserInputService.MouseIconEnabled = false
        cursorImage.Visible = true

        -- РђРєРєСѓСЂР°С‚РЅС‹Р№ СЂР°Р·РјРµСЂ РєСѓСЂСЃРѕСЂР°: 32x32 РІ РїРѕРєРѕРµ, 28x28 РїСЂРё РЅР°Р¶Р°С‚РёРё
        if isPressed then
            cursorImage.Size = UDim2.new(0, 28, 0, 28)
            cursorImage.Position = UDim2.new(0, mPos.X - 1, 0, mPos.Y - 1)
        else
            cursorImage.Size = UDim2.new(0, 32, 0, 32)
            cursorImage.Position = UDim2.new(0, mPos.X - 2, 0, mPos.Y - 2)
        end
    end
end
RunService.RenderStepped:Connect(updateCustomCursor)player.CharacterAdded:Connect(function()
    task.wait(0.1)
    updateCustomCursor()
end)

-- [HOTBAR_SLOT_DEFS defined at top of script]
local hudContainer = Instance.new("Frame")
hudContainer.Name = "WoodHudContainer"
hudContainerRef = hudContainer
hudContainer.Size = UDim2.new(0, TOTAL_HOTBAR_WIDTH, 0, 56)
hudContainer.Position = UDim2.new(0.5, -TOTAL_HOTBAR_WIDTH / 2, 1, -74)
hudContainer.BackgroundTransparency = 1
hudContainer.BorderSizePixel = 0
hudContainer.Parent = screenGui

-- 2. ФУНКЦИОНАЛЬНЫЙ ПОХОДНЫЙ РЮКЗАК (В САМОМ ПРАВОМ НИЖНЕМ УГЛУ)
local backpackBtn = Instance.new("ImageButton")
backpackBtn.Name = "OpenBackpackBtn"
backpackBtnRef = backpackBtn
backpackBtn.Size = UDim2.new(0, 58, 0, 58)
backpackBtn.AnchorPoint = Vector2.new(1, 1)
backpackBtn.Position = UDim2.new(1, -16, 1, -16) -- Самый правый нижний угол экрана
backpackBtn.BackgroundTransparency = 1
backpackBtn.BorderSizePixel = 0
backpackBtn.Image = "rbxassetid://94027994735248"
backpackBtn.ResampleMode = Enum.ResamplerMode.Pixelated
backpackBtn.ScaleType = Enum.ScaleType.Fit
backpackBtn.AutoButtonColor = false
backpackBtn.ZIndex = 6
backpackBtn.Parent = screenGui

-- Бейдж горячей клавиши [E]
local bpKeyBadge = Instance.new("TextLabel")
bpKeyBadge.Name = "KeyBadge"
bpKeyBadge.Size = UDim2.new(0, 18, 0, 12)
bpKeyBadge.Position = UDim2.new(1, -2, 1, -2)
bpKeyBadge.AnchorPoint = Vector2.new(1, 1)
bpKeyBadge.BackgroundColor3 = Color3.fromRGB(35, 20, 12)
bpKeyBadge.BackgroundTransparency = 0.2
bpKeyBadge.Text = "[E]"
bpKeyBadge.TextColor3 = Color3.fromRGB(255, 230, 120)
bpKeyBadge.Font = Enum.Font.FredokaOne
bpKeyBadge.TextSize = 9
bpKeyBadge.ZIndex = 8
bpKeyBadge.Parent = backpackBtn

local bpKeyCorner = Instance.new("UICorner")
bpKeyCorner.CornerRadius = UDim.new(0, 3)
bpKeyCorner.Parent = bpKeyBadge

backpackBtn.MouseEnter:Connect(function()
    backpackBtn.ImageColor3 = Color3.fromRGB(255, 245, 210)
end)
backpackBtn.MouseLeave:Connect(function()
    backpackBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
end)
backpackBtn.MouseButton1Down:Connect(function()
    backpackBtn.Size = UDim2.new(0, 53, 0, 53)
end)
backpackBtn.MouseButton1Up:Connect(function()
    backpackBtn.Size = UDim2.new(0, 58, 0, 58)
end)



-- === ПАНЕЛЬ ЖИЗНЕННЫХ ПОКАЗАТЕЛЕЙ (В ЛЕВОМ НИЖНЕМ УГЛУ) ===
-- Иконки: Еда (зеленая вилка и нож), Вода (голубая капля), Энергия (желтая молния)
local VITALITY_ICONS = {
    hunger = "rbxassetid://85498299233584",
    thirst = "rbxassetid://138664811721806",
    energy = "rbxassetid://129785022833362",
}

local catStats = {
    hunger = 100,
    thirst = 100,
    energy = 100,
}

local vitalityFrame = Instance.new("Frame")
vitalityFrame.Name = "VitalityStatusPanel"
vitalityFrameRef = vitalityFrame
vitalityFrame.Size = UDim2.new(0, 50, 0, 142)
vitalityFrame.Position = UDim2.new(1, -8, 0, 82) -- Р’ РїСЂР°РІРѕРј РІРµСЂС…РЅРµРј СѓРіР»Сѓ РїРѕРґ С‡Р°СЃР°РјРё Рё РїРѕРіРѕРґРѕР№
vitalityFrame.AnchorPoint = Vector2.new(1, 0)
vitalityFrame.BackgroundColor3 = Color3.fromRGB(111, 98, 77)
vitalityFrame.BorderSizePixel = 0
vitalityFrame.ZIndex = 5
vitalityFrame.Parent = screenGui

local vitCorner = Instance.new("UICorner")
vitCorner.CornerRadius = UDim.new(0, 10)
vitCorner.Parent = vitalityFrame

local vitStroke = Instance.new("UIStroke")
vitStroke.Color = Color3.fromRGB(80, 70, 55)
vitStroke.Thickness = 1.5
vitStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
vitStroke.Parent = vitalityFrame

local vitalityUIElements = {}

local function createVitalityColumn(name, iconId, colIndex, defaultPercent)
    local rowH = 142 / 3
    local colFrame = Instance.new("Frame")
    colFrame.Name = "Col_" .. name
    colFrame.Size = UDim2.new(1, 0, 0, math.floor(rowH))
    colFrame.Position = UDim2.new(0, 0, 0, math.floor((colIndex - 1) * rowH))
    colFrame.BackgroundTransparency = 1
    colFrame.ZIndex = 6
    colFrame.Parent = vitalityFrame

    -- Пиксельная иконка
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 22, 0, 24)
    icon.Position = UDim2.new(0.5, -11, 0, 4)
    icon.BackgroundTransparency = 1
    icon.Image = iconId
    icon.ResampleMode = Enum.ResamplerMode.Pixelated
    icon.ScaleType = Enum.ScaleType.Fit
    icon.ZIndex = 7
    icon.Parent = colFrame

    -- Текст процентов под иконкой
    local pctLabel = Instance.new("TextLabel")
    pctLabel.Name = "PercentText"
    pctLabel.Size = UDim2.new(1, 0, 0, 14)
    pctLabel.Position = UDim2.new(0, 0, 0, 27)
    pctLabel.BackgroundTransparency = 1
    pctLabel.Text = math.floor(defaultPercent) .. "%"
    pctLabel.TextColor3 = Color3.fromRGB(235, 230, 210)
    pctLabel.Font = Enum.Font.FredokaOne
    pctLabel.TextSize = 10
    pctLabel.ZIndex = 7
    pctLabel.Parent = colFrame

    local txtStroke = Instance.new("UIStroke")
    txtStroke.Color = Color3.fromRGB(40, 35, 25)
    txtStroke.Thickness = 1
    txtStroke.Parent = pctLabel

    -- Темная подложка горизонтальной полоски
    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.Size = UDim2.new(0, 30, 0, 3)
    barBg.Position = UDim2.new(0.5, -15, 0, 41)
    barBg.BackgroundColor3 = Color3.fromRGB(65, 75, 60)
    barBg.BorderSizePixel = 0
    barBg.ZIndex = 7
    barBg.Parent = colFrame

    local barBgCorner = Instance.new("UICorner")
    barBgCorner.CornerRadius = UDim.new(0, 1.5)
    barBgCorner.Parent = barBg

    -- Заполненная часть полоски (активная)
    local barFill = Instance.new("Frame")
    barFill.Name = "BarFill"
    barFill.Size = UDim2.new(math.clamp(defaultPercent / 100, 0, 1), 0, 1, 0)
    barFill.Position = UDim2.new(0, 0, 0, 0)
    barFill.BackgroundColor3 = (defaultPercent > 10) and Color3.fromRGB(132, 204, 118) or Color3.fromRGB(75, 85, 70)
    barFill.BorderSizePixel = 0
    barFill.ZIndex = 8
    barFill.Parent = barBg

    local barFillCorner = Instance.new("UICorner")
    barFillCorner.CornerRadius = UDim.new(0, 1.5)
    barFillCorner.Parent = barFill

    vitalityUIElements[name] = {
        label = pctLabel,
        bar = barFill,
    }
end

createVitalityColumn("hunger", VITALITY_ICONS.hunger, 1, catStats.hunger)
createVitalityColumn("thirst", VITALITY_ICONS.thirst, 2, catStats.thirst)
createVitalityColumn("energy", VITALITY_ICONS.energy, 3, catStats.energy)

local function updateVitalityDisplay()
    for statName, val in pairs(catStats) do
        local el = vitalityUIElements[statName]
        if el then
            el.label.Text = math.floor(val) .. "%"
            local frac = math.clamp(val / 100, 0, 1)
            el.bar.Size = UDim2.new(frac, 0, 1, 0)
            if frac > 0.1 then
                el.bar.BackgroundColor3 = Color3.fromRGB(132, 204, 118)
            else
                el.bar.BackgroundColor3 = Color3.fromRGB(75, 85, 70)
            end
        end
    end
end

-- Всплывающее уведомление о сборе лута
-- === ВРЕМЕНА ГОДА И ДЕНЬ / НОЧЬ (НОЧЬ С 23:00 ДО 05:00, ЗОЛОТЫЕ ЧАСЫ БЕЗ ЦИФР) ===
local SEASON_CONFIGS = {
    autumn = {
        name = "\u{041e}\u{0441}\u{0435}\u{043d}\u{044c}",
        tempNight = 2,
        tempDay = 12,
        ambientDay = Color3.fromRGB(125, 125, 115),
        ambientNight = Color3.fromRGB(60, 75, 105),
        colorShiftTop = Color3.fromRGB(255, 230, 190),
        brightnessDay = 1.9,
        brightnessNight = 0.85,
        fogColor = Color3.fromRGB(175, 155, 130),
        fogEnd = 320,
    },
    winter = {
        name = "\u{0417}\u{0438}\u{043c}\u{0430}",
        tempNight = -12,
        tempDay = -4,
        ambientDay = Color3.fromRGB(135, 145, 165),
        ambientNight = Color3.fromRGB(65, 80, 120),
        colorShiftTop = Color3.fromRGB(210, 230, 255),
        brightnessDay = 1.8,
        brightnessNight = 0.85,
        fogColor = Color3.fromRGB(190, 210, 235),
        fogEnd = 250,
    },
    spring = {
        name = "\u{0412}\u{0435}\u{0441}\u{043d}\u{0430}",
        tempNight = 4,
        tempDay = 18,
        ambientDay = Color3.fromRGB(130, 145, 135),
        ambientNight = Color3.fromRGB(65, 82, 118),
        colorShiftTop = Color3.fromRGB(255, 245, 220),
        brightnessDay = 2.0,
        brightnessNight = 0.85,
        fogColor = Color3.fromRGB(180, 215, 195),
        fogEnd = 380,
    },
    summer = {
        name = "\u{041b}\u{0435}\u{0442}\u{043e}",
        tempNight = 16,
        tempDay = 28,
        ambientDay = Color3.fromRGB(135, 145, 130),
        ambientNight = Color3.fromRGB(68, 85, 122),
        colorShiftTop = Color3.fromRGB(255, 245, 215),
        brightnessDay = 2.1,
        brightnessNight = 0.85,
        fogColor = Color3.fromRGB(200, 220, 240),
        fogEnd = 500,
    }
}
local currentSeasonId = "autumn"
local SEASON_ORDER = { "autumn", "winter", "spring", "summer" }
local inGameTime = 14.0 -- Стартуем в 14:00 (ясный день)
local seasonButtonsUI = {}

-- Виджет в верхнем правом углу экрана
local seasonWidget = Instance.new("Frame")
seasonWidget.Name = "SeasonTimeWidget"
seasonWidgetRef = seasonWidget
seasonWidget.Size = UDim2.new(0, 0, 0, 0)
seasonWidget.AutomaticSize = Enum.AutomaticSize.XY
seasonWidget.Position = UDim2.new(1, -8, 0, 8)
seasonWidget.AnchorPoint = Vector2.new(1, 0)
seasonWidget.BackgroundTransparency = 1
seasonWidget.ZIndex = 5
seasonWidget.Parent = screenGui

-- Золотые часы без цифр
local clockIcon = Instance.new("ImageLabel")
clockIcon.Name = "ClockIcon"
clockIcon.Size = UDim2.new(0, 32, 0, 32)
clockIcon.Position = UDim2.new(0, 0, 0, 0)
clockIcon.BackgroundTransparency = 1
clockIcon.Image = "rbxassetid://82825016999107"
clockIcon.ScaleType = Enum.ScaleType.Fit
clockIcon.ZIndex = 6
clockIcon.Parent = seasonWidget

-- Часовая стрелка (вращается по времени суток)
-- РџРѕРІРѕСЂРѕС‚РЅР°СЏ РѕСЃСЊ С‡Р°СЃРѕРІРѕР№ СЃС‚СЂРµР»РєРё (СЂР°Р·РјРµСЂ 1x1 СЂРѕРґРёС‚РµР»СЏ, РІСЂР°С‰Р°РµС‚СЃСЏ СЃС‚СЂРѕРіРѕ РІРѕРєСЂСѓРі С†РµРЅС‚СЂР° С‡Р°СЃРѕРІ)
local hourPivot = Instance.new("Frame")
hourPivot.Name = "HourPivot"
hourPivot.Size = UDim2.new(1, 0, 1, 0)
hourPivot.Position = UDim2.new(0.5, 0, 0.5, 0)
hourPivot.AnchorPoint = Vector2.new(0.5, 0.5)
hourPivot.BackgroundTransparency = 1
hourPivot.ZIndex = 7
hourPivot.Parent = clockIcon

local hourHand = Instance.new("Frame")
hourHand.Name = "HourHand"
hourHand.Size = UDim2.new(0, 2.5, 0, 8)
hourHand.Position = UDim2.new(0.5, -1.25, 0.5, -8)
hourHand.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
hourHand.BorderSizePixel = 0
hourHand.ZIndex = 7
hourHand.Parent = hourPivot

local hCorner = Instance.new("UICorner")
hCorner.CornerRadius = UDim.new(1, 0)
hCorner.Parent = hourHand

local minutePivot = Instance.new("Frame")
minutePivot.Name = "MinutePivot"
minutePivot.Size = UDim2.new(1, 0, 1, 0)
minutePivot.Position = UDim2.new(0.5, 0, 0.5, 0)
minutePivot.AnchorPoint = Vector2.new(0.5, 0.5)
minutePivot.BackgroundTransparency = 1
minutePivot.ZIndex = 8
minutePivot.Parent = clockIcon

local minuteHand = Instance.new("Frame")
minuteHand.Name = "MinuteHand"
minuteHand.Size = UDim2.new(0, 1.8, 0, 11.5)
minuteHand.Position = UDim2.new(0.5, -0.9, 0.5, -11.5)
minuteHand.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
minuteHand.BorderSizePixel = 0
minuteHand.ZIndex = 8
minuteHand.Parent = minutePivot

local mCorner = Instance.new("UICorner")
mCorner.CornerRadius = UDim.new(1, 0)
mCorner.Parent = minuteHand

local pin = Instance.new("Frame")
pin.Name = "ClockPin"
pin.Size = UDim2.new(0, 4, 0, 4)
pin.Position = UDim2.new(0.5, 0, 0.5, 0)
pin.AnchorPoint = Vector2.new(0.5, 0.5)
pin.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
pin.BorderSizePixel = 0
pin.ZIndex = 10
pin.Parent = clockIcon
local pCorner = Instance.new("UICorner")
pCorner.CornerRadius = UDim.new(1, 0)
pCorner.Parent = pin
local seasonLabel = Instance.new("TextLabel")
seasonLabel.Name = "SeasonLabel"
seasonLabel.Size = UDim2.new(0, 0, 0, 26)
seasonLabel.AutomaticSize = Enum.AutomaticSize.X
seasonLabel.Position = UDim2.new(0, 38, 0, 3)
seasonLabel.BackgroundTransparency = 1
seasonLabel.Text = "\u{041e}\u{0441}\u{0435}\u{043d}\u{044c}"
seasonLabel.TextColor3 = Color3.fromRGB(240, 235, 220)
seasonLabel.Font = Enum.Font.FredokaOne
seasonLabel.TextSize = 15
seasonLabel.TextXAlignment = Enum.TextXAlignment.Left
seasonLabel.ZIndex = 6
seasonLabel.Parent = seasonWidget
local sStroke = Instance.new("UIStroke")
sStroke.Color = Color3.fromRGB(30, 20, 15)
sStroke.Thickness = 1.2
sStroke.Parent = seasonLabel

-- Золотой термометр
local thermoIcon = Instance.new("ImageLabel")
thermoIcon.Name = "ThermoIcon"
thermoIcon.Size = UDim2.new(0, 13, 0, 30)
thermoIcon.Position = UDim2.new(0, 9, 0, 38)
thermoIcon.BackgroundTransparency = 1
thermoIcon.Image = "rbxassetid://78871414670017"
thermoIcon.ScaleType = Enum.ScaleType.Fit
thermoIcon.ZIndex = 6
thermoIcon.Parent = seasonWidget

-- Значение температуры ("+8 °C")
local tempLabel = Instance.new("TextLabel")
tempLabel.Name = "TempLabel"
tempLabel.Size = UDim2.new(0, 0, 0, 24)
tempLabel.AutomaticSize = Enum.AutomaticSize.X
tempLabel.Position = UDim2.new(0, 38, 0, 42)
tempLabel.BackgroundTransparency = 1
tempLabel.Text = "+8 °C"
tempLabel.TextColor3 = Color3.fromRGB(240, 235, 220)
tempLabel.Font = Enum.Font.FredokaOne
tempLabel.TextSize = 14
tempLabel.TextXAlignment = Enum.TextXAlignment.Left
tempLabel.ZIndex = 6
tempLabel.Parent = seasonWidget
local tStroke = Instance.new("UIStroke")
tStroke.Color = Color3.fromRGB(30, 20, 15)
tStroke.Thickness = 1.2
tStroke.Parent = tempLabel

local notifContainer = Instance.new("Frame")
notifContainer.Name = "NotifContainer"
notifContainer.Size = UDim2.new(0, 320, 0, 50)
notifContainer.Position = UDim2.new(0.5, -160, 1, -114)
notifContainer.BackgroundTransparency = 1
notifContainer.Parent = screenGui

local function showPickupNotification(itemName, count)
    local pill = Instance.new("TextLabel")
    pill.Size = UDim2.new(0, 210, 0, 24)
    pill.Position = UDim2.new(0.5, -105, 0, 18)
    pill.BackgroundColor3 = Color3.fromRGB(22, 34, 24)
    pill.BackgroundTransparency = 1
    pill.TextTransparency = 1
    pill.TextColor3 = Color3.fromRGB(160, 255, 150)
    pill.TextStrokeColor3 = Color3.fromRGB(15, 25, 15)
    pill.TextStrokeTransparency = 1
    pill.Font = Enum.Font.FredokaOne
    pill.TextSize = 12
    pill.Text = (count and count > 0) and string.format("+%d %s", count, itemName) or tostring(itemName)
    pill.ZIndex = 80
    pill.Parent = notifContainer

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(0, 7)
    pillCorner.Parent = pill

    local pillStroke = Instance.new("UIStroke")
    pillStroke.Name = "Border"
    pillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    pillStroke.Color = Color3.fromRGB(70, 185, 85)
    pillStroke.Thickness = 1.2
    pillStroke.Transparency = 1
    pillStroke.Parent = pill

    local popIn = TweenService:Create(pill, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -105, 0, 4),
        BackgroundTransparency = 0.12,
        TextTransparency = 0,
        TextStrokeTransparency = 0.3
    })
    local strokeIn = TweenService:Create(pillStroke, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 0.35
    })
    popIn:Play()
    strokeIn:Play()

    task.delay(2.4, function()
        if pill and pill.Parent then
            local fadeOut = TweenService:Create(pill, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -105, 0, -10),
                BackgroundTransparency = 1,
                TextTransparency = 1,
                TextStrokeTransparency = 1
            })
            local strokeOut = TweenService:Create(pillStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Transparency = 1
            })
            fadeOut:Play()
            strokeOut:Play()
            fadeOut.Completed:Connect(function()
                if pill and pill.Parent then pill:Destroy() end
            end)
        end
    end)
end

-- ============================================================
-- === ПОГОДНАЯ СИСТЕМА (ДОЖДЬ, СНЕГ, ВЕТЕР, ЛИСТЬЯ, ГРАД, ЛЕПЕСТКИ, СВЕТЛЯЧКИ) ===
-- ============================================================
local DAY_CYCLE_SECONDS = 300 -- 1 игровые сутки (24 часа) = 2 минуты реального времени

local weatherAnchor = Instance.new("Part")
weatherAnchor.Name = "WeatherAnchor"
weatherAnchor.Size = Vector3.new(220, 2, 220)
weatherAnchor.Transparency = 1
weatherAnchor.Anchored = true
weatherAnchor.CanCollide = false
weatherAnchor.CanTouch = false
weatherAnchor.CanQuery = false
weatherAnchor.CastShadow = false
weatherAnchor.Parent = Workspace

local firefliesAnchor = Instance.new("Part")
firefliesAnchor.Name = "FirefliesAnchor"
firefliesAnchor.Size = Vector3.new(120, 2, 120)
firefliesAnchor.Transparency = 1
firefliesAnchor.Anchored = true
firefliesAnchor.CanCollide = false
firefliesAnchor.CanTouch = false
firefliesAnchor.CanQuery = false
firefliesAnchor.CastShadow = false
firefliesAnchor.Parent = Workspace

-- 1. Осенние летящие листья (золотые, оранжевые, багряные листья)
local leavesEmitter = Instance.new("ParticleEmitter")
leavesEmitter.Name = "LeavesEmitter"
leavesEmitter.Rate = 95
leavesEmitter.Lifetime = NumberRange.new(5.0, 7.5)
leavesEmitter.Speed = NumberRange.new(8, 14)
leavesEmitter.SpreadAngle = Vector2.new(20, 20)
leavesEmitter.EmissionDirection = Enum.NormalId.Bottom
leavesEmitter.Acceleration = Vector3.new(12, -8, 6)
leavesEmitter.RotSpeed = NumberRange.new(-180, 180)
leavesEmitter.Rotation = NumberRange.new(0, 360)
leavesEmitter.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 140, 25)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(205, 75, 20)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(155, 45, 15))
})
leavesEmitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.38),
    NumberSequenceKeypoint.new(0.5, 0.44),
    NumberSequenceKeypoint.new(1, 0.32)
})
leavesEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.05),
    NumberSequenceKeypoint.new(0.85, 0.15),
    NumberSequenceKeypoint.new(1, 1)
})
leavesEmitter.Enabled = false
leavesEmitter.Parent = weatherAnchor

-- 2. Порывистый ветер (серебристо-белые полосы завихрения воздуха)
local windEmitter = Instance.new("ParticleEmitter")
windEmitter.Name = "WindEmitter"
windEmitter.Rate = 35
windEmitter.Lifetime = NumberRange.new(1.8, 2.8)
windEmitter.Speed = NumberRange.new(30, 45)
windEmitter.SpreadAngle = Vector2.new(10, 10)
windEmitter.EmissionDirection = Enum.NormalId.Right
windEmitter.Acceleration = Vector3.new(25, -2, 10)
windEmitter.Color = ColorSequence.new(Color3.fromRGB(240, 245, 255))
windEmitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.12),
    NumberSequenceKeypoint.new(0.5, 0.3),
    NumberSequenceKeypoint.new(1, 0.04)
})
windEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.2, 0.65),
    NumberSequenceKeypoint.new(0.7, 0.65),
    NumberSequenceKeypoint.new(1, 1)
})
windEmitter.Enabled = false
windEmitter.Parent = weatherAnchor

-- 3. Дождь (падающие наклонные струи воды)
local rainEmitter = Instance.new("ParticleEmitter")
rainEmitter.Name = "RainEmitter"
rainEmitter.Rate = 850
rainEmitter.Lifetime = NumberRange.new(0.65, 0.90)
rainEmitter.Speed = NumberRange.new(50, 70)
rainEmitter.SpreadAngle = Vector2.new(4, 4)
rainEmitter.EmissionDirection = Enum.NormalId.Bottom
rainEmitter.Orientation = Enum.ParticleOrientation.VelocityParallel
rainEmitter.Acceleration = Vector3.new(5, -85, 3)
rainEmitter.Color = ColorSequence.new(Color3.fromRGB(190, 215, 250))
rainEmitter.Size = NumberSequence.new(0.08)
rainEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.4),
    NumberSequenceKeypoint.new(1, 0.6)
})
rainEmitter.Enabled = false
rainEmitter.Parent = weatherAnchor

-- 4. Пушистый снег (мягко кружащиеся белые хлопья снега)
local snowEmitter = Instance.new("ParticleEmitter")
snowEmitter.Name = "SnowEmitter"
snowEmitter.Rate = 380
snowEmitter.Lifetime = NumberRange.new(5.5, 8.0)
snowEmitter.Speed = NumberRange.new(5, 9)
snowEmitter.SpreadAngle = Vector2.new(15, 15)
snowEmitter.EmissionDirection = Enum.NormalId.Bottom
snowEmitter.Acceleration = Vector3.new(4, -5, 2)
snowEmitter.RotSpeed = NumberRange.new(-50, 50)
snowEmitter.Color = ColorSequence.new(Color3.fromRGB(248, 252, 255))
snowEmitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.22),
    NumberSequenceKeypoint.new(0.5, 0.32),
    NumberSequenceKeypoint.new(1, 0.2)
})
snowEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.15),
    NumberSequenceKeypoint.new(0.85, 0.2),
    NumberSequenceKeypoint.new(1, 1)
})
snowEmitter.Enabled = false
snowEmitter.Parent = weatherAnchor

-- 5. Ледяной град (быстрые плотные ледяные крупинки)
local hailEmitter = Instance.new("ParticleEmitter")
hailEmitter.Name = "HailEmitter"
hailEmitter.Rate = 220
hailEmitter.Lifetime = NumberRange.new(0.55, 0.80)
hailEmitter.Speed = NumberRange.new(65, 85)
hailEmitter.SpreadAngle = Vector2.new(6, 6)
hailEmitter.EmissionDirection = Enum.NormalId.Bottom
hailEmitter.Orientation = Enum.ParticleOrientation.VelocityParallel
hailEmitter.Acceleration = Vector3.new(8, -100, 4)
hailEmitter.Color = ColorSequence.new(Color3.fromRGB(230, 245, 255))
hailEmitter.Size = NumberSequence.new(0.16)
hailEmitter.Transparency = NumberSequence.new(0.1)
hailEmitter.Enabled = false
hailEmitter.Parent = weatherAnchor

-- 6. Весенние цветочные лепестки (розовые и белые лепестки сакуры)
local petalsEmitter = Instance.new("ParticleEmitter")
petalsEmitter.Name = "PetalsEmitter"
petalsEmitter.Rate = 100
petalsEmitter.Lifetime = NumberRange.new(5.0, 7.5)
petalsEmitter.Speed = NumberRange.new(6, 11)
petalsEmitter.SpreadAngle = Vector2.new(20, 20)
petalsEmitter.EmissionDirection = Enum.NormalId.Bottom
petalsEmitter.Acceleration = Vector3.new(7, -6, 5)
petalsEmitter.RotSpeed = NumberRange.new(-120, 120)
petalsEmitter.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 220)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 175, 205)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 235))
})
petalsEmitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.26),
    NumberSequenceKeypoint.new(0.5, 0.32),
    NumberSequenceKeypoint.new(1, 0.2)
})
petalsEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.1),
    NumberSequenceKeypoint.new(0.85, 0.15),
    NumberSequenceKeypoint.new(1, 1)
})
petalsEmitter.Enabled = false
petalsEmitter.Parent = weatherAnchor

-- 7. Ночные светлячки (теплое мерцание в летнюю ночь)
local firefliesEmitter = Instance.new("ParticleEmitter")
firefliesEmitter.Name = "FirefliesEmitter"
firefliesEmitter.Rate = 28
firefliesEmitter.Lifetime = NumberRange.new(3.5, 6.0)
firefliesEmitter.Speed = NumberRange.new(1.5, 3.5)
firefliesEmitter.SpreadAngle = Vector2.new(45, 45)
firefliesEmitter.EmissionDirection = Enum.NormalId.Top
firefliesEmitter.Acceleration = Vector3.new(0.5, 0.3, -0.5)
firefliesEmitter.Color = ColorSequence.new(Color3.fromRGB(225, 255, 110))
firefliesEmitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.1),
    NumberSequenceKeypoint.new(0.5, 0.22),
    NumberSequenceKeypoint.new(1, 0.1)
})
firefliesEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.2, 0.1),
    NumberSequenceKeypoint.new(0.5, 0.75),
    NumberSequenceKeypoint.new(0.8, 0.1),
    NumberSequenceKeypoint.new(1, 1)
})
firefliesEmitter.Enabled = false
firefliesEmitter.Parent = firefliesAnchor

-- 8. РЎС‚РµР»СЋС‰РёР№СЃСЏ СѓС‚СЂРµРЅРЅРёР№ РІРµСЃРµРЅРЅРёР№ С‚СѓРјР°РЅ Сѓ Р·РµРјР»Рё
local groundFogEmitter = Instance.new("ParticleEmitter")
groundFogEmitter.Name = "GroundFogEmitter"
groundFogEmitter.Rate = 26
groundFogEmitter.Lifetime = NumberRange.new(4.5, 6.5)
groundFogEmitter.Speed = NumberRange.new(1.0, 2.0)
groundFogEmitter.SpreadAngle = Vector2.new(180, 0)
groundFogEmitter.EmissionDirection = Enum.NormalId.Top
groundFogEmitter.Acceleration = Vector3.new(0.6, 0.08, 0.4)
groundFogEmitter.Color = ColorSequence.new(Color3.fromRGB(220, 235, 248))
groundFogEmitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 3.5),
    NumberSequenceKeypoint.new(0.5, 7.0),
    NumberSequenceKeypoint.new(1, 4.0)
})
groundFogEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.2, 0.82),
    NumberSequenceKeypoint.new(0.8, 0.85),
    NumberSequenceKeypoint.new(1, 1)
})
groundFogEmitter.Enabled = false
groundFogEmitter.Parent = firefliesAnchor

-- 9. Р’РµСЃРµРЅРЅРёРµ СЂР°Р·РЅРѕС†РІРµС‚РЅС‹Рµ Р±Р°Р±РѕС‡РєРё (РїРѕСЂС…Р°СЋС‚ РЅР°Рґ С†РІРµС‚СѓС‰РµР№ РїРѕР»СЏРЅРѕР№ СЃ 11:00 РґРѕ 17:00)
local butterfliesEmitter = Instance.new("ParticleEmitter")
butterfliesEmitter.Name = "ButterfliesEmitter"
butterfliesEmitter.Rate = 20
butterfliesEmitter.Lifetime = NumberRange.new(5.0, 8.0)
butterfliesEmitter.Speed = NumberRange.new(1.2, 2.8)
butterfliesEmitter.SpreadAngle = Vector2.new(45, 45)
butterfliesEmitter.EmissionDirection = Enum.NormalId.Top
butterfliesEmitter.Acceleration = Vector3.new(0.8, 0.25, -0.6)
butterfliesEmitter.RotSpeed = NumberRange.new(-75, 75)
butterfliesEmitter.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 235, 75)),  -- Р›РёРјРѕРЅРЅРѕ-Р¶РµР»С‚Р°СЏ
    ColorSequenceKeypoint.new(0.35, Color3.fromRGB(110, 215, 255)), -- РќРµР¶РЅРѕ-РіРѕР»СѓР±Р°СЏ
    ColorSequenceKeypoint.new(0.70, Color3.fromRGB(255, 145, 185)), -- Р РѕР·РѕРІР°СЏ
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(248, 252, 255))   -- Р‘РµР»СЏРЅРєР°
})
butterfliesEmitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0.0, 0.16),
    NumberSequenceKeypoint.new(0.5, 0.32),
    NumberSequenceKeypoint.new(1.0, 0.18)
})
butterfliesEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0.0, 1.0),
    NumberSequenceKeypoint.new(0.15, 0.05),
    NumberSequenceKeypoint.new(0.85, 0.1),
    NumberSequenceKeypoint.new(1.0, 1.0)
})
butterfliesEmitter.Enabled = false
butterfliesEmitter.Parent = firefliesAnchor

-- 10. РџСѓС€РёСЃС‚С‹Рµ РїРѕР»РѕСЃР°С‚С‹Рµ РІРµСЃРµРЅРЅРёРµ С€РјРµР»Рё
local bumblebeesEmitter = Instance.new("ParticleEmitter")
bumblebeesEmitter.Name = "BumblebeesEmitter"
bumblebeesEmitter.Rate = 10
bumblebeesEmitter.Lifetime = NumberRange.new(4.0, 6.5)
bumblebeesEmitter.Speed = NumberRange.new(1.8, 3.2)
bumblebeesEmitter.SpreadAngle = Vector2.new(35, 35)
bumblebeesEmitter.EmissionDirection = Enum.NormalId.Top
bumblebeesEmitter.Acceleration = Vector3.new(0.4, 0.1, 0.4)
bumblebeesEmitter.RotSpeed = NumberRange.new(-40, 40)
bumblebeesEmitter.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(245, 190, 40)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(45, 35, 25)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(245, 190, 40))
})
bumblebeesEmitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0.0, 0.14),
    NumberSequenceKeypoint.new(0.5, 0.24),
    NumberSequenceKeypoint.new(1.0, 0.14)
})
bumblebeesEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0.0, 1.0),
    NumberSequenceKeypoint.new(0.15, 0.0),
    NumberSequenceKeypoint.new(0.85, 0.05),
    NumberSequenceKeypoint.new(1.0, 1.0)
})
bumblebeesEmitter.Enabled = false
bumblebeesEmitter.Parent = firefliesAnchor

-- 11. Р¤РѕРЅРѕРІРѕРµ РїРµРЅРёРµ РїС‚РёС† (Р°РєС‚РёРІРёСЂСѓРµС‚СЃСЏ РЅР° СЂР°СЃСЃРІРµС‚Рµ СЃ 05:00, РїРѕРµС‚ РґРЅРµРј Рё Р·Р°С‚РёС…Р°РµС‚ Рє 21:00)
local rainbowFolder = Instance.new("Folder")
rainbowFolder.Name = "RainbowVisual"
rainbowFolder.Parent = Workspace

local rPart0 = Instance.new("Part")
rPart0.Name = "RainbowNode0"
rPart0.Size = Vector3.new(1, 1, 1)
rPart0.Position = Vector3.new(-85, 4, -85)
rPart0.Anchored = true
rPart0.CanCollide = false
rPart0.CanTouch = false
rPart0.CanQuery = false
rPart0.CastShadow = false
rPart0.Transparency = 1
rPart0.Parent = rainbowFolder

local rPart1 = Instance.new("Part")
rPart1.Name = "RainbowNode1"
rPart1.Size = Vector3.new(1, 1, 1)
rPart1.Position = Vector3.new(85, 4, -85)
rPart1.Anchored = true
rPart1.CanCollide = false
rPart1.CanTouch = false
rPart1.CanQuery = false
rPart1.CastShadow = false
rPart1.Transparency = 1
rPart1.Parent = rainbowFolder

local rAtt0 = Instance.new("Attachment")
rAtt0.Name = "Att0"
rAtt0.Parent = rPart0

local rAtt1 = Instance.new("Attachment")
rAtt1.Name = "Att1"
rAtt1.Parent = rPart1

local rainbowBeam = Instance.new("Beam")
rainbowBeam.Name = "RainbowArcBeam"
rainbowBeam.Attachment0 = rAtt0
rainbowBeam.Attachment1 = rAtt1
rainbowBeam.Width0 = 14
rainbowBeam.Width1 = 14
rainbowBeam.CurveSize0 = 80
rainbowBeam.CurveSize1 = -80
rainbowBeam.FaceCamera = true
rainbowBeam.LightEmission = 0.65
rainbowBeam.LightInfluence = 0.05
rainbowBeam.Segments = 32

-- 7 spectral colors of rainbow (Red, Orange, Yellow, Green, Cyan, Blue, Violet)
rainbowBeam.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 60, 60)),
    ColorSequenceKeypoint.new(0.18, Color3.fromRGB(255, 150, 40)),
    ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 235, 40)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(60, 220, 80)),
    ColorSequenceKeypoint.new(0.68, Color3.fromRGB(60, 200, 255)),
    ColorSequenceKeypoint.new(0.85, Color3.fromRGB(60, 100, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(180, 70, 240))
})
rainbowBeam.Enabled = false
rainbowBeam.Parent = rainbowFolder

local currentRainbowAlpha = 0
local springFogAlpha = 0
local nextLightningTime = 0
local isFlashingLightning = false
local function triggerLightningStrike()
    if isFlashingLightning then return end
    isFlashingLightning = true

    task.spawn(function()
        local cam = Workspace.CurrentCamera
        local camPos = cam and cam.CFrame.Position or Vector3.new(0, 20, 0)

        local offsetX = math.random(-110, 110)
        local offsetZ = math.random(-110, 110)
        local topPos = camPos + Vector3.new(offsetX, 95, offsetZ)
        local groundY = 12
        local bottomPos = camPos + Vector3.new(offsetX + math.random(-15, 15), groundY, offsetZ + math.random(-15, 15))

        local boltModel = Instance.new("Model")
        boltModel.Name = "LightningBoltVisual"

        local numSegments = 6
        local currentPos = topPos
        for i = 1, numSegments do
            local frac = i / numSegments
            local nextPos = topPos:Lerp(bottomPos, frac)
            if i < numSegments then
                nextPos = nextPos + Vector3.new(math.random(-5, 5), math.random(-2, 2), math.random(-5, 5))
            end

            local segDist = (nextPos - currentPos).Magnitude
            local segPart = Instance.new("Part")
            segPart.Name = "BoltSegment"
            segPart.Material = Enum.Material.Neon
            segPart.Color = Color3.fromRGB(240, 250, 255)
            segPart.Transparency = 0.05
            segPart.Anchored = true
            segPart.CanCollide = false
            segPart.CanTouch = false
            segPart.CanQuery = false
            segPart.CastShadow = false
            segPart.Size = Vector3.new(0.5, 0.5, segDist)
            segPart.CFrame = CFrame.new((currentPos + nextPos) / 2, nextPos)
            segPart.Parent = boltModel

            currentPos = nextPos
        end
        boltModel.Parent = Workspace

        local origBrightness = Lighting.Brightness
        local origColorShift = Lighting.ColorShift_Top
        local origAmbient = Lighting.Ambient

        local isSpringStrike = (currentSeasonId == "spring")
        Lighting.Brightness = isSpringStrike and 2.7 or 4.6
        Lighting.ColorShift_Top = isSpringStrike and Color3.fromRGB(225, 238, 255) or Color3.fromRGB(255, 255, 255)
        Lighting.Ambient = isSpringStrike and Color3.fromRGB(150, 175, 210) or Color3.fromRGB(190, 205, 235)
        task.wait(0.08)

        Lighting.Brightness = isSpringStrike and 1.8 or 2.2
        task.wait(0.05)

        Lighting.Brightness = isSpringStrike and 2.3 or 3.8
        task.wait(0.06)

        boltModel:Destroy()

        local tw = TweenService:Create(Lighting, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Brightness = origBrightness,
            ColorShift_Top = origColorShift,
            Ambient = origAmbient
        })
        tw:Play()
        tw.Completed:Connect(function()
            isFlashingLightning = false
        end)
    end)
end

-- ============================================================
-- === НАЗЕМНЫЕ СЛЕДЫ ПОГОДЫ (ЛУЖИ, СНЕЖНЫЕ СУГРОБЫ, ЛИСТЬЯ) ===
-- ============================================================
local groundDecorFolder = Workspace:FindFirstChild("WeatherGroundDecor")
if not groundDecorFolder then
    groundDecorFolder = Instance.new("Folder")
    groundDecorFolder.Name = "WeatherGroundDecor"
    groundDecorFolder.Parent = Workspace
end

local groundPuddles = {}
local groundSnowCaps = {}
local groundLeafPatches = {}
local groundSpringFlowers = {}

local puddleWetness = 0
local snowCoverage = (currentSeasonId == "winter") and 1 or 0
local leavesCoverage = (currentSeasonId == "autumn") and 1 or 0
local flowersCoverage = (currentSeasonId == "spring") and 1 or 0

local lastProcessedDecorBlockCount = 0
local lastDecorRegenTick = 0

local function cellHash(x, z, seed)
    local h = bit32.bxor(x * 374761393, z * 668265263) + seed
    h = bit32.bxor(h, bit32.rshift(h, 13))
    h = (h * 1274126177) % 4294967296
    h = bit32.bxor(h, bit32.rshift(h, 16))
    return h
end

local function setupGroundWeatherDecor()
    local worldFolder = Workspace:FindFirstChild("VoxelWorld")
    if not worldFolder then return end

    local allChildren = worldFolder:GetChildren()
    if #allChildren < 30 then return end

    groundDecorFolder:ClearAllChildren()
    table.clear(groundPuddles)
    table.clear(groundSnowCaps)
    table.clear(groundLeafPatches)
    table.clear(groundSpringFlowers)

    local blockGrid = {}
    for _, block in ipairs(allChildren) do
        if block:IsA("BasePart") then
            local gx = math.floor((block.Position.X / BLOCK_SIZE) + 0.5)
            local gy = math.floor((block.Position.Y / BLOCK_SIZE) + 0.5)
            local gz = math.floor((block.Position.Z / BLOCK_SIZE) + 0.5)
            blockGrid[gx .. "_" .. gy .. "_" .. gz] = block
        end
    end

    local grassBlocks = {}
    for _, block in ipairs(allChildren) do
        if block:IsA("BasePart") and block:GetAttribute("BlockType") == "Grass" then
            local gx = math.floor((block.Position.X / BLOCK_SIZE) + 0.5)
            local gy = math.floor((block.Position.Y / BLOCK_SIZE) + 0.5)
            local gz = math.floor((block.Position.Z / BLOCK_SIZE) + 0.5)
            if not blockGrid[gx .. "_" .. (gy + 1) .. "_" .. gz] then
                table.insert(grassBlocks, block)
            end
        end
    end

    for _, block in ipairs(grassBlocks) do
        local topY = block.Position.Y + (block.Size.Y / 2)
        local isGroundLevel = (block.Position.Y <= 3.0)
        local gx = math.floor((block.Position.X / BLOCK_SIZE) + 0.5)
        local gz = math.floor((block.Position.Z / BLOCK_SIZE) + 0.5)

        -- РРЎРљР›Р®Р§Р•РќРР• Р—РћРќР« РџР РЈР”Рђ (X: 9..19, Z: -2..8): РІ РїСЂСѓРґСѓ РІРѕРґР°, С‚Р°Рј РЅРµС‚ С‚СЂР°РІС‹ Рё РЅРµ РґРѕР»Р¶РЅРѕ Р±С‹С‚СЊ РЅР°Р·РµРјРЅС‹С… Р»СѓР¶/Р»РёСЃС‚СЊРµРІ!
        local pondDist = math.sqrt(((block.Position.X - 14.0) / 6.2)^2 + ((block.Position.Z - 3.0) / 4.8)^2)
        if pondDist <= 1.08 then
            continue
        end

                local h_puddle = cellHash(gx, gz, 101)
        local h_flower = cellHash(gx, gz, 202)
        local h_leaf   = cellHash(gx, gz, 303)

        local n_puddle = math.noise(gx * 0.19 + 5.2, gz * 0.19 + 17.8, 11.4)
        local n_flower = math.noise(gx * 0.22 + 43.1, gz * 0.22 + 7.6, 88.2)
        local n_leaf   = math.noise(gx * 0.24 + 19.4, gz * 0.24 + 52.3, 144.7)

        -- 1. РЎРЅРµР¶РЅС‹Рµ С€Р°РїРєРё Р·РёРјРѕР№:
        local sH = 0.06
        local snowCap = Instance.new("Part")
        snowCap.Name = "SnowCap"
        snowCap.Size = Vector3.new(BLOCK_SIZE * 0.98, sH, BLOCK_SIZE * 0.98)
        snowCap.Position = Vector3.new(block.Position.X, topY + (sH / 2), block.Position.Z)
        snowCap.Color = Color3.fromRGB(246, 250, 255)
        snowCap.Material = Enum.Material.Sand
        snowCap.Anchored = true
        snowCap.CanCollide = false
        snowCap.CanTouch = false
        snowCap.CanQuery = false
        snowCap.CastShadow = false
        snowCap.Transparency = (currentSeasonId == "winter") and 0 or 1
        snowCap.Parent = groundDecorFolder
        table.insert(groundSnowCaps, snowCap)

        local hasPuddleOnBlock = false

        -- 2. Р’РµСЃРµРЅРЅРёРµ Рё РґРѕР¶РґРµРІС‹Рµ Р»СѓР¶Рё: РѕСЂРіР°РЅРёС‡РµСЃРєРёРµ РµСЃС‚РµСЃС‚РІРµРЅРЅС‹Рµ Р·РѕРЅС‹, Р±РµР· РїРѕР»РѕСЃ Рё РїРѕРІС‚РѕСЂРµРЅРёР№
        if isGroundLevel and (n_puddle > 0.05) and ((h_puddle % 100) < 60) then
            hasPuddleOnBlock = true
            local pSizeCat = (h_puddle % 10)
            local pRadX, pRadZ, pH
            if pSizeCat < 3 then
                -- РњРµР»РєРёРµ РєСЂСѓРіР»С‹Рµ Р±СЂС‹Р·РіРё/Р»СѓР¶РёС†С‹
                local r = 0.20 + ((h_puddle % 13) / 13) * 0.10
                pRadX = r
                pRadZ = r * (0.95 + ((h_puddle % 5) / 5) * 0.15)
                pH = 0.012
            elseif pSizeCat < 7 then
                -- РЎСЂРµРґРЅРёРµ Р»СѓР¶РёС†С‹ РµСЃС‚РµСЃС‚РІРµРЅРЅРѕР№ С„РѕСЂРјС‹
                local r = 0.40 + ((h_puddle % 17) / 17) * 0.18
                local aspect = 1.10 + ((h_puddle % 7) / 7) * 0.25
                pRadX = r
                pRadZ = r * aspect
                pH = 0.015
            else
                -- РљСЂСѓРїРЅС‹Рµ РІРµСЃРµРЅРЅРёРµ Р»СѓР¶Рё
                local r = 0.70 + ((h_puddle % 23) / 23) * 0.32
                local aspect = 1.15 + ((h_puddle % 9) / 9) * 0.35
                pRadX = r
                pRadZ = r * aspect
                pH = 0.018
            end

            local puddle = Instance.new("Part")
            puddle.Name = "Puddle"
            puddle.Size = Vector3.new(pRadX * 2, pH, pRadZ * 2)
            -- РЎРјРµС‰РµРЅРёРµ РїРѕР·РёС†РёРё РІРЅСѓС‚СЂРё РІРѕРєСЃРµР»СЏ: Р»СѓР¶Рё Р±РѕР»СЊС€Рµ РЅРёРєРѕРіРґР° РЅРµ РІС‹СЃС‚СЂР°РёРІР°СЋС‚СЃСЏ РІ СЂРµС€РµС‚РєСѓ
            local offsetX = (((h_puddle % 15) - 7) / 7) * 0.28
            local offsetZ = ((((h_puddle / 15) % 15) - 7) / 7) * 0.28
            puddle.Position = Vector3.new(
                block.Position.X + offsetX,
                topY + (pH / 2) + 0.002,
                block.Position.Z + offsetZ
            )
            puddle.Orientation = Vector3.new(0, (h_puddle % 360), 0)
            puddle.Color = Color3.fromRGB(115, 170, 225)
            puddle.Material = Enum.Material.Glass
            puddle.Reflectance = 0.48
            puddle.Anchored = true
            puddle.CanCollide = false
            puddle.CanTouch = false
            puddle.CanQuery = false
            puddle.CastShadow = false
            puddle.Transparency = 1
            puddle.Parent = groundDecorFolder

            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.Sphere
            mesh.Scale = Vector3.new(1, pH / math.max(pRadX * 2, pRadZ * 2), 1)
            mesh.Parent = puddle

            table.insert(groundPuddles, puddle)
        end

        -- 3. Р’РµСЃРµРЅРЅРёРµ РїРµСЂРІРѕС†РІРµС‚С‹: Р¶РёРІРѕРїРёСЃРЅС‹Рµ РїРѕР»СЏРЅС‹ (РЅРµ СЂР°СЃС‚СѓС‚ РІ Р»СѓР¶Р°С…)
        if isGroundLevel and (not hasPuddleOnBlock) and (n_flower > 0.04) and ((h_flower % 100) < 52) then
            local flower = Instance.new("Part")
            flower.Name = "SpringFlower"
            local fType = (h_flower % 3)
            local fColor
            if fType == 0 then
                fColor = Color3.fromRGB(255, 225, 45) -- Р¶РµР»С‚С‹Р№ РїРµСЂРІРѕС†РІРµС‚
            elseif fType == 1 then
                fColor = Color3.fromRGB(252, 255, 255) -- Р±РµР»Р°СЏ РІРµС‚СЂРµРЅРёС†Р°
            else
                fColor = Color3.fromRGB(165, 120, 245) -- РЅРµР¶РЅРѕ-СЃРёСЂРµРЅРµРІС‹Р№ С€Р°С„СЂР°РЅ
            end

            local fH = 0.08
            local fSize = 0.24 + ((h_flower % 11) / 11) * 0.09
            flower.Size = Vector3.new(fSize, fH, fSize)
            local fOffX = (((h_flower % 15) - 7) / 7) * 0.32
            local fOffZ = ((((h_flower / 15) % 15) - 7) / 7) * 0.32
            flower.Position = Vector3.new(
                block.Position.X + fOffX,
                topY + (fH / 2) + 0.002,
                block.Position.Z + fOffZ
            )
            flower.Color = fColor
            flower.Material = Enum.Material.SmoothPlastic
            flower.Anchored = true
            flower.CanCollide = false
            flower.CanTouch = false
            flower.CanQuery = false
            flower.CastShadow = false
            flower.Transparency = (currentSeasonId == "spring") and 0 or 1
            flower.Parent = groundDecorFolder

            local stem = Instance.new("Part")
            stem.Name = "Stem"
            stem.Size = Vector3.new(0.08, 0.04, 0.08)
            stem.Position = Vector3.new(flower.Position.X, topY + 0.02, flower.Position.Z)
            stem.Color = Color3.fromRGB(65, 145, 45)
            stem.Material = Enum.Material.SmoothPlastic
            stem.Anchored = true
            stem.CanCollide = false
            stem.CanTouch = false
            stem.CanQuery = false
            stem.CastShadow = false
            stem.Transparency = (currentSeasonId == "spring") and 0 or 1
            stem.Parent = flower

            table.insert(groundSpringFlowers, flower)
        end

        -- 4. РћСЃРµРЅРЅРёРµ Р»РёСЃС‚СЊСЏ: РµСЃС‚РµСЃС‚РІРµРЅРЅС‹Р№ Р»РёСЃС‚РѕРїР°Рґ Р±РµР· СЂСЏРґРѕРІ Рё РїРѕР»РѕСЃ
        if isGroundLevel and (not hasPuddleOnBlock) and (n_leaf > -0.05) and ((h_leaf % 100) < 45) then
            local lH = 0.012
            local leafColors = {
                Color3.fromRGB(225, 125, 20),
                Color3.fromRGB(195, 65, 15),
                Color3.fromRGB(240, 165, 25),
                Color3.fromRGB(165, 45, 10),
            }
            local leafPatch = Instance.new("Part")
            leafPatch.Name = "LeafPatch"
            local lW = 0.38 + ((h_leaf % 11) / 11) * 0.18
            local lL = 0.30 + ((h_leaf % 13) / 13) * 0.16
            local lOffX = (((h_leaf % 15) - 7) / 7) * 0.32
            local lOffZ = ((((h_leaf / 15) % 15) - 7) / 7) * 0.32
            leafPatch.Size = Vector3.new(lW, lH, lL)
            leafPatch.Position = Vector3.new(
                block.Position.X + lOffX,
                topY + (lH / 2) + 0.001,
                block.Position.Z + lOffZ
            )
            leafPatch.Orientation = Vector3.new(0, (h_leaf % 360), 0)
            leafPatch.Color = leafColors[(h_leaf % #leafColors) + 1]
            leafPatch.Material = Enum.Material.SmoothPlastic
            leafPatch.Anchored = true
            leafPatch.CanCollide = false
            leafPatch.CanTouch = false
            leafPatch.CanQuery = false
            leafPatch.CastShadow = false
            leafPatch.Transparency = (currentSeasonId == "autumn") and 0 or 1
            leafPatch.Parent = groundDecorFolder

            table.insert(groundLeafPatches, leafPatch)
        end
    end
end

local function updateGroundDecor(dt, isRaining)
    local wf = Workspace:FindFirstChild("VoxelWorld")
    local currentBlockCount = wf and #wf:GetChildren() or 0
    if currentBlockCount > 0 and (currentBlockCount ~= lastProcessedDecorBlockCount or #groundSnowCaps == 0) then
        if tick() - lastDecorRegenTick >= 1.0 or #groundSnowCaps == 0 then
            lastDecorRegenTick = tick()
            lastProcessedDecorBlockCount = currentBlockCount
            setupGroundWeatherDecor()
        end
    end

    -- 1. Р›СѓР¶Рё: РІРѕ РІСЂРµРјСЏ РґРѕР¶РґСЏ РёР»Рё РІРµСЃРЅРѕР№ РїСЂРё С‚Р°СЏРЅРёРё СЃРЅРµРіР° (РІРµСЃРЅРѕР№ РІСЃРµРіРґР° РµСЃС‚СЊ С‚Р°Р»Р°СЏ РІР»Р°РіР°!)
    local minWetness = (currentSeasonId == "spring") and 0.35 or 0.0
    if isRaining then
        puddleWetness = math.clamp(puddleWetness + dt / 6, 0, 1)
    else
        puddleWetness = math.clamp(puddleWetness - dt / 18, minWetness, 1)
    end

    local pTrans = 1 - (puddleWetness * 0.65)
    for _, puddle in ipairs(groundPuddles) do
        if puddle.Parent then
            puddle.Transparency = pTrans
        end
    end

    -- 2. РЎРЅРµР¶РЅС‹Рµ С€Р°РїРєРё: Р·РёРјРѕР№ СѓРєСЂС‹РІР°СЋС‚ (1), РІРµСЃРЅРѕР№ РїР»Р°РІРЅРѕ С‚Р°СЋС‚ (0)
    local targetSnow = (currentSeasonId == "winter") and 1 or 0
    if snowCoverage < targetSnow then
        snowCoverage = math.clamp(snowCoverage + dt / 4, 0, 1)
    elseif snowCoverage > targetSnow then
        snowCoverage = math.clamp(snowCoverage - dt / 4, 0, 1)
    end

    local sTrans = 1 - snowCoverage
    for _, snow in ipairs(groundSnowCaps) do
        if snow.Parent then
            snow.Transparency = sTrans
        end
    end

    -- 3. РћРїР°РІС€РёРµ Р»РёСЃС‚СЊСЏ: РѕСЃРµРЅСЊСЋ СѓРєСЂС‹РІР°СЋС‚ С‚СЂР°РІСѓ (1), РІРµСЃРЅРѕР№/Р·РёРјРѕР№ РёСЃС‡РµР·Р°СЋС‚ (0)
    local targetLeaves = (currentSeasonId == "autumn") and 1 or 0
    if leavesCoverage < targetLeaves then
        leavesCoverage = math.clamp(leavesCoverage + dt / 4, 0, 1)
    elseif leavesCoverage > targetLeaves then
        leavesCoverage = math.clamp(leavesCoverage - dt / 6, 0, 1)
    end

    local lTrans = 1 - leavesCoverage
    for _, leaf in ipairs(groundLeafPatches) do
        if leaf.Parent then
            leaf.Transparency = lTrans
        end
    end

    -- 4. Р’РµСЃРµРЅРЅРёРµ РїРµСЂРІРѕС†РІРµС‚С‹: РІРµСЃРЅРѕР№ СЂР°СЃРїСѓСЃРєР°СЋС‚СЃСЏ (1), РІ РґСЂСѓРіРёРµ СЃРµР·РѕРЅС‹ РёСЃС‡РµР·Р°СЋС‚ (0)
    local targetFlowers = (currentSeasonId == "spring") and 1 or 0
    if flowersCoverage < targetFlowers then
        flowersCoverage = math.clamp(flowersCoverage + dt / 3, 0, 1)
    elseif flowersCoverage > targetFlowers then
        flowersCoverage = math.clamp(flowersCoverage - dt / 4, 0, 1)
    end

    local flTrans = 1 - flowersCoverage
    for _, fl in ipairs(groundSpringFlowers) do
        if fl.Parent then
            fl.Transparency = flTrans
            local stem = fl:FindFirstChild("Stem")
            if stem then stem.Transparency = flTrans end
        end
    end
end

local function setSeason(seasonKey, notifyServer)
    local cfg = SEASON_CONFIGS[seasonKey]
    if not cfg then return end
    currentSeasonId = seasonKey

    -- 1. Синхронное обновление надписи времени года с плавной анимацией
    seasonLabel.Text = cfg.name
    seasonLabel.TextColor3 = cfg.accentColor or Color3.fromRGB(255, 220, 150)
    local popTween = TweenService:Create(seasonLabel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        TextSize = 17,
        TextColor3 = Color3.fromRGB(255, 255, 255)
    })
    popTween:Play()
    popTween.Completed:Connect(function()
        TweenService:Create(seasonLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            TextSize = 15,
            TextColor3 = Color3.fromRGB(240, 235, 220)
        }):Play()
    end)

    -- 2. Всплывающее уведомление о смене времени года
    showPickupNotification(string.format("%s Время года: %s", cfg.icon or "🌿", cfg.name), 0)

    -- 3. Атмосферное освещение и туман
    if cfg.fogColor then
        Lighting.FogColor = cfg.fogColor
    end
    if cfg.fogEnd then
        Lighting.FogEnd = cfg.fogEnd
    end

    -- 4. Подсветка кнопок в окне настроек
    for sKey, btnData in pairs(seasonButtonsUI) do
        if sKey == currentSeasonId then
            btnData.stroke.Color = Color3.fromRGB(255, 215, 100)
            btnData.stroke.Thickness = 2
            btnData.button.BackgroundColor3 = Color3.fromRGB(75, 58, 42)
            btnData.button.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btnData.stroke.Color = Color3.fromRGB(85, 65, 48)
            btnData.stroke.Thickness = 1
            btnData.button.BackgroundColor3 = Color3.fromRGB(48, 38, 30)
            btnData.button.TextColor3 = Color3.fromRGB(220, 210, 195)
        end
    end

    nextLightningTime = tick() + math.random(5, 12)

    if notifyServer then
        voxelRemote:FireServer("SetSeason", { season = seasonKey })
    end
end

local function updateDayNightAndWeather(dt)
    -- Продвижение времени: 1 игровые сутки (24ч) = 120 секунд (2 минуты реального времени)
    local oldTime = inGameTime
    inGameTime = (inGameTime + dt * (24 / DAY_CYCLE_SECONDS)) % 24

    -- Каждые 1 внутриигровые сутки: переход к следующему времени года строго Осень -> Зима -> Весна -> Лето -> Осень...
    if inGameTime < oldTime and oldTime >= 23.0 and inGameTime < 2.0 then
        local nextSeason = "autumn"
        for i, s in ipairs(SEASON_ORDER) do
            if s == currentSeasonId then
                nextSeason = SEASON_ORDER[(i % #SEASON_ORDER) + 1]
                break
            end
        end
        setSeason(nextSeason, true)
    end

    -- Вращение только черной часовой и минутной стрелок (секундная убрана)
    hourPivot.Rotation = ((inGameTime % 12) / 12) * 360
    minutePivot.Rotation = (inGameTime % 1) * 360

    local cfg = SEASON_CONFIGS[currentSeasonId] or SEASON_CONFIGS.autumn

    -- Реалистичная температура: пик холода рано утром (04:30), пик тепла днем (14:30)
    local tAngle = (inGameTime - 4.5) / 24 * (math.pi * 2)
    local heatFactor = (1 - math.cos(tAngle)) / 2
    local curTemp
    if currentSeasonId == "spring" and inGameTime >= 5.0 and inGameTime < 7.0 then
        curTemp = 4
    else
        curTemp = math.floor(cfg.tempNight + (cfg.tempDay - cfg.tempNight) * heatFactor + 0.5)
    end
    local tempStr
    if curTemp > 0 then
        tempStr = "+" .. curTemp
    elseif curTemp < 0 then
        tempStr = "- " .. math.abs(curTemp)
    else
        tempStr = "0"
    end
    tempLabel.Text = tempStr .. " \u{00b0}C"

    -- Плавное освещение:
    -- Светлеет строго в 5 утра (рассвет 05:00 - 06:30)
        -- РџР»Р°РІРЅРѕРµ РѕСЃРІРµС‰РµРЅРёРµ:
    -- РЎРІРµС‚Р»РµРµС‚ РЎРўР РћР“Рћ СЃ 05:00 СѓС‚СЂР° (СЂР°СЃСЃРІРµС‚ 05:00 - 05:45).
    -- РџРѕР»РЅС‹Р№ СЏСЃРЅС‹Р№ СЃРІРµС‚Р»С‹Р№ РґРµРЅСЊ РїСЂРѕРґРѕР»Р¶Р°РµС‚СЃСЏ Р’РЎР• Р’Р Р•РњРЇ РґРѕ 23:00 (11 РІРµС‡РµСЂР°)!
    -- РўРµРјРЅРµС‚СЊ РЅР°С‡РёРЅР°РµС‚ РЎРўР РћР“Рћ СЃ 23:00 РІРµС‡РµСЂР° (Р·Р°РєР°С‚ 23:00 - 23:45).
    -- РЎ 23:45 РґРѕ 05:00 - С‚РµРјРЅР°СЏ РЅРѕС‡СЊ.

    Lighting.ClockTime = inGameTime

    -- РџР»Р°РІРЅРѕРµ СЃРѕР»РЅРµС‡РЅРѕРµ Рё Р»СѓРЅРЅРѕРµ РѕСЃРІРµС‰РµРЅРёРµ РїРѕР»СЏРЅС‹:
    -- Р”РµРЅСЊ (06:30 - 17:30): СЏСЂРєРѕРµ С‚РµРїР»РѕРµ СЃРѕР»РЅС†Рµ РѕСЃРІРµС‰Р°РµС‚ РїРѕР»СЏРЅСѓ
    -- Р—Р°РєР°С‚ (17:30 - 19:30): СЃРѕР»РЅС†Рµ СЃР°РґРёС‚СЃСЏ, Р·Р°РєР°С‚РЅС‹Рµ Р·РѕР»РѕС‚РёСЃС‚Рѕ-РѕСЂР°РЅР¶РµРІС‹Рµ Р»СѓС‡Рё
    -- РќРѕС‡СЊ (19:30 - 05:00): Р»СѓРЅР° РЅР° РЅРµР±Рµ РјСЏРіРєРѕ РѕСЃРІРµС‰Р°РµС‚ РїРѕР»СЏРЅСѓ СЃРµСЂРµР±СЂРёСЃС‚Рѕ-РіРѕР»СѓР±С‹Рј СЃРІРµС‚РѕРј
    -- Р Р°СЃСЃРІРµС‚ (05:00 - 06:30): Р»СѓРЅР° Р·Р°С…РѕРґРёС‚, РІРѕСЃС…РѕРґРёС‚ СѓС‚СЂРµРЅРЅРµРµ Р·РѕР»РѕС‚РѕРµ СЃРѕР»РЅС†Рµ

    local moonColorShift = Color3.fromRGB(145, 180, 240)
    local moonAmbient = cfg.ambientNight
    local moonOutdoorAmbient = Color3.fromRGB(65, 80, 115)
    local moonBrightness = cfg.brightnessNight

    local sunColorShift = cfg.colorShiftTop
    local sunAmbient = Color3.fromRGB(85, 90, 100)
    local sunOutdoorAmbient = cfg.ambientDay
    local sunBrightness = cfg.brightnessDay

    if inGameTime >= 5.0 and inGameTime < 6.5 then
        -- Р Р°СЃСЃРІРµС‚ (05:00 - 06:30): РїРµСЂРµС…РѕРґ РѕС‚ Р»СѓРЅС‹ Рє РІРѕСЃС…РѕРґСЏС‰РµРјСѓ СЃРѕР»РЅС†Сѓ
        local a = (inGameTime - 5.0) / 1.5
        local dawnTint = Color3.fromRGB(255, 185, 115)
        Lighting.Brightness = moonBrightness + (sunBrightness - moonBrightness) * a
        Lighting.OutdoorAmbient = moonOutdoorAmbient:Lerp(sunOutdoorAmbient, a)
        Lighting.Ambient = moonAmbient:Lerp(sunAmbient, a)
        local colorBlend = moonColorShift:Lerp(sunColorShift, a)
        Lighting.ColorShift_Top = colorBlend:Lerp(dawnTint, math.sin(a * math.pi) * 0.7)
    elseif inGameTime >= 6.5 and inGameTime < 17.5 then
        -- РџРѕР»РЅС‹Р№ РґРµРЅСЊ (06:30 - 17:30): РїРѕР»СЏРЅР° СЏСЂРєРѕ Р·Р°Р»РёС‚Р° СЃРѕР»РЅРµС‡РЅС‹Рј СЃРІРµС‚РѕРј
        Lighting.Brightness = sunBrightness
        Lighting.OutdoorAmbient = sunOutdoorAmbient
        Lighting.Ambient = sunAmbient
        Lighting.ColorShift_Top = sunColorShift
    elseif inGameTime >= 17.5 and inGameTime < 19.5 then
        -- Р—Р°РєР°С‚ (17:30 - 19:30): Р·Р°С…РѕРґ СЃРѕР»РЅС†Р°, РјСЏРіРєРёР№ С‚РµРїР»С‹Р№ СЃРІРµС‚
        local a = (inGameTime - 17.5) / 2.0
        local duskTint = Color3.fromRGB(255, 140, 70)
        Lighting.Brightness = sunBrightness + (moonBrightness - sunBrightness) * a
        Lighting.OutdoorAmbient = sunOutdoorAmbient:Lerp(moonOutdoorAmbient, a)
        Lighting.Ambient = sunAmbient:Lerp(moonAmbient, a)
        local colorBlend = sunColorShift:Lerp(moonColorShift, a)
        Lighting.ColorShift_Top = colorBlend:Lerp(duskTint, math.sin(a * math.pi) * 0.8)
    else
        -- РќРѕС‡СЊ (19:30 - 05:00): РїРѕР»СЏРЅР° РјСЏРіРєРѕ РѕСЃРІРµС‰Р°РµС‚СЃСЏ СЃРµСЂРµР±СЂРёСЃС‚Рѕ-РіРѕР»СѓР±РѕР№ Р»СѓРЅРѕР№
        Lighting.Brightness = moonBrightness
        Lighting.OutdoorAmbient = moonOutdoorAmbient
        Lighting.Ambient = moonAmbient
        Lighting.ColorShift_Top = moonColorShift
    end

    local cam = Workspace.CurrentCamera
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local focusPos = root and root.Position or Vector3.new(0, 1, 0)

    if weatherAnchor then
        if cam then
            local camPos = cam.CFrame.Position
            -- РЎРјРµС€РёРІР°РµРј РїРѕР·РёС†РёСЋ: 65% С„РѕРєСѓСЃ РЅР° РїРµСЂСЃРѕРЅР°Р¶Рµ/РїРѕР»СЏРЅРµ, 35% РїРѕР·РёС†РёСЏ РєР°РјРµСЂС‹.
            -- Р­С‚Рѕ РіР°СЂР°РЅС‚РёСЂСѓРµС‚ 100% РѕР±СЉРµРјРЅРѕРµ РїРѕРєСЂС‹С‚РёРµ РІСЃРµР№ РїРѕР»СЏРЅС‹ Рё РІРёРґРёРјРѕР№ РѕР±Р»Р°СЃС‚Рё СЌРєСЂР°РЅР° РїСЂРё Р»СЋР±РѕРј Р·СѓРјРµ (РѕС‚ 18 РґРѕ 140 СЃС‚Р°РґСЃРѕРІ)
            local midX = (focusPos.X * 0.65) + (camPos.X * 0.35)
            local midZ = (focusPos.Z * 0.65) + (camPos.Z * 0.35)
            weatherAnchor.CFrame = CFrame.new(midX, 36, midZ)
        else
            weatherAnchor.CFrame = CFrame.new(focusPos.X, 36, focusPos.Z)
        end
    end

    if firefliesAnchor then
        firefliesAnchor.CFrame = CFrame.new(focusPos.X, 2.0, focusPos.Z)
    end

    -- Актуализация погодных явлений под текущее время года и время суток
    local isAutumn = (currentSeasonId == "autumn")
    local isWinter = (currentSeasonId == "winter")
    local isSpring = (currentSeasonId == "spring")
    local isSummer = (currentSeasonId == "summer")

    -- 1. Летящие листья: осенью
    leavesEmitter.Enabled = isAutumn

    -- 2. Ветер: осенью постоянно, зимой в бурю (12-18), весной днем (10-18), летом при грозе (14-17)
    windEmitter.Enabled = isAutumn
        or (isWinter and inGameTime >= 12 and inGameTime < 18)
        or (isSpring and inGameTime >= 10 and inGameTime < 18)
        or (isSummer and inGameTime >= 14 and inGameTime < 17)

    -- 3. Дождь: осенью днем/вечером (13-19), весной днем (12-17), летом при грозе (14-17)
    local isRaining = (isAutumn and inGameTime >= 13 and inGameTime < 19)
        or (isSpring and inGameTime >= 12 and inGameTime < 17)
        or (isSummer and inGameTime >= 14 and inGameTime < 17)
    rainEmitter.Enabled = isRaining

    -- 4. Пушистый снег: зимой
    snowEmitter.Enabled = isWinter

    -- 5. Ледяной град: зимой в пик бури (13-17)
    hailEmitter.Enabled = (isWinter and inGameTime >= 13 and inGameTime < 17)

    -- 6. Лепестки цветов: весной
    petalsEmitter.Enabled = isSpring

    -- 7. Ночные светлячки: теплой летней ночью (22:00 - 05:00)
    firefliesEmitter.Enabled = (isSummer and (inGameTime >= 22 or inGameTime < 5))

    -- Р‘Р°Р±РѕС‡РєРё Рё С€РјРµР»Рё: РІРµСЃРЅРѕР№ РІ СЃРѕР»РЅРµС‡РЅС‹Рµ РґРЅРµРІРЅС‹Рµ С‡Р°СЃС‹ (11:00 - 17:00) РїСЂРё СЏСЃРЅРѕР№ РїРѕРіРѕРґРµ
    local isSpringButterflyHours = isSpring and (inGameTime >= 11.0 and inGameTime <= 17.0) and (not isRaining)
    butterfliesEmitter.Enabled = isSpringButterflyHours
    bumblebeesEmitter.Enabled = isSpringButterflyHours

    -- 8. Гроза с молниями: весной (13-16) и летом (14-17)
    -- 8. Thunderstorm with lightning: spring (13:00 - 16:30) and summer (14:00 - 17:00)
    local isSpringStorming = isSpring and (inGameTime >= 13 and inGameTime < 16.5)
    local isSummerStorming = isSummer and (inGameTime >= 14 and inGameTime < 17)
    local isStorming = isSpringStorming or isSummerStorming

    if isStorming and tick() >= nextLightningTime then
        -- Spring thunder rumbles are rare and distant (22-38s interval)
        nextLightningTime = tick() + (isSpring and math.random(22, 38) or math.random(11, 20))
        triggerLightningStrike()
    end

    -- 9. Spring rainbow in sky after rain stops (17:00 - 19:00):
    local isSpringRainbowTime = isSpring and (inGameTime >= 17.0 and inGameTime < 19.0)
    local targetRainbowAlpha = 0
    if isSpringRainbowTime then
        if inGameTime < 17.4 then
            targetRainbowAlpha = (inGameTime - 17.0) / 0.4
        elseif inGameTime <= 18.5 then
            targetRainbowAlpha = 1.0
        else
            targetRainbowAlpha = (19.0 - inGameTime) / 0.5
        end
    end

    currentRainbowAlpha = currentRainbowAlpha + (targetRainbowAlpha - currentRainbowAlpha) * math.clamp(dt * 2.5, 0, 1)

    if currentRainbowAlpha > 0.01 then
        rainbowBeam.Enabled = true
        local midTrans = 0.42 + (1 - currentRainbowAlpha) * 0.58
        rainbowBeam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 1.0),
            NumberSequenceKeypoint.new(0.12, midTrans),
            NumberSequenceKeypoint.new(0.88, midTrans),
            NumberSequenceKeypoint.new(1.0, 1.0)
        })
    else
        rainbowBeam.Enabled = false
    end

    -- 10. Morning spring fog at dawn (05:00 - 07:00) (+4 В°C):
    local isSpringMorning = isSpring and (inGameTime >= 4.8 and inGameTime < 7.2)
    local targetFogAlpha = 0
    if isSpringMorning then
        if inGameTime < 5.3 then
            targetFogAlpha = (inGameTime - 4.8) / 0.5
        elseif inGameTime <= 6.5 then
            targetFogAlpha = 1.0
        else
            targetFogAlpha = (7.2 - inGameTime) / 0.7
        end
    end

    springFogAlpha = springFogAlpha + (targetFogAlpha - springFogAlpha) * math.clamp(dt * 2.5, 0, 1)

    if springFogAlpha > 0.01 then
        Lighting.FogStart = math.clamp(120 - (105 * springFogAlpha), 15, 120)
        Lighting.FogEnd = math.clamp(380 - (295 * springFogAlpha), 85, 380)
        Lighting.FogColor = cfg.fogColor:Lerp(Color3.fromRGB(205, 224, 238), springFogAlpha)
        if groundFogEmitter then groundFogEmitter.Enabled = (springFogAlpha > 0.15) end
    else
        Lighting.FogStart = 0
        Lighting.FogEnd = cfg.fogEnd
        Lighting.FogColor = cfg.fogColor
        if groundFogEmitter then groundFogEmitter.Enabled = false end
    end

    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmo then
        if springFogAlpha > 0.01 then
            atmo.Density = 0.30 + (0.16 * springFogAlpha)
            atmo.Haze = 2.6 * springFogAlpha
            atmo.Color = Color3.fromRGB(200, 200, 200):Lerp(Color3.fromRGB(210, 228, 245), springFogAlpha)
        else
            atmo.Density = 0.30
            atmo.Haze = 0.0
            atmo.Color = Color3.fromRGB(200, 200, 200)
        end
    end

    -- 11. Ground decor update
    updateGroundDecor(dt, isRaining)
end



-- 2. МОДАЛЬНОЕ ОКНО РЮКЗАКА (Интерактивная лесная поляна)
-- Активный таб: "backpack" (Ресурсы), "basket" (Еда и сбор), "toolbag" (Инструменты)
local activeBagTab = "backpack"

local modalBackdrop = Instance.new("TextButton")
modalBackdrop.Name = "BackpackBackdrop"
modalBackdrop.Size = UDim2.new(1, 0, 1, 0)
modalBackdrop.Position = UDim2.new(0, 0, 0, 0)
modalBackdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
modalBackdrop.BackgroundTransparency = 0.5
modalBackdrop.AutoButtonColor = false
modalBackdrop.Text = ""
modalBackdrop.Visible = false
modalBackdrop.ZIndex = 20
modalBackdrop.Parent = screenGui

local backpackModal = Instance.new("Frame")
backpackModal.Name = "BackpackModal"
backpackModal.Size = UDim2.new(0.95, 0, 0.95, 0)
backpackModal.Position = UDim2.new(0.5, 0, 0.5, 0)
backpackModal.AnchorPoint = Vector2.new(0.5, 0.5)
backpackModal.BackgroundTransparency = 1
backpackModal.Active = true
backpackModal.Visible = false
backpackModal.ZIndex = 21
backpackModal.Parent = modalBackdrop

-- Сохранение пропорций иллюстрации высокого разрешения (1376 x 768)
local aspectConstraint = Instance.new("UIAspectRatioConstraint")
aspectConstraint.AspectRatio = 1376 / 768
aspectConstraint.AspectType = Enum.AspectType.FitWithinMaxSize
aspectConstraint.DominantAxis = Enum.DominantAxis.Width
aspectConstraint.Parent = backpackModal

-- Фоновый арт лесной поляны с сумками и предметами (High-Definition Lossless PNG)
local modalBgImage = Instance.new("ImageLabel")
modalBgImage.Name = "BackpackBackgroundArt"
modalBgImage.Size = UDim2.new(1, 0, 1, 0)
modalBgImage.Position = UDim2.new(0, 0, 0, 0)
modalBgImage.BackgroundTransparency = 1
modalBgImage.Image = "rbxassetid://107996494359842"
modalBgImage.ScaleType = Enum.ScaleType.Fit
modalBgImage.ZIndex = 21
modalBgImage.Parent = backpackModal

local modalBgCorner = Instance.new("UICorner")
modalBgCorner.CornerRadius = UDim.new(0, 14)
modalBgCorner.Parent = modalBgImage

-- Всплывающая подсказка при наведении на интерактивные объекты
local hoverTooltip = Instance.new("TextLabel")
hoverTooltip.Name = "HoverTooltip"
hoverTooltip.Size = UDim2.new(0, 220, 0, 26)
hoverTooltip.Position = UDim2.new(0.5, -110, 0, 8)
hoverTooltip.BackgroundColor3 = Color3.fromRGB(24, 18, 14)
hoverTooltip.BackgroundTransparency = 0.2
hoverTooltip.TextColor3 = Color3.fromRGB(255, 235, 140)
hoverTooltip.Font = Enum.Font.FredokaOne
hoverTooltip.TextSize = 12
hoverTooltip.Text = ""
hoverTooltip.Visible = false
hoverTooltip.ZIndex = 40
hoverTooltip.Parent = backpackModal

local tooltipCorner = Instance.new("UICorner")
tooltipCorner.CornerRadius = UDim.new(0, 6)
tooltipCorner.Parent = hoverTooltip

local tooltipStroke = Instance.new("UIStroke")
tooltipStroke.Color = Color3.fromRGB(120, 90, 50)
tooltipStroke.Thickness = 1.5
tooltipStroke.Parent = hoverTooltip

local function showTooltip(text)
    hoverTooltip.Text = text
    hoverTooltip.Visible = true
end

local function hideTooltip()
    hoverTooltip.Visible = false
end

-- === АКТИВНЫЕ ОБЪЕКТЫ НАВЕРХУ И ВНИЗУ ===

-- Ассеты сплошной мягкой подсветки сумок по форме изгибов (без просветов и дыр внутри, плавный контур)
local BAG_OUTLINE_ASSETS = {
    backpack = "rbxassetid://96185584410898",
    toolbag = "rbxassetid://118946129070577",
    basket = "rbxassetid://120085443174964"
}

-- Индикатор активной выбранной сумки (светящийся контур точно повторяет форму активного объекта)
local activeBagOutline = Instance.new("ImageLabel")
activeBagOutline.Name = "ActiveBagOutline"
activeBagOutline.Size = UDim2.new(1, 0, 1, 0)
activeBagOutline.Position = UDim2.new(0, 0, 0, 0)
activeBagOutline.BackgroundTransparency = 1
activeBagOutline.Image = BAG_OUTLINE_ASSETS.backpack
activeBagOutline.ScaleType = Enum.ScaleType.Fit
activeBagOutline.ZIndex = 22
activeBagOutline.Parent = backpackModal

-- Контур предпросмотра при наведении курсора мыши на сумку
local hoverBagOutline = Instance.new("ImageLabel")
hoverBagOutline.Name = "HoverBagOutline"
hoverBagOutline.Size = UDim2.new(1, 0, 1, 0)
hoverBagOutline.Position = UDim2.new(0, 0, 0, 0)
hoverBagOutline.BackgroundTransparency = 1
hoverBagOutline.Image = ""
hoverBagOutline.ImageTransparency = 0.40
hoverBagOutline.ScaleType = Enum.ScaleType.Fit
hoverBagOutline.Visible = false
hoverBagOutline.ZIndex = 23
hoverBagOutline.Parent = backpackModal

-- 1. БЛОКНОТ (Книга рецептов и заданий)
local notebookBtn = Instance.new("TextButton")
notebookBtn.Name = "NotebookBtn"
notebookBtn.Size = UDim2.new(0.078, 0, 0.147, 0)
notebookBtn.Position = UDim2.new(0.225, 0, 0.157, 0)
notebookBtn.AnchorPoint = Vector2.new(0.5, 0.5)
notebookBtn.BackgroundTransparency = 1
notebookBtn.Text = ""
notebookBtn.ZIndex = 30
notebookBtn.Parent = backpackModal

-- 2. ПОРТФЕЛЬ / РЮКЗАК (Ресурсы и блоки)
local backpackTabBtn = Instance.new("TextButton")
backpackTabBtn.Name = "BackpackTabBtn"
backpackTabBtn.Size = UDim2.new(0.176, 0, 0.210, 0)
backpackTabBtn.Position = UDim2.new(0.354, 0, 0.138, 0)
backpackTabBtn.AnchorPoint = Vector2.new(0.5, 0.5)
backpackTabBtn.BackgroundTransparency = 1
backpackTabBtn.Text = ""
backpackTabBtn.ZIndex = 30
backpackTabBtn.Parent = backpackModal

-- 3. СУМКА С ИНСТРУМЕНТАМИ (Топор, кирка, лопата)
local toolbagTabBtn = Instance.new("TextButton")
toolbagTabBtn.Name = "ToolbagTabBtn"
toolbagTabBtn.Size = UDim2.new(0.176, 0, 0.215, 0)
toolbagTabBtn.Position = UDim2.new(0.534, 0, 0.143, 0)
toolbagTabBtn.AnchorPoint = Vector2.new(0.5, 0.5)
toolbagTabBtn.BackgroundTransparency = 1
toolbagTabBtn.Text = ""
toolbagTabBtn.ZIndex = 30
toolbagTabBtn.Parent = backpackModal

-- 4. КОРЗИНКА (Еда, ягоды, грибы, припасы)
local basketTabBtn = Instance.new("TextButton")
basketTabBtn.Name = "BasketTabBtn"
basketTabBtn.Size = UDim2.new(0.110, 0, 0.205, 0)
basketTabBtn.Position = UDim2.new(0.684, 0, 0.145, 0)
basketTabBtn.AnchorPoint = Vector2.new(0.5, 0.5)
basketTabBtn.BackgroundTransparency = 1
basketTabBtn.Text = ""
basketTabBtn.ZIndex = 30
basketTabBtn.Parent = backpackModal

-- 5. КАРТА (Остров котёнка)
local mapBtn = Instance.new("TextButton")
mapBtn.Name = "MapBtn"
mapBtn.Size = UDim2.new(0.166, 0, 0.210, 0)
mapBtn.Position = UDim2.new(0.820, 0, 0.154, 0)
mapBtn.AnchorPoint = Vector2.new(0.5, 0.5)
mapBtn.BackgroundTransparency = 1
mapBtn.Text = ""
mapBtn.ZIndex = 30
mapBtn.Parent = backpackModal

-- 6. КРЕСТИК ЗАКРЫТИЯ [X]
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0.029, 0, 0.046, 0)
closeBtn.Position = UDim2.new(0.976, 0, 0.059, 0)
closeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = ""
closeBtn.ZIndex = 35
closeBtn.Parent = backpackModal

closeBtn.MouseEnter:Connect(function()
    showTooltip("Закрыть [Esc]")
end)
closeBtn.MouseLeave:Connect(function()
    hideTooltip()
end)

-- 7. ШЕСТЕРЕНКА (Настройки игры)
local gearBtn = Instance.new("TextButton")
gearBtn.Name = "GearSettingsBtn"
gearBtn.Size = UDim2.new(0.093, 0, 0.166, 0)
gearBtn.Position = UDim2.new(0.862, 0, 0.816, 0)
gearBtn.AnchorPoint = Vector2.new(0.5, 0.5)
gearBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
gearBtn.BackgroundTransparency = 1
gearBtn.Text = ""
gearBtn.ZIndex = 30
gearBtn.Parent = backpackModal

local gearCorner = Instance.new("UICorner")
gearCorner.CornerRadius = UDim.new(1, 0)
gearCorner.Parent = gearBtn

gearBtn.MouseEnter:Connect(function()
    showTooltip("⚙️ Настройки игры")
end)
gearBtn.MouseLeave:Connect(function()
    hideTooltip()
end)

-- 8. КНОПКА СОРТИРОВКИ [Сортировать] НА ТАБЛИЧКЕ
local sortBtn = Instance.new("TextButton")
sortBtn.Name = "SortBtn"
sortBtn.Size = UDim2.new(0.115, 0, 0.044, 0)
sortBtn.Position = UDim2.new(0.36, 0, 0.850, 0)
sortBtn.AnchorPoint = Vector2.new(0, 0)
sortBtn.BackgroundTransparency = 0.1
sortBtn.BackgroundColor3 = Color3.fromRGB(42, 90, 70)
sortBtn.Text = "Сортировать"
sortBtn.TextColor3 = Color3.fromRGB(240, 255, 235)
sortBtn.Font = Enum.Font.FredokaOne
sortBtn.TextSize = 12
sortBtn.ZIndex = 30
sortBtn.Parent = backpackModal

local sortCorner = Instance.new("UICorner")
sortCorner.CornerRadius = UDim.new(0, 6)
sortCorner.Parent = sortBtn

local sortStroke = Instance.new("UIStroke")
sortStroke.Color = Color3.fromRGB(120, 240, 200)
sortStroke.Thickness = 1.2
sortStroke.Transparency = 0.5
sortStroke.Parent = sortBtn

sortBtn.MouseEnter:Connect(function()
    sortStroke.Transparency = 0.1
    sortBtn.BackgroundColor3 = Color3.fromRGB(55, 115, 90)
    showTooltip("Сортировать предметы в сумке")
end)
sortBtn.MouseLeave:Connect(function()
    sortStroke.Transparency = 0.5
    sortBtn.BackgroundColor3 = Color3.fromRGB(42, 90, 70)
    hideTooltip()
end)

-- Динамический заголовок на нижней табличке
local bagTitleBadge = Instance.new("TextLabel")
bagTitleBadge.Name = "BagTitleBadge"
bagTitleBadge.Size = UDim2.new(0.28, 0, 0.04, 0)
bagTitleBadge.Position = UDim2.new(0.36, 0, 0.755, 0)
bagTitleBadge.BackgroundTransparency = 1
bagTitleBadge.TextColor3 = Color3.fromRGB(255, 235, 140)
bagTitleBadge.TextStrokeTransparency = 0.35
bagTitleBadge.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
bagTitleBadge.Font = Enum.Font.FredokaOne
bagTitleBadge.TextSize = 14
bagTitleBadge.TextXAlignment = Enum.TextXAlignment.Left
bagTitleBadge.Text = "🎒 Портфель: Ресурсы и блоки"
bagTitleBadge.ZIndex = 28
bagTitleBadge.Parent = backpackModal

-- Подсказка управления под табличкой
local swapTip = Instance.new("TextLabel")
swapTip.Name = "SwapTip"
swapTip.Size = UDim2.new(0.30, 0, 0.035, 0)
swapTip.Position = UDim2.new(0.36, 0, 0.800, 0)
swapTip.BackgroundTransparency = 1
swapTip.TextColor3 = Color3.fromRGB(230, 210, 175)
swapTip.TextStrokeTransparency = 0.45
swapTip.TextStrokeColor3 = Color3.fromRGB(30, 20, 10)
swapTip.Font = Enum.Font.FredokaOne
swapTip.TextSize = 11
swapTip.TextXAlignment = Enum.TextXAlignment.Left
swapTip.Text = "💡 Кликните предмет для выбора, затем слот хотбара или другой"
swapTip.ZIndex = 28
swapTip.Parent = backpackModal

-- === ПРЕДМЕТЫ НА ТРАВЕ (БЕЗ РАМОК И ПОДЛОЖЕК!) ===
-- 20 интерактивных слотов на поляне (5 колонок х 4 ряда)
local grassSlotsContainer = Instance.new("Frame")
grassSlotsContainer.Name = "GrassSlotsContainer"
grassSlotsContainer.Size = UDim2.new(0.86, 0, 0.48, 0)
grassSlotsContainer.Position = UDim2.new(0.5, 0, 0.49, 0)
grassSlotsContainer.AnchorPoint = Vector2.new(0.5, 0.5)
grassSlotsContainer.BackgroundTransparency = 1
grassSlotsContainer.ZIndex = 25
grassSlotsContainer.Parent = backpackModal

local hotbarButtons = {}
local grassSlotButtons = {} -- [1..20] кнопки слотов на траве

-- Создание кнопки слота БЕЗ РАМКИ И ПОДЛОЖКИ (только иконка, имя и количество)
local function createGrassSlotUI(parent, localIndex, pos)
    local btn = Instance.new("TextButton")
    btn.Name = "GrassSlot_" .. localIndex
    btn.Size = UDim2.new(0.175, 0, 0.22, 0)
    btn.Position = pos
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    btn.BackgroundTransparency = 1 -- НЕТ ПОДЛОЖКИ!
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.ZIndex = 26
    btn.Parent = parent

    -- Мягкая круглая подсветка строго под иконкой (без жёлтых рамок)
    local halo = Instance.new("Frame")
    halo.Name = "Halo"
    halo.Size = UDim2.new(0, 48, 0, 48)
    halo.Position = UDim2.new(0.40, 0, 0.38, 0)
    halo.AnchorPoint = Vector2.new(0.5, 0.5)
    halo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    halo.BackgroundTransparency = 1
    halo.ZIndex = 26
    halo.Parent = btn

    local haloCorner = Instance.new("UICorner")
    haloCorner.CornerRadius = UDim.new(1, 0)
    haloCorner.Parent = halo

    -- Пиксель-арт спрайт предмета (стилистика пиксельных ячеек)
    local itemSprite = Instance.new("ImageLabel")
    itemSprite.Name = "ItemSprite"
    itemSprite.Size = UDim2.new(0, 44, 0, 44)
    itemSprite.Position = UDim2.new(0.40, 0, 0.38, 0)
    itemSprite.AnchorPoint = Vector2.new(0.5, 0.5)
    itemSprite.BackgroundTransparency = 1
    itemSprite.ResampleMode = Enum.ResamplerMode.Pixelated
    itemSprite.ScaleType = Enum.ScaleType.Fit
    itemSprite.Visible = false
    itemSprite.ZIndex = 27
    itemSprite.Parent = btn

    -- Иконка/эмодзи предмета (запасной вариант)
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "IconLabel"
    iconLabel.Size = UDim2.new(0, 36, 0, 32)
    iconLabel.Position = UDim2.new(0.40, 0, 0.38, 0)
    iconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Font = Enum.Font.FredokaOne
    iconLabel.TextSize = 24
    iconLabel.Text = ""
    iconLabel.ZIndex = 27
    iconLabel.Parent = btn

    -- Мини-кубик цвета (если нет эмодзи)
    local colorBox = Instance.new("Frame")
    colorBox.Name = "ColorBox"
    colorBox.Size = UDim2.new(0, 24, 0, 24)
    colorBox.Position = UDim2.new(0.40, 0, 0.38, 0)
    colorBox.AnchorPoint = Vector2.new(0.5, 0.5)
    colorBox.BorderSizePixel = 0
    colorBox.Visible = false
    colorBox.ZIndex = 27
    colorBox.Parent = btn

    local colorCorner = Instance.new("UICorner")
    colorCorner.CornerRadius = UDim.new(0, 6)
    colorCorner.Parent = colorBox

    -- Название предмета (под иконкой) с чёткой обводкой
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "NameLabel"
    nameLbl.Size = UDim2.new(1, 0, 0, 14)
    nameLbl.Position = UDim2.new(0.5, 0, 0.84, 0)
    nameLbl.AnchorPoint = Vector2.new(0.5, 0.5)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.TextStrokeTransparency = 0.25
    nameLbl.TextStrokeColor3 = Color3.fromRGB(15, 25, 10)
    nameLbl.Font = Enum.Font.FredokaOne
    nameLbl.TextSize = 11
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.ZIndex = 28
    nameLbl.Parent = btn

    -- Счётчик количества предметов (справа от иконки)
    local countLbl = Instance.new("TextLabel")
    countLbl.Name = "CountLabel"
    countLbl.Size = UDim2.new(0, 36, 0, 16)
    countLbl.Position = UDim2.new(0.82, 0, 0.38, 0)
    countLbl.AnchorPoint = Vector2.new(0.5, 0.5)
    countLbl.BackgroundTransparency = 1
    countLbl.TextColor3 = Color3.fromRGB(255, 235, 120)
    countLbl.TextStrokeTransparency = 0.25
    countLbl.TextStrokeColor3 = Color3.fromRGB(20, 15, 10)
    countLbl.Font = Enum.Font.FredokaOne
    countLbl.TextSize = 12
    countLbl.TextXAlignment = Enum.TextXAlignment.Left
    countLbl.Text = ""
    countLbl.ZIndex = 28
    countLbl.Parent = btn

    btn.MouseEnter:Connect(function()
        if btn:GetAttribute("HasItem") and not btn:GetAttribute("IsSelected") then
            iconLabel.TextStrokeColor3 = Color3.fromRGB(255, 255, 220)
            iconLabel.TextStrokeTransparency = 0
            itemSprite.Size = UDim2.new(0, 48, 0, 48)
            itemSprite.ImageColor3 = Color3.fromRGB(255, 255, 230)
        end
    end)
    btn.MouseLeave:Connect(function()
        if not btn:GetAttribute("IsSelected") then
            iconLabel.TextStrokeColor3 = Color3.fromRGB(15, 15, 15)
            iconLabel.TextStrokeTransparency = 0.5
            itemSprite.Size = UDim2.new(0, 44, 0, 44)
            itemSprite.ImageColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)

    return btn
end

-- Создание слота в спрайтовом пиксельном хотбаре (1: Дерево, 2: Земля, 3: Камень, 4: Трава)
local function createHotbarSlotUI(parent, slotIndex, pos)
    local slotDef = HOTBAR_SLOT_DEFS[slotIndex]

    local btn = Instance.new("TextButton")
    btn.Name = "HotbarSlot_" .. slotIndex
    btn.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    btn.Position = pos
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.ZIndex = 5
    btn.Parent = parent

    -- Базовый спрайт ячейки (пиксель-арт ячейки из изображения: Дерево, Земля, Камень, Трава)
    local spriteImg = Instance.new("ImageLabel")
    spriteImg.Name = "SpriteImage"
    spriteImg.Size = UDim2.new(1, 0, 1, 0)
    spriteImg.Position = UDim2.new(0, 0, 0, 0)
    spriteImg.BackgroundTransparency = 1
    spriteImg.Image = slotDef.sprite
    spriteImg.ResampleMode = Enum.ResamplerMode.Pixelated
    spriteImg.ScaleType = Enum.ScaleType.Fit
    spriteImg.ZIndex = 6
    spriteImg.Parent = btn

    -- Активная белая рамка выбора (обводит пиксельный закругленный контур ячейки, без белой плашки)
    local activeBorder = Instance.new("Frame")
    activeBorder.Name = "ActiveBorder"
    activeBorder.Size = UDim2.new(1, 6, 1, 6)
    activeBorder.Position = UDim2.new(0.5, 0, 0.5, 0)
    activeBorder.AnchorPoint = Vector2.new(0.5, 0.5)
    activeBorder.BackgroundTransparency = 1
    activeBorder.Visible = (slotIndex == activeHotbarSlot)
    activeBorder.ZIndex = 9
    activeBorder.Parent = btn

    local activeCorner = Instance.new("UICorner")
    activeCorner.CornerRadius = UDim.new(0, 8)
    activeCorner.Parent = activeBorder

    local activeStroke = Instance.new("UIStroke")
    activeStroke.Color = Color3.fromRGB(255, 255, 255)
    activeStroke.Thickness = 3
    activeStroke.Transparency = 0
    activeStroke.Parent = activeBorder

    -- Бейдж номера горячей клавиши [1..4] в верхнем левом углу
    local keyBadge = Instance.new("Frame")
    keyBadge.Name = "KeyBadge"
    keyBadge.Size = UDim2.new(0, 16, 0, 14)
    keyBadge.Position = UDim2.new(0, 3, 0, 3)
    keyBadge.BackgroundColor3 = Color3.fromRGB(20, 15, 12)
    keyBadge.BackgroundTransparency = 0.35
    keyBadge.ZIndex = 10
    keyBadge.Parent = btn

    local kbCorner = Instance.new("UICorner")
    kbCorner.CornerRadius = UDim.new(0, 3)
    kbCorner.Parent = keyBadge

    local keyLbl = Instance.new("TextLabel")
    keyLbl.Name = "KeyLabel"
    keyLbl.Size = UDim2.new(1, 0, 1, 0)
    keyLbl.BackgroundTransparency = 1
    keyLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyLbl.Font = Enum.Font.FredokaOne
    keyLbl.TextSize = 10
    keyLbl.Text = tostring(slotIndex)
    keyLbl.ZIndex = 11
    keyLbl.Parent = keyBadge

    -- Счётчик количества блоков (в правом нижнем углу)
    local countLbl = Instance.new("TextLabel")
    countLbl.Name = "CountLabel"
    countLbl.Size = UDim2.new(0, 34, 0, 15)
    countLbl.Position = UDim2.new(1, -4, 1, -3)
    countLbl.AnchorPoint = Vector2.new(1, 1)
    countLbl.BackgroundTransparency = 1
    countLbl.TextColor3 = Color3.fromRGB(255, 245, 140)
    countLbl.TextStrokeTransparency = 0.2
    countLbl.TextStrokeColor3 = Color3.fromRGB(20, 15, 10)
    countLbl.Font = Enum.Font.FredokaOne
    countLbl.TextSize = 12
    countLbl.TextXAlignment = Enum.TextXAlignment.Right
    countLbl.Text = ""
    countLbl.ZIndex = 11
    countLbl.Parent = btn

    -- Наведение курсора (подсветка при ховере)
    btn.MouseEnter:Connect(function()
        if slotIndex ~= activeHotbarSlot then
            spriteImg.ImageColor3 = Color3.fromRGB(255, 250, 230)
        end
    end)
    btn.MouseLeave:Connect(function()
        if slotIndex ~= activeHotbarSlot then
            local slotData = currentInventorySlots[slotIndex]
            if slotData and slotData.count > 0 then
                spriteImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
            else
                spriteImg.ImageColor3 = Color3.fromRGB(140, 140, 140)
            end
        end
    end)

    return btn
end

local refreshAllInventoryUI

-- Собираем 4 активных спрайтовых слота хотбара (1–4)
for i = 1, NUM_HOTBAR_SLOTS do
    local xPos = (i - 1) * (SLOT_SIZE + SLOT_GAP)
    local btn = createHotbarSlotUI(
        hudContainer,
        i,
        UDim2.new(0, xPos, 0, 0)
    )

    btn.MouseButton1Click:Connect(function()
        if isBackpackOpen and selectedBackpackSlot then
            -- Если выбран предмет из сумки, клик по хотбару перемещает его туда!
            voxelRemote:FireServer("MoveItem", { fromSlot = selectedBackpackSlot, toSlot = i })
            selectedBackpackSlot = nil
            refreshAllInventoryUI()
        else
            if activeHotbarSlot == i then
                activeHotbarSlot = nil
                voxelRemote:FireServer("SelectSlot", { slot = 0 })
            else
                activeHotbarSlot = i
                voxelRemote:FireServer("SelectSlot", { slot = i })
            end
            refreshAllInventoryUI()
        end
    end)

    hotbarButtons[i] = btn
end

-- Связка локального индекса на траве (1..20) с глобальным слотом инвентаря:
-- "backpack" (Портфель): 10..29 (20 слотов)
-- "basket" (Корзинка): 30..44 (15 слотов)
-- "toolbag" (Сумка): 45..54 (10 слотов)
local function getGlobalSlotForLocalIndex(localIndex)
    if activeBagTab == "backpack" then
        return 9 + localIndex -- 10..29
    elseif activeBagTab == "basket" then
        if localIndex <= 15 then
            return 29 + localIndex -- 30..44
        end
    elseif activeBagTab == "toolbag" then
        if localIndex <= 10 then
            return 44 + localIndex -- 45..54
        end
    end
    return nil
end

-- Собираем 20 слотов на поляне (5 колонок х 4 ряда)
local colPositions = { 0.10, 0.30, 0.50, 0.70, 0.90 }
local rowPositions = { 0.14, 0.39, 0.63, 0.88 }

local slotCounter = 1
for r = 1, 4 do
    for c = 1, 5 do
        local btn = createGrassSlotUI(
            grassSlotsContainer,
            slotCounter,
            UDim2.new(colPositions[c], 0, rowPositions[r], 0)
        )

        local currentLocalIdx = slotCounter
        btn.MouseButton1Click:Connect(function()
            local globalSlot = getGlobalSlotForLocalIndex(currentLocalIdx)
            if not globalSlot then return end

            if selectedBackpackSlot == nil then
                if currentInventorySlots[globalSlot] then
                    selectedBackpackSlot = globalSlot
                    refreshAllInventoryUI()
                end
            elseif selectedBackpackSlot == globalSlot then
                selectedBackpackSlot = nil
                refreshAllInventoryUI()
            else
                voxelRemote:FireServer("MoveItem", { fromSlot = selectedBackpackSlot, toSlot = globalSlot })
                selectedBackpackSlot = nil
                refreshAllInventoryUI()
            end
        end)

        grassSlotButtons[slotCounter] = btn
        slotCounter = slotCounter + 1
    end
end

-- Переключение активной сумки (контурная подсветка точно по форме активного объекта)
local function setActiveBagTab(tab)
    activeBagTab = tab
    selectedBackpackSlot = nil

    if BAG_OUTLINE_ASSETS[tab] then
        activeBagOutline.Image = BAG_OUTLINE_ASSETS[tab]
        activeBagOutline.Visible = true
    else
        activeBagOutline.Visible = false
    end
    hoverBagOutline.Visible = false

    if tab == "backpack" then
        bagTitleBadge.Text = "🎒 Портфель: Ресурсы и блоки"
    elseif tab == "toolbag" then
        bagTitleBadge.Text = "🧰 Сумка: Походные инструменты"
    elseif tab == "basket" then
        bagTitleBadge.Text = "🧺 Корзинка: Еда, ягоды и припасы"
    end

    refreshAllInventoryUI()
end

backpackTabBtn.MouseButton1Click:Connect(function() setActiveBagTab("backpack") end)
backpackTabBtn.MouseEnter:Connect(function()
    if activeBagTab ~= "backpack" then
        hoverBagOutline.Image = BAG_OUTLINE_ASSETS.backpack
        hoverBagOutline.Visible = true
    end
    showTooltip("🎒 Портфель (Ресурсы и блоки)")
end)
backpackTabBtn.MouseLeave:Connect(function()
    hoverBagOutline.Visible = false
    hideTooltip()
end)

toolbagTabBtn.MouseButton1Click:Connect(function() setActiveBagTab("toolbag") end)
toolbagTabBtn.MouseEnter:Connect(function()
    if activeBagTab ~= "toolbag" then
        hoverBagOutline.Image = BAG_OUTLINE_ASSETS.toolbag
        hoverBagOutline.Visible = true
    end
    showTooltip("🧰 Сумка (Инструменты)")
end)
toolbagTabBtn.MouseLeave:Connect(function()
    hoverBagOutline.Visible = false
    hideTooltip()
end)

basketTabBtn.MouseButton1Click:Connect(function() setActiveBagTab("basket") end)
basketTabBtn.MouseEnter:Connect(function()
    if activeBagTab ~= "basket" then
        hoverBagOutline.Image = BAG_OUTLINE_ASSETS.basket
        hoverBagOutline.Visible = true
    end
    showTooltip("🧺 Корзинка (Еда и сбор)")
end)
basketTabBtn.MouseLeave:Connect(function()
    hoverBagOutline.Visible = false
    hideTooltip()
end)

sortBtn.MouseButton1Click:Connect(function()
    voxelRemote:FireServer("SortInventory", { containerType = activeBagTab })
end)

-- Обновление одного слота на траве (мягкая круглая подсветка выбранного предмета, без рамок)
local function renderGrassSlotUI(btn, slotData, isSelected)
    local halo = btn:FindFirstChild("Halo")
    local itemSprite = btn:FindFirstChild("ItemSprite")
    local iconLabel = btn:FindFirstChild("IconLabel")
    local colorBox = btn:FindFirstChild("ColorBox")
    local nameLbl = btn:FindFirstChild("NameLabel")
    local countLbl = btn:FindFirstChild("CountLabel")

    if slotData and slotData.count > 0 then
        local def = itemsDefinition[slotData.id] or {
            name = slotData.id,
            icon = "📦",
            color = Color3.fromRGB(150, 150, 150)
        }

        btn:SetAttribute("HasItem", true)
        btn:SetAttribute("IsSelected", isSelected)

        -- Проверяем наличие пиксель-арт спрайта (в стилистике ячеек из второго изображения)
        local spriteAsset = def.sprite
        if not spriteAsset and (slotData.id == "wood_block" or slotData.id == "dirt_block" or slotData.id == "stone_block" or slotData.id == "grass_block") then
            local spriteFallback = {
                wood_block  = "rbxassetid://102991854156536",
                dirt_block  = "rbxassetid://104779952223143",
                stone_block = "rbxassetid://109072643235539",
                grass_block = "rbxassetid://114424346454200",
            }
            spriteAsset = spriteFallback[slotData.id]
        end

        if spriteAsset and spriteAsset ~= "" then
            if itemSprite then
                itemSprite.Image = spriteAsset
                itemSprite.Visible = true
            end
            iconLabel.Visible = false
            colorBox.Visible = false
        elseif def.icon and def.icon ~= "" then
            iconLabel.Text = def.icon
            iconLabel.Visible = true
            colorBox.Visible = false
            if itemSprite then itemSprite.Visible = false end
        else
            colorBox.BackgroundColor3 = def.color or Color3.fromRGB(150, 150, 150)
            colorBox.Visible = true
            iconLabel.Visible = false
            if itemSprite then itemSprite.Visible = false end
        end

        nameLbl.Text = def.name or slotData.id
        nameLbl.Visible = true
        countLbl.Text = slotData.count > 1 and ("x" .. slotData.count) or ""
        countLbl.Visible = true

        if isSelected then
            if itemSprite and itemSprite.Visible then
                itemSprite.Size = UDim2.new(0, 48, 0, 48)
                itemSprite.ImageColor3 = Color3.fromRGB(255, 255, 230)
            end
            iconLabel.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
            iconLabel.TextStrokeTransparency = 0
            iconLabel.TextSize = 28
            nameLbl.TextColor3 = Color3.fromRGB(255, 240, 140)
            nameLbl.TextStrokeTransparency = 0
        else
            if itemSprite and itemSprite.Visible then
                itemSprite.Size = UDim2.new(0, 44, 0, 44)
                itemSprite.ImageColor3 = Color3.fromRGB(255, 255, 255)
            end
            iconLabel.TextStrokeColor3 = Color3.fromRGB(15, 15, 15)
            iconLabel.TextStrokeTransparency = 0.5
            iconLabel.TextSize = 24
            nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLbl.TextStrokeTransparency = 0.25
        end
        if halo then halo.BackgroundTransparency = 1 end
    else
        btn:SetAttribute("HasItem", false)
        btn:SetAttribute("IsSelected", false)
        if itemSprite then itemSprite.Visible = false end
        iconLabel.Visible = false
        iconLabel.TextSize = 24
        iconLabel.TextStrokeTransparency = 0.5
        colorBox.Visible = false
        nameLbl.Visible = false
        countLbl.Visible = false
        if halo then halo.BackgroundTransparency = 1 end
    end
end

-- Обновление одного спрайтового слота хотбара
local function renderHotbarSlotUI(btn, slotData, isActive)
    local activeBorder = btn:FindFirstChild("ActiveBorder")
    local countLbl = btn:FindFirstChild("CountLabel")
    local spriteImg = btn:FindFirstChild("SpriteImage")

    if activeBorder then
        activeBorder.Visible = isActive
    end

    if spriteImg and slotData and slotData.id then
        local def = itemsDefinition[slotData.id]
        if def and def.sprite and def.sprite ~= "" then
            spriteImg.Image = def.sprite
        end
    end

    if slotData and slotData.count > 0 then
        countLbl.Text = tostring(slotData.count)
        countLbl.Visible = true

        if spriteImg then
            spriteImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
        end
    else
        countLbl.Text = "0"
        countLbl.Visible = true

        if spriteImg then
            spriteImg.ImageColor3 = Color3.fromRGB(140, 140, 140)
        end
    end
end

-- Полная перерисовка интерфейса
refreshAllInventoryUI = function()
    -- 1. Обновляем 4 активных спрайтовых слота хотбара
    for i = 1, NUM_HOTBAR_SLOTS do
        local btn = hotbarButtons[i]
        if btn then
            renderHotbarSlotUI(btn, currentInventorySlots[i], (i == activeHotbarSlot))
        end
    end

    -- 2. Обновляем 20 слотов на поляне в соответствии с активной сумкой
    for localIdx = 1, 20 do
        local btn = grassSlotButtons[localIdx]
        if btn then
            local globalSlot = getGlobalSlotForLocalIndex(localIdx)
            if globalSlot then
                btn.Visible = true
                local isSel = (selectedBackpackSlot == globalSlot)
                renderGrassSlotUI(btn, currentInventorySlots[globalSlot], isSel)
            else
                btn.Visible = false
            end
        end
    end
end

-- === ИНТЕРАКТИВНЫЕ ОКНА: БЛОКНОТ, КАРТА, НАСТРОЙКИ ===

-- 1. ОКНО БЛОКНОТА (Рецепты и Задания)
local notebookModal = Instance.new("Frame")
notebookModal.Name = "NotebookModal"

notebookModalRef = notebookModal
notebookModal.Size = UDim2.new(0.68, 0, 0.76, 0)
notebookModal.Position = UDim2.new(0.5, 0, 0.5, 0)
notebookModal.AnchorPoint = Vector2.new(0.5, 0.5)
notebookModal.BackgroundColor3 = Color3.fromRGB(244, 230, 200)
notebookModal.Visible = false
notebookModal.ZIndex = 50
notebookModal.Parent = backpackModal

local nbCorner = Instance.new("UICorner")
nbCorner.CornerRadius = UDim.new(0, 16)
nbCorner.Parent = notebookModal

local nbStroke = Instance.new("UIStroke")
nbStroke.Color = Color3.fromRGB(110, 75, 45)
nbStroke.Thickness = 3
nbStroke.Parent = notebookModal

local nbTitle = Instance.new("TextLabel")
nbTitle.Size = UDim2.new(1, -60, 0, 36)
nbTitle.Position = UDim2.new(0, 20, 0, 12)
nbTitle.BackgroundTransparency = 1
nbTitle.Text = "📖 Походный блокнот котёнка"
nbTitle.TextColor3 = Color3.fromRGB(90, 55, 30)
nbTitle.Font = Enum.Font.FredokaOne
nbTitle.TextSize = 18
nbTitle.TextXAlignment = Enum.TextXAlignment.Left
nbTitle.ZIndex = 51
nbTitle.Parent = notebookModal

local nbClose = Instance.new("TextButton")
nbClose.Size = UDim2.new(0, 32, 0, 32)
nbClose.Position = UDim2.new(1, -44, 0, 14)
nbClose.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
nbClose.Text = "✕"
nbClose.TextColor3 = Color3.fromRGB(255, 255, 255)
nbClose.Font = Enum.Font.FredokaOne
nbClose.TextSize = 16
nbClose.ZIndex = 51
nbClose.Parent = notebookModal
local nbCloseCorner = Instance.new("UICorner")
nbCloseCorner.CornerRadius = UDim.new(0, 8)
nbCloseCorner.Parent = nbClose
nbClose.MouseButton1Click:Connect(function() notebookModal.Visible = false end)

local nbTabsContainer = Instance.new("Frame")
nbTabsContainer.Size = UDim2.new(1, -40, 0, 32)
nbTabsContainer.Position = UDim2.new(0, 20, 0, 52)
nbTabsContainer.BackgroundTransparency = 1
nbTabsContainer.ZIndex = 51
nbTabsContainer.Parent = notebookModal

local recipesTabBtn = Instance.new("TextButton")
recipesTabBtn.Size = UDim2.new(0.48, 0, 1, 0)
recipesTabBtn.Position = UDim2.new(0, 0, 0, 0)
recipesTabBtn.BackgroundColor3 = Color3.fromRGB(190, 145, 95)
recipesTabBtn.Text = "🔨 Крафтовые рецепты"
recipesTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
recipesTabBtn.Font = Enum.Font.FredokaOne
recipesTabBtn.TextSize = 13
recipesTabBtn.ZIndex = 52
recipesTabBtn.Parent = nbTabsContainer
local rcCorner = Instance.new("UICorner")
rcCorner.CornerRadius = UDim.new(0, 8)
rcCorner.Parent = recipesTabBtn

local questsTabBtn = Instance.new("TextButton")
questsTabBtn.Size = UDim2.new(0.48, 0, 1, 0)
questsTabBtn.Position = UDim2.new(0.52, 0, 0, 0)
questsTabBtn.BackgroundColor3 = Color3.fromRGB(215, 185, 145)
questsTabBtn.Text = "📜 Список заданий"
questsTabBtn.TextColor3 = Color3.fromRGB(90, 60, 35)
questsTabBtn.Font = Enum.Font.FredokaOne
questsTabBtn.TextSize = 13
questsTabBtn.ZIndex = 52
questsTabBtn.Parent = nbTabsContainer
local qcCorner = Instance.new("UICorner")
qcCorner.CornerRadius = UDim.new(0, 8)
qcCorner.Parent = questsTabBtn

local nbContentText = Instance.new("TextLabel")
nbContentText.Size = UDim2.new(1, -40, 1, -100)
nbContentText.Position = UDim2.new(0, 20, 0, 92)
nbContentText.BackgroundColor3 = Color3.fromRGB(255, 245, 225)
nbContentText.TextColor3 = Color3.fromRGB(70, 45, 25)
nbContentText.Font = Enum.Font.FredokaOne
nbContentText.TextSize = 13
nbContentText.TextXAlignment = Enum.TextXAlignment.Left
nbContentText.TextYAlignment = Enum.TextYAlignment.Top
nbContentText.Text = "• 🪵 Доски: 1 Дерево ➔ 4 Доски\n• ⛏️ Каменная кирка: 3 Камня + 2 Палки\n• 🪓 Походный топор: 3 Камня + 2 Палки\n• 🏕️ Костёр для рыбки: 4 Дерева + 4 Камня\n• 🎣 Удочка: 3 Ветки + 2 Нити\n\n(В дальнейшем сможем крафтить предметы прямо здесь!)"
nbContentText.ZIndex = 51
nbContentText.Parent = notebookModal

local nbContentCorner = Instance.new("UICorner")
nbContentCorner.CornerRadius = UDim.new(0, 10)
nbContentCorner.Parent = nbContentText

local nbContentPadding = Instance.new("UIPadding")
nbContentPadding.PaddingTop = UDim.new(0, 12)
nbContentPadding.PaddingLeft = UDim.new(0, 14)
nbContentPadding.PaddingRight = UDim.new(0, 14)
nbContentPadding.Parent = nbContentText

recipesTabBtn.MouseButton1Click:Connect(function()
    recipesTabBtn.BackgroundColor3 = Color3.fromRGB(190, 145, 95)
    recipesTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    questsTabBtn.BackgroundColor3 = Color3.fromRGB(215, 185, 145)
    questsTabBtn.TextColor3 = Color3.fromRGB(90, 60, 35)
    nbContentText.Text = "• 🪵 Доски: 1 Дерево ➔ 4 Доски\n• ⛏️ Каменная кирка: 3 Камня + 2 Палки\n• 🪓 Походный топор: 3 Камня + 2 Палки\n• 🏕️ Костёр для рыбки: 4 Дерева + 4 Камня\n• 🎣 Удочка: 3 Ветки + 2 Нити\n\n(В дальнейшем сможем крафтить предметы прямо здесь!)"
end)

questsTabBtn.MouseButton1Click:Connect(function()
    questsTabBtn.BackgroundColor3 = Color3.fromRGB(190, 145, 95)
    questsTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    recipesTabBtn.BackgroundColor3 = Color3.fromRGB(215, 185, 145)
    recipesTabBtn.TextColor3 = Color3.fromRGB(90, 60, 35)
    nbContentText.Text = "🐾 ЗАДАНИЯ КОТЁНКА:\n\n1. [ВЫПОЛНЕНО] Исследовать лесную поляну.\n2. [В ПРОЦЕССЕ] Собрать 15 блоков травы и дерева.\n3. [НОВОЕ] Поймать свежую рыбку к обеду!\n4. [НОВОЕ] Построить уютный домик из блоков на вершине холма."
end)

notebookBtn.MouseButton1Click:Connect(function()
    notebookModal.Visible = not notebookModal.Visible
end)
notebookBtn.MouseEnter:Connect(function()
    showTooltip("📖 Блокнот: Рецепты и Задания")
end)
notebookBtn.MouseLeave:Connect(function()
    hideTooltip()
end)

-- 2. ОКНО КАРТЫ (Остров котёнка)
local mapModal = Instance.new("Frame")
mapModal.Name = "MapModal"
mapModalRef = mapModal
mapModal.Size = UDim2.new(0.72, 0, 0.78, 0)
mapModal.Position = UDim2.new(0.5, 0, 0.5, 0)
mapModal.AnchorPoint = Vector2.new(0.5, 0.5)
mapModal.BackgroundColor3 = Color3.fromRGB(238, 220, 180)
mapModal.Visible = false
mapModal.ZIndex = 50
mapModal.Parent = backpackModal

local mapCorner = Instance.new("UICorner")
mapCorner.CornerRadius = UDim.new(0, 16)
mapCorner.Parent = mapModal

local mapStroke = Instance.new("UIStroke")
mapStroke.Color = Color3.fromRGB(110, 75, 45)
mapStroke.Thickness = 3
mapStroke.Parent = mapModal

local mapTitle = Instance.new("TextLabel")
mapTitle.Size = UDim2.new(1, -60, 0, 36)
mapTitle.Position = UDim2.new(0, 20, 0, 12)
mapTitle.BackgroundTransparency = 1
mapTitle.Text = "🗺️ Карта Острова Котёнка"
mapTitle.TextColor3 = Color3.fromRGB(90, 55, 30)
mapTitle.Font = Enum.Font.FredokaOne
mapTitle.TextSize = 18
mapTitle.TextXAlignment = Enum.TextXAlignment.Left
mapTitle.ZIndex = 51
mapTitle.Parent = mapModal

local mapClose = Instance.new("TextButton")
mapClose.Size = UDim2.new(0, 32, 0, 32)
mapClose.Position = UDim2.new(1, -44, 0, 14)
mapClose.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
mapClose.Text = "✕"
mapClose.TextColor3 = Color3.fromRGB(255, 255, 255)
mapClose.Font = Enum.Font.FredokaOne
mapClose.TextSize = 16
mapClose.ZIndex = 51
mapClose.Parent = mapModal
local mapCloseCorner = Instance.new("UICorner")
mapCloseCorner.CornerRadius = UDim.new(0, 8)
mapCloseCorner.Parent = mapClose
mapClose.MouseButton1Click:Connect(function() mapModal.Visible = false end)

local mapCanvas = Instance.new("Frame")
mapCanvas.Size = UDim2.new(1, -40, 1, -70)
mapCanvas.Position = UDim2.new(0, 20, 0, 54)
mapCanvas.BackgroundColor3 = Color3.fromRGB(215, 235, 210)
mapCanvas.ZIndex = 51
mapCanvas.Parent = mapModal
local mcCorner = Instance.new("UICorner")
mcCorner.CornerRadius = UDim.new(0, 10)
mcCorner.Parent = mapCanvas

local mapCompass = Instance.new("TextLabel")
mapCompass.Size = UDim2.new(0, 60, 0, 60)
mapCompass.Position = UDim2.new(1, -70, 0, 10)
mapCompass.BackgroundTransparency = 1
mapCompass.Text = "🧭 С"
mapCompass.TextColor3 = Color3.fromRGB(110, 70, 40)
mapCompass.Font = Enum.Font.FredokaOne
mapCompass.TextSize = 18
mapCompass.ZIndex = 52
mapCompass.Parent = mapCanvas

local kittenPin = Instance.new("TextLabel")
kittenPin.Name = "KittenPin"
kittenPin.Size = UDim2.new(0, 120, 0, 30)
kittenPin.Position = UDim2.new(0.5, -60, 0.5, -15)
kittenPin.BackgroundTransparency = 1
kittenPin.Text = "🐾 Вы здесь"
kittenPin.TextColor3 = Color3.fromRGB(210, 50, 50)
kittenPin.TextStrokeTransparency = 0.3
kittenPin.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
kittenPin.Font = Enum.Font.FredokaOne
kittenPin.TextSize = 14
kittenPin.ZIndex = 53
kittenPin.Parent = mapCanvas

local mapCoordLabel = Instance.new("TextLabel")
mapCoordLabel.Size = UDim2.new(1, -20, 0, 22)
mapCoordLabel.Position = UDim2.new(0, 10, 1, -26)
mapCoordLabel.BackgroundTransparency = 1
mapCoordLabel.TextColor3 = Color3.fromRGB(90, 65, 45)
mapCoordLabel.Font = Enum.Font.FredokaOne
mapCoordLabel.TextSize = 11
mapCoordLabel.Text = "Координаты: X=0, Z=0 | Остров безопасен"
mapCoordLabel.ZIndex = 52
mapCoordLabel.Parent = mapCanvas

mapBtn.MouseButton1Click:Connect(function()
    mapModal.Visible = not mapModal.Visible
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        mapCoordLabel.Text = string.format("Координаты котёнка: X=%.1f, Z=%.1f | Остров безопасен", root.Position.X, root.Position.Z)
    end
end)
mapBtn.MouseEnter:Connect(function()
    showTooltip("🗺️ Карта Острова")
end)
mapBtn.MouseLeave:Connect(function()
    hideTooltip()
end)

-- 3. ОКНО НАСТРОЕК И РУКОВОДСТВА ПО УПРАВЛЕНИЮ
local settingsModal = Instance.new("Frame")
settingsModal.Name = "SettingsModal"
settingsModalRef = settingsModal
settingsModal.Size = UDim2.new(0, 520, 0, 500)
settingsModal.Position = UDim2.new(0.5, 0, 0.5, 0)
settingsModal.AnchorPoint = Vector2.new(0.5, 0.5)
settingsModal.BackgroundColor3 = Color3.fromRGB(34, 26, 20)
settingsModal.Visible = false
settingsModal.ZIndex = 60
settingsModal.Parent = screenGui

local setCorner = Instance.new("UICorner")
setCorner.CornerRadius = UDim.new(0, 16)
setCorner.Parent = settingsModal

local setStroke = Instance.new("UIStroke")
setStroke.Color = Color3.fromRGB(150, 110, 70)
setStroke.Thickness = 2.5
setStroke.Parent = settingsModal

local setTitle = Instance.new("TextLabel")
setTitle.Size = UDim2.new(1, -60, 0, 36)
setTitle.Position = UDim2.new(0, 20, 0, 12)
setTitle.BackgroundTransparency = 1
setTitle.Text = "⚙️ Управление и Настройки"
setTitle.TextColor3 = Color3.fromRGB(255, 225, 140)
setTitle.Font = Enum.Font.FredokaOne
setTitle.TextSize = 18
setTitle.TextXAlignment = Enum.TextXAlignment.Left
setTitle.ZIndex = 61
setTitle.Parent = settingsModal

local setClose = Instance.new("TextButton")
setClose.Size = UDim2.new(0, 32, 0, 32)
setClose.Position = UDim2.new(1, -44, 0, 14)
setClose.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
setClose.Text = "✕"
setClose.TextColor3 = Color3.fromRGB(255, 255, 255)
setClose.Font = Enum.Font.FredokaOne
setClose.TextSize = 16
setClose.ZIndex = 61
setClose.Parent = settingsModal
local setCloseCorner = Instance.new("UICorner")
setCloseCorner.CornerRadius = UDim.new(0, 8)
setCloseCorner.Parent = setClose
setClose.MouseButton1Click:Connect(function() settingsModal.Visible = false end)

-- Скролл-контейнер для подробной инструкции и настроек
local setScroll = Instance.new("ScrollingFrame")
setScroll.Name = "ScrollContent"
setScroll.Size = UDim2.new(1, -28, 1, -60)
setScroll.Position = UDim2.new(0, 14, 0, 50)
setScroll.BackgroundTransparency = 1
setScroll.BorderSizePixel = 0
setScroll.ScrollBarThickness = 6
setScroll.ScrollBarImageColor3 = Color3.fromRGB(160, 120, 80)
setScroll.CanvasSize = UDim2.new(0, 0, 0, 960)
setScroll.ZIndex = 61
setScroll.Parent = settingsModal

local setPad = Instance.new("UIPadding")
setPad.PaddingLeft = UDim.new(0, 5)
setPad.PaddingRight = UDim.new(0, 10)
setPad.PaddingTop = UDim.new(0, 4)
setPad.PaddingBottom = UDim.new(0, 8)
setPad.Parent = setScroll

local setListLayout = Instance.new("UIListLayout")
setListLayout.Padding = UDim.new(0, 8)
setListLayout.SortOrder = Enum.SortOrder.LayoutOrder
setListLayout.Parent = setScroll

local function createSectionHeader(text, layoutOrder)
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Header_" .. layoutOrder
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(255, 215, 100)
    lbl.Font = Enum.Font.FredokaOne
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = layoutOrder
    lbl.ZIndex = 62
    lbl.Parent = setScroll
    return lbl
end

local function createInstructionCard(icon, keyText, actionTitle, descText, layoutOrder)
    local card = Instance.new("Frame")
    card.Name = "Card_" .. layoutOrder
    card.Size = UDim2.new(1, 0, 0, 44)
    card.BackgroundColor3 = Color3.fromRGB(48, 38, 30)
    card.BorderSizePixel = 0
    card.LayoutOrder = layoutOrder
    card.ZIndex = 62
    card.Parent = setScroll

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 8)
    cCorner.Parent = card

    local cStroke = Instance.new("UIStroke")
    cStroke.Color = Color3.fromRGB(85, 65, 48)
    cStroke.Thickness = 1
    cStroke.Parent = card

    local badge = Instance.new("TextLabel")
    badge.Name = "KeyBadge"
    badge.Size = UDim2.new(0, 78, 0, 26)
    badge.Position = UDim2.new(0, 8, 0.5, 0)
    badge.AnchorPoint = Vector2.new(0, 0.5)
    badge.BackgroundColor3 = Color3.fromRGB(28, 20, 15)
    badge.Text = keyText
    badge.TextColor3 = Color3.fromRGB(255, 230, 120)
    badge.Font = Enum.Font.FredokaOne
    badge.TextSize = 10
    badge.ZIndex = 63
    badge.Parent = card

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = badge

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "Title"
    titleLbl.Size = UDim2.new(1, -100, 0, 17)
    titleLbl.Position = UDim2.new(0, 94, 0, 5)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = string.format("%s %s", icon, actionTitle)
    titleLbl.TextColor3 = Color3.fromRGB(255, 245, 220)
    titleLbl.Font = Enum.Font.FredokaOne
    titleLbl.TextSize = 12
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.ZIndex = 63
    titleLbl.Parent = card

    local descLbl = Instance.new("TextLabel")
    descLbl.Name = "Desc"
    descLbl.Size = UDim2.new(1, -100, 0, 17)
    descLbl.Position = UDim2.new(0, 94, 0, 22)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = descText
    descLbl.TextColor3 = Color3.fromRGB(195, 175, 155)
    descLbl.Font = Enum.Font.FredokaOne
    descLbl.TextSize = 10
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.ZIndex = 63
    descLbl.Parent = card

    return card
end

createSectionHeader("⏰ ВРЕМЯ СУТОК", 1)

local timeGrid = Instance.new("Frame")
timeGrid.Name = "TimeGrid"
timeGrid.Size = UDim2.new(1, 0, 0, 76)
timeGrid.BackgroundTransparency = 1
timeGrid.LayoutOrder = 2
timeGrid.ZIndex = 62
timeGrid.Parent = setScroll

local tGridLay = Instance.new("UIGridLayout")
tGridLay.CellSize = UDim2.new(0.5, -4, 0, 34)
tGridLay.CellPadding = UDim2.new(0, 8, 0, 8)
tGridLay.Parent = timeGrid

local timeOptions = {
    { text = "☀️ Полдень (12:00)", time = 12.0, order = 1 },
    { text = "🌙 Ночь (23:00)",   time = 23.0, order = 2 },
    { text = "🌅 Рассвет (05:00)", time = 5.0,  order = 3 },
    { text = "🌇 Закат (21:00)",  time = 21.0, order = 4 },
}

local timeButtonsUI = {}
local selectedTimeValue = nil

local function updateTimeButtonsUI(targetTime)
    selectedTimeValue = targetTime
    for tVal, btnData in pairs(timeButtonsUI) do
        local isSelected = (targetTime ~= nil and math.abs(tVal - targetTime) < 0.1)
        if isSelected then
            btnData.stroke.Color = Color3.fromRGB(255, 215, 100)
            btnData.stroke.Thickness = 2
            btnData.button.BackgroundColor3 = Color3.fromRGB(75, 58, 42)
            btnData.button.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btnData.stroke.Color = Color3.fromRGB(85, 65, 48)
            btnData.stroke.Thickness = 1
            btnData.button.BackgroundColor3 = Color3.fromRGB(48, 38, 30)
            btnData.button.TextColor3 = Color3.fromRGB(255, 235, 180)
        end
    end
end

for _, opt in ipairs(timeOptions) do
    local tBtn = Instance.new("TextButton")
    tBtn.Name = "TimeBtn_" .. opt.time
    tBtn.BackgroundColor3 = Color3.fromRGB(48, 38, 30)
    tBtn.Text = opt.text
    tBtn.TextColor3 = Color3.fromRGB(255, 235, 180)
    tBtn.TextStrokeColor3 = Color3.fromRGB(25, 18, 12)
    tBtn.TextStrokeTransparency = 0.3
    tBtn.Font = Enum.Font.FredokaOne
    tBtn.TextSize = 12
    tBtn.LayoutOrder = opt.order
    tBtn.ZIndex = 63
    tBtn.Parent = timeGrid

    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(0, 8)
    tCorner.Parent = tBtn

    local tStroke = Instance.new("UIStroke")
    tStroke.Name = "ButtonBorder"
    tStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    tStroke.Color = Color3.fromRGB(85, 65, 48)
    tStroke.Thickness = 1
    tStroke.Parent = tBtn

    timeButtonsUI[opt.time] = {
        button = tBtn,
        stroke = tStroke
    }

    tBtn.MouseButton1Click:Connect(function()
        inGameTime = opt.time
        updateTimeButtonsUI(opt.time)
        voxelRemote:FireServer("SetTime", { time = opt.time })
        showPickupNotification("\u{23f0} \u{0412}\u{0440}\u{0435}\u{043c}\u{044f} \u{0441}\u{0443}\u{0442}\u{043e}\u{043a}: " .. opt.text, 0)
    end)
end

local function getClosestTimeOption()
    local bestTime = 12.0
    local minDiff = 999
    for _, opt in ipairs(timeOptions) do
        local diff = math.abs(inGameTime - opt.time)
        if diff > 12 then diff = 24 - diff end
        if diff < minDiff then
            minDiff = diff
            bestTime = opt.time
        end
    end
    return bestTime
end

updateTimeButtonsUI(getClosestTimeOption())

settingsModal:GetPropertyChangedSignal("Visible"):Connect(function()
    if settingsModal.Visible and selectedTimeValue == nil then
        updateTimeButtonsUI(getClosestTimeOption())
    end
end)

createSectionHeader("🌿 ВРЕМЕНА ГОДА", 3)

local seasonsGrid = Instance.new("Frame")
seasonsGrid.Name = "SeasonsGrid"
seasonsGrid.Size = UDim2.new(1, 0, 0, 76)
seasonsGrid.BackgroundTransparency = 1
seasonsGrid.LayoutOrder = 4
seasonsGrid.ZIndex = 62
seasonsGrid.Parent = setScroll

local sGridLay = Instance.new("UIGridLayout")
sGridLay.CellSize = UDim2.new(0.5, -4, 0, 34)
sGridLay.CellPadding = UDim2.new(0, 8, 0, 8)
sGridLay.Parent = seasonsGrid

local seasonDefs = {
    { id = "autumn", name = "🍂 Осень", order = 1 },
    { id = "winter", name = "❄️ Зима",  order = 2 },
    { id = "spring", name = "🌸 Весна", order = 3 },
    { id = "summer", name = "☀️ Лето",  order = 4 },
}

for _, sDef in ipairs(seasonDefs) do
    local isSelected = (sDef.id == currentSeasonId)
    local sBtn = Instance.new("TextButton")
    sBtn.Name = "SeasonBtn_" .. sDef.id
    sBtn.BackgroundColor3 = isSelected and Color3.fromRGB(75, 58, 42) or Color3.fromRGB(48, 38, 30)
    sBtn.Text = sDef.name
    sBtn.TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(230, 220, 205)
    sBtn.TextStrokeColor3 = Color3.fromRGB(25, 18, 12)
    sBtn.TextStrokeTransparency = 0.3
    sBtn.Font = Enum.Font.FredokaOne
    sBtn.TextSize = 14
    sBtn.LayoutOrder = sDef.order
    sBtn.ZIndex = 63
    sBtn.Parent = seasonsGrid

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 8)
    sCorner.Parent = sBtn

    local sBtnStroke = Instance.new("UIStroke")
    sBtnStroke.Name = "ButtonBorder"
    sBtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    sBtnStroke.Color = isSelected and Color3.fromRGB(255, 215, 100) or Color3.fromRGB(85, 65, 48)
    sBtnStroke.Thickness = isSelected and 2 or 1
    sBtnStroke.Parent = sBtn

    seasonButtonsUI[sDef.id] = {
        button = sBtn,
        stroke = sBtnStroke
    }

    sBtn.MouseButton1Click:Connect(function()
        setSeason(sDef.id, true)
    end)
end


-- 1. Секция: Управление
createSectionHeader("🎮 УПРАВЛЕНИЕ КОТЁНКОМ", 10)
createInstructionCard("🐾", "[ЛКМ]", "Копать лапками", "Подойдите вплотную и зажмите ЛКМ — котик копает блок", 11)
createInstructionCard("🧱", "[ПКМ] / [Q]", "Строить блок", "Ставит выбранный блок на подсвеченную воксельную грань", 12)
createInstructionCard("🪵", "[1]  Дерево", "Хотбар: Бревно", "Выбирает деревянный блок для строительства", 13)
createInstructionCard("🟤", "[2]  Земля", "Хотбар: Земля", "Выбирает блок земли для строительства", 14)
createInstructionCard("🪨", "[3]  Камень", "Хотбар: Камень", "Выбирает каменный блок для строительства", 15)
createInstructionCard("🌿", "[4]  Трава", "Хотбар: Трава", "Выбирает блок сочной травы для строительства", 16)
createInstructionCard("🎒", "[E] / [B]", "Походный рюкзак", "Открыть/закрыть инвентарь поляны, блокнот и карту", 17)
createInstructionCard("🐾", "[W A S D]", "Передвижение", "Котик ходит по поляне с процедурной анимацией лапок", 18)
createInstructionCard("🦘", "[Пробел]", "Прыжок", "Прыжок котика на возвышенности и препятствия", 19)
createInstructionCard("👀", "[Мышь]", "Взгляд и повороты", "Котик поворачивается и переступает лапками к курсору", 20)
createInstructionCard("🧍", "[Стойка]", "Стройка вверх", "При стройке блоков над головой котик встаёт на задние лапы!", 21)

-- 2. Секция: Подсказки
createSectionHeader("💡 ПОЛЕЗНЫЕ ПОДСКАЗКИ", 30)
createInstructionCard("🧲", "Авто", "Сбор лута", "Выпавшие блоки и ресурсы сами притягиваются в рюкзак", 31)
createInstructionCard("🐾", "Близко", "Кошачья лапа", "Взаимодействие с блоками только вблизи (до 4.2 стада)", 32)
createInstructionCard("🎒", "Поляна", "Сумки рюкзака", "В рюкзаке [E] доступны вкладки Портфель, Корзинка и Сумка", 33)
createInstructionCard("⚙️", "[O]", "Настройки", "Быстрое открытие этого окна настроек в любой момент", 34)

-- 3. Секция: Параметры
createSectionHeader("⚙️ ПАРАМЕТРЫ ИГРЫ", 40)

local soundBtn = Instance.new("TextButton")
soundBtn.Name = "SoundBtn"
soundBtn.Size = UDim2.new(1, -10, 0, 38)
soundBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 32)
soundBtn.Text = "🔊 Звуки окружения: ВКЛЮЧЕНО"
soundBtn.TextColor3 = Color3.fromRGB(255, 240, 200)
soundBtn.Font = Enum.Font.FredokaOne
soundBtn.TextSize = 12
soundBtn.LayoutOrder = 41
soundBtn.ZIndex = 62
soundBtn.Parent = setScroll
local sbCorner = Instance.new("UICorner")
sbCorner.CornerRadius = UDim.new(0, 8)
sbCorner.Parent = soundBtn
local soundOn = true
soundBtn.MouseButton1Click:Connect(function()
    soundOn = not soundOn
    soundBtn.Text = soundOn and "🔊 Звуки окружения: ВКЛЮЧЕНО" or "🔇 Звуки окружения: ВЫКЛЮЧЕНО"
end)

local camBtn = Instance.new("TextButton")
camBtn.Name = "CamBtn"
camBtn.Size = UDim2.new(1, -10, 0, 38)
camBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 32)
camBtn.Text = "🐱 Взгляд котёнка на курсор: ВКЛЮЧЕНО"
camBtn.TextColor3 = Color3.fromRGB(255, 240, 200)
camBtn.Font = Enum.Font.FredokaOne
camBtn.TextSize = 12
camBtn.LayoutOrder = 42
camBtn.ZIndex = 62
camBtn.Parent = setScroll
local cbCorner = Instance.new("UICorner")
cbCorner.CornerRadius = UDim.new(0, 8)
cbCorner.Parent = camBtn

-- 4. Секция: Времена года (Осень, Зима, Весна, Лето)

gearBtn.MouseButton1Click:Connect(function()
    settingsModal.Visible = not settingsModal.Visible
end)

-- Открытие/закрытие рюкзака
local function setBackpackOpen(open)
    isBackpackOpen = open
    modalBackdrop.Visible = isBackpackOpen
    backpackModal.Visible = isBackpackOpen
    selectedBackpackSlot = nil
    notebookModal.Visible = false
    mapModal.Visible = false
    settingsModal.Visible = false
    hideTooltip()
    refreshAllInventoryUI()
end

modalBackdrop.MouseButton1Click:Connect(function()
    setBackpackOpen(false)
end)

backpackBtn.MouseButton1Click:Connect(function()
    setBackpackOpen(not isBackpackOpen)
end)

closeBtn.MouseButton1Click:Connect(function()
    setBackpackOpen(false)
end)

-- Переключение активных блоков 1–4 (Дерево, Земля, Камень, Трава)
local SLOT_KEY_MAP = {
    [Enum.KeyCode.One]   = 1,
    [Enum.KeyCode.Two]   = 2,
    [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four]  = 4,
    [Enum.KeyCode.Five]        = 5,
    [Enum.KeyCode.KeypadFive]  = 5,
    [Enum.KeyCode.Six]         = 6,
    [Enum.KeyCode.KeypadSix]   = 6,
}

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.B then
        setBackpackOpen(not isBackpackOpen)
    elseif input.KeyCode == Enum.KeyCode.M then
        if not isBackpackOpen then
            setBackpackOpen(true)
            mapModal.Visible = true
        else
            mapModal.Visible = not mapModal.Visible
        end
    elseif input.KeyCode == Enum.KeyCode.O or input.KeyCode == Enum.KeyCode.F1 then
        settingsModal.Visible = not settingsModal.Visible
    elseif input.KeyCode == Enum.KeyCode.Escape then
        if settingsModal.Visible then
            settingsModal.Visible = false
        elseif isBackpackOpen then
            setBackpackOpen(false)
        end
    elseif not isBackpackOpen and not settingsModal.Visible then
        local slotNum = SLOT_KEY_MAP[input.KeyCode]
        if slotNum then
            if activeHotbarSlot == slotNum then
                activeHotbarSlot = nil
                voxelRemote:FireServer("SelectSlot", { slot = 0 })
            else
                activeHotbarSlot = slotNum
                voxelRemote:FireServer("SelectSlot", { slot = slotNum })
            end
            refreshAllInventoryUI()
        end
    end
end)

-- === ОБРАБОТКА СЕТЕВЫХ СООБЩЕНИЙ С СЕРВЕРА ===
voxelRemote.OnClientEvent:Connect(function(action, data)
    if action == "InventoryUpdate" then
        currentInventorySlots = {}
        if data.slots then
            for k, v in pairs(data.slots) do
                local slotNum = tonumber(k)
                if slotNum and v and v.id and v.count and v.count > 0 then
                    currentInventorySlots[slotNum] = v
                end
            end
        end
        activeHotbarSlot = (data.activeSlot and data.activeSlot > 0) and data.activeSlot or nil
        if data.itemsDef then
            itemsDefinition = data.itemsDef
        end
        refreshAllInventoryUI()

    elseif action == "ItemPickedUp" then
        showPickupNotification(data.name, data.count)

    elseif action == "SeasonChanged" then
        if data and data.season then
            setSeason(data.season, false)
        end
    elseif action == "TimeChanged" then
        if data and data.time then
            inGameTime = data.time
        end
    end
end)

-- === ТОЧНЫЙ ВЫБОР ЦЕЛИ: КУРСОР МЫШИ + УМНЫЙ ЛУЧ ПЕРЕД КОТИКОМ (ВВЕРХ / ВНИЗ / ВПЕРЁД) ===
local currentTargetBlock = nil
local currentTargetNormal = nil

-- Нежная плоская подсветка поверхности (земля или грань объекта)
local surfaceHighlight = Instance.new("Part")
surfaceHighlight.Name = "VoxelSurfaceHighlight"
surfaceHighlight.Anchored = true
surfaceHighlight.CanCollide = false
surfaceHighlight.CanQuery = false
surfaceHighlight.CanTouch = false
surfaceHighlight.CastShadow = false
surfaceHighlight.Material = Enum.Material.SmoothPlastic
surfaceHighlight.Transparency = 1
surfaceHighlight.Parent = Workspace

local function getTargetBlockAndNormal()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return nil, nil end

    local camera = Workspace.CurrentCamera
    if not camera then return nil, nil end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { worldFolder }
    params.FilterType = Enum.RaycastFilterType.Include

    -- 1. ПРИОРИТЕТ 1: Курсор мыши в изометрии
    -- Взаимодействовать можно ТОЛЬКО с блоками вплотную / рядом с котиком (нельзя издалека)
    local mousePos = UserInputService:GetMouseLocation()
    local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
    local mouseResult = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 300, params)

    if mouseResult and mouseResult.Instance then
        local distToCat = (mouseResult.Position - root.Position).Magnitude
        if distToCat <= MAX_INTERACTION_DISTANCE then
            return mouseResult.Instance, mouseResult.Normal
        else
            -- Блок находится далеко от котика: взаимодействовать и подсвечивать нельзя!
            return nil, nil
        end
    end

    -- 2. ПРИОРИТЕТ 2: Интеллектуальный луч перед котиком (если мышь в небе или не на блоке)
    local origin = root.Position
    local forward = root.CFrame.LookVector
    local activeItem = currentInventorySlots[activeHotbarSlot]
    local isHoldingBlock = activeItem and activeItem.count > 0 and itemsDefinition[activeItem.id] and itemsDefinition[activeItem.id].isBlock

    -- а) Луч на уровне груди (прямо перед носом)
    local rayChest = Workspace:Raycast(origin - Vector3.new(0, 0.2, 0), forward * 3.2, params)
    if rayChest and rayChest.Instance then
        local blk = rayChest.Instance
        local norm = rayChest.Normal

        -- Если котик держит блок для строительства и смотрит в бок стоящего перед ним блока:
        -- Проверяем, свободна ли ячейка НАД этим блоком — если да, предлагаем ставить НА ВЕРХ!
        if isHoldingBlock and math.abs(norm.Y) < 0.5 then
            local topPos = snapToGrid(blk.Position + Vector3.new(0, BLOCK_SIZE, 0), BLOCK_SIZE)
            local isTopOccupied = false
            for _, other in ipairs(worldFolder:GetChildren()) do
                if other:IsA("BasePart") and (other.Position - topPos).Magnitude < 0.4 then
                    isTopOccupied = true
                    break
                end
            end
            if not isTopOccupied then
                return blk, Vector3.new(0, 1, 0) -- Верхняя грань блока!
            end
        end
        return blk, norm
    end

    -- б) Луч на 1 блок выше (если стена уже построена и хотим строить/копать 2-й слой)
    local rayHigh = Workspace:Raycast(origin + Vector3.new(0, 1.2, 0), forward * 3.2, params)
    if rayHigh and rayHigh.Instance then
        return rayHigh.Instance, rayHigh.Normal
    end

    -- в) Луч под лапками впереди (земля под ногами)
    local rayFloor = Workspace:Raycast(origin, forward * 2.8 - Vector3.new(0, 2.6, 0), params)
    if rayFloor and rayFloor.Instance then
        return rayFloor.Instance, rayFloor.Normal
    end

    return nil, nil
end

RunService.RenderStepped:Connect(function()
    local blk, nrm = getTargetBlockAndNormal()
    currentTargetBlock = blk
    currentTargetNormal = nrm

    -- Передаём целевую точку взгляда котику (куда ставит или где ломает)
    local character = player.Character
    if character then
        if isBackpackOpen or not currentTargetBlock then
            character:SetAttribute("TargetLookPos", nil)
        else
            local lookPos = currentTargetBlock.Position
            if currentTargetNormal then
                local activeItem = currentInventorySlots[activeHotbarSlot]
                local isHoldingBlock = activeItem and activeItem.count > 0 and itemsDefinition[activeItem.id] and itemsDefinition[activeItem.id].isBlock
                if isHoldingBlock then
                    lookPos = currentTargetBlock.Position + (currentTargetNormal * BLOCK_SIZE)
                end
            end
            character:SetAttribute("TargetLookPos", lookPos)
        end
    end

    if isBackpackOpen or not currentTargetBlock or not currentTargetNormal then
        surfaceHighlight.Transparency = 1
        return
    end

    local n = currentTargetNormal
    local halfSize = BLOCK_SIZE * 0.5
    local offset = halfSize + 0.008

    -- Подсвечивается ТОЛЬКО сама поверхность (земля или грань блока), без 3D куба и рамок
    if math.abs(n.Y) > 0.5 then
        -- Земля (горизонтальная плоскость под лапками)
        surfaceHighlight.Size = Vector3.new(BLOCK_SIZE * 0.98, 0.012, BLOCK_SIZE * 0.98)
        surfaceHighlight.CFrame = CFrame.new(currentTargetBlock.Position + Vector3.new(0, offset * math.sign(n.Y), 0))
    elseif math.abs(n.X) > 0.5 then
        -- Боковая грань объекта (X)
        surfaceHighlight.Size = Vector3.new(0.012, BLOCK_SIZE * 0.98, BLOCK_SIZE * 0.98)
        surfaceHighlight.CFrame = CFrame.new(currentTargetBlock.Position + Vector3.new(offset * math.sign(n.X), 0, 0))
    else
        -- Боковая грань объекта (Z)
        surfaceHighlight.Size = Vector3.new(BLOCK_SIZE * 0.98, BLOCK_SIZE * 0.98, 0.012)
        surfaceHighlight.CFrame = CFrame.new(currentTargetBlock.Position + Vector3.new(0, 0, offset * math.sign(n.Z)))
    end

    local activeItem = currentInventorySlots[activeHotbarSlot]
    local def = activeItem and itemsDefinition[activeItem.id]

    if def and def.isBlock and activeItem.count > 0 then
        -- Земля подсвечивается мягким оттенком устанавливаемого блока
        surfaceHighlight.Color = def.color
        surfaceHighlight.Transparency = 0.60
    else
        -- Для копания — совсем немного подсвечивается место
        surfaceHighlight.Color = Color3.fromRGB(255, 255, 240)
        surfaceHighlight.Transparency = 0.68
    end
end)

-- === КОПАНИЕ И СТРОИТЕЛЬСТВО ЛАПКАМИ ===
local isDiggingKeyHeld = false
local lastDigTick = 0
local isPlacingCooldown = false

local lastDistanceWarningTick = 0
local activeDistanceWarningPill = nil
local function showDistanceWarning()
    local now = tick()
    if now - lastDistanceWarningTick < 1.0 and activeDistanceWarningPill and activeDistanceWarningPill.Parent then
        return
    end
    lastDistanceWarningTick = now

    if activeDistanceWarningPill and activeDistanceWarningPill.Parent then
        activeDistanceWarningPill:Destroy()
        activeDistanceWarningPill = nil
    end

    local pill = Instance.new("TextLabel")
    pill.Name = "DistanceWarningPill"
    pill.Size = UDim2.new(0, 246, 0, 24)
    pill.Position = UDim2.new(0.5, -123, 0, 18)
    pill.BackgroundColor3 = Color3.fromRGB(42, 20, 20)
    pill.BackgroundTransparency = 1
    pill.TextTransparency = 1
    pill.TextColor3 = Color3.fromRGB(255, 235, 230)
    pill.TextStrokeColor3 = Color3.fromRGB(35, 10, 10)
    pill.TextStrokeTransparency = 1
    pill.Font = Enum.Font.FredokaOne
    pill.TextSize = 12
    pill.Text = "🐾 Слишком далеко! Подойдите ближе"
    pill.ZIndex = 80
    pill.Parent = notifContainer
    activeDistanceWarningPill = pill

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(0, 7)
    pillCorner.Parent = pill

    local pillStroke = Instance.new("UIStroke")
    pillStroke.Name = "Border"
    pillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    pillStroke.Color = Color3.fromRGB(215, 75, 75)
    pillStroke.Thickness = 1.2
    pillStroke.Transparency = 1
    pillStroke.Parent = pill

    -- 1. Быстрое плавное появление (0.22 сек)
    local popIn = TweenService:Create(pill, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -123, 0, 4),
        BackgroundTransparency = 0.08,
        TextTransparency = 0,
        TextStrokeTransparency = 0.2
    })
    local strokeIn = TweenService:Create(pillStroke, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 0.25
    })
    popIn:Play()
    strokeIn:Play()

    -- 2. Время на спокойное чтение: подсказка неподвижно и четко видна 2.8 секунды
    task.delay(2.8, function()
        if pill and pill.Parent then
            -- 3. Плавное затухание (0.5 сек)
            local fadeOut = TweenService:Create(pill, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -123, 0, -10),
                BackgroundTransparency = 1,
                TextTransparency = 1,
                TextStrokeTransparency = 1
            })
            local strokeOut = TweenService:Create(pillStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Transparency = 1
            })
            fadeOut:Play()
            strokeOut:Play()
            fadeOut.Completed:Connect(function()
                if pill and pill.Parent then
                    if activeDistanceWarningPill == pill then
                        activeDistanceWarningPill = nil
                    end
                    pill:Destroy()
                end
            end)
        end
    end)
end

local function checkAndWarnFarClick()
    local camera = Workspace.CurrentCamera
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not (camera and root) then return end

    local mousePos = UserInputService:GetMouseLocation()
    local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { worldFolder }
    params.FilterType = Enum.RaycastFilterType.Include
    local hit = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 300, params)
    if hit and hit.Instance then
        local dist = (hit.Position - root.Position).Magnitude
        if dist > MAX_INTERACTION_DISTANCE then
            showDistanceWarning()
        end
    end
end

local function doDigStep()
    local character = player.Character
    if not character or isBackpackOpen then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if currentTargetBlock then
        local dist = (currentTargetBlock.Position - root.Position).Magnitude
        if dist > MAX_INTERACTION_DISTANCE + 0.8 then
            showDistanceWarning()
            return
        end

        character:SetAttribute("TargetLookPos", currentTargetBlock.Position)
        if currentTargetBlock.Position.Y >= (root.Position.Y - 0.2) then
            character:SetAttribute("IsDiggingUp", true)
            character:SetAttribute("IsDigging", false)
        else
            character:SetAttribute("IsDigging", true)
            character:SetAttribute("IsDiggingUp", false)
        end
        voxelRemote:FireServer("Hit", { Block = currentTargetBlock })
    else
        checkAndWarnFarClick()
    end
end

local function doPlaceStep()
    local character = player.Character
    if not character or isBackpackOpen or isPlacingCooldown then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if not currentTargetBlock or not currentTargetNormal then
        checkAndWarnFarClick()
        return
    end

    local dist = (currentTargetBlock.Position - root.Position).Magnitude
    if dist > MAX_INTERACTION_DISTANCE + 0.8 then
        showDistanceWarning()
        return
    end

    local activeItem = currentInventorySlots[activeHotbarSlot]
    if not (activeItem and activeItem.count > 0) then return end

    local def = itemsDefinition[activeItem.id]
    if not (def and def.isBlock) then return end

    local newPos = snapToGrid(currentTargetBlock.Position + (currentTargetNormal * BLOCK_SIZE), BLOCK_SIZE)
    local distNew = (newPos - root.Position).Magnitude
    if distNew > MAX_INTERACTION_DISTANCE + 1.2 then
        showDistanceWarning()
        return
    end

    character:SetAttribute("TargetLookPos", newPos)

    -- Проверяем, ставится ли блок НАВЕРХ
    local isUpwards = false
    if (currentTargetNormal.Y > 0.5 and currentTargetBlock.Position.Y >= (root.Position.Y - 0.75)) or
       (newPos.Y >= root.Position.Y - 0.1) then
        isUpwards = true
    end

    isPlacingCooldown = true
    task.delay(0.25, function()
        isPlacingCooldown = false
    end)

    if isUpwards then
        -- Котик встаёт на задние лапки и тянется вверх!
        character:SetAttribute("IsPlacingUp", true)
        task.delay(0.65, function()
            if character then character:SetAttribute("IsPlacingUp", false) end
        end)
    else
        -- Обычная установка блока внизу на земле
        character:SetAttribute("IsPlacing", true)
        task.delay(0.40, function()
            if character then character:SetAttribute("IsPlacing", false) end
        end)
    end

    voxelRemote:FireServer("Place", {
        TargetBlock = currentTargetBlock,
        Normal = currentTargetNormal,
        Slot = activeHotbarSlot
    })
end

UserInputService.InputBegan:Connect(function(input, processed)
    if isBackpackOpen then return end

    -- Если клик пришелся на интерактивный UI (например, слот рюкзака), пропускаем для мыши
    if processed and input.UserInputType ~= Enum.UserInputType.MouseButton2 and input.KeyCode ~= Enum.KeyCode.Q then
        return
    end

    -- ЛКМ: копать лапками
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if not processed then
            -- РџСЂРѕРІРµСЂСЏРµРј: РєР»РёРє РїРѕ РїСЂСѓРґСѓ РґР»СЏ РІРµСЃРµРЅРЅРµР№ СЂС‹Р±Р°Р»РєРё
            local mPos = UserInputService:GetMouseLocation()
            local cam = Workspace.CurrentCamera
            if cam then
                local unitRay = cam:ViewportPointToRay(mPos.X, mPos.Y)
                local pondParams = RaycastParams.new()
                local pondInst = Workspace:FindFirstChild("SpringFishingPond")
                if pondInst then
                    pondParams.FilterDescendantsInstances = { pondInst }
                    pondParams.FilterType = Enum.RaycastFilterType.Include
                    local pondHit = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 300, pondParams)
                    if pondHit then
                        local char = player.Character
                        local root = char and char:FindFirstChild("HumanoidRootPart")
                        if root and (pondHit.Position - root.Position).Magnitude <= 14 then
                            voxelRemote:FireServer("FishPond", {})
                            return
                        end
                    end
                end
            end

            local now = tick()
            isDiggingKeyHeld = true
            if now - lastDigTick >= 0.22 then
                lastDigTick = now
                doDigStep()
            end
        end
    -- ПКМ или Q: ставить блок из активного слота
    elseif input.KeyCode == Enum.KeyCode.Q or input.UserInputType == Enum.UserInputType.MouseButton2 then
        doPlaceStep()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isDiggingKeyHeld = false
        local character = player.Character
        if character then
            character:SetAttribute("IsDigging", false)
            character:SetAttribute("IsDiggingUp", false)
        end
    end
end)

-- Интервал копания лапками — 0.55 секунды (плавный, размеренный ритм)
local lastVitalityTick = 0
RunService.Heartbeat:Connect(function(dt)
    if isDiggingKeyHeld and not isBackpackOpen then
        if tick() - lastDigTick > 0.55 then
            lastDigTick = tick()
            doDigStep()
            catStats.energy = math.max(0, catStats.energy - 1.2)
        end
    end

    -- Плавное обновление показателей котика (энергия, голод, жажда)
    if tick() - lastVitalityTick >= 0.1 then
        lastVitalityTick = tick()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0.1 then
            catStats.energy = math.max(0, catStats.energy - 0.12)
        else
            catStats.energy = math.min(100, catStats.energy + 0.3)
        end
        updateVitalityDisplay()
    end

    -- Обновление суточного цикла дня и ночи, стрелок часов и температуры
    updateDayNightAndWeather(dt)
end)
