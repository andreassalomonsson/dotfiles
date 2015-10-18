#!/usr/bin/env bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

ln -s ${DIR}/.inputrc ~/.inputrc && \

ln -s ${DIR}/.zshrc ~/.zshrc && \
ln -s ${DIR}/.zsh ~/.zsh && \

ln -s ${DIR}/.tmux.conf ~/.tmux.conf && \

ln -s ${DIR}/.vimrc ~/.vimrc && \

ln -s ${DIR}/.Xresources ~/.Xresources && \

ln -s ${DIR}/.xmonad ~/.xmonad && \

ln -s ${DIR}/.gitconfig ~/.gitconfig
