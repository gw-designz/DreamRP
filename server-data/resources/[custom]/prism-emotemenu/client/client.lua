-- ============================================================
-- prism-emotemenu | client.lua
-- ============================================================

-- State variables
local menuOpen         = false   -- Is the emote UI open?
local currentEmote     = nil     -- Active emote command name
local spawnedProps     = {}      -- Tracked prop entities
local currentWalkStyle = nil     -- Active walk style clipset
local isInAnimation    = false   -- Is the ped currently in an emote animation?
local hasPtfxActive    = false   -- Is a particle effect emote active?
local canUsePtfx       = false   -- Particle effect pending player trigger
local ptfxAsset        = nil     -- Current particle effect asset name
local ptfxName         = nil     -- Current particle effect name
local ptfxNoProp       = false   -- Particle effect doesn't need a prop
local ptfxBone         = nil     -- Bone for particle attachment
local ptfxPlacement    = nil     -- Placement offsets table
local ptfxColor        = nil     -- Particle color table {R,G,B,A}
local ptfxWait         = nil     -- Delay before ptfx triggers
local ptfxCanHold      = nil     -- Whether ptfx can be held
local ptfxParticles    = {}      -- Active particle effect handles per player
local ptfxNotified     = false   -- Has the ptfx hint notification been shown?
local currentExpression = nil    -- Active facial expression name
local playerPed        = nil     -- Cached local player ped
local playerCoords     = nil     -- Cached player world coordinates

targetPlayerId = nil   -- Server ID of the partner in a shared emote (global: used by server events)
isRequestAnim  = false -- Waiting for shared emote response (global: used by event handlers)


-- ============================================================
-- Utility: Load Resources
-- ============================================================

function LoadAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            Wait(10)
        end
    end
end

function LoadModel(modelName)
    local hash = GetHashKey(modelName)
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        while not HasModelLoaded(hash) do
            Wait(10)
        end
    end
    return hash
end

function LoadPtfxAsset(asset)
    while not HasNamedPtfxAssetLoaded(asset) do
        RequestNamedPtfxAsset(asset)
        Wait(10)
    end
    UseParticleFxAsset(asset)
end


-- ============================================================
-- Background Thread: Cache ped + coords
-- ============================================================

CreateThread(function()
    while true do
        playerPed    = PlayerPedId()
        playerCoords = GetEntityCoords(playerPed)
        Wait(500)
    end
end)


-- ============================================================
-- Props
-- ============================================================

function ClearProps()
    for _, entity in pairs(spawnedProps) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    spawnedProps = {}
end

-- Spawns a prop, attaches it to a ped bone, and tracks it.
function AttachProp(modelName, boneId, ox, oy, oz, rx, ry, rz)
    local hash = LoadModel(modelName)
    local prop = CreateObject(hash, playerCoords.x, playerCoords.y, playerCoords.z + 0.2, true, true, false)

    AttachEntityToEntity(
        prop, playerPed,
        GetPedBoneIndex(playerPed, boneId),
        ox, oy, oz, rx, ry, rz,
        true, true, false, true, 1, true
    )

    table.insert(spawnedProps, prop)
    SetModelAsNoLongerNeeded(hash)
    return prop
end


-- ============================================================
-- Particle Effects
-- ============================================================

function StartPtfx()
    if not ptfxAsset or not ptfxName then return end

    LoadPtfxAsset(ptfxAsset)

    local boneIndex
    if ptfxBone then
        boneIndex = GetPedBoneIndex(playerPed, ptfxBone)
        if not boneIndex then
            boneIndex = GetEntityBoneIndexByName(playerPed, "VFX")
        end
    else
        boneIndex = GetEntityBoneIndexByName(playerPed, "VFX")
    end

    local ox, oy, oz, rx, ry, rz, scale = table.unpack(ptfxPlacement)
    if not scale then scale = 1.0 end

    local playerId = PlayerId()

    if ptfxNoProp then
        ptfxParticles[playerId] = StartNetworkedParticleFxLoopedOnEntityBone(
            ptfxName, playerPed, ox, oy, oz, rx, ry, rz, boneIndex,
            scale, false, false, false
        )
    elseif spawnedProps[1] then
        ptfxParticles[playerId] = StartNetworkedParticleFxLoopedOnEntity(
            ptfxName, spawnedProps[1], ox, oy, oz, rx, ry, rz,
            scale, false, false, false
        )
    end

    if ptfxColor then
        local handle = ptfxParticles[playerId]
        SetParticleFxLoopedAlpha(handle, ptfxColor.A)
        SetParticleFxLoopedColour(handle, ptfxColor.R / 255, ptfxColor.G / 255, ptfxColor.B / 255, false)
    end
end

function StopPtfx()
    local playerId = PlayerId()
    if ptfxParticles[playerId] then
        StopParticleFxLooped(ptfxParticles[playerId], false)
        ptfxParticles[playerId] = nil
    end
end


-- ============================================================
-- Expressions
-- ============================================================

