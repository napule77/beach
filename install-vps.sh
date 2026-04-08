#!/usr/bin/env bash
# =============================================================================
#  install-vps.sh — Auto-installer guidato per Beach Project
#  VPS: 80.211.137.54  |  OS: Ubuntu 22.04 LTS
#  Supporta il resume: se interrotto, riparte dall'ultimo step fallito.
# =============================================================================
set -euo pipefail

# ── Colori ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Costanti ──────────────────────────────────────────────────────────────────
VPS_IP="80.211.137.54"
BASE_DOMAIN="${VPS_IP//./-}.sslip.io"
PROJECT_DIR="/opt/beach"
STATE_FILE="/opt/.beach-install-state"   # step completati (uno per riga)
CONFIG_CACHE="/opt/.beach-install-config" # credenziali per il resume

# ── Helper generici ───────────────────────────────────────────────────────────
step()    { echo -e "\n${BOLD}${BLUE}══════════════════════════════════════════════${NC}"
            echo -e "${BOLD}${BLUE}  STEP $1: $2${NC}"
            echo -e "${BOLD}${BLUE}══════════════════════════════════════════════${NC}"; }
ok()      { echo -e "  ${GREEN}✔  $*${NC}"; }
warn()    { echo -e "  ${YELLOW}⚠  $*${NC}"; }
err()     { echo -e "  ${RED}✖  $*${NC}"; }
info()    { echo -e "  ${CYAN}ℹ  $*${NC}"; }
pause()   { echo -e "\n${YELLOW}  Premi [INVIO] per continuare o Ctrl+C per interrompere…${NC}"; read -r; }
confirm() { echo -e "\n${YELLOW}  $1 [s/N]: ${NC}\c"; read -r ans; [[ "$ans" =~ ^[sS]$ ]]; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        err "Questo script deve essere eseguito come root."
        echo "  Riesegui con: sudo bash $0"
        exit 1
    fi
}

# ── Sistema di resume ─────────────────────────────────────────────────────────
# mark_done <id>   — segna uno step come completato
# is_done   <id>   — ritorna 0 (true) se già completato
# reset_step <id>  — rimuove uno step dallo state (per ri-eseguirlo)

mark_done() { echo "$1" >> "${STATE_FILE}"; }

is_done() {
    [[ -f "${STATE_FILE}" ]] && grep -qx "$1" "${STATE_FILE}"
}

reset_step() {
    [[ -f "${STATE_FILE}" ]] && sed -i "/^${1}$/d" "${STATE_FILE}"
}

# Salva le credenziali per il resume (chmod 600)
save_config() {
    # printf '%q' quota correttamente ogni valore (gestisce spazi, =, +, / nei JWT/password)
    {
        printf 'CERTBOT_EMAIL=%q\n'        "${CERTBOT_EMAIL}"
        printf 'MYSQL_ROOT_PASS=%q\n'      "${MYSQL_ROOT_PASS}"
        printf 'BB_DB_PASS=%q\n'           "${BB_DB_PASS}"
        printf 'BD_DB_PASS=%q\n'           "${BD_DB_PASS}"
        printf 'BB_JWT=%q\n'               "${BB_JWT}"
        printf 'BD_JWT=%q\n'               "${BD_JWT}"
        printf 'PAYPAL_CLIENT_ID=%q\n'     "${PAYPAL_CLIENT_ID}"
        printf 'PAYPAL_CLIENT_SECRET=%q\n' "${PAYPAL_CLIENT_SECRET}"
        printf 'SMTP_HOST=%q\n'            "${SMTP_HOST}"
        printf 'SMTP_PORT=%q\n'            "${SMTP_PORT}"
        printf 'SMTP_USER=%q\n'            "${SMTP_USER}"
        printf 'SMTP_PASS=%q\n'            "${SMTP_PASS}"
    } > "${CONFIG_CACHE}"
    chmod 600 "${CONFIG_CACHE}"
}

