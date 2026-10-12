local HauntingDecoy = {}

local Traps = require(game.ServerScriptService.Server.Traps)

local SameSideBinder = require(game.ReplicatedStorage.Modules.Library.SameSideBinder)
local OpenableBind = SameSideBinder.CreateBind("Openable")

function HauntingDecoy.CastAbility(player, model:Model)

    if not model then return end
    
    local triggerPos = model:GetPivot().Position

    local function GhostOpens()
        OpenableBind:Fire({model})
    end

    Traps.AddTrap(triggerPos, GhostOpens, nil, player, "HauntingDecoy")

end

return HauntingDecoy
