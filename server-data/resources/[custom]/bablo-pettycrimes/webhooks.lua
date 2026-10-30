
-- Here you can configure the webhooks here is all the diffrent types of webhooks if you only would like some and not all you can either set it as false or leave it as ''.
-- The webhooks are used to log diffrent actions in the server to discord.

while not eventName do Wait(0) end

Webhooks = {
    ['OPENED_LETTER'] = {
        title = 'Opened Letter',
        template = '%s opened letter and got %s',
        webhook = ''
    },
    ['PARKING_METER_ROBBERY'] = {
        title = 'Parking Meter Robbery',
        template = '%s robbed a parking meter and got %s',
        webhook = ''
    },
    ['MUGGED_NPC'] = {
        title = 'Mugged NPC',
        template = '%s mugged a npc and got %s',
        webhook = ''
    },
    ['OPENED_PARCEL'] = {
        title = 'Opened Parcel',
        template = '%s opened parcel and got %s',
        webhook = ''
    },
    ['PICKPOCKED_NPC'] = {
        title = 'Pickpocketed NPC',
        template = '%s pickpocketed a npc and got %s',
        webhook = ''
    },
    ['SMASH_N_GRAB'] = {
        title = 'Smash and Grab',
        template = '%s smashed and vehicle and got %s',
        webhook = ''
    },
    ['STORE_SHELVES'] = {
        title = 'Store Shelves',
        template = '%s searched store shelves and received loot.',
        webhook = ''
    },
    ['ATM_ROBBERY_DRAIN'] = {
        title = 'ATM Robbery',
        template = '%s drained an ATM and got %s',
        webhook = ''
    },
    ['CASH_REGISTER_ROBBERY'] = {
        title = 'Cash Register Robbery',
        template = '%s robbed a cash register and got %s',
        webhook = ''
    },
    ['VENDING_MACHINE_ROBBERY'] = {
        title = 'Vending Machine Robbery',
        template = '%s robbed a vending machine and got %s',
        webhook = ''
    },
    ['TIRE_SLASH'] = {
        title = 'Tire Slash',
        template = '%s %s',
        webhook = ''
    },
    ['PEDAL_BRICK'] = {
        title = 'Pedal Brick',
        template = '%s %s',
        webhook = ''
    },
    ['SMASH_N_GRAB_BAG'] = {
        title = 'Smash and Grab Bag',
        template = '%s opened a smash and grab bag and got %s',
        webhook = ''
    },
}

function sendWebhook(source, name, messageData)
    if not Config.Logs then return end

    if not Webhooks[name] or not Webhooks[name].webhook or Webhooks[name].webhook == '' then
        Trace('Webhook error: Webhook URL not set for', name)
        return
    end

    local playerName
    if Config.Framework == 'standalone' then
        playerName = GetPlayerName(source)
    else
        playerName = GetPlayerName(source) .. ' (' .. source .. ') ' .. Framework:getPlayerName(source)
    end

    local message = Webhooks[name].template and string.format(Webhooks[name].template, playerName, tostring(messageData)) or
        "ERROR: No template found"

    local payload = {
        embeds = {
            {
                title = Webhooks[name].title or "Webhook",
                description = message,
                color = 8039935,
                footer = {
                    text = 'Bablo PettyCrimes | ' .. os.date("%Y-%m-%d %H:%M:%S")
                }
            }
        }
    }

    PerformHttpRequest(Webhooks[name].webhook, function(err, text, headers)
        if err == 401 then
            Trace("ERROR: Unauthorized - The webhook URL might be invalid or expired.")
        elseif err == 429 then
            Trace("ERROR: Rate limited - Too many requests. Wait and try again later.")
        elseif err ~= 200 and err ~= 204 then
            Trace("Webhook failed! HTTP Error:", err, "Response:", text)
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

RegisterNetEvent(eventName .. 'server:sendWebhook')
AddEventHandler(eventName .. 'server:sendWebhook', function(name, data)
    Trace('Sending webhook', name, json.encode(data))

    sendWebhook(source, name, data)
end)
