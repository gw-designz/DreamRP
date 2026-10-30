lib.locale(Bridge?.Config?.Language or 'en')

--- Editable client-side utility functions
--- You can modify these functions to customize behavior across the entire resource.

Editable = {}

--- Check if a player is dead by their server ID
--- Used throughout interactions (cuff, drag, carry, search, vehicle, etc.)
---@param serverId number
---@return boolean
function Editable:isPlayerDead(serverId)
    if not serverId or serverId == 0 then return false end
    local state = Player(serverId).state
    if not state then return false end
    return state.isDead or state.dead or false
end

--- Quick state-based dead check (used in per-frame canInteract checks)
--- Same logic as isPlayerDead but takes a state table directly for performance
---@param state table Player state table
---@return boolean
function Editable:isDead(state)
    if not state then return false end
    return state.isDead or state.dead or false
end

--- Check if the local player can perform actions
--- Returns false when the player is dragging or carrying someone
---@return boolean
function Editable:canAct()
    local ls = LocalPlayer.state
    if ls.draggingPlayer or ls.carryingPlayer then return false end
    return true
end

--- Check if the local player is standing in front of the target entity
--- Used to determine cuff position (front vs rear)
---@param entity number
---@return boolean
function Editable:isInFront(entity)
    local ped = cache.ped
    local myCoords = GetEntityCoords(ped)
    local targetCoords = GetEntityCoords(entity)
    local targetFwd = GetEntityForwardVector(entity)
    local dir = myCoords - targetCoords
    local dot = dir.x * targetFwd.x + dir.y * targetFwd.y
    return dot > 0.0
end

--- Get the player's current gender based on ped model
---@return string 'male' | 'female'
function Editable:getPlayerGender()
    local model = GetEntityModel(cache.ped)
    return model == `mp_f_freemode_01` and 'female' or 'male'
end

--- Revive integrations, checked top to bottom - the first started resource wins.
--- Used by the prison infirmary (and anything else that needs to revive the local
--- player). Add your own entry here if you run a different ambulance job.
Editable.reviveSystems = {
    { resource = 'wasabi_ambulance', revive = function() TriggerEvent('wasabi_ambulance:revive') end },
    { resource = 'wasabi_ambulance_v2', revive = function() TriggerEvent('wasabi_ambulance:revive') end },
    { resource = 'qbx_medical', revive = function() TriggerEvent('qbx_medical:client:playerRevived') end },
    { resource = 'qb-ambulancejob', revive = function() TriggerEvent('hospital:client:Revive', true) end },
    { resource = 'ars_ambulancejob', revive = function() TriggerEvent('ars_ambulancejob:revive') end },
    { resource = 'p_ambulancejob', revive = function() TriggerEvent('p_ambulancejob:RevivePlayer') end },
    { resource = 'esx_ambulancejob', revive = function() TriggerEvent('esx_ambulancejob:revive') end },
}

--- Revive the local player through whichever ambulance job is running.
--- Falls back to a plain native resurrect when no known system is detected.
function Editable:revivePlayer()
    for _, system in ipairs(self.reviveSystems) do
        if GetResourceState(system.resource) == 'started' then
            return system.revive()
        end
    end

    local coords = GetEntityCoords(cache.ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(cache.ped), true, false)
    SetEntityHealth(cache.ped, GetEntityMaxHealth(cache.ped))
    ClearPedBloodDamage(cache.ped)
    ClearPedTasksImmediately(cache.ped)
end

Editable.mdtSystems = {
    { resource = 'p_mdt', open = function() exports.p_mdt:OpenMDT() end },
    { resource = 'lb-tablet', open = function() exports['lb-tablet']:ToggleOpen(true) end },
    { resource = 'tk_mdt', open = function() exports.tk_mdt:openUI('police') end },
    { resource = 'ps-mdt', open = function() ExecuteCommand('mdt') end },
    { resource = 'redutzu-mdt', open = function() TriggerEvent('redutzu-mdt:client:openMDT') end },
}

function Editable:openMDT()
    local system = Config.MDT?.system or 'auto'

    if system ~= 'custom' then
        for _, mdt in ipairs(self.mdtSystems) do
            if (system == 'auto' or system == mdt.resource) and GetResourceState(mdt.resource) == 'started' then
                return mdt.open()
            end
        end
    end

    if Config.MDT?.customOpen then
        return Config.MDT.customOpen()
    end

    Bridge.Notify.showNotify(locale('mdt_not_found'), 'error')
end

-- Police Radial

