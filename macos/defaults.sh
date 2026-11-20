#!/bin/bash
# System and app preferences. Safe to re-run.

echo "Repeating held keys instead of showing the accent menu (for vi mode)..."
defaults write -g ApplePressAndHoldEnabled -bool false

echo "Showing hidden files in Finder..."
defaults write com.apple.finder AppleShowAllFiles -bool true

killall Finder