# Carica le credenziali salvate (resume)
load_config() {
    # shellcheck source=/dev/null
    source "${CONFIG_CACHE}"
}

# ── Banner ────────────────────────────────────────────────────────────────────
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
echo -e "  ${BOLD}Supporta il resume:${NC} se interrotto, riparte dall'ultimo step fallito."
echo -e "\n  ${BOLD}URL finali dopo l'installazione:${NC}"
echo -e "  🏠 Landing    → https://${BASE_DOMAIN}"
echo -e "  ⛱  Booking    → https://booking.${BASE_DOMAIN}"
echo -e "  🍹 Delivery   → https://delivery.${BASE_DOMAIN}"
echo -e "  🔌 API        → https://api-delivery.${BASE_DOMAIN}"

check_root

# Mostra stato attuale se esiste già una sessione parziale
if [[ -f "${STATE_FILE}" ]]; then
    echo -e "\n${YELLOW}${BOLD}  ► Sessione precedente rilevata. Step già completati:${NC}"
    while IFS= read -r line; do
        echo -e "    ${GREEN}✔${NC}  ${line}"
    done < "${STATE_FILE}"
    echo ""
    if confirm "Vuoi AZZERARE la sessione e ricominciare da capo?"; then
        rm -f "${STATE_FILE}" "${CONFIG_CACHE}"
        ok "Sessione azzerata. Ripartenza da zero."
    else
        ok "Riprendo dall'ultimo step non completato."
    fi
fi
echo ""

# =============================================================================
#  STEP 0 — Raccolta credenziali
# =============================================================================
step "0" "Raccolta credenziali e configurazione"

if is_done "step-0" && [[ -f "${CONFIG_CACHE}" ]]; then
    ok "Step già completato — carico la configurazione salvata."
    load_config
else
    # Config cache mancante (es. skip manuale): resetta e ri-raccoglie
    if is_done "step-0" && [[ ! -f "${CONFIG_CACHE}" ]]; then
        warn "Config cache non trovata — raccolgo nuovamente le credenziali."
        reset_step "step-0"
    fi
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

    # JWT secrets generati automaticamente (stabili per questa sessione)
    BB_JWT=$(openssl rand -hex 48)
    BD_JWT=$(openssl rand -hex 72)

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

    save_config
    mark_done "step-0"
fi

# =============================================================================
#  STEP 1 — Setup iniziale sistema
# =============================================================================
step "1" "Setup iniziale VPS"

if is_done "step-1"; then
    ok "Step già completato — skip."
else
    if confirm "Aggiornare il sistema e installare i tool essenziali?"; then
        info "Aggiornamento pacchetti in corso…"
        apt update -qq && apt upgrade -y -qq
        apt install -y git curl wget ufw nano htop net-tools -qq
        timedatectl set-timezone Europe/Rome
        ok "Sistema aggiornato. Timezone: $(timedatectl show -p Timezone --value)"
        mark_done "step-1"
    else
        warn "Step saltato manualmente."
    fi
fi

# =============================================================================
#  STEP 2 — Installazione Docker
# =============================================================================
step "2" "Installazione Docker"

if is_done "step-2"; then
    ok "Step già completato — skip."
else
    if command -v docker &>/dev/null; then
        ok "Docker già installato: $(docker --version)"
        mark_done "step-2"
    elif confirm "Installare Docker?"; then
        info "Download e installazione Docker…"
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker --quiet
        systemctl start docker
        ok "Docker installato: $(docker --version)"
        ok "Docker Compose: $(docker compose version)"
        mark_done "step-2"
    else
        warn "Step saltato manualmente. Docker è obbligatorio per proseguire."
    fi
fi

# =============================================================================
#  STEP 3 — Installazione Nginx e Certbot
# =============================================================================
step "3" "Installazione Nginx e Certbot"

if is_done "step-3"; then
    ok "Step già completato — skip."
