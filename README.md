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

- 스스로 업데이트하는 툴을 stow/mise 에 넣지 않는다. 버전 디렉토리 안의 파일이 제자리에서 새 버전으로
  덮여 버전 표기와 롤백이 깨진다. herdr 0.9.5 로 실측했다(`scripts/install-herdr.sh` 주석 참고).
- mise 버전은 `config.toml` 에, 체크섬은 `mise.lock` 에 고정된다. 노트북과 빌드서버가 같은 선언을 쓴다.

## 동기화 원칙: 빌드서버가 기준

주 작업 환경은 빌드서버다. 버전을 올리는 일은 빌드서버에서 하고, 노트북은 따라간다.

| 대상 | 빌드서버 (기준) | 노트북 (따라감) |
|---|---|---|
| nvim 플러그인 `nvim/.config/nvim/lazy-lock.json` | `:Lazy update` → 동작 확인 → lock 커밋 | pull → `:Lazy restore` |
| mise 툴 `mise/.config/mise/{config.toml,mise.lock}` | 버전 수정 → `mise install` → `mise lock --global` → 커밋 | pull → `mise install` |

- lazy-lock.json 은 "이 머신에 설치된 플러그인 커밋"을 lazy 가 자동으로 기록하는 파일이다.
  `~/.config/nvim` 이 저장소로 링크돼 있어서 lazy 가 쓰는 즉시 저장소 파일이 바뀐다.
  - 노트북에서는 `:Lazy update` / `:Lazy sync` 를 하지 않는다. 노트북 lock 이 modified 가 되면
    업데이트를 했거나 lock 에 없는 플러그인을 설치한 것이다. `git restore` 로 버리고 `:Lazy restore` 를 실행한다.
  - 플러그인을 추가하거나 제거할 때는 설정 파일과 lock 변경을 같은 커밋에 넣는다.
    lock 을 빼고 커밋하면 다른 머신이 그 플러그인을 설치하면서 lock 을 다시 쓴다(2026-08 smear-cursor 사례).
  - 수정된 lock 을 `git stash` 로 치우지 않는다. 저장소 lock 과 실제 설치 상태가 어긋난 채로 남는다(2026-09 사례).
- 빌드서버는 GitHub 에 push 하지 못한다(SSH 키 없음). 노트북에서 빌드서버 저장소를 pull 해서 GitHub 로 push 한다.
  `git pull ssh://ghgwon@192.168.0.99/disk/vol3/ghgwon/dotfiles main && git push`

## tree-sitter (구문 하이라이트)

nvim 의 하이라이트, 들여쓰기, 접기, `]f`/`vaf` 같은 코드 단위 이동이 tree-sitter 로 동작한다. 세 부분으로 나뉜다.

| 구성 | 역할 | 버전을 정하는 곳 |
|---|---|---|
| ① 엔진 | 파서를 실행한다 | nvim 에 내장 → mise `neovim` |
| ② nvim-treesitter 플러그인 | 언어별 파서 버전과 하이라이트 규칙(쿼리)을 정한다 | `lazy-lock.json` |
| ③ tree-sitter CLI | 파서를 `.so` 로 컴파일한다 | mise `tree-sitter` |

- 파서 버전은 ② 의 커밋이 정한다. 그래서 `lazy-lock.json` 만 같으면 두 머신의 하이라이트가 같다.
  파서는 `~/.local/share/nvim/site/parser/*.so` 에 있다(저장소 밖).
- ② 를 올리면 파서(.so)도 같이 맞춰야 한다. 어긋나면 "query error" 가 나거나 하이라이트가 빠진다.
  LazyVim 은 ② 가 바뀔 때 build 훅으로 `:TSUpdate` 를 **자동으로** 돌린다. 단 nvim 을 화면으로 열었을 때 얘기다.
  headless 로 `+Lazy! update +qa` 를 돌리면 훅이 끝나기 전에 종료되므로 `:TSUpdate` 를 따로 해야 한다.
