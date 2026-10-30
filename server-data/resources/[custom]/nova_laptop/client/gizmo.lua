--[[
    object_gizmo, with a cursor you can see.

    object_gizmo uses FiveM's cursor mode, whose cursor does not draw on every
    client (it is invisible here even in its own /testGizmo), though the mouse
    still works the gizmo. While the gizmo is up this draws a cursor where the
    mouse is: the NUI layer's idea of it or the game's, whichever is moving.
]]

LaptopGizmo = {}

local function drawCursor(x, y)
    local ratio = GetAspectRatio(false)
    -- An arrow-ish pointer: a black edge, then white, tip at (x, y).
    for _, layer in ipairs({ { 0.011, 0, 0, 0 }, { 0.008, 255, 255, 255 } }) do
        local size = layer[1]
        DrawRect(x + size / 2, y + size * ratio / 2, size, size * ratio, layer[2], layer[3], layer[4], 255)
    end
    DrawRect(x + 0.0012, y + 0.0012 * ratio, 0.0024, 0.0024 * ratio, 225, 30, 50, 255)
end

--- Same as exports.object_gizmo:useGizmo(entity), but with a cursor drawn.
function LaptopGizmo.use(entity)
    local active = true
    CreateThread(function()
        local x, y = 0.5, 0.5
        local lastNui, lastGame
        while active do
            local nx, ny = GetNuiCursorPosition()
            local width, height = GetActiveScreenResolution()
            local nui = vector2(nx / width, ny / height)
            local game = vector2(GetDisabledControlNormal(0, 239), GetDisabledControlNormal(0, 240))
            if lastNui and #(nui - lastNui) > 0.0001 then x, y = nui.x, nui.y
            elseif lastGame and #(game - lastGame) > 0.0001 then x, y = game.x, game.y end
            lastNui, lastGame = nui, game
            drawCursor(x, y)
            Wait(0)
        end
    end)
    local ok, result = pcall(function() return exports.object_gizmo:useGizmo(entity) end)
    active = false
    if not ok then print(('[nova_laptop] object_gizmo failed: %s'):format(result)) return nil end
    return result
end