else
    if confirm "Installare Nginx e Certbot?"; then
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
        mark_done "step-3"
    else
        warn "Step saltato manualmente."
    fi
fi

# =============================================================================
#  STEP 4 — Configurazione Firewall
# =============================================================================
step "4" "Configurazione Firewall (UFW)"

if is_done "step-4"; then
    ok "Step già completato — skip."
else
    if confirm "Configurare il firewall UFW (22 SSH + 80 HTTP + 443 HTTPS)?"; then
        ufw allow 22   comment 'SSH'   >/dev/null
        ufw allow 80   comment 'HTTP'  >/dev/null
        ufw allow 443  comment 'HTTPS' >/dev/null
        ufw --force enable >/dev/null
        ok "Firewall attivo."
        ufw status | sed 's/^/    /'
        mark_done "step-4"
    else
        warn "Step saltato manualmente. Assicurati che le porte 22/80/443 siano aperte."
    fi
fi

# =============================================================================
#  STEP 5 — Verifica codice su VPS
# =============================================================================
step "5" "Verifica codice progetto in ${PROJECT_DIR}"

if is_done "step-5"; then
    ok "Step già completato — skip."
else
    if [[ -f "${PROJECT_DIR}/docker-compose.yml" ]]; then
        ok "Codice già presente in ${PROJECT_DIR}."
        mark_done "step-5"
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
        echo -e "  ${YELLOW}  Esegui il comando in un'altra finestra, poi torna qui e premi INVIO.${NC}"
        pause

        if [[ ! -f "${PROJECT_DIR}/docker-compose.yml" ]]; then
            err "docker-compose.yml non trovato in ${PROJECT_DIR}. Verifica il caricamento."
            err "Rilancia lo script dopo aver caricato il codice — questo step verrà riproposto."
            exit 1
        fi
        mark_done "step-5"
    fi
    ok "Struttura progetto:"
    ls "${PROJECT_DIR}/" | sed 's/^/    /'
fi

# =============================================================================
#  STEP 6 — Configurazione .env
# =============================================================================
step "6" "Configurazione file .env"

if is_done "step-6"; then
    ok "Step già completato — skip."
else
    cd "${PROJECT_DIR}"
    [[ -f .env.example ]] && cp .env.example .env

    # Nota: i valori sono quotati con "" per evitare problemi con caratteri
    # speciali (/, +, =) che Docker Compose non accetta senza virgolette.
    cat > .env << ENVEOF
# ================================================================
# MYSQL CONDIVISO
# ================================================================
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASS}"

# ================================================================
# BEACH BOOKING
# ================================================================
BEACHBOOKING_DB_PASSWORD="${BB_DB_PASS}"
BEACHBOOKING_JWT_SECRET="${BB_JWT}"

# PayPal
PAYPAL_CLIENT_ID="${PAYPAL_CLIENT_ID:-CONFIGURA_QUI}"
PAYPAL_CLIENT_SECRET="${PAYPAL_CLIENT_SECRET:-CONFIGURA_QUI}"
PAYPAL_BASE_URL=https://api-m.paypal.com
VITE_PAYPAL_CLIENT_ID="${PAYPAL_CLIENT_ID:-CONFIGURA_QUI}"

# ================================================================
# BEACH DELIVERY
# ================================================================
BEACHDELIVERY_DB_PASSWORD="${BD_DB_PASS}"
BEACHDELIVERY_JWT_SECRET="${BD_JWT}"

BEACHDELIVERY_API_URL=https://api-delivery.${BASE_DOMAIN}
APP_CORS_ALLOWED_ORIGINS=https://delivery.${BASE_DOMAIN}
SPRING_JPA_HIBERNATE_DDL_AUTO=validate

