-- ============================================================
-- debug-invoices.lua  –  bablo-billing  (server, DEBUG only)
-- ============================================================

local MySQL = rawget(_G, "MySQL") or exports.oxmysql

-- ── Seed data ─────────────────────────────────────────────────

local debugInvoices = {
    -- Personal → Personal (John → Mike)
    { issuer_identifier = "YHX13966", issuer_display_name = "John Smith",    recipient_identifier = "AHU78510", issuer_account_type = "personal", issuer_job_name = nil, recipient_account_type = "personal", recipient_job_name = nil, amount = 1500, title = "Vehicle Repair Service",  description = "Full engine rebuild and transmission service",   status = "pending" },
    { issuer_identifier = "YHX13966", issuer_display_name = "John Smith",    recipient_identifier = "AHU78510", issuer_account_type = "personal", issuer_job_name = nil, recipient_account_type = "personal", recipient_job_name = nil, amount = 350,  title = "Towing Service",           description = "Emergency towing from highway to garage",        status = "paid"    },
    { issuer_identifier = "YHX13966", issuer_display_name = "John Smith",    recipient_identifier = "AHU78510", issuer_account_type = "personal", issuer_job_name = nil, recipient_account_type = "personal", recipient_job_name = nil, amount = 750,  title = "Custom Paint Job",         description = "Matte black finish with racing stripes",         status = "pending" },
    -- Personal → Personal (Mike → John)
    { issuer_identifier = "AHU78510", issuer_display_name = "Mike Johnson",  recipient_identifier = "YHX13966", issuer_account_type = "personal", issuer_job_name = nil, recipient_account_type = "personal", recipient_job_name = nil, amount = 2500, title = "House Renovation",         description = "Kitchen remodeling and new cabinets",            status = "pending" },
    { issuer_identifier = "AHU78510", issuer_display_name = "Mike Johnson",  recipient_identifier = "YHX13966", issuer_account_type = "personal", issuer_job_name = nil, recipient_account_type = "personal", recipient_job_name = nil, amount = 180,  title = "Delivery Service",         description = "Package delivery across town",                   status = "paid"    },
    { issuer_identifier = "AHU78510", issuer_display_name = "Mike Johnson",  recipient_identifier = "YHX13966", issuer_account_type = "personal", issuer_job_name = nil, recipient_account_type = "personal", recipient_job_name = nil, amount = 500,  title = "Consulting Fee",           description = "Business consulting session - 2 hours",          status = "pending" },
    -- Job (police) → Personal
    { issuer_identifier = "job:police",   issuer_display_name = "Officer Davis",    recipient_identifier = "AHU78510", issuer_account_type = "job", issuer_job_name = "police", recipient_account_type = "personal", recipient_job_name = nil, amount = 1200, title = "Speeding Ticket",         description = "Speeding violation - 85mph in a 45mph zone",     status = "pending" },
    { issuer_identifier = "job:police",   issuer_display_name = "Officer Martinez", recipient_identifier = "AHU78510", issuer_account_type = "job", issuer_job_name = "police", recipient_account_type = "personal", recipient_job_name = nil, amount = 500,  title = "Parking Violation",       description = "Illegal parking in no-parking zone",             status = "paid"    },
    { issuer_identifier = "job:police",   issuer_display_name = "Sergeant Wilson",  recipient_identifier = "AHU78510", issuer_account_type = "job", issuer_job_name = "police", recipient_account_type = "personal", recipient_job_name = nil, amount = 2500, title = "Reckless Driving Fine",   description = "Reckless driving and failure to stop for police", status = "pending" },
    { issuer_identifier = "job:police",   issuer_display_name = "Officer Chen",     recipient_identifier = "AHU78510", issuer_account_type = "job", issuer_job_name = "police", recipient_account_type = "personal", recipient_job_name = nil, amount = 350,  title = "Equipment Damage Fee",    description = "Damage to police barrier during pursuit",        status = "pending" },
    -- Job (mechanic) → Personal
    { issuer_identifier = "job:mechanic", issuer_display_name = "LS Customs Staff", recipient_identifier = "YHX13966", issuer_account_type = "job", issuer_job_name = "mechanic", recipient_account_type = "personal", recipient_job_name = nil, amount = 3500, title = "Engine Swap",             description = "V8 engine swap with turbo installation",         status = "pending" },
    { issuer_identifier = "job:mechanic", issuer_display_name = "LS Customs Staff", recipient_identifier = "YHX13966", issuer_account_type = "job", issuer_job_name = "mechanic", recipient_account_type = "personal", recipient_job_name = nil, amount = 850,  title = "Suspension Upgrade",      description = "Sport suspension kit installation",              status = "paid"    },
    -- Misc personal
    { issuer_identifier = "YHX13966", issuer_display_name = "John Smith",    recipient_identifier = "AHU78510", issuer_account_type = "personal", issuer_job_name = nil, recipient_account_type = "personal", recipient_job_name = nil, amount = 125,  title = "Taxi Ride",               description = "Airport pickup and drop-off",                    status = "paid"    },
    { issuer_identifier = "AHU78510", issuer_display_name = "Mike Johnson",  recipient_identifier = "YHX13966", issuer_account_type = "personal", issuer_job_name = nil, recipient_account_type = "personal", recipient_job_name = nil, amount = 999,  title = "Electronics Purchase",    description = "Laptop and accessories",                         status = "pending" },
}