function SetExpression(expressionName)
    if not RP or not RP.Expressions or not RP.Expressions[expressionName] then return end

    local data = RP.Expressions[expressionName]
    local anim = data[1] or data.anim
    SetFacialIdleAnimOverride(playerPed, anim, 0)
    currentExpression = expressionName
end

function ResetExpression()
    ClearFacialIdleAnimOverride(playerPed)
    currentExpression = nil
end


-- ============================================================
-- Walk Styles
-- ============================================================

function SetWalkStyle(walkName)
    if not RP or not RP.Walks or not RP.Walks[walkName] then return end

    local clipset = RP.Walks[walkName][1]
    currentWalkStyle = clipset

    RequestAnimSet(clipset)
    while not HasAnimSetLoaded(clipset) do
        Wait(10)
    end

    SetPedMovementClipset(playerPed, clipset, 0.2)
end

function ResetWalkStyle()
    if not currentWalkStyle then return end
    ResetPedMovementClipset(playerPed, 0.2)
    currentWalkStyle = nil
end


-- ============================================================
-- Scenarios
-- ============================================================

function PlayScenario(scenarioName)
    ClearPedTasks(playerPed)
    TaskStartScenarioInPlace(playerPed, scenarioName, 0, true)
    isInAnimation = true
end


-- ============================================================
-- Cancel / Stop Emote
-- ============================================================

function CancelEmote()
    if not isInAnimation then return end

    ClearPedTasks(playerPed)
    ClearProps()
    StopPtfx()

    isInAnimation  = false
    hasPtfxActive  = false
    currentEmote   = nil

    if IsEntityAttached(playerPed) then
        DetachEntity(playerPed, true, false)
    end

    if targetPlayerId then
        TriggerServerEvent("prism-emotemenu:cancelEmote", targetPlayerId)
        targetPlayerId = nil
    end
end


-- ============================================================
-- Shared Emote Requests
-- ============================================================

function RequestSharedEmote(emoteName)
    if not RP or not RP.Shared or not RP.Shared[emoteName] then return end

    local closestPlayer, distance = GetClosestPlayer()
    if closestPlayer == -1 or distance > 3.0 then
        ShowNotification("No player nearby for shared emote")
        return
    end

    local targetServerId = GetPlayerServerId(closestPlayer)
    TriggerServerEvent("prism-emotemenu:requestSharedEmote", targetServerId, emoteName)

    local displayName = RP.Shared[emoteName][3] or emoteName
    ShowNotification("Sent request to nearby player: " .. displayName)
end

-- Called when our shared emote is accepted: play the requester's side of the animation.
function AcceptSharedEmote(partnerServerId, emoteName)
    if not RP or not RP.Shared or not RP.Shared[emoteName] then return end

    local emoteData = RP.Shared[emoteName]
    local partnerEmoteName = emoteData[4] or emoteName

    if not RP.Shared[partnerEmoteName] then return end

    local animData = RP.Shared[partnerEmoteName]
    local dict     = animData[1]
    local anim     = animData[2]
    local opts     = animData.AnimationOptions or {}

    LoadAnimDict(dict)

    local flags = 1
    if opts.EmoteMoving then flags = 51
    elseif opts.EmoteLoop then flags = 1 end

    if opts.Attachto then
        local partnerClientId = GetPlayerFromServerId(partnerServerId)
        local partnerPed      = GetPlayerPed(partnerClientId)
        if DoesEntityExist(partnerPed) then
            local bone  = opts.bone or -1
            local xPos  = opts.xPos or 0.0
            local yPos  = opts.yPos or 0.0
            local zPos  = opts.zPos or 0.0
            local xRot  = opts.xRot or 0.0
            local yRot  = opts.yRot or 0.0
            local zRot  = opts.zRot or 0.0
            AttachEntityToEntity(
                playerPed, partnerPed,
                GetPedBoneIndex(partnerPed, bone),
                xPos, yPos, zPos, xRot, yRot, zRot,
                false, false, false, true, 1, true
            )
        end
    end

    TaskPlayAnim(playerPed, dict, anim, 8.0, -8.0, -1, flags, 0, false, false, false)
    RemoveAnimDict(dict)

    isInAnimation  = true
    currentEmote   = emoteName
    targetPlayerId = partnerServerId
end

function GetClosestPlayer()
    local players     = GetActivePlayers()
    local myId        = PlayerId()
    local myPed       = PlayerPedId()
    local myCoords    = GetEntityCoords(myPed, false)

    local closestId   = -1
    local closestDist = -1

    for _, playerId in ipairs(players) do
        local ped = GetPlayerPed(playerId)
        if ped ~= myId and ped ~= myPed then
            local coords = GetEntityCoords(ped, false)
            local dist   = #(vector3(coords.x, coords.y, coords.z) - vector3(myCoords.x, myCoords.y, myCoords.z))
            if closestId == -1 or closestDist > dist then
                closestId   = playerId
                closestDist = dist
            end
        end
    end

    return closestId, closestDist
