Utils = {}

function Utils.ShowTextUI(text)
    if GetResourceState('ox_lib') == 'started' then
        lib.showTextUI(text)
    end
end

function Utils.HideTextUI()
    if GetResourceState('ox_lib') == 'started' then
        lib.hideTextUI()
    end
end

local PLAYER_DATA_EVENTS = {
    'esx:playerLoaded',
    'esx:setJob',
    'QBCore:Client:OnPlayerLoaded',
    'QBCore:Client:OnJobUpdate',
    'qbx_core:client:playerLoaded',
    'qbx_core:client:onJobUpdate',
}

function Utils.OnPlayerDataChanged(cb)
    for _, name in ipairs(PLAYER_DATA_EVENTS) do
        RegisterNetEvent(name, function() cb() end)
    end
end

function Utils.GetImageBase()
    if type(Config.ImageBase) == 'string' and Config.ImageBase ~= '' then
        return Config.ImageBase
    end

    if GetResourceState('ox_inventory') == 'started' then
        return 'nui://ox_inventory/web/images/';
    elseif GetResourceState('qb-inventory') == 'started' then
        return 'nui://qb-inventory/html/images/';
    elseif GetResourceState('tgiann-inventory') == 'started' then
        return 'nui://inventory_images/images/';
    end

    print('^3[df_crafting]^7 No known inventory found for item images. Set Config.ImageBase in configuration/config.lua.')
    return '';
end
