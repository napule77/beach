-- ============================================================
-- MOCK DATA – BeachDelivery
-- Eseguito automaticamente da DataInitializer solo se il DB è
-- privo di dati (tabella `user` vuota).
-- ============================================================

-- ----------------------------------------------------------------
-- 1. UTENTI  (lido_id NULL, verrà aggiornato al passo 4)
-- ----------------------------------------------------------------
INSERT IGNORE INTO user (id, email, password, nome, cognome, ruolo, attivo, lingua_preferita, lido_id) VALUES
-- SUPER_ADMIN
(1, 'superadmin@beachdelivery.it',
    '$2b$10$4wskPhhNNO7dMbd0tAOXUe5D8dQIxa4XcTAgnFg/lDva7BmbEY/hq',
    'Super', 'Admin', 'SUPER_ADMIN', TRUE, 'it', NULL),
-- GESTORE_LIDO
(2, 'gestore1@beachdelivery.it',
    '$2b$10$s1hHi2UmUvH84YHE2GBitu9caVM6OPuocwrbIEGiyiipkKivcHsOa',
    'Marco', 'Fontana', 'GESTORE_LIDO', TRUE, 'it', NULL),
(3, 'gestore2@beachdelivery.it',
    '$2b$10$s1hHi2UmUvH84YHE2GBitu9caVM6OPuocwrbIEGiyiipkKivcHsOa',
    'Laura', 'Ricci', 'GESTORE_LIDO', TRUE, 'it', NULL),
-- CAMERIERE
(4, 'cameriere1@beachdelivery.it',
    '$2b$10$PIl/z4riLsgTSXlRUZAGBuve5FCyND44EzXgWK7lNqjMlv3znuU82',
    'Giovanni', 'Esposito', 'CAMERIERE', TRUE, 'it', NULL),
(5, 'cameriere2@beachdelivery.it',
    '$2b$10$PIl/z4riLsgTSXlRUZAGBuve5FCyND44EzXgWK7lNqjMlv3znuU82',
    'Alessia', 'Mancini', 'CAMERIERE', TRUE, 'it', NULL),
(6, 'cameriere3@beachdelivery.it',
    '$2b$10$PIl/z4riLsgTSXlRUZAGBuve5FCyND44EzXgWK7lNqjMlv3znuU82',
    'Davide', 'Greco', 'CAMERIERE', TRUE, 'it', NULL),
-- CLIENTE
(7, 'mario.rossi@mail.it',
    '$2b$10$4mCEKAzQaZCC6TvJSPU8ruMTyxAPB7s/4wvSiq4.2BGdJz815y9wi',
    'Mario', 'Rossi', 'CLIENTE', TRUE, 'it', NULL),
(8, 'giulia.bianchi@mail.it',
    '$2b$10$4mCEKAzQaZCC6TvJSPU8ruMTyxAPB7s/4wvSiq4.2BGdJz815y9wi',
    'Giulia', 'Bianchi', 'CLIENTE', TRUE, 'en', NULL),
(9, 'luca.verdi@mail.it',
    '$2b$10$4mCEKAzQaZCC6TvJSPU8ruMTyxAPB7s/4wvSiq4.2BGdJz815y9wi',
    'Luca', 'Verdi', 'CLIENTE', TRUE, 'it', NULL);

-- ----------------------------------------------------------------
-- 2. LIDI
-- ----------------------------------------------------------------
INSERT IGNORE INTO lido (id, nome, indirizzo, gestore_id, attivo, descrizione, orari) VALUES
(1, 'Lido Sole e Mare',
    'Via del Mare 12, Rimini (RN)',
    2, TRUE,
    'Il lido più amato della riviera romagnola con spiaggia attrezzata e servizio in ombrellone.',
    '08:00 – 20:00'),
(2, 'Lido Azzurro',
    'Lungomare Colombo 45, Riccione (RN)',
    3, TRUE,
    'Spiaggia privata con piscina e ristorante fronte mare.',
    '08:30 – 19:30');

-- ----------------------------------------------------------------
-- 3. AGGIORNA lido_id SUGLI UTENTI
-- ----------------------------------------------------------------
UPDATE user SET lido_id = 1 WHERE id IN (2, 4, 5);
UPDATE user SET lido_id = 2 WHERE id IN (3, 6);

