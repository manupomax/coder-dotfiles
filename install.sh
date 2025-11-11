#!/bin/bash
set -euo pipefail

# --- CONFIGURAZIONE ---
ADMIN_EMAIL="admin@example.com"
ADMIN_PASSWORD="AdminSecret123!"
INSTALL_DIR="/opt/pgadmin4"
VENV_DIR="${INSTALL_DIR}/venv"
DATA_DIR="/var/lib/pgadmin"
LOG_DIR="/var/log/pgadmin"
SERVICE_FILE="/etc/systemd/system/pgadmin4.service"
PGADMIN_PORT=5050
# -----------------------

echo "1. Aggiornamento sistema e installazione dipendenze..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y python3 python3-venv python3-pip apache2

echo "2. Creazione directory installazione e permessi..."
sudo mkdir -p "${INSTALL_DIR}" "${DATA_DIR}/storage" "${LOG_DIR}"
sudo chown -R $USER:$USER "${INSTALL_DIR}" "${DATA_DIR}" "${LOG_DIR}"
chmod -R 750 "${DATA_DIR}" "${LOG_DIR}"

echo "3. Creazione ambiente virtuale e installazione pgAdmin4..."
python3 -m venv "${VENV_DIR}"
source "${VENV_DIR}/bin/activate"
pip install --upgrade pip setuptools wheel
pip install pgadmin4

WEB_DIR="${VENV_DIR}/lib/python3*/site-packages/pgadmin4"

echo "4. Creazione config_local.py..."
cat > "${WEB_DIR}/config_local.py" <<EOF
SERVER_MODE = True
DEFAULT_SERVER = '0.0.0.0'
DEFAULT_SERVER_PORT = ${PGADMIN_PORT}
SQLITE_PATH = '${DATA_DIR}/pgadmin4.db'
SESSION_DB_PATH = '${DATA_DIR}/pgadmin4_session'
STORAGE_DIR = '${DATA_DIR}/storage'
LOG_FILE = '${LOG_DIR}/pgadmin4.log'
EOF

echo "5. Creazione utente admin non interattivo..."
cat > /tmp/pgadmin_create_admin.py <<'PY'
import os
from pgadmin import create_app
from pgadmin.model import db, User

app = create_app()
with app.app_context():
    db.create_all()
    email = os.environ['PGADMIN_SETUP_EMAIL']
    passwd = os.environ['PGADMIN_SETUP_PASSWORD']
    existing = User.query.filter_by(email=email).first()
    if existing:
        existing.set_password(passwd)
        existing.active = True
        existing.role = 'Administrator'
        db.session.commit()
        print("Utente aggiornato:", email)
    else:
        user = User(email=email, active=True, role='Administrator')
        user.set_password(passwd)
        db.session.add(user)
        db.session.commit()
        print("Utente creato:", email)
PY

export PGADMIN_SETUP_EMAIL="${ADMIN_EMAIL}"
export PGADMIN_SETUP_PASSWORD="${ADMIN_PASSWORD}"
python /tmp/pgadmin_create_admin.py
rm /tmp/pgadmin_create_admin.py
deactivate

echo "6. Creazione file di servizio systemd..."
sudo tee "${SERVICE_FILE}" > /dev/null <<EOF
[Unit]
Description=pgAdmin 4 Web Service
After=network.target

[Service]
Type=simple
User=$USER
Group=$USER
Environment="PATH=${VENV_DIR}/bin:/usr/bin:/bin"
WorkingDirectory=${INSTALL_DIR}
ExecStart=${VENV_DIR}/bin/python ${WEB_DIR}/pgAdmin4.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "7. Ricarica systemd e avvio servizio..."
sudo systemctl daemon-reload
sudo systemctl enable pgadmin4
sudo systemctl start pgadmin4

echo "Installazione completata!"
echo "Accedi a pgAdmin su http://<server>:${PGADMIN_PORT} con:"
echo "EMAIL: ${ADMIN_EMAIL}"
echo "PASSWORD: ${ADMIN_PASSWORD}"
