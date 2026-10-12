local Traps = {}

local Types = require(game.ReplicatedStorage.Modules.Shared.Types)

local BridgeNet = require(game.ReplicatedStorage.Modules.Library.BridgeNet2)
local VFXBridge = BridgeNet.ServerBridge("VFX")
local TrapBridge = BridgeNet.ServerBridge("Trap")

local SameSideBinder = require(game.ReplicatedStorage.Modules.Library.SameSideBinder)
local OpenableBind = SameSideBinder.CreateBind("Openable") --firing it toggles a container (calls Toggle)

local PointsService = require(game.ServerScriptService.Server.PointsService)
local WardService = require(game.ServerScriptService.Server.WardService)
local ParticipantService = require(game.ServerScriptService.Server.ParticipantService)


local ActiveTraps = {}

local BOT_STUN_DURATIONS = {
    FrightTrap = 5,
    Lightning = 5.5,
}

local function resolveParticipant(target)
    if ParticipantService.IsParticipant(target) then
        return target
    end
    if typeof(target) == "Instance" then
        if target:IsA("Player") then
            return ParticipantService.FromPlayer(target)
        elseif target:IsA("Model") then
            return ParticipantService.FromCharacter(target)
        end
    end
    return nil
end

local function getActor(participant)
    return participant.Player or ParticipantService.GetCharacter(participant)
end

local function getOtherRecipients(participant)
    if participant.Player then
        return BridgeNet.PlayersExcept({participant.Player})
    end
    return BridgeNet.AllPlayers()
end

local function applyBotTrapEffect(participant, vfxName:string?)
    if participant.Kind ~= "Bot" or not vfxName then return end
    local duration = BOT_STUN_DURATIONS[vfxName]
    if not duration then return end

	local character = ParticipantService.GetCharacter(participant)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = Vector3.zero
	end

    local current = ParticipantService.GetAttribute(participant, "BotStunnedUntil")
    ParticipantService.SetAttribute(
        participant,
        "BotStunnedUntil",
        math.max(type(current) == "number" and current or 0, os.clock() + duration)
    )
end

function Traps.GetTraps()
	local trapsTable:{Model | Vector3} = {}
	
	for modelorpoint, _ in pairs(ActiveTraps) do
		table.insert(trapsTable, modelorpoint)
	end
	
	return trapsTable
end

local POINT_TRAP_TRIGGER_DISTANCE = 5
local POINT_TRAP_ARM_DELAY = 3 --seconds a point trap stays inert after placement, so the trapper can step clear

