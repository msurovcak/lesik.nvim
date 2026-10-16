# lesik.nvim

A small Git worktree manager for Neovim. Open Neovim inside a repository or
any of its worktrees, then create, remove, or switch worktrees with `:Lesik`.

Switching changes Neovim's global working directory using `:cd` semantics.
Telescope and other tools that use the current working directory will follow it.
Existing buffers stay open; windows or tabs with their own local working
directories can still override the global directory. Tools with explicitly
configured roots may need their own configuration.

Requires Neovim 0.10+ and Git 2.31+. No plugin dependencies. Pickers use
`vim.ui.select` and `vim.ui.input`, so your preferred UI plugin can enhance them.

Install with lazy.nvim:

```lua
{ "msurovcak/lesik.nvim" }
```

No setup is required. Optional keymaps:

```lua
vim.keymap.set("n", "<leader>ww", "<cmd>Lesik<cr>")
vim.keymap.set("n", "<leader>wa", "<cmd>Lesik add<cr>")
vim.keymap.set("n", "<leader>wd", "<cmd>Lesik remove<cr>")
```

The `:Lesik` picker includes **Create worktree…** and **Remove worktree…**
actions alongside the worktrees. Select Create to enter a branch and confirm
the destination path; select Remove to pick a worktree and confirm deletion.

New worktrees default to `<main-repository>/.worktrees/<branch>`, with `/` in
branch names replaced by `-`. The path prompt is editable. Relative directory
configuration always resolves from the main repository, including when Neovim
starts inside a linked worktree.

To configure this per project, enable Neovim's local configuration in your
regular `init.lua`:

```lua
vim.opt.exrc = true
```

Then put this in the repository's `.nvim.lua`:

```lua
require("lesik").setup({
  worktree_dir = ".worktrees", -- relative to the main repository, or an absolute path
})
```

Neovim asks you to trust local configuration before executing it. Ensure the
plugin is available when `.nvim.lua` runs (the lazy.nvim installation above
loads it at startup). Local configuration loads when starting Neovim;
switching worktrees does not source another `.nvim.lua`. Commit `.nvim.lua` to
share it with new worktrees, and add `.worktrees/` to the repository's
`.gitignore` or `.git/info/exclude` so Git and search tools can ignore nested
worktrees. The plugin does not edit these files for you.

| Command | Action |
| --- | --- |
| `:Lesik` / `:Lesik switch` / `:Lesik list` | Pick a worktree and change directory |
| `:Lesik add` | Enter a branch and path, create the worktree, then switch to it |
| `:Lesik remove` | Pick a worktree and confirm removal |

Creation reuses an existing local branch or creates a new branch from HEAD.
Git refuses branches already checked out elsewhere. Removal keeps the branch,
never forces deletion, and refuses to remove your current worktree. Switch to
another worktree first. Git also protects dirty, locked, and main worktrees.

The Lua API raises errors on failure; interactive commands display errors as
notifications:

```lua
local lesik = require("lesik")
lesik.list() -- { { path = "...", branch = "main", head = "..." }, ... }
lesik.switch("/path/to/worktree")
lesik.add("/path/to/feature", "feature", { switch = true })
lesik.add("/path/to/other", "other", { start_point = "main", switch = false })
lesik.remove("/path/to/other")
```

`list(cwd)`, `remove(path, cwd)`, and `add(path, branch, { cwd = ... })` can
target a repository explicitly. Absolute paths are recommended.

After switching, the `User LesikSwitch` autocmd exposes `event.data.path` and
`event.data.previous`. Neovim also emits its normal directory change events.

Run integration tests with:

```sh
nvim --headless -u NONE --cmd 'set rtp+=.' -l tests/worktrees.lua
```

Licensed under the [MIT License](LICENSE).
