#!/usr/bin/env bash
# =========================================================
# install.sh — Installazione pgAdmin4 in server mode su Linux
# Ottimizzato per Coder (Python 3.10+, port forwarding)
# =========================================================

set -e

echo "=== [pgAdmin Setup] Avvio installazione pgAdmin 4 ==="

# Controllo versione Python
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python rilevato: $PYTHON_VERSION"
if [[ "$PYTHON_VERSION" != "3.10."* && "$PYTHON_VERSION" != "3.11."* && "$PYTHON_VERSION" != "3.12."* ]]; then
    echo "Attenzione: versione Python non standard, potrebbero esserci problemi di compatibilità"
fi

# Aggiorna pacchetti e installa dipendenze
sudo apt-get update -y
sudo apt-get install -y curl gnupg lsb-release python3-pip netcat

# Aggiorna pip
pip3 install --upgrade pip

# Aggiungi repository ufficiale pgAdmin (se non presente)
if ! grep -q "pgadmin.org" /etc/apt/sources.list.d/pgadmin.list 2>/dev/null; then
  curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | \
    sudo gpg --dearmor -o /usr/share/keyrings/pgadmin.gpg
  echo "deb [signed-by=/usr/share/keyrings/pgadmin.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" | \
    sudo tee /etc/apt/sources.list.d/pgadmin.list
fi

# Installa pgAdmin (ultima versione disponibile)
sudo apt-get update -y
sudo apt-get install -y pgadmin4

echo "=== [pgAdmin Setup] pgAdmin installato ==="

# Configurazione server mode
CONFIG_PATH="$HOME/.pgadmin_config_local.py"
if [ ! -f "$CONFIG_PATH" ]; then
cat <<EOF > "$CONFIG_PATH"
SERVER_MODE = True
DEFAULT_SERVER = '0.0.0.0'
DEFAULT_SERVER_PORT = 5050
EOF
fi

# Imposta variabili ambiente per server mode
export PGADMIN_CONFIG_SERVER_MODE=True
export PGADMIN_CONFIG_DEFAULT_SERVER='0.0.0.0'
export PGADMIN_CONFIG_DEFAULT_SERVER_PORT=5050

# Avvio pgAdmin in background
echo "=== [pgAdmin Setup] Avvio pgAdmin in SERVER MODE su 0.0.0.0:5050 ==="
nohup python3 /usr/pgadmin4/web/pgAdmin4.py --config "$CONFIG_PATH" > ~/pgadmin.log 2>&1 &

echo "=== [pgAdmin Setup] pgAdmin avviato in background ==="
echo "Attendere qualche secondo affinché il server sia pronto."
echo "Accedi a pgAdmin tramite il port forwarding di Coder sulla porta 5050."
echo "Controlla l'URL pubblico generato nella sezione Ports del workspace Coder."
