#!/usr/bin/env bash
# =============================================================================
#  install-vps.sh — Auto-installer guidato per Beach Project
#  VPS: 80.211.137.54  |  OS: Ubuntu 22.04 LTS
# =============================================================================
set -euo pipefail

# ── Colori ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Costanti ─────────────────────────────────────────────────────────────────
VPS_IP="80.211.137.54"
BASE_DOMAIN="${VPS_IP//./-}.sslip.io"
PROJECT_DIR="/opt/beach"

# ── Helper ───────────────────────────────────────────────────────────────────
step()    { echo -e "\n${BOLD}${BLUE}══════════════════════════════════════════════${NC}"; \
            echo -e "${BOLD}${BLUE}  STEP $1: $2${NC}"; \
            echo -e "${BOLD}${BLUE}══════════════════════════════════════════════${NC}"; }
ok()      { echo -e "  ${GREEN}✔  $*${NC}"; }
warn()    { echo -e "  ${YELLOW}⚠  $*${NC}"; }
err()     { echo -e "  ${RED}✖  $*${NC}"; }
info()    { echo -e "  ${CYAN}ℹ  $*${NC}"; }
pause()   { echo -e "\n${YELLOW}  Premi [INVIO] per continuare o Ctrl+C per interrompere…${NC}"; read -r; }
confirm() {
    local msg="$1"
    echo -e "\n${YELLOW}  ${msg} [s/N]: ${NC}\c"
    read -r ans
    [[ "$ans" =~ ^[sS]$ ]]
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        err "Questo script deve essere eseguito come root."
        echo "  Riesegui con: sudo bash $0"
        exit 1
    fi
}

