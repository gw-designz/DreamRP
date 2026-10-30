X = X or {}

local MAX_NOTIFS = 60

local accountCache = nil
local postCache = nil

local function countKeys(t)
    local n = 0
    if type(t) == 'table' then for _ in pairs(t) do n = n + 1 end end
    return n
end

X.countKeys = countKeys

local function hashPassword(salt, password)
    local data = tostring(salt) .. ':' .. tostring(password)
    local h = 0xcbf29ce484222325
    for round = 1, 1200 do
        for i = 1, #data do
            h = h ~ data:byte(i)
            h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
        end
        h = h ~ (round * 0x9E3779B97F4A7C15)
        h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    end
    return ('%016x'):format(h)
end

local function randomSalt()
    local hex = '0123456789abcdef'
    local out = {}
    for i = 1, 16 do
        local n = math.random(1, 16)
        out[i] = hex:sub(n, n)
    end
    return table.concat(out)
end

local function loadAccounts()
    if accountCache then return accountCache end

    Sql.Wait()
    local out = {}
    for _, row in ipairs(Sql.Query('SELECT * FROM `oph3z_phone_twexa_accounts`')) do
        out[tostring(row.id)] = {
            id        = row.id,
            handle    = row.handle,
            name      = row.name,
            email     = row.email,
            passSalt  = row.pass_salt,
            passHash  = row.pass_hash,
            bio       = row.bio or '',
            avatar    = row.avatar,
            banner    = row.banner,
            badge     = row.badge,
            verified  = false,
            createdAt = row.created_at,
            lastCid   = row.last_cid,
            following = {},
            followers = {},
            bookmarks = {},
            mutes     = {},
            blocks    = {},
        }
    end

    for _, row in ipairs(Sql.Query('SELECT `account_id`, `target_id` FROM `oph3z_phone_twexa_mutes`')) do
        local acc = out[tostring(row.account_id)]
        if acc then acc.mutes[tostring(row.target_id)] = true end
    end

    for _, row in ipairs(Sql.Query('SELECT `account_id`, `target_id` FROM `oph3z_phone_twexa_blocks`')) do
        local acc = out[tostring(row.account_id)]
        if acc then acc.blocks[tostring(row.target_id)] = true end
    end

    for _, row in ipairs(Sql.Query('SELECT `account_id`, `post_id`, `ts` FROM `oph3z_phone_twexa_bookmarks`')) do
        local acc = out[tostring(row.account_id)]
        if acc then acc.bookmarks[tostring(row.post_id)] = row.ts or 0 end
    end

    for _, row in ipairs(Sql.Query('SELECT `follower_id`, `target_id` FROM `oph3z_phone_twexa_follows`')) do
        local me = out[tostring(row.follower_id)]
        local target = out[tostring(row.target_id)]
        if me then me.following[tostring(row.target_id)] = true end
        if target then target.followers[tostring(row.follower_id)] = true end
    end

    accountCache = out
    return accountCache
end

local function loadPosts()
    if postCache then return postCache end

    Sql.Wait()
    local out = {}
    for _, row in ipairs(Sql.Query('SELECT * FROM `oph3z_phone_twexa_posts`')) do
        out[tostring(row.id)] = {
            id         = row.id,
            author     = row.author,
            text       = row.text or '',
            media      = Sql.Decode(row.media, {}),
            createdAt  = row.created_at,
            parentId   = row.parent_id,
            rootId     = row.root_id,
            replyCount = row.reply_count or 0,
            likes      = {},
            reposts    = {},
            views      = 0,
        }
    end

    for _, row in ipairs(Sql.Query('SELECT `post_id`, COUNT(*) AS `n` FROM `oph3z_phone_twexa_views` GROUP BY `post_id`')) do
        local p = out[tostring(row.post_id)]
        if p then p.views = tonumber(row.n) or 0 end
    end

    for _, row in ipairs(Sql.Query('SELECT `post_id`, `account_id` FROM `oph3z_phone_twexa_likes`')) do
        local p = out[tostring(row.post_id)]
        if p then p.likes[tostring(row.account_id)] = true end
    end

    for _, row in ipairs(Sql.Query('SELECT `post_id`, `account_id`, `ts` FROM `oph3z_phone_twexa_reposts`')) do
        local p = out[tostring(row.post_id)]
        if p then p.reposts[tostring(row.account_id)] = row.ts or 0 end
    end

    postCache = out
    return postCache
