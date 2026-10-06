import pandas as pd
from sqlalchemy import create_engine

engine = create_engine("postgresql+psycopg2://postgres:postgres@localhost:5434/olist")

file_tabelle = {
    "olist_orders_dataset.csv": "orders",
    "olist_customers_dataset.csv": "customers",
    "olist_order_items_dataset.csv": "order_items",
    "olist_products_dataset.csv": "products",
    "product_category_name_translation.csv": "category_translation",
    "olist_order_reviews_dataset.csv": "order_reviews",
}

for csv, nome in file_tabelle.items():
    df = pd.read_csv(f"data/{csv}", dtype=str)
    df.to_sql(nome, engine, schema="raw", if_exists="replace", index=False)
    print(f"Ho caricato {len(df)} righe nella tabella raw.{nome}")

