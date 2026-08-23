-- Marketplace seed -- deterministic, byte-identical on every run.
-- 20 vendors, 40 categories (two levels), 5000 products, 1-3 images each.

-- Clean existing data
TRUNCATE product_images, products, categories, vendors CASCADE;

-- Vendors (20)
INSERT INTO vendors (id, name, slug, created_at) VALUES
('11111111-1111-4000-a000-000000000001', 'Hearth & Hollow', 'hearth-hollow', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000002', 'North Studio', 'north-studio', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000003', 'Cedar & Vine', 'cedar-vine', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000004', 'Matter Made', 'matter-made', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000005', 'Field Supply Co.', 'field-supply-co', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000006', 'Atelier Forma', 'atelier-forma', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000007', 'Woven Standard', 'woven-standard', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000008', 'Juniper Trade', 'juniper-trade', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000009', 'Foundry General', 'foundry-general', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000010', 'Sable & Stone', 'sable-stone', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000011', 'Palette Works', 'palette-works', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000012', 'Harbor Thread', 'harbor-thread', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000013', 'Grain Collective', 'grain-collective', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000014', 'Lumen Supply', 'lumen-supply', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000015', 'Terra & Oak', 'terra-oak', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000016', 'Orchard Line', 'orchard-line', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000017', 'Marlowe & Sons', 'marlowe-sons', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000018', 'Canyon Workshop', 'canyon-workshop', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000019', 'Evergreen Outpost', 'evergreen-outpost', '2023-01-10T08:00:00Z'),
('11111111-1111-4000-a000-000000000020', 'Atlas Craft House', 'atlas-craft-house', '2023-01-10T08:00:00Z');

-- Categories: 8 parents
INSERT INTO categories (id, name, slug, parent_id, created_at) VALUES
('22222222-2222-4000-a000-000000000001', 'Apparel', 'apparel', NULL, '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000002', 'Home & Living', 'home-living', NULL, '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000003', 'Electronics', 'electronics', NULL, '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000004', 'Beauty', 'beauty', NULL, '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000005', 'Sports & Outdoor', 'sports-outdoor', NULL, '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000006', 'Toys & Games', 'toys-games', NULL, '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000007', 'Pantry', 'pantry', NULL, '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000008', 'Books & Media', 'books-media', NULL, '2023-01-11T08:00:00Z');

-- Children (32) -- 4 per parent
INSERT INTO categories (id, name, slug, parent_id, created_at) VALUES
('22222222-2222-4000-a000-000000000101', 'Outerwear', 'outerwear', '22222222-2222-4000-a000-000000000001', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000102', 'Knitwear', 'knitwear', '22222222-2222-4000-a000-000000000001', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000103', 'Footwear', 'footwear', '22222222-2222-4000-a000-000000000001', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000104', 'Accessories', 'accessories', '22222222-2222-4000-a000-000000000001', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000105', 'Kitchen & Dining', 'kitchen-dining', '22222222-2222-4000-a000-000000000002', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000106', 'Decor', 'decor', '22222222-2222-4000-a000-000000000002', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000107', 'Textiles', 'textiles', '22222222-2222-4000-a000-000000000002', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000108', 'Lighting', 'lighting', '22222222-2222-4000-a000-000000000002', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000109', 'Audio', 'audio', '22222222-2222-4000-a000-000000000003', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000110', 'Accessories (Tech)', 'accessories-tech', '22222222-2222-4000-a000-000000000003', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000111', 'Office Tools', 'office-tools', '22222222-2222-4000-a000-000000000003', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000112', 'Photography', 'photography', '22222222-2222-4000-a000-000000000003', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000113', 'Skincare', 'skincare', '22222222-2222-4000-a000-000000000004', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000114', 'Fragrance', 'fragrance', '22222222-2222-4000-a000-000000000004', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000115', 'Bath & Body', 'bath-body', '22222222-2222-4000-a000-000000000004', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000116', 'Hair', 'hair', '22222222-2222-4000-a000-000000000004', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000117', 'Training', 'training', '22222222-2222-4000-a000-000000000005', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000118', 'Camping & Hike', 'camping-hike', '22222222-2222-4000-a000-000000000005', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000119', 'Cycling', 'cycling', '22222222-2222-4000-a000-000000000005', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000120', 'Water Sports', 'water-sports', '22222222-2222-4000-a000-000000000005', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000121', 'Building Sets', 'building-sets', '22222222-2222-4000-a000-000000000006', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000122', 'Puzzles', 'puzzles', '22222222-2222-4000-a000-000000000006', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000123', 'Plush & Dolls', 'plush-dolls', '22222222-2222-4000-a000-000000000006', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000124', 'Board Games', 'board-games', '22222222-2222-4000-a000-000000000006', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000125', 'Coffee & Tea', 'coffee-tea', '22222222-2222-4000-a000-000000000007', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000126', 'Snacks', 'snacks', '22222222-2222-4000-a000-000000000007', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000127', 'Pantry Staples', 'pantry-staples', '22222222-2222-4000-a000-000000000007', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000128', 'Baking', 'baking', '22222222-2222-4000-a000-000000000007', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000129', 'Fiction', 'fiction', '22222222-2222-4000-a000-000000000008', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000130', 'Non-Fiction', 'non-fiction', '22222222-2222-4000-a000-000000000008', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000131', 'Journals', 'journals', '22222222-2222-4000-a000-000000000008', '2023-01-11T08:00:00Z'),
('22222222-2222-4000-a000-000000000132', 'Art & Photo Books', 'art-photo-books', '22222222-2222-4000-a000-000000000008', '2023-01-11T08:00:00Z');


