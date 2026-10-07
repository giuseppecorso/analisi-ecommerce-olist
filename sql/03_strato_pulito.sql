-- Creazione schema clean dove inseriremo le tabelle pulite

CREATE SCHEMA IF NOT EXISTS clean;

-- Creazione tabella ordini pulita con casting dei tipi
-- Periodo: 01/01/2017 -> 31/08/2018 senza l'ora per facilitare le operazioni e perché la logica
-- di business ragiona in giorni e mesi
-- Solo ordini delivered: degli altri stati non sappiamo se sono andati a buon fine

DROP TABLE IF EXISTS clean.orders;

CREATE TABLE clean.orders AS
SELECT o.order_id, o.customer_id, 
CAST(o.order_purchase_timestamp AS DATE) AS order_purchase_date,
CAST(o.order_delivered_customer_date AS DATE) AS order_delivered_customer_date,
CAST(o.order_estimated_delivery_date AS DATE) AS order_estimated_delivery_date
FROM raw.orders o
WHERE CAST(o.order_purchase_timestamp AS DATE) >= '2017-01-01'
AND CAST(o.order_purchase_timestamp AS DATE) <= '2018-08-31'
AND o.order_status = 'delivered';

SELECT COUNT(*) FROM clean.orders;