# ================================================================
# MAIL (opzionale)
# ================================================================
SPRING_MAIL_HOST=${SMTP_HOST:-smtp.tuoprovider.com}
SPRING_MAIL_PORT=${SMTP_PORT:-587}
SPRING_MAIL_USERNAME=${SMTP_USER:-tua_email@dominio.com}
SPRING_MAIL_PASSWORD="${SMTP_PASS:-TuaPasswordEmail}"
ENVEOF

    chmod 600 .env
    ok ".env creato con permessi 600."
    [[ -z "${PAYPAL_CLIENT_ID}" ]] && warn "PayPal non configurato: modifica .env prima della build."
    mark_done "step-6"
fi

# =============================================================================
#  STEP 7 — Configurazione Nginx Virtual Hosts
# =============================================================================
step "7" "Configurazione Nginx Virtual Hosts"

if is_done "step-7"; then
    ok "Step già completato — skip."
else
    if confirm "Creare le configurazioni Nginx per i 4 siti?"; then

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

        for site in beach-landing beachbooking beachdelivery beachdelivery-api; do
            ln -sf /etc/nginx/sites-available/${site} /etc/nginx/sites-enabled/${site}
        done
        rm -f /etc/nginx/sites-enabled/default

        if nginx -t 2>&1; then
            systemctl reload nginx
            ok "Nginx configurato e ricaricato."
            mark_done "step-7"
        else
            err "Configurazione Nginx non valida. Correggila e rilancia lo script."
            exit 1
        fi
    else
        warn "Step saltato manualmente."
    fi
fi

# =============================================================================
#  STEP 8 — Certificati SSL
# =============================================================================
step "8" "Certificati SSL — Let's Encrypt"

if is_done "step-8"; then
    ok "Step già completato — skip."
else
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
        if ! confirm "Continuare comunque con Certbot?"; then
            info "Step SSL rimandato. Rilancia lo script quando il DNS è pronto."
            info "Questo step verrà riproposto alla prossima esecuzione."
            exit 0
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

        ok "Certificati SSL ottenuti."

        if ! systemctl is-active --quiet certbot.timer 2>/dev/null; then
            systemctl enable certbot.timer --quiet
            systemctl start certbot.timer
        fi
        ok "certbot.timer attivo — rinnovo automatico configurato."
        mark_done "step-8"
    else
        warn "Step SSL saltato manualmente."
    fi
fi

# =============================================================================
#  STEP 9 — Build e avvio container Docker
# =============================================================================
step "9" "Build e avvio container Docker"

if is_done "step-9"; then
    ok "Step già completato — skip."
    info "Stato attuale dei container:"
    cd "${PROJECT_DIR}" && docker compose ps
else
    echo -e "  ${YELLOW}⚠  La build completa può richiedere 5–15 minuti.${NC}"
    echo -e "  Vengono compilati: Java (Maven) + Node.js (Vite) per ogni servizio.\n"

    if confirm "Avviare la build e il deploy dei container?"; then
        cd "${PROJECT_DIR}"
        info "Avvio build Docker Compose…"
        echo -e "${CYAN}─────────────────────────────────────────────────────${NC}"
        docker compose up -d --build
        echo -e "${CYAN}─────────────────────────────────────────────────────${NC}"
        ok "Build completata. Attendo 10 secondi per l'avvio dei servizi…"
        sleep 10
        echo ""
        info "Stato dei container:"
        docker compose ps
        mark_done "step-9"
    else
        warn "Step saltato manualmente. Avvia con:"
        echo "  cd ${PROJECT_DIR} && docker compose up -d --build"
    fi
fi

# =============================================================================
#  STEP 10 — Backup automatico
# =============================================================================
step "10" "Backup automatico giornaliero (cron)"

if is_done "step-10"; then
    ok "Step già completato — skip."
