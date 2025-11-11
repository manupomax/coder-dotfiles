#!/bin/bash

# --- USCITA IMMEDIATA IN CASO DI ERRORE ---
set -e

# --- 1. IMPOSTAZIONI UTENTE ---
MY_EMAIL="admin@example.com"
MY_PASSWORD="AdminSecret123!"

echo "**************************************************"
echo "AVVIO SCRIPT DOTFILE: Configurazione pgAdmin4 (Standalone - Porta 5050)"
echo "Utente admin che sarà creato: $MY_EMAIL"
echo "**************************************************"

# Imposta DEBIAN_FRONTEND per l'installazione non interattiva
export DEBIAN_FRONTEND=noninteractive
PGADMIN_HOME="/usr/pgadmin4" # Percorso standard di installazione

# --- 2. INSTALLAZIONE REPOSITORY E PGADMIN4 STANDALONE ---
# Installiamo 'pgadmin4' al posto di 'pgadmin4-web'
echo "[1/4] Installazione pgAdmin4 e configurazione repository..."
sudo apt-get update
sudo apt-get install -y curl ca-certificates gnupg

# Aggiunta del repository pgAdmin
sudo curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/pgadmin4-archive-keyring.gpg
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/pgadmin4-archive-keyring.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'

# Installazione del pacchetto 'pgadmin4' (Standalone/Desktop)
sudo apt-get update
sudo apt-get install -y pgadmin4

echo "[1/4] Installazione completata. Apache NON installato/avviato."


# --- 3. CONFIGURAZIONE PORTA E ACCESSO REMOTO ---
# Creiamo un file di configurazione locale per sovrascrivere le impostazioni predefinite
echo "[2/4] Configurazione di pgAdmin per Porta 5050 e accesso remoto..."

# Rimuovi eventuali configurazioni precedenti di pgadmin4-web
sudo rm -f "$PGADMIN_HOME/web/config_local.py"

# Scrive il file di configurazione
sudo sh -c "cat > $PGADMIN_HOME/web/config_local.py" <<EOL
# File di configurazione locale generato da dotfiles
# Porta di ascolto (richiesta dall'utente)
DEFAULT_SERVER = '0.0.0.0'
DEFAULT_SERVER_PORT = 5050
# Disabilita il controllo di sicurezza per gli host consentiti
ALLOWED_HOSTS = ['*']
EOL

# Diamo la proprietà del file di configurazione all'utente Coder
sudo chown $USER:$USER "$PGADMIN_HOME/web/config_local.py"
echo "[2/4] Configurazione completata."


# --- 4. ESECUZIONE SETUP NON INTERATTIVO E AVVIO ---
echo "[3/4] Esecuzione di setup-web.sh per creare l'utente..."

# SETUP UTENTE: Eseguiamo il setup come l'utente Coder ($USER), NON come root.
# Questo è necessario perché setup-web.sh configura il database SQLite
# nella home dell'utente che esegue lo script in modalità standalone.
/usr/bin/python3 $PGADMIN_HOME/web/setup.py --yes --email "$MY_EMAIL" --password "$MY_PASSWORD"

# Nota: in modalità standalone, lo script di setup NON avvia un server e NON tenta systemctl.

echo "[3/4] Setup utente e database completato."


# --- 5. AVVIO DEL SERVER PGADMIN STANDALONE (PORTA 5050) ---
echo "[4/4] Avvio del server pgAdmin Standalone in background sulla Porta 5050..."

# Avvia il server Python in background, reindirizzando l'output su un log file
# per evitare di bloccare lo script Coder.
nohup /usr/bin/python3 $PGADMIN_HOME/web/pgAdmin4.py 2>&1 > /dev/null &

# Controlla che il processo sia attivo
if pgrep -f "pgAdmin4.py" > /dev/null
then
    echo "[4/4] Server pgAdmin avviato correttamente in background sulla porta 5050."
else
    echo "❌ ERRORE FATALE: Impossibile avviare pgAdmin4. Esco."
    exit 1
fi


echo "**************************************************"
echo "✅ CONFIGURAZIONE COMPLETATA! Il servizio è attivo sulla PORTA 5050."
echo "Accedi a: <URL del tuo Workspace>/ (Il tunnel Coder per 5050)"
echo "Credenziali: $MY_EMAIL / $MY_PASSWORD"
echo "**************************************************"
