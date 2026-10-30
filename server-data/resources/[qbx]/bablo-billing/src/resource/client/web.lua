-- ============================================================
-- web.lua  –  bablo-billing  (client)
-- ============================================================

WEB = {}

-- ── Internal helpers ─────────────────────────────────────────

-- Wraps RegisterNUICallback with pcall + debug logging.
function WEB.RegisterNUICallback(callbackName, handler)
    RegisterNUICallback(callbackName, function(data, cb)
        local ok, result = pcall(function()
            return handler(data, cb)
        end)

        Debug.info(Debug, "NUI Callback", callbackName, "called with data:", data)
        Debug.info(Debug, "NUI Callback", callbackName, "result:", result)

        if not ok then
            Debug.error(Debug, "Error in NUI callback '" .. callbackName .. "':", result)
            cb({ success = false, message = "An error occurred in the NUI callback" })
        elseif result ~= nil then
            cb(result)
        else
            cb({ success = true })
        end
    end)
end

-- Fires a server callback and returns the response, or a failure table.
local function serverCall(eventName, ...)
    local args = { ... }
    local response = TriggerServerCallback({ eventName = eventName, args = args })
    return response
end

-- Returns a standard failure response table.
local function failResponse(message)
    return { success = false, message = message }
end

-- ── NUI Callbacks ────────────────────────────────────────────

WEB.RegisterNUICallback("SET_IS_JOB_ACCOUNT", function(data)
    Debug.info(Debug, "Setting isJobAccount to", data)
    return { success = true, data = true }
end)

WEB.RegisterNUICallback("GET_RECEIVED_INVOICES", function(data)
    local response = serverCall("bablo-billing:GET_RECEIVED_INVOICES", data)
    Debug.info(Debug, "Received invoices data from server", response)
    return response or failResponse("Failed to get received invoices")
end)

WEB.RegisterNUICallback("CLOSE_MENU", function()
    Debug.info(Debug, "Closing billing menu")
    SetNuiFocus(false, false)
    SendNUIMessage({ event = "SET_OPEN", data = false })
    Close()
    return { success = true }
end)

WEB.RegisterNUICallback("GET_NEARBY_PLAYERS", function(data)
    local radius   = data.radius or 10
    local response = serverCall("bablo-billing:GET_NEARBY_PLAYERS", radius)
    Debug.info(Debug, "Received nearby players data from server", response)
    return response or failResponse("Failed to get nearby players")
end)

WEB.RegisterNUICallback("CREATE_INVOICE", function(data)
    Debug.info(Debug, "Creating invoice", data)

    local recipientIdentifier = nil
    local recipientSource     = nil
    local jobName             = nil

    if data.recipientType == "job" then
        if not data.jobName or data.jobName == "" then
            Debug.error(Debug, "No job name provided for job invoice")
            return failResponse("No job name provided")
        end
        jobName = data.jobName
        Debug.info(Debug, "Creating invoice for job:", jobName)
    else
        -- Resolve identifier: prefer selectedPlayer.identifier, fall back to data.identifier
        local identifier = (data.selectedPlayer and data.selectedPlayer.identifier) or data.identifier

        if not identifier then
            Debug.error(Debug, "No identifier provided")
            return failResponse("No identifier provided")
        end

        -- If recipientSource is present, use source-based delivery (online player);
        -- otherwise use identifier-based delivery (offline player).
        if data.recipientSource then
            recipientSource     = tonumber(data.recipientSource)
            recipientIdentifier = nil
        else
            recipientIdentifier = identifier
        end
    end

    if not data.amount or data.amount <= 0 then
        Debug.error(Debug, "Invalid amount provided")
        return failResponse("Invalid amount provided")
    end

    if not data.title or data.title == "" then
        Debug.error(Debug, "No title provided")
        return failResponse("No title provided")
    end

    local invoice = {
        id                   = math.random(1000, 9999),
        amount               = data.amount,
        title                = data.title,
        description          = data.description or "",
        recipient_identifier = recipientIdentifier,
        recipient_source     = recipientSource,
        recipientType        = data.recipientType,
        jobName              = jobName,
        status               = "pending",
        accountType          = data.accountType or "personal",
    }

    local response = serverCall("bablo-billing:CREATE_INVOICE", invoice)

    if not response or not response.success then
        Debug.error(Debug, "Failed to create invoice")
        return failResponse("Failed to create invoice")
    end

    Debug.info(Debug, "Successfully created invoice:", response.data)
    return response
end)

WEB.RegisterNUICallback("GET_SENT_INVOICES", function(data)
    local response = serverCall("bablo-billing:GET_SENT_INVOICES", data)
    Debug.info(Debug, "Received sent invoices data from server", response)
    return response or failResponse("Failed to get sent invoices")
end)

