#!/usr/bin/env bash
set -e

echo "=== [pgAdmin Setup] Avvio installazione pgAdmin 4 ==="

# Controllo versione Python
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python rilevato: $PYTHON_VERSION"
if [[ "$PYTHON_VERSION" != "3.10."* ]]; then
    echo "Attenzione: versione Python non 3.10.x, potrebbe non essere completamente supportata"
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

# Configurazione locale (standalone)
CONFIG_PATH="$HOME/.pgadmin_config_local.py"
if [ ! -f "$CONFIG_PATH" ]; then
cat <<EOF > "$CONFIG_PATH"
SERVER_MODE = False
DEFAULT_SERVER = '0.0.0.0'
DEFAULT_SERVER_PORT = 5050
EOF
fi

# Imposta variabili d'ambiente per forzare il bind su 0.0.0.0
export PGADMIN_LISTEN_ADDRESS=0.0.0.0
export PGADMIN_LISTEN_PORT=5050

# Avvio pgAdmin in background
nohup python3 /usr/pgadmin4/web/pgAdmin4.py --config "$CONFIG_PATH" > ~/pgadmin.log 2>&1 &

# Attendere che la porta sia pronta
echo "Attendo che pgAdmin sia pronto sulla porta 5050..."
while ! nc -z 0.0.0.0 5050; do
  sleep 1
done
echo "pgAdmin pronto! Puoi ora usare il port forwarding di Coder."
