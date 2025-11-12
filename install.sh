#!/bin/bash
# Script per l'installazione non interattiva di pgAdmin 4 in Server Mode tramite PIP/VENV per Coder
# Tutti i comandi apt sono stati sostituiti con apt-get

# --- Configurazioni Utente ---
PGADMIN_EMAIL="admin@esempio.com"
PGADMIN_PASSWORD="la_tua_password_segreta"
PGADMIN_PORT=5050

# --- Percorsi Controllati ---
PGADMIN_HOME="/opt/pgadmin4" # Directory di installazione controllata
PGADMIN_VENV="${PGADMIN_HOME}/venv"
PGADMIN_CONFIG_DIR="${PGADMIN_HOME}/config"
PGADMIN_LOG_DIR="${PGADMIN_HOME}/log"
PGADMIN_STORAGE_DIR="${PGADMIN_HOME}/storage"
PGADMIN_CONFIG_FILE="${PGADMIN_CONFIG_DIR}/config_local.py"

echo "Aggiornamento pacchetti e installazione prerequisiti..."
# Uso di apt-get
sudo apt-get update -y
# Uso di apt-get
sudo apt-get install -y python3 python3-pip python3-venv libpq-dev libgmp3-dev build-essential

# --- 1. Creazione e Attivazione dell'Ambiente Virtuale (VENV) ---
echo "Creazione dell'ambiente virtuale in ${PGADMIN_VENV}..."
sudo mkdir -p "${PGADMIN_HOME}"
sudo chown -R "$(whoami)" "${PGADMIN_HOME}" # Assicuriamo i permessi all'utente del workspace

python3 -m venv "${PGADMIN_VENV}"
source "${PGADMIN_VENV}/bin/activate"

# --- 2. Installazione di pgAdmin 4 e Gunicorn tramite PIP ---
echo "Installazione di pgAdmin 4 e Gunicorn..."
# Installiamo pgAdmin 4 e Gunicorn (il server WSGI per l'esecuzione)
pip install pgadmin4 gunicorn

# --- 3. Creazione delle Directory di Runtime e Configurazione ---
echo "Creazione delle directory di runtime necessarie..."
mkdir -p "${PGADMIN_CONFIG_DIR}"
mkdir -p "${PGADMIN_LOG_DIR}"
mkdir -p "${PGADMIN_STORAGE_DIR}"

# --- 4. Configurazione della Porta e dell'Interfaccia ---
echo "Creazione di config_local.py per l'ascolto su 0.0.0.0:${PGADMIN_PORT}..."

# Creiamo il file di configurazione per impostare i percorsi e la porta
cat <<EOF > "${PGADMIN_CONFIG_FILE}"
# Configurazione personalizzata per Coder Workspace (VENV/PIP)
import os

# Imposta i percorsi delle directory create da noi
DATA_DIR = os.path.realpath(os.path.expanduser(u'${PGADMIN_CONFIG_DIR}'))
LOG_FILE = os.path.join(DATA_DIR, 'pgadmin4.log')
SQLITE_PATH = os.path.join(DATA_DIR, 'pgadmin4.db') # Database di configurazione
SESSION_DB_PATH = os.path.join(DATA_DIR, 'sessions')
STORAGE_DIR = os.path.realpath(os.path.expanduser(u'${PGADMIN_STORAGE_DIR}'))

# Interfaccia e Porta per l'accesso remoto (0.0.0.0)
DEFAULT_SERVER = '0.0.0.0'
DEFAULT_SERVER_PORT = ${PGADMIN_PORT}

# Aggiunge il percorso di configurazione all'ambiente Python
import sys
sys.path.append('${PGADMIN_CONFIG_DIR}')
EOF

# --- 5. Configurazione Non Interattiva dell'Utente Iniziale ---
echo "Configurazione non interattiva dell'utente iniziale..."
PGADMIN_PACKAGE_DIR=$(python -c "import pgadmin4; print(pgadmin4.__file__)" | sed 's/__init__.pyc?//')

# Settiamo le variabili d'ambiente per il setup non interattivo
export PGADMIN_SETUP_EMAIL="${PGADMIN_EMAIL}"
export PGADMIN_SETUP_PASSWORD="${PGADMIN_PASSWORD}"

# Eseguiamo il setup del database (che legge le variabili d'ambiente per l'utente)
python "${PGADMIN_PACKAGE_DIR}/setup.py"

# --- 6. Avvio Manuale di pgAdmin 4 con Gunicorn ---
echo "Avvio manuale di pgAdmin 4 in background con Gunicorn sulla porta ${PGADMIN_PORT}..."

# Avvia Gunicorn in background (`nohup ... &`) utilizzando l'app pgAdmin4
nohup gunicorn \
    --bind "0.0.0.0:${PGADMIN_PORT}" \
    --workers=1 \
    --threads=25 \
    --daemon \
    --chdir "${PGADMIN_PACKAGE_DIR}" \
    pgAdmin4:app > "${PGADMIN_LOG_DIR}/gunicorn.log" 2>&1 &

# Disattiviamo l'ambiente virtuale
deactivate

echo "🎉 pgAdmin 4 avviato in background sulla porta ${PGADMIN_PORT}."
echo "   - Accesso con: Email: ${PGADMIN_EMAIL} | Password: ${PGADMIN_PASSWORD}"
echo "   - Log di Gunicorn: ${PGADMIN_LOG_DIR}/gunicorn.log"
echo "✅ Script di installazione pgAdmin 4 completato."
