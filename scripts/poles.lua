-- Runtime-only cache: the engine has already applied every mod's data stages.
-- Quality is part of the key because it can change BOTH electrical limits.
local M = {}
local cache = {}

function M.clear_cache() cache = {} end

local function positive(n)
  return type(n) == "number" and n > 0 and n < math.huge
end

function M.describe(prototype, quality)
  if not prototype or prototype.type ~= "electric-pole" then return nil end
  local quality_name = type(quality) == "string" and quality or quality.name
  local key = prototype.name .. "/" .. quality_name
  if cache[key] ~= nil then return cache[key] or nil end
  local supply = prototype.get_supply_area_distance(quality_name)
  local wire = prototype.get_max_wire_distance(quality_name)
  -- Despite the documented "log2" description, Factorio 2.0.77 returns the
  -- grid SIZE here: explicit build_grid_size=1 -> 1, =2 -> 2. Both values are
  -- covered by engine regression fixtures. Exponentiating over-spaces the
  -- search grid and loses valid maximal positions (small poles: 4 vs 5).
  local grid = prototype.building_grid_bit_shift
  -- Off-grid and nonstandard placement modes deliberately retain native behavior.
  if not positive(supply) or not positive(wire)
    or (grid ~= 1 and grid ~= 2)
    or prototype.has_flag("placeable-off-grid")
    or prototype.has_flag("building-direction-8-way") then
    cache[key] = false
    return nil
  end
  local result = {
    name = prototype.name, quality = quality_name,
    supply = supply, wire = wire,
    grid = grid,
    width = prototype.tile_width, height = prototype.tile_height
  }
  cache[key] = result
  return result
end

function M.cursor(player)
  local stack = player.cursor_stack
  if not stack or not stack.valid_for_read then return nil end
  local prototype = stack.prototype.place_result
  if not prototype or prototype.type ~= "electric-pole" then return nil end
  return M.describe(prototype, stack.quality), prototype
end

return M
