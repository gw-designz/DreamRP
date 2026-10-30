if Config.Framework ~= "qbcore" then return end

local migrations = {
    [[ALTER TABLE `players`
        ADD COLUMN IF NOT EXISTS `playtime` INT(11) NOT NULL DEFAULT 0;]],
}

MySQL.ready(function()
    Trace(("[Framework/QBCore/db] Running %d migration(s)…"):format(#migrations))

    for i, sql in ipairs(migrations) do
        local ok, err = pcall(function() MySQL.query.await(sql) end)
        if not ok then
            Trace(("[Framework/QBCore/db] Migration #%d failed: %s"):format(i, tostring(err)))
        end
    end

    Trace("[Framework/QBCore/db] Migrations done.")
end)
