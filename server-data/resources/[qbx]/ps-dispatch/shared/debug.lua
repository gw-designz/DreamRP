-- Trace output for following an alert through every gate (Config.Debug).
-- Client lines land in F8 / CitizenFX.log, server lines in the server console.
function DispatchTrace(...)
    if not Config.Debug then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    print('^3[ps-dispatch trace]^7 ' .. table.concat(parts, ' '))
end
