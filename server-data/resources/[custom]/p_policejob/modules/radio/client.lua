if not Config.RadioList.Enabled then return end

-- File-level state
local currentChannel  = 0          -- active radio channel (0 = disconnected)
local channelUsers    = {}         -- array of user entries on current channel
local currentFreqLabel = ""        -- formatted frequency + channel name
local isVisible       = false      -- is the radio list NUI visible
local isEditMode      = false      -- is the move/edit overlay open
local keyCooldown     = GetGameTimer()
local currentAnim     = nil        -- selected radio animation definition

local restrictedJobs  = Config.RadioList.RestrictedJobs  -- nil = unrestricted

-- ============================================================
--  Access check
-- ============================================================

local function hasJobAccess()
    if not restrictedJobs then return true end
    local job = Bridge.Framework.fetchPlayerJob()
    if not job then return false end
    local minGrade = restrictedJobs[job.name]
    if not minGrade then return false end
    return (job.grade or 0) >= minGrade
end

-- ============================================================
--  Helpers
-- ============================================================

-- Returns a formatted frequency label, appending the channel name if configured.
local function formatFrequency(channel)
    local name = Config.RadioList.ChannelNames[tostring(channel)]
    if name then return ("%s - %s"):format(channel, name) end
    return tostring(channel)
end

-- Normalises a raw user list from the server into display-ready entries.
local function normaliseUsers(rawUsers)
    local result = {}
    for i, u in ipairs(rawUsers) do
        result[i] = {
            id        = u.player,
            name      = u.name,
            badge     = u.badge,
            isTalking = u.talking  or false,
            isDead    = u.isDead   or false,
        }
    end
    return result
end

-- ============================================================
--  NUI push
-- ============================================================

local function pushRadioData()
    SendNUIMessage({ action = "setRadioData", data = {
        frequency = currentFreqLabel,
        users     = channelUsers,
    }})
end

-- Controls NUI visibility (without toggling edit mode).
local function setVisible(visible)
    if isVisible == visible then return end
    isVisible = visible
    SendNUIMessage({ action = "setVisibleRadioList", data = visible })
end

-- ============================================================
--  Edit / move overlay
-- ============================================================

local function setEditMode(enabled)
    isEditMode = enabled

    if enabled then
        SetNuiFocus(true, true)
        SendNUIMessage({ action = "setVisibleRadioList", data = true })

        if currentChannel == 0 then
            -- Show a preview with dummy data so the user can see where to drag
            SendNUIMessage({ action = "setRadioData", data = {
                frequency = formatFrequency(1),
                users     = {
                    { id = 1, name = "John Smith",   badge = "1247", isTalking = true,  isDead = false },
                    { id = 2, name = "Jane Doe",     badge = "3892", isTalking = false, isDead = false },
                    { id = 3, name = "Mike Johnson", badge = nil,    isTalking = false, isDead = true  },
                },
            }})
        else
            pushRadioData()
        end
        SendNUIMessage({ action = "setRadioListEdit", data = true })
    else
        SendNUIMessage({ action = "setRadioListEdit", data = false })
        SetNuiFocus(false, false)

        if currentChannel ~= 0 and isVisible then
            pushRadioData()
        elseif currentChannel == 0 then
            SendNUIMessage({ action = "setVisibleRadioList", data = false })
        end
    end
end

-- ============================================================
--  Keybinds
-- ============================================================

-- Toggle visibility keybind
if Config.RadioList.ToggleKey then
    lib.addKeybind({
        name        = "toggle_radio_list",
        description = locale("toggle_radio_list"),
        defaultKey  = Config.RadioList.ToggleKey,
        onPressed   = function()
            if keyCooldown > GetGameTimer() then return end
            if currentChannel == 0 then return end
            keyCooldown = GetGameTimer() + 100
            setVisible(not isVisible)
        end,
    })
end

-- Page navigation keybinds
CreateThread(function()
    for direction, key in pairs(Config.RadioList.ChangePageKeys) do
        lib.addKeybind({
            name        = "change_radio_page_" .. direction,
            description = locale("change_radio_page"),
            defaultKey  = key,
            onPressed   = function()
                if keyCooldown > GetGameTimer() then return end
                if currentChannel == 0 or not isVisible then return end
                if not hasJobAccess() then return end
                keyCooldown = GetGameTimer() + 100
                SendNUIMessage({ action = "changeRadioPage", data = {
                    page = (direction == "left") and -1 or 1,
                }})
            end,
        })
    end
end)

-- Move/edit command toggle
if Config.RadioList.MoveCommand then
    RegisterCommand(Config.RadioList.MoveCommand, function()
        setEditMode(not isEditMode)
    end, false)
end

-- ============================================================
--  Net events
-- ============================================================

