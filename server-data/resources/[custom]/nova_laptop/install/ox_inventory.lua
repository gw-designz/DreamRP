-- Add these entries INSIDE the returned table in ox_inventory/data/items.lua.
-- Copy install/laptop.png into ox_inventory/web/images/.
-- Keep the resource folder named nova_laptop, or update the exports below.
['laptop'] = {
    label = 'Weazel Laptop',
    weight = 2000,
    stack = false,
    close = true,
    consume = 0,
    description = 'LifeInvader for Business, Weazel Writer and the magazine desk.',
    client = {
        image = 'laptop.png',
        export = 'nova_laptop.UseLaptop'
    }
},

-- Used up by the office printer, one sheet per copy (Config.News.Printing.Paper).
['paper'] = {
    label = 'Paper',
    weight = 5,
    description = 'A sheet of printer paper.',
},

-- A printed issue. Its metadata says which issue; using it opens the reader.
['magazine'] = {
    label = 'LifeInvader Magazine',
    weight = 150,
    stack = false,
    close = true,
    consume = 0, -- reading it keeps it
    description = 'A printed copy of LifeInvader Magazine.',
    client = {
        export = 'nova_laptop.ReadMagazine'
    }
},