end


-- ============================================================
-- Core: Play Emote
-- ============================================================

-- Determines animation flags from AnimationOptions
local function ResolveAnimFlags(opts)
    if opts.onFootFlag then return opts.onFootFlag end
    if opts.EmoteMoving then return 51 end
    if opts.EmoteLoop   then return 1 end
    if opts.EmoteStuck  then return 50 end
    return 1
end

-- Checks if an emote entry in RP.Emotes is a scenario type
local function IsScenarioEmote(emoteEntry)
    local kind = emoteEntry[1]
    if kind == "Scenario" or kind == "MaleScenario" or kind == "ScenarioObject" then
        return true
    end
    if type(kind) == "string" and string.find(kind, "Scenario") then
        return true
    end
    return false
end

function PlayEmote(emoteName, category)
    CancelEmote()

    -- Normalise category aliases
    if category == "dance"    then category = "dances" end
    if category == "prop"     then category = "props"  end

    -- Expressions are handled separately
    if category == "expression" then
        SetExpression(emoteName)
        return
    end

    -- Resolve the emote data table
    local emoteData = nil

    if category == "emotes" or category == "general" or category == "emote" then
        if RP and RP.Emotes and RP.Emotes[emoteName] then
            emoteData = RP.Emotes[emoteName]
            if IsScenarioEmote(emoteData) then
                PlayScenario(emoteData[2])
                currentEmote = emoteName
                return
            end
        end

    elseif category == "dances" then
        if RP and RP.Dances and RP.Dances[emoteName] then
            emoteData = RP.Dances[emoteName]
        end

    elseif category == "props" then
        if RP and RP.PropEmotes and RP.PropEmotes[emoteName] then
            emoteData = RP.PropEmotes[emoteName]
        end

    elseif category == "shared" then
        if RP and RP.Shared and RP.Shared[emoteName] then
            RequestSharedEmote(emoteName)
            return
        end

    elseif category == "shared-force" then
        if RP and RP.Shared and RP.Shared[emoteName] then
            emoteData = RP.Shared[emoteName]
        end

    elseif category == "scenarios" then
        if RP and RP.Emotes and RP.Emotes[emoteName] then
            local entry = RP.Emotes[emoteName]
            if IsScenarioEmote(entry) then
                PlayScenario(entry[2])
                currentEmote = emoteName
                return
            end
        end
    end

    if not emoteData then return end

    currentEmote = emoteName

    local opts = emoteData.AnimationOptions or {}

    -- If [1] is a string with no [2], treat it as a scenario name
    if emoteData[1] and type(emoteData[1]) == "string" and not emoteData[2] then
        PlayScenario(emoteData[1])
        return
    end

    local dict = emoteData[1]
    local anim = emoteData[2]

    if not DoesAnimDictExist(dict) then
        print("^1[EmoteMenu]^7 Animation dictionary does not exist: " .. dict)
        return
    end

    LoadAnimDict(dict)

    -- Spawn primary prop
    if opts.Prop then
        CreateThread(function()
            Wait(opts.EmoteDuration or 0)
            local placement = opts.PropPlacement or {0.0, 0.0, 0.0, 0.0, 0.0, 0.0}
            AttachProp(
                opts.Prop,
                opts.PropBone or 28422,
                placement[1], placement[2], placement[3],
                placement[4], placement[5], placement[6]
            )
        end)
    end

    -- Spawn secondary prop
    if opts.SecondProp then
        CreateThread(function()
            Wait(opts.EmoteDuration or 0)
            local placement = opts.SecondPropPlacement or {0.0, 0.0, 0.0, 0.0, 0.0, 0.0}
            AttachProp(
                opts.SecondProp,
                opts.SecondPropBone or 60309,
                placement[1], placement[2], placement[3],
                placement[4], placement[5], placement[6]
            )
        end)
    end

    -- Store particle effect config for player-triggered activation
    if opts.PtfxAsset then
        ptfxAsset     = opts.PtfxAsset
        ptfxName      = opts.PtfxName
        ptfxNoProp    = opts.PtfxNoProp
        ptfxBone      = opts.PtfxBone
        ptfxPlacement = opts.PtfxPlacement
        ptfxColor     = opts.PtfxColor
        ptfxWait      = opts.PtfxWait or 500
        ptfxCanHold   = opts.PtfxCanHold
        hasPtfxActive = true
        ptfxNotified  = false

        local hintText = opts.PtfxInfo or "Press ~INPUT_DETONATE~ to use effect"

        CreateThread(function()
            while hasPtfxActive and isInAnimation do
                if not ptfxNotified then
                    ShowNotification(hintText)
                    ptfxNotified = true
                end

                -- INPUT_DETONATE = 47
                if IsControlPressed(0, 47) then
                    StartPtfx()
                    Wait(ptfxWait)

                    if ptfxCanHold then
                        while IsControlPressed(0, 47) and isInAnimation and hasPtfxActive do
                            Wait(5)
                        end
                    end

                    StopPtfx()
                end

                Wait(0)
            end
        end)
    end

    -- Resolve animation flags
    local flags    = ResolveAnimFlags(opts)
    if opts.Upperbody then flags = flags + 16 end

    local duration = opts.EmoteDuration or -1

    TaskPlayAnim(playerPed, dict, anim, 8.0, -8.0, duration, flags, 0, false, false, false)
    RemoveAnimDict(dict)
    isInAnimation = true

    -- Auto-cancel after timed emotes (no prop)
    if opts.EmoteDuration and opts.EmoteDuration > 0 and not opts.Prop then
        CreateThread(function()
            Wait(opts.EmoteDuration)
            if currentEmote == emoteName then
                CancelEmote()
            end
        end)
    end
