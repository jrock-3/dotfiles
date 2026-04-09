#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  dotfiles installer — works on fresh or pre-existing macOS & Linux  ║
# ║  Usage:  bash install.sh                                            ║
# ║          bash <(curl -fsSL https://raw.githubusercontent.com/       ║
# ║               jrock-3/dotfiles/main/install.sh)                     ║
# ╚══════════════════════════════════════════════════════════════════════╝
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: this script requires bash. Run with: bash $0" >&2
    exit 1
fi
set -euo pipefail

REPO_URL="https://github.com/jrock-3/dotfiles.git"
DEFAULT_DIR="$HOME/git-repos/dotfiles"
SKIP_DEPS="${SKIP_DEPS:-}"

# ─── Logging ──────────────────────────────────────────────────────────
info()  { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
err()   { printf '\033[1;31m  ✗ %s\033[0m\n' "$*"; }
has()   { command -v "$1" &>/dev/null; }

# ─── Bootstrap ────────────────────────────────────────────────────────
# Detect whether we're inside the repo or need to clone it first.
_script_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$_script_dir" ] && [ -f "$_script_dir/zshrc" ] && [ -d "$_script_dir/nvim" ]; then
    DOTFILES_DIR="$_script_dir"
else
    DOTFILES_DIR="${DOTFILES_DIR:-$DEFAULT_DIR}"

    _ensure_git() {
        has git && return
        echo "==> git not found — installing minimal prerequisites..."
        if   has apt-get; then sudo apt-get update -qq && sudo apt-get install -y git curl
        elif has dnf;     then sudo dnf install -y git curl
        elif has pacman;  then sudo pacman -S --noconfirm git curl
        elif has brew;    then brew install git
        else echo "ERROR: install git manually and re-run." >&2; exit 1; fi
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

# ─── Platform detection ──────────────────────────────────────────────
OS="$(uname -s)"
PKG=""
if [ "$OS" = "Linux" ]; then
    if   has apt-get; then PKG="apt"
    elif has dnf;     then PKG="dnf"
    elif has pacman;  then PKG="pacman"
    fi
fi

# ─── Package manager helpers ─────────────────────────────────────────
wait_for_apt() {
    local max=120 waited=0
    while sudo fuser /var/lib/dpkg/lock-frontend &>/dev/null 2>&1; do
        (( waited >= max )) && { warn "Timed out waiting for dpkg lock — trying anyway"; return; }
        warn "Waiting for dpkg lock..."; sleep 5; waited=$((waited + 5))
    done
}

apt_install() { wait_for_apt; sudo apt-get install -y "$@"; }

# Install a package via the detected Linux package manager.
pkg_install() {
    case "$PKG" in
        apt)    apt_install "$@" ;;
        dnf)    sudo dnf install -y "$@" ;;
        pacman) sudo pacman -S --noconfirm "$@" ;;
        *)      return 1 ;;
    esac
}

portable_sed() {
    if sed --version &>/dev/null 2>&1; then sed -i "$@"; else sed -i '' "$@"; fi
}

# ─── Reusable install wrappers ───────────────────────────────────────

# Install a CLI tool via the system package manager (fatal on failure).
ensure_pkg() {
    local cmd="$1"; shift
    has "$cmd" && { ok "$cmd"; return; }
    info "Installing $cmd..."
    if [ "$OS" = "Darwin" ]; then brew install "$cmd"
    else pkg_install "$@"; fi
}

# Same as ensure_pkg but won't abort the script on failure.
try_pkg() {
    local cmd="$1"; shift
    has "$cmd" && { ok "$cmd"; return; }
    info "Installing $cmd..."
    if [ "$OS" = "Darwin" ]; then
        brew install "$@" || warn "$cmd install failed"
    else
        pkg_install "$@" || warn "$cmd install failed"
    fi
}

# Clone a repo to a target dir if it doesn't exist yet.
ensure_clone() {
    local name="$1" url="$2" dest="$3"
    if [ -d "$dest" ]; then ok "$name"; return; fi
    info "Installing $name..."
    mkdir -p "$(dirname "$dest")"
    git clone "$url" "$dest"
    ok "$name"
}

# ─── Individual installers ───────────────────────────────────────────
# Each function is self-contained: check → install → report.
# To add a new tool, write a function and call it from install_deps.

install_homebrew() {
    has brew && return
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if   [ -f /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f /usr/local/bin/brew ];    then eval "$(/usr/local/bin/brew shellenv)"
    fi
}

install_ohmyzsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then ok "oh-my-zsh"; return; fi
    info "Installing oh-my-zsh..."
    KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "oh-my-zsh"
}

