vim.opt.runtimepath:prepend(vim.fn.getcwd())
local root = vim.fn.tempname() .. " lesik"
vim.fn.mkdir(root, "p")
local repo = root .. "/repo"
local tree = root .. "/feature tree"
local function run(args, cwd)
  local result = vim.system(args, { cwd = cwd, text = true }):wait()
  assert(result.code == 0, result.stderr)
end
local ok, err = pcall(function()
  run({ "git", "init", repo })
  run({ "git", "-c", "user.name=Test", "-c", "user.email=test@example.com", "-c", "commit.gpgsign=false", "commit", "--allow-empty", "-m", "Initial" }, repo)
  vim.api.nvim_set_current_dir(repo)
  local lesik = require("lesik")
  assert(#lesik.list() == 1)
  assert(lesik.worktree_dir() == repo .. "/.worktrees")
  lesik.setup({ worktree_dir = ".custom-worktrees" })
  assert(lesik.worktree_dir() == repo .. "/.custom-worktrees")
  lesik.setup({ worktree_dir = root .. "/shared" })
  assert(lesik.worktree_dir() == root .. "/shared")
  lesik.setup()
  local switched
  vim.api.nvim_create_autocmd("User", {
    pattern = "LesikSwitch",
    callback = function(event) switched = event.data end,
  })
  lesik.add(tree, "feature/test")
  assert(vim.fn.getcwd() == tree)
  assert(lesik.worktree_dir() == repo .. "/.worktrees")
  assert(switched.path == tree and switched.previous == repo)
  local items = lesik.list()
  assert(#items == 2 and items[2].branch == "feature/test")
  assert(not pcall(lesik.remove, tree), "Must refuse removing the current worktree")
  lesik.switch(repo)
  vim.fn.writefile({ "dirty" }, tree .. "/untracked")
  assert(not pcall(lesik.remove, tree), "Git must protect untracked files")
  vim.fn.delete(tree .. "/untracked")
  lesik.remove(tree)
  assert(#lesik.list() == 1)
  lesik.add(tree, "feature/test", { switch = false })
  assert(vim.fn.getcwd() == repo)
  run({ "git", "checkout", "--detach" }, tree)
  assert(lesik.list()[2].detached)
  lesik.remove(tree)
  local original_select, original_input = vim.ui.select, vim.ui.input
  local prompts = 0
  vim.ui.input = function(opts, callback)
    prompts = prompts + 1
    if prompts == 1 then
      callback("picker-feature")
    else
      assert(opts.default == repo .. "/.worktrees/picker-feature")
      callback(opts.default)
    end
  end
  vim.ui.select = function(items, _, callback)
    assert(items[#items - 1].label:find("Create"))
    assert(items[#items].label:find("Remove"))
    callback(items[#items - 1])
  end
  lesik.select()
  assert(vim.fn.getcwd() == repo .. "/.worktrees/picker-feature")
  lesik.switch(repo)
  vim.ui.select = function(items, _, callback)
    if items[#items].action then
      callback(items[#items])
    elseif type(items[1]) == "table" then
      callback(items[#items])
    else
      callback("Remove")
    end
  end
  lesik.select()
  assert(#lesik.list() == 1)
  vim.ui.select, vim.ui.input = original_select, original_input
  vim.cmd("runtime plugin/lesik.lua")
  assert(vim.fn.exists(":Lesik") == 2)
end)
vim.api.nvim_set_current_dir("/tmp")
vim.fn.delete(root, "rf")
if not ok then
  error(err)
end
print("lesik integration tests passed")
