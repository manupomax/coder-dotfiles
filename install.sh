#!/bin/bash
set -euo pipefail

# --- CONFIGURAZIONE ---
ADMIN_EMAIL="admin@example.com"
ADMIN_PASSWORD="AdminSecret123!"
WEB_DIR="/usr/pgadmin4/web"
# -----------------------

echo "Aggiornamento sistema e installazione dipendenze..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y curl wget ca-certificates gnupg python3 python3-venv python3-pip apache2

echo "Aggiunta repository ufficiale pgAdmin..."
curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/pgadmin.gpg
DIST_CODENAME=$(lsb_release -cs || echo "focal")
echo "deb [signed-by=/usr/share/keyrings/pgadmin.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/${DIST_CODENAME} pgadmin4 main" \
  | sudo tee /etc/apt/sources.list.d/pgadmin4.list

sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y pgadmin4

echo "Creazione config_local.py..."
CONFIG_LOCAL="${WEB_DIR}/config_local.py"
sudo tee "${CONFIG_LOCAL}" > /dev/null <<EOF
SERVER_MODE = True
SQLITE_PATH = '/var/lib/pgadmin/pgadmin4.db'
SESSION_DB_PATH = '/var/lib/pgadmin/pgadmin4_session'
STORAGE_DIR = '/var/lib/pgadmin/storage'
LOG_FILE = '/var/log/pgadmin/pgadmin4.log'
EOF

sudo mkdir -p /var/lib/pgadmin /var/lib/pgadmin/storage /var/log/pgadmin
sudo chown -R www-data:www-data /var/lib/pgadmin /var/log/pgadmin
sudo chmod 750 /var/lib/pgadmin /var/log/pgadmin

echo "Creazione ambiente virtuale temporaneo per API pgAdmin..."
TMP_VENV="/tmp/pgadmin-venv-$$"
python3 -m venv "${TMP_VENV}"
source "${TMP_VENV}/bin/activate"
pip install --upgrade pip setuptools wheel > /dev/null

echo "Creazione utente admin in modalità non interattiva..."
cat > /tmp/pgadmin_create_admin.py <<'PY'
import os
from pgadmin import create_app
try:
    from pgadmin.model import db, User
except Exception:
    from pgadmin4.model import db, User

app = create_app()
with app.app_context():
    db.create_all()
    email = os.environ.get('PGADMIN_SETUP_EMAIL')
    passwd = os.environ.get('PGADMIN_SETUP_PASSWORD')
    if not email or not passwd:
        raise SystemExit("PGADMIN_SETUP_EMAIL e PGADMIN_SETUP_PASSWORD devono essere impostate come env var")
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

echo "Pulizia ambiente temporaneo..."
deactivate
rm -rf "${TMP_VENV}" /tmp/pgadmin_create_admin.py

echo "Riavvio Apache per applicare le modifiche..."
sudo systemctl restart apache2 || true

echo "Installazione pgAdmin 4 completata. Accedi con ${ADMIN_EMAIL}"
