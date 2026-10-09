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

-- =====================================================
-- DOMANDA 4
-- I ritardi di consegna peggiorano le recensioni?
-- In quali stati si consegna peggio?
-- =====================================================
-- Ritardo = consegna dopo la data stimata (almeno 1 giorno).
--   Consegnato il giorno stimato o prima = in tempo.
-- Solo ordini con data di consegna (decisione dello strato pulito).
-- Recensioni: quota negative (voto 1-2) come misura principale,
--   voto medio come seconda. La mediana non serve: i voti sono
--   polarizzati e sarebbe quasi sempre 5.
-- AVG(CASE WHEN ... THEN 1 ELSE 0 END) * 100 = quota in %:
--   la media di una colonna di 1 e 0 è la quota degli 1.


-- 4a. Recensioni: ordini in tempo contro ordini in ritardo.
-- Il JOIN con reviews tiene solo gli ordini con una recensione.
-- Verifica: 89.182 + 6.378 = 95.560 ordini. Le recensioni sono 95.568:
--   la differenza (8) sono gli 8 ordini senza data di consegna.
-- Dati:
--   - In ritardo: 6.378 ordini (6,67%), voto medio 2,27,
--     negative 62,42%.
--   - In tempo: 89.182 ordini, voto medio 4,29, negative 9,25%.
--   - Con il ritardo le negative passano dal 9,25% al 62,42%:
--     quasi 7 volte tanto.
--   - Il 6,67% degli ordini (quelli in ritardo) produce circa un terzo
--     delle recensioni negative (circa 3.980 su 12.230,
--     calcolate dalle quote).
-- E quindi:
--   - Sì: i ritardi peggiorano le recensioni, e di molto.
--   - Ridurre i ritardi è la leva più forte sulle recensioni: riguarda
--     pochi ordini, ma un terzo delle negative.
WITH consegne AS (
    SELECT
        CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
             THEN 'in ritardo'
             ELSE 'in tempo'
        END AS consegna,                                   
        r.review_score                                     
    FROM clean.orders AS o
    JOIN clean.reviews AS r
        ON r.order_id = o.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
)
SELECT
    c.consegna,
    COUNT(*) AS ordini,
    ROUND(AVG(c.review_score), 2) AS voto_medio,
    ROUND(AVG(CASE WHEN c.review_score <= 2 THEN 1 ELSE 0 END) * 100, 2) AS quota_negative
FROM consegne AS c
GROUP BY c.consegna
ORDER BY c.consegna;


-- 4b. Recensioni per fascia di ritardo.
-- Verifica: le 4 fasce di ritardo sommano 6.378 ordini, come in 4a.
-- Dati (quota negative / voto medio):
--   - in tempo: 9,25% / 4,29
--   - ritardo 1-3 giorni: 32,14% / 3,29 (3,5 volte le negative in tempo)
--   - ritardo 4-7 giorni: 67,68% / 2,10
--   - ritardo 8-14 giorni: 80,15% / 1,67
--   - ritardo oltre 14 giorni: 78,32% / 1,72
-- E quindi:
--   - Più il ritardo è lungo, più le recensioni peggiorano. È un indizio
--     forte che il ritardo sia una causa, non una coincidenza.
--     Resta un'ipotesi: i dati mostrano il legame, non lo dimostrano
--     (es. uno stesso venditore potrebbe causare sia ritardi sia
--     prodotti difettosi).
--   - Anche 1-3 giorni di ritardo pesano: le negative triplicano.
--   - Dopo una settimana il danno è quasi al massimo (4 su 5 negative)
--     e poi si ferma: conta soprattutto non sforare la prima settimana.
WITH consegne AS (
    SELECT
        CASE
            WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
                THEN '1. in tempo'
            WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date + 3
                THEN '2. ritardo 1-3 giorni'
            WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date + 7
                THEN '3. ritardo 4-7 giorni'
            WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date + 14
                THEN '4. ritardo 8-14 giorni'
            ELSE '5. ritardo oltre 14 giorni'
        END AS fascia,
        r.review_score
    FROM clean.orders AS o
    JOIN clean.reviews AS r
        ON r.order_id = o.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
)
SELECT
    c.fascia,
    COUNT(*) AS ordini,
    ROUND(AVG(c.review_score), 2) AS voto_medio,
    ROUND(AVG(CASE WHEN c.review_score <= 2 THEN 1 ELSE 0 END) * 100, 2) AS quota_negative
FROM consegne AS c
GROUP BY c.fascia
ORDER BY c.fascia;


-- 4c. Consegne per stato del cliente.
-- Giorni di consegna = data di consegna - data di acquisto (mediana).
-- Quota ritardo = % di ordini consegnati dopo la data stimata.
-- Soglia: solo stati con almeno 100 ordini, sotto la quota è rumore.
--   Non uso l'1% degli ordini: taglierebbe proprio gli stati piccoli,
--   che potrebbero essere la risposta.
-- Qui non servono le recensioni: si contano tutti gli ordini con
--   data di consegna.
-- Risultato: 24 stati (3 esclusi perché sotto i 100 ordini).
-- Dati:
--   - Quota ritardo più alta: AL 21,46% (1 ordine su 5), MA 17,53%,
--     SE 15,36%, PI 13,89%, CE 13,83%. Tutti stati del nord-est.
--   - RJ: 12.310 ordini (secondo mercato) e 12,14% di ritardi, quasi
--     3 volte SP (4,50%). Circa 1.500 ordini in ritardo, poco meno di
--     SP (circa 1.800), che però ha più del triplo degli ordini.
--   - SP: consegna più veloce (7 giorni mediani) e una delle quote
--     di ritardo più basse.
--   - Lontano non vuol dire in ritardo: AM ha la consegna più lenta
--     (26 giorni) ma la quota di ritardo più bassa (2,76%).
-- E quindi:
--   - "Consegnare peggio" si misura sulla promessa, non sui giorni:
--     le recensioni peggiorano con il ritardo rispetto alla data stimata
--     (4a, 4b). Dove la data stimata è realistica, anche una consegna
--     lunga non è un ritardo.
--   - Priorità: RJ per numero di ordini in ritardo, il nord-est
--     (AL, MA, SE, PI, CE) per quota.
--   - Ipotesi (non verificata): nel nord-est la data stimata è troppo
--     ottimista. Le leve possibili: consegnare più in fretta o
--     promettere date più realistiche.
--   - Ipotesi: SP è servito meglio perché lì ci sono molti venditori.
--     I venditori non fanno parte di questo progetto.
--   - Limite: gli stati sotto i 400 ordini (AL, SE, TO, RO, AM) hanno
--     quote meno stabili.
SELECT
    cu.customer_state AS stato,
    COUNT(*) AS ordini,
    ROUND(CAST(PERCENTILE_CONT(0.5) WITHIN GROUP
        (ORDER BY o.order_delivered_customer_date - o.order_purchase_date)
        AS NUMERIC), 1) AS giorni_consegna_mediani,
    ROUND(AVG(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
                   THEN 1 ELSE 0 END) * 100, 2) AS quota_ritardo
FROM clean.orders AS o
JOIN clean.customers AS cu
    ON cu.customer_id = o.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY cu.customer_state
HAVING COUNT(*) >= 100
ORDER BY quota_ritardo DESC;