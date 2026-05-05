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

_ensure_git() {
    command -v git &>/dev/null && return
    echo "==> git not found — installing minimal prerequisites..."
    if   command -v apt-get &>/dev/null; then sudo apt-get update -qq && sudo apt-get install -y git curl
    elif command -v dnf &>/dev/null;     then sudo dnf install -y git curl
    elif command -v pacman &>/dev/null;  then sudo pacman -S --noconfirm git curl
    elif command -v brew &>/dev/null;    then brew install git
    else echo "ERROR: install git manually and re-run." >&2; exit 1; fi
}

if [ -n "$_script_dir" ] && [ -f "$_script_dir/zshrc" ] && [ -d "$_script_dir/nvim" ]; then
    DOTFILES_DIR="$_script_dir"
else
    DOTFILES_DIR="${DOTFILES_DIR:-$DEFAULT_DIR}"

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

# Pull latest changes if the repo already exists
if [ -d "$DOTFILES_DIR/.git" ]; then
    _ensure_git
    info "Pulling latest dotfiles..."
    git -C "$DOTFILES_DIR" pull --ff-only 2>/dev/null \
        || warn "Could not pull latest — continuing with current version"
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

# Get latest release version from GitHub without the API (avoids rate limits).
# Uses the /releases/latest redirect to extract the tag.
gh_latest_ver() {
    local repo="$1"
    curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest" \
        | grep -oE '[^/]+$' | sed 's/^v//'
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
    for _p in /usr/share /usr/local/share; do
        [ -f "$_p/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && { ok "zsh-syntax-highlighting"; return; }
    done
    local dest="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    [ -d "$dest" ] && { ok "zsh-syntax-highlighting"; return; }
    info "Installing zsh-syntax-highlighting..."
    pkg_install zsh-syntax-highlighting 2>/dev/null \
        || git clone https://github.com/zsh-users/zsh-syntax-highlighting "$dest"
    ok "zsh-syntax-highlighting"
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

install_fzf_linux() {
    has fzf && { ok "fzf"; return; }
    info "Installing fzf..."
    if pkg_install fzf 2>/dev/null; then
        ok "fzf"; return
    fi
    if [ ! -d "$HOME/.fzf" ]; then
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    fi
    "$HOME/.fzf/install" --bin --no-key-bindings --no-completion --no-update-rc
    mkdir -p "$HOME/.local/bin"
    sudo install "$HOME/.fzf/bin/fzf" /usr/local/bin/fzf 2>/dev/null \
        || ln -sf "$HOME/.fzf/bin/fzf" "$HOME/.local/bin/fzf"
    has fzf && ok "fzf" || warn "fzf install failed"
}

install_zoxide_linux() {
    has zoxide && { ok "zoxide"; return; }
    info "Installing zoxide..."
    if pkg_install zoxide 2>/dev/null; then
        ok "zoxide"; return
    fi
    mkdir -p "$HOME/.local/bin"
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    has zoxide && ok "zoxide" || warn "zoxide install failed"
}

install_eza_linux() {
    has eza && { ok "eza"; return; }
    info "Installing eza..."
    (
        local arch; arch="$(uname -m)"
        case "$arch" in
            x86_64|aarch64) ;;
            *) warn "eza: unsupported arch $arch"; false ;;
        esac
        local tmpdir; tmpdir="$(mktemp -d)"
        curl -fsSLo "$tmpdir/eza.tar.gz" \
            "https://github.com/eza-community/eza/releases/latest/download/eza_${arch}-unknown-linux-gnu.tar.gz"
        tar xzf "$tmpdir/eza.tar.gz" -C "$tmpdir"
        sudo install "$tmpdir/eza" /usr/local/bin/eza
        rm -rf "$tmpdir"
    ) || warn "eza install failed — https://github.com/eza-community/eza"
    has eza && ok "eza" || true
}

install_bat_linux() {
    has bat && { ok "bat"; return; }
    info "Installing bat..."
    if pkg_install bat 2>/dev/null; then
        # Debian/Ubuntu installs the binary as "batcat" due to naming conflict
        if ! has bat && has batcat; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$(which batcat)" "$HOME/.local/bin/bat"
        fi
    fi
    ( has bat || has batcat ) && ok "bat" || warn "bat install failed"
}

