Config = Config or {}


--[[
╔══════════════════════════════════════════════════════════════════════════════════╗
║                                BATTERY CONFIGURATION                             ║
╠══════════════════════════════════════════════════════════════════════════════════╣
║              For detailed documentation and setup instructions, visit:           ║
║        https://docs.teamsgg.dev/paid-scripts/phone/configure/battery-system      ║
╚══════════════════════════════════════════════════════════════════════════════════╝
--]]


-- With these settings, a full charge will last around 2 hours.
Config.Battery = {}
Config.Battery.Enabled = false       -- Enable battery on the phone, you'll need to use the exports to charge it.
Config.Battery.DrainInterval = {
    Active = { 50, 60 },             -- Always keep 2 numbers in the array. Min and Max seconds to drain 1% of the battery.
    Inactive = { 80, 120 }           -- Always keep 2 numbers in the array. Min and Max seconds to drain 1% of the battery.
}
Config.Battery.StartingBattery = 100 -- Starting battery percentage
Config.Battery.ShutdownThreshold = 0 -- Phone shuts down at this percentage
Config.Battery.ChargingRate = 5      -- Percentage per minute when charging

-- Vehicle Charging System
Config.Battery.VehicleCharging = {
    Enabled = true,             -- Enable vehicle charging
    RequiredItem = "usb_cable", -- Required item to charge in vehicle
    ChargingRate = 8,           -- Percentage per minute when charging in vehicle(default)
    EngineRequired = true,      -- Vehicle engine must be running
    MinEngineHealth = 300,      -- Minimum engine health required for charging
    VehicleTypes = {            -- Vehicle types that support charging
        [0] = true,             -- Compacts
        [1] = true,             -- Sedans
        [2] = true,             -- SUVs
        [3] = true,             -- Coupes
        [4] = true,             -- Muscle
        [5] = true,             -- Sports Classics
        [6] = true,             -- Sports
        [7] = true,             -- Super
        [8] = false,            -- Motorcycles
        [9] = true,             -- Off-road
        [10] = true,            -- Industrial
        [11] = true,            -- Utility
        [12] = true,            -- Vans
        [13] = false,           -- Cycles
        [14] = false,           -- Boats
        [15] = false,           -- Helicopters
        [16] = false,           -- Planes
        [17] = true,            -- Service
        [18] = true,            -- Emergency
        [19] = true,            -- Military
        [20] = true,            -- Commercial
        [21] = false,           -- Trains
    }
}

Config.Battery.NotifyMessages = {
    VehicleTypeNotSupported = "Vehicle type not supported for charging",
    NoPhoneDetected = "No phone detected",
    VehicleNotCompatible = "Vehicle not compatible or engine not running",
    NoUSBFound = "You need a USB cable to charge your phone",
    PhoneAlreadyCharging = "Phone is already charging",
    PhoneBatteryFull = "Phone battery is already full",
    ConnectingUSBCableProgress = "Connecting USB cable to vehicle...",
    PhoneConnectedToVehicleCharger = "Phone connected to vehicle charger (Enhanced rate: %s%%/min)",
    ConnectionCancelled = "Connection cancelled",
    VehicleChargingStopped = "Vehicle charging stopped",
    VehicleChargingNoPhoneDetected = "No phone detected",
    VehicleChargingConditionsNotMet = "Vehicle conditions no longer met",
    VehicleChargingPhoneFull = "Phone fully charged",
}
