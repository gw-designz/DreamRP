
-- Example: Police Job Integration with bablo-billing
-- This script shows how to integrate job billing with police commands

-- Command to open police billing (requires sergeant rank or higher)
RegisterCommand('police_billing', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then return end

    -- Check if player is police
    if xPlayer.job.name ~= 'police' then
        xPlayer.showNotification('You must be a police officer to use this command', 'error')
        return
    end

    -- Check rank requirement (grade 2+ for sergeant)
    if xPlayer.job.grade < 2 then
        xPlayer.showNotification('You need to be at least a Sergeant to access billing system', 'error')
        return
    end

    -- Grant job account access and open billing
    TriggerClientEvent('police:openBilling', source)
end, false)

-- Client-side command handler
RegisterNetEvent('police:openBilling')
AddEventHandler('police:openBilling', function()
    -- Use the OpenJob export to grant access and open billing
    exports['bablo-billing']:OpenJob()
end)

-- Alternative: Check access before opening
RegisterCommand('check_billing_access', function(source, args)
    local canAccess = exports['bablo-billing']:CanAccessJobAccount()
    if canAccess then
        print('✅ You have job billing access')
        exports['bablo-billing']:Open()
    else
        print('❌ No job billing access - use /police_billing first')
    end
end, false)

-- Example: Automatic billing access for on-duty police
RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    if job.name == 'police' and job.grade >= 2 then
        -- Automatically grant access when going on duty as sergeant+
        Citizen.SetTimeout(1000, function()
            exports['bablo-billing']:OpenJob()
            exports['bablo-billing']:CanAccessJobAccount() -- This will return true now
        end)
    end
end)
