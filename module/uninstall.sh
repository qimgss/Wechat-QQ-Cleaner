#!/system/bin/sh
# 卸载脚本
LOG_FILE="/data/local/tmp/wechat_qq_cleaner.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UNINSTALL] $1" >> "$LOG_FILE"
}

log "Module uninstalled"
