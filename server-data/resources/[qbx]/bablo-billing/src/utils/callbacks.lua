
local L0_1, L1_1, L2_1, L3_1, L4_1, L5_1, L6_1, L7_1, L8_1, L9_1, L10_1, L11_1, L12_1, L13_1, L14_1, L15_1, L16_1
L0_1 = IsDuplicityVersion
L0_1 = L0_1()
L1_1 = table
L1_1 = L1_1.unpack
L2_1 = debug
L3_1 = L2_1.getinfo
L4_1 = msgpack
L5_1 = L4_1.pack
L6_1 = L4_1.unpack
L7_1 = L4_1.pack_args
L8_1 = 0
L9_1 = 1
L10_1 = 2
L11_1 = 3
L12_1 = 4
function L13_1(A0_2, A1_2, A2_2, A3_2)
  local L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2
  L4_2 = type
  L5_2 = A0_2
  L4_2 = L4_2(L5_2)
  L5_2 = L3_1
  L6_2 = 2
  L5_2 = L5_2(L6_2)
  L6_2 = A3_2 or L6_2
  if not A3_2 then
    if nil == A2_2 then
      L6_2 = L5_2.name
      L7_2 = " expected %s, but got %s"
      L6_2 = L6_2 .. L7_2
      if L6_2 then
        goto lbl_19
      end
    end
    L6_2 = L5_2.name
    L7_2 = " expected %s or %s, but got %s"
    L6_2 = L6_2 .. L7_2
  end
  ::lbl_19::
  if "function" ~= A1_2 then
    if L4_2 ~= A1_2 and L4_2 ~= A2_2 then
      L7_2 = error
      L9_2 = L6_2
      L8_2 = L6_2.format
      L10_2 = A1_2
      L11_2 = L4_2 or L11_2
      if nil ~= A2_2 or not L4_2 then
        L11_2 = A2_2
      end
      L12_2 = L4_2
      L8_2, L9_2, L10_2, L11_2, L12_2 = L8_2(L9_2, L10_2, L11_2, L12_2)
      L7_2(L8_2, L9_2, L10_2, L11_2, L12_2)
    end
  elseif "table" == L4_2 then
    L7_2 = rawget
    L8_2 = A0_2
    L9_2 = "__cfx_functionReference"
    L7_2 = L7_2(L8_2, L9_2)
    if not L7_2 then
      L7_2 = error
      L9_2 = L6_2
      L8_2 = L6_2.format
      L10_2 = A1_2
      L11_2 = L4_2 or L11_2
      if nil ~= A2_2 or not L4_2 then
        L11_2 = A2_2
      end
      L12_2 = L4_2
      L8_2, L9_2, L10_2, L11_2, L12_2 = L8_2(L9_2, L10_2, L11_2, L12_2)
      L7_2(L8_2, L9_2, L10_2, L11_2, L12_2)
    end
  end
