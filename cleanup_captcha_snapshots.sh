#!/bin/bash

# Directorio principal de snapshots
SNAPSHOT_DIR="/Users/juancarlosmerlosalbarracin/Developer/Essential_Developer/essential-feed-case-study/EssentialApp/EssentialAppTests/Features/Auth/UI/snapshots"

echo "Limpiando snapshots de CAPTCHA..."

# Verificar que los archivos en las ubicaciones correctas existen
if [ -f "$SNAPSHOT_DIR/en/light/CAPTCHA_HIDDEN.png" ] && \
   [ -f "$SNAPSHOT_DIR/en/light/CAPTCHA_LOADING.png" ] && \
   [ -f "$SNAPSHOT_DIR/en/light/CAPTCHA_VISIBLE.png" ] && \
   [ -f "$SNAPSHOT_DIR/en/dark/CAPTCHA_LOADING.png" ] && \
   [ -f "$SNAPSHOT_DIR/en/dark/CAPTCHA_VISIBLE.png" ] && \
   [ -f "$SNAPSHOT_DIR/es/light/CAPTCHA_HIDDEN.png" ] && \
   [ -f "$SNAPSHOT_DIR/es/light/CAPTCHA_LOADING.png" ] && \
   [ -f "$SNAPSHOT_DIR/es/light/CAPTCHA_VISIBLE.png" ] && \
   [ -f "$SNAPSHOT_DIR/es/dark/CAPTCHA_LOADING.png" ] && \
   [ -f "$SNAPSHOT_DIR/es/dark/CAPTCHA_VISIBLE.png" ]; then
    
    echo "✅ Todos los archivos necesarios existen en las ubicaciones correctas"
    
    # Eliminar archivos duplicados de la raíz
    echo "Eliminando archivos duplicados de la raíz..."
    rm -f "$SNAPSHOT_DIR/CAPTCHA_HIDDEN.png"
    rm -f "$SNAPSHOT_DIR/CAPTCHA_LOADING_DARK.png"
    rm -f "$SNAPSHOT_DIR/CAPTCHA_LOADING_LIGHT.png"
    rm -f "$SNAPSHOT_DIR/CAPTCHA_VISIBLE_DARK.png"
    rm -f "$SNAPSHOT_DIR/CAPTCHA_VISIBLE_LIGHT.png"
    
    echo "✅ Limpieza completa"
else
    echo "⚠️ No todos los archivos existen en las ubicaciones correctas."
    echo "❌ Abortando limpieza para evitar pérdida de datos."
    
    # Listar archivos faltantes
    echo "Verificando archivos individuales:"
    
    [ -f "$SNAPSHOT_DIR/en/light/CAPTCHA_HIDDEN.png" ] || echo "❌ Falta: en/light/CAPTCHA_HIDDEN.png"
    [ -f "$SNAPSHOT_DIR/en/light/CAPTCHA_LOADING.png" ] || echo "❌ Falta: en/light/CAPTCHA_LOADING.png"
    [ -f "$SNAPSHOT_DIR/en/light/CAPTCHA_VISIBLE.png" ] || echo "❌ Falta: en/light/CAPTCHA_VISIBLE.png"
    [ -f "$SNAPSHOT_DIR/en/dark/CAPTCHA_LOADING.png" ] || echo "❌ Falta: en/dark/CAPTCHA_LOADING.png"
    [ -f "$SNAPSHOT_DIR/en/dark/CAPTCHA_VISIBLE.png" ] || echo "❌ Falta: en/dark/CAPTCHA_VISIBLE.png"
    [ -f "$SNAPSHOT_DIR/es/light/CAPTCHA_HIDDEN.png" ] || echo "❌ Falta: es/light/CAPTCHA_HIDDEN.png"
    [ -f "$SNAPSHOT_DIR/es/light/CAPTCHA_LOADING.png" ] || echo "❌ Falta: es/light/CAPTCHA_LOADING.png"
    [ -f "$SNAPSHOT_DIR/es/light/CAPTCHA_VISIBLE.png" ] || echo "❌ Falta: es/light/CAPTCHA_VISIBLE.png"
    [ -f "$SNAPSHOT_DIR/es/dark/CAPTCHA_LOADING.png" ] || echo "❌ Falta: es/dark/CAPTCHA_LOADING.png"
    [ -f "$SNAPSHOT_DIR/es/dark/CAPTCHA_VISIBLE.png" ] || echo "❌ Falta: es/dark/CAPTCHA_VISIBLE.png"
fi
