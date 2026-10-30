local MySQL = rawget(_G, "MySQL") or exports.oxmysql

-- ─── Tax helpers ─────────────────────────────────────────────────────────────

if type(GetTaxRate) ~= "function" then
    function GetTaxRate(accountType, jobName)
        if not Config or not Config.Tax or not Config.Tax.enabled then
            return 0
        end
        if accountType == "job" and jobName then
            local jobRate = Config.Tax.jobRates and Config.Tax.jobRates[jobName]
            if jobRate ~= nil then
                return tonumber(jobRate) or 0
            end
        end
        return tonumber(Config.Tax.defaultRate) or 0
    end
end

if type(GetPayoutSplit) ~= "function" then
    function GetPayoutSplit(jobName)
        if not Config or not Config.Payout or not Config.Payout.enabled then
            return nil
        end
        local split = (Config.Payout.jobs and Config.Payout.jobs[jobName]) or Config.Payout.default or {}
        local issuerShare = math.max(0, math.min(100, tonumber(split.issuer) or 0))
        local societyShare = math.max(0, tonumber(split.society) or 0)
        if issuerShare + societyShare > 100 then
            societyShare = 100 - issuerShare
        end
        return issuerShare, societyShare
    end
end

if type(CalculateTax) ~= "function" then
    function CalculateTax(amount, taxRate)
        amount   = tonumber(amount)   or 0
        taxRate  = tonumber(taxRate)  or 0
        if taxRate <= 0 or amount <= 0 then
            return 0, amount
        end
        local taxAmount = math.floor(amount * taxRate / 100 * 100 + 0.5) / 100
        return taxAmount, amount + taxAmount
    end
end

-- ─── Payout ──────────────────────────────────────────────────────────────────

function CreditJobInvoicePayout(jobName, issuerIdentifier, totalAmount)
    local issuerShare, societyShare = GetPayoutSplit(jobName)
    if not issuerShare then
        Core.addJobMoney(jobName, totalAmount)
        return
    end

    local issuerPayout  = math.floor(totalAmount * issuerShare  / 100)
    local societyPayout = math.floor(totalAmount * societyShare / 100)

    if societyPayout > 0 then
        Core.addJobMoney(jobName, societyPayout)
    end

    if issuerPayout > 0 and issuerIdentifier then
        local ok = Core.addPlayerBankMoney(issuerIdentifier, issuerPayout)
        if not ok then
            Core.addOfflineMoney(issuerIdentifier, "bank", issuerPayout)
        end
    end

    local remainder = totalAmount - issuerPayout - societyPayout
    if remainder > 0 and Config.Payout and Config.Payout.remainderSociety then
        local targetSociety = Config.Payout.remainderSociety
        local ok, result = pcall(function() return Core.addJobMoney(targetSociety, remainder) end)
        if not ok then
            Debug.warn(Debug, "Payout remainder credit to society", targetSociety, "raised an error:", tostring(result), "- remainder becomes a sink for this invoice")
        elseif result == false then
            Debug.warn(Debug, "Payout remainder credit to society", targetSociety, "rejected by framework (society missing?) - remainder becomes a sink for this invoice")
        end
    end

    Debug.info(Debug, "Payout split for", jobName, "- issuer:", issuerPayout, "society:", societyPayout, "remainder:", totalAmount - issuerPayout - societyPayout)
end

-- ─── Due-date helpers ────────────────────────────────────────────────────────

local function calculateDueDate(params)
    if params.due_date then
        return params.due_date
    end
    if Config.Invoice and Config.Invoice.defaultDueDays then
        local nowMs   = os.time() * 1000
        local daysMs  = Config.Invoice.defaultDueDays * 24 * 60 * 60 * 1000
        return nowMs + daysMs
    end
    return nil
end

-- ─── Job-label resolution ────────────────────────────────────────────────────

local function resolveJobLabel(jobName)
    if not jobName then return nil end
    return Core.getJobLabel(jobName) or jobName
end

local function enrichInvoiceJobLabels(invoice)
    if invoice.issuer_account_type == "job" and invoice.issuer_job_name then
        invoice.issuer_job_name = resolveJobLabel(invoice.issuer_job_name)
    end
    if invoice.recipient_account_type == "job" and invoice.recipient_job_name then
        invoice.recipient_job_name = resolveJobLabel(invoice.recipient_job_name)
    end
end

-- ─── DB insert helpers ───────────────────────────────────────────────────────

local INSERT_FULL = [[
    INSERT INTO bablo_invoices (uuid, issuer_identifier, issuer_display_name, recipient_identifier,
                         issuer_account_type, issuer_job_name, recipient_account_type, recipient_job_name,
                         amount, title, description, status, created_at, due_date)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
]]

local INSERT_SIMPLE = [[
    INSERT INTO bablo_invoices (uuid, issuer_identifier, issuer_display_name, recipient_identifier, amount, title, description, status, created_at, due_date)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
]]

local function notifyInvoiceCreated(senderSource, recipientIdentifier, invoice, recipientAccountType)
    TriggerClientEvent("bablo-billing:invoiceCreated", senderSource, { type = "sent", invoice = invoice })

    local recipientPlayer = Core.getPlayerFromIdentifier(recipientIdentifier)
    if recipientPlayer then
        TriggerClientEvent("bablo-billing:invoiceCreated", recipientPlayer, { type = "received", invoice = invoice })
        if recipientAccountType == "personal" and Core.notifyPlayer then
            Core.notifyPlayer(recipientPlayer, t("notifications.invoice_received.simple", { amount = tostring(invoice.amount) }), "info")
        end
        Debug.info(Debug, "Recipient notified of new invoice:", invoice.uuid)
    else
        Debug.info(Debug, "Recipient not online, invoice will be visible when they connect")
    end
