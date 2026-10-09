-- =====================================================
-- 04_analisi.sql
-- Analisi SQL sulle 4 domande di business
-- Base: schema clean (solo ordini delivered,
--   acquisti da gennaio 2017 ad agosto 2018)
-- =====================================================
--
-- Domande:
-- 1. Quali categorie vendono di più (fatturato e pezzi)?
-- 2. Come cambiano le vendite nel tempo, quali categorie crescono?
-- 3. Quanto pesa la spedizione sul prezzo, per categoria?
-- 4. I ritardi di consegna peggiorano le recensioni?
--    In quali stati si consegna peggio?

-- =====================================================
-- DOMANDA 1
-- Quali categorie vendono di più (fatturato e pezzi)?
-- =====================================================
-- Definizioni:
--   Fatturato = somma di price in R$, senza spedizione
--     (la spedizione si analizza nella domanda 3).
--     È il valore dei prodotti venduti, non i ricavi di Olist:
--     Olist è un marketplace e incassa commissioni,
--     che nel dataset non ci sono.
--   Pezzi = righe di clean.order_items (una riga = un pezzo).
-- Totali di controllo, da clean.order_items:
--   13.181.027,13 R$ e 109.880 pezzi.


-- Verifica 1. Il JOIN con products non perde pezzi.
-- Attesi: 13.181.027,13 e 109.880 (i totali di controllo).
-- Risultato: 13.181.027,13 e 109.880. Ogni pezzo venduto ha il suo
--   prodotto in catalogo: basta il JOIN, nessun pezzo orfano.
SELECT
    ROUND(SUM(oi.price), 2) AS fatturato_totale,
    COUNT(*) AS pezzi_totali
FROM clean.order_items AS oi
JOIN clean.products AS p
    ON p.product_id = oi.product_id;


-- Fatturato, pezzi e quota sul totale per ogni categoria.
-- Le quote si calcolano su tutte le categorie: un WHERE aggiunto
--   qui cambierebbe il totale, e quindi le percentuali.
-- Risultato: 74 categorie, compresa "senza categoria".
-- Dati:
--   - health_beauty: 1ª per fatturato (9,33%), 2ª per pezzi (8,57%).
--   - bed_bath_table: 1ª per pezzi (9,96%), 3ª per fatturato (7,76%).
--   - watches_gifts: 2ª per fatturato (8,83%), 7ª per pezzi (5,33%):
--     in media ogni pezzo vale più della media generale.
--   - furniture_decor: 4ª per pezzi (7,37%), ma 5,36% del fatturato.
--   - "senza categoria": 1,29% del fatturato, 1,40% dei pezzi.
-- E quindi:
--   - "Chi vende di più" ha due risposte: soldi e volumi non coincidono.
--     La classifica per fatturato dice dove stanno i ricavi, quella
--     per pezzi dove sta il lavoro di magazzino e spedizione.
--     Nella dashboard servono tutte e due.
--   - "Senza categoria" pesa poco: resta come barra a sé nei grafici.
--     Limite: vale più del distacco tra 1ª e 2ª per fatturato
--     (circa 66 mila R$), quindi l'ordine dei primi posti non è certo.
-- Ipotesi da verificare nella domanda 3: furniture_decor vende pezzi
--   sotto il prezzo medio (dato) e probabilmente pesanti (ipotesi),
--   quindi la spedizione dovrebbe pesarci più che altrove.
WITH categorie AS (
    SELECT
        p.product_category,
        ROUND(SUM(oi.price), 2) AS fatturato,
        COUNT(*) AS pezzi
    FROM clean.order_items AS oi
    JOIN clean.products AS p
        ON p.product_id = oi.product_id
    GROUP BY p.product_category
)
SELECT
    c.product_category,
    c.fatturato,
    ROUND(c.fatturato / SUM(c.fatturato) OVER () * 100, 2) AS quota_fatturato,
    c.pezzi,
    ROUND(c.pezzi / SUM(c.pezzi) OVER () * 100, 2) AS quota_pezzi
FROM categorie AS c
ORDER BY c.fatturato DESC;