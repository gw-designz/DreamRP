openMenuDrawText = false
nuiLoaded = false
local vehicleBasket = {}
playerVeh = nil
oldDataVehicle = false
local vehicleModifyCompleted = false
key = false
lastMenuLabel = false
freecam = false

function NuiMessage(action, payload)
  while not nuiLoaded do
    Wait(0)
  end
  SendNUIMessage({ action = action, payload = payload })
end

CreateThread(function()
  while not nuiLoaded do
    if NetworkIsSessionStarted() then
      SendNUIMessage({ action = "CHECK_NUI" })
    end
    Wait(2000)
  end
end)

RegisterNUICallback("loaded", function(data, cb)
  nuiLoaded = true
  NuiMessage("SET_LOCALES", Config.Locales)
  NuiMessage("SET_MODIFYCASH", Config.ModifyWithYourCash)
  NuiMessage("SET_NPC_MISSIONS", Config.EnableNPCMissions)
  cb("ok")
end)

Citizen.CreateThread(function()
  Config.OpenTrigger()

  while not nuiLoaded do
    Citizen.Wait(50)
  end

  NuiMessage("configDefaulPrice", Config.MechanicUpgradeDefaultPrice)
  NuiMessage("configMechanicSettings", Config.MechanicCategoriesSettings)
  NuiMessage("configCategoryLocked", Config.CategoryLocked)
  NuiMessage("configMechanicThema", Config.MechanicThema)
  NuiMessage("configEnableNPCMissions", Config.EnableNPCMissions)

  local serverKey = TriggerCallback("codem-mechanic:getKey")
  key = serverKey or false

  local mechanicMode = Config.MechanicMode
  if mechanicMode == "no_job" then
    if Config.InteractionHandler == "ox-target" then
      for _, mechanicData in pairs(Config.MechanicSettings) do
        for _, coords in pairs(mechanicData.bossMenuCoords) do
          TriggerEvent("codem-mechanic:AddZone", coords, "mechanic-boss", {
            {
              name = "mechanic-boss",
              event = "codem-mechanic:OpenBossMenu",
              icon = "fa-solid fa-bars-progress",
              label = Config.Locales.OPEN_BOSS_MENU,
            }
          })
        end
        for _, coords in pairs(mechanicData.mechanicMenuCoords) do
          TriggerEvent("codem-mechanic:AddZone", coords, "mechanic-tuning-menu", {
            {
              name = "mechanic-boss",
              event = "codem-mechanic:OpenMechanicMenu",
              icon = "fas fa-gears",
              label = Config.Locales.OPEN_MECHANIC_MENU,
            }
          })
        end
      end
    end

    if Config.InteractionHandler == "qb-target" then
      for _, mechanicData in pairs(Config.MechanicSettings) do
        for _, coords in pairs(mechanicData.bossMenuCoords) do
          TriggerEvent("codem-mechanic:AddZone", coords, mechanicData)
        end
        for _, coords in pairs(mechanicData.mechanicMenuCoords) do
          TriggerEvent("codem-mechanic:AddZoneMechanic", coords, mechanicData)
        end
      end
    end
  end
end)

RegisterNetEvent("codem-mechanic:OpenBossMenu")
AddEventHandler("codem-mechanic:OpenBossMenu", function()
  local mechanicData = Config.MechanicSettings[job]
  if mechanicData then
    openMenu("boss", mechanicData.label)
  end
end)

RegisterNetEvent("codem-mechanic:OpenMechanicMenu")
AddEventHandler("codem-mechanic:OpenMechanicMenu", function()
  local mechanicData = Config.MechanicSettings[job]
  local mechanicMode = Config.MechanicMode

  if mechanicMode ~= "no_job" then
    local nearestJob, nearestDist = getNearestMechanic()
    if not CheckCanUseMechanic(nearestJob, nearestDist) then
      goto skipMenu
    end
  end

  do
    local nearestJob = getNearestMechanic()
    if nearestJob then
      mechanicData = Config.MechanicSettings[nearestJob]
    end
  end

  ::skipMenu::
  if mechanicData then
    openMenu("mechanic", mechanicData.label)
  end
end)

RegisterNetEvent("codem-mechanic:OpenMechanicJobMenu")
AddEventHandler("codem-mechanic:OpenMechanicJobMenu", function()
  local mechanicData = Config.MechanicSettings[job]
  if mechanicData then
    openMenu("jobmenu", mechanicData.label)
  end
end)

Citizen.CreateThread(function()
  if Config.EnableRegisterKeyMapping then
    RegisterCommand("mechanicmenu", function()
      local mechanicData = Config.MechanicSettings[job]
      if mechanicData and nuiLoaded then
        openMenu("jobmenu", mechanicData.label)
      end
    end)
    RegisterKeyMapping("mechanicmenu", "Mechanic Menu", "keyboard", Config.EnableRegisterKeyMappingKey)
  else
    CreateThread(function()
      while true do
        local mechanicData = Config.MechanicSettings[job]
        local waitTime = 2000

        if mechanicData then
          waitTime = 2
          if IsControlJustPressed(0, Config.JobMenuKey) then
            openMenu("jobmenu", mechanicData.label)
          end
        end

        Citizen.Wait(waitTime)
      end
    end)
  end
end)

