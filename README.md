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
| 1. 툴이 직접 관리 | claude, herdr, mise | `~/.local/bin` (실제 파일) | `claude update`, `herdr update`, `mise self-update` |
| 2. mise | GitHub 릴리즈 단일 바이너리 (rg, fd, bat, eza, lazygit, zoxide) | `~/.local/share/mise` | `mise/.config/mise/config.toml` 버전 수정 → `mise install` → `mise lock --global` → 커밋 |
| 3. stow | 직접 빌드하거나 rpm 을 푼 것 | `~/.local/stow/<이름-버전>`, 원본은 `~/.local/_tarball` | 새 버전 디렉토리 stow, 이전 버전 `stow -D` |

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
