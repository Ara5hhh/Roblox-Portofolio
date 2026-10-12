local RunService = game:GetService("RunService")

local Hopscotch = {}

local localPlayer = game.Players.LocalPlayer
local camera = workspace.CurrentCamera

local VFX = require(script.Parent.Parent:WaitForChild("VFX"))

local DASH_SPEED = 150      -- studs/sec, held flat until the tail-off (tune for reach/power)
local DASH_DURATION = 0.4     -- seconds, keep in sync with DASH_DURATION in VFX.Abilities.Hopscotch (hardcoded to avoid a cyclic require)
local SLOWDOWN_TIME = 0.1     -- seconds before the end to ease speed down to 0
local WALL_STOP_PADDING = 0.25
local DASH_COLLISION_GROUP = "Hopscotch"

local isDashing = false

local CORNER_SIGNS = {
    Vector3.new(-1, -1, -1),
    Vector3.new(-1, -1, 1),
    Vector3.new(-1, 1, -1),
    Vector3.new(-1, 1, 1),
    Vector3.new(1, -1, -1),
    Vector3.new(1, -1, 1),
    Vector3.new(1, 1, -1),
    Vector3.new(1, 1, 1),
}

-- Returns a box aligned to `referenceCFrame` that encloses the parts which physically collide
-- during Hopscotch. Using Head + Torso avoids false hits from non-colliding limbs or held tools.
local function getCollisionCastBox(referenceCFrame: CFrame, parts: {BasePart}): (CFrame, Vector3)
    local minimum = Vector3.new(math.huge, math.huge, math.huge)
    local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)

    for _, part in parts do
        local relativeCFrame = referenceCFrame:ToObjectSpace(part.CFrame)
        local halfSize = part.Size / 2
        for _, signs in CORNER_SIGNS do
            local localCorner = Vector3.new(
                halfSize.X * signs.X,
                halfSize.Y * signs.Y,
                halfSize.Z * signs.Z
            )
            local corner = relativeCFrame:PointToWorldSpace(localCorner)
            minimum = Vector3.new(
                math.min(minimum.X, corner.X),
                math.min(minimum.Y, corner.Y),
                math.min(minimum.Z, corner.Z)
            )
            maximum = Vector3.new(
                math.max(maximum.X, corner.X),
                math.max(maximum.Y, corner.Y),
                math.max(maximum.Z, corner.Z)
            )
        end
    end

    local localCenter = (minimum + maximum) / 2
    return referenceCFrame * CFrame.new(localCenter), maximum - minimum
end



