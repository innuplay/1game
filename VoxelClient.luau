-- LocalScript: StarterPlayer -> StarterPlayerScripts -> VoxelClient
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local voxelRemote = ReplicatedStorage:WaitForChild("VoxelRemote")
local worldFolder = Workspace:WaitForChild("VoxelWorld")

-- Компактный размер блоков (1.5x1.5x1.5 studs)
local BLOCK_SIZE = 1.5

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

-- 1. УЮТНЫЙ ДЕРЕВЯННЫЙ HUD (ВИТАЛЬНОСТЬ + РЮКЗАК + ХОТБАР 1-9 + ПОЛОСА ОПЫТА)
local hudContainer = Instance.new("Frame")
hudContainer.Name = "WoodHudContainer"
hudContainer.Size = UDim2.new(0, 605, 0, 112)
hudContainer.Position = UDim2.new(0.5, -302, 1, -120)
hudContainer.BackgroundTransparency = 1
hudContainer.BorderSizePixel = 0
hudContainer.Parent = screenGui

local DEFAULT_TIP_TEXT = "[ЛКМ] — Копать лапками | [Q или ПКМ] — Строить | [1–9] — Выбор слота | [E] — Рюкзак"

-- Подсказка управления сверху
local tipLabel = Instance.new("TextLabel")
tipLabel.Name = "ControlsTip"
tipLabel.Size = UDim2.new(0, 605, 0, 20)
tipLabel.Position = UDim2.new(0, 0, 0, -22)
tipLabel.BackgroundTransparency = 1
tipLabel.TextColor3 = Color3.fromRGB(255, 235, 130)
tipLabel.TextStrokeTransparency = 0.35
tipLabel.TextStrokeColor3 = Color3.fromRGB(30, 20, 12)
tipLabel.Font = Enum.Font.FredokaOne
tipLabel.TextSize = 12
tipLabel.Text = DEFAULT_TIP_TEXT
tipLabel.ZIndex = 5
tipLabel.Parent = hudContainer
local hudBackground = Instance.new("ImageLabel")
hudBackground.Name = "HudBackground"
hudBackground.Size = UDim2.new(1, 0, 1, 0)
hudBackground.Position = UDim2.new(0, 0, 0, 0)
hudBackground.BackgroundTransparency = 1
hudBackground.Image = "rbxassetid://128642629180420"
hudBackground.ResampleMode = Enum.ResamplerMode.Pixelated
hudBackground.ScaleType = Enum.ScaleType.Fit
hudBackground.ZIndex = 1
hudBackground.Parent = hudContainer

-- А) ЛЕВАЯ ПАНЕЛЬ ВИТАЛЬНОСТИ (КОЛОННЫ С ЛОЗОЙ И ЖИДКОСТЯМИ)
-- Трубка энергии / сытости (оранжевая)
local energyTube = Instance.new("Frame")
energyTube.Name = "EnergyTube"
energyTube.Size = UDim2.new(0, 10, 0, 66)
energyTube.Position = UDim2.new(0, 13, 0, 22)
energyTube.BackgroundColor3 = Color3.fromRGB(35, 20, 12)
energyTube.BorderSizePixel = 0
energyTube.ZIndex = 2
energyTube.Parent = hudContainer

local energyFill = Instance.new("Frame")
energyFill.Name = "Fill"
energyFill.Size = UDim2.new(1, 0, 1, 0)
energyFill.Position = UDim2.new(0, 0, 0, 0)
energyFill.BackgroundColor3 = Color3.fromRGB(235, 145, 55)
energyFill.BorderSizePixel = 0
energyFill.ZIndex = 3
energyFill.Parent = energyTube

local energyCorner = Instance.new("UICorner")
energyCorner.CornerRadius = UDim.new(0, 4)
energyCorner.Parent = energyFill

-- Трубка воды / здоровья (голубая)
local waterTube = Instance.new("Frame")
waterTube.Name = "WaterTube"
waterTube.Size = UDim2.new(0, 10, 0, 66)
waterTube.Position = UDim2.new(0, 31, 0, 22)
waterTube.BackgroundColor3 = Color3.fromRGB(20, 30, 40)
waterTube.BorderSizePixel = 0
waterTube.ZIndex = 2
waterTube.Parent = hudContainer

local waterFill = Instance.new("Frame")
waterFill.Name = "Fill"
waterFill.Size = UDim2.new(1, 0, 1, 0)
waterFill.Position = UDim2.new(0, 0, 0, 0)
waterFill.BackgroundColor3 = Color3.fromRGB(85, 195, 235)
waterFill.BorderSizePixel = 0
waterFill.ZIndex = 3
waterFill.Parent = waterTube

