# My dotfiles

## Requirements

* MacOS or Ubuntu
* Git
* root access

## Installation

Walk through to install and configure a new MacOS or Linux box

These scripts are idempotent, meaning they can be run again and won't break anything. So if you encounter an error, please fix, it and re-run the install. Once you have it working, feel free to submit a PR.

### Install Brew

Browse to https://brew.sh/ and install brew or 

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Run the eval command to get brew in your path

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

It's a bit of chicken and egg problem as the installer WILL install Brew but you want to be already running from iTerm.

### Install iTerm

```bash
brew install iterm2
```

### Install script

While running iterm do the install script

```bash
# Clone this repo into your home directory
cd ~
git clone https://github.com/chrishirsch/dotfiles.git
# Run the install script
cd dotfiles/install
./install.sh
```

While running install and at iTerm, you SHOULD be asked to run `p10k configure`. Once here go to iTerm

### iTerm

* Run p10k configure (if not already prompted)
* Select Install fonts
* Quit all of iTerm as requested
* Restart iTerm and if things don't quite look right, re-run the install.sh and/or p10k configure

Make SURE that you're running iTerm2 when attempting to configure zsh and p10k otherwise nothing works!

### ohmyzsh

If you see
` zsh compinit: insecure directories, run compaudit for list.
Ignore insecure directories and continue [y] or abort compinit [n]?`

You will need to run compaudit and note that there is a directory with incorrect permissions. Fix this by:

```bash
compaudit | xargs chmod g-w
```

and validate its working again by opening a new iTerm with no errors.

## Setting up Visual Studio Code

### Repeating Keys on OSX

To get repeating keys for vi mode:
```bash
defaults write -g ApplePressAndHoldEnabled 0
```

### Enabling Sync

#### Settings Sync Plugin is now DEPRECATED

Add the Settings Sync plugin by Shan Khan and then login to Git. Select the Gist and then do Shift+Option+D (or Shift+Alt+D) to download and sync

Ensure that 
```
Select Command "Sync : Advanced Options > Toggle Auto-Upload on Settings Change" command to Turn ON 
```

is ENABLED by Shift+Cmd+P and then Sync: Advanced Options > Toggle Auto-Upload on Settings Change (You may have to toggle it depending on it's current default but definitely make sure it's ON)

#### MS Sync 

Unfortunately the Settings Sync that worked perfect with Git and Gists and was private is no longer. So now we get to expose everything to MS to sync. Progress!

To enable the built in Settings Sync, click on the Gear in the lower left, Backup and Sync Settings, Sign in to GitHub (if this is personal or you wish to sync to a SPECIFIC GitHub, make sure you're logged in there first. It won't ask for credentials). You can also sync from your personal settings by signing into the personal, get everything synced, sign out and then sign in with your other account and sync there. Obviously that's a one-shot but at least you get all your plugins, etc. 

### Git

For the most part, git should be setup and ready to go from the installer. There will probably be site specific settings (ie your git email for the company you are developing for may be different). If so, just create a ~/.gitconfig.user file

```bash
[user]
        name = Chris Hirsch
        email = chris.hirsch@somerandomcompany.com

[credential]
        helper = cache --timeout 2592000
        helper =
        helper = /usr/local/share/gcm-core/git-credential-manager
        guiPrompt = false

[commit]
        gpgSign = true

[credential "https://dev.azure.com"]
        useHttpPath = true
```

This will override any more general config in ~/.gitconfig 

### PR tracking

`bin/pr-state-record`, `bin/pr-status`, and `bin/pr-state-hook` keep track of the pull requests you open, grouped by ticket.

- `pr-state-record <pr-url> [--ticket ABC-1234] [--title "Ticket title"] [--desc "Row description"]` records a PR in `~/.local/state/pr/<TICKET>.md`, one file per ticket and one table row per PR. Re-running it for the same PR updates the row.
- `pr-status` shows the review and merge status of every open PR, from one GitHub GraphQL query. Open PRs carry badges for draft, merge conflicts, behind base, CI failing or pending, and unresolved review threads. `--comments` lists each unresolved thread under its PR. `pr-status --all` includes merged and closed PRs, and `--since YYYY-MM-DD` includes those merged or closed on or after the date. `--markdown` prints "Merged / closed" and "Open" sections without colors, with the unresolved threads, for pasting into notes such as a standup. Each run refreshes the state files and moves a ticket's file to `~/.local/state/pr/archive/` once all its PRs are merged or closed and the newest one closed more than `PR_EXPIRE_DAYS` (default 14) days ago.
- `pr-state-hook` is a Claude Code `PostToolUse` hook for Bash that records every PR created with `gh pr create`. Register it in `~/.claude/settings.json`:

```json
"hooks": {
  "PostToolUse": [
    { "matcher": "Bash", "hooks": [{ "type": "command", "command": "bash ~/.local/bin/pr-state-hook" }] }
  ]
}
```

Site-specific settings belong in `~/.site`, which `zshrc` sources:

```bash
export PR_TICKET_PATTERN='ABC-[0-9]+'             # ticket keys to detect in branch, title, and body
export PR_JIRA_URL='https://example.atlassian.net' # adds a Jira link to each ticket file
```

Without `PR_TICKET_PATTERN`, PRs go to the `housekeeping` ticket unless you pass `--ticket`.
