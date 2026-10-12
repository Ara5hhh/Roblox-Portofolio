local RevealTraps = {}

local RedAuraTemplate:Attachment = script:WaitForChild("RedAura")

function RevealTraps.CastAbility(trapPositions:{Vector3})
	
	local activeAuras:{Attachment} = {}

    for _, position in ipairs(trapPositions) do
        local redAura = RedAuraTemplate:Clone()
        redAura.Position = position
        redAura.Parent = workspace

        table.insert(activeAuras, redAura)
    end

    task.delay(10, function()
        for _, aura in pairs(activeAuras) do
            aura:Destroy()
        end
    end)
	
end

return RevealTraps
