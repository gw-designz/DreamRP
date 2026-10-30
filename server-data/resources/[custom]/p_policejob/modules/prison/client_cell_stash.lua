if not (Config and Config.Prison and Config.Prison.Enabled) then return end
if not (Config.Prison.CellStash and Config.Prison.CellStash.enabled) then return end

local cellStashCfg = Config.Prison.CellStash

-- Registered target zone handles (cleaned up on resource stop)
local registeredZones = {}

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function RemoveCellStashZone(zone)
    if not zone then return end
    if Bridge.Target and Bridge.Target.removeSphereZone then
        pcall(Bridge.Target.removeSphereZone, zone)
    end
end

local function CleanupAllZones()
    for _, zone in ipairs(registeredZones) do
        RemoveCellStashZone(zone)
    end
    registeredZones = {}
end

-- Opens the cell stash for the given cell id if the local player is in that cell
local function OpenCellStash(cellId)
    if not (Prison and Prison.isInPrison and Prison.cellId == cellId) then
        return Bridge.Notify.showNotify(locale("cell_stash_no_access"), "error")
    end

    TriggerServerEvent("p_policejob/server/prison/cellStash/open", cellId)
    Citizen.Wait(150)

    Bridge.Inventory.openInventory("stash", {
        id    = "p_policejob_cell",
        owner = tostring(cellId),
    })
end

-- ─── Zone Registration ────────────────────────────────────────────────────────

local function RegisterCellStashZones()
    CleanupAllZones()

    if not (Prison and Prison.Map and Prison.Map.cells) then return end

    local offset = cellStashCfg.offset or vec3(0.0, 0.0, -0.2)
    local radius = tonumber(cellStashCfg.radius) or 0.5

    for _, cell in ipairs(Prison.Map.cells) do
        local stashPos = cell.stash
            or vector3(
                cell.coords.x + offset.x,
                cell.coords.y + offset.y,
                cell.coords.z + offset.z
            )

        local cellId = cell.id

        local zone = Bridge.Target.addSphereZone({
            coords = vector3(stashPos.x, stashPos.y, stashPos.z),
            radius = radius,
            debug  = Bridge.Config and Bridge.Config.Debug,
            options = {
                {
                    name     = string.format("p_policejob_cell_stash_%d", cellId),
                    label    = cellStashCfg.label or "Hidden Stash",
                    icon     = cellStashCfg.icon  or "fa-solid fa-box-archive",
                    distance = 1.2,
                    onSelect = function()
                        OpenCellStash(cellId)
                    end,
                },
            },
        })

        registeredZones[#registeredZones + 1] = zone
    end
end

-- ─── Init Thread ─────────────────────────────────────────────────────────────

CreateThread(function()
    while not (Prison and Prison.Map and Prison.Map.cells) do
        Wait(250)
    end
    RegisterCellStashZones()
end)

-- ─── Cleanup ─────────────────────────────────────────────────────────────────

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CleanupAllZones()
    end
end)