WEB.RegisterNUICallback("GET_ALL_SENT_INVOICES", function()
    local response = serverCall("bablo-billing:GET_ALL_SENT_INVOICES")
    Debug.info(Debug, "Received all sent invoices data from server", response)
    return response or failResponse("Failed to get all sent invoices")
end)

WEB.RegisterNUICallback("GET_ALL_RECEIVED_INVOICES", function()
    local response = serverCall("bablo-billing:GET_ALL_RECEIVED_INVOICES")
    Debug.info(Debug, "Received all received invoices data from server", response)
    return response or failResponse("Failed to get all received invoices")
end)

WEB.RegisterNUICallback("GET_OVERDUE_INVOICES", function(data)
    local response = serverCall("bablo-billing:GET_OVERDUE_INVOICES", data)
    Debug.info(Debug, "Received overdue invoices data from server", response)
    return response or failResponse("Failed to get overdue invoices")
end)

WEB.RegisterNUICallback("GET_PLAYER_BY_SOURCE", function(data)
    local response = serverCall("bablo-billing:GET_PLAYER_BY_SOURCE", data)
    Debug.info(Debug, "Received player data by source from server", response)
    return response or failResponse("Failed to get player by source")
end)

WEB.RegisterNUICallback("GET_ALL_JOBS", function()
    local response = serverCall("bablo-billing:GET_ALL_JOBS")
    Debug.info(Debug, "Received jobs data from server", response)
    return response or failResponse("Failed to get jobs")
end)

WEB.RegisterNUICallback("VALIDATE_IDENTIFIER", function(data)
    local response = serverCall("bablo-billing:VALIDATE_IDENTIFIER", data)
    Debug.info(Debug, "Received identifier validation result from server", response)
    return response or { success = false, data = { isValid = false, errorMessage = "Failed to validate identifier" } }
end)

WEB.RegisterNUICallback("GET_LOCALE", function()
    Wait(1000)   -- brief delay to ensure resources are ready before locale load

    local localeName = Config.Locale
    local localeData = loadLocale(localeName)   -- ⚠️ loadLocale must be defined elsewhere (framework/locale file)

    if not localeData then
        Debug.error(Debug, "Failed to load locale:", localeName)
        return failResponse("Failed to load locale")
    end

    Debug.info(Debug, "Loaded locale:", localeName, localeData)
    return { success = true, data = localeData }
end)

WEB.RegisterNUICallback("GET_TOTAL_INVOICE_PRICE", function(data)
    Debug.info(Debug, "Getting total price of invoices", data)
    local response = serverCall("bablo-billing:GET_TOTAL_PRICE_INVOICES")
    Debug.info(Debug, "Received total price of invoices from server", response)
    return response or failResponse("Failed to get total invoice price")
end)

WEB.RegisterNUICallback("CHECK_PAYMENT_BALANCE", function(data)
    local invoiceId = data.invoiceId
    Debug.info(Debug, "Checking payment balance for invoice", invoiceId)

    if not invoiceId then
        Debug.error(Debug, "No invoice ID provided")
        return failResponse("No invoice ID provided")
    end

    local response = serverCall("bablo-billing:CHECK_PAYMENT_BALANCE", invoiceId)
    Debug.info(Debug, "Balance check response", response)
    return response or failResponse("Failed to check payment balance")
end)

WEB.RegisterNUICallback("GET_TAX_INFO", function(data)
    Debug.info(Debug, "Getting tax info", data)
    local response = serverCall("bablo-billing:GET_TAX_INFO", data)
    return response or failResponse("Failed to get tax info")
end)

WEB.RegisterNUICallback("PAY_INVOICE", function(data)
    local invoiceId = data.invoiceId
    Debug.info(Debug, "Paying invoice", invoiceId)

    if not invoiceId then
        Debug.error(Debug, "No invoice ID provided")
        return failResponse("No invoice ID provided")
    end

    local response = serverCall("bablo-billing:PAY_INVOICE", invoiceId)
    Debug.info(Debug, "Invoice response", response)

    if not response or not response.success then
        Debug.error(Debug, "Failed to pay invoice")
        return failResponse("Failed to pay invoice")
    end

    Debug.info(Debug, "Successfully paid invoice:", response.data)
    return response
end)

WEB.RegisterNUICallback("DELETE_INVOICE", function(data)
    local invoiceId = data.invoiceId

    if not invoiceId then
        Debug.error(Debug, "No invoice ID provided")
        return failResponse("No invoice ID provided")
    end

    local response = serverCall("bablo-billing:DELETE_INVOICE", invoiceId)

    if not response or not response.success then
        Debug.error(Debug, "Failed to delete invoice")
        return failResponse("Failed to delete invoice")
    end

    Debug.info(Debug, "Successfully deleted invoice:", invoiceId)
    return response
end)

