# ─── Path ─────────────────────────────────────────────────────────────
export PATH=$HOME/bin:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH

# ─── Terminal ─────────────────────────────────────────────────────────
stty -ixon 2>/dev/null   # disable flow control so C-s passes through
export LANG=en_US.UTF-8

# ─── Oh My Zsh ────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"

if command -v oh-my-posh &>/dev/null || [ -x "$HOME/.local/bin/oh-my-posh" ]; then
    ZSH_THEME=""           # oh-my-posh handles the prompt
else
    ZSH_THEME="robbyrussell"
fi

DISABLE_AUTO_TITLE="true"
ENABLE_CORRECTION="true"
HIST_STAMPS="yyyy-mm-dd"
plugins=(git zsh-autosuggestions)

[ -f "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"

# ─── Syntax highlighting (loaded after OMZ) ───────────────────────────
for _zsh_hl in \
    /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
    [ -f "$_zsh_hl" ] && { source "$_zsh_hl"; break; }
done
unset _zsh_hl

# ─── Prompt (Oh My Posh) ─────────────────────────────────────────────
_omp_bin=""
if   command -v oh-my-posh &>/dev/null;       then _omp_bin="oh-my-posh"
elif [ -x "$HOME/.local/bin/oh-my-posh" ];    then _omp_bin="$HOME/.local/bin/oh-my-posh"
fi

if [ -n "$_omp_bin" ]; then
    _omp_theme="catppuccin_mocha.omp.json"
    _omp_config=""
    for _dir in \
        "$(command -v brew &>/dev/null && brew --prefix oh-my-posh 2>/dev/null)/themes" \
        "$HOME/.cache/oh-my-posh/themes" \
        "/usr/local/share/oh-my-posh/themes"; do
        [ -f "$_dir/$_omp_theme" ] && { _omp_config="$_dir/$_omp_theme"; break; }
    done

    if [ -n "$_omp_config" ]; then
        eval "$("$_omp_bin" init zsh --config "$_omp_config")"
    else
        eval "$("$_omp_bin" init zsh)"
    fi
    unset _omp_theme _omp_config _omp_bin _dir
fi

# ─── Editor ───────────────────────────────────────────────────────────
if command -v nvim &>/dev/null; then
    export EDITOR='nvim'
else
    export EDITOR='vim'
fi
export VISUAL="$EDITOR"

# ─── Aliases ──────────────────────────────────────────────────────────
alias nv="nvim"
alias c="clear"
alias clip="pbcopy"
alias t="tmux attach || tmux new"
command -v eza     &>/dev/null && alias l="eza -la --icons --no-user --group-directories-first --time-style long-iso"
command -v lazygit &>/dev/null && alias lg="lazygit"
command -v gmktemp &>/dev/null && alias mktemp="gmktemp"

# ─── Tools ────────────────────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
    unalias z 2>/dev/null   # conflicts with oh-my-zsh git plugin
    eval "$(zoxide init zsh)"
fi

# ─── fzf ──────────────────────────────────────────────────────────────
if command -v fzf &>/dev/null; then
    eval "$(fzf --zsh 2>/dev/null)" || { [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh; }
    export FZF_DEFAULT_OPTS=" \
      --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
      --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
      --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
      --border --height=40%"
fi

# ─── Machine-local overrides (not tracked in dotfiles) ───────────────
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# ─── NVM (lazy-loaded for fast shell startup) ─────────────────────────
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    _nvm_load() { unset -f nvm node npm npx; \. "$NVM_DIR/nvm.sh"; [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"; }
    nvm()  { _nvm_load; nvm  "$@"; }
    node() { _nvm_load; node "$@"; }
    npm()  { _nvm_load; npm  "$@"; }
    npx()  { _nvm_load; npx  "$@"; }
fi

export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST

# ─── Optional integrations (only loaded if present) ──────────────────
[ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ]       && source "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"
[ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ]  && source "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"
[ -d /usr/local/anaconda3/bin ]    && export PATH=/usr/local/anaconda3/bin:$PATH
[ -d /opt/homebrew/anaconda3/bin ] && export PATH=/opt/homebrew/anaconda3/bin:$PATH
