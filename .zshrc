# key bindings
bindkey -v
bindkey '^w' backward-kill-word
bindkey '^r' history-incremental-search-backward
export KEYTIMEOUT=1

# aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ip='ip --color=auto'
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
autoload -Uz compinit
compinit

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

if [ $commands[bw] ]; then
    bwpass() {
        bw_create_session() {
            if ! bw login --check > /dev/null 2>&1; then
                bw login
            elif ! (echo "" | bw list items > /dev/null 2>&1); then
                bw unlock
            else
                echo "export BW_SESSION=\"$BW_SESSION\""
            fi
        }

        bw_get_session() {
            while true; do
                session_output="$(bw_create_session)"
                if [[ -n "$session_output" ]]; then
                    break
                fi
            done
            if [[ -n "$session_output" ]]; then
                export BW_SESSION="$(echo "$session_output" \
                    | grep "export" \
                    | sed -r 's/.*BW_SESSION="(.*)".*/\1/g')"
            fi
        }

        bw_get_session
        unfunction bw_create_session
        unfunction bw_get_session

        if [[ -z "$1" ]]; then
            result="$(bw list items)"
        else
            search_term="$1"
            result="$(bw list items --search "$search_term")"
        fi

        if echo -E "$result" | grep --quiet 'Session key is invalid.'; then
            unset BW_SESSION
            result="$(echo -E "$result" | tail --lines +2)"
        fi

        number_of_results="$(echo -E "$result" | jq 'length')"

        if [[ "$number_of_results" == "1" ]]; then
            item_id="$(echo -E "$result" | jq --raw-output '.[0].id')"
            bw get password "$item_id"
        else
            >&2 echo "Usage: $(basename "$0") [search_term]"
            >&2 echo "Expected to find exactly on match, found $number_of_results."
            >&2 echo ""
            echo -E "$result" | jq --raw-output '.[] | .name + " (" + .login.uris[0].uri + ")"' >&2
        fi
    }
fi

if [ $commands[nix-shell] ]; then
    nixzsh()  {
        nix-shell "$HOME/nix-shells/$1" --run zsh
    }

    _nixzsh() {
        _alternative \
            "args:nix-shells:($(find "$HOME/nix-shells" -maxdepth 1 -type f \
                | xargs --max-args 1 basename))"
    }

    compdef _nixzsh nixzsh
fi

if [ -f "$HOME/.cargo/env" ]; then
    source $HOME/.cargo/env
fi