end


-- ============================================================
-- NUI Data Helpers
-- ============================================================

local function CountTable(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

local function GetCategories()
    local categories = {}

    table.insert(categories, {
        name  = "General",
        icon  = "general",
        count = CountTable(RP and RP.Emotes or {})
    })
    table.insert(categories, {
        name  = "Dances",
        icon  = "dance",
        count = CountTable(RP and RP.Dances or {})
    })
    table.insert(categories, {
        name  = "Expressions",
        icon  = "moods",
        count = CountTable(RP and RP.Expressions or {})
    })
    table.insert(categories, {
        name  = "Props",
        icon  = "prop",
        count = CountTable(RP and RP.PropEmotes or {})
    })

    if RP and RP.Scenarios then
        table.insert(categories, {
            name  = "Scenarios",
            icon  = "scenarios",
            count = CountTable(RP.Scenarios)
        })
    end

    table.insert(categories, {
        name  = "Shared",
        icon  = "shared",
        count = CountTable(RP and RP.Shared or {})
    })
    table.insert(categories, {
        name  = "Walk Styles",
        icon  = "walk",
        count = CountTable(RP and RP.Walks or {})
    })

    return categories
end

local function GetEmoteList(categoryName)
    local list = {}

    if categoryName == "General" then
        for key, data in pairs(RP and RP.Emotes or {}) do
            table.insert(list, { command = key, label = data[3] or key, category = "general" })
        end

    elseif categoryName == "Dances" then
        for key, data in pairs(RP and RP.Dances or {}) do
            table.insert(list, { command = key, label = data[3] or key, category = "dance" })
        end

    elseif categoryName == "Expressions" then
        for key, data in pairs(RP and RP.Expressions or {}) do
            table.insert(list, { command = key, label = data[2] or key, category = "moods" })
        end

    elseif categoryName == "Props" then
        for key, data in pairs(RP and RP.PropEmotes or {}) do
            table.insert(list, { command = key, label = data[3] or key, category = "prop" })
        end

    elseif categoryName == "Scenarios" then
        if RP and RP.Scenarios then
            for key, data in pairs(RP.Scenarios) do
                table.insert(list, { command = key, label = data[2] or key, category = "scenarios" })
            end
        end

    elseif categoryName == "Shared" then
        for key, data in pairs(RP and RP.Shared or {}) do
            table.insert(list, { command = key, label = data[3] or key, category = "shared" })
        end

    elseif categoryName == "Walk Styles" then
        for key in pairs(RP and RP.Walks or {}) do
            table.insert(list, { command = key, label = key, category = "walk" })
        end
    end

    return list
end


-- ============================================================
-- Quick Slots
-- ============================================================

local quickSlotModifierActive = false

local function ExecuteQuickSlot(slotIndex)
    local raw = GetResourceKvpString("prism_quickslot_" .. slotIndex)
    if not raw then return end

    local ok, data = pcall(json.decode, raw)
    if not ok or not data then return end

    if data.categoryId == "walk" then
        SetWalkStyle(data.emoteName)
    else
        PlayEmote(data.emoteName, data.categoryId)
    end
end


-- ============================================================
-- NUI Callbacks
-- ============================================================

RegisterNUICallback("focusSearch", function(data, cb)
    SetNuiFocusKeepInput(not data.focused)
    cb("ok")
end)

RegisterNUICallback("getEmoteData", function(data, cb)
    local result = {
        walks       = {},
        dances      = {},
        expressions = {},
        shared      = {},
        props       = {},
        emotes      = {},
        scenarios   = {},
    }

    for key, entry in pairs(RP and RP.Walks or {}) do
        result.walks[key] = { style = entry[1], name = entry[2] or key }
    end

    for key, entry in pairs(RP and RP.Dances or {}) do
        result.dances[key] = { dict = entry[1], anim = entry[2], name = entry[3] or key, options = entry.AnimationOptions }
    end

    for key, entry in pairs(RP and RP.Expressions or {}) do
        result.expressions[key] = { anim = entry[1], name = entry[2] or key }
    end

    for key, entry in pairs(RP and RP.Shared or {}) do
        result.shared[key] = { name = key, requester = entry.Requester, accepter = entry.Accepter }
    end

    for key, entry in pairs(RP and RP.PropEmotes or {}) do
        result.props[key] = { dict = entry[1], anim = entry[2], name = entry[3] or key, options = entry.AnimationOptions }
    end

    for key, entry in pairs(RP and RP.Emotes or {}) do
        if IsScenarioEmote(entry) then
            result.scenarios[key] = { scenarioType = entry[1], scenario = entry[2], name = entry[3] or key }
        else
            result.emotes[key] = { dict = entry[1], anim = entry[2], name = entry[3] or key, options = entry.AnimationOptions }
        end
    end

    cb(result)
end)

RegisterNUICallback("getCategories", function(data, cb)
    cb(GetCategories())
end)

RegisterNUICallback("getEmotes", function(data, cb)
    cb(GetEmoteList(data.category))
end)

RegisterNUICallback("playEmote", function(data, cb)
    local emoteName = data.emoteName or data.emote
    local category  = data.category

    if category == "walk" then
        SetWalkStyle(emoteName)
    elseif category == "expression" then
        SetExpression(emoteName)
    else
        PlayEmote(emoteName, category)
    end

    cb("ok")
end)

RegisterNUICallback("cancelEmote", function(data, cb)
    CancelEmote()
    cb("ok")
end)

RegisterNUICallback("resetExpression", function(data, cb)
    ResetExpression()
    cb("ok")
end)

RegisterNUICallback("resetWalkStyle", function(data, cb)
    ResetWalkStyle()
    cb("ok")
end)

RegisterNUICallback("setWalkStyle", function(data, cb)
    if data.walkName then
        SetWalkStyle(data.walkName)
    else
        ResetWalkStyle()
    end
    cb("ok")
end)

RegisterNUICallback("closeMenu", function(data, cb)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    Citizen.SetTimeout(500, function()
        menuOpen = false
    end)
    cb("ok")
end)

RegisterNUICallback("searchEmotes", function(data, cb)
    local query   = string.lower(data.search or "")
    local results = {}

    local function matchEntry(key, labelIndex, category, source)
        local label = source[key][labelIndex]
        if string.find(string.lower(key), query) or (label and string.find(string.lower(label), query)) then
            table.insert(results, { command = key, label = label or key, category = category })
        end
    end

    for key, entry in pairs(RP and RP.Emotes or {}) do
        local lkey = string.lower(key)
        local lname = entry[3] and string.lower(entry[3])
        if string.find(lkey, query) or (lname and string.find(lname, query)) then
            table.insert(results, { command = key, label = entry[3] or key, category = "general" })
        end
    end

    for key, entry in pairs(RP and RP.Dances or {}) do
        local lkey = string.lower(key)
        local lname = entry[3] and string.lower(entry[3])
        if string.find(lkey, query) or (lname and string.find(lname, query)) then
            table.insert(results, { command = key, label = entry[3] or key, category = "dance" })
        end
    end

    for key, entry in pairs(RP and RP.Expressions or {}) do
        if string.find(string.lower(key), query) then
            table.insert(results, { command = key, label = entry[2] or key, category = "moods" })
        end
    end

    for key, entry in pairs(RP and RP.PropEmotes or {}) do
        local lkey = string.lower(key)
        local lname = entry[3] and string.lower(entry[3])
        if string.find(lkey, query) or (lname and string.find(lname, query)) then
            table.insert(results, { command = key, label = entry[3] or key, category = "prop" })
        end
    end

    cb(results)
end)

RegisterNUICallback("getQuickSlots", function(data, cb)
    local slots = {}
    for i = 1, 4 do
        local raw = GetResourceKvpString("prism_quickslot_" .. i)
        if raw then
            local ok, decoded = pcall(json.decode, raw)
            slots[i] = (ok and decoded) or nil
        else
            slots[i] = nil
        end
    end
    cb(slots)
end)

RegisterNUICallback("setQuickSlot", function(data, cb)
    local slot      = data.slot
    local emoteData = data.emoteData

    if not slot or slot < 1 or slot > 4 then
        cb({ success = false, error = "Invalid slot number" })
        return
    end

    if emoteData then
        local ok, encoded = pcall(json.encode, emoteData)
        if ok then
            SetResourceKvp("prism_quickslot_" .. slot, encoded)
            cb({ success = true })
        else
            cb({ success = false, error = "Failed to encode emote data" })
        end
    else
        DeleteResourceKvp("prism_quickslot_" .. slot)
        cb({ success = true })
    end
end)


-- ============================================================
-- Commands
-- ============================================================

RegisterCommand(Config.EmoteCommand, function()
    if not menuOpen then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
        SendNUIMessage({
            action = "openMenu",
            data   = { color = Config.UIColor }
        })
        menuOpen = true

        -- Disable game controls while menu is open
        CreateThread(function()
            while menuOpen do
                for _, control in ipairs({1,2,3,4,5,6,14,15,16,17,24,25,142,257,263,264}) do
                    DisableControlAction(0, control, true)
                end
                SetPauseMenuActive(false)
                Wait(0)
            end
        end)
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        Citizen.SetTimeout(500, function()
            menuOpen = false
        end)
    end
end, false)

-- /e <emoteName> — play an emote by name (case-insensitive search across all categories)
RegisterCommand("e", function(source, args)
    local input = args[1]
    if not input then return end

    local lInput = string.lower(input)

    local function tryPlay(tbl, category)
        if not RP or not RP[tbl] then return false end
        for key in pairs(RP[tbl]) do
            if string.lower(key) == lInput then
                PlayEmote(key, category)
                return true
            end
        end
        return false
    end

    -- Search Emotes (with scenario detection)
    if RP and RP.Emotes then
        for key, entry in pairs(RP.Emotes) do
            if string.lower(key) == lInput then
                local cat = IsScenarioEmote(entry) and "scenarios" or "emotes"
                PlayEmote(key, cat)
                return
            end
        end
    end

    if tryPlay("Dances",     "dance")      then return end
    if tryPlay("Expressions","expression") then return end
    if tryPlay("PropEmotes", "prop")       then return end

    if RP and RP.Shared then
        for key in pairs(RP.Shared) do
            if string.lower(key) == lInput then
                RequestSharedEmote(key)
                return
            end
        end
    end

    ShowNotification("Emote not found: " .. input)
end, false)

-- /ec — cancel current emote + expression
RegisterCommand("ec", function()
    CancelEmote()
    ResetExpression()
end, false)

-- /walk <styleName> — apply walk style (no arg = reset)
RegisterCommand("walk", function(source, args)
    local input = args[1]
    if not input then
        ResetWalkStyle()
        return
    end

    local lInput = string.lower(input)
    if RP and RP.Walks then
        for key in pairs(RP.Walks) do
            if string.lower(key) == lInput then
                SetWalkStyle(key)
                return
            end
        end
    end

    ShowNotification("Walk style not found: " .. input)
end, false)

-- /shared <emoteName> — request a shared emote with the nearest player
RegisterCommand("shared", function(source, args)
    local input = args[1]
    if not input then return end

    local lInput = string.lower(input)
    if RP and RP.Shared then
        for key in pairs(RP.Shared) do
            if string.lower(key) == lInput then
                RequestSharedEmote(key)
                return
            end
        end
    end

    ShowNotification("Shared emote not found: " .. input)
end, false)


-- ============================================================
-- Quick Slot Commands
-- ============================================================

RegisterCommand("+emotemodifier", function()
    quickSlotModifierActive = true
end, false)

RegisterCommand("-emotemodifier", function()
    quickSlotModifierActive = false
end, false)

RegisterCommand("quickslot1", function()
    if not quickSlotModifierActive then return end
    ExecuteQuickSlot(1)
end, false)

RegisterCommand("quickslot2", function()
    if not quickSlotModifierActive then return end
    ExecuteQuickSlot(2)
end, false)

RegisterCommand("quickslot3", function()
    if not quickSlotModifierActive then return end
    ExecuteQuickSlot(3)
end, false)

RegisterCommand("quickslot4", function()
    if not quickSlotModifierActive then return end
    ExecuteQuickSlot(4)
end, false)


-- ============================================================
-- Key Mappings
-- ============================================================

RegisterKeyMapping(Config.EmoteCommand, "Open Emote Menu",       "keyboard", Config.DefaultKeybind)
RegisterKeyMapping("ec",                "Cancel Emote",           "keyboard", "X")
RegisterKeyMapping("+emotemodifier",    "Emote Modifier (Hold)",  "keyboard", "LSHIFT")
RegisterKeyMapping("quickslot1",        "Quick Access Slot 1",    "keyboard", "1")
RegisterKeyMapping("quickslot2",        "Quick Access Slot 2",    "keyboard", "2")
RegisterKeyMapping("quickslot3",        "Quick Access Slot 3",    "keyboard", "3")
RegisterKeyMapping("quickslot4",        "Quick Access Slot 4",    "keyboard", "4")


-- ============================================================
-- Net Events: Shared Emote Flow
-- ============================================================

RegisterNetEvent("prism-emotemenu:receiveSharedEmoteRequest")
AddEventHandler("prism-emotemenu:receiveSharedEmoteRequest", function(requesterServerId, emoteName)
    if isRequestAnim then return end
    if not RP or not RP.Shared or not RP.Shared[emoteName] then return end

    isRequestAnim = true

    local displayName = RP.Shared[emoteName][3] or emoteName
    ShowNotification("Press Y to accept shared emote: " .. displayName .. " (or L to decline)")

    CreateThread(function()
        local timeout   = 10000
        local startTime = GetGameTimer()

        while isRequestAnim and (GetGameTimer() - startTime) < timeout do
            -- Y key = accept (246), L key = decline (182)
            if IsControlJustPressed(0, 246) then
                isRequestAnim = false
                TriggerServerEvent("prism-emotemenu:acceptSharedEmote", requesterServerId, emoteName)
                break
            elseif IsControlJustPressed(0, 182) then
                isRequestAnim = false
                TriggerServerEvent("prism-emotemenu:declineSharedEmote", requesterServerId)
                ShowNotification("Shared emote declined")
                break
            end
            Wait(0)
        end

        if isRequestAnim then
            isRequestAnim = false
            ShowNotification("Shared emote request timed out")
        end
    end)
end)

RegisterNetEvent("prism-emotemenu:syncEmote")
AddEventHandler("prism-emotemenu:syncEmote", function(emoteName, partnerServerId)
    CancelEmote()
    Wait(300)
    AcceptSharedEmote(partnerServerId, emoteName)
end)

RegisterNetEvent("prism-emotemenu:syncEmoteSource")
AddEventHandler("prism-emotemenu:syncEmoteSource", function(emoteName, partnerServerId)
    CancelEmote()
    Wait(300)

    if not RP or not RP.Shared or not RP.Shared[emoteName] then return end

    local animData = RP.Shared[emoteName]
    local dict     = animData[1]
    local anim     = animData[2]
    local opts     = animData.AnimationOptions or {}

    LoadAnimDict(dict)

    local flags = 1
    if opts.EmoteMoving then flags = 51
    elseif opts.EmoteLoop then flags = 1 end

    TaskPlayAnim(playerPed, dict, anim, 8.0, -8.0, -1, flags, 0, false, false, false)
    RemoveAnimDict(dict)

    isInAnimation  = true
    currentEmote   = emoteName
    targetPlayerId = partnerServerId
end)

RegisterNetEvent("prism-emotemenu:cancelEmote")
AddEventHandler("prism-emotemenu:cancelEmote", function(fromServerId)
    if targetPlayerId and targetPlayerId == fromServerId then
        targetPlayerId = nil
        CancelEmote()
    end
end)

RegisterNetEvent("prism-emotemenu:sharedEmoteDeclined")
AddEventHandler("prism-emotemenu:sharedEmoteDeclined", function()
    ShowNotification("Player declined your shared emote request")
end)


-- ============================================================
-- Resource Lifecycle
-- ============================================================

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    CancelEmote()
    ResetExpression()
    ResetWalkStyle()
    ClearProps()
    StopPtfx()
end)


