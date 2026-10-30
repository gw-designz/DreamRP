-- https://docs.teamsgg.dev/paid-scripts/properties/configure#camera
-- ! DON'T TOUCH THIS IF YOU DON'T KNOW WHAT YOU'RE DOING ! READ THE DOCUMENTATION FIRST !
local settings = {
    apiUrl = "https://fmapi.net/api/v2/image",
    apiKeyConvar = "PROPERTIES_UPLOAD_TOKEN",
}

lib.callback.register('nolag_properties:server:getCameraStatus', function(source)
    if GetResourceState('screencapture') ~= 'started' then
        lib.print.error(
            'Camera functionality for nolag_properties is not available because screencapture is not started. You can download it from https://github.com/itschip/screencapture/releases')
        return false
    end

    if GetConvar(settings.apiKeyConvar, "none") == "none" then
        lib.print.error('Camera functionality for nolag_properties is not available because the API key is not set. Please set the API key using the following command: set ' ..
            settings.apiKeyConvar .. ' "your_api_key"')
        return false
    end

    return true
end)

if GetResourceState('screencapture') ~= 'started' then
    lib.print.error(
        'Camera functionality for nolag_properties is not available because screencapture is not started. You can download it from https://github.com/itschip/screencapture/releases')
    return
end

if GetConvar(settings.apiKeyConvar, "none") == "none" then
    lib.print.error('Camera functionality for nolag_properties is not available because the API key is not set. Please set the API key using the following command: set ' ..
        settings.apiKeyConvar .. ' "your_api_key"')
    return
end

local screencapture = exports.screencapture

lib.callback.register('nolag_properties:server:takePhoto', function(source)
    local image

    screencapture:remoteUpload(source, settings.apiUrl, {
        encoding = "webp",
        headers = {
            ["Authorization"] = GetConvar(settings.apiKeyConvar, "none")
        }
    }, function(responseData)
        image = responseData?.data?.url
    end, "blob")

    lib.waitFor(function()
        if image then return true end
    end, "Failed to take photo. Make sure you have setuped the API key correctly.", 10000)

    return image
end)
