-- Run from the mod root with Lua 5.2+; no Factorio globals are needed.
local geometry = require("scripts.geometry")
local assertions = 0
local function check(condition, message)
  assertions = assertions + 1
  assert(condition, message)
end
local function close(actual, expected, message)
  check(actual and math.abs(actual - expected) < 1e-7, message or (tostring(actual) .. " ~= " .. expected))
end
local function same(actual, x, y, message)
  check(actual and actual.x == x and actual.y == y, message or "unexpected snapped position")
end
local function candidates(dx, dy, supply, wire, phase, extras)
  local options = {
    from = {x = phase or 0, y = phase or 0},
    toward = {x = (phase or 0) + dx, y = (phase or 0) + dy},
    supply = supply, wire = wire,
    grid = {size = 1, offset_x = phase or 0, offset_y = phase or 0}
  }
  for key, value in pairs(extras or {}) do options[key] = value end
  return geometry.candidates(options)
end

-- Static vanilla fixtures verify expected geometry, never select prototypes
-- in the production module. Each fixture is normal quality on a clear map.
local fixtures = {
  {name = "small", supply = 5, wire = 7.5, phase = 0.5, axis = 5, diagonal = 5},
  {name = "medium", supply = 7, wire = 9, phase = 0.5, axis = 7, diagonal = 6},
  {name = "big", supply = 4, wire = 32, phase = 0, axis = 4, diagonal = 4},
  {name = "substation", supply = 18, wire = 18, phase = 0, axis = 18, diagonal = 12}
}
for _, fixture in ipairs(fixtures) do
  for _, direction in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {-1, 1}, {1, -1}, {-1, -1}}) do
    local dx, dy = direction[1], direction[2]
    local spacing = dx ~= 0 and dy ~= 0 and fixture.diagonal or fixture.axis
    local positions = candidates(dx, dy, fixture.supply, fixture.wire, fixture.phase)
    same(positions[1], fixture.phase + dx * spacing, fixture.phase + dy * spacing, fixture.name)
    for _, point in ipairs(positions) do
      check(geometry.connected({x = fixture.phase, y = fixture.phase}, point, fixture.supply, fixture.wire), "constraint violated")
    end
  end
end

close(geometry.continuous_limit({x = 1, y = 0}, 5, 7.5), 5)
close(geometry.continuous_limit({x = 1, y = 1}, 5, 7.5), 5 * math.sqrt(2))
close(geometry.continuous_limit({x = 1, y = 1}, 18, 18), 18)
close(geometry.continuous_limit({x = 100, y = 100}, 18, 18), 18, "direction normalization")
check(not geometry.connected({x = 0, y = 0}, {x = 5.01, y = 0}, 5, 100), "supply gap accepted")
check(not geometry.connected({x = 0, y = 0}, {x = 7, y = 7}, 7, 9), "wire overreach accepted")
check(geometry.connected({x = 0, y = 0}, {x = 5, y = 5}, 5, 7.5), "corner contact rejected")

-- Quality and modded values are ordinary parameters, including a much lower
-- wire reach than supply size, fractional radii, and the maximum base radius.
same(candidates(1, 0, 15, 17.5, 0.5)[1], 15.5, 0.5, "quality-like radius")
same(candidates(1, 0, 128, 3)[1], 3, 0, "wire-limited modded pole")
same(candidates(1, 0, 4.75, 64)[1], 4, 0, "fractional supply radius")
same(candidates(1, 0, 128, 64)[1], 64, 0, "large radius")
same(candidates(1, 0, 18, 18, 0, {grid = {size = 2, offset_x = 0, offset_y = 0}})[1], 18, 0, "two-tile grid")
same(candidates(0, 1, 7, 9, 0, {grid = {size = 1, offset_x = 0.5, offset_y = 0}})[1], 0.5, 7, "mixed parity footprint")
same(candidates(1, 0, 5, 7.5, 0.5, {max_distance = 3.1})[1], 3.5, 0.5, "available distance")

