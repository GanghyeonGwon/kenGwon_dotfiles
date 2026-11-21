#!/usr/bin/env bash
# tree-sitter 상태 점검 (설명은 check-treesitter.lua 맨 위 참고)
#   scripts/check-treesitter.sh                 # 파서·쿼리만 검사
#   scripts/check-treesitter.sh foo.c bar.dts   # 실제 파일 하이라이트까지 검사
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec nvim --headless -c "luafile $here/check-treesitter.lua" "$@"
