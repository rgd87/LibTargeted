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

local wipe = table.wipe

local scanUnits = {
    ["target"] = true,
    ["focus"] = true,
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

local UnitGUID = UnitGUID
local GetTime = GetTime

f:SetScript("OnEvent", function(self, event, ...)
    return self[event](self, event, ...)
end)

local IsGroupUnit = function(unit)
    return UnitExists(unit) and (UnitIsUnit(unit, "player") or UnitPlayerOrPetInParty(unit) or UnitPlayerOrPetInRaid(unit))
end


local function FireCallback(event, guid, ...)
    -- TODO: Add unit lookup
    callbacks:Fire(event, guid, ...)
end

-- UNIT_TARGET is not being generated for all nameplates.
-- For example If you pull a pack it only fires for 1 nameplate unit

local encountered = {}
local function ScanUnitsIntoTable(tbl)
    wipe(encountered)
    for unit in pairs(scanUnits) do
        local unitGUID = UnitGUID(unit)
        -- avoiding duplicate units
        if unitGUID and not encountered[unitGUID] then
            encountered[unitGUID] = true

            local targetUnit = unit.."target"
            local targetGUID = UnitGUID(targetUnit)
            if targetGUID then
                local cur = tbl[targetGUID] or 0
                tbl[targetGUID] = cur + 1
            end
        end
    end
end

local function DiffStates(cur, old)
    for guid, newCount in pairs(cur) do
        local oldCount = old[guid]
        if oldCount ~= newCount then
            FireCallback("TARGETED_COUNT_CHANGED", guid, newCount)
        end
        old[guid] = nil -- removing keys that exist in both states
    end
    -- at this point only the keys that existed in old, but not in the new remain
    local guid, count = next(old)
    while (guid) do
        FireCallback("TARGETED_COUNT_CHANGED", guid, 0)
        old[guid] = nil

        guid, count = next(old)
    end
end

local buffer1 = {}
local buffer2 = {}
local bufToggle = false
local cur, old = buffer1, buffer2
local function ScanUnits()
    cur, old = old, cur

    -- wipe(cur)
    ScanUnitsIntoTable(cur)
    DiffStates(cur, old) -- also wipes the "back buffer" in the process
end

-- Again if you aggro a pack not all units will instantly have a target unit present
-- so rescanning shortly after
local scheduledUpdateTime = 0
function f:UNIT_TARGET(event, unit)
    local now = GetTime()
    if now - scheduledUpdateTime > 0.5 then
        C_Timer.After(0.5, ScanUnits)
        scheduledUpdateTime = now
    end
    ScanUnits()
end


function f:NAME_PLATE_UNIT_ADDED(event, unit)
    scanUnits[unit] = true

    ScanUnits()
end


function f:NAME_PLATE_UNIT_REMOVED(event, unit)
    scanUnits[unit] = nil

    ScanUnits()
end


function lib:GetUnitTargetedCount(unit)
    local targetGUID = UnitGUID(unit)
    return self:GetGUIDTargetedCount(targetGUID)
end

function lib:GetGUIDTargetedCount(targetGUID)
    return cur[targetGUID] or 0
end

function f:COMBAT_LOG_EVENT_UNFILTERED()
    local timestamp, eventType, hideCaster,
    srcGUID, srcName, srcFlags, srcFlags2,
    dstGUID, dstName, dstFlags, dstFlags2,
    spellID, spellName, spellSchool, auraType, amount = CombatLogGetCurrentEventInfo()

    if eventType == "UNIT_DIED" or eventType == "UNIT_DESTROYED" then
        ScanUnits()
    end
end

function callbacks.OnUsed()
    f:RegisterEvent("UNIT_TARGET")
    f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
end

function callbacks.OnUnused()
    f:UnregisterAllEvents()
end


