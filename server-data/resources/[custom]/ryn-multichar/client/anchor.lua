-- Tells the UI where each slot ped's head is on screen, so every card can float above its ped.

local HEAD_BONE = 31086 -- SKEL_Head
local ABOVE_HEAD = 0.3 -- metres above the head bone
local MIN_STEP = 0.002 -- screen fraction a move must exceed before it is sent

local last = {}
local lastCount = -1

local function headOnScreen(ped)
    if not ped or not DoesEntityExist(ped) or not IsEntityVisible(ped) or GetEntityAlpha(ped) == 0 then
        return nil
    end
    local head = GetPedBoneCoords(ped, HEAD_BONE, 0.0, 0.0, 0.0)
    local onScreen, x, y = GetScreenCoordFromWorldCoord(head.x, head.y, head.z + ABOVE_HEAD)
    if not onScreen then return nil end
    return x, y
end

local function sendAll(slots)
    local changed = #slots ~= lastCount
    if not changed then
        for i, s in ipairs(slots) do
            local p = last[i]
            if not p or p.slot ~= s.slot or math.abs(p.x - s.x) >= MIN_STEP or math.abs(p.y - s.y) >= MIN_STEP then
                changed = true
                break
            end
        end
    end
    if not changed then return end

    last, lastCount = slots, #slots
    SendNUIMessage({ action = 'pedAnchor', data = { slots = slots } })
end

CreateThread(function()
    while true do
        local wait = 250
        local slots = {}
        if Camera.active and not Spawn.selectMode and not Photo.active then
            wait = 0
            for slotIndex, ped in pairs(Preview.peds) do
                local x, y = headOnScreen(ped)
                if x then
                    slots[#slots + 1] = { slot = tonumber(slotIndex) or slotIndex, x = x, y = y }
                end
            end
            table.sort(slots, function(a, b) return a.slot < b.slot end)
        end
        sendAll(slots)
        Wait(wait)
    end
end)
