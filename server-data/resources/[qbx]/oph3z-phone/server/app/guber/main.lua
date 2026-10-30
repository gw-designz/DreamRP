-- Guber: ride hailing between players. Customers request a ride to a destination, online
-- drivers get the offer, the first to accept takes it. Fares are computed here from real
-- positions; on completion the customer is charged and the driver paid through the bank.
local CFG = Config.Guber or {}

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_guber_drivers` (
    `cid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) DEFAULT NULL,
    `rides` INT UNSIGNED NOT NULL DEFAULT 0,
    `rating_sum` INT UNSIGNED NOT NULL DEFAULT 0,
    `rating_count` INT UNSIGNED NOT NULL DEFAULT 0,
    `earned` BIGINT NOT NULL DEFAULT 0,
    `joined_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_guber_rides` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `driver_cid` VARCHAR(64) DEFAULT NULL,
    `driver_name` VARCHAR(64) DEFAULT NULL,
    `customer_cid` VARCHAR(64) NOT NULL,
    `customer_name` VARCHAR(64) DEFAULT NULL,
    `pickup` VARCHAR(64) DEFAULT NULL,
    `dropoff` VARCHAR(64) DEFAULT NULL,
    `fare` INT UNSIGNED NOT NULL DEFAULT 0,
    `paid` TINYINT(1) NOT NULL DEFAULT 0,
    `stars` TINYINT UNSIGNED DEFAULT NULL,
    `comment` VARCHAR(160) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_driver` (`driver_cid`, `id`),
    KEY `idx_customer` (`customer_cid`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local drivers = {}   -- src -> { cid, name, since, earned, rides }
local rides = {}     -- id -> ride
local bySrc = {}     -- src -> ride id (customer or driver)
local nextId = 0

local MILE = 1609.34

local function push(src, payload)
    if src then TriggerClientEvent('oph3z-phone:client:np:guber', src, payload) end
end

local function dist2d(a, b)
    if not a or not b then return 0 end
    local dx, dy = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local function fareFor(meters)
    local miles = meters / MILE
    local fare = (tonumber(CFG.BaseFare) or 25) + miles * (tonumber(CFG.PerMile) or 35)
    return math.max(tonumber(CFG.MinFare) or 25, math.floor(fare * 100 + 0.5) / 100)
end

local function zoneLabel(c)
    return ('%.0f, %.0f'):format(c.x, c.y)
end

local function publicRide(r, forSrc)
    if not r then return nil end
    return {
        id = r.id, state = r.state, fare = r.fare,
        miles = math.floor(r.meters / MILE * 100 + 0.5) / 100,
        pickup = { label = r.pickup.label, x = r.pickup.x, y = r.pickup.y },
        dropoff = { label = r.dropoff.label, x = r.dropoff.x, y = r.dropoff.y },
        customer = r.customerName, driver = r.driverName,
        role = forSrc == r.driverSrc and 'driver' or 'customer',
        expiresAt = r.expiresAt,
    }
end

local function driverRow(cid)
    return Sql.Single('SELECT * FROM `oph3z_phone_np_guber_drivers` WHERE `cid` = ?', { cid })
end

local function endRide(r, reason, notifyCustomer, notifyDriver)
    rides[r.id] = nil
    if bySrc[r.customerSrc] == r.id then bySrc[r.customerSrc] = nil end
    if r.driverSrc and bySrc[r.driverSrc] == r.id then bySrc[r.driverSrc] = nil end
    if notifyCustomer then push(r.customerSrc, { type = 'ended', reason = reason }) end
    if notifyDriver and r.driverSrc then push(r.driverSrc, { type = 'ended', reason = reason }) end
    for src in pairs(r.offered or {}) do
        if src ~= r.driverSrc then push(src, { type = 'offerGone', id = r.id }) end
    end
end

local function destinations(src)
    local here = NP.coords(src)
    local out = {}
    for i, d in ipairs(CFG.Destinations or {}) do
        local c = d.coords
        local m = here and dist2d(here, c) or 0
        out[#out + 1] = { index = i, label = d.label, x = c.x, y = c.y, miles = math.floor(m / MILE * 100 + 0.5) / 100, fare = fareFor(m) }
    end
    return out
end

local function session(src)
    local d = drivers[src]
    if not d then return nil end
    return { since = d.since, earned = d.earned, rides = d.rides, now = os.time() }
end

local function canDrive(src)
    if type(CFG.DriverJobs) == 'table' and next(CFG.DriverJobs) then return NP.hasJob(src, CFG.DriverJobs) end
    return true
end

NP.cb('guber:state', function(src, cid)
    Sql.Wait()
    local row = driverRow(cid)
    -- an offer that arrived while the app was closed
    local offer
    if drivers[src] and not bySrc[src] then
        for _, r in pairs(rides) do
            if r.state == 'requested' and r.offered[src] then offer = publicRide(r, src) break end
        end
    end
    return {
        ok = true,
        offer = offer,
        name = NP.name(src),
        destinations = destinations(src),
        ride = publicRide(rides[bySrc[src]], src),
        online = drivers[src] ~= nil,
        session = session(src),
        canDrive = canDrive(src),
        rating = row and row.rating_count > 0 and (row.rating_sum / row.rating_count) or nil,
    }
end)

NP.cb('guber:request', function(src, cid, data)
    if bySrc[src] then return { ok = false, reason = 'busy' } end
    if not NP.rate(src, 'guberreq', 5) then return { ok = false, reason = 'slow' } end
    local here = NP.coords(src)
    if not here then return { ok = false, reason = 'bad' } end
    local dest
    local idx = tonumber(data.index)
    if idx and CFG.Destinations and CFG.Destinations[idx] then
        local d = CFG.Destinations[idx]
        dest = { x = d.coords.x, y = d.coords.y, label = d.label }
    elseif CFG.AllowWaypoint ~= false and tonumber(data.x) and tonumber(data.y) then
        local x, y = tonumber(data.x), tonumber(data.y)
        if math.abs(x) > 8000 or y < -5000 or y > 9000 then return { ok = false, reason = 'bad' } end
        dest = { x = x, y = y, label = NP.clean(data.label, 64) ~= '' and NP.clean(data.label, 64) or 'Waypoint' }
    end
    if not dest then return { ok = false, reason = 'dest' } end
    local meters = dist2d(here, dest)
    if meters < 50 then return { ok = false, reason = 'close' } end
    local fare = fareFor(meters)
    if Bank.Get(cid) < fare then return { ok = false, reason = 'funds' } end

    nextId = nextId + 1
    local r = {
        id = nextId, state = 'requested', fare = fare, meters = meters,
        customerSrc = src, customerCid = cid, customerName = NP.name(src),
        pickup = { x = here.x, y = here.y, label = NP.clean(data.pickupLabel, 64) ~= '' and NP.clean(data.pickupLabel, 64) or zoneLabel(here) },
        dropoff = dest, offered = {}, createdAt = os.time(),
        expiresAt = os.time() + (tonumber(CFG.RequestTimeout) or 30),
    }
    rides[r.id] = r
    bySrc[src] = r.id

    local any = false
    for dsrc, d in pairs(drivers) do
        if dsrc ~= src and not bySrc[dsrc] then
            r.offered[dsrc] = true
            any = true
            push(dsrc, { type = 'offer', ride = publicRide(r, dsrc) })
            NP.notify(d.cid, 'guber', 'Guber Ride Request', 'New ride request available. Open Guber to accept or deny.')
        end
    end
    if not any then
        endRide(r, 'nodrivers', false, false)
        return { ok = false, reason = 'nodrivers' }
    end

    SetTimeout((tonumber(CFG.RequestTimeout) or 30) * 1000, function()
        local cur = rides[r.id]
        if cur and cur.state == 'requested' then
            endRide(cur, 'timeout', true, false)
            NP.notify(cid, 'guber', 'Guber', 'No driver accepted your ride. Try again.')
        end
    end)
    return { ok = true, ride = publicRide(r, src) }
end)

NP.cb('guber:cancel', function(src, cid)
    local r = rides[bySrc[src]]
    if not r then return { ok = true } end
    if r.state == 'pickedup' then return { ok = false, reason = 'inride' } end
    local byDriver = r.driverSrc == src
    endRide(r, byDriver and 'driver_cancelled' or 'customer_cancelled', byDriver, not byDriver)
    if byDriver then NP.notify(r.customerCid, 'guber', 'Guber', 'Your driver cancelled the ride.')
    elseif r.driverSrc then NP.notify(drivers[r.driverSrc] and drivers[r.driverSrc].cid, 'guber', 'Guber', 'The customer cancelled the ride.') end
    return { ok = true }
end)

NP.cb('guber:online', function(src, cid, data)
    if data.on == true then
        if not canDrive(src) then return { ok = false, reason = 'job' } end
        if not drivers[src] then
            Sql.Wait()
            local name = NP.name(src)
            Sql.Execute('INSERT INTO `oph3z_phone_np_guber_drivers` (`cid`, `name`, `joined_at`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `name` = VALUES(`name`)', { cid, name, os.time() })
            drivers[src] = { cid = cid, name = name, since = os.time(), earned = 0, rides = 0 }
            NP.notify(cid, 'guber', 'Guber', 'You’re online. Waiting for ride requests.')
        end
    else
        if bySrc[src] and rides[bySrc[src]] and rides[bySrc[src]].driverSrc == src then return { ok = false, reason = 'inride' } end
        if drivers[src] then NP.notify(cid, 'guber', 'Guber', 'You’re offline.') end
        drivers[src] = nil
    end
    return { ok = true, online = drivers[src] ~= nil, session = session(src) }
end)

NP.cb('guber:accept', function(src, cid, data)
    local d = drivers[src]
    local r = rides[tonumber(data.id)]
    if not d then return { ok = false, reason = 'offline' } end
    if not r or r.state ~= 'requested' then return { ok = false, reason = 'taken' } end
    if bySrc[src] then return { ok = false, reason = 'busy' } end
    if r.customerSrc == src then return { ok = false, reason = 'own' } end
    r.state = 'accepted'
    r.driverSrc, r.driverCid, r.driverName = src, cid, d.name
    bySrc[src] = r.id
    for osrc in pairs(r.offered) do
        if osrc ~= src then push(osrc, { type = 'offerGone', id = r.id }) end
    end
    push(r.customerSrc, { type = 'update', ride = publicRide(r, r.customerSrc) })
    NP.notify(r.customerCid, 'guber', 'Guber', ('%s accepted your ride and is on the way.'):format(d.name))
    NP.notify(cid, 'guber', 'Guber', 'Ride accepted. Proceed to pickup location.')
    return { ok = true, ride = publicRide(r, src), waypoint = { x = r.pickup.x, y = r.pickup.y } }
end)

NP.cb('guber:decline', function(src, cid, data)
    local r = rides[tonumber(data.id)]
    if r and r.offered then r.offered[src] = nil end
    return { ok = true }
end)

NP.cb('guber:pickup', function(src, cid)
    local r = rides[bySrc[src]]
    if not r or r.driverSrc ~= src or r.state ~= 'accepted' then return { ok = false, reason = 'bad' } end
    local a, b = NP.coords(src), NP.coords(r.customerSrc)
    if not a or not b or #(a - b) > (tonumber(CFG.PickupDistance) or 12.0) then return { ok = false, reason = 'far' } end
    r.state = 'pickedup'
    push(r.customerSrc, { type = 'update', ride = publicRide(r, r.customerSrc) })
    NP.notify(cid, 'guber', 'Guber', 'Customer has entered your vehicle. Proceed to the drop-off location.')
    return { ok = true, ride = publicRide(r, src), waypoint = { x = r.dropoff.x, y = r.dropoff.y } }
end)

NP.cb('guber:complete', function(src, cid)
    local r = rides[bySrc[src]]
    if not r or r.driverSrc ~= src or r.state ~= 'pickedup' then return { ok = false, reason = 'bad' } end
    local here = NP.coords(src)
    if not here or dist2d(here, r.dropoff) > (tonumber(CFG.CompleteDistance) or 80.0) then return { ok = false, reason = 'far' } end
    local paid = NP.charge(r.customerCid, math.floor(r.fare), 'Guber', ('Ride to %s'):format(r.dropoff.label))
    local earn = 0
    if paid then
        earn = math.floor(r.fare * (1 - (tonumber(CFG.CommissionPercent) or 0) / 100))
        NP.pay(cid, earn, 'Guber', ('Fare from %s'):format(r.customerName))
    end
    Sql.Wait()
    local rideId = Sql.Insert(
        'INSERT INTO `oph3z_phone_np_guber_rides` (`driver_cid`, `driver_name`, `customer_cid`, `customer_name`, `pickup`, `dropoff`, `fare`, `paid`, `ts`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { cid, r.driverName, r.customerCid, r.customerName, r.pickup.label, r.dropoff.label, math.floor(r.fare), paid and 1 or 0, os.time() })
    Sql.Execute('UPDATE `oph3z_phone_np_guber_drivers` SET `rides` = `rides` + 1, `earned` = `earned` + ? WHERE `cid` = ?', { earn, cid })
    local d = drivers[src]
    if d then
        d.rides = d.rides + 1
        d.earned = d.earned + earn
    end
    endRide(r, 'completed', false, false)
    push(r.customerSrc, { type = 'completed', rideId = rideId, fare = math.floor(r.fare), paid = paid, driver = r.driverName })
    if paid then
        NP.notify(cid, 'guber', 'Guber', ('Earned $%s for completing the ride.'):format(earn))
    else
        NP.notify(cid, 'guber', 'Guber', 'The customer couldn’t pay for this ride.')
    end
    return { ok = true, paid = paid, earned = earn, session = session(src) }
end)

NP.cb('guber:rate', function(src, cid, data)
    local id = tonumber(data.rideId)
    local stars = math.floor(tonumber(data.stars) or 0)
    if not id or stars < 1 or stars > 5 then return { ok = false, reason = 'bad' } end
    Sql.Wait()
    local ride = Sql.Single('SELECT `driver_cid`, `stars` FROM `oph3z_phone_np_guber_rides` WHERE `id` = ? AND `customer_cid` = ?', { id, cid })
    if not ride or ride.stars then return { ok = false, reason = 'bad' } end
    Sql.Execute('UPDATE `oph3z_phone_np_guber_rides` SET `stars` = ?, `comment` = ? WHERE `id` = ?', { stars, NP.clean(data.comment, 160), id })
    Sql.Execute('UPDATE `oph3z_phone_np_guber_drivers` SET `rating_sum` = `rating_sum` + ?, `rating_count` = `rating_count` + 1 WHERE `cid` = ?', { stars, ride.driver_cid })
    return { ok = true }
end)

NP.cb('guber:profile', function(src, cid, data)
    Sql.Wait()
    local asDriver = data.role == 'driver'
    local row = driverRow(cid)
    local history
    if asDriver then
        history = Sql.Query('SELECT `id`, `customer_name` AS `name`, `pickup`, `dropoff`, `fare`, `stars`, `ts` FROM `oph3z_phone_np_guber_rides` WHERE `driver_cid` = ? ORDER BY `id` DESC LIMIT 30', { cid })
    else
        history = Sql.Query('SELECT `id`, `driver_name` AS `name`, `pickup`, `dropoff`, `fare`, `stars`, `ts` FROM `oph3z_phone_np_guber_rides` WHERE `customer_cid` = ? ORDER BY `id` DESC LIMIT 30', { cid })
    end
    local feedback = asDriver and Sql.Query(
        'SELECT `customer_name` AS `name`, `stars`, `comment`, `ts` FROM `oph3z_phone_np_guber_rides` WHERE `driver_cid` = ? AND `stars` IS NOT NULL ORDER BY `id` DESC LIMIT 20', { cid }) or {}
    return {
        ok = true,
        name = NP.name(src),
        rating = row and row.rating_count > 0 and (row.rating_sum / row.rating_count) or nil,
        rides = row and row.rides or 0,
        joinedAt = row and row.joined_at or nil,
        history = history,
        feedback = feedback,
    }
end)

AddEventHandler('playerDropped', function()
    local src = source
    drivers[src] = nil
    local r = rides[bySrc[src]]
    if r then
        if r.customerSrc == src then
            endRide(r, 'customer_left', false, true)
        else
            endRide(r, 'driver_left', true, false)
        end
    end
    bySrc[src] = nil
end)
