param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

try {
    $pubspecPath = Join-Path $root 'pubspec.yaml'
    $pubspec = Get-Content $pubspecPath -Raw

    if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?\s*$') {
        throw 'Не удалось найти version в pubspec.yaml'
    }

    $version = $Matches[1]
    $buildNumber = if ($Matches[2]) { $Matches[2] } else { '0' }

    Write-Host "InkFlow $version+$buildNumber" -ForegroundColor Cyan

    if (-not $SkipBuild) {
        Write-Host 'Сборка Windows Release...' -ForegroundColor Cyan
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) {
            throw 'flutter build windows завершился с ошибкой'
        }
    }

    $releaseDir = Join-Path $root 'build\windows\x64\runner\Release'
    if (-not (Test-Path (Join-Path $releaseDir 'note_app.exe'))) {
        throw 'Не найден note_app.exe. Сначала успешно соберите Windows Release.'
    }

    $isccCandidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
    )

    $iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $iscc) {
        $command = Get-Command iscc.exe -ErrorAction SilentlyContinue
        if ($command) {
            $iscc = $command.Source
        }
    }

    if (-not $iscc) {
        throw 'Inno Setup не найден. Установите: winget install -e --id JRSoftware.InnoSetup'
    }

    $distDir = Join-Path $root 'dist'
    New-Item -ItemType Directory -Force -Path $distDir | Out-Null

    Write-Host 'Создание установщика...' -ForegroundColor Cyan
    & $iscc "/DMyAppVersion=$version" (Join-Path $root 'installer\inkflow.iss')

    if ($LASTEXITCODE -ne 0) {
        throw 'ISCC завершился с ошибкой'
    }

    $installerPath = Join-Path $distDir "InkFlow-Setup-$version.exe"
    if (-not (Test-Path $installerPath)) {
        throw "Установщик не найден: $installerPath"
    }

    Write-Host ''
    Write-Host "Готово: $installerPath" -ForegroundColor Green
    Write-Host "Загрузите этот файл в GitHub Release с тегом v$version."
}
finally {
    Pop-Location
}