local waterCorner = Instance.new("UICorner")
waterCorner.CornerRadius = UDim.new(0, 4)
waterCorner.Parent = waterFill

-- Б) ДЕРЕВЯННАЯ КНОПКА РЮКЗАКА
local backpackBtn = Instance.new("ImageButton")
backpackBtn.Name = "OpenBackpackBtn"
backpackBtn.Size = UDim2.new(0, 60, 0, 60)
backpackBtn.Position = UDim2.new(0, 63, 0, 46)
backpackBtn.BackgroundTransparency = 1
backpackBtn.Image = "rbxassetid://106822265493004"
backpackBtn.ResampleMode = Enum.ResamplerMode.Pixelated
backpackBtn.ScaleType = Enum.ScaleType.Fit
backpackBtn.AutoButtonColor = false
backpackBtn.ZIndex = 4
backpackBtn.Parent = hudContainer

-- Бейдж горячей клавиши [E]
local bpKeyBadge = Instance.new("TextLabel")
bpKeyBadge.Name = "KeyBadge"
bpKeyBadge.Size = UDim2.new(0, 24, 0, 14)
bpKeyBadge.Position = UDim2.new(1, -2, 1, -2)
bpKeyBadge.AnchorPoint = Vector2.new(1, 1)
bpKeyBadge.BackgroundColor3 = Color3.fromRGB(38, 24, 15)
bpKeyBadge.BackgroundTransparency = 0.15
bpKeyBadge.Text = "[E]"
bpKeyBadge.TextColor3 = Color3.fromRGB(255, 230, 120)
bpKeyBadge.Font = Enum.Font.FredokaOne
bpKeyBadge.TextSize = 10
bpKeyBadge.ZIndex = 5
bpKeyBadge.Parent = backpackBtn

local bpKeyCorner = Instance.new("UICorner")
bpKeyCorner.CornerRadius = UDim.new(0, 4)
bpKeyCorner.Parent = bpKeyBadge


backpackBtn.MouseEnter:Connect(function()
    backpackBtn.ImageColor3 = Color3.fromRGB(255, 245, 210)
    tipLabel.Text = "🎒 Походный рюкзак котёнка [E] — Открыть сумки и ресурсы"
end)
backpackBtn.MouseLeave:Connect(function()
    backpackBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
    tipLabel.Text = DEFAULT_TIP_TEXT
end)

-- Интерактивные подсказки для шкал витальности
local energySensor = Instance.new("TextButton")
energySensor.Size = UDim2.new(0, 16, 0, 72)
energySensor.Position = UDim2.new(0, 10, 0, 18)
energySensor.BackgroundTransparency = 1
energySensor.Text = ""
energySensor.ZIndex = 5
energySensor.Parent = hudContainer
energySensor.MouseEnter:Connect(function()
    tipLabel.Text = "⚡ Энергия котёнка: 100/100 (Сытость и бодрость)"
end)
energySensor.MouseLeave:Connect(function()
    tipLabel.Text = DEFAULT_TIP_TEXT
end)

local waterSensor = Instance.new("TextButton")
waterSensor.Size = UDim2.new(0, 16, 0, 72)
waterSensor.Position = UDim2.new(0, 28, 0, 18)
waterSensor.BackgroundTransparency = 1
waterSensor.Text = ""
waterSensor.ZIndex = 5
waterSensor.Parent = hudContainer
waterSensor.MouseEnter:Connect(function()
    tipLabel.Text = "💧 Вода и Здоровье: 100/100 (Жажда утолена)"
end)
waterSensor.MouseLeave:Connect(function()
    tipLabel.Text = DEFAULT_TIP_TEXT
end)

-- В) НИЖНЯЯ ДЛИННАЯ ПОЛОСА ОПЫТА / ВЫНОСЛИВОСТИ
local expBarContainer = Instance.new("Frame")
expBarContainer.Name = "ExpBarContainer"
expBarContainer.Size = UDim2.new(0, 452, 0, 8)
expBarContainer.Position = UDim2.new(0, 138, 0, 99)
expBarContainer.BackgroundColor3 = Color3.fromRGB(45, 28, 18)
expBarContainer.BorderSizePixel = 0
expBarContainer.ZIndex = 3
expBarContainer.Parent = hudContainer

local expBarFill = Instance.new("Frame")
expBarFill.Name = "Fill"
expBarFill.Size = UDim2.new(0.68, 0, 1, 0)
expBarFill.Position = UDim2.new(0, 0, 0, 0)
expBarFill.BackgroundColor3 = Color3.fromRGB(154, 214, 100)
expBarFill.BorderSizePixel = 0
expBarFill.ZIndex = 4
expBarFill.Parent = expBarContainer

