-- Add this entry INSIDE QBShared.Items in qb-core/shared/items.lua.
-- Do not replace your existing items file.
-- Copy install/laptop.png into qb-inventory/html/images/.
['laptop'] = {
    name = 'laptop',
    label = 'Nova Laptop',
    weight = 2000,
    type = 'item',
    image = 'laptop.png',
    unique = true,
    useable = true,
    shouldClose = true,
    combinable = nil,
    description = 'Your own little space. Notes, stocks, jobs, and everything in between.'
},
