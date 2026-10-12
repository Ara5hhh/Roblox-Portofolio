local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItFollows = {}

local ParticipantService = require(game.ServerScriptService.Server.ParticipantService)
local WardService = require(game.ServerScriptService.Server.WardService)
local RealmTrap = require(game.ServerScriptService.Modules.RealmTrap)
local BlackHole = require(script.Parent.BlackHole)

local BridgeNet = require(ReplicatedStorage.Modules.Library.BridgeNet2)
local VFXBridge = BridgeNet.ServerBridge("VFX")

local GAME_STARTED = ReplicatedStorage.GAME_INFO.STARTED

local WISP_SPEED = 11
local SPAWN_DISTANCE = 25
local REVEAL_DURATION = 2
local MOVEMENT_DELAY = REVEAL_DURATION
local CONTACT_PADDING = 0.35

local randomGenerator = Random.new()
local warnedMissingTemplate = false
local nextRevealId = 0

type ImmobilizationEntry = {
	Count: number,
	Root: BasePart,
	WasAnchored: boolean,
}

type WispState = {
	Part: BasePart,
	Caster: any,
	Target: any?,
	Height: number,
	MoveAt: number,
	Connection: RBXScriptConnection?,
	SoundConnection: RBXScriptConnection?,
	RevealCleanup: (() -> ())?,
	Destroyed: boolean,
}

local immobilizations: {[Model]: ImmobilizationEntry} = {}
local activeWisps: {[WispState]: boolean} = {}

local function resolveParticipant(actor)
	if ParticipantService.IsParticipant(actor) then
		return actor
	end
	if typeof(actor) == "Instance" then
		if actor:IsA("Player") then
			return ParticipantService.FromPlayer(actor)
		elseif actor:IsA("Model") then
			return ParticipantService.FromCharacter(actor)
		end
	end
	return nil
end

local function getCharacterParts(participant)
	if not ParticipantService.IsParticipant(participant) then return nil end

	local character = ParticipantService.GetCharacter(participant)
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and (character:FindFirstChild("Head") or root)
	if not character or not character.Parent
		or not humanoid or humanoid.Health <= 0
		or not root or not root:IsA("BasePart")
		or not head or not head:IsA("BasePart") then
		return nil
	end

	return character, root, head, humanoid
end

local function isTargetAvailable(participant, caster): boolean
	if not ParticipantService.IsParticipant(participant) or participant == caster or not participant.Connected then
		return false
	end

	local lives = ParticipantService.GetAttribute(participant, "Lives")
	if type(lives) ~= "number" or lives <= 0 then return false end
	if ParticipantService.GetAttribute(participant, "BeingJumpscared") == true then return false end
	if RealmTrap.IsTrapped(participant) then return false end

	return getCharacterParts(participant) ~= nil
end

