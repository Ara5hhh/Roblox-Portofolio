local ItemClass = require(game.ServerScriptService.Modules.Classes.ItemClass)
local RunesData = require(game.ReplicatedStorage.Modules.Data.Runes)

local Rune = setmetatable({}, {__index = ItemClass})
Rune.__index = Rune

local CS = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Runes = require(ReplicatedStorage.Modules.Data.Runes)

local RuneTemplate:Model = script.Rune

local function toEmissive(color: Color3, intensity: number): Color3
    return Color3.new(
        color.R * intensity,
        color.G * intensity,
        color.B * intensity
    )
end

function Rune.New()

    local self = ItemClass.New()
    setmetatable(self, Rune)

    self.Model = RuneTemplate:Clone()

    local runeTypeName, runeData = RunesData.GetRandomRune()
    self.Model:SetAttribute("Type", runeTypeName)

    local runeSymbol:Decal = self.Model.DecalPart:FindFirstChildWhichIsA("Decal")
    runeSymbol.ColorMapContent = Content.fromUri(runeData.imageId)
    runeSymbol.Color3 = toEmissive(runeData.color, 80)

    self:IndexByModel("Rune")

    self.Prox = Instance.new("ProximityPrompt")
    self.Prox.Parent = self.Model.PrimaryPart

    self.Prox.ActionText = "Pick Up"
    self.Prox.ObjectText = runeTypeName

    --Janitor

    self.Janitor:Add(self.Model)

    return self
end


function Rune.Spawn(spawnPos:Vector3)
    local self = Rune.New()

    CS:AddTag(self.Model, "Rune")

    self.Model.Parent = workspace.Items

    self.Model:PivotTo(CFrame.new(spawnPos))

    return self
end


-- Creates a rune of a specific type straight into a player's backpack (starter spell runes).
-- Produces a Tool identical to a normally picked-up rune (same GiveToPlayer path).
function Rune.Grant(player:Player, runeType:string)
    local runeData = Runes.GetRuneData(runeType)
    if not runeData then
        warn("[Rune] Grant: unknown rune type '" .. tostring(runeType) .. "'")
        return
    end

    local self = Rune.New()

    --force the requested type + matching visuals (Rune.New picked a random one)
    self.Model:SetAttribute("Type", runeType)
    local runeSymbol:Decal = self.Model.DecalPart:FindFirstChildWhichIsA("Decal")
    if runeSymbol then
        runeSymbol.ColorMapContent = Content.fromUri(runeData.imageId)
        runeSymbol.Color3 = toEmissive(runeData.color, 80)
    end

    CS:AddTag(self.Model, "Rune") --Ability.PerformAction filters backpack runes by this tag
    --marker for the client HUD hook: a starter rune has no world prompt, so the normal
    --pickup flow never fires RuneHUD for it
    self.Model:SetAttribute("IsStarterRune", true)

    self:GiveToPlayer(player) --converts the model into a Tool in the backpack

    return self
end


--local runes = {"BERKANA", "JERA", "DAGAZ", "ALGIZ", "OTHALA"}

--for i, runeName in ipairs(runes) do
--    local spawnPos = Vector3.new((i - 1) * 4, 3, 0) -- 4 studs intre fiecare runa
    
--    local function spawnRune()
--        local rune = Rune.Spawn(spawnPos)
--        rune.Model:SetAttribute("Type", runeName) -- forteaza tipul specific

--        local runeData = Runes.GetRuneData(runeName)

--        local runeSymbol:Decal = rune.Model.DecalPart:FindFirstChildWhichIsA("Decal")
--        runeSymbol.ColorMapContent = Content.fromUri(runeData.imageId)
--        runeSymbol.Color3 = toEmissive(runeData.color, 80)
        
--        rune.Model.Destroying:Once(function()
--            if not rune.Model.Parent then
--                task.wait(1) -- mic delay inainte de respawn
--                spawnRune()
--            end
--        end)
--    end
    
--    spawnRune()
--end


return Rune