end

local function writeAccount(acc)
    Sql.Execute(
        'UPDATE `oph3z_phone_twexa_accounts` SET `handle` = ?, `name` = ?, `email` = ?, `pass_salt` = ?, ' ..
        '`pass_hash` = ?, `bio` = ?, `avatar` = ?, `banner` = ?, `badge` = ?, `last_cid` = ? WHERE `id` = ?',
        {
            acc.handle, acc.name, acc.email, acc.passSalt, acc.passHash,
            acc.bio, acc.avatar, acc.banner, acc.badge, acc.lastCid, acc.id,
        }
    )
end

function X.NormalizeHandle(raw)
    local h = tostring(raw or ''):gsub('^@', ''):gsub('[^%w_]', '')
    return h
end

function X.HandleAvailable(handle, exceptId)
    local norm = X.NormalizeHandle(handle)
    if norm == '' then return false end
    local owner = X.AccountIdByHandle(norm)
    return owner == nil or tostring(owner) == tostring(exceptId)
end

function X.AccountIdByHandle(handle)
    local norm = X.NormalizeHandle(handle):lower()
    if norm == '' then return nil end
    for _, acc in pairs(loadAccounts()) do
        if acc.handle and acc.handle:lower() == norm then return acc.id end
    end
    return nil
end

function X.EmailInUse(email, exceptId)
    local want = tostring(email or ''):lower()
    if want == '' then return false end
    for id, acc in pairs(loadAccounts()) do
        if acc.email and acc.email:lower() == want and tostring(id) ~= tostring(exceptId) then
            return true
        end
    end
    return false
end

function X.GetAccount(id)
    if id == nil then return nil end
    return loadAccounts()[tostring(id)]
end

function X.SaveAccount(acc)
    if not acc or not acc.id then return end
    Sql.Wait()
    loadAccounts()[tostring(acc.id)] = acc
    writeAccount(acc)
end

function X.CreateAccount(handle, name, password, cid, email)
    local norm = X.NormalizeHandle(handle)
    if #norm < 3 or #norm > 15 then return nil, 'handle' end
    if not X.HandleAvailable(norm) then return nil, 'taken' end
    name = tostring(name or ''):sub(1, 40)
    if name == '' then name = norm end
    if type(password) ~= 'string' or #password < 4 then return nil, 'password' end

    Sql.Wait()
    local salt = randomSalt()
    local acc = {
        handle    = norm,
        name      = name,
        email     = email and tostring(email):lower() or nil,
        passSalt  = salt,
        passHash  = hashPassword(salt, password),
        bio       = '',
        avatar    = nil,
        banner    = nil,
        badge     = nil,
        verified  = false,
        createdAt = os.time(),
        following = {},
        followers = {},
        bookmarks = {},
        mutes     = {},
        blocks    = {},
        lastCid   = cid,
    }

    acc.id = Sql.Insert(
        'INSERT INTO `oph3z_phone_twexa_accounts` (`handle`, `name`, `email`, `pass_salt`, `pass_hash`, `bio`, `badge`, `last_cid`, `created_at`) ' ..
        'VALUES (?, ?, ?, ?, ?, \'\', NULL, ?, ?)',
        { acc.handle, acc.name, acc.email, acc.passSalt, acc.passHash, acc.lastCid, acc.createdAt }
    )
    if not acc.id then return nil, 'taken' end

    loadAccounts()[tostring(acc.id)] = acc
    return acc, nil
