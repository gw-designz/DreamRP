-- Preserve an existing Playtime table across resource restarts (hot-reload safety).
if not Playtime then
    Playtime = { Sessions = {} }
end

local FLUSH_INTERVAL_MS = 300000  -- flush accumulated playtime every 5 minutes

-- Return the stored total playtime (in minutes) for citizenid, or 0.
function Playtime:Get(citizenid)
    return Framework:GetPlaytime(citizenid) or 0
end

-- Return total playtime for citizenid, adding the elapsed minutes of an active
-- session identified by src if that session belongs to the same citizenid.
function Playtime:GetWithSession(citizenid, src)
    local total = self:Get(citizenid)
    if not src then return total end

    local session = self.Sessions[src]
    if session and session.citizenid == citizenid then
        total = total + math.floor((os.time() - session.start) / 60)
    end
    return total
end

-- Begin tracking a playtime session for src / citizenid.
function Playtime:StartSession(src, citizenid)
    if not src or not citizenid then return end
    self.Sessions[src] = { citizenid = citizenid, start = os.time() }
    Trace(("[Playtime] Started session — src=%s citizenid=%s"):format(src, citizenid))
end

-- End the session for src, flushing elapsed minutes to the Framework if ≥ 1 min.
function Playtime:EndSession(src)
    local session = self.Sessions[src]
    if not session then return end

    local elapsed = math.floor((os.time() - session.start) / 60)
    if elapsed > 0 then
        Framework:AddPlaytime(session.citizenid, elapsed)
        Trace(("[Playtime] Ended session — src=%s citizenid=%s elapsed=%dm"):format(
            src, session.citizenid, elapsed))
    else
        Trace(("[Playtime] Ended session — src=%s citizenid=%s elapsed<1m (no flush)"):format(
            src, session.citizenid))
    end

    self.Sessions[src] = nil
end

-- Periodic flush: every FLUSH_INTERVAL_MS, write completed full minutes for every
-- active session and advance each session's start time by the flushed amount so
-- the next flush only counts new time.
CreateThread(function()
    while true do
        Wait(FLUSH_INTERVAL_MS)
        for src, session in pairs(Playtime.Sessions) do
            local elapsed = math.floor((os.time() - session.start) / 60)
            if elapsed >= 1 then
                Framework:AddPlaytime(session.citizenid, elapsed)
                session.start = session.start + elapsed * 60
                Trace(("[Playtime] Flushed %dm for citizenid=%s"):format(elapsed, session.citizenid))
            end
        end
    end
end)

AddEventHandler("playerDropped", function()
    Playtime:EndSession(source)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for src in pairs(Playtime.Sessions) do
        Playtime:EndSession(src)
    end
end)
