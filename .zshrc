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
    if [[ -z "$AWS_PROFILE" && -z "$KUBECONFIG" && -z "$DISCO_NAMESPACE" ]]; then
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
    disco_profile="$DISCO_NAMESPACE:$DISCO_REALM:$DISCO_HTH"
    echo "( %{$fg[$aws_profile_color]%}$AWS_PROFILE%{$reset_color%} | %{$fg[$kube_config_color]%}$kube_config%{$reset_color%} | %{$fg[green]%}$disco_profile%{$reset_color%} )"
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

if [ $commands[aws] ]; then
    esprofile() {
        cluster_name="$1"
        aws_profile="prod-cep-metadata-api-team"
        tools_pod=""
        case "$cluster_name" in
            us1-test-content)
                aws_region="eu-west-1"
                kubernetes_cluster="eu-west-1-test-v2"
                namespace="sonic-test"
                aws_profile="test-cep-metadata-api-team"
                cluster_name="test-content"
                ;;
            ap2-test-*|ap-southeast-1-test-search)
                aws_region="ap-southeast-1"
                kubernetes_cluster="ap-southeast-1-test-v1"
                namespace="ap2-test"
                aws_profile="test-cep-metadata-api-team"
                ;;
            us1-*)
                aws_region="us-east-1"
                kubernetes_cluster="us-east-1-prod-v1"
                namespace="us1-prod"
                ;;
            ap1-*)
                aws_region="ap-northeast-1"
                kubernetes_cluster="ap-northeast-1-prod-v2"
                namespace="ap1-prod"
                ;;
            ap2-*)
                aws_region="ap-southeast-1"
                kubernetes_cluster="ap-southeast-1-prod-v1"
                namespace="ap2-prod"
                ;;
            eu-int-*)
                aws_region="eu-west-1"
                kubernetes_cluster="workload-eu-west-1-int-v1"
                namespace="eu-int"
                aws_profile="test-cep-metadata-api-team"
                ;;
            eu-west-1-test-search)
                aws_region="eu-west-1"
                namespace="eu1-test"
                kubernetes_cluster="eu-west-1-test-v2"
                aws_profile="test-cep-metadata-api-team"
                ;;
            eu*)
                aws_region="eu-west-1"
                kubernetes_cluster="eu-west-1-prod-v1"
                namespace="eu1-prod"
                ;;
            localhost)
                tools_pod="localhost"
                namespace="localhost"
                endpoint="http://localhost:9200"
                ;;
            *)
                aws_region="eu-west-1"
                kubernetes_cluster="eu-west-1-test-v2"
                namespace="sonic-test"
                ;;
        esac

        if [[ "$tools_pod" != "localhost" ]]; then
            export KUBECONFIG="$HOME/.kube/$kubernetes_cluster"
            export AWS_PROFILE="$aws_profile"

            endpoint="https://$(aws --region "$aws_region" \
                es describe-elasticsearch-domains \
                --domain-names "$cluster_name" \
                --output text \
                --query 'DomainStatusList[0].Endpoints.vpc')"

            tools_pod=$(kubectl get pods \
                --namespace "$namespace" \
                --selector 'app=tools-pod' \
                --output jsonpath='{.items[0].metadata.name}')
        fi

        export DISCOVERY_TOOLS_POD="$tools_pod"
        export DISCOVERY_TOOLS_POD_NAMESPACE="$namespace"
        export ES_ENDPOINT="$endpoint"
    }

    _esprofile() {
      _alternative \
        "args:elasticsearch cluster:(\
        localhost \
        ap2-prod-content-es7 \
        eu1-prod-content-es7 \
        eu2-prod-content-es7 \
        eu3-prod-content-es7 \
        us1-prod-content-es7 \
        ap2-prod-shared \
        eu1-prod-shared \
        eu2-prod-shared \
        eu3-prod-shared \
        us1-prod-shared \
        eu-int-content-es7 \
        ap2-test-content \
        eu1-test-content \
        us1-test-content \
        ap2-test-shared \
        test-content \
        test-shared \
        ap-southeast-1-test-search \
        eu-west-1-test-search \
        sonic-test-content \
        sonic-test-shared)"
    }
    compdef _esprofile esprofile
fi

