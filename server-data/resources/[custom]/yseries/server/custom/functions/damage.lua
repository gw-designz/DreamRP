-- #region Damage System

-- Function to get the phone's damage data by IMEI
local getPhoneDamage = function(phoneImei)
    local result = MySQL.single.await([[
        SELECT damage
        FROM yphone_devices
        WHERE imei = @imei
    ]], {
        ['@imei'] = phoneImei
    })

    if not result then
        return { success = false, error = "Invalid IMEI" }
    end

    -- If the damage field is not null, return the decoded JSON, otherwise return an empty table
    if result.damage then
        return { success = true, data = json.decode(result.damage) }
    else
        return { success = true, data = {} }
    end
end

-- Function to set the phone's damage data by IMEI
local setPhoneDamage = function(phoneImei, damageData)
    if next(damageData) == nil then
        local success = MySQL.update.await([[
            UPDATE yphone_devices
            SET damage = NULL
            WHERE imei = @imei
        ]], {
            ['@imei'] = phoneImei
        })

        if success then
            return { success = true, data = damageData }
        else
            return { success = false, error = "Error updating database" }
        end
    else
        local success = MySQL.update.await([[
            UPDATE yphone_devices
            SET damage = @damage
            WHERE imei = @imei
        ]], {
            ['@damage'] = json.encode(damageData),
            ['@imei'] = phoneImei
        })

        if success then
            return { success = true, data = damageData }
        else
            return { success = false, error = "Error updating database" }
        end
    end
end

-- A function to update or set the screen damage and touchscreen status
local function breakScreen(phoneImei, level, breakTouchscreen)
    -- Generate random level and touchscreen status if either is nil
    if level == nil then
        level = math.random(Config.Damage.Screen.LevelLowest, Config.Damage.Screen.LevelHighest)
    end

    if breakTouchscreen == nil then
        breakTouchscreen = math.random(0, 1) -- 50% chance of touchscreen working
    end

    level = tonumber(level)

    -- Validate the damage level using the config values
    if level < Config.Damage.Screen.LevelLowest or level > Config.Damage.Screen.LevelHighest then
        return {
            success = false,
            error = ("Invalid level. Please provide a value between %d and %d."):format(
                Config.Damage.Screen.LevelLowest, Config.Damage.Screen.LevelHighest)
        }
    end

    -- Get the current damage data
    local result = getPhoneDamage(phoneImei)
    if not result.success then
        return result -- Propagate the error message
    end

    local damageData = result.data

    -- Replace or add the `screen` damage with the new level
    damageData.screen = level
    damageData.breakTouchscreen = breakTouchscreen

    -- Update the database with the new damage data (preserving other damages)
    return setPhoneDamage(phoneImei, damageData)
end

-- A function to remove the screen damage and touchscreen status
local function fixScreen(phoneImei)
    -- Get the current damage data
    local result = getPhoneDamage(phoneImei)
    if not result.success then
        return result -- Propagate the error message
    end

    local damageData = result.data

    -- Remove the 'screen' and 'touchscreen' properties
    damageData.screen = nil
    damageData.breakTouchscreen = nil

    -- Update the damage data in the database
    return setPhoneDamage(phoneImei, damageData)
end

-- #endregion

-- #region Damage System Exports

local function exportHandler(resource, name, cb)
    AddEventHandler(('__cfx_export_%s_%s'):format(resource, name), function(setCB)
        setCB(cb)
    end)
end

local function export_breakScreen(phoneImei, level, breakTouchscreen)
    if not phoneImei then
        return
    end

    local result = breakScreen(phoneImei, level, breakTouchscreen)

    if result?.success then
        local sourceId = GetPlayerSourceIdByPhoneImei(phoneImei)

        if sourceId then
            TriggerClientEvent('yseries:client:after-device-screen-damage', sourceId, result.data)
        end
    end

    return result
end
exports('BreakScreen', export_breakScreen)
exportHandler('yseries', 'BreakScreen', export_breakScreen)

local function export_fixScreen(phoneImei)
    if not phoneImei then
        return
    end

    local result = fixScreen(phoneImei)

    if result?.success then
        local sourceId = GetPlayerSourceIdByPhoneImei(phoneImei)

        if sourceId then
            TriggerClientEvent('yseries:client:after-device-screen-damage', sourceId, nil)
        end
    end

    return result
end
exports('FixScreen', export_fixScreen)
exportHandler('yseries', 'FixScreen', export_fixScreen)

---@param phoneImei string The phone IMEI to get screen damage for
---@return table|nil Returns table with screen damage level and touchscreen status, or nil if no damage or invalid IMEI
local function export_getScreenDamage(phoneImei)
    if not phoneImei then
        return nil
    end

    local result = getPhoneDamage(phoneImei)
    if not result.success then
        return nil
    end

    local damageData = result.data

    -- Return nil if no screen damage exists
    if not damageData.screen then
        return nil
    end

    -- Return screen damage level and touchscreen status
    return {
        level = damageData.screen,
        breakTouchscreen = damageData.breakTouchscreen or false
    }
end
exports('GetScreenDamage', export_getScreenDamage)
exportHandler('yseries', 'GetScreenDamage', export_getScreenDamage)

-- #endregion
