local TellBells = {}

local RunService = game:GetService("RunService")
local Types = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("Types"))

-- Looped "fae chime" sound, kept in the SFX folder (same place SoundModule reads from).
local chimeTemplate:Sound = script:WaitForChild("TellBellsChime")
chimeTemplate.Looped = true

local DURATION = 20      -- seconds the chime sticks to the victim
local MOVE_THRESHOLD = 2 -- horizontal studs/sec that counts as "moving"

-- one chime per victim at a time, on this client
local active: { [Types.VFXActor]: boolean } = {}

local function getCharacter(actor: Types.VFXActor): Model?
    if actor:IsA("Player") then
        return actor.Character
    end
    return actor
end

-- Runs on EVERY client. Sticks a looped, positional chime to the victim that rings only while
-- they move, for DURATION seconds, so anyone nearby can hear where they are.
function TellBells.Play(player: Types.VFXActor)
    if active[player] then return end

    if not chimeTemplate then
        warn("[TellBells] no 'TellBellsChime' sound in the SFX folder")
        return
    end

    local character = getCharacter(player)
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    active[player] = true

    -- parenting the sound to the HRP makes it positional — heard by all clients by distance
    local chime = chimeTemplate:Clone()
    chime.Looped = true
    chime.Parent = hrp
    chime:Play()

    local startClock = os.clock()
    local wasMoving = true --matches the initial :Play(); the first Heartbeat corrects it

    local conn
    conn = RunService.Heartbeat:Connect(function()
        --end after the duration, or if the character is gone (died / left)
        if os.clock() - startClock >= DURATION or not hrp.Parent or not character.Parent then
            conn:Disconnect()
            chime:Destroy()
            active[player] = nil
            return
        end

        --ring only while moving (horizontal speed); a still victim is silent
        local vel = hrp.AssemblyLinearVelocity
        local moving = Vector3.new(vel.X, 0, vel.Z).Magnitude > MOVE_THRESHOLD
        if moving ~= wasMoving then
            wasMoving = moving
            if moving then
                chime:Resume()
            else
                chime:Pause()
            end
        end
    end)
end

return TellBells
