-- Wait for Config.Locker to be available
while not (Config and Config.Locker) do Citizen.Wait(500) end

if not Config.Locker.Enabled then return end

-- Global Locker object (module-scoped table)
local Locker = {}

-- ─── Internal Helpers ─────────────────────────────────────────────────────────

-- Returns true if the local player's job meets the locker access threshold
function PlayerHasLockerAccess()
    if not Config.Jobs then return true end

    local job = Bridge.Framework.fetchPlayerJob()
    if not job then return false end

    local threshold = Config.Jobs[job.name]
    if threshold == nil then return false end

    return threshold <= job.grade
end

-- ─── Locker Methods ───────────────────────────────────────────────────────────

-- Opens a specific locker stash by id.
-- Notifies the server (so it can register the stash), then opens the inventory.
function Locker.openById(_, lockerId)
    if not lockerId or lockerId == "" then return end

    if not PlayerHasLockerAccess() then
        return Bridge.Notify.showNotify(locale("locker_no_access"), "error")
    end

    local safeId = tostring(lockerId):sub(1, 64)

    TriggerServerEvent("p_policejob/server/locker/open", safeId)
    Citizen.Wait(100)

    Bridge.Inventory.openInventory("stash", {
        id = Config.Locker.StashPrefix .. "_" .. safeId,
    })
end

-- Prompts the player to type a locker id, then opens it
function Locker.openWithInput(self)
    if not PlayerHasLockerAccess() then
        return Bridge.Notify.showNotify(locale("locker_no_access"), "error")
    end

    local input = lib.inputDialog(locale("locker_input_title"), {
        { type = "input", label = locale("locker_input_label"), required = true },
    })

    if not (input and input[1]) then return end

    Locker.openById(self, input[1])
end

-- ─── Exports ─────────────────────────────────────────────────────────────────

exports("openLocker", function(lockerId)
    Locker.openById(Locker, lockerId)
end)

exports("openLockerWithInput", function()
    Locker.openWithInput(Locker)
end)
