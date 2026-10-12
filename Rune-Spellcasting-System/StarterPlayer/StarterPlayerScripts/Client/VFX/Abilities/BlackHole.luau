local BlackHole = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundModule = require(ReplicatedStorage.Modules.Shared.SoundModule)
local Types = require(ReplicatedStorage.Modules.Shared.Types)

local localPlayer = game.Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Attachment (with particle emitters) designed in Studio as a child of this ModuleScript.
local vortexTemplate: Attachment = script:WaitForChild("Vortex")

local SINK_DEPTH = 8         -- studs the character sinks into the vortex
local SINK_TIME = 1.8        -- seconds to sink (keep in sync with VFX_DURATION in the server BlackHole ability)
local SINK_TWEENINFO = TweenInfo.new(SINK_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- how steeply (degrees) the forced first-person camera pitches down toward the vortex
local CAMERA_PITCH = 75

-- Fail-safe: if the server's Stop never arrives (error, disconnect, etc.), self-restore the
-- camera/anchor after this long so a victim can NEVER be left permanently camera-locked.
local SAFETY_TIMEOUT = 8

-- per-victim visual state, so Stop tears down the right one
local active: {[Types.VFXActor]: any} = {}

local function getCharacter(actor: Types.VFXActor): Model?
    if actor:IsA("Player") then
        return actor.Character
    end
    return actor
end

local function getFeetPosition(character: Model, hrp: BasePart): Vector3
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { character }

    local result = workspace:Raycast(hrp.Position, Vector3.new(0, -10, 0), rayParams)
    return result and result.Position or (hrp.Position - Vector3.new(0, 3, 0))
end

-- Tears down the effect for `player`. Safe to call more than once (Stop + the safety timer
-- can both fire). Restores the local victim's camera to normal play regardless of what it
-- was before — never back to Scriptable.
local function teardown(player: Types.VFXActor)
    local state = active[player]
    if not state then return end
    active[player] = nil

    if state.safetyThread and state.safetyThread ~= coroutine.running() then
        task.cancel(state.safetyThread)
    end
    if state.anchor then
        state.anchor:Destroy() --also destroys the cloned vortex attachment
    end
    if state.sound then
        state.sound:Destroy()
    end

    if player == localPlayer then
        if state.camConn then state.camConn:Disconnect() end
        if state.sinkTween then state.sinkTween:Cancel() end
        if state.hrp then state.hrp.Anchored = false end

        camera.CameraType = Enum.CameraType.Custom
        local character = localPlayer.Character
        local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
        if humanoid then
            camera.CameraSubject = humanoid
        end
    end
end

-- Runs on EVERY client for the trapped player. The victim's own client also gets the
-- camera-down + character sink; other clients just render the vortex at their feet.
function BlackHole.Play(player: Types.VFXActor)
    if active[player] then return end --already running for this victim
    local character = getCharacter(player)
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local feetPos = getFeetPosition(character, hrp)

    -- vortex at the victim's feet (a local, anchored visual on this client)
    local anchor = Instance.new("Part")
    anchor.Name = "BlackHoleVortex"
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.Transparency = 1
    anchor.Size = Vector3.one
    anchor.CFrame = CFrame.new(feetPos)
    anchor.Parent = workspace

    local vortex = vortexTemplate:Clone()
    vortex.Parent = anchor
    --the template attachment carries a large design-time offset; zero it so the emitters
    --sit exactly on the anchor (at the feet) instead of ~290 studs away
	vortex.CFrame = CFrame.identity
	
	local sinkSound = SoundModule.Play("BlackHole", anchor)

    local state = { anchor = anchor, sound = sinkSound }
    active[player] = state

    if player == localPlayer then
        state.hrp = hrp
        local head = character:FindFirstChild("Head") or hrp

        -- Stay in FIRST PERSON, but force the camera to look straight down at the vortex and
        -- lock it there. Re-pin it to the (sinking) head every frame so the player watches the
        -- vortex rise up and swallow them from their own eyes. Third person would show nothing
        -- here — the characters are invisible.
        camera.CameraType = Enum.CameraType.Scriptable
        state.camConn = RunService.RenderStepped:Connect(function()
            camera.CFrame = CFrame.new(head.Position) * hrp.CFrame.Rotation * CFrame.Angles(-math.rad(CAMERA_PITCH), 0, 0)
        end)

        -- anchor so the sink is smooth AND so the server's later PivotTo lands reliably
        -- (an anchored part isn't fighting client physics)
        hrp.Anchored = true
        state.sinkTween = TweenService:Create(hrp, SINK_TWEENINFO, {
            CFrame = hrp.CFrame + Vector3.new(0, -SINK_DEPTH, 0),
        })
        state.sinkTween:Play()

        state.safetyThread = task.delay(SAFETY_TIMEOUT, function()
            teardown(player)
        end)
    end
end

-- Fired by the server AFTER it has pivoted the victim into the realm.
function BlackHole.Stop(player: Types.VFXActor)
	teardown(player)

    SoundModule.Play("EnterRoomRealm")
end

return BlackHole
