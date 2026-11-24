#!/bin/bash
# Runs the installer as a sudo user in a fresh Ubuntu container, then checks the result.
# Locally: docker run --rm -v ~/dotfiles:/src:ro ubuntu:24.04 /src/install/test-linux.sh
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq sudo git curl gpg ca-certificates > /dev/null
useradd -m -s /bin/bash tester
echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester
cp -a /src /home/tester/dotfiles
chown -R tester:tester /home/tester/dotfiles
git config --system --add safe.directory '*'

# A ~/.site without SITE_FILES skips 1Password
printf 'export CLAUDE_EXTRA_DIRS=""\n' > /home/tester/.site
chown tester:tester /home/tester/.site

# Answers: no desktop packages, then the git email
cd /home/tester/dotfiles/install
printf 'n\ntest@example.com\n' \
  | sudo -u tester -H DEBIAN_FRONTEND=noninteractive ./install.sh 2>&1 | tee /tmp/install.log

fail=0
check() {
  if sudo -u tester -H bash -c "$2"; then echo "ok: $1"; else echo "FAIL: $1"; fail=1; fi
}
check "tools installed" 'command -v zsh jq fzf op tmux vim > /dev/null'
check "dotfiles linked" 'test -L ~/.zshrc && test -L ~/.ssh/config && test -L ~/.gitconfig && test -L ~/.tmux.conf'
check "git email set" 'grep -q test@example.com ~/.gitconfig.user'
check "oh-my-zsh installed" 'test -f ~/.oh-my-zsh/oh-my-zsh.sh'
if grep -n -E 'command not found|No such file or directory' /tmp/install.log; then
  echo "FAIL: errors in the install output (above)"
  fail=1
fi
exit $fail
