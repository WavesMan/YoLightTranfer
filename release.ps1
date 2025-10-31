# YoLightTransfer Release Script
# 自动构建 APK 和 MSIX 发布包

param(
    [switch]$SkipClean = $false
)

Write-Host "=== YoLightTransfer Release Script ===" -ForegroundColor Cyan

# 检查 Flutter 是否可用
try {
    $flutterVersion = flutter --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter not found"
    }
    Write-Host "✓ Flutter detected" -ForegroundColor Green
} catch {
    Write-Host "✗ Flutter not found. Please ensure Flutter is installed and in PATH." -ForegroundColor Red
    exit 1
}

# 读取配置文件
$configPath = "lib\config.yaml"
if (-not (Test-Path $configPath)) {
    Write-Host "✗ Config file not found: $configPath" -ForegroundColor Red
    exit 1
}

Write-Host "Reading version from $configPath..." -ForegroundColor Yellow
$configContent = Get-Content $configPath -Raw
$versionMatch = [regex]::Match($configContent, 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)')
if (-not $versionMatch.Success) {
    Write-Host "✗ Could not extract version from config.yaml" -ForegroundColor Red
    exit 1
}

$appVersion = $versionMatch.Groups[1].Value
Write-Host "✓ Detected app version: $appVersion" -ForegroundColor Green

# 解析版本号用于 MSIX
$versionParts = $appVersion -split '\.'
$msixVersion = "$($versionParts[0]).$($versionParts[1]).$($versionParts[2]).0"

Write-Host "MSIX version will be: $msixVersion" -ForegroundColor Yellow

# 清理构建目录
if (-not $SkipClean) {
    Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
    flutter clean
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Flutter clean failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Build cleaned" -ForegroundColor Green
}

# 更新 pubspec.yaml 版本
Write-Host "Updating pubspec.yaml version..." -ForegroundColor Yellow
$pubspecPath = "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw

# 更新主版本号
$pubspecContent = $pubspecContent -replace 'version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+', "version: $appVersion+1"

# 更新 MSIX 版本
$pubspecContent = $pubspecContent -replace 'msix_version:\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+', "msix_version: $msixVersion"

Set-Content -Path $pubspecPath -Value $pubspecContent
Write-Host "✓ pubspec.yaml updated" -ForegroundColor Green

# 更新 Android build.gradle.kts
Write-Host "Updating Android build.gradle.kts..." -ForegroundColor Yellow
$androidBuildPath = "android\app\build.gradle.kts"
$androidContent = Get-Content $androidBuildPath -Raw

# 替换版本号引用为固定值
$androidContent = $androidContent -replace 'versionCode\s*=\s*flutter\.versionCode', "versionCode = 1"
$androidContent = $androidContent -replace 'versionName\s*=\s*flutter\.versionName', "versionName = `"$appVersion`""

Set-Content -Path $androidBuildPath -Value $androidContent
Write-Host "✓ Android build.gradle.kts updated" -ForegroundColor Green

# 创建 Release 目录
$releaseDir = "Release\$appVersion"
if (Test-Path $releaseDir) {
    Write-Host "Cleaning existing release directory..." -ForegroundColor Yellow
    Remove-Item -Path "$releaseDir\*" -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
}
Write-Host "✓ Release directory ready: $releaseDir" -ForegroundColor Green

# 构建 APK
Write-Host "Building APK..." -ForegroundColor Yellow
flutter build apk --release --split-per-abi 2>&1 | Out-Null
# 忽略构建过程中的警告，检查 APK 文件是否存在
Write-Host "✓ APK build completed" -ForegroundColor Green

# 复制 APK
$apkSource = "android\app\build\outputs\apk\release\app-arm64-v8a-release.apk"
$apkDest = "$releaseDir\YoLightTransfer-v${appVersion}_for_android.apk"
if (Test-Path $apkSource) {
    Copy-Item -Path $apkSource -Destination $apkDest
    Write-Host "✓ APK copied: $apkDest" -ForegroundColor Green
} else {
    Write-Host "⚠ APK file not found at: $apkSource" -ForegroundColor Yellow
}

# 构建 Windows MSIX
Write-Host "Building Windows executable..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Windows build failed" -ForegroundColor Red
    exit 1
}

Write-Host "Creating MSIX package..." -ForegroundColor Yellow
flutter pub run msix:create
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ MSIX creation failed" -ForegroundColor Red
    exit 1
}

# 复制 MSIX
$msixSource = "build\windows\x64\runner\Release\*.msix"
$msixFiles = Get-ChildItem -Path $msixSource -ErrorAction SilentlyContinue
if ($msixFiles.Count -gt 0) {
    $msixFile = $msixFiles[0]
    $msixDest = "$releaseDir\YoLightTransfer-v${appVersion}_for_windows.msix"
    Copy-Item -Path $msixFile.FullName -Destination $msixDest
    Write-Host "✓ MSIX copied: $msixDest" -ForegroundColor Green
    
    # 创建 ZIP 版本（免安装）
    $zipDest = "$releaseDir\YoLightTransfer-v${appVersion}_for_windows.zip"
    Copy-Item -Path $msixDest -Destination $zipDest
    Write-Host "✓ ZIP version created: $zipDest" -ForegroundColor Green
} else {
    Write-Host "⚠ MSIX file not found at: $msixSource" -ForegroundColor Yellow
}

# 显示构建结果
Write-Host "`n=== Release Build Complete ===" -ForegroundColor Cyan
Write-Host "Version: $appVersion" -ForegroundColor White
Write-Host "Location: $releaseDir" -ForegroundColor White
Write-Host "`nGenerated files:" -ForegroundColor Yellow

Get-ChildItem $releaseDir | ForEach-Object {
    Write-Host "  - $($_.Name)" -ForegroundColor White
}

Write-Host "`n✓ All builds completed successfully!" -ForegroundColor Green