- 언어 목록은 `nvim/.config/nvim/lua/plugins/treesitter.lua` 의 `ensure_installed` 다(LazyVim 기본 목록에 더해짐).
  목록에 없는 언어는 vim 의 옛 정규식 syntax 로 떨어진다. 목록에 추가하면 nvim 을 열 때 자동으로 설치된다.
- `.h` 는 내용으로 C/C++ 를 판정한다(같은 파일 주석 참고). nvim 기본값은 무조건 C++ 라서 커널 헤더가 깨졌다.
- 언어별 하이라이트 규칙 보강은 `nvim/.config/nvim/queries/<언어>/highlights.scm`(`; extends`), 색은 `colorscheme.lua` 의
  `@그룹.<언어>` 항목에 둔다. 지금은 devicetree 만 있다(매크로 purple, `&참조` 를 라벨 색으로, `#if`/`#define` 등 전처리문을 .h 와 같은 회색으로,
  `#define` 값은 `injections.scm` 으로 C 처럼 칠함).

업데이트 절차(빌드서버):
1. nvim 을 화면으로 열고 `:Lazy update` → 아래쪽에 "Installed/Updated N languages" 요약이 뜰 때까지 기다린다.
2. nvim 을 닫고 `scripts/check-treesitter.sh <자주 여는 파일들>` → 마지막 줄이 `TREESITTER OK` 인지 본다.
   설치된 모든 파서의 쿼리를 실제로 파싱하고, 빠진 파서와 파일별 하이라이트 켜짐 여부를 확인한다.
3. 평소 보는 파일 몇 개를 열어 색을 눈으로 본다(아래 "눈으로 볼 것").
4. 이상하면 `:TSUpdate` → 그래도 이상하면 lock 을 되돌리고 `:Lazy restore` → `:TSUpdate`.

노트북: pull → nvim 을 열면 새 언어가 자동 설치된다 → `:Lazy restore` → `:TSUpdate` → `scripts/check-treesitter.sh`.

눈으로 볼 것(스크립트가 못 잡는 것: "켜졌는데 색이 틀린" 경우):
- C: 매크로(`#define`), 함수 이름, 타입, 문자열 안 `%d` 같은 포맷, 주석 안 `TODO`
- 커널 헤더: `new`, `class` 같은 변수명이 키워드 색이 아닌지
- `.dts`, Makefile, Kconfig, `.S`, `.cmm`: 대충이라도 구분돼서 칠해지는지
- `:Inspect` 를 커서 위에서 실행하면 그 글자에 붙은 하이라이트 그룹을 볼 수 있다.

## Yocto / BitBake (nvim)

설정은 `nvim/.config/nvim/lua/plugins/yocto.lua` 하나다. 공식 도구만 쓴다.

| 기능 | 도구 | 상태 |
|---|---|---|
| 하이라이트 | tree-sitter `bitbake` 파서 | 됨 |
| 자동완성, 변수 문서(`K`) | `language-server-bitbake`(Yocto 공식 LSP, mason) | 됨 |
| 레시피 검사 | `oelint-adv`(mason) + nvim-lint. 열 때·저장할 때. info 수준은 숨김 | 됨 |
| `inherit`/`require`/레시피 정의로 이동 | — | **안 됨.** 공식 LSP 가 VS Code 확장의 프로젝트 스캔에 의존한다 |
| 변수의 최종 값 hover | — | 안 됨. 같은 이유. 아래 `bitbake -e` 로 본다 |

