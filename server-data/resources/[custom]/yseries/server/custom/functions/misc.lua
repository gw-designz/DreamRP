RegisterNetEvent('yseries:server:toggle-phone', function(state, currentPhoneImei)
    -- * A callback function that you can use as you want when the phone is toggled.
end)

RegisterNetEvent('yseries:server:set-soft-open', function(softOpen)
    -- * A callback function that you can use as you want when the phone is soft open. Happens when a notification is received or a call and the phone is not fully opened.
end)

-- Function to check if the phone number already exists in the database
local function checkPhoneNumberExists(phoneNumber)
    local exists = MySQL.scalar.await([[
        SELECT COUNT(*) FROM yphone_sim_cards WHERE sim_number = @phoneNumber
    ]], {
        ['@phoneNumber'] = phoneNumber
    })

    return exists > 0
end

local function getRandomValue(tbl)
    if #tbl == 0 then return nil end

    -- Generate a random index and return the corresponding value
    local index = math.random(1, #tbl)
    return tbl[index]
end

function GeneratePhoneNumber()
    local phone = ""
    local exists = true

    while exists do
        phone = getRandomValue(Config.Sim.NumberPrefix) --[[@as string]]

        for _ = 1, Config.Sim.NumberLength do
            phone = phone .. tostring(math.random(0, 9))
        end

        -- Check if the generated number exists in the database
        exists = checkPhoneNumberExists(phone)
    end

    return phone
end

function SplitStr(inputstr, sep)
    sep = sep or ":"
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        t[#t + 1] = str
    end
    return t
end

RegisterNetEvent('yseries:server:update-users-phone-number', function(phoneNumber)
    local src = source

    if not phoneNumber or phoneNumber == '' then
        debugPrint('update-users-phone-number: missing phone number')
        return
    end

    local playerIdentifier = Framework.GetPlayerFromId(src)?.identifier

    if Config.Framework == 'esx' then
        MySQL.query.await([[
            UPDATE users
            SET phone_number = @phoneNumber
            WHERE identifier = @identifier]], {
            ['@phoneNumber'] = phoneNumber,
            ['@identifier'] = playerIdentifier
        })
    elseif Config.Framework == 'qb' or Config.Framework == 'qbox' then
        local player = Config.Framework == 'qbox'
            and exports.qbx_core:GetPlayer(src)
            or exports['qb-core']:GetCoreObject()?.Functions.GetPlayer(src)

        if not player then
            debugPrint('update-users-phone-number: player not found for source ' .. tostring(src))
            return
        end

        -- * Update charinfo in memory, sync to client, then persist to `players.charinfo`.
        local charInfo = player.PlayerData.charinfo
        if not charInfo then
            debugPrint('update-users-phone-number: missing charinfo for source ' .. tostring(src))
            return
        end

        charInfo.phone = phoneNumber

        player.Functions.SetPlayerData('charinfo', charInfo)
        player.Functions.Save()
    end
end)

RegisterNetEvent('yseries:server:y:new-tweet', function(data, playerIdentifier)
    debugPrint('Misc: New tweet added: RegisterNetEvent:yseries:server:twitter:new-tweet')

    local notification = {
        app = 'y',
        sound = 'custom',
        text = '',
        data = {
            creator = data.username,
        },
        timeout = 3000
    }

    if data.replyTo then
        TriggerEvent('yseries:server:logs:create', 'y', 'Y', '📢 New reply from ' .. data.username .. ' to ' .. data.ownerUsername, 'y', data.content, data?.attachments?.photo, nil,
            playerIdentifier)
    else
        TriggerEvent('yseries:server:logs:create', 'y', 'Y', '📢 New tweet from ' .. data.username, 'y', data.content, data?.attachments?.photo, nil, nil, playerIdentifier)

        if (Config.Y.GlobalNotifications) then
            notification.data.type = 'newPost'
            notification.data.translateKey = 'newPostLabel'
            notification.data.translateParams = { username = data.username }

            TriggerClientEvent('yseries:client:send-notification', -1, notification)
        end
    end
end)

RegisterNetEvent('yseries:server:instashots:on-new-post', function(data, playerIdentifier)
    debugPrint('Misc: New instashots post added: RegisterNetEvent:yseries:server:instashots:on-new-post')

    local imageUrl = nil -- Initialize as nil for no image

    -- Check if there is media data and it's a table
    if data.attachments?.media and type(data.attachments?.media) == 'table' then
        -- Check if the first media item has an image
        if data.attachments.media[1] and data.attachments.media[1].image then
            imageUrl = data.attachments.media[1].image
        end
    end

    TriggerEvent('yseries:server:logs:create', 'instashots', 'Instashots', '📸 New post from ' .. data.username, 'instashots', data.caption, imageUrl, nil, nil, playerIdentifier)

    local instaGlobal = Config.Instashots.GlobalNotifications
    if instaGlobal == true or (type(instaGlobal) == 'table' and instaGlobal.newPost) then
        local notification = {
            app = 'instashots',
            sound = 'default',
            text = '',
            data = {
                type = 'newPost',
                translateKey = 'newPostLabelNotify',
                translateParams = { username = data.username },
                creator = data.username,
            },
            timeout = 3000
        }
        TriggerClientEvent('yseries:client:send-notification', -1, notification)
    end
end)

RegisterNetEvent('yseries:server:ypay:on-new-transfer', function(data, playerIdentifier)
    debugPrint('Misc: New YPay transfer added: RegisterNetEvent:yseries:server:ypay:on-new-transfer')

    local transferMessage = data.sender ..
        ' → ' .. data.recipient .. ' | Amount: ' .. data.amount .. Config.CurrencySymbol .. ' | Reason: ' ..
        data.reason

    TriggerEvent('yseries:server:logs:create', 'ypay', 'YPay', 'New transfer 💸', 'ypay', transferMessage, nil, nil, nil, playerIdentifier)
end)

RegisterNetEvent('yseries:server:ybuy:on-new-ad', function(data, playerIdentifier)
    debugPrint('Misc: New YBuy ad created: RegisterNetEvent:yseries:server:ybuy:on-new-ad')

    local adMessage = ''

    TriggerEvent('yseries:server:logs:create', 'ybuy', 'YBuy', 'New ad created 📃', 'ybuy', adMessage,
        json.decode(data.attachments)?.photos[1]?.image, false,
        data, playerIdentifier)

    if Config.YBuy.GlobalNotifications then
        local notification = {
            app = 'ybuy',
            sound = 'default',
            text = '',
            data = {
                type = 'newAd',
                creator = data.number,
            },
            timeout = 3000
        }
        TriggerClientEvent('yseries:client:send-notification', -1, notification)
    end
end)

RegisterNetEvent('yseries:server:promoHub:on-new-ad', function(data, playerIdentifier)
    debugPrint('Misc: New PromoHub ad created: RegisterNetEvent:yseries:server:promoHub:on-new-ad')

    local adMessage = ''

    TriggerEvent('yseries:server:logs:create', 'promoHub', 'PromoHub', 'New ad created 📢', 'promoHub', adMessage, json.decode(data.attachments)?.photos[1]?.image, false, data,
        playerIdentifier, true)

    if Config.PromoHub.GlobalNotifications then
        local notification = {
            app = 'promoHub',
            sound = 'default',
            text = '',
            data = {
                from = playerIdentifier,
                type = 'newAd',
                creator = data.number,
            },
            timeout = 3000
        }
        TriggerClientEvent('yseries:client:send-notification', -1, notification)
    end
end)

--- Payload for `yseries:server:gallery:on-photo-deleted`.
---@class GalleryPhotoDeletedData
---@field id number Gallery row ID in `yphone_gallery`.
---@field phoneImei string Phone IMEI that owned the media row.
---@field image string Primary media URL. Photo file URL for images; video file URL for videos (`yphone_gallery.image`).
---@field thumbnail string|nil Video poster/thumbnail URL. Empty or `nil` for photo rows.
---@field source string|nil Gallery source tag (`camera`, `download`, `hidden`, `private`, `other`, etc.).
---@field permanent boolean `false` when moved to recycle bin (soft delete); `true` when the DB row is purged.
---@field playerSource number|nil Server id of the player who initiated the delete. `nil` for automated recycle purge.

--- Fired server-side when a gallery photo/video row is removed (soft delete or recycle purge).
--- Use this hook to delete the underlying media from FiveManage, S3, etc.
--- Prefer `AddEventHandler` in your own server resource; this stub mirrors other yseries integration hooks.
---@param data GalleryPhotoDeletedData
---@param playerIdentifier string|nil Framework identifier of the deleting player. `nil` when purged by the server.
AddEventHandler('yseries:server:gallery:on-photo-deleted', function(data, playerIdentifier)
    -- * Example: delete remote storage when the DB row is permanently purged.
    -- if data.permanent then
    --     -- deleteMedia(data.image)
    --     -- if data.thumbnail and data.thumbnail ~= '' then deleteMedia(data.thumbnail) end
    -- end
end)
