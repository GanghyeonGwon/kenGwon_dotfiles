# kenGwon dotfiles

bash / tmux / nvim / herdr / mise 설정. root 권한 없이 `$HOME` 안에서만 동작하도록 구성한다.

## 배포 방식 (머신별)

| 머신 | 방식 |
|---|---|
| 빌드서버 (192.168.0.99, AlmaLinux, root 없음) | GNU stow: `stow --no-folding -d ~/dotfiles -t ~ <패키지>` |
| WSL2 노트북 | `./install.sh` (심볼릭 링크) |

`herdr`, `mise` 패키지는 반드시 `--no-folding` 으로 stow 한다. 이 두 툴은 `~/.config/<툴>/` 아래에
로그·소켓·상태 파일을 쓰므로, 디렉토리째 링크되면(tree folding) 그 파일들이 저장소 안에 쌓인다.

## `$HOME` 툴 배치 원칙: "업데이트를 누가 하나"

| 층 | 대상 | 위치 | 업데이트 |
|---|---|---|---|
| 1. 툴이 직접 관리 | claude, herdr, mise, rclone | `~/.local/bin` (실제 파일) | `claude update`, `herdr update`, `mise self-update`, `rclone selfupdate` |
| 2. mise | GitHub 릴리즈 바이너리 (rg, fd, bat, eza, lazygit, zoxide, neovim, tree-sitter) | `~/.local/share/mise` | `mise/.config/mise/config.toml` 버전 수정 → `mise install` → `mise lock --global` → 커밋 |
| 3. stow | 직접 빌드하거나 rpm 을 푼 것, mise 에 없는 단일 바이너리·AppImage (magick, tectonic, wezterm) | `~/.local/stow/<이름-버전>`, 원본은 `~/.local/_tarball` | 새 버전 디렉토리 stow, 이전 버전 `stow -D` |

### `~/.local` 디렉토리 역할

| 경로 | 용도 |
|---|---|
| `bin/` | 실행 파일과 링크만 둔다. 소스나 빌드 트리를 두지 않는다 |
| `stow/<이름-버전>/` | 3층 패키지. 여기 있는 패키지는 전부 stow 된 상태를 유지한다 (`stow -n -v <pkg>` → 할 일 없음) |
| `src/` | 소스·빌드 트리. 재빌드하거나 `install_manifest.txt` 를 볼 때 쓴다. 런타임에는 쓰지 않는다 |
| `_tarball/` | 받은 원본 (tar.gz, rpm, 단일 바이너리) |
| `_retired/<날짜>/` | 정리하면서 치운 것과 롤백 스크립트·메모 |

3층 설치 절차 (예: `make install`):
`./configure --prefix=$HOME/.local/stow/foo-1.2` → `make install` → `stow --no-folding -d ~/.local/stow -t ~/.local foo-1.2`.
rpm 은 `rpm2cpio x.rpm | cpio -id` 로 푼 `usr/` 아래 내용을 `~/.local/stow/<이름-버전>/` 에 넣는다.
stow 디렉토리 바로 아래에 풀지 않는다(예전에 `stow/bin` 같은 가짜 패키지가 생긴 원인이다).
AppImage 처럼 파일 이름이 긴 경우에는 패키지 `bin/` 에 짧은 이름의 링크를 만든다.
긴 원본 이름은 `.stow-local-ignore` 에 `.*\.AppImage` 를 적어 `~/.local/bin` 에 노출하지 않는다
(stow 의 무시 패턴은 이름 전체와 비교하므로 `.*` 가 필요하다).

## 알려진 문제

- 빌드서버의 시스템 tmux(`tmux-3.3a-13.20230918git…el10`, `tmux -V` = next-3.4)는 `tmux capture-pane` 을
  실행하면 서버가 core dump 로 죽는다. 빈 설정(`-f /dev/null`)에서도, pane 내용과 상관없이 재현된다.
  평소 사용(attach, 분할, popup, resurrect 저장)에서는 이 명령을 쓰지 않는다.
  `@resurrect-capture-pane-contents` 는 켜지 않는다.

- 스스로 업데이트하는 툴을 stow/mise 에 넣지 않는다. 버전 디렉토리 안의 파일이 제자리에서 새 버전으로
  덮여 버전 표기와 롤백이 깨진다. herdr 0.9.5 로 실측했다(`scripts/install-herdr.sh` 주석 참고).
