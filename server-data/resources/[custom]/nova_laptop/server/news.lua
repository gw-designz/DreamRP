--[[
    Weazel News: everything the laptop's apps ask the server for.

      LifeInvader portal   the staff (players with Config.News.Job), the
                           portal's groups and what each may do, duty,
                           the company account and paying staff
      Weazel Writer        submitting articles; reviewers approve them
      Magazine Editor      one shared draft of the next issue, published
                           to the newsstand
      Newsstand            published issues, printed as magazine items
      Camera               each character's memory card of photos

    Saved in MySQL (oxmysql); the tables are made on start.
]]

News = {}

local cfg = Config.News
local LAYOUTS = { ['feature-left'] = 2, ['feature-right'] = 2, full = 1, three = 3, grid = 4 }
local PERMISSIONS = {
    { id = 'write', section = 'Weazel Writer', label = 'Write articles', description = 'Employee can write articles and submit them for review' },
    { id = 'review', section = 'Weazel Writer', label = 'Review articles', description = 'Employee can approve, reject and restore submitted articles' },
    { id = 'edit', section = 'Magazine', label = 'Edit the magazine', description = 'Employee can lay out pages and edit staff columns' },
    { id = 'publish', section = 'Magazine', label = 'Publish issues', description = 'Employee can publish the magazine to the newsstand' },
    { id = 'print', section = 'Magazine', label = 'Print copies', description = 'Employee can print copies of published issues' },
    { id = 'staff', section = 'Business', label = 'Manage staff', description = 'Employee can add and remove staff and move them between groups' },
    { id = 'pay', section = 'Business', label = 'Pay staff', description = 'Employee can pay staff from the company account' },
}
local KNOWN = {}
for _, permission in ipairs(PERMISSIONS) do KNOWN[permission.id] = true end
local DEFAULT_PERMISSIONS = { 'write', 'print' }

local printing, photoTimes = {}, {}

-- The owners named in config.lua, by citizen ID. Their group is the Owner
-- group (id 0): every permission, kept in config.lua rather than the database.
local OWNER_GROUP = 0
local owners = {}
for _, cid in ipairs(cfg.Owners or {}) do
    if type(cid) == 'string' and cid ~= '' then owners[cid] = true end
end
local function isOwner(cid) return cid ~= nil and owners[cid] == true end

local function now() return os.time() * 1000 end

local function decode(text, fallback)
    if type(text) ~= 'string' then return fallback end
    local ok, value = pcall(json.decode, text)
    return ok and value or fallback
end

local function clean(text, max)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('[%c]', function(c) return (c == '\n') and c or '' end):match('^%s*(.-)%s*$')
    local length = utf8.len(text)
    if not length or length > max then return nil end
    return text
end

local function qbx() return exports.qbx_core end

-- ── tables ─────────────────────────────────────────────────────────────

local function setup()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `nova_news_groups` (
        `id` INT AUTO_INCREMENT PRIMARY KEY, `name` VARCHAR(40) NOT NULL, `description` VARCHAR(120) NOT NULL DEFAULT '',
        `permissions` TEXT NOT NULL, `builtin` TINYINT NOT NULL DEFAULT 0)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `nova_news_members` (
        `citizenid` VARCHAR(64) PRIMARY KEY, `group_id` INT NULL, `joined_at` BIGINT NOT NULL)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `nova_news_photos` (
        `id` INT AUTO_INCREMENT PRIMARY KEY, `citizenid` VARCHAR(64) NOT NULL, `url` VARCHAR(512) NOT NULL,
        `origin` VARCHAR(12) NOT NULL, `created_at` BIGINT NOT NULL, INDEX (`citizenid`))]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `nova_news_articles` (
        `id` INT AUTO_INCREMENT PRIMARY KEY, `author_cid` VARCHAR(64) NULL, `author_name` VARCHAR(80) NOT NULL,
        `headline` VARCHAR(160) NOT NULL, `body` TEXT NOT NULL, `photos` TEXT NOT NULL, `status` VARCHAR(12) NOT NULL,
        `reviewer` VARCHAR(80) NULL, `created_at` BIGINT NOT NULL, `updated_at` BIGINT NOT NULL, INDEX (`status`))]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `nova_news_issues` (
        `id` INT AUTO_INCREMENT PRIMARY KEY, `volume` INT NOT NULL, `title` VARCHAR(80) NOT NULL, `cover` VARCHAR(512) NULL,
        `pages` MEDIUMTEXT NOT NULL, `published_by` VARCHAR(80) NOT NULL, `created_at` BIGINT NOT NULL)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `nova_news_feed` (
        `id` INT AUTO_INCREMENT PRIMARY KEY, `kind` VARCHAR(20) NOT NULL, `text` VARCHAR(255) NOT NULL,
        `actor` VARCHAR(80) NOT NULL, `created_at` BIGINT NOT NULL)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `nova_news_state` (
        `name` VARCHAR(32) PRIMARY KEY, `value` MEDIUMTEXT NOT NULL)]])

    if not MySQL.scalar.await('SELECT `id` FROM `nova_news_groups` WHERE `builtin` = 1') then
        MySQL.insert.await('INSERT INTO `nova_news_groups` (`name`, `description`, `permissions`, `builtin`) VALUES (?, ?, ?, 1)',
            { 'Employee', 'Default role for employees', json.encode(DEFAULT_PERMISSIONS) })
    end
    if not MySQL.scalar.await("SELECT `id` FROM `nova_news_articles` WHERE `status` = 'column' LIMIT 1") then
        for _, column in ipairs(cfg.Columns or {}) do
            MySQL.insert.await([[INSERT INTO `nova_news_articles` (`author_name`, `headline`, `body`, `photos`, `status`, `created_at`, `updated_at`)
                VALUES ('LIFEINVADER Staff', ?, ?, '[]', 'column', ?, ?)]], { column.title, column.body, now(), now() })
        end
    end