install_fd_linux() {
    has fd && { ok "fd"; return; }
    info "Installing fd..."
    # Debian/Ubuntu: package is fd-find, binary is fdfind
    if pkg_install fd-find 2>/dev/null; then
        if ! has fd && has fdfind; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
        fi
        ( has fd || has fdfind ) && ok "fd" || warn "fd install failed"
        return
    fi
    # Fallback: GitHub release binary
    (
        local arch; arch="$(uname -m)"
        case "$arch" in
            x86_64)  arch="x86_64" ;;
            aarch64) arch="aarch64" ;;
            *) warn "fd: unsupported arch $arch"; false ;;
        esac
        local ver
        ver="$(gh_latest_ver sharkdp/fd)"
        [ -z "$ver" ] && { warn "Could not determine latest fd version"; false; }
        local tarball="/tmp/fd.tar.gz"
        curl -fsSLo "$tarball" \
            "https://github.com/sharkdp/fd/releases/download/v${ver}/fd-v${ver}-${arch}-unknown-linux-gnu.tar.gz"
        tar xzf "$tarball" -C /tmp
        sudo install "/tmp/fd-v${ver}-${arch}-unknown-linux-gnu/fd" /usr/local/bin/fd
        rm -rf "/tmp/fd-v${ver}-${arch}-unknown-linux-gnu" "$tarball"
    ) || warn "fd install failed — https://github.com/sharkdp/fd"
    has fd && ok "fd" || true
}

install_dust_linux() {
    has dust && { ok "dust"; return; }
    info "Installing dust..."
    (
        local arch; arch="$(uname -m)"
        case "$arch" in
            x86_64)  arch="x86_64" ;;
            aarch64) arch="aarch64" ;;
            *) warn "dust: unsupported arch $arch"; false ;;
        esac
        local ver
        ver="$(gh_latest_ver bootandy/dust)"
        [ -z "$ver" ] && { warn "Could not determine latest dust version"; false; }
        local tarball="/tmp/dust.tar.gz"
        curl -fsSLo "$tarball" \
            "https://github.com/bootandy/dust/releases/download/v${ver}/dust-v${ver}-${arch}-unknown-linux-gnu.tar.gz"
        tar xzf "$tarball" -C /tmp
        sudo install "/tmp/dust-v${ver}-${arch}-unknown-linux-gnu/dust" /usr/local/bin/dust
        rm -rf "/tmp/dust-v${ver}-${arch}-unknown-linux-gnu" "$tarball"
    ) || warn "dust install failed — https://github.com/bootandy/dust"
    has dust && ok "dust" || true
}

install_duf_linux() {
    has duf && { ok "duf"; return; }
    info "Installing duf..."
    if pkg_install duf 2>/dev/null; then
        has duf && ok "duf" || warn "duf install failed"
        return
    fi
    # Fallback: GitHub release binary
    (
        local arch; arch="$(uname -m)"
        case "$arch" in
            x86_64)  arch="amd64" ;;
            aarch64) arch="arm64" ;;
            *) warn "duf: unsupported arch $arch"; false ;;
        esac
        local ver
        ver="$(gh_latest_ver muesli/duf)"
        [ -z "$ver" ] && { warn "Could not determine latest duf version"; false; }
        local tarball="/tmp/duf.tar.gz"
        curl -fsSLo "$tarball" \
            "https://github.com/muesli/duf/releases/download/v${ver}/duf_${ver}_linux_${arch}.tar.gz"
        tar xzf "$tarball" -C /tmp duf
        sudo install /tmp/duf /usr/local/bin/duf
        rm -f /tmp/duf "$tarball"
    ) || warn "duf install failed — https://github.com/muesli/duf"
    has duf && ok "duf" || true
}

install_eaas_cli_linux() {
    has eaas-cli && { ok "eaas-cli"; return; }
    info "Installing eaas-cli..."
    (
        local latest
        latest="$(curl -sf \
            "https://artifactory.rbx.com/artifactory/api/storage/generic-all/entities-as-a-service/eaas-cli/" \
            | python3 -c "import sys,json; c=json.load(sys.stdin)['children']; v=[x['uri'].strip('/') for x in c]; v.sort(key=lambda s: list(map(int,s.split('.')))); print(v[-1])" 2>/dev/null)"
        [ -z "$latest" ] && { warn "Could not determine latest eaas-cli version"; false; }
        sudo curl -fsSL -o /usr/local/bin/eaas-cli \
            "https://artifactory.rbx.com/artifactory/generic-all/entities-as-a-service/eaas-cli/${latest}/x86_64-linux/eaas-cli"
        sudo chmod +x /usr/local/bin/eaas-cli
    ) || warn "eaas-cli install failed — check Artifactory access"
    has eaas-cli && ok "eaas-cli" || true
}

