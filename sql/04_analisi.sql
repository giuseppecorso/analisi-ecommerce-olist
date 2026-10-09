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

-- =====================================================
-- DOMANDA 2
-- Come cambiano le vendite nel tempo, quali categorie crescono?
-- =====================================================
-- Mese = mese della data di acquisto (la vendita è l'acquisto).
-- Fatturato e pezzi: stesse definizioni della domanda 1.


-- 2a. Fatturato e pezzi per mese.
-- Il JOIN con orders non può perdere pezzi: clean.order_items
--   è stata costruita con un JOIN su clean.orders.
-- Atteso: 20 mesi (gen 2017 - ago 2018).
-- Risultato: 20 mesi. La somma dei mesi dà 13.181.027,13 R$
--   e 109.880 pezzi, uguale ai totali di controllo.
-- Dati:
--   - gen-ott 2017: crescita continua, da 112 mila a 648 mila R$ al mese.
--   - nov 2017: 988 mila R$, il mese più alto del periodo
--     (+52% su ottobre).
--   - gen-ago 2018: stabile, tra 826 e 978 mila R$ al mese.
--   - Stessi mesi a confronto: gen-ago 2017 2.993.456,13 R$,
--     gen-ago 2018 7.218.125,12 R$ (+141,13%).
-- Ipotesi (non verificate):
--   - Il picco di novembre 2017 è il Black Friday (24/11/2017).
--   - Giu-ago 2018 un po' più bassi: calo reale, oppure ordini ancora
--     in viaggio quando il dataset è stato estratto, quindi non
--     delivered ed esclusi.
-- E quindi:
--   - Il 2017 è l'anno della crescita, il 2018 della stabilità.
--     Gli anni interi non si confrontano (del 2018 ci sono 8 mesi):
--     si confrontano gli stessi mesi.
--   - Ogni crescita di categoria va letta rispetto al +141,13%
--     del negozio: sotto quella cifra la categoria perde quota.
SELECT
    TO_CHAR(o.order_purchase_date, 'YYYY-MM') AS mese,
    ROUND(SUM(oi.price), 2) AS fatturato,
    COUNT(*) AS pezzi
FROM clean.order_items AS oi
JOIN clean.orders AS o
    ON o.order_id = oi.order_id
GROUP BY TO_CHAR(o.order_purchase_date, 'YYYY-MM')
ORDER BY mese;


-- 2b. Verifica delle date usate nel confronto gen-ago.
-- Attesi: 2.993.456,13 e 7.218.125,12
--   (somma dei mesi gen-ago della 2a).
-- Risultato: 2.993.456,13 e 7.218.125,12. Le condizioni sulle date
--   non perdono nessuna vendita.
SELECT
    ROUND(SUM(CASE WHEN o.order_purchase_date >= '2017-01-01'
                    AND o.order_purchase_date <= '2017-08-31'
                   THEN oi.price END), 2) AS fatturato_2017,
    ROUND(SUM(CASE WHEN o.order_purchase_date >= '2018-01-01'
                    AND o.order_purchase_date <= '2018-08-31'
                   THEN oi.price END), 2) AS fatturato_2018
FROM clean.order_items AS oi
JOIN clean.orders AS o
    ON o.order_id = oi.order_id
JOIN clean.products AS p
    ON p.product_id = oi.product_id;


-- 2c. Crescita per categoria, gen-ago 2017 contro gen-ago 2018.
-- Soglia: solo categorie con almeno 30.000 R$ in gen-ago 2017
--   (circa l'1% del totale). È una scelta nostra: sotto quella cifra
--   bastano pochi ordini per far esplodere la percentuale
--   (es. construction_tools_construction: da 2.581 a 122.887 R$,
--   +4.660%).
-- Il WHERE lavora sulla colonna del WITH, già calcolata.
-- Risultato: 24 categorie.
-- Dati:
--   - Tra le 24 nessuna cala: tutte crescono in valore.
--   - 9 su 24 crescono più del negozio (+141,13%). In testa baby
--     (+268,56%), stationery (+260,29%), watches_gifts (+241,98%),
--     health_beauty (+210,33%).
--   - 15 su 24 crescono meno del negozio, quindi perdono quota.
--     bed_bath_table, 1ª per pezzi, si ferma a +109,22%.
--   - cool_stuff è ultima: +10,39%. In gen-ago 2017 era 5ª
--     per fatturato, in gen-ago 2018 è 10ª.
-- E quindi:
--   - Il fatturato si concentra sulle due categorie che già vendevano
--     di più (watches_gifts e health_beauty): la loro quota sale.
--   - Crescere non basta: con il negozio a +141%, una categoria a +100%
--     sta perdendo terreno. Nella dashboard la crescita va mostrata
--     con il +141% come linea di riferimento.
--   - cool_stuff è il caso da approfondire. Il perché (assortimento,
--     venditori, prezzi) con i dati di questo progetto non si vede.
WITH categorie AS (
    SELECT
        p.product_category,
        ROUND(SUM(CASE WHEN o.order_purchase_date >= '2017-01-01'
                        AND o.order_purchase_date <= '2017-08-31'
                       THEN oi.price END), 2) AS fatturato_2017,
        ROUND(SUM(CASE WHEN o.order_purchase_date >= '2018-01-01'
                        AND o.order_purchase_date <= '2018-08-31'
                       THEN oi.price END), 2) AS fatturato_2018
    FROM clean.order_items AS oi
    JOIN clean.orders AS o
        ON o.order_id = oi.order_id
    JOIN clean.products AS p
        ON p.product_id = oi.product_id
    GROUP BY p.product_category
)
SELECT
    c.product_category,
    c.fatturato_2017,
    c.fatturato_2018,
    ROUND((c.fatturato_2018 - c.fatturato_2017) / c.fatturato_2017 * 100, 2) AS crescita
FROM categorie AS c
WHERE c.fatturato_2017 >= 30000
ORDER BY crescita DESC;