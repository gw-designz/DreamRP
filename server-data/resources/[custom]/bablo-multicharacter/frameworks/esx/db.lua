if Config.Framework ~= "esx" then return end

-- Migrations to run against the ESX `users` table on resource start.
local migrations = {
    [[ALTER TABLE `users`
        ADD COLUMN IF NOT EXISTS `playtime` INT NOT NULL DEFAULT 0;]],

    [[ALTER TABLE `users`
        ADD COLUMN IF NOT EXISTS `nationality` VARCHAR(50) DEFAULT 'United States of America';]],

    [[ALTER TABLE `users`
        MODIFY COLUMN `nationality` VARCHAR(50) DEFAULT 'United States of America';]],
}

MySQL.ready(function()
    Trace(("[Framework/ESX/db] Running %d migration(s)…"):format(#migrations))

    for i, sql in ipairs(migrations) do
        local ok, err = pcall(function() MySQL.query.await(sql) end)
        if not ok then
            Trace(("[Framework/ESX/db] Migration #%d failed: %s"):format(i, tostring(err)))
        end
    end

    Trace("[Framework/ESX/db] Migrations done.")
end)