install_zshrc_local_linux() {
    local zshrc_local="$HOME/.zshrc.local"
    if grep -q "eaas-cli-update-check" "$zshrc_local" 2>/dev/null; then
        ok "eaas-cli wrapper in ~/.zshrc.local"; return
    fi
    info "Adding eaas-cli daily-update wrapper to ~/.zshrc.local..."
    cat >> "$zshrc_local" <<'EOF'

# ─── eaas-cli: install-if-missing + daily auto-update ────────────────
eaas-cli() {
    local stamp="/tmp/.eaas-cli-update-check"
    if [ ! -f "$stamp" ] || [ "$(date +%Y-%m-%d)" != "$(cat "$stamp" 2>/dev/null)" ]; then
        local current latest
        current=$(command eaas-cli --version 2>/dev/null | awk '{print $2}')
        latest=$(curl -sf \
            "https://artifactory.rbx.com/artifactory/api/storage/generic-all/entities-as-a-service/eaas-cli/" \
            | python3 -c "import sys,json; c=json.load(sys.stdin)['children']; v=[x['uri'].strip('/') for x in c]; v.sort(key=lambda s: list(map(int,s.split('.')))); print(v[-1])" 2>/dev/null)
        if [ -n "$latest" ] && [ "$current" != "$latest" ]; then
            echo "eaas-cli: updating $current → $latest"
            sudo curl -fsSL -o "$(command -v eaas-cli)" \
                "https://artifactory.rbx.com/artifactory/generic-all/entities-as-a-service/eaas-cli/${latest}/x86_64-linux/eaas-cli" \
                && sudo chmod +x "$(command -v eaas-cli)" \
                && echo "eaas-cli: updated to $latest"
        fi
        date +%Y-%m-%d > "$stamp"
    fi
    command eaas-cli "$@"
}
EOF
    ok "eaas-cli wrapper → ~/.zshrc.local"
}

