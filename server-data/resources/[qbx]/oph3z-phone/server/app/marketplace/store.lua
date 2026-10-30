Market = Market or {}

Market.Categories = { ads = true, cars = true, items = true, houses = true, other = true }
-- Lemon List categories (Config.LemonList.Categories) are valid too; those ads may be text-only.
Market.TextOnly = {}
for _, c in ipairs((Config.LemonList and Config.LemonList.Categories) or {}) do
    if type(c) == 'table' and type(c.id) == 'string' then
        Market.Categories[c.id] = true
        Market.TextOnly[c.id] = true
    end
end

local COLUMNS = '`id`, `seller_cid`, `category`, `title`, `description`, `price`, `media`, `seller`, ' ..
    '`allow_calls`, `allow_msg`, `created_at`, `updated_at`'

local function hydrate(row)
    if not row then return nil end
    return {
        id         = row.id,
        sellerCid  = row.seller_cid,
        category   = row.category,
        title      = row.title,
        desc       = row.description or '',
        price      = tonumber(row.price) or 0,
        media      = Sql.Decode(row.media, {}),
        seller     = Sql.Decode(row.seller, {}),
        allowCalls = Sql.Bool(row.allow_calls),
        allowMsg   = Sql.Bool(row.allow_msg),
        createdAt  = row.created_at,
        updatedAt  = row.updated_at,
    }
end

local function cleanMedia(media)
    local out = {}
    if type(media) ~= 'table' then return out end
    for _, m in ipairs(media) do
        if type(m) == 'table' and type(m.url) == 'string' and m.url:match('^https?://') then
            out[#out + 1] = {
                url   = m.url,
                type  = (m.type == 'video') and 'video' or 'image',
                thumb = (type(m.thumb) == 'string' and m.thumb:match('^https?://')) and m.thumb or nil,
            }
            if #out >= 10 then break end
        end
    end
    return out
end

local function normCategory(c)
    c = tostring(c or ''):lower()
    return Market.Categories[c] and c or 'other'
end

local function clampPrice(p)
    p = tonumber(p) or 0
    if p < 0 then p = 0 end
    if p > 9999999999 then p = 9999999999 end
    return math.floor(p)
end

function Market.Get(id)
    if id == nil then return nil end
    Sql.Wait()
    return hydrate(Sql.Single(
        ('SELECT %s FROM `oph3z_phone_listings` WHERE `id` = ?'):format(COLUMNS),
        { tonumber(id) }
    ))
end

function Market.List(filter)
    Sql.Wait()
    local out = {}
    for _, row in ipairs(Sql.Query(
        ('SELECT %s FROM `oph3z_phone_listings` ORDER BY `created_at` DESC'):format(COLUMNS)
    )) do
        local listing = hydrate(row)
        if not filter or filter(listing) then out[#out + 1] = listing end
    end
    return out
end

function Market.Create(sellerCid, seller, data)
    if not sellerCid or type(data) ~= 'table' then return nil, 'bad' end
    local category = normCategory(data.category)
    local textOnly = Market.TextOnly[category] == true
    local title = tostring(data.title or ''):sub(1, 80)
    if textOnly and title:gsub('%s', '') == '' then title = tostring(data.desc or ''):sub(1, 80) end
    if title:gsub('%s', '') == '' then return nil, 'title' end
    local media = cleanMedia(data.media)
    if #media == 0 and not textOnly then return nil, 'media' end
    local allowCalls = data.allowCalls == true
    local allowMsg   = data.allowMsg == true
    if textOnly and not allowCalls and not allowMsg then allowCalls, allowMsg = true, true end
    if not allowCalls and not allowMsg then return nil, 'contact' end
    local maxAds = tonumber(Config.LemonList and Config.LemonList.MaxAdsPerPlayer) or 0
    if textOnly and maxAds > 0 then
        Sql.Wait()
        local n = tonumber(Sql.Scalar('SELECT COUNT(*) FROM `oph3z_phone_listings` WHERE `seller_cid` = ?', { sellerCid })) or 0
        if n >= maxAds then return nil, 'limit' end
    end

    Sql.Wait()
    local now = os.time()
    local l = {
        sellerCid = sellerCid,
        category = category,
        title = title,
        desc = tostring(data.desc or ''):sub(1, 1200),
        price = clampPrice(data.price),
        media = media,
        seller = seller,
        allowCalls = allowCalls,
        allowMsg = allowMsg,
        createdAt = now,
        updatedAt = now,
    }

    l.id = Sql.Insert(
        'INSERT INTO `oph3z_phone_listings` (`seller_cid`, `category`, `title`, `description`, `price`, ' ..
        '`media`, `seller`, `allow_calls`, `allow_msg`, `created_at`, `updated_at`) ' ..
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        {
            l.sellerCid, l.category, l.title, l.desc, l.price,
            Sql.Encode(l.media), Sql.Encode(l.seller),
            l.allowCalls and 1 or 0, l.allowMsg and 1 or 0, now, now,
        }
    )
    if not l.id then return nil, 'bad' end
    return l, nil
end

function Market.Update(l, seller, data)
    if not l or type(data) ~= 'table' then return nil, 'bad' end
    if data.title ~= nil then
        local title = tostring(data.title):sub(1, 80)
        if title:gsub('%s', '') == '' then return nil, 'title' end
        l.title = title
    end
    if data.category ~= nil then l.category = normCategory(data.category) end
    if data.desc ~= nil then l.desc = tostring(data.desc):sub(1, 1200) end
    if data.price ~= nil then l.price = clampPrice(data.price) end
    if data.media ~= nil then
        local media = cleanMedia(data.media)
        if #media == 0 then return nil, 'media' end
        l.media = media
    end
    if data.allowCalls ~= nil then l.allowCalls = data.allowCalls == true end
    if data.allowMsg ~= nil then l.allowMsg = data.allowMsg == true end
    if not l.allowCalls and not l.allowMsg then return nil, 'contact' end
    if seller then l.seller = seller end
    l.updatedAt = os.time()
    Market.Save(l)
    return l, nil
end

function Market.Save(l)
    if not l or not l.id then return end
    Sql.Wait()
    Sql.Execute(
        'UPDATE `oph3z_phone_listings` SET `category` = ?, `title` = ?, `description` = ?, `price` = ?, ' ..
        '`media` = ?, `seller` = ?, `allow_calls` = ?, `allow_msg` = ?, `updated_at` = ? WHERE `id` = ?',
        {
            l.category, l.title, l.desc, l.price,
            Sql.Encode(l.media), Sql.Encode(l.seller),
            l.allowCalls and 1 or 0, l.allowMsg and 1 or 0,
            l.updatedAt or os.time(), l.id,
        }
    )
end

function Market.Delete(id)
    if id == nil then return end
    Sql.Wait()
    Sql.Execute('DELETE FROM `oph3z_phone_listings` WHERE `id` = ?', { tonumber(id) })
end