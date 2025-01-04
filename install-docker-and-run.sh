#!/bin/bash

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script avec sudo ou en tant que root."
  exit 1
fi

# =============================
# Étape 1 : Installation de Docker et Docker Compose
# =============================

echo "Installation de Docker et Docker Compose..."

# Mise à jour du système
echo "Mise à jour des paquets..."
apt update && apt upgrade -y

# Installation des prérequis pour Docker
echo "Installation des prérequis pour Docker..."
apt install -y apt-transport-https ca-certificates curl software-properties-common

# Ajout du dépôt officiel Docker
echo "Ajout du dépôt officiel Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Installation de Docker
echo "Installation de Docker..."
apt update && apt install -y docker-ce docker-ce-cli containerd.io

# Vérification de l'installation de Docker
if docker --version; then
  echo "Docker a été installé avec succès !"
else
  echo "Échec de l'installation de Docker."
  exit 1
fi

# Ajout de l'utilisateur au groupe Docker
echo "Ajout de l'utilisateur actuel au groupe Docker..."
usermod -aG docker $USER

# Installation de Docker Compose
echo "Installation de Docker Compose..."

# Détection de l'architecture système
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
  BIN_URL="https://github.com/docker/compose/releases/download/v2.32.0/docker-compose-linux-x86_64"
elif [[ "$ARCH" == "aarch64" ]]; then
  BIN_URL="https://github.com/docker/compose/releases/download/v2.32.0/docker-compose-linux-aarch64"
elif [[ "$ARCH" == "i386" || "$ARCH" == "i686" ]]; then
  BIN_URL="https://github.com/docker/compose/releases/download/v2.32.0/docker-compose-linux-i386"
else
  echo "Architecture non prise en charge : $ARCH"
  exit 1
fi

# Téléchargement de Docker Compose
curl -fSL "$BIN_URL" -o /usr/local/bin/docker-compose
if [ $? -ne 0 ]; then
  echo "Échec du téléchargement de Docker Compose. Vérifiez votre connexion ou l'URL."
  exit 1
fi

# Attribution des permissions d'exécution
chmod +x /usr/local/bin/docker-compose

# Vérification de l'installation de Docker Compose
if docker-compose --version; then
  echo "Docker Compose a été installé avec succès !"
else
  echo "Échec de l'installation de Docker Compose."
  exit 1
fi

# =============================
# Étape 2 : Configuration Docker Compose
# =============================

echo "Création de la configuration Docker Compose..."

# Création du dossier du projet
PROJECT_DIR="$HOME/zero-trust-lab"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Création du fichier docker-compose.yml
cat > docker-compose.yml <<EOL
version: '3.9'
services:
  server:
    image: debian:bullseye
    container_name: zero-trust-server
    command: bash -c "mkdir -p /evidence_data && echo 'Preuve critique' > /evidence_data/evidence.txt && tail -f /dev/null"
    networks:
      zero_trust_net:
        ipv4_address: 192.168.1.10
    volumes:
      - server_data:/evidence_data
    ports:
      - "2222:22"

  client:
    image: debian:bullseye
    container_name: zero-trust-client
    command: tail -f /dev/null
    networks:
      zero_trust_net:
        ipv4_address: 192.168.1.20

  siem:
    image: debian:bullseye
    container_name: siem-server
    command: bash -c "apt update && apt install -y rsyslog && service rsyslog start && tail -f /dev/null"
    networks:
      zero_trust_net:
        ipv4_address: 192.168.1.30

networks:
  zero_trust_net:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.1.0/24

volumes:
  server_data:
EOL

echo "Fichier docker-compose.yml créé dans $PROJECT_DIR."

# =============================
# Étape 3 : Lancement des services Docker Compose
# =============================

echo "Lancement des services Docker Compose..."
docker-compose up -d

# Vérification des services
echo "Les services suivants sont en cours d'exécution :"
docker ps

echo "Configuration et lancement terminés. Connectez-vous aux containers pour continuer votre TP."
