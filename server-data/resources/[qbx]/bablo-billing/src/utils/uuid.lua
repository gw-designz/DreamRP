
local L0_1, L1_1
function L0_1()
  local L0_2, L1_2, L2_2, L3_2, L4_2
  L0_2 = "INV-xxxx-4xxx-yxxx"
  L1_2 = string
  L1_2 = L1_2.gsub
  L2_2 = L0_2
  L3_2 = "[xy]"
  function L4_2(A0_3)
    local L1_3, L2_3, L3_3, L4_3
    if "x" == A0_3 then
      L1_3 = math
      L1_3 = L1_3.random
      L2_3 = 0
      L3_3 = 15
      L1_3 = L1_3(L2_3, L3_3)
      if L1_3 then
        goto lbl_15
      end
    end
    L1_3 = math
    L1_3 = L1_3.random
    L2_3 = 8
    L3_3 = 11
    L1_3 = L1_3(L2_3, L3_3)
    ::lbl_15::
    L2_3 = string
    L2_3 = L2_3.format
    L3_3 = "%x"
    L4_3 = L1_3
    return L2_3(L3_3, L4_3)
  end
  return L1_2(L2_2, L3_2, L4_2)
end
generateInvoiceUUID = L0_1