-- ── Helpers ───────────────────────────────────────────────────

-- Generates a UUID-like string (format: INV-xxxx-4xxx-yxxx).
local function generateInvoiceUUID()
    return ("INV-xxxx-4xxx-yxxx"):gsub("[xy]", function(c)
        local n = c == "x" and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", n)
    end)
end

-- ── Commands ─────────────────────────────────────────────────

-- /debuginvoices  –  inserts all seed invoices into bablo_invoices (console only)
RegisterCommand("debuginvoices", function(source)
    if source ~= 0 then
        print("^1[DEBUG] This command can only be run from server console^0")
        return
    end

    print("^3[DEBUG] Creating debug invoices...^0")

    local now       = os.time() * 1000
    local inserted  = 0

    for index, invoice in ipairs(debugInvoices) do
        local uuid        = generateInvoiceUUID()
        local daysAgo     = math.random(0, 30)
        local createdAt   = now - (daysAgo * 24 * 60 * 60 * 1000)
        local dueDate     = createdAt + 2592000000   -- +30 days in ms

        local result = MySQL.query.await([[
            INSERT INTO bablo_invoices (uuid, issuer_identifier, issuer_display_name, recipient_identifier,
                                 issuer_account_type, issuer_job_name, recipient_account_type, recipient_job_name,
                                 amount, title, description, status, created_at, due_date)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            uuid,
            invoice.issuer_identifier,
            invoice.issuer_display_name,
            invoice.recipient_identifier,
            invoice.issuer_account_type,
            invoice.issuer_job_name,
            invoice.recipient_account_type,
            invoice.recipient_job_name,
            invoice.amount,
            invoice.title,
            invoice.description,
            invoice.status,
            createdAt,
            dueDate,
        })

        if result and result.affectedRows > 0 then
            inserted = inserted + 1
            print(string.format("^2[DEBUG] Created invoice %d: %s - %s ($%d) [%s]^0",
                index, uuid, invoice.title, invoice.amount, invoice.status))
        else
            print(string.format("^1[DEBUG] Failed to create invoice %d: %s^0",
                index, invoice.title))
        end
    end

    print(string.format("^2[DEBUG] Successfully created %d/%d debug invoices!^0",
        inserted, #debugInvoices))
end, false)

-- /cleardebugdata  –  removes all seed invoices by known identifiers (console only)
RegisterCommand("cleardebugdata", function(source)
    if source ~= 0 then
        print("^1[DEBUG] This command can only be run from server console^0")
        return
    end

    local result = MySQL.query.await([[
        DELETE FROM bablo_invoices
        WHERE (issuer_identifier IN ('YHX13966', 'AHU78510', 'job:police', 'job:mechanic')
           OR recipient_identifier IN ('YHX13966', 'AHU78510'))
    ]])

    local deleted = (result and result.affectedRows) or 0
    print(string.format("^3[DEBUG] Deleted %d debug invoices^0", deleted))
end, false)

-- Startup hint
if Config.DEBUG then
    print("^2[bablo-billing] Debug invoice commands loaded^0")
    print("^3  /debuginvoices - Create test invoices^0")
    print("^3  /cleardebugdata - Remove test invoices^0")
end
