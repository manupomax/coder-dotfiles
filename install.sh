#!/bin/bash

# --- USCITA IMMEDIATA IN CASO DI ERRORE ---
set -e

# --- 1. IMPOSTAZIONI UTENTE ---
MY_EMAIL="admin@example.com"
MY_PASSWORD="AdminSecret123!"
PGADMIN_HOME="/usr/local/lib/python3.10/dist-packages/pgadmin4" # Percorso standard PIP
PGADMIN_SERVER_BIN="/usr/local/bin/pgadmin4" # Binario di avvio PIP

echo "**************************************************"
echo "AVVIO SCRIPT DOTFILE: Configurazione pgAdmin4 (MODALITÀ FLASK/PIP - Porta 5050)"
echo "Metodo più pulito per ambienti Headless (bypassa problemi APT/Grafici)."
echo "**************************************************"

export DEBIAN_FRONTEND=noninteractive

# --- 2. INSTALLAZIONE PREREQUISITI E DIPENDENZE NATIVE ---
echo "[1/6] Aggiornamento pacchetti e installazione prerequisiti (pip, python3-dev, native)..."

sudo apt-get update
# Installiamo le dipendenze minimali + quelle native che sappiamo mancano
sudo apt-get install -y curl ca-certificates gnupg python3-pip python3-dev \
    libpq-dev # Necessario per il driver PostgreSQL Python
    
echo "[1/6] Installazione prerequisiti completata."


# --- 3. INSTALLAZIONE PGADMIN VIA PIP E CORREZIONE DEL PERCORSO HOME ---
echo "[2/6] Installazione di pgAdmin4 tramite PIP (Modalità Server Pura)..."

# Installazione del pacchetto Python puro (questo include tutte le dipendenze Python come typer)
sudo pip3 install pgadmin4
# Aggiunta di un'altra dipendenza comune
sudo pip3 install psycopg2-binary

echo "[2/6] pgAdmin4 installato tramite PIP."


# --- 4. CONFIGURAZIONE PORTA E ACCESSO REMOTO (Modalità Server) ---
echo "[3/6] Configurazione di pgAdmin per Porta 5050 e accesso remoto..."

# Troviamo il percorso dinamico di installazione di pgAdmin (dipende dalla versione Python)
PGADMIN_WEB_PATH=$(python3 -c "import pgadmin4; import os; print(os.path.dirname(pgadmin4.__file__))")
if [ -z "$PGADMIN_WEB_PATH" ]; then
    echo "❌ ERRORE: Impossibile trovare il percorso di installazione di pgAdmin4.py."
    exit 1
fi

# Scrive il file di configurazione nel percorso PIP
sudo sh -c "cat > $PGADMIN_WEB_PATH/config_local.py" <<EOL
# File di configurazione locale generato da dotfiles
# Configura l'ambiente WSGI/Flask per l'accesso remoto
DEFAULT_SERVER = '0.0.0.0'
DEFAULT_SERVER_PORT = 5050
EOL

sudo chown $USER:$USER "$PGADMIN_WEB_PATH/config_local.py"
echo "[3/6] Configurazione completata."


# --- 5. ESECUZIONE SETUP E CREAZIONE UTENTE (Tramite binario PIP) ---
echo "[4/6] Esecuzione di setup-web (binario PIP) per creare l'utente..."
# Usiamo il binario di setup fornito da PIP, che usa le variabili d'ambiente
sudo PGADMIN_SETUP_EMAIL="$MY_EMAIL" \
     PGADMIN_SETUP_PASSWORD="$MY_PASSWORD" \
     "$PGADMIN_SERVER_BIN" --setup-web
echo "[4/6] Setup utente e database completato."


# --- 6. AVVIO DEL SERVER PGADMIN WEB (FLASK/WSGI) ---
echo "[5/6] Avvio del server pgAdmin WEB in background sulla Porta 5050..."

# Avviamo il server usando il binario fornito da PIP (che è configurato per avviare Flask)
nohup "$PGADMIN_SERVER_BIN" 2>&1 > pgadmin_server.log &

sleep 2

# Controlla che il processo Python/Flask sia attivo
if pgrep -f "$PGADMIN_SERVER_BIN" > /dev/null
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
