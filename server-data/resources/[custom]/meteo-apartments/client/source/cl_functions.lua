ApartmentFunctions = {}

local isPlayingLockpick = false

local function dropFingerprint()
    if GetResourceState('meteo-appearance') == 'started' then
        if exports['meteo-appearance']:isWearingGloves() then return end
    end
    TriggerServerEvent('evidence:server:CreateFingerDrop', GetEntityCoords(cache.ped))
end

local function getMinigame()
    if Config.minigame ~= 'auto' then return Config.minigame end
    if GetResourceState('meteo-circlepick') == 'started' then return 'meteo-circlepick' end
    return 'ox_lib'
end

--- Lockpick minigame - uses Config.minigame to determine which system
---@param difficulty table Array of difficulty strings for ox_lib {'easy', 'medium', 'hard'}
---@param circlepickDifficulty string|nil Difficulty for meteo-circlepick ('easy', 'medium', 'hard')
---@param speedBonus number|nil % to slow down circlepick (e.g. 42 = 42% slower circles)
---@return boolean|nil success true = passed, false = failed, nil = cancelled
function ApartmentFunctions.LockpickMinigame(difficulty, circlepickDifficulty, speedBonus)
    local minigame = getMinigame()
    if minigame == 'meteo-circlepick' then
        return exports['meteo-circlepick']:startLockpick(circlepickDifficulty or 'medium', nil, speedBonus or 0)
    end
    return lib.skillCheck(difficulty)
end

local function PlayLockpickAnimLoop(ped)
    local dict = 'veh@break_in@0h@p_m_one@'
    local anim = 'low_force_entry_ds'
    lib.requestAnimDict(dict)

    CreateThread(function()
        while isPlayingLockpick do
            if not IsEntityPlayingAnim(ped, dict, anim, 3) then
                TaskPlayAnim(ped, dict, anim, 3.0, 3.0, -1, 16, 0, false, false, false)
            end
            Wait(1000)
        end
        ClearPedTasks(ped)
    end)
end

--- Full lockpick attempt with animation and minigame
---@param difficulty table Array of difficulty strings
---@param circlepickDifficulty string|nil Difficulty for meteo-circlepick ('easy', 'medium', 'hard')
---@param speedBonus number|nil % to slow down circlepick (from perks)
---@return boolean|nil success
function ApartmentFunctions.DoLockpick(difficulty, circlepickDifficulty, speedBonus)
    local ped = cache.ped

    -- Start looping animation
    isPlayingLockpick = true
    PlayLockpickAnimLoop(ped)

    -- Run minigame
    local success = ApartmentFunctions.LockpickMinigame(difficulty, circlepickDifficulty, speedBonus)

    -- Stop animation
    isPlayingLockpick = false

    dropFingerprint()

    return success
end