-- 5000 products -- deterministic via generate_series + domain arrays
DO $$
DECLARE
  adj TEXT[] := ARRAY[
    'Woven','Brushed','Stonewashed','Handmade','Minimal','Vintage-Inspired','Organic','Recycled','Artisan','Heirloom',
    'Compact','Modular','Everyday','Heritage','Raw','Linen','Walnut','Ceramic','Copper','Boucle',
    'Ribbed','Quilted','Glazed','Matte','Polished','Tumbled','Knitted','Pressed','Folded','Serged'
  ];
  material TEXT[] := ARRAY[
    'Wool','Cotton','Linen','Silk','Canvas','Leather','Ceramic','Oak','Walnut','Brass',
    'Copper','Glass','Concrete','Rattan','Paper','Stone','Merino','Cashmere','Hemp','Denim'
  ];
  noun TEXT[] := ARRAY[
    'Jacket','Cardigan','Sneaker','Tote','Throw','Vase','Bowl','Mug','Lamp','Rug',
    'Pendant','Stool','Speaker','Headphones','Notebook','Backpack','Candle','Blanket','Planter','Board',
    'Jacket','Parka','Quilt','Shirt','Sweater','Trousers','Dress','Scarf','Beanie','Gloves',
    'Kettle','Carafe','Cutting Board','Mortar & Pestle','Wall Shelf','Side Table','Floor Cushion','Linen Sheet Set','Table Runner','Storage Basket',
    'Portable Speaker','Desk Mat','Mechanical Keyboard','Webcam Cover','Lens Cloth','Tripod','Film Safe','Light Strip','Cable Tray','Sound Bar',
    'Cleanser','Serum','Moisturizer','Lip Balm','Bath Soak','Hand Cream','Hair Oil','Dry Brush','Face Mask','Perfume Oil',
    'Resistance Band','Yoga Block','Kettlebell','Trail Pack','Water Bottle','Bike Light','Helmet','Dry Bag','Paddle Board','Towel',
    'Wooden Blocks','Puzzle Cube','Plush Fox','Memory Game','Chess Set','Card Deck','Model Kit','Paint Box','Clay Set','Marble Run',
    'Espresso Blend','Matcha Tin','Granola','Hot Honey','Olive Oil','Sea Salt','Pancake Mix','Cookie Kit','Jam Trio','Tea Sampler',
    'Hardcover Novel','Essay Collection','Photo Monograph','Sketch Journal','Planner','Field Notes Set','Cookbook','Poetry Volume','Story Cards','Guidebook'
  ];
  desc_lead TEXT[] := ARRAY[
    'Designed for daily rituals and built to last.',
    'Small-batch crafted with responsibly sourced materials.',
    'A quiet essential that gets better with use.',
    'Balanced proportion, honest materials, no excess.',
    'Made to gather a patina over seasons of use.',
    'Thoughtfully minimal — every detail earns its place.',
    'Hand-finished by makers who know their craft.',
    'Utility meets warmth in a form that stays out of your way.',
    'A modern heirloom you will reach for every day.',
    'Grounded in tradition, refined for contemporary life.'
  ];
  base_ts TIMESTAMPTZ := '2024-01-01 00:00:00+00';
  vendor_ids UUID[] := ARRAY[
    '11111111-1111-4000-a000-000000000001','11111111-1111-4000-a000-000000000002','11111111-1111-4000-a000-000000000003','11111111-1111-4000-a000-000000000004','11111111-1111-4000-a000-000000000005',
    '11111111-1111-4000-a000-000000000006','11111111-1111-4000-a000-000000000007','11111111-1111-4000-a000-000000000008','11111111-1111-4000-a000-000000000009','11111111-1111-4000-a000-000000000010',
    '11111111-1111-4000-a000-000000000011','11111111-1111-4000-a000-000000000012','11111111-1111-4000-a000-000000000013','11111111-1111-4000-a000-000000000014','11111111-1111-4000-a000-000000000015',
    '11111111-1111-4000-a000-000000000016','11111111-1111-4000-a000-000000000017','11111111-1111-4000-a000-000000000018','11111111-1111-4000-a000-000000000019','11111111-1111-4000-a000-000000000020'
  ];
  category_ids UUID[] := ARRAY[
    '22222222-2222-4000-a000-000000000101','22222222-2222-4000-a000-000000000102','22222222-2222-4000-a000-000000000103','22222222-2222-4000-a000-000000000104',
    '22222222-2222-4000-a000-000000000105','22222222-2222-4000-a000-000000000106','22222222-2222-4000-a000-000000000107','22222222-2222-4000-a000-000000000108',
    '22222222-2222-4000-a000-000000000109','22222222-2222-4000-a000-000000000110','22222222-2222-4000-a000-000000000111','22222222-2222-4000-a000-000000000112',
    '22222222-2222-4000-a000-000000000113','22222222-2222-4000-a000-000000000114','22222222-2222-4000-a000-000000000115','22222222-2222-4000-a000-000000000116',
    '22222222-2222-4000-a000-000000000117','22222222-2222-4000-a000-000000000118','22222222-2222-4000-a000-000000000119','22222222-2222-4000-a000-000000000120',
    '22222222-2222-4000-a000-000000000121','22222222-2222-4000-a000-000000000122','22222222-2222-4000-a000-000000000123','22222222-2222-4000-a000-000000000124',
    '22222222-2222-4000-a000-000000000125','22222222-2222-4000-a000-000000000126','22222222-2222-4000-a000-000000000127','22222222-2222-4000-a000-000000000128',
    '22222222-2222-4000-a000-000000000129','22222222-2222-4000-a000-000000000130','22222222-2222-4000-a000-000000000131','22222222-2222-4000-a000-000000000132'
  ];
  n INT;
  a_idx INT; m_idx INT; nn_idx INT; d_idx INT;
  v_idx INT; c_idx INT;
  title TEXT; slug TEXT; desc_text TEXT;
  price INT; stk INT; stat TEXT;
  vend UUID; cat UUID;
  ts TIMESTAMPTZ;
  pid UUID;
  img_count INT;
  j INT;
  slug_base TEXT;
