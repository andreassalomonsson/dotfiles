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
autoload -U colors && colors
setopt prompt_subst
PS1=$'%{\e[01;92m%n@%m%}%{\e[0m:%}%{\e[01;94m%~%}\n%(?..%{\e[01;91m%}[%?])%# %{\e[0m%}'
PS4='+%N:%i:%_>'

RPROMPT='$(rprompt)'
function rprompt {
    if [[ -z "$AWS_PROFILE" && -z "$KUBECONFIG" ]]; then
        return
    fi
    if [[ "$AWS_PROFILE" =~ "prod" && ! "$AWS_PROFILE" =~ "readonly" ]]; then
        aws_profile_color="red"
    else
        aws_profile_color="green"
    fi
    if [[ "$KUBECONFIG" =~ "prod" ]]; then
        kube_config_color="red"
    else
        kube_config_color="green"
    fi
    if [[ ! -z "$KUBECONFIG" ]]; then
        kube_config="$(basename $KUBECONFIG)"
    fi
    echo "( %{$fg[$aws_profile_color]%}$AWS_PROFILE%{$reset_color%} | %{$fg[$kube_config_color]%}$kube_config%{$reset_color%} )"
}

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

    kubeconfig() {
        local new_config="$1"
        if [[ -z "$new_config" ]]; then
            new_config=$(find "$HOME/.kube" -maxdepth 1 -type f \
                | xargs --max-args 1 basename \
                | fzf --header 'Cluster')
        fi
        if [[ -z "$new_config" ]]; then
            return
        fi
        if [[ ! -f "$HOME/.kube/$new_config" ]]; then
            echo 1>&2 "ERROR: Kube config file not found $HOME/.kube/$new_config"
            return
        fi
        export KUBECONFIG="$HOME/.kube/$new_config"
    }

    _kubeconfig() {
        _alternative \
            "args:kubernetes contexts:($(find "$HOME/.kube" -maxdepth 1 -type f \
                | xargs --max-args 1 basename))"
    }

    compdef _kubeconfig kubeconfig
fi

if [ $commands[aws] ]; then
    awsprofile()  {
        local new_aws_profile="$1"
        if [[ -z "$new_aws_profile" ]]; then
            new_aws_profile=$(env --unset=AWS_PROFILE aws configure list-profiles \
                | fzf --header "AWS profile")
        fi
        if [[ -z "$new_aws_profile" ]]; then
            return
        fi
        if ! aws --profile "$new_aws_profile" sts get-caller-identity > /dev/null 2>&1; then
            bwpass 'discovery sso' > /dev/null  # exports BW_SESSION
            expect-gimme-aws-creds "$new_aws_profile" "$(bwpass 'discovery sso')"
        fi
        export AWS_PROFILE="$new_aws_profile"
        aws sts get-caller-identity
    }

    _awsprofile() {
        _alternative \
            "args:aws profiles:($(aws configure list-profiles))"
    }

    compdef _awsprofile awsprofile

    awsecrlogin()  {
        aws_account_id=$(aws sts get-caller-identity --query 'Account' --output text)
        aws --region "eu-west-1" ecr get-login-password \
            | docker login \
                --username AWS \
                --password-stdin \
                "https://$aws_account_id.dkr.ecr.eu-west-1.amazonaws.com"
    }

    if [ $commands[aws_completer] ]; then
        autoload bashcompinit && bashcompinit
        complete -C "$(which aws_completer)" aws
    fi
fi

