param(
    [switch]$Prod
)

$ErrorActionPreference = "Stop"

function Test-Docker {
    try {
        docker info *> $null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

if (-not (Test-Docker)) {
    Write-Host "Docker daemon chua chay. Mo Docker Desktop roi chay lai." -ForegroundColor Yellow
    return
}

if ($Prod) {
    Start-Process -NoNewWindow -FilePath "php" -ArgumentList "artisan", "serve", "--host=0.0.0.0", "--port=8000"
    Start-Process -NoNewWindow -FilePath "npm.cmd" -ArgumentList "run", "build"
    Write-Host "Da khoi dong prod build. Chay 'php artisan serve --port=8000' neu can."
}
else {
    Start-Process -NoNewWindow -FilePath "php" -ArgumentList "artisan", "serve", "--host=0.0.0.0", "--port=8000"
    Start-Process -NoNewWindow -FilePath "npm.cmd" -ArgumentList "run", "dev"
    Write-Host "Dev env: http://localhost:8000 (Laravel) + Vite dev server tai port cau hinh."
    Write-Host "Dung: Ctrl+C hai window, hoac dung task manager."
}