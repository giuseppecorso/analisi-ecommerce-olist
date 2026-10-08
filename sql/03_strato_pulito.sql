-- =====================================================
-- 03_strato_pulito.sql
-- Strato pulito: tabelle con tipi corretti,
-- solo ordini delivered e solo il periodo di analisi
-- =====================================================

-- Creazione schema clean dove inseriremo le tabelle pulite
CREATE SCHEMA IF NOT EXISTS clean;


-- -----------------------------------------------------
-- Tabella ordini
-- Periodo (data di acquisto): 01/01/2017 -> 31/08/2018
-- Date senza ora: la logica di business ragiona in giorni e mesi,
--   e sottraendo due date si ottengono direttamente i giorni
-- Solo ordini delivered: degli altri stati non sappiamo
--   se sono andati a buon fine
-- -----------------------------------------------------

DROP TABLE IF EXISTS clean.orders;

CREATE TABLE clean.orders AS
SELECT
    o.order_id,
    o.customer_id,
    CAST(o.order_purchase_timestamp AS DATE)      AS order_purchase_date,
    CAST(o.order_delivered_customer_date AS DATE) AS order_delivered_customer_date,
    CAST(o.order_estimated_delivery_date AS DATE) AS order_estimated_delivery_date
FROM raw.orders o
WHERE CAST(o.order_purchase_timestamp AS DATE) >= '2017-01-01'
  AND CAST(o.order_purchase_timestamp AS DATE) <= '2018-08-31'
  AND o.order_status = 'delivered';

-- Verifica: 96.211 ordini
SELECT COUNT(*) FROM clean.orders;


-- -----------------------------------------------------
-- Tabella righe d'ordine
-- Solo le righe degli ordini presenti in clean.orders
--   (delivered e nel periodo): il JOIN fa da filtro
-- Chiave: order_id + order_item_id
-- -----------------------------------------------------

DROP TABLE IF EXISTS clean.order_items;

CREATE TABLE clean.order_items AS
SELECT
    oi.order_id,
    CAST(oi.order_item_id AS INTEGER) AS order_item_id,
    oi.product_id,
    CAST(oi.price AS NUMERIC)         AS price,
    CAST(oi.freight_value AS NUMERIC) AS freight_value
FROM raw.order_items oi
JOIN clean.orders o
    ON o.order_id = oi.order_id;

-- Verifica: 109.880 righe
SELECT COUNT(*) FROM clean.order_items;

-- ---------------------------------------------------------
-- Tabella clienti
-- Solo i clienti degli ordini presenti in clean.orders
--   (delivered e nel periodo): il JOIN fa da filtro
-- Colonne: customer_unique_id per contare le persone vere,
--   customer_state per la domanda 4. CAP e città scartati.
-- Chiave: customer_id (uno per ordine)
-- Righe attese: 96.211, come clean.orders
-- ---------------------------------------------------------

DROP TABLE IF EXISTS clean.customers;

CREATE TABLE clean.customers AS
SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_state
FROM raw.customers AS c
JOIN clean.orders AS o
    ON o.customer_id = c.customer_id;

-- Verifica. Attesi: righe = chiavi_distinte = 96.211, stati = 27
-- Risultato: 96.211 righe, 96.211 chiavi distinte (nessun doppione),
--   93.104 persone, 27 stati.
-- Dato: gli ordini in più rispetto alle persone sono 3.107, quindi
--   al massimo il 3,3% dei clienti ha fatto più di un ordine nel periodo.
-- E quindi: l'effetto dei ritardi non si misura sui riacquisti
--   (quasi nessuno torna), ma sulle recensioni (domanda 4).
-- Ipotesi, non dimostrata: c'è margine per lavorare sulla fidelizzazione.
SELECT
    COUNT(*) AS righe,
    COUNT(DISTINCT c.customer_id) AS chiavi_distinte,
    COUNT(DISTINCT c.customer_unique_id) AS persone,
    COUNT(DISTINCT c.customer_state) AS stati
FROM clean.customers AS c;