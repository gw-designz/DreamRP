Jobs = {}
local KEY = 'nova:jobs:v1'
local state, busy, fault = nil, false, false
local delivered, lastPrune = {}, 0
local active = { submitted = true, shortlisted = true, pending_start = true, hiring = true, needs_attention = true }
local reserved = { pending_start = true, hiring = true, hired = true, needs_attention = true }
local reviewable = { submitted = true, shortlisted = true }
local function now() return os.time() * 1000 end
local function integer(n, low, high) return type(n) == 'number' and n == n and n % 1 == 0 and n >= low and n <= high end
local function copy(value) return json.decode(json.encode(value)) end
local function count(map) local n = 0; for _ in pairs(map) do n = n + 1 end; return n end
local function contains(list, value) for _, v in ipairs(list) do if v == value then return true end end return false end
local function validId(id) return type(id) == 'string' and #id >= 8 and #id <= 64 and id:match('^[%w_-]+$') end
local function fail(message) return { ok = false, error = message } end

local function read()
    if fault then error('Jobs Hub storage needs a resource restart. Check the server console.') end
    if state then return state end
    local raw = GetResourceKvpString(KEY)
    if raw then
        local ok, value = pcall(json.decode, raw)
        if not ok or type(value) ~= 'table' or value.version ~= 1 or not integer(value.revision, 0, 9000000000)
            or type(value.listings) ~= 'table' or type(value.applications) ~= 'table'
            or type(value.receipts) ~= 'table' or type(value.outbox) ~= 'table' then
            error('Jobs Hub data is unreadable. Restore the KVP backup; data was not reset.')
        end
        state = value
    else state = { version = 1, revision = 0, listings = {}, applications = {}, receipts = {}, outbox = {} } end
    return state
end

local function write(nextState)
    nextState.revision = read().revision + 1
    local encoded = json.encode(nextState)
    SetResourceKvp(KEY, encoded)
    if GetResourceKvpString(KEY) ~= encoded then
        fault = true
        error('Jobs Hub write verification failed. Restart the resource before further actions.')
    end
    state = nextState
end

local function lock(callback)
    if busy then return fail('Jobs Hub is saving another change. Please try again in a moment.') end
    busy = true
    local ok, result = pcall(callback)
    busy = false
    if not ok then
        if type(result) == 'table' and result.validation then return fail(result.validation) end
        print(('[nova_laptop] Jobs Hub: %s'):format(result))
        return fail('This action was not confirmed. Refresh Jobs Hub; contact staff if the error continues.')
    end
    return result
end

local function text(value, limit, minimum, label)
    if type(value) ~= 'string' or #value > limit or not utf8.len(value) then error({ validation = 'Invalid ' .. label .. '.' }) end
    value = value:gsub('\r\n', '\n'):gsub('\r', '\n'):match('^%s*(.-)%s*$')
    if #value < minimum or value:find('[%z\1-\8\11\12\14-\31\127]') then error({ validation = 'Please check ' .. label .. '.' }) end
    return value
end

local function stats(s, listingId)
    local result = { applications = 0, pending = 0, hired = 0, reserved = 0 }
    for _, app in pairs(s.applications) do
        if app.listingId == listingId then
            result.applications = result.applications + 1
            if reviewable[app.status] then result.pending = result.pending + 1 end
            if app.status == 'hired' then result.hired = result.hired + 1 end
            if reserved[app.status] then result.reserved = result.reserved + 1 end
        end
    end
    local listing = s.listings[listingId]
    if listing and listing.hiredTotal then
        result.reserved = result.reserved - result.hired + listing.hiredTotal
        result.hired = listing.hiredTotal
    end
    return result
end

local function advertised(listing)
    return listing.status == 'open' and listing.expiresAt > now()
end

