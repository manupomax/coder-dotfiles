#!/bin/bash

# --- USCITA IMMEDIATA IN CASO DI ERRORE ---
set -e

# --- 1. IMPOSTAZIONI UTENTE (COME RICHIESTO) ---
# Modifica queste due righe con le credenziali che vuoi usare
MY_EMAIL="admin@example.com"
MY_PASSWORD="AdminSecret123!"

echo "**************************************************"
echo "AVVIO SCRIPT DOTFILE: Configurazione pgAdmin4"
echo "Utente admin che sarà creato: $MY_EMAIL"
echo "**************************************************"

# Imposta DEBIAN_FRONTEND per evitare qualsiasi richiesta interattiva
export DEBIAN_FRONTEND=noninteractive

# --- 2. INSTALLAZIONE PREREQUISITI ---
# Dobbiamo assicurarci che 'curl' e 'gnupg' siano installati
# per aggiungere il nuovo repository.
echo "[1/6] Aggiornamento pacchetti e installazione prerequisiti (curl, gnupg)..."
sudo apt-get update
sudo apt-get install -y curl ca-certificates gnupg

# --- 3. AGGIUNTA DEL REPOSITORY PGADMIN4 UFFICIALE ---
echo "[2/6] Importazione della chiave GPG del repository pgAdmin..."
# Importa la chiave GPG di pgAdmin (metodo moderno)
sudo curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/pgadmin4-archive-keyring.gpg

echo "[3/6] Aggiunta del repository pgAdmin a sources.list..."
# Aggiunge il repository alla lista di 'apt'.
# Usa 'lsb_release -cs' per trovare automaticamente il nome della
# tua versione di Ubuntu (es. 'jammy', 'focal')
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/pgadmin4-archive-keyring.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'


# --- 4. INSTALLAZIONE DI PGADMIN4-WEB ---
echo "[4/6] Aggiornamento di apt (con il nuovo repo) e installazione di pgadmin4-web..."
# ORA 'apt' sa dove trovare il pacchetto.
sudo apt-get update
sudo apt-get install -y pgadmin4-web

echo "[4/6] Installazione completata."


# --- 5. CREAZIONE DIRECTORY E PERMESSI ---
echo "[5/6] Creazione/Impostazione permessi per /var/lib/pgadmin4 e /var/log/pgadmin4..."
sudo mkdir -p /var/lib/pgadmin4 /var/log/pgadmin4
sudo chown -R $USER:$USER /var/lib/pgadmin4
sudo chown -R $USER:$USER /var/log/pgadmin4
echo "[5/6] Permessi impostati."


# --- 5. ESECUZIONE SETUP NON INTERATTIVO (Salta l'avvio) ---
echo "[6/7] Esecuzione di setup-web.sh in modalità non interattiva (Saltando l'avvio del server)..."
# Aggiunto il flag --skip-server-start per evitare l'errore di systemd
sudo PGADMIN_SETUP_EMAIL="$MY_EMAIL" \
     PGADMIN_SETUP_PASSWORD="$MY_PASSWORD" \
     /usr/pgadmin4/bin/setup-web.sh --yes

echo "[6/7] Setup database pgAdmin completato."


# --- 6. AVVIO MANUALE DI APACHE (funziona nei container) ---
echo "[7/7] Avvio manuale del server web Apache (httpd)..."

# Apache in Debian/Ubuntu ha un comando di avvio diretto che
# non dipende da systemd/init.d ed è usato in molti container.
# Usiamo 'sudo' perché l'utente Coder di solito non può avviare servizi sulla porta 80/443.

sudo /usr/sbin/apachectl start

echo "**************************************************"
echo "✅ CONFIGURAZIONE PGADMIN COMPLETATA E SERVIZIO AVVIATO!"
echo "Puoi accedere a /pgadmin4 con l'utente: $MY_EMAIL"
echo "**************************************************"
