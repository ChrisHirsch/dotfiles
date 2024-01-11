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

Add the Settings Sync plugin by Shan Khan and then login to Git. Select the Gist and then do Shift+Option+D (or Shift+Alt+D) to download and sync

Ensure that 
```
Select Command "Sync : Advanced Options > Toggle Auto-Upload on Settings Change" command to Turn ON 
```

is ENABLED by Shift+Cmd+P and then Sync: Advanced Options > Toggle Auto-Upload on Settings Change (You may have to toggle it depending on it's current default but definitely make sure it's ON)
