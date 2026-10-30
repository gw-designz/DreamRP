
Config = {};

Config.Locale = 'en';

-- true to enable and false to disabled
Config.DEBUG = false;

-- Define Locales table early to ensure global availability
Locales = {}

--- Framework to use, options: 'auto', 'esx', 'qbcore', 'qbox'
--- Use 'auto' to automatically detect the framework based on running resources
--- You see in the "framework" folder the available frameworks
Config.Framework = 'auto';

Config.OpenMenu = 'F7'         -- Open menu keybind or false to disable keymapping
Config.OpenCommand = 'billing' -- Open menu command or false to disable command

--[[
    SocietyResource - The society resource that the script will use to get the job money.

    auto: This will automatically detect the target.
    Options: esx_society, esx_addonaccount, qb-management, qb-bossmenu, Renewed-Banking, bablo-banking
]]
Config.SocietyResource = "bablo-banking"

--- Invoice Configuration
Config.Invoice = {
    --- Default due date in days from creation (set to nil to disable automatic due dates)
    defaultDueDays = 30,

    --- Allow custom due dates when creating invoices
    allowCustomDueDate = true,

    --- Allow personal accounts to send invoices
    allowPrivatePersonToSendInvoice = false,

    --- Auto-cleanup paid invoices after X days (set to 0 or nil to disable auto-cleanup)
    --- Paid invoices older than this will be automatically deleted
    paidInvoiceRetentionDays = 8,

    --- How often to run the cleanup (in minutes)
    cleanupIntervalMinutes = 60,

    --- Auto-pay overdue invoices
    --- When enabled, invoices past their due date will be automatically paid
    --- Money is deducted from the recipient and added to the issuer
    autoPayOverdue = true,

    --- Show the built-in default invoice templates (Speeding Ticket, DUI, etc.).
    --- Set to false to hide them and show ONLY templates from bablo_billing_presets.
    showDefaultTemplates = false,
}

--- UI Theme Configuration
--- Customize the appearance of the billing system
--- Available formats: 'rgb(r, g, b)', '#hexcode', or predefined colors
Config.Theme = {
    -- Primary color (main accent color)
    primary = '#7aadff', -- blue
}

--- Currency Configuration
--- Customize how currency is displayed throughout the billing system
Config.Currency = {
    --- Currency code (ISO 4217) used for number formatting
    --- Examples: "USD", "EUR", "GBP", "SEK", "NOK", "DKK"
    code = "USD",

    --- Symbol to display (e.g., "$", "€", "kr", "£")
    symbol = "$",

    --- Position of the symbol: "prefix" ($100) or "suffix" (100 kr)
    symbolPosition = "prefix",

    --- Use browser's Intl.NumberFormat for locale-aware formatting
    --- If true, uses the currency code for automatic formatting
    --- If false, uses simple formatting with the symbol
    useNativeFormatting = true,
}

--- Job Account Configuration
Config.JobAccount = {
    --- Require specific job opening function to access job accounts
    --- If true, users must use the 'OpenJob' export to access job billing features
    --- If false, users can freely switch between personal and job accounts
    requireJobOpen = false,

    --- Jobs that are allowed to use the billing system
    --- Set to {} to allow all jobs, or specify job names: {'police', 'ambulance', 'mechanic'}
    blockedJobs = {},

    --- Default minimum grade requirements for all jobs (used when job is not specifically configured)
    --- Grade 0 means everyone can access, higher numbers restrict to higher ranks
    --- Set to -1 to completely disable that permission
    defaultGrades = {
        viewReceivedInvoices = 0,       -- Min grade to view invoices sent TO the job (hides tab if not met)
        deleteAnyInvoice = 3,           -- Min grade to delete ANY invoice (not just your own)
        handleAllSentInvoices = -1,     -- Min grade to view ALL sent invoices for the company (-1 = disabled)
        canSendInvoicesToCompanies = 0, -- Min grade to send invoices TO other companies/jobs (0 = everyone)
    },

    --- Per-job grade requirements (overrides defaultGrades for specific jobs)
    --- Format: ['job_name'] = { permission = minGrade, ... }
    jobGrades = {
        ['police'] = {
            viewReceivedInvoices = 1,       -- Min grade to view invoices sent TO the job and pay
            deleteAnyInvoice = 4,           -- Can delete any invoice
            handleAllSentInvoices = 4,      -- Grade 3+ can see all police sent invoices
            canSendInvoicesToCompanies = 0, -- Grade 2+ can send invoices to other companies
        },
        ['ambulance'] = {
            viewReceivedInvoices = 0,
            deleteAnyInvoice = 3,
            handleAllSentInvoices = 3,
            canSendInvoicesToCompanies = 0,
        },
        ['mechanic'] = {
            viewReceivedInvoices = 2,
            deleteAnyInvoice = 2,
            handleAllSentInvoices = 2,
            canSendInvoicesToCompanies = 0,
        },
        -- Example: Only bosses can view received invoices
        -- ['taxi'] = {
        --     viewReceivedInvoices = 3,
        --     deleteAnyInvoice = 3,
        -- },
    },

    --- Job Avatars Configuration
    --- Set custom avatars for specific jobs. If not configured, will use default avatar
    --- Format: ['job_name'] = 'avatar_url' or 'emoji'
    jobAvatars = {
        ['police'] = 'PD',
        ['ambulance'] = 'AM',
        ['mechanic'] = 'MH',
        ['taxi'] = 'TX',
        ['lawyer'] = 'LW',
        ['realestate'] = 'RE',
        ['cardealer'] = 'CD',
        ['banker'] = 'BK',
    }
}

