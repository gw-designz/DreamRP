
local L0_1, L1_1, L2_1
L0_1 = _G
L1_1 = {}
L2_1 = {}
L1_1.states = L2_1
L2_1 = {}
L1_1.lastValues = L2_1
L1_1.interval = 1000
L0_1.playerCache = L1_1
L0_1 = playerCache
function L1_1(A0_2, A1_2, A2_2)
  local L3_2, L4_2, L5_2, L6_2
  L3_2 = ensure
  L4_2 = A0_2
  L5_2 = "string"
  L3_2(L4_2, L5_2)
  L3_2 = ensure
  L4_2 = A1_2
  L5_2 = "function"
  L3_2(L4_2, L5_2)
  L3_2 = ensure
  L4_2 = A2_2
  L5_2 = "table"
  L6_2 = "nil"
  L3_2(L4_2, L5_2, L6_2)
  if A2_2 then
    L3_2 = ensure
    L4_2 = A2_2.interval
    L5_2 = "number"
    L6_2 = "nil"
    L3_2(L4_2, L5_2, L6_2)
    L3_2 = ensure
    L4_2 = A2_2.onChange
    L5_2 = "function"
    L6_2 = "nil"
    L3_2(L4_2, L5_2, L6_2)
  end
  L3_2 = {}
  L3_2.key = A0_2
  L3_2.getter = A1_2
  if A2_2 then
    L4_2 = A2_2.interval
    if L4_2 then
      goto lbl_37
    end
  end
  L4_2 = playerCache
  L4_2 = L4_2.interval
  ::lbl_37::
  L3_2.interval = L4_2
  L3_2.lastTick = 0
  if A2_2 then
    L4_2 = A2_2.onChange
    if L4_2 then
      goto lbl_45
    end
  end
  L4_2 = nil
  ::lbl_45::
  L3_2.onChange = L4_2
  L4_2 = playerCache
  L4_2 = L4_2.states
  L4_2[A0_2] = L3_2
  L4_2 = playerCache
  L4_2 = L4_2.lastValues
  L5_2 = A1_2
  L5_2 = L5_2()
  L4_2[A0_2] = L5_2
  L4_2 = LocalPlayer
  L4_2 = L4_2.state
  L5_2 = playerCache
  L5_2 = L5_2.lastValues
  L5_2 = L5_2[A0_2]
  L4_2[A0_2] = L5_2
end
L0_1.watch = L1_1
L0_1 = playerCache
function L1_1(A0_2)
  local L1_2, L2_2, L3_2
  L1_2 = ensure
  L2_2 = A0_2
  L3_2 = "string"
  L1_2(L2_2, L3_2)
  L1_2 = playerCache
  L1_2 = L1_2.states
  L1_2 = L1_2[A0_2]
  if L1_2 then
    L1_2 = playerCache
    L1_2 = L1_2.states
    L1_2[A0_2] = nil
  end
end
L0_1.unwatch = L1_1
L0_1 = playerCache
function L1_1(A0_2)
  local L1_2
  L1_2 = playerCache
  L1_2 = L1_2.lastValues
  L1_2 = L1_2[A0_2]
  return L1_2
end
L0_1.get = L1_1
L0_1 = CreateThread
function L1_1()
  local L0_2, L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2
  while true do
    L0_2 = GetGameTimer
    L0_2 = L0_2()
    L1_2 = pairs
    L2_2 = playerCache
    L2_2 = L2_2.states
    L1_2, L2_2, L3_2, L4_2 = L1_2(L2_2)
    for L5_2, L6_2 in L1_2, L2_2, L3_2, L4_2 do
      L7_2 = L6_2.lastTick
      L7_2 = L0_2 - L7_2
      L8_2 = L6_2.interval
      if L7_2 >= L8_2 then
        L7_2 = L6_2.getter
        L7_2 = L7_2()
        L8_2 = playerCache
        L8_2 = L8_2.lastValues
        L9_2 = L6_2.key
        L8_2 = L8_2[L9_2]
        L9_2 = tbl
        L9_2 = L9_2.deepEqual
        L10_2 = L7_2
        L11_2 = L8_2
        L9_2 = L9_2(L10_2, L11_2)
        if not L9_2 then
          L9_2 = playerCache
          L9_2 = L9_2.lastValues
          L10_2 = L6_2.key
          L9_2[L10_2] = L7_2
          L9_2 = LocalPlayer
          L9_2 = L9_2.state
          L10_2 = L6_2.key
          L9_2[L10_2] = L7_2
          L9_2 = L6_2.onChange
          if L9_2 then
            L9_2 = L6_2.onChange
            L10_2 = L7_2
            L11_2 = L8_2
            L9_2(L10_2, L11_2)
          end
        end
        L6_2.lastTick = L0_2
      end
    end
    L1_2 = Wait
    L2_2 = 100
    L1_2(L2_2)
  end
end
L0_1(L1_1)
