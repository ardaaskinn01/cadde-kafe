-- Önce var olan ürün ve kategorileri temizleyelim (Opsiyonel: Eğer temiz bir başlangıç isteniyorsa)
-- DELETE FROM products;
-- DELETE FROM categories;

-- 1. Kategorileri Ekle ve ID'lerini al
INSERT INTO categories (name) VALUES 
('Dünya Kahveleri'),
('Soğuk Kahveler'),
('Tatlılar'),
('Fast Food'),
('Diğer')
ON CONFLICT (name) DO NOTHING;

-- DÜNYA KAHVELERİ
INSERT INTO products (category_id, name, price)
SELECT id, 'Cappuccino', 70 FROM categories WHERE name = 'Dünya Kahveleri';
INSERT INTO products (category_id, name, price)
SELECT id, 'Mocha', 80 FROM categories WHERE name = 'Dünya Kahveleri';
INSERT INTO products (category_id, name, price)
SELECT id, 'Latte', 80 FROM categories WHERE name = 'Dünya Kahveleri';
INSERT INTO products (category_id, name, price)
SELECT id, 'Espresso', 60 FROM categories WHERE name = 'Dünya Kahveleri';
INSERT INTO products (category_id, name, price)
SELECT id, 'Americano', 70 FROM categories WHERE name = 'Dünya Kahveleri';
INSERT INTO products (category_id, name, price)
SELECT id, 'Filtre Kahve', 70 FROM categories WHERE name = 'Dünya Kahveleri';
INSERT INTO products (category_id, name, price)
SELECT id, 'Kenya AA', 0 FROM categories WHERE name = 'Dünya Kahveleri';
INSERT INTO products (category_id, name, price)
SELECT id, 'Guatemala', 0 FROM categories WHERE name = 'Dünya Kahveleri';
INSERT INTO products (category_id, name, price)
SELECT id, 'Costa Rica', 0 FROM categories WHERE name = 'Dünya Kahveleri';
INSERT INTO products (category_id, name, price)
SELECT id, 'Affogato', 80 FROM categories WHERE name = 'Dünya Kahveleri';
INSERT INTO products (category_id, name, price)
SELECT id, 'Macchiato', 70 FROM categories WHERE name = 'Dünya Kahveleri';
INSERT INTO products (category_id, name, price)
SELECT id, 'Aromalı Latte', 90 FROM categories WHERE name = 'Dünya Kahveleri';
INSERT INTO products (category_id, name, price)
SELECT id, 'White Chocolate Mocha', 90 FROM categories WHERE name = 'Dünya Kahveleri';
INSERT INTO products (category_id, name, price)
SELECT id, 'Aromalı Macchiato', 80 FROM categories WHERE name = 'Dünya Kahveleri';

-- SOĞUK KAHVELER
INSERT INTO products (category_id, name, price)
SELECT id, 'Ice Latte', 80 FROM categories WHERE name = 'Soğuk Kahveler';
INSERT INTO products (category_id, name, price)
SELECT id, 'Ice Mocha', 80 FROM categories WHERE name = 'Soğuk Kahveler';
INSERT INTO products (category_id, name, price)
SELECT id, 'Iced White Chocolate Mocha', 90 FROM categories WHERE name = 'Soğuk Kahveler';
INSERT INTO products (category_id, name, price)
SELECT id, 'Ice Coffee', 80 FROM categories WHERE name = 'Soğuk Kahveler';
INSERT INTO products (category_id, name, price)
SELECT id, 'Frappe', 80 FROM categories WHERE name = 'Soğuk Kahveler';

-- TATLILAR
INSERT INTO products (category_id, name, price)
SELECT id, 'Tiramisu', 0 FROM categories WHERE name = 'Tatlılar';
INSERT INTO products (category_id, name, price)
SELECT id, 'Cheesecake', 0 FROM categories WHERE name = 'Tatlılar';
INSERT INTO products (category_id, name, price)
SELECT id, 'Mozaik Pasta', 0 FROM categories WHERE name = 'Tatlılar';
INSERT INTO products (category_id, name, price)
SELECT id, 'Trileçe', 0 FROM categories WHERE name = 'Tatlılar';
INSERT INTO products (category_id, name, price)
SELECT id, 'Snickers Pasta', 0 FROM categories WHERE name = 'Tatlılar';
INSERT INTO products (category_id, name, price)
SELECT id, 'Cocostar Pasta', 0 FROM categories WHERE name = 'Tatlılar';
INSERT INTO products (category_id, name, price)
SELECT id, 'San Sabastian', 0 FROM categories WHERE name = 'Tatlılar';
INSERT INTO products (category_id, name, price)
SELECT id, 'Magnolya', 0 FROM categories WHERE name = 'Tatlılar';
INSERT INTO products (category_id, name, price)
SELECT id, 'Donut', 0 FROM categories WHERE name = 'Tatlılar';

-- FAST FOOD
INSERT INTO products (category_id, name, price)
SELECT id, 'Tost', 0 FROM categories WHERE name = 'Fast Food';
INSERT INTO products (category_id, name, price)
SELECT id, 'Hamburger', 0 FROM categories WHERE name = 'Fast Food';
INSERT INTO products (category_id, name, price)
SELECT id, 'Cheeseburger', 0 FROM categories WHERE name = 'Fast Food';
INSERT INTO products (category_id, name, price)
SELECT id, 'Cips', 0 FROM categories WHERE name = 'Fast Food';
INSERT INTO products (category_id, name, price)
SELECT id, 'Köfte Ekmek', 0 FROM categories WHERE name = 'Fast Food';
INSERT INTO products (category_id, name, price)
SELECT id, 'Kumru', 0 FROM categories WHERE name = 'Fast Food';

-- DİĞER
INSERT INTO products (category_id, name, price)
SELECT id, 'Nargile', 250 FROM categories WHERE name = 'Diğer';

