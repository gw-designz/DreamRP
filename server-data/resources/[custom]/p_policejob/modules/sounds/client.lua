Sounds = {}

-- Sends a NUI message to play a named sound at the given volume (default 0.5).
function Sounds.playSound(self, name, volume)
    SendNUIMessage({
        action = "playSound",
        data   = {
            name   = name,
            volume = volume or 0.5,
        },
    })
end
