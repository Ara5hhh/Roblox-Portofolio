local TellBells = {}

local Traps = require(game.ServerScriptService.Server.Traps)
local ParticipantService = require(game.ServerScriptService.Server.ParticipantService)

local Types = require(game.ReplicatedStorage.Modules.Shared.Types)

local BridgeNet = require(game.ReplicatedStorage.Modules.Library.BridgeNet2)
local VFXBridge = BridgeNet.ServerBridge("VFX")

function TellBells.CastAbility(player, model: Model)
    if model then
        --interactable trap. When someone opens the object the chime sticks to THEM: fire the
        --vfx to AllPlayers so everyone nearby can hear the victim ring as they move.
        --vfxName is nil so the trap system's generic PlayersExcept fire doesn't double up.
        Traps.AddTrap(model, function(victim)
            local actor = if ParticipantService.IsParticipant(victim)
                then victim.Player or ParticipantService.GetCharacter(victim)
                else victim
            if not actor then return end
            VFXBridge:Fire(BridgeNet.AllPlayers(), {
                player = actor,
                vfxName = "TellBells",
                Status = "Play",
                variant = "Victim",
            })
        end, nil, player, "TellBells")
    end

    local returnParams: Types.PlayerActionData = {
        Success = true,
    }

    return returnParams
end

return TellBells
