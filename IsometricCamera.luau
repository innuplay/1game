-- LocalScript: StarterPlayer -> StarterPlayerScripts -> IsometricCamera
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- === НАСТРОЙКИ КАМЕРЫ ===
local FOV = 20                -- Узкий угол обзора для сохранения изометрии
local SENSITIVITY = 0.35      -- Чувствительность вращения мыши
local SMOOTH_SPEED = 16       -- Плавность поворота и зума

-- === УГЛЫ ВРАЩЕНИЯ (ОРБИТА ВОКРУГ КОТЁНКА) ===
local targetYaw = 45          -- Поворот по горизонтали
local currentYaw = 45

local targetPitch = 23        -- Наклон по вертикали
local currentPitch = 23
local MIN_PITCH = 5           -- Минимальный угол
local MAX_PITCH = 80          -- Максимальный угол

-- === ЗУМ ===
local MIN_DISTANCE = 18
local MAX_DISTANCE = 140
local ZOOM_STEP = 10
local targetDistance = 55
local currentDistance = 55

-- Состояние вращения (ТОЛЬКО НА КОЛЁСИКЕ МЫШИ)
local isOrbiting = false

-- 1. СЛУШАЕМ НАЖАТИЯ МЫШИ (СТРОГО ТОЛЬКО КОЛЁСИКО МЫШИ - СКМ)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- Зажатие колёсика мыши (MouseButton3) — как в Blender 3D
    if input.UserInputType == Enum.UserInputType.MouseButton3 then
        isOrbiting = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton3 then
        isOrbiting = false
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
end)

-- 2. ВРАЩЕНИЕ МЫШЬЮ И ЗУМ КОЛЁСИКОМ
UserInputService.InputChanged:Connect(function(input, gameProcessed)
    -- Вращение только при зажатом колёсике
    if isOrbiting and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Delta
        targetYaw = targetYaw - delta.X * SENSITIVITY
        targetPitch = math.clamp(targetPitch + delta.Y * SENSITIVITY, MIN_PITCH, MAX_PITCH)
    end

    -- Зум на прокрутку колёсика
    if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseWheel then
        targetDistance = math.clamp(targetDistance - input.Position.Z * ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
    end
end)

-- 3. ОБНОВЛЕНИЕ КАМЕРЫ КАЖДЫЙ КАДР
local function updateCamera(dt)
    local character = player.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    if camera.CameraType ~= Enum.CameraType.Scriptable then
        camera.CameraType = Enum.CameraType.Scriptable
    end
    camera.FieldOfView = FOV

    -- Плавная интерполяция поворотов и зума
    currentYaw = currentYaw + (targetYaw - currentYaw) * math.clamp(dt * SMOOTH_SPEED, 0, 1)
    currentPitch = currentPitch + (targetPitch - currentPitch) * math.clamp(dt * SMOOTH_SPEED, 0, 1)
    currentDistance = currentDistance + (targetDistance - currentDistance) * math.clamp(dt * SMOOTH_SPEED, 0, 1)

    -- Расчет CFrame орбиты вокруг котенка
    local cameraRotation = CFrame.Angles(0, math.rad(currentYaw), 0) 
        * CFrame.Angles(math.rad(-currentPitch), 0, 0)
    local cameraOffset = cameraRotation:VectorToWorldSpace(Vector3.new(0, 0, currentDistance))

    -- Точка фокуса (центр котенка)
    local targetPos = rootPart.Position + Vector3.new(0, -0.4, 0)
    local camPos = targetPos + cameraOffset
    
    camera.CFrame = CFrame.new(camPos, targetPos)
end

RunService:BindToRenderStep("IsometricCameraStep", Enum.RenderPriority.Camera.Value + 1, updateCamera)
