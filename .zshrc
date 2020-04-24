# key bindings
bindkey -v
bindkey '^w' backward-kill-word
bindkey '^r' history-incremental-search-backward
export KEYTIMEOUT=1

# aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -alFh'
alias xcopy='xclip -selection clipboard'
alias xpaste='xclip -selection clipboard -out'

# history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt extended_history
setopt append_history
setopt share_history
setopt hist_find_no_dups
setopt hist_ignore_space
setopt hist_reduce_blanks

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

if [ $commands[kubectl] ]; then
    alias k=kubectl

    function kc {
        local new_context="$1"
        if [[ -z "$new_context" ]]; then
          new_context=$(kubectl config get-contexts | fzf --header-lines=1 | cut -c 2- | sed -e 's/^[[:space:]]*//' | cut -f1 -d' ')
        fi
        if [[ -n "$new_context" ]]; then
          kubectl config use-context "$new_context"
        else
          echo "Aborting."
        fi
    }

    function kns  {
        local new_namespace="$1"
        if [[ -z "$new_namespace" ]]; then
          new_namespace=$(kubectl get namespaces --output=custom-columns=:.metadata.name \
              | fzf --select-1 --preview "kubectl --namespace {} get pods")
        fi
        if [[ -n "$new_namespace" ]]; then
            echo "Setting namespace to $new_namespace"
            kubectl config set-context "$(kubectl config current-context)" --namespace="$new_namespace"
        fi
    }
fi

if [ $commands[aws_completer] ]; then
    autoload bashcompinit && bashcompinit
    complete -C '/usr/local/bin/aws_completer' aws
fi

if [ -f "$HOME/.cargo/env" ]; then
    source $HOME/.cargo/env
fi