end

function X.CheckPassword(acc, password)
    if not acc then return false end
    return acc.passHash == hashPassword(acc.passSalt, password)
end

function X.SetEmail(acc, email)
    if not acc or type(email) ~= 'string' or email == '' then return false end
    acc.email = email:lower()
    X.SaveAccount(acc)
    return true
end

function X.SetPassword(acc, password)
    if not acc or type(password) ~= 'string' or #password < 4 then return false end
    acc.passSalt = randomSalt()
    acc.passHash = hashPassword(acc.passSalt, password)
    X.SaveAccount(acc)
    return true
end

function X.SetHandle(acc, newHandle)
    local norm = X.NormalizeHandle(newHandle)
    if #norm < 3 or #norm > 15 then return false, 'handle' end
    if not X.HandleAvailable(norm, acc.id) then return false, 'taken' end
    acc.handle = norm
    X.SaveAccount(acc)
    return true
end

function X.BadgeOf(acc)
    return (acc and acc.badge == 'gold') and 'gold' or 'blue'
end

function X.SetBadge(acc, tier)
    if not acc then return false end
    acc.badge = (tier == 'gold') and 'gold' or nil
    X.SaveAccount(acc)
    return true
end

function X.Summary(acc)
    if not acc then return nil end
    return {
        id       = acc.id,
        handle   = acc.handle,
        name     = acc.name,
        avatar   = acc.avatar,
        verified = true,
        badge    = X.BadgeOf(acc),
    }
end

function X.SetFollow(meId, targetId, on)
    local me = X.GetAccount(meId)
    local target = X.GetAccount(targetId)
    if not me or not target or tostring(meId) == tostring(targetId) then return nil end

    Sql.Wait()
    me.following = me.following or {}
    target.followers = target.followers or {}
    if on then
        me.following[tostring(targetId)] = true
        target.followers[tostring(meId)] = true
        Sql.Execute(
            'INSERT INTO `oph3z_phone_twexa_follows` (`follower_id`, `target_id`) VALUES (?, ?) ' ..
            'ON DUPLICATE KEY UPDATE `follower_id` = `follower_id`',
            { me.id, target.id }
        )
    else
        me.following[tostring(targetId)] = nil
        target.followers[tostring(meId)] = nil
        Sql.Execute(
            'DELETE FROM `oph3z_phone_twexa_follows` WHERE `follower_id` = ? AND `target_id` = ?',
            { me.id, target.id }
        )
    end
    return on == true
end

function X.IsFollowing(meId, targetId)
    local me = X.GetAccount(meId)
    return me and me.following and me.following[tostring(targetId)] == true or false
end

function X.GetPost(id)
    if id == nil then return nil end
    return loadPosts()[tostring(id)]
end

function X.SetLike(p, accountId, on)
    if not p or not p.id then return end

    Sql.Wait()
    local key = tostring(accountId)
    p.likes = p.likes or {}
    if on then
        p.likes[key] = true
        Sql.Execute(
            'INSERT INTO `oph3z_phone_twexa_likes` (`post_id`, `account_id`) VALUES (?, ?) ' ..
            'ON DUPLICATE KEY UPDATE `post_id` = `post_id`',
            { p.id, tonumber(accountId) }
        )
    else
        p.likes[key] = nil
        Sql.Execute(
            'DELETE FROM `oph3z_phone_twexa_likes` WHERE `post_id` = ? AND `account_id` = ?',
            { p.id, tonumber(accountId) }
        )
    end
end

function X.SetRepost(p, accountId, on)
    if not p or not p.id then return end

    Sql.Wait()
    local key = tostring(accountId)
    p.reposts = p.reposts or {}
    if on then
        local ts = os.time()
        p.reposts[key] = ts
        Sql.Execute(
            'INSERT INTO `oph3z_phone_twexa_reposts` (`post_id`, `account_id`, `ts`) VALUES (?, ?, ?) ' ..
            'ON DUPLICATE KEY UPDATE `ts` = VALUES(`ts`)',
            { p.id, tonumber(accountId), ts }
        )
    else
        p.reposts[key] = nil
        Sql.Execute(
            'DELETE FROM `oph3z_phone_twexa_reposts` WHERE `post_id` = ? AND `account_id` = ?',
            { p.id, tonumber(accountId) }
        )
    end
