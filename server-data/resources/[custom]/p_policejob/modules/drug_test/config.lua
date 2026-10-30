while not Config do Citizen.Wait(1) end

Config.DrugTestKit = {
    ---@field enabled: boolean [master toggle for the drug test kit feature]
    enabled = true,

    ---@field itemName: string [inventory item registered to start a drug test]
    itemName = 'drug_test_kit',

    ---@field maxDistance: number [max distance (metres) between officer and target to start a test]
    maxDistance = 4.0,

    ---@field requireConsent: boolean [if true the target must accept the test before the officer's UI opens]
    requireConsent = true,

    ---@field testDuration: number [how long (ms) the analyzing animation runs before showing the result]
    testDuration = 6000,

    ---@field progressAnim: table [animation played on the officer during the test - { dict: string, clip: string, flag: number }]
    progressAnim = {
        dict = 'amb@medic@standing@kneel@base',
        clip = 'base',
        flag = 49,
    },

    ---@field notifyTarget: boolean [notify the target when the test starts and completes]
    notifyTarget = true,

    ---@field jobs: table [jobs allowed to use the kit - { jobName = minGrade } (or true for any grade)]
    jobs = {
        ['police'] = 0,
        ['sheriff'] = 0,
    },

    ---@field Detection: table [built-in consumption tracker driving the default getDrugTestResults]
    Detection = {
        ---@field windowMinutes: number [how long (minutes) after use a substance still shows on a test]
        windowMinutes = 20,
        ---@field trackItemUse: boolean [auto-record configured drug items when used (ox_inventory / qb-inventory / classic esx inventory)]
        trackItemUse = true,
        ---@field checkEsxStatus: boolean [report a generic positive when the esx_status 'drug' status is active]
        checkEsxStatus = true,
        ---@field items: table [inventory item name -> substance label shown on the test; add your server's drug items here]
        items = {
            -- common QBCore / qb-drugs item names
            ['joint'] = 'THC (Cannabis)',
            ['cokebaggy'] = 'Cocaine',
            ['crack_baggy'] = 'Cocaine (Crack)',
            ['xtcbaggy'] = 'MDMA',
            ['meth'] = 'Methamphetamine',
            ['oxy'] = 'Opiates',
            -- common ESX drug script item names
            ['weed'] = 'THC (Cannabis)',
            ['weed_joint'] = 'THC (Cannabis)',
            ['marijuana'] = 'THC (Cannabis)',
            ['coke'] = 'Cocaine',
            ['cocaine'] = 'Cocaine',
            ['crack'] = 'Cocaine (Crack)',
            ['ecstasy'] = 'MDMA',
            ['meth_pooch'] = 'Methamphetamine',
            ['heroin'] = 'Opiates',
            ['opium'] = 'Opiates',
            ['lsd'] = 'LSD',
        },
    },

    ---@field getDrugTestResults: function [integration point - return boolean, a substance string, or { positive: boolean, substances: string[], details: table } - (targetId: number, officerId: number)]
    getDrugTestResults = function(targetId, officerId)
        -- Custom integration example (takes priority over the built-in tracker):
        -- if GetResourceState('my_drug_script') == 'started' then
        --     return exports['my_drug_script']:GetPlayerDrugTest(targetId)
        -- end

        -- Default: the built-in consumption tracker (see Detection above).
        -- Other scripts can report drug use to it via:
        --   exports['p_policejob']:RegisterDrugConsumption(playerId, 'Cocaine', 20)
        --   TriggerEvent('p_policejob:drugConsumed', playerId, 'Cocaine', 20)
        return DrugTestDetection:getResults(targetId)
    end,

    ---@field onOpen: function [CLIENT - called when the UI opens - (targetId: number)]
    onOpen = function(targetId)
    end,

    ---@field onClose: function [CLIENT - called when the UI closes - (targetId: number)]
    onClose = function(targetId)
    end,

    ---@field onTestStart: function [CLIENT - called when the test starts - (targetId: number)]
    onTestStart = function(targetId)
    end,

    ---@field onTestComplete: function [CLIENT - called when the test finishes - (targetId: number, result: any)]
    onTestComplete = function(targetId, result)
    end,

    ---@field onTestStart_Server: function [SERVER - called when the test starts - (officerId: number, targetId: number)]
    onTestStart_Server = function(officerId, targetId)
    end,

    ---@field onTestComplete_Server: function [SERVER - called when the test finishes - (officerId: number, targetId: number, result: any)]
    onTestComplete_Server = function(officerId, targetId, result)
    end,
}
