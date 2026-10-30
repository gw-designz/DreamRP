
local L0_1, L1_1
function L0_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = Config
  if L2_2 then
    L2_2 = Config
    L2_2 = L2_2.Tax
    if L2_2 then
      L2_2 = Config
      L2_2 = L2_2.Tax
      L2_2 = L2_2.enabled
      if L2_2 then
        goto lbl_15
      end
    end
  end
  L2_2 = 0
  do return L2_2 end
  ::lbl_15::
  if "job" == A0_2 and A1_2 then
    L2_2 = Config
    L2_2 = L2_2.Tax
    L2_2 = L2_2.jobRates
    if L2_2 then
      L2_2 = Config
      L2_2 = L2_2.Tax
      L2_2 = L2_2.jobRates
      L2_2 = L2_2[A1_2]
    end
    if nil ~= L2_2 then
      L3_2 = tonumber
      L4_2 = L2_2
      L3_2 = L3_2(L4_2)
      if not L3_2 then
        L3_2 = 0
      end
      return L3_2
    end
  end
  L2_2 = tonumber
  L3_2 = Config
  L3_2 = L3_2.Tax
  L3_2 = L3_2.defaultRate
  L2_2 = L2_2(L3_2)
  if not L2_2 then
    L2_2 = 0
  end
  return L2_2
end
GetTaxRate = L0_1
function L0_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = tonumber
  L3_2 = A0_2
  L2_2 = L2_2(L3_2)
  A0_2 = L2_2 or A0_2
  if not L2_2 then
    A0_2 = 0
  end
  L2_2 = tonumber
  L3_2 = A1_2
  L2_2 = L2_2(L3_2)
  A1_2 = L2_2 or A1_2
  if not L2_2 then
    A1_2 = 0
  end
  if A1_2 <= 0 or A0_2 <= 0 then
    L2_2 = 0
    L3_2 = A0_2
    return L2_2, L3_2
  end
  L2_2 = math
  L2_2 = L2_2.floor
  L3_2 = A0_2 * A1_2
  L3_2 = L3_2 / 100
  L3_2 = L3_2 * 100
  L3_2 = L3_2 + 0.5
  L2_2 = L2_2(L3_2)
  L2_2 = L2_2 / 100
  L3_2 = L2_2
  L4_2 = A0_2 + L2_2
  return L3_2, L4_2
end
CalculateTax = L0_1