function openMenu(menuType, mechanicLabel)
  while Core == nil do
    Wait(0)
  end

  if menuType == "mechanic" then
    local driverPed = GetPedInVehicleSeat(GetVehiclePedIsIn(PlayerPedId(), false), -1)
    if driverPed ~= PlayerPedId() then
      return
    end

    lastMenuLabel = mechanicLabel
    local ped = PlayerPedId()
    playerVeh = GetVehiclePedIsIn(ped, false)

    local vehicleDisplayName = GetDisplayNameFromVehicleModel(GetEntityModel(playerVeh))
    local vehicleNameLower = vehicleDisplayName:lower()

    if Config.BlaclistVehicle[vehicleNameLower] then
      playerVeh = nil
      return TriggerEvent("codem-mechanic:notification", Config.Locales.CANT_MODIFY)
    end

    CreateCamVehicle()
    SetNuiFocus(true, true)
    openMenuDrawText = true

    if not oldDataVehicle then
      oldDataVehicle = GetVehicleProperties(playerVeh)
    end

    local profileAccount = TriggerCallback("codem-mechanic:getAccount")
    local vaultMoney = TriggerCallback("codem-mechanic:getMechanicVault")

    local mechanicData = Config.MechanicSettings[job]
    local mechanicMode = Config.MechanicMode
    local canUseMechanic
    if mechanicMode ~= "no_job" then
      local nearestJob, nearestDist, nearestExtra = getNearestMechanic()
      canUseMechanic = CheckCanUseMechanic(nearestJob, nearestDist, nearestExtra)
    end

    if canUseMechanic and not mechanicData then
      vaultMoney = profileAccount.cash
    end

    if Config.ModifyWithYourCash then
      local playerMoney = TriggerCallback("codem-mechanic:getPlayerAccount")
      vaultMoney = playerMoney
    end

    NuiMessage("openmenu", {
      menu = menuType,
      profileAccount = profileAccount,
      vault = vaultMoney,
      mechanicLabel = mechanicLabel,
    })

    Citizen.Wait(500)

    if mechanicMode ~= "no_job" then
      local nearestJob, nearestDist, nearestExtra = getNearestMechanic()
      canUseMechanic = CheckCanUseMechanic(nearestJob, nearestDist, nearestExtra)
      if not canUseMechanic then
        goto afterBillHide
      end
    end
    NuiMessage("hidebillplayer")
    ::afterBillHide::

    updateVehicleCard()
    changeCamera("mainCam")
    NuiMessage("updateVehicleBasket", vehicleBasket)
    hideMenuOpen()
    TriggerServerEvent("codem-mechanic:server:StartModity", NetworkGetNetworkIdFromEntity(playerVeh), oldDataVehicle)
  elseif menuType == "boss" then
    if CheckPermission("accessBossMenu") then
      local profileAccount = TriggerCallback("codem-mechanic:getAccount")
      SetNuiFocus(true, true)
      NuiMessage("openmenu", {
        menu = menuType,
        profileAccount = profileAccount,
        mechanicLabel = mechanicLabel,
      })
      NuiMessage("SET_ITEM_IMAGES_FOLDER", Config.ItemImagesFolder)
      bossMenuOpen = true

      local inventory = TriggerCallback("codem-mechanic:GetPlayerInventory")
      NuiMessage("SetInventory", inventory)
      SetMyRank()
      TriggerEvent("codem-mechanic:RefreshBossMoney")
      hideMenuOpen()
    end
  elseif menuType == "jobmenu" then
    SetNuiFocus(true, true)
    NuiMessage("openmenu", { menu = menuType })
  end
end

RegisterNetEvent("codem-mechanic:notification", function(message)
  if message then
    NuiMessage("SET_NOTIFICATION", message)
  end
end)

RegisterNetEvent("codem-mechanic:RefreshMechanicVault", function(amount)
  NuiMessage("RefreshMechanicVault", amount)
end)

RegisterNUICallback("vehicleMechanicComplete", function(data)
  local totalPrice = tonumber(data)

  local vaultMoney = TriggerCallback("codem-mechanic:getMechanicVault")
  local profileAccount = TriggerCallback("codem-mechanic:getAccount")

  if Config.MechanicMode ~= "no_job" then
    local nearestJob, nearestDist = getNearestMechanic()
    if not CheckCanUseMechanic(nearestJob, nearestDist) then
      goto skipFallback
    end
  end

  do
    local mechanicData = Config.MechanicSettings[job]
    if not mechanicData then
      vaultMoney = profileAccount.cash
    end
  end

  ::skipFallback::
  if Config.ModifyWithYourCash then
    local playerMoney = TriggerCallback("codem-mechanic:getPlayerAccount")
    vaultMoney = playerMoney
  end

  if tonumber(vaultMoney) < tonumber(totalPrice) then
    TriggerEvent("codem-mechanic:notification", Config.Locales.NOT_ENOUGH_MONEY_CASH)
    return
  end

  TriggerServerEvent("codem-mechanic:vehicleMechanicComplete", totalPrice)
  vehicleModifyCompleted = true
end)

RegisterNetEvent("codem-mechanic:completeVehicle", function()
  vehicleBasket = {}
  NuiMessage("updateVehicleBasket", vehicleBasket)
end)

RegisterNUICallback("showNearbyPlayerBill", function(data)
  if data then
    TriggerServerEvent("codem-mechanic:showOtherBill", data)
  end
end)

RegisterNetEvent("codem-mechanic:sendShowBill", function(data)
  if data then
    SetNuiFocus(true, true)
    NuiMessage("showBill", data)
  end
end)

RegisterNUICallback("closeOtherSummuryBill", function()
  SetNuiFocus(false, false)
end)

RegisterNUICallback("clearVehicleColor", function()
  if playerVeh ~= 0 and DoesEntityExist(playerVeh) then
    ClearVehicleCustomPrimaryColour(playerVeh)
    ClearVehicleCustomSecondaryColour(playerVeh)
  end
end)

