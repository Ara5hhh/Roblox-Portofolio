local GloomShroud = {}

local Types = require(game.ReplicatedStorage.Modules.Shared.Types)

local BridgeNet = require(game.ReplicatedStorage.Modules.Library.BridgeNet2)
local VFXBridge = BridgeNet.ServerBridge("VFX")

local WardService = require(game.ServerScriptService.Server.WardService)

function GloomShroud.CastAbility(player:Player)
    
    local players = game.Players:GetPlayers()
    
    local i = table.find(players, player)
    if i then
        table.remove(players, i)
    end

    local blindedPlayer = players[math.random(1, #players)]

    --WARD: a warded target consumes the ward instead of being blinded
    if WardService.TryConsume(blindedPlayer) then
        return
    end

    local VFXParams:Types.VFXEventData = {
        vfxName = "GloomShroud",
        Status = "Play"
    }

    VFXBridge:Fire(blindedPlayer, VFXParams)
 
end

return GloomShroud
