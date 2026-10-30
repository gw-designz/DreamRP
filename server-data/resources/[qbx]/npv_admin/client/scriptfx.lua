-- Client halves of script blocks: hack minigame and scenario sounds.

-- Hack block: the server asks the triggering player's client to run an ox_lib skill check.
-- Difficulty 1-5 maps to a sequence of checks; resolves true when the player passes all of them.
local HACK = {
    [1] = { 'easy' },
    [2] = { 'easy', 'easy' },
    [3] = { 'easy', 'medium' },
    [4] = { 'medium', 'medium', 'hard' },
    [5] = { 'hard', 'hard', 'hard', 'hard' },
}

lib.callback.register('npv_admin:client:hack', function(difficulty, label)
    if Nui.open then return false end
    local seq = HACK[math.floor(tonumber(difficulty) or 3)] or HACK[3]
    lib.notify({ type = 'inform', description = ('Hacking: %s'):format(tostring(label or 'system')) })
    local ok, result = pcall(lib.skillCheck, seq, { 'w', 'a', 's', 'd' })
    return ok and result == true
end)

-- Sounds started by scripts; "Stop sounds" releases all of them.
local soundIds = {}

RegisterNetEvent('npv_admin:client:scriptSound', function(name, set, coords)
    if type(name) ~= 'string' then return end
    local id = GetSoundId()
    if coords and coords.x then
        PlaySoundFromCoord(id, name, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, set or '', false, 40.0, false)
    else
        PlaySoundFrontend(id, name, set or '', true)
    end
    soundIds[#soundIds + 1] = id
    -- Keep the list from growing forever: release sounds that have finished.
    for i = #soundIds, 1, -1 do
        if HasSoundFinished(soundIds[i]) then
            ReleaseSoundId(soundIds[i])
            table.remove(soundIds, i)
        end
    end
end)

RegisterNetEvent('npv_admin:client:stopSounds', function()
    for _, id in ipairs(soundIds) do
        StopSound(id)
        ReleaseSoundId(id)
    end
    soundIds = {}
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, id in ipairs(soundIds) do StopSound(id) ReleaseSoundId(id) end
end)
