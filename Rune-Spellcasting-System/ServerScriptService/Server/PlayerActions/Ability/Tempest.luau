local Tempest = {}

local Traps = require(game.ServerScriptService.Server.Traps)
local ParticipantService = require(game.ServerScriptService.Server.ParticipantService)

local Types = require(game.ReplicatedStorage.Modules.Shared.Types)

local BridgeNet = require(game.ReplicatedStorage.Modules.Library.BridgeNet2)
local AbilityBridge = BridgeNet.ServerBridge("Ability")

local DASH_FORCE = 150
local DASH_DURATION = 1

local function Knockback(target)
    if typeof(target) == "Instance" and target:IsA("Player") then
        local abilityArgs:Types.AbilityData = {
            AbilityName = "Tempest",
            AbilityData = nil
        }
        AbilityBridge:Fire(target, abilityArgs)
        return
    end

    if not ParticipantService.IsParticipant(target) or target.Kind ~= "Bot" then return end
    local character = ParticipantService.GetCharacter(target)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return end

    ParticipantService.SetAttribute(target, "BotStunnedUntil", os.clock() + DASH_DURATION + 3)

    local attachment = root:FindFirstChild("RootAttachment")
    if not attachment or not attachment:IsA("Attachment") then
        attachment = Instance.new("Attachment")
        attachment.Name = "RootAttachment"
        attachment.Parent = root
    end

    local velocity = Instance.new("LinearVelocity")
    velocity.Attachment0 = attachment
    velocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
    velocity.MaxForce = math.huge
    velocity.Parent = root

    task.spawn(function()
        local startedAt = os.clock()
        while velocity.Parent and root.Parent do
            local alpha = math.clamp((os.clock() - startedAt) / DASH_DURATION, 0, 1)
            velocity.VectorVelocity = Vector3.new(0, 0, DASH_FORCE * (1 - alpha) ^ 2)
            if alpha >= 1 then break end
            task.wait()
        end
        velocity:Destroy()
    end)
end

function Tempest.CastAbility(player, model:Model)
    if model then
		Traps.AddTrap(model, Knockback, "Tempest", player, "Tempest")
	end
	
	local returnParams:Types.PlayerActionData = {
		Success = true
	}

	return returnParams
end

return Tempest