end

local function builtinGroup()
    return MySQL.scalar.await('SELECT `id` FROM `nova_news_groups` WHERE `builtin` = 1')
end

local function post(kind, text, actor)
    MySQL.insert.await('INSERT INTO `nova_news_feed` (`kind`, `text`, `actor`, `created_at`) VALUES (?, ?, ?, ?)',
        { kind, text:sub(1, 255), actor or 'News', now() })
end

-- ── who is asking ──────────────────────────────────────────────────────

local function jobInfo()
    return qbx():GetJob(cfg.Job) or { grades = {} }
end

local function isBossGrade(grade)
    local data = jobInfo().grades[tonumber(grade) or 0]
    return data and data.isboss == true or false
end

--- The asking player as the business sees them: staff or not, owner or
--- not, on duty, and what they may do.
local function whoIs(context)
    local data = context.player and context.player.PlayerData
    local cid = data and data.citizenid
    local job = data and data.job or {}
    local onJob = job.name == cfg.Job
    local me = { cid = cid, name = context.name, staff = onJob or isOwner(cid), onJob = onJob, owner = false,
        onDuty = onJob and job.onduty == true, groupId = nil, perms = {} }
    for id in pairs(KNOWN) do me.perms[id] = false end
    if not me.staff then return me end
    -- An owner by citizen ID sits in the Owner group with every permission.
    if isOwner(cid) then
        me.owner, me.groupId = true, OWNER_GROUP
        for id in pairs(KNOWN) do me.perms[id] = true end
        return me
    end
    me.owner = job.isboss == true
    local row = MySQL.single.await('SELECT `group_id` FROM `nova_news_members` WHERE `citizenid` = ?', { cid })
    if not row then
        local group = builtinGroup()
        MySQL.insert.await('INSERT IGNORE INTO `nova_news_members` (`citizenid`, `group_id`, `joined_at`) VALUES (?, ?, ?)', { cid, group, now() })
        row = { group_id = group }
    end
    me.groupId = row.group_id
    if me.owner then
        for id in pairs(KNOWN) do me.perms[id] = true end
    elseif row.group_id then
        local permissions = MySQL.scalar.await('SELECT `permissions` FROM `nova_news_groups` WHERE `id` = ?', { row.group_id })
        for _, id in ipairs(decode(permissions, {})) do
            if KNOWN[id] then me.perms[id] = true end
        end
    end
    return me
end

local function deny(text) return { ok = false, error = text } end
local NOT_STAFF = ('Only %s staff can do that.'):format(cfg.PageName)

local function balance()
    if GetResourceState('Renewed-Banking') ~= 'started' then return nil end
    local ok, amount = pcall(function() return exports['Renewed-Banking']:getAccountMoney(cfg.Account) end)
    return ok and tonumber(amount) or nil
end

-- ── the portal ─────────────────────────────────────────────────────────

local function company()
    local members = qbx():GetGroupMembers(cfg.Job, 'job') or {}
    local onDuty = qbx():GetDutyCountJob(cfg.Job)
    return {
        label = cfg.PageName, balance = balance(), staff = #members, onDuty = onDuty or 0,
        groups = MySQL.scalar.await('SELECT COUNT(*) FROM `nova_news_groups`') or 0,
    }
end

local function namesOf(cids)
    local names = {}
    if #cids == 0 then return names end
    for _, row in ipairs(MySQL.query.await('SELECT `citizenid`, `charinfo` FROM `players` WHERE `citizenid` IN (?)', { cids }) or {}) do
        local info = decode(row.charinfo, {})
        names[row.citizenid] = (((info.firstname or '') .. ' ' .. (info.lastname or '')):match('^%s*(.-)%s*$'))
    end
    return names
end

