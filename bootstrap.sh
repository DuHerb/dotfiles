#!/usr/bin/env bash
set -euo pipefail

# Idempotent bootstrap for a fresh macOS machine.
# Usage: curl -fsSL <raw-url>/bootstrap.sh | bash
#   or:  cd ~/dotfiles && ./bootstrap.sh

DOTFILES="$HOME/dotfiles"

# --------------------------------------------------------------------------
# 1. Xcode CLI tools
# --------------------------------------------------------------------------
if ! xcode-select -p &>/dev/null; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "Re-run this script after Xcode CLI tools finish installing."
  exit 0
fi

# --------------------------------------------------------------------------
# 2. Homebrew
# --------------------------------------------------------------------------
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --------------------------------------------------------------------------
# 3. Clone dotfiles (skip if already present)
# --------------------------------------------------------------------------
if [ ! -d "$DOTFILES" ]; then
  echo "Cloning dotfiles..."
  git clone https://github.com/DuHerb/dotfiles.git "$DOTFILES"
fi

cd "$DOTFILES"

# --------------------------------------------------------------------------
# 4. Brew bundle (installs stow + everything else)
# --------------------------------------------------------------------------
echo "Installing Homebrew packages..."
brew bundle --file="$DOTFILES/Brewfile"

# --------------------------------------------------------------------------
# 5. Stow all packages
# --------------------------------------------------------------------------
echo "Stowing dotfiles..."
for dir in */; do
  # Skip non-stow directories
  [[ "$dir" == ".git/" ]] && continue
  stow "$dir"
done

# --------------------------------------------------------------------------
# 6. Oh My Zsh
# --------------------------------------------------------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Zsh plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ] || \
  git clone https://github.com/zdharma-continuum/fast-syntax-highlighting "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
[ -d "$ZSH_CUSTOM/plugins/zsh-autocomplete" ] || \
  git clone https://github.com/marlonrichert/zsh-autocomplete "$ZSH_CUSTOM/plugins/zsh-autocomplete"

# --------------------------------------------------------------------------
# 7. TPM (Tmux Plugin Manager)
# --------------------------------------------------------------------------
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# --------------------------------------------------------------------------
# 8. Node via fnm
# --------------------------------------------------------------------------
if command -v fnm &>/dev/null; then
  eval "$(fnm env)"
  if ! fnm ls | grep -q "lts"; then
    echo "Installing Node LTS via fnm..."
    fnm install --lts
    fnm default lts-latest
  fi
fi

# --------------------------------------------------------------------------
# 9. Secrets template
# --------------------------------------------------------------------------
if [ ! -f "$HOME/.secrets" ]; then
  echo "Creating ~/.secrets template..."
  cat > "$HOME/.secrets" << 'SECRETS'
# Secrets — NOT tracked in version control
# export GH_PACKAGE_REGISTRY_READER_PAT=
# export GH_PACKAGE_REGISTRY_READER_USERNAME=
# export SHORTCUT_API_TOKEN=
SECRETS
  chmod 600 "$HOME/.secrets"
fi

echo ""
echo "Bootstrap complete! Open a new terminal to start using your dotfiles."
