# Claude Notifier Windows 安装脚本
# 用法: .\install.ps1

$ErrorActionPreference = "Stop"

$InstallDir = "$env:USERPROFILE\.claude\apps"
$SoundsDir = "$env:USERPROFILE\.claude\sounds"
$ExeName = "claude-notifier.exe"

Write-Host "[INFO] Installing Claude Notifier for Windows..." -ForegroundColor Green

# 创建目录
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
if (-not (Test-Path $SoundsDir)) {
    New-Item -ItemType Directory -Path $SoundsDir -Force | Out-Null
}

# 查找 exe
$ExePath = $null
$SearchPaths = @(
    ".\target\release\$ExeName",
    ".\$ExeName",
    "..\target\release\$ExeName"
)

foreach ($path in $SearchPaths) {
    if (Test-Path $path) {
        $ExePath = $path
        break
    }
}

if (-not $ExePath) {
    Write-Host "[ERROR] $ExeName not found. Please build the project first:" -ForegroundColor Red
    Write-Host "  cargo build --release" -ForegroundColor Yellow
    exit 1
}

# 复制文件
Write-Host "[INFO] Copying $ExeName to $InstallDir..." -ForegroundColor Cyan
Copy-Item $ExePath "$InstallDir\$ExeName" -Force

# 注册 AUMID
Write-Host "[INFO] Registering AUMID..." -ForegroundColor Cyan
& "$InstallDir\$ExeName" --init

# 生成默认语音（可选）
$DefaultSound = "$SoundsDir\done.wav"
if (-not (Test-Path $DefaultSound)) {
    Write-Host "[INFO] Generating default notification sound..." -ForegroundColor Cyan
    try {
        Add-Type -AssemblyName System.Speech
        $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
        $synth.SetOutputToWaveFile($DefaultSound)
        $synth.Speak("搞定咯")
        $synth.Dispose()
        Write-Host "[INFO] Default sound created: $DefaultSound" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] Could not generate default sound: $_" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[SUCCESS] Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Test with:" -ForegroundColor Cyan
Write-Host "  & `"$InstallDir\$ExeName`" -t `"Test`" -m `"It works!`"" -ForegroundColor Yellow
Write-Host ""
Write-Host "Add to Claude Code hooks in %USERPROFILE%\.claude\settings.json" -ForegroundColor Cyan
