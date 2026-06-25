# 鳴潮排軸工具 - 一鍵啟動腳本
# 用法：在這個資料夾按右鍵 -> 使用 PowerShell 執行，或直接雙擊 start.bat

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "找不到 Node.js，請先到 https://nodejs.org/ 安裝後再執行此腳本。" -ForegroundColor Red
    Read-Host "按 Enter 結束"
    exit 1
}

if (-not (Test-Path "node_modules")) {
    Write-Host "偵測到第一次執行，正在安裝套件，請稍候（只有第一次需要等待）..." -ForegroundColor Cyan
    & npm.cmd install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "套件安裝失敗，請檢查網路連線後再試一次。" -ForegroundColor Red
        Read-Host "按 Enter 結束"
        exit 1
    }
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
