local CalamityWard = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundModule = require(ReplicatedStorage.Modules.Shared.SoundModule)

-- Aura particle emitter designed in Studio as a child of this ModuleScript.
local wardTemplate: ParticleEmitter = script:WaitForChild("Ward")

-- one aura per warded player, on this client
local active: { [Player]: ParticleEmitter } = {}

-- Runs on every client: a persistent aura on the warded player until the ward is consumed.
function CalamityWard.Play(player: Player)
    if active[player] then return end
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local ward = wardTemplate:Clone()
    ward.Parent = hrp
    active[player] = ward

    SoundModule.Play("CalamityWardCast", hrp)
end

-- Ward consumed by a spell: emit a shatter burst, then remove the aura.
function CalamityWard.Stop(player: Player)
    local ward = active[player]
    if not ward then return end
    active[player] = nil

    ward.Enabled = false
    ward:Emit(20) --shatter burst

    SoundModule.Play("CalamityWardBreak", ward.Parent)

    task.delay(1, function()
        ward:Destroy()
    end)
end

return CalamityWard