end
if L0_1 then
  L14_1 = _G
  function L15_1(A0_2)
    local L1_2, L2_2, L3_2, L4_2, L5_2
    L1_2 = L13_1
    L2_2 = A0_2
    L3_2 = "table"
    L1_2(L2_2, L3_2)
    L1_2 = L13_1
    L2_2 = A0_2.eventName
    L3_2 = "string"
    L1_2(L2_2, L3_2)
    L1_2 = L13_1
    L2_2 = A0_2.eventCallback
    L3_2 = "function"
    L1_2(L2_2, L3_2)
    L1_2 = A0_2.eventCallback
    L2_2 = A0_2.eventName
    L3_2 = RegisterNetEvent
    L4_2 = "pmc__server_callback:"
    L5_2 = L2_2
    L4_2 = L4_2 .. L5_2
    function L5_2(A0_3, A1_3, A2_3)
      local L3_3, L4_3, L5_3, L6_3, L7_3, L8_3, L9_3, L10_3, L11_3, L12_3
      L3_3 = tonumber
      L4_3 = source
      L3_3 = L3_3(L4_3)
      if not L3_3 then
        L4_3 = A2_3
        L5_3 = L7_1
        L6_3 = L1_2
        L7_3 = A1_3
        L8_3 = L1_1
        L9_3 = L6_1
        L10_3 = A0_3
        L9_3, L10_3, L11_3, L12_3 = L9_3(L10_3)
        L8_3, L9_3, L10_3, L11_3, L12_3 = L8_3(L9_3, L10_3, L11_3, L12_3)
        L6_3, L7_3, L8_3, L9_3, L10_3, L11_3, L12_3 = L6_3(L7_3, L8_3, L9_3, L10_3, L11_3, L12_3)
        L5_3, L6_3, L7_3, L8_3, L9_3, L10_3, L11_3, L12_3 = L5_3(L6_3, L7_3, L8_3, L9_3, L10_3, L11_3, L12_3)
        L4_3(L5_3, L6_3, L7_3, L8_3, L9_3, L10_3, L11_3, L12_3)
      else
        L4_3 = TriggerClientEvent
        L5_3 = "pmc__client_callback_response:%s:%s"
        L6_3 = L5_3
        L5_3 = L5_3.format
        L7_3 = L2_2
        L8_3 = L3_3
        L5_3 = L5_3(L6_3, L7_3, L8_3)
        L6_3 = L3_3
        L7_3 = L7_1
        L8_3 = L1_2
        L9_3 = L3_3
        L10_3 = L1_1
        L11_3 = L6_1
        L12_3 = A0_3
        L11_3, L12_3 = L11_3(L12_3)
        L10_3, L11_3, L12_3 = L10_3(L11_3, L12_3)
        L8_3, L9_3, L10_3, L11_3, L12_3 = L8_3(L9_3, L10_3, L11_3, L12_3)
        L7_3, L8_3, L9_3, L10_3, L11_3, L12_3 = L7_3(L8_3, L9_3, L10_3, L11_3, L12_3)
        L4_3(L5_3, L6_3, L7_3, L8_3, L9_3, L10_3, L11_3, L12_3)
      end
    end
    L3_2 = L3_2(L4_2, L5_2)
    return L3_2
  end
  L14_1.RegisterServerCallback = L15_1
  L14_1 = _G
  function L15_1(A0_2)
    local L1_2, L2_2
    L1_2 = RemoveEventHandler
    L2_2 = A0_2
    L1_2(L2_2)
  end
  L14_1.UnregisterServerCallback = L15_1
  L14_1 = _G
  function L15_1(A0_2)
    local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2
    L1_2 = L13_1
    L2_2 = A0_2
    L3_2 = "table"
    L1_2(L2_2, L3_2)
    L1_2 = L13_1
    L2_2 = A0_2.source
    L3_2 = "string"
    L4_2 = "number"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = L13_1
    L2_2 = A0_2.eventName
    L3_2 = "string"
    L1_2(L2_2, L3_2)
    L1_2 = L13_1
    L2_2 = A0_2.args
    L3_2 = "table"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = L13_1
    L2_2 = A0_2.timeout
    L3_2 = "number"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = L13_1
    L2_2 = A0_2.timedout
    L3_2 = "function"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = L13_1
    L2_2 = A0_2.callback
    L3_2 = "function"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = tonumber
    L2_2 = A0_2.source
    L1_2 = L1_2(L2_2)
    if L1_2 >= 0 then
      L1_2 = tostring
      L2_2 = A0_2.source
      L1_2 = L1_2(L2_2)
      L2_2 = "x"
      L3_2 = tostring
      L4_2 = GetGameTimer
      L4_2, L5_2, L6_2, L7_2, L8_2, L9_2 = L4_2()
      L3_2 = L3_2(L4_2, L5_2, L6_2, L7_2, L8_2, L9_2)
      L1_2 = L1_2 .. L2_2 .. L3_2
      L2_2 = promise
      L2_2 = L2_2.new
      L2_2 = L2_2()
      L3_2 = A0_2.callback
      L4_2 = RegisterNetEvent
      L5_2 = "pmc__callback_retval:%s:%s:%s"
      L6_2 = L5_2
      L5_2 = L5_2.format
      L7_2 = A0_2.source
      L8_2 = A0_2.eventName
      L9_2 = L1_2
      L5_2 = L5_2(L6_2, L7_2, L8_2, L9_2)
      function L6_2(A0_3)
        local L1_3, L2_3, L3_3, L4_3, L5_3
        L1_3 = L3_2
        if L1_3 then
          L1_3 = L2_2.state
          L2_3 = L8_1
          if L1_3 == L2_3 then
            L1_3 = L3_2
            L2_3 = L1_1
            L3_3 = L6_1
            L4_3 = A0_3
            L3_3, L4_3, L5_3 = L3_3(L4_3)
            L2_3, L3_3, L4_3, L5_3 = L2_3(L3_3, L4_3, L5_3)
            L1_3(L2_3, L3_3, L4_3, L5_3)
          end
        end
        L1_3 = L2_2
        L2_3 = L1_3
        L1_3 = L1_3.resolve
        L3_3 = L1_1
        L4_3 = L6_1
        L5_3 = A0_3
        L4_3, L5_3 = L4_3(L5_3)
        L3_3, L4_3, L5_3 = L3_3(L4_3, L5_3)
        L1_3(L2_3, L3_3, L4_3, L5_3)
      end
      L4_2 = L4_2(L5_2, L6_2)
      L5_2 = TriggerClientEvent
      L6_2 = "pmc__client_callback:%s"
      L7_2 = L6_2
      L6_2 = L6_2.format
      L8_2 = A0_2.eventName
      L6_2 = L6_2(L7_2, L8_2)
      L7_2 = A0_2.source
      L8_2 = L5_1
      L9_2 = A0_2.args
      if not L9_2 then
        L9_2 = {}
      end
      L8_2 = L8_2(L9_2)
      L9_2 = L1_2
      L5_2(L6_2, L7_2, L8_2, L9_2)
      L5_2 = A0_2.timeout
      if nil ~= L5_2 then
        L5_2 = A0_2.timedout
        if L5_2 then
          L5_2 = A0_2.timedout
          L6_2 = SetTimeout
          L7_2 = A0_2.timeout
          L7_2 = L7_2 * 1000
          function L8_2()
            local L0_3, L1_3
            L0_3 = L2_2.state
            L1_3 = L8_1
            if L0_3 ~= L1_3 then
              L0_3 = L2_2.state
              L1_3 = L12_1
              if L0_3 ~= L1_3 then
                L0_3 = L2_2.state
                L1_3 = L10_1
                if L0_3 ~= L1_3 then
                  goto lbl_26
                end
              end
            end
            L0_3 = L5_2
            L1_3 = L2_2.state
            L0_3(L1_3)
            L0_3 = L2_2.state
            L1_3 = L8_1
            if L0_3 == L1_3 then
              L0_3 = L2_2
              L1_3 = L0_3
              L0_3 = L0_3.reject
              L0_3(L1_3)
            end
            L0_3 = RemoveEventHandler
            L1_3 = L4_2
            L0_3(L1_3)
            ::lbl_26::
          end
          L6_2(L7_2, L8_2)
        end
      end
      if not L3_2 then
        L5_2 = Citizen
        L5_2 = L5_2.Await
        L6_2 = L2_2
        L5_2 = L5_2(L6_2)
        L6_2 = RemoveEventHandler
        L7_2 = L4_2
        L6_2(L7_2)
        return L5_2
      end
    else
      L1_2 = error
      L2_2 = "source should be equal too or higher than 0"
      L1_2(L2_2)
    end
  end
  L14_1.TriggerClientCallback = L15_1
  L14_1 = _G
  function L15_1(A0_2)
    local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2
    L1_2 = L13_1
    L2_2 = A0_2
    L3_2 = "table"
    L1_2(L2_2, L3_2)
    L1_2 = L13_1
    L2_2 = A0_2.source
    L3_2 = "string"
    L4_2 = "number"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = L13_1
    L2_2 = A0_2.eventName
    L3_2 = "string"
    L1_2(L2_2, L3_2)
    L1_2 = L13_1
    L2_2 = A0_2.args
    L3_2 = "table"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = L13_1
    L2_2 = A0_2.timeout
    L3_2 = "number"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = L13_1
    L2_2 = A0_2.timedout
    L3_2 = "function"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = L13_1
    L2_2 = A0_2.callback
    L3_2 = "function"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = promise
    L1_2 = L1_2.new
    L1_2 = L1_2()
    L2_2 = A0_2.callback
    L3_2 = A0_2.eventName
    L4_2 = TriggerEvent
    L5_2 = "pmc__server_callback:"
    L6_2 = L3_2
    L5_2 = L5_2 .. L6_2
    L6_2 = L5_1
    L7_2 = A0_2.args
    if not L7_2 then
      L7_2 = {}
    end
    L6_2 = L6_2(L7_2)
    L7_2 = A0_2.source
    function L8_2(A0_3)
      local L1_3, L2_3, L3_3, L4_3, L5_3
      L1_3 = L2_2
      if L1_3 then
        L1_3 = L1_2.state
        L2_3 = L8_1
        if L1_3 == L2_3 then
          L1_3 = L2_2
          L2_3 = L1_1
          L3_3 = L6_1
          L4_3 = A0_3
          L3_3, L4_3, L5_3 = L3_3(L4_3)
          L2_3, L3_3, L4_3, L5_3 = L2_3(L3_3, L4_3, L5_3)
          L1_3(L2_3, L3_3, L4_3, L5_3)
        end
      end
      L1_3 = L1_2
      L2_3 = L1_3
      L1_3 = L1_3.resolve
      L3_3 = L1_1
      L4_3 = L6_1
      L5_3 = A0_3
      L4_3, L5_3 = L4_3(L5_3)
      L3_3, L4_3, L5_3 = L3_3(L4_3, L5_3)
      L1_3(L2_3, L3_3, L4_3, L5_3)
    end
    L4_2(L5_2, L6_2, L7_2, L8_2)
    L4_2 = A0_2.timeout
    if nil ~= L4_2 then
      L4_2 = A0_2.timedout
      if L4_2 then
        L4_2 = A0_2.timedout
        L5_2 = SetTimeout
        L6_2 = A0_2.timeout
        L6_2 = L6_2 * 1000
        function L7_2()
          local L0_3, L1_3
          L0_3 = L1_2.state
          L1_3 = L8_1
          if L0_3 ~= L1_3 then
            L0_3 = L1_2.state
            L1_3 = L12_1
            if L0_3 ~= L1_3 then
              L0_3 = L1_2.state
              L1_3 = L10_1
              if L0_3 ~= L1_3 then
                goto lbl_23
              end
            end
          end
          L0_3 = L4_2
          L1_3 = L1_2.state
          L0_3(L1_3)
          L0_3 = L1_2.state
          L1_3 = L8_1
          if L0_3 == L1_3 then
            L0_3 = L1_2
            L1_3 = L0_3
            L0_3 = L0_3.reject
            L0_3(L1_3)
          end
          ::lbl_23::
        end
        L5_2(L6_2, L7_2)
      end
    end
    if not L2_2 then
      L4_2 = Citizen
      L4_2 = L4_2.Await
      L5_2 = L1_2
      return L4_2(L5_2)
    end
  end
  L14_1.TriggerServerCallback = L15_1
