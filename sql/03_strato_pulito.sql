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