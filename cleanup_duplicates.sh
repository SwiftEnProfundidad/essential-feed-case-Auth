#!/bin/bash

PROJECT_FILE="EssentialApp/EssentialApp.xcodeproj/project.pbxproj"

# Hacer una copia de seguridad del archivo de proyecto
cp "$PROJECT_FILE" "${PROJECT_FILE}.bak"

echo "Limpiando referencias duplicadas en $PROJECT_FILE..."

# Lista de archivos problemáticos específicos
PROBLEMATIC_FILES=(
    "NETWORK_ERROR_REFRESH_RETRY-failure.png"
    "TOKEN_REFRESH_FAILURE_SPANISH-failure.png"
    "CAPTCHA_HIDDEN.png"
    "CAPTCHA_LOADING.png"
    "CAPTCHA_VISIBLE.png"
    "GLOBAL_LOGOUT_REQUIRED.png"
    "LOGIN_ACCOUNT_LOCKED.png"
    "LOGIN_BLOCKED_ACCOUNT_LOCKED.png"
    "LOGIN_BLOCKED_WITH_RECOVERY_SUGGESTION.png"
    "LOGIN_ERROR_INVALID_CREDENTIALS.png"
    "LOGIN_ERROR_NETWORK.png"
    "LOGIN_ERROR_NOTIFICATION.png"
    "LOGIN_ERROR_NO_CONNECTIVITY.png"
    "LOGIN_ERROR_OFFLINE_STORE_FAILED.png"
    "LOGIN_ERROR_TOKEN_STORAGE_FAILED.png"
    "LOGIN_FORM_VALIDATION.png"
    "LOGIN_IDLE.png"
    "LOGIN_NETWORK_ERROR_NOTIFICATION.png"
    "LOGIN_SUCCESS.png"
    "LOGIN_SUCCESS_NOTIFICATION.png"
    "LOGIN_UNKNOWN_ERROR_NOTIFICATION.png"
    "TOKEN_REFRESH_FAILURE.png"
)

# Crear un archivo temporal para el proyecto modificado
> temp_project.pbxproj

# Leer el archivo de proyecto y procesar cada línea
FOUND_FIRST=false
while IFS= read -r line; do
    # Verificar si esta línea contiene alguno de los archivos problemáticos
    SKIP_LINE=false
    for file in "${PROBLEMATIC_FILES[@]}"; do
        if [[ "$line" == *"$file"* ]]; then
            # Si ya hemos encontrado una instancia de este archivo antes, omitir esta línea
            if [[ "$FOUND_FIRST" == "true" ]]; then
                SKIP_LINE=true
                echo "Omitiendo línea duplicada: $line"
                break
            else
                # Marcar que hemos encontrado la primera instancia
                FOUND_FIRST=true
            fi
        fi
    done
    
    # Si no debemos omitir la línea, la escribimos en el archivo temporal
    if [[ "$SKIP_LINE" == "false" ]]; then
        echo "$line" >> temp_project.pbxproj
    fi
    
    # Reiniciar la bandera para el siguiente archivo
    if [[ "$line" == *";" ]]; then
        FOUND_FIRST=false
    fi
done < "$PROJECT_FILE"

# Reemplazar el archivo de proyecto con la versión limpia
mv temp_project.pbxproj "$PROJECT_FILE"

echo "Se han eliminado las referencias duplicadas de archivos PNG en el proyecto."
