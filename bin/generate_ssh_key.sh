#!/bin/sh

KEY_PATH="$HOME/.ssh/id_ed25519"

# Création du dossier .ssh si nécessaire
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Suppression ancienne clé si elle existe
if [ -f "$KEY_PATH" ]; then
    rm -f "${KEY_PATH}"*
fi

# Génération clé SSH non interactive
ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -q

echo "Clé SSH générée : $KEY_PATH"
