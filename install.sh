#!/bin/bash
set -euo pipefail

# --- CONFIGURAZIONE ---
ADMIN_EMAIL="admin@example.com"
ADMIN_PASSWORD="AdminSecret123!"
WEB_DIR="/usr/pgadmin4/web"
# -----------------------

# 1) Installa dipendenze e repository pgAdmin
apt-get update -y
apt-get install -y curl wget ca-certificates gnupg python3 python3-venv python3-pip

curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub | gpg --dearmor -o /usr/share/keyrings/pgadmin.gpg
DIST_CODENAME=$(lsb_release -cs || echo "focal")
echo "deb [signed-by=/usr/share/keyrings/pgadmin.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/${DIST_CODENAME} pgadmin4 main" \
  > /etc/apt/sources.list.d/pgadmin4.list

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y pgadmin4-web

# 2) Crea config_local.py
CONFIG_LOCAL="${WEB_DIR}/config_local.py"
cat > "${CONFIG_LOCAL}" <<EOF
SERVER_MODE = True
SQLITE_PATH = '/var/lib/pgadmin/pgadmin4.db'
SESSION_DB_PATH = '/var/lib/pgadmin/pgadmin4_session'
STORAGE_DIR = '/var/lib/pgadmin/storage'
LOG_FILE = '/var/log/pgadmin/pgadmin4.log'
EOF

mkdir -p /var/lib/pgadmin /var/lib/pgadmin/storage /var/log/pgadmin
chown -R www-data:www-data /var/lib/pgadmin /var/log/pgadmin
chmod 750 /var/lib/pgadmin /var/log/pgadmin

# 3) Ambiente virtuale temporaneo per usare l’API di pgAdmin
TMP_VENV="/tmp/pgadmin-venv-$$"
python3 -m venv "${TMP_VENV}"
source "${TMP_VENV}/bin/activate"
pip install --upgrade pip setuptools wheel > /dev/null

# 4) Script Python per creare l'utente admin
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

# 5) Pulizia
deactivate
rm -rf "${TMP_VENV}" /tmp/pgadmin_create_admin.py

# 6) Riavvio web server
if systemctl is-enabled --quiet apache2; then
  systemctl restart apache2 || true
fi
if systemctl is-enabled --quiet httpd; then
  systemctl restart httpd || true
fi

echo "Installazione pgAdmin 4 completata. Accedi con ${ADMIN_EMAIL}"
