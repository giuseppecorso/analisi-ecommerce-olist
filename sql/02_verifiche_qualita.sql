-- Verifiche di qualità sui dati raw

-- Verifica 1: ordini "delivered" senza data di consegna
-- Risultato: 8 ordini
-- Conclusione: probabile errore di registrazione. Per i tempi di consegna
--              usiamo solo ordini con la data presente, quindi restano fuori.
--              Per le vendite restano: sono ordini consegnati.
SELECT COUNT(*) AS num_ordini
FROM raw.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- Verifica 2: ordini non consegnati con data di consegna
-- Risultato: 6 ordini, tutti annullati (canceled)
-- Conclusione: forse resi o annullamenti dopo la consegna (i dati non
--              permettono di verificarlo). Per i tempi di consegna restano
--              fuori, perché non sono "delivered".
SELECT order_status, COUNT(*) AS num_ordini
FROM raw.orders
WHERE order_status <> 'delivered'
  AND order_delivered_customer_date IS NOT NULL
GROUP BY order_status;

-- Verifica 3: ordini senza righe d'ordine
-- Risultato: 775 ordini, nessuno consegnato
--            (603 unavailable, 164 canceled, 8 in stati intermedi)
-- Conclusione: senza prodotti né prezzi, non entrano nel fatturato.
--              Nessun ordine consegnato viene perso.
SELECT o.order_status, COUNT(*) AS num_ordini
FROM raw.orders o
LEFT JOIN raw.order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status;

-- Verifica 4: prodotti del catalogo mai venduti
-- Risultato: 0 prodotti
-- Conclusione: probabile estrazione dei soli prodotti venduti. Il catalogo
--              non è completo: non si possono analizzare i prodotti invenduti.
SELECT COUNT(*) AS num_prodotti
FROM raw.products p
LEFT JOIN raw.order_items oi ON p.product_id = oi.product_id
WHERE oi.product_id IS NULL;