-- ----------------------------------------------------------------
-- 4. STAGIONI
-- ----------------------------------------------------------------
INSERT IGNORE INTO stagione (id, lido_id, nome, data_inizio, data_fine, attiva) VALUES
(1, 1, 'Estate 2025', '2025-06-01', '2025-09-30', TRUE),
(2, 2, 'Estate 2025', '2025-06-01', '2025-09-30', TRUE);

-- ----------------------------------------------------------------
-- 5. PERIODI STAGIONE
-- ----------------------------------------------------------------
INSERT IGNORE INTO periodo_stagione (id, stagione_id, nome, data_inizio, data_fine) VALUES
(1, 1, 'Pre-stagione',  '2025-06-01', '2025-06-30'),
(2, 1, 'Alta stagione', '2025-07-01', '2025-08-31'),
(3, 1, 'Fine stagione', '2025-09-01', '2025-09-30'),
(4, 2, 'Pre-stagione',  '2025-06-01', '2025-06-30'),
(5, 2, 'Alta stagione', '2025-07-01', '2025-08-31'),
(6, 2, 'Fine stagione', '2025-09-01', '2025-09-30');

-- ----------------------------------------------------------------
-- 6. LAYOUT
-- ----------------------------------------------------------------
INSERT IGNORE INTO layout (id, lido_id, stagione_id, numero_file, ombrelloni_per_fila, attivo) VALUES
(1, 1, 1, 4, 5, TRUE),
(2, 2, 2, 3, 4, TRUE);

-- ----------------------------------------------------------------
-- 7. OMBRELLONI  (layout 1: 4×5=20 | layout 2: 3×4=12)
-- ----------------------------------------------------------------
INSERT IGNORE INTO ombrellone (id, layout_id, fila, numero, qr_code, attivo) VALUES
-- Layout 1 – fila 1
(1,  1, 1, 1, 'QR-L1-R1-N1', TRUE),(2,  1, 1, 2, 'QR-L1-R1-N2', TRUE),
(3,  1, 1, 3, 'QR-L1-R1-N3', TRUE),(4,  1, 1, 4, 'QR-L1-R1-N4', TRUE),
(5,  1, 1, 5, 'QR-L1-R1-N5', TRUE),
-- Layout 1 – fila 2
(6,  1, 2, 1, 'QR-L1-R2-N1', TRUE),(7,  1, 2, 2, 'QR-L1-R2-N2', TRUE),
(8,  1, 2, 3, 'QR-L1-R2-N3', TRUE),(9,  1, 2, 4, 'QR-L1-R2-N4', TRUE),
(10, 1, 2, 5, 'QR-L1-R2-N5', TRUE),
-- Layout 1 – fila 3
(11, 1, 3, 1, 'QR-L1-R3-N1', TRUE),(12, 1, 3, 2, 'QR-L1-R3-N2', TRUE),
(13, 1, 3, 3, 'QR-L1-R3-N3', TRUE),(14, 1, 3, 4, 'QR-L1-R3-N4', TRUE),
(15, 1, 3, 5, 'QR-L1-R3-N5', TRUE),
-- Layout 1 – fila 4
(16, 1, 4, 1, 'QR-L1-R4-N1', TRUE),(17, 1, 4, 2, 'QR-L1-R4-N2', TRUE),
(18, 1, 4, 3, 'QR-L1-R4-N3', TRUE),(19, 1, 4, 4, 'QR-L1-R4-N4', TRUE),
(20, 1, 4, 5, 'QR-L1-R4-N5', TRUE),
-- Layout 2 – fila 1
(21, 2, 1, 1, 'QR-L2-R1-N1', TRUE),(22, 2, 1, 2, 'QR-L2-R1-N2', TRUE),
(23, 2, 1, 3, 'QR-L2-R1-N3', TRUE),(24, 2, 1, 4, 'QR-L2-R1-N4', TRUE),
-- Layout 2 – fila 2
(25, 2, 2, 1, 'QR-L2-R2-N1', TRUE),(26, 2, 2, 2, 'QR-L2-R2-N2', TRUE),
(27, 2, 2, 3, 'QR-L2-R2-N3', TRUE),(28, 2, 2, 4, 'QR-L2-R2-N4', TRUE),
-- Layout 2 – fila 3
(29, 2, 3, 1, 'QR-L2-R3-N1', TRUE),(30, 2, 3, 2, 'QR-L2-R3-N2', TRUE),
(31, 2, 3, 3, 'QR-L2-R3-N3', TRUE),(32, 2, 3, 4, 'QR-L2-R3-N4', TRUE);

