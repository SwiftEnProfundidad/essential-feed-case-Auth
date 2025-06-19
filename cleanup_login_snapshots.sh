#!/bin/bash

# Script para organizar los snapshots de login que no están en la estructura correcta

SNAPSHOT_DIR="/Users/juancarlosmerlosalbarracin/Developer/Essential_Developer/essential-feed-case-study/EssentialApp/EssentialAppTests/Features/Auth/UI/snapshots"
cd "$SNAPSHOT_DIR"

# Asegurarse que todas las carpetas necesarias existen
mkdir -p en/light en/dark es/light es/dark el/light el/dark pt_BR/light pt_BR/dark

# Renombrando archivos según su sufijo y moviéndolos a los directorios correctos
for file in *.png; do
    # Saltamos los archivos que ya están en las carpetas correctas
    if [[ "$file" == *"/"* ]]; then
        continue
    fi
    
    # Archivos con sufijo específico de idioma y tema
    if [[ "$file" == *"_en_light.png" ]]; then
        newname=$(echo "$file" | sed 's/_en_light.png/.png/')
        if [ -e "en/light/$newname" ]; then
            echo "Ya existe el archivo: en/light/$newname, eliminando duplicado"
            rm "$file"
        else
            echo "Moviendo $file a en/light/$newname"
            mv "$file" "en/light/$newname"
        fi
    elif [[ "$file" == *"_en_dark.png" ]]; then
        newname=$(echo "$file" | sed 's/_en_dark.png/.png/')
        if [ -e "en/dark/$newname" ]; then
            echo "Ya existe el archivo: en/dark/$newname, eliminando duplicado"
            rm "$file"
        else
            echo "Moviendo $file a en/dark/$newname"
            mv "$file" "en/dark/$newname"
        fi
    elif [[ "$file" == *"_es_light.png" ]]; then
        newname=$(echo "$file" | sed 's/_es_light.png/.png/')
        if [ -e "es/light/$newname" ]; then
            echo "Ya existe el archivo: es/light/$newname, eliminando duplicado"
            rm "$file"
        else
            echo "Moviendo $file a es/light/$newname"
            mv "$file" "es/light/$newname"
        fi
    elif [[ "$file" == *"_es_dark.png" ]]; then
        newname=$(echo "$file" | sed 's/_es_dark.png/.png/')
        if [ -e "es/dark/$newname" ]; then
            echo "Ya existe el archivo: es/dark/$newname, eliminando duplicado"
            rm "$file"
        else
            echo "Moviendo $file a es/dark/$newname"
            mv "$file" "es/dark/$newname"
        fi
    elif [[ "$file" == *"_el_light.png" ]]; then
        newname=$(echo "$file" | sed 's/_el_light.png/.png/')
        if [ -e "el/light/$newname" ]; then
            echo "Ya existe el archivo: el/light/$newname, eliminando duplicado"
            rm "$file"
        else
            echo "Moviendo $file a el/light/$newname"
            mv "$file" "el/light/$newname"
        fi
    elif [[ "$file" == *"_el_dark.png" ]]; then
        newname=$(echo "$file" | sed 's/_el_dark.png/.png/')
        if [ -e "el/dark/$newname" ]; then
            echo "Ya existe el archivo: el/dark/$newname, eliminando duplicado"
            rm "$file"
        else
            echo "Moviendo $file a el/dark/$newname"
            mv "$file" "el/dark/$newname"
        fi
    elif [[ "$file" == *"_pt_BR_light.png" ]]; then
        newname=$(echo "$file" | sed 's/_pt_BR_light.png/.png/')
        if [ -e "pt_BR/light/$newname" ]; then
            echo "Ya existe el archivo: pt_BR/light/$newname, eliminando duplicado"
            rm "$file"
        else
            echo "Moviendo $file a pt_BR/light/$newname"
            mv "$file" "pt_BR/light/$newname"
        fi
    elif [[ "$file" == *"_pt_BR_dark.png" ]]; then
        newname=$(echo "$file" | sed 's/_pt_BR_dark.png/.png/')
        if [ -e "pt_BR/dark/$newname" ]; then
            echo "Ya existe el archivo: pt_BR/dark/$newname, eliminando duplicado"
            rm "$file"
        else
            echo "Moviendo $file a pt_BR/dark/$newname"
            mv "$file" "pt_BR/dark/$newname"
        fi
    fi

    # Archivos con sufijo simplificado de tema
    if [[ "$file" == *"_LIGHT"* && "$file" != *"_light.png"* && "$file" != *"_dark.png"* ]]; then
        basename=$(echo "$file" | sed 's/_LIGHT.*/.png/')
        if [ -e "en/light/$basename" ]; then
            echo "Ya existe el archivo: en/light/$basename, eliminando duplicado"
            rm "$file"
        else
            echo "Moviendo $file a en/light/$basename"
            mv "$file" "en/light/$basename"
        fi
    elif [[ "$file" == *"_DARK"* && "$file" != *"_light.png"* && "$file" != *"_dark.png"* ]]; then
        basename=$(echo "$file" | sed 's/_DARK.*/.png/')
        if [ -e "en/dark/$basename" ]; then
            echo "Ya existe el archivo: en/dark/$basename, eliminando duplicado"
            rm "$file"
        else
            echo "Moviendo $file a en/dark/$basename"
            mv "$file" "en/dark/$basename"
        fi
    fi

    # Otros archivos que simplemente tienen "light" o "dark" en su nombre
    if [[ "$file" == *"_light.png" && "$file" != *"_en_light.png"* && "$file" != *"_es_light.png"* && "$file" != *"_el_light.png"* && "$file" != *"_pt_BR_light.png"* ]]; then
        basename=$(echo "$file" | sed 's/_light.png/.png/')
        if [ -e "en/light/$basename" ]; then
            echo "Ya existe el archivo: en/light/$basename, eliminando duplicado"
            rm "$file"
        else
            echo "Moviendo $file a en/light/$basename"
            mv "$file" "en/light/$basename"
        fi
    elif [[ "$file" == *"_dark.png" && "$file" != *"_en_dark.png"* && "$file" != *"_es_dark.png"* && "$file" != *"_el_dark.png"* && "$file" != *"_pt_BR_dark.png"* ]]; then
        basename=$(echo "$file" | sed 's/_dark.png/.png/')
        if [ -e "en/dark/$basename" ]; then
            echo "Ya existe el archivo: en/dark/$basename, eliminando duplicado"
            rm "$file"
        else
            echo "Moviendo $file a en/dark/$basename"
            mv "$file" "en/dark/$basename"
        fi
    fi
done

# Para los archivos que no tienen sufijo con el esquema de color, asumimos que son light (inglés)
for file in *.png; do
    # Saltamos los archivos que ya están en las carpetas correctas
    if [[ "$file" == *"/"* ]]; then
        continue
    fi
    
    # Si todavía quedan archivos PNG en el directorio raíz, los movemos a en/light
    if [ -e "en/light/$file" ]; then
        echo "Ya existe el archivo: en/light/$file, eliminando duplicado"
        rm "$file"
    else
        echo "Moviendo $file a en/light/$file"
        mv "$file" "en/light/$file"
    fi
done

echo "Limpieza completada."
