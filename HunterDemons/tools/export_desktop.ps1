# Экспорт Windows-версии из PowerShell.
# Запуск: .\tools\export_desktop.ps1 [-Godot godot]
param(
	[string]$Godot = "godot"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

if (-not (Get-Command $Godot -ErrorAction SilentlyContinue)) {
	throw "Godot не найден. Передай путь через параметр -Godot."
}

function Invoke-GodotExport([string]$Preset, [string]$Path) {
	New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
	& $Godot --headless --path . --export-release $Preset $Path
	if ($LASTEXITCODE -ne 0) {
		throw "Экспорт '$Preset' завершился с кодом $LASTEXITCODE."
	}
}

& $Godot --headless --path . --import
if ($LASTEXITCODE -ne 0) {
	throw "Импорт ресурсов завершился с кодом $LASTEXITCODE."
}

Invoke-GodotExport "Windows Desktop" "build/windows/HunterDemons.exe"