local expBarCorner = Instance.new("UICorner")
expBarCorner.CornerRadius = UDim.new(0, 3)
expBarCorner.Parent = expBarFill

local expSensor = Instance.new("TextButton")
expSensor.Size = UDim2.new(1, 0, 1, 6)
expSensor.Position = UDim2.new(0, 0, 0, -3)
expSensor.BackgroundTransparency = 1
expSensor.Text = ""
expSensor.ZIndex = 5
expSensor.Parent = expBarContainer
expSensor.MouseEnter:Connect(function()
    tipLabel.Text = "🌟 Уровень мастерства: 1 (Опыт: 68%)"
end)
expSensor.MouseLeave:Connect(function()
    tipLabel.Text = DEFAULT_TIP_TEXT
end)



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

-- Сохранение пропорций иллюстрации (1024 x 572 = 1.7895)
local aspectConstraint = Instance.new("UIAspectRatioConstraint")
aspectConstraint.AspectRatio = 1024 / 572
aspectConstraint.AspectType = Enum.AspectType.FitWithinMaxSize
aspectConstraint.DominantAxis = Enum.DominantAxis.Width
aspectConstraint.Parent = backpackModal

-- Фоновый арт лесной поляны с сумками и предметами
local modalBgImage = Instance.new("ImageLabel")
modalBgImage.Name = "BackpackBackgroundArt"
modalBgImage.Size = UDim2.new(1, 0, 1, 0)
modalBgImage.Position = UDim2.new(0, 0, 0, 0)
modalBgImage.BackgroundTransparency = 1
modalBgImage.Image = "rbxassetid://72625998602220"
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

-- Индикатор активной выбранной сумки (золотое сияние)
-- Индикатор активной выбранной сумки (деликатная мягкая подсветка только объекта, без жёлтых рамок)
local activeBagIndicator = Instance.new("Frame")
activeBagIndicator.Name = "ActiveBagIndicator"
activeBagIndicator.Size = UDim2.new(0.176, 0, 0.210, 0)
activeBagIndicator.Position = UDim2.new(0.354, 0, 0.138, 0)
activeBagIndicator.AnchorPoint = Vector2.new(0.5, 0.5)
activeBagIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
activeBagIndicator.BackgroundTransparency = 0.85
activeBagIndicator.ZIndex = 22
activeBagIndicator.Parent = backpackModal

local indCorner = Instance.new("UICorner")
indCorner.CornerRadius = UDim.new(0, 14)
indCorner.Parent = activeBagIndicator

-- 1. БЛОКНОТ (Книга рецептов и заданий)
local notebookBtn = Instance.new("TextButton")
notebookBtn.Name = "NotebookBtn"
notebookBtn.Size = UDim2.new(0.078, 0, 0.147, 0)
notebookBtn.Position = UDim2.new(0.225, 0, 0.157, 0)
notebookBtn.AnchorPoint = Vector2.new(0.5, 0.5)
notebookBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
notebookBtn.BackgroundTransparency = 1
notebookBtn.Text = ""
notebookBtn.ZIndex = 30
notebookBtn.Parent = backpackModal

local nbBtnCorner = Instance.new("UICorner")
nbBtnCorner.CornerRadius = UDim.new(0, 8)
nbBtnCorner.Parent = notebookBtn

-- 2. ПОРТФЕЛЬ / РЮКЗАК (Ресурсы и блоки)
local backpackTabBtn = Instance.new("TextButton")
backpackTabBtn.Name = "BackpackTabBtn"
backpackTabBtn.Size = UDim2.new(0.176, 0, 0.210, 0)
backpackTabBtn.Position = UDim2.new(0.354, 0, 0.138, 0)
backpackTabBtn.AnchorPoint = Vector2.new(0.5, 0.5)
backpackTabBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
backpackTabBtn.BackgroundTransparency = 1
backpackTabBtn.Text = ""
backpackTabBtn.ZIndex = 30
backpackTabBtn.Parent = backpackModal

local bpTabCorner = Instance.new("UICorner")
bpTabCorner.CornerRadius = UDim.new(0, 14)
bpTabCorner.Parent = backpackTabBtn

-- 3. СУМКА С ИНСТРУМЕНТАМИ (Топор, кирка, лопата)
local toolbagTabBtn = Instance.new("TextButton")
toolbagTabBtn.Name = "ToolbagTabBtn"
toolbagTabBtn.Size = UDim2.new(0.176, 0, 0.215, 0)
toolbagTabBtn.Position = UDim2.new(0.534, 0, 0.143, 0)
toolbagTabBtn.AnchorPoint = Vector2.new(0.5, 0.5)
toolbagTabBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
toolbagTabBtn.BackgroundTransparency = 1
toolbagTabBtn.Text = ""
toolbagTabBtn.ZIndex = 30
toolbagTabBtn.Parent = backpackModal

