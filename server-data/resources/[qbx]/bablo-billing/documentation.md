# 📄 SKEEXS Billing System - Customer Documentation

A professional invoice solution for your FiveM servers that makes it easy to handle payments between players and businesses.

![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)
![Framework](https://img.shields.io/badge/framework-ESX-red.svg)
![License](https://img.shields.io/badge/license-Commercial-yellow.svg)

---

## 📋 Table of Contents

1. [Installation](#-installation)
2. [Configuration](#-configuration)
3. [Exports](#-exports)
4. [Events](#-events)
5. [Usage](#-usage)
6. [Theme Customization](#-theme-customization)
7. [Localization](#-localization)
8. [Troubleshooting](#-troubleshooting)
9. [Support](#-support)

---

## 🚀 Installation

### Step 1: Download and Place

```bash
# Place the folder in your resources directory
resources/
├── bablo-billing/
└── ...other resources
```

### Step 2: Add to server.cfg

```bash
ensure bablo-billing
```

### Step 3: Start the Server

```bash
# Or restart if server is already running
restart bablo-billing
```

---

## ⚙️ Configuration

### Basic Settings (`config.lua`)

```lua
Config = {}

-- 🌐 Language and Localization
Config.Locale = 'en'  -- 'en' for English, 'sv' for Swedish

-- 🔑 Permissions for sending invoices
Config.AllowedJobs = {
    'police',      -- Police
    'ambulance',   -- EMS/Ambulance
    'mechanic',    -- Mechanic
    'cardealer',   -- Car Dealer
    -- Add more jobs here
}

-- 💰 Currency Settings
Config.Currency = {
    symbol = "$",           -- Currency symbol
    position = "before",    -- "before" or "after"
    separator = "",         -- Space between number and symbol
    decimal = ".",          -- Decimal separator
    thousand = ","          -- Thousand separator
}

-- 🎨 Theme Settings (NEW!)
Config.Theme = {
    primary = '#3b82f6',    -- Primary color (blue as default)
    -- Or use color names:
    -- primary = 'rgb(59, 130, 246)'
    -- primary = 'hsl(217, 91%, 60%)'
}

-- 📝 Invoice Settings
Config.Invoice = {
    maxAmount = 100000,     -- Maximum amount per invoice
    minAmount = 1,          -- Minimum amount per invoice
    maxDescription = 500,   -- Max characters in description
    autoExpire = false,     -- Auto-expire invoices
    expireDays = 30        -- Days until expiration (if autoExpire = true)
}

-- 🔧 Advanced Settings
Config.Debug = false        -- Enable debug messages
Config.UpdateInterval = 5000 -- Update interval (ms)

-- 👔 Job Account Configuration
Config.JobAccount = {
    -- Require specific job opening function to access job accounts
    -- If true, users must use the 'OpenJob' export to access job billing features
    -- If false, users can freely switch between personal and job accounts
    requireJobOpen = true,

    -- Jobs that are allowed to use the billing system
    -- Set to {} to allow all jobs, or specify job names: {'police', 'ambulance', 'mechanic'}
    allowedJobs = {} -- Empty = all jobs allowed
}
```

### Job Account Access Control

The billing system supports controlled access to job accounts. This feature allows you to restrict job billing access and require specific authorization:

**When `requireJobOpen = true`:**

-   Users cannot freely switch to job accounts in the UI
-   Job account access must be granted via the `OpenJob` export function
-   Perfect for controlling when job billing features are available

**When `requireJobOpen = false`:**

-   Users can freely switch between personal and job accounts (traditional behavior)
-   No special authorization required

**Usage Example:**

```lua
-- In your job script (police, ambulance, etc.)
RegisterCommand('police_billing', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.job.name == 'police' then
        -- Grant job account access and open billing
        exports['bablo-billing']:OpenJob()
    end
end)
```

### Payout Splits (Config.Payout)

Controls where the money goes when a **job invoice** is paid. Disabled by default (the full
amount goes to the issuing job's society). When enabled, the amount is split between the
player who issued the invoice and their job society — any leftover percentage is removed
from the economy (a money sink), unless `remainderSociety` routes it to a society.

```lua
Config.Payout = {
    enabled = true,
    default = { issuer = 0, society = 100 },
    jobs = {
        -- Officers get 10% of each fine, the police society gets 30%,
        -- and the remaining 60% disappears from the economy:
        ['police'] = { issuer = 10, society = 30 },
    },
    remainderSociety = false, -- or e.g. 'government' to collect the leftover
}
```

With the example above, a $1,000 police fine pays out: $100 to the officer who wrote it,
$300 to the police society, and $600 is removed from the economy.

-   Applies to **every** payment path: manual payment, pay-by-reference, and auto-pay of overdue invoices
-   Personal invoices are never split — the issuer always receives the full amount
-   The issuer receives their share even while offline
-   Independent of `Config.Tax`: tax is charged on top to the payer; the split divides the invoice amount on the issuer's side

---

## 📤 Exports

Use these exports in other scripts to integrate with the billing system:

### Server Exports

#### `CreateInvoice` - Create New Invoice

```lua
-- Create a simple invoice
exports['bablo-billing']:CreateInvoice({
    from = 'steam:110000100000000',  -- Sender's identifier
    to = 'steam:110000100000001',    -- Recipient's identifier
    title = 'Vehicle Repair',        -- Invoice title
    description = 'Engine replacement and paint job', -- Description
    amount = 15000                   -- Amount in your server's currency
})

-- Create invoice with multiple line items
exports['bablo-billing']:CreateInvoice({
    from = 'steam:110000100000000',
    to = 'steam:110000100000001',
    title = 'Vehicle Modification',
    description = 'Multiple services performed',
    lineItems = {
        {
            description = 'Engine Tuning Stage 1',
            quantity = 1,
            price = 15000
        },
        {
            description = 'Carbon Fiber Hood',
            quantity = 1,
            price = 25000
        },
        {
            description = 'Racing Tires',
            quantity = 4,
            price = 3000
        }
    }
})
```

#### `GetPlayerInvoices` - Get Player's Invoices

```lua
-- Get all invoices for a player
local invoices = exports['bablo-billing']:GetPlayerInvoices('steam:110000100000000')

-- Get only pending invoices
local pendingInvoices = exports['bablo-billing']:GetPlayerInvoices('steam:110000100000000', 'pending')
```

#### `PayInvoice` - Pay Invoice Programmatically

```lua
-- Pay an invoice directly
local success = exports['bablo-billing']:PayInvoice('invoice-uuid-here', 'steam:110000100000000')
```

### Client Exports

#### `OpenBillingUI` - Open Billing Interface

```lua
-- Open the billing menu
exports['bablo-billing']:OpenBillingUI()

-- Open directly to received invoices
exports['bablo-billing']:OpenBillingUI('received')

-- Open directly to sent invoices
exports['bablo-billing']:OpenBillingUI('sent')
```

#### `GetPlayerBalance` - Get Player's Balance

```lua
-- Get player's bank balance
local balance = exports['bablo-billing']:GetPlayerBalance()
print('Player balance: ' .. balance)
```

#### `OpenJob` - Open Job Billing Interface

```lua
-- Grant job account access and open billing system
-- This function checks job permissions and grants access if authorized
exports['bablo-billing']:OpenJob()

-- Example usage in job script
RegisterCommand('police_billing', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.job.name == 'police' and xPlayer.job.grade >= 2 then
        exports['bablo-billing']:OpenJob()
    else
        xPlayer.showNotification('You need to be at least a Sergeant to access billing')
    end
end)
```

#### `CanAccessJobAccount` - Check Job Account Access

```lua
-- Check if current player can access job accounts
local canAccess = exports['bablo-billing']:CanAccessJobAccount()
if canAccess then
    print('Player has job account access')
else
    print('Player does not have job account access')
end
print('Player balance: ' .. balance)
```

---

## 📡 Events

### Server Events

Register these in a **server** script with `AddEventHandler`. Each handler receives the full
`invoice` table. They are emitted locally on the server with `TriggerEvent` (do **not** use
`RegisterNetEvent`).

```lua
-- When an invoice is created (UI, exports, or any path)
AddEventHandler('bablo-billing:invoiceCreated', function(invoice)
    print('New invoice ' .. invoice.uuid .. ': ' .. invoice.title .. ' for $' .. invoice.amount)
    print('From: ' .. invoice.issuer_identifier .. ' To: ' .. invoice.recipient_identifier)
end)

-- When an invoice is paid (manually or by auto-pay). invoice.status == 'paid'
AddEventHandler('bablo-billing:invoicePaid', function(invoice)
    print('Invoice ' .. invoice.uuid .. ' paid by ' .. invoice.recipient_identifier)
end)

-- When a pending invoice is deleted
AddEventHandler('bablo-billing:invoiceDeleted', function(invoice)
    print('Invoice ' .. invoice.uuid .. ' deleted')
end)
```

The `invoice` table contains: `id`, `uuid`, `issuer_identifier`, `issuer_display_name`,
`recipient_identifier`, `issuer_account_type`, `issuer_job_name`, `recipient_account_type`,
`recipient_job_name`, `amount`, `title`, `description`, `status`, `created_at`, `due_date`,
and `paid_at` (set on `invoicePaid`).

> The billing UI (client) also receives these via `TriggerClientEvent`, wrapped as
> `{ type = 'sent' | 'received', invoice = <invoice> }`. For server-side integrations (e.g. an MDT),
> use the server events above — they pass `invoice` directly.

### Client Events

```lua
-- When billing UI opens
AddEventHandler('bablo-billing:uiOpened', function()
    print('Billing UI opened')
end)

-- When billing UI closes
AddEventHandler('bablo-billing:uiClosed', function()
    print('Billing UI closed')
end)

-- When player receives a new invoice
AddEventHandler('bablo-billing:newInvoiceReceived', function(invoice)
    -- Show notification
    ESX.ShowNotification('You received a new invoice: ' .. invoice.title)

    -- Play sound
    PlaySoundFrontend(-1, "Menu_Accept", "Phone_SoundSet_Default", 1)
end)
```

---

## 🎮 Usage

### For Admins/Staff

#### Commands (if enabled)

```bash
# Open the billing system
/billing

# Or use exports instead
```

#### Create invoices programmatically

```lua
-- In a job script (e.g., mechanic)
RegisterCommand('invoice', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer.job.name == 'mechanic' then
        local targetId = tonumber(args[1])
        local amount = tonumber(args[2])
        local description = table.concat(args, ' ', 3)

        if targetId and amount and description then
            local targetPlayer = ESX.GetPlayerFromId(targetId)
            if targetPlayer then
                exports['bablo-billing']:CreateInvoice({
                    from = xPlayer.identifier,
                    to = targetPlayer.identifier,
                    title = 'Mechanic Work',
                    description = description,
                    amount = amount
                })

                xPlayer.showNotification('Invoice sent!', 'success')
            end
        end
    end
end)
```

### For Players

1. **Receive invoices**: Automatically through the system
2. **Open billing menu**: Via command or export
3. **Pay invoices**: Click "Pay" in the interface
4. **View invoice history**: Both received and sent invoices

---

## 🎨 Theme Customization

### Change Color Theme

Open `config.lua` and change the primary color:

```lua
Config.Theme = {
    -- Popular color choices:

    -- 🔵 Blue (Default)
    primary = '#3b82f6',

    -- 🔴 Red
    primary = '#ef4444',

    -- 🟢 Green
    primary = '#22c55e',

    -- 🟡 Yellow/Orange
    primary = '#f59e0b',

    -- 🟣 Purple
    primary = '#8b5cf6',

    -- 🟢 Cyan
    primary = '#06b6d4',

    -- 🔴 Pink
    primary = '#ec4899',

    -- You can also use RGB or HSL:
    -- primary = 'rgb(239, 68, 68)',
    -- primary = 'hsl(0, 84%, 60%)',
}
```

### Corporate Theme Examples

```lua
-- 🏢 Corporate Colors
Config.Theme = {
    -- Discord Purple
    primary = '#5865f2',

    -- Spotify Green
    primary = '#1db954',

    -- YouTube Red
    primary = '#ff0000',

    -- Twitch Purple
    primary = '#9146ff',
}
```

After changing the color, restart the resource:

```bash
restart bablo-billing
```

---

## 🌐 Localization

### Change Language

In `config.lua`:

```lua
Config.Locale = 'en'  -- For English
Config.Locale = 'sv'  -- For Swedish
```

### Adding Custom Language

1. **Create language file** in `src/locales/`:

```bash
src/locales/fr.json  # For French, for example
```

2. **Copy from existing file**:

```json
{
    "dashboard": {
        "title": "Billing Dashboard",
        "stats": {
            "total_sent": "Total Sent",
            "total_received": "Total Received"
        }
    }
}
```

3. **Translate all texts**

4. **Update config**:

```lua
Config.Locale = 'fr'
```

---

## 🔧 Troubleshooting

### Common Issues

#### ❌ "Billing system won't open"

**Solution:**

```lua
-- Check that resource is started
ensure bablo-billing

-- Check that player has correct job
Config.AllowedJobs = {
    'your_job_here'
}
```

#### ❌ "Invoices don't show up"

**Solution:**

1. Check database connection
2. Check server console for errors
3. Enable debug mode:

```lua
Config.Debug = true
```

#### ❌ "Payment doesn't work"

**Solution:**

1. Check that ESX is running correctly
2. Check player's bank balance
3. Ensure invoice isn't already paid

#### ❌ "Theme colors don't change"

**Solution:**

1. Restart resource: `restart bablo-billing`
2. Check that color code is correct (hex, rgb or hsl)
3. Clear browser cache (F5 in game)

### Debug Mode

Enable in `config.lua`:

```lua
Config.Debug = true
```

This shows detailed messages in server console for troubleshooting.

### Log Files

The system automatically logs:

-   Created invoices
-   Paid invoices
-   Errors and warnings

---

## 📞 Support

### Before Contacting Support

1. **Check config.lua** - Are all settings correct?
2. **Read error messages** - Server console often gives clear error messages
3. **Test with debug enabled** - `Config.Debug = true`
4. **Check dependencies** - ESX must be installed and working

### Support Channels

-   **Discord**: Your support server
-   **Email**: Your support email
-   **Documentation**: This guide

### Information to Include

When asking for help, always include:

-   **FiveM Server version**
-   **ESX version**
-   **Error messages from console**
-   **Config.lua settings**
-   **Steps to reproduce the issue**

---

## 📄 Changelog

### Version 1.0.0

-   ✅ Initial release
-   ✅ Basic invoice functionality
-   ✅ Multiple payment methods
-   ✅ English/Swedish language support

### Version 1.1.0 (Current)

-   ✅ Line items support (multiple items per invoice)
-   ✅ Improved UI/UX
-   ✅ Theme customization
-   ✅ Better error handling
-   ✅ Enhanced exports and events

---

## 📋 License

This is a commercial script. Redistribution or resale is prohibited without permission.

**© 2024 SKEEXS Resources. All rights reserved.**

---

_This documentation is updated regularly. Always check for the latest version._
