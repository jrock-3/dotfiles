#!/usr/bin/env bash
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: this script requires bash. Run with: bash $0" >&2
    exit 1
fi
set -euo pipefail

REPO_URL="https://github.com/jrock-3/dotfiles.git"
DEFAULT_DIR="$HOME/git-repos/dotfiles"
SKIP_DEPS="${SKIP_DEPS:-}"

# ── Bootstrap: detect if we're inside the repo or need to clone it ────
_script_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$_script_dir" ] && [ -f "$_script_dir/zshrc" ] && [ -d "$_script_dir/nvim" ]; then
    DOTFILES_DIR="$_script_dir"
else
    DOTFILES_DIR="${DOTFILES_DIR:-$DEFAULT_DIR}"

    _ensure_git() {
        command -v git &>/dev/null && return
        echo "==> git not found — installing minimal prerequisites..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y git curl
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y git curl
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm git curl
        elif command -v brew &>/dev/null; then
            brew install git
        else
            echo "ERROR: git is required but can't be auto-installed. Install git and re-run." >&2
            exit 1
        fi
    }

    if [ ! -d "$DOTFILES_DIR/.git" ]; then
        _ensure_git
        echo "==> Cloning dotfiles to $DOTFILES_DIR..."
        mkdir -p "$(dirname "$DOTFILES_DIR")"
        git clone "$REPO_URL" "$DOTFILES_DIR"
    fi

    if [ -f "$DOTFILES_DIR/install.sh" ]; then
        echo "==> Re-launching from cloned repo..."
        exec bash "$DOTFILES_DIR/install.sh" "$@"
    fi
fi

