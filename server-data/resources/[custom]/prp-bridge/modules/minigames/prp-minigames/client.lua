local minigames = {}

---@param gameName string
---@param gameOptions table?
---@param otherOptions OtherOptions?
---@return boolean
function minigames.play(gameName, gameOptions, otherOptions)
    return exports["prp-minigames"]:Start(gameName, gameOptions, otherOptions)
end

function minigames.stop()
    return exports["prp-minigames"]:Stop()
end

---@return boolean
function minigames.isPlaying()
    return exports["prp-minigames"]:IsPlaying()
end

return minigames
