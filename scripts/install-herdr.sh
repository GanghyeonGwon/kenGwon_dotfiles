#!/usr/bin/env bash
#
# herdr 설치 스크립트 (재현 가능 / sudo 불필요 / sha256 검증)
#
# 공식 설치 경로인 `curl -fsSL https://herdr.dev/install.sh | sh` 를 쓰지 않는 이유:
#   1) 버전을 고정하거나 롤백할 수 없다
#   2) 설치 대상(빌드서버)이 망분리라 herdr.dev 로 나가지 못할 수 있다
#   3) stow 레이아웃에 맞춰 버전별 디렉토리에 넣어야 한다
#
# 사용법:
#   ./install-herdr.sh                      # ~/.local/bin 에 설치 (WSL2, Arch 등 개인 머신)
#   ./install-herdr.sh --stow               # ~/.local/stow/herdr-<ver>/bin 에 설치 후 stow
#   ./install-herdr.sh --version 0.9.5      # 버전 고정
#   ./install-herdr.sh --fetch-only         # 바이너리만 내려받음 (망 되는 쪽에서 실행)
#   ./install-herdr.sh --offline <파일>     # 받아둔 바이너리로 설치 (망분리 서버에서 실행)
#
# 망분리 빌드서버 설치 흐름:
#   # 인터넷 되는 로컬에서
#   ./install-herdr.sh --fetch-only
#   scp _tarball/herdr-0.9.5-linux-x86_64 <빌드서버>:~/
#   # 빌드서버에서 (dotfiles 를 pull 받은 뒤)
#   ./scripts/install-herdr.sh --offline ~/herdr-0.9.5-linux-x86_64 --stow
#
# 롤백:
#   cd ~/.local/stow && stow -D herdr-<새버전> && stow herdr-<이전버전>

set -euo pipefail

MANIFEST_URL="https://herdr.dev/latest.json"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="$DOTFILES_DIR/_tarball"

MODE="direct"      # direct | stow
VERSION=""
OFFLINE_FILE=""
FETCH_ONLY=0

die() { printf '[error] %s\n' "$*" >&2; exit 1; }
log() { printf '[herdr] %s\n' "$*"; }

while [ $# -gt 0 ]; do
    case "$1" in
        --stow)       MODE="stow"; shift ;;
        --version)    VERSION="${2:-}"; [ -n "$VERSION" ] || die "--version 에 버전이 필요합니다"; shift 2 ;;
        --offline)    OFFLINE_FILE="${2:-}"; [ -n "$OFFLINE_FILE" ] || die "--offline 에 파일 경로가 필요합니다"; shift 2 ;;
        --fetch-only) FETCH_ONLY=1; shift ;;
        -h|--help)    sed -n '2,30p' "$0"; exit 0 ;;
        *)            die "알 수 없는 옵션: $1" ;;
    esac
done

# ── 플랫폼 판별 (herdr 공식 install.sh 와 동일한 TARGET 문자열을 만든다) ─────────
case "$(uname -s)" in
    Linux)  os="linux" ;;
    Darwin) os="macos" ;;
    *)      die "지원하지 않는 OS: $(uname -s)" ;;
esac
case "$(uname -m)" in
    x86_64|amd64)  arch="x86_64" ;;
    aarch64|arm64) arch="aarch64" ;;
    *)             die "지원하지 않는 아키텍처: $(uname -m)" ;;
esac
TARGET="${os}-${arch}"

# ── 설치 소스 결정 ──────────────────────────────────────────────────────────────
if [ -n "$OFFLINE_FILE" ]; then
    # 망분리 서버: 미리 받아둔 바이너리 사용. 버전은 바이너리에 직접 묻는다.
    [ -f "$OFFLINE_FILE" ] || die "파일이 없습니다: $OFFLINE_FILE"
    chmod +x "$OFFLINE_FILE"
    VERSION="$("$OFFLINE_FILE" --version | awk '{print $2}')"
    [ -n "$VERSION" ] || die "바이너리에서 버전을 읽지 못했습니다"
    BIN_SRC="$OFFLINE_FILE"
    log "오프라인 설치: v${VERSION} (${TARGET})"
