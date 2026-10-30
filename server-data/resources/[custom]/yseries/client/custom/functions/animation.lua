local animPrefix = 'cellphone_'
local strTypingDict = 'cellphone@str'
local playerPhones = {}
local playerState = LocalPlayer.state

---@type boolean True while a text field in the phone NUI has focus.
local inputTypingActive = false
---@type number Bumped to cancel an in-flight typing animation loop.
local typingLoopToken = 0
---@type integer Ms to reuse the last picked typing clip instead of randomizing again.
local TYPING_ANIM_REUSE_MS = 5000
--- Seconds to skip at the start of `cellphone@str` press clips (hand already out while typing).
local STR_TYPING_INTRO_SKIP_SEC = 0.20
--- Seconds to trim before clip end to avoid the hand dropping between alternated press clips.
local STR_TYPING_OUTRO_TRIM_SEC = 0.12
---@class PhoneTypingAnimClip
---@field dict string
---@field name string
---@field femaleOnly boolean|nil

---@type PhoneTypingAnimClip[]
local typingAnimPool = {
    { dict = strTypingDict,                                   name = 'cellphone_text_press_a' },
    { dict = strTypingDict,                                   name = 'cellphone_text_press_b' },
    { dict = 'amb@world_human_stand_mobile@male@text@base',   name = 'base' },
    { dict = 'amb@world_human_stand_mobile@male@text@idle_a', name = 'idle_a' },
    { dict = 'amb@world_human_stand_mobile@male@text@idle_a', name = 'idle_b' },
    { dict = 'amb@world_human_stand_mobile@male@text@idle_a', name = 'idle_c' },
    { dict = 'amb@world_human_stand_mobile@female@text@base', name = 'base',                  femaleOnly = true },
}
---@class PhoneTypingAnimState
---@field dict string|nil
---@field name string|nil
---@field pickedAt integer

---@type PhoneTypingAnimState
local lastTypingAnim = { dict = nil, name = nil, pickedAt = 0 }

-- Position adjustment variables
local phoneOffsetX = 0.0
local phoneOffsetY = 0.0
local phoneOffsetZ = 0.0
local phoneRotX = 0.0
local phoneRotY = 0.0

---@return boolean
local function isPayphoneBoothSessionActive()
    return LocalPlayer.state.payphoneCallActive == true
end

---@return boolean
local function isPhoneTypingAnimAllowed()
    if isPayphoneBoothSessionActive() then return false end

    if Config.BoomerPhoneAddon then
        local expExist, ysOpen = pcall(function() return exports['yboomer-phone']:IsOpen() end)
        if expExist and ysOpen then return false end
    end

    if not PhoneOpen then return false end
    if CameraActive then return false end

    local callData = PhoneData.CallData
    if callData?.InCall and callData?.AnsweredCall then return false end

    local currentAnim = PhoneData.AnimationData.anim
    if currentAnim and (currentAnim:find('selfie', 1, true) or currentAnim:find('call_', 1, true)) then
        return false
    end

    return true
end

---@param ped number
---@return boolean
local function isPedFemale(ped)
    return IsPedModel(ped, `mp_f_freemode_01`) or not IsPedMale(ped)
end

