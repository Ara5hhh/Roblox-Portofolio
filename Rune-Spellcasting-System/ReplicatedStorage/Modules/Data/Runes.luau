local Runes = {}

type Rune = {
    color:Color3,
    imageId:string
}

local RuneData:{Rune} = {
    ["BERKANA"] = {
        color = Color3.fromHex("#ff0059"),
        imageId ="rbxassetid://108701315372504"
    },
    ["JERA"] = {
        color = Color3.fromHex("#ff8c00"),
        imageId = "rbxassetid://89198539375502"
    },
    ["DAGAZ"] = {
        color = Color3.fromHex("#0073ff"),
        imageId = "rbxassetid://128065919239980"
    },
    ["ALGIZ"] = {
        color = Color3.fromHex("#ff0000"),
        imageId = "rbxassetid://91167911844614"
    },
    
    ["OTHALA"] = {
        --pure green: toEmissive(x80) amplifies any red channel past 1, and #11ff00's small
        --red (0x11) would clamp the rune to yellow — identical to JERA. Keep red at 0.
        color = Color3.fromHex("#00ff00"),
        imageId = "rbxassetid://131776434284349"
    },
    --["PERTHRO"] = {
    --    color = Color3.fromHex("#ffffff"),
    --    imageId = "rbxassetid://70597510736004"
    --}
}

local RuneChances = {
    ["BERKANA"] = 0.2,
    ["JERA"] = 0.2,
    ["DAGAZ"] = 0.2,
    ["ALGIZ"] = 0.2,
    ["OTHALA"] = 0.2,
    --["PERTHRO"] = 0.1
}

function Runes.GetRandomRune():(string, Rune)
    local rand = math.random()
    local cumulative = 0

    for runeName, chance in pairs(RuneChances) do
        cumulative = cumulative + chance
        if rand <= cumulative then
            return runeName, RuneData[runeName]
        end
    end

    -- Fallback in case of rounding issues
    return "JERA", RuneData["JERA"]
end

function Runes.GetRuneData(runeName:string):Rune?
    return RuneData[runeName]
end

-----------------
----ABILITIES----
-----------------

type Ability = {
    NeededRunes:{string},
    Description:string,
	AbilityType:("Interactables" | "Cursor" | "Curse")?,
	SPprice:number?,
	DevProdID:number?
}


