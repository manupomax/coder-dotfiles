#!/bin/bash
# Script per l'installazione non interattiva di pgAdmin 4 in Server Mode

# --- Configurazioni Iniziali ---
PGADMIN_EMAIL="admin@esempio.com"      # L'email che userai per accedere
PGADMIN_PASSWORD="la_tua_password_segreta" # La password che userai per accedere
PGADMIN_PORT=5050                      # La porta che hai richiesto

echo "Aggiornamento pacchetti e installazione prerequisiti..."
sudo apt update -y
sudo apt install -y curl ca-certificates gnupg

# --- 1. Aggiunta del Repository Ufficiale di pgAdmin ---
# Ottiene la chiave pubblica del repository
curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg

# Aggiunge il repository pgAdmin 4
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'

# Aggiorna l'indice dei pacchetti per includere il nuovo repository
sudo apt update -y

# --- 2. Installazione di pgAdmin 4 in Server Mode ---
echo "Installazione di pgAdmin 4..."
# L'installazione di 'pgadmin4-web' installa pgAdmin in modalità server/web
sudo apt install -y pgadmin4-web

# --- 3. Configurazione Non Interattiva dell'Utente Iniziale ---
echo "Configurazione non interattiva dell'utente iniziale..."
# Lo script setup-web.sh è interattivo per impostazione predefinita.
# Si possono evitare le richieste impostando le variabili d'ambiente
# PGADMIN_SETUP_EMAIL e PGADMIN_SETUP_PASSWORD, e aggiungendo l'opzione --yes (-y)
sudo env PGADMIN_SETUP_EMAIL="${PGADMIN_EMAIL}" PGADMIN_SETUP_PASSWORD="${PGADMIN_PASSWORD}" /usr/pgadmin4/bin/setup-web.sh --yes

# --- 4. Configurazione della Porta e dell'Interfaccia (Opzionale ma Raccomandata) ---
echo "Configurazione di pgAdmin per l'ascolto su porta ${PGADMIN_PORT}..."
# In modalità server, pgAdmin utilizza il file /etc/pgadmin4/config_local.py
# Modifichiamo questo file per impostare l'interfaccia e la porta che hai richiesto (5050)
PGADMIN_CONFIG_FILE="/etc/pgadmin4/config_local.py"

# Aggiunge le configurazioni necessarie
# BIND_ALL = True permette di accettare connessioni da qualsiasi IP (necessario in Coder)
# DEFAULT_SERVER_PORT specifica la porta 5050
sudo sh -c "cat <<EOF > ${PGADMIN_CONFIG_FILE}
# Configurazione personalizzata per Coder Workspace
# Rendere accessibile pgAdmin dall'esterno del localhost (tipico in container/workspace)
DEFAULT_SERVER = '0.0.0.0'
# Imposta la porta richiesta
DEFAULT_SERVER_PORT = ${PGADMIN_PORT}
EOF"

# --- 5. Riavvio del Servizio ---
echo "Riavvio del servizio pgAdmin 4 per applicare le modifiche..."
# Il servizio si chiama tipicamente apache2 o gunicorn a seconda della configurazione predefinita.
# La configurazione APT installa pgAdmin sotto Apache2 o Gunicorn, qui assumiamo l'uso di Apache2 (comune)
# Se stai usando una configurazione minimale (senza web server completo), potresti dover usare un comando diverso.
# Tuttavia, l'installazione 'pgadmin4-web' di solito configura un servizio web.

# Tentativo di riavvio del servizio pgadmin4/apache2
if sudo systemctl is-active --quiet pgadmin4; then
    sudo systemctl restart pgadmin4
elif sudo systemctl is-active --quiet apache2; then
    sudo systemctl restart apache2
fi

echo "✅ pgAdmin 4 in Server Mode installato e configurato."
echo "   - Email Amministratore: ${PGADMIN_EMAIL}"
echo "   - Password Amministratore: ${PGADMIN_PASSWORD}"
echo "   - Accessibile sulla porta: ${PGADMIN_PORT}"
