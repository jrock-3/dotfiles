# dotfiles

Personal development environment for macOS and Linux. One command sets up Zsh, Neovim, Tmux, Git, and a curated set of CLI tools — on a fresh OS or on top of existing configs.

## Quick start

```bash
# Remote install (clones to ~/git-repos/dotfiles)
bash <(curl -fsSL https://raw.githubusercontent.com/jrock-3/dotfiles/main/install.sh)

# Or clone + install manually
git clone https://github.com/jrock-3/dotfiles.git ~/git-repos/dotfiles
bash ~/git-repos/dotfiles/install.sh
```

The installer is **fully idempotent** — re-running skips everything already in place.

## Repository layout

```
dotfiles/
├── install.sh           # cross-platform installer (macOS + Linux)
├── zshrc                # → ~/.zshrc
├── tmux.conf            # → ~/.config/tmux/tmux.conf
├── gitignore_global     # → ~/.gitignore_global
├── nvim/                # → ~/.config/nvim  (kickstart.nvim-based)
│   ├── init.lua         #    entry point: leader key, module loading
│   ├── lua/
│   │   ├── options.lua          # editor options (line numbers, undo, splits, etc.)
│   │   ├── keymaps.lua          # all non-plugin keybindings
│   │   ├── lazy-bootstrap.lua   # lazy.nvim bootstrap
│   │   ├── lazy-plugins.lua     # plugin specs (loads kickstart/ + custom/)
│   │   ├── netrw-setup.lua      # netrw file browser config
│   │   ├── kickstart/
│   │   │   └── plugins/         # kickstart default plugins (telescope, lsp, treesitter, …)
│   │   └── custom/
│   │       ├── terminal.lua     # floating terminal (Ctrl-z toggle)
│   │       └── plugins/
│   │           ├── init.lua     # undotree, netrw.nvim, vimtex
│   │           ├── tmux.lua     # nvim-tmux-navigator (Ctrl-hjkl)
│   │           └── obsidian.lua # obsidian.nvim (~/notes vault)
│   └── ftplugin/
│       └── markdown.lua         # markdown-specific settings
└── README.md
```

## What gets installed

