lib.locale(Bridge?.Config?.Language or 'en')

Config = {}

-- You can add your map in maps/departments/ and maps/prison/ folders, then add the name of the map in the Config below. You can also add multiple maps by using a table instead of a string, for example: {'fm-mrpd', 'other-map'}
---@field Config.DepartmentMap: string | table [name of map which you want to use]
Config.DepartmentMap = 'lspd_mrpd'

---@field Config.PrisonMap: string | table [name of map which you want to use]
Config.PrisonMap = 'prompts-prison'

Config.MDT = {
    ---@field enabled: boolean [show the MDT option in the police radial menu]
    enabled = true,

    ---@field system: string [which MDT to open from the radial menu]
    -- 'auto'        - picks the first started resource from the list in editable/client.lua (Editable.mdtSystems)
    -- 'p_mdt'       - https://pscripts-store.com
    -- 'lb-tablet'   - LB Tablet (opens the tablet)
    -- 'tk_mdt'      - TK Scripts MDT (opens the police UI)
    -- 'ps-mdt'      - Project Sloth MDT (runs the /mdt command)
    -- 'redutzu-mdt' - Redutzu MDT
    -- 'custom'      - always use customOpen below
    system = 'auto',

    ---@field customOpen: function [open logic used when system = 'custom' (or when 'auto' finds no known MDT). Put your own export/event/command here]
    customOpen = function()
        ExecuteCommand('mdt')
    end,
}

---@field Config.Jobs: table [jobs that can access police features - aggregated from the `jobs` field of every loaded department map]
-- Define the allowed jobs per map via the top-level `jobs = { [jobName] = minGrade }`
-- table inside each maps/departments/*.lua file. They are merged below (keeping
-- the lowest required grade when a job appears in more than one map).
Config.Jobs = {}

-- do not touch it at all!
Config.DepartmentData = {
    extras = {},
    laboratories = {},
    vehicleShops = {},
    mugshots = {},
    garages = {},
    bodycams = {},
    bells = {},
}

local maps = type(Config.DepartmentMap) == 'table' and Config.DepartmentMap or { Config.DepartmentMap }
for _, mapName in ipairs(maps) do
    local data = lib.load(('maps.departments.%s'):format(mapName))
    if type(data) == 'table' then
        if data.jobs then
            for jobName, grade in pairs(data.jobs) do
                if Config.Jobs[jobName] == nil or grade < Config.Jobs[jobName] then
                    Config.Jobs[jobName] = grade
                end
            end
        end
        if data.extras then
            for _, v in ipairs(data.extras) do
                Config.DepartmentData.extras[#Config.DepartmentData.extras + 1] = v
            end
        end
        if data.laboratories then
            for _, v in ipairs(data.laboratories) do
                Config.DepartmentData.laboratories[#Config.DepartmentData.laboratories + 1] = v
            end
        end
        if data.vehicleShops then
            for k, v in pairs(data.vehicleShops) do
                Config.DepartmentData.vehicleShops[k] = v
            end
        end
        if data.mugshots then
            for k, v in pairs(data.mugshots) do
                Config.DepartmentData.mugshots[k] = v
            end
        end
        if data.garages then
            for k, v in pairs(data.garages) do
                Config.DepartmentData.garages[k] = v
            end
        end
        if data.bodycams then
            for k, v in pairs(data.bodycams) do
                Config.DepartmentData.bodycams[k] = v
            end
        end
        if data.bells then
            for _, v in ipairs(data.bells) do
                Config.DepartmentData.bells[#Config.DepartmentData.bells + 1] = v
            end
        end
    end
end