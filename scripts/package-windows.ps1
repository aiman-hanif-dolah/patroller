# Build a portable Patroller zip for Windows (run on a Windows machine).
# Usage (PowerShell, from repo root):
#   .\scripts\package-windows.ps1
# Output:
#   dist\Patroller-<version>-windows-x64.zip
#   dist\install-windows.txt
#   dist\SHA256SUMS-<version>.txt
#
# Then upload the zip on GitHub → Releases (manual, no CI).

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

function Get-PubspecVersion {
  $line = Get-Content "pubspec.yaml" | Where-Object { $_ -match "^version:" } | Select-Object -First 1
  if ($line -match "version:\s*([0-9]+\.[0-9]+\.[0-9]+)") {
    return $Matches[1]
  }
  return "0.0.0"
}

$Version = Get-PubspecVersion
$Dist = Join-Path $Root "dist"
New-Item -ItemType Directory -Force -Path $Dist | Out-Null

Write-Host "-> Patroller Windows packaging"
Write-Host "   version: $Version"
Write-Host "   out:     $Dist"
Write-Host ""

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "flutter not found on PATH. Install Flutter and enable Windows desktop."
}

Write-Host "-> flutter config --enable-windows-desktop"
flutter config --enable-windows-desktop | Out-Null

Write-Host "-> flutter pub get"
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

# Optional DevTools panel (same as macOS package script)
$Devtools = Join-Path $Root "devtools_extension"
if (Test-Path $Devtools) {
  Write-Host "-> build DevTools panel (web)"
  Push-Location $Devtools
  try {
    flutter pub get
    flutter build web --release --base-href=/panel/ --no-tree-shake-icons
    if ($LASTEXITCODE -ne 0) { throw "devtools web build failed" }
    $index = Join-Path (Join-Path $Devtools "build\web") "index.html"
    if (Test-Path $index) {
      (Get-Content $index -Raw) -replace '<base href="/panel/"\s*/?>', '<base href="/">' |
        Set-Content -NoNewline $index
    }
    $panelOut = Join-Path $Root "extension\devtools\build"
    if (Test-Path $panelOut) { Remove-Item -Recurse -Force $panelOut }
    New-Item -ItemType Directory -Force -Path (Split-Path $panelOut) | Out-Null
    Copy-Item -Recurse (Join-Path $Devtools "build\web") $panelOut
  } finally {
    Pop-Location
  }
}

Write-Host "-> flutter build windows --release"
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }

$ReleaseDir = Join-Path $Root "build\windows\x64\runner\Release"
if (-not (Test-Path $ReleaseDir)) {
  throw "Release folder not found: $ReleaseDir"
}

$Exe = @(
  (Join-Path $ReleaseDir "patroller.exe"),
  (Join-Path $ReleaseDir "Patroller.exe")
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $Exe) {
  throw "patroller.exe not found in $ReleaseDir"
}

$ZipName = "Patroller-$Version-windows-x64.zip"
$ZipPath = Join-Path $Dist $ZipName
if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }

Write-Host "-> create $ZipName"
Compress-Archive -Path (Join-Path $ReleaseDir "*") -DestinationPath $ZipPath -Force

$InstallTxt = @"
Patroller $Version for Windows
==============================

1. Unzip $ZipName to a folder (e.g. %LOCALAPPDATA%\Patroller).
2. Run patroller.exe.
3. Optional: pin the exe to the taskbar / Start menu.

No admin install is required for this portable zip.

Upload this zip on GitHub Releases so others can download it from the Installation section.
"@
Set-Content -Path (Join-Path $Dist "install-windows.txt") -Value $InstallTxt -Encoding UTF8

$Hash = (Get-FileHash -Algorithm SHA256 $ZipPath).Hash.ToLower()
$Sums = Join-Path $Dist "SHA256SUMS-$Version-windows.txt"
Set-Content -Path $Sums -Value "$Hash  $ZipName" -Encoding UTF8

Write-Host ""
Write-Host "Windows artifacts:"
Get-ChildItem $Dist | Where-Object { $_.Name -like "Patroller-$Version-windows*" -or $_.Name -like "*windows*" } | Format-Table Name, Length
Write-Host "SHA256: $Hash"
Write-Host ""
Write-Host "Next: GitHub -> Releases -> edit v$Version (or draft new) -> upload $ZipName"
Write-Host "Then update the Windows download link in README.md Installation if the version changed."