end

-- Bookmarks are private to the account that saved them.
function X.SetBookmark(acc, postId, on)
    if not acc or not postId then return end
    Sql.Wait()
    acc.bookmarks = acc.bookmarks or {}
    local key = tostring(postId)
    if on then
        local ts = os.time()
        acc.bookmarks[key] = ts
        Sql.Execute(
            'INSERT INTO `oph3z_phone_twexa_bookmarks` (`account_id`, `post_id`, `ts`) VALUES (?, ?, ?) ' ..
            'ON DUPLICATE KEY UPDATE `ts` = VALUES(`ts`)',
            { acc.id, tonumber(postId), ts }
        )
    else
        acc.bookmarks[key] = nil
        Sql.Execute(
            'DELETE FROM `oph3z_phone_twexa_bookmarks` WHERE `account_id` = ? AND `post_id` = ?',
            { acc.id, tonumber(postId) }
        )
    end
end

-- Unique viewers per post (one row per account). The in-memory set avoids re-inserting.
local viewSeen = {}
function X.AddView(p, accountId)
    if not p or not p.id or not accountId then return end
    local key = tostring(p.id) .. ':' .. tostring(accountId)
    if viewSeen[key] then return end
    viewSeen[key] = true
    Sql.Wait()
    local added = Sql.Execute(
        'INSERT IGNORE INTO `oph3z_phone_twexa_views` (`post_id`, `account_id`) VALUES (?, ?)',
        { p.id, tonumber(accountId) }
    )
    if (tonumber(added) or 0) > 0 then p.views = (p.views or 0) + 1 end
end

-- Mute: hide their posts from me. Block: hide both ways and drop follows between us.
local function setRelation(tbl, field, acc, targetId, on)
    if not acc or not targetId or tostring(acc.id) == tostring(targetId) then return false end
    Sql.Wait()
    acc[field] = acc[field] or {}
    local key = tostring(targetId)
    if on then
        acc[field][key] = true
        Sql.Execute(('INSERT IGNORE INTO `%s` (`account_id`, `target_id`) VALUES (?, ?)'):format(tbl), { acc.id, tonumber(targetId) })
    else
        acc[field][key] = nil
        Sql.Execute(('DELETE FROM `%s` WHERE `account_id` = ? AND `target_id` = ?'):format(tbl), { acc.id, tonumber(targetId) })
    end
    return true
end

function X.SetMute(acc, targetId, on)
    return setRelation('oph3z_phone_twexa_mutes', 'mutes', acc, targetId, on)
end

function X.SetBlock(acc, targetId, on)
    local ok = setRelation('oph3z_phone_twexa_blocks', 'blocks', acc, targetId, on)
    if ok and on then
        X.SetFollow(acc.id, targetId, false)
        X.SetFollow(targetId, acc.id, false)
    end
    return ok
end

-- true when viewer should not see author's content (muted / blocked either way)
function X.Hidden(viewerId, authorId)
    if not viewerId or not authorId then return false end
    local v, a = X.GetAccount(viewerId), X.GetAccount(authorId)
    local vk, ak = tostring(viewerId), tostring(authorId)
    if v and ((v.mutes and v.mutes[ak]) or (v.blocks and v.blocks[ak])) then return true end
    if a and a.blocks and a.blocks[vk] then return true end
    return false
end

function X.Blocked(aId, bId)
    local a, b = X.GetAccount(aId), X.GetAccount(bId)
    return (a and a.blocks and a.blocks[tostring(bId)]) or (b and b.blocks and b.blocks[tostring(aId)]) or false
