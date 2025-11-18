#!/usr/bin/env python
"""
populate.py
Populate the RushMore PostgreSQL database with realistic fake data using Faker.

Reads DB credentials from environment variables or a .env file.

"""

import os
import random
from faker import Faker
from dotenv import load_dotenv
import psycopg2
from psycopg2.extras import execute_values
from tqdm import trange

# Load env
load_dotenv()
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = int(os.getenv('DB_PORT', 5432))
DB_NAME = os.getenv('DB_NAME', 'rushmore_db')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASS = os.getenv('DB_PASS', '')
BATCH_SIZE = int(os.getenv('BATCH_SIZE', 500))
TRUNCATE_FIRST = os.getenv('TRUNCATE_FIRST', 'true').lower() in ('1','true','yes')

# Adjustable targets
NUM_STORES = 4
NUM_MENU_ITEMS = 25
NUM_INGREDIENTS = 45
NUM_CUSTOMERS = 1200
NUM_ORDERS = 6000  # target orders
AVG_ITEMS_PER_ORDER = 3

fake = Faker() # Initialize Faker
Faker.seed(42) # For reproducibility of fake data
random.seed(42) # For reproducibility of random choices


def get_conn(): # Get a new database connection
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )


def truncate_tables(conn): # Truncate all relevant tables and reset sequences
    with conn.cursor() as cur:
        cur.execute("""TRUNCATE TABLE 
            order_items, orders, item_ingredients, menu_items, ingredients, customers, stores
            RESTART IDENTITY CASCADE;""") # Truncate and reset IDs
        conn.commit() # Commit changes
    print("Truncated tables and reset sequences.") 


def insert_stores(conn): # Insert fake stores
    stores = []
    for _ in range(NUM_STORES): # Generate fake store data
        stores.append((fake.street_address(), fake.city(), fake.phone_number()[:20]))
    with conn.cursor() as cur: # Insert into DB
        execute_values(cur, # Bulk insert
            "INSERT INTO stores (address, city, phone_number) VALUES %s",
            stores # Bulk insert
        )
        conn.commit()
    print(f"Inserted {NUM_STORES} stores.") # Report


def insert_customers(conn): # Insert fake customers
    customers = []
    for _ in range(NUM_CUSTOMERS): # Generate fake customer data
        customers.append((fake.first_name(), fake.last_name(), fake.email(), fake.phone_number()[:20]))
    with conn.cursor() as cur: # Insert into DB
        execute_values(cur, # Bulk insert
            "INSERT INTO customers (first_name, last_name, email, phone_number) VALUES %s",
            customers # Bulk insert
        )
        conn.commit()
    print(f"Inserted {NUM_CUSTOMERS} customers.") # Report


def insert_ingredients(conn): # Insert fake ingredients
    units = ['kg', 'g', 'liters', 'units'] # Possible units
    ingr = []
    for i in range(NUM_INGREDIENTS): # Generate fake ingredient data
        name = fake.unique.word().title() + (" Cheese" if i%7==0 else "")
        qty = round(random.uniform(10, 200), 2) # Stock quantity
        unit = random.choice(units) # Random unit
        ingr.append((name, qty, unit)) # Add to list
    with conn.cursor() as cur:
        execute_values(cur,
            "INSERT INTO ingredients (name, stock_quantity, unit) VALUES %s",
            ingr
        )
        conn.commit()
    print(f"Inserted {NUM_INGREDIENTS} ingredients.")


def insert_menu_items(conn):
    categories = ['Pizza', 'Drink', 'Side']
    sizes = ['Small', 'Medium', 'Large', '500ml', '330ml', 'N/A'] # Possible sizes
    items = []
    for i in range(NUM_MENU_ITEMS): # Generate fake menu item data
        name = fake.unique.word().title() + (" Pizza" if i%2==0 else "")
        category = random.choice(categories)
        size = random.choice(sizes) if category != 'Drink' else random.choice(['500ml','330ml'])
        items.append((name, category, size)) # Add to list
    with conn.cursor() as cur:
        execute_values(cur, # Bulk insert
            "INSERT INTO menu_items (name, category, size) VALUES %s",
            items
        )
        conn.commit()
    print(f"Inserted {NUM_MENU_ITEMS} menu items.")


