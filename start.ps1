# 鳴潮排軸工具 - 一鍵啟動腳本
# 用法：在這個資料夾按右鍵 -> 使用 PowerShell 執行，或直接雙擊 start.bat

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "找不到 Node.js，正在透過 winget 自動安裝 Node.js LTS，請稍候..." -ForegroundColor Cyan
        Start-Process -FilePath "winget" -ArgumentList "install", "--id", "OpenJS.NodeJS.LTS", "-e", "--source", "winget", "--accept-package-agreements", "--accept-source-agreements" -Wait -NoNewWindow

        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
            Write-Host "自動安裝完成，但目前視窗尚未偵測到 Node.js。請關閉這個視窗，重新雙擊 start.bat 再試一次（安裝後通常需要重開一次才會生效）。" -ForegroundColor Yellow
            Read-Host "按 Enter 結束"
            exit 1
        }
        Write-Host "Node.js 安裝成功！" -ForegroundColor Green
    } else {
        Write-Host "找不到 Node.js，且此電腦沒有 winget 可自動安裝，請先到 https://nodejs.org/ 安裝後再執行此腳本。" -ForegroundColor Red
        Read-Host "按 Enter 結束"
        exit 1
    }
}

$lockHashFile = "node_modules\.lock-hash"
$currentLockHash = (Get-FileHash -Path "package-lock.json" -Algorithm SHA256).Hash
$needsInstall = $true

if ((Test-Path "node_modules") -and (Test-Path $lockHashFile)) {
    $savedLockHash = Get-Content -Path $lockHashFile -Raw
    if ($savedLockHash.Trim() -eq $currentLockHash) {
        $needsInstall = $false
    }
}

if ($needsInstall) {
    Write-Host "偵測到需要安裝/更新套件，正在處理，請稍候..." -ForegroundColor Cyan
    & npm.cmd install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "套件安裝失敗，請檢查網路連線後再試一次。" -ForegroundColor Red
        Read-Host "按 Enter 結束"
        exit 1
    }
    Set-Content -Path $lockHashFile -Value $currentLockHash -NoNewline
}

$port = 5173
$url = "http://localhost:$port"

Write-Host "正在啟動本地伺服器..." -ForegroundColor Cyan
$devProcess = Start-Process -FilePath "npm.cmd" -ArgumentList "run", "dev" -PassThru -NoNewWindow:$false

$ready = $false
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 500
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 1
        if ($resp.StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch {}
}

if ($ready) {
    Write-Host "伺服器已啟動，正在開啟瀏覽器：$url" -ForegroundColor Green
} else {
    Write-Host "伺服器可能還在啟動中，仍會嘗試開啟瀏覽器，若空白請手動重新整理。" -ForegroundColor Yellow
}

Start-Process $url

Write-Host ""
Write-Host "提示：關閉這個視窗或按 Ctrl+C 即可停止伺服器。" -ForegroundColor DarkGray
Wait-Process -Id $devProcess.Id
