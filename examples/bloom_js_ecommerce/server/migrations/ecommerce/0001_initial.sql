-- up
CREATE TABLE IF NOT EXISTS ecommerce_users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ecommerce_products (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    price_cents INTEGER NOT NULL,
    image_url VARCHAR(1024) NOT NULL DEFAULT '',
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ecommerce_orders (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES ecommerce_users(id) ON DELETE CASCADE,
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    total_cents INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ecommerce_order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES ecommerce_orders(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES ecommerce_products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL,
    unit_price_cents INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS ecommerce_orders_user_id_idx ON ecommerce_orders(user_id);
CREATE INDEX IF NOT EXISTS ecommerce_order_items_order_id_idx ON ecommerce_order_items(order_id);
CREATE INDEX IF NOT EXISTS ecommerce_order_items_product_id_idx ON ecommerce_order_items(product_id);

-- down
DROP TABLE IF EXISTS ecommerce_order_items;
DROP TABLE IF EXISTS ecommerce_orders;
DROP TABLE IF EXISTS ecommerce_products;
DROP TABLE IF EXISTS ecommerce_users;
