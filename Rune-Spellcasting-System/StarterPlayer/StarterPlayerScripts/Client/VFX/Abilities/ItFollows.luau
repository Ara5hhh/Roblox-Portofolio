local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ItFollows = {}

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local SAFETY_TIMEOUT = 3
local REVEAL_DURATION = 2
local ZOOM_FOV_DELTA = 25
local MIN_ZOOM_FOV = 35

type RevealState = {
	RevealId: number,
	Wisp: BasePart,
	Head: BasePart,
	PreviousCameraType: Enum.CameraType,
	PreviousCameraSubject: Instance?,
	PreviousCameraCFrame: CFrame,
	PreviousFieldOfView: number,
	CameraConnection: RBXScriptConnection?,
	ZoomConnection: RBXScriptConnection?,
	ZoomInTween: Tween?,
	ZoomOutTween: Tween?,
	SafetyThread: thread?,
}

local active: RevealState? = nil

local function teardown(expectedRevealId: number?)
	local state = active
	if not state or (expectedRevealId ~= nil and state.RevealId ~= expectedRevealId) then return end
	active = nil

	if state.CameraConnection then
		state.CameraConnection:Disconnect()
	end
	if state.ZoomConnection then
		state.ZoomConnection:Disconnect()
	end
	if state.ZoomInTween then
		state.ZoomInTween:Cancel()
	end
	if state.ZoomOutTween then
		state.ZoomOutTween:Cancel()
	end
	if state.SafetyThread and state.SafetyThread ~= coroutine.running() then
		task.cancel(state.SafetyThread)
	end

	camera.FieldOfView = state.PreviousFieldOfView
	camera.CameraType = state.PreviousCameraType
	if state.PreviousCameraSubject and state.PreviousCameraSubject.Parent then
		camera.CameraSubject = state.PreviousCameraSubject
	else
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		if humanoid then camera.CameraSubject = humanoid end
	end
	if state.PreviousCameraType == Enum.CameraType.Scriptable then
		camera.CFrame = state.PreviousCameraCFrame
	end
end

function ItFollows.Play(player, _variant, _secondPlayer, additionalData)
	if player ~= localPlayer or typeof(additionalData) ~= "table" then return end

	local revealId = additionalData.RevealId
	local wisp = additionalData.Wisp
	if type(revealId) ~= "number" or typeof(wisp) ~= "Instance" or not wisp:IsA("BasePart") then
		return
	end

	local character = localPlayer.Character
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if not head or not head:IsA("BasePart") then return end

	-- A newer curse reveal supersedes the camera from an older one. Reveal ids make the older
	-- server Stop harmless instead of letting it terminate the newer camera shot.
	teardown()

	local state: RevealState = {
		RevealId = revealId,
		Wisp = wisp,
		Head = head,
		PreviousCameraType = camera.CameraType,
		PreviousCameraSubject = camera.CameraSubject,
		PreviousCameraCFrame = camera.CFrame,
		PreviousFieldOfView = camera.FieldOfView,
		CameraConnection = nil,
		ZoomConnection = nil,
		ZoomInTween = nil,
		ZoomOutTween = nil,
		SafetyThread = nil,
	}
	active = state

	camera.CameraType = Enum.CameraType.Scriptable
	state.CameraConnection = RunService.RenderStepped:Connect(function()
		if active ~= state or not state.Wisp.Parent or not state.Head.Parent then
			teardown(revealId)
			return
		end
		camera.CFrame = CFrame.lookAt(state.Head.Position, state.Wisp.Position)
	end)

	-- Pull the target's focus into the wisp for the first half of the reveal, then settle
	-- precisely back to whatever FOV they had before the curse during the second half.
	local halfDuration = REVEAL_DURATION / 2
	local zoomedFOV = math.max(MIN_ZOOM_FOV, state.PreviousFieldOfView - ZOOM_FOV_DELTA)
	state.ZoomInTween = TweenService:Create(
		camera,
		TweenInfo.new(halfDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ FieldOfView = zoomedFOV }
	)
	state.ZoomOutTween = TweenService:Create(
		camera,
		TweenInfo.new(halfDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ FieldOfView = state.PreviousFieldOfView }
	)
	state.ZoomConnection = state.ZoomInTween.Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed and active == state and state.ZoomOutTween then
			state.ZoomOutTween:Play()
		end
	end)
	state.ZoomInTween:Play()

	state.SafetyThread = task.delay(SAFETY_TIMEOUT, function()
		teardown(revealId)
	end)
end

function ItFollows.Stop(player, _variant, _secondPlayer, additionalData)
	if player ~= localPlayer then return end
	local revealId = typeof(additionalData) == "table" and additionalData.RevealId or nil
	if type(revealId) == "number" then
		teardown(revealId)
	end
end

return ItFollows
