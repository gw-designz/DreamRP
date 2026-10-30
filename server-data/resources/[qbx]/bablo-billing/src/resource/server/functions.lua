-- ============================================================
-- functions.lua  –  bablo-billing  (server)
-- ============================================================

-- ── useReceivedInvoice ────────────────────────────────────────
-- Looks up a single invoice by ID.
-- In DEBUG mode, searches MockData; otherwise returns nil (live DB lookup expected elsewhere).
-- Returns: { success=true, data=invoice } or nil.
function useReceivedInvoice(invoiceId)
    if not invoiceId then
        Debug.error(Debug, "No invoice ID provided")
        return nil
    end

    local invoice = nil

    if Config.DEBUG then
        invoice = tbl.find(MockData.mockInvoices, function(entry)
            return entry.id == invoiceId
        end)
    end

    if not invoice then
        Debug.error(Debug, "Invoice not found for ID:", invoiceId)
        return nil
    end

    Debug.info(Debug, "Received invoice data", invoice)
    return { success = true, data = invoice }
end

-- ── getNearbyPlayersInRadius ──────────────────────────────────
-- Returns a list of players within `radius` units of `sourcePlayer`.
-- Each entry: { source, coords, distance, identifier, characterName }
-- Returns nil if no players are found.
function getNearbyPlayersInRadius(sourcePlayer, radius)
    radius = radius or 5.0

    local sourceCoords = GetEntityCoords(GetPlayerPed(sourcePlayer))
    local nearby       = {}

    for _, playerId in ipairs(GetPlayers()) do
        local ped    = GetPlayerPed(playerId)
        local coords = GetEntityCoords(ped)

        Debug.info(Debug, "Checking player", playerId, "at coords", coords)
        Debug.info(Debug, "Player source", sourcePlayer, "at coords", sourceCoords)

        local dist = #(sourceCoords - coords)

        if dist <= radius then
            local playerSource = tonumber(playerId)

            if playerSource ~= sourcePlayer then
                local identifier    = Core.getIdentifier(playerSource)
                local characterName = Core.getCharacterName(playerSource) or "Unknown Player"

                table.insert(nearby, {
                    source        = playerSource,
                    coords        = coords,
                    distance      = #(sourceCoords - coords),
                    identifier    = identifier,
                    characterName = characterName,
                })
            end
        end
    end

    if #nearby == 0 then
        Debug.info(Debug, "No players found within radius of", radius)
        return nil
    end

    Debug.info(Debug, "Found", #nearby, "players within radius of", radius)
    return nearby
end
