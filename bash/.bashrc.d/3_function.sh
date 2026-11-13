winpath() {
  if [ -z "$1" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: winpath <file>"
    echo "Convert Linux path to Windows style path with network share substitution."
    return 0
  fi

  local abs_path transformed_target_path

  # 절대 경로 획득
  abs_path=$(realpath "$1" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "Error: 파일 경로를 찾을 수 없습니다."
    return 1
  fi

  transformed_target_path=$(echo "$abs_path" | sed 's/\//\\/g')

  # 런타임 환경 감지
  if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
    # === WSL 환경 ===
    # WSL distro 이름 동적 획득 (없으면 fallback)
    local distro_name
    distro_name=$(wslvar WSL_DISTRO_NAME 2>/dev/null || echo "$WSL_DISTRO_NAME")
    [ -z "$distro_name" ] && distro_name="Ubuntu-24.04"

    transformed_target_path="\\\\wsl.localhost\\${distro_name}${transformed_target_path}"
  else
    # === 원격 리눅스 서버 환경 ===
    local build_server_ip transformed_user_path
    build_server_ip=$(ip addr show \
      | grep "inet " \
      | grep -v 127.0.0.1 \
      | awk '{print $2}' \
      | cut -d/ -f1 \
      | head -n1)

    transformed_user_path=$(echo "$HOME" | sed 's/\//\\/g')

    if [[ "$transformed_target_path" == "$transformed_user_path"* ]]; then
      transformed_target_path="\\\\${build_server_ip}\\${USER}${transformed_target_path#"$transformed_user_path"}"
    fi
  fi

  echo "$transformed_target_path"
}

evk_echo_nfs_mount() {
	echo "mount -t nfs -o nolock 192.168.0.99:/disk/vol3/ghgwon /nfs"
	echo

	/usr/bin/cat << 'EOF'
ping 192.168.0.99 -c 1 > /dev/null 
if [ $? -eq 0 ] ; then 
  mount -t nfs -o nolock 192.168.0.99:/disk/vol3/ghgwon /nfs 
  if [ $? -eq 0 ] ; then 
    df | grep nfs 
    echo "0.100 WSL ghgwon NFS mount success!!!" 
  fi 
fi
EOF
}


# ── 192.168.0.166 옵시디언 볼트 (rclone SMB) 수동 마운트 ──────────────────────
# 셸 시작 시 자동 마운트하지 않는다. 원격지가 망에서 사라지면 마운트가 응답 없는
# 파일시스템이 되어 df/셸 시작이 멈추기 때문. 필요할 때만 직접 붙이고 뗀다.
#   obsidian_mount [시간]  원격지 살아있을 때만 마운트. 지정 시간(기본 3h, sleep 형식:
#                          90m, 2h 등) 뒤 자동 해제 예약: 정상 해제 실패 시 강제 해제
#   obsidian_umount        정상 해제
#   obsidian_umount_force  원격지가 사라져 멈춘 마운트를 강제로 끊음
# 마운트 여부는 /proc/mounts로만 판단한다 (마운트 디렉터리를 건드리면 멈출 수 있음).
OBSIDIAN_HOST="192.168.0.166"
OBSIDIAN_REMOTE="kenGwon-ObsidianVault:Obsidian_Vault"
OBSIDIAN_MOUNT_DIR="$HOME/remote-obsidian-vault"
OBSIDIAN_AUTO_UMOUNT_LOG="$HOME/.cache/obsidian-auto-umount.log"
_OBSIDIAN_FUNC_FILE="$(realpath "${BASH_SOURCE[0]}")"

_obsidian_is_mounted() {
  awk -v d="$OBSIDIAN_MOUNT_DIR" '$2 == d { found = 1 } END { exit !found }' /proc/mounts
}

obsidian_mount() {
  local delay="${1:-3h}"
  if [[ ! "$delay" =~ ^[0-9]+(\.[0-9]+)?[smhd]?$ ]]; then
    echo "[obsidian] 잘못된 시간 형식: $delay (예: 90m, 2h)"
    return 1
  fi
  if _obsidian_is_mounted; then
    echo "[obsidian] 이미 마운트되어 있음: $OBSIDIAN_MOUNT_DIR"
    return 0
  fi
  if ! timeout 1 bash -c "</dev/tcp/$OBSIDIAN_HOST/445" 2>/dev/null; then
    echo "[obsidian] 원격지 응답 없음 ($OBSIDIAN_HOST:445), 마운트하지 않음"
    return 1
  fi
  mkdir -p "$OBSIDIAN_MOUNT_DIR"
  if ! rclone mount "$OBSIDIAN_REMOTE" "$OBSIDIAN_MOUNT_DIR" --daemon \
      --vfs-cache-mode full --contimeout 5s --timeout 15s; then
    echo "[obsidian] 마운트 실패: $OBSIDIAN_MOUNT_DIR"
    return 1
  fi
  echo "[obsidian] 마운트 성공: $OBSIDIAN_MOUNT_DIR"

  # 자동 해제 예약. 이전 예약이 남아 있으면 취소 (재마운트 직후 옛 예약이 끊지 않도록)
  pkill -f '^bash -c .* obsidian-auto-umount ' 2>/dev/null
  mkdir -p "$(dirname "$OBSIDIAN_AUTO_UMOUNT_LOG")"
  # setsid: 셸/ssh 세션이 끝나도 살아남도록 새 세션에서 실행
  setsid bash -c '
    source "$1"
    sleep "$2"
    echo "[$(date "+%F %T")] 자동 해제 시도"
    obsidian_umount || obsidian_umount_force
  ' obsidian-auto-umount "$_OBSIDIAN_FUNC_FILE" "$delay" \
    </dev/null >>"$OBSIDIAN_AUTO_UMOUNT_LOG" 2>&1 &
  disown
  echo "[obsidian] $delay 뒤 자동 해제 예약 (로그: $OBSIDIAN_AUTO_UMOUNT_LOG)"
}

obsidian_umount() {
  if ! _obsidian_is_mounted; then
    echo "[obsidian] 마운트되어 있지 않음"
    return 0
  fi
  if timeout 5 fusermount -u "$OBSIDIAN_MOUNT_DIR"; then
    echo "[obsidian] 해제 완료"
  else
    echo "[obsidian] 정상 해제 실패. 멈춘 상태라면 obsidian_umount_force 를 사용"
    return 1
  fi
}

obsidian_umount_force() {
  # lazy unmount: 응답 없는 파일시스템도 즉시 마운트 트리에서 떼어냄 (df 등 즉시 복구)
  if _obsidian_is_mounted; then
    fusermount -uz "$OBSIDIAN_MOUNT_DIR" && echo "[obsidian] 마운트 강제 해제"
  fi
  # 남아있는 rclone 데몬 정리 (TERM 후 2초 내 안 죽으면 KILL)
  if pkill -f -- "rclone mount $OBSIDIAN_REMOTE"; then
    sleep 2
    pkill -KILL -f -- "rclone mount $OBSIDIAN_REMOTE"
    echo "[obsidian] rclone 프로세스 종료"
  fi
  # 미업로드 쓰기는 ~/.cache/rclone/vfs 에 남아 다음 마운트 때 업로드됨
}