-- ============================================================
-- Exports: Public API
-- ============================================================

-- PlayAnimation(emoteName, category, forcePlay)
--   emoteName : string  — command key in the RP tables
--   category  : string? — optional hint ("emote","dance","walk","expression","shared",...)
--   returns   : bool
function PlayAnimation(emoteName, category, forcePlay)
    if not emoteName then
        ShowNotification("Error: No emote name provided")
        return false
    end

    -- Auto-detect category if not supplied
    if not category then
        if RP and RP.Emotes and RP.Emotes[emoteName] then
            local entry = RP.Emotes[emoteName]
            category = IsScenarioEmote(entry) and "scenarios" or "emotes"
        elseif RP and RP.Dances and RP.Dances[emoteName] then
            category = "dance"
        elseif RP and RP.Expressions and RP.Expressions[emoteName] then
            category = "expression"
        elseif RP and RP.PropEmotes and RP.PropEmotes[emoteName] then
            category = "prop"
        elseif RP and RP.Shared and RP.Shared[emoteName] then
            category = "shared"
        elseif RP and RP.Walks and RP.Walks[emoteName] then
            category = "walk"
        else
            ShowNotification("Error: Emote '" .. emoteName .. "' not found")
            return false
        end
    end

    -- Normalise category and dispatch
    if category == "walk" then
        SetWalkStyle(emoteName)
        return true
    elseif category == "expression" or category == "mood" then
        SetExpression(emoteName)
        return true
    elseif category == "shared" then
        RequestSharedEmote(emoteName)
        return true
    else
        local normalized = category
        if category == "dance"                         then normalized = "dances"   end
        if category == "emote" or category == "emotes" then normalized = "emotes"   end
        if category == "prop"                          then normalized = "props"    end
        if category == "scenario" or category == "scenarios" then normalized = "scenarios" end
        PlayEmote(emoteName, normalized)
        return true
    end