local tbTabCorner = Instance.new("UICorner")
tbTabCorner.CornerRadius = UDim.new(0, 14)
tbTabCorner.Parent = toolbagTabBtn

-- 4. КОРЗИНКА (Еда, ягоды, грибы, припасы)
local basketTabBtn = Instance.new("TextButton")
basketTabBtn.Name = "BasketTabBtn"
basketTabBtn.Size = UDim2.new(0.110, 0, 0.205, 0)
basketTabBtn.Position = UDim2.new(0.684, 0, 0.145, 0)
basketTabBtn.AnchorPoint = Vector2.new(0.5, 0.5)
basketTabBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
basketTabBtn.BackgroundTransparency = 1
basketTabBtn.Text = ""
basketTabBtn.ZIndex = 30
basketTabBtn.Parent = backpackModal

local bskTabCorner = Instance.new("UICorner")
bskTabCorner.CornerRadius = UDim.new(0, 14)
bskTabCorner.Parent = basketTabBtn

-- 5. КАРТА (Остров котёнка)
local mapBtn = Instance.new("TextButton")
mapBtn.Name = "MapBtn"
mapBtn.Size = UDim2.new(0.166, 0, 0.210, 0)
mapBtn.Position = UDim2.new(0.820, 0, 0.154, 0)
mapBtn.AnchorPoint = Vector2.new(0.5, 0.5)
mapBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mapBtn.BackgroundTransparency = 1
mapBtn.Text = ""
mapBtn.ZIndex = 30
mapBtn.Parent = backpackModal

local mapBtnCorner = Instance.new("UICorner")
mapBtnCorner.CornerRadius = UDim.new(0, 12)
mapBtnCorner.Parent = mapBtn

-- 6. КРЕСТИК ЗАКРЫТИЯ [X]
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0.029, 0, 0.046, 0)
closeBtn.Position = UDim2.new(0.976, 0, 0.059, 0)
closeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = ""
closeBtn.ZIndex = 35
closeBtn.Parent = backpackModal

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseEnter:Connect(function()
    closeBtn.BackgroundTransparency = 0.82
    showTooltip("Закрыть [Esc]")
end)
closeBtn.MouseLeave:Connect(function()
    closeBtn.BackgroundTransparency = 1
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
    gearBtn.BackgroundTransparency = 0.88
    showTooltip("⚙️ Настройки игры")
end)
gearBtn.MouseLeave:Connect(function()
    gearBtn.BackgroundTransparency = 1
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

    -- Иконка/эмодзи предмета
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
            halo.BackgroundTransparency = 0.85
        end
    end)
    btn.MouseLeave:Connect(function()
        if not btn:GetAttribute("IsSelected") then
            halo.BackgroundTransparency = 1
        end
    end)

    return btn
end

