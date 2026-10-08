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

-- ---------------------------------------------------------
-- Tabella prodotti (catalogo)
-- Tutti i prodotti di raw, senza filtro: è un'anagrafica.
--   Filtrarla con un JOIN sulle vendite ripeterebbe ogni prodotto
--   una volta per ogni vendita. Le analisi partono dalle vendite,
--   quindi i prodotti mai venduti nel periodo non compaiono comunque.
-- product_category: categoria in inglese, costruita con CASE WHEN:
--   - 610 prodotti senza categoria -> 'senza categoria'
--   - 2 categorie senza traduzione, 13 prodotti, tradotte a mano:
--     pc_gamer (3), portateis_cozinha_e_preparadores_de_alimentos (10)
--   - tutte le altre -> traduzione da raw.category_translation
--   LEFT JOIN e non JOIN: con JOIN sparirebbero 623 prodotti
--   (610 senza categoria + 13 senza traduzione).
-- product_weight_g: per spiegare il peso della spedizione (domanda 3).
--   Limite: anche il volume incide sulla spedizione, non usato.
-- Scartati: nome portoghese (serve solo al collegamento), dimensioni,
--   lunghezza di nome e descrizione, numero di foto.
-- Chiave: product_id
-- Righe attese: 32.951
-- ---------------------------------------------------------

DROP TABLE IF EXISTS clean.products;

CREATE TABLE clean.products AS
SELECT
    p.product_id,
    CASE
        WHEN p.product_category_name IS NULL THEN 'senza categoria'
        WHEN p.product_category_name = 'pc_gamer' THEN 'pc_gamer'
        WHEN p.product_category_name = 'portateis_cozinha_e_preparadores_de_alimentos' THEN 'portable_kitchen_and_food_preparers'
        ELSE ct.product_category_name_english
    END AS product_category,
    CAST(p.product_weight_g AS INTEGER) AS product_weight_g
FROM raw.products AS p
LEFT JOIN raw.category_translation AS ct
    ON p.product_category_name = ct.product_category_name;

-- Verifica 1. Attesi: righe = chiavi_distinte = con_categoria = 32.951
-- Risultato: 32.951 / 32.951 / 32.951. Nessun doppione sulla chiave
--   e nessun prodotto rimasto senza categoria.
SELECT
    COUNT(*) AS righe,
    COUNT(DISTINCT p.product_id) AS chiavi_distinte,
    COUNT(p.product_category) AS con_categoria
FROM clean.products AS p;

-- Verifica 2. I tre casi speciali del CASE. Attesi: 610, 3, 10
-- Risultato: senza categoria 610, pc_gamer 3,
--   portable_kitchen_and_food_preparers 10.
-- Dato: i prodotti senza categoria sono circa l'1,9% del catalogo.
-- E quindi: "senza categoria" comparirà nei grafici per categoria;
--   il suo peso sulle vendite si calcola nelle analisi (sessione 7).
SELECT
    p.product_category,
    COUNT(*) AS prodotti
FROM clean.products AS p
WHERE p.product_category = 'senza categoria'
    OR p.product_category = 'pc_gamer'
    OR p.product_category = 'portable_kitchen_and_food_preparers'
GROUP BY p.product_category;

-- ---------------------------------------------------------
-- Tabella recensioni
-- Una sola recensione per ordine: la più recente.
--   In raw al massimo lo 0,6% degli ordini ha più recensioni
--   (fino a 3): tenerle tutte duplicherebbe quegli ordini
--   nella domanda 4.
-- "Più recente" = review_answer_timestamp: quando il cliente
--   risponde, con l'ora. review_creation_date ha solo il giorno,
--   quindi due recensioni dello stesso giorno sarebbero pari merito.
-- Metodo: ROW_NUMBER numera le recensioni di ogni ordine dalla più
--   recente; serve il WITH perché il WHERE non vede posizione.
-- Solo ordini presenti in clean.orders: il JOIN fa da filtro.
-- Colonne: order_id, review_score (domanda 4).
-- Scartati: review_id (814 doppioni, non può essere chiave),
--   titolo e testo del commento (non usati), le due date
--   (servono solo a scegliere).
-- Chiave: order_id
-- Righe attese: al massimo 96.211 (gli ordini consegnati
--   senza recensione restano fuori)
-- ---------------------------------------------------------

DROP TABLE IF EXISTS clean.reviews;

CREATE TABLE clean.reviews AS
WITH recensioni_numerate AS (
    SELECT
        order_id,
        review_score,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY CAST(review_answer_timestamp AS TIMESTAMP) DESC
        ) AS posizione
    FROM raw.order_reviews
)
SELECT
    rn.order_id,
    CAST(rn.review_score AS INTEGER) AS review_score
FROM recensioni_numerate AS rn
JOIN clean.orders AS o
    ON o.order_id = rn.order_id
WHERE rn.posizione = 1;

-- Verifica 1. Attesi: righe = chiavi_distinte = con_voto
-- Risultato: 95.568 / 95.568 / 95.568. Una sola recensione per
--   ordine, nessun voto vuoto.
-- Dato: 643 ordini consegnati (0,7%) non hanno recensione.
-- E quindi: la domanda 4 lavora su 95.568 ordini; lo 0,7% escluso
--   pesa poco, ma va dichiarato nel README.
SELECT
    COUNT(*) AS righe,
    COUNT(DISTINCT r.order_id) AS chiavi_distinte,
    COUNT(r.review_score) AS con_voto
FROM clean.reviews AS r;

-- Verifica 2. Distribuzione dei voti. Attesi: solo voti 1-5,
--   somma 95.568.
-- Risultato: 1 = 9.314 (9,7%), 2 = 2.915 (3,1%), 3 = 7.895 (8,3%),
--   4 = 18.837 (19,7%), 5 = 56.607 (59,2%). Somma 95.568.
-- Dato: il 78,9% dei voti è 4 o 5; il voto 1 è più di tre volte
--   più frequente del 2 (voti polarizzati).
-- E quindi: la mediana sarà 5 quasi ovunque e non distingue i
--   gruppi. Per la domanda 4 conviene misurare la quota di voti
--   negativi (1-2) o la media: da decidere nella sessione 7.
SELECT
    r.review_score,
    COUNT(*) AS recensioni
FROM clean.reviews AS r
GROUP BY r.review_score
ORDER BY r.review_score;