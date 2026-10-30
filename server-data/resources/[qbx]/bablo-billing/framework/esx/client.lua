
if Config.Framework:lower() ~= 'esx' then
    return
end

local ESX = nil
local m = {}
local isReady = false

local function WaitForESX()
    if isReady then return true end
    
    local timeout = 0
    while not isReady and timeout < 30000 do
        Citizen.Wait(100)
        timeout = timeout + 100
    end
    
    return isReady
end

Citizen.CreateThread(function()
    while GetResourceState('es_extended') ~= 'started' do
        Citizen.Wait(100)
    end
    
    Citizen.Wait(500)
    
    local success, esxObj = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)

    if not success then
        Debug:error("Failed to get ESX object:", esxObj)
        return
    end
    
    ESX = esxObj
    isReady = true
    
    Debug:info("ESX Client Framework initialized successfully")
end)

Framework = m

m.Notify = function(message, type)
    if not WaitForESX() then return end
    
    if not message or type == nil then
        Debug:error("Invalid parameters for notify")
        return
    end

    ESX.ShowNotification(message, type)
end

m.GetPlayerData = function()
    if not WaitForESX() then return nil end
    
    local ok, data = pcall(function()
        return ESX.GetPlayerData()
    end)
    if not ok then
        return nil
    end
    return data
end
