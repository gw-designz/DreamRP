local log = {}
local logColor <const> = 5814783

---@param webhookUrl string
---@param title string
---@param message string
---@param args? table<string, any>
log.send = function(webhookUrl, title, message, args)
    if webhookUrl == "" then
        lib.print.error("No webhook url when logging", title, message)
        return
    end

    local description = message

    if args then
        description = description .. "\n\n"
        local formattedArgs = ""

        for k, v in pairs(args) do
            formattedArgs = formattedArgs .. ("**%s**: %s\n"):format(k, v)
        end

        description = description .. formattedArgs
    end

    local discordMessage = {
        embeds = {
            {
                title = title,
                description = description,
                color = logColor,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = {
                    text = ("Resource: %s"):format(bridge.currentResource)
                }
            }
        },
    }

    PerformHttpRequest(webhookUrl, function(statusCode, text, headers)
        if statusCode ~= 204 then
            print("Discord request failed", webhookUrl, statusCode)
        end
    end, "POST", json.encode(discordMessage), { ["Content-Type"] = "application/json" })
end

return log
