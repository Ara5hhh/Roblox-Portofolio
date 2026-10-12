local Abilities = {}

local Types = require(game.ReplicatedStorage.Modules.Shared:WaitForChild("Types"))

local BridgeNet = require(game.ReplicatedStorage.Modules.Library:WaitForChild("BridgeNet2"))
local AbilityBridge = BridgeNet.ClientBridge("Ability")

local AbilitiesModules = {}
for _, module:ModuleScript in pairs(script:GetChildren()) do
    AbilitiesModules[module.Name] = require(module)
end

function Abilities.Init()
    AbilityBridge:Connect(function(args:Types.AbilityData)
        if AbilitiesModules[args.AbilityName] then
            AbilitiesModules[args.AbilityName].CastAbility(args.AbilityData)
        end
    end)
end

return Abilities