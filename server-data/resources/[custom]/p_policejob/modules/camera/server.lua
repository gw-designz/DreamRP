-- Wait for Config to be available
while true do
    if Config and Config.Camera then break end
    Citizen.Wait(500)
end

if not Config.Camera.Enabled then return end

-- ============================================================
--  Take photo — validate access, build metadata, add item
-- ============================================================

RegisterNetEvent("p_policejob/server/camera/TakePhoto", function(photoUrl)
    local playerSource = source
    local playerJob    = Bridge.Framework.getPlayerJob(playerSource)

    -- Grade-based access check (Config.Camera.CameraAccess[jobName] = minGrade)
    if Config.Camera.CameraAccess then
        local minGrade = Config.Camera.CameraAccess[playerJob.name]
        if minGrade and minGrade > playerJob.grade then
            return Bridge.Notify.showNotify(playerSource, locale("camera_item_no_access"), "error")
        end
    end

    local playerName       = Bridge.Framework.getPlayerName(playerSource)
    local playerIdentifier = Bridge.Framework.getUniqueId(playerSource)
    local timestamp        = os.time()

    local photoMetadata = {
        url               = photoUrl,
        playerName        = playerName,
        playerIdentifier  = playerIdentifier,
        jobName           = playerJob.name,
        jobGrade          = playerJob.grade,
        timestamp         = timestamp,
    }

    local description = locale(
        "camera_photo_description",
        playerName,
        playerJob.name,
        os.date("%Y-%m-%d %H:%M", timestamp)
    )

    Bridge.Inventory.addItem(playerSource, "photo", 1, photoMetadata, nil, description)
    Bridge.Notify.showNotify(playerSource, locale("photo_taken"), "success")
    Bridge.Debug(("[Camera] Player %s took a photo (url=%s)"):format(playerSource, tostring(photoUrl)))

    if Config.Webhooks and Config.Webhooks.camera then
        Bridge.Logs.Send(
            playerSource,
            "Camera",
            ("Photo taken by %s"):format(playerName),
            Config.Webhooks.camera
        )
    end
end)

-- ============================================================
--  Screenshot upload config — tells client how to upload
-- ============================================================

lib.callback.register("p_policejob/server/screenshot/uploadTarget", function()
    -- Validate ScreenshotConfig is usable
    if not ScreenshotConfig or not ScreenshotConfig.Url or ScreenshotConfig.Url == "" then
        return nil
    end

    if not ScreenshotConfig.ClientUpload then
        return { clientUpload = false }
    end

    -- Validate API key
    local apiKey = tostring(ScreenshotConfig.ApiKey or "")
    if apiKey == "" or apiKey:find("KEY_HERE") then
        print("^8[ERROR] MEDIA PROVIDER API KEY NOT SET - edit MediaProvider/ApiKey in config/server.lua^7")
        return nil
    end

    return {
        clientUpload = true,
        url          = ScreenshotConfig.Url,
        field        = ScreenshotConfig.Field    or "file",
        encoding     = ScreenshotConfig.Encoding or "jpg",
        quality      = ScreenshotConfig.Quality  or 0.85,
        headers      = { Authorization = ScreenshotConfig.ApiKey },
    }
end)

-- ============================================================
--  Resolve raw upload response → clean public URL
-- ============================================================

lib.callback.register("p_policejob/server/screenshot/resolveUrl", function(playerSource, rawResponse)
    if type(rawResponse) ~= "string" or rawResponse == "" then return nil end

    local resolvedUrl = ScreenshotConfig.GetUrl(rawResponse)

    if type(resolvedUrl) == "string" and resolvedUrl:match("^https://") then
        Bridge.Debug(("[Camera] Client uploaded screenshot for player %s -> %s"):format(playerSource, resolvedUrl))
        return resolvedUrl
    end

    Bridge.Debug(("[Camera] Client upload response could not be resolved to a URL: %s"):format(rawResponse:sub(1, 120)))
    return nil
end)

-- ============================================================
--  Server-side screenshot capture (via screenshot-basic export)
-- ============================================================

lib.callback.register("p_policejob/server/screenshotCapture", function(playerSource)
    -- Validate config
    if not ScreenshotConfig or not ScreenshotConfig.Url or ScreenshotConfig.Url == "" then
        print("^8[ERROR] SET SCREENSHOT UPLOAD URL IN ScreenshotConfig (config/server.lua)^7")
        return nil
    end

    local apiKey = tostring(ScreenshotConfig.ApiKey or "")
    if apiKey == "" or apiKey:find("KEY_HERE") then
        print("^8[ERROR] MEDIA PROVIDER API KEY NOT SET - edit MediaProvider/ApiKey in config/server.lua^7")
        return nil
    end

    local encoding = ScreenshotConfig.Encoding or "jpg"
    local quality  = ScreenshotConfig.Quality  or 0.85
    local p        = promise.new()

    exports["screenshot-basic"].requestClientScreenshot(
        playerSource,
        { encoding = encoding, quality = quality },
        function(err, rawData)
            if err then
                print("^8[ERROR] FAILED TO CAPTURE SCREENSHOT: " .. tostring(err) .. "^7")
                p:resolve(nil)
                return
            end

            if not rawData or rawData == "" then
                print("^8[ERROR] SCREENSHOT DATA EMPTY - is the `screenshot-basic` resource started before p_policejob?^7")
                p:resolve(nil)
                return
            end

            -- Strip data-URI prefix to get raw base64
            local base64Data = rawData:gsub("^data:image/[%w%+%-.]+;base64,", "")
            Bridge.Debug(("[Camera] Screenshot captured (%d base64 bytes)"):format(#base64Data))

            -- Build request body (custom builder or default JSON)
            local body, contentType
            if ScreenshotConfig.BuildRequest then
                body, contentType = ScreenshotConfig.BuildRequest(base64Data, encoding)
            else
                body        = json.encode({ base64 = base64Data })
                contentType = "application/json"
            end

            Bridge.Debug(("[Camera] Uploading %s (%d body bytes) to %s"):format(encoding, #body, tostring(ScreenshotConfig.Url)))

            PerformHttpRequest(
                ScreenshotConfig.Url,
                function(statusCode, responseBody)
                    if statusCode == 200 then
                        local resolvedUrl = ScreenshotConfig.GetUrl(responseBody)
                        Bridge.Debug(("[Camera] Screenshot uploaded for player %s -> %s"):format(playerSource, tostring(resolvedUrl)))
                        p:resolve(resolvedUrl)
                    else
                        print("^8[ERROR] SCREENSHOT UPLOAD FAILED (" .. statusCode .. "): " .. tostring(responseBody) .. "^7")
                        Bridge.Debug(("[Camera] Screenshot upload failed (status=%s)"):format(statusCode))
                        p:resolve(nil)
                    end
                end,
                "POST",
                body,
                {
                    ["Content-Type"] = contentType,
                    Authorization    = ScreenshotConfig.ApiKey,
                }
            )
        end
    )

    return Citizen.Await(p)
end)

-- ============================================================
--  Photo item use — show photo viewer to player
-- ============================================================

-- ⚠️ Generic item-use export — signature: (action, officerSource, itemData, slotSource, extra)
-- Only "usingItem" is handled here. Expand if other actions are needed.
exports("photo", function(action, officerSource, itemData, slotSource, extra)
    if action ~= "usingItem" then return end

    local slot = Bridge.Inventory.getItemSlot(itemData.id, slotSource)
    if slot and slot.metadata and slot.metadata.url then
        TriggerClientEvent("p_policejob/client/camera/ShowPhoto", itemData.id, slot.metadata.url)
    end
end)