else
    if confirm "Configurare il backup automatico del database ogni notte alle 3:00?"; then
        mkdir -p "${PROJECT_DIR}/backups"
        (crontab -l 2>/dev/null | grep -v "beach/backups"
         echo "0 3 * * * docker exec beach-mysql mysqldump -u root -p\"\$(grep MYSQL_ROOT_PASSWORD ${PROJECT_DIR}/.env | cut -d= -f2)\" --all-databases --single-transaction > ${PROJECT_DIR}/backups/backup_\$(date +\\%Y\\%m\\%d).sql && find ${PROJECT_DIR}/backups -name '*.sql' -mtime +7 -delete") \
        | crontab -
        ok "Cron configurato: backup ogni giorno alle 03:00, rotazione 7 giorni."
        mark_done "step-10"
    else
        warn "Backup automatico non configurato."
    fi
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
    local label="$1" url="$2"
    local code
    code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
    if [[ "$code" =~ ^2 ]]; then
        ok "${label} → ${url} [HTTP ${code}]"
    else
        warn "${label} → ${url} [HTTP ${code}]"
        all_ok=false
    fi
}

check_url "Landing Page   " "https://${BASE_DOMAIN}"
check_url "BeachBooking   " "https://booking.${BASE_DOMAIN}"
check_url "BeachDelivery  " "https://delivery.${BASE_DOMAIN}"
check_url "Delivery API   " "https://api-delivery.${BASE_DOMAIN}/actuator/health"

echo ""

if [[ "$all_ok" == "true" ]]; then
    echo -e "${GREEN}${BOLD}"
    cat << 'SUCCESS'

  ╔════════════════════════════════════════════════════╗
  ║   🎉  Installazione completata con successo!       ║
  ╚════════════════════════════════════════════════════╝
SUCCESS
    echo -e "${NC}"
    mark_done "step-11"
else
    echo -e "${YELLOW}${BOLD}"
    cat << 'PARTIAL'

  ╔════════════════════════════════════════════════════╗
  ║   ⚠   Alcuni servizi non sono ancora raggiungibili║
  ║   Rilancia lo script per ritentare la verifica.   ║
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
    echo    "  Poi riavvia: docker compose up -d --build beachbooking-frontend beachbooking-app"
    echo ""
fi

# =============================================================================
#  SUMMARY FILE
# =============================================================================
SUMMARY_FILE="${PROJECT_DIR}/INSTALL-SUMMARY.txt"
INSTALL_DATE=$(date '+%d/%m/%Y %H:%M:%S')

cat > "${SUMMARY_FILE}" << SUMMARYEOF
================================================================================
  BEACH PROJECT — RIEPILOGO INSTALLAZIONE
  Data installazione : ${INSTALL_DATE}
  VPS IP             : ${VPS_IP}
================================================================================

── URL PUBBLICI ────────────────────────────────────────────────────────────────

  Landing Page    : https://${BASE_DOMAIN}
  BeachBooking    : https://booking.${BASE_DOMAIN}
  BeachDelivery   : https://delivery.${BASE_DOMAIN}
  API Delivery    : https://api-delivery.${BASE_DOMAIN}
  API Health      : https://api-delivery.${BASE_DOMAIN}/actuator/health

── CREDENZIALI DATABASE ────────────────────────────────────────────────────────

  MySQL root
    Utente         : root
    Password       : ${MYSQL_ROOT_PASS}
    Host           : 127.0.0.1 (solo rete interna Docker)
    Porta          : 3306

  BeachBooking DB
    Database       : beach_booking
    Password       : ${BB_DB_PASS}

  BeachDelivery DB
    Database       : beachdelivery
    Password       : ${BD_DB_PASS}

── JWT SECRETS (generati automaticamente) ──────────────────────────────────────

  BeachBooking JWT Secret:
    ${BB_JWT}

  BeachDelivery JWT Secret:
    ${BD_JWT}

── PAYPAL ────────────────────────────────────────────────────────────────────────

  Client ID      : ${PAYPAL_CLIENT_ID:-[NON CONFIGURATO — aggiornare .env]}
  Client Secret  : ${PAYPAL_CLIENT_SECRET:-[NON CONFIGURATO — aggiornare .env]}
  Endpoint       : https://api-m.paypal.com

