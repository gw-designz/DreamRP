Debug.debug(Debug, "bablo-billing", "Loading framework server", Config.Framework)

-- ─── Shared helpers (guards against being defined twice across files) ─────────

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

if type(CalculateTax) ~= "function" then
    function CalculateTax(amount, taxRate)
        amount  = tonumber(amount)  or 0
        taxRate = tonumber(taxRate) or 0
        if taxRate <= 0 or amount <= 0 then
            return 0, amount
        end
        local taxAmount = math.floor(amount * taxRate / 100 * 100 + 0.5) / 100
        return taxAmount, amount + taxAmount
    end
end

-- ─── Feature-gate helpers ─────────────────────────────────────────────────────

local function isPayReferenceEnabled(playerSource)
    if not Config.PayReference or not Config.PayReference.enabled then
        return false, "Feature is disabled"
    end
    return true, nil
end

local function isCitizenLookupAllowed(playerSource)
    if not Config.CitizenLookup or not Config.CitizenLookup.enabled then
        return false, "Feature is disabled"
    end
    local allowedJobs = Config.CitizenLookup.allowedJobs or {}
    if #allowedJobs == 0 then
        return false, "No jobs are configured to use this feature"
    end
    local playerJob = Core.getPlayerJob(playerSource)
    if not playerJob or not playerJob.name then
        return false, "You must have a job to use this feature"
    end
    for _, jobName in ipairs(allowedJobs) do
        if playerJob.name == jobName then
            return true, nil
        end
    end
    return false, "Your job is not authorized to use this feature"
end

-- ─── Theme helper ────────────────────────────────────────────────────────────

local THEME_KEYS = {
    "primary", "primaryHover", "primaryLight", "primaryDark",
    "background", "card", "foreground", "muted", "border",
    "accent", "sidebar", "radius", "job",
}

local function buildThemeConfig()
    if not Config.Theme then return nil end
    local theme  = {}
    local count  = 0
    for _, key in ipairs(THEME_KEYS) do
        if Config.Theme[key] then
            theme[key] = Config.Theme[key]
            count = count + 1
        end
    end
    return count > 0 and theme or nil
end

-- ─── Server callbacks ─────────────────────────────────────────────────────────

