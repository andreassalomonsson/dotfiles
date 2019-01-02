#!/usr/bin/env bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

ln -s ${DIR}/.inputrc ~/.inputrc
ln -s ${DIR}/.vimrc ~/.vimrc
ln -s ${DIR}/.gitconfig ~/.gitconfig

command -v zsh > /dev/null 2>&1 && {
    ln -s ${DIR}/.zshrc ~/.zshrc && \
    ln -s ${DIR}/.zsh ~/.zsh
}

command -v tmux > /dev/null 2>&1 && {
    ln -s ${DIR}/.tmux.conf ~/.tmux.conf
}

command -v xmonad > /dev/null 2>&1 && {
    ln -s ${DIR}/.Xresources ~/.Xresources && \
    rm -rf ~/.xmonad; ln -s ${DIR}/.xmonad ~/.xmonad
}

command -v i3 > /dev/null 2>&1 && {
    rm -rf ~/.config/i3; ln -s ${DIR}/.config/i3 ~/.config/i3
}

command -v chromium-browser > /dev/null 2>&1 && {
    sudo cp chrome-extensions-policy.json /etc/chromium-browser/policies/managed/
}
