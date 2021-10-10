#!/usr/bin/env bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

ln --symbolic "$DIR/.inputrc" ~/.inputrc
ln --symbolic "$DIR/.vimrc" ~/.vimrc
ln --symbolic "$DIR/.gitconfig" ~/.gitconfig

command -v zsh > /dev/null 2>&1 && {
    ln --symbolic "$DIR/.zshrc" ~/.zshrc && \
        ln --symbolic "$DIR/.zsh" ~/.zsh
}

command -v tmux > /dev/null 2>&1 && {
    ln --symbolic "$DIR/.tmux.conf" ~/.tmux.conf
}

command -v xmonad > /dev/null 2>&1 && {
    ln --symbolic "$DIR/.Xresources" ~/.Xresources && \
        rm --recursive --force ~/.xmonad; \
        ln --symbolic "$DIR/.xmonad" ~/.xmonad
}

(command -v chromium > /dev/null 2>&1 || command -v chromium-browser > /dev/null 2>&1) && {
    sudo mkdir --parents /etc/chromium/policies/managed && \
        sudo cp "$DIR/chrome-extensions-policy.json" /etc/chromium/policies/managed/
}

for cmd in alacritty i3 htop yamllint; do
    command -v "$cmd" > /dev/null 2>&1 && {
        rm --recursive --force "$HOME/.config/$cmd"; \
            ln --symbolic "$DIR/.config/$cmd" "$HOME/.config/$cmd"
    }
done