if [ $commands[aws] ] && [ $commands[kubectl] ]; then
    ktoolscurl() {
        cluster="$1"
        if [[ -z "$cluster" ]]; then
            cluster="$(find "$HOME/.kube" -maxdepth 1 -name '*' -exec basename {} \; \
                | grep --extended-regexp 'test|prod' \
                | fzf --header 'cluster')"
        fi

        namespace="$2"
        if [[ -z "$namespace" ]]; then
            namespace="$(KUBECONFIG="$HOME/.kube/$cluster" kubectl get namespaces \
                    --output 'custom-columns=:.metadata.name' \
                    --no-headers \
                    | grep --extended-regexp 'test|prod' \
                    | fzf --header 'namespace')"
        fi

        service="$3"
        if [[ -z "$service" ]]; then
            service="$(KUBECONFIG="$HOME/.kube/$cluster" kubectl get services \
                    --namespace "$namespace" \
                    --output 'custom-columns=:.metadata.name' \
                    --no-headers \
                    | fzf --header 'service')"
        fi

        port="$4"
        if [[ -z "$port" ]]; then
            port="$(KUBECONFIG="$HOME/.kube/$cluster" kubectl get services \
                --namespace "$namespace" \
                "$service" \
                --output 'json' \
                | jq '.spec.ports[].port' \
                | fzf --header 'port')"
        fi

        tools_pod="$(KUBECONFIG="$HOME/.kube/$cluster" kubectl get pods \
            --namespace "$namespace" \
            --selector 'app=tools-pod' \
            --output 'custom-columns=:.metadata.name' \
            --no-headers \
            | head --lines 1)"

        request_path="$5"
        if [[ -z "$request_path" ]]; then
            request_path="/private/appConfig"
        fi

        KUBECONFIG="$HOME/.kube/$cluster" kubectl exec \
            --namespace "$namespace" \
            --stdin \
            --tty \
            "$tools_pod" \
            -- \
                curl "http://$service:$port$request_path"
    }
fi

if [ $commands[aws] ] && [ $commands[kubectl] ]; then
    ktoolspod() {
        cluster="$1"
        if [[ -z "$cluster" ]]; then
            cluster="$(find "$HOME/.kube" -maxdepth 1 -name '*' -exec basename {} \; \
                | grep --extended-regexp 'test|prod' \
                | fzf --header 'cluster')"
        fi

        namespace="$2"
        if [[ -z "$namespace" ]]; then
            namespace="$(KUBECONFIG="$HOME/.kube/$cluster" kubectl get namespaces \
                    --output 'custom-columns=:.metadata.name' \
                    --no-headers \
                    | grep --extended-regexp 'test|prod' \
                    | fzf --header 'namespace')"
        fi

        tools_pod="$(KUBECONFIG="$HOME/.kube/$cluster" kubectl get pods \
            --namespace "$namespace" \
            --selector 'app=tools-pod' \
            --output 'custom-columns=:.metadata.name' \
            --no-headers \
            | head --lines 1)"

        if [[ -z "$3" ]]; then
            KUBECONFIG="$HOME/.kube/$cluster" kubectl exec \
                --namespace "$namespace" \
                --stdin \
                --tty \
                "$tools_pod" \
                -- \
                    /bin/bash
        else
            KUBECONFIG="$HOME/.kube/$cluster" kubectl exec \
                --namespace "$namespace" \
                --stdin \
                --tty \
                "$tools_pod" \
                -- \
                    ${@:3}
        fi
    }
fi

if [ $commands[kafkacli] ]; then
    _kafkacli() {
        _arguments '1: :->cluster' '2: :->script'
            case $state in
                cluster)
                    _describe 'command' "($(kafkacli zsh-completion 1))"
                    ;;
                script)
                    _describe 'command' "($(kafkacli zsh-completion 2))"
                    ;;
            esac
    }
    compdef _kafkacli kafkacli
fi

if [ $commands[gimme-aws-creds] ]; then
    _gimme-aws-creds() {
      _arguments \
        "-p[gimme-aws-creds profile]:profile:->profiles" \
        "--profile[gimme-aws-creds profile]:profile:->profiles"
      case "$state" in
        profiles)
          _alternative \
            "args:gimme-aws-creds profiles:($(gimme-aws-creds --action-list-profiles | grep '^\[.*\]$' | tr -d '[]'))"
          ;;
      esac
    }
    compdef _gimme-aws-creds gimme-aws-creds
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