-- Создание слота в деревянном хотбаре (1–9 слоты)
local function createHotbarSlotUI(parent, slotIndex, pos)
    local btn = Instance.new("TextButton")
    btn.Name = "HotbarSlot_" .. slotIndex
    btn.Size = UDim2.new(0, 48, 0, 48)
    btn.Position = pos
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.ZIndex = 5
    btn.Parent = parent

    -- Базовая деревянная рамка слота (пиксельный стиль)
    local normalFrame = Instance.new("ImageLabel")
    normalFrame.Name = "NormalFrame"
    normalFrame.Size = UDim2.new(1, 0, 1, 0)
    normalFrame.Position = UDim2.new(0, 0, 0, 0)
    normalFrame.BackgroundTransparency = 1
    normalFrame.Image = "rbxassetid://134703361876239"
    normalFrame.ResampleMode = Enum.ResamplerMode.Pixelated
    normalFrame.ScaleType = Enum.ScaleType.Fit
    normalFrame.ZIndex = 6
    normalFrame.Parent = btn

    -- Белая акцентная рамка активного выбранного слота (как слот 2 на изображении)
    local activeFrame = Instance.new("ImageLabel")
    activeFrame.Name = "ActiveFrame"
    activeFrame.Size = UDim2.new(1, 0, 1, 0)
    activeFrame.Position = UDim2.new(0, 0, 0, 0)
    activeFrame.BackgroundTransparency = 1
    activeFrame.Image = "rbxassetid://75125194643262"
    activeFrame.ResampleMode = Enum.ResamplerMode.Pixelated
    activeFrame.ScaleType = Enum.ScaleType.Fit
    activeFrame.Visible = (slotIndex == activeHotbarSlot)
    activeFrame.ZIndex = 7
    activeFrame.Parent = btn

    -- Номер слота (1..9) в левом верхнем углу
    local keyLbl = Instance.new("TextLabel")
    keyLbl.Name = "KeyLabel"
    keyLbl.Size = UDim2.new(0, 14, 0, 14)
    keyLbl.Position = UDim2.new(0, 4, 0, 3)
    keyLbl.BackgroundTransparency = 1
    keyLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyLbl.TextStrokeTransparency = 0.35
    keyLbl.TextStrokeColor3 = Color3.fromRGB(25, 18, 12)
    keyLbl.Font = Enum.Font.FredokaOne
    keyLbl.TextSize = 10
    keyLbl.Text = tostring(slotIndex)
    keyLbl.ZIndex = 8
    keyLbl.Parent = btn

    -- Иконка предмета в центре
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "IconLabel"
    iconLabel.Size = UDim2.new(0, 28, 0, 26)
    iconLabel.Position = UDim2.new(0.5, 0, 0.46, 0)
    iconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Font = Enum.Font.FredokaOne
    iconLabel.TextSize = 19
    iconLabel.Text = ""
    iconLabel.ZIndex = 8
    iconLabel.Parent = btn

    -- Мини-кубик цвета (если нет эмодзи)
    local colorBox = Instance.new("Frame")
    colorBox.Name = "ColorBox"
    colorBox.Size = UDim2.new(0, 18, 0, 18)
    colorBox.Position = UDim2.new(0.5, 0, 0.46, 0)
    colorBox.AnchorPoint = Vector2.new(0.5, 0.5)
    colorBox.BorderSizePixel = 0
    colorBox.Visible = false
    colorBox.ZIndex = 8
    colorBox.Parent = btn

    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 4)
    cbCorner.Parent = colorBox

    -- Счётчик количества предметов (в правом нижнем углу)
    local countLbl = Instance.new("TextLabel")
    countLbl.Name = "CountLabel"
    countLbl.Size = UDim2.new(0, 24, 0, 12)
    countLbl.Position = UDim2.new(1, -3, 1, -5)
    countLbl.AnchorPoint = Vector2.new(1, 1)
    countLbl.BackgroundTransparency = 1
    countLbl.TextColor3 = Color3.fromRGB(255, 240, 140)
    countLbl.TextStrokeTransparency = 0.3
    countLbl.TextStrokeColor3 = Color3.fromRGB(20, 15, 10)
    countLbl.Font = Enum.Font.FredokaOne
    countLbl.TextSize = 10
    countLbl.TextXAlignment = Enum.TextXAlignment.Right
    countLbl.Text = ""
    countLbl.ZIndex = 8
    countLbl.Parent = btn

    -- Мини-полоска под предметом (как на первом изображении: полоска ресурса/прочности)
    local miniBar = Instance.new("Frame")
    miniBar.Name = "MiniBar"
    miniBar.Size = UDim2.new(0, 28, 0, 3)
    miniBar.Position = UDim2.new(0.5, -14, 1, -7)
    miniBar.BackgroundColor3 = Color3.fromRGB(35, 22, 14)
    miniBar.BorderSizePixel = 0
    miniBar.Visible = false
    miniBar.ZIndex = 8
    miniBar.Parent = btn

    local miniFill = Instance.new("Frame")
    miniFill.Name = "Fill"
    miniFill.Size = UDim2.new(0.8, 0, 1, 0)
    miniFill.BackgroundColor3 = Color3.fromRGB(130, 215, 80)
    miniFill.BorderSizePixel = 0
    miniFill.ZIndex = 9
    miniFill.Parent = miniBar

    -- Наведение курсора
    btn.MouseEnter:Connect(function()
        if not (slotIndex == activeHotbarSlot) then
            normalFrame.ImageColor3 = Color3.fromRGB(255, 242, 215)
        end
        local slotData = currentInventorySlots[slotIndex]
        if slotData and slotData.count > 0 then
            local def = itemsDefinition[slotData.id] or { name = slotData.id }
            tipLabel.Text = string.format("Слот %d: %s (%d шт.)", slotIndex, def.name or slotData.id, slotData.count)
        else
            tipLabel.Text = string.format("Слот %d: Пусто", slotIndex)
        end
    end)
    btn.MouseLeave:Connect(function()
        normalFrame.ImageColor3 = Color3.fromRGB(255, 255, 255)
        tipLabel.Text = DEFAULT_TIP_TEXT
    end)

    return btn
