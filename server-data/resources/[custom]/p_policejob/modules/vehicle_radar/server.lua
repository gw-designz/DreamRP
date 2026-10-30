if not (Config.VehicleRadar and Config.VehicleRadar.enabled) then return end

-- Server side of the vehicle radar is intentionally minimal.
-- All radar processing happens on the client. The server file
-- exists to satisfy the fxmanifest server_script entry and to
-- provide a place for future server-side radar events.
