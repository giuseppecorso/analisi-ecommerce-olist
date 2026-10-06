-- Conta le righe delle tabelle caricate
-- Lo facciamo per verificare che corrispondano ai dati letti da Python

SELECT COUNT(*) FROM raw.category_translation;
SELECT COUNT(*) FROM raw.customers;
SELECT COUNT(*) FROM raw.order_items;
SELECT COUNT(*) FROM raw.order_reviews;
SELECT COUNT(*) FROM raw.orders;
SELECT COUNT(*) FROM raw.products;