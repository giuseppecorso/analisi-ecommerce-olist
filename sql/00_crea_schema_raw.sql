-- Crea lo schema raw (se non esiste già).
-- Contiene la copia fedele dei CSV di Olist, senza pulizie:
-- le trasformazioni si fanno dopo, in SQL, in uno schema separato.

CREATE SCHEMA IF NOT EXISTS raw;