-- Helper to find or insert a basket item by modId and update the basket
function FindBasketItemByModId(modId)
  for i, item in ipairs(vehicleBasket) do
    if item.modId == modId or tonumber(item.modId) == modId then
      return i, item
    end
  end
  return nil, nil
end

function AddOrUpdateBasketItem(modId, priceConfigId, priceIndex, labelOverride)
  local found = false
  for _, item in ipairs(vehicleBasket) do
    if item.modId == modId or tonumber(item.modId) == modId then
      found = true
      break
    end
  end

  if not found then
    local priceConfig = Config.MechanicUpgradeDefaultPrice[priceConfigId]
    local price, label
    if priceIndex then
      price = priceConfig.count[priceIndex].price
      label = labelOverride or priceConfig.count[priceIndex].label
    else
      price = priceConfig.price
      label = labelOverride or priceConfig.label
    end
    table.insert(vehicleBasket, {
      modId = modId,
      price = price,
      index = "",
      label = label,
    })
  end

  NuiMessage("updateVehicleBasket", vehicleBasket)
end

RegisterNUICallback("setVehicleColor", function(data)
  SetVehicleModKit(playerVeh, 0)
  local pearlescent, wheelColor = GetVehicleExtraColours(playerVeh)
  local colorType = data.modname

  if colorType == "allcolor" then
    ClearVehicleCustomPrimaryColour(playerVeh)
    ClearVehicleCustomSecondaryColour(playerVeh)
    SetVehicleColours(playerVeh, data.color, data.color)
    AddOrUpdateBasketItem("allcolor", 992, 2)
  elseif colorType == "primarycolor" then
    local r, g, b = data.color[1], data.color[2], data.color[3]
    SetVehicleCustomPrimaryColour(playerVeh, r, g, b)
    AddOrUpdateBasketItem("primarycolor", 992, 3)
  elseif colorType == "secondarycolor" then
    local r, g, b = data.color[1], data.color[2], data.color[3]
    SetVehicleCustomSecondaryColour(playerVeh, r, g, b)
    AddOrUpdateBasketItem("secondarycolor", 992, 4)
  elseif colorType == "extracolor" then
    local currentPearlescent, _ = GetVehicleExtraColours(playerVeh)
    SetVehicleExtraColours(playerVeh, currentPearlescent, data.color)
    AddOrUpdateBasketItem("extracolor", 992, 5)
  elseif colorType == "pearlescentcolor" then
    local _, currentWheelColor = GetVehicleExtraColours(playerVeh)
    SetVehicleExtraColours(playerVeh, data.color, currentWheelColor)
    AddOrUpdateBasketItem("extracolor", 992, 5)
  elseif colorType == "tiresmoke" then
    local r, g, b = data.color[1], data.color[2], data.color[3]
    ToggleVehicleMod(playerVeh, 20, true)
    SetVehicleTyreSmokeColor(playerVeh, r, g, b)

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    SetVehicleBurnout(vehicle, true)
    TaskVehicleTempAction(ped, vehicle, 23, 5000)
    AddOrUpdateBasketItem("tiresmoke", 992, 6)
  elseif colorType == "xenoncolor" then
    SetVehicleHeadlightsColour(playerVeh, data.color)
  elseif colorType == "allsidesneon" then
    local r, g, b = data.color[1], data.color[2], data.color[3]
    SetVehicleNeonLightsColour(playerVeh, r, g, b)
    NuiMessage("updateStockNumber", { modId = 996, stock = 1 })
    AddOrUpdateBasketItem(996, 996, nil)
  end
end)

RegisterNetEvent("codem-mechanic:client:ForceDefaultVehicle", function(netId, vehicleData)
  local vehicle = NetworkGetEntityFromNetworkId(netId)
  SetVehicleProperties(vehicle, vehicleData)
  SetVehicleLights(vehicle, 0)
  FreezeEntityPosition(vehicle, false)
  SetVehicleBurnout(vehicle, false)

  for doorIndex = 0, 7 do
    if GetVehicleDoorAngleRatio(vehicle, doorIndex) > 0 then
      SetVehicleDoorShut(vehicle, doorIndex, false)
    end
  end
end)

RegisterNUICallback("hornVehicle", function()
  StartVehicleHorn(playerVeh, 5000, 0, false)
end)

RegisterNUICallback("stockNeon", function()
  SetVehicleNeonLightsColour(playerVeh, 255, 255, 255)
end)

table.contains = function(tbl, value)
  for _, v in pairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

