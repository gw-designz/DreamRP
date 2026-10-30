--[[
    The radial menu (web/src/Radial.tsx), drawn like codera-radialmenu, for
    menus of our own such as the printer's. Opened while the laptop is closed;
    the NUI page has the mouse until an item is picked or it is closed.
]]

LaptopRadial = {}

local pending = nil

--- Shows the wheel with items { id, title, icon } and calls onSelect(id)
--- with the one picked. Returns false when a wheel is already open.
function LaptopRadial.open(items, onSelect)
    if pending then return false end
    pending = onSelect
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'radial', items = items })
    return true
end

local function finish()
    local done = pending
    pending = nil
    SetNuiFocus(false, false)
    return done
end

RegisterNUICallback('radialSelect', function(data, cb)
    cb({ ok = true })
    local done = finish()
    if done and type(data) == 'table' and type(data.id) == 'string' then done(data.id) end
end)

RegisterNUICallback('radialClose', function(_, cb)
    cb({ ok = true })
    finish()
end)
