-- LocalScript: StarterPlayer -> StarterCharacterScripts -> PixelCharacter
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- === 1. ХИТБОКС И ФИЗИЧЕСКИЕ СВОЙСТВА (ЕСТЕСТВЕННАЯ ХОДЬБА С ЦЕПКИМ СЦЕПЛЕНИЕМ) ===
-- Симметричный компактный хитбокс (1.2 x 1.4 x 1.2 studs)
-- Одинаковая ширина и длина исключают провалы в землю при поворотах на любой угол
rootPart.Size = Vector3.new(1.2, 1.4, 1.2)
rootPart.CanCollide = true
-- Плотное сцепление с поверхностью (Friction = 0.85) — котик не скользит как по льду, а уверенно ступает
rootPart.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.85, 0.0, 1.0, 1.0)

humanoid.HipHeight = 0.914
humanoid.MaxSlopeAngle = 45
humanoid.AutoJumpEnabled = false
-- Естественная скорость шага котенка (9.5 studs/sec вместо неестественного сверхзвукового 16)
humanoid.WalkSpeed = 9.5
humanoid.AutoRotate = false

humanoid.UseJumpPower = false
humanoid.JumpHeight = 3.6

local catModel = Instance.new("Model")
catModel.Name = "VoxelChibiCat"
catModel.Parent = character

-- Скрываем части стандартного аватара и отключаем тени от невидимого тела
local function hideCharacterPart(desc)
    if desc:IsDescendantOf(catModel) then return end
    if desc:IsA("BasePart") then
        if desc.Name ~= "HumanoidRootPart" then
            desc.Transparency = 1
        end
        desc.CanCollide = false
        desc.CastShadow = false
    elseif desc:IsA("Decal") then
        desc.Transparency = 1
    end
end

for _, desc in ipairs(character:GetDescendants()) do
    hideCharacterPart(desc)
end
character.DescendantAdded:Connect(hideCharacterPart)

if rootPart then
    rootPart.CastShadow = false
end

-- Отключаем коллизии стандартных скрытых частей персонажа каждый шаг физики,
-- чтобы они не цеплялись за землю и не вызывали проваливания котика,
-- но ГАРАНТИРУЕМ коллизии для туловища и головы котёнка, чтобы он никогда не проходил сквозь блоки
RunService.Stepped:Connect(function()
    for _, desc in ipairs(character:GetChildren()) do
        if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
            desc.CanCollide = false
        end
    end
    if torso and torso.Parent then
        torso.CanCollide = true
    end
    if head and head.Parent then
        head.CanCollide = true
    end
end)

-- === 2. ПЛАВНЫЙ ПОВОРОТ ТЕЛА КОТЁНКА ===
local rootAttachment = Instance.new("Attachment")
rootAttachment.Name = "CatOrientationAttachment"
rootAttachment.Parent = rootPart

local alignOrient = Instance.new("AlignOrientation")
alignOrient.Name = "CatSmoothTurn"
alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
alignOrient.Attachment0 = rootAttachment
alignOrient.Responsiveness = 25
alignOrient.MaxAngularVelocity = 35
alignOrient.MaxTorque = 500000
alignOrient.CFrame = rootPart.CFrame
alignOrient.Parent = rootPart

-- === 3. ВИЗУАЛЬНЫЕ ЧАСТИ КОТИКА ===
local COLOR_BLACK = Color3.fromRGB(24, 24, 26)
local COLOR_WHITE = Color3.fromRGB(250, 250, 255)
local COLOR_PINK  = Color3.fromRGB(255, 150, 175)
local COLOR_EYE   = Color3.fromRGB(255, 215, 0)
local COLOR_PUPIL = Color3.fromRGB(15, 15, 15)

local function createPart(name, size, color, parent)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = color
    p.Transparency = 0
    p.Material = Enum.Material.SmoothPlastic
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Massless = true
    p.CastShadow = true
    p.Parent = parent
    return p
end

local function createWedge(name, size, color, parent)
    local w = Instance.new("WedgePart")
    w.Name = name
    w.Size = size
    w.Color = color
    w.Transparency = 0
    w.Material = Enum.Material.SmoothPlastic
    w.CanCollide = false
    w.CanQuery = false
    w.CanTouch = false
    w.Massless = true
    w.CastShadow = true
    w.Parent = parent
    return w
end

local function weldParts(p0, p1, c0)
    local w = Instance.new("Weld")
    w.Part0 = p0
    w.Part1 = p1
    w.C0 = c0
    w.Parent = p0
    return w
end

local function createMotor(p0, p1, c0)
    local m = Instance.new("Motor6D")
    m.Part0 = p0
    m.Part1 = p1
    m.C0 = c0
    m.Parent = p0
    return m
end

-- Высота посадки туловища: лапки стоят ровно на блоках земли, не утопая в траве
local TORSO_Y_OFFSET = -0.84
local torso = createPart("CatTorso", Vector3.new(1.3, 0.9, 1.4), COLOR_BLACK, catModel)
torso.CanCollide = true
torso.CanQuery = true
torso.CanTouch = true
torso.Massless = true
torso.CustomPhysicalProperties = PhysicalProperties.new(0.8, 0.3, 0.0, 1.0, 1.0)
local torsoJoint = createMotor(rootPart, torso, CFrame.new(0, TORSO_Y_OFFSET, 0.05))

-- ГОЛОВА (сидит прямо над грудкой и передними лапками, милые чиби-пропорции)
local head = createPart("CatHead", Vector3.new(1.5, 1.3, 1.3), COLOR_BLACK, catModel)
head.CanCollide = true
head.CanQuery = true
head.CanTouch = true
head.Massless = true
head.CustomPhysicalProperties = PhysicalProperties.new(0.8, 0.3, 0.0, 1.0, 1.0)
local headJoint = createMotor(torso, head, CFrame.new(0, 0.68, -0.65))

-- НАСТОЯЩИЕ ТРЕУГОЛЬНЫЕ КОШАЧЬИ УШКИ
-- Left Ear
local rotLeft = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
local tiltLeft = CFrame.Angles(0, 0, math.rad(10))
local leftEar = createWedge("LeftEar", Vector3.new(0.18, 0.48, 0.44), COLOR_BLACK, catModel)
weldParts(head, leftEar, CFrame.new(-0.46, 0.76, -0.05) * tiltLeft * rotLeft)

local leftEarIn = createWedge("LeftEarIn", Vector3.new(0.06, 0.36, 0.32), COLOR_PINK, catModel)
weldParts(leftEar, leftEarIn, CFrame.new(0.08, -0.05, 0.04))