RegisterNUICallback("deleteVehicleBasket", function(data)
  local nonRemovableIds = {
    "allcolor", "primarycolor", "secondarycolor", "extracolor", "tiresmoke", "xenoncolor",
    "sport", "muscle", "lowrider", "stock", "suv", "offroad", "tuner", "bike", "highend",
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
  }

  if table.contains(nonRemovableIds, data.modId) then
    return TriggerEvent("codem-mechanic:notification", Config.Locales.CANT_REMOVE)
  end

  local currentMod = GetVehicleMod(playerVeh, tonumber(data.modId))
  local modConfig = Config.MechanicUpgradeDefaultPrice[tonumber(data.modId)]
  local modName = modConfig.modName

  if not modName then
    TriggerEvent("codem-mechanic:notification", Config.Locales.MOD_NAME_NIL)
    NuiMessage("resultValue")
    return
  end

  local modIdNum = tonumber(data.modId)

  -- Handle turbo (mod 18)
  if modIdNum == 18 then
    ToggleVehicleMod(playerVeh, 18, false)
    local turboState = IsToggleModOn(playerVeh, 18)
    if turboState == false then turboState = 0 end

    for i, item in ipairs(vehicleBasket) do
      if tonumber(item.modId) == data.modId then
        table.remove(vehicleBasket, i)
        break
      end
    end
    NuiMessage("updateVehicleBasket", vehicleBasket)
    NuiMessage("updateStockNumberDelete", { modId = data.modId, stock = turboState })
    return
  end

  -- Handle livery (mod 48)
  if modIdNum == 48 then
    local liveryCount = GetVehicleLiveryCount(playerVeh)
    SetVehicleModKit(playerVeh, 0)

    if liveryCount == -1 then
      if oldDataVehicle.modLivery ~= nil then
        SetVehicleLivery(playerVeh, tonumber(oldDataVehicle.modLivery))
        SetVehicleMod(playerVeh, 48, tonumber(oldDataVehicle.modLivery))
      else
        SetVehicleMod(playerVeh, 48, tonumber(-1))
        SetVehicleLivery(playerVeh, -1)
      end
    else
      if oldDataVehicle.modLivery ~= nil then
        SetVehicleLivery(playerVeh, tonumber(oldDataVehicle.modLivery))
      else
        SetVehicleLivery(playerVeh, tonumber(0))
      end
    end

    for i, item in ipairs(vehicleBasket) do
      if tonumber(item.modId) == data.modId then
        table.remove(vehicleBasket, i)
        break
      end
    end
    NuiMessage("updateVehicleBasket", vehicleBasket)
    NuiMessage("updateStockNumberDelete", { modId = data.modId, stock = 0 })
    return
  end

  -- Handle neon (mod 996)
  if modIdNum == 996 then
    for i, item in ipairs(vehicleBasket) do
      if tonumber(item.modId) == data.modId then
        table.remove(vehicleBasket, i)
        break
      end
    end
    NuiMessage("updateVehicleBasket", vehicleBasket)
    SetVehicleNeonLightsColour(playerVeh, 255, 255, 255)
    return
  end

  -- Handle regular mods
  local foundInOldData = false
  for propName, _ in pairs(oldDataVehicle) do
    if propName == modName then
      foundInOldData = true
      SetVehicleMod(playerVeh, tonumber(data.modId), -1)
      break
    end
  end

  if foundInOldData then
    for i, item in ipairs(vehicleBasket) do
      if tonumber(item.modId) == data.modId then
        table.remove(vehicleBasket, i)
        break
      end
    end
    NuiMessage("updateVehicleBasket", vehicleBasket)
    local currentStock = GetVehicleMod(playerVeh, tonumber(data.modId))
    NuiMessage("updateStockNumberDelete", { modId = data.modId, stock = currentStock })
  end
end)

RegisterNUICallback("selectMechanicCategoryItem", function(modId)
  if playerVeh ~= 0 and DoesEntityExist(playerVeh) then
    local modConfig = Config.MechanicUpgradeDefaultPrice[tonumber(modId)]
    local modName = modConfig.modName

    if modName == nil then
      TriggerEvent("codem-mechanic:notification", Config.Locales.MOD_NAME_NIL)
      NuiMessage("resultValue")
      return
    end

    local vehicleClass = getFindVehicle(playerVeh)
    local modPrice = modConfig.price or 258258
    local currentMod = GetVehicleMod(playerVeh, tonumber(modId))
    local classModifier = Config.ClassModifier[vehicleClass] or "C"
    local isFixedPrice = modConfig.isFixedPrice

    SetVehicleModKit(playerVeh, 0)

    local camName = modConfig.camName
    local vehicleDisplayName = GetDisplayNameFromVehicleModel(GetEntityModel(playerVeh))
    local vehicleNameLower = vehicleDisplayName:lower()

    -- Motorcycle check
    if vehicleClass == "M" then
      changeCamera("mainCam")
      local modCount = GetNumVehicleMods(playerVeh, tonumber(modId))
      NuiMessage("mechanicCategoryResult", {
        modCount = modCount,
        modId = tonumber(modId),
        stock = currentMod,
        price = modPrice,
        classPrice = classModifier,
        isFixedPrice = isFixedPrice,
      })
      return
    end

    -- Engine hood at rear check
    local isRearEngine = Config.EngineHoodatTheRearModel[vehicleNameLower]
    if isRearEngine then
      local rearDoorAngle = GetVehicleDoorAngleRatio(playerVeh, 4)
      if modId == 11 or modId == 13 or modId == 18 or modId == 39 or modId == 40 or modId == 41 then
        changeCamera("rearCam")
        if rearDoorAngle < 0.5 then
          SetVehicleDoorOpen(playerVeh, 4, false)
        end
      else
        if camName then
          changeCamera(camName)
        end
        if rearDoorAngle > 0 then
          SetVehicleDoorShut(playerVeh, 4, false)
        end
      end
    else
      if camName then
        changeCamera(camName)
      end

      local hoodAngle = GetVehicleDoorAngleRatio(playerVeh, 4)
      if modId == 11 or modId == 13 or modId == 18 or modId == 39 or modId == 40 or modId == 41 then
        if hoodAngle < 0.5 then
          SetVehicleDoorOpen(playerVeh, 4, false)
        end
      elseif hoodAngle > 0 then
        SetVehicleDoorShut(playerVeh, 4, false)
      end

      local trunkAngle = GetVehicleDoorAngleRatio(playerVeh, 1)
      if modId == 31 then
        if trunkAngle < 0.5 then
          SetVehicleDoorOpen(playerVeh, 1, false, false)
        end
      elseif trunkAngle > 0 then
        SetVehicleDoorShut(playerVeh, 1, false)
      end
    end

    -- Handle livery (mod 48) specially
    local modIdNum = tonumber(modId)
    if modIdNum == 48 then
      local liveryCount = GetVehicleLiveryCount(playerVeh)
      if liveryCount == -1 then
        local numMods = GetNumVehicleMods(playerVeh, 48)
        if numMods and numMods > 0 then
          NuiMessage("mechanicCategoryResult", {
            modCount = tonumber(GetNumVehicleMods(playerVeh, 48)),
            modId = tonumber(modId),
            stock = currentMod,
            price = modPrice,
            classPrice = classModifier,
            isFixedPrice = isFixedPrice,
          })
          GetVehicleMod(playerVeh, 48)
          return
        end
      else
        modCount = liveryCount
        local currentLivery = GetVehicleLivery(playerVeh) or 0
        if not GetVehicleLivery(playerVeh) then
          currentLivery = 0
        end
        NuiMessage("mechanicCategoryResult", {
          modCount = modCount,
          modId = tonumber(modId),
          stock = currentMod,
          price = modPrice,
          classPrice = classModifier,
          isFixedPrice = isFixedPrice,
        })
        NuiMessage("updateStockNumber", { modId = 48, stock = tonumber(currentLivery) })
        return
      end
    end

    -- Default: get mod count for this category
    local modCount = GetNumVehicleMods(playerVeh, tonumber(modId))
    NuiMessage("mechanicCategoryResult", {
      modCount = modCount,
      modId = tonumber(modId),
      stock = currentMod,
      price = modPrice,
      classPrice = classModifier,
      isFixedPrice = isFixedPrice,
    })
  end
end)

