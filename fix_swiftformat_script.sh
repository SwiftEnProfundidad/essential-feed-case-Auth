#!/bin/sh

# 1. Desactivar sandbox (necesario para Xcode 16.4)
export DISABLE_XCODE_USER_SCRIPT_SANDBOXING=1

# 2. Detectar binario de SwiftFormat según arquitectura
if [ -x "/opt/homebrew/bin/swiftformat" ]; then
  SWIFTFORMAT="/opt/homebrew/bin/swiftformat"
elif [ -x "/usr/local/bin/swiftformat" ]; then
  SWIFTFORMAT="/usr/local/bin/swiftformat"
elif which swiftformat >/dev/null 2>&1; then
  SWIFTFORMAT="$(which swiftformat)"
else
  echo "warning: SwiftFormat not installed. Install via: brew install swiftformat"
  exit 0
fi

# 3. Configuración de rutas
REPO_ROOT="$SRCROOT/.."
CONFIG_FILE="$REPO_ROOT/.swiftformat"

# 4. Verificar que existe el archivo de configuración
if [ ! -f "$CONFIG_FILE" ]; then
  echo "warning: SwiftFormat config file not found at $CONFIG_FILE"
  exit 0
fi

# 5. Ejecutar SwiftFormat solo en EssentialApp
echo "Running SwiftFormat on EssentialApp..."
"$SWIFTFORMAT" "$SRCROOT" \
  --config "$CONFIG_FILE" \
  --swiftversion 5.9 \
  --quiet \
  || exit 1

# 6. Output ficticio para Xcode
touch "${DERIVED_FILE_DIR}/swiftformat.done"
echo "SwiftFormat completed successfully"