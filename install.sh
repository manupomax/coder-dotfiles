#!/usr/bin/env bash
# =========================================================
# install.sh — Installazione pgAdmin4 in server mode su Linux
# Ottimizzato per Coder (Python 3.10+, port forwarding)
# =========================================================

set -e

echo "=== [pgAdmin Setup] Avvio installazione pgAdmin 4 ==="

# Controllo versione Python
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python rilevato: $PYTHON_VERSION"

# Aggiorna pacchetti e installa dipendenze
sudo apt-get update -y
sudo apt-get install -y curl gnupg lsb-release python3-pip netcat

# Aggiorna pip
pip3 install --upgrade pip

#
# Setup the repository
#

# Install the public key for the repository (if not done previously):
curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg

# Create the repository configuration file:
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list && apt update'

#
# Install pgAdmin
#

# Install for both desktop and web modes:
# sudo apt install pgadmin4

# Install for desktop mode only:
# sudo apt install pgadmin4-desktop

# Install for web mode only: 
sudo apt install pgadmin4-web 

# Configure the webserver, if you installed pgadmin4-web:
sudo /usr/pgadmin4/bin/setup-web.sh

echo "=== [pgAdmin Setup] pgAdmin installato ==="

# Imposta variabili ambiente per server mode
# export PGADMIN_CONFIG_SERVER_MODE=True
# export PGADMIN_CONFIG_DEFAULT_SERVER='0.0.0.0'
# export PGADMIN_CONFIG_DEFAULT_SERVER_PORT=5050
