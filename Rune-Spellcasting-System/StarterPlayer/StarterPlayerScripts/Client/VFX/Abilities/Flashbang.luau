local Flashbang = {}

local RunService = game:GetService("RunService")

local localPlayer = game.Players.LocalPlayer
local Types = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("Types"))

local FlashbangGuiTemplate:ScreenGui = script:WaitForChild("FlashbangGui")
local FlashbangPartTempalte:Part = script:WaitForChild("FlashbangPart")

local SoundModule = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("SoundModule"))

local POINT_LIGHT_BRIGHTNESS = 10

local function FlashbangClientAsync(instance: Frame | PointLight, enabled: boolean)
    local multiplier = if enabled then 1 else -1

    local transpConn
	transpConn = RunService.Heartbeat:Connect(function(delta)
		delta *= 2
		
        if instance:IsA("Frame") then
            if enabled and instance.BackgroundTransparency <= 0 then
                transpConn:Disconnect()
                return
            elseif not enabled and instance.BackgroundTransparency >= 1 then
                transpConn:Disconnect()
                return
            end
            instance.BackgroundTransparency -= delta * multiplier

        elseif instance:IsA("PointLight") then
            if enabled and instance.Brightness >= POINT_LIGHT_BRIGHTNESS then
                transpConn:Disconnect()
                return
            elseif not enabled and instance.Brightness <= 0 then
                transpConn:Disconnect()
                return
            end
            instance.Brightness += delta * multiplier * POINT_LIGHT_BRIGHTNESS
        end
    end)

    while transpConn.Connected do
        task.wait(0.1)
    end
end

local function getCharacter(actor: Types.VFXActor): Model?
    if actor:IsA("Player") then
        return actor.Character
    end
    return actor
end

function Flashbang.Play(player:Types.VFXActor)
    if player == localPlayer then
        task.spawn(function()
            local flashbangGui = FlashbangGuiTemplate:Clone()
            local whiteFrame:Frame = flashbangGui:WaitForChild("WhiteFrame")

            whiteFrame.Transparency = 1

            flashbangGui.Parent = player.PlayerGui

            FlashbangClientAsync(whiteFrame, true)

            task.wait(2)

            FlashbangClientAsync(whiteFrame, false)

            flashbangGui:Destroy()
        end)
    end

    --for all players
    local character = getCharacter(player)
    if not character then return end
    local head = character:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return end

    local flashPart = FlashbangPartTempalte:Clone()
    flashPart.Anchored = true
    local flashLight = flashPart:FindFirstChildWhichIsA("PointLight")
    flashLight.Brightness = 0

    flashPart.CFrame = head.CFrame
	flashPart.Parent = workspace
	
	local soundParent = if player ~= localPlayer then flashPart else nil
	
	SoundModule.Play("Flashbang", soundParent, 0.2, 2)

    FlashbangClientAsync(flashLight, true)

    task.wait(2)

    FlashbangClientAsync(flashLight, false)

    flashPart:Destroy()
end

return Flashbang
