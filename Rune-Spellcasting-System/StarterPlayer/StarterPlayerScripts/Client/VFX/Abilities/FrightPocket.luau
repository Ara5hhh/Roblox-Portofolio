local RunService = game:GetService("RunService")
local FrightPocket = {}

local BatPart:Part = script:WaitForChild("BatPart")

local SoundModule = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("SoundModule"))

local localPlayer = game.Players.LocalPlayer
local Types = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("Types"))

local function getCharacter(actor: Types.VFXActor): Model?
	if actor:IsA("Player") then
		return actor.Character
	end
	return actor
end

function FrightPocket.Play(player:Types.VFXActor)
	local character = getCharacter(player)
	if not character then return end

    local head = character:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return end
	
	local bats = BatPart:Clone()
	
	bats.Parent = workspace
	
    bats.CFrame = CFrame.lookAt(head.Position + head.CFrame.LookVector * 5, head.Position )
	
	
	local soundParent = if player ~= localPlayer then bats else nil

	SoundModule.Play("BatsSound", soundParent, 0.2, 1.5)
    
	
    task.wait(2)

    -- Opreste emitter-ul
    local emitter = bats:FindFirstChildWhichIsA("ParticleEmitter")
    if emitter then
        emitter.Enabled = false
	end

    -- Asteapta particulele sa dispara dupa ce emitter-ul e oprit
    task.wait(emitter and emitter.Lifetime.Max or 1)
    bats:Destroy()
	
end

return FrightPocket