info()  { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
err()   { printf '\033[1;31m  ✗ %s\033[0m\n' "$*"; }

has() { command -v "$1" &>/dev/null; }

wait_for_apt() {
    local max_wait=120 waited=0
    while sudo fuser /var/lib/dpkg/lock-frontend &>/dev/null 2>&1; do
        if [ "$waited" -ge "$max_wait" ]; then
            warn "Timed out waiting for dpkg lock after ${max_wait}s — trying anyway"
            return
        fi
        warn "Waiting for dpkg lock..."
        sleep 5
        waited=$((waited + 5))
    done
}

apt_install() {
    wait_for_apt
    sudo apt-get install -y "$@"
}

# Installs a tool; failure is non-fatal (warns instead of aborting)
try_install() {
    local name="$1"; shift
    if "$@"; then
        ok "$name"
    else
        warn "$name install failed — install manually"
    fi
}

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
        brew install neovim tmux eza lazygit zoxide zsh-syntax-highlighting oh-my-posh fzf

        # ── oh-my-zsh ────────────────────────────────────────────
        # ── oh-my-zsh ────────────────────────────────────────────
        if [ ! -d "$HOME/.oh-my-zsh" ]; then
            info "Installing oh-my-zsh..."
            KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
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
            mkdir -p "$HOME/.config/tmux/plugins"
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

        if ! has sudo; then
            err "sudo is required but not found"
            exit 1
        fi

        local PKG=""
        if has apt-get; then
            PKG="apt"
            wait_for_apt
            sudo apt-get update -qq
        elif has dnf; then
            PKG="dnf"
        elif has pacman; then
            PKG="pacman"
        else
            err "No supported package manager found (apt, dnf, pacman)"
            exit 1
        fi

        # ── zsh ──────────────────────────────────────────────────
        if ! has zsh; then
            info "Installing zsh..."
            case "$PKG" in
                apt)    apt_install zsh ;;
                dnf)    sudo dnf install -y zsh ;;
                pacman) sudo pacman -S --noconfirm zsh ;;
            esac
        fi
        ok "zsh"

        # ── git, curl, unzip (prerequisites) ────────────────────
        info "Ensuring git, curl, unzip..."
        case "$PKG" in
            apt)    apt_install git curl unzip ;;
            dnf)    sudo dnf install -y git curl unzip ;;
            pacman) sudo pacman -S --noconfirm git curl unzip ;;
        esac

        # ── tmux ─────────────────────────────────────────────────
        if ! has tmux; then
            info "Installing tmux..."
            case "$PKG" in
                apt)    apt_install tmux ;;
                dnf)    sudo dnf install -y tmux ;;
                pacman) sudo pacman -S --noconfirm tmux ;;
            esac
        fi
        ok "tmux"

        # ── TPM (tmux plugin manager) ────────────────────────────
        if [ ! -d "$HOME/.config/tmux/plugins/tpm" ]; then
            info "Installing TPM..."
            mkdir -p "$HOME/.config/tmux/plugins"
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
                cd - >/dev/null
            fi
        fi
        ok "neovim"

        # ── oh-my-zsh ────────────────────────────────────────────
        if [ ! -d "$HOME/.oh-my-zsh" ]; then
            info "Installing oh-my-zsh..."
            KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
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
                apt)    try_install "zsh-syntax-highlighting" apt_install zsh-syntax-highlighting ;;
                dnf)    try_install "zsh-syntax-highlighting" sudo dnf install -y zsh-syntax-highlighting ;;
                pacman) try_install "zsh-syntax-highlighting" sudo pacman -S --noconfirm zsh-syntax-highlighting ;;
                *)
                    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
                        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
                    ;;
            esac
        else
            ok "zsh-syntax-highlighting"
        fi

        # ── oh-my-posh ───────────────────────────────────────────
        if ! has oh-my-posh && ! [ -x "$HOME/.local/bin/oh-my-posh" ]; then
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

        # ── fzf ──────────────────────────────────────────────────
        if ! has fzf; then
            info "Installing fzf..."
            case "$PKG" in
                apt)    try_install "fzf" apt_install fzf ;;
                dnf)    try_install "fzf" sudo dnf install -y fzf ;;
                pacman) try_install "fzf" sudo pacman -S --noconfirm fzf ;;
            esac
        else
            ok "fzf"
        fi

        # ── eza (non-critical) ───────────────────────────────────
        if ! has eza; then
            info "Installing eza..."
            (
                case "$PKG" in
                    apt)
                        sudo mkdir -p /etc/apt/keyrings
                        curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                            | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/gierens.gpg
                        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
                            | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
                        wait_for_apt && sudo apt-get update -qq && apt_install eza
                        ;;
                    dnf)    sudo dnf install -y eza ;;
                    pacman) sudo pacman -S --noconfirm eza ;;
                    *)      false ;;
                esac
            ) || warn "eza install failed — install manually: https://github.com/eza-community/eza"
        fi
        has eza && ok "eza" || warn "eza not installed"

        # ── lazygit (non-critical) ───────────────────────────────
        if ! has lazygit; then
            info "Installing lazygit..."
            (
                case "$PKG" in
                    apt)
                        has add-apt-repository || apt_install software-properties-common
                        wait_for_apt
                        sudo add-apt-repository -y ppa:lazygit-team/release 2>/dev/null
                        sudo apt-get update -qq
                        apt_install lazygit
                        ;;
                    dnf)    sudo dnf copr enable -y atim/lazygit && sudo dnf install -y lazygit ;;
                    pacman) sudo pacman -S --noconfirm lazygit ;;
                    *)      false ;;
                esac
            ) || warn "lazygit install failed — install manually: https://github.com/jesseduffield/lazygit"
        fi
        has lazygit && ok "lazygit" || warn "lazygit not installed"

        # ── zoxide ───────────────────────────────────────────────
        if ! has zoxide; then
            info "Installing zoxide..."
            case "$PKG" in
                apt)    try_install "zoxide" apt_install zoxide ;;
                dnf)    try_install "zoxide" sudo dnf install -y zoxide ;;
                pacman) try_install "zoxide" sudo pacman -S --noconfirm zoxide ;;
            esac
        else
            ok "zoxide"
        fi

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

# ── Install tmux plugins via TPM ──────────────────────────────────────
TPM_INSTALL="$HOME/.config/tmux/plugins/tpm/bin/install_plugins"
if [ -x "$TPM_INSTALL" ]; then
    info "Installing tmux plugins..."
    "$TPM_INSTALL" >/dev/null 2>&1 || warn "TPM plugin install failed — run prefix + I in tmux"
    ok "tmux plugins"
fi

# ── Set default shell to zsh if it isn't already ─────────────────────
if [ "$(basename "$SHELL")" != "zsh" ] && has zsh; then
    info "Setting default shell to zsh..."
    if has chsh; then
        sudo chsh -s "$(which zsh)" "$(whoami)" 2>/dev/null \
            || warn "chsh failed — run manually: chsh -s \$(which zsh)"
    else
        warn "chsh not found — add 'exec zsh -l' to ~/.bashrc to use zsh"
    fi
fi

echo ""
info "Done! You may want to:"
echo "  • Restart your shell or run:  exec zsh"
echo "  • Open nvim to trigger lazy.nvim plugin install"
if [ -d "$HOME/.dotfiles-backup" ]; then
    echo ""
    info "Your previous configs were backed up to ~/.dotfiles-backup/"
fi
