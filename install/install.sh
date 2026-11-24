#!/bin/bash

#set -e

# Record the whole run in a log file. script(1) keeps a real terminal, so
# brew's progress and the prompts still work.
if [ -z "$DOTFILES_INSTALL_LOG" ] && [ -t 0 ] && command -v script > /dev/null; then
  DOTFILES_INSTALL_LOG=~/dotfiles-install-$(date +%Y%m%d-%H%M%S).log
  export DOTFILES_INSTALL_LOG
  # Readable only by you, since it holds everything shown on screen
  (umask 077 && : > "$DOTFILES_INSTALL_LOG")
  echo "Logging this run to $DOTFILES_INSTALL_LOG (view with: less -R)"
  if [ "$(uname -s)" = Darwin ]; then
    script -q "$DOTFILES_INSTALL_LOG" "$0" "$@"
  else
    script -q -e -c "$(printf '%q ' "$0" "$@")" "$DOTFILES_INSTALL_LOG"
  fi
  exit $?
fi

# Set OS specific variables
set_os_vars() {
  unameOut="$(uname -s)"
  case "${unameOut}" in
      Linux*)     machine=Linux
                  alias_file=~/.bashrc
                  bash_profile_file=~/.bashrc
                  functions_file=~/.functions
                  if [ -n "$(command -v yum)" ]  ; then
                    pkg_mgr=${pkg_mgr:-yum}
                    # Enable epel
                    sudo yum install -y epel-release
                    sudo yum-config-manager --enable epel
                  elif [ -n "$(command -v apt)" ]  ; then
                    pkg_mgr=${pkg_mgr:-apt-get}
                  fi
                  ;;
      Darwin*)    machine=Mac
                  alias_file=~/.aliases
                  functions_file=~/.functions
                  bash_profile_file=~/.bash_profile
                  ;;
      CYGWIN*)    machine=Cygwin;;
      MINGW*)     machine=MinGw;;
      *)          machine="UNKNOWN:${unameOut}"
  esac
}

logger() {
    DATE_TIME=$(date +"%Y-%m-%d %H:%M:%S")
    if [ -z "$CONTEXT" ]
    then
        CONTEXT=$(caller)
    fi
    MESSAGE=$1
    CONTEXT_LINE=$(echo "$CONTEXT" | awk '{print $1}')
    CONTEXT_FILE=$(echo "$CONTEXT" | awk -F"/" '{print $NF}')
    printf "%s %05s %s %s\n" "$DATE_TIME" "[$CONTEXT_LINE" "$CONTEXT_FILE]" "$MESSAGE"
    CONTEXT=
}