end

function X.CreatePost(authorId, text, media, parentId)
    Sql.Wait()
    local parent = parentId and X.GetPost(parentId) or nil
    local rootId
    if parent then rootId = parent.rootId or parent.id end

    local p = {
        author     = authorId,
        text       = tostring(text or ''):sub(1, 800),
        media      = media or {},
        createdAt  = os.time(),
        likes      = {},
        reposts    = {},
        views      = 0,
        parentId   = parentId,
        rootId     = rootId,
        replyCount = 0,
    }

    p.id = Sql.Insert(
        'INSERT INTO `oph3z_phone_twexa_posts` (`author`, `text`, `media`, `parent_id`, `root_id`, `reply_count`, `created_at`) ' ..
        'VALUES (?, ?, ?, ?, ?, 0, ?)',
        { p.author, p.text, Sql.Encode(p.media), p.parentId, p.rootId, p.createdAt }
    )
    if not p.id then return nil end

    loadPosts()[tostring(p.id)] = p

    if parent then
        parent.replyCount = (parent.replyCount or 0) + 1
        Sql.Execute('UPDATE `oph3z_phone_twexa_posts` SET `reply_count` = ? WHERE `id` = ?', { parent.replyCount, parent.id })
    end
    return p
end

local function dropPost(p)
    Sql.Execute('DELETE FROM `oph3z_phone_twexa_bookmarks` WHERE `post_id` = ?', { p.id })
    Sql.Execute('DELETE FROM `oph3z_phone_twexa_views` WHERE `post_id` = ?', { p.id })
    for _, acc in pairs(loadAccounts()) do
        if acc.bookmarks then acc.bookmarks[tostring(p.id)] = nil end
    end
    Sql.Execute('DELETE FROM `oph3z_phone_twexa_likes` WHERE `post_id` = ?', { p.id })
    Sql.Execute('DELETE FROM `oph3z_phone_twexa_reposts` WHERE `post_id` = ?', { p.id })
    Sql.Execute('DELETE FROM `oph3z_phone_twexa_notifs` WHERE `post_id` = ?', { p.id })
    Sql.Execute('DELETE FROM `oph3z_phone_twexa_posts` WHERE `id` = ?', { p.id })
    loadPosts()[tostring(p.id)] = nil
end

function X.DeletePost(id)
    local p = X.GetPost(id)
    if not p then return end

    Sql.Wait()
    if p.parentId then
        local parent = X.GetPost(p.parentId)
        if parent and parent.replyCount then
            parent.replyCount = math.max(0, parent.replyCount - 1)
            Sql.Execute('UPDATE `oph3z_phone_twexa_posts` SET `reply_count` = ? WHERE `id` = ?', { parent.replyCount, parent.id })
        end
    end
    dropPost(p)
end