RegisterServerCallback({
    eventName = "bablo-billing:GET_SENT_INVOICES",
    eventCallback = function(playerSource, params)
        local playerIdentifier = Core.getIdentifier(playerSource)
        if not playerIdentifier then
            Debug.error(Debug, "Failed to get identifier for source", playerSource)
            return { success = false, error = "Failed to get player identifier" }
        end

        local page         = (params and params.page)         or 1
        local limit        = (params and params.limit)        or 20
        local accountType  = (params and params.accountType)  or "personal"
        local statusFilter = (params and params.statusFilter) or "all"

        Debug.debug(Debug, "Fetching sent invoices for identifier", playerIdentifier, "page:", page, "limit:", limit, "accountType:", accountType, "statusFilter:", statusFilter)

        local result = getInvoicesWithAccountType("SENT", page, limit, accountType, playerSource, statusFilter)
        if not result then
            Debug.info(Debug, "No sent invoices found for identifier", playerIdentifier, "accountType:", accountType)
            return {
                success = true,
                data = {
                    invoices   = {},
                    pagination = { page = page, limit = limit, total = 0, hasMore = false },
                },
            }
        end

        Debug.info(Debug, "Sending sent invoices to client for source", playerSource, #result.invoices, "invoices, page:", page, "accountType:", accountType, "statusFilter:", statusFilter)
        return { success = true, data = result }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_RECEIVED_INVOICES",
    eventCallback = function(playerSource, params)
        local playerIdentifier = Core.getIdentifier(playerSource)
        if not playerIdentifier then
            Debug.error(Debug, "Failed to get identifier for source", playerSource)
            return { success = false, error = "Failed to get player identifier" }
        end

        local page         = (params and params.page)         or 1
        local limit        = (params and params.limit)        or 20
        local accountType  = (params and params.accountType)  or "personal"
        local statusFilter = (params and params.statusFilter) or "all"

        if accountType == "job" then
            local playerJob = Core.getPlayerJob(playerSource)
            if not playerJob or not playerJob.name then
                return { success = false, error = "No job found" }
            end
            Debug.debug(Debug, "[GET_RECEIVED_INVOICES] job.grade type:", type(playerJob.grade), "value:", playerJob.grade)
            local grade       = playerJob.grade or 0
            local hasPermission = JobPermissions.hasPermission(playerJob.name, grade, JobPermissions.PERMISSIONS.VIEW_RECEIVED_INVOICES)
            if not hasPermission then
                return {
                    success = true,
                    data = {
                        invoices   = {},
                        pagination = { page = page, limit = limit, total = 0, totalPages = 0 },
                    },
                }
            end
        end

        Debug.debug(Debug, "Fetching received invoices for identifier", playerIdentifier, "page:", page, "limit:", limit, "accountType:", accountType, "statusFilter:", statusFilter)

        local result = getInvoicesWithAccountType("RECEIVED", page, limit, accountType, playerSource, statusFilter)
        if not result then
            Debug.info(Debug, "No received invoices found for identifier", playerIdentifier, "accountType:", accountType)
            return {
                success = true,
                data = {
                    invoices   = {},
                    pagination = { page = page, limit = limit, total = 0, hasMore = false },
                },
            }
        end

        Debug.info(Debug, "Sending received invoices to client for source", playerSource, #result.invoices, "invoices, page:", page, "accountType:", accountType, "statusFilter:", statusFilter)
        return { success = true, data = result }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_RECEIVED_INVOICE",
    eventCallback = function(playerSource, invoiceUuid)
        local invoice = useReceivedInvoice(invoiceUuid)
        if not invoice then
            return { success = false, error = "Invoice not found" }
        end
        Debug.info(Debug, "Sending invoice data to client", invoice)
        return invoice
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_TOTAL_PRICE_INVOICES",
    eventCallback = function(playerSource, params)
        local playerIdentifier = Core.getIdentifier(playerSource)
        if not playerIdentifier then
            Debug.error(Debug, "Failed to get identifier for source", playerSource)
            return { success = false, data = 0 }
        end
        local result = getTotalPriceInvoices(playerIdentifier)
        Debug.info(Debug, "Total price of invoices for identifier", playerIdentifier, result)
        return result
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_NEARBY_PLAYERS",
    eventCallback = function(playerSource, radius)
        local players = getNearbyPlayersInRadius(playerSource, radius)
        if not players then
            return { success = false, error = "No players found within radius" }
        end
        Debug.info(Debug, "Found", #players, "players within radius of", radius)
        return { success = true, data = players }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_ALL_JOBS",
    eventCallback = function(playerSource)
        if not Core.getAllJobs then
            Debug.error(Debug, "getAllJobs function not implemented for framework", Config.Framework)
            return { success = false, error = "Jobs functionality not available for this framework" }
        end
        local jobs = Core.getAllJobs(playerSource)
        Debug.info(Debug, "Fetching all jobs for source", playerSource)
        if not jobs then
            Debug.error(Debug, "Failed to get jobs for source", playerSource)
            return { success = false, error = "Failed to retrieve jobs" }
        end
        Debug.info(Debug, "Found", #jobs, "jobs for source", playerSource)
        return { success = true, data = jobs }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:CREATE_INVOICE",
    eventCallback = function(playerSource, payload)
        Debug.debug(Debug, "Creating invoice for source", playerSource, "with payload", payload)

        if not payload then
            Debug.error(Debug, "No payload provided to CREATE_INVOICE")
            return { success = false, error = "No invoice data provided" }
        end

        -- Unwrap array payload (some clients wrap in a table)
        local invoiceData = (type(payload) == "table" and payload[1]) and payload[1] or payload
        if not invoiceData then
            Debug.error(Debug, "No invoice data found in payload")
            return { success = false, error = "No invoice data provided" }
        end

        local senderIdentifier = Core.getIdentifier(playerSource)
        if not senderIdentifier then
            Debug.error(Debug, "Failed to get identifier for source", playerSource)
            return { success = false, error = "Failed to get player identifier" }
        end

        -- Resolve recipient
        local recipientIdentifier = nil
        local recipientAccountType = "personal"
        local recipientJobName     = nil

        if invoiceData.recipientType == "job" then
            if not invoiceData.jobName then
                Debug.error(Debug, "No job name provided for job recipient")
                return { success = false, error = "Job name is required for job recipients" }
            end
            -- Permission check: can sender send to companies?
            local senderJob = Core.getPlayerJob(playerSource)
            if senderJob and senderJob.name then
                local senderGrade = senderJob.grade or 0
                Debug.debug(Debug, "[CREATE_INVOICE] senderJob.grade type:", type(senderJob.grade), "value:", senderJob.grade, "| senderGrade type:", type(senderGrade), "value:", senderGrade)
                local canSend = JobPermissions.hasPermission(senderJob.name, senderGrade, JobPermissions.PERMISSIONS.CAN_SEND_TO_COMPANIES)
                if not canSend then
                    Debug.error(Debug, "Player does not have permission to send invoices to companies")
                    return { success = false, error = "You do not have permission to send invoices to companies" }
                end
            end
            recipientIdentifier  = "job:" .. invoiceData.jobName
            recipientAccountType = "job"
            recipientJobName     = invoiceData.jobName
        else
            -- Personal recipient: prefer explicit identifier, fall back to resolving from source
            recipientIdentifier = invoiceData.recipient_identifier
            if not recipientIdentifier and invoiceData.recipient_source then
                local recipSource = tonumber(invoiceData.recipient_source)
                if recipSource and recipSource > 0 then
                    recipientIdentifier = Core.getIdentifier(recipSource)
                    if not recipientIdentifier then
                        Debug.error(Debug, "Failed to get identifier for recipient source:", recipSource)
                        return { success = false, error = "Invalid recipient player source or player is offline" }
                    end
                else
                    Debug.error(Debug, "Invalid recipient source provided:", invoiceData.recipient_source)
                    return { success = false, error = "Invalid recipient player source" }
                end
            end
            if not recipientIdentifier or recipientIdentifier == "" then
                Debug.error(Debug, "No valid recipient identifier found")
                return { success = false, error = "Recipient identifier is required" }
            end
            local isValid, validationError = Core.isValidIdentifier(recipientIdentifier)
            if not isValid then
                Debug.error(Debug, "Invalid recipient identifier:", recipientIdentifier, "Error:", validationError)
                return { success = false, error = validationError }
            end
        end

        -- Sender account type
        local senderAccountType = invoiceData.accountType or "personal"
        if senderAccountType == "job" then
            local senderJob = Core.getPlayerJob(playerSource)
            local senderJobName = senderJob and senderJob.name
            if not senderJobName then
                return { success = false, error = "No job found for sender" }
            end
            if JobPermissions.isJobBlocked(senderJobName) then
                return { success = false, error = "Your job is not authorized to use billing system" }
            end
        end

        return createInvoiceWithAccountType(playerSource, recipientIdentifier, {
            amount               = invoiceData.amount,
            title                = invoiceData.title,
            description          = invoiceData.description,
            due_date             = invoiceData.due_date,
            recipientAccountType = recipientAccountType,
            recipientJobName     = recipientJobName,
        }, senderAccountType)
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_ALL_SENT_INVOICES",
    eventCallback = function(playerSource, params)
        local accountType = (params and params.accountType) or "personal"
        local invoices    = getAllInvoicesWithAccountType(playerSource, "SENT", accountType)
        if not invoices then
            return { success = false, data = {} }
        end
        Debug.info(Debug, "Sending all sent invoices to client for source", playerSource, #invoices, "invoices, accountType:", accountType)
        return { success = true, data = invoices }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_ALL_RECEIVED_INVOICES",
    eventCallback = function(playerSource, params)
        local accountType = (params and params.accountType) or "personal"
        local invoices    = getAllInvoicesWithAccountType(playerSource, "RECEIVED", accountType)
        if not invoices then
            return { success = false, data = {} }
        end
        Debug.info(Debug, "Sending all received invoices to client for source", playerSource, #invoices, "invoices, accountType:", accountType)
        return { success = true, data = invoices }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_USER",
    eventCallback = function(playerSource)
        local playerIdentifier = Core.getIdentifier(playerSource)
        if not playerIdentifier then
            Debug.error(Debug, "Failed to get identifier for source", playerSource)
            return { success = false, error = "Failed to get player identifier" }
        end

        Debug.debug(Debug, "Fetching user data for identifier", playerIdentifier)

        local playerJob     = Core.getPlayerJob(playerSource)
        local jobPermissions = nil

        if playerJob and playerJob.name then
            local grade = playerJob.grade or 0
            Debug.debug(Debug, "[GET_USER_DATA] job.grade type:", type(playerJob.grade), "value:", playerJob.grade)
            jobPermissions = JobPermissions.getPlayerPermissions(playerJob.name, grade)
            Debug.info(Debug, "Job permissions for", playerJob.name, "grade", playerJob.grade, "(type:", type(playerJob.grade), "):", jobPermissions)
        end

        local fullName = Core.getCharacterName(playerSource) or "Unknown"
        local userData = {
            identifier      = playerIdentifier,
            fullName        = fullName,
            job             = playerJob,
            jobPermissions  = jobPermissions,
        }

        Debug.info(Debug, "User data for source", playerSource, "is", userData)
        return { success = true, data = userData }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_JOB_AVATAR",
    eventCallback = function(playerSource)
        local playerJob = Core.getPlayerJob(playerSource)
        if not playerJob or not playerJob.name then
            Debug.warn(Debug, "No job found for player source:", playerSource)
            return { success = true, data = { avatar = nil, isImageUrl = false } }
        end

        local avatar    = Config.JobAccount and Config.JobAccount.jobAvatars and Config.JobAccount.jobAvatars[playerJob.name]
        local isImageUrl = false

        if avatar then
            isImageUrl = avatar:find("^https?://") ~= nil
            Debug.info(Debug, "Found job avatar for", playerJob.name, "->", avatar, "isImageUrl:", isImageUrl)
        else
            Debug.info(Debug, "No avatar configured for job:", playerJob.name)
        end

        return {
            success = true,
            data = {
                avatar    = avatar,
                isImageUrl = isImageUrl,
                jobName   = playerJob.name,
                jobLabel  = playerJob.label,
            },
        }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:CHECK_PAYMENT_BALANCE",
    eventCallback = function(playerSource, invoiceUuid)
        local invoice = getInvoice(invoiceUuid)
        if not invoice then
            return { success = false, error = "Invoice not found" }
        end

        local playerIdentifier = Core.getIdentifier(playerSource)
        if not playerIdentifier then
            return { success = false, error = "Failed to get player identifier" }
        end

        local recipientAccountType = invoice.recipient_account_type or "personal"
        local rawAmount            = tonumber(invoice.amount)
        if not rawAmount then
            return { success = false, error = "Invalid amount" }
        end

        local issuerType        = invoice.issuer_account_type or "personal"
        local taxRate           = GetTaxRate(issuerType, invoice.issuer_job)
        local taxAmount, totalDue = CalculateTax(rawAmount, taxRate)

        local canPay     = false
        local balance    = 0
        local accountTag = "personal"

        if recipientAccountType == "job" then
            local playerJob = Core.getPlayerJob(playerSource)
            if not playerJob then
                return { success = false, error = "You are not authorized to pay this invoice" }
            end
            if playerJob.name == invoice.recipient_job then
                balance  = tonumber(Core.getJobMoney(playerJob.name)) or 0
                canPay   = totalDue <= balance
                accountTag = "job"
            end
        else
            if playerIdentifier == invoice.recipient_identifier then
                balance = Core.getPlayerBankMoney(playerIdentifier)
                canPay  = totalDue <= balance
            else
                return { success = false, error = "You are not authorized to pay this invoice" }
            end
        end

        local jobName = (recipientAccountType == "job" and invoice.recipient_job_name) or nil

        return {
            success = true,
            data = {
                canPay         = canPay,
                currentBalance = balance,
                requiredAmount = totalDue,
                subtotal       = rawAmount,
                taxAmount      = taxAmount,
                taxRate        = taxRate,
                accountType    = accountTag,
                jobName        = jobName,
            },
        }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:PAY_INVOICE",
    eventCallback = function(playerSource, invoiceUuid)
        local result = payInvoice(invoiceUuid, playerSource)
        if not result or not result.success then
            return { success = false, error = (result and result.message) or "Failed to pay invoice" }
        end
        return { success = true, data = result }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_THEME_CONFIG",
    eventCallback = function(playerSource)
        local theme = buildThemeConfig()
        if not theme then
            Debug.debug(Debug, "No custom theme config found, using CSS defaults")
            return { success = true, data = nil }
        end
        Debug.debug(Debug, "Sending custom theme config to client", json.encode(theme))
        return { success = true, data = theme }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_CURRENCY_CONFIG",
    eventCallback = function(playerSource)
        local currency = Config.Currency or {}
        local config = {
            code               = currency.code             or "USD",
            symbol             = currency.symbol           or "$",
            symbolPosition     = currency.symbolPosition   or "prefix",
            useNativeFormatting = (currency.useNativeFormatting ~= nil) and currency.useNativeFormatting or true,
        }
        Debug.debug(Debug, "Sending currency config to client", json.encode(config))
        return { success = true, data = config }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:DELETE_INVOICE",
    eventCallback = function(playerSource, invoiceUuid)
        local invoice = getInvoice(invoiceUuid)
        if not invoice then
            return { success = false, message = "Invoice not found" }
        end

        local playerIdentifier = Core.getIdentifier(playerSource)
        if not playerIdentifier then
            return { success = false, message = "Failed to get player identifier" }
        end

        local playerJob         = Core.getPlayerJob(playerSource)
        local issuerAccountType = invoice.issuer_account_type or "personal"
        local isAuthorized      = false

        if issuerAccountType == "personal" and playerIdentifier == invoice.issuer_identifier then
            isAuthorized = true
        end
        if issuerAccountType == "job" and playerJob and playerJob.name == invoice.issuer_job then
            isAuthorized = true
        end

        if playerJob then
            Debug.debug(Debug, "[DELETE_INVOICE] playerJob.grade type:", type(playerJob.grade), "value:", playerJob.grade)
            local grade      = playerJob.grade or 0
            local canDeleteAny = JobPermissions.hasPermission(playerJob.name, grade, JobPermissions.PERMISSIONS.DELETE_ANY_INVOICE)
            if canDeleteAny then
                isAuthorized = true
                Debug.info(Debug, "Player has deleteAnyInvoice permission, allowing delete")
            end
        end

        if not isAuthorized then
            return { success = false, message = "You are not authorized to delete this invoice" }
        end

        local result = deleteInvoice(invoiceUuid)
        if not result or not result.success then
            return { success = false, data = false, message = (result and result.message) or "Failed to delete invoice" }
        end
        return { success = true, data = true, message = result.message or "Invoice deleted successfully" }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_CONTACTS",
    eventCallback = function(playerSource)
        local playerIdentifier = Core.getIdentifier(playerSource)
        if not playerIdentifier then
            Debug.error(Debug, "Failed to get identifier for source", playerSource)
            return { success = false, error = "Failed to get player identifier" }
        end
        local contacts = getContacts(playerIdentifier)
        return { success = true, data = contacts or {} }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:ADD_CONTACT",
    eventCallback = function(playerSource, params)
        local playerIdentifier = Core.getIdentifier(playerSource)
        if not playerIdentifier then
            Debug.error(Debug, "Failed to get identifier for source", playerSource)
            return { success = false, error = "Failed to get player identifier" }
        end
        if not params or not params.contactIdentifier or not params.displayName then
            return { success = false, error = "Missing contact identifier or display name" }
        end
        local success, errorMsg = addContact(playerIdentifier, params.contactIdentifier, params.displayName)
        return { success = success, data = success, error = (not success and errorMsg) or nil }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:UPDATE_CONTACT",
    eventCallback = function(playerSource, params)
        local playerIdentifier = Core.getIdentifier(playerSource)
        if not playerIdentifier then
            Debug.error(Debug, "Failed to get identifier for source", playerSource)
            return { success = false, error = "Failed to get player identifier" }
        end
        if not params or not params.contactId or not params.displayName then
            return { success = false, error = "Missing contact ID or display name" }
        end
        local success = updateContact(playerIdentifier, params.contactId, params.displayName)
        return { success = success, data = success, error = not success and "Failed to update contact" or nil }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:DELETE_CONTACT",
    eventCallback = function(playerSource, params)
        local playerIdentifier = Core.getIdentifier(playerSource)
        if not playerIdentifier then
            Debug.error(Debug, "Failed to get identifier for source", playerSource)
            return { success = false, error = "Failed to get player identifier" }
        end
        if not params or not params.contactId then
            return { success = false, error = "Missing contact ID" }
        end
        local success = deleteContact(playerIdentifier, params.contactId)
        return { success = success, data = success, error = not success and "Failed to delete contact" or nil }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_OVERDUE_INVOICES",
    eventCallback = function(playerSource, params)
        local accountType = (params and params.accountType) or "personal"
        local invoices    = getOverdueInvoices(playerSource, accountType)
        local count       = invoices and #invoices or 0
        Debug.info(Debug, "Sending overdue invoices to client for source", playerSource, count, "invoices")
        return { success = true, data = invoices or {} }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_PLAYER_BY_SOURCE",
    eventCallback = function(playerSource, params)
        if not params or not params.playerSource then
            return { success = false, error = "Player source is required" }
        end
        local targetSource = tonumber(params.playerSource)
        if not targetSource or targetSource <= 0 then
            return { success = false, error = "Invalid player source" }
        end
        local targetIdentifier = Core.getIdentifier(targetSource)
        if not targetIdentifier then
            return { success = false, error = "Player is not online or invalid source" }
        end

        local characterName = Core.getCharacterName(targetSource) or "Unknown"
        local targetCoords  = GetEntityCoords(GetPlayerPed(targetSource))
        local selfCoords    = GetEntityCoords(GetPlayerPed(playerSource))
        local distance      = #(vector3(targetCoords.x, targetCoords.y, targetCoords.z) - vector3(selfCoords.x, selfCoords.y, selfCoords.z))

        local playerData = {
            source        = targetSource,
            identifier    = targetIdentifier,
            characterName = characterName,
            coords        = targetCoords,
            distance      = distance,
        }

        Debug.info(Debug, "Found player by source", targetSource, "data:", playerData)
        return { success = true, data = playerData }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:VALIDATE_IDENTIFIER",
    eventCallback = function(playerSource, params)
        if not params or not params.identifier then
            return { success = true, data = { isValid = false, errorMessage = "No identifier provided" } }
        end
        local identifier = params.identifier
        if #identifier < 3 then
            return { success = true, data = { isValid = false, errorMessage = "Identifier is too short" } }
        end
        local isValid, errorMsg = Core.isValidIdentifier(identifier)
        Debug.info(Debug, "Validated identifier", identifier, "result:", isValid, errorMsg)
        return { success = true, data = { isValid = isValid, errorMessage = errorMsg } }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_PRESETS",
    eventCallback = function(playerSource)
        local playerIdentifier = Core.getIdentifier(playerSource)
        if not playerIdentifier then
            Debug.error(Debug, "Failed to get identifier for source", playerSource)
            return { success = false, error = "Failed to get player identifier" }
        end
        local presets = getPresets(playerIdentifier)
        return { success = true, data = presets or {} }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:CREATE_PRESET",
    eventCallback = function(playerSource, params)
        local playerIdentifier = Core.getIdentifier(playerSource)
        if not playerIdentifier then
            Debug.error(Debug, "Failed to get identifier for source", playerSource)
            return { success = false, error = "Failed to get player identifier" }
        end
        if not params or not params.name or not params.title or not params.description then
            return { success = false, error = "Missing required preset data (name, title, description)" }
        end
        local success, errorMsg, insertId = createPreset(playerIdentifier, params)
        if success then
            return {
                success = true,
                data = {
                    id          = insertId,
                    name        = params.name,
                    title       = params.title,
                    description = params.description,
                    amount      = tonumber(params.amount) or 0,
                    category    = params.category or "custom",
                },
            }
        else
            return { success = false, error = errorMsg or "Failed to create preset" }
        end
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:UPDATE_PRESET",
    eventCallback = function(playerSource, params)
        local playerIdentifier = Core.getIdentifier(playerSource)
        if not playerIdentifier then
            Debug.error(Debug, "Failed to get identifier for source", playerSource)
            return { success = false, error = "Failed to get player identifier" }
        end
        if not params or not params.presetId then
            return { success = false, error = "Missing preset ID" }
        end
        local success, errorMsg = updatePreset(playerIdentifier, params.presetId, params)
        return { success = success, data = success, error = not success and (errorMsg or "Failed to update preset") or nil }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:DELETE_PRESET",
    eventCallback = function(playerSource, params)
        local playerIdentifier = Core.getIdentifier(playerSource)
        if not playerIdentifier then
            Debug.error(Debug, "Failed to get identifier for source", playerSource)
            return { success = false, error = "Failed to get player identifier" }
        end
        if not params or not params.presetId then
            return { success = false, error = "Missing preset ID" }
        end
        local success, errorMsg = deletePreset(playerIdentifier, params.presetId)
        return { success = success, data = success, error = not success and (errorMsg or "Failed to delete preset") or nil }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_PAY_REFERENCE_CONFIG",
    eventCallback = function(playerSource)
        local canUse, errorMessage = isPayReferenceEnabled(playerSource)
        return {
            success = true,
            data = {
                enabled      = Config.PayReference and Config.PayReference.enabled or false,
                canUse       = canUse,
                errorMessage = errorMessage,
            },
        }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_CITIZEN_LOOKUP_CONFIG",
    eventCallback = function(playerSource)
        local canUse, errorMessage = isCitizenLookupAllowed(playerSource)
        return {
            success = true,
            data = {
                enabled                 = Config.CitizenLookup and Config.CitizenLookup.enabled or false,
                canUse                  = canUse,
                errorMessage            = errorMessage,
                paidInvoiceRetentionDays = (Config.Invoice and Config.Invoice.paidInvoiceRetentionDays) or 8,
            },
        }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:LOOKUP_INVOICE_BY_REFERENCE",
    eventCallback = function(playerSource, params)
        local canUse, errorMsg = isPayReferenceEnabled(playerSource)
        if not canUse then
            return { success = false, error = errorMsg }
        end
        if not params or not params.reference then
            return { success = false, error = "Invoice reference is required" }
        end

        local rows = MySQL.query.await("SELECT * FROM bablo_invoices WHERE uuid = ? LIMIT 1", { params.reference })
        if not rows or #rows == 0 then
            return { success = false, error = "Invoice not found" }
        end

        local invoice          = rows[1]
        local playerIdentifier = Core.getIdentifier(playerSource)
        local playerJob        = Core.getPlayerJob(playerSource)
        local isCreator        = invoice.issuer_identifier == playerIdentifier

        -- Determine if player is from the same job as the creator
        local isSameJobAsCreator = false
        if invoice.issuer_account_type == "job" and playerJob and playerJob.name then
            local issuerJobName = invoice.issuer_job or (invoice.issuer_identifier and invoice.issuer_identifier:match("^job:(.+)$"))
            if issuerJobName and playerJob.name == issuerJobName then
                isSameJobAsCreator = true
            end
        end

        local canPay = invoice.status == "pending" and not isCreator

        return {
            success = true,
            data = {
                invoice           = invoice,
                isCreator         = isCreator,
                isSameJobAsCreator = isSameJobAsCreator,
                canPay            = canPay,
            },
        }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:CHECK_REFERENCE_PAYMENT_BALANCE",
    eventCallback = function(playerSource, params)
        local canUse, errorMsg = isPayReferenceEnabled(playerSource)
        if not canUse then
            return { success = false, error = errorMsg }
        end
        if not params or not params.reference then
            return { success = false, error = "Invoice reference is required" }
        end

        local rows = MySQL.query.await("SELECT * FROM bablo_invoices WHERE uuid = ? LIMIT 1", { params.reference })
        if not rows or #rows == 0 then
            return { success = false, error = "Invoice not found" }
        end

        local invoice          = rows[1]
        local playerIdentifier = Core.getIdentifier(playerSource)
        local rawAmount        = tonumber(invoice.amount) or 0
        local issuerType       = invoice.issuer_account_type or "personal"
        local taxRate          = GetTaxRate(issuerType, invoice.issuer_job)
        local taxAmount, totalDue = CalculateTax(rawAmount, taxRate)

        local balance = Core.getPlayerBankMoney(playerIdentifier)
        local canPay  = totalDue <= balance

        return {
            success = true,
            data = {
                canPay         = canPay,
                currentBalance = balance,
                requiredAmount = totalDue,
                subtotal       = rawAmount,
                taxAmount      = taxAmount,
                taxRate        = taxRate,
                accountType    = "personal",
            },
        }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:PAY_INVOICE_BY_REFERENCE",
    eventCallback = function(playerSource, params)
        local canUse, errorMsg = isPayReferenceEnabled(playerSource)
        if not canUse then
            return { success = false, error = errorMsg }
        end
        if not params or not params.reference then
            return { success = false, error = "Invoice reference is required" }
        end

        local rows = MySQL.query.await("SELECT * FROM bablo_invoices WHERE uuid = ? LIMIT 1", { params.reference })
        if not rows or #rows == 0 then
            return { success = false, error = "Invoice not found" }
        end

        local invoice          = rows[1]
        local playerIdentifier = Core.getIdentifier(playerSource)
        local playerJob        = Core.getPlayerJob(playerSource)

        if invoice.status ~= "pending" then
            return { success = false, error = "Invoice has already been paid" }
        end
        if invoice.issuer_identifier == playerIdentifier then
            return { success = false, error = "You cannot pay your own invoice" }
        end

        -- Prevent same-job payment
        if invoice.issuer_account_type == "job" and playerJob and playerJob.name then
            local issuerJobName = invoice.issuer_job or (invoice.issuer_identifier and invoice.issuer_identifier:match("^job:(.+)$"))
            if issuerJobName and playerJob.name == issuerJobName then
                return { success = false, error = "You cannot pay an invoice created by your job" }
            end
        end

        local rawAmount  = tonumber(invoice.amount) or 0
        local issuerType = invoice.issuer_account_type or "personal"
        local taxRate    = GetTaxRate(issuerType, invoice.issuer_job)
        local taxAmount, totalDue = CalculateTax(rawAmount, taxRate)

        local balance = Core.getPlayerBankMoney(playerIdentifier)
        if totalDue > balance then
            return { success = false, error = "Insufficient funds" }
        end

        local deducted = Core.removePlayerBankMoney(playerIdentifier, totalDue)
        if not deducted then
            return { success = false, error = "Failed to process payment" }
        end

        -- Credit issuer
        if issuerType == "job" then
            local issuerJobName = invoice.issuer_job or invoice.issuer_job_name
            if issuerJobName then
                CreditJobInvoicePayout(issuerJobName, invoice.issuer_identifier, rawAmount)
            end
        else
            local ok = Core.addPlayerBankMoney(invoice.issuer_identifier, rawAmount)
            if not ok then
                Debug.info(Debug, "Issuer is offline, using offline money function for:", invoice.issuer_identifier)
                ok = Core.addOfflineMoney(invoice.issuer_identifier, "bank", rawAmount)
                if not ok then
                    Debug.error(Debug, "Failed to add money to offline issuer:", invoice.issuer_identifier)
                end
            end
        end

        -- Credit tax society
        if taxAmount and taxAmount > 0 and Config.Tax and Config.Tax.recipientSociety then
            local society = Config.Tax.recipientSociety
            local ok, result = pcall(function() return Core.addJobMoney(society, taxAmount) end)
            if not ok then
                Debug.warn(Debug, "Tax credit to society", society, "raised an error:", tostring(result), "- payment is not rolled back; tax becomes a sink for this invoice")
            elseif result == false then
                Debug.warn(Debug, "Tax credit to society", society, "rejected by framework (society missing?) - payment is not rolled back; tax becomes a sink for this invoice")
            end
        end

        local paidAt = os.time() * 1000
        MySQL.update.await("UPDATE bablo_invoices SET status = 'paid', paid_at = ? WHERE id = ?", { paidAt, invoice.id })

        Debug.info(Debug, "Invoice", params.reference, "paid by", playerIdentifier, "amount:", rawAmount)
        return { success = true, data = { message = "Invoice paid successfully", amount = rawAmount } }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:SEARCH_CITIZEN",
    eventCallback = function(playerSource, params)
        local canUse, errorMsg = isCitizenLookupAllowed(playerSource)
        if not canUse then
            return { success = false, error = errorMsg }
        end
        if not params or not params.searchTerm then
            return { success = false, error = "Search term is required" }
        end

        if not Core.searchCitizens then
            return { success = false, error = "Search function not available for this framework" }
        end

        local citizens = Core.searchCitizens(params.searchTerm, 20) or {}
        local results  = {}

        for _, citizen in ipairs(citizens) do
            local unpaidStats = MySQL.query.await([[
                SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
                FROM bablo_invoices
                WHERE recipient_identifier = ? AND status = 'pending'
            ]], { citizen.identifier })

            local paidStats = MySQL.query.await([[
                SELECT COUNT(*) as count FROM bablo_invoices
                WHERE recipient_identifier = ? AND status = 'paid'
            ]], { citizen.identifier })

            -- Check online status and try to get live name
            local isOnline = false
            for _, playerNetId in ipairs(GetPlayers()) do
                local pid        = tonumber(playerNetId)
                local identifier = Core.getIdentifier(pid)
                if identifier == citizen.identifier then
                    isOnline = true
                    local liveName = Core.getCharacterName(pid)
                    if liveName then citizen.name = liveName end
                    break
                end
            end

            table.insert(results, {
                identifier  = citizen.identifier,
                name        = citizen.name or citizen.identifier,
                unpaidCount = (unpaidStats and unpaidStats[1] and unpaidStats[1].count) or 0,
                unpaidTotal = (unpaidStats and unpaidStats[1] and tonumber(unpaidStats[1].total)) or 0,
                paidCount   = (paidStats   and paidStats[1]   and paidStats[1].count)   or 0,
                isOnline    = isOnline,
            })
        end

        return { success = true, data = results }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_CITIZEN_INFO",
    eventCallback = function(playerSource, params)
        local canUse, errorMsg = isCitizenLookupAllowed(playerSource)
        if not canUse then
            return { success = false, error = errorMsg }
        end
        if not params or not params.identifier then
            return { success = false, error = "Citizen identifier is required" }
        end

        local citizenId = params.identifier

        local unpaidStats = MySQL.query.await([[
            SELECT COUNT(*) as count, COALESCE(SUM(amount), 0) as total
            FROM bablo_invoices
            WHERE recipient_identifier = ? AND status = 'pending'
        ]], { citizenId })

        local paidStats = MySQL.query.await([[
            SELECT COUNT(*) as count FROM bablo_invoices
            WHERE recipient_identifier = ? AND status = 'paid'
        ]], { citizenId })

        -- Resolve display name: prefer online player, then offline lookup
        local displayName = citizenId
        local isOnline    = false

        for _, playerNetId in ipairs(GetPlayers()) do
            local pid        = tonumber(playerNetId)
            local identifier = Core.getIdentifier(pid)
            if identifier == citizenId then
                isOnline = true
                displayName = Core.getCharacterName(pid) or citizenId
                break
            end
        end

        if not isOnline and Core.getCitizenName then
            local offlineName = Core.getCitizenName(citizenId)
            if offlineName then displayName = offlineName end
        end

        return {
            success = true,
            data = {
                identifier  = citizenId,
                name        = displayName,
                unpaidCount = (unpaidStats and unpaidStats[1] and unpaidStats[1].count) or 0,
                unpaidTotal = (unpaidStats and unpaidStats[1] and tonumber(unpaidStats[1].total)) or 0,
                paidCount   = (paidStats   and paidStats[1]   and paidStats[1].count)   or 0,
                isOnline    = isOnline,
            },
        }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_CITIZEN_UNPAID_INVOICES",
    eventCallback = function(playerSource, params)
        local canUse, errorMsg = isCitizenLookupAllowed(playerSource)
        if not canUse then
            return { success = false, error = errorMsg }
        end
        if not params or not params.identifier then
            return { success = false, error = "Citizen identifier is required" }
        end

        local invoices = MySQL.query.await([[
            SELECT * FROM bablo_invoices
            WHERE recipient_identifier = ? AND status = 'pending'
            ORDER BY created_at DESC
        ]], { params.identifier })

        return { success = true, data = invoices or {} }
    end,
})

RegisterServerCallback({
    eventName = "bablo-billing:GET_TAX_INFO",
    eventCallback = function(playerSource, params)
        local taxEnabled = Config.Tax and Config.Tax.enabled
        if not taxEnabled then
            return { success = true, data = { enabled = false, rate = 0 } }
        end

        local accountType = "personal"
        local jobName     = nil

        if params and params.invoiceUuid then
            local invoice = getInvoice(params.invoiceUuid)
            if invoice then
                accountType = invoice.issuer_account_type or "personal"
                jobName     = invoice.issuer_job
            end
        elseif params and params.accountType then
            accountType = params.accountType
            if accountType == "job" then
                local playerJob = Core.getPlayerJob(playerSource)
                jobName = playerJob and playerJob.name
            end
        end

        local taxRate = GetTaxRate(accountType, jobName)
        return { success = true, data = { enabled = true, rate = taxRate } }
    end,
})
