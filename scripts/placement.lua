local geometry = require("scripts.geometry")
local poles = require("scripts.poles")
local states = require("scripts.state")
local M = {}

-- build_from_cursor raises both build events synchronously. This guard is
-- intentionally transient: it must never survive a save or a failed stroke.
local building = {}

local function existing_anchor(player, descriptor, point)
  if not point then return nil end
  local existing = player.surface.find_entity(
    {name = descriptor.name, quality = descriptor.quality}, point)
  if not existing or not existing.valid or existing.force ~= player.force then return nil end
  local position = existing.position
  local snapped = geometry.snap(point,
    {size = descriptor.grid, offset_x = position.x, offset_y = position.y})
  if snapped.x == position.x and snapped.y == position.y then return existing end
end

function M.begin_build(event)
  if building[event.player_index] then return end
  local state = states.get(event.player_index)
  if not state.enabled then return end
  local player = game.get_player(event.player_index)
  local descriptor = player and poles.cursor(player)
  state.anchor = descriptor and existing_anchor(player, descriptor, event.cursor_position) or nil
  state.pending = nil
end

local function warn(player, state, key)
  if not state.last_warning or game.tick - state.last_warning >= 180 then
    player.create_local_flying_text{text = {key}, create_at_cursor = true}
    state.last_warning = game.tick
  end
end

local function build(player, position, direction)
  local spec = {position = position, direction = direction, build_mode = defines.build_mode.normal}
  if not player.can_build_from_cursor(spec) then return false end
  local state = states.get(player.index)
  local previous = state.anchor
  building[player.index] = true
  player.build_from_cursor(spec)
  building[player.index] = nil
  local current = state.anchor
  if not current or not current.valid or current == previous then return false end
  if previous and previous.valid then
    local a = poles.describe(previous.prototype, previous.quality)
    local b = poles.describe(current.prototype, current.quality)
    if not a or not b or not geometry.connected(previous.position, current.position,
      a.supply + b.supply, math.min(a.wire, b.wire)) then
      warn(player, state, "cpp.blocked")
      return true -- Do not destroy/duplicate an item if another mod moved it.
    end
    -- Some modded poles disable automatic copper connections. Ask the engine
    -- for a real, range-checked connection; never bypass its connection rules.
    local source = previous.get_wire_connector(defines.wire_connector_id.pole_copper, true)
    local target = current.get_wire_connector(defines.wire_connector_id.pole_copper, true)
    if source and target and not source.is_connected_to(target) then
      source.connect_to(target, true)
    end
    if previous.electric_network_id ~= current.electric_network_id then
      warn(player, state, "cpp.connection-blocked")
    end
  end
  return true
end

function M.pre_build(event)
  local index = event.player_index
  if building[index] then return end
  local state = states.get(index)
  if not state.enabled then return end
  local player = game.get_player(index)
  if not player then return end
  -- Ghost/blueprint/force placement stays native. Never clear or swap a stack.
  local descriptor, prototype = poles.cursor(player)
  if not descriptor or event.build_mode ~= defines.build_mode.normal then
    state.anchor = nil
    state.pending = nil
    if prototype and not descriptor then warn(player, state, "cpp.unsupported") end
    return
  end
  state.pending = {tick = event.tick, name = descriptor.name, quality = descriptor.quality}
  if not event.created_by_moving then
    -- Extending a line often starts by clicking its existing end pole. A
    -- single point lookup avoids putting an unnecessary pole one tile away.
    state.anchor = existing_anchor(player, descriptor, event.position)
    return -- The initial click is built entirely by Factorio.
  end
  local anchor = state.anchor
  if anchor and (not anchor.valid or anchor.surface ~= player.surface
    or anchor.force ~= player.force or anchor.name ~= descriptor.name
    or anchor.quality.name ~= descriptor.quality) then
    anchor = nil
    state.anchor = nil
  end
  if not anchor then
    -- This also starts promptly when ON is selected during an existing drag.
    build(player, event.position, event.direction)
    return
  end
  local origin = anchor.position
  local delta = {x = event.position.x - origin.x, y = event.position.y - origin.y}
  local length = math.sqrt(delta.x * delta.x + delta.y * delta.y)
  if length < descriptor.grid then return end
  -- No grid candidate at the boundary can be this close in any direction.
  -- Particularly useful for modded poles with very large supply squares.
  if length < math.min(descriptor.supply * 2, descriptor.wire)
    - descriptor.grid * math.sqrt(2) then return end
  local candidates, metadata = geometry.candidates{
    from = origin, toward = event.position,
    supply = descriptor.supply * 2, wire = descriptor.wire,
    grid = {size = descriptor.grid, offset_x = origin.x, offset_y = origin.y},
    backoff = 3, max_candidates = 12
  }
  if not candidates[1] then return end
  local direction = metadata.direction
  local first = candidates[1]
  local required = (first.x - origin.x) * direction.x + (first.y - origin.y) * direction.y
  if length + 1e-9 < required then return end
  -- Bounded local backoff on the snapped ray; normal native collision, reach,
  -- surface conditions, item consumption and events are retained.
  for _, candidate in ipairs(candidates) do
    if build(player, candidate, event.direction) then return end
  end
  if not geometry.connected(origin, event.position, descriptor.supply * 2, descriptor.wire) then
    warn(player, state, "cpp.blocked")
  end
end

function M.built(event)
  local state = states.get(event.player_index)
  if not state.enabled then return end
  local entity = event.entity
  if not entity or not entity.valid or entity.type ~= "electric-pole" then return end
  local pending = state.pending
  if not pending or pending.tick ~= event.tick or pending.name ~= entity.name
    or pending.quality ~= entity.quality.name then return end
  state.anchor = entity
end

function M.cursor_changed(event)
  if building[event.player_index] then return end
  local state = states.get(event.player_index)
  if not state.enabled or not state.anchor then return end
  local player = game.get_player(event.player_index)
  local descriptor = player and poles.cursor(player)
  local anchor = state.anchor
  if not descriptor or not anchor.valid or anchor.name ~= descriptor.name
    or anchor.quality.name ~= descriptor.quality then states.reset(event.player_index) end
end

return M
