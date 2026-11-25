#!/bin/bash
# Exports the HTML5 build and copies the loading-screen pictures next to it.
# Usage: bash tools/export_web.sh        (run from the prototype folder)
set -e
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
mkdir -p build/web
$GODOT --headless --path . --export-release Web
cp web/loading_bg.jpg web/loading_pirate.png web/privacy.html web/terms.html build/web/
ls -la build/web/index.html build/web/index.pck | awk '{print $5, $9}'