-- Right Ear
local rotRight = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0))
local tiltRight = CFrame.Angles(0, 0, math.rad(-10))
local rightEar = createWedge("RightEar", Vector3.new(0.18, 0.48, 0.44), COLOR_BLACK, catModel)
weldParts(head, rightEar, CFrame.new(0.46, 0.76, -0.05) * tiltRight * rotRight)

local rightEarIn = createWedge("RightEarIn", Vector3.new(0.06, 0.36, 0.32), COLOR_PINK, catModel)
weldParts(rightEar, rightEarIn, CFrame.new(-0.08, -0.05, 0.04))

-- ГЛАЗКИ
local function createEye(offset, isLeft)
    local eyeBg = createPart("EyeBg", Vector3.new(0.35, 0.45, 0.05), COLOR_EYE, catModel)
    weldParts(head, eyeBg, CFrame.new(offset.X, offset.Y, -0.66))

    local pupil = createPart("Pupil", Vector3.new(0.16, 0.35, 0.06), COLOR_PUPIL, catModel)
    weldParts(eyeBg, pupil, CFrame.new(0, 0, -0.02))

    local shine = createPart("Shine", Vector3.new(0.1, 0.1, 0.07), COLOR_WHITE, catModel)
    weldParts(eyeBg, shine, CFrame.new(isLeft and 0.08 or -0.08, 0.12, -0.03))
end
createEye(Vector3.new(-0.4, 0.05, 0), true)
createEye(Vector3.new(0.4, 0.05, 0), false)

-- НОСИК
local nose = createPart("Nose", Vector3.new(0.18, 0.14, 0.1), COLOR_PINK, catModel)
weldParts(head, nose, CFrame.new(0, -0.18, -0.68))

-- 4 ЛАПКИ С БЕЛЫМИ НОСОЧКАМИ
local function createPaw(name, relPos)
    local pawBase = createPart(name, Vector3.new(0.34, 0.65, 0.34), COLOR_BLACK, catModel)
    local motor = createMotor(torso, pawBase, CFrame.new(relPos.X, relPos.Y, relPos.Z))

    local sock = createPart(name .. "_Sock", Vector3.new(0.36, 0.30, 0.36), COLOR_WHITE, catModel)
    weldParts(pawBase, sock, CFrame.new(0, -0.21, 0))

    return {
        base = pawBase,
        motor = motor,
        origC0 = motor.C0,
        relPos = relPos,
        sock = sock,
        currentY = relPos.Y,
        wasInAir = false,
        lastGroundHit = nil
    }
end

local pawFL = createPaw("Paw_FrontLeft",  Vector3.new(-0.45, -0.4, -0.50))
local pawFR = createPaw("Paw_FrontRight", Vector3.new( 0.45, -0.4, -0.50))
local pawBL = createPaw("Paw_BackLeft",   Vector3.new(-0.45, -0.4,  0.50))
local pawBR = createPaw("Paw_BackRight",  Vector3.new( 0.45, -0.4,  0.50))
local allPaws = { pawFL, pawFR, pawBL, pawBR }

-- === СИСТЕМА ИДЕАЛЬНОГО ПРИМАГНИЧИВАНИЯ ЛАПОК К ЗЕМЛЕ (FOOT GROUND SNAPPING) ===
-- Расстояние от центра pawBase до нижней плоской поверхности белого носочка:
-- offset (-0.21) + half-size (0.30 / 2) = 0.36 studs.
local PAW_BOTTOM_OFFSET = 0.36

local groundRayParams = RaycastParams.new()
groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
groundRayParams.IgnoreWater = true

local function updateGroundRayFilter()
    local filterList = { character }
    local lootFolder = workspace:FindFirstChild("VoxelLoot")
    if lootFolder then table.insert(filterList, lootFolder) end
    groundRayParams.FilterDescendantsInstances = filterList
end
updateGroundRayFilter()

local function getPawTargetLocalY(paw)
    local worldPos = torso.CFrame:PointToWorldSpace(paw.relPos)
    -- Луч строго вниз от уровня туловища
    local rayOrigin = Vector3.new(worldPos.X, rootPart.Position.Y + 0.8, worldPos.Z)
    local rayDir = Vector3.new(0, -3.2, 0)
    local hit = workspace:Raycast(rayOrigin, rayDir, groundRayParams)
    paw.lastGroundHit = hit
    if hit then
        local targetBaseWorldY = hit.Position.Y + PAW_BOTTOM_OFFSET
        local targetLocal = torso.CFrame:PointToObjectSpace(Vector3.new(worldPos.X, targetBaseWorldY, worldPos.Z))
        -- Ограничиваем естественный диапазон сустава (+-0.28 studs), чтобы лапка не растягивалась в пустоту
        return math.clamp(targetLocal.Y, paw.relPos.Y - 0.28, paw.relPos.Y + 0.28)
    end
    return paw.relPos.Y
end

-- ХВОСТИК
local tail = createPart("Tail", Vector3.new(0.24, 0.65, 0.24), COLOR_BLACK, catModel)
local tailMotor = createMotor(torso, tail, CFrame.new(0, 0.4, 0.75) * CFrame.Angles(math.rad(45), 0, 0))
local tailOrigC0 = tailMotor.C0

local tailTip = createPart("TailTip", Vector3.new(0.26, 0.3, 0.26), COLOR_WHITE, catModel)
weldParts(tail, tailTip, CFrame.new(0, 0.35, 0))

-- === 3D ПОХОДНЫЙ РЮКЗАК НА СПИНЕ КОТЁНКА С РЕМНЯМИ ВОКРУГ ЖИВОТИКА И ГРУДИ ===
local COLOR_LEATHER_MAIN = Color3.fromRGB(115, 75, 45)  -- коричневая кожа рюкзака
local COLOR_LEATHER_DARK = Color3.fromRGB(80, 50, 30)   -- темная кожа для ремней и клапана
local COLOR_LEATHER_POCK = Color3.fromRGB(102, 65, 38)  -- накладной задний карман
local COLOR_BEDROLL      = Color3.fromRGB(155, 140, 110) -- скрученный походный спальник
local COLOR_GOLD_BUCKLE  = Color3.fromRGB(245, 210, 110) -- золотые металлические пряжки

