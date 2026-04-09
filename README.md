# dotfiles

Personal development environment for macOS and Linux. One command sets up Zsh, Neovim, Tmux, and a curated set of CLI tools — on a fresh OS or on top of existing configs.

## Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jrock-3/dotfiles/main/install.sh)
```

Or clone manually:

```bash
git clone https://github.com/jrock-3/dotfiles.git ~/git-repos/dotfiles
bash ~/git-repos/dotfiles/install.sh
```

The script is fully idempotent — running it again skips everything already installed.

## What Gets Installed

| Tool | macOS | Linux |
|------|-------|-------|
| [Neovim](https://neovim.io) | Homebrew | AppImage (with FUSE fallback) |
| [Tmux](https://github.com/tmux/tmux) | Homebrew | apt / dnf / pacman |
| [Oh My Zsh](https://ohmyz.sh) | curl installer | curl installer |
| [Oh My Posh](https://ohmyposh.dev) (Catppuccin Mocha) | Homebrew | curl installer |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | OMZ plugin | OMZ plugin |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | Homebrew | apt / dnf / pacman |
| [eza](https://github.com/eza-community/eza) | Homebrew | apt / dnf / pacman |
| [lazygit](https://github.com/jesseduffield/lazygit) | Homebrew | PPA / COPR / pacman |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Homebrew | apt / dnf / pacman |
| [fzf](https://github.com/junegunn/fzf) | Homebrew | apt / dnf / pacman |
| [NVM](https://github.com/nvm-sh/nvm) + Node.js LTS | curl installer | curl installer |
| [TPM](https://github.com/tmux-plugins/tpm) (Tmux Plugin Manager) | git clone | git clone |

On macOS, [Homebrew](https://brew.sh) is installed automatically if missing.

## What Gets Symlinked

| Source | Destination |
|--------|-------------|
| `nvim/` | `~/.config/nvim` |
| `tmux.conf` | `~/.config/tmux/tmux.conf` |
| `zshrc` | `~/.zshrc` |

## Pre-existing Configs

If any of these files already exist, they are moved to `~/.dotfiles-backup/<timestamp>/` before symlinking. Nothing is deleted — you can always restore your old setup by copying them back.

## Config Highlights

### Zsh

- **Prompt**: Oh My Posh with Catppuccin Mocha theme (falls back to robbyrussell if unavailable)
- **Double-space autosuggestion**: pressing space once types normally; pressing space twice accepts and runs the suggestion
- **Aliases**: `nv` (nvim), `c` (clear), `l` (eza), `lg` (lazygit), `z` (zoxide)
- **Editor**: prefers `nvim`, falls back to `vim`

### Tmux

- **Prefix**: `C-a` locally, `C-b` over SSH — avoids conflicts in nested sessions
- **Theme**: Catppuccin Mocha with top status bar
- **Vim navigation**: `h/j/k/l` pane switching, `M-h/j/k/l` pane resizing
- **Popups**: `C-j` jump to session (fzf), `C-f` jump to window (fzf), `C-t` popup terminal, `C-g` lazygit
- **Plugins**: tmux-resurrect, tmux-continuum, tmux-yank, vim-tmux-navigator
- **Config reload**: `prefix + r`

### Neovim

- Based on [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) with lazy.nvim
- LSP support via Mason (requires Node.js for JS/TS servers)
- Catppuccin color scheme
- Telescope, Treesitter, gitsigns, mini.nvim, and more
- Open nvim after install to trigger automatic plugin installation

## Options

| Variable | Default | Description |
|----------|---------|-------------|
| `DOTFILES_DIR` | `~/git-repos/dotfiles` | Where to clone the repo (only used when running standalone) |
| `SKIP_DEPS` | *(unset)* | Set to any value to skip dependency installation and only symlink |

```bash
# Example: only symlink, don't install anything
SKIP_DEPS=1 bash install.sh

# Example: clone to a custom location
DOTFILES_DIR=~/dotfiles bash <(curl -fsSL https://raw.githubusercontent.com/jrock-3/dotfiles/main/install.sh)
```

## Supported Platforms

- **macOS** (Apple Silicon and Intel)
- **Linux** (Debian/Ubuntu, Fedora/RHEL, Arch) — requires `sudo`

## Uninstall

Remove the symlinks and restore your backups:

```bash
rm ~/.zshrc ~/.config/nvim ~/.config/tmux/tmux.conf
cp ~/.dotfiles-backup/<timestamp>/* ~/  # restore old configs
```
