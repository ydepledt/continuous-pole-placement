data:extend({
  {
    type = "custom-input",
    name = "cpp-toggle",
    key_sequence = "ALT + P",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "cpp-begin-build",
    key_sequence = "",
    linked_game_control = "build",
    consuming = "none"
  },
  {
    type = "shortcut",
    name = "cpp-toggle",
    action = "lua",
    toggleable = true,
    associated_control_input = "cpp-toggle",
    icon = "__continuous-pole-placement__/graphics/shortcut.png",
    icon_size = 32,
    small_icon = "__continuous-pole-placement__/graphics/shortcut-small.png",
    small_icon_size = 24,
    order = "p[continuous-pole-placement]"
  }
})
