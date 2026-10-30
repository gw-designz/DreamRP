-- In-world editor for the DM tool: local (client-only) preview entities for the scenario being
-- edited, a selection ring, labels, and ray-cast placement. Nothing here is networked or saved;
-- the draft lives in the NUI and is persisted through the server on Save.

Editor = { draft = {}, selected = nil, labels = true, placing = false }

local ClientCalls = Nui.ClientCalls
local syncVersion = 0
local previews = {} -- [objectId] = { entity, model, kind }

---The local preview ped/object for a draft object id (used by the appearance camera).
function Editor.Preview(id)
    local p = previews[id]
    return p and p.entity or nil
end

local function rotationToDirection(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local cx = math.abs(math.cos(x))
    return vec3(-math.sin(z) * cx, math.cos(z) * cx, math.sin(x))
end

local function animScenario(id)
    for _, a in ipairs(Config.NpcAnimations) do
        if a.id == id then return a.scenario end
    end
end

local function applyPedState(ped, def)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    FreezeEntityPosition(ped, true)
    ClearPedTasksImmediately(ped)
    local scenario = def.anim and animScenario(def.anim)
    if scenario then TaskStartScenarioInPlace(ped, scenario, 0, true) end
end

local function destroyPreview(id)
    local p = previews[id]
    if p and DoesEntityExist(p.entity) then DeleteEntity(p.entity) end
    previews[id] = nil
end

local function createPreview(def, version)
    if def.kind == 'trigger' or def.kind == 'rope' or def.world or not def.model then -- nothing to preview (existing map doors have no model of ours)
        previews[def.id] = { entity = 0, kind = def.kind }
        return
    end
    local hash = joaat(def.model)
    if not IsModelInCdimage(hash) then return end
    if not lib.requestModel(hash, 5000) then return end
    if version ~= syncVersion then return end -- a newer sync superseded this one
    local c = def.coords
    local ent
    if def.kind == 'npc' then
        ent = CreatePed(4, hash, c.x, c.y, c.z, c.h + 0.0, false, false)
        if ent ~= 0 then
            applyPedState(ent, def)
            if Appearance.IsFreemodeName(def.model) then Appearance.Apply(ent, def.appearance or {}) end
        end
    else
        ent = CreateObjectNoOffset(hash, c.x, c.y, c.z, false, false, false)
        if ent ~= 0 then
            SetEntityHeading(ent, c.h + 0.0)
            FreezeEntityPosition(ent, true)
        end
    end
    SetModelAsNoLongerNeeded(hash)
    if ent ~= 0 then previews[def.id] = { entity = ent, model = def.model, kind = def.kind, anim = def.anim, look = def.appearance and json.encode(def.appearance) or '' } end
end

local function sync(objects, selected)
    syncVersion = syncVersion + 1
    local version = syncVersion
    Editor.selected = selected
    local wanted = {}
    for _, d in ipairs(objects) do wanted[d.id] = d end
    Editor.draft = wanted

    for id in pairs(previews) do
        if not wanted[id] then destroyPreview(id) end
    end
    CreateThread(function()
        for id, def in pairs(wanted) do
            if version ~= syncVersion then return end
            local p = previews[id]
            if p and (p.model ~= def.model or p.kind ~= def.kind) then
                destroyPreview(id)
                p = nil
            end
            if not p then
                createPreview(def, version)
            elseif p.entity ~= 0 and DoesEntityExist(p.entity) then
                local c = def.coords
                SetEntityCoordsNoOffset(p.entity, c.x, c.y, c.z, false, false, false)
                SetEntityHeading(p.entity, c.h + 0.0)
                if def.kind == 'npc' and p.anim ~= def.anim then
                    p.anim = def.anim
                    applyPedState(p.entity, def)
                end
                -- Appearance edits show up live on the preview ped.
                if def.kind == 'npc' and Appearance.IsFreemodeName(def.model) then
                    local look = def.appearance and json.encode(def.appearance) or ''
                    if p.look ~= look then
                        p.look = look
                        Appearance.Apply(p.entity, def.appearance or {})
                        applyPedState(p.entity, def)
                    end
                end
            end
        end
    end)
end

local function drawLabel(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.0, 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

-- Draw loop: only runs while a draft exists and the DM tool is the active view.
CreateThread(function()
    while true do
        if next(Editor.draft) and Editor.active then
            for id, def in pairs(Editor.draft) do
                local c = def.coords
                if def.kind == 'rope' then
                    -- Preview of where the rope hangs: a line from the anchor down its length.
                    local len = def.length or 20.0
                    DrawLine(c.x, c.y, c.z, c.x, c.y, c.z - len, 255, 200, 40, 220)
                    DrawMarker(1, c.x, c.y, c.z - 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 200, 40, 200, false, false, 2, false, nil, nil, false)
                end
                if def.kind == 'trigger' and def.size then
                    local hx, hy, hz = def.size.x / 2, def.size.y / 2, def.size.z / 2
                    DrawBox(c.x - hx, c.y - hy, c.z, c.x + hx, c.y + hy, c.z + def.size.z, 40, 200, 240, id == Editor.selected and 70 or 35)
                end
                if id == Editor.selected then
                    DrawMarker(25, c.x, c.y, c.z + 0.03, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 1.2, 40, 200, 240, 200, false, false, 2, false, nil, nil, false)
                end
                if id == Editor.selected and def.patrol and #def.patrol > 0 then
                    for i, p in ipairs(def.patrol) do
                        DrawMarker(1, p.x, p.y, p.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.3, 255, 200, 40, 170, false, false, 2, false, nil, nil, false)
                        local nxt = def.patrol[i % #def.patrol + 1]
                        DrawLine(p.x, p.y, p.z + 0.2, nxt.x, nxt.y, nxt.z + 0.2, 255, 200, 40, 200)
                        drawLabel(p.x, p.y, p.z + 0.6, tostring(i))
                    end
                end
                if Editor.labels then drawLabel(c.x, c.y, c.z + (def.kind == 'npc' and 1.1 or 0.6), def.label or def.id) end
            end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- Placement ---------------------------------------------------------------------------------------
local function raycast()
    local cam = GetGameplayCamCoord()
    local dir = rotationToDirection(GetGameplayCamRot(2))
    local dest = cam + dir * 80.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 1 | 2 | 16, PlayerPedId(), 7)
    local _, hit, coords = GetShapeTestResult(ray)
    return hit == 1 and coords or nil
end

-- Picking an existing door (map / MLO): aim at it and press Enter. The door under the crosshair is outlined.
local function entityUnder()
    local cam = GetGameplayCamCoord()
    local dir = rotationToDirection(GetGameplayCamRot(2))
    local dest = cam + dir * 25.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 1 | 16, PlayerPedId(), 7)
    local _, hit, hitAt, _, entityHit = GetShapeTestResult(ray)
    if hit ~= 1 then return nil end
    if entityHit and entityHit ~= 0 and GetEntityType(entityHit) == 3 then return entityHit end
    -- The ray hit the building: find the smallest object whose box contains the point instead.
    local best, bestVol
    for _, e in ipairs(GetGamePool('CObject')) do
        if #(GetEntityCoords(e) - hitAt) < 8.0 then
            local mn, mx = GetModelDimensions(GetEntityModel(e))
            local l = GetOffsetFromEntityGivenWorldCoords(e, hitAt.x, hitAt.y, hitAt.z)
            local pad = 0.2
            if l.x >= mn.x - pad and l.x <= mx.x + pad and l.y >= mn.y - pad and l.y <= mx.y + pad and l.z >= mn.z - pad and l.z <= mx.z + pad then
                local vol = (mx.x - mn.x) * (mx.y - mn.y) * (mx.z - mn.z)
                if not bestVol or vol < bestVol then best, bestVol = e, vol end
            end
        end
    end
    return best
end

local function pickDoorLoop()
    Editor.placing = true
    Nui.Send('placement', { active = true, kind = 'worlddoor' })
    local result, marked
    while Editor.placing do
        DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 257, true)
        DisableControlAction(0, 200, true) DisableControlAction(0, 177, true)
        local e = entityUnder()
        if e ~= marked then
            if marked and DoesEntityExist(marked) then SetEntityDrawOutline(marked, false) end
            marked = e
            if e then
                SetEntityDrawOutlineColor(40, 200, 240, 255)
                SetEntityDrawOutlineShader(1)
                SetEntityDrawOutline(e, true)
            end
        end
        if e and (IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201)) then
            local c = GetEntityCoords(e)
            local mn, mx = GetModelDimensions(GetEntityModel(e))
            local mid = GetOffsetFromEntityInWorldCoords(e, (mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
            result = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(e), hash = GetEntityModel(e), ax = mid.x, ay = mid.y, az = mid.z }
            break
        end
        if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then break end -- Backspace / Esc
        Wait(0)
    end
    if marked and DoesEntityExist(marked) then SetEntityDrawOutline(marked, false) end
    Editor.placing = false
    Nui.Send('placement', { active = false, kind = 'worlddoor', result = result })
    if Nui.open then Nui.Focus(true) Nui.Blur(true) end
end

local function placeLoop(kind, model, size, length)
    Editor.placing = true
    local ghost
    local heading = GetEntityHeading(PlayerPedId())
    local lift = 0.0
    local hash = model and joaat(model)
    if kind ~= 'trigger' and kind ~= 'patrol' and kind ~= 'rope' then
        if not lib.requestModel(hash, 5000) then Editor.placing = false return end
        local c = GetEntityCoords(PlayerPedId())
        if kind == 'npc' then
            ghost = CreatePed(4, hash, c.x, c.y, c.z, heading, false, false)
            SetEntityInvincible(ghost, true)
            FreezeEntityPosition(ghost, true)
        else
            ghost = CreateObjectNoOffset(hash, c.x, c.y, c.z, false, false, false)
            FreezeEntityPosition(ghost, true)
        end
        SetEntityCollision(ghost, false, false)
        SetEntityAlpha(ghost, 150, false)
        SetModelAsNoLongerNeeded(hash)
    end

    Nui.Send('placement', { active = true, kind = kind })
    local result
    local coords = GetEntityCoords(PlayerPedId())
    while Editor.placing do
        DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
        DisableControlAction(0, 14, true) DisableControlAction(0, 15, true)
        DisableControlAction(0, 142, true) DisableControlAction(0, 257, true)
        DisableControlAction(0, 44, true) DisableControlAction(0, 38, true)

        local hit = raycast()
        if hit then coords = hit end
        if IsDisabledControlPressed(0, 15) then heading = (heading + 3.0) % 360.0 end -- scroll up
        if IsDisabledControlPressed(0, 14) then heading = (heading - 3.0) % 360.0 end -- scroll down
        if IsDisabledControlPressed(0, 38) then lift = lift + 0.02 end -- E up
        if IsDisabledControlPressed(0, 44) then lift = lift - 0.02 end -- Q down

        if ghost then
            SetEntityCoordsNoOffset(ghost, coords.x, coords.y, coords.z + lift, false, false, false)
            SetEntityHeading(ghost, heading)
            if kind ~= 'npc' and lift == 0.0 then PlaceObjectOnGroundProperly(ghost) end
        else
            if kind == 'patrol' then
                DrawMarker(1, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.6, 0.6, 0.4, 40, 200, 240, 160, false, false, 2, false, nil, nil, false)
            elseif kind == 'rope' then
                local top = coords.z + lift
                DrawLine(coords.x, coords.y, top, coords.x, coords.y, top - (length or 20.0), 255, 200, 40, 220)
                DrawMarker(1, coords.x, coords.y, top - 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 200, 40, 200, false, false, 2, false, nil, nil, false)
            else
                local hx, hy = (size and size.x or 3.0) / 2, (size and size.y or 3.0) / 2
                DrawBox(coords.x - hx, coords.y - hy, coords.z, coords.x + hx, coords.y + hy, coords.z + (size and size.z or 3.0), 40, 200, 240, 60)
            end
        end

        if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201) then -- Enter
            local final = ghost and GetEntityCoords(ghost) or vec3(coords.x, coords.y, coords.z + lift)
            result = { x = final.x, y = final.y, z = final.z, h = heading }
            break
        end
        DisableControlAction(0, 200, true) DisableControlAction(0, 177, true)
        if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then break end -- Backspace / Esc
        Wait(0)
    end

    if ghost and DoesEntityExist(ghost) then DeleteEntity(ghost) end
    Editor.placing = false
    Nui.Send('placement', { active = false, kind = kind, result = result })
    if Nui.open then Nui.Focus(true) Nui.Blur(true) end
