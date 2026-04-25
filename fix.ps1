# fix-build-for-ndk-home.ps1
Write-Host "=== 修复构建脚本以使用 NDK_HOME ===" -ForegroundColor Cyan

# 1. 检查当前环境变量
Write-Host "`n1. 检查环境变量:" -ForegroundColor Yellow
Write-Host "NDK_HOME: $($env:NDK_HOME)" -ForegroundColor White
Write-Host "ANDROID_NDK_HOME: $($env:ANDROID_NDK_HOME)" -ForegroundColor White

# 2. 验证NDK路径
if ([string]::IsNullOrEmpty($env:NDK_HOME)) {
    Write-Host "`n错误: NDK_HOME 未设置" -ForegroundColor Red
    Write-Host "`n请运行以下命令设置:" -ForegroundColor Yellow
    Write-Host "[Environment]::SetEnvironmentVariable('NDK_HOME', 'C:\你的\NDK\路径', 'User')" -ForegroundColor White
    Write-Host "然后重启PowerShell" -ForegroundColor White
    exit 1
}

$ndkPath = $env:NDK_HOME
if (-not (Test-Path $ndkPath)) {
    Write-Host "`n错误: NDK_HOME 路径不存在" -ForegroundColor Red
    Write-Host "当前路径: $ndkPath" -ForegroundColor White
    exit 1
}

Write-Host "`n2. 验证NDK结构:" -ForegroundColor Green
if (Test-Path "$ndkPath\toolchains") {
    Write-Host "✓ 找到 toolchains 目录" -ForegroundColor Green
} else {
    Write-Host "✗ 未找到 toolchains 目录" -ForegroundColor Red
}

# 3. 查找链接器
Write-Host "`n3. 查找链接器:" -ForegroundColor Yellow
$linkers = Get-ChildItem -Path $ndkPath -Recurse -Filter "*aarch64-linux-android*clang*" -ErrorAction SilentlyContinue

if ($linkers.Count -eq 0) {
    Write-Host "✗ 未找到链接器" -ForegroundColor Red
    
    # 显示目录结构帮助诊断
    Write-Host "`nNDK目录结构:" -ForegroundColor Cyan
    Get-ChildItem $ndkPath | Select-Object Name, Mode | Format-Table
    
    # 检查是否是有效的NDK
    $possiblePaths = @(
        "$ndkPath\toolchains\llvm\prebuilt",
        "$ndkPath\prebuilt\windows-x86_64",
        "$ndkPath\llvm\prebuilt"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            Write-Host "找到路径: $path" -ForegroundColor Yellow
            Get-ChildItem $path | Select-Object Name | Format-Table
        }
    }
    
    exit 1
}

foreach ($linker in $linkers) {
    Write-Host "✓ 找到链接器: $($linker.FullName)" -ForegroundColor Green
}

# 4. 测试构建
Write-Host "`n4. 测试构建环境..." -ForegroundColor Yellow

# 创建测试项目
$testDir = "test-ndk-home"
if (Test-Path $testDir) { Remove-Item -Recurse -Force $testDir }
New-Item -ItemType Directory -Path $testDir
Set-Location $testDir

cargo init --lib test-lib

# 修改Cargo.toml
@'
[package]
name = "test-lib"
version = "0.1.0"
edition = "2021"

[lib]
name = "testlib"
crate-type = ["cdylib"]
'@ | Set-Content Cargo.toml

# 创建简单的lib.rs
@'
#[no_mangle]
pub extern "C" fn add(a: i32, b: i32) -> i32 {
    a + b
}
'@ | Set-Content src/lib.rs

# 设置链接器
$linkerPath = $linkers[0].FullName
$env:CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = $linkerPath
Write-Host "设置链接器: $linkerPath" -ForegroundColor Green

# 尝试构建
Write-Host "`n尝试构建..." -ForegroundColor Cyan
cargo build --target aarch64-linux-android --release

if (Test-Path "target/aarch64-linux-android/release/libtestlib.so") {
    Write-Host "`n✓ 构建成功！" -ForegroundColor Green
    $libSize = (Get-Item "target/aarch64-linux-android/release/libtestlib.so").Length
    Write-Host "库文件大小: $([math]::Round($libSize/1024, 2)) KB" -ForegroundColor White
} else {
    Write-Host "`n✗ 构建失败" -ForegroundColor Red
}

# 清理
Set-Location ..
Remove-Item -Recurse -Force $testDir

Write-Host "`n修复完成！" -ForegroundColor Green
Write-Host "现在可以运行: .\build.ps1" -ForegroundColor Yellow