function Hopscotch.CastAbility()
    if isDashing then return end

    local character = localPlayer.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    local torso = character:FindFirstChild("Torso")
    if not hrp or not hrp:IsA("BasePart")
        or not head or not head:IsA("BasePart")
        or not torso or not torso:IsA("BasePart") then return end

    isDashing = true

    -- VFXBridge only broadcasts this ability's VFX to OTHER clients (PlayersExcept the
    -- caster), so the caster has to trigger their own copy locally. Play() blocks for
    -- DASH_DURATION internally, so spawn it off-thread.
    task.spawn(function()
        VFX.Play("Hopscotch")
    end)

    -- Snapshot the dash direction in WORLD space at cast time so the path is a
    -- dead-straight line for the whole dash (no curving mid-dash).
    local dashDir = hrp.CFrame.LookVector
    local dashStartPosition = hrp.Position

    -- One swept query covers the entire fixed path. RaycastParams.CollisionGroup makes the
    -- query obey the same collision matrix as the phasing body, so regular phase-through map
    -- geometry is ignored while the dedicated static borders are detected regardless of width.
    local castCFrame, castSize = getCollisionCastBox(hrp.CFrame, {head, torso})
    local castParams = RaycastParams.new()
    castParams.FilterType = Enum.RaycastFilterType.Exclude
    castParams.FilterDescendantsInstances = {character}
    castParams.CollisionGroup = DASH_COLLISION_GROUP
    castParams.RespectCanCollide = true

    local wallResult = workspace:Blockcast(
        castCFrame,
        castSize,
        dashDir * (DASH_SPEED * DASH_DURATION),
        castParams
    )
    local wallStopDistance = if wallResult
        then math.max(0, wallResult.Distance - WALL_STOP_PADDING)
        else nil

    -- Attachment (reuse the character's RootAttachment if present)
    local attachment = hrp:FindFirstChild("RootAttachment")
    local createdAttachment = false
    if not attachment or not attachment:IsA("Attachment") then
        attachment = Instance.new("Attachment")
        attachment.Name = "RootAttachment"
        attachment.Parent = hrp
        createdAttachment = true
    end

    -- Flat, full-power velocity that snaps to top speed instantly, then eases down
    -- to 0 over the last SLOWDOWN_TIME seconds so the stop isn't a jarring wall-slam.
    local linVel = Instance.new("LinearVelocity")
    linVel.Attachment0 = attachment
    linVel.RelativeTo = Enum.ActuatorRelativeTo.World
    linVel.MaxForce = math.huge
    linVel.VectorVelocity = dashDir * DASH_SPEED
    linVel.Parent = hrp

    -- phasing (collide)
    local originalHeadCollisionGroup = head.CollisionGroup
    local originalTorsoCollisionGroup = torso.CollisionGroup
    head.CollisionGroup = DASH_COLLISION_GROUP
    torso.CollisionGroup = DASH_COLLISION_GROUP

    -- FULLY FREEZE THE CAMERA: snapshot its current orientation and pin it to the
    -- (moving) head so the world streams past but the player can't look around.
    local frozenRot = camera.CFrame - camera.CFrame.Position -- rotation-only CFrame
    local previousCameraType = camera.CameraType
    camera.CameraType = Enum.CameraType.Scriptable

    local elapsed = 0
    local finished = false
    local movementConn: RBXScriptConnection? = nil
    local cameraConn: RBXScriptConnection? = nil

    local function finishDash()
        if finished then return end
        finished = true

        if movementConn then
            movementConn:Disconnect()
            movementConn = nil
        end
        if cameraConn then
            cameraConn:Disconnect()
            cameraConn = nil
        end

        if linVel.Parent then
            linVel:Destroy()
        end
        if hrp.Parent then
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
        if createdAttachment and attachment.Parent then
            attachment:Destroy()
        end

        if head.Parent then
            head.CollisionGroup = originalHeadCollisionGroup
        end
        if torso.Parent then
            torso.CollisionGroup = originalTorsoCollisionGroup
        end

        camera.CameraType = previousCameraType
        isDashing = false
    end

    -- Movement/collision prediction belongs before physics. The only per-step collision work is
    -- scalar distance math; the spatial query above runs once per cast.
    movementConn = RunService.PreSimulation:Connect(function(delta)
        if not character.Parent or not hrp.Parent or not head.Parent then
            finishDash()
            return
        end

        elapsed += delta
        local remaining = DASH_DURATION - elapsed
        if remaining <= 0 then
            finishDash()
            return
        end

        local speed = DASH_SPEED
        if remaining < SLOWDOWN_TIME then
            speed *= math.clamp(remaining / SLOWDOWN_TIME, 0, 1)
        end

        if wallStopDistance then
            local travelled = math.max(0, (hrp.Position - dashStartPosition):Dot(dashDir))
            local predictedTravel = travelled + speed * delta
            if predictedTravel >= wallStopDistance then
                finishDash()
                return
            end
        end

        linVel.VectorVelocity = dashDir * speed
    end)

    cameraConn = RunService.RenderStepped:Connect(function()
        if not head.Parent then
            finishDash()
            return
        end
        -- Hold the frozen orientation while tracking the moving head.
        camera.CFrame = CFrame.new(head.Position) * frozenRot
    end)
end


return Hopscotch
