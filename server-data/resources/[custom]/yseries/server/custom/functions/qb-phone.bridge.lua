-- #region Email Bridge

local function exportHandler(exportName, func)
    AddEventHandler(('__cfx_export_qb-phone_%s'):format(exportName), function(setCB)
        setCB(func)
    end)
end

exportHandler('sendNewMailToOffline', function(citizenid, mailData)
    local offlineLookup = true
    local number = exports["yseries"]:GetPhoneNumberByIdentifier(citizenid, offlineLookup)

    exports["yseries"]:SendMail(mailData, 'phoneNumber', number)
end)

RegisterNetEvent('qb-phone:server:sendNewMail', function(mailData)
    local _source = source

    local _mailData = {
        title = mailData.subject,
        sender = mailData.sender .. '@yseries.live',
        senderDisplayName = mailData.sender,
        content = mailData.message,
    }

    if mailData?.button?.enabled then
        _mailData.actions = {
            {
                label = mailData?.button?.label,
                data = {
                    event = mailData?.button?.buttonEvent,
                    isServer = not string.find(mailData?.button?.buttonEvent, "client"),
                    data = mailData?.button?.buttonData
                }
            }
        }
    end

    exports["yseries"]:SendMail(_mailData, 'source', _source)
end)

-- #endregion

-- #region Notifications Bridge

-- ? Client side event is registered in `client\custom\functions\misc.lua` - `qb-phone:client:CustomNotification`

RegisterNetEvent('yseries:server:qb-phone-bridge:send-notification', function(title, text, timeout, playerSource)
    local number = exports["yseries"]:GetPhoneNumberBySourceId(playerSource)

    exports["yseries"]:SendNotification({
        app = 'phone',
        title = title,
        text = text,
        timeout = timeout,
    }, 'phoneNumber', number)
end)

-- #endregion