-- ----------------------------------------------------------------
-- 8. CATEGORIE MENU
-- ----------------------------------------------------------------
INSERT IGNORE INTO categoria_menu (id, lido_id, nome, descrizione, ordinamento, attiva) VALUES
-- Lido 1
(1, 1, 'Bevande',  'Acqua, bibite, succhi e birre',      1, TRUE),
(2, 1, 'Cibo',     'Panini, piadine e piatti leggeri',   2, TRUE),
(3, 1, 'Cocktail', 'Aperitivi e long drink',             3, TRUE),
(4, 1, 'Snack',    'Sfizi e stuzzichini',                4, TRUE),
-- Lido 2
(5, 2, 'Bevande',  'Acqua, bibite e succhi',             1, TRUE),
(6, 2, 'Cibo',     'Panini, insalate e piatti freschi',  2, TRUE);

-- ----------------------------------------------------------------
-- 9. TRADUZIONI CATEGORIE (EN)
-- ----------------------------------------------------------------
INSERT IGNORE INTO categoria_menu_trad (id, categoria_id, lingua, nome, descrizione) VALUES
(1,  1, 'en', 'Drinks',    'Water, soft drinks, juices and beers'),
(2,  2, 'en', 'Food',      'Sandwiches, flatbreads and light dishes'),
(3,  3, 'en', 'Cocktails', 'Aperitifs and long drinks'),
(4,  4, 'en', 'Snacks',    'Nibbles and finger food'),
(5,  5, 'en', 'Drinks',    'Water, soft drinks and juices'),
(6,  6, 'en', 'Food',      'Sandwiches, salads and fresh dishes');

-- ----------------------------------------------------------------
-- 10. PRODOTTI
-- ----------------------------------------------------------------
INSERT IGNORE INTO prodotto (id, categoria_id, nome, descrizione, prezzo_base, attivo) VALUES
-- Bevande Lido 1
(1,  1, 'Acqua naturale 0.5L',  'Acqua minerale naturale',              1.50, TRUE),
(2,  1, 'Acqua frizzante 0.5L', 'Acqua minerale frizzante',             1.50, TRUE),
(3,  1, 'Coca-Cola 0.33L',      'Lattina di Coca-Cola ghiacciata',      2.50, TRUE),
(4,  1, 'Birra chiara 0.33L',   'Birra chiara in bottiglia',            3.00, TRUE),
(5,  1, 'Succo di frutta',      'Succo ACE, pesca o pera – 0.2L',       2.00, TRUE),
-- Cibo Lido 1
(6,  2, 'Panino prosciutto e mozzarella', 'Con pomodoro e basilico fresco', 5.00, TRUE),
(7,  2, 'Piadina vegetariana',  'Con verdure grigliate e hummus',       5.50, TRUE),
(8,  2, 'Club sandwich',        'Con pollo, bacon, lattuga e maionese', 6.00, TRUE),
(9,  2, 'Insalata mista',       'Con tonno, olive e pomodori',          5.50, TRUE),
-- Cocktail Lido 1
(10, 3, 'Aperol Spritz',        'Aperol, Prosecco e una fettina d''arancio', 7.00, TRUE),
(11, 3, 'Mojito',               'Rum, menta, lime, zucchero e seltz',   7.50, TRUE),
(12, 3, 'Negroni',              'Gin, Campari e vermouth rosso',        8.00, TRUE),
(13, 3, 'Hugo',                 'Prosecco, sciroppo di sambuco e menta', 7.00, TRUE),
-- Snack Lido 1
(14, 4, 'Patatine fritte',      'Croccanti con ketchup e maionese',     3.50, TRUE),
(15, 4, 'Bruschette al pomodoro','Due bruschette con pomodoro fresco',  4.00, TRUE),
(16, 4, 'Nachos con guacamole', 'Tortilla chips con guacamole fatto in casa', 4.50, TRUE),
-- Bevande Lido 2
(17, 5, 'Acqua naturale 0.5L',  'Acqua minerale naturale',              1.50, TRUE),
(18, 5, 'Coca-Cola 0.33L',      'Lattina di Coca-Cola ghiacciata',      2.50, TRUE),
(19, 5, 'Limonata artigianale', 'Limoni freschi, zucchero e acqua frizzante', 3.50, TRUE),
-- Cibo Lido 2
(20, 6, 'Piadina prosciutto',   'Con prosciutto crudo, rucola e stracchino', 5.50, TRUE),
(21, 6, 'Insalata greca',       'Pomodori, cetrioli, feta e olive',     5.00, TRUE),
(22, 6, 'Wrap pollo e avocado', 'Pollo alla griglia con guacamole',     6.50, TRUE);