정의 이동은 [vscode-bitbake#380](https://github.com/yoctoproject/vscode-bitbake/issues/380) 에서 진행 중이다
(메인테이너: "neovim 개선이 다음 순서"). 지원되면 mason 에서 서버만 업데이트하면 된다.

대신 쓰는 방법(빌드 환경을 source 한 셸에서):
- **변수가 어디서 어떻게 정해졌나** — 이게 bitbake 의 진짜 "정의로 이동"이다. 레이어·bbappend·override 를 다 거친 결과다.
  `bitbake -e <레시피> > /tmp/<레시피>.env` 를 nvim 으로 열고 `/^# \$SRC_URI` 로 찾는다.
  변수마다 `#   set /경로/foo.bb:12`, `#   :append /경로/foo.bbappend:3` 같은 대입 이력이 있고, 그 줄에서 `gF` 로 바로 간다.
  최종 값은 이력 아래 `SRC_URI="..."` 줄이다.
- **bbappend / 레시피 위치**: `bitbake-layers show-appends`, `bitbake-layers show-recipes -f <이름>`
- **inherit/require 대상 파일**: 파일 picker(`<leader><space>`)로 `kernel.bbclass` 처럼 찾는다.
- **빌드 실패**: `tmp/work/<arch>/<레시피>/<버전>/temp/log.do_<task>` 와 실행된 스크립트 `run.do_<task>` 를 nvim 으로 연다.
  손으로 고쳐 보려면 `bitbake -c devshell <레시피>`, 소스를 계속 고칠 거면 `devtool modify <레시피>`.
- `bitbake` 는 빌드 디렉토리에 잠금 파일을 잡는다. 빌드가 도는 중에는 `bitbake -e` 가 기다리거나 실패한다.

## 알려진 문제

- 빌드서버의 시스템 tmux(`tmux-3.3a-13.20230918git…el10`, `tmux -V` = next-3.4)는 `tmux capture-pane` 을
  실행하면 서버가 core dump 로 죽는다. 빈 설정(`-f /dev/null`)에서도, pane 내용과 상관없이 재현된다.
  평소 사용(attach, 분할, popup, resurrect 저장)에서는 이 명령을 쓰지 않는다.
  `@resurrect-capture-pane-contents` 는 켜지 않는다.

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
- 2026-11-21: mise shim 호환 링크(`~/.local/bin/<툴>` → shims) 7개를 `RETIRE_COMPAT_LINKS.sh` 로 지웠다.
  재부팅은 필요 없었다. PATH 에 shims 가 없던 11/19~20 시작 프로세스(VS Code server, Claude 원격 세션 2개)를
  정리한 뒤 실행했다. 대화형·로그인·비대화형 SSH 셸 모두 shims 로 툴을 찾는다.
  되돌리기: `ln -s ../share/mise/shims/<툴> ~/.local/bin/<툴>`
- 2026-11-21: `mise prune` 으로 옛 버전 7개(neovim 0.11.4, rg 14.1.1 등)를 지웠다. 되돌리려면 버전을 되돌리고 `mise install`.
- herdr 롤백: `scripts/install-herdr.sh --offline ~/.local/_tarball/herdr-<이전버전>-linux-x86_64`
- 2026-11-21: nvim 을 0.11.4 에서 0.12.6 으로 올리고 `:Lazy update` 로 플러그인 23개를 갱신했다(LazyVim 16.0.2).
  - LazyVim 은 nvim < 0.12 일 때만 nvim-treesitter 를 `7caec274` 로 고정한다. 0.12 에서는 고정이 풀려 최신 main 을 따른다.
    그래서 lock 의 treesitter 커밋이 nvim 버전에 따라 달라진다. **노트북과 빌드서버의 nvim 버전을 같이 맞춘다.**
  - treesitter 를 올린 뒤 `:TSUpdate` 를 해야 한다. 하지 않으면 `diff` 쿼리 오류가 난다.
  - 최신 nvim-treesitter 는 `jsonc` 파서를 뺐다(`json` 이 jsonc 파일도 처리한다).
    지원 목록에서 빠졌기 때문에 `uninstall('jsonc')` 는 "unsupported language" 경고만 내고 아무것도 지우지 않는다.
    `~/.local/share/nvim/site/parser/jsonc.so` 와 `site/parser-info/jsonc.revision` 을 직접 지웠다.
  - mason 이 예전에 깔아 둔 tree-sitter-cli 0.25.10 이 nvim 안의 PATH 에서 mise 0.26.13 을 가리고 있었다
    (checkhealth: "tree-sitter-cli v0.26.1 is required"). mason 패키지를 지웠다. LazyVim 은 PATH 에
    tree-sitter 가 없을 때만 mason 으로 설치하므로 다시 깔리지 않는다.
  - 검증(headless): C, jsonc 하이라이트, t32 파서 정상. checkhealth 에 남은 오류는 headless 에서만 나는 snacks 5개로,
    0.11.4 와 같다. 롤백: 이 커밋을 되돌리고 `mise install` → `:Lazy restore` → `:TSUpdate`.
  - 노트북 따라가기: pull → `mise install` → `:Lazy restore` → `:TSUpdate` → jsonc 파서 파일 직접 삭제(위 참고)
    → `:MasonUninstall tree-sitter-cli`(있으면) → `:checkhealth nvim-treesitter`.
- 2026-11-21: mise 툴을 올렸다. rg 14.1.1→15.2.0, fd 10.3.0→10.5.2, bat 0.26.0→0.26.1, eza 0.23.4→0.23.5,
  lazygit 0.55.1→0.66.3, zoxide 0.9.8→0.10.0. tree-sitter(0.27)는 nvim-treesitter 지원을 확인하기 전까지 보류한다.
  - 검증: rg/fd/bat/eza 출력(검색 결과, 파일 목록, 하이라이트 해시, ls 결과)이 전후 바이트 단위로 같다.
    대화형 bash 기동 오류 없음. zoxide 는 DB 599개 그대로이고, 새 셸과 이미 떠 있던 셸(0.9.8 init 함수) 모두 `z` 정상.
    lazygit 은 pty 에서 패널이 정상으로 그려지고 `state.yml` 이 바뀌지 않았다.
  - 롤백: `config.toml`, `mise.lock` 을 되돌리고 `mise install`. 옛 버전은 `mise prune` 전까지 남아 있다.
- 2026-11-21: mason 패키지를 올렸다(저장소 밖이라 머신마다 따로 한다. `:Mason` → `U`).
  clangd 21.1.0→23.1.0, lua-language-server 3.15.0→3.19.2, bash-language-server 5.6.0→5.8.1, pyright 1.1.406→1.1.414,
  marksman, markdownlint(-cli2), stylua 2.3.0→2.6.0, shfmt 3.12.0→3.14.1.
  - 검증: c/lua/sh/py/json 버퍼에 LSP 가 전후 똑같이 붙는다. 실제 BSP 파일(`eyeTune`)에 `clangd --check` 를 돌리면
    21 은 `-mno-riscv-attribute` 등 커널 플래그 3개를 몰라서 오류 3개를 냈고, 23 은 0개다.
  - 롤백: `:MasonInstall clangd@21.1.0` 처럼 버전을 지정해 다시 설치한다.
  - 같이 정리: `~/.local/state/nvim/lsp.log`(268MB)를 비우고, clone 실패로 남은 `lazy/vim-osc52.cloning` 을 지웠다.

## 노트북 이력 메모

- 2026-11-21: 노트북(WSL2)을 빌드서버 기준으로 맞췄다. mise(v2026.10.25)를 도입하고
  rg/fd/bat/eza/lazygit/zoxide/neovim/tree-sitter 를 mise 로 이전했다.
  `mise.lock` 은 빌드서버 것과 이미 일치해서 한 줄도 바뀌지 않았다.
  - apt 판을 쓰던 rg(14.1.0 → 14.1.1), bat(0.24.0 → 0.26.0)은 shims 우선순위로 자동 교체된다.
  - `~/.local/bin/<툴>` 은 mise shim 으로 가는 링크로 남겨 두었다. 교체는 `ln -s … tmp && mv -T tmp <경로>`
    로 원자적으로 해서 떠 있던 tmux 셸이 깨지지 않았다. 옛 파일은 `~/.local/_retired/20261121/` + `ROLLBACK.sh`.
- 2026-11-21: nvim 을 0.12.0 에서 mise neovim 0.11.4 로 **내렸다**. 노트북이 서버보다 앞서 있어서
  lazy 가 lock 을 계속 다시 쓰던 것이 원인이었다. 내린 뒤 `:Lazy! restore` 로 42개를 복원했고
  lock 해시가 전후 동일하다. checkhealth 는 오류 6→5, 경고 17→16 으로 줄었다
  (차이는 tree-sitter CLI 설치로 해소된 오류 1개 + "0.12.6 업데이트 가능" 경고 1개).
- 2026-11-21: 노트북 `~/.local` 을 3층 원칙대로 정리했다.
  - `src/` 로 옮긴 빌드 트리: fd-v10.3.0, lua-5.4.6, luarocks-3.12.2, nvim-linux-x86_64, ghostscript-10.06.0
  - stow 패키지 8개: ghostscript-10.06.0, ghostty-1.2.2, wezterm-20240203, tectonic-0.15.0,
    lua-5.4.6, luarocks-3.12.2, magick-7.1.2-5, win32yank-x64
  - `bin/` 에 남은 실제 파일은 herdr, mise(1층)와 vba_extract.py(버전 없는 헬퍼 스크립트)뿐이다.
- ghostscript 는 ROMFS 빌드라 **재배치해도 된다.** 바이너리에 `~/.local/ghostscript-10.06.0-local/` prefix 가
  박혀 있지만 리소스를 `%rom%Resource/...` 에서 읽으므로 그 경로가 없어도 동작한다.
  전혀 다른 경로에 복사해 렌더한 PNG 가 바이트 단위로 동일한 것을 확인하고 stow 로 옮겼다.
  옮기면서 `ps2pdf`, `dvipdf`, `pdf2ps` 등 래퍼 20여 개가 처음으로 PATH 에 노출됐다.
- stow 주의: `~/.config/herdr` 나 `~/.local/bin` 처럼 **없는 디렉토리를 대상으로 stow 하면 tree folding 이
  일어나 디렉토리 자체가 패키지로 가는 링크가 된다.** herdr 는 그 밑에 로그·소켓을 쓰므로 치명적이다.
  `--no-folding` 을 쓰거나 대상 디렉토리를 미리 만들 것. 노트북에서 실측으로 재현했다.
- 2026-11-21: 노트북을 빌드서버 f9b736f 에 맞췄다. 저장소는 이미 같은 커밋이라 pull 이 필요 없었다.
  - mise 8개 전부 설치 확인(rg 15.2.0, fd 10.5.2, bat 0.26.1, eza 0.23.5, lazygit 0.66.3,
    zoxide 0.10.0, neovim 0.12.6, tree-sitter 0.26.13). mise.lock 변경 없음.
  - `:Lazy! restore` → `:TSUpdate`(13/13). lazy-lock.json 해시 전후 동일.
  - jsonc 파서 제거. `require('nvim-treesitter').uninstall('jsonc')` 는
    "unsupported language" 로 거부당한다(신버전이 지원 목록에서 뺐다).
    `site/parser/jsonc.so` 와 `site/parser-info/jsonc.revision` 을 직접 지웠다.
  - mason 의 tree-sitter-cli 제거 후 checkhealth 가 mise 의 0.26.13 을 잡는다.
    mason 패키지 최신화(clangd 21.1.0 → 23.1.0).
  - headless 에서 mason/treesitter 명령을 쓰려면 `Lazy load <플러그인>` 을 먼저 해야 한다.
    `:MasonUninstall`, `:checkhealth nvim-treesitter` 모두 로드 전에는 없는 명령이다.
    mason 에는 `check_new_version` API 가 없다. `install()` 이 최신으로 재설치하는 방식이다.
  - 검증: LSP 5종 연결, jsonc→json 파서 하이라이트, t32 로드, zoxide DB 383 유지,
    lazygit TUI, WSL 클립보드(nvim → win32yank → Windows) 모두 정상.
