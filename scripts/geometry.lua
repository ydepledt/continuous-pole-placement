-- Pure geometry: no Factorio globals, entity names, inventory or world access.
-- Supply areas are squares centred on entity positions. `supply` is the SUM
-- of the two half-side lengths; `wire` is the SMALLER of their wire reaches.
local geometry = {}
local EPSILON = 1e-9

local function finite(value)
  return type(value) == "number" and value == value
    and value ~= math.huge and value ~= -math.huge
end

local function position(value)
  return type(value) == "table" and finite(value.x) and finite(value.y)
end

local function limits(supply, wire)
  return finite(supply) and supply > 0 and finite(wire) and wire > 0
end

-- Necessary and sufficient for square intersection AND direct wire reach.
-- Physical collision/buildability is deliberately left to the game engine.
function geometry.connected(from, to, supply, wire)
  if not position(from) or not position(to) or not limits(supply, wire) then
    return false
  end
  local dx, dy = to.x - from.x, to.y - from.y
  return math.abs(dx) <= supply + EPSILON
    and math.abs(dy) <= supply + EPSILON
    and dx * dx + dy * dy <= wire * wire + EPSILON
end

-- Maximum Euclidean advance along a ray, before snapping to the build grid.
-- `delta` can be any nonzero vector: callers need not normalize it.
function geometry.continuous_limit(delta, supply, wire)
  if not position(delta) or not limits(supply, wire) then return nil end
  local length = math.sqrt(delta.x * delta.x + delta.y * delta.y)
  if not finite(length) then return nil end
  if length <= EPSILON then return 0 end
  return math.min(supply * length / math.max(math.abs(delta.x), math.abs(delta.y)), wire)
end

-- Grid offsets are absolute world-coordinate phases. Obtain them from the
-- actual first built pole, or from the prototype's odd/even tile dimensions.
-- Standard Factorio build grids have size 1 or 2. Off-grid prototypes need a
-- deliberate runtime fallback, rather than pretending their grid is size 1.
function geometry.snap(point, grid)
  if not position(point) or type(grid) ~= "table"
    or not finite(grid.size) or grid.size <= 0
    or not finite(grid.offset_x) or not finite(grid.offset_y) then return nil end
  return {
    x = grid.offset_x + grid.size * math.floor((point.x - grid.offset_x) / grid.size + 0.5),
    y = grid.offset_y + grid.size * math.floor((point.y - grid.offset_y) / grid.size + 0.5)
  }
end

-- Return the bounded sequence of nearest-grid positions reached by this ray,
-- furthest forward first. The caller can try ordinary placement at each point
-- until one succeeds. This never searches sideways around an obstacle.
--
-- Required: from, toward, supply, wire, grid={size,offset_x,offset_y}.
-- Optional: max_distance (advance available along the ray), backoff (default
-- 3 tiles), max_candidates (default 24, capped at 64).
-- Returns positions, metadata; invalid input returns {}, {reason=...}.
function geometry.candidates(options)
  if type(options) ~= "table" or not position(options.from)
    or not position(options.toward) or not limits(options.supply, options.wire)
    or not geometry.snap(options.from, options.grid) then
    return {}, {reason = "unsupported-geometry"}
  end
  local from, grid = options.from, options.grid
  local dx, dy = options.toward.x - from.x, options.toward.y - from.y
  local length = math.sqrt(dx * dx + dy * dy)
  if not finite(length) then return {}, {reason = "unsupported-geometry"} end
  if length <= EPSILON then return {}, {reason = "zero-direction"} end
  local ux, uy = dx / length, dy / length
  local limit = geometry.continuous_limit({x = dx, y = dy}, options.supply, options.wire)
  local maximum = options.max_distance
  if maximum == nil then maximum = math.huge end
  local backoff = options.backoff == nil and 3 or options.backoff
  local count = options.max_candidates == nil and 24 or options.max_candidates
  if (not finite(maximum) and maximum ~= math.huge) or maximum <= 0
    or not finite(backoff) or backoff < 0 or not finite(count) or count < 1 then
    return {}, {reason = "invalid-search-bounds"}
  end
  count = math.min(64, math.floor(count))

  -- Nearest snapping moves a point by at most half a grid-cell diagonal.
  -- Looking this far beyond the continuous limit includes the last valid
  -- snapped cell. Only a short interval behind it is traversed, regardless
  -- of supply radius or total cursor distance.
  local margin = grid.size / math.sqrt(2)
  local end_time = math.min(maximum, limit + margin)
  local start_time = math.max(0, math.min(maximum, limit) - backoff - 2 * margin)
  local result, seen = {}, {}

  local function add(time)
    local x_index = math.floor((from.x + ux * time - grid.offset_x) / grid.size + 0.5)
    local y_index = math.floor((from.y + uy * time - grid.offset_y) / grid.size + 0.5)
    local key = x_index .. ":" .. y_index
    if seen[key] then return end
    seen[key] = true
    local candidate = {x = grid.offset_x + x_index * grid.size, y = grid.offset_y + y_index * grid.size}
    local cx, cy = candidate.x - from.x, candidate.y - from.y
    local progress = cx * ux + cy * uy
    if progress > EPSILON and progress <= maximum + EPSILON
      and geometry.connected(from, candidate, options.supply, options.wire) then
      result[#result + 1] = {position = candidate, progress = progress,
        lateral = math.abs(cx * uy - cy * ux)}
    end
  end

  -- Descend through grid-cell boundaries (a short, exact digital ray walk).
  -- Sampling fixed intervals would miss very short cells near a diagonal.
  local function previous_boundary(origin, velocity, offset)
    if math.abs(velocity) <= EPSILON then return -math.huge, math.huge end
    local coordinate = (origin + velocity * end_time - offset) / grid.size
    local boundary
    if velocity > 0 then boundary = math.floor(coordinate - 0.5 + EPSILON) + 0.5
    else boundary = math.ceil(coordinate - 0.5 - EPSILON) + 0.5 end
    local time = (offset + boundary * grid.size - origin) / velocity
    local stride = grid.size / math.abs(velocity)
    if time > end_time + EPSILON then time = time - stride end
    return time, stride
  end
  local tx, sx = previous_boundary(from.x, ux, grid.offset_x)
  local ty, sy = previous_boundary(from.y, uy, grid.offset_y)
  local time = end_time
  add(time)
  for _ = 1, count * 4 + 8 do
    local boundary = math.max(tx, ty, start_time)
    if boundary < time - EPSILON then add((boundary + time) * 0.5) end
    if boundary <= start_time + EPSILON then break end
    if tx >= boundary - EPSILON then tx = tx - sx end
    if ty >= boundary - EPSILON then ty = ty - sy end
    time = boundary
  end
  table.sort(result, function(a, b)
    if a.progress ~= b.progress then return a.progress > b.progress end
    if a.lateral ~= b.lateral then return a.lateral < b.lateral end
    if a.position.x ~= b.position.x then return a.position.x < b.position.x end
    return a.position.y < b.position.y
  end)
  local positions = {}
  if result[1] then
    local furthest = result[1].progress
    for _, candidate in ipairs(result) do
      if #positions >= count then break end
      if furthest - candidate.progress <= backoff + EPSILON then
        positions[#positions + 1] = candidate.position
      end
    end
  end
  return positions, {limit = limit, direction = {x = ux, y = uy}, reason = #positions == 0 and "no-candidate" or nil}
end

return geometry
