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

The installer also installs Brew, but install Ghostty first and run the installer from it, so the prompt and fonts are set up in the terminal you'll use.

### Install Ghostty

```bash
brew install --cask ghostty
```

### Install script

Run the install script from Ghostty

```bash
# Clone this repo into your home directory
cd ~
git clone https://github.com/chrishirsch/dotfiles.git
# Run the install script
cd dotfiles/install
./install.sh
```

The install script links the powerlevel10k config from this repo. To change the prompt, open a new terminal and run `p10k configure`.

Each run is logged to `~/dotfiles-install-<date>.log`. Read it with `less -R`.

### Moving to a new Mac

Some files hold settings for one machine and stay out of this repo. Before running the install script:

1. Make sure the machine's site document exists in 1Password (see [Site settings](#site-settings-site)). The install script creates `~/.site` and the site's other files from it.
2. Clone the private Claude config repo, and list it in `CLAUDE_EXTRA_DIRS` in the site document (see [Claude Code](#claude-code)).

During the install script:

- after `brew bundle`, the script signs in to 1Password if needed (Touch ID with the app's CLI integration, or your password for an account added with `op account add`), then asks which site document to use
- the macOS step shows hidden files in Finder, makes held keys repeat, rebuilds the Dock, and sets the system keyboard shortcuts
- asks whether to use AeroSpace. With AeroSpace, workspaces 1-9 are on Cmd-1..9 and the config is `aerospace/aerospace.toml`. Without it, the script waits while you add 9 desktops in Mission Control, sets Cmd-1..9 to switch between them, and stages the Rectangle config for import.

Log out and back in afterwards so every setting takes effect.

### Handing a Mac back

`install/uninstall.sh` removes your personal accounts, credentials, and data before you return a Mac. Company-managed things stay as they are: MDM profiles, system logs, and work apps it doesn't list.

```bash
~/dotfiles/install/uninstall.sh            # dry run: changes nothing
~/dotfiles/install/uninstall.sh --remove   # asks before each group
```

It runs in three steps:

1. A checklist of things to sign out of or revoke by hand, since deleting files doesn't unlink them: Apple ID, Internet Accounts, Keybase, Signal, Slack, Tailscale, CLI logins, and 1Password last.
2. Backup checks, which change nothing:
   - SSH keys that aren't in 1Password
   - GPG secret keys, with the commands to export them to 1Password
   - an Obsidian vault with unpushed changes
   - git repos with work that exists only on this Mac
   - personal files in Downloads, Desktop, Documents, and Pictures
3. Removal, one group at a time: messaging apps, Keybase, browsers, personal apps, the Obsidian vault, SSH keys, GPG, credentials and site files, `~/src`, Claude and other AI tools, shell history, your folders, and 1Password. Homebrew apps are removed with `brew uninstall --zap`. Every prompt defaults to no.

The app lists are at the top of the script. Messages, Safari, and 1Password's data are protected by macOS, so removing them needs Full Disk Access for your terminal.

### Ghostty

The config is `ghostty/config`, linked to `~/.config/ghostty/config`. Ghostty includes the Nerd Font symbols p10k uses, so no font install is needed.

* Run `p10k configure` (if not already prompted)
* If things don't look right, re-run install.sh and/or `p10k configure`

### ohmyzsh

If you see
` zsh compinit: insecure directories, run compaudit for list.
Ignore insecure directories and continue [y] or abort compinit [n]?`

You will need to run compaudit and note that there is a directory with incorrect permissions. Fix this by:

```bash
compaudit | xargs chmod g-w
```

and validate its working again by opening a new Ghostty window with no errors.

## Setting up Visual Studio Code

### Repeating Keys on OSX

The macOS step of the install script turns off press-and-hold accents (`ApplePressAndHoldEnabled`) in `macos/defaults.sh`, so held keys repeat in vi mode.

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

`bin/pr-state-record` and `bin/pr-status` keep track of the pull requests you open, grouped by ticket.

- `pr-state-record <pr-url> [--ticket ABC-1234] [--title "Ticket title"] [--desc "Row description"]` records a PR in `~/.local/state/pr/<TICKET>.md`, one file per ticket and one table row per PR. Re-running it for the same PR updates the row.
- `pr-status` shows the review and merge status of every open PR, from one GitHub GraphQL query. Open PRs carry badges for draft, merge conflicts, behind base, CI failing or pending, and unresolved review threads. `--comments` lists each unresolved thread under its PR. `pr-status --all` includes merged and closed PRs, and `--since YYYY-MM-DD` includes those merged or closed on or after the date. `--markdown` prints "Merged / closed" and "Open" sections without colors, with the unresolved threads, for pasting into notes such as a standup; ticket keys matching `PR_TICKET_PATTERN` become Obsidian `[[wikilinks]]`. Each run refreshes the state files and moves a ticket's file to `~/.local/state/pr/archive/` once all its PRs are merged or closed and the newest one closed more than `PR_EXPIRE_DAYS` (default 14) days ago.

The ticket settings live in `~/.site` (see [Site settings](#site-settings-site)). Without `PR_TICKET_PATTERN`, PRs go to the `housekeeping` ticket unless you pass `--ticket`.

### Claude Code

The `claude_config` step of the install script sets up `~/.claude`:

- `~/.claude/CLAUDE.md` is a local file on each machine. The installer adds an import of the shared rules in `ai/claude/CLAUDE.md`, plus one import for each private repo. Notes for one machine only can go directly in this file.
- Each skill in `ai/skills/` is linked into `~/.claude/skills/`, alongside any skills already there.
- Private config (the Obsidian vault map, company-specific workflows, private skills) lives in a private repo such as `ai-private`. List its path in `CLAUDE_EXTRA_DIRS`; the installer imports the repo's `claude/CLAUDE.md` and links its `skills/`, `commands/`, and `agents/`. It warns when `CLAUDE_EXTRA_DIRS` is unset; set it to `""` on a machine without private config.
- The shared rules keep project plans, notes, and proofs in the Obsidian vault at `$OBSIDIAN_VAULT`, and working files in a `tmp/` folder at the project root, which `git/gitignore_global` ignores in every repo.

### Site settings (`~/.site`)

`zshrc` sources `~/.site` for settings that differ between machines:

```bash
export PR_TICKET_PATTERN='ABC-[0-9]+'                # ticket keys to detect in branch, title, and body
export PR_JIRA_URL='https://example.atlassian.net'   # adds a Jira link to each ticket file
export OBSIDIAN_VAULT="$HOME/obsidian/Second Brain"  # Obsidian vault for Claude project notes
export CLAUDE_EXTRA_DIRS="$HOME/src/github/ai-private" # space-separated private Claude config repos
export SITE_FILES="acme_npmrc:~/.npmrc"              # other files to create from 1Password, see below
```

#### Site documents in 1Password

Each kind of machine has a site document in the `Clients` vault of 1Password, named owner first: `chris_site_macbook`, `chris_site_framework`, `acme_site`. Secrets are separate 1Password items named the same way (`acme_jfrog`), and documents refer to them with secret references instead of holding the values:

```bash
export GOPROXY="https://user:{{ op://Clients/acme_jfrog/credential }}@acme.jfrog.io/artifactory/api/go/go,direct"
```

To get a reference, open the item in the 1Password app and choose **Copy Secret Reference** from the field's menu.

The `site_settings` step of the install script:

1. Creates `~/.site` from the site document you choose (default `chris_site_macbook`), with each secret reference replaced by its value.
2. Creates each file in the site's `SITE_FILES` the same way. Entries are `document:path`, separated by spaces, so document names can't contain spaces.

It never overwrites an existing file; it warns and skips it. To refresh a file from 1Password, move it aside and re-run the script. Files are created with mode `600`. If `op` can't reach the vault or a reference doesn't resolve, the script stops; fix the problem and re-run it. `SITE_OP_VAULT` and `SITE_OP_DOCUMENT` override the vault and the default document.

To create a document from a local file, replace its secrets with references, then:

```bash
op document create ~/site.tpl --title acme_site --vault Clients
op document get acme_site --vault Clients | op inject > /dev/null && echo ok   # check the references resolve
command rm ~/site.tpl
```

To change one: `op document get acme_site --vault Clients > ~/site.tpl`, edit the file, run `op document edit acme_site ~/site.tpl --vault Clients`, and delete the local copy.

### SSH

SSH keys live in 1Password as SSH Key items, named owner first (`acme_id_ed25519`), and the 1Password SSH agent offers them; private keys aren't kept in `~/.ssh`. Turn the agent on in the app under **Settings > Developer > Use the SSH agent**.

`ssh/config` points `IdentityAgent` at `~/.1password/agent.sock` when that socket exists. That is the agent's socket on Linux; on macOS the `ssh` step of the install script links it to the app's socket. Agent forwarding is off; turn it on per host where it's needed.

Each site adds its own pieces through `SITE_FILES`:

- `~/.config/1Password/ssh/agent.toml` lists the keys the agent offers on that machine. Without it, the agent offers only keys in the Personal (Private) vault. Missing items are skipped silently.

  ```toml
  [[ssh-keys]]
  item = "acme_id_ed25519"
  vault = "Clients"
  ```

- Files in `~/.ssh/config.d/` hold host entries, one file per site (`acme_ssh_config:~/.ssh/config.d/acme`). `ssh/config` includes them all, so the public config holds no hosts.

Check what the agent offers with `SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l`, and which agent a host uses with `ssh -G <host> | grep identityagent`.