WEB.RegisterNUICallback("GET_THEME_CONFIG", function()
    local response = serverCall("bablo-billing:GET_THEME_CONFIG")

    if not response or not response.success then
        Debug.error(Debug, "Failed to get theme config")
        return failResponse("Failed to get theme config")
    end

    Debug.info(Debug, "Successfully retrieved theme config:", json.encode(response.data))
    return response
end)

WEB.RegisterNUICallback("GET_CURRENCY_CONFIG", function()
    local response = serverCall("bablo-billing:GET_CURRENCY_CONFIG")

    if not response or not response.success then
        Debug.error(Debug, "Failed to get currency config")
        return failResponse("Failed to get currency config")
    end

    return response
end)

WEB.RegisterNUICallback("GET_CONTACTS", function()
    local response = serverCall("bablo-billing:GET_CONTACTS")

    if not response or not response.success then
        Debug.error(Debug, "Failed to get contacts")
        return failResponse("Failed to get contacts")
    end

    Debug.info(Debug, "Successfully retrieved contacts:", #response.data, "contacts")
    return response
end)

WEB.RegisterNUICallback("ADD_CONTACT", function(data)
    if not data.contactIdentifier or not data.displayName then
        Debug.error(Debug, "Missing contact identifier or display name")
        return failResponse("Missing contact identifier or display name")
    end

    local response = serverCall("bablo-billing:ADD_CONTACT", data)

    if not response or not response.success then
        Debug.error(Debug, "Failed to add contact")
        return { success = false, message = (response and response.error) or "Failed to add contact" }
    end

    Debug.info(Debug, "Successfully added contact:", data.displayName)
    return response
end)

WEB.RegisterNUICallback("UPDATE_CONTACT", function(data)
    if not data.contactId or not data.displayName then
        Debug.error(Debug, "Missing contact ID or display name")
        return failResponse("Missing contact ID or display name")
    end

    local response = serverCall("bablo-billing:UPDATE_CONTACT", data)

    if not response or not response.success then
        Debug.error(Debug, "Failed to update contact")
        return { success = false, message = (response and response.error) or "Failed to update contact" }
    end

    Debug.info(Debug, "Successfully updated contact:", data.contactId)
    return response
end)

WEB.RegisterNUICallback("DELETE_CONTACT", function(data)
    if not data.contactId then
        Debug.error(Debug, "Missing contact ID")
        return failResponse("Missing contact ID")
    end

    local response = serverCall("bablo-billing:DELETE_CONTACT", data)

    if not response or not response.success then
        Debug.error(Debug, "Failed to delete contact")
        return { success = false, message = (response and response.error) or "Failed to delete contact" }
    end

    Debug.info(Debug, "Successfully deleted contact:", data.contactId)
    return response
end)

WEB.RegisterNUICallback("GET_JOB_AVATAR", function()
    local response = serverCall("bablo-billing:GET_JOB_AVATAR")

    if not response or not response.success then
        Debug.error(Debug, "Failed to get job avatar")
        return failResponse("Failed to get job avatar")
    end

    Debug.info(Debug, "Successfully retrieved job avatar:", response.data)
    return response
end)

WEB.RegisterNUICallback("GET_PRESETS", function()
    local response = serverCall("bablo-billing:GET_PRESETS")

    if not response or not response.success then
        Debug.error(Debug, "Failed to get presets")
        return failResponse("Failed to get presets")
    end

    Debug.info(Debug, "Successfully retrieved presets:", #response.data, "presets")
    return response
end)

WEB.RegisterNUICallback("CREATE_PRESET", function(data)
    if not data.name or not data.title or not data.description then
        Debug.error(Debug, "Missing preset data")
        return failResponse("Missing required preset data (name, title, description)")
    end

    local response = serverCall("bablo-billing:CREATE_PRESET", data)

    if not response or not response.success then
        Debug.error(Debug, "Failed to create preset")
        return { success = false, message = (response and response.error) or "Failed to create preset" }
    end

    Debug.info(Debug, "Successfully created preset:", data.name)
    return response
end)

WEB.RegisterNUICallback("UPDATE_PRESET", function(data)
    if not data.presetId then
        Debug.error(Debug, "Missing preset ID")
        return failResponse("Missing preset ID")
    end

    local response = serverCall("bablo-billing:UPDATE_PRESET", data)

    if not response or not response.success then
        Debug.error(Debug, "Failed to update preset")
        return { success = false, message = (response and response.error) or "Failed to update preset" }
    end

    Debug.info(Debug, "Successfully updated preset:", data.presetId)
    return response
end)

WEB.RegisterNUICallback("DELETE_PRESET", function(data)
    if not data.presetId then
        Debug.error(Debug, "Missing preset ID")
        return failResponse("Missing preset ID")
    end

    local response = serverCall("bablo-billing:DELETE_PRESET", data)

    if not response or not response.success then
        Debug.error(Debug, "Failed to delete preset")
        return { success = false, message = (response and response.error) or "Failed to delete preset" }
    end

    Debug.info(Debug, "Successfully deleted preset:", data.presetId)
    return response
end)

WEB.RegisterNUICallback("CLOSE_QUICK_BILL", function()
    Debug.info(Debug, "Closing quick bill dialog")
    SetNuiFocus(false, false)
    SendNUIMessage({ event = "CLOSE_QUICK_BILL" })
    return { success = true }
end)

WEB.RegisterNUICallback("GET_PAY_REFERENCE_CONFIG", function()
    local response = serverCall("bablo-billing:GET_PAY_REFERENCE_CONFIG")

    if not response or not response.success then
        Debug.error(Debug, "Failed to get pay reference config")
        return failResponse("Failed to get pay reference config")
    end

    return response
end)

WEB.RegisterNUICallback("LOOKUP_INVOICE_BY_REFERENCE", function(data)
    local response = serverCall("bablo-billing:LOOKUP_INVOICE_BY_REFERENCE", data)

    if not response or not response.success then
        Debug.error(Debug, "Failed to lookup invoice by reference")
        return { success = false, message = (response and response.error) or "Invoice not found" }
    end

    return response
end)

WEB.RegisterNUICallback("CHECK_REFERENCE_PAYMENT_BALANCE", function(data)
    local response = serverCall("bablo-billing:CHECK_REFERENCE_PAYMENT_BALANCE", data)

    if not response or not response.success then
        Debug.error(Debug, "Failed to check reference payment balance")
        return { success = false, message = (response and response.error) or "Failed to check balance" }
    end

    return response
end)

WEB.RegisterNUICallback("PAY_INVOICE_BY_REFERENCE", function(data)
    local response = serverCall("bablo-billing:PAY_INVOICE_BY_REFERENCE", data)

    if not response or not response.success then
        Debug.error(Debug, "Failed to pay invoice by reference")
        return { success = false, message = (response and response.error) or "Failed to pay invoice" }
    end

    return response
end)

WEB.RegisterNUICallback("GET_CITIZEN_LOOKUP_CONFIG", function()
    local response = serverCall("bablo-billing:GET_CITIZEN_LOOKUP_CONFIG")

    if not response or not response.success then
        Debug.error(Debug, "Failed to get citizen lookup config")
        return failResponse("Failed to get citizen lookup config")
    end

    return response
end)

WEB.RegisterNUICallback("SEARCH_CITIZEN", function(data)
    local response = serverCall("bablo-billing:SEARCH_CITIZEN", data)

    if not response or not response.success then
        Debug.error(Debug, "Failed to search citizen")
        return { success = false, message = (response and response.error) or "Search failed" }
    end

    return response
end)

WEB.RegisterNUICallback("GET_CITIZEN_INFO", function(data)
    local response = serverCall("bablo-billing:GET_CITIZEN_INFO", data)

    if not response or not response.success then
        Debug.error(Debug, "Failed to get citizen info")
        return { success = false, message = (response and response.error) or "Failed to get citizen info" }
    end

    return response
end)

WEB.RegisterNUICallback("GET_CITIZEN_UNPAID_INVOICES", function(data)
    local response = serverCall("bablo-billing:GET_CITIZEN_UNPAID_INVOICES", data)

    if not response or not response.success then
        Debug.error(Debug, "Failed to get citizen unpaid invoices")
        return { success = false, message = (response and response.error) or "Failed to get invoices" }
    end

    return response
end)

-- ── Real-time server → client events ─────────────────────────

RegisterNetEvent("bablo-billing:invoiceCreated")
AddEventHandler("bablo-billing:invoiceCreated", function(invoiceData)
    Debug.info(Debug, "Real-time invoice created event received:", invoiceData)
    SendNUIMessage({ event = "invoiceCreated", data = invoiceData })
end)

RegisterNetEvent("bablo-billing:invoicePaid")
AddEventHandler("bablo-billing:invoicePaid", function(invoiceData)
    Debug.info(Debug, "Real-time invoice paid event received:", invoiceData)
    SendNUIMessage({ event = "invoicePaid", data = invoiceData })
end)

RegisterNetEvent("bablo-billing:invoiceDeleted")
AddEventHandler("bablo-billing:invoiceDeleted", function(invoiceData)
    Debug.info(Debug, "Real-time invoice deleted event received:", invoiceData)
    SendNUIMessage({ event = "invoiceDeleted", data = invoiceData })
end)