end

local refreshAllInventoryUI

-- Собираем 9 слотов деревянного хотбара (1–9)
for i = 1, 9 do
    local xPos = 140 + (i - 1) * 50
    local btn = createHotbarSlotUI(
        hudContainer,
        i,
        UDim2.new(0, xPos, 0, 46)
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

-- Переключение активной сумки (подсветка строго по габаритам сумки, без рамок)
local function setActiveBagTab(tab)
    activeBagTab = tab
    selectedBackpackSlot = nil

    if tab == "backpack" then
        activeBagIndicator.Position = UDim2.new(0.354, 0, 0.138, 0)
        activeBagIndicator.Size = UDim2.new(0.176, 0, 0.210, 0)
        indCorner.CornerRadius = UDim.new(0, 14)
        bagTitleBadge.Text = "🎒 Портфель: Ресурсы и блоки"
    elseif tab == "toolbag" then
        activeBagIndicator.Position = UDim2.new(0.534, 0, 0.143, 0)
        activeBagIndicator.Size = UDim2.new(0.176, 0, 0.215, 0)
        indCorner.CornerRadius = UDim.new(0, 14)
        bagTitleBadge.Text = "🧰 Сумка: Походные инструменты"
    elseif tab == "basket" then
        activeBagIndicator.Position = UDim2.new(0.684, 0, 0.145, 0)
        activeBagIndicator.Size = UDim2.new(0.110, 0, 0.205, 0)
        indCorner.CornerRadius = UDim.new(0, 14)
        bagTitleBadge.Text = "🧺 Корзинка: Еда, ягоды и припасы"
    end

    refreshAllInventoryUI()
end

backpackTabBtn.MouseButton1Click:Connect(function() setActiveBagTab("backpack") end)
backpackTabBtn.MouseEnter:Connect(function()
    if activeBagTab ~= "backpack" then backpackTabBtn.BackgroundTransparency = 0.90 end
    showTooltip("🎒 Портфель (Ресурсы и блоки)")
end)
backpackTabBtn.MouseLeave:Connect(function()
    backpackTabBtn.BackgroundTransparency = 1
    hideTooltip()
end)

toolbagTabBtn.MouseButton1Click:Connect(function() setActiveBagTab("toolbag") end)
toolbagTabBtn.MouseEnter:Connect(function()
    if activeBagTab ~= "toolbag" then toolbagTabBtn.BackgroundTransparency = 0.90 end
    showTooltip("🧰 Сумка (Инструменты)")
end)
toolbagTabBtn.MouseLeave:Connect(function()
    toolbagTabBtn.BackgroundTransparency = 1
    hideTooltip()
end)

basketTabBtn.MouseButton1Click:Connect(function() setActiveBagTab("basket") end)
basketTabBtn.MouseEnter:Connect(function()
    if activeBagTab ~= "basket" then basketTabBtn.BackgroundTransparency = 0.90 end
    showTooltip("🧺 Корзинка (Еда и сбор)")
end)
basketTabBtn.MouseLeave:Connect(function()
    basketTabBtn.BackgroundTransparency = 1
    hideTooltip()
end)

sortBtn.MouseButton1Click:Connect(function()
    voxelRemote:FireServer("SortInventory", { containerType = activeBagTab })
end)

-- Обновление одного слота на траве (мягкая круглая подсветка выбранного предмета, без рамок)
local function renderGrassSlotUI(btn, slotData, isSelected)
    local halo = btn:FindFirstChild("Halo")
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

        if def.icon and def.icon ~= "" then
            iconLabel.Text = def.icon
            iconLabel.Visible = true
            colorBox.Visible = false
        else
            colorBox.BackgroundColor3 = def.color or Color3.fromRGB(150, 150, 150)
            colorBox.Visible = true
            iconLabel.Visible = false
        end

        nameLbl.Text = def.name or slotData.id
        nameLbl.Visible = true
        countLbl.Text = slotData.count > 1 and ("x" .. slotData.count) or ""
        countLbl.Visible = true

        if isSelected then
            if halo then halo.BackgroundTransparency = 0.65 end
        else
            if halo then halo.BackgroundTransparency = 1 end
        end
    else
        btn:SetAttribute("HasItem", false)
        btn:SetAttribute("IsSelected", false)
        iconLabel.Visible = false
        colorBox.Visible = false
        nameLbl.Visible = false
        countLbl.Visible = false
        if halo then halo.BackgroundTransparency = 1 end
    end
end

-- Обновление одного слота деревянного хотбара
local function renderHotbarSlotUI(btn, slotData, isActive)
    local normalFrame = btn:FindFirstChild("NormalFrame")
    local activeFrame = btn:FindFirstChild("ActiveFrame")
    local iconLabel = btn:FindFirstChild("IconLabel")
    local colorBox = btn:FindFirstChild("ColorBox")
    local countLbl = btn:FindFirstChild("CountLabel")
    local miniBar = btn:FindFirstChild("MiniBar")
    local miniFill = miniBar and miniBar:FindFirstChild("Fill")

    if activeFrame then
        activeFrame.Visible = isActive
    end

    if slotData and slotData.count > 0 then
        local def = itemsDefinition[slotData.id] or {
            name = slotData.id,
            icon = "📦",
            color = Color3.fromRGB(150, 150, 150)
        }

        if def.icon and def.icon ~= "" then
            iconLabel.Text = def.icon
            iconLabel.Visible = true
            if colorBox then colorBox.Visible = false end
        else
            if colorBox then
                colorBox.BackgroundColor3 = def.color or Color3.fromRGB(150, 150, 150)
                colorBox.Visible = true
            end
            iconLabel.Visible = false
        end

        countLbl.Text = slotData.count > 1 and tostring(slotData.count) or ""
        countLbl.Visible = true

        -- Мини-полоска ресурса/прочности внизу слота (как на первом скриншоте)
        if miniBar then
            miniBar.Visible = true
            local ratio = math.clamp(slotData.count / (slotData.max or 64), 0.25, 1.0)
            if miniFill then
                miniFill.Size = UDim2.new(ratio, 0, 1, 0)
                if def.category == "tools" then
                    miniFill.BackgroundColor3 = Color3.fromRGB(130, 215, 80) -- зеленый для инструментов
                elseif def.category == "food" then
                    miniFill.BackgroundColor3 = Color3.fromRGB(240, 120, 140) -- розоватый для еды (как слот 9 на фото)
                else
                    miniFill.BackgroundColor3 = Color3.fromRGB(230, 190, 90) -- золотистый для блоков/ресурсов
                end
            end
        end
    else
        iconLabel.Visible = false
        if colorBox then colorBox.Visible = false end
        countLbl.Text = ""
        countLbl.Visible = false
        if miniBar then miniBar.Visible = false end
    end
end

-- Полная перерисовка интерфейса
refreshAllInventoryUI = function()
    -- 1. Обновляем хотбар внизу (все 9 слотов)
    for i = 1, 9 do
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
    notebookBtn.BackgroundTransparency = 0.88
    showTooltip("📖 Блокнот: Рецепты и Задания")
end)
notebookBtn.MouseLeave:Connect(function()
    notebookBtn.BackgroundTransparency = 1
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
    mapBtn.BackgroundTransparency = 0.88
    showTooltip("🗺️ Карта Острова")
end)
mapBtn.MouseLeave:Connect(function()
    mapBtn.BackgroundTransparency = 1
    hideTooltip()
end)

