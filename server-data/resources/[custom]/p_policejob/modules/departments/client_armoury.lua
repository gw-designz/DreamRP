-- Global Armoury object shared across the resource
Armoury = {}
Armoury.antiSpam        = GetGameTimer()
Armoury.currentArmouryId = nil

-- ─── Internal Helpers ────────────────────────────────────────────────────────

-- Returns the local player's current job, or nil
function GetLocalPlayerJob()
    if Bridge.Framework.fetchPlayerJob then
        return Bridge.Framework.fetchPlayerJob()
    end
    return nil
end

-- Enriches items with their inventory image if available
function EnrichItemImages(items)
    if type(items) ~= "table" then return items end

    for _, item in ipairs(items) do
        if Bridge.Inventory.getItemData then
            local itemData = Bridge.Inventory.getItemData(item.id)
            if itemData and itemData.image then
                item.image = itemData.image
            end
        end
    end

    return items
end

-- ─── Armoury Methods ─────────────────────────────────────────────────────────

-- Returns true if the local player's job and grade allow managing the armoury
function Armoury:canManage()
    local job = GetLocalPlayerJob()
    if not job then return false end
    if not Config.Jobs[job.name] then return false end

    local requiredGrade = (Config.Armoury and Config.Armoury.ManageGrade) or 0
    return job.grade >= requiredGrade
end

-- Opens the armoury NUI for the given armouryId (anti-spam protected)
function Armoury:open(armouryId)
    if GetGameTimer() <= self.antiSpam then return end
    self.antiSpam = GetGameTimer() + 2000

    if type(armouryId) ~= "string" then return end

    local result = lib.callback.await("p_policejob/server/armoury/getItems", false, armouryId)
    if not result then
        return Bridge.Notify.showNotify(locale("no_access"), "error")
    end

    self.currentArmouryId = armouryId
    SendNUIMessage({ action = "setVisibleArmoury",    data = true })
    SendNUIMessage({ action = "setArmouryCategories", data = result.categories or {} })
    SendNUIMessage({ action = "setArmouryItems",      data = EnrichItemImages(result.items) })
    SetNuiFocus(true, true)
end

-- Closes the armoury NUI
function Armoury:close()
    self.antiSpam        = GetGameTimer() + 2000
    self.currentArmouryId = nil
    SendNUIMessage({ action = "setVisibleArmoury", data = false })
    SetNuiFocus(false, false)
end

-- ─── Armoury Management Panel ────────────────────────────────────────────────

-- Returns a locale string, or the fallback when the key is missing from the locale file
local function L(key, fallback)
    local text = locale(key)
    if not text or text == key then return fallback end
    return text
end

-- UI strings for the management panel (overridable via locales/*.json)
local function GetManageLabels()
    return {
        title          = L("armoury_manage_title", "Armoury Management"),
        subtitle       = L("armoury_manage_subtitle", "Add, remove and price armoury items"),
        allItems       = L("armoury_manage_all_items", "All items"),
        addItem        = L("armoury_manage_add_item", "Add Item"),
        removeItem     = L("armoury_manage_remove_item", "Remove"),
        save           = L("armoury_manage_save", "Save changes"),
        discard        = L("armoury_manage_discard", "Discard changes"),
        unsaved        = L("armoury_manage_unsaved", "Unsaved changes"),
        search         = L("armoury_manage_search", "Search items..."),
        empty          = L("armoury_manage_empty", "No items in this category"),
        itemName       = L("armoury_manage_item_name", "Item name"),
        price          = L("armoury_manage_price", "Price"),
        category       = L("armoury_manage_category", "Category"),
        minGrade       = L("armoury_manage_min_grade", "Min. grade"),
        stock          = L("armoury_stock", "Stock"),
        licenses       = L("armoury_manage_licenses", "Required licenses (comma separated)"),
        limits         = L("armoury_set_limits", "Per-grade limits"),
        limitsHint     = L("armoury_manage_limits_hint", "Max purchases per restart. Empty = no limit"),
        grade          = L("armoury_manage_grade", "Grade %s"),
        newItem        = L("armoury_manage_new_item", "New item"),
        unknownItem    = L("armoury_manage_unknown_item", "Unknown item"),
        saved          = L("armoury_saved", "Saved"),
        saveFailed     = L("armoury_save_failed", "Failed to save"),
        errEmptyName   = L("armoury_manage_err_empty", "Every item needs a name"),
        errDuplicate   = L("armoury_manage_err_duplicate", "%s is listed more than once"),
        errUnknown     = L("armoury_manage_err_unknown", "%s is not a registered inventory item"),
        confirmClose   = L("armoury_manage_confirm_close", "You have unsaved changes. Close anyway?"),
    }
end

-- Fetches fresh manage data for the given armouryId from the server
local function FetchManageData(armouryId)
    return lib.callback.await("p_policejob/server/armoury/getManageData", false, armouryId)
end

-- Opens the management panel for the given armouryId after a server-side auth check
function Armoury:openManage(armouryId)
    if not armouryId then return end
    if GetGameTimer() <= self.antiSpam then return end
    self.antiSpam = GetGameTimer() + 1000

    local data = FetchManageData(armouryId)
    if not data then
        return Bridge.Notify.showNotify(locale("no_access"), "error")
    end

    self.managingArmouryId = armouryId
    data.labels = GetManageLabels()

    SendNUIMessage({ action = "setVisibleArmouryManage", data = data })
    SetNuiFocus(true, true)
end

-- Closes the management panel
function Armoury:closeManage()
    self.managingArmouryId = nil
    SendNUIMessage({ action = "setVisibleArmouryManage", data = false })
    SetNuiFocus(false, false)
end

-- NUI: save the edited item list
RegisterNUICallback("armoury/manage/save", function(payload, cb)
    local armouryId = Armoury.managingArmouryId
    if not (armouryId and type(payload) == "table" and type(payload.items) == "table") then
        return cb({ success = false })
    end

    local success, err = lib.callback.await("p_policejob/server/armoury/saveManage", false, armouryId, payload.items)

    Bridge.Notify.showNotify(
        success and locale("armoury_saved") or locale("armoury_save_failed"),
        success and "success" or "error"
    )

    local fresh = success and FetchManageData(armouryId) or nil
    if fresh then fresh.labels = GetManageLabels() end

    cb({ success = success, error = err, data = fresh })
end)

-- NUI: management panel closed
RegisterNUICallback("armoury/manage/close", function(_, cb)
    Armoury:closeManage()
    cb("ok")
end)

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────

-- NUI: player confirmed a purchase
RegisterNUICallback("armoury/purchase", function(payload, cb)
    if not (type(payload) == "table" and payload.account and payload.items) then
        return cb(false)
    end

    if not Armoury.currentArmouryId then return cb(false) end

    payload.armouryId = Armoury.currentArmouryId

    local success = lib.callback.await("p_policejob/server/armoury/purchase", false, payload)
    if success then
        local fresh = lib.callback.await("p_policejob/server/armoury/getItems", false, Armoury.currentArmouryId)
        if fresh then
            SendNUIMessage({ action = "setArmouryCategories", data = fresh.categories or {} })
            SendNUIMessage({ action = "setArmouryItems",      data = EnrichItemImages(fresh.items) })
        end
    end

    cb(success)
end)

-- ─── Event Handlers ──────────────────────────────────────────────────────────

-- Close armoury when the NUI frame signals it should hide
AddEventHandler("p_policejob:client:hideFrame", function(frameData)
    local frameName = frameData and frameData.name or nil
    if frameName == "setVisibleArmoury" then
        Armoury:close()
    end
end)