-- 1. Основное отделение рюкзака на спинке котенка
local backpackMain = createPart("BackpackMain", Vector3.new(0.85, 0.52, 0.60), COLOR_LEATHER_MAIN, catModel)
weldParts(torso, backpackMain, CFrame.new(0, 0.71, 0.08))

-- 2. Верхний клапан (крышка рюкзака)
local backpackFlap = createPart("BackpackFlap", Vector3.new(0.88, 0.12, 0.52), COLOR_LEATHER_DARK, catModel)
weldParts(backpackMain, backpackFlap, CFrame.new(0, 0.26, -0.02) * CFrame.Angles(math.rad(8), 0, 0))

-- 3. Скрученный походный спальник / коврик сверху рюкзака
local bedroll = createPart("BackpackBedroll", Vector3.new(0.88, 0.22, 0.22), COLOR_BEDROLL, catModel)
weldParts(backpackMain, bedroll, CFrame.new(0, 0.35, -0.12))

-- Ремешки-стяжки спальника (левый и правый)
local bedrollStrapL = createPart("BedrollStrapL", Vector3.new(0.06, 0.24, 0.24), COLOR_LEATHER_DARK, catModel)
weldParts(backpackMain, bedrollStrapL, CFrame.new(-0.28, 0.35, -0.12))

local bedrollStrapR = createPart("BedrollStrapR", Vector3.new(0.06, 0.24, 0.24), COLOR_LEATHER_DARK, catModel)
weldParts(backpackMain, bedrollStrapR, CFrame.new(0.28, 0.35, -0.12))

-- 4. Задний накладной кармашек (виден игроку со спины)
local backpackPocket = createPart("BackpackPocket", Vector3.new(0.56, 0.28, 0.16), COLOR_LEATHER_POCK, catModel)
weldParts(backpackMain, backpackPocket, CFrame.new(0, -0.06, 0.32))

-- Золотые пряжки на клапане и кармане
local buckleL = createPart("BackpackBuckleL", Vector3.new(0.08, 0.10, 0.04), COLOR_GOLD_BUCKLE, catModel)
weldParts(backpackMain, buckleL, CFrame.new(-0.24, 0.12, 0.31))

local buckleR = createPart("BackpackBuckleR", Vector3.new(0.08, 0.10, 0.04), COLOR_GOLD_BUCKLE, catModel)
weldParts(backpackMain, buckleR, CFrame.new(0.24, 0.12, 0.31))

local bucklePocket = createPart("PocketBuckle", Vector3.new(0.09, 0.09, 0.04), COLOR_GOLD_BUCKLE, catModel)
weldParts(backpackPocket, bucklePocket, CFrame.new(0, 0.02, 0.09))

-- 5. РЕМНИ КРЕПЛЕНИЯ ВОКРУГ ТЕЛА КОТЁНКА:
-- А) Ремень через животик котика (проходит под пузиком)
local bellyStrap = createPart("BellyStrap", Vector3.new(1.32, 0.06, 0.18), COLOR_LEATHER_DARK, catModel)
weldParts(torso, bellyStrap, CFrame.new(0, -0.46, 0.08))

-- Золотая пряжка на ремне животика
local bellyBuckle = createPart("BellyBuckle", Vector3.new(0.18, 0.08, 0.20), COLOR_GOLD_BUCKLE, catModel)
weldParts(torso, bellyBuckle, CFrame.new(0, -0.47, 0.08))

-- Б) Боковые ремни (соединяют рюкзак на спине и ремень на животике)
local sideStrapL = createPart("SideStrapL", Vector3.new(0.06, 0.92, 0.18), COLOR_LEATHER_DARK, catModel)
weldParts(torso, sideStrapL, CFrame.new(-0.66, 0.0, 0.08))

local sideStrapR = createPart("SideStrapR", Vector3.new(0.06, 0.92, 0.18), COLOR_LEATHER_DARK, catModel)
weldParts(torso, sideStrapR, CFrame.new(0.66, 0.0, 0.08))

-- В) Плечевые ремни через грудку котенка
local chestStrapL = createPart("ChestStrapL", Vector3.new(0.14, 0.06, 0.45), COLOR_LEATHER_DARK, catModel)
weldParts(torso, chestStrapL, CFrame.new(-0.36, 0.46, -0.16))

local chestStrapR = createPart("ChestStrapR", Vector3.new(0.14, 0.06, 0.45), COLOR_LEATHER_DARK, catModel)
weldParts(torso, chestStrapR, CFrame.new(0.36, 0.46, -0.16))

-- === ОТОБРАЖЕНИЕ ПРЕДМЕТОВ В ЛАПКАХ (РЫБКА) ===
local HELD_ITEM_BASE_C0 = CFrame.new(0, -0.42, -0.58)

-- Вкусная рыбка в лапках
local fishBody = createPart("FishBody", Vector3.new(0.18, 0.20, 0.38), Color3.fromRGB(255, 140, 70), catModel)
local fishWeld = weldParts(torso, fishBody, HELD_ITEM_BASE_C0 * CFrame.Angles(0, math.rad(90), math.rad(15)))

local fishTail = createWedge("FishTail", Vector3.new(0.08, 0.22, 0.16), Color3.fromRGB(250, 240, 240), catModel)
weldParts(fishBody, fishTail, CFrame.new(0, 0, 0.24))

local fishEye = createPart("FishEye", Vector3.new(0.04, 0.04, 0.04), Color3.fromRGB(20, 20, 20), catModel)
weldParts(fishBody, fishEye, CFrame.new(0.08, 0.04, -0.12))

local ITEM_VISUALS = {
    fish = { isBlock = false, isFish = true }
}

local function updateHeldItemVisibility(isDigging, isPlacing)
    local itemId = character:GetAttribute("HeldItemId") or ""
    local itemCount = character:GetAttribute("HeldItemCount") or 0

    if isDigging or itemCount <= 0 or itemId == "" then
        fishBody.Transparency = 1
        fishTail.Transparency = 1
        fishEye.Transparency = 1
        return
    end

    local vis = ITEM_VISUALS[itemId]
    if vis and vis.isFish then
        fishBody.Transparency = 0
        fishTail.Transparency = 0
        fishEye.Transparency = 0
    else
        fishBody.Transparency = 1
        fishTail.Transparency = 1
        fishEye.Transparency = 1
    end
end

character:GetAttributeChangedSignal("HeldItemId"):Connect(function()
    updateHeldItemVisibility(false, false)
end)
character:GetAttributeChangedSignal("HeldItemCount"):Connect(function()
    updateHeldItemVisibility(false, false)
end)
updateHeldItemVisibility(false, false)

