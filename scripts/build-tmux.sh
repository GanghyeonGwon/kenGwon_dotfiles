#!/usr/bin/env bash
# tmux 를 소스에서 빌드해 ~/.local/stow/tmux-<버전> 에 설치하고 ~/.local 로 stow 한다(README "3층 stow").
# root 없이 동작한다. libevent 는 정적 라이브러리로 빌드해 tmux 실행 파일에 넣는다
# (빌드서버에 libevent-devel 이 없고 설치할 권한도 없어서). 실행할 때 필요한 외부 라이브러리는 ncurses(tinfo)뿐이다.
#
# 노트북·빌드서버가 같은 버전·같은 방식으로 빌드하도록 버전과 sha256 을 여기서 고정한다.
# 올릴 때: 아래 버전과 sha256(GitHub 릴리스 asset 의 digest)을 바꾸고 실행 → 동작 확인 → 커밋
#
# 사용법:
#   scripts/build-tmux.sh            # 이미 설치돼 있으면 빌드는 건너뛰고 stow 만 확인
#   scripts/build-tmux.sh --force    # 다시 빌드
#   scripts/build-tmux.sh --no-stow  # 설치만 하고 ~/.local 로 연결하지 않는다(시험용)
#
# 필요한 것: cc, make, pkg-config, yacc(bison 또는 byacc), ncurses 헤더, curl, stow
#   AlmaLinux/RHEL: gcc make pkgconf bison ncurses-devel
#   Ubuntu/WSL    : build-essential pkg-config bison libncurses-dev
#
# 되돌리기: stow -D -d ~/.local/stow -t ~/.local tmux-<버전>  (시스템 tmux 로 돌아간다)
# 주의: 실행 중인 tmux 서버는 옛 버전 그대로 돈다. 새 클라이언트가 옛 서버에 붙지 못하면
#       서버를 끝낸 뒤(필요하면 resurrect 로 저장) 다시 띄운다.
set -euo pipefail

TMUX_VER=3.8
TMUX_SHA256=e79c699c7e949dccd0a4a125e17b8d1261e311b16979dbc8eb34542f3966d82e
LIBEVENT_VER=2.1.13-stable
LIBEVENT_SHA256=f7e9383b8c0baa81b687e5b5eecc01beefaf1b19b64151d95ed61647fe7a315c

LOCAL="${LOCAL_DIR:-$HOME/.local}"   # 시험할 때만 바꾼다
TARBALL="$LOCAL/_tarball"
SRC="$LOCAL/src"
DEPS="$SRC/tmux-$TMUX_VER-deps"
PKG="$LOCAL/stow/tmux-$TMUX_VER"
JOBS="$(nproc 2>/dev/null || echo 4)"

force=0; do_stow=1
for a in "$@"; do
  case "$a" in
    --force) force=1 ;;
    --no-stow) do_stow=0 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "알 수 없는 옵션: $a" >&2; exit 2 ;;
  esac
done

die() { echo "오류: $*" >&2; exit 1; }
log() { echo "==> $*"; }