- mise 버전은 `config.toml` 에, 체크섬은 `mise.lock` 에 고정된다. 노트북과 빌드서버가 같은 선언을 쓴다.

## PATH

`bash/.bashrc` 맨 위(비대화형 가드보다 위)에서 `~/.local/bin` 과 그 바로 뒤에 mise shims 를 넣는다.
그래서 `ssh host cmd` 나 `herdr --remote` 처럼 비대화형 SSH 셸에서도 툴을 찾는다
(bash 는 `SSH_CLIENT` 가 있으면 비대화형이어도 `~/.bashrc` 를 읽는다. Ubuntu, AlmaLinux 10 확인).
`.bashrc` 는 노트북과 빌드서버가 공유하므로, 특정 호스트에만 있는 경로는 넣지 않는다.

## 빌드서버 이력 메모

- 2026-11-21: rg/fd/bat/eza/lazygit/zoxide 를 mise 로 이전했다(바이너리 sha256 동일).
  `~/.local/bin/<툴>` 은 mise shim 으로 가는 호환 링크로 남겨 두었다. 이전부터 떠 있던 tmux/herdr 셸의
  PATH 에는 shims 가 없기 때문이다. 옛 파일은 `~/.local/_retired/20261121/` 에 있고, `ROLLBACK.sh` 로 되돌린다.
- 2026-11-21: nvim 도 mise(neovim 0.11.4)로 이전했다. `--version` 과 런타임 트리가 옛 AppImage 판과 동일하다.
  옛 `~/.local/bin/squashfs-root` 는 실행 중인 nvim 이 런타임 파일을 계속 읽기 때문에 그 자리에 두었다.
  옛 nvim 이 모두 종료된 뒤 `~/.local/_retired/20261121/RETIRE_NVIM_APPIMAGE.sh` 로 치운다
  (사용 중인 프로세스가 있으면 스스로 거부한다).
- 2026-11-21: `~/.local` 구조를 정리했다.
  - 소스·빌드 트리(Bear, lua, luarocks, autojump, ghostscript, stow)를 `bin/` 에서 `src/` 로 옮겼다.
  - 흩어져 설치돼 있던 lua, luarocks, bear, ghostscript 를 stow 패키지로 이관했다(기능 테스트 결과 전후 동일).
  - `stow/{bin,lib,share}` 에 섞여 있던 rpm 내용물을 `lz4-1.9.4`, `rpcgen-1.4` 패키지로 분리했다.
  - `~/.local/bin/stow` 를 `stow-2.4.1` 패키지로 연결했다.
  - 상세 내용과 롤백 방법은 `~/.local/_retired/20261121/ROLLBACK_LOCAL_LAYOUT.md` 에 있다.
- 2026-11-21: tmux 세션과 nvim 을 모두 종료하고(저장 안 된 버퍼 없음 확인, resurrect 저장 뒤) 남은 것을 정리했다.
  - 옛 nvim AppImage(`squashfs-root`)를 `_retired` 로 옮겼다.
  - magick, tectonic, wezterm 을 stow 패키지로 옮겼다. rclone 은 1층에 둔다.
  - 깨끗한 상태에서 새로 띄워 검증했다.
    - tmux: 설정, 플러그인, popup 환경, pane 셸, pane 안의 nvim TUI
    - herdr: 서버를 재시작하자 claude 2개가 `--resume <세션ID>` 로 자동 복구됐다. pane 셸과 nvim 도 정상
    - nvim: checkhealth 오류·경고가 옛 판과 동일
- mise shim 호환 링크(`~/.local/bin/<툴>` → shims)는 PATH 에 shims 가 없는 오래된 프로세스(VS Code server,
  Claude 원격 세션)가 남아 있어 아직 두었다. 그 프로세스들이 사라진 뒤(재부팅 등)
  `~/.local/_retired/20261121/RETIRE_COMPAT_LINKS.sh` 로 지운다(남아 있으면 스스로 거부한다).
- herdr 롤백: `scripts/install-herdr.sh --offline ~/.local/_tarball/herdr-<이전버전>-linux-x86_64`
