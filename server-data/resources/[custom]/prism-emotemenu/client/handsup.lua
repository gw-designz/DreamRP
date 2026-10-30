-- ============================================================
-- Hands Up — animation + keybind
-- ============================================================

local HANDSUP_DICT  = "missminuteman_1ig_2"
local HANDSUP_ANIM  = "handsup_enter"
local UNARMED_HASH  = -1569615261  -- GetHashKey("WEAPON_UNARMED")

local animDictReady = true   -- gate: false while dict is loading
local isHansingUp   = false  -- true while the hands-up animation is active


local function ApplyHandsUp(pressed)
    -- Load the anim dict before doing anything
    RequestAnimDict(HANDSUP_DICT)
    while not HasAnimDictLoaded(HANDSUP_DICT) do
        Wait(100)
    end

    if not animDictReady then return end

    local ped            = PlayerPedId()
    local _, weaponHash  = GetCurrentPedWeapon(ped)

    if pressed then
        if weaponHash == UNARMED_HASH then
            -- Unarmed: play the hands-up animation (once, no repeat)
            if not isHansingUp then
                TaskPlayAnim(ped, HANDSUP_DICT, HANDSUP_ANIM, 8.0, 8.0, -1, 50, 0, false, false, false)
                isHansingUp = true
            end
        else
            -- Armed: trigger inventory disarm event
            TriggerEvent("ox_inventory:disarm")
        end
    else
        -- Key released: cancel animation if it was playing
        if isHansingUp then
            isHansingUp = false
            ClearPedTasks(ped)
        end
    end
end


-- ============================================================
-- Register keybind if enabled in config
-- ============================================================

if Config.Handsup.enabled then
    RegisterCommand("+handsup", function() ApplyHandsUp(true)  end, false)
    RegisterCommand("-handsup", function() ApplyHandsUp(false) end, false)

    RegisterKeyMapping("+handsup", "Hands Up", "keyboard", Config.Handsup.keybind)
end