local function buildRadial()
    local policeMenuItems = {
        {
            label = locale('interactions'),
            icon = 'handcuffs',
            menu = 'police_interactions'
        },
        {
            label = locale('radial_ticket'),
            icon = 'file-invoice-dollar',
            onSelect = function()
                ExecuteCommand('issueTicket')
            end
        },
        {
            label = locale('radial_traffic'),
            icon = 'traffic-light',
            onSelect = function()
                ExecuteCommand('trafficmenu')
            end
        },
        {
            label = locale('analyze_vehicle'),
            icon = 'fingerprint',
            onSelect = function()
                TriggerEvent('p_policejob/analyzeVehicle')
            end
        },
    }

    if Config.Objects?.enabled then
        policeMenuItems[#policeMenuItems + 1] = {
            label = locale('objects'),
            icon = 'road-barrier',
            onSelect = function()
                TriggerEvent('p_policejob/client/objects/open')
            end
        }
    end

    if Config.MDT?.enabled then
        policeMenuItems[#policeMenuItems + 1] = {
            label = locale('radial_mdt'),
            icon = 'laptop',
            onSelect = function()
                Editable:openMDT()
            end
        }
    end

    if Config.K9?.enabled then
        policeMenuItems[#policeMenuItems + 1] = {
            label = locale('k9'),
            icon = 'dog',
            menu = 'k9_root_radial'
        }
    end

    policeMenuItems[#policeMenuItems + 1] = {
        label = locale('radio'),
        icon = 'walkie-talkie',
        menu = 'police_radio'
    }

    lib.registerRadial({
        id = 'police_menu',
        items = policeMenuItems
    })

    if Config.RadioList and Config.RadioList.Enabled then
        local radioItems = {}
        for _, ch in ipairs(Config.RadioList.RadialChannels or {}) do
            radioItems[#radioItems + 1] = {
                id = 'police_radio_' .. ch.channel,
                icon = ch.icon or 'walkie-talkie',
                label = ch.label,
                onSelect = function()
                    if GetResourceState('pma-voice') ~= 'started' then
                        return Bridge.Notify.showNotify(locale('radio_voice_unavailable'), 'error')
                    end
                    exports['pma-voice']:setRadioChannel(ch.channel)
                    Bridge.Notify.showNotify(locale('radio_joined_channel', ch.label), 'success')
                end
            }
        end

        radioItems[#radioItems + 1] = {
            id = 'police_radio_leave',
            icon = 'ban',
            label = locale('radio_leave_channel'),
            onSelect = function()
                if GetResourceState('pma-voice') ~= 'started' then
                    return Bridge.Notify.showNotify(locale('radio_voice_unavailable'), 'error')
                end
                exports['pma-voice']:setRadioChannel(0)
                Bridge.Notify.showNotify(locale('radio_left_channel'), 'inform')
            end
        }

        radioItems[#radioItems + 1] = {
            id = 'police_radio_anim',
            icon = 'person-rays',
            label = locale('radio_anim_menu'),
            onSelect = function()
                TriggerEvent('p_policejob/client/radio/openAnimMenu')
            end
        }

        lib.registerRadial({ id = 'police_radio', items = radioItems })
    end

    lib.registerRadial({
        id = 'police_interactions',
        items = {
            {
                label = locale('search'),
                icon = 'magnifying-glass',
                onSelect = function()
                    TriggerEvent('p_policejob/searchPlayer')
                end
            },
            {
                label = locale('cuff'),
                icon = 'handcuffs',
                onSelect = function()
                    TriggerEvent('p_policejob/cuffPlayer')
                end
            },
            {
                label = locale('drag'),
                icon = 'person-digging',
                onSelect = function()
                    TriggerEvent('p_policejob/dragPlayer')
                end
            },
            {
                label = locale('put_in_vehicle'),
                icon = 'car-side',
                onSelect = function()
                    TriggerEvent('p_policejob/putInVehicle')
                end
            },
            {
                label = locale('radial_escort'),
                icon = 'people-arrows',
                onSelect = function()
                    TriggerEvent('p_policejob/escortPlayer')
                end
            }
        }
    })

    if Config.K9?.enabled then
        local spawnItems = {}
        for _, m in ipairs(Config.K9.models) do
            local breed = m.breed
            spawnItems[#spawnItems + 1] = {
                id = 'k9_spawn_' .. breed,
                icon = 'dog',
                label = m.name,
                onSelect = function() K9:spawn(breed) end,
            }
        end
        lib.registerRadial({ id = 'k9_spawn_radial', items = spawnItems })

        lib.registerRadial({
            id = 'k9_actions_radial',
            items = {
                { id = 'k9_follow', icon = 'person-walking', label = locale('k9_radial_follow'), onSelect = function() K9:follow() end },
                { id = 'k9_stay', icon = 'hand', label = locale('k9_radial_stay'), onSelect = function() K9:stay() end },
                { id = 'k9_sit', icon = 'chair', label = locale('k9_radial_sit'), onSelect = function() K9:sit() end },
                { id = 'k9_lay', icon = 'bed', label = locale('k9_radial_lay'), onSelect = function() K9:lay() end },
                { id = 'k9_search', icon = 'magnifying-glass', label = locale('k9_radial_search'), onSelect = function() K9:search() end },
                { id = 'k9_attack', icon = 'skull', label = locale('k9_radial_attack'), onSelect = function() K9:attack() end },
                { id = 'k9_heel', icon = 'rotate-left', label = locale('k9_radial_heel'), onSelect = function() K9:heel() end },
                { id = 'k9_dismiss', icon = 'trash', label = locale('k9_radial_dismiss'), onSelect = function() K9:dismiss() end },
            },
        })

        lib.registerRadial({
            id = 'k9_root_radial',
            items = {
                { id = 'k9_open_spawn', icon = 'dog', label = locale('k9_radial_deploy'), menu = 'k9_spawn_radial' },
                { id = 'k9_open_actions', icon = 'paw', label = locale('k9_radial_commands'), menu = 'k9_actions_radial' },
            },
        })
    end
end

buildRadial()

AddEventHandler('p_bridge/client/setPlayerData', function(playerData)
    if playerData.job and Config.Jobs[playerData.job.name] then
        lib.addRadialItem({
            {
                id = 'police_job_menu',
                label = locale('police_menu'),
                icon = 'shield-halved',
                menu = 'police_menu'
            }
        })
    else
        lib.removeRadialItem('police_job_menu')
    end
end)