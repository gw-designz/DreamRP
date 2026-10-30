local sound = {}

---@param src number | string
---@param fileName string
---@param volume number
---@param noAutoPath boolean? This lets you decide, if you want prp-bridge to search for sounds in `sounds` folder of resource.
function sound.play(src, fileName, volume, noAutoPath)
    local resourceName = GetCurrentResourceName()
    ---@diagnostic disable-next-line: param-type-mismatch
    TriggerClientEvent("prp-bridge:sound:play", src, fileName, volume, noAutoPath, resourceName)
end

---@param src number | string
---@param fileName string
---@param volume number
---@param coords vector3
---@param distance number Max distance where the sound can be heard.
---@param shouldMuffle boolean? Whether the sound should be muffled when behind walls.
---@param noAutoPath boolean? This lets you decide, if you want prp-bridge to search for sounds in `sounds` folder of resource.
function sound.playSpatial(src, fileName, volume, coords, distance, shouldMuffle, noAutoPath)
    local resourceName = GetCurrentResourceName()
    ---@diagnostic disable-next-line: param-type-mismatch
    TriggerClientEvent("prp-bridge:sound:playSpatial", src, fileName, volume, coords, distance, shouldMuffle, noAutoPath, resourceName)
end

return sound
