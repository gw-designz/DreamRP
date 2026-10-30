local sound = {}

---@param fileName string
---@param volume number
---@param noAutoPath boolean? This lets you decide, if you want prp-bridge to search for sounds in `sounds` folder of resource.
function sound.play(fileName, volume, noAutoPath)
    exports["prp-bridge"]:PlaySound(fileName, volume, noAutoPath)
end

---@param fileName string
---@param volume number
---@param coords vector3
---@param distance number Max distance where the sound can be heard.
---@param shouldMuffle boolean? Whether the sound should be muffled when behind walls.
---@param noAutoPath boolean? This lets you decide, if you want prp-bridge to search for sounds in `sounds` folder of resource.
function sound.playSpatial(fileName, volume, coords, distance, shouldMuffle, noAutoPath)
    exports["prp-bridge"]:PlaySpatialSound(fileName, volume, coords, distance, shouldMuffle, noAutoPath)
end

return sound
