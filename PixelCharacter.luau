-- LocalScript: StarterPlayer -> StarterCharacterScripts -> PixelCharacter
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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
        currentY = relPos.Y
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
local walkTimer = 0
local idleTimer = 0
local digTimer = 0
local placeUpTimer = 0
local standProgress = 0
local currentMoveVector = Vector3.zero

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

    local targetLookPos = character:GetAttribute("TargetLookPos")
    local hasTarget = typeof(targetLookPos) == "Vector3"

    -- Поворот тела котика:
    -- 1. При взаимодействии (копает / строит) — ВСЕГДА строго поворачиваемся к блоку
    -- 2. При беге по карте — поворачиваемся по направлению ходьбы
    -- 3. На месте при наведении мыши — котик плавно и естественно поворачивается лицом к блоку
    if isInteracting and hasTarget then
        local delta = targetLookPos - rootPart.Position
        local horiz = Vector3.new(delta.X, 0, delta.Z)
        if horiz.Magnitude > 0.3 then
            alignOrient.CFrame = CFrame.lookAlong(Vector3.zero, horiz.Unit)
        end
    elseif isMoving then
        alignOrient.CFrame = CFrame.lookAlong(Vector3.zero, currentMoveVector.Unit)
    elseif hasTarget then
        local delta = targetLookPos - rootPart.Position
        local horiz = Vector3.new(delta.X, 0, delta.Z)
        if horiz.Magnitude > 0.6 then
            alignOrient.CFrame = CFrame.lookAlong(Vector3.zero, horiz.Unit)
        end
    end

    -- Плавная интерполяция стойки на задних лапках при установке/добыче наверх
    local wantsStand = (isPlacingUp or isDiggingUp)
    local targetStand = wantsStand and 1 or 0
    standProgress = standProgress + (targetStand - standProgress) * math.clamp(dt * 10, 0, 1)

    if wantsStand or standProgress > 0.02 then
        placeUpTimer = placeUpTimer + dt
        local p = math.sin(standProgress * math.pi * 0.5)

        -- 1. Туловище встаёт на задние лапки (угол ~56 градусов вверх-назад)
        local standAngle = math.rad(56) * p
        local standLift = 0.44 * p
        local standBack = 0.14 * p
        torsoJoint.C0 = CFrame.new(0, TORSO_Y_OFFSET + standLift, 0.05 + standBack) * CFrame.Angles(standAngle, 0, 0)

        -- 2. Голова наклоняется вперёд-вверх, наблюдая за установкой блока
        local headLookUp = math.rad(-40) * p
        headJoint.C0 = CFrame.new(0, 0.68 + 0.04 * p, -0.65) * CFrame.Angles(headLookUp, 0, 0)

        -- 3. Задние лапки остаются устойчиво примагниченными к земле
        local backPawCounter = math.rad(-56) * p
        pawBL.motor.C0 = CFrame.new(pawBL.relPos.X, pawBL.currentY, pawBL.relPos.Z) * CFrame.Angles(backPawCounter, 0, 0) * CFrame.new(0, -0.05 * p, 0)
        pawBR.motor.C0 = CFrame.new(pawBR.relPos.X, pawBR.currentY, pawBR.relPos.Z) * CFrame.Angles(backPawCounter, 0, 0) * CFrame.new(0, -0.05 * p, 0)

        -- 4. Передние лапки тянутся высоко вверх с милыми белыми носочками
        local pawReachY = 0.36 * p
        local pawReachZ = -0.28 * p
        local pawAngle = math.rad(52) * p

        if isDiggingUp then
            -- При копании верхнего блока лапки яростно скребут вверх
            local digSwing = math.sin(placeUpTimer * 16) * math.rad(25) * p
            pawFL.motor.C0 = pawFL.origC0 * CFrame.new(0, pawReachY, pawReachZ) * CFrame.Angles(pawAngle + digSwing, 0, math.rad(-14 * p))
            pawFR.motor.C0 = pawFR.origC0 * CFrame.new(0, pawReachY, pawReachZ) * CFrame.Angles(pawAngle - digSwing, 0, math.rad(14 * p))
            updateHeldItemVisibility(true, false)
        else
            -- При установке наверх: аккуратный хлопок/постукивание лапками по блоку
            local tap = math.sin(placeUpTimer * 12) * math.rad(8) * p
            pawFL.motor.C0 = pawFL.origC0 * CFrame.new(0, pawReachY, pawReachZ) * CFrame.Angles(pawAngle + tap, 0, math.rad(-14 * p))
            pawFR.motor.C0 = pawFR.origC0 * CFrame.new(0, pawReachY, pawReachZ) * CFrame.Angles(pawAngle - tap, 0, math.rad(14 * p))
            updateHeldItemVisibility(false, true)
        end

        -- 5. Хвостик упирается назад для балансировки центра масс
        tailMotor.C0 = tailOrigC0 * CFrame.Angles(math.rad(-36) * p, 0, 0)

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

        -- Лапки идеально и устойчиво примагничены к поверхности земли без проваливания и парения
        local targetFL = CFrame.new(pawFL.relPos.X, pawFL.currentY, pawFL.relPos.Z)
        local targetFR = CFrame.new(pawFR.relPos.X, pawFR.currentY, pawFR.relPos.Z)
        local targetBL = CFrame.new(pawBL.relPos.X, pawBL.currentY, pawBL.relPos.Z)
        local targetBR = CFrame.new(pawBR.relPos.X, pawBR.currentY, pawBR.relPos.Z)

        pawFL.motor.C0 = pawFL.motor.C0:Lerp(targetFL, math.clamp(dt * 18, 0, 1))
        pawFR.motor.C0 = pawFR.motor.C0:Lerp(targetFR, math.clamp(dt * 18, 0, 1))
        pawBL.motor.C0 = pawBL.motor.C0:Lerp(targetBL, math.clamp(dt * 18, 0, 1))
        pawBR.motor.C0 = pawBR.motor.C0:Lerp(targetBR, math.clamp(dt * 18, 0, 1))

        idleTimer = idleTimer + dt * 2.2
        local breath = math.sin(idleTimer) * 0.025
        torsoJoint.C0 = torsoJoint.C0:Lerp(CFrame.new(0, TORSO_Y_OFFSET + breath, 0.05), math.clamp(dt * 8, 0, 1))

        local lazyTail = math.sin(idleTimer * 0.7) * math.rad(16)
        tailMotor.C0 = tailOrigC0 * CFrame.Angles(0, lazyTail, 0)

        if hasTarget and (targetLookPos - rootPart.Position).Magnitude > 0.8 then
            local delta = targetLookPos - rootPart.Position
            local horiz = Vector3.new(delta.X, 0, delta.Z)
            local deltaY = targetLookPos.Y - (rootPart.Position.Y + 0.4)
            local horizDist = math.max(0.8, horiz.Magnitude)
            local headPitch = math.clamp(math.atan2(deltaY, horizDist), math.rad(-22), math.rad(24))
            headJoint.C0 = headJoint.C0:Lerp(CFrame.new(0, 0.68, -0.65) * CFrame.Angles(headPitch, 0, 0), math.clamp(dt * 12, 0, 1))
        else
            local headTilt = math.sin(idleTimer * 0.4) * math.rad(3)
            headJoint.C0 = headJoint.C0:Lerp(CFrame.new(0, 0.68, -0.65) * CFrame.Angles(0, 0, headTilt), math.clamp(dt * 8, 0, 1))
        end

        fishWeld.C0 = CFrame.new(0, -0.42 + breath * 0.5, -0.58) * CFrame.Angles(0, math.rad(90), math.rad(15))
    end
end)