end

-- ─── createInvoiceWithAccountType ────────────────────────────────────────────

function createInvoiceWithAccountType(senderSource, recipientIdentifier, params, senderAccountType)
    if senderAccountType == "personal" and Config.Invoice.allowPrivatePersonToSendInvoice == false then
        Debug.error(Debug, "Personal account billing is disabled")
        return { success = false, error = "Personal account billing is disabled" }
    end

    local senderIdentifier = Core.getIdentifier(senderSource)
    if not senderIdentifier then
        Debug.error(Debug, "Failed to get identifier for sender source", senderSource)
        return { success = false, error = "Failed to get sender identifier" }
    end

    local senderJob     = Core.getPlayerJob(senderSource)
    local senderJobName = senderJob and senderJob.name or nil
    local senderName    = Core.getCharacterName(senderSource) or "Unknown"

    local recipientAccountType = params.recipientAccountType or "personal"
    local recipientJobName     = params.recipientJobName
    local dueDate              = calculateDueDate(params)

    local issuerJobName = (senderAccountType == "job" and senderJobName) and senderJobName or nil

    local invoice = {
        uuid                   = generateInvoiceUUID(),
        issuer_identifier      = senderIdentifier,
        issuer_display_name    = senderName,
        recipient_identifier   = recipientIdentifier,
        issuer_account_type    = senderAccountType,
        issuer_job_name        = issuerJobName,
        recipient_account_type = recipientAccountType,
        recipient_job_name     = recipientJobName,
        amount                 = params.amount,
        title                  = params.title,
        description            = params.description or "No description provided",
        status                 = "pending",
        created_at             = os.time() * 1000,
        due_date               = dueDate,
    }

    local result = MySQL.query.await(INSERT_FULL, {
        invoice.uuid, invoice.issuer_identifier, invoice.issuer_display_name, invoice.recipient_identifier,
        invoice.issuer_account_type, invoice.issuer_job_name, invoice.recipient_account_type, invoice.recipient_job_name,
        invoice.amount, invoice.title, invoice.description, invoice.status, invoice.created_at, invoice.due_date,
    })

    if not result or result.affectedRows == 0 then
        Debug.error(Debug, "Failed to create invoice in database")
        return { success = false, error = "Failed to create invoice in database" }
    end

    invoice.id = result.insertId
    Debug.info(Debug, "Invoice created successfully with UUID:", invoice.uuid, "ID:", invoice.id, "senderAccountType:", senderAccountType)

    TriggerEvent("bablo-billing:invoiceCreated", invoice)
    notifyInvoiceCreated(senderSource, recipientIdentifier, invoice, recipientAccountType)
    enrichInvoiceJobLabels(invoice)

    return { success = true, data = invoice }
end

-- ─── createInvoice (simple / system-facing) ──────────────────────────────────

function createInvoice(issuerIdentifier, recipientIdentifier, params)
    local dueDate = calculateDueDate(params)

    local invoice = {
        uuid                 = generateInvoiceUUID(),
        issuer_identifier    = issuerIdentifier,
        issuer_display_name  = "Unknown",
        recipient_identifier = recipientIdentifier,
        amount               = params.amount,
        title                = params.title,
        description          = params.description or "No description provided",
        status               = "pending",
        created_at           = os.time() * 1000,
        due_date             = dueDate,
    }

    local result = MySQL.query.await(INSERT_SIMPLE, {
        invoice.uuid, invoice.issuer_identifier, invoice.issuer_display_name, invoice.recipient_identifier,
        invoice.amount, invoice.title, invoice.description, invoice.status, invoice.created_at, invoice.due_date,
    })

    if not result or result.affectedRows == 0 then
        Debug.error(Debug, "Failed to create invoice in database")
        return { success = false, error = "Failed to create invoice in database" }
    end

    invoice.id = result.insertId
    Debug.info(Debug, "Invoice created successfully with UUID:", invoice.uuid, "and ID:", invoice.id)

    TriggerEvent("bablo-billing:invoiceCreated", invoice)

    local issuerPlayer    = Core.getPlayerFromIdentifier(issuerIdentifier)
    local recipientPlayer = Core.getPlayerFromIdentifier(recipientIdentifier)

    if issuerPlayer then
        TriggerClientEvent("bablo-billing:invoiceCreated", issuerPlayer, { type = "sent", invoice = invoice })
    end
    if recipientPlayer then
        TriggerClientEvent("bablo-billing:invoiceCreated", recipientPlayer, { type = "received", invoice = invoice })
        if Core.notifyPlayer then
            Core.notifyPlayer(recipientPlayer, t("notifications.invoice_received.simple", { amount = tostring(invoice.amount) }), "info")
        end
    end

    return { success = true, data = invoice }
end

-- ─── CreateInvoice (public API / export) ─────────────────────────────────────