RegisterNUICallback("changeVehicleWindowTint", function(data)
  if playerVeh ~= 0 and DoesEntityExist(playerVeh) then
    SetVehicleModKit(playerVeh, 0)
    SetVehicleWindowTint(playerVeh, data.index)

    local found = false
    for _, item in ipairs(vehicleBasket) do
      if tonumber(item.modId) == 994 then
        found = true
        break
      end
    end

    if not found then
      table.insert(vehicleBasket, {
        modId = 994,
        price = Config.MechanicUpgradeDefaultPrice[994].price,
        index = data.index,
        label = Config.MechanicUpgradeDefaultPrice[994].label,
      })
    end

    local currentTint = GetVehicleWindowTint(playerVeh)
    NuiMessage("updateStockNumber", { modId = 994, stock = currentTint })
    NuiMessage("updateVehicleBasket", vehicleBasket)
  end
end)

RegisterNUICallback("changeVehicleCamera", function(modId)
  local camName = Config.MechanicUpgradeDefaultPrice[tonumber(modId)].camName
  if camName then
    local vehicleClass = getFindVehicle(playerVeh)
    if vehicleClass == "M" then
      changeCamera("mainCam")
      return
    end

    if modId == 11 or modId == 13 or modId == 18 or modId == 39 or modId == 40 or modId == 41 then
      local vehicleDisplayName = GetDisplayNameFromVehicleModel(GetEntityModel(playerVeh))
      local vehicleNameLower = vehicleDisplayName:lower()
      local isRearEngine = Config.EngineHoodatTheRearModel[vehicleNameLower]
      if not isRearEngine then
        changeCamera(camName)
      end
    else
      changeCamera(camName)
    end
  end
end)

RegisterNUICallback("turboOpen", function()
  local hoodAngle = GetVehicleDoorAngleRatio(playerVeh, 4)
  if hoodAngle < 0.5 then
    SetVehicleDoorOpen(playerVeh, 4, false, false)
  end

  local turboState = IsToggleModOn(playerVeh, 18)
  if turboState == false then turboState = 0 end

  NuiMessage("updateStockNumber", { modId = 18, stock = turboState })
end)

RegisterNUICallback("xenonOpen", function()
  SetVehicleModKit(playerVeh, 0)
  local xenonState = IsToggleModOn(playerVeh, 22)
  if xenonState == false then xenonState = 0 end

  NuiMessage("updateStockNumber", { modId = 997, stock = xenonState })
end)

RegisterNUICallback("changeVehicleXenon", function(data)
  if playerVeh ~= 0 and DoesEntityExist(playerVeh) then
    SetVehicleModKit(playerVeh, 0)
    SetVehicleLights(playerVeh, 2)

    local selectedIndex = tonumber(data.index)

    if selectedIndex == 0 then
      -- Turn off xenon
      ToggleVehicleMod(playerVeh, 22, false)

      -- Remove existing xenon basket item
      for i, item in ipairs(vehicleBasket) do
        if tonumber(item.modId) == 997 then
          table.remove(vehicleBasket, i)
          break
        end
      end

      -- Add "off" price basket entry
      local found = false
      for _, item in ipairs(vehicleBasket) do
        if tonumber(item.modId) == 997 then
          found = true
          break
        end
      end
      if not found then
        table.insert(vehicleBasket, {
          modId = 997,
          price = Config.MechanicUpgradeDefaultPrice[997].count[1].price,
          index = "",
          label = Config.MechanicUpgradeDefaultPrice[997].label,
        })
      end
    else
      -- Turn on xenon
      ToggleVehicleMod(playerVeh, 22, true)

      -- Remove existing xenon basket item
      for i, item in ipairs(vehicleBasket) do
        if tonumber(item.modId) == 997 then
          table.remove(vehicleBasket, i)
          break
        end
      end

      -- Add "on" price basket entry
      local found = false
      for _, item in ipairs(vehicleBasket) do
        if tonumber(item.modId) == 997 then
          found = true
          break
        end
      end
      if not found then
        table.insert(vehicleBasket, {
          modId = 997,
          price = Config.MechanicUpgradeDefaultPrice[997].count[2].price,
          index = "",
          label = Config.MechanicUpgradeDefaultPrice[997].label,
        })
      end
    end

    local xenonState = IsToggleModOn(playerVeh, 22)
    if xenonState == false then xenonState = 0 end

    NuiMessage("updateStockNumber", { modId = 997, stock = xenonState })
    NuiMessage("updateVehicleBasket", vehicleBasket)
  end
end)

