# key bindings
bindkey -v
bindkey '^w' backward-kill-word
bindkey '^r' history-incremental-search-backward
export KEYTIMEOUT=1

# aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -alFh'

# history
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=1000
setopt extended_history
setopt append_history
setopt share_history
setopt hist_find_no_dups
setopt hist_ignore_space

# prompts
setopt prompt_subst
PS1=$'%{\e[01;92m%n@%m%}%{\e[0m:%}%{\e[01;94m%~%}\n%(?..%{\e[01;91m%}[%?])%# %{\e[0m%}'
PS4='+%N:%i:%_>'
RPROMPT=""

# completion
zmodload zsh/complist
setopt complete_in_word
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*:defualt' menu 'select=0'
zstyle ':completion::*:::' completer _complete _prefix

# Enable ESC v to edit command line
autoload -U edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

. ~/.zsh/terminal.zsh

export JQ_COLORS="1;32:0;39:0;39:0;39:0;32:1;39:1;39"
