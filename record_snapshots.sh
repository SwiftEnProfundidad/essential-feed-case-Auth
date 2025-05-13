#!/bin/bash

set -e

SCHEME="EssentialApp"
DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4"
PROJECT_DIR="EssentialApp"

cd "$PROJECT_DIR"

echo "⏺️  Grabando snapshots en $DESTINATION para el esquema $SCHEME..."

RECORD_SNAPSHOTS=YES xcodebuild test \
  -scheme "$SCHEME" \
  -destination "$DESTINATION"

echo "✅ Snapshots grabados correctamente."
echo "Revisa la carpeta de snapshots y ejecuta los tests normalmente para comparar en futuras ejecuciones."