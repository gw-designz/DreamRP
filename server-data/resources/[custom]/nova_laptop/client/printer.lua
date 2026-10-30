--[[
    The newsroom printers: the ones staff set down (prop_printer_01) and the
    fixed office printers in Config.News.Printing.Printers. Walking up to one
    shows a single Interact (interact), which opens the radial menu
    (codera-radialmenu):

      Open Printer       the output tray: the ox_inventory stash copies come out into
      Make Copy(s)       pick an issue and how many (ox_lib dialog)
      Deposit Paper      the paper tray: put paper in, one sheet per copy
      Pick Up Printer    its owner only

    The server checks every one of these (server/news.lua).
]]

local MODEL = GetHashKey(Config.News.Printing.Prop)

local function notify(text)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, false)
end

--- Only server-made printers carry an owner; asking a local entity is an error.
local function placedPrinter(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity) and NetworkGetEntityIsNetworked(entity)
        and Entity(entity).state.novaPrinter ~= nil
end

local function mine(entity)
    return placedPrinter(entity) and Entity(entity).state.novaPrinter == GetPlayerServerId(PlayerId())
end

RegisterNetEvent('nova_laptop:client:openStash', function(id)
    exports.ox_inventory:openInventory('stash', id)
end)

-- The Make copies dialog asks the server what there is to print first.
local waiting = nil
RegisterNetEvent('nova_laptop:client:printerInfo', function(found, issues, paper, maxCopies)
    if waiting then waiting:resolve({ found = found, issues = issues, paper = paper, maxCopies = maxCopies }) waiting = nil end
end)

local function makeCopies(target)
    waiting = promise.new()
    local p = waiting
    TriggerServerEvent('nova_laptop:server:printerInfo', target)
    SetTimeout(5000, function() if waiting == p then waiting = nil p:resolve(nil) end end)
    local info = Citizen.Await(p)
    if not info then return notify('The printer did not answer.') end
    if not info.found then return notify('Stand by the printer first.') end
    if #info.issues == 0 then return notify('Nothing has been published yet. Publish an issue in the Magazine Editor.') end
    local options = {}
    for i, issue in ipairs(info.issues) do options[i] = { value = issue.id, label = issue.label } end
    local max = info.maxCopies or 10
    if info.paper then max = math.min(max, info.paper) end
    if max < 1 then return notify('The printer is out of paper. Load paper first.') end
    local input = lib.inputDialog('Make copies', {
        { type = 'select', label = 'Issue', options = options, default = options[1].value, required = true },
        { type = 'number', label = 'Copies', description = info.paper and ('%d sheet%s of paper loaded'):format(info.paper, info.paper == 1 and '' or 's') or nil,
            default = 1, min = 1, max = max, required = true },
    })
    if input then TriggerServerEvent('nova_laptop:server:printerCopies', target, input[1], input[2]) end
end

--- The printer's menu: our radial wheel (client/radial.lua), drawn like
--- codera-radialmenu's.
local function openMenu(target, owner)
    local items = {
        { id = 'tray', title = 'Open Printer', icon = 'printer' },
        { id = 'copies', title = 'Make Copy(s)', icon = 'copy' },
        { id = 'paper', title = 'Deposit Paper', icon = 'filedown' },
    }
    if owner then items[#items + 1] = { id = 'pickup', title = 'Pick Up Printer', icon = 'hand' } end
    LaptopRadial.open(items, function(option)
        TriggerEvent('nova_laptop:client:printerOption', { option = option, target = target })
    end)
end

-- A choice from the printer's menu.
AddEventHandler('nova_laptop:client:printerOption', function(choice)
    if type(choice) ~= 'table' then return end
    local target = choice.target
    if choice.option == 'tray' then
        TriggerServerEvent('nova_laptop:server:printerTray', target, 'tray')
    elseif choice.option == 'paper' then
        TriggerServerEvent('nova_laptop:server:printerTray', target, 'paper')
    elseif choice.option == 'copies' then
        CreateThread(function() makeCopies(target) end)
    elseif choice.option == 'pickup' then
        TriggerServerEvent('nova_laptop:server:pickUp', 'printer')
    end
end)

CreateThread(function()
    if GetResourceState('interact') ~= 'started' then return end

    -- Printers staff set down: one Interact point on each.
    exports.interact:AddModelInteraction({
        modelData = { { model = Config.News.Printing.Prop, offset = vec3(0.0, 0.0, 0.35) } },
        distance = Config.Placement.UseDistance + 2.0,
        interactDst = Config.Placement.UseDistance,
        options = {
            { name = 'nova_printer:interact', label = 'Interact', canInteract = placedPrinter,
                action = function(entity) openMenu(NetworkGetNetworkIdFromEntity(entity), mine(entity)) end },
        },
    })

    -- The fixed office printers.
    for i, spot in ipairs(Config.News.Printing.Printers or {}) do
        exports.interact:AddInteraction({
            coords = spot,
            distance = 4.0,
            interactDst = 1.5,
            name = 'nova_printer_office_' .. i,
            options = {
                { name = 'nova_printer:interact', label = 'Interact', action = function() openMenu('office:' .. i, false) end },
            },
        })
    end
end)
