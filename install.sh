#!/bin/bash

# --- USCITA IMMEDIATA IN CASO DI ERRORE ---
set -e

# --- 1. IMPOSTAZIONI UTENTE ---
# Modifica qui le tue credenziali
MY_EMAIL="admin@example.com"
MY_PASSWORD="AdminSecret123!"

echo "**************************************************"
echo "AVVIO SCRIPT DOTFILE: Configurazione pgAdmin4"
echo "Utente admin che sarà creato: $MY_EMAIL"
echo "**************************************************"

# Imposta DEBIAN_FRONTEND per l'installazione non interattiva
export DEBIAN_FRONTEND=noninteractive

# --- 2. INSTALLAZIONE REPOSITORY E PGADMIN4-WEB ---
echo "[1/5] Installazione pgAdmin4-web e configurazione repository..."
sudo apt-get update
sudo apt-get install -y curl ca-certificates gnupg

# Aggiunta del repository pgAdmin
sudo curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/pgadmin4-archive-keyring.gpg
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/pgadmin4-archive-keyring.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'

# Installazione
sudo apt-get update
sudo apt-get install -y pgadmin4-web

echo "[1/5] Installazione completata."


# --- 3. CREAZIONE DIRECTORY E PERMESSI ---
echo "[2/5] Creazione/Impostazione permessi per le directory di pgAdmin..."
sudo mkdir -p /var/lib/pgadmin4 /var/log/pgadmin4
sudo chown -R $USER:$USER /var/lib/pgadmin4
sudo chown -R $USER:$USER /var/log/pgadmin4
echo "[2/5] Permessi impostati."


# --- 4. CONFIGURAZIONE APACHE (Risolve AH00558 Warning) ---
echo "[3/5] Configurazione Apache per risolvere il warning ServerName..."
# Aggiunge la direttiva ServerName al file di configurazione principale di Apache.
sudo sh -c 'echo "ServerName 127.0.0.1" >> /etc/apache2/apache2.conf'
echo "[3/5] ServerName impostato."


# --- 5. ESECUZIONE SETUP NON INTERATTIVO (SOLUZIONE DEFINITIVA) ---
echo "[4/5] Esecuzione di setup-web.sh per creare l'utente..."

sudo PGADMIN_SETUP_EMAIL="$MY_EMAIL" PGADMIN_SETUP_PASSWORD="$MY_PASSWORD" /usr/pgadmin4/bin/setup-web.sh --yes

echo "[4/5] Setup utente e database completato."


# --- 6. AVVIO DI APACHE ROBUSTO PER CONTAINER ---
echo "[5/5] Avvio del server web Apache in background..."

# Usiamo 'service' che è più robusto e compatibile.
# Reindirizziamo l'output per eliminare il warning AH00558
sudo service apache2 start 2>&1 > /dev/null

# Controlla che Apache sia in esecuzione
if pgrep apache2 > /dev/null
then
    echo "[5/5] Apache avviato correttamente in background."
else
    # Questo controllo è cruciale. Se fallisce, usciamo
    echo "❌ ERRORE FATALE: Impossibile avviare il servizio Apache. Esco."
    exit 1
fi


echo "**************************************************"
echo "✅ CONFIGURAZIONE PGADMIN COMPLETATA E SERVIZIO AVVIATO!"
echo "Ora dovresti poter accedere a /pgadmin4 con l'utente: $MY_EMAIL"
echo "**************************************************"
