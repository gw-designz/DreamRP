
Config = {}

Config.Debug = false
Config.Logs = false
Config.Framework = 'auto'
Config.Inventory = 'auto'
Config.Target = 'auto'
Config.Dispatch = 'auto'
Config.Locale = 'en-US'

-- Parcels: when true (default) the player carries the package prop and plays the
-- box-carry animation after collecting a parcel. Set to false to skip holding it
-- (the player still receives the item, just without the carry prop/animation).
Config.HoldParcelAfterCollect = true

Config.Modules = {
    ['MAILBOX_ROBBERY'] = true,
    ['PARKING_METER_ROBBERY'] = true,
    ['PARCEL_THEFT'] = true,
    ['PICKPOCKETING'] = true,
    ['SMASH_N_GRAB'] = true,
    ['MUGGING'] = true,
    ['ATM_ROBBERY'] = true,
    ['VENDING_MACHINE'] = true,
    ['TIRE_SLASH'] = true,
    ['PEDAL_BRICK'] = true,
    ['CASH_REGISTER_ROBBERY'] = true,
    ['STORE_SHELVES'] = true,
}
