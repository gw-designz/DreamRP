-- Adds / removes the DM Tool button in the radial menu (default: codera-radialmenu).
-- The choice is remembered per player (resource KVP) and re-applied after reconnects and after
-- either resource restarts, because the radial menu only keeps its dynamic options in memory.

DmRadial = { enabled = false }

local KVP = 'npv_admin:dmRadial'
local OPTION_KEY = 'npv_dm_tool'

local function radialRunning()
    return GetResourceState(Config.Radial.resource) == 'started'
end

local function push(on)
    local res = Config.Radial.resource
    if on then
        exports[res]:AddOption({
            id = OPTION_KEY,
            title = Config.Radial.title,
            icon = Config.Radial.icon,
            type = 'command',
            event = 'npv_dm', -- registered in client/main.lua; the server still checks the staff rank
            shouldClose = true,
        }, OPTION_KEY)
    else
        exports[res]:RemoveOption(OPTION_KEY)
    end
end

local function announce()
    Nui.Send('hud', { dmRadial = DmRadial.enabled })
end

---Re-apply the saved choice. `staff` false clears the button.
function DmRadial.Sync(staff)
    DmRadial.enabled = GetResourceKvpInt(KVP) == 1
    if not radialRunning() then announce() return end
    pcall(push, staff and DmRadial.enabled)
    if not staff then DmRadial.enabled = false end
    announce()
end

---Called by the "DM Tool" command (already authorised by the server).
function DmRadial.Toggle()
    if not radialRunning() then
        if Config.Radial.fallbackOpenDirectly then
            Nui.Close()
            Wait(50)
            Nui.Open('dm')
        else
            lib.notify({ type = 'error', description = ('%s is not running.'):format(Config.Radial.resource) })
        end
        return
    end
    DmRadial.enabled = not DmRadial.enabled
    SetResourceKvpInt(KVP, DmRadial.enabled and 1 or 0)
    local ok = pcall(push, DmRadial.enabled)
    if not ok then
        lib.notify({ type = 'error', description = 'Could not update the radial menu.' })
        return
    end
    announce()
    lib.notify({ type = 'inform', description = DmRadial.enabled and 'DM Tool added to your radial menu.' or 'DM Tool removed from your radial menu.' })
end

AddEventHandler('onResourceStart', function(res)
    if res ~= Config.Radial.resource then return end
    Wait(1000)
    local staff = lib.callback.await('npv_admin:isStaff', false) == true
    DmRadial.Sync(staff)
end)
