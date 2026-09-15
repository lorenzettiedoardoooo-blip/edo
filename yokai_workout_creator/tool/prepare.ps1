$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$project = (Get-Location).Path
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter non trovato. Segui prima LEGGIMI.md: installa Flutter e aggiungi flutter\bin al PATH.'
}
# Generate the official Gradle launchers in a TEMPORARY Flutter project. Existing
# application files, Android configuration and Dart sources are never replaced.
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('yokai-setup-' + [guid]::NewGuid().ToString('N'))
try {
    & flutter create --empty --no-pub --platforms=android --org=it.yokai --project-name=yokai_workout_creator $temp
    if ($LASTEXITCODE -ne 0) { throw 'flutter create non riuscito.' }
    foreach ($relative in @('gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar')) {
        $destination = Join-Path $project ('android/' + $relative)
        New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
        Copy-Item (Join-Path $temp ('android/' + $relative)) $destination -Force
    }
    $properties = Join-Path $temp 'android/local.properties'
    if (Test-Path $properties) { Copy-Item $properties (Join-Path $project 'android/local.properties') -Force }
} finally {
    if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
}
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get non riuscito.' }
Write-Host 'Progetto preparato. Ora puoi eseguire flutter analyze, flutter test e flutter build apk --release.'
