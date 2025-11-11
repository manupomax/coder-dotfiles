#!/bin/bash

# --- USCITA IMMEDIATA IN CASO DI ERRORE ---
# Se un comando fallisce, l'intero script si ferma.
set -e

# --- 1. IMPOSTAZIONI UTENTE (COME RICHIESTO) ---
# Modifica queste due righe con le credenziali che vuoi usare
MY_EMAIL="admin@example.com"
MY_PASSWORD="AdminSecret123!"

echo "**************************************************"
echo "AVVIO SCRIPT DOTFILE: Configurazione pgAdmin4"
echo "Utente admin che sarà creato: $MY_EMAIL"
echo "**************************************************"

# --- 2. INSTALLAZIONE DI PGADMIN4-WEB ---
# Imposta DEBIAN_FRONTEND per evitare qualsiasi richiesta interattiva
# da 'apt' o dai suoi processi secondari (dpkg).
echo "[1/4] Aggiornamento pacchetti e installazione di pgadmin4-web..."

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y pgadmin4-web

echo "[1/4] Installazione completata."

# --- 3. CREAZIONE DIRECTORY E PERMESSI ---
# Questo è FONDAMENTALE per evitare l'errore "Database migration failed".
# Lo script `setup-web.sh` (come root) crea file che il server (come utente 'coder')
# deve poter leggere/scrivere.
echo "[2/4] Creazione directory /var/lib/pgadmin4 e /var/log/pgadmin4..."
sudo mkdir -p /var/lib/pgadmin4 /var/log/pgadmin4

echo "[3/4] Impostazione dei permessi per l'utente Coder ($USER)..."
sudo chown -R $USER:$USER /var/lib/pgadmin4
sudo chown -R $USER:$USER /var/log/pgadmin4

echo "[3/4] Permessi impostati."

# --- 4. ESECUZIONE SETUP NON INTERATTIVO ---
# Questo è il comando chiave.
# Passiamo le variabili "in linea" con il comando `sudo`.
# Questo è il metodo più robusto per assicurare che lo script
# `/usr/pgadmin4/bin/setup-web.sh` le riceva, evitando
# che `getpass.py` provi a chiedere la password.
echo "[4/4] Esecuzione di setup-web.sh in modalità non interattiva..."

sudo PGADMIN_SETUP_EMAIL="$MY_EMAIL" \
     PGADMIN_SETUP_PASSWORD="$MY_PASSWORD" \
     /usr/pgadmin4/bin/setup-web.sh --yes

echo "**************************************************"
echo "✅ CONFIGURAZIONE PGADMIN COMPLETATA!"
echo "Puoi accedere a /pgadmin4 con l'utente: $MY_EMAIL"
echo "**************************************************"
