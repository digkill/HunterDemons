#!/bin/zsh
# Экспорт iOS только из macOS: реимпорт ресурсов -> генерация Xcode-проекта.
# Запуск: ./tools/export_ios.sh [--no-open]
set -e

if [[ "$(uname -s)" != "Darwin" ]]; then
	echo "iOS-экспорт доступен только из macOS: требуются Xcode и инструменты Apple." >&2
	exit 1
fi

cd "$(dirname "$0")/.."
GODOT="/Applications/Godot_mono.app/Contents/MacOS/Godot"

"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-debug "iOS" build/ios/HunterDemons.ipa
echo "Xcode-проект: build/ios/HunterDemons.xcodeproj"

if [[ "$1" != "--no-open" ]]; then
	open build/ios/HunterDemons.xcodeproj
fi