def map_item_ingredients(conn):
    # Create mappings: each menu item uses 3-8 ingredients
    with conn.cursor() as cur:
        cur.execute("SELECT item_id FROM menu_items")
        item_ids = [r[0] for r in cur.fetchall()] # Get all menu item IDs
        cur.execute("SELECT ingredient_id FROM ingredients") # Get all ingredient IDs
        ing_ids = [r[0] for r in cur.fetchall()]

    mappings = []
    for item_id in item_ids:
        num = random.randint(3, min(8, len(ing_ids)))
        chosen = random.sample(ing_ids, num)
        for ing in chosen:
            qty = round(random.uniform(0.05, 1.5), 2)
            mappings.append((item_id, ing, qty))

    with conn.cursor() as cur:
        execute_values(cur,
            "INSERT INTO item_ingredients (item_id, ingredient_id, quantity_required) VALUES %s",
            mappings # Bulk insert
        )
        conn.commit()
    print(f"Inserted {len(mappings)} item_ingredient mappings.")


def insert_customers(conn):
    customers = []
    for _ in range(NUM_CUSTOMERS):
        fn = fake.first_name()
        ln = fake.last_name()
        email = f"{fn.lower()}.{ln.lower()}{random.randint(1,9999)}@{fake.free_email_domain()}"
        customers.append((fn, ln, email, fake.phone_number()[:20]))
    with conn.cursor() as cur:
        execute_values(cur,
            "INSERT INTO customers (first_name, last_name, email, phone_number) VALUES %s",
            customers
        )
        conn.commit()
    print(f"Inserted {NUM_CUSTOMERS} customers.")


def create_orders(conn): # Create fake orders and order items
    with conn.cursor() as cur:
        cur.execute("SELECT store_id FROM stores")
        stores = [r[0] for r in cur.fetchall()]
        cur.execute("SELECT customer_id FROM customers")
        customers = [r[0] for r in cur.fetchall()] # Get all customer IDs
        cur.execute("SELECT item_id FROM menu_items") # Get all menu item IDs
        items = [r[0] for r in cur.fetchall()] # Get all menu item IDs

    order_records = []
    order_items_records = []
    order_count = 0

    for _ in trange(NUM_ORDERS, desc="Generating orders"): # Generate fake orders
        customer_id = random.choice(customers) # Random customer
        store_id = random.choice(stores) # Random store
        num_line_items = max(1, int(random.gauss(AVG_ITEMS_PER_ORDER, 1)))
        chosen_items = random.choices(items, k=num_line_items)
        order_timestamp = fake.date_time_this_year() # Random timestamp

        order_records.append((customer_id, store_id, order_timestamp, 0.0))  # placeholder total

        for it in chosen_items:
            qty = random.randint(1, 3)
            price = round(random.uniform(2.5, 20.0), 2)
            order_items_records.append((None, it, qty, price))  # order_id to fill later

        if len(order_records) >= BATCH_SIZE:
            batch_insert_orders_and_items(conn, order_records, order_items_records)
            order_records = []
            order_items_records = []

    if order_records:
        batch_insert_orders_and_items(conn, order_records, order_items_records)

    print(f"Inserted approx {NUM_ORDERS} orders and their items.")


def batch_insert_orders_and_items(conn, order_records, order_items_records):
    """Inserts orders and order_items in a batch."""
    with conn.cursor() as cur:
        # Insert orders and get their IDs
        execute_values(cur,
            "INSERT INTO orders (customer_id, store_id, order_timestamp, total_amount) VALUES %s RETURNING order_id",
            order_records,
            fetch=True
        )
        inserted = cur.fetchall()
        order_ids = [r[0] for r in inserted]

        # Assign items to orders in order
        order_ids_iter = iter(order_ids)
        current_order_id = next(order_ids_iter, None)
        assigned_items = []
        for rec in order_items_records:
            if current_order_id is None:
                break
            assigned_items.append((current_order_id, rec[1], rec[2], rec[3]))
            if random.random() < 0.4:
                current_order_id = next(order_ids_iter, None)

        if assigned_items:
            execute_values(cur,
                "INSERT INTO order_items (order_id, item_id, quantity, price_at_time_of_order) VALUES %s",
                assigned_items
            )

        # Update order totals for the recently inserted orders
        cur.execute("""UPDATE orders o
                       SET total_amount = COALESCE(sub.total, 0)
                       FROM (
                         SELECT order_id, SUM(quantity * price_at_time_of_order) AS total
                         FROM order_items
                         WHERE order_id = ANY(ARRAY(SELECT order_id FROM orders ORDER BY order_id DESC LIMIT %s))
                         GROUP BY order_id
                       ) AS sub
                       WHERE o.order_id = sub.order_id;""", (len(order_ids),))
        conn.commit()
    return order_ids


def main():
    conn = get_conn()
    try:
        if TRUNCATE_FIRST:
            truncate_tables(conn)
        insert_stores(conn)
        insert_ingredients(conn)
        insert_menu_items(conn)
        map_item_ingredients(conn)
        insert_customers(conn)
        create_orders(conn)
    finally:
        conn.close()
    print("Data population complete.")


if __name__ == '__main__':
    main()
