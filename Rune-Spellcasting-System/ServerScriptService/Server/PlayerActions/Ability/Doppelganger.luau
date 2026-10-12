local Doppelganger = {}

local CS = game:GetService("CollectionService")

local Types = require(game.ReplicatedStorage.Modules.Shared.Types)
local AIMovement = require(game.ServerScriptService.Modules.AIMovement)

local DoppelgangerTemplate = script:WaitForChild("DoppelgangerTemplate")

local SameSideBinder = require(game.ReplicatedStorage.Modules.Library.SameSideBinder)
local BridgeNet = require(game.ReplicatedStorage.Modules.Library.BridgeNet2)

local AbilityBridge = BridgeNet.ServerBridge("Ability")
local DoppelgangerBind = SameSideBinder.CreateBind("Doppelganger")

local VFXBridge = BridgeNet.ServerBridge("VFX")

local WardService = require(game.ServerScriptService.Server.WardService)

DoppelgangerBind:Connect(function(args:Types.DoppelgangerData)
    local vfxParams:Types.VFXEventData = {
        vfxName = "Explosion",
        Status = "Play",
        additionalData = args.Doppelganger:GetPivot()
    }
    VFXBridge:Fire(BridgeNet.AllPlayers(), vfxParams)

    --WARD: the trigger player gets the knockback; a warded one consumes the ward instead
    if not WardService.TryConsume(args.TriggerPlayer) then
        local abilityParams:Types.AbilityData = {
            AbilityName = "Tempest"
        }
        AbilityBridge:Fire(args.TriggerPlayer, abilityParams)
    end

    args.Doppelganger:Destroy()
end)


--Tunables
local DOPPELGANGER_LIFETIME = 20  --seconds a never-triggered decoy survives before self-despawning
local DOPPELGANGER_WALK_SPEED = 10 --same base speed used by Client/Keybinds/Sprint
local PEDESTAL_APPROACH_CLEARANCE = 3

local function getPedestalApproachPosition(pedestal: Model, fromPosition: Vector3): Vector3
    local boundingCFrame, boundingSize = pedestal:GetBoundingBox()
    local center = boundingCFrame.Position
    local horizontalDirection = Vector3.new(fromPosition.X - center.X, 0, fromPosition.Z - center.Z)
    if horizontalDirection.Magnitude < 0.001 then
        horizontalDirection = Vector3.new(boundingCFrame.LookVector.X, 0, boundingCFrame.LookVector.Z)
    end
    if horizontalDirection.Magnitude < 0.001 then
        horizontalDirection = Vector3.xAxis
    end

    local outsideRadius = math.max(boundingSize.X, boundingSize.Z) / 2 + PEDESTAL_APPROACH_CLEARANCE
    local flatPosition = center + horizontalDirection.Unit * outsideRadius

    --Project the approach point onto the floor. The pedestal itself is excluded so the ray cannot
    --select its top and put the destination back inside the obstacle.
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {pedestal}

    local rayOrigin = Vector3.new(flatPosition.X, center.Y + boundingSize.Y / 2 + 5, flatPosition.Z)
    local rayResult = workspace:Raycast(
        rayOrigin,
        Vector3.new(0, -(boundingSize.Y + 50), 0),
        raycastParams
    )

    if rayResult then
        return rayResult.Position + Vector3.new(0, 0.1, 0)
    end

    return Vector3.new(flatPosition.X, center.Y - boundingSize.Y / 2, flatPosition.Z)
end

function Doppelganger.CastAbility(player:Player)
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local doppelganger = DoppelgangerTemplate:Clone()
    doppelganger.Name = "Doppelganger"
    doppelganger:PivotTo(hrp.CFrame)

    --The embedded orb does not pass through ItemClass:GiveToPlayer(), which is what normally
    --unanchors held orb parts. One anchored part joined to the rig anchors the whole assembly.
    for _, descendant in doppelganger:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Anchored = false
        end
    end

    --hide the body (players render invisible), but leave the orb visible so it reads as a
    --player carrying one. The orb sits under RightArm, so hiding only the direct child parts
    --keeps it visible.
    for _, part in pairs(doppelganger:GetChildren()) do
        if part:IsA("Part") then
            part.Transparency = 1
        end
    end

    --orb team setup
    local rightArm = doppelganger:FindFirstChild("RightArm")
    if rightArm then
        local orb = rightArm:FindFirstChild("Orb")
        if orb then
            orb:SetAttribute("OwnerId", player.UserId)
            CS:AddTag(orb, "Orb")
        end
    end

    --destination: the caster's own pedestal, so the decoy mimics them delivering their orb
    local targetPos = nil
    for _, pedestal in pairs(workspace.Pedestals:GetChildren()) do
        if pedestal:GetAttribute("OwnerId") == player.UserId then
            targetPos = getPedestalApproachPosition(pedestal, hrp.Position)
            break
        end
    end

    if not targetPos then
        warn(string.format("[Doppelganger] No pedestal found for %s (%d)", player.Name, player.UserId))
    end

    doppelganger.Parent = workspace

    --Guaranteed self-despawn: a decoy that never gets jumpscared cleans itself up. (Being
    --jumpscared destroys it earlier via DoppelgangerBind; the guard makes that safe.)
    task.delay(DOPPELGANGER_LIFETIME, function()
        if doppelganger.Parent then
            doppelganger:Destroy()
        end
    end)

    --Navigate in the background so the cast returns immediately. If there's no humanoid/rootpart
    --or the caster owns no pedestal, the decoy simply stands in place until its lifetime ends —
    --it no longer despawns after ~1s.
    local humanoid = doppelganger:WaitForChild("Humanoid", 3)
    local rootPart = doppelganger:FindFirstChild("HumanoidRootPart")
    if humanoid and rootPart and targetPos then
        humanoid.WalkSpeed = DOPPELGANGER_WALK_SPEED

        local movement = AIMovement.New(doppelganger, {
            AgentCanJump = false,
            ReachDistance = 6,
            DebugWaypoints = false,
        })
        if movement then
            movement.DestinationReached.Event:Once(function()
                if doppelganger.Parent then
                    doppelganger:Destroy()
                end
            end)
            movement:MoveTo(targetPos)
        end
    end

    return { Success = true }
end

return Doppelganger
