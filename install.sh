#!/usr/bin/env bash
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: this script requires bash. Run with: bash $0" >&2
    exit 1
fi
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKIP_DEPS="${SKIP_DEPS:-}"

info()  { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
err()   { printf '\033[1;31m  ✗ %s\033[0m\n' "$*"; }

has() { command -v "$1" &>/dev/null; }

portable_sed() {
    if sed --version &>/dev/null; then
        sed -i "$@"
    else
        sed -i '' "$@"
    fi
}

backup_and_link() {
    local src="$1" dest="$2"
    local backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

    if [ -L "$dest" ]; then
        local current_target
        current_target=$(readlink "$dest")
        if [ "$current_target" = "$src" ]; then
            ok "$dest -> $src (already linked)"
            return
        fi
        warn "Removing existing symlink $dest -> $current_target"
        rm "$dest"
    elif [ -e "$dest" ]; then
        mkdir -p "$backup_dir"
        warn "Backing up $dest -> $backup_dir/"
        mv "$dest" "$backup_dir/"
    fi

    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    ok "$dest -> $src"
}

# ── Install dependencies ─────────────────────────────────────────────
install_deps() {
    local OS
    OS="$(uname -s)"

    if [ "$OS" = "Darwin" ]; then
        info "macOS detected — install deps with Homebrew"
        if ! has brew; then
            info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            if [ -f /opt/homebrew/bin/brew ]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [ -f /usr/local/bin/brew ]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
        fi

        info "Installing Homebrew packages..."
        brew install neovim tmux eza lazygit zoxide zsh-syntax-highlighting oh-my-posh

        # ── oh-my-zsh ────────────────────────────────────────────
        if [ ! -d "$HOME/.oh-my-zsh" ]; then
            info "Installing oh-my-zsh..."
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        fi
        ok "oh-my-zsh"

        # ── zsh-autosuggestions (omz plugin) ─────────────────────
        local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
        if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
            info "Installing zsh-autosuggestions..."
            git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        fi
        ok "zsh-autosuggestions"

        # ── TPM (tmux plugin manager) ────────────────────────────
        if [ ! -d "$HOME/.config/tmux/plugins/tpm" ]; then
            info "Installing TPM..."
            git clone https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
        fi
        ok "tpm"

        # ── nvm + Node LTS ───────────────────────────────────────
        if [ ! -d "$HOME/.nvm" ]; then
            info "Installing nvm..."
            curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        fi
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        if ! has node; then
            info "Installing Node.js LTS..."
            nvm install --lts
        fi
        ok "nvm + node"
    elif [ "$OS" = "Linux" ]; then
        info "Linux detected — installing dependencies"

        local PKG=""
        if has apt-get; then
            PKG="apt"
            sudo apt-get update -qq
        elif has dnf; then
            PKG="dnf"
        elif has pacman; then
            PKG="pacman"
        fi

        # ── zsh ──────────────────────────────────────────────────
        if ! has zsh; then
            info "Installing zsh..."
            case "$PKG" in
                apt)    sudo apt-get install -y zsh ;;
                dnf)    sudo dnf install -y zsh ;;
                pacman) sudo pacman -S --noconfirm zsh ;;
                *)      err "Install zsh manually"; exit 1 ;;
            esac
        fi
        ok "zsh"

        # ── git, curl, unzip (prerequisites) ────────────────────
        info "Ensuring git, curl, unzip..."
        case "$PKG" in
            apt)    sudo apt-get install -y git curl unzip ;;
            dnf)    sudo dnf install -y git curl unzip ;;
            pacman) sudo pacman -S --noconfirm git curl unzip ;;
        esac

        # ── tmux ─────────────────────────────────────────────────
        if ! has tmux; then
            info "Installing tmux..."
            case "$PKG" in
                apt)    sudo apt-get install -y tmux ;;
                dnf)    sudo dnf install -y tmux ;;
                pacman) sudo pacman -S --noconfirm tmux ;;
            esac
        fi
        ok "tmux"

        # ── TPM (tmux plugin manager) ────────────────────────────
        if [ ! -d "$HOME/.config/tmux/plugins/tpm" ]; then
            info "Installing TPM..."
            git clone https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
        fi
        ok "tpm"

        # ── neovim (latest stable via GitHub release) ────────────
        if ! has nvim; then
            info "Installing neovim..."
            curl -fLo /tmp/nvim-linux-x86_64.appimage \
                "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage"
            chmod +x /tmp/nvim-linux-x86_64.appimage
            if /tmp/nvim-linux-x86_64.appimage --version &>/dev/null; then
                sudo mv /tmp/nvim-linux-x86_64.appimage /usr/local/bin/nvim
            else
                info "FUSE not available — extracting AppImage..."
                cd /tmp && /tmp/nvim-linux-x86_64.appimage --appimage-extract &>/dev/null
                sudo rm -rf /opt/nvim
                sudo mv /tmp/squashfs-root /opt/nvim
                sudo ln -sf /opt/nvim/usr/bin/nvim /usr/local/bin/nvim
                rm -f /tmp/nvim-linux-x86_64.appimage
                cd -
            fi
        fi
        ok "neovim"

        # ── oh-my-zsh ────────────────────────────────────────────
        if [ ! -d "$HOME/.oh-my-zsh" ]; then
            info "Installing oh-my-zsh..."
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        fi
        ok "oh-my-zsh"

        # ── zsh-autosuggestions (omz plugin) ─────────────────────
        local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
        if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
            info "Installing zsh-autosuggestions..."
            git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        fi
        ok "zsh-autosuggestions"

        # ── zsh-syntax-highlighting ──────────────────────────────
        if ! [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] &&
           ! [ -f /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
            info "Installing zsh-syntax-highlighting..."
            case "$PKG" in
                apt)    sudo apt-get install -y zsh-syntax-highlighting ;;
                dnf)    sudo dnf install -y zsh-syntax-highlighting ;;
                pacman) sudo pacman -S --noconfirm zsh-syntax-highlighting ;;
                *)
                    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
                        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
                    ;;
            esac
        fi
        ok "zsh-syntax-highlighting"

        # ── oh-my-posh ───────────────────────────────────────────
        if ! has oh-my-posh; then
            info "Installing oh-my-posh..."
            curl -fsSL https://ohmyposh.dev/install.sh | bash -s
        fi
        ok "oh-my-posh"

        # ── oh-my-posh theme ─────────────────────────────────────
        local OMP_THEME_DIR="$HOME/.cache/oh-my-posh/themes"
        local OMP_THEME="catppuccin_mocha.omp.json"
        if [ ! -f "$OMP_THEME_DIR/$OMP_THEME" ]; then
            info "Downloading oh-my-posh theme ($OMP_THEME)..."
            mkdir -p "$OMP_THEME_DIR"
            curl -fsSL "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$OMP_THEME" \
                -o "$OMP_THEME_DIR/$OMP_THEME"
        fi
        ok "oh-my-posh theme"

        # ── eza ──────────────────────────────────────────────────
        if ! has eza; then
            info "Installing eza..."
            case "$PKG" in
                apt)
                    sudo mkdir -p /etc/apt/keyrings
                    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                        | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
                    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
                        | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
                    sudo apt-get update -qq && sudo apt-get install -y eza
                    ;;
                dnf)    sudo dnf install -y eza ;;
                pacman) sudo pacman -S --noconfirm eza ;;
                *)      warn "Install eza manually: https://github.com/eza-community/eza" ;;
            esac
        fi
        ok "eza"

        # ── lazygit ──────────────────────────────────────────────
        if ! has lazygit; then
            info "Installing lazygit..."
            case "$PKG" in
                apt)
                    sudo add-apt-repository -y ppa:lazygit-team/release 2>/dev/null \
                        && sudo apt-get update -qq \
                        && sudo apt-get install -y lazygit \
                        || warn "PPA failed — install lazygit manually: https://github.com/jesseduffield/lazygit#installation"
                    ;;
                dnf)    sudo dnf copr enable -y atim/lazygit && sudo dnf install -y lazygit ;;
                pacman) sudo pacman -S --noconfirm lazygit ;;
                *)      warn "Install lazygit manually: https://github.com/jesseduffield/lazygit" ;;
            esac
        fi
        has lazygit && ok "lazygit" || warn "lazygit not installed"

        # ── zoxide ───────────────────────────────────────────────
        if ! has zoxide; then
            info "Installing zoxide..."
            case "$PKG" in
                apt)    sudo apt-get install -y zoxide ;;
                dnf)    sudo dnf install -y zoxide ;;
                pacman) sudo pacman -S --noconfirm zoxide ;;
                *)      warn "Install zoxide manually: https://github.com/ajeetdsouza/zoxide#installation" ;;
            esac
        fi
        has zoxide && ok "zoxide" || warn "zoxide not installed"

        # ── nvm + Node LTS ───────────────────────────────────────
        if [ ! -d "$HOME/.nvm" ]; then
            info "Installing nvm..."
            curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        fi
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        if ! has node; then
            info "Installing Node.js LTS..."
            nvm install --lts
        fi
        ok "nvm + node"
    else
        err "Unsupported OS: $OS"
        exit 1
    fi
}

