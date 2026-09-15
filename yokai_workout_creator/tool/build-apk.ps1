$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'prepare.ps1')
if (-not $?) { throw 'Preparazione non riuscita.' }
& flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Analisi non superata. Leggi gli errori prima di compilare.' }
& flutter test
if ($LASTEXITCODE -ne 0) { throw 'Test non superati. Leggi gli errori prima di compilare.' }
& flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'Build non riuscita.' }
Write-Host ''
Write-Host ('APK: ' + (Resolve-Path 'build/app/outputs/flutter-apk/app-release.apk').Path)