end
if not L0_1 then
  L14_1 = GetPlayerServerId
  L15_1 = PlayerId
  L15_1, L16_1 = L15_1()
  L14_1 = L14_1(L15_1, L16_1)
  L15_1 = _G
  function L16_1(A0_2)
    local L1_2, L2_2, L3_2, L4_2, L5_2
    L1_2 = L13_1
    L2_2 = A0_2
    L3_2 = "table"
    L1_2(L2_2, L3_2)
    L1_2 = L13_1
    L2_2 = A0_2.eventName
    L3_2 = "string"
    L1_2(L2_2, L3_2)
    L1_2 = L13_1
    L2_2 = A0_2.eventCallback
    L3_2 = "function"
    L1_2(L2_2, L3_2)
    L1_2 = A0_2.eventCallback
    L2_2 = A0_2.eventName
    L3_2 = RegisterNetEvent
    L4_2 = "pmc__client_callback:"
    L5_2 = L2_2
    L4_2 = L4_2 .. L5_2
    function L5_2(A0_3, A1_3)
      local L2_3, L3_3, L4_3, L5_3, L6_3, L7_3, L8_3
      L2_3 = type
      L3_3 = A1_3
      L2_3 = L2_3(L3_3)
      if "function" == L2_3 then
        L2_3 = A1_3
        L3_3 = L7_1
        L4_3 = L1_2
        L5_3 = L1_1
        L6_3 = L6_1
        L7_3 = A0_3
        L6_3, L7_3, L8_3 = L6_3(L7_3)
        L5_3, L6_3, L7_3, L8_3 = L5_3(L6_3, L7_3, L8_3)
        L4_3, L5_3, L6_3, L7_3, L8_3 = L4_3(L5_3, L6_3, L7_3, L8_3)
        L3_3, L4_3, L5_3, L6_3, L7_3, L8_3 = L3_3(L4_3, L5_3, L6_3, L7_3, L8_3)
        L2_3(L3_3, L4_3, L5_3, L6_3, L7_3, L8_3)
      else
        L2_3 = TriggerServerEvent
        L3_3 = "pmc__callback_retval:%s:%s:%s"
        L4_3 = L3_3
        L3_3 = L3_3.format
        L5_3 = L14_1
        L6_3 = L2_2
        L7_3 = A1_3
        L3_3 = L3_3(L4_3, L5_3, L6_3, L7_3)
        L4_3 = L7_1
        L5_3 = L1_2
        L6_3 = L1_1
        L7_3 = L6_1
        L8_3 = A0_3
        L7_3, L8_3 = L7_3(L8_3)
        L6_3, L7_3, L8_3 = L6_3(L7_3, L8_3)
        L5_3, L6_3, L7_3, L8_3 = L5_3(L6_3, L7_3, L8_3)
        L4_3, L5_3, L6_3, L7_3, L8_3 = L4_3(L5_3, L6_3, L7_3, L8_3)
        L2_3(L3_3, L4_3, L5_3, L6_3, L7_3, L8_3)
      end
    end
    L3_2 = L3_2(L4_2, L5_2)
    return L3_2
  end
  L15_1.RegisterClientCallback = L16_1
  L15_1 = _G
  function L16_1(A0_2)
    local L1_2, L2_2
    L1_2 = RemoveEventHandler
    L2_2 = A0_2
    L1_2(L2_2)
  end
  L15_1.UnregisterClientCallback = L16_1
  L15_1 = _G
  function L16_1(A0_2)
    local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2
    L1_2 = L13_1
    L2_2 = A0_2
    L3_2 = "table"
    L1_2(L2_2, L3_2)
    L1_2 = L13_1
    L2_2 = A0_2.args
    L3_2 = "table"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = L13_1
    L2_2 = A0_2.eventName
    L3_2 = "string"
    L1_2(L2_2, L3_2)
    L1_2 = L13_1
    L2_2 = A0_2.timeout
    L3_2 = "number"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = L13_1
    L2_2 = A0_2.timedout
    L3_2 = "function"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = L13_1
    L2_2 = A0_2.callback
    L3_2 = "function"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = promise
    L1_2 = L1_2.new
    L1_2 = L1_2()
    L2_2 = A0_2.callback
    L3_2 = RegisterNetEvent
    L4_2 = "pmc__client_callback_response:%s:%s"
    L5_2 = L4_2
    L4_2 = L4_2.format
    L6_2 = A0_2.eventName
    L7_2 = L14_1
    L4_2 = L4_2(L5_2, L6_2, L7_2)
    function L5_2(A0_3)
      local L1_3, L2_3, L3_3, L4_3, L5_3
      L1_3 = L2_2
      if L1_3 then
        L1_3 = L1_2.state
        L2_3 = L8_1
        if L1_3 == L2_3 then
          L1_3 = L2_2
          L2_3 = L1_1
          L3_3 = L6_1
          L4_3 = A0_3
          L3_3, L4_3, L5_3 = L3_3(L4_3)
          L2_3, L3_3, L4_3, L5_3 = L2_3(L3_3, L4_3, L5_3)
          L1_3(L2_3, L3_3, L4_3, L5_3)
        end
      end
      L1_3 = L1_2
      L2_3 = L1_3
      L1_3 = L1_3.resolve
      L3_3 = L1_1
      L4_3 = L6_1
      L5_3 = A0_3
      L4_3, L5_3 = L4_3(L5_3)
      L3_3, L4_3, L5_3 = L3_3(L4_3, L5_3)
      L1_3(L2_3, L3_3, L4_3, L5_3)
    end
    L3_2 = L3_2(L4_2, L5_2)
    L4_2 = TriggerServerEvent
    L5_2 = "pmc__server_callback:"
    L6_2 = A0_2.eventName
    L5_2 = L5_2 .. L6_2
    L6_2 = L5_1
    L7_2 = A0_2.args
    L6_2, L7_2 = L6_2(L7_2)
    L4_2(L5_2, L6_2, L7_2)
    L4_2 = A0_2.timeout
    if nil ~= L4_2 then
      L4_2 = A0_2.timedout
      if L4_2 then
        L4_2 = A0_2.timedout
        L5_2 = SetTimeout
        L6_2 = A0_2.timeout
        L6_2 = L6_2 * 1000
        function L7_2()
          local L0_3, L1_3
          L0_3 = L1_2.state
          L1_3 = L8_1
          if L0_3 ~= L1_3 then
            L0_3 = L1_2.state
            L1_3 = L12_1
            if L0_3 ~= L1_3 then
              L0_3 = L1_2.state
              L1_3 = L10_1
              if L0_3 ~= L1_3 then
                goto lbl_26
              end
            end
          end
          L0_3 = L4_2
          L1_3 = L1_2.state
          L0_3(L1_3)
          L0_3 = L1_2.state
          L1_3 = L8_1
          if L0_3 == L1_3 then
            L0_3 = L1_2
            L1_3 = L0_3
            L0_3 = L0_3.reject
            L0_3(L1_3)
          end
          L0_3 = RemoveEventHandler
          L1_3 = L3_2
          L0_3(L1_3)
          ::lbl_26::
        end
        L5_2(L6_2, L7_2)
      end
    end
    if not L2_2 then
      L4_2 = Citizen
      L4_2 = L4_2.Await
      L5_2 = L1_2
      L4_2 = L4_2(L5_2)
      L5_2 = RemoveEventHandler
      L6_2 = L3_2
      L5_2(L6_2)
      return L4_2
    end
  end
  L15_1.TriggerServerCallback = L16_1
  L15_1 = _G
  function L16_1(A0_2)
    local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2
    L1_2 = L13_1
    L2_2 = A0_2
    L3_2 = "table"
    L1_2(L2_2, L3_2)
    L1_2 = L13_1
    L2_2 = A0_2.eventName
    L3_2 = "string"
    L1_2(L2_2, L3_2)
    L1_2 = L13_1
    L2_2 = A0_2.args
    L3_2 = "table"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = L13_1
    L2_2 = A0_2.timeout
    L3_2 = "number"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = L13_1
    L2_2 = A0_2.timedout
    L3_2 = "function"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = L13_1
    L2_2 = A0_2.callback
    L3_2 = "function"
    L4_2 = "nil"
    L1_2(L2_2, L3_2, L4_2)
    L1_2 = promise
    L1_2 = L1_2.new
    L1_2 = L1_2()
    L2_2 = A0_2.callback
    L3_2 = A0_2.eventName
    L4_2 = TriggerEvent
    L5_2 = "pmc__client_callback:"
    L6_2 = L3_2
    L5_2 = L5_2 .. L6_2
    L6_2 = L5_1
    L7_2 = A0_2.args
    if not L7_2 then
      L7_2 = {}
    end
    L6_2 = L6_2(L7_2)
    function L7_2(A0_3)
      local L1_3, L2_3, L3_3, L4_3, L5_3
      L1_3 = L2_2
      if L1_3 then
        L1_3 = L1_2.state
        L2_3 = L8_1
        if L1_3 == L2_3 then
          L1_3 = L2_2
          L2_3 = L1_1
          L3_3 = L6_1
          L4_3 = A0_3
          L3_3, L4_3, L5_3 = L3_3(L4_3)
          L2_3, L3_3, L4_3, L5_3 = L2_3(L3_3, L4_3, L5_3)
          L1_3(L2_3, L3_3, L4_3, L5_3)
        end
      end
      L1_3 = L1_2
      L2_3 = L1_3
      L1_3 = L1_3.resolve
      L3_3 = L1_1
      L4_3 = L6_1
      L5_3 = A0_3
      L4_3, L5_3 = L4_3(L5_3)
      L3_3, L4_3, L5_3 = L3_3(L4_3, L5_3)
      L1_3(L2_3, L3_3, L4_3, L5_3)
    end
    L4_2(L5_2, L6_2, L7_2)
    L4_2 = A0_2.timeout
    if nil ~= L4_2 then
      L4_2 = A0_2.timedout
      if L4_2 then
        L4_2 = A0_2.timedout
        L5_2 = SetTimeout
        L6_2 = A0_2.timeout
        L6_2 = L6_2 * 1000
        function L7_2()
          local L0_3, L1_3
          L0_3 = L1_2.state
          L1_3 = L8_1
          if L0_3 ~= L1_3 then
            L0_3 = L1_2.state
            L1_3 = L12_1
            if L0_3 ~= L1_3 then
              L0_3 = L1_2.state
              L1_3 = L10_1
              if L0_3 ~= L1_3 then
                goto lbl_23
              end
            end
          end
          L0_3 = L4_2
          L1_3 = L1_2.state
          L0_3(L1_3)
          L0_3 = L1_2.state
          L1_3 = L8_1
          if L0_3 == L1_3 then
            L0_3 = L1_2
            L1_3 = L0_3
            L0_3 = L0_3.reject
            L0_3(L1_3)
          end
          ::lbl_23::
        end
        L5_2(L6_2, L7_2)
      end
    end
    if not L2_2 then
      L4_2 = Citizen
      L4_2 = L4_2.Await
      L5_2 = L1_2
      return L4_2(L5_2)
    end
  end
  L15_1.TriggerClientCallback = L16_1
end
