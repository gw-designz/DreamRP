local QBCore = exports['qb-core']:GetCoreObject()

-- Auto-detect dispatch system
local function GetDispatchSystem()
    local configured = Config.doorlock.alerts.dispatchSystem
    if configured and configured ~= 'auto' then
        return configured
    end

    if GetResourceState('meteo-dispatch') == 'started' then
        return 'meteo-dispatch'
    elseif GetResourceState('ps-dispatch') == 'started' then
        return 'ps-dispatch'
    elseif GetResourceState('tk_dispatch') == 'started' then
        return 'tk_dispatch'
    end

    return 'default'
end

-- Auto-detect phone system
local function GetPhoneSystem()
    local configured = Config.doorlock.alerts.phoneSystem
    if configured and configured ~= 'auto' then
        return configured
    end

    if GetResourceState('meteo-phone') == 'started' then
        return 'meteo-phone'
    elseif GetResourceState('high-phone') == 'started' then
        return 'high-phone'
    elseif GetResourceState('qb-phone') == 'started' then
        return 'qb-phone'
    elseif GetResourceState('npwd') == 'started' then
        return 'qb-phone'
    end

    return 'default'
end

-- Send email/notification to a single player
local function SendPhoneAlert(serverId, message, emailData)
    local phoneSystem = GetPhoneSystem()

    if phoneSystem == 'meteo-phone' and emailData then
        local success, err = pcall(function()
            local phoneItem, phoneSerial, slot = exports['meteo-phone']:GetPlayerPhoneBySource(serverId)
            if phoneSerial then
                exports['meteo-phone']:SendEmailToPhone(
                    phoneSerial,
                    emailData.sender or 'security@gruppesechs.com',
                    emailData.subject or 'Security Alert',
                    emailData.content or message
                )
                DebugPrint('Email sent via meteo-phone:', serverId)
                return true
            end
        end)
        if success then return true end
        DebugPrint('meteo-phone error:', err)
    end

    if phoneSystem == 'high-phone' and emailData then
        local success, err = pcall(function()
            local Player = QBCore.Functions.GetPlayer(serverId)
            if Player then
                local charInfo = Player.PlayerData.charinfo
                local email = charInfo and (charInfo.email or (charInfo.firstname .. '.' .. charInfo.lastname .. '@high.mail'):lower())

                exports['high-phone']:sendMail({
                    sender = emailData.sender or 'security@gruppesechs.com',
                    recipients = { email },
                    subject = emailData.subject or 'Security Alert',
                    content = emailData.content or message,
                })
                DebugPrint('Email sent via high-phone:', serverId)
                return true
            end
        end)
        if success then return true end
        DebugPrint('high-phone error:', err)
    end

    if phoneSystem == 'qb-phone' and emailData then
        local success, err = pcall(function()
            TriggerClientEvent('qb-phone:client:CustomNotification', serverId,
                emailData.subject or 'Security Alert',
                emailData.content or message,
                'fas fa-shield-alt',
                '#e74c3c',
                8000
            )
            DebugPrint('Notification sent via qb-phone:', serverId)
            return true
        end)
        if success then return true end
        DebugPrint('qb-phone error:', err)
    end

    -- Fallback to QBCore notify
    TriggerClientEvent('QBCore:Notify', serverId, message, 'info', 8000)
    return false
end

-- Send notification to apartment owner
function AlertOwner(ownerServerId, message, notifyType, duration, emailData)
    if not ownerServerId then return end
    notifyType = notifyType or 'info'
    duration = duration or 8000

    SendPhoneAlert(ownerServerId, message, emailData)
end

-- Send notification to apartment members
function AlertMembers(memberServerIds, message, notifyType, duration, emailData)
    if not memberServerIds or #memberServerIds == 0 then return end

    for _, serverId in ipairs(memberServerIds) do
        SendPhoneAlert(serverId, message, emailData)
    end
end

-- Send dispatch alert to police/emergency services
function SendDispatch(data)
    if not data then return end

    local message = data.message
    local code = data.code or '10-91'
    local title = data.title or 'Suspicious Activity'
    local description = data.description or message
    local coords = data.coords
    local priority = data.priority or 2
    local jobs = data.jobs or Config.doorlock.alertPoliceJobs or { ['police'] = 0 }
    local excludeSource = data.excludeSource
    local location = data.location or title or 'Unknown Location'

    local dispatchSystem = GetDispatchSystem()
    DebugPrint('Using dispatch system:', dispatchSystem)

    if dispatchSystem == 'meteo-dispatch' and coords then
        exports['meteo-dispatch']:AddCall({
            callType = 'auto',
            code = code,
            title = title,
            description = description,
            location = location,
            street = location,
            coords = { x = coords.x, y = coords.y, z = coords.z },
            priority = priority,
            jobFilter = 'leo'
        })
        DebugPrint('Dispatch alert sent via meteo-dispatch:', code, title)
        return
    end

    if dispatchSystem == 'ps-dispatch' and coords then
        local jobNames = {}
        for job, _ in pairs(jobs) do
            jobNames[#jobNames + 1] = job
        end

        local players = QBCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            if playerId ~= excludeSource then
                local Player = QBCore.Functions.GetPlayer(playerId)
                if Player then
                    local playerJob = Player.PlayerData.job
                    if playerJob and jobs[playerJob.name] ~= nil then
                        local minGrade = jobs[playerJob.name]
                        if playerJob.grade.level >= minGrade then
                            TriggerClientEvent('meteo-apartments:client:psDispatch', playerId, {
                                coords = coords,
                                message = message or title,
                                dispatchCode = code,
                                description = title,
                                priority = priority,
                            })
                        end
                    end
                end
            end
        end
        DebugPrint('Dispatch alert sent via ps-dispatch:', code, title)
        return
    end

    if dispatchSystem == 'tk_dispatch' and coords then
        local jobNames = {}
        for job, _ in pairs(jobs) do
            jobNames[#jobNames + 1] = job
        end

        exports.tk_dispatch:addCall({
            title = title,
            code = code,
            priority = tostring(priority),
            message = description,
            coords = coords,
            location = location,
            jobs = jobNames,
            blip = {
                sprite = data.blipSprite or 161,
                scale = data.blipScale or 1.0,
                color = data.blipColor or 1,
                flash = true,
            }
        })
        DebugPrint('Dispatch alert sent via tk_dispatch:', code, title)
        return
    end

    -- Fallback: Notify all online officers
    if not message then return end

    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        if playerId ~= excludeSource then
            local Player = QBCore.Functions.GetPlayer(playerId)
            if Player then
                local playerJob = Player.PlayerData.job
                if playerJob and jobs[playerJob.name] ~= nil then
                    local minGrade = jobs[playerJob.name]
                    if playerJob.grade.level >= minGrade then
                        TriggerClientEvent('QBCore:Notify', playerId, message, 'error', 10000)
                    end
                end
            end
        end
    end
end