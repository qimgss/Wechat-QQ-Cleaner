# create-module.ps1
Write-Host "=== 创建Magisk模块 ===" -ForegroundColor Cyan

# 检查库文件
$soFile = "target\aarch64-linux-android\release\libwechatqqcleaner.so"
if (-not (Test-Path $soFile)) {
    Write-Host "❌ 未找到库文件: $soFile" -ForegroundColor Red
    Write-Host "请先运行: .\build-s.ps1" -ForegroundColor Yellow
    exit 1
}

$fileSize = (Get-Item $soFile).Length
Write-Host "✓ 找到库文件: $soFile ($([math]::Round($fileSize/1024, 2)) KB)" -ForegroundColor Green

# 创建模块目录
$moduleDir = "wechat-qq-cleaner-module"
if (Test-Path $moduleDir) {
    Remove-Item -Recurse -Force $moduleDir
}

Write-Host "`n创建模块结构..." -ForegroundColor Yellow
$dirs = @(
    "$moduleDir\META-INF\com\google\android",
    "$moduleDir\common",
    "$moduleDir\bin",
    "$moduleDir\lib"
)

foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# 复制库文件
Copy-Item $soFile "$moduleDir\lib\libwechatqqcleaner.so" -Force
Write-Host "✓ 复制库文件到模块" -ForegroundColor Green

Copy-Item .\resources.html "$moduleDir\resources.html" -Force
Write-Host "✓ 复制源代码链接到模块" -ForegroundColor Green

