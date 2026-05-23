#!/system/bin/sh
# Post-fs-data script
MODDIR=${0%/*}

# 创建必要的目录
mkdir -p "/data/local/tmp"

# 设置权限
chmod 755 "$MODDIR/service.sh"
chmod 755 "$MODDIR/bin/cleaner"
chmod 755 "$MODDIR/lib/libwechatqqcleaner.so"

# 启动服务
nohup "$MODDIR/service.sh" >/dev/null 2>&1 &

# 记录启动时间
echo "[$(date '+%Y-%m-%d %H:%M:%S')] WeChat/QQ Cleaner started" > "/data/local/tmp/cleaner_start.log"