if [ $commands[disco] ]; then
    discoprofile() {
        disco_namespace="${1%:*}"
        disco_realm="${1#*:}"
        disco_hth="${disco_realm#*_}"
        if [[ -n "$disco_hth" ]]; then
            disco_realm="${disco_realm%_*}"
        else
            disco_hth="se"
        fi

        disco_host="$disco_namespace.disco-api.com"
        if [[ "$disco_namespace" == "eu-int" ]]; then
            disco_host="eu.int.disco-api.com"
        fi
        if [[ "$disco_realm" == "dplay" ]]; then
            if [[ "$disco_namespace" == "*-test" ]]; then
                disco_hn="test.hashbuild.discoveryplus.com"
            else
                disco_hn="www.discoveryplus.com"
            fi
            x_disco_params="realm=$disco_realm,bid=dplus,hn=$disco_hn,hth=$disco_hth"
        else
            x_disco_params="realm=$disco_realm"
        fi
        disco_token=$(curl \
            --silent \
            --request GET \
            --get \
            --header "x-disco-params: $x_disco_params"\
            --data-urlencode "realm=$disco_realm" \
            "https://$disco_host/token" \
            | jq --raw-output '.data.attributes.token')
        # if [[ -n "$2" ]]; then
        #     username="$2"
        #     echo -n "Enter password for $username: "
        #     read -s password
        #     curl \
        #         --silent \
        #         --request POST \
        #         --header "Content-Type: application/json" \
        #         --header "Authorization: Bearer $disco_token" \
        #         --header "x-disco-params: $x_disco_params"\
        #         --data-binary "{\"credentials\":{\"username\":\"$username\",\"password\":\"$password\"}}" \
        #         "https://$disco_host/login" \
        #         | jq '.'
        #
        # fi
        export DISCO_TOKEN="$disco_token"

        export DISCO_NAMESPACE="$disco_namespace"
        export DISCO_REALM="$disco_realm"
        export DISCO_HTH="$disco_hth"
    }

    _discoprofile() {
      _alternative \
        "args:Disco Environment:(\
        ap2-prod:dplusapac \
        ap2-prod:dplusindia \
        eu1-prod:dmaxde \
        eu1-prod:dplay_at \
        eu1-prod:dplay_de \
        eu1-prod:dplay_dk \
        eu1-prod:dplay_es \
        eu1-prod:dplay_fi \
        eu1-prod:dplay_ie \
        eu1-prod:dplay_it \
        eu1-prod:dplay_nl \
        eu1-prod:dplay_no \
        eu1-prod:dplay_se \
        eu1-prod:dplay_uk \
        eu1-prod:dplaydk \
        eu1-prod:dplayfi \
        eu1-prod:dplayno \
        eu1-prod:dplayse \
        eu1-prod:hgtv \
        eu1-prod:questuk \
        eu1-prod:tlcde \
        eu2-prod:dplayes \
        eu2-prod:dplayit \
        eu2-prod:dplaynl \
        eu2-prod:loma \
        eu3-prod:eurosport \
        us1-prod:dkidses \
        us1-prod:dkidsonpt \
        us1-prod:dkidspt \
        us1-prod:factual \
        us1-prod:foodnetwork \
        us1-prod:gcn \
        us1-prod:go \
        us1-prod:motortrend \
        eu-int:dplay \
        eu1-test:dmaxde \
        eu1-test:dplay_at \
        eu1-test:dplay_de \
        eu1-test:dplay_dk \
        eu1-test:dplay_es \
        eu1-test:dplay_fi \
        eu1-test:dplay_ie \
        eu1-test:dplay_it \
        eu1-test:dplay_nl \
        eu1-test:dplay_no \
        eu1-test:dplay_se \
        eu1-test:dplay_uk \
        eu1-test:dplaydk \
        eu1-test:dplaydkdev \
        eu1-test:dplayfi \
        eu1-test:dplayno \
        eu1-test:dplayse \
        eu1-test:eurosport \
        eu1-test:hgtv \
        eu1-test:luna \
        eu1-test:lunadev \
        eu1-test:questuk \
        eu1-test:tlcde \
        eu2-test:dplayes \
        eu2-test:dplayit \
        eu2-test:dplaynl \
        us1-test:dkidses \
        us1-test:dkidsonpt \
        us1-test:dkidspt \
        us1-test:dplayjp \
        us1-test:dplusindia \
        us1-test:factual \
        us1-test:foodnetwork \
        us1-test:gcn \
        us1-test:go \
        us1-test:magnolia \
        us1-test:motortrend \
        sonic-test:dplaydk \
        sonic-test:dplayno \
        sonic-test:dplayse \
        sonic-test:eurosport)"
    }
    compdef _discoprofile discoprofile

    _disco() {
      _alternative \
        "args:Disco CLI paths:(\
        '/cms/articles/:id include=default' \
        /cms/collections/:id \
        /cms/configs/:id \
        /cms/links/:id \
        /cms/rawContents/:id \
        /cms/recommendations/nextVideos \
        '/cms/routes/:routePath include=default' \
        /content/channels/:alternateId \
        /content/channels/:id \
        /content/genres \
        /content/genres/:alternateId \
        /content/genres/:id \
        /content/serverTime \
        '/content/showletters filter[letter]=:letters' \
        /content/shows \
        /content/shows/:alternateId \
        /content/shows/:id \
        /content/videos \
        /content/videos/:id \
        '/content/videos/:id/next algorithm=:algorithm' \
        /content/videos/:showAlternateId/:videoAlternateId \
        /content/videos/:showAlternateId/activeVideoForShow \
        /contentrestrictions/levels \
        /entitlements/userEntitlementsSummary/me \
        /legal/consents \
        /legal/consents/:id \
        /legal/terms \
        /legal/terms/:id \
        /monetization/priceplans/:id \
        /monetization/products \
        /monetization/products/:id \
        /monetization/products/:id/addons \
        /monetization/subscriptions \
        /monetization/subscriptions/:id \
        /packages \
        '/playback/channelPlaybackInfo/channelId usePreAuth=true' \
        '/playback/channelPlaybackInfo/sourceSystemId/channelSsid usePreAuth=true' \
        /playback/history \
        '/playback/videoPlaybackInfo/:videoId usePreAuth=true' \
        '/playback/videoPlaybackInfo/sourceSystemId/videoSsid usePreAuth=true' \
        /settings/languageTags \
        '/token realm=:realm' \
        /users/me \
        /users/me/details \
        '/users/me/favorites/:type include=default' \
        '/users/me/favorites include=default' \
        /users/me/profiles \
        /users/me/profiles/:id \
        /users/me/profiles/:id/pin \
        /users/me/profiles/selected \
        /users/me/tokens)"
    }
    compdef _disco disco
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
        nix-shell -I /nix/var/nix/profiles/per-user/andreas/channels-13-link/unstable "$HOME/nix-shells/$1" --run zsh
        # nix-shell "$HOME/nix-shells/$1" --run zsh
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
