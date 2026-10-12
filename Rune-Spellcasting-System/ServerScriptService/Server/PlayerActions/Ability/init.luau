local Ability = {}

local CS = game:GetService("CollectionService")

local Types = require(game.ReplicatedStorage.Modules.Shared.Types)
local PointsData = require(game.ReplicatedStorage.Modules.Data.Points)
local Runes = require(game.ReplicatedStorage.Modules.Data.Runes)
local SoundModule = require(game.ReplicatedStorage.Modules.Shared.SoundModule)

local RuneAbilityModules = {}
for _, abilityModule:ModuleScript in pairs(script:GetChildren()) do
	task.spawn(function()
		RuneAbilityModules[abilityModule.Name] = require(abilityModule)
	end)
end

function Ability.PerformAction(player:Player, additionalData)
	
	--retrieving runes posessed by the player
	if not player.Backpack then return end

	--collect the rune tools WITHOUT consuming them yet — we only burn them once we know
	--the cast will actually go through (see the targeting check below)
	local posessedRunes:{string} = {}
	local runeTools:{Tool} = {}

	for _, tool in pairs(player.Backpack:GetChildren()) do
		local toolmodel = tool:FindFirstChildWhichIsA("Model")
		if not toolmodel then continue end

		--tag check
		if not CS:HasTag(toolmodel, "Rune") then continue end

		local runeTypeName = toolmodel:GetAttribute("Type")
		if not runeTypeName then continue end

		table.insert(posessedRunes, runeTypeName)
		table.insert(runeTools, tool)
	end

	--get matching rune ability module
	local abilityName = Runes.GetAbilityFromRunes(posessedRunes)
	if not abilityName then return end
	local abilityModule = RuneAbilityModules[abilityName]
	if not abilityModule then return end

	--trap-style abilities need a target from the client. If the player pressed Q without
	--aiming at a valid one, bail BEFORE consuming the runes so a mis-aim isn't punished.
	local abilityType = Runes.GetAbilityType(abilityName)
	if abilityType == "Interactables" then
		if typeof(additionalData) ~= "Instance" or not additionalData:IsA("Model") or not CS:HasTag(additionalData, "Openable") then
			return {
				Success = false,
				FailureReason = "NoInteractableTarget",
			} :: Types.PlayerActionData
		end
	elseif abilityType == "Cursor" then
		if typeof(additionalData) ~= "Vector3" then
			return {
				Success = false,
				FailureReason = "NoFloorTarget",
			} :: Types.PlayerActionData
		end
	end

	-- Some untargeted spells still need server-only preparation before their runes are burned.
	-- ItFollows uses this to reserve a currently valid enemy (and to reject a solo cast).
	if type(abilityModule.CanCast) == "function" then
		local canCast, failureReason, preparedData = abilityModule.CanCast(player, additionalData)
		if not canCast then
			return {
				Success = false,
				FailureReason = failureReason or "AbilityUnavailable",
			} :: Types.PlayerActionData
		end
		if preparedData ~= nil then
			additionalData = preparedData
		end
	end

	--validated (or the ability needs no target): NOW consume the runes and cast
	for _, tool in ipairs(runeTools) do
		tool:Destroy()
	end
	player:SetAttribute("RuneCount", 0)

	--cast sound, keyed by how many runes the spell needed (RuneCast1/2/3) — 2D, no parent
	SoundModule.Play(`RuneCast{#runeTools}`, player.PlayerGui)

	return abilityModule.CastAbility(player, additionalData)
end

return Ability
