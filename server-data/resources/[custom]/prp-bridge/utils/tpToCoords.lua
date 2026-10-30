---@param time number
local function FadeOutScreen(time)
    DoScreenFadeOut(time)
    while not IsScreenFadedOut() do
        Wait(0)
    end
    Wait(0)
end

---@param time number
local function FadeInScreen(time)
    DoScreenFadeIn(time)
    while not IsScreenFadedIn() do
        Wait(0)
    end
    Wait(0)
end

---@param coords vector3 | vector4
---@param fadeInOut boolean | nil
local function TpToCoords(coords, fadeInOut)
    local playerPed = cache.ped

    if fadeInOut ~= nil and type(fadeInOut) == "number" then
        FadeOutScreen(500)
        Wait(50)
    end

    if type(coords) == "vector3" then
        coords = vec4(coords.x, coords.y, coords.z, 0.0)
    end

    ClearPedTasksImmediately(playerPed)
    FreezeEntityPosition(playerPed, true)
    NetworkFadeOutEntity(playerPed, true, false)

    SetEntityCoords(playerPed, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(playerPed, coords.w)

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    NewLoadSceneStart(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 50.0, 0)
    local gameTimer = GetGameTimer()
    while not IsNewLoadSceneLoaded() and (GetGameTimer() - gameTimer < 2000) do
        Wait(0)
    end
    NewLoadSceneStop()

    SetEntityCoords(playerPed, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(playerPed, coords.w)
    gameTimer = GetGameTimer()
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    while not HasCollisionLoadedAroundEntity(playerPed) and GetGameTimer() - gameTimer < 2000 do
        Wait(0)
    end

    FreezeEntityPosition(playerPed, false)
    NetworkFadeInEntity(playerPed, true)

    SetGameplayCamRelativePitch(0.0, 1.0)

    if fadeInOut ~= nil and type(fadeInOut) == "number" then
        Wait(1000)
        FadeInScreen(fadeInOut)
    end
end
exports('TpToCoords', TpToCoords)