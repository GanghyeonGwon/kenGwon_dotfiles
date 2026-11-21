#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# gitstatus(빠른 git 프롬프트 데몬) 서브모듈 초기화
if [ -d "$DOTFILES_DIR/.git" ]; then
  git -C "$DOTFILES_DIR" submodule update --init --recursive bash/.bashrc.d/vendor/gitstatus
fi

link() {
  local src="$1"
  local dst="$2"

  if [ -L "$dst" ]; then
    echo "[skip]   $dst (already a symlink)"
    return
  fi

  if [ -e "$dst" ]; then
    local backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
    echo "[backup] $dst → $backup"
    mv "$dst" "$backup"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "[link]   $dst → $src"
}

link "$DOTFILES_DIR/bash/.bash_profile"   "$HOME/.bash_profile"
link "$DOTFILES_DIR/bash/.bashrc"         "$HOME/.bashrc"
link "$DOTFILES_DIR/bash/.bashrc.d"       "$HOME/.bashrc.d"
link "$DOTFILES_DIR/tmux/.tmux.conf"      "$HOME/.tmux.conf"
link "$DOTFILES_DIR/nvim/.config/nvim"    "$HOME/.config/nvim"
# herdr 는 ~/.config/herdr/ 아래에 로그(herdr.log 등)와 세션 상태도 쓰므로
# 디렉토리째 링크하면 안 된다. config.toml 파일 하나만 링크한다.
link "$DOTFILES_DIR/herdr/.config/herdr/config.toml" "$HOME/.config/herdr/config.toml"

echo ""
echo "Done. Re-login or run: source ~/.bashrc"
echo ""
echo "herdr 바이너리는 별도로 설치해야 합니다:"
echo "  ./scripts/install-herdr.sh          # 개인 머신 (~/.local/bin)"
echo "  ./scripts/install-herdr.sh --stow   # 빌드서버 (~/.local/stow)"
