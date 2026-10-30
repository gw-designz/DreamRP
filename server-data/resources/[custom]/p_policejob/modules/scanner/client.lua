while true do
    if Config and Config.Scanner then break end
    Citizen.Wait(50)
end

if not Config.Scanner.enabled then return end

Scanner = {}
Scanner.busy    = false
Scanner.pending = nil  -- { targetId, targetPed }

-- ============================================================
--  Access check
-- ============================================================

local function hasJobAccess()
    local job = Bridge.Framework.fetchPlayerJob()
    return job and Config.Jobs[job.name] or false
end

-- ============================================================
--  Mugshot capture (requires MugShotBase64 resource)
-- ============================================================

local function captureMugshot(targetPed)
    if not Config.Scanner.showMugshot then return nil end
    if not targetPed or targetPed == 0 then return nil end
    if not DoesEntityExist(targetPed) then return nil end

    if GetResourceState("MugShotBase64") ~= "started" then
        lib.print.error("MugShotBase64 resource is not started - the scanner cannot take a headshot of the target ped")
        return nil
    end

    local ok, result = pcall(function()
        return exports.MugShotBase64:GetMugShotBase64(targetPed, true)
    end)

    if ok and type(result) == "string" and result ~= "" then
        return result
    end
    return nil
end

-- ============================================================
--  Open / Close
-- ============================================================

function Scanner.close(self)
    self.pending = nil
    SendNUIMessage({ action = "setVisibleScanner", data = false })
    SetNuiFocus(false, false)
end

function Scanner.open(self, targetServerId, targetPed)
    if self.busy then return end
    if not hasJobAccess() then return end

    targetServerId = tonumber(targetServerId)
    if not targetServerId or targetServerId == 0 then return end

    -- Resolve ped if not provided or invalid
    if not targetPed or targetPed == 0 or not DoesEntityExist(targetPed) then
        targetPed = GetPlayerPed(GetPlayerFromServerId(targetServerId))
    end
    if not targetPed or targetPed == 0 then return end

    -- Item check
    if Config.Scanner.requireItem then
        if Bridge.Inventory.getItemCount(Config.Scanner.item) < 1 then
            return Bridge.Notify.showNotify(locale("scanner_no_device"), "error")
        end
    end

    self.pending = { targetId = targetServerId, targetPed = targetPed }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "setVisibleScanner", data = true })
    SendNUIMessage({ action = "setScannerData", data = { status = "idle" } })
end

-- ============================================================
--  Run scan (triggered by NUI "start" button)
-- ============================================================

function Scanner.runScan(self)
    if self.busy then return end

    local pending = self.pending
    if not pending then
        SendNUIMessage({ action = "setScannerData", data = { status = "idle" } })
        return
    end

    self.busy = true

    local targetServerId = pending.targetId
    local targetPed      = pending.targetPed

    -- Re-resolve ped if stale
    if not targetPed or targetPed == 0 or not DoesEntityExist(targetPed) then
        targetPed = GetPlayerPed(GetPlayerFromServerId(targetServerId))
    end

    local gender = IsPedMale(targetPed) and "male" or "female"

    SendNUIMessage({ action = "setScannerData", data = { status = "scanning" } })

    -- Optional scan animation
    local scanAnim = Config.Scanner.scanAnim
    if scanAnim and scanAnim.dict then
        lib.requestAnimDict(scanAnim.dict)
        TaskPlayAnim(cache.ped, scanAnim.dict, scanAnim.clip,
            8.0, -8.0, Config.Scanner.scanDuration,
            scanAnim.flag or 1, 0, false, false, false)
    end

    Wait(Config.Scanner.scanDuration)

    if scanAnim and scanAnim.dict then
        ClearPedTasks(cache.ped)
        RemoveAnimDict(scanAnim.dict)
    end

    -- Server-side identity lookup
    local result = lib.callback.await("p_policejob/scanner/identify", false, targetServerId)

    if not result then
        SendNUIMessage({ action = "setScannerData", data = { status = "not_found" } })
        self.busy = false
        return
    end

    -- Try to get a live mugshot; fall back to server record
    local mugshot = captureMugshot(targetPed) or result.mugshot

    SendNUIMessage({ action = "setScannerData", data = {
        status    = "complete",
        firstName = result.firstName,
        lastName  = result.lastName,
        gender    = gender,
        mugshot   = mugshot,
    }})

    self.busy = false
end

-- ============================================================
--  Events / callbacks / exports
-- ============================================================

AddEventHandler("p_policejob/scanner/scan", function(targetServerId, targetPed)
    Scanner:open(targetServerId, targetPed)
end)

RegisterNUICallback("scanner/start", function(_, cb)
    cb("ok")
    CreateThread(function() Scanner:runScan() end)
end)

AddEventHandler("p_policejob:client:hideFrame", function(data)
    local name = data and data.name or nil
    if name == "setVisibleScanner" then
        Scanner:close()
    end
end)

exports("scanFingerprint", function(targetServerId)
    Scanner:open(targetServerId)
end)
