Config = {
    RealEstateJobs = {
        -- ["job name"] = minimum grade to access real estate menu,
        ["realestate"] = {
            ["creation"] = 0,                -- Can create new properties
            ["allproperties"] = 1,           -- Can view all properties in admin panel
            ["deleteproperty"] = 1,          -- Can delete properties
            ["deletebuilding"] = 1,          -- Can delete buildings
            ["forceopeninventory"] = 1,      -- Can force open property inventories
            ["transfer"] = 1,                -- Can transfer properties
            ["update_inventory_config"] = 1, -- Can update property inventory config (change the inventory weight and slots)
            ["edit_property"] = 1,           -- Can edit property settings
            ["edit_building"] = 1,           -- Can edit building settings
            ["change_interior"] = 1,         -- Can change property interior
            ["give_furniture"] = 1,          -- Can spawn furniture as item
            ["terminate_renter"] = 1,        -- Can terminate renters (cancel rent from /allproperties menu)
        },
    },

    CreatePropertyCommand = "createproperty",              -- The command to create a property
    ToggleBlipsCommand = "togglepropertyblips",            -- The command to toggle property blips
    AdminPanelCommand = "allproperties",                   -- The command to open the admin panel
    GiveStarterApartmentCommand = "givestarterapartments", -- The command to give starter apartments to all players (run only once)
    GiveFurnitureCommand = "givefurniture",                -- The command to give furniture to a player

    PoliceRaid = {
        Enabled = true,
        Jobs = {
            -- ["job name"] = minimum grade to breach door,
            ["police"] = 0,
            ["sheriff"] = 1,
        },
    },

    PoliceLockdown = {
        DisableEnter = true,              -- Disable entering properties during lockdown
        DisableInventory = true,          -- Disable inventory during lockdown
        DisableGarage = true,             -- Disable garage during lockdown
        DisableKeyManagement = true,      -- Disable key management during lockdown
        DisableInteractablePoints = true, -- Disable interactable points during lockdown
        DisableDoorManagement = true,     -- Disable door management during lockdown
        DisableSellProperty = true,       -- Disable selling properties during lockdown
        DisableFurniture = true,          -- Disable furniture during lockdown
        DisableIplManagement = true,      -- Disable ipl management during lockdown
    },

    --[[ Framework ]]

    FixShellOffsets = true, -- Enable the shell offsets fix

    -- Enable the offset finder used to find the offset of the shells
    -- This is useful if you want to add custom shells
    -- It will register new commands that everyone can use so it's recommended to disable this in production
    EnableOffsetFinder = true, -- Enable the offset finder

    --[[
        Supported Frameworks:
        * qbox
        * qbcore
        * esx
        * ox_core
        * standalone (you need to do the integration yourself)
    ]]
    Framework = "auto",
    --[[
        Suppoted Interact Options:
        * lib.zones
        * ox_target - https://github.com/overextended/ox_target
        * interact - https://github.com/darktrovx/interact
        * sleepless_interact - https://github.com/Sleepless-Development/sleepless_interact
        * sleepless_interactv2 - https://github.com/Sleepless-Development/sleepless_interact
        * bl_sprites - https://github.com/Byte-Labs-Studio/bl_sprites
    ]]
    InteractOption = "auto",
    --[[
        Supported garages:
        * nolag_garages
        * cd_garage
        * qb-garages
        * jg-advancedgarages
        * loaf_garage
        * okokGarage
        * rcore_garage
        * zerio-garage
        * rx_garages
        * vms_garagesv2
        ! You can add your own in custom/garages/
    ]]
    Garage = "auto",
    --[[
        Supported inventories:
        * ox_inventory
        * qb-inventory-v1
        * qb-inventory-v2
        * core_inventory
        * mf-inventory
        * qs-inventory
        * chezza_inventory
        * tgiann-inventory
        ! You can add your own in custom/inventory/
    ]]
    Inventory = "auto",
    --[[
        Supported clothing scripts:
        * illenium-appearance
        * bl_appearance
        * qb-clothing
        * fivem-appearance
        * rcore_clothing
        * rcore_clothes (The old version of rcore_clothing)
        * vms_clothestore
        * 17mov_CharacterSystem
        * crm-appearance
        * codem-appearance
        ! You can add your own in custom/clothes/
    ]]
    Clothes = "auto",
    --[[
        Supported weather scripts:
        * Renewed-Weathersync
        * randol_weather
        * av_weather
        * cd_easytime
        * qb-weathersync
        * night_natural_disasters
        * vSync
        ! You can add your own in custom/weather/
    ]]
    Weather = "auto",
    --[[
        Supported banking scripts:
        * tgg-banking
        * Renewed-Banking
        * snipe-banking
        * okokBanking (Only for QB, use esx_addonaccount for ESX)
        * fd_banking
        * LGMods_Banking
        * qb-banking
        * qb-management
        * esx_addonaccount
    ]]
    Banking = "auto",
    --[[
        Supported dispatch methods:
        * ps-dispatch
        * nolag_properties (default from nolag_properties)
        ! You can add your own in custom/dispatch/
    ]]
    Dispatch = "auto",
    --[[
        Supported log methods:
        * ox_lib
        * discord
        ! You can add your own in custom/logs/
    ]]
    Logs = "ox_lib",

    -- Set the color theme in the config
    -- setr nolag:primaryColor violet
    -- setr nolag:primaryShade 8
    ColorTheme = {
        useOxTheme = true,        -- If set to true the color theme will be based on the ox_theme otherwise it will use the nolag colors (nolag:primaryColor, nolag:primaryShade)
        laser = { r = 108, g = 0, b = 135, a = 200 },
        laserBasedOnTheme = true, -- If set to true the laser color will be based on the theme color
    },

    UseContextMenuForInteractionMenu = true, -- Use the context menu for the interaction menu

    ModelRequestTime = 30000,                -- The time to wait for a model to load
    FurnitureModelTimeout = 10000,           -- The time to wait for furniture models to load with UI indicator (default: 10 seconds, min: 5000, max: 30000)
    -- When placing furniture from the menu, a loading indicator will show while the model loads
    -- If the model fails to load within this time, the placement will be cancelled

    DynamicDoors = true,

    --[[ Point Selection Methods ]]
    -- Configure which method to use for different point selection types
    -- "laser" = Laser crosshair method
    -- "ped" = Ped placement method
    PointSelectionMethods = {
        enterPoint = "laser",         -- Enter point selection method
        exitPoint = "ped",            -- Exit point selection method (spawn coords)
        mloInteractPoint = "laser",   -- MLO interaction point selection method
        interactablePoints = "laser", -- General interactable points selection method
    },

    --[[ Properties ]]
    --[[ Lockpick Configuration ]]
    Lockpick = {
        Enable = false,                -- Enable lockpicking by other players (default: false)
        RequireOwnerOnline = false,    -- Require the property owner or renter (if the property is rented) to be online to lockpick the property (default: false)
        AllowCompanyProperties = true, -- Allow lockpicking of company/society owned properties (default: true)
        ShowLockpickButton = false,     -- Show the lockpick button in the interaction menu (default: true)

        Item = {
            Require = false,         -- Require a lockpick item to lockpick (default: false)
            Name = 'lockpick',       -- The name of the lockpick item
            Amount = 1,              -- The amount of lockpick items required
            RemoveOnFail = true,     -- Remove the lockpick item on failed attempt (default: true)
            RemoveOnSuccess = false, -- Remove the lockpick item on successful attempt (default: false)
        },

        --- Lockpick minigame function
        ---@param item string | number
        ---@param difficulty number
        ---@param pins number
        ---@return boolean? success
        Minigame = function(item, difficulty, pins)
            lib.playAnim(cache.ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 3.0, 1.0, -1, 49)
            local success = lib.skillCheck({ 'easy', 'easy', { areaSize = 60, speedMultiplier = 2 }, 'hard' }, { 'q', 'w', 'e', 'r' })
            ClearPedTasks(cache.ped)
            return success
        end,
    },

    LockDoorsByDefault = false,                  -- Save the door lock state to the database
    ExitEnterWhileLocked = true,                 -- Allow entering and exiting while locked (if you have a key)
    EnterExitAnimations = false,                 -- Enable enter and exit animations
    OpenForPreview = true,                       -- Allow the property to be enter for preview (if the property is for sale or for rent)
    SpawnInProperty = true,                      -- Spawn the player in the property if they disconnected while inside one otherwise it will spawn them at the outside door (default: true)
    PropertyPrice = { 1, 1000000 },              -- The price of the property, first number is the minimum, second is the maximum.
    InactivityDays = 30,                         -- The amount of days before a property is considered inactive and set for sale (If you want to disable you can just set it to false)
    InactivityDaysForRent = 30,                  -- The amount of days before a property is considered inactive and auto renew is disabled (If you want to disable you can just set it to false)
    MaxPropertiesPerPlayer = false,              -- The maximum amount of properties a player can owned
    PropertyLimitOverrides = {                   -- Overrides the property limit for a player based on the character identifier/citizenid
        -- Example:
        -- ["character_identifier"] = 5, -- This player can own up to 5 properties
    },
    MaxRentsPerPlayer = false,     -- The maximum amount of rents a player can have
    PropertyRentLimitOverrides = { -- Overrides the property rent limit for a player based on the character identifier/citizenid
        -- Example:
        -- ["character_identifier"] = 5, -- This player can own up to 5 properties
    },
    -- This is the radius of the yard zone that will be used for spawning the outside furniture
    -- If set to lower value the outside furniture will be spawned when the player is near the property
    -- If set to higher value the outside furniture will be spawned when the player is far from the property
    YardZoneRadius = 10,         -- The radius of the yard zone (default: 10)
    MaxFurnitureInside = false,  -- Global limit for inside furniture count per property (false to disable)
    MaxFurnitureOutside = false, -- Global limit for outside furniture count per property (false to disable)
    DefaultFurnitureWeight = 1000, -- The default weight for the furniture
    -- If enabled, furniture buy/sell money for society-owned or society-rented properties
    -- will use the society account. If disabled, money is taken from/paid to the player.
    FurnitureUseSocietyAccountForSocietyProperties = false,
    -- Ability to add myself as a keyholder (default: false) If set to true the player will be able to add himself as a keyholder when he is owner of the property
    AllowSelfAsKeyholder = false,

    --[[ Security Cam ]]
    SecurityCamFilter = "secret_camera",         -- The filter for the security cameras (default: "CAMERA_secuirity_FUZZ") https://wiki.rage.mp/index.php?title=Timecycle_Modifiers
    SecurityCamFilterStrength = 1,               -- The strength of the filter (default: 0.4)
    SecurityCamNightVision = true,               -- Enable/disable night vision toggle for security cameras (default: true)
    SecurityCamNightVisionFilter = "MP_heli_cam", -- The filter for the night vision mode (default: "MP_heli_cam")
    SecurityCamNightVisionStrength = 1,          -- The strength of the night vision filter (default: 1)
    MaxSecurityCameras = false,                  -- Global limit for security cameras count per property (false to disable)
    MaxSecurityCamerasInside = false,            -- Limit for inside security cameras count per property (false to disable)
    MaxSecurityCamerasOutside = false,            -- Limit for outside security cameras count per property (false to disable)


    --[[ Utility Bills ]]
    UtilityBills = {
        Enabled = true,
        BillingPeriod = 7, -- Billing period in days
        GratisPeriod = 3,  -- The number of days before the utility is cut off
        Prices = {
            -- Base prices per billing period (consumption costs are added on top if UtilityConsumption is enabled)
            Electricity = 100, -- Base price per billing period for electricity
            Water = 50,        -- Base price per billing period for water
            Internet = 75      -- Price per billing period for internet (no consumption tracking)
        }
    },

    --[[ Utility Consumption ]]
    -- Track electricity usage based on time spent inside with lights on
    -- Track water usage when using showers and sinks
    UtilityConsumption = {
        Enabled = true,
        Electricity = {
            Enabled = true,
            -- Cost per minute with lights on inside the property
            CostPerMinute = 0.5,
            -- Interval in seconds to track electricity consumption
            TrackingInterval = 60,
        },
        Water = {
            Enabled = true,
            -- Cost per shower use
            ShowerCost = 2.0,
            -- Cost per sink use (handwash/facewash)
            SinkCost = 0.5,
            -- Duration of shower animation in ms
            ShowerDuration = 10000,
            -- Duration of sink animation in ms
            SinkDuration = 5000,
        },
        -- Function called after washing (shower or sink)
        -- Useful for clearing evidence, gunpowder residue, etc.
        ---@param washType 'shower' | 'sink_handwash' | 'sink_facewash'
        ---@param property table The property object
        OnWashComplete = function(washType, property)
            -- Example: Clear gunpowder residue after washing
            -- if washType == 'shower' then
            --     TriggerEvent('evidence:clearGunpowder')
            --     TriggerEvent('evidence:clearBlood')
            -- elseif washType == 'sink_handwash' or washType == 'sink_facewash' then
            --     TriggerEvent('evidence:clearGunpowder')
            -- end
            lib.print.debug('Wash complete: ' .. washType .. ' in property #' .. property.id)
        end,
    },

    --[[ Selling ]]
    SellPercentage = 70, -- The percentage of the property price the owner will get back when selling it to the government (default: 70 %)
    DefaultBuyerType = "society",

    -- [[Starter Apartment]]
    -- This is the starter apartment that will be used for the player when they first join the server
    -- You can change the building id to the one you want to use as a starter apartment
    StarterApartment = {
        Enabled = true,             -- Enable the starter apartment
        DisableForceSale = true,    -- Disable the starter apartment from being force sold
        DisableSell = true,         -- Disable the starter apartment from being set for sale
        DisableRent = true,         -- Disable the starter apartment from being set for rent
        DisableInactivity = true,   -- Disable the starter apartment from being set for sale by inactivity
        DisableFurniture = true,    -- Disable furniture functionality for starter apartments
        BuildingId = 1,             -- The building id of the starter apartment
        Address = "Los Santos",     -- The address of the starter apartment
        Name = "Starter Apartment", -- The name of the starter apartment
        UniqueName = true,          -- If true, the name will be unique it will add a number to the name if there is already a property with the same name
        RentedInstead = true,       -- If true, the apartment will be rented instead of owned
        InitialRentDays = 7,        -- How many days the starter apartment should be rented for free
        FutureRentPrice = 500,      -- How much it will cost to renew the rent after the free period
        Interior = {
            type = "shell",         -- The type of the interior, "shell" or "ipl"
            name = "Container",     -- The name of the shell or ipl
        },
        Inventory = {
            slots = 10,     -- The amount of slots the inventory has
            weight = 10000, -- The weight of the inventory
        },
        InteractablePoints = {
            ["OpenInventory"] = true, -- The name of the interactable point
            ["ClothingMenu"] = true,  -- The name of the interactable point
        }
    },

    Building = {
        OwnerDisplay = true,       -- Enable the owner display
        OwnerDisplayType = "name", -- The type of the owner display, "identifier", "type" (user or society) or "name" (default: "identifier")
    },

    EnableMap = false, -- Enable the leaflet map displayed in the the creation menu

    --[[
        The type of the selling, "society" or "user" (default: "society") if set to "user"
        you need to set the identifier of the government in the config
    ]]
    DefaultBuyerIdentifier = "realestate",
    --[[
        The identifier of the government (default: "realestate") if DefaultSellType is set
        to "user" this needs to be set to the identifier of the user that will recive the
        money and the property
    ]]
    RequireDefaultSellToBuy = false,
    --[[
        If set to true the DefaultSellIdentifier needs to have enough money to buy the property
        otherwise the property will not be sold (default: false)
    ]]
    SellPercentageForTheGovernment = 100,
    --[[
        The percentage of the property price the government will pay when buying it from a
        player (default: 100 %) if set to 100 % the government will pay the full price of
        the property. If a player is selling property the fast way then it will get the money
        from the DefaultSellIdentifier and the property will be sold to the DefaultSellIdentifier
        if the DefaultSellIdentifier doesn't have enough money then the property will be sold
        * only if RequireDefaultSellToBuy is set to true
    ]]
    ResetPropertyPriceOnSell = true, -- Should the property price be reset to the purchase price when the property is force sold?

    BuyPropertyOnCreation = false,   -- Should the player or society buy the property on creation?
    --[[
        If set to true the player will have to pay the price of the property on creation,
        if set to false the player will get the property for free on creation (default: false)
    ]]
    CreatePropertyAsSociety = true, -- Should the property be assigned to a society on creation?
    --[[
        If set to true the player will buy the property as a society, if set to false the player
        will buy the property as a user (default: true)
    ]]
    DisableSocietyBuying = false,              -- Disable buying properties as a society
    DisableSocietyRenting = false,             -- Disable renting properties as a society
    RequireBossGradeForSocietyBuying = false,  -- Require boss grade to buy properties as a society
    RequireBossGradeForSocietyRenting = false, -- Require boss grade to rent properties as a society

    ProcessPropertiesCron = "*/30 * * * *",    -- The cron job to process the properties (Auto-rent, inactivity, etc) (default: */30 * * * *)

    --[[ Renting ]]
    OwnerCanCancelRent = false,       -- Enable the owner to cancel the rent (default: false)
    EnableRenting = true,             -- Enable renting of properties
    EnableForceSale = true,           -- Enable force saling of properties
    RentPercentage = 90,              -- How much money will the owner get from the rent (default: 90 %)
    MaxRentDays = 10,                 -- Maximum number of days a property can be rented for (default: 10)
    RemoveAllKeysOnRentCancel = true, -- Should all keys be removed when the rent is canceled?
    LockDoorsOnForceSale = true,      -- Should the doors be locked when the property is force sold?
    -- Enable selling of properties (default: true) If set to false the property will be sold only one time after creation
    -- and then it will be transferable only trough the admin menu
    EnableSellProperty = true,

    -- [[ Ipls ]]
    IplPrice = { 1, 1000000 },     -- The price of the ipl, first number is the minimum, second is the maximum.
    PaidIplChanges = true,         -- Does the player have to pay for IPL changes?
    IplDistanceToCheck = 50.0,     -- The distance to check if a player is near the ipl and if not, it will teleport the player to the ipl
    IplsUseRoutingBuckets = false, -- Use routing buckets instead of concealing for ipls (concealing allows to see the outside world when in ipl with windows but could be problematic for some people)


    --[[ Shells ]]
    ShellZLevel = 2000.0,        -- The z level of the shell spawn (default: 2000)
    ShellPrice = { 1, 1000000 }, -- The price of the shell, first number is the minimum, second is the maximum.
    --[[
        Use routing buckets for the shell (default: false)
    ]]
    ShellUseRoutingBuckets = true,
    ShellDistanceToCheck = 50.0, -- The distance to check if a player is near the shell and if not, it will teleport the player to the shell

    --[[ Mlos ]]
    MloPriceBasedOnArea = true,    -- Should the price be based on the area of the mlo?
    MloInventoryData = {
        Slots = { 1, 100 },        -- The amount of slots the inventory has, first number is the minimum, second is the maximum
        Weight = { 1, 1000000 },   -- The weight of the inventory, first number is the minimum, second is the maximum
    },
    PricePerSquare = { 1, 200 },   -- The price per square meter, first number is the minimum, second is the maximum
    MloPrice = { 1, 1000000 },     -- The price of the mlo, first number is the minimum, second is the maximum (if MloPriceBasedOnArea is false)

    LimitFreeCam = true,           -- Limit the freecam to the property area
    LimitFreeCamDistance = 100.0,  -- The distance from the property to the freecam limit
    RestrictFreecamToZone = false, -- Restrict freecam movement to stay within property/building zone boundaries (prevents abuse)

    DefaultSlots = 50,             -- The default amount of slots for the inventory
    DefaultWeight = 10000,         -- The default weight for the inventory

    Keybinds = {
        Interact = 'E',        -- The keybind to interact with the property
        PropertyMenu = "F5",   -- The keybind to open the property menu
        DeleteShell = "BACK",  -- The keybind to delete shell (offset finder / testshell)
    },

    Trash = {
        Enabled = true, -- Should the trash be enabled?
        TrashCreatedOnCron = true, -- Should the trash be created on the cron job? (automatically add trash to properties)
        TrashCreatedOnCronCount = 1, -- The amount of trash to create on the cron job 
        Objects = {
            `proc_litter_01`,
            `proc_litter_02`,
            `prop_rub_litter_01`,
            `prop_rub_litter_02`,
            `prop_rub_litter_03`,
            `prop_rub_litter_04`,
            `prop_rub_litter_05`,
            `prop_rub_litter_06`,
            `prop_rub_litter_07`,
            `prop_rub_flotsam_01`,
            `prop_rub_flotsam_03`,
        }
    },

    InteractDistance = 1.5, -- The distance to interact with the property (ox_target - default: 1.5)
    InteractRadius = 1.5,   -- The radius to interact with the property (ox_target - default: 1.5)
    --[[ Blips ]]
    --[[
        Display Types:
            0 = Doesn't show up, ever, anywhere.
            1 = Doesn't show up, ever, anywhere.
            2 = Shows on both main map and minimap. (Selectable on map)
            3 = Shows on main map only. (Selectable on map)
            4 = Shows on main map only. (Selectable on map)
            5 = Shows on minimap only.
            6 = Shows on both main map and minimap. (Selectable on map)
            7 = Doesn't show up, ever, anywhere.
            8 = Shows on both main map and minimap. (Not selectable on map)
            9 = Shows on minimap only.
            10 = Shows on both main map and minimap. (Not selectable on map)
            Anything higher than 10 seems to be exactly the same as 10.

        Categories:
            default = The blip that all players will see if they are not the owner of the property and
                        the property is not for sale or for rent
            owner = The blip that the owner of the property will see
            renter = The blip that the renter of the property will see
            keyholder = The blip that the keyholder of the property will see
            forSale = The blip that all players will see if the property is for sale
            forRent = The blip that all players will see if the property is for rent
    ]]
    Blips = {
        -- Properties
        ["ipl"] = {
            ["default"] = {
                Color = 3,
                Sprite = 40,
                Scale = 0.8,
                Category = 55, -- Property
                Display = 2,
                ShortRange = false,
                Disabled = true,
            },
            ["owner"] = {
                Color = 3,
                Sprite = 40,
                Scale = 0.8,
                Category = 50, -- Owned Property
                Display = 2,
                ShortRange = false,
                Disabled = false,
            },
            ["forSale"] = {
                Color = 69,
                Sprite = 374,
                Scale = 0.8,
                Category = 52, -- Property For Sale
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
            ["forRent"] = {
                Color = 69,
                Sprite = 374,
                Scale = 0.8,
                Category = 53, -- Property For Rent
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
            ["renter"] = {
                Color = 5,
                Sprite = 40,
                Scale = 0.8,
                Category = 51, -- Rented Property
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
            ["keyholder"] = {
                Color = 9,
                Sprite = 40,
                Scale = 0.8,
                Category = 54, -- Property with Key
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
        },
        ["shell"] = {
            ["default"] = {
                Color = 3,
                Sprite = 40,
                Scale = 0.8,
                Category = 55, -- Property
                Display = 2,
                ShortRange = false,
                Disabled = true,
            },
            ["owner"] = {
                Color = 3,
                Sprite = 40,
                Scale = 0.8,
                Category = 50, -- Owned Property
                Display = 2,
                ShortRange = false,
                Disabled = false,
            },
            ["forSale"] = {
                Color = 69,
                Sprite = 374,
                Scale = 0.8,
                Category = 52, -- Property For Sale
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
            ["forRent"] = {
                Color = 69,
                Sprite = 374,
                Scale = 0.8,
                Category = 53, -- Property For Rent
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
            ["renter"] = {
                Color = 5,
                Sprite = 40,
                Scale = 0.8,
                Category = 51, -- Rented Property
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
            ["keyholder"] = {
                Color = 9,
                Sprite = 40,
                Scale = 0.8,
                Category = 54, -- Property with Key
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
        },
        ["mlo"] = {
            ["default"] = {
                Color = 3,
                Sprite = 492,
                Scale = 0.8,
                Category = 55, -- Property
                Display = 2,
                ShortRange = false,
                Disabled = true,
            },
            ["owner"] = {
                Color = 3,
                Sprite = 492,
                Scale = 0.8,
                Category = 50, -- Owned Property
                Display = 2,
                ShortRange = false,
                Disabled = false,
            },
            ["forSale"] = {
                Color = 69,
                Sprite = 374,
                Scale = 0.8,
                Category = 52, -- Property For Sale
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
            ["forRent"] = {
                Color = 69,
                Sprite = 374,
                Scale = 0.8,
                Category = 53, -- Property For Rent
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
            ["renter"] = {
                Color = 5,
                Sprite = 492,
                Scale = 0.8,
                Category = 51, -- Rented Property
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
            ["keyholder"] = {
                Color = 9,
                Sprite = 492,
                Scale = 0.8,
                Category = 54, -- Property with Key
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
        },
        -- Buildings
        ["building"] = {
            ["default"] = {
                Color = 3,
                Sprite = 475,
                Scale = 0.8,
                Category = 55, -- Property
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
            ["ownProperty"] = {
                Color = 3,
                Sprite = 475,
                Scale = 0.8,
                Category = 50, -- Owned Property
                Display = 2,
                ShortRange = false,
                Disabled = false,
            },
            ["forSale"] = {
                Color = 69,
                Sprite = 374,
                Scale = 0.8,
                Category = 52, -- Property For Sale
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
            ["forRent"] = {
                Color = 69,
                Sprite = 374,
                Scale = 0.8,
                Category = 53, -- Property For Rent
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
            ["renter"] = {
                Color = 5,
                Sprite = 475,
                Scale = 0.8,
                Category = 51, -- Rented Property
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
            ["keyholder"] = {
                Color = 9,
                Sprite = 475,
                Scale = 0.8,
                Category = 54, -- Property with Key
                Display = 2,
                ShortRange = true,
                Disabled = false,
            },
        },

        -- Default visibility for the blips (for the menu)
        DefaultVisibility = {
            all = true,
            owned = true,
            forSale = true,
            forRent = true,
            renter = true,
            keyholder = true,
        },
    },

    Tags = {
        "🪑 Furnished",
        "🚗 Garage",
        "🏊 Pool",
        "🌳 Yard",
        "🌷 Garden",
        "🪟 Balcony",
        "🌇 Terrace",
        "🌊 Sea view",
        "🏔️ Mountain view",
        "🏙️ City view",
        "🌲 Forest view",
        "🏞️ Lake view",
        "🏞️ River view",
        "🅿️ Parking",
        "🏋️ Gym",
        "🧖 Sauna",
        "🛀 Jacuzzi",
        "🍺 Bar",
        "🎥 Cinema",
        "📚 Library",
        "🏢 Office",
        "🔥 Fireplace",
        "🌡️ Heating",
        "❄️ Air conditioning",
    },
    PropertiesPerPage = 16, -- The amount of properties to show per page in the building menu

    -- [[ Custom Functions ]]
    Functions = {
        -- ["OpenRealEstateMenu"] = {
        --     type = "inside", -- inside or outside
        --     maxPerProperty = 1, -- The maximum amount of real estate menu's per property
        --     label = "RealEstate Menu",
        --     icon = "fas fa-house-chimney-user",
        --     onSelect = function(property)
        --         lib.print.debug("Open Real Estate Menu for property #" .. property.id)
        --     end
        -- },
        ["UseShower"] = {
            type = "inside",
            maxPerProperty = 10,
            label = locale("use_shower") or "Use Shower",
            icon = "fas fa-shower",
            radius = 0.5,
            onSelect = function(property, data)
                if not Config.UtilityConsumption.Enabled or not Config.UtilityConsumption.Water.Enabled then
                    Framework.Notify({
                        description = locale("water_system_disabled") or "Water system is disabled",
                        type = "error"
                    })
                    return
                end

                -- Check if water is cut off
                if property.utilities and property.utilities.water and property.utilities.water.cutOff then
                    Framework.Notify({
                        description = locale("property_no_water") or "No water supply - bill unpaid",
                        type = "error"
                    })
                    return
                end

                local success = lib.callback.await('nolag_properties:server:property:useWater', false, property.id, 'shower')
                if not success then
                    Framework.Notify({
                        description = locale("water_use_failed") or "Failed to use water",
                        type = "error"
                    })
                    return
                end

                -- Play shower animation
                local player = cache.ped
                local duration = Config.UtilityConsumption.Water.ShowerDuration or 10000

                -- Face the correct direction if offset has heading
                if data and data.coords and data.coords.w and data.coords.w ~= 0 then
                    SetEntityHeading(player, data.coords.w)
                end

                if lib.progressCircle({
                        duration = duration,
                        label = locale("showering") or "Showering...",
                        useWhileDead = false,
                        canCancel = true,
                        disable = {
                            car = true,
                            move = true,
                            combat = true,
                        },
                        anim = {
                            dict = 'mp_safehouseshower@male@',
                            clip = 'male_shower_idle_a',
                            blendIn = 8.0,
                            blendOut = 8.0,
                            flag = 1,
                            lockX = true,
                            lockY = true,
                            lockZ = false,
                        }
                    }) then
                    -- Call the wash complete callback
                    if Config.UtilityConsumption.OnWashComplete then
                        Config.UtilityConsumption.OnWashComplete('shower', property)
                    end
                    Framework.Notify({
                        description = locale("shower_complete") or "You feel refreshed!",
                        type = "success"
                    })
                end
            end
        },
        ["UseSink"] = {
            type = "inside",
            maxPerProperty = 10,
            label = locale("use_sink") or "Use Sink",
            icon = "fas fa-faucet",
            radius = 0.5,
            onSelect = function(property, data)
                if not Config.UtilityConsumption.Enabled or not Config.UtilityConsumption.Water.Enabled then
                    Framework.Notify({
                        description = locale("water_system_disabled") or "Water system is disabled",
                        type = "error"
                    })
                    return
                end

                -- Check if water is cut off
                if property.utilities and property.utilities.water and property.utilities.water.cutOff then
                    Framework.Notify({
                        description = locale("property_no_water") or "No water supply - bill unpaid",
                        type = "error"
                    })
                    return
                end

                -- Show context menu for wash type selection
                lib.registerContext({
                    id = 'sink_wash_menu',
                    title = locale("sink_menu_title") or "Sink",
                    options = {
                        {
                            title = locale("wash_hands") or "Wash Hands",
                            icon = "fas fa-hands-wash",
                            onSelect = function()
                                local success = lib.callback.await('nolag_properties:server:property:useWater', false, property.id, 'sink')
                                if not success then
                                    Framework.Notify({
                                        description = locale("water_use_failed") or "Failed to use water",
                                        type = "error"
                                    })
                                    return
                                end

                                local player = cache.ped
                                local duration = Config.UtilityConsumption.Water.SinkDuration or 5000

                                if data and data.coords and data.coords.w and data.coords.w ~= 0 then
                                    SetEntityHeading(player, data.coords.w)
                                end

                                if lib.progressCircle({
                                        duration = duration,
                                        label = locale("washing_hands") or "Washing hands...",
                                        useWhileDead = false,
                                        canCancel = true,
                                        disable = {
                                            car = true,
                                            move = true,
                                            combat = true,
                                        },
                                        anim = {
                                            dict = 'missheist_agency3aig_23',
                                            clip = 'urinal_sink_loop',
                                            blendIn = 8.0,
                                            blendOut = 8.0,
                                            flag = 1,
                                            lockX = true,
                                            lockY = true,
                                            lockZ = false,
                                        }
                                    }) then
                                    if Config.UtilityConsumption.OnWashComplete then
                                        Config.UtilityConsumption.OnWashComplete('sink_handwash', property)
                                    end
                                    Framework.Notify({
                                        description = locale("hands_clean") or "Your hands are clean!",
                                        type = "success"
                                    })
                                end
                            end
                        },
                        {
                            title = locale("wash_face") or "Wash Face",
                            icon = "fas fa-head-side-mask",
                            onSelect = function()
                                local success = lib.callback.await('nolag_properties:server:property:useWater', false, property.id, 'sink')
                                if not success then
                                    Framework.Notify({
                                        description = locale("water_use_failed") or "Failed to use water",
                                        type = "error"
                                    })
                                    return
                                end

                                local player = cache.ped
                                local duration = Config.UtilityConsumption.Water.SinkDuration or 5000

                                if data and data.coords and data.coords.w and data.coords.w ~= 0 then
                                    SetEntityHeading(player, data.coords.w)
                                end

                                if lib.progressCircle({
                                        duration = duration,
                                        label = locale("washing_face") or "Washing face...",
                                        useWhileDead = false,
                                        canCancel = true,
                                        disable = {
                                            car = true,
                                            move = true,
                                            combat = true,
                                        },
                                        anim = {
                                            dict = 'missmic2_washing_face',
                                            clip = 'michael_washing_face',
                                            blendIn = 8.0,
                                            blendOut = -8.0,
                                            flag = 0,
                                            lockX = false,
                                            lockY = false,
                                            lockZ = false,
                                        }
                                    }) then
                                    if Config.UtilityConsumption.OnWashComplete then
                                        Config.UtilityConsumption.OnWashComplete('sink_facewash', property)
                                    end
                                    Framework.Notify({
                                        description = locale("face_clean") or "Your face is clean!",
                                        type = "success"
                                    })
                                end
                            end
                        },
                    }
                })
                lib.showContext('sink_wash_menu')
            end
        },
        ["LightSwitch"] = {
            type = "inside",
            maxPerProperty = 10,
            label = locale("light_switch") or "Light Switch",
            icon = "fas fa-lightbulb",
            radius = 0.5,
            onSelect = function(property)
                property:toggleLights(nil, true)
            end
        },
    },

    InteractableProps = {
        ["reh_prop_reh_switch_01a"] = {
            label = locale("light_switch") or "Light Switch",
            icon = "fas fa-lightbulb",
            radius = 1.5,
            maxPerProperty = 10,
            breakable = true,
            onSelect = function(property)
                lib.print.debug("Toggle lights for property #" .. property.id)
                property:toggleLights(nil, true)
            end
        },
        -- ["v_res_tre_plugsocket"] = {
        --     label = "Plug Socket",
        --     icon = "fas fa-plug",
        --     radius = 1.5,
        --     maxPerProperty = 6,
        --     breakable = true,
        --     onSelect = function(property)
        --         local info = exports.yseries:GetBatteryInfo()
        --         if info.level >= 100 then
        --             lib.print.debug("Battery is already fully charged")
        --             lib.notify({
        --                 title = "Plug Socket",
        --                 description = "The battery is already fully charged.",
        --                 type = "error"
        --             })
        --             return
        --         end
        --         if info.isCharging then
        --             lib.print.debug("Stopping charging")
        --             lib.notify({
        --                 title = "Plug Socket",
        --                 description = "You unplugged the phone from the socket.",
        --                 type = "error"
        --             })
        --             exports.yseries:StopCharging()
        --         else
        --             lib.print.debug("Starting charging")
        --             lib.notify({
        --                 title = "Plug Socket",
        --                 description = "You plugged in the phone to the socket.",
        --                 type = "success"
        --             })
        --             exports.yseries:StartCharging()
        --         end
        --     end,
        --     onExit = function(property)
        --         lib.print.debug("Exiting Plug Socket for property #" .. property.id)
        --         local info = exports.yseries:GetBatteryInfo()
        --         if info.isCharging then
        --             lib.print.debug("Stopping charging")
        --             exports.yseries:StopCharging()
        --             lib.notify({
        --                 title = "Plug Socket",
        --                 description = "Got too far away from the plug socket. Stopped charging.",
        --                 type = "success"
        --             })
        --         end
        --     end
        -- },
        -- ["p_v_43_safe_s"] = {
        --     label = "Safe",
        --     icon = "fas fa-lock",
        --     radius = 2.5,
        --     useObject = true,
        --     maxPerProperty = 1,
        --     breakable = true,
        --     inventory = {
        --         label = "Safe",
        --         slots = 25,
        --         weight = 100000,
        --     },
        -- },
        -- ["vw_prop_vw_key_cabinet_01a"] = {
        --     maxPerProperty = 1,
        --     label = "Key Cabinet",
        --     icon = "fas fa-key",
        --     radius = 2.5,
        --     useObject = true,
        --     canInteract = function(property)
        --         return PlayerData.job.name == "realestate"
        --     end,
        --     onSelect = function(property, data)
        --         lib.print.debug("Open Key Cabinet for property #" .. property.id)
        --     end,
        --     canDelete = function(property)
        --         return false, "Axel said so"
        --     end,
        --     canMove = function(property)
        --         return false, "Axel said so"
        --     end,
        --     onCreate = function(property)
        --         lib.print.debug("Create Key Cabinet for property #" .. property.id)
        --     end,
        --     onRemove = function(property)
        --         lib.print.debug(property)
        --         lib.print.debug("Remove Key Cabinet for property #" .. property.id)
        --     end,
        --     inventory = {
        --         label = "Key Cabinet",
        --         slots = 5,
        --         weight = 10000,
        --     },
        -- },
    },

    WardrobeObjects = {
        "ch_prop_ch_service_locker_01a",
        "ch_prop_ch_service_locker_02a",
        "apa_mp_h_str_shelffloorm_02",
        "apa_mp_h_str_shelffreel_01",
        "bkr_prop_gunlocker_01a",
        "apa_mp_h_str_shelfwallm_01",
        "v_serv_cupboard_01"
    },

    InventoryObjects = {
        ["p_v_43_safe_s"] = {
            slots = 35,
            weight = 100000,
            -- breakable = true, -- Can be broken with lockpick
            -- maxPerProperty = 1,
            -- radius = 2.5,
            -- icon = "fas fa-lock",
            -- label = "Safe",
        },
    },

    Bell = {
        Cooldown = 5000
    },

    --[[ Physical Keys ]]
    -- Physical keys use ox_inventory items to represent property keys
    -- Each key has a unique bitting code that identifies the lock it opens
    PhysicalKeys = {
        Enabled = true, -- Enable physical key system (requires ox_inventory)
        ItemName = 'housing_key', -- The item name for physical keys in ox_inventory
        KeychainItemName = 'keychain', -- The item name for the keychain in ox_inventory
        KeychainSlots = 5, -- The number of slots in the keychain
        KeychainMaxWeight = 1000, -- The maximum weight of the keychain
        -- Bitting code configuration
        BittingCodeLength = 5, -- Length of the random bitting code portion (e.g., 63323)
        -- Key types that can be issued
        KeyTypes = {
            MainEntrance = true, -- Keys for main property entrance (Shell/IPL)
            InteractablePoints = true, -- Keys for individual interactable points
            Doors = true, -- Keys for individual MLO doors
            MasterKey = true, -- Master key that unlocks everything
        },
        -- Allow re-keying (changing lock cylinders)
        AllowRekey = true,
        -- Cost to change the lock cylinder of a lock (0 for free)
        RekeyPrice = 500,
        -- Key wax system (allows players to make impressions of keys)
        KeyWax = {
            Enabled = true, -- Enable key wax functionality
            BlankItemName = 'key_wax', -- Blank key wax item name
            UsedItemName = 'key_wax_used', -- Used key wax (with bitting code imprint) item name
        },

        -- Ped configuration for key distribution
        -- You can add multiple locksmiths with different settings
        LockSmiths = {
            {
                Enabled = true, -- Enable this locksmith ped
                CreateInvalidKeys = true, -- Allow creating invalid keys
                CreateKeyByBittingCode = true, -- Allow creating a key by bitting code
                SellKeyWax = false, -- Allow buying blank key wax from this locksmith
                KeyWaxPrice = 500, -- Price for one blank key wax
                SellKeychain = false, -- Allow buying keychains from this locksmith
                KeychainPrice = 750, -- Price for one keychain
                KeyByBittingCodePrice = 1000, -- Price for a key by bitting code
                KeyPrice = 1000, -- Price for a key
                Model = 'IG_Benny_02', -- Ped model to use for key distribution
                Coords = vector4(169.9714, -1799.5154, 29.3159, 318.0738), -- Location for this ped
            },
            -- Example of additional locksmith (uncomment and modify to add more):
            {
                Enabled = true,
                CreateInvalidKeys = false, -- This locksmith doesn't create invalid keys
                CreateKeyByBittingCode = true,
                SellKeyWax = true,
                KeyWaxPrice = 750, -- Different key wax pricing per locksmith
                SellKeychain = true,
                KeychainPrice = 1000,
                KeyByBittingCodePrice = 1500, -- Higher price
                KeyPrice = 800, -- Lower key price
                Model = 's_m_m_autoshop_02', -- Different ped model
                Coords = vector4(-401.3177, -450.8532, 37.3349, 194.9187), -- Different location
            },
        },
    },

    Marketplace = {
        Enabled = true, -- Enables or disables the marketplace system
        AllowTransactionFromMenu = true, -- Allow transactions directly from the property management menu

        PriceFilter = {
            Max = 1000000, -- Maximum price for the filter slider ($1M)
            Step = 5000,   -- Step increment for the slider ($5K)
        },

        Blip = {
            Enabled = true,
            Sprite = 476,
            Scale = 0.8,
            Color = 43,
            Display = 4,
            ShortRange = true,
            Category = 1,
            Label = "Property Marketplace",
        },
        BlipCoords = vector3(-1082.4330, -247.6247, 37.7633), -- Location of the blip on the map

        TargetCoords = vector4(-1083.1598, -245.97, 37.6632, 208.5247), -- Target interaction coordinates (for targeting systems like ox_target)
        TargetRadius = 3.0, -- Target zone radius

        Ped = {
            Enabled = true,
            Model = 'ig_drfriedlander',
            Coords = vector4(-1083.1598, -245.97, 37.6632, 208.5247),
            InteractDistance = 2.5,
            -- Animation = { 'switch@michael@sitting', 'idle' }
        },
    },

    DoorLock = {
        DrawTextUI = false,
        Notify = true,
        SpriteIcons = {
            unlocked = {
                dict = 'mpsafecracking',
                texture = 'lock_open_dark',
                x = 0,
                y = 0,
                width = 0.018,
                height = 0.018,
            },
            locked = {
                dict = 'mpsafecracking',
                texture = 'lock_closed_dark',
                x = 0,
                y = 0,
                width = 0.018,
                height = 0.018,
            }
        }
    },

    CreationMenu = {
        PhotoFreecam = false, -- Enable freecam while taking creation photos
        ipl = {
            label = 'IPL',
            enabled = true,
            image = 'https://r2.fivemanage.com/acP9u7gLziIbHCwCT6NVX/57CYSM.jpg'
        },
        shell = {
            label = 'Shell',
            enabled = true,
            image = 'https://r2.fivemanage.com/acP9u7gLziIbHCwCT6NVX/Rm30eg.jpg'
        },
        mlo = {
            label = 'MLO',
            enabled = true,
            image = 'https://r2.fivemanage.com/acP9u7gLziIbHCwCT6NVX/kddbLu.png'
        },
        building = {
            label = 'Building',
            enabled = true,
            image = 'https://r2.fivemanage.com/acP9u7gLziIbHCwCT6NVX/HTu5AH.jpg',
            -- jobs = { -- If you want to restrict the building creation to certain jobs
            --     ["realestate"] = 1,
            -- }
        }
    },

    --- Toggle HUD
    ---@param toggle boolean true to show, false to hide
    ToggleHud = function(toggle)
        if GetResourceState("tgg-hud") == "started" then
            exports["tgg-hud"]:ToggleHud(toggle)
            return
        end

        DisplayHud(toggle)
        DisplayRadar(toggle)
    end,

    RaidProperty = function()
        local result = false

        local success = lib.skillCheck({ 'easy', 'easy' }, { 'w', 'a', 's', 'd' })
        if success then
            success = lib.progressCircle({
                duration = math.random(10000, 20000),
                label = 'Breaching the door..',
                disable = {
                    car = true,
                    combat = true,
                    move = true
                },
                anim = {
                    dict = "missheistfbi3b_ig7",
                    clip = 'lift_fibagent_loop'
                }
            })
            if success then
                result = true
            end
        end

        return result
    end,

    Debug = false,              -- Simple debug mode
    ManualSQLInjection = false, -- Enable manual SQL injection
    CheckForUpdates = true,     -- Check for updates on start
}

if Config.Framework == 'auto' then
    lib.print.debug('Detecting framework...')

    if GetResourceState('qbx_core'):find('start') then
        Config.Framework = 'qbox'
    elseif GetResourceState('qb-core'):find('start') then
        Config.Framework = 'qbcore'
    elseif GetResourceState('es_extended'):find('start') then
        Config.Framework = 'esx'
    elseif GetResourceState('ox_core'):find('start') then
        Config.Framework = 'ox_core'
    else
        Config.Framework = 'standalone'
    end

    lib.print.debug('Detected framework: ' .. Config.Framework)
end

if Config.InteractOption == 'auto' then
    lib.print.debug('Detecting interact option...')

    local interactOptions = {
        'ox_target',
        'interact',
        'sleepless_interact',
        'bl_sprites',
    }

    for i = 1, #interactOptions do
        if GetResourceState(interactOptions[i]):find('start') then
            if interactOptions[i] == 'sleepless_interact' then
                local version = GetResourceMetadata('sleepless_interact', 'version', 0)
                if version and tonumber(string.sub(version, 1, 1)) >= 2 then
                    Config.InteractOption = 'sleepless_interactv2'
                else
                    Config.InteractOption = 'sleepless_interact'
                end
            else
                Config.InteractOption = interactOptions[i]
            end
            break
        end
    end

    if Config.InteractOption == 'auto' then
        Config.InteractOption = 'lib.zones'
    end

    lib.print.debug('Detected interact option: ' .. Config.InteractOption)
end

if Config.Inventory == 'auto' then
    lib.print.debug('Detecting inventory...')

    local inventories = {
        'ox_inventory',
        'qb-inventory',
        'core_inventory',
        'mf-inventory',
        'qs-inventory',
        'inventory',
        'tgiann-inventory',
    }

    for i = 1, #inventories do
        if GetResourceState(inventories[i]):find('start') then
            if inventories[i] == 'qb-inventory' then
                local version = GetResourceMetadata('qb-inventory', 'version', 0)
                if version and tonumber(string.sub(version, 1, 1)) >= 2 then
                    Config.Inventory = 'qb-inventory-v2'
                else
                    Config.Inventory = 'qb-inventory-v1'
                end
            else
                Config.Inventory = inventories[i]
            end
            break
        end
    end

    lib.print.debug('Detected inventory: ' .. Config.Inventory)
end

if Config.Clothes == 'auto' then
    lib.print.debug('Detecting clothes...')

    local clothes = {
        'illenium-appearance',
        'qb-clothing',
        'fivem-appearance',
        'rcore_clothing',
        'rcore_clothes',
        'vms_clothestore',
        '17mov_CharacterSystem',
        'crm-appearance',
        'bl_appearance',
        'codem-appearance',
        '0r-clothingv2',
    }

    for i = 1, #clothes do
        if GetResourceState(clothes[i]):find('start') then
            Config.Clothes = clothes[i]
            break
        end
    end

    lib.print.debug('Detected clothes: ' .. Config.Clothes)
end

if Config.Weather == 'auto' then
    lib.print.debug('Detecting weather...')

    local weathers = {
        'Renewed-Weathersync',
        'randol_weather',
        'qb-weathersync',
        'av_weather',
        'cd_easytime',
        'vSync',
        'night_natural_disasters',
        'm-Weather',
    }

    for i = 1, #weathers do
        if GetResourceState(weathers[i]):find('start') then
            Config.Weather = weathers[i]
            break
        end
    end

    lib.print.debug('Detected weather: ' .. Config.Weather)
end

if Config.Banking == 'auto' then
    lib.print.debug('Detecting banking...')

    local bankings = {
        'tgg-banking',
        'Renewed-Banking',
        'snipe-banking',
        'okokBanking',
        'fd_banking',
        'LGMods_Banking',
        'qb-banking',
        'qb-management',
        'esx_addonaccount',
    }

    for i = 1, #bankings do
        if GetResourceState(bankings[i]):find('start') then
            if bankings[i] == 'qb-banking' and tonumber(string.sub(GetResourceMetadata('qb-banking', 'version', 0), 1, 3)) < 2 then
                goto skip
            end

            Config.Banking = bankings[i]
            break
        end
        ::skip::
    end

    lib.print.debug('Detected banking: ' .. Config.Banking)
end

if Config.Dispatch == 'auto' then
    lib.print.debug('Detecting dispatch...')
    local dispatches = {
        'ps-dispatch',
        'nolag_properties',
    }
    for i = 1, #dispatches do
        if GetResourceState(dispatches[i]):find('start') then
            Config.Dispatch = dispatches[i]
            break
        end
    end
    lib.print.debug('Detected dispatch: ' .. Config.Dispatch)
end

if Config.Garage == 'auto' then
    lib.print.debug('Detecting garage...')

    local garages = {
        'nolag_garages',
        'cd_garage',
        'qb-garages',
        'jg-advancedgarages',
        'qbx_garages',
        'loaf_garage',
        'okokGarage',
        'rcore_garage',
        'zerio-garage',
        'rx_garages',
        'vms_garagesv2',
    }

    for i = 1, #garages do
        if GetResourceState(garages[i]):find('start') then
            Config.Garage = garages[i]
            break
        end
    end

    lib.print.debug('Detected garage: ' .. Config.Garage)
end