end

ClientCalls['editor.sync'] = function(p)
    Editor.active = true
    sync(type(p.objects) == 'table' and p.objects or {}, p.selected)
    return true
end

ClientCalls['editor.stop'] = function()
    Editor.active = false
    sync({}, nil)
    return true
end

ClientCalls['editor.labels'] = function(p)
    Editor.labels = p.on == true
    return true
end

ClientCalls['editor.place'] = function(p)
    if Editor.placing then return { ok = false, error = 'already_placing' } end
    local kind, model = p.kind, p.model
    if p.world then
        Nui.Focus(false)
        Nui.Blur(false)
        CreateThread(pickDoorLoop)
        return { ok = true }
    end
    if kind ~= 'trigger' and kind ~= 'patrol' and kind ~= 'rope' then
        if type(model) ~= 'string' or not IsModelInCdimage(joaat(model)) then
            return { ok = false, error = 'unknown_model' }
        end
    end
    Nui.Focus(false)
    Nui.Blur(false)
    CreateThread(function() placeLoop(kind, model, p.size, tonumber(p.length)) end)
    return { ok = true }
end

ClientCalls['editor.cancelPlace'] = function()
    Editor.placing = false
    return true
end

ClientCalls['coords.get'] = function(p)
    if p.mode == 'waypoint' then
        local blip = GetFirstBlipInfoId(8)
        if not DoesBlipExist(blip) then return nil end
        local c = GetBlipInfoIdCoord(blip)
        local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, 1000.0, false)
        return { x = c.x, y = c.y, z = ok and gz or c.z, h = 0.0 }
    elseif p.mode == 'aim' then
        local hit = raycast()
        if not hit then return nil end
        return { x = hit.x, y = hit.y, z = hit.z, h = 0.0 }
    end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z - 1.0, h = GetEntityHeading(ped) }
end

ClientCalls['coords.ground'] = function(p)
    local x, y, z = tonumber(p.x) or 0.0, tonumber(p.y) or 0.0, tonumber(p.z) or 0.0
    RequestCollisionAtCoord(x, y, z)
    local ok, gz = GetGroundZFor_3dCoord(x, y, z + 50.0, false)
    return ok and gz or nil
end

ClientCalls['clipboard'] = function(p)
    if type(p.text) == 'string' then lib.setClipboard(p.text:sub(1, 2000)) end
    return true
end

ClientCalls['model.valid'] = function(p)
    if type(p.model) ~= 'string' or not p.model:match('^[%w_]+$') then return false end
    local hash = joaat(p.model)
    return IsModelInCdimage(hash) and IsModelValid(hash)
end

-- DM tool "Go to": move the staff member next to an item they are editing.
ClientCalls['teleport.self'] = function(p)
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if not (x and y and z) then return false end
    SetEntityCoords(PlayerPedId(), x, y, z + 0.5, false, false, false, false)
    return true
end

AddEventHandler('npv_admin:client:closed', function()
    Editor.placing = false
    Editor.active = false
    sync({}, nil)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(previews) do destroyPreview(id) end
end)
