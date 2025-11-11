#!/usr/bin/env bash
# =========================================================
# install.sh — Installazione automatica di pgAdmin4 su Linux
# Compatibile con Python 3.12.12
# =========================================================

set -e

echo "=== [pgAdmin Setup] Avvio installazione pgAdmin 4 ==="

# Verifica versione Python
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "Trovato Python: $PYTHON_VERSION"

# Assicurati di avere pip
if ! command -v pip3 >/dev/null 2>&1; then
  echo "pip3 non trovato, installo..."
  sudo apt-get update -y
  sudo apt-get install -y python3-pip
fi

# Aggiorna pip
pip3 install --upgrade pip

# Installa dipendenze necessarie
sudo apt-get update -y
sudo apt-get install -y curl gnupg lsb-release

# Aggiungi repository ufficiale pgAdmin (se non già presente)
if ! grep -q "pgadmin.org" /etc/apt/sources.list.d/pgadmin.list 2>/dev/null; then
  curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | \
    sudo gpg --dearmor -o /usr/share/keyrings/pgadmin.gpg
  echo "deb [signed-by=/usr/share/keyrings/pgadmin.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" | \
    sudo tee /etc/apt/sources.list.d/pgadmin.list
fi

# Installa pgAdmin
sudo apt-get update -y
sudo apt-get install -y pgadmin4

echo "=== [pgAdmin Setup] pgAdmin installato ==="

# Configurazione locale (modalità standalone)
CONFIG_PATH="$HOME/.pgadmin_config_local.py"
if [ ! -f "$CONFIG_PATH" ]; then
cat <<EOF > "$CONFIG_PATH"
SERVER_MODE = False
DEFAULT_SERVER = '0.0.0.0'
DEFAULT_SERVER_PORT = 5050
EOF
fi

# Avvio pgAdmin
echo "=== [pgAdmin Setup] Avvio pgAdmin su porta 5050 ==="
nohup python3 /usr/pgadmin4/web/pgAdmin4.py --config "$CONFIG_PATH" > "$HOME/pgadmin.log" 2>&1 &

echo "=== [pgAdmin Setup] Installazione completata! ==="
echo "pgAdmin è disponibile su: http://localhost:5050"
