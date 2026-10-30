local inFlight = false
local function clip(value, length)
    value = tostring(value or '')
    if utf8.len(value) and utf8.len(value) > length then return value:sub(1, utf8.offset(value, length + 1) - 1) .. '…' end
    return value
end
local function plain(value, length)
    return clip(tostring(value or ''):gsub('([\\*_~|>])', '\\%1'), length)
end

function Jobs.WebhookPayload(item, app)
    local fields = {
        { name = 'Business / role', value = plain(app.company .. ' — ' .. app.title, 160), inline = false },
        { name = 'Applicant', value = plain(app.applicantName, 80), inline = true },
        { name = 'In-game contact', value = plain(app.contact, 80), inline = true },
        { name = 'Availability', value = plain(app.availability, 240), inline = false }
    }
    if item.event == 'application' then
        fields[#fields + 1] = { name = 'Application', value = plain(app.cover, 800), inline = false }
        if app.experience ~= '' then fields[#fields + 1] = { name = 'Experience', value = plain(app.experience, 600), inline = false } end
        for _, answer in ipairs(app.answers) do
            fields[#fields + 1] = { name = clip(answer.question, 100), value = plain(answer.answer, 420), inline = false }
        end
    else
        fields[#fields + 1] = { name = 'Status', value = item.status:gsub('_', ' '), inline = true }
        if item.message and item.message ~= '' then fields[#fields + 1] = { name = 'Update', value = plain(item.message, 500), inline = false } end
    end
    return { username = 'Nova Jobs Hub', allowed_mentions = { parse = {} },
        embeds = {{ title = item.event == 'application' and 'New job application' or 'Application update',
            color = item.event == 'application' and 6512095 or 1747056, fields = fields,
            footer = { text = 'Event ' .. item.id .. ' • Review and hire inside Jobs Hub' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ', math.floor(item.at / 1000)) }} }
end

function Jobs.WebhookURL(job)
    local settings = Config.Jobs.Webhook
    local convar = settings.JobConvars[job] or settings.DefaultConvar
    local url = GetConvar(convar, '')
    if url:match('^https://discord%.com/api/webhooks/%d+/[%w%._%-]+$')
        or url:match('^https://discordapp%.com/api/webhooks/%d+/[%w%._%-]+$') then return url end
    return nil
end

function Jobs.PumpWebhook()
    if inFlight or not Config.Jobs.Enabled or not Config.Jobs.Webhook.Enabled then return end
    local item, app = Jobs.WebhookNext()
    if not item then return end
    local url = Jobs.WebhookURL(item.job)
    if not url then Jobs.WebhookResult(item.id, false, 60); return end
    inFlight = true
    local payload = json.encode(Jobs.WebhookPayload(item, app))
    -- Cfx may encode an empty Lua table as an object; Discord needs an array.
    payload = payload:gsub('"parse"%s*:%s*{}', '"parse":[]')
    local called = false
    local function completed(status, body, headers)
        if called then return end
        called = true
        local success = status >= 200 and status < 300
        local retry
        if status == 429 then
            local ok, data = pcall(json.decode, body or '')
            retry = ok and type(data) == 'table' and tonumber(data.retry_after) or tonumber((headers or {})['retry-after'])
        end
        local function persist()
            local result = Jobs.WebhookResult(item.id, success, retry)
            if not result.ok then SetTimeout(500, persist) else inFlight = false end
        end
        persist()
    end
    local ok = pcall(PerformHttpRequest, url, completed, 'POST', payload, { ['Content-Type'] = 'application/json' }, { followLocation = false })
    if not ok then completed(0, '', {}) end
    -- Ambiguous timeouts may retry; stable event IDs identify duplicate deliveries.
    SetTimeout(20000, function() if not called then completed(0, '', {}) end end)
end

CreateThread(function()
    while true do
        Wait(2000)
        local ok = pcall(Jobs.PumpWebhook)
        if not ok then print('[nova_laptop] Jobs webhook worker failed; check its configuration.') end
    end
end)
