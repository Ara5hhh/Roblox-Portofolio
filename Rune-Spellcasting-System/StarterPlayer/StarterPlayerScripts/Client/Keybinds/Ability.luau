local Ability = {}

local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function updateRaycastFilter()
    raycastParams.FilterDescendantsInstances = { player.Character or {} }
end
updateRaycastFilter()
player.CharacterAdded:Connect(updateRaycastFilter)

local function getRaycastFromCursor()
    local viewportSize = camera.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local unitRay = camera:ScreenPointToRay(screenCenter.X, screenCenter.Y)
    local raycastResult = workspace:Raycast(
        unitRay.Origin,
        unitRay.Direction * 15,
        raycastParams
    )

    return raycastResult
end

local function getPosFromCursor()
    local raycastResult = getRaycastFromCursor()
    -- Cursor traps are floor traps. Reject empty space, walls, and steep faces so
    -- the server can return a useful placement warning without consuming runes.
    if not raycastResult or raycastResult.Normal.Y < 0.65 then return end
    return raycastResult.Position
end

local function getOpenableFromCursor()
    local raycastResult = getRaycastFromCursor()

    if not (raycastResult and raycastResult.Instance) then return end

    local model = raycastResult.Instance:FindFirstAncestorWhichIsA("Model")
    if not model then return end

    if not CS:HasTag(model, "Openable") then
        model = model:FindFirstAncestorWhichIsA("Model")
        if not model then return end
        if not CS:HasTag(model, "Openable") then return end
    end

    return model
end

local functionsByAbilityType = {
    ["Interactables"] = getOpenableFromCursor,
    ["Cursor"] = getPosFromCursor
}

local CURRENT_TYPE:string = nil

local Runes = require(game.ReplicatedStorage.Modules.Data:WaitForChild("Runes"))

local currentRunes:{string} = {}
local resetRunesConn:RBXScriptConnection = nil

local function onRuneToolAdded(tool: Tool)
    local runeModel = tool:FindFirstChildWhichIsA("Model")
    if not runeModel then return end

    local runeType = runeModel:GetAttribute("Type")
    if not runeType then return end -- not a rune tool

    if resetRunesConn and resetRunesConn.Connected then resetRunesConn:Disconnect() end
    resetRunesConn = tool.Destroying:Once(function()
        currentRunes = {}
        CURRENT_TYPE = nil
    end)

    table.insert(currentRunes, runeType)

    local currentAbility = Runes.GetAbilityFromRunes(currentRunes)
    if currentAbility then
        CURRENT_TYPE = Runes.GetAbilityType(currentAbility)
    end
end

local SameSideBinder = require(game.ReplicatedStorage.Modules.Library:WaitForChild("SameSideBinder"))
local RuneBind = SameSideBinder.CreateBind("RuneHUD")
RuneBind:Connect(onRuneToolAdded)

local ACTION_DATA:(Vector3 | Model) = nil

local highlight = Instance.new("Highlight")
highlight.FillTransparency = 0.5
highlight.OutlineTransparency = 0
highlight.FillColor = Color3.fromRGB(255, 0, 0)
highlight.OutlineColor = Color3.fromRGB(255, 255, 255)

RunService.Heartbeat:Connect(function()
    if CURRENT_TYPE and functionsByAbilityType[CURRENT_TYPE] then
        ACTION_DATA = functionsByAbilityType[CURRENT_TYPE]()
    else
        ACTION_DATA = nil
    end

    if ACTION_DATA then
        if typeof(ACTION_DATA) == "Instance" and ACTION_DATA:IsA("Model") then
            highlight.Parent = ACTION_DATA
        end
    else
        highlight.Parent = nil
    end
end)

function Ability.GetActionDataOnPress()
    return ACTION_DATA
end

return Ability
