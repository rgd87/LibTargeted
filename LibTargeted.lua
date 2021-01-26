--[================[
LibTargeted
Author: d87
--]================]


local MAJOR, MINOR = "LibTargeted", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end


lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)

lib.frame = lib.frame or CreateFrame("Frame")

local f = lib.frame
local callbacks = lib.callbacks

local enemies = {} -- [GUID: string] = { targetGUID: string, lastEncountered: time }
local targets = {} -- [targetGUID: string] = { [srcGUID: string] = true }
local activeNameplates = {}
lib.enemies = enemies


local UnitGUID = UnitGUID
local GetTime = GetTime

f:SetScript("OnEvent", function(self, event, ...)
    return self[event](self, event, ...)
end)

-- local refreshCastTable = function(tbl, ...)
--     local numArgs = select("#", ...)
--     for i=1, numArgs do
--         tbl[i] = select(i, ...)
--     end
-- end

-- local IsGroupUnit = function(unit)
--     return UnitExists(unit) and (UnitIsUnit(unit, "player") or UnitPlayerOrPetInParty(unit) or UnitPlayerOrPetInRaid(unit))
-- end


local function FireCallback(event, guid, ...)
    -- TODO: Add unit lookup
    callbacks:Fire(event, guid, ...)
end




local function IncrementTargetCount(guid, mod)
    local targetTable = targets[guid]
    -- print("incrementing")
    if targetTable then
        local count = targetTable[1]
        count = count + 1
        targetTable[1] = count
        FireCallback("TARGETED_COUNT_CHANGED", guid, count)
    else
        targets[guid] = { 1 }
        FireCallback("TARGETED_COUNT_CHANGED", guid, 1)
    end
end

local function DecrementTargetCount(guid, mod)
    local targetTable = targets[guid]
    -- print("decermenting")
    if targetTable then
        local count = targetTable[1]
        count = count - 1
        if count == 0 then
            targets[guid] = nil
        else
            targetTable[1] = count
        end
        FireCallback("TARGETED_COUNT_CHANGED", guid, count)
    end
end

function f:UNIT_TARGET(event, unit)
    -- if not UnitIsFriend("player", srcUnit) then
    -- if string.sub(unit, 1, 9) ~= "nameplate" then return end
    local unitGUID = UnitGUID(unit)
    if not unitGUID then return end

    -- print(event, unit)
    local enemyTable = enemies[unitGUID]
    if enemyTable then
        local oldTargetGUID = enemyTable[1]
        local unitTarget = unit.."target"
        local newTargetGUID = UnitGUID(unitTarget)

        if oldTargetGUID == newTargetGUID then return end

        if oldTargetGUID then
            FireCallback("TARGETED_COUNT_CHANGED", oldTargetGUID)
            -- DecrementTargetCount(oldTargetGUID)
        end

        if newTargetGUID then
            FireCallback("TARGETED_COUNT_CHANGED", newTargetGUID)
            -- IncrementTargetCount(newTargetGUID)
        end

        local now = GetTime()

        enemyTable[1] = newTargetGUID
        enemyTable[2] = now
    -- else
    --     -- this can be a normal unit like target focus arena1-3
    --     self:NAME_PLATE_UNIT_ADDED(event, unit)
    end
end


function f:NAME_PLATE_UNIT_ADDED(event, unit)
    activeNameplates[unit] = true
    -- not letting friendly units in, but mc'd ones should pass
    -- local isAttackable = UnitCanAttack("player", unit)
    -- local isFriendly = UnitReaction(unit, "player") >= 4
    -- if not isAttackable and isFriendly then return end


    local unitGUID = UnitGUID(unit)

    -- print(event, unit)
    if not enemies[unitGUID] then
        local now = GetTime()
        enemies[unitGUID] = { nil, now }
    end

    local enemyTable = enemies[unitGUID]

    local oldTargetGUID = enemyTable[1]

    local unitTarget = unit.."target"
    local newTargetGUID = UnitGUID(unitTarget)

    if newTargetGUID and newTargetGUID ~= oldTargetGUID then
        FireCallback("TARGETED_COUNT_CHANGED", newTargetGUID)
        -- IncrementTargetCount(newTargetGUID)
    end
end

local normalUnits = {
    -- ["target"] = true,
    -- ["focus"] = true,
    ["boss1"] = true,
    ["boss2"] = true,
    ["boss3"] = true,
    ["boss4"] = true,
    ["boss5"] = true,
    ["arena1"] = true,
    ["arena2"] = true,
    ["arena3"] = true,
    ["arena4"] = true,
    ["arena5"] = true,
}

function f:NAME_PLATE_UNIT_REMOVED(event, unit)
    activeNameplates[unit] = nil
    -- for unit in pairs(normalUnits) do
    --     if UnitIsUnit(unit, unit) then
    --         return
    --     end
    -- end

    local unitGUID = UnitGUID(unit)
    local enemy = enemies[unitGUID]
    -- print(event, unit)
    if enemy then
        local targetGUID = enemy[1]
        if targetGUID then
            FireCallback("TARGETED_COUNT_CHANGED", targetGUID)
            -- DecrementTargetCount(targetGUID)
        end
        -- enemies[unitGUID] = nil
    end
end

-- local function PurgeExpired()
--     for i, guid in ipairs(guidsToPurge) do
--         casters[guid] = nil
--     end
--     table.wipe(guidsToPurge)
-- end

function lib:GetUnitTargetedCount(unit)
    local targetGUID = UnitGUID(unit)
    print(unit, targetGUID)
    return self:GetGUIDTargetedCount(targetGUID)
end

function lib:GetGUIDTargetedCount(targetGUID)
    print(targetGUID)
    local count = 0
    for unit in pairs(activeNameplates) do
        local unitTarget = unit
        local guid = UnitGUID(unitTarget)
        local enemyTable = enemies[guid]
        print(unit, guid, enemyTable)
        if enemyTable then
            if enemyTable[1] == targetGUID then
                count = count + 1
            end
        end
    end
    return count
    -- if targetGUID and targets[targetGUID] then
    --     local count = targets[targetGUID][1]
    --     return count
    -- end
    -- return 0
end

function callbacks.OnUsed()
    f:RegisterEvent("UNIT_TARGET")

    f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
end

function callbacks.OnUnused()
    f:UnregisterAllEvents()
end