end

-- GetAvailableEmotes(filter)
--   filter : nil/"all" | "emote" | "dance" | "expression" | "prop" | "shared" | "walk" | "scenario"
function GetAvailableEmotes(filter)
    local result = {}

    local function addEntries(tbl, nameIdx, cat)
        for key, data in pairs(tbl or {}) do
            result[key] = { name = data[nameIdx] or key, command = key, category = cat }
        end
    end

    if not filter or filter == "all" then
        result = { emotes = {}, dances = {}, expressions = {}, props = {}, shared = {}, walks = {}, scenarios = {} }

        for key, data in pairs(RP and RP.Emotes or {}) do
            result.emotes[key] = { name = data[3] or key, command = key, category = "emote" }
        end
        for key, data in pairs(RP and RP.Dances or {}) do
            result.dances[key] = { name = data[3] or key, command = key, category = "dance" }
        end
        for key, data in pairs(RP and RP.Expressions or {}) do
            result.expressions[key] = { name = data[2] or key, command = key, category = "expression" }
        end
        for key, data in pairs(RP and RP.PropEmotes or {}) do
            result.props[key] = { name = data[3] or key, command = key, category = "prop" }
        end
        for key in pairs(RP and RP.Shared or {}) do
            result.shared[key] = { name = key, command = key, category = "shared" }
        end
        for key, data in pairs(RP and RP.Walks or {}) do
            result.walks[key] = { name = data[2] or key, command = key, category = "walk" }
        end
        for key, data in pairs(RP and RP.Scenarios or {}) do
            result.scenarios[key] = { name = data[2] or key, command = key, category = "scenario" }
        end

    elseif filter == "emote" or filter == "emotes" then
        for key, data in pairs(RP and RP.Emotes or {}) do
            result[key] = { name = data[3] or key, command = key, category = "emote" }
        end
    elseif filter == "dance" or filter == "dances" then
        for key, data in pairs(RP and RP.Dances or {}) do
            result[key] = { name = data[3] or key, command = key, category = "dance" }
        end
    elseif filter == "expression" or filter == "expressions" then
        for key, data in pairs(RP and RP.Expressions or {}) do
            result[key] = { name = data[2] or key, command = key, category = "expression" }
        end
    elseif filter == "prop" or filter == "props" then
        for key, data in pairs(RP and RP.PropEmotes or {}) do
            result[key] = { name = data[3] or key, command = key, category = "prop" }
        end
    elseif filter == "shared" then
        for key in pairs(RP and RP.Shared or {}) do
            result[key] = { name = key, command = key, category = "shared" }
        end
    elseif filter == "walk" or filter == "walks" then
        for key, data in pairs(RP and RP.Walks or {}) do
            result[key] = { name = data[2] or key, command = key, category = "walk" }
        end
    elseif filter == "scenario" or filter == "scenarios" then
        for key, data in pairs(RP and RP.Scenarios or {}) do
            result[key] = { name = data[2] or key, command = key, category = "scenario" }
        end
    end

    return result