local function chooseTarget(caster)
	local candidates = {}
	for _, participant in ParticipantService.GetAlive() do
		if isTargetAvailable(participant, caster) then
			table.insert(candidates, participant)
		end
	end

	if #candidates == 0 then return nil end
	return candidates[randomGenerator:NextInteger(1, #candidates)]
end

local function getWispTemplate(): BasePart?
	local template = script:FindFirstChild("WispTemplate")
	if template and template:IsA("BasePart") then
		warnedMissingTemplate = false
		return template
	end

	if not warnedMissingTemplate then
		warnedMissingTemplate = true
		warn("[ItFollows] Add a BasePart named WispTemplate as a direct child of this ModuleScript")
	end
	return nil
end

local function playWispSounds(wisp: BasePart): RBXScriptConnection?
	local appear = wisp:FindFirstChild("WispAppear", true)
	local moving = wisp:FindFirstChild("WispMoving", true)
	local appearSound = if appear and appear:IsA("Sound") then appear else nil
	local movingSound = if moving and moving:IsA("Sound") then moving else nil

	if movingSound then
		movingSound.Looped = true
		movingSound:Stop()
	end
	if not appearSound then
		if movingSound then movingSound:Play() end
		return nil
	end

	appearSound.Looped = false
	appearSound:Stop()
	appearSound:Play()
	if not movingSound then return nil end

	return appearSound.Ended:Once(function()
		if wisp.Parent then
			movingSound:Play()
		end
	end)
end

-- Anchoring is authoritative and lock-counted so two simultaneous wisps cannot unfreeze a
-- target until both reveals have finished.
local function immobilizeTarget(participant)
	local character, root = getCharacterParts(participant)
	if not character or not root then
		return function() end
	end

	local entry = immobilizations[character]
	if entry then
		entry.Count += 1
	else
		entry = {
			Count = 1,
			Root = root,
			WasAnchored = root.Anchored,
		}
		immobilizations[character] = entry
		root.AssemblyLinearVelocity = Vector3.zero
		root.Anchored = true
	end

	if participant.Kind == "Bot" then
		local currentStun = ParticipantService.GetAttribute(participant, "BotStunnedUntil")
		ParticipantService.SetAttribute(
			participant,
			"BotStunnedUntil",
			math.max(type(currentStun) == "number" and currentStun or 0, os.clock() + REVEAL_DURATION)
		)
	end

	local released = false
	return function()
		if released then return end
		released = true

		local current = immobilizations[character]
		if current ~= entry then return end
		current.Count -= 1
		if current.Count > 0 then return end

		immobilizations[character] = nil
		if current.Root.Parent then
			current.Root.Anchored = current.WasAnchored
			if not current.WasAnchored then
				current.Root.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end
end

local function beginReveal(state: WispState, target)
	if state.RevealCleanup then
		state.RevealCleanup()
	end

	nextRevealId += 1
	local revealId = nextRevealId
	local releaseMovement = immobilizeTarget(target)
	local targetPlayer = target.Player
	local stopped = false
	local timeoutThread: thread? = nil

	local function stopReveal()
		if stopped then return end
		stopped = true

		if timeoutThread and timeoutThread ~= coroutine.running() then
			task.cancel(timeoutThread)
		end
		releaseMovement()

		if targetPlayer and targetPlayer.Parent then
			VFXBridge:Fire(targetPlayer, {
				player = targetPlayer,
				vfxName = "ItFollows",
				Status = "Stop",
				variant = "Victim",
				additionalData = { RevealId = revealId },
			})
		end
	end

	state.RevealCleanup = stopReveal

	if targetPlayer then
		VFXBridge:Fire(targetPlayer, {
			player = targetPlayer,
			vfxName = "ItFollows",
			Status = "Play",
			variant = "Victim",
			additionalData = {
				RevealId = revealId,
				Wisp = state.Part,
			},
		})
	end

	timeoutThread = task.delay(REVEAL_DURATION, stopReveal)
end

local function placeWispAroundTarget(state: WispState, target): boolean
	local _, _, head = getCharacterParts(target)
	if not head then return false end

	local angle = randomGenerator:NextNumber(0, math.pi * 2)
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local targetPosition = head.Position
	local spawnPosition = targetPosition + direction * SPAWN_DISTANCE
	state.Height = targetPosition.Y

	local flatTarget = Vector3.new(targetPosition.X, state.Height, targetPosition.Z)
	state.Part.CFrame = CFrame.lookAt(spawnPosition, flatTarget)
	return true
end

local function setTarget(state: WispState, target): boolean
	if not isTargetAvailable(target, state.Caster) then return false end
	if not placeWispAroundTarget(state, target) then return false end

	state.Target = target
	state.MoveAt = os.clock() + MOVEMENT_DELAY
	state.Part:SetAttribute("TargetParticipantId", target.Id)
	beginReveal(state, target)
	return true
end

local cleanupWisp

cleanupWisp = function(state: WispState)
	if state.Destroyed then return end
	state.Destroyed = true
	activeWisps[state] = nil

	if state.Connection then
		state.Connection:Disconnect()
		state.Connection = nil
	end
	if state.SoundConnection then
		state.SoundConnection:Disconnect()
		state.SoundConnection = nil
	end
	if state.RevealCleanup then
		state.RevealCleanup()
		state.RevealCleanup = nil
	end
	if state.Part.Parent then
		state.Part:Destroy()
	end
end

local function captureTarget(state: WispState)
	local target = state.Target
	local character = target and getCharacterParts(target)
	if not target or not character then
		cleanupWisp(state)
		return
	end

	local returnCFrame = character:GetPivot()
	cleanupWisp(state)

	-- The curse reaches the player before checking the ward: contact shatters the ward and
	-- consumes the wisp, while an unwarded target receives BlackHole's complete capture flow.
	if WardService.TryConsume(target) then return end
	task.spawn(BlackHole.Exile, target, returnCFrame)
end

local function updateWisp(state: WispState, deltaTime: number)
	if state.Destroyed then return end
	if not GAME_STARTED.Value or not state.Part.Parent then
		cleanupWisp(state)
		return
	end

	local target = state.Target
	if not target or not isTargetAvailable(target, state.Caster) then
		local replacement = chooseTarget(state.Caster)
		if not replacement or not setTarget(state, replacement) then
			cleanupWisp(state)
		end
		return
	end

	if os.clock() < state.MoveAt then return end

	local _, _, head = getCharacterParts(target)
	if not head then return end

	local currentPosition = state.Part.Position
	local flatTarget = Vector3.new(head.Position.X, state.Height, head.Position.Z)
	local offset = flatTarget - currentPosition
	local distance = offset.Magnitude
	local horizontalContactDistance = math.max(state.Part.Size.X, state.Part.Size.Z) / 2
		+ math.max(head.Size.X, head.Size.Z) / 2
		+ CONTACT_PADDING
	local verticalContactDistance = state.Part.Size.Y / 2 + head.Size.Y / 2 + CONTACT_PADDING
	local verticallyTouching = math.abs(state.Height - head.Position.Y) <= verticalContactDistance

	if distance <= horizontalContactDistance then
		if verticallyTouching then
			captureTarget(state)
		end
		return
	end

	local travelDistance = math.min(WISP_SPEED * deltaTime, distance - horizontalContactDistance)
	local nextPosition = currentPosition + offset.Unit * travelDistance
	state.Part.CFrame = CFrame.lookAt(nextPosition, flatTarget)

	-- Swept endpoint check prevents a lag spike from stepping across a small character.
	if verticallyTouching and distance - travelDistance <= horizontalContactDistance then
		captureTarget(state)
	end
end

function ItFollows.CanCast(caster, _additionalData)
	if not getWispTemplate() then
		return false, "AbilityUnavailable"
	end

	local casterParticipant = resolveParticipant(caster)
	if not casterParticipant then
		return false, "AbilityUnavailable"
	end

	local target = chooseTarget(casterParticipant)
	if not target then
		return false, "NoEnemyTarget"
	end

	-- Third return is server-prepared cast data. Ability/init passes it into CastAbility only
	-- after validation, so the client never gets to nominate the victim.
	return true, nil, target
end

function ItFollows.CastAbility(caster, preparedTarget)
	local template = getWispTemplate()
	local casterParticipant = resolveParticipant(caster)
	if not template or not casterParticipant then
		return { Success = false, FailureReason = "AbilityUnavailable" }
	end

	local target = if isTargetAvailable(preparedTarget, casterParticipant)
		then preparedTarget
		else chooseTarget(casterParticipant)
	if not target then
		return { Success = false, FailureReason = "NoEnemyTarget" }
	end

	local wisp = template:Clone()
	wisp.Name = "ItFollowsWisp"
	wisp.Anchored = true
	wisp.CanCollide = false
	wisp.CanTouch = false
	wisp.CanQuery = false
	wisp:SetAttribute("CasterParticipantId", casterParticipant.Id)
	wisp.Parent = workspace

	local state: WispState = {
		Part = wisp,
		Caster = casterParticipant,
		Target = nil,
		Height = 0,
		MoveAt = 0,
		Connection = nil,
		SoundConnection = nil,
		RevealCleanup = nil,
		Destroyed = false,
	}
	activeWisps[state] = true

	if not setTarget(state, target) then
		cleanupWisp(state)
		return { Success = false, FailureReason = "NoEnemyTarget" }
	end
	state.SoundConnection = playWispSounds(wisp)

	state.Connection = RunService.Heartbeat:Connect(function(deltaTime)
		updateWisp(state, deltaTime)
	end)

	return { Success = true }
end

GAME_STARTED:GetPropertyChangedSignal("Value"):Connect(function()
	if GAME_STARTED.Value then return end
	for state in table.clone(activeWisps) do
		cleanupWisp(state)
	end
end)

return ItFollows