local function staffList(me)
    local members = qbx():GetGroupMembers(cfg.Job, 'job') or {}
    local cids, listed = {}, {}
    for i, member in ipairs(members) do cids[i] = member.citizenid listed[member.citizenid] = true end
    -- Owners by citizen ID belong on the list even without the job.
    for cid in pairs(owners) do
        if not listed[cid] then
            members[#members + 1] = { citizenid = cid, grade = -1 }
            cids[#cids + 1] = cid
        end
    end
    local names = namesOf(cids)
    local rows = {}
    if #cids > 0 then
        for _, row in ipairs(MySQL.query.await('SELECT * FROM `nova_news_members` WHERE `citizenid` IN (?)', { cids }) or {}) do
            rows[row.citizenid] = row
        end
    end
    local fallback = builtinGroup()
    local list = {}
    for _, member in ipairs(members) do
        local cid = member.citizenid
        local row = rows[cid]
        if not row then
            row = { group_id = fallback, joined_at = now() }
            MySQL.insert.await('INSERT IGNORE INTO `nova_news_members` (`citizenid`, `group_id`, `joined_at`) VALUES (?, ?, ?)', { cid, fallback, row.joined_at })
        end
        local online = qbx():GetPlayerByCitizenId(cid)
        local job = online and online.PlayerData.job
        list[#list + 1] = {
            cid = cid, name = (names[cid] ~= nil and names[cid] ~= '') and names[cid] or cid,
            owner = isOwner(cid) or isBossGrade(member.grade), groupId = isOwner(cid) and OWNER_GROUP or row.group_id, since = row.joined_at,
            online = online ~= nil, onDuty = job ~= nil and job.name == cfg.Job and job.onduty == true,
            you = cid == me.cid,
        }
    end
    table.sort(list, function(a, b)
        if a.owner ~= b.owner then return a.owner end
        return a.name:lower() < b.name:lower()
    end)
    return list
end

local function groupList()
    local counts = {}
    for _, row in ipairs(MySQL.query.await('SELECT `group_id`, COUNT(*) AS `n` FROM `nova_news_members` GROUP BY `group_id`') or {}) do
        if row.group_id then counts[row.group_id] = row.n end
    end
    -- The Owner group first: every permission, its members named in config.lua.
    local everything, holders, cids = {}, {}, {}
    for _, permission in ipairs(PERMISSIONS) do everything[#everything + 1] = permission.id end
    for cid in pairs(owners) do cids[#cids + 1] = cid end
    table.sort(cids)
    local names = namesOf(cids)
    for _, cid in ipairs(cids) do holders[#holders + 1] = { cid = cid, name = names[cid] ~= '' and names[cid] or nil } end
    local list = { {
        id = OWNER_GROUP, name = 'Owner', description = 'Every permission, set by citizen ID in config.lua',
        permissions = everything, builtin = true, owner = true, members = #cids, holders = holders,
    } }
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `nova_news_groups` ORDER BY `builtin` DESC, `name` ASC') or {}) do
        list[#list + 1] = { id = row.id, name = row.name, description = row.description,
            permissions = decode(row.permissions, {}), builtin = row.builtin == 1, members = counts[row.id] or 0 }
    end
    return list
end

local function feed()
    local list = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `nova_news_feed` ORDER BY `id` DESC LIMIT 40') or {}) do
        list[#list + 1] = { id = row.id, kind = row.kind, text = row.text, actor = row.actor, at = row.created_at }
    end
    return list
end

-- ── articles ───────────────────────────────────────────────────────────

local function articleOut(row, me)
    return { id = row.id, headline = row.headline, body = row.body, photos = decode(row.photos, {}),
        author = row.author_name, status = row.status, at = row.updated_at, mine = row.author_cid == me.cid,
        reviewer = row.reviewer }
end

local function articles(me)
    local out = { mine = {}, pending = {}, approved = {}, columns = {} }
    for _, row in ipairs(MySQL.query.await([[SELECT * FROM `nova_news_articles` WHERE `author_cid` = ?
        AND `status` IN ('pending', 'approved', 'published', 'rejected') ORDER BY `updated_at` DESC LIMIT 30]], { me.cid }) or {}) do
        out.mine[#out.mine + 1] = articleOut(row, me)
    end
    if me.perms.review or me.perms.edit then
        for _, row in ipairs(MySQL.query.await("SELECT * FROM `nova_news_articles` WHERE `status` = 'pending' ORDER BY `created_at` ASC LIMIT 60") or {}) do
            out.pending[#out.pending + 1] = articleOut(row, me)
        end
    end
    if me.perms.edit then
        for _, row in ipairs(MySQL.query.await("SELECT * FROM `nova_news_articles` WHERE `status` = 'approved' ORDER BY `updated_at` DESC LIMIT 80") or {}) do
            out.approved[#out.approved + 1] = articleOut(row, me)
        end
        for _, row in ipairs(MySQL.query.await("SELECT * FROM `nova_news_articles` WHERE `status` = 'column' ORDER BY `id` ASC") or {}) do
            out.columns[#out.columns + 1] = articleOut(row, me)
        end
    end
    return out
end

local function articleRow(id)
    return type(id) == 'number' and MySQL.single.await('SELECT * FROM `nova_news_articles` WHERE `id` = ?', { id }) or nil
end

-- ── the magazine draft ─────────────────────────────────────────────────

local function emptyDraft()
    return { title = '', pages = { { section = 'Cover', layout = 'feature-left', slots = { false, false } } } }
end

local function readDraft()
    return decode(MySQL.scalar.await("SELECT `value` FROM `nova_news_state` WHERE `name` = 'draft'"), nil) or emptyDraft()
end

local function writeDraft(draft)
    MySQL.query.await("INSERT INTO `nova_news_state` (`name`, `value`) VALUES ('draft', ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)",
        { json.encode(draft) })
end

--- A draft from the editor, checked: known layouts, the right number of
--- slots, article ids or empty.
local function checkDraft(input)
    if type(input) ~= 'table' or type(input.pages) ~= 'table' or #input.pages < 1 or #input.pages > 24 then return nil end
    local draft = { title = clean(input.title or '', 60) or '', pages = {} }
    for i, page in ipairs(input.pages) do
        if type(page) ~= 'table' or not LAYOUTS[page.layout] or type(page.slots) ~= 'table' then return nil end
        local slots = {}
        for n = 1, LAYOUTS[page.layout] do
            local id = page.slots[n]
            slots[n] = (type(id) == 'number' and id % 1 == 0) and id or false
        end
        draft.pages[i] = { section = clean(page.section or '', 40) or '', layout = page.layout, slots = slots }
    end
    return draft
end

-- ── issues ─────────────────────────────────────────────────────────────

local function issueSummary(row)
    return { id = row.id, volume = row.volume, title = row.title, cover = row.cover, at = row.created_at, by = row.published_by }
end

local function publish(me, title)
    local draft = readDraft()
    local used, pages, cover = {}, {}, nil
    for i, page in ipairs(draft.pages) do
        local items = {}
        for n, id in ipairs(page.slots) do
            local row = id and articleRow(id)
            if row and (row.status == 'approved' or row.status == 'column') then
                local photos = decode(row.photos, {})
                items[n] = { headline = row.headline, body = row.body, photos = photos, author = row.author_name }
                if row.status == 'approved' then used[#used + 1] = row.id end
                if i == 1 and not cover then cover = photos[1] end
            else
                items[n] = false
            end
        end
        pages[i] = { section = page.section, layout = page.layout, items = items }
    end
    if not pages[1].items[1] then return deny('Put an article in the first slot of the cover page.') end
    local volume = (MySQL.scalar.await('SELECT MAX(`volume`) FROM `nova_news_issues`') or 0) + 1
    local name = clean(title or '', 60)
    if not name or name == '' then name = draft.title ~= '' and draft.title or ('Issue ' .. volume) end
    local id = MySQL.insert.await([[INSERT INTO `nova_news_issues` (`volume`, `title`, `cover`, `pages`, `published_by`, `created_at`)
        VALUES (?, ?, ?, ?, ?, ?)]], { volume, name, cover, json.encode(pages), me.name, now() })
    if #used > 0 then
        MySQL.update.await("UPDATE `nova_news_articles` SET `status` = 'published', `updated_at` = ? WHERE `id` IN (?)", { now(), used })
    end
    writeDraft(emptyDraft())
    post('issue', ('published Vol. %d: %s'):format(volume, name), me.name)
    return { ok = true, issue = id }
end

-- ── printers ───────────────────────────────────────────────────────────

--[[
    Every printer has two ox_inventory stashes: a paper tray staff load with
    paper, and an output tray the copies come out into. A printer someone set
    down is keyed by its owner's citizen ID, so its trays keep their contents;
    the fixed office printers are 'office1', 'office2', ...
]]

local function printers()
    local list = Placement.Printers()
    for i, spot in ipairs(cfg.Printing.Printers or {}) do
        list[#list + 1] = { key = 'office' .. i, coords = spot, office = i }
    end
    return list
end

--- The printer a player means: `target` (a placed printer's net id, or
--- 'office:n'), or failing that the nearest; either way within reach.
local function printerFor(src, target)
    local at = GetEntityCoords(GetPlayerPed(src))
    local range = cfg.Printing.Range or 4.0
    local best, bestDistance = nil, range
    for _, printer in ipairs(printers()) do
        local matches = target == nil or printer.netId == target or (printer.office and target == 'office:' .. printer.office)
        local distance = #(at - printer.coords)
        if matches and distance <= bestDistance then best, bestDistance = printer, distance end
    end
    return best
end

--- The printer's trays, registered with ox_inventory (again is harmless).
local function trays(printer)
    local inventory = exports.ox_inventory
    local output, paper = 'nova_printer_tray_' .. printer.key, 'nova_printer_paper_' .. printer.key
    inventory:RegisterStash(output, 'Printer output tray', 20, 40000, nil, nil, printer.coords)
    inventory:RegisterStash(paper, 'Printer paper tray', 5, 20000, nil, nil, printer.coords)
    return output, paper
end

local function paperIn(stash)
    return cfg.Printing.Paper and (exports.ox_inventory:GetItemCount(stash, cfg.Printing.Paper) or 0) or math.huge
end

local function print_(src, me, input)
    local id, copies = tonumber(input.id), math.floor(tonumber(input.copies) or 0)
    if copies < 1 or copies > cfg.Printing.MaxCopies then return deny(('Print between 1 and %d copies.'):format(cfg.Printing.MaxCopies)) end
    if printing[src] then return deny('The printer is still busy with your last job.') end
    local row = id and MySQL.single.await('SELECT `id`, `volume`, `title` FROM `nova_news_issues` WHERE `id` = ?', { id })
    if not row then return deny('That issue no longer exists.') end
    local printer = printerFor(src, input.printer)
    if not printer then return { ok = false, noPrinter = true, error = 'There is no printer here. Set one down, or stand by the office printer.' } end
    local inventory = exports.ox_inventory
    local output, paperTray = trays(printer)
    local paper = cfg.Printing.Paper
    local loaded = paperIn(paperTray)
    if paper and loaded < copies then
        return deny(('The printer has %d sheet%s of paper. Load more paper into it first.'):format(loaded, loaded == 1 and '' or 's'))
    end
    local metadata = { issue = row.id, label = ('LifeInvader Vol. %d'):format(row.volume), description = row.title }
    if not inventory:CanCarryItem(output, cfg.Printing.Item, copies, metadata) then return deny('The output tray is full. Empty it first.') end
    if paper and not inventory:RemoveItem(paperTray, paper, copies) then return deny('The printer could not take the paper.') end
    printing[src] = true
    SetTimeout(copies * cfg.Printing.SecondsPerCopy * 1000, function()
        printing[src] = nil
        if not inventory:AddItem(output, cfg.Printing.Item, copies, metadata) and paper then
            inventory:AddItem(paperTray, paper, copies)
        end
        if GetPlayerPing(src) > 0 then
            TriggerClientEvent('nova_laptop:client:denied', src, ('%d cop%s of Vol. %d are in the output tray.'):format(copies, copies == 1 and 'y' or 'ies', row.volume))
        end
    end)
    return { ok = true, seconds = copies * cfg.Printing.SecondsPerCopy }
end

--- Opening a printer's output tray or paper tray: staff who may print, at the printer.
RegisterNetEvent('nova_laptop:server:printerTray', function(target, which)
    local src = source
    local context = Bridge.Context(src)
    if not context then return end
    local me = whoIs(context)
    local function refuse(text) TriggerClientEvent('nova_laptop:client:denied', src, text) end
    if not me.perms.print then return refuse('Your group cannot use the printer.') end
    local printer = printerFor(src, target)
    if not printer then return refuse('Stand by the printer first.') end
    local output, paper = trays(printer)
    TriggerClientEvent('nova_laptop:client:openStash', src, which == 'paper' and paper or output)
end)

-- The paper tray only takes paper, and nothing goes back into the output tray.
CreateThread(function()
    if GetResourceState('ox_inventory') ~= 'started' then return end
    exports.ox_inventory:registerHook('swapItems', function(payload)
        local to = type(payload.toInventory) == 'string' and payload.toInventory or ''
        local item = type(payload.fromSlot) == 'table' and payload.fromSlot.name
        if to:find('^nova_printer_paper_') and payload.fromInventory ~= to then
            return item == cfg.Printing.Paper
        end
        if to:find('^nova_printer_tray_') and payload.fromInventory ~= to then return false end
        return true
    end, { inventoryFilter = { '^nova_printer_paper_', '^nova_printer_tray_' } })
end)

--- What the printer's Make copies dialog needs: the issues and the paper loaded.
RegisterNetEvent('nova_laptop:server:printerInfo', function(target)
    local src = source
    local printer = printerFor(src, target)
    local issues = {}
    for _, row in ipairs(MySQL.query.await('SELECT `id`, `volume`, `title` FROM `nova_news_issues` ORDER BY `id` DESC LIMIT 30') or {}) do
        issues[#issues + 1] = { id = row.id, label = ('Vol. %d · %s'):format(row.volume, row.title) }
    end
    local paper = nil
    if printer and cfg.Printing.Paper then
        local _, paperTray = trays(printer)
        paper = paperIn(paperTray)
    end
    TriggerClientEvent('nova_laptop:client:printerInfo', src, printer ~= nil, issues, paper, cfg.Printing.MaxCopies)
end)

--- Make copies, from the printer itself.
RegisterNetEvent('nova_laptop:server:printerCopies', function(target, issue, copies)
    local src = source
    local context = Bridge.Context(src)
    if not context then return end
    local me = whoIs(context)
    local reply
    if not me.perms.print then reply = deny('Your group cannot print copies.')
    else reply = print_(src, me, { id = tonumber(issue), copies = tonumber(copies), printer = target }) end
    TriggerClientEvent('nova_laptop:client:denied', src, reply.ok
        and ('Printing %d cop%s. Ready in about %d seconds.'):format(tonumber(copies) or 0, tonumber(copies) == 1 and 'y' or 'ies', reply.seconds)
        or reply.error)
end)

-- ── photos ─────────────────────────────────────────────────────────────

local function photos(cid)
    local list = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `nova_news_photos` WHERE `citizenid` = ? ORDER BY `created_at` DESC, `id` DESC', { cid }) or {}) do
        list[#list + 1] = { id = row.id, url = row.url, origin = row.origin, at = row.created_at }
    end
    return list
end

--- The phone's photos, newest first: { url, at (ms) }. oph3z-phone's are read
--- straight from its table (the same database); another phone through its
--- GetPhotos export.
local function phoneRows(src)
    local cid = Bridge.Context(src)
    cid = cid and cid.player and cid.player.PlayerData.citizenid
    if not cid then return nil end
    if cfg.PhoneResource == 'oph3z-phone' then
        local ok, rows = pcall(MySQL.query.await,
            'SELECT `url`, `type`, `ts` FROM `oph3z_phone_photos` WHERE `citizenid` = ? ORDER BY `id` ASC', { cid })
        if ok and type(rows) == 'table' then return rows end
        print(('[nova_laptop] Could not read oph3z-phone photos: %s'):format(rows))
    end
    if GetResourceState(cfg.PhoneResource) ~= 'started' then return nil end
    local ok, rows = pcall(function() return exports[cfg.PhoneResource]:GetPhotos(src) end)
    if ok and type(rows) == 'table' then return rows end
    print(('[nova_laptop] %s GetPhotos failed: %s'):format(cfg.PhoneResource, rows))
    return nil
end

local function phoneGallery(src)
    local rows = phoneRows(src)
    if not rows then return nil end
    local list = {}
    for i = #rows, 1, -1 do
        local row = rows[i]
        if type(row.url) == 'string' and row.url ~= '' and (row.type == nil or row.type == 'photo' or row.type == 'image') then
            -- The phone keeps seconds; the laptop works in milliseconds.
            local at = tonumber(row.ts) or 0
            if at > 0 and at < 1e11 then at = at * 1000 end
            list[#list + 1] = { url = row.url, at = at }
        end
    end
    return list
end

local function storePhoto(cid, url, origin, at)
    if (MySQL.scalar.await('SELECT COUNT(*) FROM `nova_news_photos` WHERE `citizenid` = ?', { cid }) or 0) >= cfg.MemoryCard then
        return nil, 'Your memory card is full. Delete some photos first.'
    end
    local id = MySQL.insert.await('INSERT INTO `nova_news_photos` (`citizenid`, `url`, `origin`, `created_at`) VALUES (?, ?, ?, ?)',
        { cid, url, origin, at and at > 0 and at or now() })
    return id
end

--- A photo from the Camera app: the server takes the player's screen and
--- uploads it, then keeps the address on their memory card.
RegisterNetEvent('nova_laptop:server:photo', function()
    local src = source
    local fivemanage = ServerConfig and ServerConfig.Fivemanage or {}
    local key = fivemanage.apiKey or ''
    local function done(ok, text) TriggerClientEvent('nova_laptop:client:photoTaken', src, ok, text) end
    if photoTimes[src] and GetGameTimer() - photoTimes[src] < 1500 then return done(false) end
    photoTimes[src] = GetGameTimer()
    local context = Bridge.Context(src)
    local cid = context and context.player and context.player.PlayerData.citizenid
    if not cid then return done(false, 'Your character is not ready.') end
    if key == '' then return done(false, 'Photos need a Fivemanage key: set ServerConfig.Fivemanage.apiKey in server_config.lua.') end
    if GetResourceState('screencapture') ~= 'started' then return done(false, 'The screencapture resource is not running.') end
    if (MySQL.scalar.await('SELECT COUNT(*) FROM `nova_news_photos` WHERE `citizenid` = ?', { cid }) or 0) >= cfg.MemoryCard then
        return done(false, 'Your memory card is full.')
    end
    exports.screencapture:remoteUpload(src, fivemanage.url or 'https://api.fivemanage.com/api/v3/file', {
        encoding = 'webp', maxWidth = 1600, maxHeight = 900,
        headers = { Authorization = key },
    }, function(response)
        local url = type(response) == 'table' and type(response.data) == 'table' and response.data.url
        if type(url) ~= 'string' or #url > 512 then return done(false, 'The photo could not be uploaded.') end
        local id, err = storePhoto(cid, url, 'camera')
        done(id ~= nil, err)
    end, 'blob')
end)

AddEventHandler('playerDropped', function() printing[source], photoTimes[source] = nil, nil end)

-- ── the actions ────────────────────────────────────────────────────────

local handlers = {}

function handlers.newsBoot(_, me) return { ok = true, me = me, company = company() } end

function handlers.newsFeed(_, me)
    if not me.staff then return deny(NOT_STAFF) end
    return { ok = true, feed = feed(), company = company() }
end

function handlers.newsStaff(_, me)
    if not me.staff then return deny(NOT_STAFF) end
    return { ok = true, staff = staffList(me), groups = groupList() }
end

function handlers.newsHire(_, me, input)
    if not me.perms.staff then return deny('Your group cannot add staff.') end
    local target = tonumber(input.serverId)
    local player = target and qbx():GetPlayer(target)
    if not player then return deny('Nobody with that ID is in the city.') end
    local data = player.PlayerData
    if data.job and data.job.name == cfg.Job then return deny('They already work here.') end
    qbx():SetJob(target, cfg.Job, 0)
    MySQL.insert.await([[INSERT INTO `nova_news_members` (`citizenid`, `group_id`, `joined_at`) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE `group_id` = VALUES(`group_id`), `joined_at` = VALUES(`joined_at`)]], { data.citizenid, builtinGroup(), now() })
    local info = data.charinfo or {}
    post('staff', ('added %s %s as a friend'):format(info.firstname or '', info.lastname or ''), me.name)
    return { ok = true }
end

function handlers.newsFire(_, me, input)
    if not me.perms.staff then return deny('Your group cannot remove staff.') end
    local cid = type(input.cid) == 'string' and input.cid
    if not cid or cid == me.cid then return deny('You cannot unfriend yourself.') end
    if isOwner(cid) then return deny('The owner cannot be unfriended.') end
    for _, member in ipairs(qbx():GetGroupMembers(cfg.Job, 'job') or {}) do
        if member.citizenid == cid then
            if isBossGrade(member.grade) then return deny('The owner cannot be unfriended.') end
            qbx():RemovePlayerFromJob(cid, cfg.Job)
            MySQL.query.await('DELETE FROM `nova_news_members` WHERE `citizenid` = ?', { cid })
            post('staff', 'unfriended a member of staff', me.name)
            return { ok = true }
        end
    end
    return deny('They do not work here.')
end

function handlers.newsSetGroup(_, me, input)
    if not me.perms.staff then return deny('Your group cannot move staff.') end
    local group = tonumber(input.groupId)
    if group == OWNER_GROUP or isOwner(tostring(input.cid)) then return deny('Owners are set by citizen ID in config.lua.') end
    if not group or not MySQL.scalar.await('SELECT `id` FROM `nova_news_groups` WHERE `id` = ?', { group }) then return deny('That group no longer exists.') end
    local changed = MySQL.update.await('UPDATE `nova_news_members` SET `group_id` = ? WHERE `citizenid` = ?', { group, tostring(input.cid) })
    return changed > 0 and { ok = true } or deny('They do not work here.')
end

function handlers.newsGroups(_, me)
    if not me.staff then return deny(NOT_STAFF) end
    return { ok = true, groups = groupList(), permissions = PERMISSIONS }
end

function handlers.newsSaveGroup(_, me, input)
    if not me.owner then return deny('Only the owner can change groups.') end
    local name, description = clean(input.name or '', 40), clean(input.description or '', 120)
    if not name or name == '' or not description then return deny('Give the group a name of up to 40 characters.') end
    local permissions = {}
    for _, id in ipairs(type(input.permissions) == 'table' and input.permissions or {}) do
        if KNOWN[id] then permissions[#permissions + 1] = id end
    end
    local id = tonumber(input.id)
    if id == OWNER_GROUP then return deny('The Owner group is set in config.lua.') end
    if id then
        local builtin = MySQL.scalar.await('SELECT `builtin` FROM `nova_news_groups` WHERE `id` = ?', { id })
        if builtin == nil then return deny('That group no longer exists.') end
        -- The built-in group keeps its name; only what it may do changes.
        if builtin == 1 then
            MySQL.update.await('UPDATE `nova_news_groups` SET `permissions` = ? WHERE `id` = ?', { json.encode(permissions), id })
        else
            MySQL.update.await('UPDATE `nova_news_groups` SET `name` = ?, `description` = ?, `permissions` = ? WHERE `id` = ?',
                { name, description, json.encode(permissions), id })
        end
    else
        if (MySQL.scalar.await('SELECT COUNT(*) FROM `nova_news_groups`') or 0) >= 12 then return deny('A page can have at most 12 groups.') end
        id = MySQL.insert.await('INSERT INTO `nova_news_groups` (`name`, `description`, `permissions`) VALUES (?, ?, ?)',
            { name, description, json.encode(permissions) })
    end
    return { ok = true, id = id }
end

function handlers.newsDeleteGroup(_, me, input)
    if not me.owner then return deny('Only the owner can change groups.') end
    local id = tonumber(input.id)
    if id == OWNER_GROUP then return deny('The Owner group is set in config.lua.') end
    local builtin = id and MySQL.scalar.await('SELECT `builtin` FROM `nova_news_groups` WHERE `id` = ?', { id })
    if builtin == nil then return deny('That group no longer exists.') end
    if builtin == 1 then return deny('The built-in group cannot be deleted.') end
    MySQL.update.await('UPDATE `nova_news_members` SET `group_id` = ? WHERE `group_id` = ?', { builtinGroup(), id })
    MySQL.query.await('DELETE FROM `nova_news_groups` WHERE `id` = ?', { id })
    return { ok = true }
end

function handlers.newsDuty(src, me)
    if not me.staff then return deny(NOT_STAFF) end
    if not me.onJob then return deny(('Clocking in needs the %s job.'):format(cfg.Job)) end
    qbx():SetJobDuty(src, not me.onDuty)
    return { ok = true, onDuty = not me.onDuty }
end

function handlers.newsWallet(_, me)
    if not me.staff then return deny(NOT_STAFF) end
    return { ok = true, balance = balance() }
end

function handlers.newsPay(_, me, input)
    if not me.perms.pay then return deny('Your group cannot pay staff.') end
    local amount = math.floor(tonumber(input.amount) or 0)
    if amount < 1 or amount > cfg.MaxPayment then return deny(('Pay between $1 and $%d.'):format(cfg.MaxPayment)) end
    local note = clean(input.note or '', 60) or ''
    local cid = type(input.cid) == 'string' and input.cid or ''
    local working = false
    for _, member in ipairs(qbx():GetGroupMembers(cfg.Job, 'job') or {}) do
        if member.citizenid == cid then working = true end
    end
    if not working and not isOwner(cid) then return deny('You can only pay your own staff.') end
    local player = qbx():GetPlayerByCitizenId(cid)
    if not player then return deny('They need to be in the city to be paid.') end
    local current = balance()
    if not current then return deny('The company account is unavailable.') end
    if current < amount then return deny('The company account cannot cover that.') end
    local reason = note ~= '' and note or ('%s payroll'):format(cfg.PageName)
    if not exports['Renewed-Banking']:removeAccountMoney(cfg.Account, amount, reason) then
        return deny('The bank refused the payment.')
    end
    if not player.Functions.AddMoney('bank', amount, reason) then
        exports['Renewed-Banking']:addAccountMoney(cfg.Account, amount, 'Refund: ' .. reason)
        return deny('The payment could not reach them and was refunded.')
    end
    return { ok = true, balance = balance() }
end

--- The card mirrors the phone: new phone photos are copied on (while there is
--- room) and ones deleted from the phone are dropped. Camera photos are untouched.
local function syncPhone(src, cid)
    local gallery = phoneGallery(src)
    if not gallery then return end
    local onPhone, have = {}, {}
    for _, photo in ipairs(gallery) do onPhone[photo.url] = photo end
    for _, photo in ipairs(photos(cid)) do
        if photo.origin == 'phone' and not onPhone[photo.url] then
            MySQL.query.await('DELETE FROM `nova_news_photos` WHERE `id` = ? AND `citizenid` = ?', { photo.id, cid })
        else
            have[photo.url] = true
        end
    end
    -- Oldest first, so the card keeps the phone's order when it fills up.
    for i = #gallery, 1, -1 do
        local photo = gallery[i]
        if not have[photo.url] then
            have[photo.url] = true
            if not storePhoto(cid, photo.url, 'phone', photo.at) then break end
        end
    end
end

function handlers.newsPhotos(src, me)
    if not me.cid then return deny('Your character is not ready.') end
    syncPhone(src, me.cid)
    return { ok = true, photos = photos(me.cid), capacity = cfg.MemoryCard }
end

function handlers.newsPhoneGallery(src)
    local list = phoneGallery(src)
    if not list then return deny('Your phone gallery is unavailable.') end
    return { ok = true, photos = list }
end

--- Phone photos are copied onto the memory card when attached.
function handlers.newsImport(src, me, input)
    local gallery = phoneGallery(src)
    if not gallery then return deny('Your phone gallery is unavailable.') end
    local known, have = {}, {}
    for _, photo in ipairs(gallery) do known[photo.url] = true end
    for _, photo in ipairs(photos(me.cid)) do have[photo.url] = photo.id end
    local ids = {}
    for _, url in ipairs(type(input.urls) == 'table' and input.urls or {}) do
        if #ids >= cfg.MaxAttachments then break end
        if type(url) == 'string' and known[url] then
            local id = have[url]
            if not id then
                local err
                id, err = storePhoto(me.cid, url, 'phone')
                if not id then return deny(err) end
                have[url] = id
            end
            ids[#ids + 1] = id
        end
    end
    return { ok = true, ids = ids, photos = photos(me.cid) }
end

function handlers.newsDeletePhoto(_, me, input)
    MySQL.query.await('DELETE FROM `nova_news_photos` WHERE `id` = ? AND `citizenid` = ?', { tonumber(input.id) or 0, me.cid })
    return { ok = true, photos = photos(me.cid) }
end

function handlers.newsArticles(_, me)
    if not me.staff then return deny(NOT_STAFF) end
    return { ok = true, articles = articles(me) }
end

function handlers.newsSubmit(_, me, input)
    if not me.perms.write then return deny('Your group cannot submit articles.') end
    local headline, body = clean(input.headline or '', 75), clean(input.body or '', 1000)
    if not headline or headline == '' then return deny('Give the story a headline of up to 75 characters.') end
    if not body or body == '' then return deny('Write the story first. It can be up to 1,000 characters.') end
    local mine, urls = {}, {}
    for _, photo in ipairs(photos(me.cid)) do mine[photo.id] = photo.url end
    for _, id in ipairs(type(input.photos) == 'table' and input.photos or {}) do
        if #urls >= cfg.MaxAttachments then break end
        if mine[id] then urls[#urls + 1] = mine[id] end
    end
    local id = MySQL.insert.await([[INSERT INTO `nova_news_articles` (`author_cid`, `author_name`, `headline`, `body`, `photos`, `status`, `created_at`, `updated_at`)
        VALUES (?, ?, ?, ?, ?, 'pending', ?, ?)]], { me.cid, me.name, headline, body, json.encode(urls), now(), now() })
    post('article', ('submitted "%s" for review'):format(headline), me.name)
    return { ok = true, id = id }
end

function handlers.newsReview(_, me, input)
    if not me.perms.review then return deny('Your group cannot review articles.') end
    local row = articleRow(input.id)
    if not row or row.status ~= 'pending' then return deny('That article is no longer waiting for review.') end
    local status = input.approve and 'approved' or 'rejected'
    MySQL.update.await('UPDATE `nova_news_articles` SET `status` = ?, `reviewer` = ?, `updated_at` = ? WHERE `id` = ?', { status, me.name, now(), row.id })
    post('review', ('%s "%s"'):format(input.approve and 'approved' or 'rejected', row.headline), me.name)
    return { ok = true }
end

function handlers.newsColumn(_, me, input)
    if not me.perms.edit then return deny('Your group cannot edit staff columns.') end
    local row = articleRow(input.id)
    local body = clean(input.body or '', 1000)
    if not row or row.status ~= 'column' then return deny('That column no longer exists.') end
    if not body or body == '' then return deny('A column needs up to 1,000 characters of text.') end
    MySQL.update.await('UPDATE `nova_news_articles` SET `body` = ?, `updated_at` = ? WHERE `id` = ?', { body, now(), row.id })
    return { ok = true }
end

local function ownsOrReviews(me, row) return row.author_cid == me.cid or me.perms.review end

function handlers.newsTrashList(_, me)
    if not me.staff then return deny(NOT_STAFF) end
    local rows = me.perms.review
        and MySQL.query.await("SELECT * FROM `nova_news_articles` WHERE `status` IN ('trashed', 'rejected') ORDER BY `updated_at` DESC LIMIT 60")
        or MySQL.query.await("SELECT * FROM `nova_news_articles` WHERE `status` IN ('trashed', 'rejected') AND `author_cid` = ? ORDER BY `updated_at` DESC LIMIT 60", { me.cid })
    local list = {}
    for _, row in ipairs(rows or {}) do list[#list + 1] = articleOut(row, me) end
    return { ok = true, articles = list }
end

function handlers.newsTrash(_, me, input)
    local row = articleRow(input.id)
    if not row or not ownsOrReviews(me, row) or (row.status ~= 'pending' and row.status ~= 'approved' and row.status ~= 'rejected') then
        return deny('That article cannot be moved to the trash.')
    end
    MySQL.update.await("UPDATE `nova_news_articles` SET `status` = 'trashed', `updated_at` = ? WHERE `id` = ?", { now(), row.id })
    return { ok = true }
end

function handlers.newsRestore(_, me, input)
    local row = articleRow(input.id)
    if not row or not ownsOrReviews(me, row) or (row.status ~= 'trashed' and row.status ~= 'rejected') then
        return deny('That article cannot be restored.')
    end
    MySQL.update.await("UPDATE `nova_news_articles` SET `status` = 'pending', `updated_at` = ? WHERE `id` = ?", { now(), row.id })
    return { ok = true }
end

function handlers.newsPurge(_, me, input)
    local row = articleRow(input.id)
    if not row or not ownsOrReviews(me, row) or (row.status ~= 'trashed' and row.status ~= 'rejected') then
        return deny('Only articles in the trash can be deleted.')
    end
    MySQL.query.await('DELETE FROM `nova_news_articles` WHERE `id` = ?', { row.id })
    return { ok = true }
end

function handlers.newsDraft(_, me)
    if not me.staff then return deny(NOT_STAFF) end
    return { ok = true, draft = readDraft(), nextVolume = (MySQL.scalar.await('SELECT MAX(`volume`) FROM `nova_news_issues`') or 0) + 1 }
end

function handlers.newsSaveDraft(_, me, input)
    if not me.perms.edit then return deny('Your group cannot edit the magazine.') end
    local draft = checkDraft(input.draft)
    if not draft then return deny('The magazine draft could not be read.') end
    writeDraft(draft)
    return { ok = true }
end

function handlers.newsPublish(_, me, input)
    if not me.perms.publish then return deny('Your group cannot publish issues.') end
    return publish(me, input.title)
end

function handlers.newsIssues()
    local list = {}
    for _, row in ipairs(MySQL.query.await('SELECT `id`, `volume`, `title`, `cover`, `published_by`, `created_at` FROM `nova_news_issues` ORDER BY `id` DESC LIMIT 60') or {}) do
        list[#list + 1] = issueSummary(row)
    end
    return { ok = true, issues = list }
end

function News.Issue(id)
    local row = tonumber(id) and MySQL.single.await('SELECT * FROM `nova_news_issues` WHERE `id` = ?', { tonumber(id) })
    if not row then return nil end
    local issue = issueSummary(row)
    issue.pages = decode(row.pages, {})
    return issue
end

function handlers.newsIssue(_, _, input)
    local issue = News.Issue(input.id)
    return issue and { ok = true, issue = issue } or deny('That issue no longer exists.')
end

--- Sets a printer down: the laptop closes and the player places it with the gizmo.
function handlers.newsPlacePrinter(src, me)
    if not me.perms.print then return deny('Your group cannot print copies.') end
    Placement.Grant(src, 'printer', 'printer')
    return { ok = true }
end

-- /printer: the same, without opening the laptop.
if cfg.Printing.Command then
    RegisterCommand(cfg.Printing.Command, function(src)
        if src <= 0 then return end
        local context = Bridge.Context(src)
        if not context then return end
        local reply = handlers.newsPlacePrinter(src, whoIs(context))
        if not reply.ok then TriggerClientEvent('nova_laptop:client:denied', src, reply.error) end
    end, false)
end

function handlers.newsPrint(src, me, input)
    if not me.perms.print then return deny('Your group cannot print copies.') end
    return print_(src, me, input)
end

News.Actions = {}
for name in pairs(handlers) do News.Actions[name] = true end

function News.Handle(src, context, action, input)
    return handlers[action](src, whoIs(context), input)
end

--- A printed copy being read: the issue for the reader.
RegisterNetEvent('nova_laptop:server:readIssue', function(id)
    local src = source
    local issue = News.Issue(id)
    if issue then TriggerClientEvent('nova_laptop:client:readIssue', src, issue) end
end)

CreateThread(function()
    setup()
    -- The account staff are paid from.
    if GetResourceState('Renewed-Banking') == 'started' then
        pcall(function()
            if not exports['Renewed-Banking']:GetJobAccount(cfg.Account) then
                exports['Renewed-Banking']:CreateJobAccount({ name = cfg.Account, label = cfg.PageName }, 0)
            end
        end)
    end
end)
