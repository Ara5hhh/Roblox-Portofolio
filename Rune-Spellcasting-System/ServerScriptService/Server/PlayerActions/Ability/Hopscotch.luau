local Hopscotch = {}

local Types = require(game.ReplicatedStorage.Modules.Shared.Types)

local BridgeNet = require(game.ReplicatedStorage.Modules.Library.BridgeNet2)
local AbilityBridge = BridgeNet.ServerBridge("Ability")


function Hopscotch.CastAbility(player:Player)
    

    local abilityArgs:Types.AbilityData = {
        AbilityName = "Hopscotch",
        AbilityData = nil
    }

    AbilityBridge:Fire(player, abilityArgs)


    local returnParams:Types.PlayerActionData = {
        Success = true,
        AffectedPlayer = nil,
        OtherVFXName = "Hopscotch"
    }

    return returnParams
end

return Hopscotch
