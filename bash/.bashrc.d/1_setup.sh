# 사용자용 실행파일 PATH 추가
export PATH="$PATH:$HOME/.local/bin"

# npm 패키지 매니저로 깐 모듈들 PATH 잡기
export PATH="$PATH:$HOME/.nvm/versions/node/v22.20.0/lib/node_modules/@mermaid-js/mermaid-cli/node_modules/.bin"

# zoxide 사용을 위한 eval(cd에 대한 zoxide alias는 setup.sh에서 자체적으로 적용중임)
eval "$(zoxide init bash)"


# kenGwon alias
alias vim='nvim'
alias vi='nvim'

alias ls='eza --color=always'
alias ll='eza --color=always --long --bytes --all' 
# alias ls='ls -Cv --color=auto'
# alias ll='ls -alFv --color=auto'
# alias lh='ls -alFvh --color=auto'
# alias la='ls -A --color=auto'
# alias l='ls -CFv --color=auto'
#
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias gr='grep -r -n -i'


alias python='python3'
alias cat='bat'

alias bmake='bear --append -- make'
alias bmakef='bear -- make'          # f = fresh

# 192.168.0.166 옵시디언 볼트 마운트 (IP가 192.168.0.99일 때만)
TARGET_IP="192.168.0.99"
REMOTE="kenGwon-ObsidianVault:Obsidian_Vault"
MOUNT_DIR="$HOME/remote-obsidian-vault"

if ! ip -4 -o addr show | awk '{print $4}' | cut -d/ -f1 | grep -Fxq "$TARGET_IP"; then
    echo "[obsidian] 현재 IP가 $TARGET_IP 가 아니므로 마운트하지 않습니다."
elif mountpoint -q "$MOUNT_DIR"; then
    if ls "$MOUNT_DIR" >/dev/null 2>&1; then
        echo "[obsidian] 이미 마운트되어 있습니다: $MOUNT_DIR"
    else
        echo "[obsidian] 끊어진 마운트 감지, 해제 후 다시 마운트합니다."
        fusermount -uz "$MOUNT_DIR"
        rclone mount "$REMOTE" "$MOUNT_DIR" --daemon --vfs-cache-mode full
    fi
else
    mkdir -p "$MOUNT_DIR"
    rclone mount "$REMOTE" "$MOUNT_DIR" --daemon --vfs-cache-mode full \
        && echo "[obsidian] 마운트 완료: $MOUNT_DIR"
fi

