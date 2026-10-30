-- Property / Real Estate: buy listings from Config.Property.Listings with bank money, give keys,
-- sell back. This tracks ownership for the phone; Config.Property.OnPurchase / OnSell let a
-- housing resource grant / revoke the real interior.
local CFG = Config.Property or {}

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_property_owners` (
    `property_id` VARCHAR(48) NOT NULL,
    `cid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) DEFAULT NULL,
    `price` INT UNSIGNED NOT NULL DEFAULT 0,
    `bought_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`property_id`),
    KEY `idx_cid` (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_property_keys` (
    `property_id` VARCHAR(48) NOT NULL,
    `cid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`property_id`, `cid`),
    KEY `idx_cid` (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local function listing(id)
    for _, l in ipairs(CFG.Listings or {}) do
        if l.id == id then return l end
    end
    return nil
end

local function ownerOf(id)
    return Sql.Single('SELECT `cid`, `name`, `bought_at` FROM `oph3z_phone_np_property_owners` WHERE `property_id` = ?', { id })
end

local function hook(fn, ...)
    if type(fn) == 'function' then
        local ok, err = pcall(fn, ...)
        if not ok then print(('^1[oph3z-phone] Config.Property hook failed: %s^0'):format(tostring(err))) end
    end
end

NP.cb('prop:list', function(src, cid)
    Sql.Wait()
    local owners, keys = {}, {}
    for _, r in ipairs(Sql.Query('SELECT `property_id`, `cid`, `bought_at` FROM `oph3z_phone_np_property_owners`')) do owners[r.property_id] = r end
    for _, r in ipairs(Sql.Query('SELECT `property_id` FROM `oph3z_phone_np_property_keys` WHERE `cid` = ?', { cid })) do keys[r.property_id] = true end
    local out = {}
    for _, l in ipairs(CFG.Listings or {}) do
        local o = owners[l.id]
        local c = l.coords
        out[#out + 1] = {
            id = l.id, label = l.label, description = l.description or '', type = l.type or 'residential',
            zone = l.zone or '', street = l.street or '', price = l.price or 0, garage = l.garage or 0,
            size = l.size or 0, listing = l.listing or 'open', image = l.image, realtor = l.realtor or 'None',
            x = c and c.x or nil, y = c and c.y or nil,
            sold = o ~= nil, mine = o ~= nil and o.cid == cid, hasKey = keys[l.id] == true,
            boughtAt = o and o.cid == cid and o.bought_at or nil,
        }
    end
    return { ok = true, listings = out, sellBack = tonumber(CFG.SellBackPercent) or 0 }
end)

NP.cb('prop:buy', function(src, cid, data)
    local l = listing(tostring(data.id or ''))
    if not l then return { ok = false, reason = 'gone' } end
    if not NP.rate(src, 'propbuy', 3) then return { ok = false, reason = 'slow' } end
    Sql.Wait()
    if ownerOf(l.id) then return { ok = false, reason = 'sold' } end
    local owned = tonumber(Sql.Scalar('SELECT COUNT(*) FROM `oph3z_phone_np_property_owners` WHERE `cid` = ?', { cid })) or 0
    if owned >= (tonumber(CFG.MaxOwned) or 3) then return { ok = false, reason = 'limit' } end
    -- reserve first (primary key) so two buyers can't both pay for the same property
    local n = Sql.Execute('INSERT IGNORE INTO `oph3z_phone_np_property_owners` (`property_id`, `cid`, `name`, `price`, `bought_at`) VALUES (?, ?, ?, ?, ?)',
        { l.id, cid, NP.name(src), l.price or 0, os.time() })
    if (tonumber(n) or 0) == 0 then return { ok = false, reason = 'sold' } end
    if (l.price or 0) > 0 and not NP.charge(cid, l.price, 'Dynasty 8 Real Estate', l.label) then
        Sql.Execute('DELETE FROM `oph3z_phone_np_property_owners` WHERE `property_id` = ? AND `cid` = ?', { l.id, cid })
        return { ok = false, reason = 'funds' }
    end
    hook(CFG.OnPurchase, src, cid, l)
    return { ok = true }
end)

NP.cb('prop:sell', function(src, cid, data)
    local l = listing(tostring(data.id or ''))
    if not l then return { ok = false, reason = 'gone' } end
    local pct = tonumber(CFG.SellBackPercent) or 0
    if pct <= 0 then return { ok = false, reason = 'disabled' } end
    Sql.Wait()
    local o = ownerOf(l.id)
    if not o or o.cid ~= cid then return { ok = false, reason = 'owner' } end
    local n = Sql.Execute('DELETE FROM `oph3z_phone_np_property_owners` WHERE `property_id` = ? AND `cid` = ?', { l.id, cid })
    if (tonumber(n) or 0) == 0 then return { ok = false, reason = 'owner' } end
    Sql.Execute('DELETE FROM `oph3z_phone_np_property_keys` WHERE `property_id` = ?', { l.id })
    local amount = math.floor((l.price or 0) * pct / 100)
    if amount > 0 then NP.pay(cid, amount, 'Dynasty 8 Real Estate', 'Sold ' .. l.label) end
    hook(CFG.OnSell, src, cid, l)
    return { ok = true, amount = amount }
end)

NP.cb('prop:keys', function(src, cid, data)
    Sql.Wait()
    local o = ownerOf(tostring(data.id or ''))
    if not o or o.cid ~= cid then return { ok = false, reason = 'owner' } end
    return { ok = true, keys = Sql.Query('SELECT `cid`, `name`, `ts` FROM `oph3z_phone_np_property_keys` WHERE `property_id` = ?', { data.id }) }
end)

NP.cb('prop:giveKey', function(src, cid, data)
    local id = tostring(data.id or '')
    Sql.Wait()
    local o = ownerOf(id)
    if not o or o.cid ~= cid then return { ok = false, reason = 'owner' } end
    local digits = DB.Digits(data.number or '')
    local target = digits ~= '' and DB.GetCitizenIdByNumber(digits) or nil
    if not target then return { ok = false, reason = 'notfound' } end
    if target == cid then return { ok = false, reason = 'self' } end
    local count = tonumber(Sql.Scalar('SELECT COUNT(*) FROM `oph3z_phone_np_property_keys` WHERE `property_id` = ?', { id })) or 0
    if count >= (tonumber(CFG.MaxKeyholders) or 5) then return { ok = false, reason = 'limit' } end
    local p = DB.Player(target)
    Sql.Execute('INSERT IGNORE INTO `oph3z_phone_np_property_keys` (`property_id`, `cid`, `name`, `ts`) VALUES (?, ?, ?, ?)', { id, target, p and p.name or digits, os.time() })
    local l = listing(id)
    NP.notify(target, 'property', 'Property', ('You received keys to %s.'):format(l and l.label or 'a property'))
    hook(CFG.OnKeyChange, src, cid, l, target, true)
    return { ok = true }
end)

NP.cb('prop:removeKey', function(src, cid, data)
    local id = tostring(data.id or '')
    Sql.Wait()
    local o = ownerOf(id)
    if not o or o.cid ~= cid then return { ok = false, reason = 'owner' } end
    Sql.Execute('DELETE FROM `oph3z_phone_np_property_keys` WHERE `property_id` = ? AND `cid` = ?', { id, tostring(data.cid or '') })
    hook(CFG.OnKeyChange, src, cid, listing(id), tostring(data.cid or ''), false)
    return { ok = true }
end)

NP.cb('prop:locate', function(src, cid, data)
    local l = listing(tostring(data.id or ''))
    if not l or not l.coords then return { ok = false, reason = 'nolocation' } end
    return { ok = true, x = l.coords.x, y = l.coords.y }
end)

-- Other resources can ask who owns / holds keys to a property.
exports('GetPropertyOwner', function(id)
    local o = ownerOf(id)
    return o and o.cid or nil
end)

exports('HasPropertyAccess', function(id, citizenid)
    local o = ownerOf(id)
    if o and o.cid == citizenid then return true end
    return Sql.Scalar('SELECT 1 FROM `oph3z_phone_np_property_keys` WHERE `property_id` = ? AND `cid` = ?', { id, citizenid }) ~= nil
end)
