-- LocalScript: StarterPlayer -> StarterPlayerScripts -> VoxelClient
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

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
local activeHotbarSlot = 1
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
    paw   = "rbxassetid://81554992150735", -- Чёрная кошачья лапка (по умолчанию)
    wood  = "rbxassetid://78173367572097", -- Рука из полена (дерево)
    stone = "rbxassetid://125315613353193",-- Рука из камня
    grass = "rbxassetid://78225648528704", -- Рука из травы и листвы
    dirt  = "rbxassetid://75303885811286", -- Рука из земли/грунта
}

local ITEM_TO_CURSOR = {
    wood_block  = CURSORS.wood,
    stone_block = CURSORS.stone,
    grass_block = CURSORS.grass,
    dirt_block  = CURSORS.dirt,
}

local cursorGui = playerGui:FindFirstChild("CustomCursorGui") or Instance.new("ScreenGui")
cursorGui.Name = "CustomCursorGui"
cursorGui.ResetOnSpawn = false
cursorGui.IgnoreGuiInset = true
cursorGui.DisplayOrder = 1000000 -- Всегда поверх всех элементов интерфейса
cursorGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local cursorImage = cursorGui:FindFirstChild("CursorImage") or Instance.new("ImageLabel")
cursorImage.Name = "CursorImage"
cursorImage.Size = UDim2.new(0, 52, 0, 52)
cursorImage.Position = UDim2.new(0, 0, 0, 0)
cursorImage.BackgroundTransparency = 1
cursorImage.Image = CURSORS.paw
cursorImage.ScaleType = Enum.ScaleType.Fit
cursorImage.ZIndex = 1000000
cursorImage.Active = false -- Клики проходят сквозь курсор
cursorImage.Selectable = false
cursorImage.Parent = cursorGui
cursorGui.Parent = playerGui

-- Отключаем стандартный курсор Roblox, чтобы он никогда не появлялся над кнопками
UserInputService.MouseIconEnabled = false

local function getDesiredCursor()
    local activeItem = currentInventorySlots and currentInventorySlots[activeHotbarSlot]
    if activeItem and activeItem.count and activeItem.count > 0 then
        local hand = ITEM_TO_CURSOR[activeItem.id]
        if hand then
            return hand
        end
    end
    return CURSORS.paw
end

local function updateCustomCursor()
    UserInputService.MouseIconEnabled = false
    local mPos = UserInputService:GetMouseLocation()
    local isPressed = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)

    local targetIcon = getDesiredCursor()
    if cursorImage.Image ~= targetIcon then
        cursorImage.Image = targetIcon
    end
    if mouse and mouse.Icon ~= targetIcon then
        mouse.Icon = targetIcon
    end

    -- Нажатие ЛКМ: легкое тактильное сжатие курсора на кончике клика
    if isPressed then
        cursorImage.Size = UDim2.new(0, 47, 0, 47)
        cursorImage.Position = UDim2.new(0, mPos.X - 1, 0, mPos.Y - 1)
    else
        cursorImage.Size = UDim2.new(0, 52, 0, 52)
        cursorImage.Position = UDim2.new(0, mPos.X - 2, 0, mPos.Y - 2)
    end
end

RunService.RenderStepped:Connect(updateCustomCursor)

player.CharacterAdded:Connect(function()
    task.wait(0.1)
    updateCustomCursor()
end)

-- 1. СПРАЙТОВЫЙ ПИКСЕЛЬНЫЙ ХОТБАР (4 СЛОТА: ДЕРЕВО, ЗЕМЛЯ, КАМЕНЬ, ТРАВА)
local NUM_HOTBAR_SLOTS = 4
local SLOT_SIZE = 54
local SLOT_GAP = 8
local TOTAL_HOTBAR_WIDTH = (NUM_HOTBAR_SLOTS * SLOT_SIZE) + ((NUM_HOTBAR_SLOTS - 1) * SLOT_GAP) -- 216 + 24 = 240px

local HOTBAR_SLOT_DEFS = {
    [1] = { id = "wood_block",  sprite = "rbxassetid://102991854156536", name = "Дерево", icon = "🪵" },
    [2] = { id = "dirt_block",  sprite = "rbxassetid://104779952223143", name = "Земля",  icon = "🟤" },
    [3] = { id = "stone_block", sprite = "rbxassetid://109072643235539", name = "Камень", icon = "🪨" },
    [4] = { id = "grass_block", sprite = "rbxassetid://114424346454200", name = "Трава",  icon = "🌿" },
}

local hudContainer = Instance.new("Frame")
hudContainer.Name = "WoodHudContainer"
hudContainer.Size = UDim2.new(0, TOTAL_HOTBAR_WIDTH, 0, 56)
hudContainer.Position = UDim2.new(0.5, -TOTAL_HOTBAR_WIDTH / 2, 1, -74)
hudContainer.BackgroundTransparency = 1
hudContainer.BorderSizePixel = 0
hudContainer.Parent = screenGui