-- 3. ОКНО НАСТРОЕК (Шестеренка)
local settingsModal = Instance.new("Frame")
settingsModal.Name = "SettingsModal"
settingsModal.Size = UDim2.new(0.50, 0, 0.58, 0)
settingsModal.Position = UDim2.new(0.5, 0, 0.5, 0)
settingsModal.AnchorPoint = Vector2.new(0.5, 0.5)
settingsModal.BackgroundColor3 = Color3.fromRGB(36, 28, 22)
settingsModal.Visible = false
settingsModal.ZIndex = 50
settingsModal.Parent = backpackModal

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
setTitle.Text = "⚙️ Настройки игры"
setTitle.TextColor3 = Color3.fromRGB(255, 225, 140)
setTitle.Font = Enum.Font.FredokaOne
setTitle.TextSize = 18
setTitle.TextXAlignment = Enum.TextXAlignment.Left
setTitle.ZIndex = 51
setTitle.Parent = settingsModal

local setClose = Instance.new("TextButton")
setClose.Size = UDim2.new(0, 32, 0, 32)
setClose.Position = UDim2.new(1, -44, 0, 14)
setClose.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
setClose.Text = "✕"
setClose.TextColor3 = Color3.fromRGB(255, 255, 255)
setClose.Font = Enum.Font.FredokaOne
setClose.TextSize = 16
setClose.ZIndex = 51
setClose.Parent = settingsModal
local setCloseCorner = Instance.new("UICorner")
setCloseCorner.CornerRadius = UDim.new(0, 8)
setCloseCorner.Parent = setClose
setClose.MouseButton1Click:Connect(function() settingsModal.Visible = false end)

