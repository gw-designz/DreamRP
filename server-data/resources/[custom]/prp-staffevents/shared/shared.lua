lib.locale()

Animations = {} ---@type table<string, { label: string, value: string, category: string, categoryLabel: string, AnDictionary: string, AnAnim: string, flag: number }>
AnimList = {} ---@type { label: string, name: string }[]
Minigames = {}
Weapons = {} ---@type { name: string, label: string }[]

Permissions = {
    {
        name = "add_stash",
        label = "Add Stash",
    },
    {
        name = "remove_stash",
        label = "Remove Stash",
    },
    {
        name = "refill_stash",
        label = "Refill Stash",
    },
    {
        name = "edit_stash_items",
        label = "Edit Stash Items",
    },
    {
        name = "add_stash_to_object",
        label = "Add Stash to Object",
    },
    {
        name = "remove_scene",
        label = "Remove Scene",
    },
    {
        name = "disable_scene",
        label = "Toggle Enable/Disable Scene",
    },
    {
        name = "edit_scene",
        label = "Create and Edit Scene",
    },
    {
        name = "all",
        label = "All Permissions",
    }
}

TimeSettings = {
    {
        label = locale("MINUTES", 5),
        value = 5 * 60
    },
    {
        label = locale("MINUTES", 15),
        value = 15 * 60
    },
    {
        label = locale("MINUTES", 30),
        value = 30 * 60
    },
    {
        label = locale("HOUR", 1),
        value = 60 * 60
    },
    {
        label = locale("HOURS", 2),
        value = 2 * 60 * 60
    },
    {
        label = locale("HOURS", 3),
        value = 3 * 60 * 60
    },
    {
        label = locale("HOURS", 5),
        value = 5 * 60 * 60
    },
    {
        label = locale("HOURS", 8),
        value = 8 * 60 * 60
    },
    {
        label = locale("HOURS", 12),
        value = 12 * 60 * 60
    },
    {
        label = locale("HOURS", 24),
        value = 24 * 60 * 60
    },
    {
        label = locale("HOURS", 48),
        value = 48 * 60 * 60
    },
    {
        label = locale("HOURS", 72),
        value = 72 * 60 * 60
    },
    {
        label = locale("WEEK"),
        value = 7 * 24 * 60 * 60
    },
    {
        label = locale("WEEKS", 2),
        value = 14 * 24 * 60 * 60
    },
    {
        label = locale("MONTH"),
        value = 30 * 24 * 60 * 60
    },
    {
        label = locale("MONTHS", 2),
        value = 60 * 24 * 60 * 60
    },
}

---@param fileName string
---@return table?
local function loadJsonFile(fileName)
    local file = LoadResourceFile(GetCurrentResourceName(), fileName)
    if file then
        local j = nil
        local success, err = pcall(function()
            j = json.decode(file)
        end)
        if success then
            return j
        else
            print("Error parsing JSON file: " .. tostring(fileName) .. "\nError: " .. err)
            return nil
        end
    else
        print("Could not load file: " .. tostring(fileName))
        return nil
    end
end

-- Load Animations
CreateThread(function()
    local anims = loadJsonFile("editable/animations.json")
    if not anims then
        print("^1Failed to load animations.json^7")
        return
    end

    for i=1, #anims do
        local anim = anims[i] ---@type { name: string, label: string, category: string, animDict: string, animName: string, animFlag: number }
        AnimList[#AnimList + 1] = { label = anim.label, name = anim.name }
        Animations[anim.name] = {
            label = anim.label,
            value = anim.name,
            category = anim.category,
            categoryLabel = anim.category,
            AnDictionary = anim.animDict,
            AnAnim = anim.animName,
            flag = anim.animFlag
        }
    end
end)

-- Load Minigames
CreateThread(function()
    local minigames = loadJsonFile("editable/minigames.json")
    if not minigames then
        print("^1Failed to load minigames.json^7")
        return
    end

    Minigames = minigames
end)

-- Load Weapons
CreateThread(function()
    local weaponsList = loadJsonFile("editable/weapons.json")
    if not weaponsList then
        print("^1Failed to load weapons.json^7")
        return
    end

    Weapons = weaponsList
end)