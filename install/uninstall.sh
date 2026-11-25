#!/bin/bash
# Removes your personal accounts, credentials, and data from a Mac before you
# hand it back. Company-managed things stay as they are: MDM profiles, system
# logs, and work apps that aren't listed below.
#
#   ./uninstall.sh           dry run: the sign-out checklist, backup checks, and
#                            everything that would be removed (changes nothing)
#   ./uninstall.sh --remove  same, then removes each group after you confirm it
#
# Your data is moved or backed up first; the backup checks say what isn't yet.

# Homebrew casks with personal data. brew uninstall --zap removes the app and the
# data folders Homebrew knows about. Only installed ones are listed or removed.
# Each list can be overridden from the environment (set it to "" to skip).
MESSAGING_CASKS=${MESSAGING_CASKS-"pulse-sms signal slack discord whatsapp telegram zoom"}
KEYBASE_CASKS=${KEYBASE_CASKS-"keybase"}
BROWSER_CASKS=${BROWSER_CASKS-"firefox google-chrome brave-browser arc"}
PERSONAL_CASKS=${PERSONAL_CASKS-"spotify calibre yacreader obsidian cursor claude plex plexamp pocket-casts todoist-app evernote thunderbird"}
ONEPASSWORD_CASKS=${ONEPASSWORD_CASKS-"1password 1password-cli"}
# Apps installed outside Homebrew, removed with their data by bundle ID
PERSONAL_APPS=${PERSONAL_APPS-"Scribe"}

MODE=dry-run
[ "$1" = --remove ] && MODE=remove
REMOVED=()
# Every path already listed in a group, so later groups skip it
LISTED=()

if [ "$(uname -s)" != Darwin ]; then
  echo "This script is for macOS."
  exit 1
fi

bold() { printf '\n\033[1m%s\033[0m\n' "$*"; }
note() { printf '  %s\n' "$*"; }
# Paths print with ~ in place of $HOME. The ~ is a variable because bash 5
# tilde-expands a literal one in the replacement, which puts $HOME back.
short() {
  local tilde='~'
  printf '%s' "${1/#$HOME/$tilde}"
}

# Asks before something destructive; the default is no
confirm() {
  local reply
  read -r -p "  $1 [y/N] " reply
  [[ $reply =~ ^[Yy]$ ]]
}

site_var() {
  zsh -c "source ~/.site 2>/dev/null; print -r -- \$$1" 2>/dev/null
}

# --- Groups ----------------------------------------------------------------
# group "<name>" "<hint>", then add_* calls, then end_group lists the group and,
# with --remove, removes it after you confirm.

group() { GROUP=$1; GROUP_HINT=$2; PATHS=(); CASKS=(); }

