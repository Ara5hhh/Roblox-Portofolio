local Hopscotch = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundModule = require(ReplicatedStorage.Modules.Shared.SoundModule)

local localPlayer = game.Players.LocalPlayer
local camera = workspace.CurrentCamera

local DASH_DURATION = 0.4 --keep in sync with DASH_DURATION in Client.Abilities.Hopscotch (hardcoded to avoid a cyclic require)

local BASE_FOV = 70
local DASH_FOV = 120

--DASH TEMPLATE--
local dashPartTemplate:BasePart = script:WaitForChild("DashPart")

-- Cache every emitter's designed transparency curve BEFORE it gets flattened below,
-- so ChangeTransparencyAsync can fade back into the original look instead of a flat value.
-- Keyed by path (relative to the template), NOT instance identity — ChangeTransparencyAsync
-- runs on a Clone() of the template, whose effects are different instances entirely.
local originalTransparencies: {[string]: NumberSequence} = {}

local function getRelativePath(instance:Instance, root:Instance): string
    local path = {}
    local current = instance
    while current and current ~= root do
        table.insert(path, 1, current.Name)
        current = current.Parent
    end
    return table.concat(path, "/")
end

local function cacheOriginalTransparencies(part:BasePart)
    for _, effect in pairs(part:GetDescendants()) do
        if effect:IsA("ParticleEmitter") or effect:IsA("Beam") then
            originalTransparencies[getRelativePath(effect, part)] = effect.Transparency
        end
    end
end

cacheOriginalTransparencies(dashPartTemplate)

--PREPARING TEMPLATE--
for _, effect in pairs(dashPartTemplate:GetDescendants()) do
    if effect:IsA("ParticleEmitter") or effect:IsA("Beam") then
        effect.Transparency = NumberSequence.new(1)
    end
end
-------------------------------------------

-- Shifts every keypoint of the original curve toward fully transparent by `hiddenAmount`
-- (0 = original look, 1 = fully hidden), preserving the curve's shape while it fades.
local function blendTransparency(original:NumberSequence, hiddenAmount:number): NumberSequence
    local keypoints = {}
    for _, kp in ipairs(original.Keypoints) do
        table.insert(keypoints, NumberSequenceKeypoint.new(kp.Time, math.clamp(kp.Value + hiddenAmount, 0, 1), kp.Envelope))
    end
    return NumberSequence.new(keypoints)
end

local function ChangeTransparencyAsync(part:BasePart, visible:boolean)
    local fxInstances:{ParticleEmitter | Beam} = {}

    for _, effect in pairs(part:GetDescendants()) do
        if effect:IsA("ParticleEmitter") or effect:IsA("Beam") then
            table.insert(fxInstances, effect)
        end
    end

    local hiddenAmount = if visible then 0 else 1
    local direction = if visible then -1 else 1 --moves hiddenAmount toward 0 (visible) or 1 (hidden)

    local transpConn
    transpConn = RunService.Heartbeat:Connect(function(deltaTime)
        hiddenAmount = math.clamp(hiddenAmount + (direction * deltaTime), 0, 1)

        for _, effect in pairs(fxInstances) do
            local original = originalTransparencies[getRelativePath(effect, part)]
            if original then
                effect.Transparency = blendTransparency(original, hiddenAmount)
            end
        end

        if hiddenAmount <= 0 or hiddenAmount >= 1 then
            transpConn:Disconnect()
        end
    end)
end

-- Widens the FOV out and back over the dash — only felt by the player actually dashing.
local function tweenLocalFOV()
    local halfDuration = DASH_DURATION / 2

    local widen = TweenService:Create(camera, TweenInfo.new(halfDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {FieldOfView = DASH_FOV})
    local settle = TweenService:Create(camera, TweenInfo.new(halfDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {FieldOfView = BASE_FOV})

    widen.Completed:Once(function()
        settle:Play()
    end)

    widen:Play()
end


function Hopscotch.Play(player:Player)
    if not player.Character then return end

    SoundModule.Play("Hopscotch")

    if player == localPlayer then
        tweenLocalFOV()
    end

    local dash = dashPartTemplate:Clone()
    dash.Parent = player.Character
    dash.Anchored = false

    local weld = Instance.new("WeldConstraint")

    dash.CFrame = player.Character.HumanoidRootPart.CFrame * CFrame.Angles(math.rad(-90), 0, 0)
    weld.Parent = dash
    weld.Part0 = player.Character.HumanoidRootPart
    weld.Part1 = dash

    ChangeTransparencyAsync(dash, true)

    task.wait(DASH_DURATION)

    ChangeTransparencyAsync(dash, false)


    dash:Destroy()
end


return Hopscotch