-- 2. ФУНКЦИОНАЛЬНЫЙ ПОХОДНЫЙ РЮКЗАК (В САМОМ ПРАВОМ НИЖНЕМ УГЛУ)
local backpackBtn = Instance.new("ImageButton")
backpackBtn.Name = "OpenBackpackBtn"
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
vitalityFrame.Size = UDim2.new(0, 146, 0, 72)
vitalityFrame.Position = UDim2.new(0, 16, 1, -86) -- Левый нижний угол экрана
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
    local colW = 146 / 3
    local colFrame = Instance.new("Frame")
    colFrame.Name = "Col_" .. name
    colFrame.Size = UDim2.new(0, math.floor(colW), 1, 0)
    colFrame.Position = UDim2.new(0, math.floor((colIndex - 1) * colW), 0, 0)
    colFrame.BackgroundTransparency = 1
    colFrame.ZIndex = 6
    colFrame.Parent = vitalityFrame

    -- Пиксельная иконка
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 24, 0, 28)
    icon.Position = UDim2.new(0.5, -12, 0, 6)
    icon.BackgroundTransparency = 1
    icon.Image = iconId
    icon.ResampleMode = Enum.ResamplerMode.Pixelated
    icon.ScaleType = Enum.ScaleType.Fit
    icon.ZIndex = 7
    icon.Parent = colFrame

    -- Текст процентов под иконкой
    local pctLabel = Instance.new("TextLabel")
    pctLabel.Name = "PercentText"
    pctLabel.Size = UDim2.new(1, 0, 0, 16)
    pctLabel.Position = UDim2.new(0, 0, 0, 36)
    pctLabel.BackgroundTransparency = 1
    pctLabel.Text = math.floor(defaultPercent) .. "%"
    pctLabel.TextColor3 = Color3.fromRGB(235, 230, 210)
    pctLabel.Font = Enum.Font.FredokaOne
    pctLabel.TextSize = 11
    pctLabel.ZIndex = 7
    pctLabel.Parent = colFrame

    local txtStroke = Instance.new("UIStroke")
    txtStroke.Color = Color3.fromRGB(40, 35, 25)
    txtStroke.Thickness = 1
    txtStroke.Parent = pctLabel

    -- Темная подложка горизонтальной полоски
    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.Size = UDim2.new(0, 32, 0, 3)
    barBg.Position = UDim2.new(0.5, -16, 0, 56)
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
local notifContainer = Instance.new("Frame")
notifContainer.Name = "NotifContainer"
notifContainer.Size = UDim2.new(0, 260, 0, 100)
notifContainer.Position = UDim2.new(0.5, -130, 1, -220)
notifContainer.BackgroundTransparency = 1
notifContainer.Parent = screenGui

local function showPickupNotification(itemName, count)
    local pill = Instance.new("TextLabel")
    pill.Size = UDim2.new(0, 220, 0, 28)
    pill.Position = UDim2.new(0.5, -110, 1, 0)
    pill.BackgroundColor3 = Color3.fromRGB(20, 25, 20)
    pill.BackgroundTransparency = 0.2
    pill.TextColor3 = Color3.fromRGB(130, 255, 120)
    pill.Font = Enum.Font.FredokaOne
    pill.TextSize = 14
    pill.Text = string.format("+%d %s", count or 1, itemName)
    pill.Parent = notifContainer

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(0, 8)
    pillCorner.Parent = pill

    local tweenUp = TweenService:Create(pill, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -110, 0, -20),
        TextTransparency = 1,
        BackgroundTransparency = 1
    })
    tweenUp:Play()
    tweenUp.Completed:Connect(function()
        pill:Destroy()
    end)
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
            activeHotbarSlot = i
            voxelRemote:FireServer("SelectSlot", { slot = i })
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
setScroll.CanvasSize = UDim2.new(0, 0, 0, 840)
setScroll.ZIndex = 61
setScroll.Parent = settingsModal

local setListLayout = Instance.new("UIListLayout")
setListLayout.Padding = UDim.new(0, 8)
setListLayout.SortOrder = Enum.SortOrder.LayoutOrder
setListLayout.Parent = setScroll

local function createSectionHeader(text, layoutOrder)
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Header_" .. layoutOrder
    lbl.Size = UDim2.new(1, -10, 0, 24)
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
    card.Size = UDim2.new(1, -10, 0, 44)
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
}

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.B then
        setBackpackOpen(not isBackpackOpen)
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
            activeHotbarSlot = slotNum
            voxelRemote:FireServer("SelectSlot", { slot = slotNum })
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
        activeHotbarSlot = data.activeSlot or activeHotbarSlot
        if data.itemsDef then
            itemsDefinition = data.itemsDef
        end
        refreshAllInventoryUI()

    elseif action == "ItemPickedUp" then
        showPickupNotification(data.name, data.count)
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
local function showDistanceWarning()
    if tick() - lastDistanceWarningTick < 1.2 then return end
    lastDistanceWarningTick = tick()

    local pill = Instance.new("TextLabel")
    pill.Size = UDim2.new(0, 260, 0, 28)
    pill.Position = UDim2.new(0.5, -130, 1, 0)
    pill.BackgroundColor3 = Color3.fromRGB(35, 20, 20)
    pill.BackgroundTransparency = 0.2
    pill.TextColor3 = Color3.fromRGB(255, 140, 140)
    pill.Font = Enum.Font.FredokaOne
    pill.TextSize = 13
    pill.Text = "🐾 Слишком далеко! Подойдите ближе"
    pill.Parent = notifContainer

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(0, 8)
    pillCorner.Parent = pill

    local tween = TweenService:Create(pill, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -130, 0, 0),
        TextTransparency = 1,
        BackgroundTransparency = 1
    })
    tween:Play()
    tween.Completed:Connect(function()
        pill:Destroy()
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
            isDiggingKeyHeld = true
            doDigStep()
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
end)
