local GloomShroud = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SoundModule = require(ReplicatedStorage.Modules.Shared.SoundModule)

local darknessAtmosphereTemplate:Atmosphere = script:WaitForChild("Darkness")

local function fadeAtmosphere(atmosphere:Atmosphere ,enabled:boolean)
    local multiplier = if enabled then 1 else -1
    local target = if enabled then 1 else 0

    local fadeConn
    fadeConn = RunService.Heartbeat:Connect(function(delta)

        if enabled then
            if atmosphere.Density >= target then
                fadeConn:Disconnect()
                return
            end
        else
            if atmosphere.Density <= target then
                fadeConn:Disconnect()
                return
            end
        end
        
        atmosphere.Density += delta * multiplier

    end)
end

function GloomShroud.Play()
    
    local atmos = darknessAtmosphereTemplate:Clone()
    atmos.Density = 0

    atmos.Parent = game.Lighting

    SoundModule.Play("GloomShroud")

    fadeAtmosphere(atmos, true)

    task.delay(20, function()
        fadeAtmosphere(atmos, false)
        task.wait(2)
        atmos:Destroy()
    end)
end

return GloomShroud