function X.DeleteAccount(acc)
    if not acc then return false end

    Sql.Wait()
    local id = tostring(acc.id)
    local posts = loadPosts()

    for pid, p in pairs(posts) do
        if tostring(p.author) == id then
            if p.parentId then
                local parent = posts[tostring(p.parentId)]
                if parent and parent.replyCount then
                    parent.replyCount = math.max(0, parent.replyCount - 1)
                    Sql.Execute('UPDATE `oph3z_phone_twexa_posts` SET `reply_count` = ? WHERE `id` = ?', { parent.replyCount, parent.id })
                end
            end
            Sql.Execute('DELETE FROM `oph3z_phone_twexa_likes` WHERE `post_id` = ?', { p.id })
            Sql.Execute('DELETE FROM `oph3z_phone_twexa_reposts` WHERE `post_id` = ?', { p.id })
            Sql.Execute('DELETE FROM `oph3z_phone_twexa_bookmarks` WHERE `post_id` = ?', { p.id })
            Sql.Execute('DELETE FROM `oph3z_phone_twexa_views` WHERE `post_id` = ?', { p.id })
            Sql.Execute('DELETE FROM `oph3z_phone_twexa_posts` WHERE `id` = ?', { p.id })
            posts[pid] = nil
        end
    end

    Sql.Execute('DELETE FROM `oph3z_phone_twexa_bookmarks` WHERE `account_id` = ?', { acc.id })
    Sql.Execute('DELETE FROM `oph3z_phone_twexa_mutes` WHERE `account_id` = ? OR `target_id` = ?', { acc.id, acc.id })
    Sql.Execute('DELETE FROM `oph3z_phone_twexa_blocks` WHERE `account_id` = ? OR `target_id` = ?', { acc.id, acc.id })
    Sql.Execute('DELETE FROM `oph3z_phone_twexa_views` WHERE `account_id` = ?', { acc.id })
    Sql.Execute('DELETE FROM `oph3z_phone_twexa_likes` WHERE `account_id` = ?', { acc.id })
    Sql.Execute('DELETE FROM `oph3z_phone_twexa_reposts` WHERE `account_id` = ?', { acc.id })
    for _, p in pairs(posts) do
        if p.likes then p.likes[id] = nil end
        if p.reposts then p.reposts[id] = nil end
    end

    Sql.Execute('DELETE FROM `oph3z_phone_twexa_follows` WHERE `follower_id` = ? OR `target_id` = ?', { acc.id, acc.id })
    for _, other in pairs(loadAccounts()) do
        if other.following then other.following[id] = nil end
        if other.followers then other.followers[id] = nil end
    end

    Sql.Execute('DELETE FROM `oph3z_phone_twexa_notifs` WHERE `account_id` = ? OR `actor` = ?', { acc.id, acc.id })
    Sql.Execute('DELETE FROM `oph3z_phone_twexa_link` WHERE `account_id` = ?', { acc.id })
    Sql.Execute('DELETE FROM `oph3z_phone_twexa_accounts` WHERE `id` = ?', { acc.id })
    loadAccounts()[id] = nil
    return true
end

function X.PushNotif(accountId, notif)
    if not accountId then return end

    Sql.Wait()
    notif.ts = os.time()
    notif.read = false
    notif.id = Sql.Insert(
        'INSERT INTO `oph3z_phone_twexa_notifs` (`account_id`, `type`, `actor`, `post_id`, `is_read`, `ts`) ' ..
        'VALUES (?, ?, ?, ?, 0, ?)',
        { tonumber(accountId), notif.type, notif.actor, notif.postId, notif.ts }
    )
    Sql.Execute(
        'DELETE FROM `oph3z_phone_twexa_notifs` WHERE `account_id` = ? AND `id` NOT IN ' ..
        '(SELECT `id` FROM (SELECT `id` FROM `oph3z_phone_twexa_notifs` WHERE `account_id` = ? ORDER BY `id` DESC LIMIT ?) AS keep)',
        { tonumber(accountId), tonumber(accountId), MAX_NOTIFS }
    )
end

function X.GetNotifs(accountId)
    if not accountId then return {} end

    Sql.Wait()
    local out = {}
    for _, row in ipairs(Sql.Query(
        'SELECT `id`, `type`, `actor`, `post_id`, `is_read`, `ts` FROM `oph3z_phone_twexa_notifs` ' ..
        'WHERE `account_id` = ? ORDER BY `id` DESC',
        { tonumber(accountId) }
    )) do
        out[#out + 1] = {
            id = row.id, type = row.type, actor = row.actor,
            postId = row.post_id, read = Sql.Bool(row.is_read), ts = row.ts,
        }
    end
    return out
end

function X.MarkNotifsRead(accountId)
    if not accountId then return end
    Sql.Wait()
    Sql.Execute('UPDATE `oph3z_phone_twexa_notifs` SET `is_read` = 1 WHERE `account_id` = ?', { tonumber(accountId) })
end

function X.AllPosts() return loadPosts() end
function X.AllAccounts() return loadAccounts() end