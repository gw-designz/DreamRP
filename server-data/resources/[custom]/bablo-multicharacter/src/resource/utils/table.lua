

tbl = {}

function tbl.deepEqual(t1, t2)
    if type(t1) ~= 'table' or type(t2) ~= 'table' then
        return false
    end

    for k, v in pairs(t1) do
        if type(v) == 'table' then
            if not tbl.deepEqual(v, t2[k]) then
                return false
            end
        elseif v ~= t2[k] then
            return false
        end
    end

    for k in pairs(t2) do
        if t1[k] == nil then
            return false
        end
    end

    return true
end

function tbl.getKeyByValue(tbl, value)
    for k, v in pairs(tbl) do
        if v:lower() == value then
            return k
        end
    end
    return nil
end

function tbl.find(tbl, predicate)
    for i, v in ipairs(tbl) do
        if predicate(v, i) then
            return v, i
        end
    end
    return nil, nil
end

function tbl.filter(tbl, predicate)
    local result = {}
    for i, v in ipairs(tbl) do
        if predicate(v, i) then
            table.insert(result, v)
        end
    end
    return result
end

function tbl.map(tbl, func)
    local result = {}
    for i, v in ipairs(tbl) do
        result[i] = func(v, i)
    end
    return result
end

function tbl.reduce(tbl, func, initial)
    local acc = initial
    for i, v in ipairs(tbl) do
        acc = func(acc, v, i)
    end
    return acc
end

function tbl.sort(tbl, comparator)
    table.sort(tbl, comparator)
    return tbl
end