-- ----------------------------------------------------------------
-- 11. TRADUZIONI PRODOTTI (EN – campione)
-- ----------------------------------------------------------------
INSERT IGNORE INTO prodotto_trad (id, prodotto_id, lingua, nome, descrizione) VALUES
(1,  1,  'en', 'Still water 0.5L',       'Still mineral water'),
(2,  2,  'en', 'Sparkling water 0.5L',   'Sparkling mineral water'),
(3,  3,  'en', 'Coca-Cola 0.33L',        'Chilled Coca-Cola can'),
(4,  4,  'en', 'Lager beer 0.33L',       'Bottled lager beer'),
(5,  5,  'en', 'Fruit juice',            'ACE, peach or pear juice – 0.2L'),
(6,  6,  'en', 'Ham & mozzarella roll',  'With fresh tomato and basil'),
(7,  7,  'en', 'Veggie flatbread',       'With grilled vegetables and hummus'),
(8,  8,  'en', 'Club sandwich',          'Chicken, bacon, lettuce and mayo'),
(9,  10, 'en', 'Aperol Spritz',          'Aperol, Prosecco and orange slice'),
(10, 11, 'en', 'Mojito',                 'Rum, mint, lime, sugar and soda'),
(11, 14, 'en', 'French fries',           'Crispy with ketchup and mayo'),
(12, 15, 'en', 'Bruschetta',             'Two bruschette with fresh tomato');

-- ----------------------------------------------------------------
-- 12. INGREDIENTI (campione)
-- ----------------------------------------------------------------
INSERT IGNORE INTO ingrediente (id, prodotto_id, nome, allergene, attivo) VALUES
-- Panino prosciutto e mozzarella
(1, 6, 'Pane',        FALSE, TRUE),
(2, 6, 'Prosciutto',  FALSE, TRUE),
(3, 6, 'Mozzarella',  TRUE,  TRUE),  -- lattosio
(4, 6, 'Pomodoro',    FALSE, TRUE),
-- Club sandwich
(5, 8, 'Pane in cassetta', TRUE,  TRUE),  -- glutine
(6, 8, 'Pollo',            FALSE, TRUE),
(7, 8, 'Bacon',            FALSE, TRUE),
(8, 8, 'Lattuga',          FALSE, TRUE),
(9, 8, 'Maionese',         TRUE,  TRUE),  -- uova
-- Aperol Spritz
(10, 10, 'Aperol',   FALSE, TRUE),
(11, 10, 'Prosecco', TRUE,  TRUE),  -- solfiti
(12, 10, 'Arancio',  FALSE, TRUE),
-- Mojito
(13, 11, 'Rum',   FALSE, TRUE),
(14, 11, 'Menta', FALSE, TRUE),
(15, 11, 'Lime',  FALSE, TRUE);

-- ----------------------------------------------------------------
-- 13. TRADUZIONI INGREDIENTI (EN)
-- ----------------------------------------------------------------
INSERT IGNORE INTO ingrediente_trad (id, ingrediente_id, lingua, nome) VALUES
(1,  1,  'en', 'Bread'),
(2,  2,  'en', 'Ham'),
(3,  3,  'en', 'Mozzarella'),
(4,  4,  'en', 'Tomato'),
(5,  5,  'en', 'Sliced bread'),
(6,  6,  'en', 'Chicken'),
(7,  7,  'en', 'Bacon'),
(8,  8,  'en', 'Lettuce'),
(9,  9,  'en', 'Mayonnaise'),
(10, 10, 'en', 'Aperol'),
(11, 11, 'en', 'Prosecco'),
(12, 12, 'en', 'Orange');

-- ----------------------------------------------------------------
-- 14. PROMOZIONI
-- ----------------------------------------------------------------
INSERT IGNORE INTO promozione (id, lido_id, nome, descrizione, tipo, valore, data_inizio, data_fine, attiva, attivazione_manuale) VALUES
(1, 1, 'Happy Hour',
    'Sconto del 20% su tutti i cocktail dalle 17:00 alle 19:00',
    'SCONTO_PERCENTUALE', 20.00,
    '2025-07-01 17:00:00', '2025-09-30 19:00:00',
    TRUE, FALSE),