function CreateInvoice(params)
    if type(params) ~= "table" then
        Debug.error(Debug, "CreateInvoice: Invalid arguments, expected a table")
        return { success = false, error = "Invalid arguments, expected a table" }
    end

    local from             = params.from
    local to               = params.to
    local title            = params.title
    local description      = params.description or "No description provided"
    local amount           = params.amount
    local lineItems        = params.lineItems
    local accountType      = params.accountType or "personal"
    local jobName          = params.jobName
    local recipientType    = params.recipientAccountType or "personal"
    local recipientJobName = params.recipientJobName

    if not from or from == "" then
        Debug.error(Debug, "CreateInvoice: Missing 'from' (sender identifier)")
        return { success = false, error = "Missing 'from' (sender identifier)" }
    end
    if not to or to == "" then
        Debug.error(Debug, "CreateInvoice: Missing 'to' (recipient identifier)")
        return { success = false, error = "Missing 'to' (recipient identifier)" }
    end
    if not title or title == "" then
        Debug.error(Debug, "CreateInvoice: Missing 'title'")
        return { success = false, error = "Missing 'title'" }
    end
    if accountType == "job" and (not jobName or jobName == "") then
        Debug.error(Debug, "CreateInvoice: Missing 'jobName' when accountType is 'job'")
        return { success = false, error = "Missing 'jobName' when accountType is 'job'" }
    end
    if recipientType == "job" and (not recipientJobName or recipientJobName == "") then
        Debug.error(Debug, "CreateInvoice: Missing 'recipientJobName' when recipientAccountType is 'job'")
        return { success = false, error = "Missing 'recipientJobName' when recipientAccountType is 'job'" }
    end

    -- Compute amount from line items if provided
    if lineItems and type(lineItems) == "table" and #lineItems > 0 then
        local total    = 0
        local lineParts = {}
        for _, item in ipairs(lineItems) do
            local qty   = tonumber(item.quantity) or 1
            local price = tonumber(item.price) or 0
            total = total + (qty * price)
            table.insert(lineParts, string.format("%dx %s ($%s)", qty, item.description or "Item", price))
        end
        amount = total
        if description == "No description provided" then
            description = table.concat(lineParts, ", ")
        end
    end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        Debug.error(Debug, "CreateInvoice: Invalid amount:", amount)
        return { success = false, error = "Invalid amount" }
    end

    local dueDate = calculateDueDate(params)

    local issuerJobName = (accountType == "job" and jobName) and jobName or nil
    local recipJobName  = (recipientType == "job" and recipientJobName) and recipientJobName or nil

    local invoice = {
        uuid                   = generateInvoiceUUID(),
        issuer_identifier      = from,
        issuer_display_name    = params.senderName or "Unknown",
        recipient_identifier   = to,
        issuer_account_type    = accountType,
        issuer_job_name        = issuerJobName,
        recipient_account_type = recipientType,
        recipient_job_name     = recipJobName,
        amount                 = amount,
        title                  = title,
        description            = description,
        status                 = "pending",
        created_at             = os.time() * 1000,
        due_date               = dueDate,
    }

    local result = MySQL.query.await(INSERT_FULL, {
        invoice.uuid, invoice.issuer_identifier, invoice.issuer_display_name, invoice.recipient_identifier,
        invoice.issuer_account_type, invoice.issuer_job_name, invoice.recipient_account_type, invoice.recipient_job_name,
        invoice.amount, invoice.title, invoice.description, invoice.status, invoice.created_at, invoice.due_date,
    })

    if not result or result.affectedRows == 0 then
        Debug.error(Debug, "CreateInvoice: Failed to create invoice in database")
        return { success = false, error = "Failed to create invoice in database" }
    end

    invoice.id = result.insertId
    Debug.info(Debug, "CreateInvoice: Invoice created UUID:", invoice.uuid, "ID:", invoice.id, "accountType:", accountType)

    TriggerEvent("bablo-billing:invoiceCreated", invoice)

    local issuerPlayer    = Core.getPlayerFromIdentifier(from)
    local recipientPlayer = Core.getPlayerFromIdentifier(to)

    if issuerPlayer then
        TriggerClientEvent("bablo-billing:invoiceCreated", issuerPlayer, { type = "sent", invoice = invoice })
    end
    if recipientPlayer then
        TriggerClientEvent("bablo-billing:invoiceCreated", recipientPlayer, { type = "received", invoice = invoice })
        if recipientType == "personal" and Core.notifyPlayer then
            Core.notifyPlayer(recipientPlayer, t("notifications.invoice_received.simple", { amount = tostring(invoice.amount) }), "info")
        end
    end

    enrichInvoiceJobLabels(invoice)

    return { success = true, data = invoice }
end

-- ─── getInvoice ──────────────────────────────────────────────────────────────

function getInvoice(uuid)
    local rows = MySQL.query.await("SELECT * FROM bablo_invoices WHERE uuid = ?", { uuid })
    if not rows or #rows == 0 then
        Debug.error(Debug, "Invoice not found for UUID:", uuid)
        return nil
    end
    local invoice = rows[1]
    invoice.issuer_job    = invoice.issuer_job_name
    invoice.recipient_job = invoice.recipient_job_name
    enrichInvoiceJobLabels(invoice)
    return invoice
end

-- ─── getInvoicesWithAccountType ──────────────────────────────────────────────

local function buildStatusFilter(statusFilter)
    if statusFilter == "pending" then return "AND status = 'pending'" end
    if statusFilter == "paid"    then return "AND status = 'paid'"    end
    return ""
end

