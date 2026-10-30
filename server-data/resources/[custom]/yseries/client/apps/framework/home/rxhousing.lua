CreateThread(function()
    if Config.Housing ~= 'RxHousing' then return end

    debugPrint("Using RxHousing")

    function MapHomes(homes)
        return homes
    end

    function MapKeyHolders(keys)
        return keys
    end
end)
