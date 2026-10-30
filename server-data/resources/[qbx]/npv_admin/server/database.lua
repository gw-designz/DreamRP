DB = {}

-- Runs sql/install.sql statements on start so a fresh server needs no manual import.
CreateThread(function()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if not sql then
        print('^1[npv_admin] sql/install.sql missing^7')
        return
    end
    sql = sql:gsub('%-%-[^\n]*', '') -- strip comments (including trailing ones)
    for statement in sql:gmatch('[^;]+;') do
        if statement:match('%S') then MySQL.query.await(statement) end
    end
    if Config.AuditRetentionDays > 0 then
        MySQL.query.await('DELETE FROM npv_admin_audit WHERE created_at < (NOW() - INTERVAL ? DAY)', { Config.AuditRetentionDays })
    end
    DB.ready = true
    print('^2[npv_admin] database ready^7')
end)

function DB.WaitReady()
    while not DB.ready do Wait(100) end
end