-- === 4. УПРАВЛЕНИЕ, ЕСТЕСТВЕННАЯ ИНЕРЦИЯ И ЖИВАЯ ПОХОДКА КОТЁНКА ===
-- === РђРўРњРћРЎР¤Р•Р РќР«Р• Р­Р¤Р¤Р•РљРўР«: РЎР›Р•Р”Р« РќРђ РЎРќР•Р“РЈ Р РџР›РђР’РђРќРР• Р’ Р’РћР”Р• ===
local effectsFolder = workspace:FindFirstChild("CatVisualEffects")
if not effectsFolder then
    effectsFolder = Instance.new("Folder")
    effectsFolder.Name = "CatVisualEffects"
    effectsFolder.Parent = workspace
end

local activeSnowPrints = {}
local MAX_SNOW_PRINTS = 45

local function spawnSnowPawPrint(worldPos, yawAngle)
    local printModel = Instance.new("Model")
    printModel.Name = "PawPrint"
    printModel.Parent = effectsFolder

    local printBaseCF = CFrame.new(worldPos + Vector3.new(0, 0.004, 0)) * CFrame.Angles(0, yawAngle, 0)
    local printColor = Color3.fromRGB(165, 192, 218)

    local mainPad = Instance.new("Part")
    mainPad.Name = "MainPad"
    mainPad.Size = Vector3.new(0.13, 0.003, 0.11)
    mainPad.Color = printColor
    mainPad.Material = Enum.Material.SmoothPlastic
    mainPad.Transparency = 0.35
    mainPad.CanCollide = false
    mainPad.CanQuery = false
    mainPad.CanTouch = false
    mainPad.CastShadow = false
    mainPad.Anchored = true
    mainPad.CFrame = printBaseCF
    mainPad.Parent = printModel

    local toeOffsets = {
        Vector3.new(-0.045, 0, -0.075),
        Vector3.new( 0.000, 0, -0.085),
        Vector3.new( 0.045, 0, -0.075),
    }
    local allPads = { mainPad }
    for i, off in ipairs(toeOffsets) do
        local toe = Instance.new("Part")
        toe.Name = "Toe_" .. i
        toe.Size = Vector3.new(0.038, 0.003, 0.038)
        toe.Color = printColor
        toe.Material = Enum.Material.SmoothPlastic
        toe.Transparency = 0.35
        toe.CanCollide = false
        toe.CanQuery = false
        toe.CanTouch = false
        toe.CastShadow = false
        toe.Anchored = true
        toe.CFrame = printBaseCF * CFrame.new(off)
        toe.Parent = printModel
        table.insert(allPads, toe)
    end

    table.insert(activeSnowPrints, { model = printModel, pads = allPads, time = tick() })

    if #activeSnowPrints > MAX_SNOW_PRINTS then
        local oldest = table.remove(activeSnowPrints, 1)
        if oldest and oldest.model and oldest.model.Parent then
            oldest.model:Destroy()
        end
    end

    task.delay(7.5, function()
        if printModel and printModel.Parent then
            for _, pad in ipairs(allPads) do
                TweenService:Create(pad, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Transparency = 1
                }):Play()
            end
            task.delay(2.6, function()
                if printModel and printModel.Parent then
                    printModel:Destroy()
                end
            end)
        end
    end)
end

-- Р’РѕРґРЅС‹Рµ СЌС„С„РµРєС‚С‹
local lastRippleTime = 0
local lastSplashTime = 0
local isInWater = false
local currentWaterSurfaceY = nil

local function spawnWaterBubbles(pos, velDir, isIdle)
    local numCubes = isIdle and math.random(1, 2) or math.random(3, 5)
    for _ = 1, numCubes do
        local bubble = Instance.new("Part")
        bubble.Name = "WaterBubble"
        bubble.Shape = Enum.PartType.Block -- РњР°Р»РµРЅСЊРєРёРµ РїРёРєСЃРµР»СЊРЅС‹Рµ РєСѓР±РёРєРё-РїСѓР·С‹СЂСЊРєРё!
        local s = math.random(5, 8) * 0.01
        bubble.Size = Vector3.new(s, s, s)
        bubble.Color = Color3.fromRGB(195, 235, 255)
        bubble.Material = Enum.Material.Glass
        bubble.Transparency = 0.25
        bubble.CanCollide = false
        bubble.CanQuery = false
        bubble.CanTouch = false
        bubble.CastShadow = false
        bubble.Anchored = false
        bubble.Position = pos + Vector3.new(
            (math.random() - 0.5) * 0.45,
            -0.06 + (math.random() - 0.5) * 0.08,
            (math.random() - 0.5) * 0.45
        )
        local upwardSpeed = math.random(22, 36) * 0.1
        local drift = Vector3.new(
            (math.random() - 0.5) * 1.5 + (velDir and velDir.X * 1.1 or 0),
            upwardSpeed,
            (math.random() - 0.5) * 1.5 + (velDir and velDir.Z * 1.1 or 0)
        )
        bubble.Velocity = drift
        bubble.Parent = effectsFolder

        local lifeTime = math.random(35, 55) * 0.01
        local tw = TweenService:Create(bubble, TweenInfo.new(lifeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = Vector3.new(0.01, 0.01, 0.01),
            Transparency = 0.95
        })
        tw:Play()
        Debris:AddItem(bubble, lifeTime + 0.05)
    end
end

local function checkPawSnowStep(paw, lift)
    if lift > 0.04 then
        paw.wasInAir = true
    elseif lift <= 0.02 and paw.wasInAir then
        paw.wasInAir = false
        if not isInWater and paw.lastGroundHit and paw.lastGroundHit.Normal.Y > 0.65 then
            local isWinter = (workspace:GetAttribute("Season") == "winter")
            local inst = paw.lastGroundHit.Instance
            local isSnow = isWinter or (inst and (inst.Name:find("Snow") ~= nil or inst.Material == Enum.Material.Snow))
            if isSnow then
                local catYaw = math.atan2(-rootPart.CFrame.LookVector.X, -rootPart.CFrame.LookVector.Z) + math.pi
                spawnSnowPawPrint(paw.lastGroundHit.Position, catYaw)
            end
        end
    end
end

local waterRayParams = RaycastParams.new()
waterRayParams.FilterType = Enum.RaycastFilterType.Include
local function updateWaterRayFilter()
    local wf = workspace:FindFirstChild("VoxelWorld")
    if wf then
        waterRayParams.FilterDescendantsInstances = { wf }
    end
