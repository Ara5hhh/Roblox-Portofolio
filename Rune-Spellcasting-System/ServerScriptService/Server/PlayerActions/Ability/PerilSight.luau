--BERKANA-- (was "RevealTraps"; renamed to match the Runes data key so RuneAbilityModules
--resolves it. The AbilityBridge name below stays "RevealTraps" to match the client-side
--effect module Client.Abilities.RevealTraps.)

local Types = require(game.ReplicatedStorage.Modules.Shared.Types)

local BridgeNet = require(game.ReplicatedStorage.Modules.Library.BridgeNet2)
local AbilityBridge = BridgeNet.ServerBridge("Ability")

local Traps = require(game.ServerScriptService.Server.Traps)

local PerilSight = {}

local TRAP_REVEALING_DISTANCE = 50

function PerilSight.CastAbility(player:Player)
	if not player.Character then return end
	local hrp:BasePart = player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local trapPositions:{Vector3} = {}

	for _, trap in pairs(Traps.GetTraps()) do

		if typeof(trap) == "Vector3" then
			if (hrp.Position - trap).Magnitude <= TRAP_REVEALING_DISTANCE then
				table.insert(trapPositions, trap)
			end
		else
			if (hrp.Position - trap:GetPivot().Position).Magnitude <= TRAP_REVEALING_DISTANCE then
				table.insert(trapPositions, trap:GetPivot().Position)
			end
		end
	end

	local abilityData:Types.AbilityData = {
		AbilityName = "RevealTraps", --client effect module (Client.Abilities.RevealTraps)
		AbilityData = trapPositions
	}

    AbilityBridge:Fire(player, abilityData)


    local returnParams:Types.PlayerActionData = {
        Success = true,
        AffectedPlayer = nil,
        OtherVFXName = nil
    }

    return returnParams
end

return PerilSight