# 0. 준비물 확인
missing=()
for c in cc make pkg-config curl stow tar; do command -v "$c" >/dev/null || missing+=("$c"); done
command -v bison >/dev/null || command -v byacc >/dev/null || command -v yacc >/dev/null || missing+=("bison|byacc")
[ ${#missing[@]} -eq 0 ] || die "필요한 명령이 없다: ${missing[*]} (맨 위 주석의 패키지 목록 참고)"
printf '#include <curses.h>\nint main(void){return 0;}\n' | cc -x c - -o /dev/null 2>/dev/null \
  || die "ncurses 헤더가 없다(ncurses-devel / libncurses-dev)"

mkdir -p "$TARBALL" "$SRC" "$LOCAL/stow"

fetch() { # url file sha256
  local url="$1" f="$TARBALL/$2" sum="$3"
  if [ ! -f "$f" ]; then log "받기: $2"; curl -fsSL -o "$f.part" "$url"; mv "$f.part" "$f"; fi
  echo "$sum  $f" | sha256sum -c --quiet - || die "$2 sha256 불일치. 파일을 지우고 다시 실행하라."
}

if [ -x "$PKG/bin/tmux" ] && [ "$force" = 0 ]; then
  log "이미 설치됨: $PKG ($("$PKG/bin/tmux" -V)). 다시 빌드하려면 --force"
else
  fetch "https://github.com/libevent/libevent/releases/download/release-$LIBEVENT_VER/libevent-$LIBEVENT_VER.tar.gz" \
        "libevent-$LIBEVENT_VER.tar.gz" "$LIBEVENT_SHA256"
  fetch "https://github.com/tmux/tmux/releases/download/$TMUX_VER/tmux-$TMUX_VER.tar.gz" \
        "tmux-$TMUX_VER.tar.gz" "$TMUX_SHA256"

  log "libevent $LIBEVENT_VER (정적) → $DEPS"
  rm -rf "$SRC/libevent-$LIBEVENT_VER" "$DEPS"
  tar -xzf "$TARBALL/libevent-$LIBEVENT_VER.tar.gz" -C "$SRC"
  ( cd "$SRC/libevent-$LIBEVENT_VER"
    ./configure --prefix="$DEPS" --disable-shared --enable-static --with-pic \
      --disable-openssl --disable-samples --disable-libevent-regress >"$SRC/libevent-configure.log" 2>&1
    make -j"$JOBS" >"$SRC/libevent-make.log" 2>&1
    make install >"$SRC/libevent-install.log" 2>&1 ) || die "libevent 빌드 실패. 로그: $SRC/libevent-*.log"

  log "tmux $TMUX_VER → $PKG"
  rm -rf "$SRC/tmux-$TMUX_VER" "$PKG"
  tar -xzf "$TARBALL/tmux-$TMUX_VER.tar.gz" -C "$SRC"
  ( cd "$SRC/tmux-$TMUX_VER"
    PKG_CONFIG_PATH="$DEPS/lib/pkgconfig" ./configure --prefix="$PKG" >"$SRC/tmux-configure.log" 2>&1
    make -j"$JOBS" >"$SRC/tmux-make.log" 2>&1
    make install >"$SRC/tmux-install.log" 2>&1 ) || die "tmux 빌드 실패. 로그: $SRC/tmux-*.log"
fi

# 1. 빌드 결과 확인
"$PKG/bin/tmux" -V | grep -qx "tmux $TMUX_VER" || die "설치된 tmux 버전이 $TMUX_VER 이 아니다"
if ldd "$PKG/bin/tmux" | grep -q "not found"; then die "실행에 필요한 라이브러리가 없다: $(ldd "$PKG/bin/tmux" | grep 'not found')"; fi
ldd "$PKG/bin/tmux" | grep -q libevent && die "libevent 가 정적으로 들어가지 않았다"
log "확인: $("$PKG/bin/tmux" -V), libevent 정적 포함"

# 2. capture-pane 회귀 확인(빌드서버 시스템 tmux 는 이 명령에 서버가 죽었다). 임시 소켓·빈 설정으로만 한다.
sock="build-tmux-check-$$"
sock_path="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$sock"
trap 'rm -f "$sock_path"' EXIT   # 서버를 끝내도 소켓 파일은 남으므로 지운다
"$PKG/bin/tmux" -L "$sock" -f /dev/null new-session -d -x 80 -y 20 "sleep 30"
if ! { "$PKG/bin/tmux" -L "$sock" capture-pane -p >/dev/null && "$PKG/bin/tmux" -L "$sock" has-session 2>/dev/null; }; then
  "$PKG/bin/tmux" -L "$sock" kill-server 2>/dev/null || true
  die "capture-pane 뒤 서버가 살아 있지 않다"
fi
"$PKG/bin/tmux" -L "$sock" kill-server
log "확인: capture-pane 정상(임시 소켓)"

# 3. ~/.local 로 연결
if [ "$do_stow" = 1 ]; then
  # 다른 버전의 tmux 패키지가 stow 돼 있으면 먼저 내린다
  for old in "$LOCAL"/stow/tmux-*; do
    [ -d "$old" ] && [ "$old" != "$PKG" ] || continue
    if [ "$(readlink -f "$LOCAL/bin/tmux" 2>/dev/null)" = "$(readlink -f "$old/bin/tmux")" ]; then
      log "이전 버전 내리기: $(basename "$old")"; stow -D -d "$LOCAL/stow" -t "$LOCAL" "$(basename "$old")"
    fi
  done
  stow --no-folding -d "$LOCAL/stow" -t "$LOCAL" "tmux-$TMUX_VER"
  log "연결: $LOCAL/bin/tmux → $(readlink "$LOCAL/bin/tmux")"
  case ":$PATH:" in *":$LOCAL/bin:"*) ;; *) echo "참고: $LOCAL/bin 이 PATH 에 없다";; esac
  echo "새 셸에서 'command -v tmux' 가 $LOCAL/bin/tmux 인지 확인하라. 되돌리기: stow -D -d $LOCAL/stow -t $LOCAL tmux-$TMUX_VER"
fi