RegisterNUICallback("changeVehicleTurbo", function(data)
  if playerVeh ~= 0 and DoesEntityExist(playerVeh) then
    SetVehicleModKit(playerVeh, 0)
    local selectedIndex = tonumber(data.index)

    if selectedIndex == 0 then
      -- Turn off turbo
      ToggleVehicleMod(playerVeh, 18, false)
      for i, item in ipairs(vehicleBasket) do
        if tonumber(item.modId) == 18 then
          table.remove(vehicleBasket, i)
          break
        end
      end
    else
      -- Turn on turbo
      ToggleVehicleMod(playerVeh, 18, true)

      local found = false
      for _, item in ipairs(vehicleBasket) do
        if tonumber(item.modId) == 18 then
          found = true
          break
        end
      end
      if not found then
        table.insert(vehicleBasket, {
          modId = 18,
          price = Config.MechanicUpgradeDefaultPrice[18].count[2].price,
          index = "",
          label = Config.MechanicUpgradeDefaultPrice[18].label,
        })
      end
    end

    updateVehicleCard()
    local turboState = IsToggleModOn(playerVeh, 18)
    NuiMessage("updateStockNumber", { modId = 18, stock = turboState })
    NuiMessage("updateVehicleBasket", vehicleBasket)
  end
end)

RegisterNUICallback("changeVehiclePlayer", function(data)
  if playerVeh ~= 0 and DoesEntityExist(playerVeh) then
    local found = false
    for _, item in ipairs(vehicleBasket) do
      if tonumber(item.modId) == 993 then
        found = true
        break
      end
    end

    if not found then
      table.insert(vehicleBasket, {
        modId = 993,
        price = Config.MechanicUpgradeDefaultPrice[993].price,
        index = data.index,
        label = Config.MechanicUpgradeDefaultPrice[993].label,
      })
    end

    SetVehicleNumberPlateTextIndex(playerVeh, data.index)
    local currentPlateIndex = GetVehicleNumberPlateTextIndex(playerVeh)
    NuiMessage("updateStockNumber", { modId = 993, stock = currentPlateIndex })
    NuiMessage("updateVehicleBasket", vehicleBasket)
  end
end)

function ArrayContains(arr, value)
  for i = 1, #arr do
    if arr[i] == value then
      return true
    end
  end
  return false
end

RegisterNUICallback("repairVehicle", function()
  repairVehicle(playerVeh)
end)

RegisterNUICallback("cleanVehicle", function()
  cleanVehicle(playerVeh)
end)

RegisterNUICallback("changeVehicleModification", function(data)
  if playerVeh ~= 0 and DoesEntityExist(playerVeh) then
    local currentMod = GetVehicleMod(playerVeh, data.modId)

    if currentMod == data.index then
      -- Same mod selected = remove it
      SetVehicleMod(playerVeh, data.modId, -1)
      for i, item in ipairs(vehicleBasket) do
        if tonumber(item.modId) == tonumber(data.modId) then
          table.remove(vehicleBasket, i)
          break
        end
      end
    else
      -- Different mod selected = apply it
      SetVehicleMod(playerVeh, data.modId, data.index)

      local found = false
      for _, item in ipairs(vehicleBasket) do
        if tonumber(item.modId) == tonumber(data.modId) then
          item.price = data.price
          item.index = data.index
          item.label = Config.MechanicUpgradeDefaultPrice[tonumber(data.modId)].label
          found = true
          break
        end
      end

      if not found then
        table.insert(vehicleBasket, {
          modId = data.modId,
          price = data.price,
          index = data.index,
          label = Config.MechanicUpgradeDefaultPrice[tonumber(data.modId)].label,
        })
      end
    end

    -- Update vehicle card for performance mods
    local performanceMods = { 11, 13, 12, 15, 16, 18 }
    if ArrayContains(performanceMods, data.modId) then
      updateVehicleCard()
    end

    local vehicleProps = GetVehicleProperties(playerVeh)
    local modConfig = Config.MechanicUpgradeDefaultPrice[tonumber(data.modId)]
    local currentValue = vehicleProps[modConfig.modName]

    NuiMessage("updateStockNumber", { modId = data.modId, stock = currentValue })
    NuiMessage("updateVehicleBasket", vehicleBasket)
  end
end)

RegisterNUICallback("selectVehicleWheel", function(data)
  SetVehicleModKit(playerVeh, 0)

  local wheelTypeMap = {
    sport = 0,
    muscle = 1,
    lowrider = 2,
    stock = 0,
    suv = 3,
    offroad = 4,
    tuner = 5,
    bike = 6,
    highend = 7,
  }

  local function UpdateWheelCount(wheelTypeId, wheelName)
    if wheelName == "stock" then
      wheelCount = 1
      NuiMessage("updateWheelCount", { wheelCount = wheelCount, wheelType = wheelName })
      return
    end

    SetVehicleWheelType(playerVeh, wheelTypeId)
    local numWheelMods = GetNumVehicleMods(playerVeh, 23)
    local count = 0
    for _ = 0, numWheelMods - 1 do
      count = count + 1
    end
    NuiMessage("updateWheelCount", { wheelCount = count, wheelType = wheelName })
  end

  local wheelTypeId = wheelTypeMap[data.name]
  if wheelTypeId then
    UpdateWheelCount(wheelTypeId, data.name)
  end
end)

