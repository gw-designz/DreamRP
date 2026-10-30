MatchPairs = {}

local matchpairsPromise = nil
local isMatchpairsActive = false

function MatchPairs:start(options)
    if isMatchpairsActive then
        return { success = false, pairsFound = 0, cancelled = false }
    end

    if not options then options = {} end

    isMatchpairsActive = true
    matchpairsPromise = promise.new()

    SetNuiFocus(true, true)

    SendNUIMessage({
        action = "MATCH_PAIRS_OPEN",
        data = {
            pairs        = options.pairs        or 5,
            timeLimit    = options.timeLimit    or 30,
            gridCols     = options.gridCols     or 10,
            gridRows     = options.gridRows     or 10,
            tilesPerPair = options.tilesPerPair or 4,
            labels = {
                memorize  = Translate("MATCHPAIRS_MEMORIZE"),
                complete  = Translate("MATCHPAIRS_COMPLETE"),
                timesUp   = Translate("MATCHPAIRS_TIMES_UP"),
                findPairs = Translate("MATCHPAIRS_FIND_PAIRS"),
            }
        }
    })

    local result = Citizen.Await(matchpairsPromise)
    SetNuiFocus(false, false)
    isMatchpairsActive = false
    matchpairsPromise = nil
    return result
end

RegisterNUICallback("matchpairs:result", function(data, cb)
    cb({})
    if matchpairsPromise then
        matchpairsPromise:resolve(data)
    end
end)

exports("startMatchPairs", function(options, callback)
    Citizen.CreateThread(function()
        local result = MatchPairs:start(options)
        if callback then
            callback(result)
        end
    end)
end)
