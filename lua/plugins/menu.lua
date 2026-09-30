return {
  "nvzone/menu",
  -- popup menu UI (nested menus, keyboard or mouse). API-only: nothing to trigger it with, so it
  -- stays lazy and lazy.nvim's module searcher picks it up on the first require("menu")
  lazy = true,
  -- volt is the UI library menu draws with
  dependencies = { "nvzone/volt" },
}
