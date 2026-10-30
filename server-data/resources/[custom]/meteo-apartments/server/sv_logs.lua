local loggerType = GetConvar('meteo:logger', 'discord')

-- Discord Webhook Configuration
local DiscordWebhook = {
    webhook = "", -- Set your Discord webhook URL here for logs
    botName = "METEO APARTMENTS",
    embedColor = 3447003,
    footer = {
        text = "METEO APARTMENTS • " .. os.date("%Y"),
        icon_url = "https://r2.fivemanage.com/ND1ABtrhOCiEbMgp1LFCW/182349304.png"
    }
}

local function SendDiscordLog(title, description, color, fields)
    if DiscordWebhook.webhook == "" then return end

    local embed = {
        {
            title = title,
            description = description,
            color = color or DiscordWebhook.embedColor,
            fields = fields or {},
            footer = {
                text = DiscordWebhook.footer.text,
                icon_url = DiscordWebhook.footer.icon_url
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    }

    PerformHttpRequest(DiscordWebhook.webhook, function(err, text, headers) end, 'POST', json.encode({
        username = DiscordWebhook.botName,
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

local function GetPlayerInfo(source)
    local QBCore = exports['qb-core']:GetCoreObject()
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return nil end
    return {
        name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
        citizenid = player.PlayerData.citizenid
    }
end

-- Color constants
local Colors = {
    RED = 15548997,
    GREEN = 5763719,
    ORANGE = 15105570,
    BLUE = 3447003,
}

function LogApartmentPurchased(source, apartmentId, price)
    if DiscordWebhook.webhook == "" then return end
    local player = GetPlayerInfo(source)
    if not player then return end

    if loggerType == 'oxlib' then
        lib.logger(source, 'ApartmentPurchased', string.format('%s purchased apartment %s for $%s', player.name, apartmentId, price), 'apartments', 'purchase', 'citizenid:' .. player.citizenid)
        return
    end

    SendDiscordLog(
        ":key: Apartment Purchased",
        "**" .. player.name .. "** purchased an apartment",
        Colors.GREEN,
        {
            { name = ":bust_in_silhouette: Player", value = "**" .. player.name .. "**\n(" .. player.citizenid .. ")", inline = true },
            { name = ":key: Apartment", value = "**" .. apartmentId .. "**", inline = true },
            { name = ":moneybag: Price", value = "**$" .. price .. "**", inline = true },
        }
    )
end

function LogApartmentSold(source, apartmentId, sellPrice)
    if DiscordWebhook.webhook == "" then return end
    local player = GetPlayerInfo(source)
    if not player then return end

    if loggerType == 'oxlib' then
        lib.logger(source, 'ApartmentSold', string.format('%s sold apartment %s for $%s', player.name, apartmentId, sellPrice), 'apartments', 'sell', 'citizenid:' .. player.citizenid)
        return
    end

    SendDiscordLog(
        ":dollar: Apartment Sold",
        "**" .. player.name .. "** sold their apartment",
        Colors.ORANGE,
        {
            { name = ":bust_in_silhouette: Player", value = "**" .. player.name .. "**\n(" .. player.citizenid .. ")", inline = true },
            { name = ":key: Apartment", value = "**" .. apartmentId .. "**", inline = true },
            { name = ":moneybag: Sell Price", value = "**$" .. sellPrice .. "**", inline = true },
        }
    )
end

function LogApartmentTransferred(buyerSource, apartmentId, ownerCid, targetCid, price)
    if DiscordWebhook.webhook == "" then return end
    local buyer = GetPlayerInfo(buyerSource)
    local buyerName = buyer and buyer.name or targetCid

    local priceText = price > 0 and ("$" .. price) or "Free"

    if loggerType == 'oxlib' then
        lib.logger(buyerSource or -1, 'ApartmentTransferred', string.format('Apartment %s transferred from %s to %s (%s) for %s', apartmentId, ownerCid, buyerName, targetCid, priceText), 'apartments', 'transfer', 'citizenid:' .. targetCid)
        return
    end

    SendDiscordLog(
        ":repeat: Apartment Transferred",
        "Apartment **" .. apartmentId .. "** transferred",
        Colors.BLUE,
        {
            { name = ":bust_in_silhouette: From", value = "**" .. ownerCid .. "**", inline = true },
            { name = ":bust_in_silhouette: To", value = "**" .. buyerName .. "**\n(" .. targetCid .. ")", inline = true },
            { name = ":moneybag: Price", value = "**" .. priceText .. "**", inline = true },
            { name = ":key: Apartment", value = "**" .. apartmentId .. "**", inline = false },
        }
    )
end

function LogMemberAdded(source, apartmentId, targetCid, role)
    if DiscordWebhook.webhook == "" then return end
    local player = GetPlayerInfo(source)
    if not player then return end

    if loggerType == 'oxlib' then
        lib.logger(source, 'MemberAdded', string.format('%s added member %s to apartment %s as %s', player.name, targetCid, apartmentId, role or 'guest'), 'apartments', 'member', 'citizenid:' .. player.citizenid)
        return
    end

    SendDiscordLog(
        ":white_check_mark: Member Added",
        "**" .. player.name .. "** added a member to their apartment",
        Colors.GREEN,
        {
            { name = ":bust_in_silhouette: Owner", value = "**" .. player.name .. "**\n(" .. player.citizenid .. ")", inline = true },
            { name = ":bust_in_silhouette: New Member", value = "**" .. targetCid .. "**", inline = true },
            { name = ":label: Role", value = "**" .. (role or "guest") .. "**", inline = true },
            { name = ":key: Apartment", value = "**" .. apartmentId .. "**", inline = false },
        }
    )
end

function LogMemberRemoved(source, apartmentId, targetCid)
    if DiscordWebhook.webhook == "" then return end
    local player = GetPlayerInfo(source)
    if not player then return end

    if loggerType == 'oxlib' then
        lib.logger(source, 'MemberRemoved', string.format('%s removed member %s from apartment %s', player.name, targetCid, apartmentId), 'apartments', 'member', 'citizenid:' .. player.citizenid)
        return
    end

    SendDiscordLog(
        ":x: Member Removed",
        "**" .. player.name .. "** removed a member from their apartment",
        Colors.RED,
        {
            { name = ":bust_in_silhouette: Owner", value = "**" .. player.name .. "**\n(" .. player.citizenid .. ")", inline = true },
            { name = ":bust_in_silhouette: Removed", value = "**" .. targetCid .. "**", inline = true },
            { name = ":key: Apartment", value = "**" .. apartmentId .. "**", inline = false },
        }
    )
end

function LogDoorUpgraded(source, apartmentId, doorIndex, newLevel, price)
    if DiscordWebhook.webhook == "" then return end
    local player = GetPlayerInfo(source)
    if not player then return end

    if loggerType == 'oxlib' then
        lib.logger(source, 'DoorUpgraded', string.format('%s upgraded door #%s in apartment %s to level %s for $%s', player.name, doorIndex, apartmentId, newLevel, price), 'apartments', 'upgrade', 'citizenid:' .. player.citizenid)
        return
    end

    SendDiscordLog(
        ":arrow_up: Door Security Upgraded",
        "**" .. player.name .. "** upgraded door security",
        Colors.BLUE,
        {
            { name = ":bust_in_silhouette: Player", value = "**" .. player.name .. "**\n(" .. player.citizenid .. ")", inline = true },
            { name = ":key: Apartment", value = "**" .. apartmentId .. "**", inline = true },
            { name = ":moneybag: Price", value = "**$" .. price .. "**", inline = true },
            { name = ":gear: Door #" .. doorIndex, value = "**Level " .. newLevel .. "**", inline = true },
        }
    )
end

function LogMemberLimitUpgraded(source, apartmentId, tierIndex, price)
    if DiscordWebhook.webhook == "" then return end
    local player = GetPlayerInfo(source)
    if not player then return end

    if loggerType == 'oxlib' then
        lib.logger(source, 'MemberLimitUpgraded', string.format('%s upgraded member limit for apartment %s to tier %s for $%s', player.name, apartmentId, tierIndex, price), 'apartments', 'upgrade', 'citizenid:' .. player.citizenid)
        return
    end

    SendDiscordLog(
        ":arrow_up: Member Limit Upgraded",
        "**" .. player.name .. "** upgraded member limit",
        Colors.BLUE,
        {
            { name = ":bust_in_silhouette: Player", value = "**" .. player.name .. "**\n(" .. player.citizenid .. ")", inline = true },
            { name = ":key: Apartment", value = "**" .. apartmentId .. "**", inline = true },
            { name = ":moneybag: Price", value = "**$" .. price .. "**", inline = true },
            { name = ":star: New Tier", value = "**Tier " .. tierIndex .. "**", inline = true },
        }
    )
end

function LogLockpickSuccess(source, doorId)
    if DiscordWebhook.webhook == "" then return end
    local player = GetPlayerInfo(source)
    if not player then return end

    if loggerType == 'oxlib' then
        lib.logger(source, 'DoorLockpicked', string.format('%s lockpicked door %s', player.name, doorId), 'apartments', 'security', 'citizenid:' .. player.citizenid)
        return
    end

    SendDiscordLog(
        ":warning: Door Lockpicked",
        "**" .. player.name .. "** lockpicked a door",
        Colors.RED,
        {
            { name = ":bust_in_silhouette: Player", value = "**" .. player.name .. "**\n(" .. player.citizenid .. ")", inline = true },
            { name = ":key: Door", value = "**" .. doorId .. "**", inline = true },
            { name = ":clock1: Time", value = os.date("%H:%M:%S"), inline = true },
        }
    )
end

function LogStormramSuccess(source, doorId)
    if DiscordWebhook.webhook == "" then return end
    local player = GetPlayerInfo(source)
    if not player then return end

    if loggerType == 'oxlib' then
        lib.logger(source, 'DoorBreached', string.format('%s breached door %s with stormram', player.name, doorId), 'apartments', 'security', 'citizenid:' .. player.citizenid)
        return
    end

    SendDiscordLog(
        ":warning: Door Breached (Stormram)",
        "**" .. player.name .. "** breached a door with stormram",
        Colors.RED,
        {
            { name = ":bust_in_silhouette: Officer", value = "**" .. player.name .. "**\n(" .. player.citizenid .. ")", inline = true },
            { name = ":key: Door", value = "**" .. doorId .. "**", inline = true },
            { name = ":clock1: Time", value = os.date("%H:%M:%S"), inline = true },
        }
    )
end
