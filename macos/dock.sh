#!/bin/bash
# Rebuilds the Dock from scratch. Safe to re-run.
# Apps that are not installed are skipped.

if ! command -v dockutil > /dev/null; then
  echo "dockutil not found, run brew bundle first"
  exit 1
fi

apps=(
  "/System/Applications/Apps.app"
  "/Applications/Safari.app"
  "/Applications/Google Chrome.app"
  "/System/Applications/Messages.app"
  "/System/Applications/Mail.app"
  "/System/Applications/Maps.app"
  "/System/Applications/Photos.app"
  "/System/Applications/FaceTime.app"
  "/Applications/Numbers.app"
  "/System/Applications/Calendar.app"
  "/System/Applications/Contacts.app"
  "/System/Applications/Reminders.app"
  "/System/Applications/Notes.app"
  "/System/Applications/Freeform.app"
  "/System/Applications/TV.app"
  "/System/Applications/Music.app"
  "/System/Applications/News.app"
  "/Applications/Keynote.app"
  "/Applications/Pages.app"
  "/System/Applications/App Store.app"
  "/System/Applications/System Settings.app"
)

echo "Setting Dock preferences..."
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock orientation -string left
defaults write com.apple.dock magnification -bool true

echo "Rebuilding Dock items..."
dockutil --remove all --no-restart
for app in "${apps[@]}"; do
  if [ -e "$app" ]; then
    dockutil --add "$app" --no-restart
  else
    echo "Skipping missing app: $app"
  fi
done
dockutil --add ~/Downloads --view fan --display stack --sort dateadded --no-restart

killall Dock
