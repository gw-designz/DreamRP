if not Config.Tickets.enabled then return end

Tickets = {}
Tickets.isOpen = false

-- ============================================================
--  Open / Close
-- ============================================================

function Tickets.open(self)
    if self.isOpen then return end

    local job = Bridge.Framework.fetchPlayerJob()
    if not (job and Config.Jobs[job.name]) then
        Bridge.Notify.showNotify(locale("not_on_duty"), "error")
        return
    end

    local records = lib.callback.await("p_policejob/server/tickets/getTickets", false)
    if not records then return end

    self.isOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({ action = "setTicketsConfig", data = {
        violations = Config.Tickets.violations,
        categories = Config.Tickets.categories,
    }})
    SendNUIMessage({ action = "setTicketsData", data = records })
    SendNUIMessage({ action = "setVisibleTrafficTickets", data = true })
end

function Tickets.close(self)
    if not self.isOpen then return end
    self.isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisibleTrafficTickets", data = false })
end

-- ============================================================
--  Exports + command
-- ============================================================

exports("openTickets",   function() Tickets:open() end)
exports("isTicketsOpen", function() return Tickets.isOpen end)

local cmd = Config.Tickets.command or "issueTicket"
RegisterCommand(cmd, function() Tickets:open() end, false)

-- ============================================================
--  Global event — hide frame
-- ============================================================

AddEventHandler("p_policejob:client:hideFrame", function(data)
    if data.name == "setVisibleTrafficTickets" then
        Tickets:close()
    end
end)

-- ============================================================
--  NUI callbacks
-- ============================================================

RegisterNUICallback("tickets/create", function(data, cb)
    if not Tickets.isOpen then return cb(nil) end
    local result = lib.callback.await("p_policejob/server/tickets/createTicket", false, data)
    cb(result)
end)

RegisterNUICallback("tickets/delete", function(data, cb)
    if not Tickets.isOpen then return cb(false) end
    local result = lib.callback.await("p_policejob/server/tickets/deleteTicket", false, data.ticketId)
    cb(result)
end)

RegisterNUICallback("tickets/markPaid", function(data, cb)
    if not Tickets.isOpen then return cb(false) end
    local result = lib.callback.await("p_policejob/server/tickets/markPaid", false, data.ticketId)
    cb(result)
end)

RegisterNUICallback("tickets/getNearbyPlayers", function(_, cb)
    if not Tickets.isOpen then return cb({}) end
    local result = lib.callback.await("p_policejob/server/tickets/getNearbyPlayers", false)
    cb(result or {})
end)

RegisterNUICallback("tickets/sendForSigning", function(data, cb)
    if not Tickets.isOpen then return cb(false) end

    local closestPlayer = lib.getClosestPlayer(GetEntityCoords(cache.ped),
        Config.Tickets.maxDistance, false)
    if not closestPlayer or closestPlayer == 0 then
        Bridge.Notify.showNotify(locale("ticket_no_nearby_player"), "error")
        return cb(false)
    end

    local result = lib.callback.await("p_policejob/server/tickets/sendForSigning", false, {
        ticketId = data.ticketId,
        targetId = GetPlayerServerId(closestPlayer),
    })
    cb(result)
end)

-- ============================================================
--  Sign request (shown to the suspect/target)
-- ============================================================

RegisterNetEvent("p_policejob/client/tickets/requestSign", function(data)
    if not (data and data.ticketId) then return end
    SendNUIMessage({ action = "setTicketSignRequest", data = data })
    SetNuiFocus(true, true)
end)

RegisterNUICallback("tickets/sign", function(data, cb)
    TriggerServerEvent("p_policejob/server/tickets/signTicket", {
        ticketId  = data.ticketId,
        signature = data.signature or nil,
    })
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNetEvent("p_policejob/client/tickets/onSigned", function(data)
    if not data then return end
    SendNUIMessage({ action = "ticketOnSigned", data = data })
end)

RegisterNUICallback("tickets/refuse", function(data, cb)
    TriggerServerEvent("p_policejob/server/tickets/refuseTicket", {
        ticketId = data.ticketId,
    })
    SetNuiFocus(false, false)
    cb("ok")
end)
