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

-- =====================================================
-- DOMANDA 3
-- Quanto pesa la spedizione sul prezzo, per categoria?
-- =====================================================
-- Quota spedizione = somma delle spedizioni / somma dei prezzi x 100.
--   Si legge: "su 100 R$ di merce, quanti R$ di spedizione".
--   È un rapporto tra somme, non la media dei rapporti pezzo per
--   pezzo: la media verrebbe gonfiata dai pezzi da pochi R$.
--   Limite: la quota riflette di più i pezzi costosi. Per chi compra
--   un pezzo economico, la spedizione pesa più di quanto dica la quota.
-- freight_value = spedizione pagata dal cliente per il pezzo
--   (se l'ordine ha più pezzi, è già divisa tra i pezzi).


-- 3a. Riferimento: il negozio intero.
-- Risultato: 2.192.092,88 R$ di spedizione su 13.181.027,13 R$
--   di merce, quota 16,63%.
-- E quindi: una categoria "pesa tanto" se sta sopra il 16,63%.
SELECT
    ROUND(SUM(oi.freight_value), 2) AS spedizione_totale,
    ROUND(SUM(oi.price), 2) AS fatturato_totale,
    ROUND(SUM(oi.freight_value) / SUM(oi.price) * 100, 2) AS quota_spedizione
FROM clean.order_items AS oi;


-- 3b. Quota spedizione per categoria, con prezzo e peso tipici.
-- Soglia: solo categorie con almeno 1.000 pezzi (circa l'1% dei pezzi).
--   È una scelta nostra: sotto quella cifra la quota è rumore
--   (es. home_comfort_2: 30 pezzi, 53,97%).
-- HAVING e non WHERE: il numero di pezzi esiste solo dopo il GROUP BY.
-- Prezzo e peso tipici = mediana sui pezzi venduti: pochi pezzi
--   molto cari o molto pesanti alzerebbero la media.
-- Il JOIN con products non perde pezzi (verificato nella domanda 1).
-- Risultato: 22 categorie.
-- Dati:
--   - La quota va da 8,43% (watches_gifts) a 29,47% (electronics).
--   - 12 categorie su 22 sono sopra il negozio (16,63%).
--   - In cima ci sono due profili diversi:
--     economici e leggeri: electronics (21,89 R$, 200 g, 29,47%),
--       telephony (29,99 R$, 225 g, 22,36%);
--     pesanti: office_furniture (144,94 R$, 10.975 g, 25,02%),
--       furniture_decor (65,49 R$, 1.300 g, 23,67%).
--   - In fondo ci sono i prezzi alti: watches_gifts (128,90 R$, 346 g,
--     8,43%), cool_stuff (129,90 R$, 1.450 g, 13,34%).
--   - Ipotesi della domanda 1 confermata: furniture_decor ha prezzo
--     tipico basso e peso tra i più alti, e la spedizione ci pesa
--     più che nel negozio.
-- E quindi:
--   - La spedizione pesa tanto per due motivi diversi, con rimedi
--     diversi (ipotesi di intervento, non risultati):
--     prezzo basso (electronics, telephony): spedizione gratuita
--       sopra una soglia, per spingere a comprare più pezzi insieme;
--     peso alto (mobili): tariffe dei corrieri per peso.
--   - Il prezzo basso spiega la quota per aritmetica (si divide per
--     un numero piccolo). Il peso è un'ipotesi coerente con i dati
--     (i corrieri fanno pagare il peso), non una prova.
--   - Limite: il volume non è considerato. Un mobile leggero ma
--     ingombrante costa da spedire più di quanto dica il peso.
SELECT
    p.product_category,
    COUNT(*) AS pezzi,
    ROUND(SUM(oi.freight_value) / SUM(oi.price) * 100, 2) AS quota_spedizione,
    ROUND(CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY oi.price) AS NUMERIC), 2) AS prezzo_mediano,
    ROUND(CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.product_weight_g) AS NUMERIC), 0) AS peso_mediano_g
FROM clean.order_items AS oi
JOIN clean.products AS p
    ON p.product_id = oi.product_id
GROUP BY p.product_category
HAVING COUNT(*) >= 1000
ORDER BY quota_spedizione DESC;