---@param ped number
---@return PhoneTypingAnimClip[]
local function getEligibleTypingAnims(ped)
    local female = isPedFemale(ped)
    local inVehicle = IsPedInAnyVehicle(ped, false)
    local eligible = {}

    for i = 1, #typingAnimPool do
        local clip = typingAnimPool[i]
        if clip.femaleOnly and not female then
            goto continue
        end
        if inVehicle and clip.dict:find('stand_mobile', 1, true) then
            goto continue
        end
        eligible[#eligible + 1] = clip
        ::continue::
    end

    return eligible
end

---@param ped number
---@return string dict
---@return string name
local function pickTypingAnim(ped)
    local now = GetGameTimer()

    if lastTypingAnim.dict and lastTypingAnim.name and (now - lastTypingAnim.pickedAt) < TYPING_ANIM_REUSE_MS then
        return lastTypingAnim.dict, lastTypingAnim.name
    end

    local eligible = getEligibleTypingAnims(ped)
    if #eligible == 0 then
        return strTypingDict, 'cellphone_text_press_a'
    end
    local clip = eligible[math.random(#eligible)]
    lastTypingAnim.dict = clip.dict
    lastTypingAnim.name = clip.name
    lastTypingAnim.pickedAt = now

    return clip.dict, clip.name
end

---@param name string
---@return string
local function getStrTypingAlternate(name)
    if name == 'cellphone_text_press_a' then
        return 'cellphone_text_press_b'
    end
    return 'cellphone_text_press_a'
end

---@param dict string
---@param name string
---@return number durationSec
local function getAnimDurationSec(dict, name)
    lib.requestAnimDict(dict)
    local duration = GetAnimDuration(dict, name)
    if not duration or duration <= 0.0 then
        return dict == strTypingDict and 1.07 or 1.5
    end
    return duration
end

--- Play a `cellphone@str` press clip starting past the intro so the hand stays at typing height.
---@param name string
---@return integer playMs How long to wait before playing the next alternated clip.
local function playStrTypingAnimClip(name)
    local ped = PlayerPedId()
    local totalSec = getAnimDurationSec(strTypingDict, name)
    local playMs = math.floor(math.max(0.35, totalSec - STR_TYPING_INTRO_SKIP_SEC - STR_TYPING_OUTRO_TRIM_SEC) * 1000)
    local coords = GetEntityCoords(ped)

    TaskPlayAnimAdvanced(
        ped,
        strTypingDict,
        name,
        coords.x, coords.y, coords.z,
        0.0, 0.0, GetEntityHeading(ped),
        8.0, 3.0,
        playMs,
        50,
        STR_TYPING_INTRO_SKIP_SEC,
        2, 0, false, false
    )

    PhoneData.AnimationData.lib = strTypingDict
    PhoneData.AnimationData.anim = name

    return playMs
end

---@param dict string
---@param name string
local function playAmbientTypingAnimClip(dict, name)
    local ped = PlayerPedId()
    lib.requestAnimDict(dict)
    lib.playAnim(ped, dict, name, 3.0, 3.0, -1, 50, 0, false, false, false)

    PhoneData.AnimationData.lib = dict
    PhoneData.AnimationData.anim = name
end

--- Run the typing animation loop until `StopTyping` cancels it.
---@param token number
---@param dict string
---@param name string
local function runTypingAnimationLoop(token, dict, name)
    CreateThread(function()
        local currentName = name
        local isStrClip = dict == strTypingDict

        while inputTypingActive and typingLoopToken == token do
            if not isPhoneTypingAnimAllowed() then
                Wait(250)
                goto continue
            end

            if isStrClip then
                Wait(playStrTypingAnimClip(currentName))
                currentName = getStrTypingAlternate(currentName)
            else
                local ped = PlayerPedId()
                if not IsEntityPlayingAnim(ped, dict, name, 3) then
                    playAmbientTypingAnimClip(dict, name)
                end
                Wait(200)
            end

            ::continue::
        end
    end)
end

---@return nil
local function startPhoneTypingAnimation()
    typingLoopToken += 1
    local dict, name = pickTypingAnim(PlayerPedId())
    runTypingAnimationLoop(typingLoopToken, dict, name)
end

---@return nil
local function stopPhoneTypingAnimation()
    typingLoopToken += 1
end

--- Restore the open-phone hold animation when the text field loses focus.
---@return nil
local function playPhoneBrowseAnimation()
    DoPhoneAnimation('cellphone_text_read_base')
end

Animation = {
    OpenPhone = function()
        if Config.BoomerPhoneAddon then
            local expExist, ysOpen = pcall(function() return exports['yboomer-phone']:IsOpen() end)
            if expExist and ysOpen then return end
        end

        inputTypingActive = false
        stopPhoneTypingAnimation()
        lastTypingAnim = { dict = nil, name = nil, pickedAt = 0 }
        PhoneModelSync()

        DoPhoneAnimation(animPrefix .. 'text_in')
    end,
    ClosePhone = function()
        CreateThread(function()
            if Config.BoomerPhoneAddon then
                local expExist, ybOpen, softOpen = pcall(function() return exports['yboomer-phone']:IsOpen() end)
                if expExist and ybOpen and not softOpen then
                    exports['yboomer-phone']:OpenPhoneAnimation()
                end
            end
        end)

        DoPhoneAnimation(animPrefix .. 'text_out')

        Animation.Reset(false, true)
    end,
    TextToCall = function()
        DoPhoneAnimation(animPrefix .. 'text_to_call')
    end,
    CallToText = function()
        DoPhoneAnimation(animPrefix .. 'call_to_text')
    end,
    PocketToCall = function()
        DoPhoneAnimation(animPrefix .. 'call_listen_base')
    end,
    CallToPocket = function()
        DoPhoneAnimation(animPrefix .. 'call_out')

        Animation.Reset()
    end,
    Selfie = function()
        DoPhoneAnimation('selfie', 'self')
    end,
    SelfieIn = function()
        DoPhoneAnimation('selfie_in', 'self')
    end,
    SelfieOut = function()
        DoPhoneAnimation('selfie_out', 'self')
    end,
    InCar = function()
        DoPhoneAnimation('cellphone_text_read_base')
    end,
    --- Start the looping typing animation when a phone NUI text field gains focus.
    ---@return nil
    StartTyping = function()
        if inputTypingActive then return end
        if not isPhoneTypingAnimAllowed() then return end

        inputTypingActive = true
        PhoneModelSync()
        startPhoneTypingAnimation()
    end,
    --- Stop the typing animation and restore the open-phone hold when the field blurs.
    ---@return nil
    StopTyping = function()
        if not inputTypingActive then return end

        inputTypingActive = false
        stopPhoneTypingAnimation()
        lastTypingAnim = { dict = nil, name = nil, pickedAt = 0 }

        if not isPhoneTypingAnimAllowed() then return end
        playPhoneBrowseAnimation()
    end,
    Reset = function(immediately, nocleartasks)
        inputTypingActive = false
        stopPhoneTypingAnimation()
        lastTypingAnim = { dict = nil, name = nil, pickedAt = 0 }

        SetTimeout(immediately and 0 or 500, function()
            StopAnimTask(PlayerPedId(), PhoneData.AnimationData.lib, PhoneData.AnimationData.anim, 2.5)

            if not nocleartasks then
                ClearPedTasks(PlayerPedId())
            end

            DeletePhone()
            PhoneData.AnimationData.lib = nil
            PhoneData.AnimationData.anim = nil
        end)
    end,
}

exports('OpenPhoneAnimation', Animation.OpenPhone)
exports('ClosePhoneAnimation', Animation.ClosePhone)

local function checkAnimationLoop()
    CreateThread(function()
        while PhoneData.AnimationData.lib ~= nil and PhoneData.AnimationData.anim ~= nil do
            if inputTypingActive then
                Wait(500)
            else
                local ped = PlayerPedId()
                if not IsEntityPlayingAnim(ped, PhoneData.AnimationData.lib, PhoneData.AnimationData.anim, 3) then
                    lib.playAnim(ped, PhoneData.AnimationData.lib, PhoneData.AnimationData.anim, 3.0, 3.0, -1, 50, 0, false, false, false)
                end
                Wait(1250)
            end
        end
    end)
end

local function isEntityAPhone(model)
    return
        model == `prop_y24-black`
        or model == `prop_yflip-gold`
        or model == `prop_yflip-mint`
        or model == `prop_y24-silver`
        or model == `prop_y24-violet`
        or model == `prop_y24-yellow`
        or model == `prop_yphone-blue`
        or model == `prop_yfold-black`
        or model == `prop_yphone-black`
        or model == `prop_yphone-white`
        or model == `prop_yflip-graphite`
        or model == `prop_yflip-lavender`
        or model == `prop_yphone-natural`
        or model == `prop_yfold-black-open`
        or model == `prop_yphone-fold-black`
        or model == `prop_yphone-fold-black-open`
end

local function createPhoneProp(ped, model)
    for _, v in pairs(GetGamePool('CObject')) do
        if IsEntityAttachedToEntity(ped, v) then
            local phoneModel = GetEntityModel(v)
            if isEntityAPhone(phoneModel) then
                SetEntityAsMissionEntity(v, false, false)
                DeleteObject(v)
                DeleteEntity(v)
            end
        end
    end

    local coords = GetEntityCoords(ped)
    local phone = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)

    local zRot = (string.find(model, "fold") and not PhoneFolded) and 200.0 or 180.0

    AttachEntityToEntity(phone, ped, GetPedBoneIndex(ped, 28422), phoneOffsetX, phoneOffsetY, phoneOffsetZ, phoneRotX, phoneRotY, zRot, true, true, false, true, 2, true)
    SetModelAsNoLongerNeeded(model)

    return phone
end

local function deletePhoneProp(serverId)
    local playerId = GetPlayerFromServerId(serverId)
    if playerId ~= -1 then
        for _, v in pairs(GetGamePool('CObject')) do
            if IsEntityAttachedToEntity(GetPlayerPed(playerId), v) then
                local phoneModel = GetEntityModel(v)
                if isEntityAPhone(phoneModel) then
                    SetEntityAsMissionEntity(v, false, false)
                    DeleteObject(v)
                    DeleteEntity(v)
                end
            end
        end
    end
end

CreateThread(function()
    while true do
        local coords = GetEntityCoords(GetPlayerPed(-1))
        for serverId, v in pairs(playerPhones) do
            local playerId = GetPlayerFromServerId(serverId)
            if v and playerId ~= -1 then
                local distance = #(GetEntityCoords(GetPlayerPed(playerId)) - coords)
                if v.spawn and distance > 150.0 then
                    playerPhones[serverId].spawn = false
                    deletePhoneProp(serverId)
                elseif not v.spawn and distance <= 150.0 then
                    createPhoneProp(GetPlayerPed(playerId), playerPhones[serverId].value)
                    playerPhones[serverId].spawn = true
                end
            end
        end

        Wait(2500)
    end
end)

AddStateBagChangeHandler('phoneProp', '', function(bagName, key, value, reserved, replicated)
    local player = GetPlayerFromStateBagName(bagName)
    if player == 0 then return end

    local ped = GetPlayerPed(player)
    local serverId = GetPlayerServerId(player)

    if not value then
        playerPhones[serverId] = nil
        return deletePhoneProp(serverId)
    end

    local phoneEntity = createPhoneProp(ped, value)
    playerPhones[serverId] = { value = value, spawn = true, entityId = phoneEntity }
end)

RegisterNetEvent('onPlayerDropped', function(serverId)
    local playerProp = playerPhones[serverId]
    if not playerProp then return end

    if playerProp.entityId and DoesEntityExist(playerProp.entityId) then
        SetEntityAsMissionEntity(playerProp.entityId, false, false)
        DeleteObject(playerProp.entityId)
        DeleteEntity(playerProp.entityId)
    else
        for _, obj in pairs(GetGamePool('CObject')) do
            local phoneModel = GetEntityModel(obj)
            if isEntityAPhone(phoneModel) and not IsEntityAttachedToAnyPed(obj) then
                SetEntityAsMissionEntity(obj, false, false)
                DeleteObject(obj)
                DeleteEntity(obj)
            end
        end
    end

    playerPhones[serverId] = nil
end)

-- Prop sync
function PhoneModelSync()
    if isPayphoneBoothSessionActive() then
        DeletePhone()
        return
    end

    if Config.BoomerPhoneAddon then
        local expExist, ysOpen = pcall(function() return exports['yboomer-phone']:IsOpen() end)
        if expExist and ysOpen then return end
    end

    DeletePhone()

    local hash = GetPhoneModelHash()
    if hash then
        playerState:set('phoneProp', hash, true)
    end
end

function DeletePhone()
    playerState:set('phoneProp', nil, true)
end

function DoPhoneAnimation(anim, extraDict, override)
    if isPayphoneBoothSessionActive() then
        DeletePhone()
        return
    end

    if Config.BoomerPhoneAddon then
        local expExist, ysOpen = pcall(function() return exports['yboomer-phone']:IsOpen() end)
        if expExist and ysOpen then return end
    end

    local ped = PlayerPedId()
    local animationLib = 'cellphone@'
    local animationStatus = anim

    if IsPedInAnyVehicle(ped, false) then
        animationLib = 'anim@cellphone@in_car@ds'
    end

    if type(override) == 'string' and override ~= '' then
        animationLib = override
    elseif type(extraDict) == 'string' and extraDict ~= '' then
        if override then
            animationLib = extraDict
        else
            animationLib = animationLib .. extraDict
        end
    end

    lib.playAnim(ped, animationLib, animationStatus, 3.0, 3.0, -1, 50, 0, false, false, false)

    PhoneData.AnimationData.lib = animationLib
    PhoneData.AnimationData.anim = animationStatus
    checkAnimationLoop()
end

--- Cleanup phone animation and props on stop.
---@return nil
local function cleanupPhoneAnimationOnStop()
    local ped = PlayerPedId()
    local animationLib = PhoneData.AnimationData.lib
    local animationName = PhoneData.AnimationData.anim

    if animationLib and animationName then
        StopAnimTask(ped, animationLib, animationName, 2.5)
    end

    ClearPedTasks(ped)

    PhoneData.AnimationData.lib = nil
    PhoneData.AnimationData.anim = nil
    inputTypingActive = false
    stopPhoneTypingAnimation()
    lastTypingAnim = { dict = nil, name = nil, pickedAt = 0 }

    DeletePhone()

    for _, v in pairs(GetGamePool('CObject')) do
        if IsEntityAttachedToAnyPed(v) then
            local phoneModel = GetEntityModel(v)
            if isEntityAPhone(phoneModel) then
                SetEntityAsMissionEntity(v, false, false)
                DeleteObject(v)
                DeleteEntity(v)
            end
        end
    end
end

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    cleanupPhoneAnimationOnStop()
end)
