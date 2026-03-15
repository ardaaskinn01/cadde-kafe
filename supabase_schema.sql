-- Enum Tanımlamaları
CREATE TYPE user_role AS ENUM ('garson', 'kasa', 'yonetici');
CREATE TYPE order_status AS ENUM ('bekliyor', 'hazirlaniyor', 'teslim_edildi', 'odendi', 'iptal');

-- Kullanıcı Profilleri Tablosu (Supabase Auth ile senkronize çalışacak)
CREATE TABLE profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    full_name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'garson',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('Europe/Istanbul'::text, now()) NOT NULL
);

-- Masalar Tablosu
CREATE TABLE tables (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_number TEXT NOT NULL UNIQUE,
    capacity INTEGER DEFAULT 4,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('Europe/Istanbul'::text, now()) NOT NULL
);

-- Ürün Kategorileri Tablosu
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('Europe/Istanbul'::text, now()) NOT NULL
);

-- Ürünler Tablosu
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID REFERENCES categories(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    image_url TEXT,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('Europe/Istanbul'::text, now()) NOT NULL
);

-- Siparişler Tablosu
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_id UUID REFERENCES tables(id) ON DELETE SET NULL,
    waiter_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    status order_status DEFAULT 'bekliyor' NOT NULL,
    total_amount DECIMAL(10, 2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('Europe/Istanbul'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('Europe/Istanbul'::text, now()) NOT NULL
);

-- Sipariş Detayları (İçerik) Tablosu
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
    product_id UUID REFERENCES products(id) ON DELETE RESTRICT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price DECIMAL(10, 2) NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Updated_at güncellemeleri için Trigger örneği (Siparişler tablosu için)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_orders_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- İsteğe bağlı, güvenlik (RLS) politikaları aktif edilebilir:
-- ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
-- ve benzeri şekilde tüm tablolar için auth.uid() izinleri ayarlanmalıdır.