-- Called when the player connects to or disconnects from a channel.
RegisterNetEvent("p_policejob/client_radio/connectedChannel", function(channel)
    if not hasJobAccess() then return end
    currentChannel = channel
    currentFreqLabel = formatFrequency(channel)

    if channel == 0 then
        channelUsers = {}
        setVisible(false)
    else
        setVisible(true)
        pushRadioData()
    end
end)

-- Called when the channel user list changes (someone joins/leaves/talks).
RegisterNetEvent("p_policejob/client_radio/refreshRadioChannels", function(channel, rawUsers)
    if not hasJobAccess() then return end
    if currentChannel ~= channel then return end

    currentFreqLabel = formatFrequency(channel)
    channelUsers     = normaliseUsers(rawUsers)
    pushRadioData()
end)

-- Called when a player on the same channel changes dead status.
RegisterNetEvent("p_policejob/client_radio/playerDead", function(channel, serverId, isDead)
    if not hasJobAccess() then return end
    if currentChannel ~= channel then return end

    for _, user in ipairs(channelUsers) do
        if user.id == serverId then
            user.isDead = isDead
            break
        end
    end
    pushRadioData()
end)

-- ============================================================
--  radioTalking state bag — update isTalking in the user list
-- ============================================================

AddStateBagChangeHandler("radioTalking", nil, function(bagName, _, newValue)
    if currentChannel == 0 then return end

    -- Extract server ID from "player:N" bag name
    local serverId = tonumber(bagName:match("^player:(%d+)$"))
    if not serverId then return end

    local isTalking = newValue and true or false
    for _, user in ipairs(channelUsers) do
        if user.id == serverId then
            if user.isTalking ~= isTalking then
                user.isTalking = isTalking
                pushRadioData()
            end
            break
        end
    end
end)

-- ============================================================
--  Global event — hide frame
-- ============================================================

AddEventHandler("p_policejob:client:hideFrame", function(data)
    if data and data.name == "setVisibleRadioList" then
        if isEditMode then setEditMode(false) end
    end
end)

-- ============================================================
--  Radio animation (playing when transmitting)
-- ============================================================

-- Plays or stops the radio animation + optional prop based on `active` bool.
local function applyRadioAnim(active)
    CreateThread(function()
        if not currentAnim then return end

        if active then
            local animDict = lib.requestAnimDict(currentAnim.animDict)
            TaskPlayAnim(cache.ped, animDict, currentAnim.animClip,
                2.0, -2.0, -1, currentAnim.animFlag, 1)

            if currentAnim.prop then
                local propCfg = currentAnim.prop
                local model   = lib.requestModel(propCfg.model)
                local prop    = CreateObject(model, GetEntityCoords(cache.ped), true, true, true)
                currentAnim.createdProp = prop

                local boneIndex = GetPedBoneIndex(cache.ped, propCfg.bone)
                AttachEntityToEntity(
                    prop, cache.ped, boneIndex,
                    vector3(propCfg.coords.x, propCfg.coords.y, propCfg.coords.z),
                    vector3(propCfg.rotation.x, propCfg.rotation.y, propCfg.rotation.z),
                    true, true, false, false, 1, true)
                SetEntityAsMissionEntity(prop, true, true)
            end
        else
            if currentAnim.createdProp then
                DeleteEntity(currentAnim.createdProp)
                currentAnim.createdProp = nil
            end
            StopAnimTask(cache.ped, currentAnim.animDict, currentAnim.animClip, -2.0)
        end
    end)
end

-- pma-voice fires this when the local player starts/stops transmitting on radio.
AddEventHandler("pma-voice:radioActive", function(isActive)
    LocalPlayer.state:set("radioTalking", isActive and true or false, true)
    applyRadioAnim(isActive)
end)

-- ============================================================
--  Load saved animation preference (or pick default)
-- ============================================================

CreateThread(function()
    Wait(1000)
    local saved = GetResourceKvpString("radio_anim")
    if saved then
        currentAnim = json.decode(saved)
    else
        for _, animDef in pairs(Config.RadioAnimations) do
            if animDef.isDefault then
                currentAnim = animDef
                break
            end
        end
    end
end)

-- ============================================================
--  Animation picker menu
-- ============================================================

local function openRadioAnimMenu()
    local options = {}
    for _, animDef in pairs(Config.RadioAnimations) do
        local def = animDef
        options[#options + 1] = {
            title       = def.label,
            description = locale("set_radio_anim", def.label),
            arrow       = true,
            onSelect    = function()
                currentAnim = def
                Bridge.Notify.showNotify(locale("radio_anim_selected", def.label), "success")
                SetResourceKvp("radio_anim", json.encode(def))
            end,
        }
    end

    lib.registerContext({
        id      = "radio_anim_menu",
        title   = locale("radio_anim_menu"),
        options = options,
    })
    lib.showContext("radio_anim_menu")
end

RegisterCommand("radioanim", openRadioAnimMenu)
AddEventHandler("p_policejob/client/radio/openAnimMenu", openRadioAnimMenu)
exports("OpenRadioAnimMenu", openRadioAnimMenu)
