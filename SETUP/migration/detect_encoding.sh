#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <répertoire>"
    exit 1
fi

rep="$1"

if [ ! -d "$rep" ]; then
    echo "Erreur: Le répertoire '$rep' n'existe pas."
    exit 1
fi

find "$rep" -type f -exec file {} + | grep -E ':.*text' | cut -d: -f1 | while read -r fichier; do
    enc=$(file -b --mime-encoding "$fichier")
    #if [[ "$enc" != *"utf-8"* && "$enc" != *"us-ascii"* && "$enc" != *"iso-8859"* ]]; then
    if [[ "$enc" != *"utf-8"* && "$enc" != *"us-ascii"* ]]; then
        echo "Fichier: $fichier - Encodage: $enc"
    fi
done
