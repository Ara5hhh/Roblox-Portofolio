local StaticCharge = {}

local Traps = require(game.ServerScriptService.Server.Traps)

function StaticCharge.CastAbility(player, model:Model)
    if not model then return end

    Traps.AddTrap(model, nil, "Lightning", player, "StaticCharge")
end

return StaticCharge
