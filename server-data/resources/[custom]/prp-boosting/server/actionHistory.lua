ActionHistory = {}

lib.callback.register("prp-boosting:requestActionHistory", function(source)
    return ActionHistory
end)

function AddActionHistory(stateId, actionType, class, success)
    local username = PlayerUsernames[stateId]
    table.insert(ActionHistory, {
        type = actionType,
        class = class,
        success = success,
        authorName = username,
    })

    if #ActionHistory > 15 then
        table.remove(ActionHistory, 1)
    end

    TriggerClientEvent("prp-boosting:addActionHistory", -1, ActionHistory[#ActionHistory]) 
end