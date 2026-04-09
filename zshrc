# If you come from bash you might have to change your $PATH.
# /opt/homebrew/bin: Apple Silicon Homebrew
# /usr/local/bin: Intel Homebrew / standard Linux
# ~/.local/bin: pip, oh-my-posh (Linux), etc.
export PATH=$HOME/bin:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH

# Disable terminal flow control so C-s passes through (for save keybinds)
stty -ixon 2>/dev/null

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# Disable oh-my-zsh theme when oh-my-posh is available (it handles the prompt)
if command -v oh-my-posh &>/dev/null || [ -x "$HOME/.local/bin/oh-my-posh" ]; then
    ZSH_THEME=""
else
    ZSH_THEME="robbyrussell"
fi

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable auto-setting terminal title.
DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Command execution timestamp
# see 'man strftime' for details.
HIST_STAMPS="yyyy-mm-dd"

# Plugins
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
plugins=(git zsh-autosuggestions)

if [ -f "$ZSH/oh-my-zsh.sh" ]; then
    source "$ZSH/oh-my-zsh.sh"
fi

# zsh-syntax-highlighting: check Homebrew (macOS) then common Linux paths
if [ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [ -f /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# User configuration
export EDITOR=nvim
export VISUAL="$EDITOR"

# Double-space to accept and run the autosuggestion; single space types normally.
_double_space_execute() {
    if [[ "$LBUFFER" == *" " ]] && [[ -n "$POSTDISPLAY" ]]; then
        zle autosuggest-execute
    else
        zle self-insert
    fi
}
zle -N _double_space_execute
bindkey ' ' _double_space_execute

_omp_bin=""
if command -v oh-my-posh &>/dev/null; then
    _omp_bin="oh-my-posh"
elif [ -x "$HOME/.local/bin/oh-my-posh" ]; then
    _omp_bin="$HOME/.local/bin/oh-my-posh"
fi
if [ -n "$_omp_bin" ]; then
    _omp_theme="catppuccin_mocha.omp.json"
    _omp_config=""
    if command -v brew &>/dev/null; then
        _omp_config="$(brew --prefix oh-my-posh)/themes/$_omp_theme"
    elif [ -f "$HOME/.cache/oh-my-posh/themes/$_omp_theme" ]; then
        _omp_config="$HOME/.cache/oh-my-posh/themes/$_omp_theme"
    elif [ -f "/usr/local/share/oh-my-posh/themes/$_omp_theme" ]; then
        _omp_config="/usr/local/share/oh-my-posh/themes/$_omp_theme"
    fi
    if [ -n "$_omp_config" ] && [ -f "$_omp_config" ]; then
        eval "$("$_omp_bin" init zsh --config "$_omp_config")"
    else
        eval "$("$_omp_bin" init zsh)"
    fi
    unset _omp_theme _omp_config _omp_bin
fi

export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
 export EDITOR='vim'
else
 export EDITOR='nvim'
fi

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
alias nv="nvim"
alias c="clear"

command -v eza &>/dev/null && alias l="eza -la --icons --no-user --group-directories-first --time-style long-iso"
command -v lazygit &>/dev/null && alias lg="lazygit"
if command -v zoxide &>/dev/null; then
    unalias z 2>/dev/null
    eval "$(zoxide init zsh)"
fi
command -v gmktemp &>/dev/null && alias mktemp="gmktemp"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST

# Google Cloud SDK
if [ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ]; then
    source "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"
fi
if [ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ]; then
    source "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"
fi

[ -d /usr/local/anaconda3/bin ] && export PATH=/usr/local/anaconda3/bin:$PATH
[ -d /opt/homebrew/anaconda3/bin ] && export PATH=/opt/homebrew/anaconda3/bin:$PATH
