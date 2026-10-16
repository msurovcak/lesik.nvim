if vim.g.loaded_lesik then
  return
end
vim.g.loaded_lesik = true

vim.api.nvim_create_user_command("Lesik", function(opts)
  require("lesik").command(opts.args)
end, {
  nargs = "?",
  desc = "Manage Git worktrees",
  complete = function()
    return { "list", "switch", "add", "remove" }
  end,
})
