--[[
    WardService — CalamityWard's "immunity from the next spell". A warded player carries a
    charge (the `Warded` attribute) that the first incoming rune spell consumes instead of
    landing. Call TryConsume(target) at each point a spell applies its effect to a player;
    if it returns true the spell was warded off and should do nothing to them.

    Also drives the ward aura VFX (Play on grant, Stop/shatter on consume) — shown ONLY to the
    warded player themselves, so opponents can't tell someone is holding immunity.
]]

local WardService = {}

local BridgeNet = require(game.ReplicatedStorage.Modules.Library.BridgeNet2)
local VFXBridge = BridgeNet.ServerBridge("VFX")
local ParticipantService = require(game.ServerScriptService.Server.ParticipantService)

local WARD_ATTRIBUTE = "Warded"

local function resolveTarget(target)
    if ParticipantService.IsParticipant(target) then
        return target
    end
    if typeof(target) == "Instance" then
        if target:IsA("Player") then
            return ParticipantService.FromPlayer(target)
        elseif target:IsA("Model") then
            return ParticipantService.FromCharacter(target)
        end
    end
    return nil
end

local function setWarded(target, value: boolean)
    local participant = resolveTarget(target)
    if participant then
        ParticipantService.SetAttribute(participant, WARD_ATTRIBUTE, value)
    elseif typeof(target) == "Instance" then
        target:SetAttribute(WARD_ATTRIBUTE, value)
    end
    return participant
end

local function getWarded(target): boolean
    local participant = resolveTarget(target)
    if participant then
        return ParticipantService.GetAttribute(participant, WARD_ATTRIBUTE) == true
    end
    return typeof(target) == "Instance" and target:GetAttribute(WARD_ATTRIBUTE) == true
end

-- Grant the ward: it sits on the player (aura shown) until a spell consumes it.
function WardService.SetWard(target)
    local participant = setWarded(target, true)
    --only the warded player sees their own aura (immunity is meant to be hidden from opponents)
    local player = participant and participant.Player or (typeof(target) == "Instance" and target:IsA("Player") and target)
    if player then
        VFXBridge:Fire(player, {
            player = player,
            vfxName = "CalamityWard",
            Status = "Play",
        })
    end
end

function WardService.IsWarded(target): boolean
    return getWarded(target)
end

-- If the player is warded, consume the charge (break the aura) and return true so the caller
-- knows to skip the spell's effect. Returns false if they weren't warded.
function WardService.TryConsume(target): boolean
    if not getWarded(target) then
        return false
    end

    local participant = setWarded(target, false)
    --match the Play above: only the warded player sees the aura shatter
    local player = participant and participant.Player or (typeof(target) == "Instance" and target:IsA("Player") and target)
    if player then
        VFXBridge:Fire(player, {
            player = player,
            vfxName = "CalamityWard",
            Status = "Stop",
        })
    end
    return true
end

return WardService
