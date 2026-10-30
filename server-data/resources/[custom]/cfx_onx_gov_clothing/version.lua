local L0_1, L1_1, L2_1, L3_1
L0_1 = Citizen
L0_1 = L0_1.Wait
L1_1 = 5000
L0_1(L1_1)
L0_1 = GetResourceMetadata
L1_1 = GetCurrentResourceName
L1_1 = L1_1()
L2_1 = "version"
L0_1 = L0_1(L1_1, L2_1)
curVersion = L0_1
L0_1 = PerformHttpRequest
L1_1 = "https://raw.githubusercontent.com/onxgg/rockstar/main/versions/"
L2_1 = GetCurrentResourceName
L2_1 = L2_1()
L3_1 = ".json"
L1_1 = L1_1 .. L2_1 .. L3_1
function L2_1(A0_2, A1_2, A2_2, A3_2)
  local L4_2, L5_2, L6_2, L7_2, L8_2, L9_2
  if 200 ~= A0_2 then
    L4_2 = print
    L5_2 = "Error checking for updates: "
    L6_2 = A0_2
    L5_2 = L5_2 .. L6_2
    L4_2(L5_2)
    return
  end
  L4_2 = json
  L4_2 = L4_2.decode
  L5_2 = A1_2
  L4_2 = L4_2(L5_2)
  result = L4_2
  L4_2 = result
  if L4_2 then
    L4_2 = result
    L4_2 = L4_2.version
    L5_2 = curVersion
    if L4_2 ~= L5_2 then
      L4_2 = print
      L5_2 = "^4==================================================="
      L4_2(L5_2)
      L4_2 = print
      L5_2 = "^4ONX.GG"
      L4_2(L5_2)
      L4_2 = print
      L5_2 = "^0"
      L6_2 = GetCurrentResourceName
      L6_2 = L6_2()
      L7_2 = " is outdated. Please update to "
      L8_2 = result
      L8_2 = L8_2.version
      L9_2 = "."
      L5_2 = L5_2 .. L6_2 .. L7_2 .. L8_2 .. L9_2
      L4_2(L5_2)
      L4_2 = print
      L5_2 = "^4Patch Notes: ^0"
      L6_2 = result
      L6_2 = L6_2.notes
      L5_2 = L5_2 .. L6_2
      L4_2(L5_2)
      L4_2 = print
      L5_2 = "^4==================================================="
      L4_2(L5_2)
    end
  end
end
L0_1(L1_1, L2_1)