end

-- HasEmote(emoteName, category?) — returns true/false
function HasEmote(emoteName, category)
    if not emoteName then return false end

    if category then
        if category == "scenario" or category == "scenarios" then
            if RP and RP.Emotes and RP.Emotes[emoteName] then
                return IsScenarioEmote(RP.Emotes[emoteName])
            end
            return false
        elseif category == "emote" or category == "emotes" then
            return RP ~= nil and RP.Emotes ~= nil and RP.Emotes[emoteName] ~= nil
        elseif category == "dance" or category == "dances" then
            return RP ~= nil and RP.Dances ~= nil and RP.Dances[emoteName] ~= nil
        elseif category == "expression" or category == "expressions" then
            return RP ~= nil and RP.Expressions ~= nil and RP.Expressions[emoteName] ~= nil
        elseif category == "prop" or category == "props" then
            return RP ~= nil and RP.PropEmotes ~= nil and RP.PropEmotes[emoteName] ~= nil
        elseif category == "shared" then
            return RP ~= nil and RP.Shared ~= nil and RP.Shared[emoteName] ~= nil
        elseif category == "walk" or category == "walks" then
            return RP ~= nil and RP.Walks ~= nil and RP.Walks[emoteName] ~= nil
        end
    end

    -- No category: search all tables
    if RP then
        if RP.Emotes      and RP.Emotes[emoteName]      then return true end
        if RP.Dances      and RP.Dances[emoteName]      then return true end
        if RP.Expressions and RP.Expressions[emoteName] then return true end
        if RP.PropEmotes  and RP.PropEmotes[emoteName]  then return true end
        if RP.Shared      and RP.Shared[emoteName]      then return true end
        if RP.Walks       and RP.Walks[emoteName]       then return true end
    end

    return false
end

-- GetAnimationStatus() — returns current animation state snapshot
function GetAnimationStatus()
    return {
        isInAnimation   = isInAnimation,
        currentEmote    = currentEmote,
        currentExpression = currentExpression,
        walkStyle       = currentWalkStyle,
        hasProps        = #spawnedProps > 0,
    }
end

function GetAllEmotes()
    return RP
end

-- Register exports
exports("GetAllEmotes",       GetAllEmotes)
exports("PlayEmote",          PlayEmote)
exports("CancelEmote",        CancelEmote)
exports("SetExpression",      SetExpression)
exports("ResetExpression",    ResetExpression)
exports("SetWalkStyle",       SetWalkStyle)
exports("ResetWalkStyle",     ResetWalkStyle)
exports("PlayAnimation",      PlayAnimation)
exports("GetAvailableEmotes", GetAvailableEmotes)
exports("HasEmote",           HasEmote)
exports("GetAnimationStatus", GetAnimationStatus)