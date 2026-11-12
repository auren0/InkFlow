
$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

$appName = "InkFlow"
$cmakePath = "windows\CMakeLists.txt"
$buildPath = "build\windows"
$exePath = "build\windows\x64\runner\Release\$appName.exe"

Write-Host "Configuring $appName..." -ForegroundColor Cyan

if (-not (Test-Path $cmakePath)) {
    throw "CMakeLists.txt not found!"
}

# Update the executable target name
$content = Get-Content $cmakePath -Raw

$content = $content -replace 'set\(BINARY_NAME\s+"[^"]+"\)', "set(BINARY_NAME `"$appName`")"

Set-Content $cmakePath $content -Encoding UTF8

# Fix old target references in project CMake files
Get-ChildItem "windows" -Recurse -Filter "CMakeLists.txt" |
    ForEach-Object {
        $path = $_.FullName
        $text = Get-Content $path -Raw

        $text = $text.Replace(
            '$<TARGET_FILE_DIR:note_app>',
            '$<TARGET_FILE_DIR:InkFlow>'
        )

        Set-Content $path $text -Encoding UTF8
    }

# Remove stale Windows build cache
if (Test-Path $buildPath) {
    Write-Host "Cleaning old Windows build..." -ForegroundColor Yellow
    Remove-Item $buildPath -Recurse -Force
}

# Build Windows application
Write-Host "Building $appName..." -ForegroundColor Yellow

flutter build windows

if ($LASTEXITCODE -ne 0) {
    throw "Flutter build failed!"
}

if (Test-Path $exePath) {
    Write-Host ""
    Write-Host "BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "Executable: $exePath" -ForegroundColor Cyan
} else {
    throw "$appName.exe was not found!"
}
