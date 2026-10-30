
local L0_1, L1_1
function L0_1(A0_2, A1_2, A2_2)
  local L3_2, L4_2, L5_2, L6_2, L7_2, L8_2
  if nil == A0_2 then
    if nil ~= A2_2 then
      return A2_2
    else
      L3_2 = error
      L4_2 = "Expected value of type "
      L5_2 = A1_2
      L6_2 = ", but got nil"
      L4_2 = L4_2 .. L5_2 .. L6_2
      L3_2(L4_2)
    end
  end
  L3_2 = type
  L4_2 = A0_2
  L3_2 = L3_2(L4_2)
  if L3_2 ~= A1_2 then
    L4_2 = error
    L5_2 = "Expected value of type "
    L6_2 = A1_2
    L7_2 = ", but got "
    L8_2 = L3_2
    L5_2 = L5_2 .. L6_2 .. L7_2 .. L8_2
    L4_2(L5_2)
  end
  return A0_2
end
ensure = L0_1
