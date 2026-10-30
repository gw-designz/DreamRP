-- Wait for Config to be available
while not Config do Citizen.Wait(1) end

-- ─── Internal Helpers ────────────────────────────────────────────────────────

-- Loads the department map module(s) and returns a list of { name, data } entries
function LoadDepartmentMaps()
    local maps = {}
    local mapConfig = Config.DepartmentMap

    if type(mapConfig) == "string" then
        local data = lib.load(string.format("maps.departments.%s", mapConfig))
        table.insert(maps, { name = mapConfig, data = data })
    elseif type(mapConfig) == "table" then
        for _, mapName in ipairs(mapConfig) do
            local data = lib.load(string.format("maps.departments.%s", mapName))
            table.insert(maps, { name = mapName, data = data })
        end
    end

    return maps
end

-- Spawns and configures a scenario/anim NPC at the given pedConfig coords.
-- Returns the ped entity handle.
-- fallbackCoords: vec4 used when pedConfig has no .coords (e.g. duty-point peds)
function SpawnDutyPed(pedConfig, fallbackCoords)
    -- Resolve spawn position: ped table may carry its own coords, or we use the duty-point coords
    local spawnCoords = pedConfig.coords or fallbackCoords
    if not spawnCoords then
        lib.print.error("[SpawnDutyPed] No coords provided for ped model: " .. tostring(pedConfig.model))
        return nil
    end

    local modelHash = lib.requestModel(pedConfig.model)
    local ped = CreatePed(4, modelHash,
        spawnCoords.x, spawnCoords.y, spawnCoords.z - 1.0,
        spawnCoords.w or 0.0,
        false, true
    )

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)

    if pedConfig.scenario then
        TaskStartScenarioInPlace(ped, pedConfig.scenario, 0, true)
    elseif pedConfig.anim then
        lib.requestAnimDict(pedConfig.anim.dict)
        TaskPlayAnim(ped, pedConfig.anim.dict, pedConfig.anim.name, 8.0, -8.0, -1, 1, 0, false, false, false)
        RemoveAnimDict(pedConfig.anim.dict)
    end

    if type(pedConfig.onCreate) == "function" then
        pedConfig.onCreate(ped)
    end

    return ped
end

-- Validates that a map section value is a table; prints an error and returns false otherwise
function ValidateSection(value, sectionName)
    if type(value) ~= "table" then
        lib.print.error(string.format("Invalid %s data. Expected a table, got %s", sectionName, type(value)))
        return false
    end
    return true
end

-- ─── Init Thread ─────────────────────────────────────────────────────────────