local function publicListing(s, listing, precomputed, currentGrade)
    local tally = precomputed or stats(s, listing.id)
    return { id = listing.id, revision = listing.revision, job = listing.job, company = listing.company,
        title = listing.title, category = listing.category, employment = listing.employment,
        location = listing.location, description = listing.description, requirements = listing.requirements,
        grade = listing.grade, gradeLabel = currentGrade and currentGrade.label or listing.gradeLabel, pay = currentGrade and currentGrade.pay or listing.pay,
        openings = listing.openings, available = math.max(0, listing.openings - tally.reserved),
        questions = listing.questions, status = listing.expiresAt <= now() and listing.status == 'open' and 'expired' or listing.status,
        createdAt = listing.createdAt, updatedAt = listing.updatedAt, expiresAt = listing.expiresAt, stats = tally }
end

local function history(app, status, actor, message)
    app.revision = app.revision + 1
    app.status, app.updatedAt = status, now()
    app.timeline[#app.timeline + 1] = { status = status, actor = actor, message = message, at = now() }
    while #app.timeline > 20 do table.remove(app.timeline, 1) end
end

local function notice(app, title, body)
    app.notice = { id = app.id .. '_' .. app.revision, applicationId = app.id,
        title = title, body = body, at = now(), read = false }
end

local function queue(s, event, app)
    local config = Config.Jobs.Webhook
    if not config.Enabled or not config.Events[event] then return end
    if #s.outbox >= config.MaxQueue then
        print('[nova_laptop] Jobs webhook queue is full; application is saved. Check webhook delivery.')
        return
    end
    s.outbox[#s.outbox + 1] = { id = app.id .. '_' .. app.revision .. '_' .. event,
        appId = app.id, job = app.job, event = event, status = app.status,
        message = app.status == 'hired' and (app.decisionMessage or '') or (app.timeline[#app.timeline] or {}).message or '',
        attempts = 0, nextAt = now(), at = now() }
end

local function publicApplication(app, employer)
    local result = { id = app.id, revision = app.revision, listingId = app.listingId, job = app.job,
        title = app.title, company = app.company, grade = app.grade, gradeLabel = app.gradeLabel,
        applicantName = app.applicantName, contact = app.contact, cover = app.cover,
        experience = app.experience, availability = app.availability, answers = app.answers,
        status = app.status, createdAt = app.createdAt, updatedAt = app.updatedAt,
        previousJob = app.previousJob, timeline = app.timeline, decisionMessage = app.decisionMessage,
        notice = not employer and app.notice or nil, assignmentIssue = app.assignmentIssue }
    if employer then result.internalNote = app.internalNote or '' end
    return result
end

function Jobs.Snapshot(context)
    if not Config.Jobs.Enabled then return nil, 'Jobs Hub is disabled.' end
    local s, authority = read(), JobsBridge.Authority(context)
    local board, own, companyListings, applications, notifications = {}, {}, {}, {}, {}
    local totals = {}
    for id, listing in pairs(s.listings) do totals[id] = { applications = 0, pending = 0, hired = listing.hiredTotal or 0, reserved = listing.hiredTotal or 0 } end
    for _, app in pairs(s.applications) do
        local tally = totals[app.listingId]
        if tally then
            tally.applications = tally.applications + 1
            if reviewable[app.status] then tally.pending = tally.pending + 1 end
            if reserved[app.status] and app.status ~= 'hired' then tally.reserved = tally.reserved + 1 end
        end
    end
    local businesses = {}
    for _, listing in pairs(s.listings) do
        if businesses[listing.job] == nil then businesses[listing.job] = JobsBridge.Business(context, listing.job) or false end
        local business, currentGrade = businesses[listing.job], nil
        for _, grade in ipairs(business and business.grades or {}) do if grade.level == listing.grade then currentGrade = grade end end
        local visible = advertised(listing) and totals[listing.id].reserved < listing.openings
        if visible and currentGrade then board[#board + 1] = publicListing(s, listing, totals[listing.id], currentGrade) end
        if authority and listing.job == authority.name then companyListings[#companyListings + 1] = publicListing(s, listing, totals[listing.id], currentGrade) end
    end
    for _, app in pairs(s.applications) do
        if app.applicantKey == context.key then
            own[#own + 1] = publicApplication(app, false)
            if app.notice then notifications[#notifications + 1] = app.notice end
        end
        if authority and app.job == authority.name then applications[#applications + 1] = publicApplication(app, true) end
    end
    for _, items in ipairs({board, own, companyListings, applications}) do table.sort(items, function(a,b) return a.createdAt > b.createdAt end) end
    table.sort(notifications, function(a,b) return a.at > b.at end)
    local pending, hires, live = 0, 0, 0
    for _, app in ipairs(applications) do
        if reviewable[app.status] then pending = pending + 1 end
        if app.status == 'hired' then hires = hires + 1 end
    end
    for _, listing in ipairs(companyListings) do if listing.status == 'open' then live = live + 1 end end
    return { revision = s.revision, serverTime = now(),
        viewer = { name = context.name, framework = context.framework, currentJob = JobsBridge.CurrentJob(context),
            canApply = context.framework ~= 'standalone', business = authority },
        listings = board, myApplications = own, companyListings = companyListings,
        applications = applications, notifications = notifications,
        stats = { pending = pending, hired = hires, live = live },
        rules = { categories = Config.Jobs.Categories, employmentTypes = Config.Jobs.EmploymentTypes,
            maxOpenings = Config.Jobs.MaxOpenings, maxQuestions = Config.Jobs.MaxQuestions,
            maxActiveApplications = Config.Jobs.MaxActiveApplications, limits = Config.Jobs.Limits,
            reapplyCooldownSeconds = Config.Jobs.ReapplyCooldownSeconds,
            lifetimeDays = Config.Jobs.ListingLifetimeDays } }
end

local function success(context, message, replayed)
    local snapshot, err = Jobs.Snapshot(context)
    return { ok = snapshot ~= nil, jobs = snapshot, error = err, message = message, replayed = replayed or false }
end

local function changed()
    -- No private application data is broadcast. Clients request their own view.
    TriggerClientEvent('nova_laptop:client:jobsChanged', -1)
end

local function mutation(context, action, input, callback)
    return lock(function()
        if not validId(input.requestId) then return fail('Invalid Jobs Hub request ID.') end
        local s = read()
        for _, item in ipairs(s.receipts) do
            if item.key == context.key and item.id == input.requestId then
                if item.action ~= action then return fail('Request ID has already been used.') end
                return success(context, item.message, true)
            end
        end
        local draft = copy(s)
        local message = callback(draft)
        if type(message) ~= 'string' then return message end
        draft.receipts[#draft.receipts + 1] = { key = context.key, id = input.requestId, action = action, message = message }
        while #draft.receipts > Config.Jobs.ReceiptLimit do table.remove(draft.receipts, 1) end
        write(draft)
        changed()
        return success(context, message)
    end)
end

local function ownedListing(s, context, id)
    local listing = s.listings[id]
    if not listing or not JobsBridge.CanHire(context, listing.job, listing.grade) then return nil end
    return listing
end

function Jobs.SaveListing(context, input)
    return mutation(context, 'jobsSaveListing', input, function(s)
        local business = JobsBridge.Authority(context)
        if not business then return fail('Only a business boss can post vacancies.') end
        local existing = input.id and s.listings[input.id]
        if input.id and (not existing or existing.job ~= business.name or existing.revision ~= input.revision) then
            return fail('This vacancy changed or is not yours. Refresh before editing.')
        end
        if not existing and s.listings[input.requestId] then return fail('This vacancy request already exists.') end
        if not JobsBridge.CanHire(context, business.name, input.grade) then return fail('This hiring grade is not permitted.') end
        if not contains(Config.Jobs.Categories, input.category) or not contains(Config.Jobs.EmploymentTypes, input.employment) then return fail('Choose a valid category and employment type.') end
        if not integer(input.openings, 1, Config.Jobs.MaxOpenings) then return fail('Enter a valid number of openings.') end
        if type(input.questions) ~= 'table' or #input.questions > Config.Jobs.MaxQuestions then return fail('Too many application questions.') end
        local tally = existing and stats(s, existing.id) or { applications = 0, reserved = 0 }
        if existing and input.grade ~= existing.grade and tally.applications > 0 then return fail('The hiring grade is locked after an application. Post a new vacancy for another grade.') end
        if input.openings < tally.reserved then return fail('Openings cannot be lower than hires and accepted applicants.') end
        if not existing then
            local total = 0
            for _, listing in pairs(s.listings) do if listing.job == business.name and listing.status ~= 'closed' and listing.status ~= 'filled' then total = total + 1 end end
            if total >= Config.Jobs.MaxListingsPerBusiness or count(s.listings) >= Config.Jobs.MaxListings then return fail('The vacancy limit has been reached. Close older listings.') end
        end
        local limits, questions = Config.Jobs.Limits, {}
        for _, question in ipairs(input.questions) do questions[#questions + 1] = text(question, limits.question, 3, 'application question') end
        local grade
        for _, item in ipairs(business.grades) do if item.level == input.grade then grade = item end end
        local listing = existing or { id = input.requestId, createdAt = now(), createdBy = context.key, revision = 0, status = 'open', hiredTotal = 0 }
        listing.title = text(input.title, limits.title, 3, 'job title')
        listing.location = text(input.location, limits.location, 2, 'workplace')
        listing.description = text(input.description, limits.description, 30, 'role description')
        listing.requirements = text(input.requirements, limits.requirements, 0, 'requirements')
        listing.category, listing.employment = input.category, input.employment
        listing.company, listing.job = business.label, business.name
        listing.grade, listing.gradeLabel, listing.pay = grade.level, grade.label, grade.pay
        listing.questions, listing.openings = questions, input.openings
        listing.updatedAt, listing.expiresAt, listing.revision = now(), now() + Config.Jobs.ListingLifetimeDays * 86400000, listing.revision + 1
        if listing.status == 'filled' and tally.reserved < listing.openings then listing.status = 'paused' end
        s.listings[listing.id] = listing
        return existing and 'Vacancy updated.' or 'Your vacancy is live.'
    end)
end

function Jobs.ListingState(context, input)
    return mutation(context, 'jobsListingState', input, function(s)
        local listing = ownedListing(s, context, input.id)
        if not listing then return fail('You cannot manage this vacancy.') end
        if listing.revision ~= input.revision then return fail('The vacancy changed. Refresh before continuing.') end
        if not contains({'open','paused','closed'}, input.status) then return fail('Invalid vacancy status.') end
        if input.status == 'open' and stats(s, listing.id).reserved >= listing.openings then return fail('All openings are filled or reserved. Increase openings first.') end
        listing.status, listing.revision, listing.updatedAt = input.status, listing.revision + 1, now()
        if input.status == 'open' then listing.expiresAt = now() + Config.Jobs.ListingLifetimeDays * 86400000 end
        if input.status == 'closed' then
            for _, app in pairs(s.applications) do
                if app.listingId == listing.id and reviewable[app.status] then
                    history(app, 'rejected', context.name, 'The vacancy was closed by the employer.')
                    notice(app, 'Vacancy closed', app.company .. ' has closed applications for ' .. app.title .. '.')
                    queue(s, 'decision', app)
                end
            end
        end
        return input.status == 'open' and 'Vacancy published.' or input.status == 'paused' and 'Vacancy paused.' or 'Vacancy closed; outstanding applications were declined.'
    end)
end

function Jobs.Apply(context, input)
    return mutation(context, 'jobsApply', input, function(s)
        if context.framework == 'standalone' then return fail('A supported framework is required to apply and receive a job.') end
        local listing = s.listings[input.listingId]
        if not listing or not advertised(listing) or listing.revision ~= input.revision then return fail('This vacancy changed or is no longer accepting applications.') end
        local business = JobsBridge.Business(context, listing.job)
        local gradeAllowed = false
        for _, grade in ipairs(business and business.grades or {}) do if grade.level == listing.grade then gradeAllowed = true end end
        if not gradeAllowed then return fail('The advertised hiring grade is no longer available.') end
        if context.job == listing.job then return fail('You already work for this business. Speak to your boss about a different role.') end
        if input.consent ~= true then return fail('Confirm that acceptance can change your active job.') end
        local tally, current = stats(s, listing.id), 0
        if tally.reserved >= listing.openings then return fail('All openings are filled or reserved.') end
        for _, app in pairs(s.applications) do
            if app.applicantKey == context.key then
                if active[app.status] then current = current + 1 end
                if app.listingId == listing.id and (active[app.status] or app.status == 'hired'
                    or now() - app.updatedAt < Config.Jobs.ReapplyCooldownSeconds * 1000) then
                    return fail('You already applied to this vacancy, or the reapplication cooldown is still active.')
                end
            end
        end
        if current >= Config.Jobs.MaxActiveApplications then return fail('Withdraw an active application before submitting another.') end
        if tally.applications >= Config.Jobs.MaxApplicantsPerListing or count(s.applications) >= Config.Jobs.MaxApplications then return fail('Application capacity has been reached. Please try another vacancy or contact staff.') end
        if s.applications[input.requestId] then return fail('This application request already exists.') end
        if type(input.answers) ~= 'table' or #input.answers ~= #listing.questions then return fail('Answer every employer question.') end
        local limits, answers = Config.Jobs.Limits, {}
        for index, question in ipairs(listing.questions) do answers[index] = { question = question, answer = text(input.answers[index], limits.answer, 1, 'question answer') } end
        local app = { id = input.requestId, listingId = listing.id, listingRevision = listing.revision,
            job = listing.job, company = listing.company, title = listing.title,
            grade = listing.grade, gradeLabel = listing.gradeLabel, applicantKey = context.key,
            applicantName = context.name, previousJob = JobsBridge.CurrentJob(context), consent = true,
            contact = text(input.contact, limits.contact, 2, 'in-game contact'),
            cover = text(input.cover, limits.cover, 20, 'application'),
            experience = text(input.experience, limits.experience, 0, 'experience'),
            availability = text(input.availability, limits.availability, 3, 'availability'),
            answers = answers, timeline = {}, createdAt = now(), revision = 0 }
        history(app, 'submitted', context.name, 'Application submitted.')
        notice(app, 'Application received', app.company .. ' received your application for ' .. app.title .. '.')
        s.applications[app.id] = app
        queue(s, 'application', app)
        return 'Application sent. Track it in My applications.'
    end)
end

function Jobs.Withdraw(context, input)
    return mutation(context, 'jobsWithdraw', input, function(s)
        local app = s.applications[input.id]
        if not app or app.applicantKey ~= context.key then return fail('Application not found.') end
        if app.revision ~= input.revision then return fail('Your application changed. Refresh before withdrawing.') end
        if not reviewable[app.status] and app.status ~= 'pending_start' then return fail('This application can no longer be withdrawn.') end
        history(app, 'withdrawn', context.name, 'Withdrawn by the applicant.')
        notice(app, 'Application withdrawn', 'Your application for ' .. app.title .. ' was withdrawn.')
        queue(s, 'decision', app)
        return 'Application withdrawn.'
    end)
end

function Jobs.Review(context, input)
    return mutation(context, 'jobsReview', input, function(s)
        local app = s.applications[input.id]
        if not app or not JobsBridge.CanHire(context, app.job, app.grade) then return fail('You cannot review this application.') end
        if app.revision ~= input.revision then return fail('Another reviewer updated this application. Refresh first.') end
        if not reviewable[app.status] then return fail('This application already has a decision.') end
        if not contains({'shortlisted','rejected','accept'}, input.decision) then return fail('Invalid application decision.') end
        local listing = s.listings[app.listingId]
        if not listing or listing.status == 'closed' then return fail('The vacancy has been closed.') end
        local message = text(input.message or '', Config.Jobs.Limits.message, 0, 'message to applicant')
        if input.decision == 'accept' then
            if app.applicantKey == context.key then return fail('You cannot hire yourself.') end
            if stats(s, listing.id).reserved >= listing.openings then return fail('All openings are filled or reserved.') end
            for _, other in pairs(s.applications) do
                if other.id ~= app.id and other.applicantKey == app.applicantKey and reserved[other.status] and other.status ~= 'hired' then return fail('This applicant already has a pending job assignment.') end
            end
            app.decisionMessage = message
            app.approvedBy, app.approvedGrade, app.approvedAt = context.name, context.grade, now()
            history(app, 'pending_start', context.name, message ~= '' and message or 'Application accepted.')
            notice(app, 'Application accepted', app.company .. ' accepted you for ' .. app.title .. '. Your job will be assigned when your character is online.')
            queue(s, 'decision', app)
            return 'Application accepted. Job assignment is queued for the applicant.'
        end
        app.decisionMessage = message
        history(app, input.decision, context.name, message ~= '' and message or (input.decision == 'shortlisted' and 'Added to the shortlist.' or 'Application declined.'))
        notice(app, input.decision == 'shortlisted' and 'You have been shortlisted' or 'Application update',
            app.company .. (input.decision == 'shortlisted' and ' shortlisted you for ' or ' declined your application for ') .. app.title .. '.' .. (message ~= '' and (' ' .. message) or ''))
        queue(s, 'decision', app)
        return input.decision == 'shortlisted' and 'Applicant shortlisted.' or 'Application declined and the applicant notified.'
    end)
end

function Jobs.Note(context, input)
    return mutation(context, 'jobsNote', input, function(s)
        local app = s.applications[input.id]
        if not app or not JobsBridge.CanHire(context, app.job, app.grade) then return fail('You cannot access this application.') end
        if app.revision ~= input.revision then return fail('This application changed. Refresh before saving notes.') end
        app.internalNote = text(input.note, Config.Jobs.Limits.internalNote, 0, 'internal note')
        app.revision = app.revision + 1
        return 'Internal note saved. Only this business can see it.'
    end)
end

function Jobs.ReadNotices(context, input)
    return mutation(context, 'jobsReadNotices', input, function(s)
        if type(input.ids) ~= 'table' or #input.ids > 100 then return fail('Invalid notifications.') end
        local ids = {}; for _, id in ipairs(input.ids) do if type(id) == 'string' then ids[id] = true end end
        for _, app in pairs(s.applications) do
            if app.applicantKey == context.key and app.notice and ids[app.notice.id] then app.notice.read = true end
        end
        return 'Notifications marked as read.'
    end)
end

local function markHired(s, app)
    history(app, 'hired', 'Jobs Hub', 'Framework job assignment confirmed.')
    app.assignmentIssue = nil
    notice(app, 'You have been hired', 'You now work for ' .. app.company .. ' as ' .. app.gradeLabel .. '. ' .. (app.decisionMessage or ''))
    for _, other in pairs(s.applications) do
        if other.id ~= app.id and other.applicantKey == app.applicantKey and reviewable[other.status] then
            history(other, 'withdrawn', 'Jobs Hub', 'Another job application was accepted.')
            notice(other, 'Application withdrawn', 'Your application for ' .. other.title .. ' was withdrawn because you accepted another job.')
            queue(s, 'decision', other)
        end
    end
    local listing = s.listings[app.listingId]
    if listing then listing.hiredTotal = (listing.hiredTotal or 0) + 1 end
    if listing and stats(s, listing.id).reserved >= listing.openings then
        listing.status, listing.revision, listing.updatedAt = 'filled', listing.revision + 1, now()
    end
    queue(s, 'decision', app)
end

function Jobs.ProcessHire(id)
    return lock(function()
        local saved = read().applications[id]
        if not saved or (saved.status ~= 'pending_start' and saved.status ~= 'hiring') then return { ok = true } end
        local src, context = JobsBridge.Find(saved.applicantKey)
        if not context or context.dead then return { ok = true } end
        local s, app = copy(read()), nil; app = s.applications[id]
        if app.status == 'hiring' then
            -- Recover a completed external leg after resource interruption. Never
            -- repeat an uncertain assignment: that could rehire a fired player.
            if context.job == app.job and context.grade == app.grade then markHired(s, app)
            else
                history(app, 'needs_attention', 'Jobs Hub', 'A previous job assignment could not be confirmed.')
                app.assignmentIssue = 'Staff must reconcile the interrupted assignment.'
                notice(app, 'Hiring needs staff attention', app.company .. ' accepted your application. Staff need to verify the job assignment.')
                queue(s, 'decision', app)
            end
            write(s); changed(); return { ok = true }
        end
        local business, available = JobsBridge.Business(context, app.job), false
        for _, grade in ipairs(business and business.grades or {}) do if grade.level == app.grade then available = true end end
        if not available or context.job ~= app.previousJob.name or context.grade ~= app.previousJob.grade then
            history(app, 'cancelled', 'Jobs Hub', not available and 'The hiring grade is no longer available.' or 'Your employment changed after applying. Submit a new application to confirm the change.')
            notice(app, 'Job assignment cancelled', app.timeline[#app.timeline].message)
            queue(s, 'decision', app); write(s); changed()
            return { ok = true }
        end
        history(app, 'hiring', 'Jobs Hub', 'Assigning the framework job.')
        write(s) -- Intent is durable before the external framework call.
        local ok, applied, issue = pcall(JobsBridge.Assign, src, app.applicantKey, app.job, app.grade)
        s = copy(read()); app = s.applications[id]
        local after = Bridge.Context(src)
        if after and after.key == app.applicantKey and after.job == app.job and after.grade == app.grade then
            if ok and applied == true then markHired(s, app)
            else
                history(app, 'needs_attention', 'Jobs Hub', 'The job changed but its save was not confirmed.')
                app.assignmentIssue = 'Staff must verify framework persistence before resolving this hire.'
                notice(app, 'Hiring needs staff attention', 'Your new job was assigned, but its save needs verification by staff.')
                queue(s, 'decision', app)
            end
        elseif ok and applied == false then
            history(app, 'cancelled', 'Jobs Hub', issue or 'The framework declined the job assignment.')
            notice(app, 'Job assignment could not complete', app.timeline[#app.timeline].message)
            queue(s, 'decision', app)
        else
            history(app, 'needs_attention', 'Jobs Hub', 'The framework returned an uncertain job assignment.')
            app.assignmentIssue = 'Staff must reconcile the interrupted assignment.'
            notice(app, 'Hiring needs staff attention', app.company .. ' accepted your application. Staff need to verify the job assignment.')
            queue(s, 'decision', app)
        end
        write(s); changed()
        return { ok = true }
    end)
end

function Jobs.Deliver()
    local s = read()
    for _, value in ipairs(GetPlayers()) do
        local src, context = tonumber(value), Bridge.Context(tonumber(value))
        if context then
            delivered[src] = delivered[src] or {}
            local sent, bossSent = 0, 0
            local authority = JobsBridge.Authority(context)
            local notices = {}
            for _, app in pairs(s.applications) do
                if app.applicantKey == context.key and app.notice and not app.notice.read then notices[#notices + 1] = app.notice end
                if app.status == 'submitted' and authority and authority.name == app.job then
                    local id = 'employer_' .. app.id .. '_' .. context.key
                    if bossSent < 3 and not delivered[src][id] then
                        bossSent = bossSent + 1
                        delivered[src][id] = true
                        TriggerClientEvent('nova_laptop:client:jobsNotice', src, { id = id, title = 'New job application', body = app.applicantName .. ' applied for ' .. app.title .. '. Review it in Jobs Hub.' })
                    end
                end
            end
            table.sort(notices, function(a,b) return a.at > b.at end)
            for _, item in ipairs(notices) do
                local key = context.key .. '_' .. item.id
                if sent < 3 and not delivered[src][key] then
                    delivered[src][key] = true; sent = sent + 1
                    TriggerClientEvent('nova_laptop:client:jobsNotice', src, item)
                end
            end
        end
    end
end

function Jobs.Prune()
    if now() - lastPrune < 3600000 or busy then return end
    lastPrune = now()
    lock(function()
        local s, modified = copy(read()), false
        local cutoff = now() - Config.Jobs.RetentionDays * 86400000
        local queued = {}; for _, item in ipairs(s.outbox) do queued[item.appId] = true end
        for id, app in pairs(s.applications) do
            if not active[app.status] and app.updatedAt < cutoff and not queued[id] then s.applications[id] = nil; modified = true end
        end
        for id, listing in pairs(s.listings) do
            if listing.updatedAt < cutoff and not advertised(listing) and stats(s, id).applications == 0 then s.listings[id] = nil; modified = true end
        end
        if modified then write(s) end
        return { ok = true }
    end)
end

function Jobs.Resolve(id, resolution)
    return lock(function()
        local s = copy(read()); local app = s.applications[id]
        if not app or (app.status ~= 'hiring' and app.status ~= 'needs_attention') then return fail('This application has no uncertain assignment.') end
        if resolution == 'applied' then
            local _, context = JobsBridge.Find(app.applicantKey)
            if not context or context.job ~= app.job or context.grade ~= app.grade then return fail('Applicant must be online with the exact accepted job and grade. Verify framework records first.') end
            markHired(s, app)
        elseif resolution == 'not_applied' then
            history(app, 'cancelled', 'Server console', 'Staff confirmed that the assignment was not completed. Submit a new application if still interested.')
            app.assignmentIssue = nil
            notice(app, 'Job assignment cancelled', app.timeline[#app.timeline].message)
            queue(s, 'decision', app)
        else return fail('Use applied or not_applied.') end
        write(s); changed(); return { ok = true, message = 'Hiring record reconciled; no job assignment was repeated.' }
    end)
end

RegisterCommand('novajobs_resolve', function(src, args)
    if src ~= 0 then return end
    local result = Jobs.Resolve(args[1], args[2])
    print('[nova_laptop] ' .. (result.message or result.error))
end, false)

-- Webhook worker uses the same serialized store. Delivery never controls hiring.
function Jobs.WebhookNext()
    if not Config.Jobs.Webhook.Enabled or busy then return nil end
    for _, item in ipairs(read().outbox) do
        if item.nextAt <= now() then
            local app = read().applications[item.appId]
            if app then return copy(item), publicApplication(app, true) end
        end
    end
end

function Jobs.WebhookResult(id, success, delaySeconds)
    return lock(function()
        local s = copy(read())
        for index, item in ipairs(s.outbox) do
            if item.id == id then
                item.attempts = item.attempts + 1
                if success or item.attempts >= Config.Jobs.Webhook.MaxAttempts then
                    if not success then print('[nova_laptop] Jobs webhook delivery failed for event ' .. id .. '; application remains saved.') end
                    table.remove(s.outbox, index)
                else item.nextAt = now() + math.max(2, math.min(600, delaySeconds or 2 ^ item.attempts * 5)) * 1000 end
                write(s); break
            end
        end
        return { ok = true }
    end)
end

function Jobs.Handle(src, context, action, input)
    if not Config.Jobs.Enabled then return fail('Jobs Hub is disabled.') end
    if action == 'jobsSnapshot' then
        local snapshot, err = Jobs.Snapshot(context); return { ok = snapshot ~= nil, jobs = snapshot, error = err }
    end
    local handlers = { jobsSaveListing = Jobs.SaveListing, jobsListingState = Jobs.ListingState,
        jobsApply = Jobs.Apply, jobsWithdraw = Jobs.Withdraw, jobsReview = Jobs.Review,
        jobsNote = Jobs.Note, jobsReadNotices = Jobs.ReadNotices }
    if not handlers[action] then return fail('Unknown Jobs Hub action.') end
    local result = handlers[action](context, input)
    if result.ok then
        if action == 'jobsReview' and input.decision == 'accept' then
            local processed = Jobs.ProcessHire(input.id)
            if not processed.ok then return processed end
            local latest = Bridge.Context(src)
            if latest and latest.key == context.key then
                result.jobs = Jobs.Snapshot(latest)
                local app = read().applications[input.id]
                if app and app.status == 'hired' then result.message = 'Applicant hired. Their framework job is assigned.'
                elseif app and (app.status == 'cancelled' or app.status == 'needs_attention') then result.message = 'Decision saved; check the application for the job-assignment result.' end
            end
        end
        Jobs.Deliver()
    end
    return result
end

AddEventHandler('playerDropped', function() delivered[source] = nil end)
CreateThread(function()
    while true do
        Wait(Config.Jobs.PollSeconds * 1000)
        if Config.Jobs.Enabled and not busy then
            local ok, err = pcall(function()
                local ids = {}
                for id, app in pairs(read().applications) do if app.status == 'pending_start' or app.status == 'hiring' then ids[#ids + 1] = id end end
                for _, id in ipairs(ids) do Jobs.ProcessHire(id) end
                Jobs.Deliver(); Jobs.Prune()
            end)
            if not ok then print('[nova_laptop] Jobs worker: ' .. tostring(err)) end
        end
    end
end)
