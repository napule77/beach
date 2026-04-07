# 🏖️ INSTALL-VPS.md — Guida completa al deploy su VPS

> **VPS IP:** `80.211.137.54`  
> **OS consigliato:** Ubuntu 22.04 LTS  
> **Accesso richiesto:** root o utente con sudo

---

## Indice

1. [Architettura](#1-architettura)
2. [Setup iniziale VPS](#2-setup-iniziale-vps)
3. [Installazione Docker](#3-installazione-docker)
4. [Installazione Nginx e Certbot](#4-installazione-nginx-e-certbot)
5. [Configurazione Firewall](#5-configurazione-firewall)
6. [Caricamento del codice](#6-caricamento-del-codice)
7. [Configurazione .env](#7-configurazione-env)
8. [Configurazione Nginx — Virtual Hosts](#8-configurazione-nginx--virtual-hosts)
9. [Certificati SSL — Let's Encrypt](#9-certificati-ssl--lets-encrypt)
10. [Build e avvio dei container](#10-build-e-avvio-dei-container)
11. [Verifica finale](#11-verifica-finale)
12. [Comandi di gestione](#12-comandi-di-gestione)
13. [Backup e ripristino](#13-backup-e-ripristino)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Architettura

```
                          INTERNET
                              │
                   ┌──────────▼──────────┐
                   │   Nginx  (host)     │  :80 → redirect HTTPS
                   │  + Let's Encrypt    │  :443 → SSL termination
                   └──────┬─────────┬───┘
               ┌──────────┘         └──────────────┐
               ▼                                   ▼
  80-211-137-54.sslip.io          booking / delivery / api-delivery
  (landing page)                  .80-211-137-54.sslip.io
               │                                   │
    ┌──────────▼───────────────────────────────────▼──────┐
    │                  Docker Compose                      │
    │                                                      │
    │   ┌────────────┐   ┌──────────────┐                  │
    │   │  landing   │   │ beachbooking │                  │
    │   │  :8080     │   │ frontend :82 │                  │
    │   └────────────┘   │ backend  exp │                  │
    │                    └──────────────┘                  │
    │                                                      │
    │                    ┌──────────────┐                  │
    │                    │beachdelivery │                  │
    │                    │ frontend :81 │                  │
    │                    │ backend :8081│                  │
    │                    └──────────────┘                  │
    │                                                      │
    │              ┌─────────────────┐                     │
    │              │  MySQL :3306    │  (solo rete interna) │
    │              │  beach_booking  │                     │
    │              │  beachdelivery  │                     │
    │              └─────────────────┘                     │
    └──────────────────────────────────────────────────────┘
```

### URL finali

| Servizio | URL |
|---|---|
| 🏠 Landing Page | `https://80-211-137-54.sslip.io` |
| ⛱ BeachBooking | `https://booking.80-211-137-54.sslip.io` |
| 🍹 BeachDelivery | `https://delivery.80-211-137-54.sslip.io` |
| 🔌 BeachDelivery API | `https://api-delivery.80-211-137-54.sslip.io` |

> **Nota su sslip.io:** è un servizio DNS gratuito che risolve automaticamente
> `<IP-con-trattini>.sslip.io` al corrispondente IP. Non serve acquistare un dominio.
> Let's Encrypt emette certificati validi per questi domini.

---

## 2. Setup iniziale VPS

```bash
# Accedi alla VPS
ssh root@80.211.137.54

# Aggiorna il sistema
apt update && apt upgrade -y

# Installa tool essenziali
apt install -y git curl wget ufw nano htop

# (Opzionale ma consigliato) Crea un utente non-root
adduser beachadmin
usermod -aG sudo beachadmin
rsync --archive --chown=beachadmin:beachadmin ~/.ssh /home/beachadmin

# Imposta il fuso orario italiano
timedatectl set-timezone Europe/Rome
```

---

## 3. Installazione Docker

```bash
# Installa Docker con lo script ufficiale
curl -fsSL https://get.docker.com | sh

# Abilita Docker all'avvio automatico
systemctl enable docker
systemctl start docker

# (Se hai creato un utente non-root) Aggiungilo al gruppo docker
usermod -aG docker beachadmin

# Verifica installazione
docker --version
docker compose version
```

Output atteso:
```
Docker version 26.x.x, build ...
Docker Compose version v2.x.x
```

---

## 4. Installazione Nginx e Certbot

```bash
# Installa Nginx
apt install -y nginx

# Installa Certbot con il plugin Nginx
apt install -y certbot python3-certbot-nginx

# Verifica che Nginx sia attivo
systemctl status nginx
# Deve mostrare: Active: active (running)
```

---

## 5. Configurazione Firewall

```bash
# Regole minime necessarie
ufw allow 22      # SSH — NON chiudere mai prima di ufw enable!
ufw allow 80      # HTTP (necessario per la challenge Let's Encrypt)
ufw allow 443     # HTTPS

# Attiva il firewall
ufw enable

# Verifica
ufw status
```

> ⚠️ Le porte 81, 82, 8080, 8081 dei container sono legate a `127.0.0.1`
> e **non sono raggiungibili da internet**. Solo Nginx sul host può accedervi.
> MySQL non ha porte esposte all'esterno.

---

## 6. Caricamento del codice

### Opzione A — Da repository Git (consigliata)

```bash
cd /opt
git clone <URL_DEL_TUO_REPO> beach
cd /opt/beach
```

### Opzione B — Upload da locale via rsync

Esegui dal tuo PC (non dalla VPS):

```bash
rsync -avz \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='target' \
  --exclude='.env' \
  /percorso/locale/beach/ \
  root@80.211.137.54:/opt/beach/
```

### Verifica struttura

```bash
ls /opt/beach/
```

Deve mostrare:
```
beachbooking/   beachdelivery/   landing/
docker-compose.yml   mysql-init/   .env.example
```

---

## 7. Configurazione .env

```bash
cd /opt/beach

# Copia il template
cp .env.example .env

# Apri in modifica
nano .env
```

Compila il file `.env` con i valori reali:

```env
# ================================================================
# MYSQL CONDIVISO
# ================================================================
MYSQL_ROOT_PASSWORD=SceglieUnaPasswordForte_Root_1!

# ================================================================
# BEACH BOOKING
# ================================================================
BEACHBOOKING_DB_PASSWORD=SceglieUnaPasswordForte_BB_2!
BEACHBOOKING_JWT_SECRET=mZ8v3YxQ1rT7uLpKc9Vb2NfG5Hj6DsAaW0XyZpRtEw==

# PayPal (stesso account per entrambe le app)
PAYPAL_CLIENT_ID=<tua_chiave_client_paypal>
PAYPAL_CLIENT_SECRET=<tuo_secret_paypal>
PAYPAL_BASE_URL=https://api-m.paypal.com

# Chiave pubblica PayPal per il frontend BeachBooking (baked nel build)
VITE_PAYPAL_CLIENT_ID=<tua_chiave_client_paypal>

# ================================================================
# BEACH DELIVERY
# ================================================================
BEACHDELIVERY_DB_PASSWORD=SceglieUnaPasswordForte_BD_3!
BEACHDELIVERY_JWT_SECRET=yLTC1fWKTN5Rgg6AT5IxFsaXbogHbMwCYDF952uZKLVQzG8s27oqO0U7qDEsyGWmP07pMyr1PLQ6XCBs87If0e

# URL pubblico del backend BeachDelivery (baked nel build del frontend Vite)
BEACHDELIVERY_API_URL=https://api-delivery.80-211-137-54.sslip.io

# Origini CORS autorizzate dal backend BeachDelivery
APP_CORS_ALLOWED_ORIGINS=https://delivery.80-211-137-54.sslip.io

# Modalità DDL Hibernate
SPRING_JPA_HIBERNATE_DDL_AUTO=validate

# Mail (opzionale — lascia i valori di default se non usi le email)
SPRING_MAIL_HOST=smtp.tuoprovider.com
SPRING_MAIL_PORT=587
SPRING_MAIL_USERNAME=tua_email@dominio.com
SPRING_MAIL_PASSWORD=TuaPasswordEmail
```

> 🔒 **Sicurezza:** Il file `.env` non deve mai essere committato su Git.
> Verifica che `.gitignore` contenga la riga `.env`.

---

## 8. Configurazione Nginx — Virtual Hosts

Crea un file di configurazione Nginx per ogni sito.

### 8.1 Landing Page

```bash
cat > /etc/nginx/sites-available/beach-landing << 'EOF'
server {
    listen 80;
    server_name 80-211-137-54.sslip.io;

    location / {
        proxy_pass         http://127.0.0.1:8080;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
EOF
```

### 8.2 BeachBooking

```bash
cat > /etc/nginx/sites-available/beachbooking << 'EOF'
server {
    listen 80;
    server_name booking.80-211-137-54.sslip.io;

    location / {
        proxy_pass         http://127.0.0.1:82;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
EOF
```

### 8.3 BeachDelivery Frontend

```bash
cat > /etc/nginx/sites-available/beachdelivery << 'EOF'
server {
    listen 80;
    server_name delivery.80-211-137-54.sslip.io;

    location / {
        proxy_pass         http://127.0.0.1:81;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
EOF
```

### 8.4 BeachDelivery API

```bash
cat > /etc/nginx/sites-available/beachdelivery-api << 'EOF'
server {
    listen 80;
    server_name api-delivery.80-211-137-54.sslip.io;

    # Aumenta il timeout per richieste lunghe (es. upload, WebSocket)
    proxy_read_timeout 300;
    proxy_send_timeout 300;

    location / {
        proxy_pass         http://127.0.0.1:8081;
        proxy_http_version 1.1;

        # WebSocket support — richiesto da STOMP/SockJS
        proxy_set_header   Upgrade           $http_upgrade;
        proxy_set_header   Connection        "upgrade";

        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
EOF
```

### 8.5 Attiva i siti e rimuovi il default

```bash
# Abilita tutti i siti
ln -s /etc/nginx/sites-available/beach-landing   /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/beachbooking    /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/beachdelivery   /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/beachdelivery-api /etc/nginx/sites-enabled/

# Rimuovi il sito di default di Nginx
rm -f /etc/nginx/sites-enabled/default

# Testa la configurazione
nginx -t
# Output atteso: syntax is ok / test is successful

# Ricarica Nginx
systemctl reload nginx
```

---

## 9. Certificati SSL — Let's Encrypt

> **Prerequisito:** i DNS dei 4 domini devono già rispondere con l'IP della VPS.
> Con `sslip.io` questo è automatico — non serve configurazione DNS.

```bash
# Ottieni i certificati per tutti e 4 i domini in un unico comando
certbot --nginx \
  -d 80-211-137-54.sslip.io \
  -d booking.80-211-137-54.sslip.io \
  -d delivery.80-211-137-54.sslip.io \
  -d api-delivery.80-211-137-54.sslip.io \
  --non-interactive \
  --agree-tos \
  --email tua_email@dominio.com \
  --redirect
```

Certbot modifica automaticamente i file Nginx aggiungendo:
- Il blocco `server` in ascolto su `:443` con il certificato
- Il redirect automatico da HTTP a HTTPS

### Verifica il rinnovo automatico

```bash
# Simula un rinnovo (non rinnova davvero)
certbot renew --dry-run
# Output atteso: Congratulations, all simulated renewals succeeded

# I certificati scadono dopo 90 giorni.
# Certbot installa un timer systemd che li rinnova automaticamente.
systemctl status certbot.timer
```

---

## 10. Build e avvio dei container

```bash
cd /opt/beach

# Prima build completa (5–15 minuti: compila Java + Node)
docker compose up -d --build

# Monitora l'avvio in tempo reale
docker compose logs -f
# Premi Ctrl+C per uscire dai log senza fermare i container
```

### Verifica che tutti i container siano UP

```bash
docker compose ps
```

Output atteso:

```
NAME                     IMAGE                STATUS              PORTS
beach-landing            beach-landing        Up                  127.0.0.1:8080->80/tcp
beach-mysql              mysql:8.0            Up (healthy)        3306/tcp
beachbooking-app         beach-beachbooking-  Up                  8080/tcp
beachbooking-frontend    beach-beachbooking-  Up                  127.0.0.1:82->80/tcp
beachdelivery-api        beach-beachdelivery- Up (healthy)        127.0.0.1:8081->8081/tcp
beachdelivery-fe         beach-beachdelivery- Up                  127.0.0.1:81->80/tcp
```

> Se un container mostra `Restarting` o `Exit`, leggi i log con:
> `docker compose logs --tail=50 <nome-container>`

---

## 11. Verifica finale

Esegui questi controlli dalla VPS o dal browser.

```bash
# Landing page
curl -I https://80-211-137-54.sslip.io
# Atteso: HTTP/2 200

# BeachBooking frontend
curl -I https://booking.80-211-137-54.sslip.io
# Atteso: HTTP/2 200

# BeachDelivery frontend
curl -I https://delivery.80-211-137-54.sslip.io
# Atteso: HTTP/2 200

# BeachDelivery API — health check
curl https://api-delivery.80-211-137-54.sslip.io/actuator/health
# Atteso: {"status":"UP"}

# Certificati SSL — verifica scadenza
echo | openssl s_client -connect 80-211-137-54.sslip.io:443 2>/dev/null \
  | openssl x509 -noout -dates

# Database — verifica i due database
docker exec -it beach-mysql \
  mysql -u root -p"$(grep MYSQL_ROOT_PASSWORD /opt/beach/.env | cut -d= -f2)" \
  -e "SHOW DATABASES;"
# Deve mostrare: beach_booking e beachdelivery
```

### Checklist ✅

- [ ] Landing page visibile su `https://80-211-137-54.sslip.io`
- [ ] BeachBooking apre su `https://booking.80-211-137-54.sslip.io`
- [ ] BeachDelivery apre su `https://delivery.80-211-137-54.sslip.io`
- [ ] API risponde `{"status":"UP"}` su `https://api-delivery.80-211-137-54.sslip.io/actuator/health`
- [ ] Lucchetto HTTPS verde in tutti i browser
- [ ] Login e registrazione funzionanti su entrambe le app
- [ ] PayPal configurato correttamente (test con sandbox)

---

## 12. Comandi di gestione

### Avvio / Stop / Riavvio

```bash
cd /opt/beach

# Ferma tutti i container (i dati nel volume MySQL sono preservati)
docker compose down

# Avvia tutto
docker compose up -d

# Riavvia un singolo servizio
docker compose restart beachdelivery-backend

# Ferma e ricrea un singolo servizio
docker compose up -d --no-deps beachbooking-frontend
```

### Aggiornamento del codice (deploy)

```bash
cd /opt/beach

# Scarica le modifiche dal repository
git pull

# Ricostruisce e riavvia solo i container modificati
docker compose up -d --build

# Se vuoi forzare la ricostruzione completa (senza cache)
docker compose build --no-cache
docker compose up -d
```

### Log

```bash
# Log di tutti i servizi in tempo reale
docker compose logs -f

# Log degli ultimi 100 righe di un servizio
docker compose logs --tail=100 beachdelivery-api

# Log con timestamp
docker compose logs -f --timestamps beachbooking-backend
```

### Shell nei container

```bash
# Accedi al container backend BeachBooking (JRE — usa sh)
docker exec -it beachbooking-app sh

# Accedi al container BeachDelivery API (Alpine — usa sh)
docker exec -it beachdelivery-api sh

# Accedi a MySQL come root
docker exec -it beach-mysql \
  mysql -u root -p"$(grep MYSQL_ROOT_PASSWORD /opt/beach/.env | cut -d= -f2)"

# Query diretta su un database
docker exec beach-mysql \
  mysql -u root -p"<PASSWORD>" beach_booking -e "SHOW TABLES;"
```

### Monitoraggio risorse

```bash
# Utilizzo CPU/RAM dei container
docker stats

# Spazio su disco usato da Docker
docker system df
```

---

## 13. Backup e ripristino

### Backup database completo

```bash
# Crea la directory di backup
mkdir -p /opt/beach/backups

# Backup di tutti i database
docker exec beach-mysql mysqldump \
  -u root -p"$(grep MYSQL_ROOT_PASSWORD /opt/beach/.env | cut -d= -f2)" \
  --all-databases \
  --single-transaction \
  --routines \
  --triggers \
  > /opt/beach/backups/backup_$(date +%Y%m%d_%H%M%S).sql

echo "Backup completato: $(ls -lh /opt/beach/backups/*.sql | tail -1)"
```

### Backup automatico giornaliero (cron)

```bash
# Apri il crontab di root
crontab -e

# Aggiungi questa riga (backup ogni giorno alle 3:00 con rotazione 7 giorni)
0 3 * * * docker exec beach-mysql mysqldump -u root -p"$(grep MYSQL_ROOT_PASSWORD /opt/beach/.env | cut -d= -f2)" --all-databases --single-transaction > /opt/beach/backups/backup_$(date +\%Y\%m\%d).sql && find /opt/beach/backups -name "*.sql" -mtime +7 -delete
```

### Ripristino database

```bash
# Ripristina da un file di backup
docker exec -i beach-mysql \
  mysql -u root -p"$(grep MYSQL_ROOT_PASSWORD /opt/beach/.env | cut -d= -f2)" \
  < /opt/beach/backups/backup_20260407_030000.sql
```

### Backup dei file caricati (immagini lidi BeachBooking)

```bash
# Backup del volume uploads
docker run --rm \
  -v beach_beachbooking_uploads:/data \
  -v /opt/beach/backups:/backup \
  alpine tar czf /backup/uploads_$(date +%Y%m%d).tar.gz /data
```

---

## 14. Troubleshooting

### Container che non parte

```bash
# Leggi i log del container problematico
docker compose logs --tail=100 <nome-servizio>

# Esempi comuni:
docker compose logs --tail=100 beach-mysql
docker compose logs --tail=100 beachbooking-app
docker compose logs --tail=100 beachdelivery-api
```

### MySQL non si avvia (primo deploy)

Il primo avvio di MySQL può richiedere 30–60 secondi per l'inizializzazione.
Se continua a fallire:

```bash
# Verifica lo stato del container
docker compose ps mysql

# Leggi i log di inizializzazione
docker compose logs mysql

# Se il volume è corrotto, rimuovilo e riparte (ATTENZIONE: cancella tutti i dati)
docker compose down
docker volume rm beach_mysql_data
docker compose up -d
```

### Errore "address already in use" su porta 80/443

```bash
# Trova il processo che occupa la porta
lsof -i :80
lsof -i :443

# Spesso è Apache (installato di default su alcune distro)
systemctl stop apache2
systemctl disable apache2
systemctl start nginx
```

### Certificato SSL non ottenuto

```bash
# Verifica che Nginx risponda sui 4 domini (su HTTP)
curl http://80-211-137-54.sslip.io
curl http://booking.80-211-137-54.sslip.io

# Riprova con Certbot in modalità verbose
certbot --nginx -d booking.80-211-137-54.sslip.io -v
```

### Il frontend non riesce a chiamare il backend

Verifica che le variabili Vite siano state passate correttamente al build:

```bash
# Controlla il contenuto del bundle JS costruito
docker exec beachdelivery-fe \
  grep -r "api-delivery.80-211-137-54" /usr/share/nginx/html/assets/ | head -3
```

Se non trova nulla, il `.env` non aveva `BEACHDELIVERY_API_URL` al momento del build.
Aggiorna `.env` e ricostruisci:

```bash
docker compose up -d --build beachdelivery-frontend beachdelivery-fe
```

### CORS error nel browser

Verifica che `APP_CORS_ALLOWED_ORIGINS` nel `.env` corrisponda esattamente
all'URL del frontend (incluso `https://`):

```bash
grep APP_CORS_ALLOWED_ORIGINS /opt/beach/.env
# Deve essere: https://delivery.80-211-137-54.sslip.io

# Dopo la modifica, riavvia solo il backend
docker compose up -d --no-deps beachdelivery-backend
```

### Spazio su disco esaurito

```bash
# Controlla lo spazio
df -h

# Rimuovi immagini Docker non usate, container fermati e cache build
docker system prune -af

# Rimuovi anche i volumi orfani (attenzione: non rimuove quelli in uso)
docker volume prune
```

---

## Struttura finale del progetto

```
/opt/beach/
├── docker-compose.yml          ← orchestratore unico
├── .env                        ← variabili d'ambiente (NON su Git)
├── .env.example                ← template da committare
├── mysql-init/
│   └── 01_init.sh              ← crea DB e utenti al primo avvio
├── landing/
│   ├── index.html              ← landing page statica
│   └── Dockerfile
├── beachbooking/
│   ├── beachbooking-backemd/   ← Spring Boot (Java 21)
│   └── beachbooking-frontend/  ← React + Vite
└── beachdelivery/
    ├── bd-be/                  ← Spring Boot (Java 17)
    └── bd-fe/                  ← React + Vite + i18n + WebSocket
```

---

*Generato automaticamente — aggiorna questo file se cambi IP, domini o porte.*
