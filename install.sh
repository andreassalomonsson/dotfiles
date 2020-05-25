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

command -v i3 > /dev/null 2>&1 && {
    rm --recursive --force ~/.config/i3; \
        ln --symbolic "$DIR/.config/i3" ~/.config/i3
}

command -v alacritty > /dev/null 2>&1 && {
    rm --recursive --force ~/.config/alacritty; \
        ln --symbolic "$DIR/.config/alacritty" ~/.config/alacritty
}

(command -v chromium > /dev/null 2>&1 || command -v chromium-browser > /dev/null 2>&1) && {
    sudo mkdir --parents /etc/chromium/policies/managed && \
        sudo cp "$DIR/chrome-extensions-policy.json" /etc/chromium/policies/managed/
}