install_zsh_autosuggestions() {
    local dest="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    ensure_clone "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions" "$dest"
}

install_zsh_syntax_highlighting() {
    if [ "$OS" = "Darwin" ]; then return; fi  # handled by brew install
    [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && { ok "zsh-syntax-highlighting"; return; }
    [ -f /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && { ok "zsh-syntax-highlighting"; return; }
    info "Installing zsh-syntax-highlighting..."
    pkg_install zsh-syntax-highlighting || warn "zsh-syntax-highlighting install failed"
}

install_tpm() {
    ensure_clone "tpm" "https://github.com/tmux-plugins/tpm" "$HOME/.config/tmux/plugins/tpm"
}

install_ohmyposh() {
    if has oh-my-posh || [ -x "$HOME/.local/bin/oh-my-posh" ]; then ok "oh-my-posh"; return; fi
    info "Installing oh-my-posh..."
    if [ "$OS" = "Darwin" ]; then brew install oh-my-posh
    else curl -fsSL https://ohmyposh.dev/install.sh | bash -s; fi
    ok "oh-my-posh"
}

install_ohmyposh_theme() {
    local dir="$HOME/.cache/oh-my-posh/themes"
    local theme="catppuccin_mocha.omp.json"
    [ -f "$dir/$theme" ] && { ok "oh-my-posh theme"; return; }
    # On macOS, themes ship with the brew package
    if [ "$OS" = "Darwin" ] && has brew; then
        local brew_theme; brew_theme="$(brew --prefix oh-my-posh 2>/dev/null)/themes/$theme"
        [ -f "$brew_theme" ] && { ok "oh-my-posh theme (brew)"; return; }
    fi
    info "Downloading oh-my-posh theme ($theme)..."
    mkdir -p "$dir"
    curl -fsSL "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$theme" -o "$dir/$theme"
    ok "oh-my-posh theme"
}

install_neovim_linux() {
    has nvim && { ok "neovim"; return; }
    info "Installing neovim..."
    local arch; arch="$(uname -m)"
    if [ "$arch" = "x86_64" ]; then
        local tarball="/tmp/nvim-linux-x86_64.tar.gz"
        curl -fLo "$tarball" \
            "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
        tar xzf "$tarball" -C /tmp
        sudo rm -rf /opt/nvim
        sudo mv /tmp/nvim-linux-x86_64 /opt/nvim
        sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
        rm -f "$tarball"
    else
        info "Non-x86_64 arch ($arch) — installing from package manager..."
        pkg_install neovim || { warn "neovim install failed — install manually"; return; }
    fi
    ok "neovim"
}

install_eza_linux() {
    has eza && { ok "eza"; return; }
    info "Installing eza..."
    (
        case "$PKG" in
            apt)
                sudo mkdir -p /etc/apt/keyrings
                curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                    | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/gierens.gpg
                echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
                    | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
                wait_for_apt && sudo apt-get update -qq && apt_install eza ;;
            dnf)    sudo dnf install -y eza ;;
            pacman) sudo pacman -S --noconfirm eza ;;
            *)      false ;;
        esac
    ) || warn "eza install failed — https://github.com/eza-community/eza"
    has eza && ok "eza" || true
}

install_lazygit_linux() {
    has lazygit && { ok "lazygit"; return; }
    info "Installing lazygit..."
    (
        case "$PKG" in
            apt)
                has add-apt-repository || apt_install software-properties-common
                wait_for_apt
                sudo add-apt-repository -y ppa:lazygit-team/release 2>/dev/null
                sudo apt-get update -qq && apt_install lazygit ;;
            dnf)    sudo dnf copr enable -y atim/lazygit && sudo dnf install -y lazygit ;;
            pacman) sudo pacman -S --noconfirm lazygit ;;
            *)      false ;;
        esac
    ) || warn "lazygit install failed — https://github.com/jesseduffield/lazygit"
    has lazygit && ok "lazygit" || true
}

install_nvm() {
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
}

# ─── Main install orchestration ──────────────────────────────────────

install_deps_darwin() {
    info "macOS detected"
    install_homebrew

    info "Installing Homebrew packages..."
    brew install neovim tmux eza lazygit zoxide zsh-syntax-highlighting fzf

    install_ohmyposh
    install_ohmyposh_theme
    install_ohmyzsh
    install_zsh_autosuggestions
    install_tpm
    install_nvm
}

