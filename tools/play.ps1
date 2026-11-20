$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotCommand = $env:GODOT
if (!$godotCommand) {
    $installedGodot = Get-Command godot,godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installedGodot) {
        $godotCommand = $installedGodot.Source
    } else {
        $verifiedEngine = Join-Path $env:LOCALAPPDATA 'Temp/ElementalTD-Godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe'
        if (Test-Path -LiteralPath $verifiedEngine) { $godotCommand = $verifiedEngine }
    }
}
if (!$godotCommand) {
    throw 'Install Godot 4, then set GODOT to the console executable or add godot to PATH.'
}
$import = & $godotCommand --headless --path $projectRoot --import 2>&1
if ($LASTEXITCODE -ne 0 -or ($import | Select-String 'SCRIPT ERROR|Parse Error|Failed to load script|Failed loading resource')) {
    $import | ForEach-Object { Write-Output $_ }
    exit 1
}
& $godotCommand --path $projectRoot
exit $LASTEXITCODE
