local BlackHole = {}

local Traps = require(game.ServerScriptService.Server.Traps)
local RealmTrap = require(game.ServerScriptService.Modules.RealmTrap)
local ParticipantService = require(game.ServerScriptService.Server.ParticipantService)

local Types = require(game.ReplicatedStorage.Modules.Shared.Types)

local BridgeNet = require(game.ReplicatedStorage.Modules.Library.BridgeNet2)
local VFXBridge = BridgeNet.ServerBridge("VFX")

-- How long to let the client vortex play before exiling. Keep in sync with SINK_TIME in
-- the client VFX (Client.VFX.Abilities.BlackHole) — a touch longer so the sink finishes first.
local VFX_DURATION = 2

-- Plays the vortex on every client (victim gets camera + sink, others just watch the vortex),
-- waits for it to finish, exiles the victim into the realm, then restores their camera.
local function getVictimActorAndCharacter(victim)
    if ParticipantService.IsParticipant(victim) then
        return victim.Player or ParticipantService.GetCharacter(victim), ParticipantService.GetCharacter(victim)
    end
    if typeof(victim) == "Instance" and victim:IsA("Player") then
        return victim, victim.Character
    end
    return nil, nil
end

-- Shared by ItFollows so both abilities use exactly the same sink, camera, realm teleport,
-- failure recovery, and realm-entry client effect.
function BlackHole.Exile(victim, returnCFrame: CFrame)
    local actor, character = getVictimActorAndCharacter(victim)
    if not actor then return end
    VFXBridge:Fire(BridgeNet.AllPlayers(), {
        player = actor,
        vfxName = "BlackHole",
        Status = "Play",
        variant = "Victim",
    })

    task.wait(VFX_DURATION)

    local trapped = RealmTrap.Trap(victim, returnCFrame)
    if not trapped and character and character.PrimaryPart then
        character:PivotTo(returnCFrame) --couldn't trap: undo the client's visual sink
    end

    VFXBridge:Fire(BridgeNet.AllPlayers(), {
        player = actor,
        vfxName = "BlackHole",
        Status = "Stop",
        variant = "Victim",
    })
end

function BlackHole.CastAbility(player, point: Vector3)
    if typeof(point) == "Vector3" then
        --single-use ground wormhole: exiles the FIRST player who comes within range.
        --vfxName is nil here — BlackHole drives its own vfx to AllPlayers so the vortex,
        --the sink wait, and the exile stay in lockstep.
        Traps.AddTrap(point, function(victim)
            local _, character = getVictimActorAndCharacter(victim)
            --capture the caught spot BEFORE the client sinks the character, so escaping
            --returns them to solid ground
            local returnCFrame = character and character:GetPivot()
            if not returnCFrame then return end

            --run off the trap thread so Traps.AddTrap's own trigger bookkeeping isn't blocked
            task.spawn(BlackHole.Exile, victim, returnCFrame)
        end, nil, player)
    end

    local returnParams: Types.PlayerActionData = {
        Success = true,
    }

    return returnParams
end

return BlackHole
