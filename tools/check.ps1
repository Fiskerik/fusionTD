$ErrorActionPreference = 'Stop'
$godotCommand = if ($env:GODOT) { $env:GODOT } else { 'godot' }
$projectRoot = Split-Path -Parent $PSScriptRoot
$lines = & $godotCommand --headless --path $projectRoot --import 2>&1
$code = $LASTEXITCODE
$lines | ForEach-Object { Write-Output $_ }
if ($code -ne 0 -or ($lines | Select-String 'SCRIPT ERROR|Parse Error|Failed to load script')) { exit 1 }
exit 0
