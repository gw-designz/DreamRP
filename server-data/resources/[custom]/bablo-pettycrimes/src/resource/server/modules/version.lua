Citizen.CreateThread(function()
    local resourceName = GetCurrentResourceName()
    local currentVersion = GetResourceMetadata(resourceName, "version", 0)

    local function toNumber(str)
        return tonumber(str)
    end

    -- Word-wrap a string to fit within maxWidth (strips color codes for measurement)
    local function wrapText(text, maxWidth)
        local words = {}
        for word in text:gmatch("%S+") do
            table.insert(words, word)
        end

        local lines = {}
        local currentLine = ""

        for _, word in ipairs(words) do
            local candidate = currentLine ~= "" and (currentLine .. " " .. word) or word
            local visibleLen = candidate:gsub("%^%d", ""):len()
            if maxWidth >= visibleLen then
                currentLine = candidate
            else
                if currentLine ~= "" then
                    table.insert(lines, currentLine)
                end
                currentLine = word
            end
        end

        if currentLine ~= "" then
            table.insert(lines, currentLine)
        end

        return lines
    end

    Citizen.Wait(5000)

    print("^6[CHECKING UPDATES]^0 ^7" .. resourceName .. "^0")

    local url = "https://raw.githubusercontent.com/TheRealBablo/version/master/" .. resourceName .. ".json"

    PerformHttpRequest(url, function(statusCode, body, headers)
        if not body then
            print("^1Unable to check version.^0")
            return
        end

        local decoded = json.decode(body:sub(1, -2))
        if not decoded or not decoded.version then
            print("^1Invalid version data received.^0")
            return
        end

        local remoteNum = toNumber(decoded.version:gsub("%.", ""))
        local localNum  = toNumber(currentVersion:gsub("%.", ""))

        if remoteNum > localNum then
            local separator = "^3" .. string.rep("-", 50) .. "^0"
            print("")
            print("^1[UPDATE AVAILABLE]^0 ^7" .. resourceName .. "^0")
            print(separator)
            print("^7Current Version: ^5" .. currentVersion .. "^0")
            print("^7New Version:     ^2" .. decoded.version .. "^0")
            print("")
            print("^6Patch Notes:^0")

            if decoded.descriptions and #decoded.descriptions > 0 then
                for _, description in ipairs(decoded.descriptions) do
                    local wrapped = wrapText(description, 75)
                    for i, line in ipairs(wrapped) do
                        if i == 1 then
                            print("^6  \226\128\162 ^5" .. line .. "^0")
                        else
                            print("^5    " .. line .. "^0")
                        end
                    end
                end
            else
                print("^6  \226\128\162 ^5No patch notes available^0")
            end

            print("")
            print("^4Download: ^7portal.cfx.re/assets/granted-assets^0")
            print(separator)
            print("")
        else
            print("")
            print("^2[UP TO DATE]^0 ^7" .. resourceName .. " - Version " .. currentVersion .. "^0")
            print("")
        end
    end, "GET")
end)
