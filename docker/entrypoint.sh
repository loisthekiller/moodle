#!/bin/bash
set -e

CONFIG=/var/www/html/config.php

# ─── 1. Esperar a que la DB esté disponible ──────────────────
echo "[entrypoint] Esperando base de datos en ${MOODLE_DATABASE_HOST}..."
until php -r "
  \$conn = @mysqli_connect(
    '${MOODLE_DATABASE_HOST}',
    '${MOODLE_DATABASE_USER}',
    '${MOODLE_DATABASE_PASSWORD}',
    '${MOODLE_DATABASE_NAME}'
  );
  exit(\$conn ? 0 : 1);
"; do
  echo "[entrypoint] DB no disponible, reintentando en 3s..."
  sleep 3
done
echo "[entrypoint] DB lista."

# ─── 2. Generar config.php si no existe ──────────────────────
if [ ! -f "$CONFIG" ]; then
  cat > "$CONFIG" <<EOF
<?php
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'mariadb';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = '${MOODLE_DATABASE_HOST}';
\$CFG->dbname    = '${MOODLE_DATABASE_NAME}';
\$CFG->dbuser    = '${MOODLE_DATABASE_USER}';
\$CFG->dbpass    = '${MOODLE_DATABASE_PASSWORD}';
\$CFG->prefix    = 'mdl_';

\$CFG->wwwroot   = '${MOODLE_WWWROOT:-http://localhost:8080}';
\$CFG->dataroot  = '/var/moodledata';
\$CFG->admin     = 'admin';

\$CFG->directorypermissions = 02750;

require_once(__DIR__ . '/lib/setup.php');
EOF
  echo "[entrypoint] config.php generado."
fi

# ─── 3. Permisos ─────────────────────────────────────────────
chown -R www-data:www-data /var/moodledata
chmod 750 /var/moodledata

# ─── 4. Instalar Moodle si no fue instalado aún ──────────────
# Se detecta si las tablas ya existen consultando mdl_config
INSTALLED=$(php -r "
  \$conn = mysqli_connect(
    '${MOODLE_DATABASE_HOST}',
    '${MOODLE_DATABASE_USER}',
    '${MOODLE_DATABASE_PASSWORD}',
    '${MOODLE_DATABASE_NAME}'
  );
  \$result = mysqli_query(\$conn, \"SHOW TABLES LIKE 'mdl_config'\");
  echo mysqli_num_rows(\$result);
")

if [ "$INSTALLED" = "0" ]; then
  echo "[entrypoint] Primera instalación, corriendo installer..."
  _ADMIN_USER="${MOODLE_ADMIN_USER:-admin}"
  _ADMIN_PASS="${MOODLE_ADMIN_PASSWORD:-Admin1234!}"
  _ADMIN_EMAIL="${MOODLE_ADMIN_EMAIL:-admin@example.com}"
  _SITE_NAME="${MOODLE_SITE_NAME:-Mi Moodle}"
  _SITE_SHORT="${MOODLE_SITE_SHORTNAME:-moodle}"
  su -s /bin/bash www-data -c "php /var/www/html/admin/cli/install_database.php \
    --lang=es \
    --adminuser='$_ADMIN_USER' \
    --adminpass='$_ADMIN_PASS' \
    --adminemail='$_ADMIN_EMAIL' \
    --fullname='$_SITE_NAME' \
    --shortname='$_SITE_SHORT' \
    --agree-license"
  echo "[entrypoint] Instalación completada."
else
  echo "[entrypoint] Moodle ya instalado, saltando installer."
fi

# ─── 5. Configurar cron (recomendado cada minuto) ────────────
echo "* * * * * www-data php /var/www/html/public/admin/cli/cron.php > /dev/null 2>&1" \
  > /etc/cron.d/moodle
chmod 0644 /etc/cron.d/moodle
cron

# ─── 6. Arrancar Apache ──────────────────────────────────────
echo "[entrypoint] Iniciando Apache..."
exec apache2-foreground