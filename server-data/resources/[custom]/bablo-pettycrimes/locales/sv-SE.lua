
if not Locales then
    Locales = {}
end

Locales['sv-SE'] = {
    -- Smash n grab

    ["NO_LOOT_FOUND"] = "Ingen loot hittades.",
    ["WINDOW_SMASHED_ALREADY"] = "Fönstret är redan krossat.",
    ["TOO_FAR_FROM_VEHICLE"] = "Du är för långt bort, gå närmare fordonet",
    ["SEARCHING_FOR_LOOT"] = "Letar efter loot...",
    ["SMASH_WINDOW"] = "Krossa fönster",
    ["SMASHNGRAB_DISPATCH"] = "En smash and grab har rapporterats",
    ["SMASHNGRAB_DISPATCH_BLIP"] = "Smash and grab",
    ["SMASHNGRAB_GOT_BAG"] = "Du hittade en väska med något i.",
    ["SMASHNGRAB_BAG_OPENED"] = "Du öppnade väskan och hittade något.",

    -- mailbox robbery

    ["MAILBOX_BROKEN"] = "Brevlådan är redan trasig.",
    ["MAILBOX_ROBBERY_SUCCESS"] = "Du lyckades bryta upp brevlådan.",
    ["MAILBOX_ROBBERY_FAIL"] = "Du misslyckades med att bryta upp brevlådan.",
    ["MAILBOX_FOUND_LETTER"] = "Du hittade ett brev.",
    ["MAILBOX_MISSING_LOCKPICK"] = "Du behöver en dyrk för att bryta upp brevlådan.",
    ["MAILBOX_ALREADY_BROKEN"] = "Brevlådan är redan trasig.",
    ["MAILBOX_LABEL"] = "Bryt upp brevlåda",
    ["MAILBOX_DISPATCH"] = "Ett brevlådeinbrott har rapporterats",
    ["MAILBOX_DISPATCH_BLIP"] = "Brevlådeinbrott",
    ["MAILBOX_STUCK"] = "Du fastnade med armen i brevlådan!",
    ["MAILBOX_STILL_STUCK"] = "Du sitter fortfarande fast... försök igen!",
    ["MAILBOX_UNSTUCK"] = "Du kom äntligen loss.",

    -- parking meter robbery

    ["PARKING_METER_BROKEN"] = "Parkeringsautomaten är redan trasig.",
    ["PARKING_METER_ROBBERY_SUCCESS"] = "Du lyckades bryta upp parkeringsautomaten.",
    ["PARKING_METER_ROBBERY_FAIL"] = "Du misslyckades med att bryta upp parkeringsautomaten.",
    ["PARKING_METER_MISSING_LOCKPICK"] = "Du behöver en dyrk för att bryta upp parkeringsautomaten.",
    ["PARKING_METER_ALREADY_BROKEN"] = "Parkeringsautomaten är redan trasig.",
    ["PARKING_METER_LABEL"] = "Bryt upp parkeringsautomat",
    ["PARKING_METER_DISPATCH"] = "Ett rån av parkeringsautomat har rapporterats",
    ["PARKING_METER_DISPATCH_BLIP"] = "Parkeringsautomat rån",

    -- parcels theft
    ["NO_PACKAGE_TOO_STEAL"] = "Det finns inget paket att stjäla.",
    ["DISARMING_BOMB"] = "Desarmerar bomb...",
    ["BOMB_DISARMED"] = "Du desarmerade bomben",
    ["STEAL_PARCEL_LABEL"] = "Stjäl paket",
    ["PARCEL_DISPATCH"] = "Någon stjäl mitt paket",
    ["PARCEL_DISPATCH_BLIP"] = "Paketstöld",
    ["PARCEL_BOMB_DISPATCH"] = "En explosion har rapporterats — möjlig paketbomb",
    ["PARCEL_BOMB_DISPATCH_BLIP"] = "Paketbombsexplosion",

    -- pickpocketing
    ["PICKPOCKET_FAIL"] = "Du misslyckades med att ficktjuva målet",
    ["PICKPOCKET_PROGRESS"] = "Ficktjuvar...",
    ["PICKPOCKET_LABEL"] = "Ficktjuva",
    ["PICKPOCKET_DISPATCH"] = "En fickstöld har rapporterats",
    ["PICKPOCKET_DISPATCH_BLIP"] = "Fickstöld",
    ["PICKPOCKET_MINIGAME_HINT"] = "Stoppa pilen i zonen",
    ["PICKPOCKET_MINIGAME_HIT"] = "Träff — fortsätt",
    ["PICKPOCKET_MINIGAME_MISS"] = "Miss",
    ["PICKPOCKET_MINIGAME_SUCCESS"] = "Fickorna tömda",
    ["PICKPOCKET_MINIGAME_CANCEL"] = "Avbruten",
    ["PICKPOCKET_MINIGAME_STOP_HINT"]    = "Stoppa pilen på föremålet du vill ha",
    ["PICKPOCKET_MINIGAME_NOTICED"]      = "Offret märkte dig",
    ["PICKPOCKET_MINIGAME_GOT"]          = "Tog %s",
    ["PICKPOCKET_MINIGAME_KEY_STOP"]     = "MELLANSLAG",
    ["PICKPOCKET_MINIGAME_KEY_CANCEL"]   = "ESC",
    ["PICKPOCKET_MINIGAME_STOP_LABEL"]   = "Stoppa",
    ["PICKPOCKET_MINIGAME_CANCEL_LABEL"] = "Avbryt",
    ["PICKPOCKET_TOO_FAR"] = "Målet rörde sig för långt bort",

    -- mugging
    ["MUGGING_DISPATCH_TITLE"] = "Rån pågår",
    ["MUGGING_DISPATCH_DESC"] = "Ett rån har rapporterats",
    ["MUGGING_DISPATCH_BLIP"] = "Rån",
    ["MUGGING_IN_PROGRESS"] = "Rånar...",
    ["MUGGING_SCARED_HINT"] = "Använd ~INPUT_PUSH_TO_TALK~ för att skrämma offret",
    ["MUGGING_SCARED_BAR"] = "Rädsla",
    ["MUGGING_RETALIATION"] = "Du får inget från mig.",

    -- match pairs minigame
    ["MATCHPAIRS_WIN"]       = "Du hittade alla par!",
    ["MATCHPAIRS_FAIL"]      = "Tiden är slut! Lycka till nästa gång.",
    ["MATCHPAIRS_CANCELLED"] = "Minispelet avbröts.",
    ["MATCHPAIRS_MEMORIZE"]  = "Memorera",
    ["MATCHPAIRS_COMPLETE"]  = "Klart",
    ["MATCHPAIRS_TIMES_UP"]  = "Tiden är slut",
    ["MATCHPAIRS_FIND_PAIRS"]= "Hitta par",

    -- vending machine robbery
    ["VENDING_LABEL"]            = "Bryt upp varuautomat",
    ["VENDING_ROBBERY_SUCCESS"]  = "Du bröt upp varuautomaten.",
    ["VENDING_ROBBERY_FAIL"]     = "Du misslyckades med att bryta upp.",
    ["VENDING_MISSING_ITEM"]     = "Du behöver ett verktyg för att bryta upp.",
    ["VENDING_ALREADY_BROKEN"]   = "Den här varuautomaten är redan uppbruten.",
    ["VENDING_DISPATCH"]         = "Ett inbrott i varuautomat har rapporterats",
    ["VENDING_DISPATCH_BLIP"]    = "Varuautomat rån",

    -- tire slashing
    ["TIRE_SLASH_LABEL"]          = "Skär sönder däck",
    ["TIRE_SLASH_NO_WEAPON"]      = "Du behöver något vasst för att göra detta",
    ["TIRE_SLASH_ALREADY_FLAT"]   = "Detta däck är redan punkterat",
    ["TIRE_SLASH_CANT_SLASH"]     = "Du kan inte skära sönder däcken på detta fordon",
    ["TIRE_SLASH_MAX_REACHED"]    = "Du har redan förstört tillräckligt många däck på detta fordon",
    ["TIRE_SLASH_VICTIM_ALERT"]   = "Någon har förstört ditt däck!",
    ["TIRE_SLASH_DISPATCH"]       = "Skadegörelse rapporterad — däck skärs sönder",
    ["TIRE_SLASH_DISPATCH_BLIP"]  = "Däckskadegörelse",

    -- pedal brick
    ["PEDAL_BRICK_LABEL"]          = "Placera tegel på pedal",
    ["PEDAL_BRICK_READY"]          = "Tegel redo — gå fram till ett fordon för att placera den",
    ["PEDAL_BRICK_EXPIRED"]        = "Du tog för lång tid, teglet är inte längre redo",
    ["PEDAL_BRICK_PLACING"]        = "Placerar tegel på gaspedalen...",
    ["PEDAL_BRICK_PLACED"]         = "Tegel placerat — fordonet är på väg att köra iväg",
    ["PEDAL_BRICK_NO_ITEM"]        = "Du har inget tegel",
    ["PEDAL_BRICK_CANT_USE"]       = "Du kan inte använda tegel på detta fordon",
    ["PEDAL_BRICK_LOCKED"]         = "Fordonet är låst",
    ["PEDAL_BRICK_ALREADY"]        = "Det finns redan ett tegel på pedalen",
    ["PEDAL_BRICK_OCCUPIED"]       = "Någon sitter i förarsätet",
    ["PEDAL_BRICK_DISPATCH"]       = "Fordon manipuleras — tegel på gaspedal",
    ["PEDAL_BRICK_DISPATCH_BLIP"]  = "Fordonsmanipulation",
    ["PEDAL_BRICK_FIRE_DISPATCH"]      = "Ett fordon brinner efter en kollision — misstänkt manipulation",
    ["PEDAL_BRICK_FIRE_DISPATCH_BLIP"] = "Fordonsbrand",

    -- ATM robbery
    ["ATM_ROBBERY_ATTACH_LABEL"]     = "Fäst hackningsenhet",
    ["ATM_ROBBERY_REMOVE_LABEL"]     = "Ta bort hackningsenhet",
    ["ATM_ROBBERY_DRAIN_LABEL"]      = "Töm bankomat",
    ["ATM_ROBBERY_NO_ITEM"]          = "Du behöver en hackningsenhet",
    ["ATM_ROBBERY_COOLDOWN"]         = "Den här bankomaten har nyligen rånats",
    ["ATM_ROBBERY_ALREADY_HACKED"]   = "Det finns redan en enhet på denna bankomat",
    ["ATM_ROBBERY_ATTACHING"]        = "Fäster hackningsenhet...",
    ["ATM_ROBBERY_DEVICE_ATTACHED"]  = "Enheten är fäst på bankomaten",
    ["ATM_ROBBERY_DEVICE_REMOVED"]   = "Enheten togs bort från bankomaten",
    ["ATM_ROBBERY_HACK_LABEL"]       = "[E] Hacka transaktion",
    ["ATM_ROBBERY_WAITING_PED"]      = "Väntar på att någon ska använda bankomaten...",
    ["ATM_ROBBERY_SUCCESS"]          = "Bankomat hackad",
    ["ATM_ROBBERY_FAIL"]             = "Hackning misslyckades",
    ["ATM_ROBBERY_DRAINING"]         = "Tömmer pengar från bankomaten...",
    ["ATM_ROBBERY_DRAINED"]          = "Bankomat tömd — $%s insamlat",
    ["ATM_ROBBERY_POOL_ADDED"]       = "Skimmade $%s från transaktion (Pool: $%s)",
    ["ATM_ROBBERY_POOL_EMPTY"]       = "Inget att tömma ännu — hacka några transaktioner först",
    ["ATM_ROBBERY_COLLECT_LABEL"]    = "[E] Plocka upp pengar",
    ["ATM_ROBBERY_COLLECTING"]       = "Samlar in pengar...",
    ["ATM_ROBBERY_MAX_PEDS"]         = "Bankomaten är tömd — töm eller ta bort enheten",
    ["ATM_ROBBERY_TOO_FAR"]          = "För långt från bankomaten för att hacka",
    ["ATM_ROBBERY_ITEM_BROKE"]       = "Din hackningsenhet gick sönder",
    ["ATM_ROBBERY_PED_ANGRY"]        = "Personen blev arg och gick därifrån",
    ["ATM_ROBBERY_DISPATCH"]         = "Ett bankomatrån har rapporterats",
    ["ATM_ROBBERY_DISPATCH_BLIP"]    = "Bankomatrån",

    -- cash register robbery
    ["CASH_REGISTER_LABEL"]            = "Dyrka kassa",
    ["CASH_REGISTER_BROKEN"]           = "Den här kassan är redan trasig.",
    ["CASH_REGISTER_SUCCESS"]          = "Du lyckades öppna kassan.",
    ["CASH_REGISTER_FAIL"]             = "Du misslyckades med att dyrka låset.",
    ["CASH_REGISTER_MISSING_LOCKPICK"] = "Du behöver en dyrk för detta.",
    ["CASH_REGISTER_ALREADY_BROKEN"]   = "Den här kassan har redan rånats.",
    ["CASH_REGISTER_DISPATCH"]         = "Ett kassaskåpsrån har rapporterats",
    ["CASH_REGISTER_DISPATCH_BLIP"]    = "Kassaskåpsrån",

    -- store shelves
    ["STORE_SHELVES_LABEL"]            = "Sök hyllor",
    ["STORE_SHELVES_SUCCESS"]          = "Du hittade några föremål.",
    ["STORE_SHELVES_EMPTY"]            = "Dessa hyllor är tomma.",
    ["STORE_SHELVES_DISPATCH"]         = "Butiksstöld",
    ["STORE_SHELVES_DISPATCH_BLIP"]    = "Snatteri",

    --global
    ["NOT_ENOUGH_POLICE"] = "Inte tillräckligt med poliser online",
    ["GIVE_MONEY"] = "Du fick %s$",
    ["NOTHING_FOUND"] = "Hittade inget",
    ["ITEM_FOUND"] = "Du hittade %sx %s",
    ["LOCKPICK_BROKE"] = "Din dyrk gick sönder",
    ["LOCKPICK_MINIGAME_CLICK"]  = "KLICKA",
    ["LOCKPICK_MINIGAME_KEY"]    = "E",
    ["LOCKPICK_MINIGAME_TO_OPEN"]= "FÖR ATT ÖPPNA LÅSET",
    ["LOCKPICK_MINIGAME_FAILED"] = "DYRKNING MISSLYCKADES",
    ["LOCKPICK_MINIGAME_OPENED"] = "LÅSET ÖPPNAT",
    ["BLEEDING"] = "Du skadade dig",
    ["CANT_DO_ACTION"] = "Du kan inte göra detta just nu",
}