install_lazygit_linux() {
    has lazygit && { ok "lazygit"; return; }
    info "Installing lazygit..."
    (
        local ver arch="$(uname -m)"
        [ "$arch" = "aarch64" ] && arch="arm64"
        ver="$(gh_latest_ver jesseduffield/lazygit)"
        [ -z "$ver" ] && { warn "Could not determine latest lazygit version"; false; }
        curl -fsSLo /tmp/lazygit.tar.gz \
            "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_Linux_${arch}.tar.gz"
        tar xzf /tmp/lazygit.tar.gz -C /tmp lazygit
        sudo install /tmp/lazygit /usr/local/bin/lazygit
        rm -f /tmp/lazygit /tmp/lazygit.tar.gz
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

install_nerd_font() {
    local font_name="JetBrainsMono"
    if [ "$OS" = "Darwin" ]; then
        if brew list --cask "font-jetbrains-mono-nerd-font" &>/dev/null; then
            ok "Nerd Font ($font_name)"; return
        fi
        info "Installing Nerd Font ($font_name)..."
        brew install --cask "font-jetbrains-mono-nerd-font" \
            || warn "Nerd Font install failed — install manually from https://www.nerdfonts.com"
    else
        local font_dir="$HOME/.local/share/fonts"
        if ls "$font_dir"/${font_name}*.ttf &>/dev/null 2>&1; then
            ok "Nerd Font ($font_name)"; return
        fi
        info "Installing Nerd Font ($font_name)..."
        local tmpdir; tmpdir="$(mktemp -d)"
        mkdir -p "$font_dir"
        local tarball="$tmpdir/${font_name}.tar.xz"
        if curl -fsSLo "$tarball" \
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.tar.xz"; then
            tar xf "$tarball" -C "$font_dir"
        else
            local zipfile="$tmpdir/${font_name}.zip"
            curl -fsSLo "$zipfile" \
                "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"
            unzip -qo "$zipfile" -d "$font_dir"
        fi
        rm -rf "$tmpdir"
        has fc-cache && fc-cache -f "$font_dir"
        ok "Nerd Font ($font_name)"
    fi
}

# Read packages.txt and install each via the system package manager.
install_linux_packages() {
    local pkg_file="$DOTFILES_DIR/packages.txt"
    [ -f "$pkg_file" ] || { warn "packages.txt not found — skipping"; return; }
    info "Installing packages from packages.txt..."
    while IFS= read -r line; do
        line="${line%%#*}"           # strip comments
        line="${line#"${line%%[![:space:]]*}"}"  # trim leading whitespace
        line="${line%"${line##*[![:space:]]}"}"  # trim trailing whitespace
        [ -z "$line" ] && continue
        has "$line" && { ok "$line"; continue; }
        pkg_install "$line" || warn "$line install failed"
    done < "$pkg_file"
}

# ─── Main install orchestration ──────────────────────────────────────

install_deps_darwin() {
    info "macOS detected"
    install_homebrew

    local brewfile="$DOTFILES_DIR/Brewfile"
    if [ -f "$brewfile" ]; then
        info "Installing Homebrew packages from Brewfile..."
        brew bundle --file="$brewfile" || warn "Some Brewfile entries failed"
    else
        info "Installing Homebrew packages..."
        brew install neovim tmux eza lazygit zoxide zsh-syntax-highlighting fzf
    fi

    install_nerd_font
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

    # Clean up stale third-party repos from previous install attempts
    if [ "$PKG" = "apt" ]; then
        for _stale in \
            /etc/apt/sources.list.d/lazygit*.list \
            /etc/apt/sources.list.d/lazygit*.sources \
            /etc/apt/sources.list.d/gierens.list \
            /etc/apt/sources.list.d/gierens.sources; do
            [ -f "$_stale" ] && { info "Removing stale apt source: $_stale"; sudo rm -f "$_stale"; }
        done
        if has add-apt-repository; then
            sudo add-apt-repository --remove -y ppa:lazygit-team/release 2>/dev/null || true
        fi
        wait_for_apt; sudo apt-get update -qq
    fi

    # Core prerequisites
    ensure_pkg zsh    zsh
    info "Ensuring git, curl, unzip..."
    pkg_install git curl unzip
    ensure_pkg tmux   tmux

    # Declarative packages from packages.txt
    install_linux_packages

    # Shell & prompt
    install_ohmyzsh
    install_zsh_autosuggestions
    install_zsh_syntax_highlighting
    install_ohmyposh
    install_ohmyposh_theme

    # Editors & tools
    install_neovim_linux
    install_tpm
    install_fzf_linux
    install_zoxide_linux
    install_bat_linux
    install_fd_linux
    install_eza_linux
    install_dust_linux
    install_duf_linux
    install_lazygit_linux
    install_nerd_font
    install_nvm
    install_eaas_cli_linux
    install_zshrc_local_linux
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
        "$DOTFILES_DIR/nvim              $HOME/.config/nvim"
        "$DOTFILES_DIR/tmux.conf         $HOME/.config/tmux/tmux.conf"
        "$DOTFILES_DIR/zshrc             $HOME/.zshrc"
        "$DOTFILES_DIR/gitignore_global  $HOME/.gitignore_global"
    )

    # Karabiner is macOS-only
    if [ "$OS" = "Darwin" ] && [ -d "$DOTFILES_DIR/karabiner" ]; then
        links+=("$DOTFILES_DIR/karabiner/karabiner.json  $HOME/.config/karabiner/karabiner.json")
    fi

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
    # Point git at the global gitignore
    if [ -f "$HOME/.gitignore_global" ]; then
        git config --global core.excludesFile "$HOME/.gitignore_global"
        ok "git core.excludesFile set"
    fi

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
    echo "  • Set your terminal font to JetBrainsMono Nerd Font"
    [ -d "$HOME/.dotfiles-backup" ] && { echo ""; info "Previous configs backed up to ~/.dotfiles-backup/"; }
}

# ─── Run ─────────────────────────────────────────────────────────────

main() {
    if [ -z "$SKIP_DEPS" ]; then
        install_deps
    else
        info "Skipping dependency install (SKIP_DEPS is set)"
    fi

    for f in nvim tmux.conf zshrc gitignore_global; do
        [ -e "$DOTFILES_DIR/$f" ] || { err "Missing $DOTFILES_DIR/$f — is the repo cloned correctly?"; exit 1; }
    done

    apply_patches
    create_symlinks
    post_install
}

main "$@"
