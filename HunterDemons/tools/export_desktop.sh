#!/usr/bin/env sh
# Экспорт для macOS/Windows из macOS или Linux.
# Запуск: ./tools/export_desktop.sh [windows|macos|all]
set -eu

cd "$(dirname "$0")/.."
TARGET="${1:-all}"
GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	if [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
		GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
	else
		echo "Godot не найден. Укажи путь через GODOT_BIN." >&2
		exit 1
	fi
fi

"$GODOT_BIN" --headless --path . --import

case "$TARGET" in
	windows)
		mkdir -p build/windows
		"$GODOT_BIN" --headless --path . --export-release "Windows Desktop" build/windows/HunterDemons.exe
		;;
	macos)
		mkdir -p build/macos
		"$GODOT_BIN" --headless --path . --export-release "macOS" build/macos/HunterDemons.app
		;;
	all)
		mkdir -p build/windows build/macos
		"$GODOT_BIN" --headless --path . --export-release "Windows Desktop" build/windows/HunterDemons.exe
		"$GODOT_BIN" --headless --path . --export-release "macOS" build/macos/HunterDemons.app
		;;
	*)
		echo "Использование: $0 [windows|macos|all]" >&2
		exit 2
		;;
esac
