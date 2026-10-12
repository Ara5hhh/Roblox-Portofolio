--DAGAZ-- (was "SeeNearbyRunes"; renamed to match the Runes data key so RuneAbilityModules
--resolves it. The AbilityBridge name below stays "SeeNearbyRunes" to match the client-side
--effect module Client.Abilities.SeeNearbyRunes.)

local RunicSight = {}

local CS = game:GetService("CollectionService")

local Types = require(game.ReplicatedStorage.Modules.Shared.Types)

local BridgeNet = require(game.ReplicatedStorage.Modules.Library.BridgeNet2)
local AbilityBridge = BridgeNet.ServerBridge("Ability")

local NEARBY_DISTANCE = 100

function RunicSight.CastAbility(player:Player)
    if not player.Character then return end
    if not workspace.Items then return end

    local revealableRunes:{Model} = {}

    for _, item:Model in pairs(workspace.Items:GetChildren()) do
        if not CS:HasTag(item, "Rune") then continue end

        local distance = (item.PrimaryPart.Position - player.Character.PrimaryPart.Position).Magnitude
        if distance <= NEARBY_DISTANCE then
            table.insert(revealableRunes, item)
        end
    end

    local abilityArgs:Types.AbilityData = {
        AbilityName = "SeeNearbyRunes", --client effect module (Client.Abilities.SeeNearbyRunes)
        AbilityData = revealableRunes
    }

    AbilityBridge:Fire(player, abilityArgs)

    local returnParams:Types.PlayerActionData = {
        Success = true,
        AffectedPlayer = nil,
        OtherVFXName = nil
    }

    return returnParams
end


return RunicSight
