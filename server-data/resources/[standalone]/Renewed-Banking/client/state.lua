RenewedBanking = RenewedBanking or {}
local RB = RenewedBanking

RB.Client = RB.Client or {}
RB.Client.state = {
    open = false,
    context = nil,
    initialized = false,
    atm = false
}

-- Key hints in my-hud's bar for keys our own UI does not already show; nil hides them.
-- Does nothing when my-hud is not running. (The bank page has its own hint bar, so it
-- sends none; only the ATM screen uses this.)
function RB.Client.hudPrompts(items)
    if GetResourceState('my-hud') ~= 'started' then return end
    pcall(function()
        if items then exports['my-hud']:ShowPrompts(items) else exports['my-hud']:HidePrompts() end
    end)
end

function RB.Client.setFocus(value)
    RB.Client.state.open = value == true
    SetNuiFocus(RB.Client.state.open, RB.Client.state.open)
    SetNuiFocusKeepInput(false)
end

function RB.Client.close()
    RB.Client.setFocus(false)
    RB.Client.state.context = nil
    SendNUIMessage({ type = 'renewedBanking:close' })
    if RB.Client.atm then RB.Client.atm.stop() end
end
