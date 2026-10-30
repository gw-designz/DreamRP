JobsBridge = {}

local function member(list, value)
    for _, item in ipairs(list or {}) do if item == value then return true end end
    return false
end

local function coreFor(mode)
    if mode == 'qb' then return exports['qb-core']:GetCoreObject() end
    if mode == 'esx' then return exports.es_extended:getSharedObject() end
end

function JobsBridge.Catalog(context)
    local raw
    if context.framework == 'qbox' then raw = exports.qbx_core:GetJobs()
    elseif context.framework == 'qb' then raw = coreFor('qb').Shared.Jobs
    elseif context.framework == 'esx' then raw = coreFor('esx').GetJobs()
    else return {} end
    local catalog = {}
    for name, job in pairs(raw or {}) do
        local grades = {}
        for index, grade in pairs(job.grades or {}) do
            local level = tonumber(index)
            if level and level % 1 == 0 and level >= 0 then
                grades[level] = { level = level, label = grade.label or grade.name or ('Grade ' .. level),
                    boss = grade.isboss == true or (context.framework == 'esx' and Config.Jobs.ESXBossGradeNames[grade.name] == true),
                    pay = tonumber(grade.payment or grade.salary) or 0 }
            end
        end
        catalog[name] = { name = name, label = job.label or name, grades = grades }
    end
    return catalog
end

function JobsBridge.Business(context, name)
    if type(name) ~= 'string' or Config.Jobs.ExcludedJobs[name] then return nil end
    local rules = Config.Jobs.Businesses[name] or {}
    if rules.enabled == false then return nil end
    local job = JobsBridge.Catalog(context)[name]
    if not job then return nil end
    local result = { name = name, label = rules.label or job.label, grades = {} }
    for _, level in ipairs(rules.hireGrades or Config.Jobs.DefaultHireGrades) do
        local grade = job.grades[level]
        -- Boss grades remain forbidden even if accidentally allowlisted.
        if grade and not grade.boss and not member(rules.bossGrades, level) then
            result.grades[#result.grades + 1] = { level = level, label = grade.label, pay = grade.pay }
        end
    end
    table.sort(result.grades, function(a, b) return a.level < b.level end)
    return result
end

function JobsBridge.Authority(context)
    if not context.job then return nil end
    local business = JobsBridge.Business(context, context.job)
    if not business then return nil end
    local rules = Config.Jobs.Businesses[context.job] or {}
    local grade = JobsBridge.Catalog(context)[context.job].grades[context.grade]
    if not grade or not (grade.boss or member(rules.bossGrades, context.grade)) then return nil end
    local allowed = {}
    for _, hire in ipairs(business.grades) do
        if hire.level < context.grade then allowed[#allowed + 1] = hire end
    end
    business.grades = allowed
    return business
end

function JobsBridge.CanHire(context, job, grade)
    local authority = JobsBridge.Authority(context)
    if not authority or authority.name ~= job then return false end
    for _, item in ipairs(authority.grades) do if item.level == grade then return true end end
    return false
end

function JobsBridge.CurrentJob(context)
    local catalog = JobsBridge.Catalog(context)
    return { name = context.job or 'unemployed', grade = context.grade or 0,
        label = catalog[context.job] and catalog[context.job].label or context.job or 'Unemployed' }
end

function JobsBridge.Find(key)
    for _, value in ipairs(GetPlayers()) do
        local src = tonumber(value)
        local context = Bridge.Context(src)
        if context and context.key == key then return src, context end
    end
end

function JobsBridge.Assign(src, expectedKey, job, grade)
    local context = Bridge.Context(src)
    if not context or context.key ~= expectedKey then return false, 'Applicant disconnected or changed character.' end
    local result
    if context.framework == 'qbox' then
        -- Supported QBox API: replace the current primary job, activate the new job.
        result = exports.qbx_core:SetJob(src, job, grade)
    elseif context.framework == 'qb' then
        result = context.player.Functions.SetJob(job, grade)
    elseif context.framework == 'esx' then
        context.player.setJob(job, grade)
    else return false, 'Framework job assignment is unavailable.' end
    local after = Bridge.Context(src)
    if not after or after.key ~= expectedKey then error('Character changed while assigning the job.') end
    if after.job ~= job or after.grade ~= grade then
        if result == false then return false, 'The framework declined this job change.' end
        error('Framework job assignment could not be verified.')
    end
    if context.framework == 'qb' and type(after.player.Functions.Save) == 'function' then after.player.Functions.Save() end
    -- QBox SetJob requests its own save. ESX retains its normal save lifecycle.
    -- A custom durable save hook may be supplied by the server owner.
    if type(Config.Jobs.PersistPlayer) == 'function' then Config.Jobs.PersistPlayer(after) end
    return true
end
