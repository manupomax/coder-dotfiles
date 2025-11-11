#!/bin/bash

echo "=== [pgAdmin Setup] Avvio installazione pgAdmin 4 ==="

# Controllo versione Python
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python rilevato: $PYTHON_VERSION"

# Aggiorna il sistema
sudo apt-get update -y
sudo apt-get upgrade -y

# Installazione dipendenze
sudo apt-get install -y curl wget ca-certificates gnupg

# Aggiungi il repository di pgAdmin
curl https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/pgadmin.gpg
echo "deb [signed-by=/usr/share/keyrings/pgadmin.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" | sudo tee /etc/apt/sources.list.d/pgadmin4.list

# Aggiorna repository
sudo apt-get update -y

# Installazione pgAdmin4 in server mode senza interazione
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y pgadmin4-web

# Configura pgAdmin4 in server mode automaticamente
sudo /usr/pgadmin4/bin/setup-web.sh <<EOF
admin@admin.com
admin@2025
EOF

# Riavvia Apache
sudo systemctl restart apache2

echo "=== [pgAdmin Setup] pgAdmin installato ==="
