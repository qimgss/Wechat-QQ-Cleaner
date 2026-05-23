Write-Host "WechatQQ_Cleaner Build Script - AArch64" -ForegroundColor Cyan

$FilePath = ".\path.txt"

if (Test-Path $FilePath) {
    $Content = Get-Content $FilePath | ForEach-Object { $_.Trim() }

    if ($Content) {
        Write-Host "Found history enters ndk path: $ndkPath"
        $ndkPath = $Content
    }
    else {
        #path.exe is found but empty
        $ndkPath = Read-Host "Please enter ndk path"
        Set-Content -Path $FilePath -Value $ndkPath
    }
}
else {
    #First run this script
    $TargetPath = Read-Host "Please enter ndk path"
    Set-Content -Path $FilePath -Value $ndkPath
}

$linkerPattern = "$ndkPath\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android*-clang.cmd"

$linker = Get-ChildItem $linkerPattern | Select-Object -First 1

if ($linker) {
    Write-Host "✓ Found linker($linker.FullName)" -ForegroundColor Green
    Set-Location ..
    
    $env:CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = $linker.FullName
    Write-Host "Setted linker environment variable" -ForegroundColor Green
    
    Write-Host "`n开始构建..." -ForegroundColor Yellow
    cargo build --target aarch64-linux-android --release
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Build success！" -ForegroundColor Green
        Copy-Item -Path target\aarch64-linux-android\release\libwechatqqcleaner.so -Destination module\lib\arm64-v8a\libwechatqqcleaner.so
        Remove-Item -Path .\module\lib\arm64-v8a\placeholder
        Compress-Archive -Path ".\module\*" -DestinationPath ".\module.zip"
        New-Item -Path .\module\lib\arm64-v8a\placeholder -ItemType File
    } else {
        Write-Host "❌ Build failed" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Can't founded linker，Please reject NDK path" -ForegroundColor Red
}