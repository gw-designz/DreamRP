local maxProps = GetConvarInt('ox:progressPropLimit', 2)

---@param props ProgressPropProps | ProgressPropProps[] | nil
RegisterNetEvent('prism:progressProps', function(props)
    local source = source

    if type(props) == 'table' then
        props = #props > maxProps and { table.unpack(props, 1, maxProps) } or props
    else
        props = nil
    end

    Player(source).state:set('prism:progressProps', props, true)
end)