| Tool | macOS | Linux | Purpose |
|------|-------|-------|---------|
| [Neovim](https://neovim.io) | Homebrew | AppImage / pkg mgr | Editor |
| [Tmux](https://github.com/tmux/tmux) | Homebrew | apt/dnf/pacman | Terminal multiplexer |
| [Oh My Zsh](https://ohmyz.sh) | curl | curl | Zsh framework |
| [Oh My Posh](https://ohmyposh.dev) | Homebrew | curl | Prompt theme engine |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | OMZ plugin | OMZ plugin | Fish-like suggestions |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | Homebrew | apt/dnf/pacman | Command highlighting |
| [eza](https://github.com/eza-community/eza) | Homebrew | binary | Modern `ls` |
| [btop](https://github.com/aristocratos/btop) | Homebrew | apt/dnf/pacman | Resource monitor |
| [lazygit](https://github.com/jesseduffield/lazygit) | Homebrew | binary | Git TUI |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Homebrew | binary/pkg mgr | Smart `cd` |
| [fzf](https://github.com/junegunn/fzf) | Homebrew | apt/dnf/pacman | Fuzzy finder |
| [NVM](https://github.com/nvm-sh/nvm) + Node LTS | curl | curl | Node version manager |
| [TPM](https://github.com/tmux-plugins/tpm) | git clone | git clone | Tmux plugin manager |

On macOS, [Homebrew](https://brew.sh) is installed automatically if missing.

## What gets symlinked

| Source (repo) | Destination | Backs up existing? |
|---------------|-------------|--------------------|
| `nvim/` | `~/.config/nvim` | Yes |
| `tmux.conf` | `~/.config/tmux/tmux.conf` | Yes |
| `zshrc` | `~/.zshrc` | Yes |
| `gitignore_global` | `~/.gitignore_global` | Yes |

Pre-existing files are moved to `~/.dotfiles-backup/<timestamp>/` — nothing is deleted.

## Installer options

| Variable | Default | Description |
|----------|---------|-------------|
| `DOTFILES_DIR` | `~/git-repos/dotfiles` | Clone target (remote install only) |
| `SKIP_DEPS` | *(unset)* | Set to skip dependency install, symlink only |

```bash
SKIP_DEPS=1 bash install.sh                         # symlink only
DOTFILES_DIR=~/dotfiles bash install.sh              # custom clone path
```

---

## Zsh (`zshrc`)

### Load order

```
PATH → terminal settings → Oh My Zsh → syntax highlighting → Oh My Posh → editor → aliases → tools → fzf → NVM (lazy) → optional integrations
```

### Prompt

[Oh My Posh](https://ohmyposh.dev) with the **Catppuccin Mocha** theme. Falls back to `robbyrussell` if Oh My Posh is not installed.

### Aliases

| Alias | Expands to | Notes |
|-------|-----------|-------|
| `nv` | `nvim` | |
| `c` | `clear` | |
| `clip` | `pbcopy` | macOS clipboard pipe |
| `t` | `tmux attach \|\| tmux new` | Attach or create tmux session |
| `l` | `eza -la --icons …` | Only if `eza` is installed |
| `lg` | `lazygit` | Only if `lazygit` is installed |
| `mktemp` | `gmktemp` | Only if `gmktemp` is installed (macOS) |
| `z` | zoxide jump | Via `zoxide init zsh` |

### fzf integration

Shell keybindings are loaded automatically when `fzf` is available:

| Binding | Action |
|---------|--------|
| `Ctrl-R` | Fuzzy search command history |
| `Ctrl-T` | Fuzzy file finder (inserts path inline) |
| `Alt-C` | Fuzzy `cd` into subdirectories |

Colors use the **Catppuccin Mocha** palette for consistency.

### NVM lazy loading

NVM is lazy-loaded via shell function wrappers — `nvm`, `node`, `npm`, and `npx` load NVM on first invocation. This eliminates the ~300-500ms startup penalty of eager NVM loading.

### Plugins (via Oh My Zsh)

- `git` — git aliases and completions
- `zsh-autosuggestions` — fish-like inline suggestions (right-arrow to accept)

---

## Tmux (`tmux.conf`)

### Prefix key

| Context | Prefix |
|---------|--------|
| Local | `Ctrl-a` |
| Over SSH | `Ctrl-b` |

This avoids conflicts when nesting tmux sessions via SSH.

### Navigation

| Binding | Action |
|---------|--------|
| `prefix h/j/k/l` | Select pane (vim-style) |
| `prefix M-h/j/k/l` | Resize pane by 5 cells |
| `prefix %` | Vertical split (inherits cwd) |
| `prefix "` | Horizontal split (inherits cwd) |
| `prefix r` | Reload config |

### Popups (all centered, 80%×75%)

| Binding | Action |
|---------|--------|
| `prefix Ctrl-j` | Switch session (fzf) |
| `prefix Ctrl-f` | Switch window (fzf) |
| `prefix Ctrl-t` | Toggle popup terminal session |
| `prefix Ctrl-g` | Lazygit in popup |
| `prefix Ctrl-o` | btop in popup |

### Copy mode

Vi-style (`mode-keys vi`). Press `v` to begin selection. Uses `tmux-yank` for system clipboard integration.

### Session persistence

[tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) + [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum):

- Sessions auto-save every 10 minutes
- Auto-restore last session on tmux start
- Pane contents are captured

### Plugins (via TPM)

| Plugin | Purpose |
|--------|---------|
| `tmux-plugins/tpm` | Plugin manager |
| `christoomey/vim-tmux-navigator` | Seamless Ctrl-hjkl between tmux panes and nvim splits |
| `tmux-plugins/tmux-sensible` | Sensible defaults |
| `tmux-plugins/tmux-resurrect` | Save/restore sessions |
| `tmux-plugins/tmux-continuum` | Auto-save sessions |
| `tmux-plugins/tmux-yank` | System clipboard in copy mode |
| `catppuccin/tmux` | Catppuccin Mocha theme, top status bar |

Install plugins after setup: `prefix + I` inside tmux.

### Theme

Catppuccin Mocha with status bar at top. Status right shows the current application name. Window tabs use rounded style with window name and number.

---

## Neovim (`nvim/`)

Based on [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) with [lazy.nvim](https://github.com/folke/lazy.nvim) for plugin management.

### Key settings (`options.lua`)

| Option | Value | Why |
|--------|-------|-----|
| Line numbers | relative | Jump with `<count>j/k` |
| Clipboard | `unnamedplus` | Synced with OS clipboard |
| Swap/backup | off | Git handles versioning |
| Undo | persistent (`~/.vim/undodir`) | Survives restarts |
| Search | `ignorecase` + `smartcase` | Case-insensitive unless uppercase used |
| Color column | 80 | Visual line-length guide |
| Splits | right / below | Natural split direction |
| Scroll offset | 10 lines | Cursor never hits edge |
| Whitespace | visible tabs, trailing spaces, nbsp | Spot formatting issues |
| Inccommand | `split` | Live substitution preview |

### Keybindings (`keymaps.lua`)

**Leader key**: `Space`

| Binding | Mode | Action |
|---------|------|--------|
| `Esc` | n | Clear search highlight |
| `[d` / `]d` | n | Prev/next diagnostic |
| `<leader>e` | n | Show diagnostic float |
| `<leader>q` | n | Diagnostics → quickfix list |
| `Ctrl-h/j/k/l` | n | Window navigation (overridden by tmux-navigator) |
| `Alt-h/l/k/j` | n | Resize window |
| `Alt-=` | n | Equalize window sizes |
| `n` / `N` | n | Next/prev search result (centered) |
| `<leader>st` | n | Open netrw file tree |
| `<leader>u` | n | Toggle Undotree |
| `Ctrl-z` | n/t | Toggle floating terminal |
| `Esc Esc` | t | Exit terminal mode |
| Arrow keys | n | Disabled (prints hjkl reminder) |

### Plugin stack

| Plugin | Purpose |
|--------|---------|
| `vim-sleuth` | Auto-detect indent settings |
| `Comment.nvim` | `gc` to comment lines/regions |
| `gitsigns.nvim` | Git signs in gutter, hunk navigation |
| `which-key.nvim` | Shows available keybindings after leader |
| `telescope.nvim` | Fuzzy finder for files, grep, buffers, etc. |
| `nvim-lspconfig` + Mason | LSP setup (auto-installs servers) |
| `conform.nvim` | Auto-formatting |
| `nvim-cmp` | Autocompletion |
| `catppuccin` | Color scheme (Mocha) |
| `todo-comments` | Highlight TODO/FIXME/NOTE in code |
| `mini.nvim` | Statusline, surround, and utilities |
| `nvim-treesitter` | Syntax highlighting and text objects |
| `nvim-dap` | Debug adapter protocol |
| `undotree` | Visual undo history |
| `netrw.nvim` | Enhanced netrw file browser |
| `vimtex` | LaTeX editing |
| `nvim-tmux-navigation` | Ctrl-hjkl across tmux panes and nvim splits |
| `obsidian.nvim` | Markdown enhancements + vault integration (loads only if `~/notes` exists) |

### Custom modules

- **`custom/terminal.lua`** — floating terminal (80%×90% of editor), toggled with `Ctrl-z`, uses login shell
- **`custom/plugins/tmux.lua`** — maps `Ctrl-hjkl` and `Ctrl-\` to navigate seamlessly between nvim splits and tmux panes
- **`custom/plugins/obsidian.lua`** — Zettelkasten-style notes in `~/notes`, Telescope picker, checkbox UI, image attachments under `assets/imgs`. Conditionally loaded: skipped when `~/notes` doesn't exist

### First launch

Open `nvim` after install — lazy.nvim auto-installs all plugins and Mason auto-installs LSP servers. Run `:Lazy` to check status, `:Lazy update` to update.

---

## Git (`gitignore_global`)

Global ignore file for `.DS_Store`, editor swap files (`*.swp`, `*.swo`, `*~`), IDE dirs (`.idea/`, `.vscode/`), env files (`.env`, `.env.local`), and `Thumbs.db`.

---

## Theme

**Catppuccin Mocha** across the full stack:

| Layer | How |
|-------|-----|
| Shell prompt | Oh My Posh `catppuccin_mocha.omp.json` |
| fzf | `FZF_DEFAULT_OPTS` color vars |
| Tmux | `catppuccin/tmux` plugin, `mocha` flavour |
| Neovim | `catppuccin` plugin |

---

## Supported platforms

- **macOS** — Apple Silicon and Intel
- **Linux** — Debian/Ubuntu (`apt`), Fedora/RHEL (`dnf`), Arch (`pacman`); requires `sudo`

## Uninstall

```bash
# Remove symlinks
rm ~/.zshrc ~/.gitignore_global ~/.config/nvim ~/.config/tmux/tmux.conf

# Restore previous configs
cp ~/.dotfiles-backup/<timestamp>/* ~/
```
