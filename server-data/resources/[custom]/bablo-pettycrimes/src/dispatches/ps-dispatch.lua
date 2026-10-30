
Dispatch = Dispatch or {}

CreateThread(function()
    if Config.Dispatch ~= 'ps-dispatch' then
        return
    end

    -- Extra law-enforcement jobs that should also receive dispatch alerts.
    -- The crime modules only target { 'police', 'lspd', 'bcso' }, so any custom
    -- LEO job (sasp, rso, ...) is added here to receive every alert too.
    local EXTRA_JOBS = { 'sasp', 'rso' }

    local function withExtraJobs(jobs)
        local result = {}
        local seen = {}

        for _, job in ipairs(jobs or {}) do
            if not seen[job] then
                seen[job] = true
                result[#result + 1] = job
            end
        end

        for _, job in ipairs(EXTRA_JOBS) do
            if not seen[job] then
                seen[job] = true
                result[#result + 1] = job
            end
        end

        return result
    end

    function Dispatch:Send(data)
        local chance = math.random(1, 100)

        if chance > 50 then
            return
        end

        local getStreetAndZone = function(coords)
            local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
            local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
            return street .. ', ' .. zone
        end

        local getGender = function(ped)
            if GetEntityModel(ped) == GetHashKey('mp_m_freemode_01') then
                return 'male'
            elseif GetHashKey('mp_f_freemode_01') then
                return 'female'
            else
                return nil
            end
        end

        local dispatchData = {
            jobs = withExtraJobs(data.jobs),
            message = data.description or "",
            codeName = "NONE",
            code = data.code or '10-35',
            icon = 'fas fa-question',
            priority = 2,
            coords = data.coords or GetEntityCoords(cache.ped),
            gender = getGender(cache.ped),
            street = getStreetAndZone(data.coords or GetEntityCoords(cache.ped)),
            name = data.message or nil,
            alertTime = 12,
            automaticGunfire = false,
            alert = {
                radius = 0,
                sprite = data.blip.sprite or 1,
                color = data.blip.color or 1,
                scale = data.blip.scale or 0.5,
                length = 2,
                sound = 'Lose_1st',
                sound2 = 'GTAO_FM_Events_Soundset',
                flash = data.blip.flash or false
            },
        }

        if data._customData then
            for k, v in pairs(data._customData) do
                dispatchData[k] = v
            end
        end

        TriggerServerEvent('ps-dispatch:server:notify', dispatchData)
    end
end)
