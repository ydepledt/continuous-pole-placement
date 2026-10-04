local M = {}

function M.get(index)
  storage.players = storage.players or {}
  local state = storage.players[index]
  if not state then
    state = {enabled = false}
    storage.players[index] = state
  end
  return state
end

function M.reset(index)
  local state = M.get(index)
  state.anchor = nil
  state.pending = nil
end

function M.sync(player)
  player.set_shortcut_toggled("cpp-toggle", M.get(player.index).enabled)
end

function M.toggle(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local state = M.get(player.index)
  state.enabled = not state.enabled
  M.reset(player.index)
  M.sync(player)
  player.create_local_flying_text{text = {state.enabled and "cpp.enabled" or "cpp.disabled"}, create_at_cursor = true}
end

return M
