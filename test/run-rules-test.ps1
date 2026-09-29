# Chạy kiểm thử Security Rules trên Firestore Emulator.
#
# CÁCH DÙNG:  powershell -ExecutionPolicy Bypass -File test\run-rules-test.ps1
#
# VÌ SAO CẦN FILE NÀY: Firestore Emulator chạy trên Java, mà firebase-tools
# 15.x từ chối Java < 21. Máy này cài sẵn Java 17 nên phải trỏ JAVA_HOME sang
# JDK 21 trước khi chạy.
#
# KHÔNG cần script này trên Linux / GitHub Actions: CI gọi thẳng
# `npm run test:rules:emulator` sau khi đã setup-java 21.
#
# Trước đây script còn tạo junction `C:\dhh-emu` vì Firestore Emulator (Java)
# không đọc được đường dẫn có dấu tiếng Việt. Repo này nằm ở `C:\code\dhhshop`
# nên không còn vấn đề đó và đã bỏ junction đi.

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$jdk  = "$env:LOCALAPPDATA\Temp\opencode\jdk21b\ext\jdk-21.0.12.1+1"

# --- 1. JDK 21 --------------------------------------------------------------
$javaExe = Join-Path $jdk 'bin\java.exe'
if (-not (Test-Path $javaExe)) {
  Write-Host "!! Khong tim thay JDK 21 o: $jdk" -ForegroundColor Yellow
  Write-Host "   Dat JDK 21 vao do, hoac doi bien `$jdk trong file nay." -ForegroundColor Yellow
  exit 1
}
$env:JAVA_HOME = $jdk
$env:PATH = "$jdk\bin;$env:PATH"
Write-Host "JDK 21: $jdk" -ForegroundColor DarkGray

# --- 2. npm.cmd, khong phai npm.ps1 ----------------------------------------
# PowerShell execution policy chặn npm.ps1, nên phải gọi npm.cmd.
$npm = (Get-Command npm.cmd -ErrorAction SilentlyContinue).Source
if (-not $npm) { $npm = 'C:\Program Files\nodejs\npm.cmd' }
Write-Host "npm: $npm" -ForegroundColor DarkGray

# --- 3. chay emulator + test ------------------------------------------------
Push-Location $root
try {
  & $npm run test:rules:emulator
  $code = $LASTEXITCODE
} finally {
  Pop-Location
}
exit $code