Citizen.CreateThread(function()
    local maps = LoadDepartmentMaps()
    if #maps < 1 then return end

    for _, entry in ipairs(maps) do
        local mapName = entry.name
        local mapData = entry.data

        if not ValidateSection(mapData, "department map") then return end

        -- ── Blips ──────────────────────────────────────────────────────────
        if mapData.blips then
            if not ValidateSection(mapData.blips, "blips") then return end

            for _, blipData in ipairs(mapData.blips) do
                if not ValidateSection(blipData, "blip") then return end

                local blip = AddBlipForCoord(blipData.coords.x, blipData.coords.y, blipData.coords.z)
                SetBlipSprite(blip, blipData.sprite)
                SetBlipColour(blip, blipData.color)
                SetBlipScale(blip, blipData.scale)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentSubstringPlayerName(blipData.label)
                EndTextCommandSetBlipName(blip)
            end
        end

        -- ── Trash zones ────────────────────────────────────────────────────
        if mapData.trashes then
            if not ValidateSection(mapData.trashes, "trashes") then return end

            for i, trashData in ipairs(mapData.trashes) do
                if not ValidateSection(trashData, "trash") then return end

                local zoneId = string.format("%s_%d", mapName, i)

                Bridge.Target.addSphereZone({
                    coords     = vec3(trashData.coords.x, trashData.coords.y, trashData.coords.z),
                    radius     = trashData.radius or 1.0,
                    drawSprite = true,
                    debug      = Bridge.Config and Bridge.Config.Debug,
                    options    = {
                        {
                            name     = "open_trash_" .. zoneId,
                            label    = locale("open_trash"),
                            icon     = "fa-solid fa-dumpster",
                            distance = trashData.distance or 2.0,
                            groups   = Config.Jobs,
                            onSelect = function()
                                exports[GetCurrentResourceName()]:openTrash(zoneId)
                            end,
                        },
                        {
                            name     = "clear_trash_" .. zoneId,
                            label    = locale("clear_trash"),
                            icon     = "fa-solid fa-trash-can",
                            distance = trashData.distance or 2.0,
                            groups   = Config.Jobs,
                            onSelect = function()
                                exports[GetCurrentResourceName()]:clearTrash(zoneId)
                            end,
                        },
                    },
                })
            end
        end

        -- ── Lockers ────────────────────────────────────────────────────────
        if mapData.lockers then
            if not ValidateSection(mapData.lockers, "lockers") then return end

            for _, lockerData in ipairs(mapData.lockers) do
                if not ValidateSection(lockerData, "locker") then return end

                Bridge.Target.addSphereZone({
                    coords     = vec3(lockerData.coords.x, lockerData.coords.y, lockerData.coords.z),
                    radius     = lockerData.radius or 1.0,
                    drawSprite = true,
                    debug      = Bridge.Config and Bridge.Config.Debug,
                    options    = {
                        {
                            name     = string.format("open_locker_%s_%d", mapName, _),
                            label    = locale("open_locker"),
                            icon     = "fa-solid fa-vault",
                            distance = lockerData.distance or 2.0,
                            groups   = Config.Jobs,
                            onSelect = function()
                                exports[GetCurrentResourceName()]:openLockerWithInput()
                            end,
                        },
                    },
                })
            end
        end

        -- ── Wardrobes ──────────────────────────────────────────────────────
        if mapData.wardrobes and Config.Wardrobe and Config.Wardrobe.Enabled then
            if not ValidateSection(mapData.wardrobes, "wardrobes") then return end

            for i, wardrobeData in ipairs(mapData.wardrobes) do
                if not ValidateSection(wardrobeData, "wardrobe") then return end

                Bridge.Target.addSphereZone({
                    coords     = vec3(wardrobeData.coords.x, wardrobeData.coords.y, wardrobeData.coords.z),
                    radius     = wardrobeData.radius or 1.0,
                    drawSprite = true,
                    debug      = Bridge.Config and Bridge.Config.Debug,
                    options    = {
                        {
                            name     = string.format("change_uniform_%s_%d", mapName, i),
                            label    = wardrobeData.label or locale("change_uniform"),
                            icon     = "fa-solid fa-shirt",
                            distance = wardrobeData.distance or 2.0,
                            groups   = Config.Jobs,
                            onSelect = function()
                                exports[GetCurrentResourceName()]:OpenUniformSelect()
                            end,
                        },
                    },
                })
            end
        end

        -- ── CCTV terminals ─────────────────────────────────────────────────
        if mapData.cctv then
            if not ValidateSection(mapData.cctv, "cctv") then return end

            for i, cctvData in ipairs(mapData.cctv) do
                if not ValidateSection(cctvData, "cctv") then return end

                Bridge.Target.addSphereZone({
                    coords     = vec3(cctvData.coords.x, cctvData.coords.y, cctvData.coords.z),
                    radius     = cctvData.radius or 1.0,
                    drawSprite = true,
                    debug      = Bridge.Config and Bridge.Config.Debug,
                    options    = {
                        {
                            name     = string.format("open_cctv_%s_%d", mapName, i),
                            label    = cctvData.label or locale("watch_cameras"),
                            icon     = "fa-solid fa-video",
                            distance = cctvData.distance or 2.0,
                            groups   = Config.Jobs,
                            onSelect = function()
                                exports[GetCurrentResourceName()]:cctvMenu()
                            end,
                        },
                    },
                })
            end
        end

        -- ── Duty points ────────────────────────────────────────────────────
        if mapData.duty then
            if not ValidateSection(mapData.duty, "duty") then return end

            for i, dutyData in ipairs(mapData.duty) do
                if not ValidateSection(dutyData, "duty") then return end

                local zoneId = string.format("%s_%d", mapName, i)

                local dutyOptions = {
                    {
                        name     = "go_on_duty_" .. zoneId,
                        label    = locale("go_on_duty"),
                        icon     = "fa-solid fa-clipboard-check",
                        distance = dutyData.distance or 2.0,
                        groups   = Config.Jobs,
                        onSelect = function()
                            TriggerServerEvent("p_policejob/server/toggleDuty", true)
                        end,
                    },
                    {
                        name     = "go_off_duty_" .. zoneId,
                        label    = locale("go_off_duty"),
                        icon     = "fa-solid fa-clipboard",
                        distance = dutyData.distance or 2.0,
                        groups   = Config.Jobs,
                        onSelect = function()
                            TriggerServerEvent("p_policejob/server/toggleDuty", false)
                        end,
                    },
                }

                if dutyData.ped then
                    -- Duty point has an NPC: use lib.points to spawn/despawn it on proximity
                    local point = lib.points.new({
                        coords   = vec3(dutyData.coords.x, dutyData.coords.y, dutyData.coords.z),
                        distance = 20,
                    })

                    point.onEnter = function(self)
                        -- Clean up any stale ped before spawning a new one
                        if self.ped and DoesEntityExist(self.ped) then
                            Bridge.Target.removeLocalEntity(self.ped, {
                                "go_on_duty_" .. zoneId,
                                "go_off_duty_" .. zoneId,
                            })
                            DeleteEntity(self.ped)
                            self.ped = nil
                        end
                        -- Pass dutyData.coords as fallback: duty-point peds have no
                        -- coords of their own, they spawn at the duty zone position
                        local ped = SpawnDutyPed(dutyData.ped, dutyData.coords)
                        if not ped then return end
                        SetEntityAsMissionEntity(ped, true, true)
                        Bridge.Target.addLocalEntity(ped, dutyOptions)
                        self.ped = ped
                    end

                    -- Re-spawn the ped if it was culled while the player is still in range
                    point.nearby = function(self)
                        if self.ped and not DoesEntityExist(self.ped) then
                            self.ped = nil
                            local ped = SpawnDutyPed(dutyData.ped, dutyData.coords)
                            if not ped then return end
                            SetEntityAsMissionEntity(ped, true, true)
                            Bridge.Target.addLocalEntity(ped, dutyOptions)
                            self.ped = ped
                        end
                    end

                    point.onExit = function(self)
                        if self.ped and DoesEntityExist(self.ped) then
                            Bridge.Target.removeLocalEntity(self.ped, {
                                "go_on_duty_" .. zoneId,
                                "go_off_duty_" .. zoneId,
                            })
                            DeleteEntity(self.ped)
                            self.ped = nil
                        end
                    end
                else
                    -- No NPC: plain sphere zone
                    Bridge.Target.addSphereZone({
                        coords     = vec3(dutyData.coords.x, dutyData.coords.y, dutyData.coords.z),
                        radius     = dutyData.radius or 1.0,
                        drawSprite = true,
                        debug      = Bridge.Config and Bridge.Config.Debug,
                        options    = dutyOptions,
                    })
                end
            end
        end

        -- ── Armoury points ─────────────────────────────────────────────────
        if mapData.armouries then
            if not ValidateSection(mapData.armouries, "armouries") then return end

            for i, armouryData in ipairs(mapData.armouries) do
                local armouryId = string.format("%s:%d", mapName, i)

                local armouryOptions = {
                    {
                        name     = "open_armoury_" .. armouryId,
                        label    = locale("open_armoury"),
                        icon     = "fa-solid fa-cart-shopping",
                        groups   = Config.Jobs,
                        onSelect = function()
                            Armoury:open(armouryId)
                        end,
                    },
                    {
                        name        = "manage_armoury_" .. armouryId,
                        label       = locale("manage_armoury"),
                        icon        = "fa-solid fa-gear",
                        groups      = Config.Jobs,
                        canInteract = function()
                            return Armoury:canManage()
                        end,
                        onSelect    = function()
                            Armoury:openManage(armouryId)
                        end,
                    },
                }

                local point = lib.points.new({
                    coords   = vec3(armouryData.coords.x, armouryData.coords.y, armouryData.coords.z),
                    distance = 20,
                })

                point.onEnter = function(self)
                    -- Clean up any stale ped before spawning a new one
                    if self.ped and DoesEntityExist(self.ped) then
                        Bridge.Target.removeLocalEntity(self.ped, {
                            "open_armoury_" .. armouryId,
                            "manage_armoury_" .. armouryId,
                        })
                        DeleteEntity(self.ped)
                        self.ped = nil
                    end
                    -- Armoury peds carry their own coords; pass armouryData.coords as fallback
                    local ped = SpawnDutyPed(armouryData.ped, armouryData.coords)
                    if not ped then return end
                    SetEntityAsMissionEntity(ped, true, true)
                    Bridge.Target.addLocalEntity(ped, armouryOptions)
                    self.ped = ped
                end

                -- Re-spawn the ped if it was culled while the player is still in range
                point.nearby = function(self)
                    if self.ped and not DoesEntityExist(self.ped) then
                        self.ped = nil
                        local ped = SpawnDutyPed(armouryData.ped, armouryData.coords)
                        if not ped then return end
                        SetEntityAsMissionEntity(ped, true, true)
                        Bridge.Target.addLocalEntity(ped, armouryOptions)
                        self.ped = ped
                    end
                end

                point.onExit = function(self)
                    if self.ped and DoesEntityExist(self.ped) then
                        Bridge.Target.removeLocalEntity(self.ped, {
                            "open_armoury_" .. armouryId,
                            "manage_armoury_" .. armouryId,
                        })
                        DeleteEntity(self.ped)
                        self.ped = nil
                    end
                end
            end
        end
    end

    -- ── Bell interaction zones ──────────────────────────────────────────────
    for i, bellData in ipairs(Config.DepartmentData.bells or {}) do
        Bridge.Target.addSphereZone({
            coords     = vec3(bellData.coords.x, bellData.coords.y, bellData.coords.z),
            radius     = bellData.radius or 0.75,
            drawSprite = true,
            debug      = Bridge.Config and Bridge.Config.Debug,
            options    = {
                {
                    name     = string.format("use_bell_%d", i),
                    label    = locale("use_bell"),
                    icon     = "fa-solid fa-bell",
                    distance = bellData.distance or 2.0,
                    onSelect = function()
                        TriggerServerEvent("p_policejob/server/departments/useBell", i)
                    end,
                },
            },
        })
    end
end)
