local M = {}
local config = { worktree_dir = ".worktrees" }

local function git(args, cwd)
  local command = { "git" }
  vim.list_extend(command, args)
  local result = vim.system(command, { cwd = cwd or vim.fn.getcwd(), text = true }):wait()
  if result.code ~= 0 then
    error(vim.trim(result.stderr or "Git command failed"), 0)
  end
  return result.stdout
end

local function notify_error(err)
  vim.notify(tostring(err), vim.log.levels.ERROR, { title = "lesik" })
end

local function protected(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then
      notify_error(err)
    end
  end
end

---Return worktrees for the repository containing cwd.
---@param cwd? string
---@return table[]
function M.list(cwd)
  local output = git({ "worktree", "list", "--porcelain", "-z" }, cwd)
  local items, item = {}, nil
  for field in output:gmatch("([^%z]+)%z") do
    local key, value = field:match("^(%S+)%s?(.*)$")
    if key == "worktree" then
      item = { path = value }
      items[#items + 1] = item
    elseif item then
      if key == "branch" then
        item.branch = value:gsub("^refs/heads/", "")
      elseif key == "HEAD" then
        item.head = value
      elseif key == "bare" or key == "detached" or key == "locked" or key == "prunable" then
        item[key] = value ~= "" and value or true
      end
    end
  end
  return items
end

---Change Neovim's global working directory and emit User LesikSwitch.
---@param path string
function M.switch(path)
  local previous = vim.fn.getcwd()
  vim.api.nvim_set_current_dir(vim.fn.fnamemodify(path, ":p"))
  vim.api.nvim_exec_autocmds("User", {
    pattern = "LesikSwitch",
    data = { path = vim.fn.getcwd(), previous = previous },
  })
end

---Create a worktree from an existing branch, or create a new branch from HEAD.
---@param path string
---@param branch string
---@param opts? {cwd?: string, start_point?: string, switch?: boolean}
function M.add(path, branch, opts)
  opts = opts or {}
  if not path or path == "" or not branch or branch == "" then
    error("A worktree path and branch are required", 0)
  end
  git({ "check-ref-format", "--branch", branch }, opts.cwd)
  local exists = pcall(git, { "show-ref", "--verify", "--quiet", "refs/heads/" .. branch }, opts.cwd)
  local args = { "worktree", "add" }
  if not exists then
    vim.list_extend(args, { "-b", branch })
  end
  vim.list_extend(args, { "--", path, exists and branch or (opts.start_point or "HEAD") })
  git(args, opts.cwd)
  if opts.switch ~= false then
    M.switch(path)
  end
end

---Remove a worktree without forcing deletion or deleting its branch.
---@param path string
---@param cwd? string
function M.remove(path, cwd)
  local current = vim.fn.resolve(vim.fn.getcwd())
  local target = vim.fn.resolve(vim.fn.fnamemodify(path, ":p")):gsub("/+$", "")
  if current == target or current:sub(1, #target + 1) == target .. "/" then
    error("Switch out of this worktree before removing it", 0)
  end
  git({ "worktree", "remove", "--", path }, cwd)
end

local function pick(prompt, callback, actions)
  local items = vim.tbl_filter(function(item)
    return not item.bare
  end, M.list())
  for _, action in ipairs(actions or {}) do
    items[#items + 1] = action
  end
  vim.ui.select(items, {
    prompt = prompt,
    format_item = function(item)
      if item.label then
        return item.label
      end
      return (item.branch or "detached") .. "  " .. item.path .. (item.locked and " [locked]" or "")
    end,
  }, protected(function(item)
    if item then
      callback(item)
    end
  end))
end

function M.select()
  pick("Worktrees", function(item)
    if item.action then
      item.action()
    else
      M.switch(item.path)
    end
  end, {
    { label = "+ Create worktree…", action = M.create },
    { label = "− Remove worktree…", action = M.delete },
  })
end

---Resolve the configured directory relative to the main repository, even from a linked worktree.
---@param cwd? string
---@return string
function M.worktree_dir(cwd)
  local root = M.list(cwd)[1].path
  local path = vim.fn.expand(config.worktree_dir)
  if path:sub(1, 1) ~= "/" and not path:match("^%a:[/\\]") then
    path = root .. "/" .. path
  end
  return vim.fs.normalize(path)
end

function M.create()
  -- Capture the repository in case the user changes directories while the UI is open.
  local cwd = vim.fn.getcwd()
  local parent = M.worktree_dir(cwd)
  vim.ui.input({ prompt = "Worktree branch: " }, protected(function(branch)
    if not branch or branch == "" then
      return
    end
    vim.ui.input({
      prompt = "Worktree path: ",
      default = parent .. "/" .. branch:gsub("/", "-"),
      completion = "dir",
    }, protected(function(path)
      if path and path ~= "" then
        M.add(vim.fn.fnamemodify(path, ":p"), branch, { cwd = cwd })
      end
    end))
  end))
end

function M.delete()
  local cwd = vim.fn.getcwd()
  pick("Remove worktree", function(item)
    vim.ui.select({ "Cancel", "Remove" }, {
      prompt = "Remove " .. item.path .. "? (branch is kept)",
    }, protected(function(choice)
      if choice == "Remove" then
        M.remove(item.path, cwd)
        vim.notify("Removed " .. item.path, vim.log.levels.INFO, { title = "lesik" })
      end
    end))
  end)
end

---Configure defaults, including from a repository's .nvim.lua.
---@param opts? {worktree_dir?: string}
function M.setup(opts)
  opts = opts or {}
  local directory = opts.worktree_dir or ".worktrees"
  if type(directory) ~= "string" or directory == "" then
    error("worktree_dir must be a non-empty string", 0)
  end
  config = { worktree_dir = directory }
end

M.command = protected(function(action)
  local actions = { list = M.select, switch = M.select, add = M.create, remove = M.delete }
  local fn = actions[action ~= "" and action or "switch"]
  if not fn then
    error("Usage: Lesik [list|switch|add|remove]", 0)
  end
  fn()
end)

return M