# ── Banner ───────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
  ____                  _       ____            _           _
 | __ )  ___  __ _  ___| |__   |  _ \ _ __ ___ (_) ___  ___| |_
 |  _ \ / _ \/ _` |/ __| '_ \  | |_) | '__/ _ \| |/ _ \/ __| __|
 | |_) |  __/ (_| | (__| | | | |  __/| | | (_) | |  __/ (__| |_
 |____/ \___|\__,_|\___|_| |_| |_|   |_|  \___// |\___|\___|\__|
                                              |__/
         🏖  Auto-Installer VPS — 80.211.137.54
BANNER
echo -e "${NC}"
echo -e "  Questo script installa e configura l'intero progetto Beach sulla VPS."
echo -e "  Ogni passo richiede conferma. Puoi interrompere in qualsiasi momento."
echo -e "\n  ${BOLD}URL finali dopo l'installazione:${NC}"
echo -e "  🏠 Landing    → https://${BASE_DOMAIN}"
echo -e "  ⛱  Booking    → https://booking.${BASE_DOMAIN}"
echo -e "  🍹 Delivery   → https://delivery.${BASE_DOMAIN}"
echo -e "  🔌 API        → https://api-delivery.${BASE_DOMAIN}"
echo ""

check_root

# =============================================================================
#  RACCOLTA CONFIGURAZIONE INIZIALE
# =============================================================================
step "0" "Raccolta credenziali e configurazione"

echo -e "\n${BOLD}  Prima di iniziare, inserisci i valori di configurazione.${NC}"
echo -e "  Verranno usati per creare il file .env e i certificati SSL.\n"

# Email
echo -e "  ${CYAN}Email per Let's Encrypt (notifiche scadenza certificati):${NC}"
read -r -p "  > " CERTBOT_EMAIL
while [[ -z "$CERTBOT_EMAIL" || ! "$CERTBOT_EMAIL" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; do
    warn "Inserisci un indirizzo email valido."
    read -r -p "  > " CERTBOT_EMAIL
done

# Password MySQL root
echo -e "\n  ${CYAN}Password MySQL root (min 12 caratteri):${NC}"
read -r -s -p "  > " MYSQL_ROOT_PASS; echo ""
while [[ ${#MYSQL_ROOT_PASS} -lt 12 ]]; do
    warn "La password deve essere di almeno 12 caratteri."
    read -r -s -p "  > " MYSQL_ROOT_PASS; echo ""
done

# Password BeachBooking DB
echo -e "\n  ${CYAN}Password DB BeachBooking (min 12 caratteri):${NC}"
read -r -s -p "  > " BB_DB_PASS; echo ""
while [[ ${#BB_DB_PASS} -lt 12 ]]; do
    warn "La password deve essere di almeno 12 caratteri."
    read -r -s -p "  > " BB_DB_PASS; echo ""
done

# Password BeachDelivery DB
echo -e "\n  ${CYAN}Password DB BeachDelivery (min 12 caratteri):${NC}"
read -r -s -p "  > " BD_DB_PASS; echo ""
while [[ ${#BD_DB_PASS} -lt 12 ]]; do
    warn "La password deve essere di almeno 12 caratteri."
    read -r -s -p "  > " BD_DB_PASS; echo ""
done

# JWT secrets (generati automaticamente se non forniti)
BB_JWT=$(openssl rand -base64 48)
BD_JWT=$(openssl rand -base64 72)

# PayPal
echo -e "\n  ${CYAN}PayPal Client ID${NC} (lascia vuoto per configurare dopo):"
read -r -p "  > " PAYPAL_CLIENT_ID
echo -e "  ${CYAN}PayPal Client Secret${NC} (lascia vuoto per configurare dopo):"
read -r -p "  > " PAYPAL_CLIENT_SECRET

# Mail SMTP (opzionale)
echo -e "\n  ${CYAN}SMTP host per le email${NC} (lascia vuoto per saltare):"
read -r -p "  > " SMTP_HOST
SMTP_PORT="587"; SMTP_USER=""; SMTP_PASS=""
if [[ -n "$SMTP_HOST" ]]; then
    read -r -p "  SMTP porta [587]: " SMTP_PORT_IN
    SMTP_PORT="${SMTP_PORT_IN:-587}"
    read -r -p "  SMTP username: " SMTP_USER
    read -r -s -p "  SMTP password: " SMTP_PASS; echo ""
fi

echo -e "\n${GREEN}  ✔ Configurazione raccolta. Riepilogo:${NC}"
echo    "  ├─ Email SSL   : $CERTBOT_EMAIL"
echo    "  ├─ MySQL root  : ••••••••"
echo    "  ├─ BB DB pass  : ••••••••"
echo    "  ├─ BD DB pass  : ••••••••"
echo    "  ├─ PayPal ID   : ${PAYPAL_CLIENT_ID:-[da configurare]}"
echo    "  └─ SMTP host   : ${SMTP_HOST:-[non configurato]}"
pause

# =============================================================================
#  STEP 1 — Setup iniziale sistema
# =============================================================================
step "1" "Setup iniziale VPS"

if confirm "Aggiornare il sistema e installare i tool essenziali?"; then
    info "Aggiornamento pacchetti in corso…"
    apt update -qq && apt upgrade -y -qq
    apt install -y git curl wget ufw nano htop net-tools -qq
    timedatectl set-timezone Europe/Rome
    ok "Sistema aggiornato. Timezone: $(timedatectl show -p Timezone --value)"
else
    warn "Step saltato."
fi

# =============================================================================
#  STEP 2 — Installazione Docker
# =============================================================================
step "2" "Installazione Docker"

if command -v docker &>/dev/null; then
    ok "Docker già installato: $(docker --version)"
else
    if confirm "Installare Docker?"; then
        info "Download e installazione Docker…"
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker --quiet
        systemctl start docker
        ok "Docker installato: $(docker --version)"
        ok "Docker Compose: $(docker compose version)"
    else
        warn "Step saltato. Docker è obbligatorio per proseguire."
    fi
fi

# =============================================================================
#  STEP 3 — Installazione Nginx e Certbot
# =============================================================================
step "3" "Installazione Nginx e Certbot"

if confirm "Installare Nginx e Certbot?"; then
    # Ferma Apache se presente (occupa la porta 80)
    if systemctl is-active --quiet apache2 2>/dev/null; then
        warn "Apache2 rilevato sulla porta 80 — disabilitazione in corso…"
        systemctl stop apache2
        systemctl disable apache2
        ok "Apache2 disabilitato."
    fi

    apt install -y nginx certbot python3-certbot-nginx -qq
    systemctl enable nginx --quiet
    systemctl start nginx
    ok "Nginx installato e avviato: $(nginx -v 2>&1)"
    ok "Certbot installato: $(certbot --version)"
else
    warn "Step saltato."
fi

# =============================================================================
#  STEP 4 — Configurazione Firewall
# =============================================================================
step "4" "Configurazione Firewall (UFW)"

if confirm "Configurare il firewall UFW (22 SSH + 80 HTTP + 443 HTTPS)?"; then
    ufw allow 22   comment 'SSH'   >/dev/null
    ufw allow 80   comment 'HTTP'  >/dev/null
    ufw allow 443  comment 'HTTPS' >/dev/null
    # Abilita senza prompt interattivo
    ufw --force enable >/dev/null
    ok "Firewall attivo."
    ufw status | sed 's/^/    /'
else
    warn "Step saltato. Assicurati che le porte 22/80/443 siano aperte."
fi

# =============================================================================
#  STEP 5 — Verifica codice su VPS
# =============================================================================
step "5" "Verifica codice progetto in ${PROJECT_DIR}"

if [[ -f "${PROJECT_DIR}/docker-compose.yml" ]]; then
    ok "Codice già presente in ${PROJECT_DIR}."
else
    warn "Il codice non è ancora presente in ${PROJECT_DIR}."
    echo ""
    echo -e "  ${BOLD}Carica il progetto con uno di questi metodi dalla tua macchina locale:${NC}"
    echo ""
    echo -e "  ${CYAN}▶ PowerShell (Windows):${NC}"
    echo    "    scp -r C:\\CMP\\Personal\\beach root@${VPS_IP}:/opt/"
    echo ""
    echo -e "  ${CYAN}▶ Git Bash / WSL / Mac / Linux:${NC}"
    echo    "    rsync -avz --exclude='.git' --exclude='node_modules' \\"
    echo    "      --exclude='target' --exclude='.env' \\"
    echo    "      /path/to/beach/ root@${VPS_IP}:/opt/beach/"
    echo ""
    echo -e "  ${YELLOW}  Esegui il comando sopra in un'altra finestra, poi torna qui e premi INVIO.${NC}"
    pause

    if [[ ! -f "${PROJECT_DIR}/docker-compose.yml" ]]; then
        err "docker-compose.yml non trovato in ${PROJECT_DIR}. Verifica il caricamento."
        echo "  Interrompi lo script (Ctrl+C) e riprova dopo aver caricato il codice."
        exit 1
    fi
fi

ok "Struttura progetto:"
ls "${PROJECT_DIR}/" | sed 's/^/    /'

# =============================================================================
#  STEP 6 — Configurazione .env
# =============================================================================
step "6" "Configurazione file .env"

cd "${PROJECT_DIR}"

if [[ -f .env ]]; then
    warn ".env già esistente."
    if ! confirm "Sovrascrivere il .env esistente con i valori inseriti?"; then
        info ".env conservato. Salta la scrittura."
    else
        _write_env=true
    fi
else
    _write_env=true
fi

if [[ "${_write_env:-false}" == "true" ]]; then
    # Copia dal template se esiste, altrimenti crea da zero
    [[ -f .env.example ]] && cp .env.example .env

    cat > .env << ENVEOF
# ================================================================
# MYSQL CONDIVISO
# ================================================================
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASS}

# ================================================================
# BEACH BOOKING
# ================================================================
BEACHBOOKING_DB_PASSWORD=${BB_DB_PASS}
BEACHBOOKING_JWT_SECRET=${BB_JWT}

# PayPal
PAYPAL_CLIENT_ID=${PAYPAL_CLIENT_ID:-CONFIGURA_QUI}
PAYPAL_CLIENT_SECRET=${PAYPAL_CLIENT_SECRET:-CONFIGURA_QUI}
PAYPAL_BASE_URL=https://api-m.paypal.com
VITE_PAYPAL_CLIENT_ID=${PAYPAL_CLIENT_ID:-CONFIGURA_QUI}

# ================================================================
# BEACH DELIVERY
# ================================================================
BEACHDELIVERY_DB_PASSWORD=${BD_DB_PASS}
BEACHDELIVERY_JWT_SECRET=${BD_JWT}

BEACHDELIVERY_API_URL=https://api-delivery.${BASE_DOMAIN}
APP_CORS_ALLOWED_ORIGINS=https://delivery.${BASE_DOMAIN}
SPRING_JPA_HIBERNATE_DDL_AUTO=validate

# ================================================================
# MAIL (opzionale)
# ================================================================
SPRING_MAIL_HOST=${SMTP_HOST:-smtp.tuoprovider.com}
SPRING_MAIL_PORT=${SMTP_PORT:-587}
SPRING_MAIL_USERNAME=${SMTP_USER:-tua_email@dominio.com}
SPRING_MAIL_PASSWORD=${SMTP_PASS:-TuaPasswordEmail}
ENVEOF

    chmod 600 .env
    ok ".env creato con permessi 600."

    if [[ -z "${PAYPAL_CLIENT_ID}" ]]; then
        warn "PayPal non configurato. Modifica .env prima di avviare i container:"
        info "  nano ${PROJECT_DIR}/.env"
    fi
fi

# =============================================================================
#  STEP 7 — Configurazione Nginx Virtual Hosts
# =============================================================================
step "7" "Configurazione Nginx Virtual Hosts"

if confirm "Creare le configurazioni Nginx per i 4 siti?"; then

    # 7.1 — Landing Page
    cat > /etc/nginx/sites-available/beach-landing << EOF
server {
    listen 80;
    server_name ${BASE_DOMAIN};

    location / {
        proxy_pass         http://127.0.0.1:8080;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }
}
EOF

    # 7.2 — BeachBooking
    cat > /etc/nginx/sites-available/beachbooking << EOF
server {
    listen 80;
    server_name booking.${BASE_DOMAIN};

    location / {
        proxy_pass         http://127.0.0.1:82;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }
}
EOF

    # 7.3 — BeachDelivery Frontend
    cat > /etc/nginx/sites-available/beachdelivery << EOF
server {
    listen 80;
    server_name delivery.${BASE_DOMAIN};

    location / {
        proxy_pass         http://127.0.0.1:81;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }
}
EOF

    # 7.4 — BeachDelivery API
    cat > /etc/nginx/sites-available/beachdelivery-api << EOF
server {
    listen 80;
    server_name api-delivery.${BASE_DOMAIN};

    proxy_read_timeout 300;
    proxy_send_timeout 300;

    location / {
        proxy_pass         http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade           \$http_upgrade;
        proxy_set_header   Connection        "upgrade";
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }
}
EOF

    # Abilita siti — evita errore se il symlink esiste già
    for site in beach-landing beachbooking beachdelivery beachdelivery-api; do
        ln -sf /etc/nginx/sites-available/${site} /etc/nginx/sites-enabled/${site}
    done

    # Rimuovi default
    rm -f /etc/nginx/sites-enabled/default

    # Test configurazione
    if nginx -t 2>&1; then
        systemctl reload nginx
        ok "Nginx configurato e ricaricato."
    else
        err "Configurazione Nginx non valida. Controlla i file in /etc/nginx/sites-available/"
        exit 1
    fi
else
    warn "Step saltato."
fi

# =============================================================================
#  STEP 8 — Certificati SSL (Let's Encrypt)
# =============================================================================
step "8" "Certificati SSL — Let's Encrypt"

echo -e "  ${CYAN}Prerequisito:${NC} i 4 domini devono rispondere con l'IP ${VPS_IP}."
echo -e "  Con sslip.io è automatico — nessuna configurazione DNS necessaria."
echo ""
info "Test DNS preventivo…"

dns_ok=true
for subdomain in "" "booking." "delivery." "api-delivery."; do
    domain="${subdomain}${BASE_DOMAIN}"
    resolved=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' | head -1 || true)
    if [[ "$resolved" == "$VPS_IP" ]]; then
        ok "  $domain → $resolved"
    else
        warn "  $domain → '${resolved:-non risolto}' (atteso: ${VPS_IP})"
        dns_ok=false
    fi
done

if [[ "$dns_ok" == "false" ]]; then
    warn "Alcuni domini non risolvono correttamente."
    warn "Certbot fallirà se i domini non sono raggiungibili dalla rete."
    if ! confirm "Continuare comunque con Certbot?"; then
        info "Step SSL saltato. Esegui manualmente dopo:"
        echo "  certbot --nginx \\"
        echo "    -d ${BASE_DOMAIN} \\"
        echo "    -d booking.${BASE_DOMAIN} \\"
        echo "    -d delivery.${BASE_DOMAIN} \\"
        echo "    -d api-delivery.${BASE_DOMAIN} \\"
        echo "    --non-interactive --agree-tos --email ${CERTBOT_EMAIL} --redirect"
        pause
    fi
fi

if confirm "Richiedere i certificati SSL con Certbot?"; then
    certbot --nginx \
        -d "${BASE_DOMAIN}" \
        -d "booking.${BASE_DOMAIN}" \
        -d "delivery.${BASE_DOMAIN}" \
        -d "api-delivery.${BASE_DOMAIN}" \
        --non-interactive \
        --agree-tos \
        --email "${CERTBOT_EMAIL}" \
        --redirect

    ok "Certificati SSL ottenuti e Nginx aggiornato con HTTPS."

    # Verifica rinnovo automatico
    info "Verifica timer rinnovo automatico…"
    if systemctl is-active --quiet certbot.timer 2>/dev/null; then
        ok "certbot.timer attivo — rinnovo automatico configurato."
    else
        warn "certbot.timer non attivo. Attivazione manuale…"
        systemctl enable certbot.timer --quiet
        systemctl start certbot.timer
        ok "certbot.timer abilitato."
    fi
else
    warn "Step SSL saltato. I siti funzioneranno solo in HTTP."
fi

# =============================================================================
#  STEP 9 — Build e avvio container Docker
# =============================================================================
step "9" "Build e avvio container Docker"

echo -e "  ${YELLOW}⚠  La build completa può richiedere 5–15 minuti.${NC}"
echo -e "  Vengono compilati: Java (Maven) + Node.js (Vite) per ogni servizio.\n"

if confirm "Avviare la build e il deploy dei container?"; then
    cd "${PROJECT_DIR}"

    info "Avvio build Docker Compose (output in tempo reale)…"
    echo -e "${CYAN}─────────────────────────────────────────────────────${NC}"
    docker compose up -d --build
    echo -e "${CYAN}─────────────────────────────────────────────────────${NC}"

    ok "Build completata. Attendo 10 secondi per l'avvio dei servizi…"
    sleep 10

    echo ""
    info "Stato dei container:"
    docker compose ps
else
    warn "Step saltato. Avvia manualmente con:"
    echo "  cd ${PROJECT_DIR} && docker compose up -d --build"
fi

# =============================================================================
#  STEP 10 — Configurazione backup automatico
# =============================================================================
step "10" "Backup automatico giornaliero (cron)"

if confirm "Configurare il backup automatico del database ogni notte alle 3:00?"; then
    mkdir -p "${PROJECT_DIR}/backups"

    # Rimuove vecchia riga backup se presente, poi aggiunge la nuova
    (crontab -l 2>/dev/null | grep -v "beach/backups"; \
     echo "0 3 * * * docker exec beach-mysql mysqldump -u root -p\"\$(grep MYSQL_ROOT_PASSWORD ${PROJECT_DIR}/.env | cut -d= -f2)\" --all-databases --single-transaction > ${PROJECT_DIR}/backups/backup_\$(date +\\%Y\\%m\\%d).sql && find ${PROJECT_DIR}/backups -name '*.sql' -mtime +7 -delete") \
    | crontab -

    ok "Cron configurato: backup ogni giorno alle 03:00, rotazione 7 giorni."
else
    warn "Backup automatico non configurato."
fi

# =============================================================================
#  STEP 11 — Verifica finale
# =============================================================================
step "11" "Verifica finale"

echo ""
info "Test dei servizi…"
echo ""

all_ok=true

check_url() {
    local label="$1" url="$2" expected="$3"
    local code
    code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
    if [[ "$code" == "$expected" || ( "$expected" == "2xx" && "$code" =~ ^2 ) ]]; then
        ok "${label} → ${url} [HTTP ${code}]"
    else
        warn "${label} → ${url} [HTTP ${code}] (atteso: ${expected})"
        all_ok=false
    fi
}

check_url "Landing Page   " "https://${BASE_DOMAIN}"                                "2xx"
check_url "BeachBooking   " "https://booking.${BASE_DOMAIN}"                        "2xx"
check_url "BeachDelivery  " "https://delivery.${BASE_DOMAIN}"                       "2xx"
check_url "Delivery API   " "https://api-delivery.${BASE_DOMAIN}/actuator/health"   "2xx"

echo ""

if [[ "$all_ok" == "true" ]]; then
    echo -e "${GREEN}${BOLD}"
    cat << 'SUCCESS'

  ╔════════════════════════════════════════════════════╗
  ║   🎉  Installazione completata con successo!       ║
  ╚════════════════════════════════════════════════════╝
SUCCESS
    echo -e "${NC}"
else
    echo -e "${YELLOW}${BOLD}"
    cat << 'PARTIAL'

  ╔════════════════════════════════════════════════════╗
  ║   ⚠   Installazione completata con avvertenze.    ║
  ║   Alcuni servizi potrebbero non essere ancora up. ║
  ╚════════════════════════════════════════════════════╝
PARTIAL
    echo -e "${NC}"
fi

echo -e "  ${BOLD}URL del progetto:${NC}"
echo -e "  🏠 Landing    → https://${BASE_DOMAIN}"
echo -e "  ⛱  Booking    → https://booking.${BASE_DOMAIN}"
echo -e "  🍹 Delivery   → https://delivery.${BASE_DOMAIN}"
echo -e "  🔌 API Health → https://api-delivery.${BASE_DOMAIN}/actuator/health"
echo ""
echo -e "  ${BOLD}Comandi utili:${NC}"
echo    "  cd ${PROJECT_DIR}"
echo    "  docker compose ps               # stato container"
echo    "  docker compose logs -f          # log in tempo reale"
echo    "  docker compose restart <svc>    # riavvia un servizio"
echo    "  docker compose up -d --build    # rebuild e redeploy"
echo ""

if [[ -z "${PAYPAL_CLIENT_ID}" ]]; then
    echo -e "  ${YELLOW}⚠  Ricordati di configurare le credenziali PayPal in:${NC}"
    echo    "     nano ${PROJECT_DIR}/.env"
    echo    "     → PAYPAL_CLIENT_ID e PAYPAL_CLIENT_SECRET"
    echo    "  Poi riavvia: docker compose up -d --build beachbooking-frontend beachbooking-app"
    echo ""
fi

echo -e "  ${CYAN}Log dell'installazione completato.${NC}"
