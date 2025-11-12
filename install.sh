#!/bin/bash
#
# Script per installare pgAdmin 4 in modalità server (Flask su 5050)
# in modo non interattivo, ideale per dotfiles di Coder.
#
# Esegue i seguenti passaggi:
# 1. Configura le variabili d'ambiente per l'utente admin.
# 2. Aggiunge il repository APT ufficiale di pgAdmin.
# 3. Installa 'pgadmin4-web' in modo non interattivo (DEBIAN_FRONTEND).
# 4. Sfrutta le variabili PGADMIN_SETUP_EMAIL/PASSWORD per automatizzare lo script
#    di setup di pgAdmin che viene eseguito durante l'installazione.
# 5. Disabilita e ferma il server 'apache2' (che è una dipendenza).
# 6. Corregge i permessi delle directory di configurazione e log.
# 7. Avvia il server Flask sulla porta 5050 e sull'indirizzo 0.0.0.0.
#

# --- INIZIO CONFIGURAZIONE UTENTE ---
# Modifica queste variabili per impostare l'utente admin di pgAdmin
PGADMIN_EMAIL="admin@example.com"
PGADMIN_PASSWORD="YourStrongPassword123!"
# --- FINE CONFIGURAZIONE UTENTE ---


# Interrompi lo script in caso di errori (e), stampa i comandi (x),
# e fallisci se una variabile non è impostata (u).
set -euo pipefail

echo "=== 1. Installazione prerequisiti (curl, gpg) ==="
sudo apt-get update
# lsb-release è necessario per $(lsb_release -cs)
sudo apt-get install -y curl gpg lsb-release

echo "=== 2. Aggiunta del repository APT ufficiale di pgAdmin ==="
# Importa la chiave GPG ufficiale di pgAdmin
curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg

# Aggiunge il repository alla lista dei sorgenti APT
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'

# Aggiorna l'elenco dei pacchetti dopo l'aggiunta del nuovo repo
sudo apt-get update

echo "=== 3. Installazione non interattiva di pgAdmin (pgadmin4-web) ==="
# Esporta le variabili d'ambiente. Lo script 'setup-web.sh' di pgAdmin,
# eseguito durante l'installazione del pacchetto, le rileverà e
# configurerà l'utente admin automaticamente.
export PGADMIN_SETUP_EMAIL="${PGADMIN_EMAIL}"
export PGADMIN_SETUP_PASSWORD="${PGADMIN_PASSWORD}"

# Imposta DEBIAN_FRONTEND=noninteractive per prevenire qualsiasi
# prompt interattivo da parte di apt o degli script di post-installazione.
export DEBIAN_FRONTEND=noninteractive

# Installa il pacchetto. Questo installerà anche 'apache2' come dipendenza
# e configurerà pgAdmin per funzionare con esso tramite WSGI.
sudo apt-get install -y pgadmin4-web

echo "=== 4. Disabilitazione e arresto di Apache2 ==="
# Il requisito è di usare il server Flask sulla 5050, non Apache sulla 80.
# Dobbiamo disabilitare il servizio Apache installato come dipendenza.
# Usiamo '|| true' per non far fallire lo script se systemctl non è
# disponibile o se il servizio non è in esecuzione (comune nei container).
# Gli errori "System has not been booted with systemd" sono normali qui.
sudo systemctl disable --now apache2 || true
sudo systemctl stop apache2 || true
sudo service apache2 stop || true # Comando di fallback per sistemi non-systemd

echo "=== 5. Pulizia (opzionale) ==="
sudo apt-get autoremove -y

echo "=== 6. Correzione dei permessi per l'utente ==="
# !! CORREZIONE FONDAMENTALE PER GLI ERRORI 'Permission denied' !!
# L'installazione crea /var/lib/pgadmin e /var/log/pgadmin come 'root'.
# Dobbiamo dare la proprietà di queste directory all'utente corrente ($USER)
# che sta eseguendo il server Flask, altrimenti l'avvio fallisce.
sudo mkdir -p /var/lib/pgadmin/sessions /var/lib/pgadmin/storage
sudo mkdir -p /var/log/pgadmin
sudo chown -R $USER:$USER /var/lib/pgadmin
sudo chown -R $USER:$USER /var/log/pgadmin

echo "Proprietà di /var/lib/pgadmin (database) e /var/log/pgadmin (log) assegnate a $USER."

echo "=== 7. Avvio del server pgAdmin in background (Flask) ==="

# !! IMPORTANTE: Imposta il server per ascoltare su 0.0.0.0 !!
# 0.0.0.0 significa "ascolta su tutte le interfacce di rete" ed è necessario
# per l'accesso esterno tramite il proxy di Coder.
export PGADMIN_LISTEN_ADDRESS="0.0.0.0"

# Avvia il server in background usando nohup e ridirigendo l'output
# a un file di log. Questo comando non bloccherà lo script.
#
# !! MODIFICA CHIAVE:
# Eseguiamo 'sh -c' per raggruppare due comandi:
# 1. cd /usr/pgadmin4/web/  ->  pgAdmin DEVE essere eseguito da qui.
# 2. /usr/pgadmin4/venv/bin/python3 ... -> Comando di avvio.
#
echo "Avvio di pgAdmin4.py dalla directory /usr/pgadmin4/web/..."
nohup sh -c 'cd /usr/pgadmin4/web && /usr/pgadmin4/venv/bin/python3 /usr/pgadmin4/web/pgAdmin4.py' > /tmp/pgadmin4.log 2>&1 &

echo "In attesa di 5 secondi per permettere al server di avviarsi..."
sleep 5

echo "=== 8. Verifica dello stato del server ==="
# Controlla se il processo è effettivamente in esecuzione.
if ! pgrep -f "pgAdmin4.py"; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!! ERRORE: Il processo pgAdmin4 non è riuscito ad avviarsi. !!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "L'errore 502 è probabilmente causato da questo."
    echo "Contenuto del log (/tmp/pgadmin4.log):"
    echo "--------------------------------------------------------------"
    cat /tmp/pgadmin4.log
    echo "--------------------------------------------------------------"
    exit 1
else
    echo "Successo: il processo pgAdmin4 è in esecuzione."
fi


echo "========================================"
echo " INSTALLAZIONE E AVVIO COMPLETATI "
echo "========================================"
echo
echo " Utente admin creato: ${PGADMIN_EMAIL}"
echo " Apache2 è stato disabilitato."
echo " Server Flask di pgAdmin avviato in background."
echo
echo "   >> pgAdmin è in esecuzione su http://<IP_TUO_WORKSPACE>:5050 <<"
echo
echo "Il log è disponibile in: /tmp/pgadmin4.log"
echo
echo "Assicurati di mappare la porta 5050 nel tuo workspace Coder."
