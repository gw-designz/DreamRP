
Dispatch = Dispatch or {}

CreateThread(function()
    if Config.Dispatch ~= 'lb-tablet' then
        return
    end

    local codes = {
        [Translate("PARCEL_DISPATCH")] = "10-35",
        [Translate("PICKPOCKET_DISPATCH")] = "10-35",
        [Translate("MUGGING_DISPATCH")] = "10-35",
        [Translate("SMASHNGRAB_DISPATCH")] = "10-35",
        [Translate("MAILBOX_DISPATCH")] = "10-35",
        [Translate("PARKING_METER_DISPATCH")] = "10-35",
    }

    local function pickJob(data)
        -- lb-tablet only supports: 'police' | 'ambulance'
        if data.job == 'police' or data.job == 'ambulance' then
            return data.job
        end

        if type(data.jobs) == 'table' then
            for _, j in ipairs(data.jobs) do
                j = tostring(j):lower()

                if j == 'ambulance' or j == 'ems' then
                    return 'ambulance'
                end

                if j == 'police' or j == 'lspd' or j == 'bcso' or j == 'sheriff' then
                    return 'police'
                end
            end
        end

        return 'police'
    end

    local function generateTitle(data)
        if data.title and data.title ~= '' then
            return data.title
        end

        if data.blip and (data.blip.label or data.blip.text) then
            return data.blip.label or data.blip.text
        end

        if data.event and data.event ~= '' then
            return data.event
        end

        return "Dispatch Alert"
    end

    local function generateCode(title, data)
        if data.code and data.code ~= '' then
            return data.code
        end

        if not title or title == '' then
            return "DISP"
        end

        -- Convert "Smash and grab" -> "SAG"
        local out = {}
        for word in title:gmatch("%a+") do
            out[#out + 1] = word:sub(1, 1):upper()
            if #out >= 4 then break end
        end

        if #out > 0 then
            return table.concat(out)
        end

        return "DISP"
    end

    local function buildLocation(data)
        local coords = data.coords or GetEntityCoords(cache.ped)

        local x, y, z = coords.x, coords.y, coords.z or 0.0

        local label = "Unknown"

        if x and y then
            local streetHash, crossingHash = GetStreetNameAtCoord(x, y, z)

            local street = (streetHash and streetHash ~= 0) and GetStreetNameFromHashKey(streetHash) or nil
            local crossing = (crossingHash and crossingHash ~= 0) and GetStreetNameFromHashKey(crossingHash) or nil

            local zone = GetNameOfZone(x, y, z)
            local area = (zone and zone ~= "") and GetLabelText(zone) or nil

            if street then
                label = crossing and (street .. " / " .. crossing) or street

                if area and area ~= "NULL" then
                    label = label .. " (" .. area .. ")"
                end
            end
        end

        return {
            label = label,
            coords = { x = x, y = y } -- IMPORTANT: lb-tablet wants only X/Y
        }
    end

    local function mapBlip(blip)
        if type(blip) ~= "table" then
            return nil
        end

        return {
            sprite = blip.sprite,
            color = blip.color,
            size = blip.size or blip.scale or 1.0, -- convert scale -> size
            shortRange = blip.shortRange ~= false, -- default true
            label = blip.label or blip.text
        }
    end

    function Dispatch:Send(data)
        if type(data) ~= "table" then
            return
        end

        local title = generateTitle(data)
        local code = generateCode(title, data)

        local dispatchPayload = {
            priority = data.priority or "medium",
            code = codes[data.description or data.message or ""] or code,
            title = title,
            description = data.description or data.message or "",
            location = data.location or buildLocation(data),
            time = data.time or 120,
            image = data.image,
            job = pickJob(data),
            sound = data.sound,
            fields = data.fields,
            blip = mapBlip(data.blip)
        }

        if data._customData then
            for k, v in pairs(data._customData) do
                dispatchPayload[k] = v
            end
        end

        TriggerServerEvent("lb-tablet:addDispatch", dispatchPayload)

        print("^2[LB-TABLET DISPATCH SENT]^7 " .. json.encode(dispatchPayload))
    end
end)