--- Target Configuration
--- Allows players with configured jobs to target other players and send them a bill
--- Options: 'ox_target', 'qb-target', or false to disable
Config.Target = 'auto'

Config.TargetBilling = {
    enabled = true,
    label = "Send Bill",
    icon = "fas fa-file-invoice-dollar",
    distance = 2.5,
    --- If true, quick bills from target can only be sent as job invoices (no personal option)
    jobOnly = true,
}

--- Pay by Reference Configuration
--- Allows ANY user to look up and pay an invoice by its reference number
Config.PayReference = {
    enabled = true, -- Set to false to disable this feature entirely
}

--- Citizen Lookup Configuration
--- Allows specific jobs to search for citizens and view their unpaid invoices
Config.CitizenLookup = {
    enabled = true, -- Set to false to disable this feature entirely

    --- Jobs allowed to use citizen lookup (empty = nobody can use it)
    allowedJobs = { 'police' },
}

--- Tax / VAT Configuration
--- When `enabled` is true, every invoice has VAT applied at payment time.
--- The issuer always receives the subtotal (the amount they entered).
--- The payer pays subtotal + VAT. If `recipientSociety` is set, that society
--- receives the VAT; otherwise the VAT is simply not credited (sink).
Config.Tax = {
    -- Master switch. false = no tax math, no tax UI; behaves exactly like before.
    enabled = false,

    -- Default VAT % applied to any invoice whose issuer job has no override.
    -- Personal-account issuers always use this rate.
    defaultRate = 10,

    -- Society that receives collected tax. Set to false/nil to disable society
    -- credit (tax is still deducted from the payer, just not credited anywhere).
    -- Must be a job name your framework recognizes.
    recipientSociety = false,

    -- Per-job overrides. Job not listed uses defaultRate. Set 0 to exempt.
    -- Format: ['job_name'] = rate_percent
    jobRates = {
        ['mechanic']  = 15,
        ['lawyer']    = 25,
        ['ambulance'] = 0,
    }
}

--- Payout Split Configuration
--- Controls where the money goes when a JOB invoice is paid.
--- When disabled, the full amount goes to the issuing job's society (default behavior).
--- When enabled, the amount is split between the player who issued the invoice and
--- their job society. Whatever percentage is left over (100 - issuer - society) is
--- REMOVED from the economy (a money sink), unless `remainderSociety` is set.
--- Personal invoices are never split - the issuer always receives the full amount.
Config.Payout = {
    -- Enabled on this test server to verify the police 10/30 split in-game.
    enabled = true,

    -- Split for job invoices whose job has no override below.
    default = { issuer = 0, society = 100 },

    -- Officers get 10% of each fine, the police society gets 30%,
    -- and the remaining 60% disappears from the economy.
    jobs = {
        ['police'] = { issuer = 10, society = 30 },
    },

    -- Society that receives the leftover percentage. false = sink.
    remainderSociety = false,
}
