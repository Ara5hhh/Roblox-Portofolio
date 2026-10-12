local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Hopscotch = {}

local localPlayer = game.Players.LocalPlayer

local DASH_FORCE = 150

local SoundModule = require(ReplicatedStorage.Modules.Shared.SoundModule)
local ControlLock = require(game.StarterPlayer.StarterPlayerScripts.Modules:WaitForChild("ControlLock"))


function Hopscotch.CastAbility()
    if not localPlayer.Character then return end

    local hrp: Part = localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Attachment
    local attachment = hrp:FindFirstChild("RootAttachment") or Instance.new("Attachment", hrp)
    
    local linVel = Instance.new("LinearVelocity")
    linVel.Attachment0 = attachment
    linVel.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
    linVel.MaxForce = math.huge
    linVel.Parent = hrp

    local elapsed = 0
    local DASH_DURATION = 1 -- secunde

    SoundModule.Play("Tempest")

    --disable controls
	local releaseControls = ControlLock.Acquire()

    local dashConn
    dashConn = RunService.RenderStepped:Connect(function(delta)
        elapsed += delta

        local t = math.clamp(elapsed / DASH_DURATION, 0, 1)
        
        -- Quad EasingDirection.In inversat = incepe repede, incetineste
        -- 1 - (1-t)^2 = Quad Out (incepe rapid)
        -- (1-t)^2 = Quad In (incetineste spre final)
        local easedT = (1 - t) * (1 - t) -- Quad In, scade de la 1 la 0

        linVel.VectorVelocity = Vector3.new(0, 0, DASH_FORCE * easedT) -- Z pozitiv = backwards pe attachment

        if t >= 1 then
            dashConn:Disconnect()
            linVel:Destroy()

            --enable controls
            task.delay(3, function()
				releaseControls()
            end)
        end
    end)
end


return Hopscotch