create_symlinks() {
  logger "Setting shortcuts for dotfiles"
  mkdir -p ~/.config/yamllint
  mkdir -p ~/.config/lazygit
  mkdir -p ~/.newsboat
  mkdir -p ~/.vagrant.d
  ln -sf ~/dotfiles/git/gitconfig ~/.gitconfig
  ln -sf ~/dotfiles/vim/vimrc ~/.vimrc
  ln -sf ~/dotfiles/newsboat/config ~/.newsboat/config
  ln -sf ~/dotfiles/newsboat/urls ~/.newsboat/urls
  ln -sf ~/dotfiles/vagrant/plugins.json ~/.vagrant.d/plugins.json
  ln -sf ~/dotfiles/vim/linters/flake8 ~/.config/flake8
  ln -sf ~/dotfiles/vim/linters/yamllint/config ~/.config/yamllint/config
  ln -sf ~/dotfiles/zsh/aliases ~/.config/aliases
  ln -sf ~/dotfiles/zsh/functions ~/.functions
  ln -sf ~/dotfiles/golang/golangci.yaml ~/.golangci.yaml
  ln -sf ~/dotfiles/postgresql/psqlrc ~/.psqlrc
  ln -sf ~/dotfiles/prettier/.prettierrc ~/.prettierrc
  mkdir -p ~/.config/ghostty
  ln -sf ~/dotfiles/ghostty/config ~/.config/ghostty/config
  # lazygit, k9s, and herdr read $XDG_CONFIG_HOME, which zshrc sets to ~/.config
  ln -sf ~/dotfiles/lazygit/config.yml ~/.config/lazygit/config.yml
  mkdir -p ~/.config/k9s ~/.config/herdr
  ln -sf ~/dotfiles/k9s/aliases.yaml ~/.config/k9s/aliases.yaml
  ln -sf ~/dotfiles/herdr/config.toml ~/.config/herdr/config.toml
  mkdir -p ~/.cursor
  ln -sfn ~/dotfiles/ai/rules ~/.cursor/rules
  ln -sfn ~/dotfiles/ai/skills ~/.cursor/skills
  mkdir -p ~/.local/bin
  for script in ~/dotfiles/bin/*; do
    ln -sf "$script" ~/.local/bin/
  done
}

# Appends an import of $1 to ~/.claude/CLAUDE.md unless it is already there
claude_import() {
  local line="@$1"
  grep -qxF "$line" ~/.claude/CLAUDE.md 2>/dev/null \
    || printf '\n%s\n' "$line" >> ~/.claude/CLAUDE.md
}

# Links each item in $1 into $2, keeping anything else already in $2
link_items() {
  local src=$1 dest=$2 item
  [ -d "$src" ] || return 0
  if [ -L "$dest" ]; then
    logger "Skipping $src: $dest is a symlink to $(readlink "$dest")"
    return 0
  fi
  mkdir -p "$dest"
  for item in "$src"/*; do
    [ -e "$item" ] || continue
    ln -sfn "$item" "$dest/"
  done
}

site_fail() {
  logger "ERROR: $1"
  logger "Fix it, then re-run ~/dotfiles/install/install.sh"
  [ -n "$SITE_TMP" ] && command rm -f "$SITE_TMP"
  exit 1
}

# Checks once that op can read the vault, signing in first if needed
site_op_ready() {
  local session
  [ -n "$SITE_OP_OK" ] && return
  command -v op > /dev/null || site_fail "1Password CLI (op) not found. Install it with: brew install --cask 1password-cli"
  if ! op vault get "$SITE_OP_VAULT" > /dev/null 2>&1; then
    logger "Signing in to 1Password..."
    session=$(op signin) || site_fail "Can't sign in to 1Password. Turn on Settings > Developer > Integrate with 1Password CLI in the app, or add the account with: op account add"
    eval "$session"
    op vault get "$SITE_OP_VAULT" > /dev/null 2>&1 || site_fail "Signed in, but can't read 1Password vault '$SITE_OP_VAULT'."
  fi
  SITE_OP_OK=1
}

# Creates $2 from 1Password document $1, resolving its op:// references, unless $2 exists
site_file() {
  local doc=$1 dest=$2 template
  if [ -e "$dest" ]; then
    logger "WARNING: $dest already exists, not overwriting it. To refresh it from 1Password, move it aside and re-run."
    return
  fi
  site_op_ready
  logger "Creating $dest from '$doc' in vault '$SITE_OP_VAULT'..."
  template=$(op document get "$doc" --vault "$SITE_OP_VAULT") || site_fail "Can't get document '$doc' from vault '$SITE_OP_VAULT'."
  mkdir -p "$(dirname "$dest")"
  SITE_TMP=$(mktemp "$dest.XXXXXX")
  printf '%s\n' "$template" | op inject -f -o "$SITE_TMP" > /dev/null || site_fail "Can't resolve the op:// references in '$doc'."
  chmod 600 "$SITE_TMP"
  command mv -f "$SITE_TMP" "$dest"
  SITE_TMP=
}

# Creates ~/.site, then each file listed in its SITE_FILES, from 1Password documents.
# Override the vault and the default ~/.site document with SITE_OP_VAULT and SITE_OP_DOCUMENT.
site_settings() {
  local default_doc="${SITE_OP_DOCUMENT:-chris_site_macbook}"
  local doc entry dest site_files
  SITE_OP_VAULT="${SITE_OP_VAULT:-Clients}"

  if [ -e ~/.site ]; then
    logger "WARNING: ~/.site already exists, not overwriting it. To refresh it from 1Password, move it aside and re-run."
  else
    site_op_ready
    read -p "1Password document for ~/.site [${default_doc}]: " -r doc
    site_file "${doc:-$default_doc}" ~/.site
  fi

  # Entries are document:path, separated by spaces; a leading ~ in the path is $HOME
  site_files=$(zsh -c 'source ~/.site 2>/dev/null; print -r -- $SITE_FILES' 2>/dev/null)
  for entry in $site_files; do
    dest=${entry#*:}
    site_file "${entry%%:*}" "${dest/#\~/$HOME}"
  done
}

claude_config() {
  logger "Setting up Claude Code config..."
  mkdir -p ~/.claude

  # Replace whole-file and whole-folder links from earlier installs
  [ -L ~/.claude/CLAUDE.md ] && rm ~/.claude/CLAUDE.md
  [ "$(readlink ~/.claude/skills)" = "$HOME/dotfiles/ai/skills" ] && rm ~/.claude/skills

  # The import line keeps a literal ~ so it resolves on any machine
  # shellcheck disable=SC2088
  claude_import '~/dotfiles/ai/claude/CLAUDE.md'
  link_items ~/dotfiles/ai/skills ~/.claude/skills

  # Private sources listed in CLAUDE_EXTRA_DIRS in ~/.site. Setting it to "" opts out.
  local extra_dirs dir kind
  if ! extra_dirs=$(zsh -c 'source ~/.site 2>/dev/null; (( ${+CLAUDE_EXTRA_DIRS} )) || exit 1; print -r -- $CLAUDE_EXTRA_DIRS' 2>/dev/null); then
    logger "WARNING: CLAUDE_EXTRA_DIRS is not set in ~/.site, so no private Claude config (vault map) is imported."
    logger "Clone ai-private and set CLAUDE_EXTRA_DIRS to its path, or set it to \"\" to skip, then re-run."
  fi
  for dir in $extra_dirs; do
    if [ ! -d "$dir" ]; then
      logger "Skipping $dir: not found (clone it, then re-run)"
      continue
    fi
    [ -f "$dir/claude/CLAUDE.md" ] && claude_import "$dir/claude/CLAUDE.md"
    for kind in skills commands agents; do
      link_items "$dir/$kind" ~/.claude/$kind
    done
  done
}

tmux() {
  logger "Setting up tmux"
  if [ ! -d ~/.tmux/plugins ]; then
    logger "Creating tmux plugins..."
    mkdir -p ~/.tmux/plugins
    logger "Cloning tmux tpm plugins..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  else 
    logger "Updating tmux tpm plugins..."
    cd ~/.tmux/plugins/tpm && git pull origin
  fi
  ln -sf ~/dotfiles/tmux.conf ~/.tmux.conf
}
ssh() {
  logger "Configuring ssh..."
  if [ ! -d ~/.ssh ]; then
    logger "Creating ~/.ssh directory ..."
    mkdir -p ~/.ssh
  fi
  ln -sf ~/dotfiles/ssh/config ~/.ssh/config
  mkdir -p ~/.ssh/sockets ~/.ssh/config.d

  # ssh/config uses ~/.1password/agent.sock, the 1Password agent's socket on Linux.
  # On macOS the app's socket path has a space in it, so link to it instead.
  if [ "${machine}" == 'Mac' ]; then
    mkdir -p ~/.1password
    ln -sf ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ~/.1password/agent.sock
  fi
}

oh_my_zsh() {
  set -e
  logger "Oh My ZSH"
  if [ ! -f ~/.oh-my-zsh/oh-my-zsh.sh ]; then
    logger "Installing Oh My ZSH...no dir found ~/.oh-my-zsh"
    wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O /tmp/install.sh
    chmod 755 /tmp/install.sh
    /tmp/install.sh --unattended
  else
    logger "Oh My ZSH already installed at ~/.oh-my-zsh"
  fi

  if [ -L ~/.zshrc ]; then
    logger "Oh My ZSH config already linked at ~/.zshrc"
  else
    ln -sf ~/dotfiles/zsh/zshrc ~/.zshrc
  fi
  logger "NOT changing the default shell to zsh..if desired: chsh -s /usr/local/bin/zsh"

  if [ -d ~/.oh-my-zsh/custom/themes/powerlevel10k ]; then
    logger "p10k already downloaded"
  else
    logger "Cloning powerlevel10k"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k
  fi

  if [ -L ~/.p10k.zsh ]; then
    logger "Found existing symlink for ~/.p10k.zsh"
  else
    logger "Installing p10k configuration"
    ln -sf ~/dotfiles/zsh/p10k.zsh ~/.p10k.zsh
  fi
  logger "Run p10k configure to re-configure powerlevel"

  set +e
  logger "Ensuring permissions are correct"
  zsh -c 'autoload -Uz compaudit && compaudit' 2>/dev/null | xargs chmod g-w

  # Need to explicitly git clone the zsh-completions (plugins no longer work)
  # https://github.com/zsh-users/zsh-completions/issues/603
  git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions
  if [ -d ~/.oh-my-zsh/custom/plugins/pnpm ]; then
    logger "pnpm plugin already cloned..updating..."
    cd ~/.oh-my-zsh/custom/plugins/pnpm 
    git pull origin
    cd -
  else
    logger "Cloning pnpm plugin..."
    git clone --depth=1 https://github.com/ntnyq/omz-plugin-pnpm.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/pnpm
  fi
  if [ -d ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions ]; then
    logger "zsh-autosuggestions plugin already cloned..updating..."
    cd ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions 
    git pull origin
    cd -
  else
    logger "Cloning zsh-autosuggestions plugin..."
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  fi
}

# Put an installed but not yet on PATH brew on PATH (Apple silicon, then Intel)
brew_shellenv() {
  command -v brew > /dev/null && return
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$b" ]; then
      eval "$("$b" shellenv)"
      return
    fi
  done
}

# Download the official Homebrew installer and run it only if the user agrees
install_homebrew() {
  local url=https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
  local script
  script=$(mktemp -t homebrew-install) || return 1
  logger "Homebrew not found. Downloading its installer from $url"
  if ! curl -fsSL "$url" -o "$script"; then
    logger "Could not download the Homebrew installer"
    command rm -f "$script"
    return 1
  fi
  logger "Installer saved to $script"
  if ask "Run the Homebrew installer now?"; then
    logger "Skipping Homebrew and brew packages. Install it from https://brew.sh and re-run the installer"
    command rm -f "$script"
    return 1
  fi
  /bin/bash "$script"
  local rc=$?
  command rm -f "$script"
  return $rc
}

install_mac_packages() {

  if [ ! -n "$(command -v gcc)" ]  ; then
    logger "Installing OSX Dev Tools (including git)..."
    softwareupdate --all --install --force
  else
    logger "OSX Dev Tools (including git) already installed..."
  fi

  brew_shellenv
  if ! command -v brew > /dev/null; then
    install_homebrew || return 1
    brew_shellenv
  fi
  brew analytics off
  # The site files and ssh keys come from 1Password, so install it on its own
  # first; a failure in brew bundle then leaves those steps working
  logger "Installing 1Password and its CLI..."
  brew install --cask 1password 1password-cli
  ln -sf ~/dotfiles/Brewfile ~/Brewfile
  logger "Installing brew packages..."
  # Without --verbose, bundle hides brew install's output (and any prompt) until it finishes
  brew bundle --verbose --file ~/Brewfile
}

install_linux_packages(){
  logger "Installing core linux packages..."
  < ~/dotfiles/linux_packages xargs sudo ${pkg_mgr} install -y
  linux_1password_repo && sudo ${pkg_mgr} install -y 1password-cli

  ask "Do you want to install linux desktop packages?"
  linux_desktop_packages=$?
  if [ $linux_desktop_packages -eq 1 ]; then
    install_linux_dekstop_packages
  fi

  if [ ! -n "$(command -v fzf)" ]  ; then
    logger "Installing fzf from git..."
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install
  fi
}

install_packages() {
  if [ ${machine} == 'Mac' ] ; then
    install_mac_packages
  elif [ ${machine} == 'Linux' ] ; then
    install_linux_packages
  fi

}

# Adds 1Password's apt repository, the source of op and the desktop app on Linux
linux_1password_repo() {
  if [ "${pkg_mgr}" != 'apt-get' ]; then
    logger "Install the 1Password CLI by hand: https://developer.1password.com/docs/cli/get-started/"
    return 1
  fi
  [ -f /etc/apt/sources.list.d/1password.list ] && return 0
  logger "Adding the 1Password apt repository..."
  local arch key=https://downloads.1password.com/linux/keys/1password.asc
  arch=$(dpkg --print-architecture)
  curl -sS "$key" | sudo gpg --dearmor --yes --output /usr/share/keyrings/1password-archive-keyring.gpg
  echo "deb [arch=$arch signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$arch stable main" \
    | sudo tee /etc/apt/sources.list.d/1password.list > /dev/null
  sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22 /usr/share/debsig/keyrings/AC2D62742012EA22
  curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol \
    | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol > /dev/null
  curl -sS "$key" | sudo gpg --dearmor --yes --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
  sudo apt-get update
}

install_linux_dekstop_packages() {
  logger "Installing repos for NordVpn and KeePass"
  sudo wget -qnc https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/nordvpn-release_1.0.0_all.deb
  sudo apt install ./nordvpn-release_1.0.0_all.deb
  sudo add-apt-repository ppa:phoerious/keepassxc
  sudo apt update
  < ~/dotfiles/linux_desktop_packages xargs sudo ${pkg_mgr} install -y
}

ask() {
  while true; do
    read -p "$1 ([y]/n) " -r
    REPLY=${REPLY:-"y"}
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      return 1
    elif [[ $REPLY =~ ^[Nn]$ ]]; then
      return 0
    fi
  done
}


add_aliases() {
  if ! grep -qs -E '^alias ll=.*$' "${alias_file}"; then
      logger "Adding ll alias..."
      echo "# List all files colorized in long format" >> "${alias_file}"
      echo 'alias ll="ls -lah"' >> "${alias_file}"
  fi

  if ! grep -qs -E '^set -o vi$' "${bash_profile_file}"; then
      logger "Setting VI bindings in bash..."
      echo 'set -o vi' >> "${bash_profile_file}"
  fi
}

kubernetes() {
  if command -v helm > /dev/null; then
    ~/dotfiles/kubernetes/install.sh
  else
    logger "Skipping helm plugins: helm not installed"
  fi
  # kubectl completion for bash; zsh gets it from the oh-my-zsh kubectl plugin
  local line='command -v kubectl > /dev/null && source <(kubectl completion bash)'
  grep -qxF "$line" ~/.bashrc 2>/dev/null || echo "$line" >> ~/.bashrc
}

submodules() {
  logger "Updating meeting backgrounds and neovim submodules..."
  git -C ~/dotfiles submodule update --init --recursive
}

gitinstall() {
  if command -v git-cz > /dev/null; then
    logger "Git commitizen already installed..."
  elif command -v npm > /dev/null; then
    logger "Setting up git commitizen..."
    npm install -g git-cz --force
  else
    logger "Skipping git commitizen: npm not installed"
  fi

  if [ ! -f ~/.gitconfig.user ] ; then
    logger "Setting up local git config (to skip this, list a ~/.gitconfig.user document in the site's SITE_FILES)..."
    read -p "Please enter your LOCAL (ie business) email address: " email
    logger "Using $email for ~/.gitconfig.user"
    printf '[user]\n  email = %s\n' "$email" > ~/.gitconfig.user
  else
    logger "Local Git config already installed..."
  fi

  # gh rewrites its config.yml, so set options instead of linking the file
  if command -v gh > /dev/null; then
    logger "Setting gh options..."
    gh config set git_protocol https
    gh alias set co 'pr checkout' --clobber > /dev/null
  fi
}

elixirinstall() {
  logger "Setting up erlang..."
  asdf plugin add erlang
  logger "Setting up elixir..."
  asdf plugin add elixir

  #asdf install
  #asdf list
}

editors() {
  mkdir -p ~/.vim/autoload
  if [ ! -f ~/.vim/autoload/plug.vim ] ; then
    logger "Installing Vim plugin manager..."
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    logger "Installing all vim plugins..."
    # vim-plug runs each plugin's build step, including YouCompleteMe's install.py
    vim -es -u ~/.vimrc -i NONE +PlugInstall +qall
  fi

  if [ -L ~/.config/nvim ]; then
    logger "NeoVim config already linked at ~/.config/nvim"
  else
    logger "NeoVim config linked to ~/.config/nvim"
    ln -sf ~/dotfiles/nvim ~/.config/nvim
  fi

  if [ ${machine} == 'Mac' ] ; then
    # Allow Key repeat for Visual Studio Code on a mac (for vim plugin)
    defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
    # VSCodium
    # defaults write com.visualstudio.code.oss ApplePressAndHoldEnabled -bool false
  fi
  }


colima() {
  if ! command -v brew > /dev/null; then
    logger "Skipping Colima: it's installed with Homebrew"
    return
  fi
  logger "Setting up Colima config..."
  if [ ! -d ~/.colima/default ]; then
    logger "Creating ~/.colima/default directory..."
    mkdir -p ~/.colima/default
  fi
  if [ -L ~/.colima/default/colima.yaml ]; then
    logger "Colima config already linked at ~/.colima/default/colima.yaml"
  else
    logger "Linking Colima config to ~/.colima/default/colima.yaml"
    ln -sf ~/dotfiles/colima/colima.yaml ~/.colima/default/colima.yaml
  fi

  # The docker CLI finds Homebrew's compose and buildx plugins through cliPluginsExtraDirs
  local plugins config=~/.docker/config.json
  plugins="$(brew --prefix)/lib/docker/cli-plugins"
  mkdir -p ~/.docker
  [ -s "$config" ] || echo '{}' > "$config"
  if ! jq -e --arg d "$plugins" '(.cliPluginsExtraDirs // []) | index($d)' "$config" > /dev/null; then
    logger "Adding $plugins to cliPluginsExtraDirs in $config"
    jq --arg d "$plugins" '.cliPluginsExtraDirs = ((.cliPluginsExtraDirs // []) + [$d])' "$config" > "$config.tmp" \
      && command mv -f "$config.tmp" "$config"
  fi
  # Docker Desktop's credential helper goes away with the app; use Homebrew's keychain helper
  if [ "$(jq -r '.credsStore // empty' "$config")" = desktop ]; then
    logger "Switching docker credsStore from desktop to osxkeychain in $config"
    jq '.credsStore = "osxkeychain"' "$config" > "$config.tmp" && command mv -f "$config.tmp" "$config"
  fi
}


macos_settings() {
  if [ "${machine}" != 'Mac' ] ; then
    return
  fi

  logger "Configuring macOS preferences..."
  ~/dotfiles/macos/defaults.sh

  logger "Configuring Dock..."
  ~/dotfiles/macos/dock.sh

  ask "Use AeroSpace for window management instead of Rectangle and native desktops?"
  if [ $? -eq 1 ]; then
    logger "Configuring AeroSpace..."
    ~/dotfiles/macos/aerospace.sh
    logger "Configuring keyboard shortcuts..."
    WINDOW_MANAGER=aerospace ~/dotfiles/macos/shortcuts.sh
    return
  fi

  logger "Configuring keyboard shortcuts..."
  ~/dotfiles/macos/shortcuts.sh

  # Rectangle imports this file on its next launch
  if [ ! -f ~/Library/Preferences/com.knollsoft.Rectangle.plist ]; then
    logger "Staging Rectangle config for import..."
    mkdir -p ~/Library/Application\ Support/Rectangle
    cp ~/dotfiles/rectangle/RectangleConfig.json ~/Library/Application\ Support/Rectangle/RectangleConfig.json
  else
    logger "Rectangle already configured..."
  fi
}


set_os_vars
create_symlinks
submodules
install_packages
site_settings
claude_config
add_aliases
oh_my_zsh
ssh
kubernetes
tmux
gitinstall
editors
colima
macos_settings
#elixirinstall
#Need to use https://github.com/deadc0de6/dotdrop
