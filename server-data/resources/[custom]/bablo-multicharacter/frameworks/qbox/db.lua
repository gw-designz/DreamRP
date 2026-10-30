if Config.Framework ~= "qbox" then return end

local migrations = {
    [[ALTER TABLE `players`
        ADD COLUMN IF NOT EXISTS `playtime` INT(11) NOT NULL DEFAULT 0;]],
}

MySQL.ready(function()
    Trace(("[Framework/qbox/db] Running %d migration(s)…"):format(#migrations))

    for i, sql in ipairs(migrations) do
        local ok, err = pcall(function() MySQL.query.await(sql) end)
        if not ok then
            Trace(("[Framework/qbox/db] Migration #%d failed: %s"):format(i, tostring(err)))
        end
    end

    Trace("[Framework/qbox/db] Migrations done.")
end)
