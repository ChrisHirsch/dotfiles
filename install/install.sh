#!/bin/bash

#set -e

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
  ln -sf ~/dotfiles/colima/colima.yaml ~/.colima/default/colima.yaml
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
  logger "Need to restore iterm2 for osx??"
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
  mkdir -p ~/.ssh/sockets
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
    logger "Don't worry we will throw away the results of the p10k configure"
    p10k configure
  fi

  if [ -L ~/.p10k.zsh ]; then
    logger "Found existing symlink for ~/.p10k.zsh"
  else
    logger "Installing p10k configuration"
    ln -sf ~/dotfiles/zsh/p10k.zsh ~/.p10k.zsh
  fi
  logger "Don't need to explicitly download fonts..just make sure to be using iterm2"
  logger "Run p10k configure to re-configure powerlevel"

  set +e
  logger "Ensuring permissions are correct"
  compaudit | xargs chmod g-w

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

install_mac_packages() {

  if [ ! -n "$(command -v gcc)" ]  ; then
    logger "Installing OSX Dev Tools (including git)..."
    softwareupdate --all --install --force
  else
    logger "OSX Dev Tools (including git) already installed..."
  fi

  if [ ! -n "$(command -v fzf)" ]  ; then
    logger "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  fi
  brew analytics off
  ln -sf ~/dotfiles/Brewfile ~/Brewfile
  logger "Installing brew packages..."
  brew bundle --file ~/Brewfile
}

install_linux_packages(){
  logger "Installing core linux packages..."
  < ~/dotfiles/linux_packages xargs sudo ${pkg_mgr} install -y

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
    source <(kubectl completion bash) # setup autocomplete in bash into the current shell, bash-completion package should be installed first.
  echo "source <(kubectl completion bash)" >> ~/.bashrc # add autocomplete permanently to your bash shell.

  if [ ${machine} == 'Mac' ] ; then
    install_mac_packages
  elif [ ${machine} == 'Linux' ] ; then
    install_linux_packages
    install_mac_packages
  fi

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
  if ! grep -q -E '^alias ll=.*$' ${alias_file}; then
      logger "Adding ll alias..."
      echo "# List all files colorized in long format" >> ${alias_file}
      echo 'alias ll="ls -lah"' >> ${alias_file}
  fi

  if ! grep -q -E '^set -o vi$' ${bash_profile_file}; then
      logger "Setting VI bindings in bash..."
      echo 'set -o vi' >> ${bash_profile_file}
  fi
}

kubernetes() {
  ../kubernetes/install.sh
}

submodules() {
  logger "Updating meeting backgrounds and neovim submodules..."
  git -C ~/dotfiles submodule update --init --recursive
}

gitinstall() {
  if [ ! -d /opt/homebrew/lib/node_modules/git-cz ] ; then
    logger "Setting up git commitizen..."
    npm install -g git-cz --force
  else
    logger "Git commitizen already installed..."
  fi

  if [ ! -f ~/.gitconfig.user ] ; then
    logger "Setting up local git config..."
    read -p "Please enter your LOCAL (ie business) email address: " email
    logger "Using $email for ~/.gitconfig.user"
    printf '[user]\n  email = %s\n' "$email" > ~/.gitconfig.user
  else
    logger "Local Git config already installed..."
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
    vim -c "PlugInstall"
  
    if [ -f ~/.vim/plugged/YouCompleteMe ] ; then
      logger "You Complete Me..."
      cd ~/.vim/plugged/YouCompleteMe
      py install.py --all
    else
      logger "Error! YouCompleteMe doesn't exist, but it should now that Plugins are installed. Try going into vim and running :PlugInstall"
      exit 1
    fi
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
}


macos_settings() {
  if [ "${machine}" != 'Mac' ] ; then
    return
  fi

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
claude_config
install_packages
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
