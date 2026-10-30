if IsDuplicityVersion() then return end

local playerZeroHash    = joaat("PLAYER_ZERO")
local HasModelLoaded    = HasModelLoaded
local RequestModel      = RequestModel
local CreatePed         = CreatePed
local DoesEntityExist   = DoesEntityExist
local FreezeEntityPosition  = FreezeEntityPosition
local SetEntityInvincible   = SetEntityInvincible
local SetEntityVisible      = SetEntityVisible
local SetEntityCanBeDamaged = SetEntityCanBeDamaged
local SetEntityCoordsNoOffset = SetEntityCoordsNoOffset
local GetEntityCoords       = GetEntityCoords
local GetEntityHeightAboveGround = GetEntityHeightAboveGround
local DeleteEntity          = DeleteEntity
local SetEntityAsNoLongerNeeded = SetEntityAsNoLongerNeeded
local SetModelAsNoLongerNeeded  = SetModelAsNoLongerNeeded

local function loadPlayerZeroModel()
    if not HasModelLoaded(playerZeroHash) then
        RequestModel(playerZeroHash)
        while not HasModelLoaded(playerZeroHash) do
            Citizen.Wait(50)
        end
    end
end

local function spawnInvisiblePed(coords)
    local ped = CreatePed(0, playerZeroHash, coords.x, coords.y, coords.z, 0.0, false, true)
    while not DoesEntityExist(ped) do
        Citizen.Wait(50)
    end

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityCanBeDamaged(ped, false)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, true)

    return ped
end

local function cleanupPed(ped)
    if DoesEntityExist(ped) then
        DeleteEntity(ped)
        SetEntityAsNoLongerNeeded(ped)
    end
end

function GetGroundCoord(coords)
    assert(
        type(coords) == "vector3",
        ("Failed to get ground coord. Expected vector3, got %s"):format(type(coords))
    )

    loadPlayerZeroModel()

    local ped       = spawnInvisiblePed(coords)
    local groundZ   = GetEntityCoords(ped).z - GetEntityHeightAboveGround(ped)

    cleanupPed(ped)

    if HasModelLoaded(playerZeroHash) then
        SetModelAsNoLongerNeeded(playerZeroHash)
    end

    return groundZ
end