BEGIN
  FOR n IN 1..5000 LOOP
    a_idx := ((n * 37) % array_length(adj, 1)) + 1;
    m_idx := ((n * 59) % array_length(material, 1)) + 1;
    nn_idx := ((n * 73) % array_length(noun, 1)) + 1;
    d_idx := ((n * 97) % array_length(desc_lead, 1)) + 1;

    title := adj[a_idx] || ' ' || material[m_idx] || ' ' || noun[nn_idx];

    -- Avoid duplicate titles by suffixing with n when needed via slug uniqueness
    -- Slug: lowercase, alphanum + hyphen, plus id suffix
    slug_base := lower(regexp_replace(title, '[^a-zA-Z0-9]+', '-', 'g'));
    slug_base := regexp_replace(slug_base, '^-|-$', '', 'g');
    slug := regexp_replace(slug_base, '-+', '-', 'g') || '-' || n::text;

    -- Price wide range: 499 .. 99999 cents
    price := 499 + ((n * 7919) % 95000);
    -- Spread further: every 100th is premium > $400
    IF n % 97 = 0 THEN price := price + 30000; END IF;
    IF price > 150000 THEN price := 150000; END IF;

    -- Stock
    stk := (n * 13) % 120;
    IF n % 37 = 0 THEN stk := 0; END IF; -- some out of stock even if published/draft
    IF stk = 0 AND n % 7 = 0 THEN stk := 2; END IF; -- low stock

    -- Status 90% published, 5% draft, 5% archived
    IF n % 20 = 0 THEN stat := 'archived';
    ELSIF n % 20 = 1 THEN stat := 'draft';
    ELSE stat := 'published';
    END IF;

    v_idx := ((n * 7) % array_length(vendor_ids, 1)) + 1;
    vend := vendor_ids[v_idx];
    c_idx := ((n * 11) % array_length(category_ids, 1)) + 1;
    cat := category_ids[c_idx];

    -- Created at descending so cursor pagination (newest first) is meaningful
    ts := base_ts + ( (5000 - n) * interval '17 minutes') + ((n % 60) * interval '23 seconds');

    pid := ('00000000-0000-4000-a000-' || lpad(to_hex(n), 12, '0'))::uuid;

    desc_text := desc_lead[d_idx] || ' ' || title ||
      ' from our seasonal collection. Crafted with care for everyday use and intended to age gracefully. ' ||
      'Dimensions and care instructions included with shipment.';

    INSERT INTO products (id, vendor_id, category_id, title, slug, description, price_cents, currency, status, stock, created_at, updated_at)
    VALUES (pid, vend, cat, title, slug, desc_text, price, 'USD', stat, stk, ts, ts);

    -- Images 1..3
    img_count := 1 + (n % 3);
    FOR j IN 1..img_count LOOP
      INSERT INTO product_images (id, product_id, url, alt, position)
      VALUES (
        ('33333333-3333-4000-a000-' || lpad(to_hex(n*10 + j), 12, '0'))::uuid,
        pid,
        'https://picsum.photos/seed/' || slug || '-' || j::text || '/800/800',
        title || ' — view ' || j::text,
        j - 1
      );
    END LOOP;
  END LOOP;
END $$;