add_path() {
  [ -e "$1" ] || [ -L "$1" ] || return 0
  local p
  for p in "${LISTED[@]}"; do
    [ "$p" = "$1" ] && return 0
    [[ $1 == "$p"/* ]] && return 0
  done
  PATHS+=("$1")
  LISTED+=("$1")
}

add_casks() {
  local c
  for c in "$@"; do
    brew list --cask "$c" > /dev/null 2>&1 && CASKS+=("$c")
  done
}

# An app installed outside Homebrew, and its data by name and bundle ID
add_app() {
  local app="/Applications/$1.app" bid p
  [ -d "$app" ] || return 0
  bid=$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null)
  add_path "$app"
  add_path ~/Library/Application\ Support/"$1"
  [ -n "$bid" ] || return 0
  for p in ~/Library/{Application\ Support,Caches,Containers,HTTPStorages,WebKit,Logs}/"$bid" \
    ~/Library/Preferences/"$bid".plist ~/Library/Saved\ Application\ State/"$bid".savedState; do
    add_path "$p"
  done
}

end_group() {
  local p c size
  [ ${#PATHS[@]} -eq 0 ] && [ ${#CASKS[@]} -eq 0 ] && return 0
  bold "$GROUP"
  [ -n "$GROUP_HINT" ] && note "$GROUP_HINT"
  for c in "${CASKS[@]}"; do note "brew uninstall --zap $c   (app and its data)"; done
  for p in "${PATHS[@]}"; do
    size=$(du -sh "$p" 2>/dev/null | cut -f1)
    if [ -n "$size" ]; then
      note "$size	$(short "$p")"
    else
      note "?	$(short "$p")   (protected by macOS; may need Full Disk Access)"
    fi
  done
  [ "$MODE" = remove ] || return 0
  confirm "Remove $GROUP?" || { note "Kept."; return 0; }
  for c in "${CASKS[@]}"; do
    brew uninstall --cask --zap --force "$c" || note "brew could not remove $c"
  done
  for p in "${PATHS[@]}"; do
    command rm -rf "$p" 2>/dev/null || note "Could not remove $(short "$p") (Full Disk Access or admin rights may be needed)"
  done
  REMOVED+=("$GROUP")
}

# --- 1. Sign out and revoke ------------------------------------------------
# Server-side, so deleting files isn't enough. These stay manual.

checklist() {
  bold "1. Sign out and revoke (by hand, before removing anything)"
  cat <<'EOF'
  [ ] Apple ID: System Settings > your name > Sign Out (also turns off Find My and Activation Lock)
  [ ] Internet Accounts: remove personal accounts (calendar, mail, contacts); local copies go with them
  [ ] Keybase: keybase deprovision (revokes this device and deletes its local keys)
  [ ] Signal: on your phone, Settings > Linked devices > remove this Mac
  [ ] Pulse SMS: on your phone, remove this Mac from the paired devices
  [ ] Slack: sign out of your personal workspaces
  [ ] Browsers: sign out of Firefox Sync and Chrome so this Mac leaves your device lists
  [ ] Tailscale: tailscale logout, then remove the machine in the admin console
  [ ] VPNs: remove personal Tunnelblick, WireGuard, and NordVPN profiles
  [ ] CLI logins: gh auth logout; gcloud auth revoke --all; aws sso logout; docker logout <registry>
  [ ] Keychain Access: delete personal items in the login keychain (website passwords, home Wi-Fi)
  [ ] System Settings: delete your Touch ID fingerprints, personal Bluetooth devices, and Wi-Fi networks
  [ ] Messages: Settings > iMessage > Sign Out
  [ ] Safari: History > Clear History (all history); its data needs Full Disk Access to delete
  [ ] 1Password: sign out and remove your accounts last, after the backup checks below pass
EOF
}

# --- 2. Backup checks ------------------------------------------------------
# Read-only. Each line says whether something is safe to remove or what to do first.

ssh_private_keys() {
  local f
  for f in ~/.ssh/*; do
    [ -f "$f" ] || continue
    case "$f" in *.pub|*/known_hosts*|*/config*|*/authorized_keys) continue ;; esac
    grep -q -- '-----BEGIN' "$f" 2>/dev/null && printf '%s\n' "$f"
  done
}

# 1Password holds a key when its agent offers it or SITE_FILES creates it
ssh_key_backed_up() {
  local key=$1 fp entry dest
  fp=$(ssh-keygen -lf "$key.pub" 2>/dev/null || ssh-keygen -lf "$key" 2>/dev/null)
  fp=$(awk '{print $2}' <<< "$fp")
  if [ -n "$fp" ] && [ -S ~/.1password/agent.sock ] \
    && SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l 2>/dev/null | grep -qF "$fp"; then
    return 0
  fi
  for entry in $(site_var SITE_FILES); do
    dest=${entry#*:}
    [ "${dest/#\~/$HOME}" = "$key" ] && return 0
  done
  return 1
}

backup_checks() {
  local key repo vault n why reasons

  bold "2. Backup checks"

  echo "  SSH keys"
  while read -r key; do
    [ -n "$key" ] || continue
    if ssh_key_backed_up "$key"; then
      note "  ok       $(short "$key") is in 1Password"
    else
      note "  BACKUP   $(short "$key"): op document create $(short "$key") --title <name> --vault <vault>"
    fi
  done < <(ssh_private_keys)

  echo "  GPG"
  n=$(gpg --list-secret-keys --with-colons 2>/dev/null | grep -c '^sec')
  if [ "${n:-0}" -gt 0 ]; then
    note "  BACKUP   $n secret key(s). Export to 1Password, then import on the new Mac:"
    note "           gpg --export-secret-keys --armor | op document create - --title gpg_secret_keys --file-name secret.asc --vault <vault>"
    note "           gpg --export-ownertrust | op document create - --title gpg_ownertrust --file-name ownertrust.txt --vault <vault>"
    note "           new Mac: op document get gpg_secret_keys | gpg --import; op document get gpg_ownertrust | gpg --import-ownertrust"
  else
    note "  ok       no secret keys"
  fi

  echo "  Obsidian"
  vault=$(site_var OBSIDIAN_VAULT)
  vault=${vault/#\~/$HOME}
  if [ -z "$vault" ] || [ ! -d "$vault" ]; then
    note "  ok       no vault found (OBSIDIAN_VAULT in ~/.site)"
  elif git -C "$vault" rev-parse --git-dir > /dev/null 2>&1; then
    if [ -n "$(git -C "$vault" status --porcelain)" ] || [ -n "$(git -C "$vault" log --branches --not --remotes --oneline)" ]; then
      note "  BACKUP   $(short "$vault") has uncommitted or unpushed changes"
    else
      note "  ok       $(short "$vault") is committed and pushed"
    fi
  else
    note "  CHECK    $(short "$vault"): open Obsidian and confirm Sync shows everything synced"
  fi

  echo "  Git repos with work that exists only on this Mac"
  n=0
  while read -r repo; do
    repo=${repo%/.git}
    why=()
    if [ -z "$(git -C "$repo" remote 2>/dev/null)" ]; then
      why+=("no remote")
    else
      [ -n "$(git -C "$repo" log --branches --not --remotes --oneline 2>/dev/null | head -1)" ] && why+=("unpushed commits")
    fi
    [ -n "$(git -C "$repo" status --porcelain 2>/dev/null | head -1)" ] && why+=("uncommitted changes")
    [ -n "$(git -C "$repo" stash list 2>/dev/null | head -1)" ] && why+=("stashes")
    if [ ${#why[@]} -gt 0 ]; then
      reasons=$(printf '%s, ' "${why[@]}")
      note "  BACKUP   $(short "$repo"): ${reasons%, }"
      n=$((n + 1))
    fi
  done < <(find ~/src ~/dotfiles -maxdepth 4 -name .git -type d -prune 2>/dev/null)
  [ $n -eq 0 ] && note "  ok       everything is committed and pushed"

  echo "  Personal files"
  for d in ~/Downloads ~/Desktop ~/Documents ~/Pictures; do
    [ -d "$d" ] || continue
    n=$(find "$d" -mindepth 1 -maxdepth 1 ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" -gt 0 ] && note "  MOVE     $(short "$d"): $n item(s); move anything personal to your own storage"
  done

  echo "  Claude"
  [ -d ~/.claude ] && note "  CHECK    ~/.claude holds session transcripts and memory; save anything worth keeping to Obsidian"
}

# --- 3. Removal ------------------------------------------------------------

removal() {
  local key entry dest

  bold "3. Removal ($([ "$MODE" = remove ] && echo 'asks before each group' || echo 'dry run; run with --remove to remove'))"

  group "Messaging apps" "Unlink them on your phone first (step 1)"
  read -ra casks <<< "$MESSAGING_CASKS"; add_casks "${casks[@]}"
  add_path ~/Library/Messages
  end_group

  group "Keybase" "Run keybase deprovision first (step 1)"
  read -ra casks <<< "$KEYBASE_CASKS"; add_casks "${casks[@]}"
  add_path ~/Library/Application\ Support/Keybase
  add_path ~/Library/Caches/Keybase
  add_path ~/Library/Group\ Containers/keybase
  end_group

  group "Browsers" "All profiles: history, cookies, saved logins, extensions"
  read -ra casks <<< "$BROWSER_CASKS"; add_casks "${casks[@]}"
  add_path ~/Library/Application\ Support/Firefox
  add_path ~/Library/Caches/Firefox
  add_path ~/Library/Application\ Support/Google/Chrome
  add_path ~/Library/Caches/Google/Chrome
  add_path ~/Library/Safari
  end_group

  group "Personal apps"
  read -ra casks <<< "$PERSONAL_CASKS"; add_casks "${casks[@]}"
  for app in $PERSONAL_APPS; do add_app "$app"; done
  add_path ~/Calibre\ Library
  end_group

  local vault
  vault=$(site_var OBSIDIAN_VAULT)
  vault=${vault/#\~/$HOME}
  group "Obsidian vault" "Only after the backup check shows it synced or pushed"
  [ -n "$vault" ] && add_path "$vault"
  end_group

  group "SSH keys in 1Password, and per-site ssh config" "Public keys, known_hosts, and the dotfiles ssh config stay"
  while read -r key; do
    [ -n "$key" ] && ssh_key_backed_up "$key" && add_path "$key"
  done < <(ssh_private_keys)
  add_path ~/.ssh/config.d
  add_path ~/.ssh/config.user
  add_path ~/.ssh/config.user.bak
  end_group

  group "SSH keys NOT in 1Password" "Back these up first if you need them (step 2)"
  while read -r key; do
    [ -n "$key" ] && ! ssh_key_backed_up "$key" && add_path "$key"
  done < <(ssh_private_keys)
  add_path ~/.ssh/old
  end_group

  group "GPG" "Export your secret keys first if step 2 lists any"
  add_path ~/.gnupg
  end_group

  group "Credentials and site files" "Cloud logins, tokens, and the files created from 1Password"
  for p in ~/.aws ~/.config/gcloud ~/.kube ~/.azure ~/.config/gh ~/.netrc ~/.npmrc \
    ~/.docker/config.json ~/.config/op ~/.gitconfig.user ~/.git-credentials ~/.config/1Password; do
    add_path "$p"
  done
  for entry in $(site_var SITE_FILES); do
    dest=${entry#*:}
    add_path "${dest/#\~/$HOME}"
  done
  add_path ~/.site
  end_group

  group "Source code in ~/src" "Only after step 2 shows nothing exists only here; ~/dotfiles is public and can stay"
  add_path ~/src
  end_group

  group "Claude and AI tools" "Transcripts, memory, settings, and logins"
  for p in ~/.claude ~/.claude.json ~/.claude.json.backup ~/.cursor ~/.codex \
    ~/Library/Application\ Support/Claude ~/Library/Application\ Support/Cursor; do
    add_path "$p"
  done
  end_group

  group "Shell and tool history"
  for p in ~/.zsh_history ~/.bash_history ~/.zsh_sessions ~/.bash_sessions ~/.viminfo \
    ~/.python_history ~/.psql_history ~/.mysql_history ~/.lesshst ~/.node_repl_history \
    ~/.local/share/nvim/shada ~/.wget-hsts; do
    add_path "$p"
  done
  end_group

  for d in ~/Downloads ~/Desktop ~/Documents ~/Pictures; do
    group "Contents of $(short "$d")" "Move anything personal elsewhere first (step 2)"
    while IFS= read -r -d '' p; do add_path "$p"; done \
      < <(find "$d" -mindepth 1 -maxdepth 1 ! -name '.localized' -print0 2>/dev/null)
    end_group
  done

  group "1Password" "Last: sign out and remove your accounts in the app first (step 1)"
  read -ra casks <<< "$ONEPASSWORD_CASKS"; add_casks "${casks[@]}"
  add_path ~/Library/Group\ Containers/2BUA8C4S2C.com.1password
  add_path ~/.1password
  end_group
}

checklist
backup_checks
removal

if [ "$MODE" = remove ]; then
  bold "Removed"
  if [ ${#REMOVED[@]} -eq 0 ]; then note "Nothing."; fi
  for g in "${REMOVED[@]}"; do note "$g"; done
  note "Finish the step 1 items that are still open, then empty the Trash."
fi
