#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

mkdir -p "$HOME/.local/bin"
cp cdto.sh "$HOME/.local/bin/cdto"
chmod +x "$HOME/.local/bin/cdto"

mkdir -p "$HOME/.zsh/completions"
cat > "$HOME/.zsh/completions/_cdto" << 'EOF'
#compdef cdto

_arguments \
  '1:base directory:_files -/' \
  '2:target folder:_files' \
  'file:command:->filemode'
EOF

if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
fi

if ! grep -q 'compinit' "$HOME/.zshrc"; then
  echo 'autoload -Uz compinit && compinit' >> "$HOME/.zshrc"
fi

if command -v apt-get &>/dev/null; then
  sudo apt-get update
  sudo apt-get install -y fd-find fzf

  if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi
else
  echo "fd and fzf must be installed manually"
fi

echo
echo "Setup complete. Running: source ~/.zshrc"

source ~/.zshrc