local AbilitiesByRunes:{[string]:Ability} = {
    --Level 1 abilities
	["PerilSight"] = {NeededRunes = {"BERKANA"}, Description = "Reveal all nearby traps for a while.", SPprice = 10, DevProdID = nil},
	["RunicSight"] = {NeededRunes = {"DAGAZ"}, Description = "Reveal all nearby runes for a while.", SPprice = 10, DevProdID = nil},
    ["Hopscotch"] = {NeededRunes = {"OTHALA"}, Description = "Dash forward through any obstacles.", SPprice = 10, DevProdID = nil},
	["FrightPocket"] = {NeededRunes = {"ALGIZ"}, Description = "Place a Jumpscare on a interactable object.", AbilityType = "Interactables", SPprice = 10, DevProdID = nil},
	["FrightTrap"] = {NeededRunes = {"JERA"}, Description = "Conjure a hidden surprise on the floor.", AbilityType = "Cursor", SPprice = 10, DevProdID = nil},

    --Level 2 abilities
	["Flashbang"] = {NeededRunes = {"BERKANA", "ALGIZ"}, Description = "Place a flashbang trap on a interactable object.", AbilityType = "Interactables", SPprice = 25, DevProdID = 3609181161},
	["Tempest"] = {NeededRunes = {"BERKANA", "JERA"}, Description = "Place a trap on a interactable object that knocks back enemies.", AbilityType = "Interactables", SPprice = 25, DevProdID = 3609181446},
	["Doppelganger"] = {NeededRunes = {"ALGIZ", "DAGAZ"}, Description = "Create an explosive magical clone that looks like a player carrying an orb.", SPprice = 35, DevProdID = 3609181508},
	["GloomShroud"] = {NeededRunes = {"JERA", "DAGAZ"}, Description = "Shroud an enemy in blinding darkness.", SPprice = 30, DevProdID = 3609181589},
	["HauntingDecoy"] = {NeededRunes = {"BERKANA", "DAGAZ"}, Description = "Places a haunting decoy onto an interactable object which opens it when approaching.", AbilityType = "Interactables", SPprice = 25, DevProdID = 3609181672},
	["StaticCharge"] = {NeededRunes = {"JERA", "ALGIZ"}, Description = "Place a static charge on a interactable object.", AbilityType = "Interactables", SPprice = 25, DevProdID = 3609181749},
	["BlackHole"] = {NeededRunes = {"BERKANA", "OTHALA"}, Description = "Places a wormhole on the floor that exiles anyone into the maze.", AbilityType = "Cursor", SPprice = 35, DevProdID = 3609181794},
	["TellBells"] = {NeededRunes = {"OTHALA", "DAGAZ"}, Description = "Places a sticky Fae chime onto an interactable object which makes sounds when you move.", AbilityType = "Interactables", SPprice = 30, DevProdID = 3609181849},
	["CalamityWard"] = {NeededRunes = {"OTHALA", "ALGIZ"}, Description = "Receive Immunity from the next spell.", SPprice = 25, DevProdID = 3609181904},
	["ItFollows"] = {NeededRunes = {"JERA", "OTHALA"}, Description = "Summon a stalking wisp to harm your foe.", AbilityType = "Curse", SPprice = 40, DevProdID = 3610002892},

	--Level 3 abilites

}

function Runes.GetAbilityFromRunes(runes: {string})
    if #runes == 0 then return nil end

    for abilityName, abilityData: Ability in pairs(AbilitiesByRunes) do
        if #runes ~= #abilityData.NeededRunes then continue end

        local matched = true
        for _, neededRune in ipairs(abilityData.NeededRunes) do
            if not table.find(runes, neededRune) then
                matched = false
                break
            end
        end

        if matched then
            return abilityName
        end
    end

    return nil
end


function Runes.GetAbilityDescription(abilityName:string)
    if AbilitiesByRunes[abilityName] then
        return AbilitiesByRunes[abilityName].Description
    end

    return nil
end

function Runes.GetAbilityType(abilityName:string)
    if AbilitiesByRunes[abilityName] then
        return AbilitiesByRunes[abilityName].AbilityType
    end

    return nil
end

-- Runes that make up an ability (used to grant a player their StarterSpell's runes).
function Runes.GetNeededRunes(abilityName:string): {string}?
    local ability = AbilitiesByRunes[abilityName]
    return ability and ability.NeededRunes
end

-- Every ability keyed by name (used by the shop's StarterSpells category to build
-- a preview per spell).
function Runes.GetAllAbilities(): {[string]:Ability}
    return AbilitiesByRunes
end

function Runes.GetAbility(abilityName:string): Ability?
    return AbilitiesByRunes[abilityName]
end

return Runes


--[[
    RUNES DESCRIPTION

    BERKANA represents a Birch Tree. It symbolizes Femininity, Fertility, Healing, Regeneration, Birth.

    JERA represents the Year. It symbolizes Cycles, Completion, Changes, Harvest, Reaping Rewards.

    DAGAZ represents Dawn. It symbolizes Awakening, Certainty, Illumination, Completion, Hope.

    ALGIZ represents an Elk. It symbolizes Protection, Defense, Instinct, Group Effort, Guardianship.

    OTHALA represents Inheritance. It symbolizes Ancestry, Possessions, Heritage, Experience, Value.

    PERTHRO represents a Dice Cup. It symbolizes Fate, Chance, Mystery, Destiny, Secrets. 

    ]]
