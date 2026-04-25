Write-Host "=== 微信QQ清理模块构建脚本 (修正版) ===" -ForegroundColor Cyan

# 1. 设置 NDK 路径
$ndkPath = "C:\Android\NDK"
$linkerPattern = "$ndkPath\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android*-clang.cmd"

# 2. 查找链接器
$linker = Get-ChildItem $linkerPattern | Select-Object -First 1

if ($linker) {
    Write-Host "✓ 找到链接器: $($linker.FullName)" -ForegroundColor Green
    
    # 3. 设置环境变量 (Windows下建议使用 .cmd)
    $env:CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = $linker.FullName
    Write-Host "已设置链接器环境变量" -ForegroundColor Green
    
    # 4. 尝试构建
    Write-Host "`n开始构建..." -ForegroundColor Yellow
    cargo build --target aarch64-linux-android --release
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 构建成功！" -ForegroundColor Green
    } else {
        Write-Host "❌ 构建失败，请检查错误信息。" -ForegroundColor Red
    }
} else {
    Write-Host "❌ 未找到链接器，请检查 NDK 路径是否正确。" -ForegroundColor Red
}