end
updateWaterRayFilter()
workspace.ChildAdded:Connect(function(child)
    if child.Name == "VoxelWorld" then updateWaterRayFilter() end
end)

local walkTimer = 0
local idleTimer = 0
local digTimer = 0
local placeUpTimer = 0
local standProgress = 0
local currentMoveVector = Vector3.zero

-- Состояние поворота на месте с естественным переступанием лапками
local turnStepTimer = 0
local turnWeight = 0
local isTurningInPlace = false
local currentTurnDir = 1
local lastTargetAngleDiff = 0

-- Определение точки взгляда мышки в 3D мире
local function getMouseWorldPosition(cam)
    local mouseLoc = UserInputService:GetMouseLocation()
    local unitRay = cam:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)

    local mouseHit = workspace:Raycast(unitRay.Origin, unitRay.Direction * 400, groundRayParams)
    if mouseHit then
        return mouseHit.Position
    end

    if math.abs(unitRay.Direction.Y) > 0.001 then
        local planeY = rootPart.Position.Y
        local t = (planeY - unitRay.Origin.Y) / unitRay.Direction.Y
        if t > 0 then
            return unitRay.Origin + unitRay.Direction * t
        end
    end
    return nil
end

RunService.RenderStepped:Connect(function(dt)
    local camera = workspace.CurrentCamera
    if not camera then return end

    -- 0. Обновляем динамическое примагничивание подошв всех 4 лапок к поверхности земли
    for _, p in ipairs(allPaws) do
        local targetY = getPawTargetLocalY(p)
        p.currentY = p.currentY + (targetY - p.currentY) * math.clamp(dt * 22, 0, 1)
    end

    local isW = UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)
    local isS = UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)
    local isA = UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)
    local isD = UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right)

    local screenX = (isD and 1 or 0) - (isA and 1 or 0)
    local screenY = (isW and 1 or 0) - (isS and 1 or 0)

    local camCF = camera.CFrame
    local camForward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
    local camRight   = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)

    if camForward.Magnitude > 0.001 then camForward = camForward.Unit end
    if camRight.Magnitude > 0.001 then camRight = camRight.Unit end

    local rawMoveDir = (camRight * screenX + camForward * screenY)
    local targetMoveDir = Vector3.zero
    local isKeyHeld = rawMoveDir.Magnitude > 0.1
    if isKeyHeld then
        targetMoveDir = rawMoveDir.Unit
    end

    -- Плавный разгон (14) и естественное мягкое торможение (16) — без резких рывков
    local accelRate = isKeyHeld and 14 or 18
    currentMoveVector = currentMoveVector:Lerp(targetMoveDir, math.clamp(dt * accelRate, 0, 1))
    if currentMoveVector.Magnitude < 0.015 then
        currentMoveVector = Vector3.zero
    end

    -- Передаём сглаженное движение в Humanoid
    humanoid:Move(currentMoveVector, false)

    local isDigging = character:GetAttribute("IsDigging") == true
    local isDiggingUp = character:GetAttribute("IsDiggingUp") == true
    local isPlacing = character:GetAttribute("IsPlacing") == true
    local isPlacingUp = character:GetAttribute("IsPlacingUp") == true
    local isInteracting = isDigging or isDiggingUp or isPlacing or isPlacingUp
    local isMoving = currentMoveVector.Magnitude > 0.08
    local isActuallyWalking = currentMoveVector.Magnitude > 0.04
    -- РћР±РЅР°СЂСѓР¶РµРЅРёРµ РІРѕРґС‹ РїРѕРґ/РІРѕРєСЂСѓРі РєРѕС‚РёРєР° РґР»СЏ РїР»Р°РІР°РЅРёСЏ
    local now = tick()
    local waterHit = workspace:Raycast(rootPart.Position + Vector3.new(0, 1.5, 0), Vector3.new(0, -3.5, 0), waterRayParams)
    if waterHit and waterHit.Instance and waterHit.Instance.Name:find("Water") ~= nil then
        isInWater = true
        currentWaterSurfaceY = waterHit.Instance.Position.Y + waterHit.Instance.Size.Y * 0.5
    else
        local touching = workspace:GetPartsInPart(rootPart)
        local foundWater = false
        for _, p in ipairs(touching) do
            if p.Name:find("Water") ~= nil then
                foundWater = true
                currentWaterSurfaceY = p.Position.Y + p.Size.Y * 0.5
                break
            end
        end
        isInWater = foundWater
    end

    if isInWater and currentWaterSurfaceY then
        if isActuallyWalking then
            if now - lastSplashTime >= 0.14 then
                lastSplashTime = now
                local forwardDir = rootPart.CFrame.LookVector
                spawnWaterBubbles(rootPart.Position + Vector3.new(0, -0.3, 0) + forwardDir * 0.25, forwardDir, false)
            end
        else
            if now - lastSplashTime >= 1.2 then
                lastSplashTime = now
                spawnWaterBubbles(rootPart.Position + Vector3.new(0, -0.35, 0), Vector3.zero, true)
            end
        end
    end

    local targetLookPos = character:GetAttribute("TargetLookPos")
    local testAim = character:GetAttribute("TestAimPos")
    local hasTarget = typeof(targetLookPos) == "Vector3"
    local mouseWorldPos = testAim or getMouseWorldPosition(camera)

    -- Целевая точка взгляда котика:
    -- 1. Если ломает/строит конкретный блок — смотрим строго на этот блок
    -- 2. В обычном режиме — смотрим строго в точку мира, куда указывает мышка игрока
    local aimTargetPos = (isInteracting and hasTarget and targetLookPos) or mouseWorldPos or targetLookPos

    -- Поворот тела котика:
    -- 1. При взаимодействии (копает / строит) — смотрим на блок
    -- 2. При беге по карте — смотрим по направлению ходьбы
    -- 3. На месте при наведении мыши — поворачиваемся переступая лапками
    local angleDiff = 0
    local absAngle = 0

    if isInteracting and aimTargetPos then
        local delta = aimTargetPos - rootPart.Position
        local horiz = Vector3.new(delta.X, 0, delta.Z)
        if horiz.Magnitude > 0.25 then
            alignOrient.MaxAngularVelocity = 25
            alignOrient.CFrame = CFrame.lookAlong(Vector3.zero, horiz.Unit)
        end
        isTurningInPlace = false
    elseif isMoving then
        alignOrient.MaxAngularVelocity = 25
        alignOrient.CFrame = CFrame.lookAlong(Vector3.zero, currentMoveVector.Unit)
        isTurningInPlace = false
    elseif aimTargetPos then
        local delta = aimTargetPos - rootPart.Position
        local horiz = Vector3.new(delta.X, 0, delta.Z)
        if horiz.Magnitude > 0.45 then
            local targetDir = horiz.Unit
            local localDir = rootPart.CFrame:VectorToObjectSpace(targetDir)
            angleDiff = math.atan2(localDir.X, -localDir.Z)
            absAngle = math.abs(angleDiff)
            lastTargetAngleDiff = angleDiff

            -- Зона нечувствительности с гистерезисом:
            -- Начинаем шагать при угле > 14 градусов (0.24 рад).
            -- Завершаем разворот, когда тело довернулось до 4 градусов (0.07 рад).
            if not isTurningInPlace then
                if absAngle > math.rad(14) then
                    isTurningInPlace = true
                    currentTurnDir = math.sign(angleDiff)
                    if currentTurnDir == 0 then currentTurnDir = 1 end
                end
            else
                if absAngle < math.rad(4) then
                    isTurningInPlace = false
                else
                    currentTurnDir = math.sign(angleDiff)
                    if currentTurnDir == 0 then currentTurnDir = 1 end
                end
            end

            if isTurningInPlace then
                -- Естественная скорость шага при развороте: 3.5 .. 5.2 рад/сек
                local turnSpeed = math.clamp(absAngle * 5.5, 3.5, 5.2)
                alignOrient.MaxAngularVelocity = turnSpeed
                alignOrient.CFrame = CFrame.lookAlong(Vector3.zero, targetDir)

                -- Шаг лапок синхронизирован со скоростью разворота
                turnStepTimer = turnStepTimer + dt * 14.0 * (turnSpeed / 4.2)
            else
                alignOrient.MaxAngularVelocity = 15
            end
        else
            isTurningInPlace = false
        end
    else
        isTurningInPlace = false
    end

    -- Плавная анимация: котёнок грациозно встаёт на две задние лапки, когда ставит или добывает блок сверху
    local wantsStand = (isPlacingUp == true or isDiggingUp == true)
    local targetStand = wantsStand and 1 or 0
    standProgress = standProgress + (targetStand - standProgress) * math.clamp(dt * 12, 0, 1)

    if wantsStand or standProgress > 0.02 then
        placeUpTimer = placeUpTimer + dt
        local p = math.sin(standProgress * math.pi * 0.5)

        -- 1. Туловище грациозно поднимается и встаёт на задние лапки (угол ~46 градусов)
        local standAngle = math.rad(46) * p
        local standLift = 0.50 * p
        local standBack = 0.20 * p
        torsoJoint.C0 = CFrame.new(0, TORSO_Y_OFFSET + standLift, 0.05 + standBack) * CFrame.Angles(standAngle, 0, 0)

        -- 2. Голова компенсирует наклон туловища, чтобы взгляд смотрел строго вперёд-вверх на устанавливаемый блок
        -- (без неестественного запрокидывания назад!)
        local headCounterAngle = -standAngle + math.rad(10) * p
        headJoint.C0 = CFrame.new(0, 0.68, -0.65) * CFrame.Angles(headCounterAngle, 0, 0)

        -- 3. Задние опорные лапки остаются неподвижно стоять на земле, сохраняя равновесие
        pawBL.motor.C0 = CFrame.new(pawBL.relPos.X, pawBL.currentY, pawBL.relPos.Z) * CFrame.Angles(-standAngle, 0, 0)
        pawBR.motor.C0 = CFrame.new(pawBR.relPos.X, pawBR.currentY, pawBR.relPos.Z) * CFrame.Angles(-standAngle, 0, 0)

        -- 4. Передние лапки поднимаются в воздух и аккуратно тянутся к блоку
        local pawReachY = 0.32 * p
        local pawReachZ = -0.30 * p
        local pawAngle = math.rad(38) * p

        if isDiggingUp then
            -- Поочередные быстрые взмахи лапками при раскапывании верхнего блока
            local digSwing = math.sin(placeUpTimer * 16) * math.rad(18) * p
            pawFL.motor.C0 = pawFL.origC0 * CFrame.new(-0.03, pawReachY, pawReachZ) * CFrame.Angles(pawAngle + digSwing, math.rad(6), math.rad(-8 * p))
            pawFR.motor.C0 = pawFR.origC0 * CFrame.new( 0.03, pawReachY, pawReachZ) * CFrame.Angles(pawAngle - digSwing, math.rad(-6), math.rad(8 * p))
            updateHeldItemVisibility(true, false)
        else
            -- Милое похлопывание лапками при установке блока сверху
            local tap = math.sin(placeUpTimer * 14) * math.rad(10) * p
            pawFL.motor.C0 = pawFL.origC0 * CFrame.new(-0.03, pawReachY, pawReachZ) * CFrame.Angles(pawAngle + tap, math.rad(6), math.rad(-8 * p))
            pawFR.motor.C0 = pawFR.origC0 * CFrame.new( 0.03, pawReachY, pawReachZ) * CFrame.Angles(pawAngle - tap, math.rad(-6), math.rad(8 * p))
            updateHeldItemVisibility(false, true)
        end

        -- 5. Хвостик опирается назад для идеального баланса и реалистичной физики
        tailMotor.C0 = tailOrigC0 * CFrame.Angles(math.rad(-26) * p, math.sin(placeUpTimer * 4) * math.rad(8) * p, 0)

    elseif isDigging then
        placeUpTimer = 0
        digTimer = digTimer + dt * 14
        local digSwingL = math.sin(digTimer) * math.rad(45)
        local digSwingR = -math.sin(digTimer) * math.rad(45)

        pawFL.motor.C0 = CFrame.new(pawFL.relPos.X, pawFL.currentY + 0.05, pawFL.relPos.Z) * CFrame.Angles(digSwingL, 0, math.rad(-10))
        pawFR.motor.C0 = CFrame.new(pawFR.relPos.X, pawFR.currentY + 0.05, pawFR.relPos.Z) * CFrame.Angles(digSwingR, 0, math.rad(10))
        pawBL.motor.C0 = CFrame.new(pawBL.relPos.X, pawBL.currentY, pawBL.relPos.Z)
        pawBR.motor.C0 = CFrame.new(pawBR.relPos.X, pawBR.currentY, pawBR.relPos.Z)

        headJoint.C0 = CFrame.new(0, 0.58, -0.68) * CFrame.Angles(math.rad(12), 0, 0)
        torsoJoint.C0 = CFrame.new(0, TORSO_Y_OFFSET - 0.04, 0.05) * CFrame.Angles(math.rad(-6), 0, 0)
        tailMotor.C0 = tailOrigC0 * CFrame.Angles(0, math.sin(digTimer * 0.5) * math.rad(28), 0)

        updateHeldItemVisibility(true, false)

    elseif isPlacing then
        placeUpTimer = 0
        pawFL.motor.C0 = CFrame.new(pawFL.relPos.X, pawFL.currentY + 0.08, pawFL.relPos.Z) * CFrame.Angles(math.rad(35), 0, math.rad(-12))
        pawFR.motor.C0 = CFrame.new(pawFR.relPos.X, pawFR.currentY + 0.08, pawFR.relPos.Z) * CFrame.Angles(math.rad(35), 0, math.rad(12))
        pawBL.motor.C0 = CFrame.new(pawBL.relPos.X, pawBL.currentY, pawBL.relPos.Z)
        pawBR.motor.C0 = CFrame.new(pawBR.relPos.X, pawBR.currentY, pawBR.relPos.Z)
        headJoint.C0 = CFrame.new(0, 0.62, -0.65) * CFrame.Angles(math.rad(8), 0, 0)
        torsoJoint.C0 = CFrame.new(0, TORSO_Y_OFFSET, 0.05)

        updateHeldItemVisibility(false, true)
        fishWeld.C0 = CFrame.new(0, -0.48, -0.70) * CFrame.Angles(0, math.rad(90), math.rad(15))

    elseif isActuallyWalking then
        placeUpTimer = 0
        updateHeldItemVisibility(false, false)

        -- Скорость шага зависит от скорости движения
        local speedMult = currentMoveVector.Magnitude
        walkTimer = walkTimer + dt * 16 * speedMult

        -- Фазы шага 4 лапок (диагональная рысь котика)
        local phaseFL = walkTimer
        local phaseFR = walkTimer + math.pi
        local phaseBL = walkTimer + math.pi * 0.95
        local phaseBR = walkTimer - math.pi * 0.05

        -- Углы взмаха лапок (аккуратный естественный шаг)
        local swingFL = math.sin(phaseFL) * math.rad(25)
        local swingFR = math.sin(phaseFR) * math.rad(25)
        local swingBL = math.sin(phaseBL) * math.rad(22)
        local swingBR = math.sin(phaseBR) * math.rad(22)

        -- Подъём лапки от земли (переступание, чтобы котик не «ездил» на лапах)
        local liftFL = math.max(0, math.sin(phaseFL)) * 0.16
        local liftFR = math.max(0, math.sin(phaseFR)) * 0.16
        local liftBL = math.max(0, math.sin(phaseBL)) * 0.13
        local liftBR = math.max(0, math.sin(phaseBR)) * 0.13

        pawFL.motor.C0 = CFrame.new(pawFL.relPos.X, pawFL.currentY + liftFL, pawFL.relPos.Z) * CFrame.Angles(swingFL, 0, 0)
        pawFR.motor.C0 = CFrame.new(pawFR.relPos.X, pawFR.currentY + liftFR, pawFR.relPos.Z) * CFrame.Angles(swingFR, 0, 0)
        pawBL.motor.C0 = CFrame.new(pawBL.relPos.X, pawBL.currentY + liftBL, pawBL.relPos.Z) * CFrame.Angles(swingBL, 0, 0)
        pawBR.motor.C0 = CFrame.new(pawBR.relPos.X, pawBR.currentY + liftBR, pawBR.relPos.Z) * CFrame.Angles(swingBR, 0, 0)
        checkPawSnowStep(pawFL, liftFL)
        checkPawSnowStep(pawFR, liftFR)
        checkPawSnowStep(pawBL, liftBL)
        checkPawSnowStep(pawBR, liftBR)

        -- Естественный вертикальный шаг тела и мягкий перенос веса
        local bodyBounce = math.abs(math.sin(walkTimer * 2)) * 0.05
        local bodyRoll = math.sin(walkTimer) * math.rad(2.2)

        torsoJoint.C0 = CFrame.new(0, TORSO_Y_OFFSET + bodyBounce, 0.05) * CFrame.Angles(0, 0, bodyRoll)

        -- Живой хвост, балансирующий походку
        local tailSway = math.sin(walkTimer * 0.5) * math.rad(20)
        tailMotor.C0 = tailOrigC0 * CFrame.Angles(math.sin(walkTimer) * math.rad(6), tailSway, 0)

        -- Стабилизация взгляда головы
        headJoint.C0 = CFrame.new(0, 0.68 - bodyBounce * 0.5, -0.65) * CFrame.Angles(math.rad(-2), 0, -bodyRoll * 0.4)

        fishWeld.C0 = CFrame.new(0, -0.42 + bodyBounce * 0.5, -0.58) * CFrame.Angles(0, math.rad(90), math.rad(15))
    else
        updateHeldItemVisibility(false, false)

        local targetTurnWeight = isTurningInPlace and 1 or 0
        turnWeight = turnWeight + (targetTurnWeight - turnWeight) * math.clamp(dt * 12, 0, 1)

        -- Базовые устойчивые точки лапок, примагниченные к земле (IK ground snapping)
        local idleCF_FL = CFrame.new(pawFL.relPos.X, pawFL.currentY, pawFL.relPos.Z)
        local idleCF_FR = CFrame.new(pawFR.relPos.X, pawFR.currentY, pawFR.relPos.Z)
        local idleCF_BL = CFrame.new(pawBL.relPos.X, pawBL.currentY, pawBL.relPos.Z)
        local idleCF_BR = CFrame.new(pawBR.relPos.X, pawBR.currentY, pawBR.relPos.Z)

        if turnWeight > 0.01 then
            local turnDir = currentTurnDir
            -- Диагональные пары лапок:
            -- Пара А: передняя левая (FL) и задняя правая (BR)
            -- Пара Б: передняя правая (FR) и задняя левая (BL)
            local phaseA = turnStepTimer
            local phaseB = turnStepTimer + math.pi

            -- Подъём лапки от земли (переступание с чистым отрывом подошвы)
            local liftA = math.max(0, math.sin(phaseA)) * 0.17
            local liftB = math.max(0, math.sin(phaseB)) * 0.17

            -- Горизонтальное смещение лапок в сторону поворота:
            local shiftX_FL = math.sin(phaseA) * 0.14 * turnDir
            local shiftZ_FL = -math.cos(phaseA) * 0.08
            local shiftX_FR = math.sin(phaseB) * 0.14 * turnDir
            local shiftZ_FR = math.cos(phaseB) * 0.08

            -- Задние лапки поворачивают корпус в такт развороту
            local shiftX_BL = -math.sin(phaseB) * 0.11 * turnDir
            local shiftZ_BL = -math.cos(phaseB) * 0.06
            local shiftX_BR = -math.sin(phaseA) * 0.11 * turnDir
            local shiftZ_BR = math.cos(phaseA) * 0.06

            -- Углы наклона лапок при шаге разворота
            local rotFL = CFrame.Angles(math.cos(phaseA) * math.rad(12), math.sin(phaseA) * math.rad(16) * turnDir, math.rad(-8) * turnDir)
            local rotFR = CFrame.Angles(math.cos(phaseB) * math.rad(12), math.sin(phaseB) * math.rad(16) * turnDir, math.rad(8) * turnDir)
            local rotBL = CFrame.Angles(math.cos(phaseB) * math.rad(10), -math.sin(phaseB) * math.rad(14) * turnDir, math.rad(-6) * turnDir)
            local rotBR = CFrame.Angles(math.cos(phaseA) * math.rad(10), -math.sin(phaseA) * math.rad(14) * turnDir, math.rad(6) * turnDir)

            local turnCF_FL = CFrame.new(pawFL.relPos.X + shiftX_FL, pawFL.currentY + liftA, pawFL.relPos.Z + shiftZ_FL) * rotFL
            local turnCF_FR = CFrame.new(pawFR.relPos.X + shiftX_FR, pawFR.currentY + liftB, pawFR.relPos.Z + shiftZ_FR) * rotFR
            local turnCF_BL = CFrame.new(pawBL.relPos.X + shiftX_BL, pawBL.currentY + liftB, pawBL.relPos.Z + shiftZ_BL) * rotBL
            local turnCF_BR = CFrame.new(pawBR.relPos.X + shiftX_BR, pawBR.currentY + liftA, pawBR.relPos.Z + shiftZ_BR) * rotBR

            pawFL.motor.C0 = idleCF_FL:Lerp(turnCF_FL, turnWeight)
            pawFR.motor.C0 = idleCF_FR:Lerp(turnCF_FR, turnWeight)
            pawBL.motor.C0 = idleCF_BL:Lerp(turnCF_BL, turnWeight)
            pawBR.motor.C0 = idleCF_BR:Lerp(turnCF_BR, turnWeight)
            checkPawSnowStep(pawFL, liftA)
            checkPawSnowStep(pawFR, liftB)
            checkPawSnowStep(pawBL, liftB)
            checkPawSnowStep(pawBR, liftA)

            -- Туловище: лёгкий шаг и наклон в поворот
            local bounce = math.abs(math.sin(turnStepTimer * 2)) * 0.04 * turnWeight
            local bodyRoll = math.sin(turnStepTimer) * math.rad(2.2) * turnDir * turnWeight
            torsoJoint.C0 = CFrame.new(0, TORSO_Y_OFFSET + bounce, 0.05) * CFrame.Angles(0, 0, -bodyRoll)

            -- Хвостик: балансирует вращение
            local tailTurn = (-turnDir * math.rad(20) + math.sin(turnStepTimer) * math.rad(8)) * turnWeight
            tailMotor.C0 = tailOrigC0 * CFrame.Angles(math.rad(10 * turnWeight), tailTurn, 0)

            -- Голова: аккуратный и естественный взгляд в сторону мышки (не более 10 градусов)
            local headYaw = math.clamp(lastTargetAngleDiff * 0.35, math.rad(-10), math.rad(10)) * turnWeight
            headJoint.C0 = CFrame.new(0, 0.68, -0.65) * CFrame.Angles(0, headYaw, 0)
        else
            -- Спокойное дыхание и покой (лапки неподвижно и ровно стоят на земле)
            pawFL.motor.C0 = pawFL.motor.C0:Lerp(idleCF_FL, math.clamp(dt * 18, 0, 1))
            pawFR.motor.C0 = pawFR.motor.C0:Lerp(idleCF_FR, math.clamp(dt * 18, 0, 1))
            pawBL.motor.C0 = pawBL.motor.C0:Lerp(idleCF_BL, math.clamp(dt * 18, 0, 1))
            pawBR.motor.C0 = pawBR.motor.C0:Lerp(idleCF_BR, math.clamp(dt * 18, 0, 1))

            idleTimer = idleTimer + dt * 2.2
            local breath = math.sin(idleTimer) * 0.025
            torsoJoint.C0 = torsoJoint.C0:Lerp(CFrame.new(0, TORSO_Y_OFFSET + breath, 0.05), math.clamp(dt * 8, 0, 1))

            local lazyTail = math.sin(idleTimer * 0.7) * math.rad(16)
            tailMotor.C0 = tailOrigC0 * CFrame.Angles(0, lazyTail, 0)

            if aimTargetPos and (aimTargetPos - rootPart.Position).Magnitude > 0.8 then
                local delta = aimTargetPos - rootPart.Position
                local horiz = Vector3.new(delta.X, 0, delta.Z)
                local deltaY = aimTargetPos.Y - (rootPart.Position.Y + 0.4)
                local horizDist = math.max(0.8, horiz.Magnitude)
                local headPitch = math.clamp(math.atan2(deltaY, horizDist) * 0.25, math.rad(-5), math.rad(5))
                local localAim = rootPart.CFrame:VectorToObjectSpace(horiz.Unit)
                local headYaw = math.clamp(math.atan2(localAim.X, -localAim.Z) * 0.3, math.rad(-10), math.rad(10))
                headJoint.C0 = headJoint.C0:Lerp(CFrame.new(0, 0.68, -0.65) * CFrame.Angles(headPitch, headYaw, 0), math.clamp(dt * 12, 0, 1))
            else
                local headTilt = math.sin(idleTimer * 0.4) * math.rad(2.5)
                headJoint.C0 = headJoint.C0:Lerp(CFrame.new(0, 0.68, -0.65) * CFrame.Angles(0, 0, headTilt), math.clamp(dt * 8, 0, 1))
            end
        end

        fishWeld.C0 = CFrame.new(0, -0.42, -0.58) * CFrame.Angles(0, math.rad(90), math.rad(15))
    end
end)