local soundBtn = Instance.new("TextButton")
soundBtn.Size = UDim2.new(1, -40, 0, 38)
soundBtn.Position = UDim2.new(0, 20, 0, 60)
soundBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 32)
soundBtn.Text = "🔊 Звуки окружения: ВКЛЮЧЕНО"
soundBtn.TextColor3 = Color3.fromRGB(255, 240, 200)
soundBtn.Font = Enum.Font.FredokaOne
soundBtn.TextSize = 13
soundBtn.ZIndex = 51
soundBtn.Parent = settingsModal
local sbCorner = Instance.new("UICorner")
sbCorner.CornerRadius = UDim.new(0, 8)
sbCorner.Parent = soundBtn
local soundOn = true
soundBtn.MouseButton1Click:Connect(function()
    soundOn = not soundOn
    soundBtn.Text = soundOn and "🔊 Звуки окружения: ВКЛЮЧЕНО" or "🔇 Звуки окружения: ВЫКЛЮЧЕНО"
end)

local camBtn = Instance.new("TextButton")
camBtn.Size = UDim2.new(1, -40, 0, 38)
camBtn.Position = UDim2.new(0, 20, 0, 110)
camBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 32)
camBtn.Text = "🐱 Взгляд котёнка на курсор: ВКЛЮЧЕНО"
camBtn.TextColor3 = Color3.fromRGB(255, 240, 200)
camBtn.Font = Enum.Font.FredokaOne
camBtn.TextSize = 13
camBtn.ZIndex = 51
camBtn.Parent = settingsModal
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

-- Переключение слотов 1–9 и открытие рюкзака по клавишам
local SLOT_KEY_MAP = {
    [Enum.KeyCode.One]   = 1,
    [Enum.KeyCode.Two]   = 2,
    [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four]  = 4,
    [Enum.KeyCode.Five]  = 5,
    [Enum.KeyCode.Six]   = 6,
    [Enum.KeyCode.Seven] = 7,
    [Enum.KeyCode.Eight] = 8,
    [Enum.KeyCode.Nine]  = 9,
}

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.B then
        setBackpackOpen(not isBackpackOpen)
    elseif input.KeyCode == Enum.KeyCode.Escape and isBackpackOpen then
        setBackpackOpen(false)
    elseif not isBackpackOpen then
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
    -- Если игрок наводит мышку на любой блок в радиусе досягаемости (до 15.0 studs ~ 10 блоков)
    local mousePos = UserInputService:GetMouseLocation()
    local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
    local mouseResult = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 300, params)

    if mouseResult and mouseResult.Instance then
        local distToCat = (mouseResult.Position - root.Position).Magnitude
        if distToCat <= 15.0 then
            return mouseResult.Instance, mouseResult.Normal
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

local function doDigStep()
    local character = player.Character
    if not character or isBackpackOpen then return end

    if currentTargetBlock then
        character:SetAttribute("TargetLookPos", currentTargetBlock.Position)
        local root = character:FindFirstChild("HumanoidRootPart")
        if root and currentTargetBlock.Position.Y >= (root.Position.Y - 0.2) then
            character:SetAttribute("IsDiggingUp", true)
            character:SetAttribute("IsDigging", false)
        else
            character:SetAttribute("IsDigging", true)
            character:SetAttribute("IsDiggingUp", false)
        end
        voxelRemote:FireServer("Hit", { Block = currentTargetBlock })
    end
end

local function doPlaceStep()
    local character = player.Character
    if not character or isBackpackOpen or isPlacingCooldown or not currentTargetBlock or not currentTargetNormal then return end

    local activeItem = currentInventorySlots[activeHotbarSlot]
    if not (activeItem and activeItem.count > 0) then return end

    local def = itemsDefinition[activeItem.id]
    if not (def and def.isBlock) then return end

    local root = character:FindFirstChild("HumanoidRootPart")
    local newPos = snapToGrid(currentTargetBlock.Position + (currentTargetNormal * BLOCK_SIZE), BLOCK_SIZE)
    character:SetAttribute("TargetLookPos", newPos)

    -- Проверяем, ставится ли блок НАВЕРХ
    local isUpwards = false
    if root then
        -- Если ставится на верхнюю грань блока или позиция нового блока выше уровня лапок котика
        if (currentTargetNormal.Y > 0.5 and currentTargetBlock.Position.Y >= (root.Position.Y - 0.75)) or
           (newPos.Y >= root.Position.Y - 0.1) then
            isUpwards = true
        end
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
RunService.Heartbeat:Connect(function()
    if isDiggingKeyHeld and not isBackpackOpen then
        if tick() - lastDigTick > 0.55 then
            lastDigTick = tick()
            doDigStep()
        end
    end
end)
