local FrightPocket = {}

local Traps = require(game.ServerScriptService.Server.Traps)

local Types = require(game.ReplicatedStorage.Modules.Shared.Types)

function FrightPocket.CastAbility(player, model:Model)
	
	if model then
		Traps.AddTrap(model, nil, "FrightPocket", player, "FrightPocket")
	end
	
	local returnParams:Types.PlayerActionData = {
		Success = true
	}

	return returnParams
	
end

return FrightPocket
