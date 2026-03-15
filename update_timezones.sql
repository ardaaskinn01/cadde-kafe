-- Existing tables update for Turkey Timezone (Europe/Istanbul)

-- Profiles
ALTER TABLE profiles ALTER COLUMN created_at SET DEFAULT timezone('Europe/Istanbul'::text, now());

-- Tables
ALTER TABLE tables ALTER COLUMN created_at SET DEFAULT timezone('Europe/Istanbul'::text, now());

-- Categories
ALTER TABLE categories ALTER COLUMN created_at SET DEFAULT timezone('Europe/Istanbul'::text, now());

-- Products
ALTER TABLE products ALTER COLUMN created_at SET DEFAULT timezone('Europe/Istanbul'::text, now());

-- Orders
ALTER TABLE orders ALTER COLUMN created_at SET DEFAULT timezone('Europe/Istanbul'::text, now());
ALTER TABLE orders ALTER COLUMN updated_at SET DEFAULT timezone('Europe/Istanbul'::text, now());

-- Order Items
ALTER TABLE order_items ALTER COLUMN created_at SET DEFAULT timezone('Europe/Istanbul'::text, now());
