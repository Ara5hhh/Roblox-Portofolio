local Flashbang = {}

local Traps = require(game.ServerScriptService.Server.Traps)

local Types = require(game.ReplicatedStorage.Modules.Shared.Types)

function Flashbang.CastAbility(player, model:Model)

    if model then
        Traps.AddTrap(model, nil, "Flashbang", player, "Flashbang")
    end
    

    local returnParams:Types.PlayerActionData = {
		Success = true
	}

	return returnParams
end

return Flashbang
