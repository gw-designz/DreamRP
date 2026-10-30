Config = Config or {}

Config.Armoury = {
    ---@field UseStock: boolean [if true track armoury item stock; false = unlimited and shows "∞" in the UI]
    UseStock = true,

    ---@field DefaultStock: number [stock value used when an item is first initialised (and no `stock` set in the map config)]
    DefaultStock = 50,

    ---@field ManageGrade: number [minimum job grade required to manage stock and per-grade limits in-game]
    ManageGrade = 4,

    ---@field RegisterWeaponsInMDT: boolean [if true, weapons purchased in the armoury get a serial and are registered to the buyer in p_mdt]
    RegisterWeaponsInMDT = true,
}