install_deps_linux() {
    info "Linux detected"
    has sudo || { err "sudo is required but not found"; exit 1; }
    [ -n "$PKG" ] || { err "No supported package manager found (apt, dnf, pacman)"; exit 1; }

    [ "$PKG" = "apt" ] && { wait_for_apt; sudo apt-get update -qq; }

    # Core prerequisites
    ensure_pkg zsh    zsh
    info "Ensuring git, curl, unzip..."
    pkg_install git curl unzip
    ensure_pkg tmux   tmux

    # Shell & prompt
    install_ohmyzsh
    install_zsh_autosuggestions
    install_zsh_syntax_highlighting
    install_ohmyposh
    install_ohmyposh_theme

    # Editors & tools
    install_neovim_linux
    install_tpm
    try_pkg fzf      fzf
    try_pkg zoxide   zoxide
    install_eza_linux
    install_lazygit_linux
    install_nvm
}

install_deps() {
    case "$OS" in
        Darwin) install_deps_darwin ;;
        Linux)  install_deps_linux ;;
        *)      err "Unsupported OS: $OS"; exit 1 ;;
    esac
}

# ─── Patches ─────────────────────────────────────────────────────────
# One-time fixes applied to repo files for cross-platform compatibility.

apply_patches() {
    local netrw="$DOTFILES_DIR/nvim/lua/netrw-setup.lua"
    if [ -f "$netrw" ] && grep -q 'vim.fn\["netrw_gitignore#Hide"\]()' "$netrw"; then
        info "Patching netrw-setup.lua for portability..."
        if sed --version &>/dev/null 2>&1; then
            sed -i 's|vim.g.netrw_list_hide = vim.fn\["netrw_gitignore#Hide"\]()|local ok, hide = pcall(vim.fn["netrw_gitignore#Hide"])\nvim.g.netrw_list_hide = ok and hide or ""|' "$netrw"
        else
            sed -i '' 's|vim.g.netrw_list_hide = vim.fn\["netrw_gitignore#Hide"\]()|local ok, hide = pcall(vim.fn["netrw_gitignore#Hide"])\
vim.g.netrw_list_hide = ok and hide or ""|' "$netrw"
        fi
    fi

    local tmux="$DOTFILES_DIR/tmux.conf"
    if [ -f "$tmux" ] && grep -q '^show-options' "$tmux"; then
        info "Patching tmux.conf (removing show-options)..."
        portable_sed '/^show-options/d' "$tmux"
    fi
}

# ─── Symlinks ────────────────────────────────────────────────────────
# Map: <repo path> → <destination>
# To add a new dotfile, just add a line to this array.

create_symlinks() {
    local links=(
        "$DOTFILES_DIR/nvim       $HOME/.config/nvim"
        "$DOTFILES_DIR/tmux.conf  $HOME/.config/tmux/tmux.conf"
        "$DOTFILES_DIR/zshrc      $HOME/.zshrc"
    )

    for entry in "${links[@]}"; do
        local src dest
        src=$(echo "$entry" | awk '{print $1}')
        dest=$(echo "$entry" | awk '{print $2}')
        backup_and_link "$src" "$dest"
    done
}

backup_and_link() {
    local src="$1" dest="$2"
    local ts; ts="$(date +%Y%m%d_%H%M%S)"

    if [ -L "$dest" ]; then
        local target; target=$(readlink "$dest")
        if [ "$target" = "$src" ]; then ok "$dest (already linked)"; return; fi
        warn "Removing stale symlink $dest -> $target"
        rm "$dest"
    elif [ -e "$dest" ]; then
        local bak="$HOME/.dotfiles-backup/$ts"
        mkdir -p "$bak"
        warn "Backing up $dest -> $bak/"
        mv "$dest" "$bak/"
    fi

    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    ok "$dest -> $src"
}

# ─── Post-install ────────────────────────────────────────────────────

post_install() {
    local tpm="$HOME/.config/tmux/plugins/tpm/bin/install_plugins"
    if [ -x "$tpm" ]; then
        info "Installing tmux plugins..."
        "$tpm" >/dev/null 2>&1 || warn "TPM plugin install failed — run prefix + I in tmux"
        ok "tmux plugins"
    fi

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
    [ -d "$HOME/.dotfiles-backup" ] && { echo ""; info "Previous configs backed up to ~/.dotfiles-backup/"; }
}

# ─── Run ─────────────────────────────────────────────────────────────

main() {
    if [ -z "$SKIP_DEPS" ]; then
        install_deps
    else
        info "Skipping dependency install (SKIP_DEPS is set)"
    fi

    for f in nvim tmux.conf zshrc; do
        [ -e "$DOTFILES_DIR/$f" ] || { err "Missing $DOTFILES_DIR/$f — is the repo cloned correctly?"; exit 1; }
    done

    apply_patches
    create_symlinks
    post_install
}

main "$@"
