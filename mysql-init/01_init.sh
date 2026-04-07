#!/bin/bash
# Script di inizializzazione MySQL condiviso.
# Viene eseguito UNA SOLA VOLTA alla prima creazione del volume.
set -e

echo "[init] Creazione database e utenti..."

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL
    -- --------------------------------------------------------
    -- Beach Booking
    -- --------------------------------------------------------
    CREATE DATABASE IF NOT EXISTS beach_booking
        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

    CREATE USER IF NOT EXISTS 'beach'@'%'
        IDENTIFIED WITH mysql_native_password BY '${BEACHBOOKING_DB_PASSWORD}';

    GRANT ALL PRIVILEGES ON beach_booking.* TO 'beach'@'%';

    -- --------------------------------------------------------
    -- Beach Delivery
    -- --------------------------------------------------------
    CREATE DATABASE IF NOT EXISTS beachdelivery
        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

    CREATE USER IF NOT EXISTS 'bdapp'@'%'
        IDENTIFIED WITH mysql_native_password BY '${BEACHDELIVERY_DB_PASSWORD}';

    GRANT ALL PRIVILEGES ON beachdelivery.* TO 'bdapp'@'%';

    FLUSH PRIVILEGES;
EOSQL

echo "[init] Database e utenti creati con successo."
