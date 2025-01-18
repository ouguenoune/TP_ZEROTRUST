#!/bin/bash

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script avec sudo ou en tant que root."
  exit 1
fi

# =============================
# Étape 1 : Vérification et installation de Docker
# =============================

echo "Vérification de l'installation de Docker..."

if ! command -v docker &> /dev/null; then
  echo "Docker n'est pas installé. Installation en cours..."
  
  # Mise à jour du système
  apt update && apt upgrade -y

  # Installation des prérequis pour Docker
  apt install -y apt-transport-https ca-certificates curl software-properties-common

  # Ajout du dépôt officiel Docker
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Installation de Docker
  apt update && apt install -y docker-ce docker-ce-cli containerd.io

  # Vérification de l'installation
  if docker --version; then
    echo "Docker a été installé avec succès !"
  else
    echo "Échec de l'installation de Docker."
    exit 1
  fi

  # Ajout de l'utilisateur au groupe Docker
  usermod -aG docker $USER
  echo "Veuillez vous déconnecter et vous reconnecter pour que les modifications prennent effet."
else
  echo "Docker est déjà installé."
fi

# =============================
# Étape 2 : Vérification et installation de Docker Compose
# =============================

echo "Vérification de l'installation de Docker Compose..."

if ! command -v docker-compose &> /dev/null; then
  echo "Docker Compose n'est pas installé. Installation en cours..."
  
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
  chmod +x /usr/local/bin/docker-compose

  # Vérification de l'installation
  if docker-compose --version; then
    echo "Docker Compose a été installé avec succès !"
  else
    echo "Échec de l'installation de Docker Compose."
    exit 1
  fi
else
  echo "Docker Compose est déjà installé."
fi

# =============================
# Étape 3 : Configuration Docker Compose
# =============================

PROJECT_DIR="$HOME/zero-trust-lab"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

cat > docker-compose.yml <<EOL
version: '3.9'
services:
  server:
    image: debian:bullseye
    container_name: zero-trust-server
    command: bash -c "apt update && apt install -y nano sudo rsyslog nftables openssh-server telnet && mkdir -p /evidence_data && echo 'Preuve critique' > /evidence_data/evidence.txt && tail -f /dev/null"
    networks:
      zero_trust_net:
        ipv4_address: 192.168.1.10
    volumes:
      - server_data:/evidence_data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "2222:22"
    privileged: true

  client:
    image: debian:bullseye
    container_name: zero-trust-client
    command: bash -c "apt update && apt install -y nano sudo rsyslog nftables openssh-server telnet && tail -f /dev/null"
    networks:
      zero_trust_net:
        ipv4_address: 192.168.1.20
    volumes:
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro

  siem:
    image: debian:bullseye
    container_name: siem-server
    command: bash -c "apt update && apt install -y nano sudo rsyslog nftables openssh-server telnet && bash -c 'service rsyslog start' && tail -f /dev/null"
    networks:
      zero_trust_net:
        ipv4_address: 192.168.1.30
    volumes:
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro

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
# Étape 4 : Lancement des services Docker Compose
# =============================

echo "Lancement des services Docker Compose..."
docker-compose up -d

echo "Les services suivants sont en cours d'exécution :"
docker ps
