local FrightTrap = {}

local Traps = require(game.ServerScriptService.Server.Traps)

local Types = require(game.ReplicatedStorage.Modules.Shared.Types)

function FrightTrap.CastAbility(player, point: Vector3)
    if typeof(point) == "Vector3" then
        --ground proximity trap. On trigger the "FrightTrap" vfx scares the victim (skeleton
        --lunge + frozen, camera-locked) and shows the skeleton to everyone else. The freeze
        --during the animation IS the effect, so no callback is needed.
        Traps.AddTrap(point, nil, "FrightTrap", player, "FrightTrap")
    end

    local returnParams: Types.PlayerActionData = {
        Success = true,
    }

    return returnParams
end

return FrightTrap