local vehicleExtras = {}

RegisterNUICallback("getVehicleExtra", function()
  vehicleExtras = {}
  SetVehicleModKit(playerVeh, 0)

  for extraId = 0, 14 do
    if DoesExtraExist(playerVeh, extraId) then
      local isOn = IsVehicleExtraTurnedOn(playerVeh, extraId)
      table.insert(vehicleExtras, { id = extraId, state = isOn })
    end
  end

  NuiMessage("updateExtraCount", { extra = vehicleExtras })
end)

RegisterNUICallback("setVehicleExtra", function(data)
  SetVehicleModKit(playerVeh, 0)

  local extraIndex = tonumber(data.id) + 1
  data.id = extraIndex

  local extraData = vehicleExtras[tonumber(data.id)]
  if extraData then
    local isCurrentlyOn = IsVehicleExtraTurnedOn(playerVeh, extraData.id)

    if isCurrentlyOn then
      -- Turn off
      SetVehicleExtra(playerVeh, extraData.id, 1)
      for i, item in ipairs(vehicleBasket) do
        if item.modId == "extra" .. extraData.id then
          table.remove(vehicleBasket, i)
          break
        end
      end
      NuiMessage("updateVehicleBasket", vehicleBasket)
      return
    else
      -- Turn on
      SetVehicleExtra(playerVeh, extraData.id, 0)

      local found = false
      for _, item in ipairs(vehicleBasket) do
        if tonumber(item.modId) == "extra" .. extraData.id then
          found = true
          break
        end
      end

      if not found then
        table.insert(vehicleBasket, {
          modId = "extra" .. extraData.id,
          price = Config.MechanicUpgradeDefaultPrice[1000].price,
          index = extraData.id,
          label = Config.MechanicUpgradeDefaultPrice[1000].label,
        })
      end
      NuiMessage("updateVehicleBasket", vehicleBasket)
    end
  end
end)

RegisterNUICallback("setVehicleLivery", function(data)
  SetVehicleModKit(playerVeh, 0)

  local currentLivery = GetVehicleLivery(playerVeh)
  local liveryCount = GetVehicleLiveryCount(playerVeh)

  if currentLivery == data.id then
    -- Deselect livery
    if liveryCount == -1 then
      SetVehicleMod(playerVeh, 48, tonumber(-1))
      SetVehicleLivery(playerVeh, -1)

      local found = false
      for _, item in ipairs(vehicleBasket) do
        if tonumber(item.modId) == 48 then
          found = true
          break
        end
      end
      if not found then
        table.insert(vehicleBasket, {
          modId = 48,
          price = Config.MechanicUpgradeDefaultPrice[48].removeprice,
          index = data.id,
          label = Config.MechanicUpgradeDefaultPrice[48].label,
        })
      end
      NuiMessage("updateStockNumber", { modId = 48, stock = -1 })
    else
      SetVehicleLivery(playerVeh, 0)
      NuiMessage("updateStockNumber", { modId = 48, stock = 0 })
    end
  else
    -- Select livery
    if liveryCount == -1 then
      SetVehicleMod(playerVeh, 48, tonumber(data.id))
      SetVehicleLivery(playerVeh, tonumber(data.id))
    else
      SetVehicleLivery(playerVeh, tonumber(data.id))
    end

    local found = false
    for _, item in ipairs(vehicleBasket) do
      if tonumber(item.modId) == 48 then
        found = true
        break
      end
    end
    if not found then
      table.insert(vehicleBasket, {
        modId = 48,
        price = Config.MechanicUpgradeDefaultPrice[48].price,
        index = data.id,
        label = Config.MechanicUpgradeDefaultPrice[48].label,
      })
    end
    NuiMessage("updateStockNumber", { modId = 48, stock = data.id })
  end

  NuiMessage("updateVehicleBasket", vehicleBasket)
end)

RegisterNUICallback("setVehicleWheelChange", function(data)
  currentwheelType = GetVehicleWheelType(playerVeh)
  currentwheelIndex = GetVehicleMod(playerVeh, 23)
  SetVehicleModKit(playerVeh, 0)

  local wheelId = data.wheelId or 0
  local wheelIndex = data.index or -1

  SetVehicleWheelType(playerVeh, wheelId)
  SetVehicleMod(playerVeh, 23, wheelIndex, false)

  local wheelTypeNames = {
    [0] = "sport",
    [1] = "muscle",
    [2] = "lowrider",
    [3] = "suv",
    [4] = "offroad",
    [5] = "tuner",
    [6] = "bike",
    [7] = "highend",
  }

  local wheelNameLookup = {}
  for id, name in pairs(wheelTypeNames) do
    wheelNameLookup[name] = true
  end

  -- Remove any existing wheel type entry from basket
  for i = #vehicleBasket, 1, -1 do
    if wheelNameLookup[vehicleBasket[i].modId] then
      table.remove(vehicleBasket, i)
      break
    end
  end

  -- Add new wheel type to basket
  local wheelName = wheelTypeNames[data.wheelId]
  local found = false
  for _, item in ipairs(vehicleBasket) do
    if item.modId == wheelName then
      found = true
      break
    end
  end

  if not found and wheelName then
    local wheelPriceConfig = Config.MechanicUpgradeDefaultPrice[wheelName]
    table.insert(vehicleBasket, {
      modId = wheelName,
      price = wheelPriceConfig.price,
      index = "",
      label = wheelPriceConfig.label,
    })
  end

  NuiMessage("updateVehicleBasket", vehicleBasket)
end)

