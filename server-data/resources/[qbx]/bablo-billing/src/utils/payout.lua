
local L0_1, L1_1
function L0_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2
  L1_2 = Config
  if L1_2 then
    L1_2 = Config
    L1_2 = L1_2.Payout
    if L1_2 then
      L1_2 = Config
      L1_2 = L1_2.Payout
      L1_2 = L1_2.enabled
      if L1_2 then
        goto lbl_15
      end
    end
  end
  L1_2 = nil
  do return L1_2 end
  ::lbl_15::
  if A0_2 then
    L1_2 = Config
    L1_2 = L1_2.Payout
    L1_2 = L1_2.jobs
    if L1_2 then
      L1_2 = Config
      L1_2 = L1_2.Payout
      L1_2 = L1_2.jobs
      L1_2 = L1_2[A0_2]
      if L1_2 then
        goto lbl_35
      end
    end
  end
  L1_2 = Config
  L1_2 = L1_2.Payout
  L1_2 = L1_2.default
  if not L1_2 then
    L1_2 = {}
  end
  ::lbl_35::
  L2_2 = tonumber
  L3_2 = L1_2.issuer
  L2_2 = L2_2(L3_2)
  if not L2_2 then
    L2_2 = 0
  end
  L3_2 = tonumber
  L4_2 = L1_2.society
  L3_2 = L3_2(L4_2)
  if not L3_2 then
    L3_2 = 0
  end
  if L2_2 < 0 then
    L2_2 = 0
  end
  if L3_2 < 0 then
    L3_2 = 0
  end
  if L2_2 > 100 then
    L2_2 = 100
  end
  L4_2 = L2_2 + L3_2
  if L4_2 > 100 then
    L4_2 = Debug
    L5_2 = L4_2
    L4_2 = L4_2.warn
    L6_2 = "Config.Payout split for"
    L7_2 = A0_2 or L7_2
    if not A0_2 then
      L7_2 = "default"
    end
    L8_2 = "exceeds 100%, clamping society share"
    L4_2(L5_2, L6_2, L7_2, L8_2)
    L4_2 = 100
    L3_2 = L4_2 - L2_2
  end
  L4_2 = L2_2
  L5_2 = L3_2
  return L4_2, L5_2
end
GetPayoutSplit = L0_1
