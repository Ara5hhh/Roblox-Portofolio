local FrightTrap = {}

local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local localPlayer = game.Players.LocalPlayer
local camera = workspace.CurrentCamera

local ControlLock = require(game.StarterPlayer.StarterPlayerScripts.Modules:WaitForChild("ControlLock"))
local SoundModule = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("SoundModule"))
local Types = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("Types"))

-- Skeleton rig (with an AnimationController + Animation inside) designed in Studio as a child.
local anim = script:WaitForChild("Animation")

local rigTemplate: Model = script:WaitForChild("Skeleton")
ContentProvider:PreloadAsync({ rigTemplate, anim })

local RIG_DISTANCE = 2    -- studs in front of the victim
local SAFETY_TIMEOUT = 5 -- fail-safe cleanup if the animation never fires .Ended (tune > anim length)

-- one scare per victim at a time, on this client
local active: { [Types.VFXActor]: boolean } = {}

local function getCharacter(actor: Types.VFXActor): Model?
    if actor:IsA("Player") then
        return actor.Character
    end
    return actor
end

-- Runs on EVERY client: each spawns its own local skeleton in front of the victim. Only the
-- victim's own client also freezes movement and locks the camera looking straight ahead.
function FrightTrap.Play(player: Types.VFXActor)
    if active[player] then return end
    local character = getCharacter(player)
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    active[player] = true

    -- Victim: freeze BEFORE placing the skeleton. A running player would otherwise have the
    -- skeleton pivoted onto a position they've already run past (mid-move), leaving it
    -- misaligned. ControlLock kills input; anchoring the HRP hard-stops leftover momentum so
    -- GetPivot below reads a stable, final position.
    local releaseControls: (() -> ())? = nil
    if player == localPlayer then
        releaseControls = ControlLock.Acquire()
    end

    -- Skeleton 2 studs in front of the (now stationary) victim, facing them, feet on the ground.
    -- GetPivot() sits at the R6 HumanoidRootPart (chest height), so we drop the Y to the
    -- character's foot level — otherwise the feet-pivoted skeleton spawns floating at head height.
    local rig = rigTemplate:Clone()
    local pivot = character:GetPivot()
    local frontPos = (pivot * CFrame.new(0, 0, -RIG_DISTANCE)).Position
    local bbCF, bbSize = character:GetBoundingBox()
    local feetY = bbCF.Position.Y - bbSize.Y / 2
    rig:PivotTo(CFrame.new(frontPos.X, feetY, frontPos.Z) * pivot.Rotation * CFrame.Angles(0, math.rad(180), 0))
	rig.Parent = workspace
	
	rig.PrimaryPart.Anchored = true

    -- play the rig's own animation (driven by its AnimationController)
    local animController = rig:FindFirstChildWhichIsA("AnimationController")
    local animator = animController and (animController:FindFirstChildWhichIsA("Animator") or Instance.new("Animator", animController))
    local track = animator and anim and animator:LoadAnimation(anim)

    local soundParent = rig.PrimaryPart
    -- victim only: lock the camera looking straight ahead at the skeleton
    local camConn: RBXScriptConnection? = nil
	if player == localPlayer then
		soundParent = nil
        camera.CameraType = Enum.CameraType.Scriptable

        local head = character:FindFirstChild("Head") or hrp
        camConn = RunService.RenderStepped:Connect(function()
            --level forward view: keep the current facing (yaw), zero pitch, pinned to the head
            camera.CFrame = CFrame.new(head.Position) * hrp.CFrame.Rotation
        end)
    end

    local cleaned = false
    local function cleanup()
        if cleaned then return end
        cleaned = true

        if camConn then camConn:Disconnect() end
        if player == localPlayer then
            hrp.Anchored = false
            camera.CameraType = Enum.CameraType.Custom
            local humanoid = character:FindFirstChildWhichIsA("Humanoid")
            if humanoid then
                camera.CameraSubject = humanoid
            end
            if releaseControls then releaseControls() end
        end

        rig:Destroy()
        active[player] = nil
    end

    if track then
		track.Looped = false --must be false so .Ended fires
		SoundModule.Play("Skeleton", soundParent)
        track:Play()
        track.Stopped:Once(cleanup)
    end

    --fail-safe: never leave the camera/controls locked if .Ended never fires (missing/looping anim)
    task.delay(SAFETY_TIMEOUT, cleanup)
end

return FrightTrap
