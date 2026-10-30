while true do
    if Config and Config.Trash then break end
    Citizen.Wait(500)
end

if not Config.Trash.Enabled then return end

local Trash = {}

-- ============================================================
--  Access check
-- ============================================================

local function hasJobAccess()
    if not Config.Jobs then return true end
    local job = Bridge.Framework.fetchPlayerJob()
    if not job then return false end
    local minGrade = Config.Jobs[job.name]
    if minGrade == nil then return false end
    return minGrade <= (job.grade or 0)
end

-- ============================================================
--  Open a trash stash
-- ============================================================

function Trash.open(self, trashId)
    if not trashId or trashId == "" then return end

    if not hasJobAccess() then
        Bridge.Notify.showNotify(locale("trash_no_access"), "error")
        return
    end

    -- Sanitise and truncate
    trashId = tostring(trashId):sub(1, 64)

    TriggerServerEvent("p_policejob/server/trash/open", trashId)
    Citizen.Wait(100)

    Bridge.Inventory.openInventory("stash", {
        id = Config.Trash.StashPrefix .. "_" .. trashId,
    })
end

-- ============================================================
--  Clear a trash stash (with confirmation)
-- ============================================================

function Trash.clear(self, trashId)
    if not trashId or trashId == "" then return end

    if not hasJobAccess() then
        Bridge.Notify.showNotify(locale("trash_no_access"), "error")
        return
    end

    local confirmed = lib.alertDialog({
        header   = locale("trash_clear_title"),
        content  = locale("trash_clear_desc"),
        centered = true,
        cancel   = true,
    })
    if confirmed ~= "confirm" then return end

    TriggerServerEvent("p_policejob/server/trash/clear", tostring(trashId):sub(1, 64))
end

-- ============================================================
--  Exports
-- ============================================================

exports("openTrash",  function(trashId) Trash:open(trashId)  end)
exports("clearTrash", function(trashId) Trash:clear(trashId) end)