else
    command -v curl >/dev/null || die "curl 이 필요합니다"
    log "릴리즈 매니페스트 조회: $MANIFEST_URL"
    MANIFEST="$(curl -fsSL --retry 3 --connect-timeout 10 --max-time 20 "$MANIFEST_URL")" \
        || die "매니페스트를 가져오지 못했습니다. 망분리 환경이면 --offline 을 쓰세요."

    # jq 없이도 돌아야 하므로(빌드서버에 없을 수 있음) 공식 install.sh 와 같은 awk 파싱을 쓴다.
    #
    # 주의: awk 에 파이프(printf | awk)로 먹이면 안 된다. awk 가 매치 직후 exit 하면
    # 거대한 매니페스트를 아직 쓰고 있던 printf 가 SIGPIPE 로 죽고, set -o pipefail
    # 때문에 스크립트 전체가 141 로 조용히 종료된다. here-string 을 쓰면 파이프가
    # 없어 이 문제가 생기지 않는다.
    pick() {  # pick <섹션> <TARGET>
        awk -v section="\"$1\"" -v target="\"$2\"" '
            $0 ~ "^[[:space:]]*" section "[[:space:]]*:" { inside = 1; next }
            inside && /^[[:space:]]*}/ { exit }
            inside && index($0, target) {
                sub(/^.*:[[:space:]]*"/, ""); sub(/".*$/, ""); print; exit
            }' <<<"$MANIFEST"
    }
    [ -n "$VERSION" ] || VERSION="$(awk -F'"' '/^[[:space:]]*"version"[[:space:]]*:/ {print $4; exit}' <<<"$MANIFEST")"
    URL="$(pick assets "$TARGET")"
    SHA="$(pick sha256 "$TARGET")"
    [ -n "$URL" ] || die "매니페스트에 ${TARGET} 바이너리가 없습니다"
    [ -n "$SHA" ] || die "매니페스트에 ${TARGET} sha256 이 없습니다"

    mkdir -p "$CACHE_DIR"
    BIN_SRC="$CACHE_DIR/herdr-${VERSION}-${TARGET}"
    if [ ! -f "$BIN_SRC" ]; then
        log "다운로드: v${VERSION} (${TARGET})"
        curl -fsSL --retry 3 --connect-timeout 10 --max-time 300 "$URL" -o "${BIN_SRC}.part" \
            || die "다운로드 실패: $URL"
        mv "${BIN_SRC}.part" "$BIN_SRC"
    else
        log "캐시 사용: $BIN_SRC"
    fi

    log "sha256 검증 중..."
    printf '%s  %s\n' "$SHA" "$BIN_SRC" | sha256sum -c - >/dev/null \
        || die "sha256 불일치. 받은 파일을 지우고 다시 시도하세요: $BIN_SRC"
    log "sha256 OK"
    chmod +x "$BIN_SRC"
fi

if [ "$FETCH_ONLY" -eq 1 ]; then
    log "바이너리 준비 완료 (설치는 하지 않음):"
    printf '  %s\n' "$BIN_SRC"
    exit 0
fi

# ── 설치 ────────────────────────────────────────────────────────────────────────
if [ "$MODE" = "stow" ]; then
    command -v stow >/dev/null || die "stow 가 필요합니다 (--stow 모드)"
    STOW_DIR="$HOME/.local/stow"
    PKG="herdr-${VERSION}"
    INSTALL_DIR="$STOW_DIR/$PKG/bin"

    mkdir -p "$INSTALL_DIR"
    install -m 0755 "$BIN_SRC" "$INSTALL_DIR/herdr"
    log "설치: $INSTALL_DIR/herdr"

    # 이전 herdr-* 패키지가 링크돼 있으면 먼저 푼다 (충돌 방지)
    for old in "$STOW_DIR"/herdr-*; do
        [ -d "$old" ] || continue
        oldpkg="$(basename "$old")"
        [ "$oldpkg" = "$PKG" ] && continue
        if [ -L "$HOME/.local/bin/herdr" ]; then
            case "$(readlink "$HOME/.local/bin/herdr")" in
                *"$oldpkg"*) log "이전 패키지 해제: $oldpkg"; stow -d "$STOW_DIR" -t "$HOME/.local" -D "$oldpkg" ;;
            esac
        fi
    done

    # stow 의 tree folding 방지. ~/.local/bin 이 없으면 stow 는 디렉토리를 만드는 대신
    # ~/.local/bin 자체를 stow/herdr-<ver>/bin 으로 가는 심볼릭 링크로 "접어"버린다.
    # 그러면 ~/.local/bin 이 herdr 패키지 소유가 되어 다른 툴을 넣을 수 없게 된다.
    mkdir -p "$HOME/.local/bin"
    stow --no-folding -d "$STOW_DIR" -t "$HOME/.local" "$PKG"
    log "stow 링크 완료: ~/.local/bin/herdr → stow/$PKG/bin/herdr"
    log "롤백하려면: stow -d $STOW_DIR -t ~/.local -D $PKG && stow -d $STOW_DIR -t ~/.local herdr-<이전버전>"
else
    INSTALL_DIR="${HERDR_INSTALL_DIR:-$HOME/.local/bin}"
    mkdir -p "$INSTALL_DIR"
    install -m 0755 "$BIN_SRC" "$INSTALL_DIR/herdr"
    log "설치: $INSTALL_DIR/herdr"
fi

# ── 사후 점검 ───────────────────────────────────────────────────────────────────
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) log "경고: ~/.local/bin 이 PATH 에 없습니다. 새 셸을 열거나 'source ~/.bashrc' 하세요." ;;
esac

log "버전: $("$HOME/.local/bin/herdr" --version 2>/dev/null || echo '확인 실패')"

if [ -f "$HOME/.config/herdr/config.toml" ]; then
    log "설정 검증:"
    "$HOME/.local/bin/herdr" config check || true
else
    log "아직 ~/.config/herdr/config.toml 이 없습니다. dotfiles 의 install.sh 를 먼저 실행하세요."
fi
