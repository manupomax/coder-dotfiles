#!/bin/bash

# --- USCITA IMMEDIATA IN CASO DI ERRORE ---
set -e

# --- 1. IMPOSTAZIONI UTENTE ---
MY_EMAIL="admin@example.com"
MY_PASSWORD="AdminSecret123!"
PGADMIN_HOME="/usr/pgadmin4" 

echo "**************************************************"
echo "AVVIO SCRIPT DOTFILE: Configurazione pgAdmin4 (Standalone - Porta 5050)"
echo "Utilizzo dei comandi ufficiali per il repository e risoluzione dei problemi ambientali."
echo "**************************************************"

export DEBIAN_FRONTEND=noninteractive

# --- 2. INSTALLAZIONE REPOSITORY E PREREQUISITI CRITICI ---
echo "[1/7] Aggiornamento pacchetti e installazione prerequisiti critici (Python e Nativi)..."

# 1. Installa i prerequisiti minimali (pip, curl, gnupg)
sudo apt-get update
sudo apt-get install -y curl ca-certificates gnupg python3-pip python3-dev

# 2. **INSTALLAZIONE MANUALE DI TUTTE LE LIBRERIE NATIVE MANCANTI**
# Risolve libnspr4, libgbm, libasound, ecc.
sudo apt-get install -y libnspr4 libnss3 libgbm1 libasound2 libgtk-3-0 libappindicator3-1

# 3. **UTILIZZO DEI COMANDI UFFICIALI PER CHIAVE E REPOSITORY**
echo "Aggiunta della chiave GPG e del repository ufficiale di pgAdmin..."

# Comando Ufficiale 1: Installa la chiave pubblica
curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg

# Comando Ufficiale 2: Crea il file di configurazione e aggiorna apt
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list && apt update'

# 4. Installazione del pacchetto pgadmin4
# Usiamo apt install pgadmin4 (come da documentazione ufficiale)
sudo apt install -y pgadmin4

echo "[1/7] Installazione apt completata."


# --- 3. INSTALLAZIONE FORZATA DI TUTTE LE DIPENDENZE PYTHON ---
echo "[2/7] Installazione forzata delle dipendenze Python (typer fix)..."
REQUIREMENTS_FILE="${PGADMIN_HOME}/requirements.txt"
if [ -f "$REQUIREMENTS_FILE" ]; then
    sudo pip3 install -r "$REQUIREMENTS_FILE" --ignore-installed || sudo pip3 install typer flask cryptography --ignore-installed
else
    sudo pip3 install typer flask cryptography --ignore-installed
fi
echo "[2/7] Dipendenze Python installate."


# --- 4. CONFIGURAZIONE PORTA E ACCESSO REMOTO ---
echo "[3/7] Configurazione di pgAdmin per Porta 5050 e accesso remoto..."
sudo rm -f "$PGADMIN_HOME/web/config_local.py"
sudo sh -c "cat > $PGADMIN_HOME/web/config_local.py" <<EOL
# File di configurazione locale generato da dotfiles
DEFAULT_SERVER = '0.0.0.0'
DEFAULT_SERVER_PORT = 5050
ALLOWED_HOSTS = ['*']
EOL
sudo chown $USER:$USER "$PGADMIN_HOME/web/config_local.py"
echo "[3/7] Configurazione completata."


# --- 5. ESECUZIONE SETUP CON VARIABILI INLINE ---
echo "[4/7] Esecuzione di setup-web.sh per creare l'utente..."
sudo PGADMIN_SETUP_EMAIL="$MY_EMAIL" \
     PGADMIN_SETUP_PASSWORD="$MY_PASSWORD" \
     "$PGADMIN_HOME/bin/setup-web.sh" --yes
echo "[4/7] Setup utente e database completato."


# --- 5.5. RISOLUZIONE DEL PERMESSO SUID CHROME-SANDBOX ---
echo "[5/7] Configurazione dei permessi SUID per il sandbox di sicurezza..."
SANDBOX_PATH="$PGADMIN_HOME/bin/chrome-sandbox"
sudo chown root:root "$SANDBOX_PATH"
sudo chmod 4755 "$SANDBOX_PATH"
echo "[5/7] Permessi SUID configurati."


# --- 6. AVVIO DEL SERVER PGADMIN STANDALONE (PORTA 5050) ---
echo "[6/7] Avvio del server pgAdmin Standalone in background sulla Porta 5050..."
nohup "$PGADMIN_HOME/bin/pgadmin4" 2>&1 > pgadmin_server.log &

sleep 2

# Controlla che il processo sia attivo
if pgrep -f "pgadmin4" > /dev/null
then
    echo "[6/7] Server pgAdmin avviato correttamente in background sulla porta 5050."
else
    echo "❌ ERRORE FATALE: Impossibile avviare pgAdmin4. Controlla il log 'pgadmin_server.log'."
    exit 1
fi

echo "[7/7] Pulizia e verifica finale..."
rm -f nohup.out

echo "**************************************************"
echo "✅ CONFIGURAZIONE COMPLETATA! Il servizio è attivo sulla PORTA 5050."
echo "Credenziali: $MY_EMAIL / $MY_PASSWORD"
echo "**************************************************"