RegisterNUICallback("openVehicleNeon", function(enabled)
  if enabled then
    for i = 0, 3 do
      SetVehicleNeonLightEnabled(playerVeh, i, true)
    end

    local neonColors = table.pack(GetVehicleNeonLightsColour(playerVeh))
    if tonumber(neonColors[1]) == 255 and tonumber(neonColors[2]) == 255 and tonumber(neonColors[3]) == 255 then
      NuiMessage("updateStockNumber", { modId = 996, stock = 0 })
    else
      NuiMessage("updateStockNumber", { modId = 996, stock = 1 })
    end
  else
    for i = 0, 3 do
      SetVehicleNeonLightEnabled(playerVeh, i, false)
    end
  end
end)

freecam = false

RegisterNUICallback("freecam", function()
  SetNuiFocus(false, false)
  RenderScriptCams(false, true, 500, true, true)

  DestroyCam(mainCam, true)
  DestroyCam(frontCam, true)
  DestroyCam(rearCam, true)
  DestroyCam(leftCam, true)
  DestroyCam(rightCam, true)
  DestroyCam(topCam, true)
  DestroyCam(interiorCam, true)
  DestroyCam(wheelCam, true)
  DestroyCam(wheelsteringCam, true)

  FreezeEntityPosition(playerVeh, true)
  ClearFocus()
  NuiMessage("openFreeCam")
  freecam = true

  CreateThread(function()
    while freecam do
      DisableAllControlActions(0)
      EnableControlAction(0, 1, true)
      EnableControlAction(0, 2, true)
      EnableControlAction(0, 38, true)
      EnableControlAction(0, 86, true)
      EnableControlAction(0, 249, true)
      Wait(1)

      if IsControlJustPressed(0, 38) then
        freecam = false
        openMenu("mechanic", lastMenuLabel)
      end
    end
  end)
end)

RegisterNUICallback("openMouse", function()
  SetNuiFocus(true, true)
  CreateCamVehicle()
end)

AddEventHandler("onResourceStop", function(resourceName)
  if GetCurrentServerEndpoint() == nil then return end

  if resourceName == GetCurrentResourceName() then
    SetNuiFocus(false, false)
    RenderScriptCams(false, true, 500, true, true)

    DestroyCam(mainCam, true)
    DestroyCam(frontCam, true)
    DestroyCam(rearCam, true)
    DestroyCam(leftCam, true)
    DestroyCam(rightCam, true)
    DestroyCam(topCam, true)
    DestroyCam(interiorCam, true)
    DestroyCam(wheelCam, true)
    DestroyCam(DireksiyonCam, true)

    ClearFocus()
    SetVehicleBurnout(playerVeh, false)
    FreezeEntityPosition(playerVeh, false)
    FreezeEntityPosition(PlayerPedId(), false)
  end
end)

RegisterNUICallback("close", function()
  openMenuDrawText = false
  bossMenuOpen = false
  SetNuiFocus(false, false)
  RenderScriptCams(false, true, 500, true, true)

  DestroyCam(mainCam, true)
  DestroyCam(frontCam, true)
  DestroyCam(rearCam, true)
  DestroyCam(leftCam, true)
  DestroyCam(rightCam, true)
  DestroyCam(topCam, true)
  DestroyCam(interiorCam, true)
  DestroyCam(wheelCam, true)

  ClearFocus()
  FreezeEntityPosition(playerVeh, false)
  SetVehicleBurnout(playerVeh, false)

  -- Close all open doors
  for doorIndex = 0, 7 do
    if GetVehicleDoorAngleRatio(playerVeh, doorIndex) > 0 then
      SetVehicleDoorShut(playerVeh, doorIndex, false)
    end
  end

  vehicleBasket = {}

  -- Revert vehicle if modifications were not completed
  if not vehicleModifyCompleted then
    SetVehicleProperties(playerVeh, oldDataVehicle)
  end

  SetVehicleLights(playerVeh, 0)
  vehicleModifyCompleted = false
  playerVeh = nil
  freecam = false
  hideMenuClose()
  oldDataVehicle = false
  lastMenuLabel = false
end)

function GetNearbyPlayers(coords, radius)
  local activePlayers = GetActivePlayers()
  local myPed = PlayerPedId()

  if coords then
    if type(coords) == "table" then
      local vecCoords = vec3(coords.x, coords.y, coords.z)
      coords = vecCoords or coords
    end
  else
    coords = GetEntityCoords(myPed)
  end

  if not radius then
    radius = 5
  end

  local nearbyPlayers = {}
  for _, playerId in pairs(activePlayers) do
    local playerPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - coords)
    if radius >= distance then
      nearbyPlayers[#nearbyPlayers + 1] = playerId
    end
  end

  return nearbyPlayers
end

RegisterNUICallback("checkNearbyPlayers", function(data)
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local nearby = GetNearbyPlayers(coords, 5)

  local playerList = {}
  for _, playerId in ipairs(nearby) do
    table.insert(playerList, { id = GetPlayerServerId(playerId) })
  end

  TriggerServerEvent("codem-mechanic:getNearbyPlayers", playerList)
end)

RegisterNetEvent("codem-mechanic:setNearbyPlayers", function(players)
  if players then
    NuiMessage("updateNearbyPlayers", players)
  end
end)

function JobSuccesMoney(amount)
  TriggerServerEvent("codem-mechanic:giveMoney", key, tonumber(amount))
end