-- An obstacle is modeled by rejecting the first candidate. Remaining points
-- stay on the same digital ray, in range, and within the bounded backoff.
local alternatives = candidates(1, 0, 5, 7.5, 0.5)
same(alternatives[1], 5.5, 0.5)
same(alternatives[2], 4.5, 0.5, "nearest earlier placement")
same(alternatives[#alternatives], 2.5, 0.5, "three-tile backoff")
check(#candidates(1, 0, 5, 7.5, 0.5, {backoff = 0}) == 1, "zero backoff")
check(#candidates(1, 1, 128, 64, 0, {backoff = 100, max_candidates = 2}) <= 2, "candidate bound")

-- Gentle turns preserve lattice positions and both invariants across every
-- octant. A tiny mouse wobble on a cardinal line retains the optimal spacing.
for _, wobble in ipairs({-0.005, -0.0001, 0, 0.0001, 0.005}) do
  same(candidates(1, wobble, 5, 7.5, 0.5)[1], 5.5, 0.5, "cardinal wobble")
end

-- Independent oracle: enumerate every integer point in a small supply square
-- and intersect its rounding cell with the ray. This proves the first result
-- has maximal advance on the snapped path, instead of just checking bounds.
local function exhaustive_best_progress(ux, uy, supply, wire)
  local best = 0
  for x = -math.ceil(supply), math.ceil(supply) do
    for y = -math.ceil(supply), math.ceil(supply) do
      if math.abs(x) <= supply and math.abs(y) <= supply and x*x + y*y <= wire*wire then
        local low, high = 0, math.huge
        for _, axis in ipairs({{x, ux}, {y, uy}}) do
          local value, velocity = axis[1], axis[2]
          if math.abs(velocity) < 1e-10 then
            if math.abs(value) > 0.5 then high = -1 end
          else
            local a, b = (value - 0.5) / velocity, (value + 0.5) / velocity
            low = math.max(low, math.min(a, b))
            high = math.min(high, math.max(a, b))
          end
        end
        if high > low + 1e-9 then best = math.max(best, x*ux + y*uy) end
      end
    end
  end
  return best
end
for degrees = 0, 359 do
  local angle = degrees * math.pi / 180
  local dx, dy = math.cos(angle), math.sin(angle)
  local positions = candidates(dx, dy, 7, 9, 0.5)
  check(#positions > 0, "missing direction " .. degrees)
  close((positions[1].x - 0.5)*dx + (positions[1].y - 0.5)*dy,
    exhaustive_best_progress(dx, dy, 7, 9), "not maximal on snapped ray " .. degrees)
  local previous = math.huge
  for _, point in ipairs(positions) do
    local progress = (point.x - 0.5) * dx + (point.y - 0.5) * dy
    check(progress <= previous + 1e-8, "not furthest first")
    check(geometry.connected({x = 0.5, y = 0.5}, point, 7, 9), "turn gap")
    previous = progress
  end
end

-- Translation and sign symmetry include negative map coordinates.
local translated = geometry.candidates{
  from = {x = -1000.5, y = -72.5}, toward = {x = -999.5, y = -72.5},
  supply = 5, wire = 7.5, grid = {size = 1, offset_x = 0.5, offset_y = 0.5}
}
same(translated[1], -995.5, -72.5, "negative world coordinates")

check(#candidates(0, 0, 5, 7.5) == 0, "zero direction")
check(#candidates(1, 0, 0, 7.5) == 0, "zero radius")
check(#candidates(1, 0, 5, 0) == 0, "zero wire")
check(#candidates(1, 0, 5, 7.5, 0, {grid = {size = 0, offset_x = 0, offset_y = 0}}) == 0, "invalid grid")
check(#candidates(1, 0, 5, 7.5, 0, {max_distance = -1}) == 0, "negative distance")
check(#geometry.candidates(nil) == 0, "invalid options")
check(not geometry.connected({x = 0, y = 0}, {x = 0/0, y = 1}, 5, 7.5), "NaN accepted")
print("geometry_spec: " .. assertions .. " assertions passed")
return assertions