function Traps.AddTrap(modelOrPoint: (Model | Vector3), callback, vfxName:string?, trapper, pointsKey:string?)
    --SetupTrap telegraph, shown only to the trapper, at the trap's location (works for a point
    --trap or a Model/interactable trap)
    local trapperParticipant = resolveParticipant(trapper)
    local trapperPlayer = trapperParticipant and trapperParticipant.Player
        or (typeof(trapper) == "Instance" and trapper:IsA("Player") and trapper)
    if trapperPlayer then
        local setupCFrame:CFrame? = nil
        if typeof(modelOrPoint) == "Instance" and modelOrPoint:IsA("Model") then
            setupCFrame = modelOrPoint:GetPivot()
        elseif typeof(modelOrPoint) == "Vector3" then
            setupCFrame = CFrame.new(modelOrPoint)
        end

        if setupCFrame then
            VFXBridge:Fire(trapperPlayer, {
                player = trapperPlayer,
                vfxName = "SetupTrap",
                Status = "Play",
                additionalData = setupCFrame,
            })
        end
    end

    local trapParams:Types.ClientTrapData = {
            Action = "Add",
            ModelOrPoint = modelOrPoint,
            VFXName = vfxName
        }

    if typeof(modelOrPoint) == "Instance" and modelOrPoint:IsA("Model") then
        --if the openable is currently open, force it closed (bypassing the toggle debounce)
        --before arming the trap: a trapped openable must never sit open
        if modelOrPoint:GetAttribute("IsOpen") then
            OpenableBind:Fire({modelOrPoint, true})
        end

        ActiveTraps[modelOrPoint] = {
            Callback = callback,
            VFXName = vfxName,
            Trapper = trapperParticipant or trapper,
            PointsKey = pointsKey,
        }

        TrapBridge:Fire(BridgeNet.AllPlayers(), trapParams)

    elseif typeof(modelOrPoint) == "Vector3" then

        --register the point too, so it shows up in GetTraps (PerilSight/RevealTraps). Model traps
        --were registered above; point traps weren't, so they were never revealed.
        ActiveTraps[modelOrPoint] = {
            Callback = callback,
            VFXName = vfxName,
            Trapper = trapperParticipant or trapper,
            PointsKey = pointsKey,
        }

        TrapBridge:Fire(BridgeNet.AllPlayers(), trapParams)

        task.spawn(function()
            --arming delay: stay inert so the trapper can walk out of range without springing it
            task.wait(POINT_TRAP_ARM_DELAY)

            local triggered = false
            while not triggered do
                for _, participant in ipairs(ParticipantService.GetAlive()) do
                    local character = ParticipantService.GetCharacter(participant)
                    if not character then continue end

                    local hrp = character:FindFirstChild("HumanoidRootPart")
                    if not hrp then continue end

                    if (hrp.Position - modelOrPoint).Magnitude <= POINT_TRAP_TRIGGER_DISTANCE then
                        triggered = true

                        --sprung: drop it from the active set so a reveal can't show a dead trap
                        ActiveTraps[modelOrPoint] = nil

                        --WARD: the trap is still consumed, but a warded victim takes no effect
                        if not WardService.TryConsume(participant) then
                            --traps only PENALIZE the victim now; the trapper gains nothing
                            if pointsKey then
                                PointsService.RemoveFor(pointsKey, participant)
                            end

                            applyBotTrapEffect(participant, vfxName)

                            local callbackTarget = participant.Player or participant
                            if callback then callback(callbackTarget) end
                            if vfxName then
                                VFXBridge:Fire(getOtherRecipients(participant), {
                                    player = getActor(participant),
                                    vfxName = vfxName,
                                    Status = "Play",
                                    variant = "Victim"
                                })
                            end
                        end

                        TrapBridge:Fire(getOtherRecipients(participant), {
                            Action = "Remove",
                            ModelOrPoint = modelOrPoint
                        })

                        break
                    end
                end
                task.wait(0.1) --check magnitudes every 0.1s
            end
        end)
    end
end

function Traps.Check(model:Model, target)
    if not ActiveTraps[model] then return end

    local participant = resolveParticipant(target)
    if not participant then return end

    local trapParams:Types.ClientTrapData = {
        Action = "Remove",
        ModelOrPoint = model
    }

    TrapBridge:Fire(getOtherRecipients(participant), trapParams)

    --WARD: the trap is still consumed, but a warded victim takes no effect (no vfx/steal/callback)
    if WardService.TryConsume(participant) then
        ActiveTraps[model] = nil
        return
    end

    if ActiveTraps[model].VFXName then
        local vfxParams:Types.VFXEventData = {
            player = getActor(participant),
            vfxName = ActiveTraps[model].VFXName,
            Status = "Play",
            variant = "Victim"
        }
        VFXBridge:Fire(getOtherRecipients(participant), vfxParams)
    end

    applyBotTrapEffect(participant, ActiveTraps[model].VFXName)

    --traps only PENALIZE the victim now; the trapper gains nothing
    if ActiveTraps[model].PointsKey then
        PointsService.RemoveFor(ActiveTraps[model].PointsKey, participant)
    end

    if ActiveTraps[model].Callback then
        ActiveTraps[model].Callback(participant.Player or participant)
    end

    ActiveTraps[model] = nil
end


return Traps
