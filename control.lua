local states = require("scripts.state")
local poles = require("scripts.poles")
local placement = require("scripts.placement")

local function initialize()
  poles.clear_cache()
  for _, player in pairs(game.players) do
    states.reset(player.index)
    states.sync(player)
  end
end

script.on_init(initialize)
script.on_configuration_changed(initialize)
-- storage preserves each player's ON/OFF state and valid entity anchor.
-- No on_load mutation and no tick subscription are necessary.
script.on_event("cpp-toggle", states.toggle)
-- The linked control also fires when clicking an existing pole (a case in
-- which Factorio may omit on_pre_build). It follows the user's build binding.
script.on_event("cpp-begin-build", placement.begin_build)
script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name == "cpp-toggle" then states.toggle(event) end
end)
script.on_event(defines.events.on_player_created, function(event)
  states.sync(game.get_player(event.player_index))
end)
script.on_event(defines.events.on_player_joined_game, function(event)
  states.reset(event.player_index)
  states.sync(game.get_player(event.player_index))
end)
script.on_event(defines.events.on_player_removed, function(event)
  if storage.players then storage.players[event.player_index] = nil end
end)
script.on_event({defines.events.on_player_changed_surface,
  defines.events.on_player_controller_changed, defines.events.on_player_died,
  defines.events.on_player_left_game}, function(event) states.reset(event.player_index) end)
script.on_event(defines.events.on_pre_build, placement.pre_build)
script.on_event(defines.events.on_built_entity, placement.built, {{filter = "type", type = "electric-pole"}})
script.on_event(defines.events.on_player_cursor_stack_changed, placement.cursor_changed)
