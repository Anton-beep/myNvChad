-- Small numeric helpers shared across configs.

local M = {}

--- Clamp v into [lo, hi]
local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

M.clamp = clamp

return M
