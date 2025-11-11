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

export DEBIAN_FRONTEND=noninteractive
PGADMIN_HOME="/usr/pgadmin4" 

# --- 2. INSTALLAZIONE REPOSITORY E PREREQUISITI ---
echo "[1/6] Aggiornamento pacchetti e installazione prerequisiti..."
# Assicurati che 'python3-pip' sia installato per usare pip3
sudo apt-get update
sudo apt-get install -y curl ca-certificates gnupg python3-pip

# Aggiunta del repository pgAdmin e installazione del pacchetto 'pgadmin4'
sudo curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/pgadmin4-archive-keyring.gpg
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/pgadmin4-archive-keyring.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'
sudo apt-get update
sudo apt-get install -y pgadmin4

echo "[1/6] Installazione completata."


# --- 3. INSTALLAZIONE DIPENDENZA MANCANTE ('typer') ---
echo "[2/6] Installazione forzata della dipendenza Python 'typer' nell'ambiente di sistema..."
# **CRUCIALE:** Ripristiniamo l'uso di SUDO per installare Typer a livello globale.
# Questo è l'unico modo per garantire che /usr/bin/python3 lo trovi sempre.

# Pulizia di qualsiasi installazione precedente (per evitare conflitti)
sudo pip3 uninstall typer -y || true

# Installazione forzata a livello di sistema
sudo pip3 install typer

echo "[2/6] Dipendenza 'typer' installata a livello di sistema."


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


# --- 5. ESECUZIONE SETUP NON INTERATTIVO ---
echo "[4/6] Esecuzione di setup.py per creare l'utente..."

# **IMPORTANTE:** Rimuoviamo la manipolazione del PATH e eseguiamo direttamente.
# dato che Typer è stato installato a livello di sistema, il setup DEVE funzionare.
/usr/bin/python3 $PGADMIN_HOME/web/setup.py --yes --email "$MY_EMAIL" --password "$MY_PASSWORD"

echo "[4/6] Setup utente e database completato."


# --- 6. AVVIO DEL SERVER PGADMIN STANDALONE (PORTA 5050) ---
echo "[5/6] Avvio del server pgAdmin Standalone in background sulla Porta 5050..."

# Avvia il server Python in background
nohup /usr/bin/python3 $PGADMIN_HOME/web/pgAdmin4.py 2>&1 > pgadmin_server.log &

sleep 2

# Controlla che il processo sia attivo
if pgrep -f "pgAdmin4.py" > /dev/null
then
    echo "[5/6] Server pgAdmin avviato correttamente in background sulla porta 5050."
else
    echo "❌ ERRORE FATALE: Impossibile avviare pgAdmin4. Controlla il log 'pgadmin_server.log'."
    # Se fallisce qui, potresti dover lanciare 'pgAdmin4.py' manualmente per vedere l'errore
    exit 1
fi

echo "[6/6] Pulizia e verifica finale..."
rm -f nohup.out

echo "**************************************************"
echo "✅ CONFIGURAZIONE COMPLETATA! Il servizio è attivo sulla PORTA 5050."
echo "Accedi a: <URL del tuo Workspace>/ (Tunnel Coder per la Porta 5050)"
echo "Credenziali: $MY_EMAIL / $MY_PASSWORD"
echo "**************************************************"
