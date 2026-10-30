
local QBCore = exports['qb-core']:GetCoreObject()

RegisterCommand(Config.MenuCommand, function()
    QBCore.Functions.TriggerCallback('Codera-dispatch:getDispatchs', function(cb)
        QBCore.Functions.TriggerCallback('Codera-dispatch:getMyUnit', function(cba)
            SendNUIMessage({
                action="openMenu",
                data = cb,
                unit = cba,
                myjob = QBCore.Functions.GetPlayerData().job.name
            })
            SetNuiFocus(true, true)
        end)
    end)
end)

RegisterKeyMapping(Config.MenuCommand, 'Open Dispatch Menu', 'keyboard', Config.MenuKey)

RegisterNUICallback('getPlayers', function(data,cab)
    QBCore.Functions.TriggerCallback('Codera-dispatch:getJobPlayers', function(cb)
        cab(cb)
    end)
end)

RegisterNUICallback('getUnits', function(data,cab)
    QBCore.Functions.TriggerCallback('Codera-dispatch:getUnits', function(cb)
        cab(cb)
    end)
end)

RegisterNUICallback('canAddtoUnit', function(data,cab)
    QBCore.Functions.TriggerCallback('Codera-dispatch:canAddtoUnit', function(cb)
        cab(cb)
    end, data.id)
end)

RegisterNUICallback('createUnit', function(data,cab)
    QBCore.Functions.TriggerCallback('Codera-dispatch:createUnit', function(cb)
        cab(cb)
    end, data)
end)

RegisterNUICallback('leaveUnit', function(data,cab)
    QBCore.Functions.TriggerCallback('Codera-dispatch:leaveUnit', function(cb)
        cab(cb)
    end, data)
end)

RegisterNUICallback('deleteUnit', function(data,cab)
    QBCore.Functions.TriggerCallback('Codera-dispatch:deleteUnit', function(cb)
        cab(cb)
    end, data)
end)

RegisterNUICallback('closeMenu', function()
    SetNuiFocus(false, false)
end)

function sendDispatch(data)
    TriggerServerEvent('Codera-dispatch:addDispatch', data)
end

exports('sendDispatch', sendDispatch)

RegisterNetEvent('Codera-dispatch:client:dispatch', function(data)
    local PlayerData = QBCore.Functions.GetPlayerData()
    local canisee = false 
    for k,v in pairs(data.jobs) do 
        if v == PlayerData.job.name then 
            canisee = true 
            break 
        end
    end 
    if not canisee then 
        return 
    end 

    SendNUIMessage({
        action="addispatch",
        data = data
    })

    DispatchBlip(data)
end)

RegisterCommand('cd1', function()
    sendDispatch(
        {
            title = "Test Dispatch 1",
            code = "10-10B",
            values = {
                {
                    text = "codera dev",
                    icon = "fa-solid fa-earth-americas",
                },
                {
                    text = "Priority 1",
                    icon = "fa-solid fa-hashtag",
                },
            },
            valuestwo = {}, -- DON'T TOUCH
            jobs = {"police", "ambulance"},
            active = false,-- DON'T TOUCH
            dispatchnumber = nil,-- DON'T TOUCH
            coords = vector3(0,0,0),
            blip = {
                blipid = 80,
                blipcolor = 1,
            }
        }
    )
end)


RegisterCommand('cd1', function()
    sendDispatch(
        {
            title = "Test Dispatch 2",
            code = "10-10A",
            values = {
                {
                    text = "codera dev",
                    icon = "fa-solid fa-earth-americas",
                },
                {
                    text = "Priority 1",
                    icon = "fa-solid fa-hashtag",
                },
            },
            jobs = {"police", "ambulance"},
            coords = vector3(-2011.78,4514.13,28.62),
            blip = {
                blipid = 80,
                blipcolor = 1,
            },
            active = false,-- DON'T TOUCH
            dispatchnumber = nil,-- DON'T TOUCH
            date = nil, -- DONT TOUCH
            valuestwo = {}, -- DON'T TOUCH
        }
    )
end)

RegisterNUICallback('setActive', function(data,cb)
    TriggerServerEvent('Codera-dispatch:setActive', data.id)
    ExecuteCommand(Config.MenuCommand)
    cb(true)
end)

RegisterNUICallback('setLocation', function(data,cb)
    QBCore.Functions.TriggerCallback('Codera-dispatch:getLocation', function(cb)
        SetNewWaypoint(cb.x, cb.y)
        cb(true)
    end, data.id)
end)

