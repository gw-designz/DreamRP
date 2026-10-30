-- A player's job can arrive without its `type` (seen on Qbox: job=police,
-- type=nil), and every alert is addressed by type ('leo', 'ems'). Fill the
-- gap from qbx_core's job definitions, then from a name fallback.
local FALLBACK_TYPES = {
    police = 'leo', lspd = 'leo', bcso = 'leo', sasp = 'leo', sheriff = 'leo', statepolice = 'leo',
    ambulance = 'ems', ems = 'ems', fire = 'ems', doctor = 'ems',
}

local cache = {}

---@param job table|nil a PlayerData.job
---@return string|nil
function JobType(job)
    if type(job) ~= 'table' then return nil end
    if job.type and job.type ~= '' then return job.type end
    local name = job.name
    if not name then return nil end
    if cache[name] == nil then
        local ok, def = pcall(function() return exports.qbx_core:GetJob(name) end)
        cache[name] = (ok and type(def) == 'table' and def.type) or FALLBACK_TYPES[name] or false
    end
    return cache[name] or nil
end
