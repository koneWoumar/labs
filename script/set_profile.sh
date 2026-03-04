#!/bin/sh

PROFILE_FILE="$HOME/.profile_custom"

echo "Création du profil personnalisé : $PROFILE_FILE"

cat > "$PROFILE_FILE" << 'EOF'
#############################################
# Profil personnalisé
# Auteur : $(whoami)
#############################################

### Variables d'environnement ###
export EDITOR=vim
export HISTSIZE=5000
export HISTFILESIZE=10000

# Exemple Oracle
# export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
# export ORACLE_SID=ORCL
# export PATH=$ORACLE_HOME/bin:$PATH

### PATH personnalisé ###
export PATH=$HOME/bin:$PATH

### Alias utiles ###
alias ll='ls -l'
alias la='ls -la'
alias dfh='df -g'        # AIX (remplacer par df -h sous Linux)
alias grep='grep --color=auto 2>/dev/null'

### Fonctions utiles ###
mkcd () {
    mkdir -p "$1" && cd "$1"
}

echo "Profil personnalisé chargé."
EOF

# Ajouter au .profile principal si non déjà présent
if ! grep -q ".profile_custom" "$HOME/.profile" 2>/dev/null; then
    echo "" >> "$HOME/.profile"
    echo "# Chargement profil personnalisé" >> "$HOME/.profile"
    echo "[ -f \$HOME/.profile_custom ] && . \$HOME/.profile_custom" >> "$HOME/.profile"
fi

echo "Configuration terminée."
echo "Rechargez avec : source ~/.profile"
