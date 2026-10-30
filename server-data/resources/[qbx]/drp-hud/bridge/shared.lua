Bridge = {}

local function running(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

local function detect()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if running('qbx_core') then return 'qbox' end
    if running('qb-core') then return 'qb' end
    if running('es_extended') then return 'esx' end
    return 'standalone'
end

Bridge.name = detect()

function Bridge.debug(...)
    if Config.Debug then print(('[my-hud:%s]'):format(Bridge.name), ...) end
end

Bridge.debug('framework detected')
