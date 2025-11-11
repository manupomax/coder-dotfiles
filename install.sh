#!/bin/bash
# Script per l'installazione non interattiva di pgAdmin 4 in Server Mode per Coder

# --- Configurazioni Utente ---
PGADMIN_EMAIL="admin@esempio.com"
PGADMIN_PASSWORD="la_tua_password_segreta"
PGADMIN_PORT=5050

# --- Percorsi e File ---
PGADMIN_ROOT_DIR="/usr/pgadmin4"
PGADMIN_WEB_SETUP="${PGADMIN_ROOT_DIR}/bin/setup-web.sh"
PGADMIN_CONFIG_DIR="/etc/pgadmin4"
PGADMIN_CONFIG_FILE="${PGADMIN_CONFIG_DIR}/config_local.py"

echo "Aggiornamento pacchetti e installazione prerequisiti..."
sudo apt update -y
sudo apt install -y curl ca-certificates gnupg

# --- 1. Aggiunta del Repository e Installazione di pgAdmin 4 ---
echo "Installazione di pgAdmin 4 in Server Mode (via repository APT)..."
curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'
sudo apt update -y
# Installiamo solo la versione web, che non trascina dipendenze grafiche
sudo apt install -y pgadmin4-web

# --- 2. Creazione della Directory di Configurazione Mancante ---
echo "Creazione della directory di configurazione: ${PGADMIN_CONFIG_DIR}"
sudo mkdir -p "${PGADMIN_CONFIG_DIR}"

# --- 3. Configurazione Non Interattiva dell'Utente Iniziale ---
echo "Configurazione non interattiva dell'utente iniziale..."
# Eseguiamo lo script di setup che crea il DB interno (sqlite) e l'utente amministratore
if [ -f "${PGADMIN_WEB_SETUP}" ]; then
    sudo env PGADMIN_SETUP_EMAIL="${PGADMIN_EMAIL}" PGADMIN_SETUP_PASSWORD="${PGADMIN_PASSWORD}" "${PGADMIN_WEB_SETUP}" --yes
else
    echo "⚠️ Avviso: Lo script di setup non è stato trovato in ${PGADMIN_WEB_SETUP}. Procedi senza setup automatico."
fi

# --- 4. Configurazione della Porta e dell'Interfaccia ---
echo "Creazione di config_local.py per l'ascolto su 0.0.0.0:${PGADMIN_PORT}..."
# Creiamo il file di configurazione per impostare l'ascolto su tutti gli IP e la porta 5050
sudo sh -c "cat <<EOF > ${PGADMIN_CONFIG_FILE}
# Configurazione personalizzata per Coder Workspace
# Ascolta su tutti gli indirizzi (0.0.0.0) per essere accessibile dal container
DEFAULT_SERVER = '0.0.0.0'
# Imposta la porta richiesta
DEFAULT_SERVER_PORT = ${PGADMIN_PORT}
EOF"

# --- 5. Avvio Manuale di pgAdmin 4 (Bypass di systemd/Apache) ---
echo "Avvio manuale di pgAdmin 4 in background con Gunicorn..."

# L'installazione APT spesso usa Apache2 (che fallisce senza systemd).
# Cerchiamo il percorso del virtual environment/package per avviare il server Gunicorn direttamente.

# Percorso standard della webapp pgAdmin (può variare, ma è comune per APT)
PGADMIN_APP_PATH="/usr/share/pgadmin4"
PGADMIN_VENV="/usr/lib/pgadmin4/venv"

if [ -d "${PGADMIN_VENV}" ]; then
    # Avvia pgAdmin utilizzando l'eseguibile python all'interno del venv e Gunicorn
    # Lo facciamo in background (&) per non bloccare lo script di setup del workspace
    echo "Utilizzo dell'ambiente virtuale ${PGADMIN_VENV} per l'avvio."
    
    # Esegui Gunicorn in background con i parametri necessari
    # L'opzione `--daemon` non è usata per dare a Coder la possibilità di monitorare il processo.
    # Usiamo 'nohup' per assicurare che il processo sopravviva all'uscita dello script.
    
    nohup sudo "${PGADMIN_VENV}/bin/gunicorn" \
        --bind "0.0.0.0:${PGADMIN_PORT}" \
        --workers=1 \
        --threads=25 \
        --chdir "${PGADMIN_APP_PATH}" \
        pgAdmin4:app > /var/log/pgadmin4.log 2>&1 &
    
    echo "🎉 pgAdmin 4 avviato in background sulla porta ${PGADMIN_PORT}."
    echo "Controlla i log in /var/log/pgadmin4.log se non è raggiungibile."

else
    echo "❌ Errore: Ambiente virtuale di pgAdmin non trovato in ${PGADMIN_VENV}. Impossibile avviare manualmente."
    echo "Per ambienti non-systemd, l'installazione PIP/VENV è spesso più robusta."
fi

echo "✅ Script di installazione pgAdmin 4 completato."
