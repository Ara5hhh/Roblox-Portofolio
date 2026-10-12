local Runes = {}

local player = game.Players.LocalPlayer

local SoundModule = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("SoundModule"))
local PopUpModule = require(game.StarterPlayer.StarterPlayerScripts.Modules:WaitForChild("PopUpModule"))

local Types = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("Types"))

local BridgeNet = require(game.ReplicatedStorage.Modules.Library:WaitForChild("BridgeNet2"))
local ItemBridge = BridgeNet.ClientBridge("Item")

local SameSideBinder = require(game.ReplicatedStorage.Modules.Library:WaitForChild("SameSideBinder"))
local RuneBind = SameSideBinder.CreateBind("RuneHUD")


function Runes.Added(rune:Model)

    local prox = rune:FindFirstChildWhichIsA("ProximityPrompt", true)

    if not prox then return end

    -- debounce: the handler yields (invoke + replication wait), during which the
    -- prompt could fire again. Block re-entry so we don't stack duplicate invokes.
    local picking = false

    prox.Triggered:Connect(function()
        if picking then return end
        picking = true

        -- read BEFORE the invoke: the count the player has prior to this pickup,
        -- already replicated from previous pickups (the server increments it during the invoke)
        local priorRuneCount = player:GetAttribute("RuneCount") or 0

        local eventParams:Types.ItemEventData = {
            ItemModel = rune,
            Action = "PickUp"
        }

        --server returns: true = success, a string = failed + popup message, nil = silent fail
        local result = ItemBridge:InvokeServerAsync(eventParams)
        if result ~= true then
			picking = false --invalid/failed pickup: allow a later retry
			if type(result) == "string" then PopUpModule.Warn(result, false, 3) end
            return
        end

        -- success: the server reparented the rune model into a Tool. Derive it from
        -- rune.Parent, waiting for replication if it hasn't arrived yet.
        local RuneTool = rune.Parent
        if not (RuneTool and RuneTool:IsA("Tool")) then
            rune.AncestryChanged:Wait()
            RuneTool = rune.Parent
        end

        if RuneTool and RuneTool:IsA("Tool") then
            RuneBind:Fire({RuneTool})
            SoundModule.Play("RunePickUp" .. priorRuneCount+1)
        end
        -- on success the rune is consumed (prompt destroyed); leave picking latched
    end)

end

return Runes
