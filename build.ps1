Write-Host "WechatQQ_Cleaner Build Script" -ForegroundColor Cyan

$ndkPath = "C:\Android\NDK"
$linkerPattern = "$ndkPath\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android*-clang.cmd"

$linker = Get-ChildItem $linkerPattern | Select-Object -First 1

if ($linker) {
    Write-Host "✓ Found linker($linker.FullName)" -ForegroundColor Green
    
    $env:CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = $linker.FullName
    Write-Host "Setted linker environment variable" -ForegroundColor Green
    
    Write-Host "`n开始构建..." -ForegroundColor Yellow
    cargo build --target aarch64-linux-android --release
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Build success！" -ForegroundColor Green
    } else {
        Write-Host "❌ Build failed" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Can't founded linker，Please reject NDK path" -ForegroundColor Red
}