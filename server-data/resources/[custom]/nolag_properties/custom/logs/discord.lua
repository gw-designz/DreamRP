--[[
    Provided below is the log configuration, allowing you to make adjustments or create your own.
    If your log sources are not included, you have the option to request the creator to generate
    a file based on this example and include it.
]]

if Config.Logs ~= "discord" then return end

-- General webhook (fallback)
local generalWebhook = GetConvar("propertiesDiscordWebhook", "SET_YOUR_WEBHOOK_IN_SERVER.CFG")

-- Specific webhooks for different actions
local webhooks = {
    property = GetConvar("propertiesPropertyWebhook", generalWebhook),
    building = GetConvar("propertiesBuildingWebhook", generalWebhook),
    keyholder = GetConvar("propertiesKeyholderWebhook", generalWebhook),
    door = GetConvar("propertiesDoorWebhook", generalWebhook),
    raid = GetConvar("propertiesRaidWebhook", generalWebhook),
    transaction = GetConvar("propertiesTransactionWebhook", generalWebhook)
}

local discord = {
    send = function(title, description, color, webhookType)
        local webhook = webhooks[webhookType] or generalWebhook
        local embed = {
            {
                ["title"] = title,
                ["description"] = description,
                ["color"] = color,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({ embeds = embed }), { ['Content-Type'] = 'application/json' })
    end,

    addField = function(embed, name, value, inline)
        table.insert(embed[1].fields, {
            ["name"] = name,
            ["value"] = value,
            ["inline"] = inline or false
        })
    end,

    sendEmbed = function(embed, webhookType)
        local webhook = webhooks[webhookType] or generalWebhook
        PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({ embeds = embed }), { ['Content-Type'] = 'application/json' })
    end
}

