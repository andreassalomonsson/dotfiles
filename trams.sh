#!/usr/bin/env bash

set -euo pipefail

username="andreas"
home="/home/$username"

mkdir --parents "$home/code"

if [ ! -d "$home/code/dotfiles" ]; then
    git clone https://github.com/andreassalomonsson/dotfiles.git "$home/code/dotfiles"
    "$home/code/dotfiles/install.sh"
fi

gnome_terminal_profile=$(gsettings get org.gnome.Terminal.ProfilesList default)
gnome_terminal_profile=${gnome_terminal_profile:1:-1}
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$gnome_terminal_profile/" use-custom-command "true"
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$gnome_terminal_profile/" custom-command "'env TERM=screen-256color tmux -2'"

if [ ! -d "$home/code/gnome-terminal-colors-solarized" ]; then
    git clone https://github.com/Anthony25/gnome-terminal-colors-solarized.git "$home/code/gnome-terminal-colors-solarized"
    "$home/code/gnome-terminal-colors-solarized/install.sh" --scheme dark --profile "$gnome_terminal_profile" --skip-dircolors
fi