if [ -z "$SKIP_DEPS" ]; then
    install_deps
else
    info "Skipping dependency install (SKIP_DEPS is set)"
fi

# ── Patch netrw-setup.lua to handle missing netrw runtime ─────────────
NETRW_FILE="$DOTFILES_DIR/nvim/lua/netrw-setup.lua"
if [ -f "$NETRW_FILE" ] && grep -q 'vim.fn\["netrw_gitignore#Hide"\]()' "$NETRW_FILE"; then
    info "Patching netrw-setup.lua for portability..."
    if sed --version &>/dev/null; then
        sed -i 's|vim.g.netrw_list_hide = vim.fn\["netrw_gitignore#Hide"\]()|local ok, hide = pcall(vim.fn["netrw_gitignore#Hide"])\nvim.g.netrw_list_hide = ok and hide or ""|' "$NETRW_FILE"
    else
        sed -i '' 's|vim.g.netrw_list_hide = vim.fn\["netrw_gitignore#Hide"\]()|local ok, hide = pcall(vim.fn["netrw_gitignore#Hide"])\
vim.g.netrw_list_hide = ok and hide or ""|' "$NETRW_FILE"
    fi
fi

# ── Patch tmux.conf: remove show-options (not valid in config files) ──
TMUX_FILE="$DOTFILES_DIR/tmux.conf"
if [ -f "$TMUX_FILE" ] && grep -q '^show-options' "$TMUX_FILE"; then
    info "Patching tmux.conf (removing show-options)..."
    portable_sed '/^show-options/d' "$TMUX_FILE"
fi

# ── Verify repo contents ─────────────────────────────────────────────
for f in nvim tmux.conf zshrc; do
    if [ ! -e "$DOTFILES_DIR/$f" ]; then
        err "Expected $DOTFILES_DIR/$f not found — is the repo cloned correctly?"
        exit 1
    fi
done

# ── Create symlinks ──────────────────────────────────────────────────
info "Linking neovim config..."
backup_and_link "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"

info "Linking tmux config..."
backup_and_link "$DOTFILES_DIR/tmux.conf" "$HOME/.config/tmux/tmux.conf"

info "Linking zsh config..."
backup_and_link "$DOTFILES_DIR/zshrc" "$HOME/.zshrc"

# ── Set default shell to zsh if it isn't already ─────────────────────
if [ "$(basename "$SHELL")" != "zsh" ] && has zsh; then
    info "Setting default shell to zsh..."
    sudo chsh -s "$(which zsh)" "$(whoami)" 2>/dev/null || warn "Run manually: chsh -s \$(which zsh)"
fi

echo ""
info "Done! You may want to:"
echo "  • Restart your shell or run:  exec zsh"
echo "  • In tmux, press prefix + I to install plugins via TPM"
echo "  • Open nvim to trigger lazy.nvim plugin install"
