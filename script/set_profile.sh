#!/bin/sh


PROFILE_CONF_DIR=/labs/config/profile
PROFILE_FILE="$PROFILE_CONF_DIR/labs-profile"
ENV_FILE=/labs/config/profile/labs-env
ALIAS_FILE=/labs/config/profile/labs-alias
FONCTION_FILE=/labs/config/profile/labs-fonctions
PATH_TO_BIN=/labs/bin


# Creation du dossier de configuration pour le profile
echo "***** Creation du dossier de config profile s'il n'existe pas *****"
if [ ! -d "$PROFILE_CONF_DIR" ]; then
    mkdir "$PROFILE_CONF_DIR"
fi


# Creation du fichier des variables d'environnements
echo "***** Creation fichier labs-env s'il n'existe pas *****"
if [ ! -f "$ENV_FILE" ]; then
    echo "### Set environment variable here###" > "$ENV_FILE"
fi


# Creation du fichier des alias
echo "***** Creation fichier labs-alias s'il n'existe pas *****"
if [ ! -f "$ALIAS_FILE" ]; then
    echo "### Set alias here###" > "$ALIAS_FILE"
fi


# Creation du fichier des fonctions
echo "***** Creation fichier labs-fonction s'il n'existe pas *****"
if [ ! -f "$FONCTION_FILE" ]; then
    echo "### Set fonctions here###" > "$FONCTION_FILE"
fi





echo "Création du profil personnalisé : $PROFILE_FILE"

cat > "$PROFILE_FILE" << EOF
#############################################
# Profil personnalisé
# Auteur : $(whoami)
#############################################

### Ajout des des variables d'environnement ###
  
if [ -f "$ENV_FILE" ]; then
     . "$ENV_FILE"
fi



### Configuration du PATH avec les chemin des executable du labs ###

export PATH=$PATH_TO_BIN:$PATH



### Ajout des alias utiles ###

if [ -f "$ALIAS_FILE" ]; then
     . "$ALIAS_FILE"
fi



### Fonctions utiles ###

if [ -f "$FONCTION_FILE" ]; then
     . "$FONCTION_FILE"
fi



EOF


# Ajouter au .profile principal si non déjà présent
if ! grep -q "$PROFILE_FILE" "$HOME/.profile" 2>/dev/null; then
    echo "" >> "$HOME/.profile"
    echo "# Chargement profil personnalisé" >> "$HOME/.profile"
    echo "[ -f $PROFILE_FILE ] && . $PROFILE_FILE" >> "$HOME/.profile"
fi

echo "Configuration terminée."
echo "Rechargez avec : source ~/.profile"


