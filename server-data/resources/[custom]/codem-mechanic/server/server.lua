local discordCache = { Avatars = {} }
offSetData = {}

RegisterServerEvent("codem-mechanic:showOtherBill", function(data)
  local targetId = tonumber(data.plyid)
  if targetId then
    TriggerClientEvent("codem-mechanic:sendShowBill", targetId, data)
  end
end)

RegisterServerEvent("codem-mechanic:getNearbyPlayers", function(players)
  local src = source
  local nearbyPlayers = {}

  for _, playerData in pairs(players) do
    if src ~= playerData.id then
      local playerName = GetName(tonumber(playerData.id))
      local avatar = GetDiscordAvatar(tonumber(playerData.id))
      if not avatar then
        avatar = Config.ExampleProfilePicture
      end
      table.insert(nearbyPlayers, {
        name = playerName,
        id = playerData.id,
        avatar = avatar,
      })
    end
  end

  if #nearbyPlayers > 0 then
    TriggerClientEvent("codem-mechanic:setNearbyPlayers", src, nearbyPlayers)
  end
end)

local authHeader = "Bot " .. bot_Token

function DiscordRequest(method, endpoint, body)
  local result = nil

  local url = "https://discordapp.com/api/" .. endpoint
  local encodedBody = ""
  if #body > 0 then
    encodedBody = json.encode(body) or ""
  end

  PerformHttpRequest(url, function(statusCode, responseData, headers)
    result = {
      data = responseData,
      code = statusCode,
      headers = headers,
    }
  end, method, encodedBody, {
    ["Content-Type"] = "application/json",
    Authorization = authHeader,
  })

  while result == nil do
    Citizen.Wait(0)
  end

  return result
end

function GetDiscordAvatar(source)
  local discordId = nil
  local avatarUrl = nil

  for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
    if string.match(identifier, "discord:") then
      discordId = string.gsub(identifier, "discord:", "")
      break
    end
  end

  if discordId then
    local cachedAvatar = discordCache.Avatars[discordId]
    if cachedAvatar == nil then
      local apiEndpoint = string.format("users/%s", discordId)
      local response = DiscordRequest("GET", apiEndpoint, {})

      if response.code == 200 then
        local userData = json.decode(response.data)
        if userData and userData.avatar then
          local firstChar = userData.avatar:sub(1, 1)
          if firstChar then
            local secondChar = userData.avatar:sub(2, 2)
            if secondChar == "_" then
              avatarUrl = "https://media.discordapp.net/avatars/" .. discordId .. "/" .. userData.avatar .. ".gif"
            end
          else
            avatarUrl = "https://media.discordapp.net/avatars/" .. discordId .. "/" .. userData.avatar .. ".png"
          end
        end
      end

      discordCache.Avatars[discordId] = avatarUrl
    else
      avatarUrl = discordCache.Avatars[discordId]
    end
  end

  return avatarUrl
end