(2, 1, 'Combo Pranzo',
    'Panino + bevanda a prezzo fisso',
    'PREZZO_FISSO', 7.00,
    '2025-06-01 12:00:00', '2025-09-30 14:30:00',
    TRUE, FALSE),
(3, 2, 'Benvenuto Estate',
    'Sconto 10% su tutti i prodotti nella prima settimana',
    'SCONTO_PERCENTUALE', 10.00,
    '2025-06-01 00:00:00', '2025-06-07 23:59:59',
    FALSE, FALSE);

-- ----------------------------------------------------------------
-- 15. PROMOZIONE → PRODOTTI
-- ----------------------------------------------------------------
INSERT IGNORE INTO promozione_prodotto (id, promozione_id, prodotto_id, categoria_id) VALUES
-- Happy Hour su categoria cocktail (cat. 3)
(1, 1, NULL, 3),
-- Combo Pranzo: panino (6) e acqua (1)
(2, 2, 6,    NULL),
(3, 2, 1,    NULL),
-- Benvenuto Estate su tutta la categoria cibo Lido 2 (cat. 6)
(4, 3, NULL, 6);

-- ----------------------------------------------------------------
-- 16. ORDINI
-- ----------------------------------------------------------------
INSERT IGNORE INTO ordine (id, cliente_id, lido_id, ombrellone_id,
    data_ordine, stato, totale, metodo_pagamento, paypal_order_id,
    qr_code, data_consegna) VALUES
(1, 7, 1, 3,
    '2025-07-15 11:30:00', 'CONSEGNATO', 11.00, 'CARTA', NULL,
    'ORD-QR-0001', '2025-07-15 11:55:00'),
(2, 8, 1, 7,
    '2025-07-15 13:15:00', 'CONSEGNATO', 14.50, 'PAYPAL', 'PAYPAL-TEST-0002',
    'ORD-QR-0002', '2025-07-15 13:40:00'),
(3, 9, 2, 21,
    '2025-07-16 12:00:00', 'IN_PREPARAZIONE', 8.50, 'CONTANTI', NULL,
    'ORD-QR-0003', NULL);

-- ----------------------------------------------------------------
-- 17. ORDINE DETTAGLI
-- ----------------------------------------------------------------
INSERT IGNORE INTO ordine_dettaglio (id, ordine_id, prodotto_id, quantita, prezzo_unitario, prezzo_totale, note) VALUES
-- Ordine 1: acqua + panino prosciutto
(1, 1, 1, 1, 1.50,  1.50, NULL),
(2, 1, 6, 1, 5.00,  5.00, 'senza pomodoro'),
(3, 1, 3, 1, 2.50,  2.50, NULL),
(4, 1, 5, 1, 2.00,  2.00, NULL),
-- Ordine 2: mojito + club sandwich + patatine
(5, 2, 11, 1, 7.50, 7.50, NULL),
(6, 2, 8,  1, 6.00, 6.00, NULL),
(7, 2, 14, 1, 3.50, 3.50, NULL),
-- Ordine 3: piadina + Coca-Cola
(8, 3, 20, 1, 5.50, 5.50, NULL),
(9, 3, 18, 1, 2.50, 2.50, NULL);

-- ----------------------------------------------------------------
-- 18. NOTIFICHE
-- ----------------------------------------------------------------
INSERT IGNORE INTO notifica (id, user_id, tipo, messaggio, data_invio, letto, via_email, ordine_id) VALUES
(1, 4, 'NUOVO_ORDINE',
    'Nuovo ordine #1 all''ombrellone F1-N3 – totale €11.00',
    '2025-07-15 11:30:05', TRUE, FALSE, 1),
(2, 7, 'ORDINE_CONSEGNATO',
    'Il tuo ordine #1 è stato consegnato. Buon appetito!',
    '2025-07-15 11:55:10', TRUE, FALSE, 1),
(3, 4, 'NUOVO_ORDINE',
    'Nuovo ordine #2 all''ombrellone F2-N2 – totale €14.50',
    '2025-07-15 13:15:05', TRUE, FALSE, 2),
(4, 8, 'ORDINE_CONSEGNATO',
    'Il tuo ordine #2 è stato consegnato. Buon appetito!',
    '2025-07-15 13:40:10', FALSE, TRUE, 2),
(5, 6, 'NUOVO_ORDINE',
    'Nuovo ordine #3 all''ombrellone F1-N1 – totale €8.50',
    '2025-07-16 12:00:10', FALSE, FALSE, 3);
