local SeeNearbyRunes = {}

local highlightTemplate = Instance.new("Highlight")
highlightTemplate.Name = "SeeNearbyRunesHighlight"
highlightTemplate.FillTransparency = 1
highlightTemplate.OutlineTransparency = 0

local Runes = require(game.ReplicatedStorage.Modules.Data:WaitForChild("Runes"))

local RunService = game:GetService("RunService")

local ABILITY_TIME = 20

function SeeNearbyRunes.CastAbility(runes:{Model})
    local activeHighlights:{Highlight} = {}

    for _, rune in pairs(runes) do
        if rune then
            local highlight = highlightTemplate:Clone()
            highlight.Parent = rune
            highlight.Adornee = rune

            --find color
            local runeTypeName = rune:GetAttribute("Type")
                if runeTypeName then highlight.OutlineColor = Runes.GetRuneData(runeTypeName).color end
            
            table.insert(activeHighlights, highlight)
        end
    end

    task.delay(ABILITY_TIME, function()
        local transparency = 0

        local fadeOutConn
        fadeOutConn = RunService.Heartbeat:Connect(function(deltaTime)
            for _, highlight in pairs(activeHighlights) do
                highlight.OutlineTransparency = transparency
            end

            transparency += deltaTime/2
            if transparency >= 1 then
                for _, highlight in pairs(activeHighlights) do
                    highlight:Destroy()
                end
                fadeOutConn:Disconnect()
            end
        end)
    end)
end

return SeeNearbyRunes
