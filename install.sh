#!/bin/bash

# --- USCITA IMMEDIATA IN CASO DI ERRORE ---
set -e

# --- 1. IMPOSTAZIONI UTENTE ---
MY_EMAIL="admin@example.com"
MY_PASSWORD="AdminSecret123!"
PGADMIN_HOME="/usr/pgadmin4" 

echo "**************************************************"
echo "AVVIO SCRIPT DOTFILE: Configurazione pgAdmin4 (Standalone - Porta 5050)"
echo "**************************************************"

export DEBIAN_FRONTEND=noninteractive

# --- 2. INSTALLAZIONE REPOSITORY E PREREQUISITI ---
echo "[1/6] Aggiornamento pacchetti e installazione prerequisiti (pip, python3-dev)..."
sudo apt-get update
sudo apt-get install -y curl ca-certificates gnupg python3-pip python3-dev

# Aggiunta del repository pgAdmin e installazione del pacchetto 'pgadmin4'
sudo curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/pgadmin4-archive-keyring.gpg
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/pgadmin4-archive-keyring.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'
sudo apt-get update
sudo apt-get install -y pgadmin4

echo "[1/6] Installazione apt completata."


# --- 3. INSTALLAZIONE FORZATA DI TUTTE LE DIPENDENZE PGADMIN ---
echo "[2/6] Installazione forzata delle dipendenze Python (incluso 'typer')..."
REQUIREMENTS_FILE="${PGADMIN_HOME}/requirements.txt"

# Installazione aggressiva di tutte le dipendenze nel percorso di sistema
if [ -f "$REQUIREMENTS_FILE" ]; then
    echo "Trovato requirements.txt. Installazione delle dipendenze..."
    sudo pip3 install -r "$REQUIREMENTS_FILE" --ignore-installed || sudo pip3 install typer flask cryptography --ignore-installed
else
    echo "requirements.txt non trovato. Installazione delle dipendenze note essenziali (typer, Flask, ecc.)."
    sudo pip3 install typer flask cryptography --ignore-installed
fi

echo "[2/6] Dipendenze Python installate."


# --- 4. CONFIGURAZIONE PORTA E ACCESSO REMOTO ---
echo "[3/6] Configurazione di pgAdmin per Porta 5050 e accesso remoto..."
sudo rm -f "$PGADMIN_HOME/web/config_local.py"

# Scrive il file di configurazione con porta 5050 e accesso remoto
sudo sh -c "cat > $PGADMIN_HOME/web/config_local.py" <<EOL
# File di configurazione locale generato da dotfiles
DEFAULT_SERVER = '0.0.0.0'
DEFAULT_SERVER_PORT = 5050
ALLOWED_HOSTS = ['*']
EOL

sudo chown $USER:$USER "$PGADMIN_HOME/web/config_local.py"
echo "[3/6] Configurazione completata."


# --- 5. ESECUZIONE SETUP TRAMITE IL SUO AMBIENTE VIRTUALE ---
echo "[4/6] Esecuzione di setup-web.sh per creare l'utente..."

# **LA MODIFICA CRUCIALE:** Aggiunto 'sudo' per risolvere "This script must be run as root"
# Usiamo il wrapper di setup (che gestisce l'ambiente Python corretto) e lo eseguiamo come root.
sudo "$PGADMIN_HOME/bin/setup-web.sh" --yes --email "$MY_EMAIL" --password "$MY_PASSWORD"

echo "[4/6] Setup utente e database completato."


# --- 6. AVVIO DEL SERVER PGADMIN STANDALONE (PORTA 5050) ---
echo "[5/6] Avvio del server pgAdmin Standalone in background sulla Porta 5050..."

# Avviamo il server utilizzando il suo script di avvio designato, come utente Coder.
nohup "$PGADMIN_HOME/bin/pgadmin4" 2>&1 > pgadmin_server.log &

sleep 2

# Controlla che il processo sia attivo
if pgrep -f "pgadmin4" > /dev/null
then
    echo "[5/6] Server pgAdmin avviato correttamente in background sulla porta 5050."
else
    echo "❌ ERRORE FATALE: Impossibile avviare pgAdmin4. Controlla il log 'pgadmin_server.log'."
    exit 1
fi

echo "[6/6] Pulizia e verifica finale..."
rm -f nohup.out

echo "**************************************************"
echo "✅ CONFIGURAZIONE COMPLETATA! Il servizio è attivo sulla PORTA 5050."
echo "Credenziali: $MY_EMAIL / $MY_PASSWORD"
echo "**************************************************"
