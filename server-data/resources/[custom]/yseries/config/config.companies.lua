Config = Config or {}

Config.Companies = {}
Config.RefreshInterval = 120                            -- 120 seconds(default). Recommended: 60 seconds or higher.
Config.Companies.MaxEmployeesToCall = 2                 -- The maximum number of employees(random) to call when calling a company.

Config.Companies.PoliceAlwaysAvailable = false          -- If true, the police company will always appear as online.
Config.Companies.AppearAsAlwaysAvailable = { 'police' } -- The job name of the police job. -- This is used to determine if the police company should always appear as online.

-- Deprecated - Set your job name manually in the config below. This option will be removed in the future.
Config.Companies.PoliceJob = 'police' -- The job name of the police job.

--[[
    The name of the script that will be used for companies funds.
    [*RECOMMENDED*] tgg-banking: If you are using the latest version of tgg-banking. - https://store.teamsgg.com/package/6545202
    * esx_society: If you are using esx_society.
    * qb-management: If you are using qb-management.
    * qb-banking: If you are using the latest version of qb-banking.
    * okokBanking: If you are using the latest version of okokBanking.
    * renewed-banking: If you are using the latest version of renewed-banking.
    * custom: If you are using a custom or not supported banking script. NOTE: You need to implement the banking functions for your script.
]]
Config.Companies.Banking = 'auto'

Config.Companies.Services = {
    {
        job = Config.Companies.PoliceJob,
        name = "Police",
        phoneNumber = 911, -- A callable number for the company.
        icon = "https://cdn-icons-png.flaticon.com/64/7693/7693100.png",
        canCall = true,    -- if true, players can call the company
        canMessage = true, -- if true, players can message the company
        location = {
            name = "Mission Row",
            coords = {
                x = 428.9,
                y = -984.5,
            }
        },
        hasJobActions = true,  -- if true, and the player job is configured here they can see the job actions
        hasBossActions = true, -- if true, and the player job is configured here they can see the boss actions(only if the player hash boss rank)
        management = {
            duty = true,       -- if true, employees can go on/off duty
            -- Boss actions
            deposit = true,    -- if true, the boss can deposit money into the company
            withdraw = true,   -- if true, the boss can withdraw money from the company
            hire = true,       -- if true, the boss can hire employees
            fire = true,       -- if true, the boss can fire employees
            promote = true,    -- if true, the boss can promote employees
            block = true,      -- if true, the boss can block callers
        }
    },
    {
        job = "ambulance",
        name = "Ambulance",
        icon = "https://cdn-icons-png.flaticon.com/64/790/790065.png",
        canCall = true,    -- if true, players can call the company
        canMessage = true, -- if true, players can message the company
        location = {
            name = "Pillbox",
            coords = {
                x = 304.2,
                y = -587.0
            }
        },
        hasJobActions = true,  -- if true, and the player job is configured here they can see the job actions
        hasBossActions = true, -- if true, and the player job is configured here they can see the boss actions(only if the player hash boss rank)
        management = {
            duty = true,       -- if true, employees can go on/off duty
            -- Boss actions
            deposit = true,    -- if true, the boss can deposit money into the company
            withdraw = true,   -- if true, the boss can withdraw money from the company
            hire = true,       -- if true, the boss can hire employees
            fire = true,       -- if true, the boss can fire employees
            promote = true,    -- if true, the boss can promote employees
            block = true,      -- if true, the boss can block callers
        }
    },
    {
        job = "mechanic",
        name = "Mechanic",
        icon = "https://cdn-icons-png.flaticon.com/64/1505/1505456.png",
        canCall = true,    -- if true, players can call the company
        canMessage = true, -- if true, players can message the company
        location = {
            name = "LS Customs",
            coords = {
                x = -336.6,
                y = -134.3
            }
        },
        hasJobActions = true,  -- if true, and the player job is configured here they can see the job actions
        hasBossActions = true, -- if true, and the player job is configured here they can see the boss actions(only if the player hash boss rank)
        management = {
            duty = true,       -- if true, employees can go on/off duty
            -- Boss actions
            deposit = true,    -- if true, the boss can deposit money into the company
            withdraw = true,   -- if true, the boss can withdraw money from the company
            hire = true,       -- if true, the boss can hire employees
            fire = true,       -- if true, the boss can fire employees
            promote = true,    -- if true, the boss can promote employees
            block = true,      -- if true, the boss can block callers
        }
    },
    {
        job = "taxi",
        name = "Taxi",
        icon = "https://cdn-icons-png.flaticon.com/64/2282/2282410.png",
        canCall = true,    -- if true, players can call the company
        canMessage = true, -- if true, players can message the company
        location = {
            name = "Taxi HQ",
            coords = {
                x = 984.2,
                y = -219.0
            }
        },
        hasJobActions = true,  -- if true, and the player job is configured here they can see the job actions
        hasBossActions = true, -- if true, and the player job is configured here they can see the boss actions(only if the player hash boss rank)
        management = {
            duty = true,       -- if true, employees can go on/off duty
            -- Boss actions
            deposit = true,    -- if true, the boss can deposit money into the company
            withdraw = true,   -- if true, the boss can withdraw money from the company
            hire = true,       -- if true, the boss can hire employees
            fire = true,       -- if true, the boss can fire employees
            promote = true,    -- if true, the boss can promote employees
            block = true,      -- if true, the boss can block callers
        }
    },
}