function getInvoicesWithAccountType(direction, page, limit, accountType, playerSource, statusFilter)
    page        = page   or 1
    limit       = limit  or 20
    statusFilter = statusFilter or "all"

    local offset     = (page - 1) * limit
    local playerIdentifier = Core.getIdentifier(playerSource)
    if not playerIdentifier then
        Debug.error(Debug, "Failed to get identifier for source", playerSource)
        return nil
    end

    local playerJob     = Core.getPlayerJob(playerSource)
    local playerJobName = playerJob and playerJob.name or nil
    local filterClause  = buildStatusFilter(statusFilter)

    local dataQuery, countQuery, dataParams, countParams

    if direction == "SENT" then
        if accountType == "personal" then
            dataQuery  = string.format("SELECT * FROM bablo_invoices WHERE issuer_identifier = ? AND issuer_account_type = 'personal' %s ORDER BY created_at DESC LIMIT ? OFFSET ?", filterClause)
            countQuery = string.format("SELECT COUNT(*) as total FROM bablo_invoices WHERE issuer_identifier = ? AND issuer_account_type = 'personal' %s", filterClause)
            dataParams  = { playerIdentifier, limit, offset }
            countParams = { playerIdentifier }
        else
            if not playerJobName then
                Debug.error(Debug, "Job account requested but no job found for source", playerSource)
                return nil
            end
            local grade = (playerJob and playerJob.grade) or 0
            local canSeeAll = JobPermissions.hasPermission(playerJobName, grade, JobPermissions.PERMISSIONS.HANDLE_ALL_SENT_INVOICES)
            if canSeeAll then
                dataQuery  = string.format("SELECT * FROM bablo_invoices WHERE issuer_account_type = 'job' AND issuer_job_name = ? %s ORDER BY created_at DESC LIMIT ? OFFSET ?", filterClause)
                countQuery = string.format("SELECT COUNT(*) as total FROM bablo_invoices WHERE issuer_account_type = 'job' AND issuer_job_name = ? %s", filterClause)
                dataParams  = { playerJobName, limit, offset }
                countParams = { playerJobName }
            else
                dataQuery  = string.format("SELECT * FROM bablo_invoices WHERE issuer_identifier = ? AND issuer_account_type = 'job' AND issuer_job_name = ? %s ORDER BY created_at DESC LIMIT ? OFFSET ?", filterClause)
                countQuery = string.format("SELECT COUNT(*) as total FROM bablo_invoices WHERE issuer_identifier = ? AND issuer_account_type = 'job' AND issuer_job_name = ? %s", filterClause)
                dataParams  = { playerIdentifier, playerJobName, limit, offset }
                countParams = { playerIdentifier, playerJobName }
            end
        end
    else -- RECEIVED
        if accountType == "personal" then
            dataQuery  = string.format("SELECT * FROM bablo_invoices WHERE recipient_identifier = ? AND recipient_account_type = 'personal' %s ORDER BY created_at DESC LIMIT ? OFFSET ?", filterClause)
            countQuery = string.format("SELECT COUNT(*) as total FROM bablo_invoices WHERE recipient_identifier = ? AND recipient_account_type = 'personal' %s", filterClause)
            dataParams  = { playerIdentifier, limit, offset }
            countParams = { playerIdentifier }
        else
            if not playerJobName then
                Debug.error(Debug, "Job account requested but no job found for source", playerSource)
                return nil
            end
            local jobIdentifier = "job:" .. playerJobName
            dataQuery  = string.format("SELECT * FROM bablo_invoices WHERE recipient_identifier = ? AND recipient_account_type = 'job' %s ORDER BY created_at DESC LIMIT ? OFFSET ?", filterClause)
            countQuery = string.format("SELECT COUNT(*) as total FROM bablo_invoices WHERE recipient_identifier = ? AND recipient_account_type = 'job' %s", filterClause)
            dataParams  = { jobIdentifier, limit, offset }
            countParams = { jobIdentifier }
        end
    end

    local invoices = MySQL.query.await(dataQuery, dataParams)
    if not invoices or #invoices == 0 then
        Debug.info(Debug, "No invoices found for type:", direction, "accountType:", accountType, "page:", page)
        return nil
    end

    for _, invoice in ipairs(invoices) do
        enrichInvoiceJobLabels(invoice)
    end

    Debug.info(Debug, "Found", #invoices, "invoices for type:", direction, "accountType:", accountType, "page:", page)

    local countResult = MySQL.query.await(countQuery, countParams)
    local total = (countResult and countResult[1] and countResult[1].total) or 0

    return {
        invoices   = invoices,
        pagination = {
            page    = page,
            limit   = limit,
            total   = total,
            hasMore = total > (page * limit),
        },
    }
end

-- ─── getInvoices (legacy / pending-only) ─────────────────────────────────────

function getInvoices(direction, page, limit)
    page  = page  or 1
    limit = limit or 20
    local offset = (page - 1) * limit

    local query
    if direction == "RECEIVED" then
        query = "SELECT * FROM bablo_invoices WHERE status = 'pending' AND recipient_identifier = ? ORDER BY created_at DESC LIMIT ? OFFSET ?"
    else
        query = "SELECT * FROM bablo_invoices WHERE status = 'pending' AND issuer_identifier = ? ORDER BY created_at DESC LIMIT ? OFFSET ?"
    end

    local playerIdentifier = Core.getIdentifier(source)
    if not playerIdentifier then
        Debug.error(Debug, "Failed to get identifier for source", source)
        return nil
    end

    local invoices = MySQL.query.await(query, { playerIdentifier, limit, offset })
    if not invoices or #invoices == 0 then
        Debug.info(Debug, "No invoices found for type:", direction, "page:", page)
        return nil
    end

    Debug.info(Debug, "Found", #invoices, "invoices for type:", direction, "page:", page)

    local countQuery
    if direction == "RECEIVED" then
        countQuery = "SELECT COUNT(*) as total FROM bablo_invoices WHERE status = 'pending' AND recipient_identifier = ?"
    else
        countQuery = "SELECT COUNT(*) as total FROM bablo_invoices WHERE status = 'pending' AND issuer_identifier = ?"
    end

    local countResult = MySQL.query.await(countQuery, { playerIdentifier })
    local total = (countResult and countResult[1] and countResult[1].total) or 0

    return {
        invoices   = invoices,
        pagination = {
            page    = page,
            limit   = limit,
            total   = total,
            hasMore = total > (page * limit),
        },
    }
end

-- ─── getAllInvoicesWithAccountType ────────────────────────────────────────────

function getAllInvoicesWithAccountType(playerSource, direction, accountType)
    local playerIdentifier = Core.getIdentifier(playerSource)
    if not playerIdentifier then
        Debug.error(Debug, "Failed to get identifier for source", playerSource)
        return nil
    end

    local playerJob     = Core.getPlayerJob(playerSource)
    local playerJobName = playerJob and playerJob.name or nil

    local query, params

    if direction == "SENT" then
        if accountType == "personal" then
            query  = "SELECT * FROM bablo_invoices WHERE issuer_identifier = ? AND issuer_account_type = 'personal' ORDER BY created_at DESC"
            params = { playerIdentifier }
        else
            if not playerJobName then
                Debug.error(Debug, "Job account requested but no job found for source", playerSource)
                return nil
            end
            local grade     = (playerJob and playerJob.grade) or 0
            local canSeeAll = JobPermissions.hasPermission(playerJobName, grade, JobPermissions.PERMISSIONS.HANDLE_ALL_SENT_INVOICES)
            if canSeeAll then
                query  = "SELECT * FROM bablo_invoices WHERE issuer_account_type = 'job' AND issuer_job_name = ? ORDER BY created_at DESC"
                params = { playerJobName }
            else
                query  = "SELECT * FROM bablo_invoices WHERE issuer_identifier = ? AND issuer_account_type = 'job' AND issuer_job_name = ? ORDER BY created_at DESC"
                params = { playerIdentifier, playerJobName }
            end
        end
    else -- RECEIVED
        if accountType == "personal" then
            query  = "SELECT * FROM bablo_invoices WHERE recipient_identifier = ? AND recipient_account_type = 'personal' ORDER BY created_at DESC"
            params = { playerIdentifier }
        else
            if not playerJobName then
                Debug.error(Debug, "Job account requested but no job found for source", playerSource)
                return nil
            end
            local jobIdentifier = "job:" .. playerJobName
            query  = "SELECT * FROM bablo_invoices WHERE recipient_identifier = ? AND recipient_account_type = 'job' ORDER BY created_at DESC"
            params = { jobIdentifier }
        end
    end

    local invoices = MySQL.query.await(query, params)
    if not invoices or #invoices == 0 then
        Debug.info(Debug, "No invoices found for type:", direction, "accountType:", accountType)
        return {}
    end

    for _, invoice in ipairs(invoices) do
        enrichInvoiceJobLabels(invoice)
    end

    Debug.info(Debug, "Found", #invoices, "invoices for type:", direction, "accountType:", accountType)
    return invoices
end

-- ─── getAllInvoices ───────────────────────────────────────────────────────────

function getAllInvoices(playerSource, direction)
    local query
    if direction == "RECEIVED" then
        query = "SELECT * FROM bablo_invoices WHERE recipient_identifier = ? ORDER BY created_at DESC"
    else
        query = "SELECT * FROM bablo_invoices WHERE issuer_identifier = ? ORDER BY created_at DESC"
    end

    local playerIdentifier = Core.getIdentifier(playerSource)
    if not playerIdentifier then
        Debug.error(Debug, "Failed to get identifier for source", playerSource)
        return nil
    end

    local invoices = MySQL.query.await(query, { playerIdentifier })
    if not invoices or #invoices == 0 then
        Debug.info(Debug, "No invoices found for type:", direction)
        return {}
    end

    Debug.info(Debug, "Found", #invoices, "total invoices for type:", direction)
    return invoices
end

-- ─── payInvoice ──────────────────────────────────────────────────────────────

local function creditIssuer(invoice, rawAmount)
    local issuerAccountType = invoice.issuer_account_type or "personal"
    if issuerAccountType == "job" then
        local issuerJob = invoice.issuer_job
        if issuerJob then
            CreditJobInvoicePayout(issuerJob, invoice.issuer_identifier, rawAmount)
        else
            Debug.warn(Debug, "Job name not found for job invoice issuer, adding to personal bank account")
            local ok = Core.addPlayerBankMoney(invoice.issuer_identifier, rawAmount)
            if not ok then
                Core.addOfflineMoney(invoice.issuer_identifier, "bank", rawAmount)
            end
        end
    else
        local ok = Core.addPlayerBankMoney(invoice.issuer_identifier, rawAmount)
        if not ok then
            Core.addOfflineMoney(invoice.issuer_identifier, "bank", rawAmount)
        end
    end
end

local function creditTaxSociety(taxAmount)
    if taxAmount and taxAmount > 0 and Config.Tax and Config.Tax.recipientSociety then
        local society = Config.Tax.recipientSociety
        local ok, result = pcall(function() return Core.addJobMoney(society, taxAmount) end)
        if not ok then
            Debug.warn(Debug, "Tax credit to society", society, "raised an error:", tostring(result), "- payment is not rolled back; tax becomes a sink for this invoice")
        elseif result == false then
            Debug.warn(Debug, "Tax credit to society", society, "rejected by framework (society missing?) - payment is not rolled back; tax becomes a sink for this invoice")
        end
    end
end

function payInvoice(invoiceUuid, payerSource, options)
    options = options or {}
    local skipPayerDeduction = options.skipPayerDeduction or false

    Debug.info(Debug, "Paying invoice", invoiceUuid, "by source", payerSource, "skipPayerDeduction:", skipPayerDeduction)

    local invoice = getInvoice(invoiceUuid)
    if not invoice then
        Debug.error(Debug, "Invoice not found for ID:", invoiceUuid)
        return { success = false, message = "Invoice not found" }
    end

    if invoice.status ~= "pending" then
        Debug.error(Debug, "Invoice is not pending")
        return { success = false, message = "Invoice is not pending" }
    end

    local payerIdentifier = Core.getIdentifier(payerSource)
    if not payerIdentifier then
        Debug.error(Debug, "Failed to get payer identifier for source", payerSource)
        return { success = false, message = "Failed to get payer identifier" }
    end

    -- Authorization check
    local recipientAccountType = invoice.recipient_account_type or "personal"
    if payerIdentifier ~= invoice.recipient_identifier then
        if recipientAccountType == "job" then
            local payerJob     = Core.getPlayerJob(payerSource)
            local payerJobName = payerJob and payerJob.name
            if payerJobName ~= invoice.recipient_job then
                Debug.error(Debug, "Payer job does not match invoice recipient job")
                return { success = false, message = "You are not authorized to pay this invoice" }
            end
        else
            Debug.error(Debug, "Payer identifier does not match invoice recipient")
            return { success = false, message = "You are not authorized to pay this invoice" }
        end
    end

    local rawAmount     = tonumber(invoice.amount)
    local issuerType    = invoice.issuer_account_type or "personal"
    local taxRate       = GetTaxRate(issuerType, invoice.issuer_job)
    local taxAmount, totalDue = CalculateTax(rawAmount, taxRate)

    if not skipPayerDeduction then
        if recipientAccountType == "job" then
            local jobName = invoice.recipient_job
            if not jobName then
                Debug.error(Debug, "Job name not found for job invoice")
                return { success = false, message = "Job information missing from invoice" }
            end
            local jobBalance = Core.getJobMoney(jobName)
            if totalDue > jobBalance then
                Debug.error(Debug, "Job", jobName, "does not have enough money. Has:", jobBalance, "Needs:", totalDue)
                return { success = false, message = "Insufficient job funds" }
            end
            local ok = Core.removeJobMoney(jobName, totalDue)
            if not ok then
                Debug.error(Debug, "Failed to remove money from job", jobName)
                return { success = false, message = "Failed to process job payment" }
            end
        else
            local bankBalance = Core.getPlayerBankMoney(invoice.recipient_identifier)
            if totalDue > bankBalance then
                Debug.error(Debug, "Player", invoice.recipient_identifier, "does not have enough bank money. Has:", bankBalance, "Needs:", totalDue)
                return { success = false, message = "Insufficient bank funds" }
            end
            local ok = Core.removePlayerBankMoney(invoice.recipient_identifier, totalDue)
            if not ok then
                Debug.error(Debug, "Failed to remove bank money from player", invoice.recipient_identifier)
                return { success = false, message = "Failed to process payment" }
            end
        end
    end

    creditIssuer(invoice, rawAmount)
    creditTaxSociety(taxAmount)

    local statusResult = changeInvoiceStatus(invoiceUuid, "paid")
    if not statusResult or not statusResult.success then
        Debug.error(Debug, "Failed to change invoice status")
        return { success = false, message = "Failed to change invoice status" }
    end

    local paidAt = os.time() * 1000
    local updateResult = MySQL.query.await("UPDATE bablo_invoices SET paid_at = ? WHERE uuid = ?", { paidAt, invoiceUuid })
    if not updateResult or updateResult.affectedRows == 0 then
        Debug.error(Debug, "Failed to update invoice paid_at")
        return { success = false, message = "Failed to update invoice paid_at" }
    end

    invoice.status  = "paid"
    invoice.paid_at = paidAt

    TriggerEvent("bablo-billing:invoicePaid", invoice)

    local issuerPlayer    = Core.getPlayerFromIdentifier(invoice.issuer_identifier)
    local recipientPlayer = Core.getPlayerFromIdentifier(invoice.recipient_identifier)

    if issuerPlayer    then TriggerClientEvent("bablo-billing:invoicePaid", issuerPlayer,    { type = "sent",     invoice = invoice }) end
    if recipientPlayer then TriggerClientEvent("bablo-billing:invoicePaid", recipientPlayer, { type = "received", invoice = invoice }) end

    return { success = true, data = updateResult }
end

-- ─── deleteInvoice ───────────────────────────────────────────────────────────

function deleteInvoice(invoiceUuid)
    Debug.info(Debug, "Deleting invoice", invoiceUuid)

    local invoice = getInvoice(invoiceUuid)
    if not invoice then
        Debug.error(Debug, "Invoice not found for UUID:", invoiceUuid)
        return { success = false, message = "Invoice not found" }
    end

    if invoice.status ~= "pending" then
        Debug.error(Debug, "Cannot delete invoice that is not pending")
        return { success = false, message = "Cannot delete invoice that is not pending" }
    end

    local result = MySQL.query.await("DELETE FROM bablo_invoices WHERE uuid = ?", { invoiceUuid })
    if not result or result.affectedRows == 0 then
        Debug.error(Debug, "Failed to delete invoice")
        return { success = false, message = "Failed to delete invoice" }
    end

    Debug.info(Debug, "Invoice deleted successfully:", invoiceUuid)
    TriggerEvent("bablo-billing:invoiceDeleted", invoice)

    local issuerPlayer    = Core.getPlayerFromIdentifier(invoice.issuer_identifier)
    local recipientPlayer = Core.getPlayerFromIdentifier(invoice.recipient_identifier)

    if issuerPlayer    then TriggerClientEvent("bablo-billing:invoiceDeleted", issuerPlayer,    { type = "sent",     invoice = invoice }) end
    if recipientPlayer then TriggerClientEvent("bablo-billing:invoiceDeleted", recipientPlayer, { type = "received", invoice = invoice }) end

    return { success = true, message = "Invoice deleted successfully" }
end

-- ─── changeInvoiceStatus ─────────────────────────────────────────────────────

function changeInvoiceStatus(invoiceUuid, newStatus)
    local result = MySQL.query.await("UPDATE bablo_invoices SET status = ? WHERE uuid = ?", { newStatus, invoiceUuid })
    if not result or result.affectedRows == 0 then
        Debug.error(Debug, "Failed to change invoice status")
        return { success = false, error = "Failed to change invoice status" }
    end
    return { success = true, data = "Invoice status changed successfully" }
end

-- ─── getTotalPriceInvoicesWithAccountType ────────────────────────────────────

function getTotalPriceInvoicesWithAccountType(playerSource, accountType)
    local playerIdentifier = Core.getIdentifier(playerSource)
    if not playerIdentifier then
        Debug.error(Debug, "Failed to get identifier for source", playerSource)
        return { success = false, error = "Failed to get player identifier" }
    end

    local result = MySQL.query.await([[
        SELECT COALESCE(SUM(amount), 0) AS total_price
        FROM bablo_invoices
        WHERE status = 'pending'
        AND recipient_identifier = ?
    ]], { playerIdentifier })

    if not result or #result == 0 then
        Debug.info(Debug, "No invoices found for identifier:", playerIdentifier)
        return { success = true, data = 0 }
    end

    local total = tonumber(result[1].total_price) or 0
    Debug.info(Debug, "Total price for identifier", playerIdentifier, "accountType:", accountType, "is", total)
    return { success = true, data = total }
end

-- ─── getTotalPriceInvoices ────────────────────────────────────────────────────

function getTotalPriceInvoices(recipientIdentifier)
    local result = MySQL.query.await([[
        SELECT COALESCE(SUM(amount), 0) AS total_price
        FROM bablo_invoices
        WHERE status = 'pending'
        AND recipient_identifier = ?
    ]], { recipientIdentifier })

    if not result or #result == 0 then
        Debug.info(Debug, "No invoices found")
        return { success = true, data = 0 }
    end

    return { success = true, data = tonumber(result[1].total_price) or 0 }
end

-- ─── isInvoiceOverdue ────────────────────────────────────────────────────────

function isInvoiceOverdue(invoice)
    if not invoice.due_date then return false end
    return os.time() * 1000 > tonumber(invoice.due_date)
end

-- ─── getDaysUntilDue ─────────────────────────────────────────────────────────

function getDaysUntilDue(invoice)
    if not invoice.due_date then return nil end
    local remaining = tonumber(invoice.due_date) - os.time() * 1000
    if remaining <= 0 then return 0 end
    return math.ceil(remaining / 86400000)
end

-- ─── cleanupOldPaidInvoices ──────────────────────────────────────────────────

function cleanupOldPaidInvoices()
    local retentionDays = Config.Invoice and Config.Invoice.paidInvoiceRetentionDays
    if not retentionDays or retentionDays <= 0 then
        Debug.info(Debug, "Paid invoice cleanup is disabled")
        return 0
    end

    local cutoffMs = (os.time() - retentionDays * 24 * 60 * 60) * 1000

    local result = MySQL.query.await([[
        DELETE FROM bablo_invoices
        WHERE status = 'paid'
        AND paid_at IS NOT NULL
        AND paid_at < ?
    ]], { cutoffMs })

    if result and result.affectedRows > 0 then
        Debug.success(Debug, "Cleaned up", result.affectedRows, "old paid invoices (older than", retentionDays, "days)")
        return result.affectedRows
    end

    Debug.info(Debug, "No old paid invoices to cleanup")
    return 0
end

-- ─── autoPayOverdueInvoices ──────────────────────────────────────────────────

local function creditIssuerAutoPay(invoice, rawAmount)
    local issuerType = invoice.issuer_account_type or "personal"
    if issuerType == "job" then
        local jobName = invoice.issuer_job_name
        if jobName then
            CreditJobInvoicePayout(jobName, invoice.issuer_identifier, rawAmount)
        else
            Debug.warn(Debug, "Auto-pay: Missing issuer job name, adding to personal account")
            local ok = Core.addPlayerBankMoney(invoice.issuer_identifier, rawAmount)
            if not ok then
                Core.addOfflineMoney(invoice.issuer_identifier, "bank", rawAmount)
            end
        end
    else
        local ok = Core.addPlayerBankMoney(invoice.issuer_identifier, rawAmount)
        if not ok then
            Core.addOfflineMoney(invoice.issuer_identifier, "bank", rawAmount)
        end
    end
end

function autoPayOverdueInvoices()
    if not Config.Invoice or not Config.Invoice.autoPayOverdue then return 0 end

    local nowMs = os.time() * 1000
    local overdueInvoices = MySQL.query.await([[
        SELECT * FROM bablo_invoices
        WHERE status = 'pending'
        AND due_date IS NOT NULL
        AND due_date < ?
        ORDER BY due_date ASC
    ]], { nowMs })

    if not overdueInvoices or #overdueInvoices == 0 then
        Debug.info(Debug, "No overdue invoices to auto-pay")
        return 0
    end

    local paidCount   = 0
    local failedCount = 0

    for _, invoice in ipairs(overdueInvoices) do
        local rawAmount = tonumber(invoice.amount)
        if not rawAmount or rawAmount <= 0 then
            Debug.error(Debug, "Auto-pay: Invalid amount for invoice", invoice.uuid)
        else
            local recipientType = invoice.recipient_account_type or "personal"
            local deducted = false

            if recipientType == "job" then
                local jobName = invoice.recipient_job_name
                if jobName then
                    local balance = Core.getJobMoney(jobName)
                    if rawAmount <= balance then
                        deducted = Core.removeJobMoney(jobName, rawAmount)
                    else
                        Debug.warn(Debug, "Auto-pay: Job", jobName, "insufficient funds for invoice", invoice.uuid, "has:", balance, "needs:", rawAmount)
                    end
                end
            else
                local recipientId     = invoice.recipient_identifier
                local recipientPlayer = Core.getPlayerFromIdentifier(recipientId)
                if recipientPlayer then
                    local balance = Core.getPlayerBankMoney(recipientId)
                    if rawAmount <= balance then
                        deducted = Core.removePlayerBankMoney(recipientId, rawAmount)
                    else
                        Debug.warn(Debug, "Auto-pay: Player", recipientId, "insufficient funds for invoice", invoice.uuid, "has:", balance, "needs:", rawAmount)
                    end
                elseif Core.getOfflineMoney and Core.removeOfflineMoney then
                    local balance = Core.getOfflineMoney(recipientId, "bank")
                    if rawAmount <= balance then
                        deducted = Core.removeOfflineMoney(recipientId, "bank", rawAmount)
                    else
                        Debug.warn(Debug, "Auto-pay: Offline player", recipientId, "insufficient funds for invoice", invoice.uuid, "has:", balance, "needs:", rawAmount)
                    end
                else
                    Debug.warn(Debug, "Auto-pay: Player", recipientId, "is offline and offline money operations not supported")
                end
            end

            if not deducted then
                failedCount = failedCount + 1
            else
                creditIssuerAutoPay(invoice, rawAmount)

                local statusResult = changeInvoiceStatus(invoice.uuid, "paid")
                if statusResult and statusResult.success then
                    MySQL.query.await("UPDATE bablo_invoices SET paid_at = ? WHERE uuid = ?", { nowMs, invoice.uuid })

                    local issuerPlayer    = Core.getPlayerFromIdentifier(invoice.issuer_identifier)
                    local recipientPlayer = Core.getPlayerFromIdentifier(invoice.recipient_identifier)

                    if issuerPlayer    then TriggerClientEvent("bablo-billing:invoicePaid", issuerPlayer,    { type = "sent",     invoice = invoice }) end
                    if recipientPlayer then TriggerClientEvent("bablo-billing:invoicePaid", recipientPlayer, { type = "received", invoice = invoice }) end

                    TriggerEvent("bablo-billing:invoicePaid", invoice)
                    paidCount = paidCount + 1
                    Debug.info(Debug, "Auto-pay: Invoice", invoice.uuid, "paid successfully, amount:", rawAmount)
                else
                    Debug.error(Debug, "Auto-pay: Failed to change status for invoice", invoice.uuid)
                    failedCount = failedCount + 1
                end
            end
        end
    end

    Debug.info(Debug, "Auto-pay completed:", paidCount, "paid,", failedCount, "failed out of", #overdueInvoices, "overdue invoices")
    return paidCount
end

-- ─── getOverdueInvoices ──────────────────────────────────────────────────────

function getOverdueInvoices(playerSource, accountType)
    local playerIdentifier = Core.getIdentifier(playerSource)
    if not playerIdentifier then
        Debug.error(Debug, "Failed to get identifier for source", playerSource)
        return nil
    end

    local nowMs = os.time() * 1000
    local query, params

    if accountType == "personal" then
        query  = [[
            SELECT * FROM bablo_invoices
            WHERE recipient_identifier = ?
            AND recipient_account_type = 'personal'
            AND status = 'pending'
            AND due_date IS NOT NULL
            AND due_date < ?
            ORDER BY due_date ASC
        ]]
        params = { playerIdentifier, nowMs }
    else
        local playerJob     = Core.getPlayerJob(playerSource)
        local playerJobName = playerJob and playerJob.name
        if not playerJobName then
            Debug.error(Debug, "Job account requested but no job found for source", playerSource)
            return {}
        end
        local jobIdentifier = "job:" .. playerJobName
        query  = [[
            SELECT * FROM bablo_invoices
            WHERE recipient_identifier = ?
            AND recipient_account_type = 'job'
            AND status = 'pending'
            AND due_date IS NOT NULL
            AND due_date < ?
            ORDER BY due_date ASC
        ]]
        params = { jobIdentifier, nowMs }
    end

    local invoices = MySQL.query.await(query, params)
    if not invoices or #invoices == 0 then
        Debug.info(Debug, "No overdue invoices found for accountType:", accountType)
        return {}
    end

    for _, invoice in ipairs(invoices) do
        enrichInvoiceJobLabels(invoice)
    end

    Debug.info(Debug, "Found", #invoices, "overdue invoices for accountType:", accountType)
    return invoices
end

-- ─── Background thread ───────────────────────────────────────────────────────

Citizen.CreateThread(function()
    Citizen.Wait(30000)

    local intervalMinutes = (Config.Invoice and Config.Invoice.cleanupIntervalMinutes) or 60
    local intervalMs      = intervalMinutes * 60 * 1000

    while true do
        local cleaned = cleanupOldPaidInvoices()
        if cleaned > 0 then
            Debug.info(Debug, "Invoice cleanup completed:", cleaned, "invoices removed")
        end

        local autoPaid = autoPayOverdueInvoices()
        if autoPaid > 0 then
            Debug.info(Debug, "Auto-pay completed:", autoPaid, "overdue invoices paid")
        end

        Citizen.Wait(intervalMs)
    end
end)

-- ─── Exports ─────────────────────────────────────────────────────────────────

exports("CreateInvoice",  CreateInvoice)
exports("createInvoice",  createInvoice)
exports("payInvoice",     payInvoice)
exports("getInvoice",     getInvoice)
exports("deleteInvoice",  deleteInvoice)