Logs = {
    CreateProperty = function(playerId, propertyId, propertyType, propertyLabel, propertyPrice)
        local embed = {
            {
                ["title"] = "🏠 Property Created",
                ["color"] = 65280,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Player", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.addField(embed, "📋 Type", "`" .. propertyType .. "`", true)
        discord.addField(embed, "🏷️ Label", "`" .. propertyLabel .. "`", true)
        discord.addField(embed, "💰 Price", "`$" .. propertyPrice .. "`", true)
        discord.sendEmbed(embed, "property")
    end,

    DeleteProperty = function(playerId, propertyId, propertyType, propertyLabel)
        local embed = {
            {
                ["title"] = "🗑️ Property Deleted",
                ["color"] = 16711680,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Player", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.addField(embed, "📋 Type", "`" .. propertyType .. "`", true)
        discord.addField(embed, "🏷️ Label", "`" .. propertyLabel .. "`", true)
        discord.sendEmbed(embed, "property")
    end,

    CreateBuilding = function(playerId, buildingId, buildingLabel)
        local embed = {
            {
                ["title"] = "🏗️ Building Created",
                ["color"] = 65280,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Player", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Building ID", "`" .. buildingId .. "`", true)
        discord.addField(embed, "🏷️ Label", "`" .. buildingLabel .. "`", true)
        discord.sendEmbed(embed, "building")
    end,

    DeleteBuilding = function(playerId, buildingId, buildingLabel)
        local embed = {
            {
                ["title"] = "🏗️ Building Deleted",
                ["color"] = 16711680,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Player", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Building ID", "`" .. buildingId .. "`", true)
        discord.addField(embed, "🏷️ Label", "`" .. buildingLabel .. "`", true)
        discord.sendEmbed(embed, "building")
    end,

    BuyProperty = function(playerId, propertyId, propertyPrice, propertyLabel)
        local embed = {
            {
                ["title"] = "💰 Property Purchase",
                ["color"] = 65280,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Buyer", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.addField(embed, "🏷️ Label", "`" .. propertyLabel .. "`", true)
        discord.addField(embed, "💰 Price", "`$" .. propertyPrice .. "`", true)
        discord.sendEmbed(embed, "transaction")
    end,

    RentProperty = function(playerId, propertyId, propertyPrice, propertyLabel, rentTill)
        local embed = {
            {
                ["title"] = "📝 Property Rented",
                ["color"] = 65280,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Tenant", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.addField(embed, "🏷️ Label", "`" .. propertyLabel .. "`", true)
        discord.addField(embed, "💰 Price", "`$" .. propertyPrice .. "`", true)
        discord.addField(embed, "📅 Rent Until", "`" .. rentTill .. "`", true)
        discord.sendEmbed(embed, "transaction")
    end,

    ExtendRentProperty = function(playerId, propertyId, propertyPrice, propertyLabel, rentFrom, rentTill, rentAs)
        local embed = {
            {
                ["title"] = "⏰ Rent Extended",
                ["color"] = 65280,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Tenant", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.addField(embed, "🏷️ Label", "`" .. propertyLabel .. "`", true)
        discord.addField(embed, "💰 Price", "`$" .. propertyPrice .. "`", true)
        discord.addField(embed, "📅 From", "`" .. rentFrom .. "`", true)
        discord.addField(embed, "📅 Until", "`" .. rentTill .. "`", true)
        discord.addField(embed, "📋 Rent Type", "`" .. rentAs .. "`", true)
        discord.sendEmbed(embed, "transaction")
    end,

    CancelRentProperty = function(playerId, propertyId, propertyLabel, canceledFrom, rentedFrom, rentedTo, rentedPrice)
        local embed = {
            {
                ["title"] = "❌ Rent Cancelled",
                ["color"] = 16711680,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Tenant", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.addField(embed, "🏷️ Label", "`" .. propertyLabel .. "`", true)
        discord.addField(embed, "💰 Price", "`$" .. rentedPrice .. "`", true)
        discord.addField(embed, "📅 Cancelled From", "`" .. canceledFrom .. "`", true)
        discord.addField(embed, "📅 Original Period", "`" .. rentedFrom .. "` → `" .. rentedTo .. "`", true)
        discord.sendEmbed(embed, "transaction")
    end,

    SellProperty = function(playerId, propertyId)
        local embed = {
            {
                ["title"] = "💰 Property Sold",
                ["color"] = 16711680,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Seller", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.sendEmbed(embed, "transaction")
    end,

    SetPropertyForSale = function(propertyId)
        local embed = {
            {
                ["title"] = "🏷️ Property Set for Sale",
                ["color"] = 16711680,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.addField(embed, "📋 Reason", "`Inactivity`", true)
        discord.sendEmbed(embed, "property")
    end,

    AddKeyHolder = function(playerId, propertyId, targetId)
        local embed = {
            {
                ["title"] = "🔑 Key Holder Added",
                ["color"] = 65280,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Added By", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.addField(embed, "👥 New Key Holder", "`" .. targetId .. "`", true)
        discord.sendEmbed(embed, "keyholder")
    end,

    RemoveKeyHolder = function(playerId, propertyId, targetId)
        local embed = {
            {
                ["title"] = "🔑 Key Holder Removed",
                ["color"] = 16711680,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Removed By", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.addField(embed, "👥 Removed Key Holder", "`" .. targetId .. "`", true)
        discord.sendEmbed(embed, "keyholder")
    end,

    RemoveAllKeyHolder = function(playerId, propertyId)
        local embed = {
            {
                ["title"] = "🔑 All Key Holders Removed",
                ["color"] = 16711680,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Removed By", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.sendEmbed(embed, "keyholder")
    end,

    AddDoor = function(playerId, propertyId, doorId)
        local embed = {
            {
                ["title"] = "🚪 Door Added",
                ["color"] = 65280,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Player", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.addField(embed, "🚪 Door ID", "`" .. doorId .. "`", true)
        discord.sendEmbed(embed, "door")
    end,

    RemoveDoor = function(playerId, propertyId, doorId)
        local embed = {
            {
                ["title"] = "🚪 Door Removed",
                ["color"] = 16711680,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Player", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.addField(embed, "🚪 Door ID", "`" .. doorId .. "`", true)
        discord.sendEmbed(embed, "door")
    end,

    RaidProperty = function(playerId, propertyId, propertyLabel)
        local embed = {
            {
                ["title"] = "🚨 Property Raided",
                ["color"] = 16711680,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Raider", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.addField(embed, "🏷️ Label", "`" .. propertyLabel .. "`", true)
        discord.sendEmbed(embed, "raid")
    end,

    RekeyLock = function(playerId, propertyId, lockType, lockId)
        local embed = {
            {
                ["title"] = "🔐 Lock Re-keyed",
                ["color"] = 16776960,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Player", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.addField(embed, "🔒 Lock Type", "`" .. lockType .. "`", true)
        discord.addField(embed, "🔢 Lock ID", "`" .. lockId .. "`", true)
        discord.sendEmbed(embed, "keyholder")
    end,

    IssuePhysicalKey = function(playerId, propertyId, lockType, lockId, targetId)
        local embed = {
            {
                ["title"] = "🔑 Physical Key Issued",
                ["color"] = 65280,
                ["footer"] = {
                    ["text"] = "NoLag Properties • " .. os.date("%Y-%m-%d %H:%M:%S")
                },
                ["fields"] = {}
            }
        }
        discord.addField(embed, "👤 Issued By", "`" .. playerId .. "`", true)
        discord.addField(embed, "🏷️ Property ID", "`" .. propertyId .. "`", true)
        discord.addField(embed, "🔒 Lock Type", "`" .. lockType .. "`", true)
        discord.addField(embed, "🔢 Lock ID", "`" .. lockId .. "`", true)
        discord.addField(embed, "👥 Recipient", "`" .. targetId .. "`", true)
        discord.sendEmbed(embed, "keyholder")
    end,
}

-- Set the metatable for the functions list
setmetatable(Logs, LogsMetaTable)
