Utils = {}

-- ============================================================
--  Screen fade helpers
-- ============================================================

-- Fades the screen out and waits until fully faded. duration defaults to 1000ms.
function Utils.fadeOutScreen(self, duration)
    duration = duration or 1000
    DoScreenFadeOut(duration)
    while not IsScreenFadedOut() do Wait(0) end
end

-- Fades the screen in and waits until fully visible. duration defaults to 1000ms.
function Utils.fadeInScreen(self, duration)
    duration = duration or 1000
    DoScreenFadeIn(duration)
    while not IsScreenFadedIn() do Wait(0) end
end

-- ============================================================
--  NUI callbacks
-- ============================================================

-- Returns all localisation strings to the NUI.
RegisterNUICallback("getLocales", function(_, cb)
    cb(lib.getLocales())
end)

-- Called by NUI when a frame should be hidden.
-- Fires a local event so any module can react.
RegisterNUICallback("hideFrame", function(data, cb)
    cb("ok")
    TriggerEvent("p_policejob:client:hideFrame", data)
end)
