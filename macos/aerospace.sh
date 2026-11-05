#!/bin/bash
# Installs AeroSpace and links its config. Safe to re-run.

if [ ! -d /Applications/AeroSpace.app ]; then
  echo "Installing AeroSpace..."
  brew install --cask nikitabobko/tap/aerospace
fi

mkdir -p ~/.config/aerospace
ln -sf ~/dotfiles/aerospace/aerospace.toml ~/.config/aerospace/aerospace.toml

# Recommended by the AeroSpace guide. "Displays have separate Spaces" takes
# effect after logging out.
echo "Setting Mission Control options for AeroSpace..."
defaults write com.apple.dock expose-group-apps -bool true
defaults write com.apple.spaces spans-displays -bool true
killall Dock

echo "Quitting Rectangle so it does not compete for window shortcuts..."
osascript -e 'quit app "Rectangle"' 2> /dev/null

open -a AeroSpace
