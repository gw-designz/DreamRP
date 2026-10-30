lib.locale()

Config = {
    framework = 'qbx', -- auto | esx | qb | qbx
    currency = { code = 'USD', symbol = '$', precision = 0 },

    v3 = {
        enabled = true,
        autoMigrateSchema = true,
        autoImportV2 = false,
        requireExplicitLegacyImport = true,
        migrationFiles = { 'migrations/001_v3_schema.sql' },
        statementPageSize = 30,
        maximumStatementPageSize = 100,
        idempotencyTtlSeconds = 86400,
        processingTimeoutSeconds = 30,
        lockTimeoutMs = 5000,
        settlementRetryLimit = 5
    },

    permissions = {
        adminAce = 'renewedbanking.admin',
        esx = {
            mode = 'gradeName',
            bossGradeNames = { boss = true },
            minimumGrades = {},
            allowedGrades = {}
        },
        qb = {
            mode = 'isboss',
            minimumGrades = {},
            allowedGrades = {}
        },
        qbx = {
            mode = 'nativeBoss',
            minimumGrades = {},
            allowedGrades = {}
        },
        sharedRoles = {
            owner = { view = true, deposit = true, withdraw = true, transfer = true, members = true, rename = true, close = true },
            admin = { view = true, deposit = true, withdraw = true, transfer = true, members = true, rename = true, close = false },
            operator = { view = true, deposit = true, withdraw = true, transfer = true, members = false, rename = false, close = false },
            viewer = { view = true, deposit = false, withdraw = false, transfer = false, members = false, rename = false, close = false }
        }
    },

    security = {
        auditEnabled = true,
        redactIdentifiers = true,
        minimumTransactionAmount = 1,
        maximumTransactionAmount = 100000000,
        requireWholeAmounts = true,
        maximumCommentLength = 160,
        minimumAccountIdLength = 3,
        maximumAccountIdLength = 50,
        accountIdPattern = '^[a-z0-9][a-z0-9_-]*$',
        maximumSharedAccountsPerPlayer = 5,
        actionCooldowns = {
            session = 350,
            statement = 350,
            deposit = 750,
            withdraw = 750,
            transfer = 1000,
            createAccount = 2500,
            listMembers = 500,
            addMember = 1000,
            removeMember = 1000,
            renameAccount = 1000,
            closeAccount = 1500
        },
        reservedAccountIds = {
            personal = true, system = true, admin = true, bank = true,
            cash = true, migration = true
        }
    },

    compatibility = {
        renewedV2Exports = true,
        allowAnyInvokingResource = false,
        allowedResources = {
            ['qb-core'] = true,
            ['qbx_core'] = true,
            ['es_extended'] = true,
            ['esx_society'] = true,
            ['qb-management'] = true,
            ['nova_laptop'] = true -- pays Weazel News staff from the laptop
        },
        qbManagementProvider = false,
        esxSocietyProvider = false
    },

    logging = {
        level = 'info',
        discordWebhook = '',
        queueLimit = 200,
        retryDelayMs = 5000
    },

    interaction = {
        -- interact (walk up, press E) is used when it is running; ox_target, then a text prompt, otherwise.
        useInteract = true,
        interact = {
            distance = 4.0,           -- how close the dot appears
            interactDst = 1.5,        -- how close [E] works
            pedOffset = { x = 0.0, y = 0.0, z = 0.3 },
            atmOffset = { x = 0.0, y = -0.3, z = 1.1 } -- ATMs without a screen in Config.atm.screens
        },
        useOxTarget = true,
        fallbackTextUi = true,
        targetDistance = 2.5,
        pedSpawnDistance = 120.0,
        progress = { style = 'circle', durationMin = 1200, durationMax = 2200 },
        atmCapabilities = { deposit = false, withdraw = true, transfer = true, createSharedAccount = false },
        bankCapabilities = { deposit = true, withdraw = true, transfer = true, createSharedAccount = true }
    },

    atms = { joaat('prop_atm_01'), joaat('prop_atm_02'), joaat('prop_atm_03'), joaat('prop_fleeca_atm') },

    -- The logo is three parts: plain, highlighted, plain.
    branding = {
        logo = { 'FL', 'EE', 'CA' },
        tagline = 'Fleeca · FDIC insured · Member DIC'
    },

    -- The ATM page painted on the machine's own screen. A model without an
    -- entry in `screens` opens the full-screen bank instead.
    atm = {
        screen = true,
        -- Who may line the screens up with /atmscreen: the framework's own staff
        -- groups (Qbox/QBCore permission levels, ESX player groups).
        editGroups = { 'god', 'admin' },
        paintDistance = 25.0,
        leaveDistance = 3.0,
        fov = 40.0,
        quickAmounts = { 1000, 5000, 10000, 50000 },
        historyPageSize = 7,
        -- Each screen in the model's own coordinates, front facing -Y:
        -- centre of the glass (x, y, z), its size in metres and how far its
        -- top leans back, in degrees. Admins tune them in game with /atmscreen;
        -- what they save goes to atm_screens.json and takes the place of these.
        -- `keys` (optional) makes the machine's own side buttons clickable.
        screens = {
            prop_atm_01 = { x = 0.0, y = -0.06, z = 1.12, width = 0.32, height = 0.24, tilt = 8.0 },
            prop_atm_02 = { x = 0.0, y = -0.19, z = 1.20, width = 0.32, height = 0.24, tilt = 8.0 },
            prop_atm_03 = { x = 0.0, y = -0.18, z = 1.20, width = 0.32, height = 0.24, tilt = 8.0 },
            prop_fleeca_atm = {
                x = -0.121, y = 0.094, z = 1.148, width = 0.326, height = 0.262, tilt = 14.5,
                -- The physical buttons beside the glass, as fractions of the screen (0 to 1
                -- across and down; below 0 is left of the glass, above 1 right of it).
                keys = {
                    rows = { 0.192, 0.418, 0.641, 0.861 }, -- centre of each row, top to bottom
                    height = 0.11,
                    left = { -0.15, -0.02 },
                    right = { 1.02, 1.15 }
                }
            }
        }
    },

    locations = {
        { id = 'pacific', model = 'u_m_m_bankman', coords = vector4(241.44, 227.19, 106.29, 170.43), createAccounts = true, blip = { enabled = true, sprite = 108, colour = 2, scale = 0.8 } },
        { id = 'hawick', model = 'ig_barry', coords = vector4(313.84, -280.58, 54.16, 338.31), blip = { enabled = true, sprite = 108, colour = 2, scale = 0.8 } },
        { id = 'legion', model = 'ig_barry', coords = vector4(149.46, -1042.09, 29.37, 335.43), blip = { enabled = true, sprite = 108, colour = 2, scale = 0.8 } },
        { id = 'rockford', model = 'ig_barry', coords = vector4(-351.23, -51.28, 49.04, 341.73), blip = { enabled = true, sprite = 108, colour = 2, scale = 0.8 } },
        { id = 'vespucci', model = 'ig_barry', coords = vector4(-1211.9, -331.9, 37.78, 20.07), blip = { enabled = true, sprite = 108, colour = 2, scale = 0.8 } },
        { id = 'great_ocean', model = 'ig_barry', coords = vector4(-2961.14, 483.09, 15.7, 83.84), blip = { enabled = true, sprite = 108, colour = 2, scale = 0.8 } },
        { id = 'harmony', model = 'ig_barry', coords = vector4(1174.8, 2708.2, 38.09, 178.52), blip = { enabled = true, sprite = 108, colour = 2, scale = 0.8 } },
        { id = 'paleto', model = 'u_m_m_bankman', coords = vector4(-112.22, 6471.01, 31.63, 134.18), createAccounts = true, blip = { enabled = true, sprite = 108, colour = 2, scale = 0.8 } }
    }
}
