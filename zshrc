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

# ─── Keybinds ─────────────────────────────────────────────────────────
# Double-space accepts and runs the autosuggestion; single space is normal.
_double_space_execute() {
    if [[ "$LBUFFER" == *" " ]] && [[ -n "$POSTDISPLAY" ]]; then
        zle autosuggest-execute
    else
        zle self-insert
    fi
}
zle -N _double_space_execute
bindkey ' ' _double_space_execute

# ─── Aliases ──────────────────────────────────────────────────────────
alias nv="nvim"
alias c="clear"
command -v eza     &>/dev/null && alias l="eza -la --icons --no-user --group-directories-first --time-style long-iso"
command -v lazygit &>/dev/null && alias lg="lazygit"
command -v gmktemp &>/dev/null && alias mktemp="gmktemp"

# ─── Tools ────────────────────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
    unalias z 2>/dev/null   # conflicts with oh-my-zsh git plugin
    eval "$(zoxide init zsh)"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ]          && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST

# ─── Optional integrations (only loaded if present) ──────────────────
[ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ]       && source "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"
[ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ]  && source "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"
[ -d /usr/local/anaconda3/bin ]    && export PATH=/usr/local/anaconda3/bin:$PATH
[ -d /opt/homebrew/anaconda3/bin ] && export PATH=/opt/homebrew/anaconda3/bin:$PATH
