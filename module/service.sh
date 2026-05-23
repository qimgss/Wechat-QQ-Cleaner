#!/system/bin/sh
# WeChat/QQ Cache Cleaner Service
MODDIR=${0%/*}
LOG_FILE="/data/local/tmp/wechat_qq_cleaner.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

case "$(uname -m)" in
    x86_64 | amd64)
        Arch="x86_64"
        ;;
    aarch64 | arm64)
        Arch="arm64-v8a"
        ;;
    armv7l | armv7)
        Arch="armeabi-v7a"
        ;;
    i386 | i686)
        Arch="x86"
        ;;
    *)
        echo "Architecture: Unknown ($ARCH)"
        ;;
esac

# 初始化
mkdir -p "/data/local/tmp"
chmod 755 "$MODDIR/bin/cleaner"
chmod 755 "$MODDIR/lib/$Arch/libwechatqqcleaner.so"

log "Service started"

# 主循环
while true; do
    # 等待12小时 (43200秒)
    sleep 43200
    
    # 检查设备状态（如果支持）
    if [ -f /sys/class/power_supply/battery/status ]; then
        POWER_STATUS=$(cat /sys/class/power_supply/battery/status 2>/dev/null)
        BATTERY_LEVEL=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo 100)
        
        # 只在充电或电量充足时清理
        if [ "$POWER_STATUS" = "Charging" ] || [ "$POWER_STATUS" = "Full" ] || [ "$BATTERY_LEVEL" -gt 20 ]; then
            log "Device ready, starting cleanup..."
            "$MODDIR/bin/cleaner"
        else
            log "Skipping cleanup (low battery: $BATTERY_LEVEL%)"
        fi
    else
        # 无法获取电池状态，直接清理
        log "Starting cleanup..."
        "$MODDIR/bin/cleaner"
    fi
done