# 创建启动脚本
$serviceSh = @'
#!/system/bin/sh
# WeChat/QQ Cache Cleaner Service
MODDIR=${0%/*}
LOG_FILE="/data/local/tmp/wechat_qq_cleaner.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 初始化
mkdir -p "/data/local/tmp"
chmod 755 "$MODDIR/bin/cleaner"
chmod 755 "$MODDIR/lib/libwechatqqcleaner.so"

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
'@

Set-Content -Path "$moduleDir\service.sh" -Value $serviceSh -Encoding UTF8
Write-Host "✓ 创建 service.sh" -ForegroundColor Green

# 创建清理脚本
$cleanerSh = @'
#!/system/bin/sh
# Cleaner script wrapper
MODDIR=${0%/*}
LIB_PATH="$MODDIR/lib/libwechatqqcleaner.so"
LOG_FILE="/data/local/tmp/wechat_qq_cleaner.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== Cleanup started ==="

# 尝试使用Rust库
if [ -f "$LIB_PATH" ]; then
    log "Using Rust library for cleanup"
    # 设置库路径并调用
    LD_LIBRARY_PATH="$MODDIR/lib" "$LIB_PATH" clean_all_cache
    RUST_RESULT=$?
    
    if [ $RUST_RESULT -eq 0 ]; then
        log "Rust cleanup successful"
    else
        log "Rust cleanup failed with code: $RUST_RESULT"
        # 回退到shell脚本清理
        log "Falling back to shell script cleanup"
        clean_with_shell
    fi
else
    log "Rust library not found, using shell script"
    clean_with_shell
fi

log "=== Cleanup completed ==="

# Shell脚本清理函数
clean_with_shell() {
    log "Shell: Cleaning WeChat cache..."
    # 微信缓存路径
    wechat_paths=(
        "/data/data/com.tencent.mm/cache"
        "/data/data/com.tencent.mm/files"
        "/sdcard/Android/data/com.tencent.mm/cache"
        "/sdcard/Android/data/com.tencent.mm/files"
        "/sdcard/tencent/MicroMsg"
    )
    
    for path in "${wechat_paths[@]}"; do
        if [ -d "$path" ]; then
            # 删除超过12小时的文件
            find "$path" -type f -mmin +720 -delete 2>/dev/null
            log "Shell: Cleaned WeChat path: $path"
        fi
    done
    
    log "Shell: Cleaning QQ cache..."
    # QQ缓存路径
    qq_paths=(
        "/data/data/com.tencent.mobileqq/cache"
        "/data/data/com.tencent.mobileqq/files"
        "/sdcard/Android/data/com.tencent.mobileqq/cache"
        "/sdcard/Android/data/com.tencent.mobileqq/files"
        "/sdcard/tencent/QQ"
    )
    
    for path in "${qq_paths[@]}"; do
        if [ -d "$path" ]; then
            # 删除超过12小时的文件
            find "$path" -type f -mmin +720 -delete 2>/dev/null
            log "Shell: Cleaned QQ path: $path"
        fi
    done
}

exit 0
'@

Set-Content -Path "$moduleDir\bin\cleaner" -Value $cleanerSh -Encoding UTF8
Write-Host "✓ 创建 cleaner 脚本" -ForegroundColor Green

# 创建post-fs-data.sh
$postFsData = @'
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
'@

Set-Content -Path "$moduleDir\common\post-fs-data.sh" -Value $postFsData -Encoding UTF8
Write-Host "✓ 创建 post-fs-data.sh" -ForegroundColor Green

# 创建update-binary
$updateBinary = @'
#!/sbin/sh
# Magisk模块安装脚本

SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=true
LATESTARTSERVICE=true

print_modname() {
    ui_print "*******************************"
    ui_print "   WeChat/QQ Cache Cleaner    "
    ui_print "*******************************"
}

on_install() {
    ui_print "- 正在解压文件"
    unzip -o "$ZIPFILE" 'system/*' -d $MODPATH >&2
    
    # 复制文件
    ui_print "- 正在安装模块"
    cp -af $MODPATH/system/* $MODPATH
    rm -rf $MODPATH/system
    
    # 设置权限
    set_perm_recursive $MODPATH 0 0 0755 0644
    set_perm_recursive $MODPATH/bin 0 0 0755 0755
    set_perm_recursive $MODPATH/lib 0 0 0755 0644
    set_perm $MODPATH/service.sh 0 0 0755
    
    ui_print "- 安装完成"
}

set_permissions() {
    set_perm_recursive $MODPATH 0 0 0755 0644
    set_perm_recursive $MODPATH/bin 0 0 0755 0755
    set_perm_recursive $MODPATH/lib 0 0 0755 0644
    set_perm $MODPATH/service.sh 0 0 0755
    set_perm $MODPATH/bin/cleaner 0 0 0755
}
'@

Set-Content -Path "$moduleDir\META-INF\com\google\android\update-binary" -Value $updateBinary -Encoding UTF8
Write-Host "✓ 创建 update-binary" -ForegroundColor Green

# 创建updater-script
$updaterScript = @'
#MAGISK
'@

Set-Content -Path "$moduleDir\META-INF\com\google\android\updater-script" -Value $updaterScript -Encoding UTF8
Write-Host "✓ 创建 updater-script" -ForegroundColor Green

# 创建module.prop
$moduleProp = @'
id=wechat_qq_cache_cleaner
name=WeChat/QQ Cache Cleaner
version=v1.0.0
versionCode=1
author=Qimgss
description=每12小时自动清理微信和QQ缓存。使用Rust库进行高效清理。
updateJson=
'@

Set-Content -Path "$moduleDir\module.prop" -Value $moduleProp -Encoding UTF8
Write-Host "✓ 创建 module.prop" -ForegroundColor Green

# 创建system.prop
$systemProp = @'
# WeChat/QQ Cache Cleaner Module
# 每12小时自动清理微信和QQ缓存
'@

Set-Content -Path "$moduleDir\system.prop" -Value $systemProp -Encoding UTF8
Write-Host "✓ 创建 system.prop" -ForegroundColor Green

# 创建uninstall.sh
$uninstallSh = @'
#!/system/bin/sh
# 卸载脚本
LOG_FILE="/data/local/tmp/wechat_qq_cleaner.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UNINSTALL] $1" >> "$LOG_FILE"
}

log "Module uninstalled"
'@

Set-Content -Path "$moduleDir\uninstall.sh" -Value $uninstallSh -Encoding UTF8
Write-Host "✓ 创建 uninstall.sh" -ForegroundColor Green

# 打包模块
Write-Host "`n打包模块..." -ForegroundColor Cyan
$zipFile = "wechat-qq-cleaner-module.zip"
if (Test-Path $zipFile) {
    Remove-Item $zipFile -Force
}

try {
    Compress-Archive -Path "$moduleDir\*" -DestinationPath $zipFile -Force
    $zipSize = (Get-Item $zipFile).Length
    Write-Host "✅ 模块打包完成: $zipFile ($([math]::Round($zipSize/1024, 2)) KB)" -ForegroundColor Green
} catch {
    Write-Host "⚠️ 使用PowerShell压缩失败，尝试使用7zip..." -ForegroundColor Yellow
    try {
        7z a -tzip $zipFile "$moduleDir\*" | Out-Null
        $zipSize = (Get-Item $zipFile).Length
        Write-Host "✅ 使用7zip打包完成: $zipFile ($([math]::Round($zipSize/1024, 2)) KB)" -ForegroundColor Green
    } catch {
        Write-Host "❌ 打包失败，手动打包目录: $moduleDir" -ForegroundColor Red
    }
}