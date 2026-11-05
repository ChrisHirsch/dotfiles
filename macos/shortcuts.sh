#!/bin/bash
# System keyboard shortcuts (System Settings > Keyboard > Keyboard Shortcuts).
# Safe to re-run.
#
# Each entry in com.apple.symbolichotkeys is keyed by a numeric action ID with
# parameters (ascii code, virtual key code, modifier mask).
# Modifier masks: shift 131072, control 262144, option 524288, command 1048576.
#
# Set WINDOW_MANAGER=aerospace to disable the native desktop shortcuts, since
# AeroSpace workspaces use the same keys.

desktops=9
plist=~/Library/Preferences/com.apple.spaces.plist

desktop_count() {
  plutil -extract "SpacesDisplayConfiguration.Management Data.Monitors.0.Spaces" raw -o - "$plist" 2> /dev/null || echo 0
}

hotkey() {
  local id=$1 enabled=$2 ascii=$3 keycode=$4 modifiers=$5
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" "
    <dict>
      <key>enabled</key><${enabled}/>
      <key>value</key><dict>
        <key>type</key><string>standard</string>
        <key>parameters</key><array>
          <integer>${ascii}</integer>
          <integer>${keycode}</integer>
          <integer>${modifiers}</integer>
        </array>
      </dict>
    </dict>"
}

disable_hotkey() {
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$1" "<dict><key>enabled</key><false/></dict>"
}

if [ "$WINDOW_MANAGER" == "aerospace" ]; then
  echo "Disabling native desktop shortcuts in favor of AeroSpace..."
  for id in 79 80 81 82 118 119 120 121 122 123 124 125 126; do
    disable_hotkey "$id"
  done
else
  # macOS has no API to create desktops, so wait for them to be added by hand
  while [ "$(desktop_count)" -lt "$desktops" ]; do
    echo "Found $(desktop_count) desktops, need ${desktops}."
    echo "Open Mission Control (Ctrl-Up), click + at the top right until there are ${desktops} desktops, then press Enter."
    read -r
  done

  echo "Setting Cmd-1..${desktops} to switch desktops..."
  # Virtual key codes for the 1-9 keys are not sequential
  keycodes=(18 19 20 21 23 22 26 28 25)
  for i in $(seq 1 "$desktops"); do
    hotkey $((117 + i)) true $((48 + i)) "${keycodes[$((i - 1))]}" 1048576
  done

  echo "Setting Ctrl-Left/Right to move between desktops..."
  hotkey 79 true 65535 123 8650752
  hotkey 80 true 65535 123 8781824
  hotkey 81 true 65535 124 8650752
  hotkey 82 true 65535 124 8781824
fi

echo "Disabling accessibility, zoom, and input source shortcuts..."
for id in 15 16 17 18 19 20 21 22 23 24 25 26 60 61 164; do
  disable_hotkey "$id"
done

# Apply without logging out
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
