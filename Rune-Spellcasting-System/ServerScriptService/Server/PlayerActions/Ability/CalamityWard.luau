local CalamityWard = {}

local WardService = require(game.ServerScriptService.Server.WardService)

local Types = require(game.ReplicatedStorage.Modules.Shared.Types)

-- Self-cast (no AbilityType): the caster receives immunity from the next rune spell.
function CalamityWard.CastAbility(player: Player)
    WardService.SetWard(player)

    local returnParams: Types.PlayerActionData = {
        Success = true,
    }

    return returnParams
end

return CalamityWard
