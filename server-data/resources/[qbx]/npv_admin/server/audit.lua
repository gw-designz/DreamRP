Audit = {}

local function license(src)
    return GetPlayerIdentifierByType(src, 'license') or 'unknown'
end

---Record a privileged action. `target` is a server id (optional).
function Audit.Log(src, action, outcome, target, details)
    local targetCid, targetName
    if target and target > 0 then
        targetName = GetPlayerName(target)
        targetCid = Players.CitizenId(target)
    end
    details = details and json.encode(details) or nil
    local staffName = src > 0 and GetPlayerName(src) or 'console'

    MySQL.insert('INSERT INTO npv_admin_audit (staff_license, staff_name, action, target_citizenid, target_name, outcome, details) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { src > 0 and license(src) or 'console', staffName or 'unknown', action, targetCid, targetName, outcome, details })

    if Config.Webhook and Config.Webhook ~= '' then
        PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
            username = 'npv_admin',
            embeds = {{
                title = ('%s — %s'):format(action, outcome),
                color = outcome == 'ok' and 3066993 or 15158332,
                description = ('**Staff:** %s\n**Target:** %s%s'):format(
                    staffName or '?', targetName or 'n/a', details and ('\n```' .. details:sub(1, 900) .. '```') or ''),
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            }},
        }), { ['Content-Type'] = 'application/json' })
    end
end