── SSL / CERTBOT ────────────────────────────────────────────────────────────────

  Email           : ${CERTBOT_EMAIL}
  Provider        : Let's Encrypt (sslip.io)
  Rinnovo auto    : certbot.timer (systemd)
  Scadenza cert   : 90 giorni (rinnovo automatico a 60 giorni)

── SMTP / EMAIL ─────────────────────────────────────────────────────────────────

  Host           : ${SMTP_HOST:-[non configurato]}
  Porta          : ${SMTP_PORT:-587}
  Username       : ${SMTP_USER:-[non configurato]}
  Password       : ${SMTP_PASS:-[non configurato]}

── PERCORSI IMPORTANTI ──────────────────────────────────────────────────────────

  Progetto       : ${PROJECT_DIR}/
  File .env      : ${PROJECT_DIR}/.env
  Backup DB      : ${PROJECT_DIR}/backups/
  Nginx sites    : /etc/nginx/sites-available/
  Certificati    : /etc/letsencrypt/live/
  State file     : ${STATE_FILE}
  Config cache   : ${CONFIG_CACHE}

── DOCKER ────────────────────────────────────────────────────────────────────────

  Landing        : 127.0.0.1:8080  (container: beach-landing)
  BB Frontend    : 127.0.0.1:82    (container: beachbooking-frontend)
  BD Frontend    : 127.0.0.1:81    (container: beachdelivery-fe)
  BD API         : 127.0.0.1:8081  (container: beachdelivery-api)
  MySQL          : 3306            (container: beach-mysql, solo rete interna)

── COMANDI UTILI ────────────────────────────────────────────────────────────────

  Stato container   : cd ${PROJECT_DIR} && docker compose ps
  Log live          : cd ${PROJECT_DIR} && docker compose logs -f
  Riavvia servizio  : cd ${PROJECT_DIR} && docker compose restart <nome>
  Rebuild completo  : cd ${PROJECT_DIR} && docker compose up -d --build
  Backup manuale    : docker exec beach-mysql mysqldump -u root -p"${MYSQL_ROOT_PASS}" --all-databases --single-transaction > ${PROJECT_DIR}/backups/backup_manual.sql
  Accesso MySQL     : docker exec -it beach-mysql mysql -u root -p"${MYSQL_ROOT_PASS}"

── BACKUP AUTOMATICO ────────────────────────────────────────────────────────────

  Cron            : ogni giorno alle 03:00
  Rotazione       : 7 giorni
  Destinazione    : ${PROJECT_DIR}/backups/backup_YYYYMMDD.sql

================================================================================
  ⚠  ATTENZIONE: questo file contiene password in chiaro.
     Scaricalo in locale e cancellalo dalla VPS dopo averlo salvato.
     Comando per scaricarlo:
       scp root@${VPS_IP}:${SUMMARY_FILE} ./INSTALL-SUMMARY.txt
     Comando per cancellarlo dalla VPS:
       rm -f ${SUMMARY_FILE}
================================================================================
SUMMARYEOF

chmod 600 "${SUMMARY_FILE}"

echo -e "\n${GREEN}${BOLD}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  📄 Summary salvato in: ${SUMMARY_FILE}${NC}"
echo -e "${GREEN}${BOLD}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\n  ${YELLOW}Scarica il file in locale con:${NC}"
echo -e "  ${BOLD}  scp root@${VPS_IP}:${SUMMARY_FILE} ./INSTALL-SUMMARY.txt${NC}"
echo -e "\n  ${RED}  Poi cancellalo dalla VPS:${NC}"
echo -e "  ${BOLD}  rm -f ${SUMMARY_FILE}${NC}\n"
echo -e "  ${CYAN}Installazione completata.${NC}"