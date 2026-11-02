-- Khaustan menu onboarding: Vihar Refreshments Pure Veg
-- Source JSON: Vihar_Restaurant_Menu_OCR.json
-- Source image(s): Vihar1.jpg, Vihar2.jpg
-- establishment_id / restaurant_id / source_id namespace: 400081005 (taken directly from the source JSON)
-- Generated against json-insertscript-prompt.md (Resolved: KhaustanRestaurantMenu).
-- Corrections carried forward from prior execution feedback on this pipeline (not from
-- reusing any previous restaurant's generated SQL): every bulk INSERT ... SELECT ... FROM
-- (VALUES ...) has an explicit VALUES keyword, and any column whose value is NULL in
-- every VALUES row is cast to its target type (PostgreSQL types an all-NULL VALUES
-- column as text, which fails against a typed target column such as boolean/bigint).
-- NOTE (schema bug, not routed around): menu_item_price's ck_menu_item_price_amount
-- CHECK compares is_market_price (boolean) to integer literals (= 1 / = 0), which
-- PostgreSQL will reject. This script never writes is_market_price = TRUE, so it is not
-- blocked by the bug, but the bug should still be fixed in the schema.
-- NOTE: protein_type is resolved live by JOIN on code, never a literal id. HALAL is
-- looked up the same way against platform_tag; if that tag_code doesn't exist yet the
-- insert simply matches zero rows (no error) -- see the trailing notes.

--\connect "KhaustanRestaurantMenu"
BEGIN;

-- Helper sequence for standalone IDs not covered by the mandatory establishment
-- namespace (restaurant_phone_id, restaurant_hours_id, menu_extraction_batch_id,
-- canonical_dish_id, canonical_dish_name_id, restaurant_tag_id).
DO $do$
DECLARE
  v_max BIGINT;
BEGIN
  SELECT GREATEST(
    COALESCE((SELECT MAX(restaurant_phone_id) FROM restaurant_phone), 0),
    COALESCE((SELECT MAX(restaurant_hours_id) FROM restaurant_hours), 0),
    COALESCE((SELECT MAX(extraction_batch_id) FROM menu_extraction_batch), 0),
    COALESCE((SELECT MAX(canonical_dish_id) FROM canonical_dish), 0),
    COALESCE((SELECT MAX(canonical_dish_name_id) FROM canonical_dish_name), 0),
    COALESCE((SELECT MAX(restaurant_tag_id) FROM restaurant_tag), 0)
  ) INTO v_max;
  EXECUTE format('CREATE SEQUENCE IF NOT EXISTS khaustan_standalone_id_seq START WITH %s', v_max + 1);
END $do$;

-- Establishment + restaurant (explicit deterministic IDs -- never nextval() here)
INSERT INTO establishment (
    establishment_id, name, normalized_name, address_line1, address_line2,
    locality, city, state, country_code, postal_code, latitude, longitude
) VALUES (
    400081005, 'Vihar Refreshments Pure Veg', 'vihar refreshments pure veg',
    'Sham Bhuvan', NULL, 'Mulund', 'Mumbai',
    'Maharashtra', 'IN', '400081', 19.171435519159143, 72.95650603942278
);

INSERT INTO restaurant (
    restaurant_id, establishment_id, display_name, normalized_name,
    veg_nonveg_status, has_bar, bar_license_type
) VALUES (
    400081005, 400081005, 'Vihar Refreshments Pure Veg', 'vihar refreshments pure veg',
    'pure_veg', FALSE, 'none'
);

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400081005, 'ai_menu_extraction', 'Vihar_Restaurant_Menu_OCR.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, status_code)
VALUES (nextval('khaustan_standalone_id_seq'), 400081005, 400081005, (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');
SELECT extraction_batch_id FROM menu_extraction_batch WHERE source_id = 400081005 ORDER BY extraction_batch_id DESC LIMIT 1 \gset

-- Phones
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES
    (nextval('khaustan_standalone_id_seq'), 400081005, '7738350705', TRUE),
    (nextval('khaustan_standalone_id_seq'), 400081005, '865751767', FALSE),
    (nextval('khaustan_standalone_id_seq'), 400081005, '7045791315', FALSE),
    (nextval('khaustan_standalone_id_seq'), 400081005, '02221635070', FALSE),
    (nextval('khaustan_standalone_id_seq'), 400081005, '02221635564', FALSE);

-- Hours: single stated window applied to every day (JSON gives one blanket timing,
-- no per-day breakdown) -- confidence: inferred blanket application, not per-day-confirmed.
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
VALUES
    (nextval('khaustan_standalone_id_seq'), 400081005, 1, 1, '07:00'::time, '23:30'::time),
    (nextval('khaustan_standalone_id_seq'), 400081005, 2, 1, '07:00'::time, '23:30'::time),
    (nextval('khaustan_standalone_id_seq'), 400081005, 3, 1, '07:00'::time, '23:30'::time),
    (nextval('khaustan_standalone_id_seq'), 400081005, 4, 1, '07:00'::time, '23:30'::time),
    (nextval('khaustan_standalone_id_seq'), 400081005, 5, 1, '07:00'::time, '23:30'::time),
    (nextval('khaustan_standalone_id_seq'), 400081005, 6, 1, '07:00'::time, '23:30'::time),
    (nextval('khaustan_standalone_id_seq'), 400081005, 7, 1, '07:00'::time, '23:30'::time);

-- HALAL restaurant tag: safe lookup-only insert. If 'halal' isn't yet a platform_tag
-- tag_code, this JOIN matches zero rows and inserts nothing -- no error, no new lookup
-- row created (lookup tables are read-only for this script).
INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id)
SELECT nextval('khaustan_standalone_id_seq'), 400081005, tag_id FROM platform_tag WHERE tag_code = 'halal';

-- Delivery partners: delivery_provider is a read-only lookup (matched on uppercase
-- provider_code, never inserted). A partner named in the JSON that doesn't exist yet
-- as a delivery_provider row simply matches zero rows here -- no error, flagged below.
INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_min_order_amount)
VALUES (400081005, TRUE, 250.00);

INSERT INTO restaurant_delivery_provider (restaurant_delivery_provider_id, restaurant_id, delivery_provider_id, minimum_order_amount, delivery_charge_type_code, effective_from)
SELECT nextval('khaustan_standalone_id_seq'), 400081005, dp.delivery_provider_id, 250.00, 'fixed', (clock_timestamp() AT TIME ZONE 'UTC')
FROM delivery_provider dp WHERE dp.provider_code IN ('ZOMATO', 'SWIGGY');

-- Menu board: one a_la_carte board for the whole JSON source.
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, is_active, display_sequence)
VALUES (400081005001, 400081005, 'Main Menu', 'a_la_carte', TRUE, 1);

-- Categories, in JSON/source order. Where the source nests a subcategory (e.g.
-- STARTERS -> INDIAN / CHINESE), the top-level name becomes a parent row and the
-- subcategory becomes its child via parent_category_id -- the leaf (child) is what
-- items attach to. A category name repeated across two distinct source sections (this
-- happens at least once in this batch) is kept as two separate rows, not merged --
-- these are keyed by source position, not by display name.
INSERT INTO menu_category (menu_category_id, restaurant_id, name, parent_category_id, display_sequence)
VALUES
    (400081005001, 400081005, 'SNACKS', NULL, 1),
    (400081005002, 400081005, 'UTTAPPA', NULL, 2),
    (400081005003, 400081005, 'DOSA', NULL, 3),
    (400081005004, 400081005, 'UPWAS ITEM', NULL, 4),
    (400081005005, 400081005, 'SANDWICH', NULL, 5),
    (400081005006, 400081005, 'GRILL SANDWICH', NULL, 6),
    (400081005007, 400081005, 'TIMEPASS', NULL, 7),
    (400081005008, 400081005, 'SALAD / RAITA', NULL, 8),
    (400081005009, 400081005, 'PAV BHAJI', NULL, 9),
    (400081005010, 400081005, 'SOUP', NULL, 10),
    (400081005011, 400081005, 'TANDOORI STARTER', NULL, 11),
    (400081005012, 400081005, 'PUNJABI TADKA (PANEER)', NULL, 12),
    (400081005013, 400081005, 'PUNJABI TADKA', NULL, 13),
    (400081005014, 400081005, 'VIHAR CHEF SPECIAL', NULL, 14),
    (400081005015, 400081005, 'DAL KA DHAMAL', NULL, 15),
    (400081005016, 400081005, 'BASMATI KA SWAD', NULL, 16),
    (400081005017, 400081005, 'RICE / KHICHDI', NULL, 17),
    (400081005018, 400081005, 'VIHAR CHIEF SPECIAL RICE', NULL, 18),
    (400081005019, 400081005, 'ROTI KI TOKRI', NULL, 19),
    (400081005020, 400081005, 'CHINESE STARTER', NULL, 20),
    (400081005021, 400081005, 'RICE / NOODLE', NULL, 21),
    (400081005022, 400081005, 'PIZZA / BURGER', NULL, 22),
    (400081005023, 400081005, 'FRUIT SALAD / JELLY', NULL, 23),
    (400081005024, 400081005, 'FRESH JUICE', NULL, 24),
    (400081005025, 400081005, 'MILK SHAKES', NULL, 25),
    (400081005026, 400081005, 'MOCKTAILS', NULL, 26),
    (400081005027, 400081005, 'FALOODA', NULL, 27),
    (400081005028, 400081005, 'DRINKS', NULL, 28),
    (400081005029, 400081005, 'DESSERT', NULL, 29);

-- Board <-> category mapping (leaf categories only)
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (400081005, 400081005001, 400081005001, 1),
    (400081005, 400081005001, 400081005002, 2),
    (400081005, 400081005001, 400081005003, 3),
    (400081005, 400081005001, 400081005004, 4),
    (400081005, 400081005001, 400081005005, 5),
    (400081005, 400081005001, 400081005006, 6),
    (400081005, 400081005001, 400081005007, 7),
    (400081005, 400081005001, 400081005008, 8),
    (400081005, 400081005001, 400081005009, 9),
    (400081005, 400081005001, 400081005010, 10),
    (400081005, 400081005001, 400081005011, 11),
    (400081005, 400081005001, 400081005012, 12),
    (400081005, 400081005001, 400081005013, 13),
    (400081005, 400081005001, 400081005014, 14),
    (400081005, 400081005001, 400081005015, 15),
    (400081005, 400081005001, 400081005016, 16),
    (400081005, 400081005001, 400081005017, 17),
    (400081005, 400081005001, 400081005018, 18),
    (400081005, 400081005001, 400081005019, 19),
    (400081005, 400081005001, 400081005020, 20),
    (400081005, 400081005001, 400081005021, 21),
    (400081005, 400081005001, 400081005022, 22),
    (400081005, 400081005001, 400081005023, 23),
    (400081005, 400081005001, 400081005024, 24),
    (400081005, 400081005001, 400081005025, 25),
    (400081005, 400081005001, 400081005026, 26),
    (400081005, 400081005001, 400081005027, 27),
    (400081005, 400081005001, 400081005028, 28),
    (400081005, 400081005001, 400081005029, 29);

-- Canonical dish identify-or-create: no unique constraint on canonical_dish.normalized_name,
-- so NOT EXISTS, not ON CONFLICT. Whether these already exist from an earlier onboarded
-- restaurant is resolved live by this check when the script runs.
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Upma', 'upma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'upma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Upma', 'upma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sheera', 'sheera'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sheera')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sheera', 'sheera', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Poha', 'poha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'poha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Poha', 'poha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Steam Idli', 'steam idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'steam idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Steam Idli', 'steam idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dahi Idli', 'dahi idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dahi idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dahi Idli', 'dahi idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Idli Vada', 'idli vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'idli vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Idli Vada', 'idli vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Medu Vada', 'medu vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'medu vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Medu Vada', 'medu vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Potato Vada', 'potato vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'potato vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Potato Vada', 'potato vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mix Vada', 'mix vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mix Vada', 'mix vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dahi Vada', 'dahi vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dahi vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dahi Vada', 'dahi vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Misal Pav', 'misal pav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'misal pav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Misal Pav', 'misal pav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Vada Usal (Potato)', 'vada usal (potato)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vada usal (potato)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Vada Usal (Potato)', 'vada usal (potato)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Puri Bhaji', 'puri bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'puri bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Puri Bhaji', 'puri bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Puri Shrikhand', 'puri shrikhand'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'puri shrikhand')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Puri Shrikhand', 'puri shrikhand', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kothimbari Vadi', 'kothimbari vadi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kothimbari vadi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kothimbari Vadi', 'kothimbari vadi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Pakoda', 'cheese pakoda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese pakoda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Pakoda', 'cheese pakoda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Puri (Plate)', 'puri (plate)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'puri (plate)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Puri (Plate)', 'puri (plate)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pav', 'pav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pav', 'pav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Cuttlet', 'veg. cuttlet'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. cuttlet')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Cuttlet', 'veg. cuttlet', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mix Pokoda', 'mix pokoda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix pokoda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mix Pokoda', 'mix pokoda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Pakoda', 'paneer pakoda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pakoda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Pakoda', 'paneer pakoda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dahi Misal Pav', 'dahi misal pav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dahi misal pav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dahi Misal Pav', 'dahi misal pav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sada Uttappa', 'sada uttappa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sada uttappa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sada Uttappa', 'sada uttappa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Masala Uttappa', 'masala uttappa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala uttappa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Masala Uttappa', 'masala uttappa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Onion Uttappa', 'onion uttappa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion uttappa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Onion Uttappa', 'onion uttappa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tomato Uttappa', 'tomato uttappa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato uttappa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tomato Uttappa', 'tomato uttappa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Onion Tomato Uttappa', 'onion tomato uttappa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion tomato uttappa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Onion Tomato Uttappa', 'onion tomato uttappa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Duet Uttappa', 'duet uttappa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'duet uttappa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Duet Uttappa', 'duet uttappa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Coconut Uttappa', 'coconut uttappa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'coconut uttappa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Coconut Uttappa', 'coconut uttappa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cucumber Uttappa', 'cucumber uttappa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cucumber uttappa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cucumber Uttappa', 'cucumber uttappa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Uttappa', 'paneer uttappa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer uttappa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Uttappa', 'paneer uttappa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tomato Omlet', 'tomato omlet'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato omlet')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tomato Omlet', 'tomato omlet', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Extra Cheese / Butter / Ghee', 'extra cheese / butter / ghee'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra cheese / butter / ghee')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Extra Cheese / Butter / Ghee', 'extra cheese / butter / ghee', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sada Dosa', 'sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sada Dosa', 'sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Masala Dosa', 'masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Masala Dosa', 'masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mysore Masala Dosa', 'mysore masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mysore masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mysore Masala Dosa', 'mysore masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Rava Sada Dosa', 'rava sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rava sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Rava Sada Dosa', 'rava sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Rava Masala Dosa', 'rava masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rava masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Rava Masala Dosa', 'rava masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mysore Sada Dosa', 'mysore sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mysore sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mysore Sada Dosa', 'mysore sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Onion Rava Sada Dosa', 'onion rava sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion rava sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Onion Rava Sada Dosa', 'onion rava sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Onion Rava Masala Dosa', 'onion rava masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion rava masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Onion Rava Masala Dosa', 'onion rava masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Jini Dosa', 'jini dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jini dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Jini Dosa', 'jini dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Junglee Dosa', 'junglee dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'junglee dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Junglee Dosa', 'junglee dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Schezwan Sada Dosa', 'schezwan sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Schezwan Sada Dosa', 'schezwan sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Schezwan Masala Dosa', 'schezwan masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Schezwan Masala Dosa', 'schezwan masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chinese Sada Dosa', 'chinese sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chinese sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chinese Sada Dosa', 'chinese sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chinese Masala Dosa', 'chinese masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chinese masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chinese Masala Dosa', 'chinese masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Palak Sada Dosa', 'palak sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'palak sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Palak Sada Dosa', 'palak sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Palak Masala Dosa', 'palak masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'palak masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Palak Masala Dosa', 'palak masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Spring Dosa', 'spring dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spring dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Spring Dosa', 'spring dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Spring Masala Dosa', 'spring masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spring masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Spring Masala Dosa', 'spring masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Vihar Special Dosa', 'vihar special dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vihar special dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Vihar Special Dosa', 'vihar special dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Dosa', 'paneer dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Dosa', 'paneer dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Ghee Karam Dosa', 'ghee karam dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee karam dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Ghee Karam Dosa', 'ghee karam dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Ghee Karam Masala Dosa', 'ghee karam masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee karam masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Ghee Karam Masala Dosa', 'ghee karam masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paper Sada Dosa', 'paper sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paper sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paper Sada Dosa', 'paper sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paper Masala Dosa', 'paper masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paper masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paper Masala Dosa', 'paper masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Neer Dosa / Set Dosa / Ragi Dosa', 'neer dosa / set dosa / ragi dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'neer dosa / set dosa / ragi dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Neer Dosa / Set Dosa / Ragi Dosa', 'neer dosa / set dosa / ragi dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Chilly Dosa / Cheese Garlic Dosa', 'cheese chilly dosa / cheese garlic dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chilly dosa / cheese garlic dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Chilly Dosa / Cheese Garlic Dosa', 'cheese chilly dosa / cheese garlic dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Dosa', 'cheese dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Dosa', 'cheese dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sweet Kachori', 'sweet kachori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sweet kachori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sweet Kachori', 'sweet kachori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sabudana Vada', 'sabudana vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sabudana vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sabudana Vada', 'sabudana vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sabudana Khichdi', 'sabudana khichdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sabudana khichdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sabudana Khichdi', 'sabudana khichdi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Finger Chips', 'finger chips'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'finger chips')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Finger Chips', 'finger chips', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Potato Toast', 'potato toast'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'potato toast')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Potato Toast', 'potato toast', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Sandwich', 'veg. sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Sandwich', 'veg. sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Cheese Sandwich', 'veg. cheese sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. cheese sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Cheese Sandwich', 'veg. cheese sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Toast Sandwich', 'veg. toast sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. toast sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Toast Sandwich', 'veg. toast sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Cheese Toast Sandwich', 'veg. cheese toast sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. cheese toast sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Cheese Toast Sandwich', 'veg. cheese toast sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Chatney Sandwich', 'cheese chatney sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chatney sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Chatney Sandwich', 'cheese chatney sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Only Cheese Sandwich', 'only cheese sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'only cheese sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Only Cheese Sandwich', 'only cheese sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Bread Butter', 'bread butter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bread butter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Bread Butter', 'bread butter', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Toast Butter', 'toast butter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'toast butter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Toast Butter', 'toast butter', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Jam Bread', 'jam bread'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jam bread')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Jam Bread', 'jam bread', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Jam Toast', 'jam toast'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jam toast')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Jam Toast', 'jam toast', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Toast Omlet Sandwich', 'toast omlet sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'toast omlet sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Toast Omlet Sandwich', 'toast omlet sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Club Sandwich', 'club sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'club sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Club Sandwich', 'club sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Russian Sandwich', 'russian sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'russian sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Russian Sandwich', 'russian sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Italian Sandwich', 'italian sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'italian sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Italian Sandwich', 'italian sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chilly Milly Sandwich', 'chilly milly sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilly milly sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chilly Milly Sandwich', 'chilly milly sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chilly Garlic Toast', 'chilly garlic toast'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilly garlic toast')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chilly Garlic Toast', 'chilly garlic toast', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Grill Sandwich', 'veg. grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Grill Sandwich', 'veg. grill sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Cheese Grill Sandwich', 'veg. cheese grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. cheese grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Cheese Grill Sandwich', 'veg. cheese grill sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Club Cheese Grill Sandwich', 'veg. club cheese grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. club cheese grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Club Cheese Grill Sandwich', 'veg. club cheese grill sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Masala Grill Sandwich', 'masala grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Masala Grill Sandwich', 'masala grill sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Punjabi Grill Sandwich', 'punjabi grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'punjabi grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Punjabi Grill Sandwich', 'punjabi grill sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Chilly Grill Sandwich', 'cheese chilly grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chilly grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Chilly Grill Sandwich', 'cheese chilly grill sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Jain Veg. Grill sandwich', 'jain veg. grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain veg. grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Jain Veg. Grill sandwich', 'jain veg. grill sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Roasted Papad', 'roasted papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'roasted papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Roasted Papad', 'roasted papad', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Fry Papad', 'fry papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fry papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Fry Papad', 'fry papad', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Masala Papd', 'masala papd'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala papd')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Masala Papd', 'masala papd', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Masala Papad', 'cheese masala papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese masala papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Masala Papad', 'cheese masala papad', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Raita', 'veg. raita'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. raita')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Raita', 'veg. raita', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Boondi Raita', 'boondi raita'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'boondi raita')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Boondi Raita', 'boondi raita', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pineapple Raita', 'pineapple raita'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pineapple raita')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pineapple Raita', 'pineapple raita', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Plain Curd', 'plain curd'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'plain curd')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Plain Curd', 'plain curd', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mix Salad (Green)', 'mix salad (green)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix salad (green)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mix Salad (Green)', 'mix salad (green)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Russian Salad', 'russian salad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'russian salad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Russian Salad', 'russian salad', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pav Bhaji', 'pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pav Bhaji', 'pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Pav Bhaji', 'cheese pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Pav Bhaji', 'cheese pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tomato Pav Bhaji', 'tomato pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tomato Pav Bhaji', 'tomato pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Khada Pav Bhaji', 'khada pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'khada pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Khada Pav Bhaji', 'khada pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mushroom Pav Bhaji / Paneer Pav Bhaji', 'mushroom pav bhaji / paneer pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom pav bhaji / paneer pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mushroom Pav Bhaji / Paneer Pav Bhaji', 'mushroom pav bhaji / paneer pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Jain Pav Bhaji', 'jain pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Jain Pav Bhaji', 'jain pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Only Bhaji', 'only bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'only bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Only Bhaji', 'only bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Masala Pav', 'masala pav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala pav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Masala Pav', 'masala pav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Vihar Special Pav Bhaji', 'vihar special pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vihar special pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Vihar Special Pav Bhaji', 'vihar special pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Extra Pav', 'extra pav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra pav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Extra Pav', 'extra pav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Soup', 'veg. soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Soup', 'veg. soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Manchaw Soup', 'veg. manchaw soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchaw soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Manchaw Soup', 'veg. manchaw soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Clear Soup', 'veg. clear soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. clear soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Clear Soup', 'veg. clear soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Noodle Soup', 'veg. noodle soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. noodle soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Noodle Soup', 'veg. noodle soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Hot & Sour Soup', 'veg. hot & sour soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. hot & sour soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Hot & Sour Soup', 'veg. hot & sour soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Sweet Corn Soup', 'veg. sweet corn soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. sweet corn soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Sweet Corn Soup', 'veg. sweet corn soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mushroom Manchow Soup', 'mushroom manchow soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom manchow soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mushroom Manchow Soup', 'mushroom manchow soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tomato Soup', 'tomato soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tomato Soup', 'tomato soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Palak Soup', 'palak soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'palak soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Palak Soup', 'palak soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Lemon Coriander Soup', 'lemon coriander soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon coriander soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Lemon Coriander Soup', 'lemon coriander soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Tikka', 'paneer tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka', 'paneer tikka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mushroom Tikka', 'mushroom tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mushroom Tikka', 'mushroom tikka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Malai Tikka / Mushroom Malai Tikka', 'paneer malai tikka / mushroom malai tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer malai tikka / mushroom malai tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Malai Tikka / Mushroom Malai Tikka', 'paneer malai tikka / mushroom malai tikka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Reshmi Tikka (Paneer / Mushroom)', 'reshmi tikka (paneer / mushroom)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'reshmi tikka (paneer / mushroom)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Reshmi Tikka (Paneer / Mushroom)', 'reshmi tikka (paneer / mushroom)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Seekh Kabab', 'paneer seekh kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer seekh kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Seekh Kabab', 'paneer seekh kabab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Seekh Kabab', 'veg. seekh kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. seekh kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Seekh Kabab', 'veg. seekh kabab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chilly Milly Kabab', 'chilly milly kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilly milly kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chilly Milly Kabab', 'chilly milly kabab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Aloo Tikka', 'aloo tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Aloo Tikka', 'aloo tikka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Hara Bhara Kabab', 'hara bhara kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hara bhara kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Hara Bhara Kabab', 'hara bhara kabab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Masala / Paneer Butter Masala', 'paneer masala / paneer butter masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer masala / paneer butter masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Masala / Paneer Butter Masala', 'paneer masala / paneer butter masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Makhanwala / Paneer Kolhapuri', 'paneer makhanwala / paneer kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer makhanwala / paneer kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Makhanwala / Paneer Kolhapuri', 'paneer makhanwala / paneer kolhapuri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Malwani / Paneer Koliwada', 'paneer malwani / paneer koliwada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer malwani / paneer koliwada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Malwani / Paneer Koliwada', 'paneer malwani / paneer koliwada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Shahi Paneer . Paneer Kurma', 'shahi paneer . paneer kurma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'shahi paneer . paneer kurma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Shahi Paneer . Paneer Kurma', 'shahi paneer . paneer kurma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Mushroom Masala', 'paneer mushroom masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer mushroom masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Mushroom Masala', 'paneer mushroom masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Lassoni / Paneer Afgani', 'paneer lassoni / paneer afgani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer lassoni / paneer afgani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Lassoni / Paneer Afgani', 'paneer lassoni / paneer afgani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Bhurji / Paneer Kheema Masala', 'paneer bhurji / paneer kheema masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer bhurji / paneer kheema masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Bhurji / Paneer Kheema Masala', 'paneer bhurji / paneer kheema masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Mutter / Paneer Chana / Palak Paneer', 'paneer mutter / paneer chana / palak paneer'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer mutter / paneer chana / palak paneer')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Mutter / Paneer Chana / Palak Paneer', 'paneer mutter / paneer chana / palak paneer', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Tikka Masala / Mush. Tikka Masala', 'paneer tikka masala / mush. tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka masala / mush. tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka Masala / Mush. Tikka Masala', 'paneer tikka masala / mush. tikka masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Mushroom Tikka Masala', 'paneer mushroom tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer mushroom tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Mushroom Tikka Masala', 'paneer mushroom tikka masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Handi / Paneer Kadai', 'paneer handi / paneer kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer handi / paneer kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Handi / Paneer Kadai', 'paneer handi / paneer kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Angara', 'paneer angara'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer angara')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Angara', 'paneer angara', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mushroom Handi / Mushroom Kadai', 'mushroom handi / mushroom kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom handi / mushroom kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mushroom Handi / Mushroom Kadai', 'mushroom handi / mushroom kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sev Bhaji', 'sev bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sev bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sev Bhaji', 'sev bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Tadka', 'veg. tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Tadka', 'veg. tadka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Aloo Mutter / Aloo Palak / Plain Palak', 'aloo mutter / aloo palak / plain palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo mutter / aloo palak / plain palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Aloo Mutter / Aloo Palak / Plain Palak', 'aloo mutter / aloo palak / plain palak', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Aloo Methi', 'aloo methi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo methi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Aloo Methi', 'aloo methi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Aloo Simla', 'aloo simla'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo simla')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Aloo Simla', 'aloo simla', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chana Masala Fry', 'chana masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chana masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chana Masala Fry', 'chana masala fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Bhindi Fry / Bhendi Masala', 'bhindi fry / bhendi masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bhindi fry / bhendi masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Bhindi Fry / Bhendi Masala', 'bhindi fry / bhendi masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Baigan Masala / Baigan Bharta', 'baigan masala / baigan bharta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'baigan masala / baigan bharta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Baigan Masala / Baigan Bharta', 'baigan masala / baigan bharta', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Green Peas Masala / Mix Veg.', 'green peas masala / mix veg.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green peas masala / mix veg.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Green Peas Masala / Mix Veg.', 'green peas masala / mix veg.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Boiled Veg.', 'boiled veg.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'boiled veg.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Boiled Veg.', 'boiled veg.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Kolhapuri / Veg. Kurma', 'veg. kolhapuri / veg. kurma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. kolhapuri / veg. kurma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Kolhapuri / Veg. Kurma', 'veg. kolhapuri / veg. kurma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Tava Masala / Veg. Koliwada', 'veg. tava masala / veg. koliwada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. tava masala / veg. koliwada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Tava Masala / Veg. Koliwada', 'veg. tava masala / veg. koliwada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Kadai / Veg. Handi', 'veg. kadai / veg. handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. kadai / veg. handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Kadai / Veg. Handi', 'veg. kadai / veg. handi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Haryali / Veg. Hydrabadi', 'veg. haryali / veg. hydrabadi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. haryali / veg. hydrabadi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Haryali / Veg. Hydrabadi', 'veg. haryali / veg. hydrabadi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Makhanwala', 'veg. makhanwala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. makhanwala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Makhanwala', 'veg. makhanwala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Bhuna Masala', 'veg. bhuna masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. bhuna masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Bhuna Masala', 'veg. bhuna masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Stuff Tomato / Stuff Capsicum', 'stuff tomato / stuff capsicum'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'stuff tomato / stuff capsicum')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Stuff Tomato / Stuff Capsicum', 'stuff tomato / stuff capsicum', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dum Aloo Punjabi', 'dum aloo punjabi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dum aloo punjabi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dum Aloo Punjabi', 'dum aloo punjabi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dum Aloo Kashmiri', 'dum aloo kashmiri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dum aloo kashmiri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dum Aloo Kashmiri', 'dum aloo kashmiri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Kofta', 'veg. kofta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. kofta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Kofta', 'veg. kofta', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Malai Kofta / Cheese Kofta . Palak Kofta', 'malai kofta / cheese kofta . palak kofta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malai kofta / cheese kofta . palak kofta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Malai Kofta / Cheese Kofta . Palak Kofta', 'malai kofta / cheese kofta . palak kofta', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Palak Lasooni / Palak Methi', 'palak lasooni / palak methi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'palak lasooni / palak methi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Palak Lasooni / Palak Methi', 'palak lasooni / palak methi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Palak Cheese Kofta', 'palak cheese kofta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'palak cheese kofta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Palak Cheese Kofta', 'palak cheese kofta', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Malwani', 'veg. malwani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. malwani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Malwani', 'veg. malwani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chole Bhature', 'chole bhature'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chole bhature')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chole Bhature', 'chole bhature', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Tiranga', 'veg. tiranga'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. tiranga')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Tiranga', 'veg. tiranga', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Patiyala', 'veg. patiyala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. patiyala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Patiyala', 'veg. patiyala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Maharaja', 'veg. maharaja'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. maharaja')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Maharaja', 'veg. maharaja', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Angara', 'veg. angara'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. angara')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Angara', 'veg. angara', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Kabab Masala', 'veg. kabab masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. kabab masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Kabab Masala', 'veg. kabab masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Diwani Handi', 'veg. diwani handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. diwani handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Diwani Handi', 'veg. diwani handi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Nargis Kofta / Veg. Dilruba', 'nargis kofta / veg. dilruba'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'nargis kofta / veg. dilruba')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Nargis Kofta / Veg. Dilruba', 'nargis kofta / veg. dilruba', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Rajwadi / Paneer Jafrani', 'paneer rajwadi / paneer jafrani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer rajwadi / paneer jafrani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Rajwadi / Paneer Jafrani', 'paneer rajwadi / paneer jafrani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Rajwadi', 'cheese rajwadi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese rajwadi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Rajwadi', 'cheese rajwadi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kaju Masala / Kaju Curry', 'kaju masala / kaju curry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kaju masala / kaju curry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kaju Masala / Kaju Curry', 'kaju masala / kaju curry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kaju Makhanwala', 'kaju makhanwala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kaju makhanwala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kaju Makhanwala', 'kaju makhanwala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kaju Mushroom Masala / Curry', 'kaju mushroom masala / curry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kaju mushroom masala / curry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kaju Mushroom Masala / Curry', 'kaju mushroom masala / curry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Pasanda', 'paneer pasanda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pasanda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Pasanda', 'paneer pasanda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Musallam', 'paneer musallam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer musallam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Musallam', 'paneer musallam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Jalfrezee', 'veg. jalfrezee'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. jalfrezee')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Jalfrezee', 'veg. jalfrezee', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Kheema Masala', 'veg. kheema masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. kheema masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Kheema Masala', 'veg. kheema masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Do Pyaza / Bhindi Do Pyaza', 'paneer do pyaza / bhindi do pyaza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer do pyaza / bhindi do pyaza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Do Pyaza / Bhindi Do Pyaza', 'paneer do pyaza / bhindi do pyaza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Laziz / Paneer Rara', 'paneer laziz / paneer rara'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer laziz / paneer rara')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Laziz / Paneer Rara', 'paneer laziz / paneer rara', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kashmiri Kofta', 'kashmiri kofta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kashmiri kofta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kashmiri Kofta', 'kashmiri kofta', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Vihar Special', 'vihar special'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vihar special')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Vihar Special', 'vihar special', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Chilly Milly', 'veg. chilly milly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. chilly milly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Chilly Milly', 'veg. chilly milly', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Afgani / Veg. Lahori', 'veg. afgani / veg. lahori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. afgani / veg. lahori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Afgani / Veg. Lahori', 'veg. afgani / veg. lahori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Seekh Kabab Masala', 'veg. seekh kabab masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. seekh kabab masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Seekh Kabab Masala', 'veg. seekh kabab masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dal Fry', 'dal fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dal Fry', 'dal fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dal Kolhapuri', 'dal kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dal Kolhapuri', 'dal kolhapuri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Dal Fry', 'butter dal fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter dal fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Dal Fry', 'butter dal fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dal Tadka', 'dal tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dal Tadka', 'dal tadka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dal Palak', 'dal palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dal Palak', 'dal palak', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Steam Rice H/F', 'steam rice h/f'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'steam rice h/f')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Steam Rice H/F', 'steam rice h/f', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Jeera Rice / Jeera Rice', 'jeera rice / jeera rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jeera rice / jeera rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Jeera Rice / Jeera Rice', 'jeera rice / jeera rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Pulao / Green Peas Pulao', 'veg. pulao / green peas pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. pulao / green peas pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Pulao / Green Peas Pulao', 'veg. pulao / green peas pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Pulao / Mushroom Pulao', 'paneer pulao / mushroom pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pulao / mushroom pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Pulao / Mushroom Pulao', 'paneer pulao / mushroom pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tawa Pulao', 'tawa pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tawa pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tawa Pulao', 'tawa pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kashmiri Pulao (with fruits)', 'kashmiri pulao (with fruits)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kashmiri pulao (with fruits)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kashmiri Pulao (with fruits)', 'kashmiri pulao (with fruits)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Biryani', 'veg. biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Biryani', 'veg. biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Dum Biryani', 'veg. dum biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. dum biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Dum Biryani', 'veg. dum biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Biryani / Mushroom Biryani', 'paneer biryani / mushroom biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer biryani / mushroom biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Biryani / Mushroom Biryani', 'paneer biryani / mushroom biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Mushroom Biryani', 'paneer mushroom biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer mushroom biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Mushroom Biryani', 'paneer mushroom biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Hydrabadi Biryani', 'veg. hydrabadi biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. hydrabadi biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Hydrabadi Biryani', 'veg. hydrabadi biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Maharaja Biryani', 'maharaja biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'maharaja biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Maharaja Biryani', 'maharaja biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Tikka Biryani / Mushroom Biryani', 'paneer tikka biryani / mushroom biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka biryani / mushroom biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka Biryani / Mushroom Biryani', 'paneer tikka biryani / mushroom biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Biryani', 'cheese biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Biryani', 'cheese biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Singapore Biryani', 'singapore biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'singapore biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Singapore Biryani', 'singapore biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Vihar Special Biryani', 'vihar special biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vihar special biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Vihar Special Biryani', 'vihar special biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Curd Rice', 'curd rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'curd rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Curd Rice', 'curd rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dal Khichdi', 'dal khichdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal khichdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dal Khichdi', 'dal khichdi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Palak Khichdi', 'palak khichdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'palak khichdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Palak Khichdi', 'palak khichdi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Curd Rice Tadka', 'curd rice tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'curd rice tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Curd Rice Tadka', 'curd rice tadka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dal Khichdi Tadka', 'dal khichdi tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal khichdi tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dal Khichdi Tadka', 'dal khichdi tadka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Ghee Rice', 'ghee rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Ghee Rice', 'ghee rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Rani Pulao', 'rani pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rani pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Rani Pulao', 'rani pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sahajani Pulao', 'sahajani pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sahajani pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sahajani Pulao', 'sahajani pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Brown Rice', 'brown rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'brown rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Brown Rice', 'brown rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tomato Rice', 'tomato rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tomato Rice', 'tomato rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chapati', 'chapati'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chapati')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chapati', 'chapati', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Naan', 'naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Naan', 'naan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paratha', 'paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paratha', 'paratha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Garlic Naan', 'garlic naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Garlic Naan', 'garlic naan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Methi Paratha', 'methi paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'methi paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Methi Paratha', 'methi paratha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Aloo Paratha / Gobi Paratha', 'aloo paratha / gobi paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo paratha / gobi paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Aloo Paratha / Gobi Paratha', 'aloo paratha / gobi paratha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Paratha', 'cheese paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Paratha', 'cheese paratha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Stuff Paratha', 'stuff paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'stuff paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Stuff Paratha', 'stuff paratha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Masala Paratha / Kulcha', 'masala paratha / kulcha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala paratha / kulcha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Masala Paratha / Kulcha', 'masala paratha / kulcha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kulcha', 'kulcha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kulcha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kulcha', 'kulcha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Bhatura', 'bhatura'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bhatura')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Bhatura', 'bhatura', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Puri', 'puri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'puri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Puri', 'puri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Paratha', 'paneer paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Paratha', 'paneer paratha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Garlic Naan', 'cheese garlic naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese garlic naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Garlic Naan', 'cheese garlic naan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Chilly (Dry/Gravy)', 'veg. chilly (dry/gravy)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. chilly (dry/gravy)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Chilly (Dry/Gravy)', 'veg. chilly (dry/gravy)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. 65 (Dry/Gravy)', 'veg. 65 (dry/gravy)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. 65 (dry/gravy)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. 65 (Dry/Gravy)', 'veg. 65 (dry/gravy)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Manchurian (Dry/Gravy)', 'veg. manchurian (dry/gravy)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchurian (dry/gravy)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Manchurian (Dry/Gravy)', 'veg. manchurian (dry/gravy)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Crispy (Dry/Gravy)', 'veg. crispy (dry/gravy)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. crispy (dry/gravy)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Crispy (Dry/Gravy)', 'veg. crispy (dry/gravy)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Dragon', 'veg. dragon'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. dragon')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Dragon', 'veg. dragon', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Burnt Garlic', 'veg. burnt garlic'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. burnt garlic')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Burnt Garlic', 'veg. burnt garlic', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Gobi Manchurian (Dry/Gravy)', 'gobi manchurian (dry/gravy)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'gobi manchurian (dry/gravy)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Gobi Manchurian (Dry/Gravy)', 'gobi manchurian (dry/gravy)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chinese Bhel', 'chinese bhel'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chinese bhel')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chinese Bhel', 'chinese bhel', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Soyabin Chilly', 'soyabin chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'soyabin chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Soyabin Chilly', 'soyabin chilly', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Fried Rice / Noodles', 'veg. fried rice / noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. fried rice / noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Fried Rice / Noodles', 'veg. fried rice / noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Schezwan Rice / Noodles', 'veg. schezwan rice / noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. schezwan rice / noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Schezwan Rice / Noodles', 'veg. schezwan rice / noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Triple Rice / Noodles', 'veg. triple rice / noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. triple rice / noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Triple Rice / Noodles', 'veg. triple rice / noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Manchurian Rice / Noodles', 'veg. manchurian rice / noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchurian rice / noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Manchurian Rice / Noodles', 'veg. manchurian rice / noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Hong Kong Rice / Noodles', 'veg. hong kong rice / noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. hong kong rice / noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Hong Kong Rice / Noodles', 'veg. hong kong rice / noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Singapore Rice / Noodles', 'veg. singapore rice / noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. singapore rice / noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Singapore Rice / Noodles', 'veg. singapore rice / noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. American Choppsy', 'veg. american choppsy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. american choppsy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. American Choppsy', 'veg. american choppsy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Burnt Garlic Rice / Noodles', 'veg. burnt garlic rice / noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. burnt garlic rice / noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Burnt Garlic Rice / Noodles', 'veg. burnt garlic rice / noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Pot Rice', 'veg. pot rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. pot rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Pot Rice', 'veg. pot rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Pizza', 'veg. pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Pizza', 'veg. pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Mushroom Baby Corn Pizza', 'paneer mushroom baby corn pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer mushroom baby corn pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Mushroom Baby Corn Pizza', 'paneer mushroom baby corn pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Jain Pizza', 'jain pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Jain Pizza', 'jain pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Cheese Pizza', 'paneer cheese pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer cheese pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Cheese Pizza', 'paneer cheese pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Onion Capsicum Pizza', 'onion capsicum pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion capsicum pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Onion Capsicum Pizza', 'onion capsicum pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Capsicum Pizza', 'capsicum pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'capsicum pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Capsicum Pizza', 'capsicum pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mushroom Cheese Pizza', 'mushroom cheese pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom cheese pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mushroom Cheese Pizza', 'mushroom cheese pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Baby Corn Pizza', 'baby corn pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'baby corn pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Baby Corn Pizza', 'baby corn pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chilly Cheese Pizza', 'chilly cheese pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilly cheese pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chilly Cheese Pizza', 'chilly cheese pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pineapple Pizza', 'pineapple pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pineapple pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pineapple Pizza', 'pineapple pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Fruit Salad', 'fruit salad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fruit salad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Fruit Salad', 'fruit salad', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Fruit Salad with Ice-Cream', 'fruit salad with ice-cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fruit salad with ice-cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Fruit Salad with Ice-Cream', 'fruit salad with ice-cream', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Jelly', 'jelly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jelly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Jelly', 'jelly', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Jelly with Ice-Cream', 'jelly with ice-cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jelly with ice-cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Jelly with Ice-Cream', 'jelly with ice-cream', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Fruit Salad Jelly with Ice-Cream', 'fruit salad jelly with ice-cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fruit salad jelly with ice-cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Fruit Salad Jelly with Ice-Cream', 'fruit salad jelly with ice-cream', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mosambi / Orange', 'mosambi / orange'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mosambi / orange')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mosambi / Orange', 'mosambi / orange', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Apple', 'apple'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'apple')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Apple', 'apple', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Ganga Jamuna', 'ganga jamuna'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ganga jamuna')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Ganga Jamuna', 'ganga jamuna', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pineapple', 'pineapple'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pineapple')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pineapple', 'pineapple', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cocktail', 'cocktail'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cocktail')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cocktail', 'cocktail', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mara Mari', 'mara mari'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mara mari')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mara Mari', 'mara mari', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Watermelon', 'watermelon'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'watermelon')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Watermelon', 'watermelon', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Grape', 'grape'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'grape')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Grape', 'grape', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Anar', 'anar'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'anar')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Anar', 'anar', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cold Coffee', 'cold coffee'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cold coffee')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cold Coffee', 'cold coffee', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cold Coffee with Ice-Cream', 'cold coffee with ice-cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cold coffee with ice-cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cold Coffee with Ice-Cream', 'cold coffee with ice-cream', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Rose Milkshake', 'rose milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rose milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Rose Milkshake', 'rose milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Strawberry Milkshake', 'strawberry milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'strawberry milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Strawberry Milkshake', 'strawberry milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mango Milkshake', 'mango milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mango milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mango Milkshake', 'mango milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Oreo Milkshake', 'oreo milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'oreo milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Oreo Milkshake', 'oreo milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chiku Milkshake', 'chiku milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chiku milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chiku Milkshake', 'chiku milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Apple Milkshake', 'apple milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'apple milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Apple Milkshake', 'apple milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Banana Milkshake', 'banana milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'banana milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Banana Milkshake', 'banana milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chocolate Milkshake', 'chocolate milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chocolate milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chocolate Milkshake', 'chocolate milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Vanilla Milkshake', 'vanilla milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vanilla milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Vanilla Milkshake', 'vanilla milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dry Fruit Milkshake', 'dry fruit milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dry fruit milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dry Fruit Milkshake', 'dry fruit milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pista Milkshake', 'pista milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pista milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pista Milkshake', 'pista milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kesar Milkshake', 'kesar milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kesar milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kesar Milkshake', 'kesar milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mojito', 'mojito'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mojito')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mojito', 'mojito', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Orange Crush', 'orange crush'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'orange crush')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Orange Crush', 'orange crush', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kiwi Punch', 'kiwi punch'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kiwi punch')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kiwi Punch', 'kiwi punch', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Blue Berry Punch', 'blue berry punch'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'blue berry punch')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Blue Berry Punch', 'blue berry punch', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Blue Lagoon', 'blue lagoon'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'blue lagoon')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Blue Lagoon', 'blue lagoon', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pina Colada', 'pina colada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pina colada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pina Colada', 'pina colada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Royal Falooda', 'royal falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'royal falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Royal Falooda', 'royal falooda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kesar Falooda', 'kesar falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kesar falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kesar Falooda', 'kesar falooda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dry Fruit Falooda', 'dry fruit falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dry fruit falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dry Fruit Falooda', 'dry fruit falooda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pista Falooda', 'pista falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pista falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pista Falooda', 'pista falooda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mango Falooda', 'mango falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mango falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mango Falooda', 'mango falooda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sitafal Falooda', 'sitafal falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sitafal falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sitafal Falooda', 'sitafal falooda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Strawberry Falooda', 'strawberry falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'strawberry falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Strawberry Falooda', 'strawberry falooda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Single Scoop', 'single scoop'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'single scoop')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Single Scoop', 'single scoop', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tea', 'tea'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tea')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tea', 'tea', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Nescafe', 'nescafe'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'nescafe')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Nescafe', 'nescafe', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Filter Coffee', 'filter coffee'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'filter coffee')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Filter Coffee', 'filter coffee', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Hot Milk (200 ml)', 'hot milk (200 ml)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hot milk (200 ml)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Hot Milk (200 ml)', 'hot milk (200 ml)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sweet Lassi', 'sweet lassi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sweet lassi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sweet Lassi', 'sweet lassi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mango Lassi / Pista Lassi / Kesar Lassi', 'mango lassi / pista lassi / kesar lassi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mango lassi / pista lassi / kesar lassi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mango Lassi / Pista Lassi / Kesar Lassi', 'mango lassi / pista lassi / kesar lassi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Lemon Juice', 'lemon juice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon juice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Lemon Juice', 'lemon juice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Lemon Soda', 'lemon soda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon soda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Lemon Soda', 'lemon soda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kokam Sharbat', 'kokam sharbat'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kokam sharbat')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kokam Sharbat', 'kokam sharbat', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Ginger Lemon Water', 'ginger lemon water'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ginger lemon water')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Ginger Lemon Water', 'ginger lemon water', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sikandar Sharbat', 'sikandar sharbat'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sikandar sharbat')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sikandar Sharbat', 'sikandar sharbat', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Milk', 'butter milk'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter milk')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Milk', 'butter milk', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Gulab Jamun (2 psc)', 'gulab jamun (2 psc)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'gulab jamun (2 psc)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Gulab Jamun (2 psc)', 'gulab jamun (2 psc)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Special Sunday', 'special sunday'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'special sunday')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Special Sunday', 'special sunday', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Carmel Custard', 'carmel custard'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'carmel custard')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Carmel Custard', 'carmel custard', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Double Scoop', 'double scoop'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'double scoop')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Double Scoop', 'double scoop', 'primary'
FROM new_dish;

-- Menu items: deterministic explicit menu_item_id; canonical_dish_id resolved live by
-- join; protein_type_id resolved live by LEFT JOIN on code (NULL stays NULL -- most
-- rows here are vegetarian or have no stated protein).
INSERT INTO menu_item (
    menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name,
    raw_category_text, food_classification_code, protein_type_id, split_group_key,
    verification_status_code
)
SELECT x.menu_item_id, x.restaurant_id, cd.canonical_dish_id, x.name, x.normalized_name,
       x.raw_category_text, x.food_classification_code, pt.protein_type_id, x.split_group_key,
       x.verification_status_code
FROM (VALUES
    (400081005001, 400081005, 'Upma', 'upma', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005002, 400081005, 'Sheera', 'sheera', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005003, 400081005, 'Poha', 'poha', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005004, 400081005, 'Steam Idli', 'steam idli', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005005, 400081005, 'Dahi Idli', 'dahi idli', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005006, 400081005, 'Idli Vada', 'idli vada', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005007, 400081005, 'Medu Vada', 'medu vada', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005008, 400081005, 'Potato Vada', 'potato vada', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005009, 400081005, 'Mix Vada', 'mix vada', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005010, 400081005, 'Dahi Vada', 'dahi vada', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005011, 400081005, 'Misal Pav', 'misal pav', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005012, 400081005, 'Vada Usal (Potato)', 'vada usal (potato)', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005013, 400081005, 'Puri Bhaji', 'puri bhaji', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005014, 400081005, 'Puri Shrikhand', 'puri shrikhand', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005015, 400081005, 'Kothimbari Vadi', 'kothimbari vadi', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005016, 400081005, 'Cheese Pakoda', 'cheese pakoda', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005017, 400081005, 'Puri (Plate)', 'puri (plate)', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005018, 400081005, 'Pav', 'pav', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005019, 400081005, 'Veg. Cuttlet', 'veg. cuttlet', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005020, 400081005, 'Mix Pokoda', 'mix pokoda', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005021, 400081005, 'Paneer Pakoda', 'paneer pakoda', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005022, 400081005, 'Dahi Misal Pav', 'dahi misal pav', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005023, 400081005, 'Sada Uttappa', 'sada uttappa', 'UTTAPPA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005024, 400081005, 'Masala Uttappa', 'masala uttappa', 'UTTAPPA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005025, 400081005, 'Onion Uttappa', 'onion uttappa', 'UTTAPPA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005026, 400081005, 'Tomato Uttappa', 'tomato uttappa', 'UTTAPPA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005027, 400081005, 'Onion Tomato Uttappa', 'onion tomato uttappa', 'UTTAPPA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005028, 400081005, 'Duet Uttappa', 'duet uttappa', 'UTTAPPA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005029, 400081005, 'Coconut Uttappa', 'coconut uttappa', 'UTTAPPA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005030, 400081005, 'Cucumber Uttappa', 'cucumber uttappa', 'UTTAPPA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005031, 400081005, 'Paneer Uttappa', 'paneer uttappa', 'UTTAPPA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005032, 400081005, 'Tomato Omlet', 'tomato omlet', 'UTTAPPA', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400081005033, 400081005, 'Extra Cheese / Butter / Ghee', 'extra cheese / butter / ghee', 'UTTAPPA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005034, 400081005, 'Sada Dosa', 'sada dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005035, 400081005, 'Masala Dosa', 'masala dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005036, 400081005, 'Mysore Masala Dosa', 'mysore masala dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005037, 400081005, 'Rava Sada Dosa', 'rava sada dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005038, 400081005, 'Rava Masala Dosa', 'rava masala dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005039, 400081005, 'Mysore Sada Dosa', 'mysore sada dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005040, 400081005, 'Onion Rava Sada Dosa', 'onion rava sada dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005041, 400081005, 'Onion Rava Masala Dosa', 'onion rava masala dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005042, 400081005, 'Jini Dosa', 'jini dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005043, 400081005, 'Junglee Dosa', 'junglee dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005044, 400081005, 'Schezwan Sada Dosa', 'schezwan sada dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005045, 400081005, 'Schezwan Masala Dosa', 'schezwan masala dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005046, 400081005, 'Chinese Sada Dosa', 'chinese sada dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005047, 400081005, 'Chinese Masala Dosa', 'chinese masala dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005048, 400081005, 'Palak Sada Dosa', 'palak sada dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005049, 400081005, 'Palak Masala Dosa', 'palak masala dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005050, 400081005, 'Spring Dosa', 'spring dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005051, 400081005, 'Spring Masala Dosa', 'spring masala dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005052, 400081005, 'Vihar Special Dosa', 'vihar special dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005053, 400081005, 'Paneer Dosa', 'paneer dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005054, 400081005, 'Ghee Karam Dosa', 'ghee karam dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005055, 400081005, 'Ghee Karam Masala Dosa', 'ghee karam masala dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005056, 400081005, 'Paper Sada Dosa', 'paper sada dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005057, 400081005, 'Paper Masala Dosa', 'paper masala dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005058, 400081005, 'Neer Dosa / Set Dosa / Ragi Dosa', 'neer dosa / set dosa / ragi dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005059, 400081005, 'Cheese Chilly Dosa / Cheese Garlic Dosa', 'cheese chilly dosa / cheese garlic dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005060, 400081005, 'Cheese Dosa', 'cheese dosa', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005061, 400081005, 'Extra Cheese / Butter / Ghee', 'extra cheese / butter / ghee', 'DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005062, 400081005, 'Sweet Kachori', 'sweet kachori', 'UPWAS ITEM', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005063, 400081005, 'Sabudana Vada', 'sabudana vada', 'UPWAS ITEM', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005064, 400081005, 'Sabudana Khichdi', 'sabudana khichdi', 'UPWAS ITEM', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005065, 400081005, 'Finger Chips', 'finger chips', 'UPWAS ITEM', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005066, 400081005, 'Potato Toast', 'potato toast', 'UPWAS ITEM', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005067, 400081005, 'Veg. Sandwich', 'veg. sandwich', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005068, 400081005, 'Veg. Cheese Sandwich', 'veg. cheese sandwich', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005069, 400081005, 'Veg. Toast Sandwich', 'veg. toast sandwich', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005070, 400081005, 'Veg. Cheese Toast Sandwich', 'veg. cheese toast sandwich', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005071, 400081005, 'Cheese Chatney Sandwich', 'cheese chatney sandwich', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005072, 400081005, 'Only Cheese Sandwich', 'only cheese sandwich', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005073, 400081005, 'Bread Butter', 'bread butter', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005074, 400081005, 'Toast Butter', 'toast butter', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005075, 400081005, 'Jam Bread', 'jam bread', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005076, 400081005, 'Jam Toast', 'jam toast', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005077, 400081005, 'Toast Omlet Sandwich', 'toast omlet sandwich', 'SANDWICH', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400081005078, 400081005, 'Club Sandwich', 'club sandwich', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005079, 400081005, 'Russian Sandwich', 'russian sandwich', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005080, 400081005, 'Italian Sandwich', 'italian sandwich', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005081, 400081005, 'Chilly Milly Sandwich', 'chilly milly sandwich', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005082, 400081005, 'Chilly Garlic Toast', 'chilly garlic toast', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005083, 400081005, 'Veg. Grill Sandwich', 'veg. grill sandwich', 'GRILL SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005084, 400081005, 'Veg. Cheese Grill Sandwich', 'veg. cheese grill sandwich', 'GRILL SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005085, 400081005, 'Veg. Club Cheese Grill Sandwich', 'veg. club cheese grill sandwich', 'GRILL SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005086, 400081005, 'Masala Grill Sandwich', 'masala grill sandwich', 'GRILL SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005087, 400081005, 'Punjabi Grill Sandwich', 'punjabi grill sandwich', 'GRILL SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005088, 400081005, 'Cheese Chilly Grill Sandwich', 'cheese chilly grill sandwich', 'GRILL SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005089, 400081005, 'Jain Veg. Grill sandwich', 'jain veg. grill sandwich', 'GRILL SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005090, 400081005, 'Roasted Papad', 'roasted papad', 'TIMEPASS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005091, 400081005, 'Fry Papad', 'fry papad', 'TIMEPASS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005092, 400081005, 'Masala Papd', 'masala papd', 'TIMEPASS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005093, 400081005, 'Cheese Masala Papad', 'cheese masala papad', 'TIMEPASS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005094, 400081005, 'Veg. Raita', 'veg. raita', 'SALAD / RAITA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005095, 400081005, 'Boondi Raita', 'boondi raita', 'SALAD / RAITA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005096, 400081005, 'Pineapple Raita', 'pineapple raita', 'SALAD / RAITA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005097, 400081005, 'Plain Curd', 'plain curd', 'SALAD / RAITA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005098, 400081005, 'Mix Salad (Green)', 'mix salad (green)', 'SALAD / RAITA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005099, 400081005, 'Russian Salad', 'russian salad', 'SALAD / RAITA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005100, 400081005, 'Pav Bhaji', 'pav bhaji', 'PAV BHAJI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005101, 400081005, 'Cheese Pav Bhaji', 'cheese pav bhaji', 'PAV BHAJI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005102, 400081005, 'Tomato Pav Bhaji', 'tomato pav bhaji', 'PAV BHAJI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005103, 400081005, 'Khada Pav Bhaji', 'khada pav bhaji', 'PAV BHAJI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005104, 400081005, 'Mushroom Pav Bhaji / Paneer Pav Bhaji', 'mushroom pav bhaji / paneer pav bhaji', 'PAV BHAJI', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400081005105, 400081005, 'Jain Pav Bhaji', 'jain pav bhaji', 'PAV BHAJI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005106, 400081005, 'Only Bhaji', 'only bhaji', 'PAV BHAJI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005107, 400081005, 'Masala Pav', 'masala pav', 'PAV BHAJI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005108, 400081005, 'Vihar Special Pav Bhaji', 'vihar special pav bhaji', 'PAV BHAJI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005109, 400081005, 'Extra Pav', 'extra pav', 'PAV BHAJI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005110, 400081005, 'Veg. Soup', 'veg. soup', 'SOUP', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005111, 400081005, 'Veg. Manchaw Soup', 'veg. manchaw soup', 'SOUP', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005112, 400081005, 'Veg. Clear Soup', 'veg. clear soup', 'SOUP', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005113, 400081005, 'Veg. Noodle Soup', 'veg. noodle soup', 'SOUP', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005114, 400081005, 'Veg. Hot & Sour Soup', 'veg. hot & sour soup', 'SOUP', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005115, 400081005, 'Veg. Sweet Corn Soup', 'veg. sweet corn soup', 'SOUP', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005116, 400081005, 'Mushroom Manchow Soup', 'mushroom manchow soup', 'SOUP', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005117, 400081005, 'Tomato Soup', 'tomato soup', 'SOUP', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005118, 400081005, 'Palak Soup', 'palak soup', 'SOUP', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005119, 400081005, 'Lemon Coriander Soup', 'lemon coriander soup', 'SOUP', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005120, 400081005, 'Paneer Tikka', 'paneer tikka', 'TANDOORI STARTER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005121, 400081005, 'Mushroom Tikka', 'mushroom tikka', 'TANDOORI STARTER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005122, 400081005, 'Paneer Malai Tikka / Mushroom Malai Tikka', 'paneer malai tikka / mushroom malai tikka', 'TANDOORI STARTER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005123, 400081005, 'Reshmi Tikka (Paneer / Mushroom)', 'reshmi tikka (paneer / mushroom)', 'TANDOORI STARTER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005124, 400081005, 'Paneer Seekh Kabab', 'paneer seekh kabab', 'TANDOORI STARTER', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400081005125, 400081005, 'Veg. Seekh Kabab', 'veg. seekh kabab', 'TANDOORI STARTER', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400081005126, 400081005, 'Chilly Milly Kabab', 'chilly milly kabab', 'TANDOORI STARTER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005127, 400081005, 'Aloo Tikka', 'aloo tikka', 'TANDOORI STARTER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005128, 400081005, 'Hara Bhara Kabab', 'hara bhara kabab', 'TANDOORI STARTER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005129, 400081005, 'Paneer Masala / Paneer Butter Masala', 'paneer masala / paneer butter masala', 'PUNJABI TADKA (PANEER)', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400081005130, 400081005, 'Paneer Makhanwala / Paneer Kolhapuri', 'paneer makhanwala / paneer kolhapuri', 'PUNJABI TADKA (PANEER)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005131, 400081005, 'Paneer Malwani / Paneer Koliwada', 'paneer malwani / paneer koliwada', 'PUNJABI TADKA (PANEER)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005132, 400081005, 'Shahi Paneer . Paneer Kurma', 'shahi paneer . paneer kurma', 'PUNJABI TADKA (PANEER)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005133, 400081005, 'Paneer Mushroom Masala', 'paneer mushroom masala', 'PUNJABI TADKA (PANEER)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005134, 400081005, 'Paneer Lassoni / Paneer Afgani', 'paneer lassoni / paneer afgani', 'PUNJABI TADKA (PANEER)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005135, 400081005, 'Paneer Bhurji / Paneer Kheema Masala', 'paneer bhurji / paneer kheema masala', 'PUNJABI TADKA (PANEER)', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400081005136, 400081005, 'Paneer Mutter / Paneer Chana / Palak Paneer', 'paneer mutter / paneer chana / palak paneer', 'PUNJABI TADKA (PANEER)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005137, 400081005, 'Paneer Tikka Masala / Mush. Tikka Masala', 'paneer tikka masala / mush. tikka masala', 'PUNJABI TADKA (PANEER)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005138, 400081005, 'Paneer Mushroom Tikka Masala', 'paneer mushroom tikka masala', 'PUNJABI TADKA (PANEER)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005139, 400081005, 'Paneer Handi / Paneer Kadai', 'paneer handi / paneer kadai', 'PUNJABI TADKA (PANEER)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005140, 400081005, 'Paneer Angara', 'paneer angara', 'PUNJABI TADKA (PANEER)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005141, 400081005, 'Mushroom Handi / Mushroom Kadai', 'mushroom handi / mushroom kadai', 'PUNJABI TADKA (PANEER)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005142, 400081005, 'Sev Bhaji', 'sev bhaji', 'PUNJABI TADKA (PANEER)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005143, 400081005, 'Veg. Tadka', 'veg. tadka', 'PUNJABI TADKA (PANEER)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005144, 400081005, 'Aloo Mutter / Aloo Palak / Plain Palak', 'aloo mutter / aloo palak / plain palak', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005145, 400081005, 'Aloo Methi', 'aloo methi', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005146, 400081005, 'Aloo Simla', 'aloo simla', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005147, 400081005, 'Chana Masala Fry', 'chana masala fry', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005148, 400081005, 'Bhindi Fry / Bhendi Masala', 'bhindi fry / bhendi masala', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400081005149, 400081005, 'Baigan Masala / Baigan Bharta', 'baigan masala / baigan bharta', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400081005150, 400081005, 'Green Peas Masala / Mix Veg.', 'green peas masala / mix veg.', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005151, 400081005, 'Boiled Veg.', 'boiled veg.', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005152, 400081005, 'Veg. Kolhapuri / Veg. Kurma', 'veg. kolhapuri / veg. kurma', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005153, 400081005, 'Veg. Tava Masala / Veg. Koliwada', 'veg. tava masala / veg. koliwada', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005154, 400081005, 'Veg. Kadai / Veg. Handi', 'veg. kadai / veg. handi', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005155, 400081005, 'Veg. Haryali / Veg. Hydrabadi', 'veg. haryali / veg. hydrabadi', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005156, 400081005, 'Veg. Makhanwala', 'veg. makhanwala', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005157, 400081005, 'Veg. Bhuna Masala', 'veg. bhuna masala', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005158, 400081005, 'Stuff Tomato / Stuff Capsicum', 'stuff tomato / stuff capsicum', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005159, 400081005, 'Dum Aloo Punjabi', 'dum aloo punjabi', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005160, 400081005, 'Dum Aloo Kashmiri', 'dum aloo kashmiri', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005161, 400081005, 'Veg. Kofta', 'veg. kofta', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005162, 400081005, 'Malai Kofta / Cheese Kofta . Palak Kofta', 'malai kofta / cheese kofta . palak kofta', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005163, 400081005, 'Palak Lasooni / Palak Methi', 'palak lasooni / palak methi', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005164, 400081005, 'Palak Cheese Kofta', 'palak cheese kofta', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005165, 400081005, 'Veg. Malwani', 'veg. malwani', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005166, 400081005, 'Chole Bhature', 'chole bhature', 'PUNJABI TADKA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005167, 400081005, 'Veg. Tiranga', 'veg. tiranga', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005168, 400081005, 'Veg. Patiyala', 'veg. patiyala', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005169, 400081005, 'Veg. Maharaja', 'veg. maharaja', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005170, 400081005, 'Veg. Angara', 'veg. angara', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005171, 400081005, 'Veg. Kabab Masala', 'veg. kabab masala', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005172, 400081005, 'Veg. Diwani Handi', 'veg. diwani handi', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005173, 400081005, 'Nargis Kofta / Veg. Dilruba', 'nargis kofta / veg. dilruba', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005174, 400081005, 'Paneer Rajwadi / Paneer Jafrani', 'paneer rajwadi / paneer jafrani', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005175, 400081005, 'Cheese Rajwadi', 'cheese rajwadi', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005176, 400081005, 'Kaju Masala / Kaju Curry', 'kaju masala / kaju curry', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005177, 400081005, 'Kaju Makhanwala', 'kaju makhanwala', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005178, 400081005, 'Kaju Mushroom Masala / Curry', 'kaju mushroom masala / curry', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005179, 400081005, 'Paneer Pasanda', 'paneer pasanda', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005180, 400081005, 'Paneer Musallam', 'paneer musallam', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005181, 400081005, 'Veg. Jalfrezee', 'veg. jalfrezee', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005182, 400081005, 'Veg. Kheema Masala', 'veg. kheema masala', 'VIHAR CHEF SPECIAL', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400081005183, 400081005, 'Paneer Do Pyaza / Bhindi Do Pyaza', 'paneer do pyaza / bhindi do pyaza', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005184, 400081005, 'Paneer Laziz / Paneer Rara', 'paneer laziz / paneer rara', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005185, 400081005, 'Kashmiri Kofta', 'kashmiri kofta', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005186, 400081005, 'Vihar Special', 'vihar special', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005187, 400081005, 'Veg. Chilly Milly', 'veg. chilly milly', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005188, 400081005, 'Veg. Afgani / Veg. Lahori', 'veg. afgani / veg. lahori', 'VIHAR CHEF SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005189, 400081005, 'Veg. Seekh Kabab Masala', 'veg. seekh kabab masala', 'VIHAR CHEF SPECIAL', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400081005190, 400081005, 'Dal Fry', 'dal fry', 'DAL KA DHAMAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005191, 400081005, 'Dal Kolhapuri', 'dal kolhapuri', 'DAL KA DHAMAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005192, 400081005, 'Butter Dal Fry', 'butter dal fry', 'DAL KA DHAMAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005193, 400081005, 'Dal Tadka', 'dal tadka', 'DAL KA DHAMAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005194, 400081005, 'Dal Palak', 'dal palak', 'DAL KA DHAMAL', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400081005195, 400081005, 'Steam Rice H/F', 'steam rice h/f', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400081005196, 400081005, 'Jeera Rice / Jeera Rice', 'jeera rice / jeera rice', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400081005197, 400081005, 'Veg. Pulao / Green Peas Pulao', 'veg. pulao / green peas pulao', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005198, 400081005, 'Paneer Pulao / Mushroom Pulao', 'paneer pulao / mushroom pulao', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005199, 400081005, 'Tawa Pulao', 'tawa pulao', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005200, 400081005, 'Kashmiri Pulao (with fruits)', 'kashmiri pulao (with fruits)', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005201, 400081005, 'Veg. Biryani', 'veg. biryani', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005202, 400081005, 'Veg. Dum Biryani', 'veg. dum biryani', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005203, 400081005, 'Paneer Biryani / Mushroom Biryani', 'paneer biryani / mushroom biryani', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005204, 400081005, 'Paneer Mushroom Biryani', 'paneer mushroom biryani', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005205, 400081005, 'Veg. Hydrabadi Biryani', 'veg. hydrabadi biryani', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005206, 400081005, 'Maharaja Biryani', 'maharaja biryani', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005207, 400081005, 'Paneer Tikka Biryani / Mushroom Biryani', 'paneer tikka biryani / mushroom biryani', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005208, 400081005, 'Cheese Biryani', 'cheese biryani', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005209, 400081005, 'Singapore Biryani', 'singapore biryani', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005210, 400081005, 'Vihar Special Biryani', 'vihar special biryani', 'BASMATI KA SWAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005211, 400081005, 'Curd Rice', 'curd rice', 'RICE / KHICHDI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005212, 400081005, 'Dal Khichdi', 'dal khichdi', 'RICE / KHICHDI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005213, 400081005, 'Palak Khichdi', 'palak khichdi', 'RICE / KHICHDI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005214, 400081005, 'Curd Rice Tadka', 'curd rice tadka', 'RICE / KHICHDI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005215, 400081005, 'Dal Khichdi Tadka', 'dal khichdi tadka', 'RICE / KHICHDI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005216, 400081005, 'Ghee Rice', 'ghee rice', 'VIHAR CHIEF SPECIAL RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005217, 400081005, 'Rani Pulao', 'rani pulao', 'VIHAR CHIEF SPECIAL RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005218, 400081005, 'Sahajani Pulao', 'sahajani pulao', 'VIHAR CHIEF SPECIAL RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005219, 400081005, 'Brown Rice', 'brown rice', 'VIHAR CHIEF SPECIAL RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005220, 400081005, 'Tomato Rice', 'tomato rice', 'VIHAR CHIEF SPECIAL RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005221, 400081005, 'Chapati', 'chapati', 'ROTI KI TOKRI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005222, 400081005, 'Naan', 'naan', 'ROTI KI TOKRI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005223, 400081005, 'Paratha', 'paratha', 'ROTI KI TOKRI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005224, 400081005, 'Garlic Naan', 'garlic naan', 'ROTI KI TOKRI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005225, 400081005, 'Methi Paratha', 'methi paratha', 'ROTI KI TOKRI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005226, 400081005, 'Aloo Paratha / Gobi Paratha', 'aloo paratha / gobi paratha', 'ROTI KI TOKRI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005227, 400081005, 'Cheese Paratha', 'cheese paratha', 'ROTI KI TOKRI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005228, 400081005, 'Stuff Paratha', 'stuff paratha', 'ROTI KI TOKRI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005229, 400081005, 'Masala Paratha / Kulcha', 'masala paratha / kulcha', 'ROTI KI TOKRI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005230, 400081005, 'Kulcha', 'kulcha', 'ROTI KI TOKRI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005231, 400081005, 'Bhatura', 'bhatura', 'ROTI KI TOKRI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005232, 400081005, 'Puri', 'puri', 'ROTI KI TOKRI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005233, 400081005, 'Paneer Paratha', 'paneer paratha', 'ROTI KI TOKRI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005234, 400081005, 'Cheese Garlic Naan', 'cheese garlic naan', 'ROTI KI TOKRI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005235, 400081005, 'Veg. Chilly (Dry/Gravy)', 'veg. chilly (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. chilly (dry/gravy)|(1, 4)'::text, 'unverified'),
    (400081005236, 400081005, 'Veg. Chilly (Dry/Gravy)', 'veg. chilly (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. chilly (dry/gravy)|(1, 4)'::text, 'unverified'),
    (400081005237, 400081005, 'Veg. Chilly (Dry/Gravy)', 'veg. chilly (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. chilly (dry/gravy)|(1, 4)'::text, 'unverified'),
    (400081005238, 400081005, 'Veg. Chilly (Dry/Gravy)', 'veg. chilly (dry/gravy)', 'CHINESE STARTER', NULL::text, NULL::text, 'sp:veg. chilly (dry/gravy)|(1, 4)'::text, 'needs_review'),
    (400081005239, 400081005, 'Veg. 65 (Dry/Gravy)', 'veg. 65 (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. 65 (dry/gravy)|(1, 4)'::text, 'unverified'),
    (400081005240, 400081005, 'Veg. 65 (Dry/Gravy)', 'veg. 65 (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. 65 (dry/gravy)|(1, 4)'::text, 'unverified'),
    (400081005241, 400081005, 'Veg. 65 (Dry/Gravy)', 'veg. 65 (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. 65 (dry/gravy)|(1, 4)'::text, 'unverified'),
    (400081005242, 400081005, 'Veg. 65 (Dry/Gravy)', 'veg. 65 (dry/gravy)', 'CHINESE STARTER', NULL::text, NULL::text, 'sp:veg. 65 (dry/gravy)|(1, 4)'::text, 'needs_review'),
    (400081005243, 400081005, 'Veg. Manchurian (Dry/Gravy)', 'veg. manchurian (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. manchurian (dry/gravy)|(1, 4)'::text, 'unverified'),
    (400081005244, 400081005, 'Veg. Manchurian (Dry/Gravy)', 'veg. manchurian (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. manchurian (dry/gravy)|(1, 4)'::text, 'unverified'),
    (400081005245, 400081005, 'Veg. Manchurian (Dry/Gravy)', 'veg. manchurian (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. manchurian (dry/gravy)|(1, 4)'::text, 'unverified'),
    (400081005246, 400081005, 'Veg. Manchurian (Dry/Gravy)', 'veg. manchurian (dry/gravy)', 'CHINESE STARTER', NULL::text, NULL::text, 'sp:veg. manchurian (dry/gravy)|(1, 4)'::text, 'needs_review'),
    (400081005247, 400081005, 'Veg. Crispy (Dry/Gravy)', 'veg. crispy (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. crispy (dry/gravy)|(1, 4)'::text, 'unverified'),
    (400081005248, 400081005, 'Veg. Crispy (Dry/Gravy)', 'veg. crispy (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. crispy (dry/gravy)|(1, 4)'::text, 'needs_review'),
    (400081005249, 400081005, 'Veg. Crispy (Dry/Gravy)', 'veg. crispy (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. crispy (dry/gravy)|(1, 4)'::text, 'unverified'),
    (400081005250, 400081005, 'Veg. Crispy (Dry/Gravy)', 'veg. crispy (dry/gravy)', 'CHINESE STARTER', NULL::text, NULL::text, 'sp:veg. crispy (dry/gravy)|(1, 4)'::text, 'needs_review'),
    (400081005251, 400081005, 'Veg. Dragon', 'veg. dragon', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. dragon|(1, 4)'::text, 'unverified'),
    (400081005252, 400081005, 'Veg. Dragon', 'veg. dragon', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. dragon|(1, 4)'::text, 'needs_review'),
    (400081005253, 400081005, 'Veg. Dragon', 'veg. dragon', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. dragon|(1, 4)'::text, 'unverified'),
    (400081005254, 400081005, 'Veg. Dragon', 'veg. dragon', 'CHINESE STARTER', NULL::text, NULL::text, 'sp:veg. dragon|(1, 4)'::text, 'needs_review'),
    (400081005255, 400081005, 'Veg. Burnt Garlic', 'veg. burnt garlic', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. burnt garlic|(1, 4)'::text, 'unverified'),
    (400081005256, 400081005, 'Veg. Burnt Garlic', 'veg. burnt garlic', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. burnt garlic|(1, 4)'::text, 'needs_review'),
    (400081005257, 400081005, 'Veg. Burnt Garlic', 'veg. burnt garlic', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:veg. burnt garlic|(1, 4)'::text, 'unverified'),
    (400081005258, 400081005, 'Veg. Burnt Garlic', 'veg. burnt garlic', 'CHINESE STARTER', NULL::text, NULL::text, 'sp:veg. burnt garlic|(1, 4)'::text, 'needs_review'),
    (400081005259, 400081005, 'Gobi Manchurian (Dry/Gravy)', 'gobi manchurian (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:gobi manchurian (dry/gravy)|(1, 4)'::text, 'unverified'),
    (400081005260, 400081005, 'Gobi Manchurian (Dry/Gravy)', 'gobi manchurian (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:gobi manchurian (dry/gravy)|(1, 4)'::text, 'unverified'),
    (400081005261, 400081005, 'Gobi Manchurian (Dry/Gravy)', 'gobi manchurian (dry/gravy)', 'CHINESE STARTER', 'veg'::text, NULL::text, 'sp:gobi manchurian (dry/gravy)|(1, 4)'::text, 'unverified'),
    (400081005262, 400081005, 'Gobi Manchurian (Dry/Gravy)', 'gobi manchurian (dry/gravy)', 'CHINESE STARTER', NULL::text, NULL::text, 'sp:gobi manchurian (dry/gravy)|(1, 4)'::text, 'needs_review'),
    (400081005263, 400081005, 'Chinese Bhel', 'chinese bhel', 'CHINESE STARTER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005264, 400081005, 'Soyabin Chilly', 'soyabin chilly', 'CHINESE STARTER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005265, 400081005, 'Veg. Fried Rice / Noodles', 'veg. fried rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. fried rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005266, 400081005, 'Veg. Fried Rice / Noodles', 'veg. fried rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. fried rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005267, 400081005, 'Veg. Fried Rice / Noodles', 'veg. fried rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. fried rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005268, 400081005, 'Veg. Schezwan Rice / Noodles', 'veg. schezwan rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. schezwan rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005269, 400081005, 'Veg. Schezwan Rice / Noodles', 'veg. schezwan rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. schezwan rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005270, 400081005, 'Veg. Schezwan Rice / Noodles', 'veg. schezwan rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. schezwan rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005271, 400081005, 'Veg. Triple Rice / Noodles', 'veg. triple rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. triple rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005272, 400081005, 'Veg. Triple Rice / Noodles', 'veg. triple rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. triple rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005273, 400081005, 'Veg. Triple Rice / Noodles', 'veg. triple rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. triple rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005274, 400081005, 'Veg. Manchurian Rice / Noodles', 'veg. manchurian rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. manchurian rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005275, 400081005, 'Veg. Manchurian Rice / Noodles', 'veg. manchurian rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. manchurian rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005276, 400081005, 'Veg. Manchurian Rice / Noodles', 'veg. manchurian rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. manchurian rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005277, 400081005, 'Veg. Hong Kong Rice / Noodles', 'veg. hong kong rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. hong kong rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005278, 400081005, 'Veg. Hong Kong Rice / Noodles', 'veg. hong kong rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. hong kong rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005279, 400081005, 'Veg. Hong Kong Rice / Noodles', 'veg. hong kong rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. hong kong rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005280, 400081005, 'Veg. Singapore Rice / Noodles', 'veg. singapore rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. singapore rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005281, 400081005, 'Veg. Singapore Rice / Noodles', 'veg. singapore rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. singapore rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005282, 400081005, 'Veg. Singapore Rice / Noodles', 'veg. singapore rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. singapore rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005283, 400081005, 'Veg. American Choppsy', 'veg. american choppsy', 'RICE / NOODLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005284, 400081005, 'Veg. Burnt Garlic Rice / Noodles', 'veg. burnt garlic rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. burnt garlic rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005285, 400081005, 'Veg. Burnt Garlic Rice / Noodles', 'veg. burnt garlic rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. burnt garlic rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005286, 400081005, 'Veg. Burnt Garlic Rice / Noodles', 'veg. burnt garlic rice / noodles', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. burnt garlic rice / noodles|(1, 5)'::text, 'unverified'),
    (400081005287, 400081005, 'Veg. Pot Rice', 'veg. pot rice', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. pot rice|(1, 5)'::text, 'unverified'),
    (400081005288, 400081005, 'Veg. Pot Rice', 'veg. pot rice', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. pot rice|(1, 5)'::text, 'unverified'),
    (400081005289, 400081005, 'Veg. Pot Rice', 'veg. pot rice', 'RICE / NOODLE', 'veg'::text, NULL::text, 'sp:veg. pot rice|(1, 5)'::text, 'unverified'),
    (400081005290, 400081005, 'Veg. Pizza', 'veg. pizza', 'PIZZA / BURGER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005291, 400081005, 'Paneer Mushroom Baby Corn Pizza', 'paneer mushroom baby corn pizza', 'PIZZA / BURGER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005292, 400081005, 'Jain Pizza', 'jain pizza', 'PIZZA / BURGER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005293, 400081005, 'Paneer Cheese Pizza', 'paneer cheese pizza', 'PIZZA / BURGER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005294, 400081005, 'Onion Capsicum Pizza', 'onion capsicum pizza', 'PIZZA / BURGER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005295, 400081005, 'Capsicum Pizza', 'capsicum pizza', 'PIZZA / BURGER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005296, 400081005, 'Mushroom Cheese Pizza', 'mushroom cheese pizza', 'PIZZA / BURGER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005297, 400081005, 'Baby Corn Pizza', 'baby corn pizza', 'PIZZA / BURGER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005298, 400081005, 'Chilly Cheese Pizza', 'chilly cheese pizza', 'PIZZA / BURGER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005299, 400081005, 'Pineapple Pizza', 'pineapple pizza', 'PIZZA / BURGER', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005300, 400081005, 'Fruit Salad', 'fruit salad', 'FRUIT SALAD / JELLY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005301, 400081005, 'Fruit Salad with Ice-Cream', 'fruit salad with ice-cream', 'FRUIT SALAD / JELLY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005302, 400081005, 'Jelly', 'jelly', 'FRUIT SALAD / JELLY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005303, 400081005, 'Jelly with Ice-Cream', 'jelly with ice-cream', 'FRUIT SALAD / JELLY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005304, 400081005, 'Fruit Salad Jelly with Ice-Cream', 'fruit salad jelly with ice-cream', 'FRUIT SALAD / JELLY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005305, 400081005, 'Mosambi / Orange', 'mosambi / orange', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005306, 400081005, 'Apple', 'apple', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005307, 400081005, 'Ganga Jamuna', 'ganga jamuna', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005308, 400081005, 'Pineapple', 'pineapple', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005309, 400081005, 'Cocktail', 'cocktail', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005310, 400081005, 'Mara Mari', 'mara mari', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005311, 400081005, 'Watermelon', 'watermelon', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005312, 400081005, 'Grape', 'grape', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005313, 400081005, 'Anar', 'anar', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005314, 400081005, 'Cold Coffee', 'cold coffee', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005315, 400081005, 'Cold Coffee with Ice-Cream', 'cold coffee with ice-cream', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005316, 400081005, 'Rose Milkshake', 'rose milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005317, 400081005, 'Strawberry Milkshake', 'strawberry milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005318, 400081005, 'Mango Milkshake', 'mango milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005319, 400081005, 'Oreo Milkshake', 'oreo milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005320, 400081005, 'Chiku Milkshake', 'chiku milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005321, 400081005, 'Apple Milkshake', 'apple milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005322, 400081005, 'Banana Milkshake', 'banana milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005323, 400081005, 'Chocolate Milkshake', 'chocolate milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005324, 400081005, 'Vanilla Milkshake', 'vanilla milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005325, 400081005, 'Dry Fruit Milkshake', 'dry fruit milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005326, 400081005, 'Pista Milkshake', 'pista milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005327, 400081005, 'Kesar Milkshake', 'kesar milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005328, 400081005, 'Mojito', 'mojito', 'MOCKTAILS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005329, 400081005, 'Orange Crush', 'orange crush', 'MOCKTAILS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005330, 400081005, 'Kiwi Punch', 'kiwi punch', 'MOCKTAILS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005331, 400081005, 'Blue Berry Punch', 'blue berry punch', 'MOCKTAILS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005332, 400081005, 'Blue Lagoon', 'blue lagoon', 'MOCKTAILS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005333, 400081005, 'Pina Colada', 'pina colada', 'MOCKTAILS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005334, 400081005, 'Royal Falooda', 'royal falooda', 'FALOODA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005335, 400081005, 'Kesar Falooda', 'kesar falooda', 'FALOODA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005336, 400081005, 'Dry Fruit Falooda', 'dry fruit falooda', 'FALOODA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005337, 400081005, 'Pista Falooda', 'pista falooda', 'FALOODA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005338, 400081005, 'Mango Falooda', 'mango falooda', 'FALOODA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005339, 400081005, 'Sitafal Falooda', 'sitafal falooda', 'FALOODA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005340, 400081005, 'Strawberry Falooda', 'strawberry falooda', 'FALOODA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005341, 400081005, 'Single Scoop', 'single scoop', 'FALOODA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005342, 400081005, 'Tea', 'tea', 'DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005343, 400081005, 'Nescafe', 'nescafe', 'DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005344, 400081005, 'Filter Coffee', 'filter coffee', 'DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005345, 400081005, 'Hot Milk (200 ml)', 'hot milk (200 ml)', 'DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005346, 400081005, 'Sweet Lassi', 'sweet lassi', 'DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005347, 400081005, 'Mango Lassi / Pista Lassi / Kesar Lassi', 'mango lassi / pista lassi / kesar lassi', 'DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005348, 400081005, 'Lemon Juice', 'lemon juice', 'DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005349, 400081005, 'Lemon Soda', 'lemon soda', 'DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005350, 400081005, 'Kokam Sharbat', 'kokam sharbat', 'DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005351, 400081005, 'Ginger Lemon Water', 'ginger lemon water', 'DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005352, 400081005, 'Sikandar Sharbat', 'sikandar sharbat', 'DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005353, 400081005, 'Butter Milk', 'butter milk', 'DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005354, 400081005, 'Gulab Jamun (2 psc)', 'gulab jamun (2 psc)', 'DESSERT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005355, 400081005, 'Special Sunday', 'special sunday', 'DESSERT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005356, 400081005, 'Carmel Custard', 'carmel custard', 'DESSERT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005357, 400081005, 'Single Scoop', 'single scoop', 'DESSERT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081005358, 400081005, 'Double Scoop', 'double scoop', 'DESSERT', 'veg'::text, NULL::text, NULL::text, 'unverified')
) AS x(menu_item_id, restaurant_id, name, normalized_name, raw_category_text, food_classification_code, protein_code, split_group_key, verification_status_code)
JOIN canonical_dish cd ON cd.normalized_name = x.normalized_name
LEFT JOIN protein_type pt ON pt.code = x.protein_code;

-- Menu item source: name/existence confidence, kept separate from price confidence.
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
VALUES
    (400081005001, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005002, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005003, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005004, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005005, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005006, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005007, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005008, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005009, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005010, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005011, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005012, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005013, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005014, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005015, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005016, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005017, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005018, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005019, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005020, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005021, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005022, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005023, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005024, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005025, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005026, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005027, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005028, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005029, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005030, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005031, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005032, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005033, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005034, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005035, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005036, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005037, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005038, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005039, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005040, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005041, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005042, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005043, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005044, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005045, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005046, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005047, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005048, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005049, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005050, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005051, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005052, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005053, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005054, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005055, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005056, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005057, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005058, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005059, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005060, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005061, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005062, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005063, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005064, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005065, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005066, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005067, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005068, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005069, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005070, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005071, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005072, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005073, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005074, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005075, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005076, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005077, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005078, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005079, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005080, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005081, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005082, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005083, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005084, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005085, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005086, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005087, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005088, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005089, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005090, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005091, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005092, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005093, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005094, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005095, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005096, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005097, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005098, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005099, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005100, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005101, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005102, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005103, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005104, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005105, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005106, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005107, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005108, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005109, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005110, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005111, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005112, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005113, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005114, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005115, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005116, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005117, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005118, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005119, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005120, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005121, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005122, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005123, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005124, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005125, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005126, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005127, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005128, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005129, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005130, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005131, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005132, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005133, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005134, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005135, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005136, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005137, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005138, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005139, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005140, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005141, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005142, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005143, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005144, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005145, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005146, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005147, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005148, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005149, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005150, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005151, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005152, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005153, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005154, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005155, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005156, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005157, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005158, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005159, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005160, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005161, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005162, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005163, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005164, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005165, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005166, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005167, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005168, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005169, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005170, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005171, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005172, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005173, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005174, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005175, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005176, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005177, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005178, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005179, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005180, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005181, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005182, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005183, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005184, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005185, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005186, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005187, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005188, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005189, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005190, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005191, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005192, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005193, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005194, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005195, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005196, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005197, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005198, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005199, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005200, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005201, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005202, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005203, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005204, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005205, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005206, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005207, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005208, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005209, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005210, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005211, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005212, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005213, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005214, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005215, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005216, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005217, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005218, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005219, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005220, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005221, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005222, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005223, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005224, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005225, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005226, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005227, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005228, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005229, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005230, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005231, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005232, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005233, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005234, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005235, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005236, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005237, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005238, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005239, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005240, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005241, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005242, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005243, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005244, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005245, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005246, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005247, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005248, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005249, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005250, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005251, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005252, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005253, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005254, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005255, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005256, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005257, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005258, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005259, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005260, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005261, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005262, 400081005, :extraction_batch_id, 0.9, 'needs_review'),
    (400081005263, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005264, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005265, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005266, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005267, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005268, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005269, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005270, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005271, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005272, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005273, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005274, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005275, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005276, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005277, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005278, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005279, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005280, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005281, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005282, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005283, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005284, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005285, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005286, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005287, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005288, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005289, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005290, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005291, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005292, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005293, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005294, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005295, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005296, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005297, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005298, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005299, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005300, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005301, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005302, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005303, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005304, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005305, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005306, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005307, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005308, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005309, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005310, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005311, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005312, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005313, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005314, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005315, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005316, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005317, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005318, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005319, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005320, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005321, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005322, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005323, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005324, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005325, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005326, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005327, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005328, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005329, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005330, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005331, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005332, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005333, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005334, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005335, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005336, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005337, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005338, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005339, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005340, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005341, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005342, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005343, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005344, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005345, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005346, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005347, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005348, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005349, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005350, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005351, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005352, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005353, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005354, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005355, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005356, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005357, 400081005, :extraction_batch_id, 0.9, 'unverified'),
    (400081005358, 400081005, :extraction_batch_id, 0.9, 'unverified');

-- Variants (portion/label variants -- one menu_item, multiple menu_item_variant rows;
-- a protein/veg split already became two separate menu_item rows above, so each carries
-- exactly one variant here).
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
VALUES
    (400081005001, 400081005001, 'Regular', 'fixed', TRUE),
    (400081005002, 400081005002, 'Regular', 'fixed', TRUE),
    (400081005003, 400081005003, 'Regular', 'fixed', TRUE),
    (400081005004, 400081005004, 'Regular', 'fixed', TRUE),
    (400081005005, 400081005005, 'Regular', 'fixed', TRUE),
    (400081005006, 400081005006, 'Regular', 'fixed', TRUE),
    (400081005007, 400081005007, 'Regular', 'fixed', TRUE),
    (400081005008, 400081005008, 'Regular', 'fixed', TRUE),
    (400081005009, 400081005009, 'Regular', 'fixed', TRUE),
    (400081005010, 400081005010, 'Regular', 'fixed', TRUE),
    (400081005011, 400081005011, 'Regular', 'fixed', TRUE),
    (400081005012, 400081005012, 'Regular', 'fixed', TRUE),
    (400081005013, 400081005013, 'Regular', 'fixed', TRUE),
    (400081005014, 400081005014, 'Regular', 'fixed', TRUE),
    (400081005015, 400081005015, 'Regular', 'fixed', TRUE),
    (400081005016, 400081005016, 'Regular', 'fixed', TRUE),
    (400081005017, 400081005017, 'Regular', 'fixed', TRUE),
    (400081005018, 400081005018, 'Regular', 'fixed', TRUE),
    (400081005019, 400081005019, 'Regular', 'fixed', TRUE),
    (400081005020, 400081005020, 'Regular', 'fixed', TRUE),
    (400081005021, 400081005021, 'Regular', 'fixed', TRUE),
    (400081005022, 400081005022, 'Regular', 'fixed', TRUE),
    (400081005023, 400081005023, 'Regular', 'fixed', TRUE),
    (400081005024, 400081005024, 'Regular', 'fixed', TRUE),
    (400081005025, 400081005025, 'Regular', 'fixed', TRUE),
    (400081005026, 400081005026, 'Regular', 'fixed', TRUE),
    (400081005027, 400081005027, 'Regular', 'fixed', TRUE),
    (400081005028, 400081005028, 'Regular', 'fixed', TRUE),
    (400081005029, 400081005029, 'Regular', 'fixed', TRUE),
    (400081005030, 400081005030, 'Regular', 'fixed', TRUE),
    (400081005031, 400081005031, 'Regular', 'fixed', TRUE),
    (400081005032, 400081005032, 'Regular', 'fixed', TRUE),
    (400081005033, 400081005033, 'Regular', 'fixed', TRUE),
    (400081005034, 400081005034, 'Regular', 'fixed', TRUE),
    (400081005035, 400081005035, 'Regular', 'fixed', TRUE),
    (400081005036, 400081005036, 'Regular', 'fixed', TRUE),
    (400081005037, 400081005037, 'Regular', 'fixed', TRUE),
    (400081005038, 400081005038, 'Regular', 'fixed', TRUE),
    (400081005039, 400081005039, 'Regular', 'fixed', TRUE),
    (400081005040, 400081005040, 'Regular', 'fixed', TRUE),
    (400081005041, 400081005041, 'Regular', 'fixed', TRUE),
    (400081005042, 400081005042, 'Regular', 'fixed', TRUE),
    (400081005043, 400081005043, 'Regular', 'fixed', TRUE),
    (400081005044, 400081005044, 'Regular', 'fixed', TRUE),
    (400081005045, 400081005045, 'Regular', 'fixed', TRUE),
    (400081005046, 400081005046, 'Regular', 'fixed', TRUE),
    (400081005047, 400081005047, 'Regular', 'fixed', TRUE),
    (400081005048, 400081005048, 'Regular', 'fixed', TRUE),
    (400081005049, 400081005049, 'Regular', 'fixed', TRUE),
    (400081005050, 400081005050, 'Regular', 'fixed', TRUE),
    (400081005051, 400081005051, 'Regular', 'fixed', TRUE),
    (400081005052, 400081005052, 'Regular', 'fixed', TRUE),
    (400081005053, 400081005053, 'Regular', 'fixed', TRUE),
    (400081005054, 400081005054, 'Regular', 'fixed', TRUE),
    (400081005055, 400081005055, 'Regular', 'fixed', TRUE),
    (400081005056, 400081005056, 'Regular', 'fixed', TRUE),
    (400081005057, 400081005057, 'Regular', 'fixed', TRUE),
    (400081005058, 400081005058, 'Regular', 'fixed', TRUE),
    (400081005059, 400081005059, 'Regular', 'fixed', TRUE),
    (400081005060, 400081005060, 'Regular', 'fixed', TRUE),
    (400081005061, 400081005061, 'Regular', 'fixed', TRUE),
    (400081005062, 400081005062, 'Regular', 'fixed', TRUE),
    (400081005063, 400081005063, 'Regular', 'fixed', TRUE),
    (400081005064, 400081005064, 'Regular', 'fixed', TRUE),
    (400081005065, 400081005065, 'Regular', 'fixed', TRUE),
    (400081005066, 400081005066, 'Regular', 'fixed', TRUE),
    (400081005067, 400081005067, 'Regular', 'fixed', TRUE),
    (400081005068, 400081005068, 'Regular', 'fixed', TRUE),
    (400081005069, 400081005069, 'Regular', 'fixed', TRUE),
    (400081005070, 400081005070, 'Regular', 'fixed', TRUE),
    (400081005071, 400081005071, 'Regular', 'fixed', TRUE),
    (400081005072, 400081005072, 'Regular', 'fixed', TRUE),
    (400081005073, 400081005073, 'Regular', 'fixed', TRUE),
    (400081005074, 400081005074, 'Regular', 'fixed', TRUE),
    (400081005075, 400081005075, 'Regular', 'fixed', TRUE),
    (400081005076, 400081005076, 'Regular', 'fixed', TRUE),
    (400081005077, 400081005077, 'Regular', 'fixed', TRUE),
    (400081005078, 400081005078, 'Regular', 'fixed', TRUE),
    (400081005079, 400081005079, 'Regular', 'fixed', TRUE),
    (400081005080, 400081005080, 'Regular', 'fixed', TRUE),
    (400081005081, 400081005081, 'Regular', 'fixed', TRUE),
    (400081005082, 400081005082, 'Regular', 'fixed', TRUE),
    (400081005083, 400081005083, 'Regular', 'fixed', TRUE),
    (400081005084, 400081005084, 'Regular', 'fixed', TRUE),
    (400081005085, 400081005085, 'Regular', 'fixed', TRUE),
    (400081005086, 400081005086, 'Regular', 'fixed', TRUE),
    (400081005087, 400081005087, 'Regular', 'fixed', TRUE),
    (400081005088, 400081005088, 'Regular', 'fixed', TRUE),
    (400081005089, 400081005089, 'Regular', 'fixed', TRUE),
    (400081005090, 400081005090, 'Regular', 'fixed', TRUE),
    (400081005091, 400081005091, 'Regular', 'fixed', TRUE),
    (400081005092, 400081005092, 'Regular', 'fixed', TRUE),
    (400081005093, 400081005093, 'Regular', 'fixed', TRUE),
    (400081005094, 400081005094, 'Regular', 'fixed', TRUE),
    (400081005095, 400081005095, 'Regular', 'fixed', TRUE),
    (400081005096, 400081005096, 'Regular', 'fixed', TRUE),
    (400081005097, 400081005097, 'Regular', 'fixed', TRUE),
    (400081005098, 400081005098, 'Regular', 'fixed', TRUE),
    (400081005099, 400081005099, 'Regular', 'fixed', TRUE),
    (400081005100, 400081005100, 'Regular', 'fixed', TRUE),
    (400081005101, 400081005101, 'Regular', 'fixed', TRUE),
    (400081005102, 400081005102, 'Regular', 'fixed', TRUE),
    (400081005103, 400081005103, 'Regular', 'fixed', TRUE),
    (400081005104, 400081005104, 'Full', 'fixed', TRUE),
    (400081005105, 400081005104, 'Half', 'fixed', FALSE),
    (400081005106, 400081005105, 'Regular', 'fixed', TRUE),
    (400081005107, 400081005106, 'Regular', 'fixed', TRUE),
    (400081005108, 400081005107, 'Regular', 'fixed', TRUE),
    (400081005109, 400081005108, 'Regular', 'fixed', TRUE),
    (400081005110, 400081005109, 'Regular', 'fixed', TRUE),
    (400081005111, 400081005110, 'Regular', 'fixed', TRUE),
    (400081005112, 400081005111, 'Regular', 'fixed', TRUE),
    (400081005113, 400081005112, 'Regular', 'fixed', TRUE),
    (400081005114, 400081005113, 'Regular', 'fixed', TRUE),
    (400081005115, 400081005114, 'Regular', 'fixed', TRUE),
    (400081005116, 400081005115, 'Regular', 'fixed', TRUE),
    (400081005117, 400081005116, 'Regular', 'fixed', TRUE),
    (400081005118, 400081005117, 'Regular', 'fixed', TRUE),
    (400081005119, 400081005118, 'Regular', 'fixed', TRUE),
    (400081005120, 400081005119, 'Regular', 'fixed', TRUE),
    (400081005121, 400081005120, 'Regular', 'fixed', TRUE),
    (400081005122, 400081005121, 'Regular', 'fixed', TRUE),
    (400081005123, 400081005122, 'Regular', 'fixed', TRUE),
    (400081005124, 400081005123, 'Regular', 'fixed', TRUE),
    (400081005125, 400081005124, 'Regular', 'fixed', TRUE),
    (400081005126, 400081005125, 'Regular', 'fixed', TRUE),
    (400081005127, 400081005126, 'Regular', 'fixed', TRUE),
    (400081005128, 400081005127, 'Regular', 'fixed', TRUE),
    (400081005129, 400081005128, 'Regular', 'fixed', TRUE),
    (400081005130, 400081005129, 'Full', 'fixed', TRUE),
    (400081005131, 400081005129, 'Half', 'fixed', FALSE),
    (400081005132, 400081005130, 'Regular', 'fixed', TRUE),
    (400081005133, 400081005131, 'Regular', 'fixed', TRUE),
    (400081005134, 400081005132, 'Regular', 'fixed', TRUE),
    (400081005135, 400081005133, 'Regular', 'fixed', TRUE),
    (400081005136, 400081005134, 'Regular', 'fixed', TRUE),
    (400081005137, 400081005135, 'Regular', 'fixed', TRUE),
    (400081005138, 400081005136, 'Regular', 'fixed', TRUE),
    (400081005139, 400081005137, 'Regular', 'fixed', TRUE),
    (400081005140, 400081005138, 'Regular', 'fixed', TRUE),
    (400081005141, 400081005139, 'Regular', 'fixed', TRUE),
    (400081005142, 400081005140, 'Regular', 'fixed', TRUE),
    (400081005143, 400081005141, 'Regular', 'fixed', TRUE),
    (400081005144, 400081005142, 'Regular', 'fixed', TRUE),
    (400081005145, 400081005143, 'Regular', 'fixed', TRUE),
    (400081005146, 400081005144, 'Regular', 'fixed', TRUE),
    (400081005147, 400081005145, 'Regular', 'fixed', TRUE),
    (400081005148, 400081005146, 'Regular', 'fixed', TRUE),
    (400081005149, 400081005147, 'Regular', 'fixed', TRUE),
    (400081005150, 400081005148, 'Full', 'fixed', TRUE),
    (400081005151, 400081005148, 'Half', 'fixed', FALSE),
    (400081005152, 400081005149, 'Full', 'fixed', TRUE),
    (400081005153, 400081005149, 'Half', 'fixed', FALSE),
    (400081005154, 400081005150, 'Regular', 'fixed', TRUE),
    (400081005155, 400081005151, 'Regular', 'fixed', TRUE),
    (400081005156, 400081005152, 'Regular', 'fixed', TRUE),
    (400081005157, 400081005153, 'Regular', 'fixed', TRUE),
    (400081005158, 400081005154, 'Regular', 'fixed', TRUE),
    (400081005159, 400081005155, 'Regular', 'fixed', TRUE),
    (400081005160, 400081005156, 'Regular', 'fixed', TRUE),
    (400081005161, 400081005157, 'Regular', 'fixed', TRUE),
    (400081005162, 400081005158, 'Regular', 'fixed', TRUE),
    (400081005163, 400081005159, 'Regular', 'fixed', TRUE),
    (400081005164, 400081005160, 'Regular', 'fixed', TRUE),
    (400081005165, 400081005161, 'Regular', 'fixed', TRUE),
    (400081005166, 400081005162, 'Regular', 'fixed', TRUE),
    (400081005167, 400081005163, 'Regular', 'fixed', TRUE),
    (400081005168, 400081005164, 'Regular', 'fixed', TRUE),
    (400081005169, 400081005165, 'Regular', 'fixed', TRUE),
    (400081005170, 400081005166, 'Regular', 'fixed', TRUE),
    (400081005171, 400081005167, 'Regular', 'fixed', TRUE),
    (400081005172, 400081005168, 'Regular', 'fixed', TRUE),
    (400081005173, 400081005169, 'Regular', 'fixed', TRUE),
    (400081005174, 400081005170, 'Regular', 'fixed', TRUE),
    (400081005175, 400081005171, 'Regular', 'fixed', TRUE),
    (400081005176, 400081005172, 'Regular', 'fixed', TRUE),
    (400081005177, 400081005173, 'Regular', 'fixed', TRUE),
    (400081005178, 400081005174, 'Regular', 'fixed', TRUE),
    (400081005179, 400081005175, 'Regular', 'fixed', TRUE),
    (400081005180, 400081005176, 'Regular', 'fixed', TRUE),
    (400081005181, 400081005177, 'Regular', 'fixed', TRUE),
    (400081005182, 400081005178, 'Regular', 'fixed', TRUE),
    (400081005183, 400081005179, 'Regular', 'fixed', TRUE),
    (400081005184, 400081005180, 'Regular', 'fixed', TRUE),
    (400081005185, 400081005181, 'Regular', 'fixed', TRUE),
    (400081005186, 400081005182, 'Regular', 'fixed', TRUE),
    (400081005187, 400081005183, 'Regular', 'fixed', TRUE),
    (400081005188, 400081005184, 'Regular', 'fixed', TRUE),
    (400081005189, 400081005185, 'Regular', 'fixed', TRUE),
    (400081005190, 400081005186, 'Regular', 'fixed', TRUE),
    (400081005191, 400081005187, 'Regular', 'fixed', TRUE),
    (400081005192, 400081005188, 'Regular', 'fixed', TRUE),
    (400081005193, 400081005189, 'Regular', 'fixed', TRUE),
    (400081005194, 400081005190, 'Regular', 'fixed', TRUE),
    (400081005195, 400081005191, 'Regular', 'fixed', TRUE),
    (400081005196, 400081005192, 'Regular', 'fixed', TRUE),
    (400081005197, 400081005193, 'Regular', 'fixed', TRUE),
    (400081005198, 400081005194, 'Regular', 'fixed', TRUE),
    (400081005199, 400081005195, 'Full', 'fixed', TRUE),
    (400081005200, 400081005195, 'Half', 'fixed', FALSE),
    (400081005201, 400081005196, 'Regular', 'fixed', TRUE),
    (400081005202, 400081005197, 'Regular', 'fixed', TRUE),
    (400081005203, 400081005198, 'Regular', 'fixed', TRUE),
    (400081005204, 400081005199, 'Regular', 'fixed', TRUE),
    (400081005205, 400081005200, 'Regular', 'fixed', TRUE),
    (400081005206, 400081005201, 'Regular', 'fixed', TRUE),
    (400081005207, 400081005202, 'Regular', 'fixed', TRUE),
    (400081005208, 400081005203, 'Regular', 'fixed', TRUE),
    (400081005209, 400081005204, 'Regular', 'fixed', TRUE),
    (400081005210, 400081005205, 'Regular', 'fixed', TRUE),
    (400081005211, 400081005206, 'Regular', 'fixed', TRUE),
    (400081005212, 400081005207, 'Regular', 'fixed', TRUE),
    (400081005213, 400081005208, 'Regular', 'fixed', TRUE),
    (400081005214, 400081005209, 'Regular', 'fixed', TRUE),
    (400081005215, 400081005210, 'Regular', 'fixed', TRUE),
    (400081005216, 400081005211, 'Regular', 'fixed', TRUE),
    (400081005217, 400081005212, 'Regular', 'fixed', TRUE),
    (400081005218, 400081005213, 'Regular', 'fixed', TRUE),
    (400081005219, 400081005214, 'Regular', 'fixed', TRUE),
    (400081005220, 400081005215, 'Regular', 'fixed', TRUE),
    (400081005221, 400081005216, 'Regular', 'fixed', TRUE),
    (400081005222, 400081005217, 'Regular', 'fixed', TRUE),
    (400081005223, 400081005218, 'Regular', 'fixed', TRUE),
    (400081005224, 400081005219, 'Regular', 'fixed', TRUE),
    (400081005225, 400081005220, 'Regular', 'fixed', TRUE),
    (400081005226, 400081005221, 'Plain', 'fixed', TRUE),
    (400081005227, 400081005221, 'Butter', 'fixed', FALSE),
    (400081005228, 400081005222, 'Plain', 'fixed', TRUE),
    (400081005229, 400081005222, 'Butter', 'fixed', FALSE),
    (400081005230, 400081005223, 'Plain', 'fixed', TRUE),
    (400081005231, 400081005223, 'Butter', 'fixed', FALSE),
    (400081005232, 400081005224, 'Butter', 'fixed', TRUE),
    (400081005233, 400081005225, 'Plain', 'fixed', TRUE),
    (400081005234, 400081005226, 'Plain', 'fixed', TRUE),
    (400081005235, 400081005227, 'Regular', 'fixed', TRUE),
    (400081005236, 400081005228, 'Regular', 'fixed', TRUE),
    (400081005237, 400081005229, 'Regular', 'fixed', TRUE),
    (400081005238, 400081005230, 'Plain', 'fixed', TRUE),
    (400081005239, 400081005230, 'Butter', 'fixed', FALSE),
    (400081005240, 400081005231, 'Plain', 'fixed', TRUE),
    (400081005241, 400081005232, 'Plain', 'fixed', TRUE),
    (400081005242, 400081005232, 'Butter', 'fixed', FALSE),
    (400081005243, 400081005233, 'Regular', 'fixed', TRUE),
    (400081005244, 400081005234, 'Regular', 'fixed', TRUE),
    (400081005245, 400081005235, 'Regular', 'fixed', TRUE),
    (400081005246, 400081005236, 'Regular', 'fixed', TRUE),
    (400081005247, 400081005237, 'Regular', 'fixed', TRUE),
    (400081005248, 400081005238, 'Regular', 'fixed', TRUE),
    (400081005249, 400081005239, 'Regular', 'fixed', TRUE),
    (400081005250, 400081005240, 'Regular', 'fixed', TRUE),
    (400081005251, 400081005241, 'Regular', 'fixed', TRUE),
    (400081005252, 400081005242, 'Regular', 'fixed', TRUE),
    (400081005253, 400081005243, 'Regular', 'fixed', TRUE),
    (400081005254, 400081005244, 'Regular', 'fixed', TRUE),
    (400081005255, 400081005245, 'Regular', 'fixed', TRUE),
    (400081005256, 400081005246, 'Regular', 'fixed', TRUE),
    (400081005257, 400081005247, 'Regular', 'fixed', TRUE),
    (400081005258, 400081005248, 'Regular', 'fixed', TRUE),
    (400081005259, 400081005249, 'Regular', 'fixed', TRUE),
    (400081005260, 400081005250, 'Regular', 'fixed', TRUE),
    (400081005261, 400081005251, 'Regular', 'fixed', TRUE),
    (400081005262, 400081005252, 'Regular', 'fixed', TRUE),
    (400081005263, 400081005253, 'Regular', 'fixed', TRUE),
    (400081005264, 400081005254, 'Regular', 'fixed', TRUE),
    (400081005265, 400081005255, 'Regular', 'fixed', TRUE),
    (400081005266, 400081005256, 'Regular', 'fixed', TRUE),
    (400081005267, 400081005257, 'Regular', 'fixed', TRUE),
    (400081005268, 400081005258, 'Regular', 'fixed', TRUE),
    (400081005269, 400081005259, 'Regular', 'fixed', TRUE),
    (400081005270, 400081005260, 'Regular', 'fixed', TRUE),
    (400081005271, 400081005261, 'Regular', 'fixed', TRUE),
    (400081005272, 400081005262, 'Regular', 'fixed', TRUE),
    (400081005273, 400081005263, 'Regular', 'fixed', TRUE),
    (400081005274, 400081005264, 'Regular', 'fixed', TRUE),
    (400081005275, 400081005265, 'Regular', 'fixed', TRUE),
    (400081005276, 400081005266, 'Regular', 'fixed', TRUE),
    (400081005277, 400081005267, 'Regular', 'fixed', TRUE),
    (400081005278, 400081005268, 'Regular', 'fixed', TRUE),
    (400081005279, 400081005269, 'Regular', 'fixed', TRUE),
    (400081005280, 400081005270, 'Regular', 'fixed', TRUE),
    (400081005281, 400081005271, 'Regular', 'fixed', TRUE),
    (400081005282, 400081005272, 'Regular', 'fixed', TRUE),
    (400081005283, 400081005273, 'Regular', 'fixed', TRUE),
    (400081005284, 400081005274, 'Regular', 'fixed', TRUE),
    (400081005285, 400081005275, 'Regular', 'fixed', TRUE),
    (400081005286, 400081005276, 'Regular', 'fixed', TRUE),
    (400081005287, 400081005277, 'Regular', 'fixed', TRUE),
    (400081005288, 400081005278, 'Regular', 'fixed', TRUE),
    (400081005289, 400081005279, 'Regular', 'fixed', TRUE),
    (400081005290, 400081005280, 'Regular', 'fixed', TRUE),
    (400081005291, 400081005281, 'Regular', 'fixed', TRUE),
    (400081005292, 400081005282, 'Regular', 'fixed', TRUE),
    (400081005293, 400081005283, 'Veg', 'fixed', TRUE),
    (400081005294, 400081005284, 'Regular', 'fixed', TRUE),
    (400081005295, 400081005285, 'Regular', 'fixed', TRUE),
    (400081005296, 400081005286, 'Regular', 'fixed', TRUE),
    (400081005297, 400081005287, 'Regular', 'fixed', TRUE),
    (400081005298, 400081005288, 'Regular', 'fixed', TRUE),
    (400081005299, 400081005289, 'Regular', 'fixed', TRUE),
    (400081005300, 400081005290, 'Regular', 'fixed', TRUE),
    (400081005301, 400081005291, 'Regular', 'fixed', TRUE),
    (400081005302, 400081005292, 'Regular', 'fixed', TRUE),
    (400081005303, 400081005293, 'Regular', 'fixed', TRUE),
    (400081005304, 400081005294, 'Regular', 'fixed', TRUE),
    (400081005305, 400081005295, 'Regular', 'fixed', TRUE),
    (400081005306, 400081005296, 'Regular', 'fixed', TRUE),
    (400081005307, 400081005297, 'Regular', 'fixed', TRUE),
    (400081005308, 400081005298, 'Regular', 'fixed', TRUE),
    (400081005309, 400081005299, 'Regular', 'fixed', TRUE),
    (400081005310, 400081005300, 'Regular', 'fixed', TRUE),
    (400081005311, 400081005301, 'Regular', 'fixed', TRUE),
    (400081005312, 400081005302, 'Regular', 'fixed', TRUE),
    (400081005313, 400081005303, 'Regular', 'fixed', TRUE),
    (400081005314, 400081005304, 'Regular', 'fixed', TRUE),
    (400081005315, 400081005305, 'Regular', 'fixed', TRUE),
    (400081005316, 400081005306, 'Regular', 'fixed', TRUE),
    (400081005317, 400081005307, 'Regular', 'fixed', TRUE),
    (400081005318, 400081005308, 'Regular', 'fixed', TRUE),
    (400081005319, 400081005309, 'Regular', 'fixed', TRUE),
    (400081005320, 400081005310, 'Regular', 'fixed', TRUE),
    (400081005321, 400081005311, 'Regular', 'fixed', TRUE),
    (400081005322, 400081005312, 'Regular', 'fixed', TRUE),
    (400081005323, 400081005313, 'Regular', 'fixed', TRUE),
    (400081005324, 400081005314, 'Regular', 'fixed', TRUE),
    (400081005325, 400081005315, 'Regular', 'fixed', TRUE),
    (400081005326, 400081005316, 'Regular', 'fixed', TRUE),
    (400081005327, 400081005317, 'Regular', 'fixed', TRUE),
    (400081005328, 400081005318, 'Regular', 'fixed', TRUE),
    (400081005329, 400081005319, 'Regular', 'fixed', TRUE),
    (400081005330, 400081005320, 'Regular', 'fixed', TRUE),
    (400081005331, 400081005321, 'Regular', 'fixed', TRUE),
    (400081005332, 400081005322, 'Regular', 'fixed', TRUE),
    (400081005333, 400081005323, 'Regular', 'fixed', TRUE),
    (400081005334, 400081005324, 'Regular', 'fixed', TRUE),
    (400081005335, 400081005325, 'Regular', 'fixed', TRUE),
    (400081005336, 400081005326, 'Regular', 'fixed', TRUE),
    (400081005337, 400081005327, 'Regular', 'fixed', TRUE),
    (400081005338, 400081005328, 'Regular', 'fixed', TRUE),
    (400081005339, 400081005329, 'Regular', 'fixed', TRUE),
    (400081005340, 400081005330, 'Regular', 'fixed', TRUE),
    (400081005341, 400081005331, 'Regular', 'fixed', TRUE),
    (400081005342, 400081005332, 'Regular', 'fixed', TRUE),
    (400081005343, 400081005333, 'Regular', 'fixed', TRUE),
    (400081005344, 400081005334, 'Regular', 'fixed', TRUE),
    (400081005345, 400081005335, 'Regular', 'fixed', TRUE),
    (400081005346, 400081005336, 'Regular', 'fixed', TRUE),
    (400081005347, 400081005337, 'Regular', 'fixed', TRUE),
    (400081005348, 400081005338, 'Regular', 'fixed', TRUE),
    (400081005349, 400081005339, 'Regular', 'fixed', TRUE),
    (400081005350, 400081005340, 'Regular', 'fixed', TRUE),
    (400081005351, 400081005341, 'Regular', 'fixed', TRUE),
    (400081005352, 400081005342, 'Regular', 'fixed', TRUE),
    (400081005353, 400081005343, 'Regular', 'fixed', TRUE),
    (400081005354, 400081005344, 'Regular', 'fixed', TRUE),
    (400081005355, 400081005345, 'Regular', 'fixed', TRUE),
    (400081005356, 400081005346, 'Regular', 'fixed', TRUE),
    (400081005357, 400081005347, 'Regular', 'fixed', TRUE),
    (400081005358, 400081005348, 'Regular', 'fixed', TRUE),
    (400081005359, 400081005349, 'Regular', 'fixed', TRUE),
    (400081005360, 400081005350, 'Regular', 'fixed', TRUE),
    (400081005361, 400081005351, 'Regular', 'fixed', TRUE),
    (400081005362, 400081005352, 'Regular', 'fixed', TRUE),
    (400081005363, 400081005353, 'Regular', 'fixed', TRUE),
    (400081005364, 400081005354, 'Regular', 'fixed', TRUE),
    (400081005365, 400081005355, 'Regular', 'fixed', TRUE),
    (400081005366, 400081005356, 'Regular', 'fixed', TRUE),
    (400081005367, 400081005357, 'Regular', 'fixed', TRUE),
    (400081005368, 400081005358, 'Regular', 'fixed', TRUE);

-- Prices (only for variants where a numeric price was actually captured)
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
VALUES
    (400081005001, 400081005001, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005002, 400081005002, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005003, 400081005003, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005004, 400081005004, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005005, 400081005005, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005006, 400081005006, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005007, 400081005007, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005008, 400081005008, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005009, 400081005009, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005010, 400081005010, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005011, 400081005011, 105.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005012, 400081005012, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005013, 400081005013, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005014, 400081005014, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005015, 400081005015, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005016, 400081005016, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005017, 400081005017, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005018, 400081005018, 8.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005019, 400081005019, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005020, 400081005020, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005021, 400081005021, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005022, 400081005022, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005023, 400081005023, 105.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005024, 400081005024, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005025, 400081005025, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005026, 400081005026, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005027, 400081005027, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005028, 400081005028, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005029, 400081005029, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005030, 400081005030, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005031, 400081005031, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005032, 400081005032, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005033, 400081005033, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005034, 400081005034, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005035, 400081005035, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005036, 400081005036, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005037, 400081005037, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005038, 400081005038, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005039, 400081005039, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005040, 400081005040, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005041, 400081005041, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005042, 400081005042, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005043, 400081005043, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005044, 400081005044, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005045, 400081005045, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005046, 400081005046, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005047, 400081005047, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005048, 400081005048, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005049, 400081005049, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005050, 400081005050, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005051, 400081005051, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005052, 400081005052, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005053, 400081005053, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005054, 400081005054, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005055, 400081005055, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005056, 400081005056, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005057, 400081005057, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005058, 400081005058, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005059, 400081005059, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005060, 400081005060, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005061, 400081005061, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005062, 400081005062, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005063, 400081005063, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005064, 400081005064, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005065, 400081005065, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005066, 400081005066, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005067, 400081005067, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005068, 400081005068, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005069, 400081005069, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005070, 400081005070, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005071, 400081005071, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005072, 400081005072, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005073, 400081005073, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005074, 400081005074, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005075, 400081005075, 85.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005076, 400081005076, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005077, 400081005077, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005078, 400081005078, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005079, 400081005079, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005080, 400081005080, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005081, 400081005081, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005082, 400081005082, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005083, 400081005083, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005084, 400081005084, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005085, 400081005085, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005086, 400081005086, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005087, 400081005087, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005088, 400081005088, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005089, 400081005089, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005090, 400081005090, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005091, 400081005091, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005092, 400081005092, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005093, 400081005093, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005094, 400081005094, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005095, 400081005095, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005096, 400081005096, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005097, 400081005097, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005098, 400081005098, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005099, 400081005099, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005100, 400081005100, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005101, 400081005101, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005102, 400081005102, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005103, 400081005103, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005104, 400081005104, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005105, 400081005105, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005106, 400081005106, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005107, 400081005107, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005108, 400081005108, 125.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005109, 400081005109, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005110, 400081005110, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005111, 400081005111, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005112, 400081005112, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005113, 400081005113, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005114, 400081005114, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005115, 400081005115, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005116, 400081005116, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005117, 400081005117, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005118, 400081005118, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005119, 400081005119, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005120, 400081005120, 185.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005121, 400081005121, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005122, 400081005122, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005123, 400081005123, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005124, 400081005124, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005125, 400081005125, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005126, 400081005126, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005127, 400081005127, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005128, 400081005128, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005129, 400081005129, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005130, 400081005130, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005131, 400081005131, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005132, 400081005132, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005133, 400081005133, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005134, 400081005134, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005135, 400081005135, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005136, 400081005136, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005137, 400081005137, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005138, 400081005138, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005139, 400081005139, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005140, 400081005140, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005141, 400081005141, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005142, 400081005142, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005143, 400081005143, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005144, 400081005144, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005145, 400081005145, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005146, 400081005146, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005147, 400081005147, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005148, 400081005148, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005149, 400081005149, 195.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005150, 400081005150, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005151, 400081005151, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005152, 400081005152, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005153, 400081005153, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005154, 400081005154, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005155, 400081005155, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005156, 400081005156, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005157, 400081005157, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005158, 400081005158, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005159, 400081005159, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005160, 400081005160, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005161, 400081005161, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005162, 400081005162, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005163, 400081005163, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005164, 400081005164, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005165, 400081005165, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005166, 400081005166, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005167, 400081005167, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005168, 400081005168, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005169, 400081005169, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005170, 400081005170, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005171, 400081005171, 390.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005172, 400081005172, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005173, 400081005173, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005174, 400081005174, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005175, 400081005175, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005176, 400081005176, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005177, 400081005177, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005178, 400081005178, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005179, 400081005179, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005180, 400081005180, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005181, 400081005181, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005182, 400081005182, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005183, 400081005183, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005184, 400081005184, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005185, 400081005185, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005186, 400081005186, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005187, 400081005187, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005188, 400081005188, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005189, 400081005189, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005190, 400081005190, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005191, 400081005191, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005192, 400081005192, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005193, 400081005193, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005194, 400081005194, 185.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005195, 400081005195, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005196, 400081005196, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005197, 400081005197, 195.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005198, 400081005199, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005199, 400081005200, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005200, 400081005202, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005201, 400081005203, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005202, 400081005204, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005203, 400081005205, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005204, 400081005206, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005205, 400081005207, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005206, 400081005208, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005207, 400081005209, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005208, 400081005210, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005209, 400081005211, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005210, 400081005212, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005211, 400081005213, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005212, 400081005214, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005213, 400081005215, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005214, 400081005216, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005215, 400081005217, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005216, 400081005218, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005217, 400081005219, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005218, 400081005220, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005219, 400081005221, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005220, 400081005222, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005221, 400081005223, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005222, 400081005224, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005223, 400081005225, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005224, 400081005226, 15.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005225, 400081005227, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005226, 400081005228, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005227, 400081005229, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005228, 400081005230, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005229, 400081005231, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005230, 400081005232, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005231, 400081005233, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005232, 400081005234, 115.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005233, 400081005235, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005234, 400081005236, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005235, 400081005237, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005236, 400081005238, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005237, 400081005239, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005238, 400081005240, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005239, 400081005241, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005240, 400081005242, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005241, 400081005243, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005242, 400081005244, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005243, 400081005245, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005244, 400081005246, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005245, 400081005247, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005246, 400081005248, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005247, 400081005249, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005248, 400081005250, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005249, 400081005251, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005250, 400081005252, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005251, 400081005253, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005252, 400081005254, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005253, 400081005255, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005254, 400081005256, 265.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005255, 400081005257, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005256, 400081005259, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005257, 400081005260, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005258, 400081005261, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005259, 400081005263, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005260, 400081005265, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005261, 400081005267, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005262, 400081005268, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005263, 400081005269, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005264, 400081005270, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005265, 400081005271, 275.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005266, 400081005272, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'needs_review'),
    (400081005267, 400081005273, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005268, 400081005274, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005269, 400081005275, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005270, 400081005276, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005271, 400081005277, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005272, 400081005278, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005273, 400081005279, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005274, 400081005280, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005275, 400081005281, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005276, 400081005282, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005277, 400081005283, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005278, 400081005284, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005279, 400081005285, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005280, 400081005286, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005281, 400081005287, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005282, 400081005288, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005283, 400081005289, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005284, 400081005290, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005285, 400081005291, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005286, 400081005292, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005287, 400081005293, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005288, 400081005294, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005289, 400081005295, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005290, 400081005296, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005291, 400081005297, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005292, 400081005298, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005293, 400081005299, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005294, 400081005300, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005295, 400081005301, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005296, 400081005302, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005297, 400081005303, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005298, 400081005304, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005299, 400081005305, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005300, 400081005306, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005301, 400081005307, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005302, 400081005308, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005303, 400081005309, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005304, 400081005310, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005305, 400081005311, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005306, 400081005312, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005307, 400081005313, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005308, 400081005314, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005309, 400081005315, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005310, 400081005316, 125.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005311, 400081005317, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005312, 400081005318, 125.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005313, 400081005319, 125.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005314, 400081005320, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005315, 400081005321, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005316, 400081005322, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005317, 400081005323, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005318, 400081005324, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005319, 400081005325, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005320, 400081005326, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005321, 400081005327, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005322, 400081005328, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005323, 400081005329, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005324, 400081005330, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005325, 400081005331, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005326, 400081005332, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005327, 400081005333, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005328, 400081005334, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005329, 400081005335, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005330, 400081005336, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005331, 400081005337, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005332, 400081005338, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005333, 400081005339, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005334, 400081005340, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005335, 400081005341, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005336, 400081005342, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005337, 400081005343, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005338, 400081005344, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005339, 400081005345, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005340, 400081005346, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005341, 400081005347, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005342, 400081005348, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005343, 400081005349, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005344, 400081005350, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005345, 400081005351, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005346, 400081005352, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005347, 400081005353, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005348, 400081005354, 45.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005349, 400081005355, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005350, 400081005356, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005351, 400081005357, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005352, 400081005358, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005353, 400081005359, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005354, 400081005360, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005355, 400081005361, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005356, 400081005362, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005357, 400081005363, 45.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005358, 400081005364, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005359, 400081005365, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005360, 400081005366, 45.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005361, 400081005367, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified'),
    (400081005362, 400081005368, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081005, 'unverified');

-- Price source (price-specific confidence, tracked separately from item confidence)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
VALUES
    (400081005001, 400081005, :extraction_batch_id, 0.95),
    (400081005002, 400081005, :extraction_batch_id, 0.95),
    (400081005003, 400081005, :extraction_batch_id, 0.95),
    (400081005004, 400081005, :extraction_batch_id, 0.95),
    (400081005005, 400081005, :extraction_batch_id, 0.95),
    (400081005006, 400081005, :extraction_batch_id, 0.95),
    (400081005007, 400081005, :extraction_batch_id, 0.95),
    (400081005008, 400081005, :extraction_batch_id, 0.95),
    (400081005009, 400081005, :extraction_batch_id, 0.95),
    (400081005010, 400081005, :extraction_batch_id, 0.95),
    (400081005011, 400081005, :extraction_batch_id, 0.95),
    (400081005012, 400081005, :extraction_batch_id, 0.95),
    (400081005013, 400081005, :extraction_batch_id, 0.95),
    (400081005014, 400081005, :extraction_batch_id, 0.95),
    (400081005015, 400081005, :extraction_batch_id, 0.95),
    (400081005016, 400081005, :extraction_batch_id, 0.95),
    (400081005017, 400081005, :extraction_batch_id, 0.95),
    (400081005018, 400081005, :extraction_batch_id, 0.95),
    (400081005019, 400081005, :extraction_batch_id, 0.95),
    (400081005020, 400081005, :extraction_batch_id, 0.95),
    (400081005021, 400081005, :extraction_batch_id, 0.95),
    (400081005022, 400081005, :extraction_batch_id, 0.95),
    (400081005023, 400081005, :extraction_batch_id, 0.95),
    (400081005024, 400081005, :extraction_batch_id, 0.95),
    (400081005025, 400081005, :extraction_batch_id, 0.95),
    (400081005026, 400081005, :extraction_batch_id, 0.95),
    (400081005027, 400081005, :extraction_batch_id, 0.95),
    (400081005028, 400081005, :extraction_batch_id, 0.95),
    (400081005029, 400081005, :extraction_batch_id, 0.95),
    (400081005030, 400081005, :extraction_batch_id, 0.95),
    (400081005031, 400081005, :extraction_batch_id, 0.95),
    (400081005032, 400081005, :extraction_batch_id, 0.95),
    (400081005033, 400081005, :extraction_batch_id, 0.95),
    (400081005034, 400081005, :extraction_batch_id, 0.95),
    (400081005035, 400081005, :extraction_batch_id, 0.95),
    (400081005036, 400081005, :extraction_batch_id, 0.95),
    (400081005037, 400081005, :extraction_batch_id, 0.95),
    (400081005038, 400081005, :extraction_batch_id, 0.95),
    (400081005039, 400081005, :extraction_batch_id, 0.95),
    (400081005040, 400081005, :extraction_batch_id, 0.95),
    (400081005041, 400081005, :extraction_batch_id, 0.95),
    (400081005042, 400081005, :extraction_batch_id, 0.95),
    (400081005043, 400081005, :extraction_batch_id, 0.95),
    (400081005044, 400081005, :extraction_batch_id, 0.95),
    (400081005045, 400081005, :extraction_batch_id, 0.95),
    (400081005046, 400081005, :extraction_batch_id, 0.95),
    (400081005047, 400081005, :extraction_batch_id, 0.95),
    (400081005048, 400081005, :extraction_batch_id, 0.95),
    (400081005049, 400081005, :extraction_batch_id, 0.95),
    (400081005050, 400081005, :extraction_batch_id, 0.95),
    (400081005051, 400081005, :extraction_batch_id, 0.95),
    (400081005052, 400081005, :extraction_batch_id, 0.95),
    (400081005053, 400081005, :extraction_batch_id, 0.95),
    (400081005054, 400081005, :extraction_batch_id, 0.95),
    (400081005055, 400081005, :extraction_batch_id, 0.95),
    (400081005056, 400081005, :extraction_batch_id, 0.95),
    (400081005057, 400081005, :extraction_batch_id, 0.95),
    (400081005058, 400081005, :extraction_batch_id, 0.95),
    (400081005059, 400081005, :extraction_batch_id, 0.95),
    (400081005060, 400081005, :extraction_batch_id, 0.95),
    (400081005061, 400081005, :extraction_batch_id, 0.95),
    (400081005062, 400081005, :extraction_batch_id, 0.95),
    (400081005063, 400081005, :extraction_batch_id, 0.95),
    (400081005064, 400081005, :extraction_batch_id, 0.95),
    (400081005065, 400081005, :extraction_batch_id, 0.95),
    (400081005066, 400081005, :extraction_batch_id, 0.95),
    (400081005067, 400081005, :extraction_batch_id, 0.95),
    (400081005068, 400081005, :extraction_batch_id, 0.95),
    (400081005069, 400081005, :extraction_batch_id, 0.95),
    (400081005070, 400081005, :extraction_batch_id, 0.95),
    (400081005071, 400081005, :extraction_batch_id, 0.95),
    (400081005072, 400081005, :extraction_batch_id, 0.95),
    (400081005073, 400081005, :extraction_batch_id, 0.95),
    (400081005074, 400081005, :extraction_batch_id, 0.95),
    (400081005075, 400081005, :extraction_batch_id, 0.95),
    (400081005076, 400081005, :extraction_batch_id, 0.95),
    (400081005077, 400081005, :extraction_batch_id, 0.95),
    (400081005078, 400081005, :extraction_batch_id, 0.95),
    (400081005079, 400081005, :extraction_batch_id, 0.95),
    (400081005080, 400081005, :extraction_batch_id, 0.95),
    (400081005081, 400081005, :extraction_batch_id, 0.95),
    (400081005082, 400081005, :extraction_batch_id, 0.95),
    (400081005083, 400081005, :extraction_batch_id, 0.95),
    (400081005084, 400081005, :extraction_batch_id, 0.95),
    (400081005085, 400081005, :extraction_batch_id, 0.95),
    (400081005086, 400081005, :extraction_batch_id, 0.95),
    (400081005087, 400081005, :extraction_batch_id, 0.95),
    (400081005088, 400081005, :extraction_batch_id, 0.95),
    (400081005089, 400081005, :extraction_batch_id, 0.95),
    (400081005090, 400081005, :extraction_batch_id, 0.95),
    (400081005091, 400081005, :extraction_batch_id, 0.95),
    (400081005092, 400081005, :extraction_batch_id, 0.95),
    (400081005093, 400081005, :extraction_batch_id, 0.95),
    (400081005094, 400081005, :extraction_batch_id, 0.95),
    (400081005095, 400081005, :extraction_batch_id, 0.95),
    (400081005096, 400081005, :extraction_batch_id, 0.95),
    (400081005097, 400081005, :extraction_batch_id, 0.95),
    (400081005098, 400081005, :extraction_batch_id, 0.95),
    (400081005099, 400081005, :extraction_batch_id, 0.95),
    (400081005100, 400081005, :extraction_batch_id, 0.95),
    (400081005101, 400081005, :extraction_batch_id, 0.95),
    (400081005102, 400081005, :extraction_batch_id, 0.95),
    (400081005103, 400081005, :extraction_batch_id, 0.95),
    (400081005104, 400081005, :extraction_batch_id, 0.55),
    (400081005105, 400081005, :extraction_batch_id, 0.55),
    (400081005106, 400081005, :extraction_batch_id, 0.95),
    (400081005107, 400081005, :extraction_batch_id, 0.95),
    (400081005108, 400081005, :extraction_batch_id, 0.95),
    (400081005109, 400081005, :extraction_batch_id, 0.95),
    (400081005110, 400081005, :extraction_batch_id, 0.95),
    (400081005111, 400081005, :extraction_batch_id, 0.95),
    (400081005112, 400081005, :extraction_batch_id, 0.95),
    (400081005113, 400081005, :extraction_batch_id, 0.95),
    (400081005114, 400081005, :extraction_batch_id, 0.95),
    (400081005115, 400081005, :extraction_batch_id, 0.95),
    (400081005116, 400081005, :extraction_batch_id, 0.95),
    (400081005117, 400081005, :extraction_batch_id, 0.95),
    (400081005118, 400081005, :extraction_batch_id, 0.95),
    (400081005119, 400081005, :extraction_batch_id, 0.95),
    (400081005120, 400081005, :extraction_batch_id, 0.95),
    (400081005121, 400081005, :extraction_batch_id, 0.95),
    (400081005122, 400081005, :extraction_batch_id, 0.95),
    (400081005123, 400081005, :extraction_batch_id, 0.95),
    (400081005124, 400081005, :extraction_batch_id, 0.95),
    (400081005125, 400081005, :extraction_batch_id, 0.95),
    (400081005126, 400081005, :extraction_batch_id, 0.95),
    (400081005127, 400081005, :extraction_batch_id, 0.95),
    (400081005128, 400081005, :extraction_batch_id, 0.95),
    (400081005129, 400081005, :extraction_batch_id, 0.95),
    (400081005130, 400081005, :extraction_batch_id, 0.55),
    (400081005131, 400081005, :extraction_batch_id, 0.55),
    (400081005132, 400081005, :extraction_batch_id, 0.95),
    (400081005133, 400081005, :extraction_batch_id, 0.95),
    (400081005134, 400081005, :extraction_batch_id, 0.95),
    (400081005135, 400081005, :extraction_batch_id, 0.95),
    (400081005136, 400081005, :extraction_batch_id, 0.95),
    (400081005137, 400081005, :extraction_batch_id, 0.95),
    (400081005138, 400081005, :extraction_batch_id, 0.95),
    (400081005139, 400081005, :extraction_batch_id, 0.95),
    (400081005140, 400081005, :extraction_batch_id, 0.95),
    (400081005141, 400081005, :extraction_batch_id, 0.95),
    (400081005142, 400081005, :extraction_batch_id, 0.95),
    (400081005143, 400081005, :extraction_batch_id, 0.95),
    (400081005144, 400081005, :extraction_batch_id, 0.95),
    (400081005145, 400081005, :extraction_batch_id, 0.95),
    (400081005146, 400081005, :extraction_batch_id, 0.95),
    (400081005147, 400081005, :extraction_batch_id, 0.95),
    (400081005148, 400081005, :extraction_batch_id, 0.95),
    (400081005149, 400081005, :extraction_batch_id, 0.95),
    (400081005150, 400081005, :extraction_batch_id, 0.55),
    (400081005151, 400081005, :extraction_batch_id, 0.55),
    (400081005152, 400081005, :extraction_batch_id, 0.55),
    (400081005153, 400081005, :extraction_batch_id, 0.55),
    (400081005154, 400081005, :extraction_batch_id, 0.95),
    (400081005155, 400081005, :extraction_batch_id, 0.95),
    (400081005156, 400081005, :extraction_batch_id, 0.95),
    (400081005157, 400081005, :extraction_batch_id, 0.95),
    (400081005158, 400081005, :extraction_batch_id, 0.95),
    (400081005159, 400081005, :extraction_batch_id, 0.95),
    (400081005160, 400081005, :extraction_batch_id, 0.95),
    (400081005161, 400081005, :extraction_batch_id, 0.95),
    (400081005162, 400081005, :extraction_batch_id, 0.95),
    (400081005163, 400081005, :extraction_batch_id, 0.95),
    (400081005164, 400081005, :extraction_batch_id, 0.95),
    (400081005165, 400081005, :extraction_batch_id, 0.95),
    (400081005166, 400081005, :extraction_batch_id, 0.95),
    (400081005167, 400081005, :extraction_batch_id, 0.95),
    (400081005168, 400081005, :extraction_batch_id, 0.95),
    (400081005169, 400081005, :extraction_batch_id, 0.95),
    (400081005170, 400081005, :extraction_batch_id, 0.95),
    (400081005171, 400081005, :extraction_batch_id, 0.95),
    (400081005172, 400081005, :extraction_batch_id, 0.95),
    (400081005173, 400081005, :extraction_batch_id, 0.95),
    (400081005174, 400081005, :extraction_batch_id, 0.95),
    (400081005175, 400081005, :extraction_batch_id, 0.95),
    (400081005176, 400081005, :extraction_batch_id, 0.95),
    (400081005177, 400081005, :extraction_batch_id, 0.95),
    (400081005178, 400081005, :extraction_batch_id, 0.95),
    (400081005179, 400081005, :extraction_batch_id, 0.95),
    (400081005180, 400081005, :extraction_batch_id, 0.95),
    (400081005181, 400081005, :extraction_batch_id, 0.95),
    (400081005182, 400081005, :extraction_batch_id, 0.95),
    (400081005183, 400081005, :extraction_batch_id, 0.95),
    (400081005184, 400081005, :extraction_batch_id, 0.95),
    (400081005185, 400081005, :extraction_batch_id, 0.95),
    (400081005186, 400081005, :extraction_batch_id, 0.95),
    (400081005187, 400081005, :extraction_batch_id, 0.95),
    (400081005188, 400081005, :extraction_batch_id, 0.95),
    (400081005189, 400081005, :extraction_batch_id, 0.95),
    (400081005190, 400081005, :extraction_batch_id, 0.95),
    (400081005191, 400081005, :extraction_batch_id, 0.95),
    (400081005192, 400081005, :extraction_batch_id, 0.95),
    (400081005193, 400081005, :extraction_batch_id, 0.95),
    (400081005194, 400081005, :extraction_batch_id, 0.95),
    (400081005195, 400081005, :extraction_batch_id, 0.95),
    (400081005196, 400081005, :extraction_batch_id, 0.95),
    (400081005197, 400081005, :extraction_batch_id, 0.95),
    (400081005198, 400081005, :extraction_batch_id, 0.55),
    (400081005199, 400081005, :extraction_batch_id, 0.55),
    (400081005200, 400081005, :extraction_batch_id, 0.95),
    (400081005201, 400081005, :extraction_batch_id, 0.95),
    (400081005202, 400081005, :extraction_batch_id, 0.95),
    (400081005203, 400081005, :extraction_batch_id, 0.95),
    (400081005204, 400081005, :extraction_batch_id, 0.95),
    (400081005205, 400081005, :extraction_batch_id, 0.95),
    (400081005206, 400081005, :extraction_batch_id, 0.95),
    (400081005207, 400081005, :extraction_batch_id, 0.95),
    (400081005208, 400081005, :extraction_batch_id, 0.95),
    (400081005209, 400081005, :extraction_batch_id, 0.95),
    (400081005210, 400081005, :extraction_batch_id, 0.95),
    (400081005211, 400081005, :extraction_batch_id, 0.95),
    (400081005212, 400081005, :extraction_batch_id, 0.95),
    (400081005213, 400081005, :extraction_batch_id, 0.95),
    (400081005214, 400081005, :extraction_batch_id, 0.95),
    (400081005215, 400081005, :extraction_batch_id, 0.95),
    (400081005216, 400081005, :extraction_batch_id, 0.95),
    (400081005217, 400081005, :extraction_batch_id, 0.95),
    (400081005218, 400081005, :extraction_batch_id, 0.95),
    (400081005219, 400081005, :extraction_batch_id, 0.95),
    (400081005220, 400081005, :extraction_batch_id, 0.95),
    (400081005221, 400081005, :extraction_batch_id, 0.95),
    (400081005222, 400081005, :extraction_batch_id, 0.95),
    (400081005223, 400081005, :extraction_batch_id, 0.95),
    (400081005224, 400081005, :extraction_batch_id, 0.95),
    (400081005225, 400081005, :extraction_batch_id, 0.95),
    (400081005226, 400081005, :extraction_batch_id, 0.95),
    (400081005227, 400081005, :extraction_batch_id, 0.95),
    (400081005228, 400081005, :extraction_batch_id, 0.95),
    (400081005229, 400081005, :extraction_batch_id, 0.95),
    (400081005230, 400081005, :extraction_batch_id, 0.95),
    (400081005231, 400081005, :extraction_batch_id, 0.95),
    (400081005232, 400081005, :extraction_batch_id, 0.95),
    (400081005233, 400081005, :extraction_batch_id, 0.95),
    (400081005234, 400081005, :extraction_batch_id, 0.95),
    (400081005235, 400081005, :extraction_batch_id, 0.95),
    (400081005236, 400081005, :extraction_batch_id, 0.95),
    (400081005237, 400081005, :extraction_batch_id, 0.95),
    (400081005238, 400081005, :extraction_batch_id, 0.95),
    (400081005239, 400081005, :extraction_batch_id, 0.95),
    (400081005240, 400081005, :extraction_batch_id, 0.95),
    (400081005241, 400081005, :extraction_batch_id, 0.95),
    (400081005242, 400081005, :extraction_batch_id, 0.95),
    (400081005243, 400081005, :extraction_batch_id, 0.95),
    (400081005244, 400081005, :extraction_batch_id, 0.95),
    (400081005245, 400081005, :extraction_batch_id, 0.95),
    (400081005246, 400081005, :extraction_batch_id, 0.3),
    (400081005247, 400081005, :extraction_batch_id, 0.95),
    (400081005248, 400081005, :extraction_batch_id, 0.95),
    (400081005249, 400081005, :extraction_batch_id, 0.95),
    (400081005250, 400081005, :extraction_batch_id, 0.3),
    (400081005251, 400081005, :extraction_batch_id, 0.95),
    (400081005252, 400081005, :extraction_batch_id, 0.95),
    (400081005253, 400081005, :extraction_batch_id, 0.95),
    (400081005254, 400081005, :extraction_batch_id, 0.3),
    (400081005255, 400081005, :extraction_batch_id, 0.95),
    (400081005256, 400081005, :extraction_batch_id, 0.95),
    (400081005257, 400081005, :extraction_batch_id, 0.3),
    (400081005258, 400081005, :extraction_batch_id, 0.95),
    (400081005259, 400081005, :extraction_batch_id, 0.95),
    (400081005260, 400081005, :extraction_batch_id, 0.95),
    (400081005261, 400081005, :extraction_batch_id, 0.95),
    (400081005262, 400081005, :extraction_batch_id, 0.3),
    (400081005263, 400081005, :extraction_batch_id, 0.95),
    (400081005264, 400081005, :extraction_batch_id, 0.95),
    (400081005265, 400081005, :extraction_batch_id, 0.95),
    (400081005266, 400081005, :extraction_batch_id, 0.3),
    (400081005267, 400081005, :extraction_batch_id, 0.95),
    (400081005268, 400081005, :extraction_batch_id, 0.95),
    (400081005269, 400081005, :extraction_batch_id, 0.95),
    (400081005270, 400081005, :extraction_batch_id, 0.95),
    (400081005271, 400081005, :extraction_batch_id, 0.95),
    (400081005272, 400081005, :extraction_batch_id, 0.95),
    (400081005273, 400081005, :extraction_batch_id, 0.95),
    (400081005274, 400081005, :extraction_batch_id, 0.95),
    (400081005275, 400081005, :extraction_batch_id, 0.95),
    (400081005276, 400081005, :extraction_batch_id, 0.95),
    (400081005277, 400081005, :extraction_batch_id, 0.95),
    (400081005278, 400081005, :extraction_batch_id, 0.95),
    (400081005279, 400081005, :extraction_batch_id, 0.95),
    (400081005280, 400081005, :extraction_batch_id, 0.95),
    (400081005281, 400081005, :extraction_batch_id, 0.95),
    (400081005282, 400081005, :extraction_batch_id, 0.95),
    (400081005283, 400081005, :extraction_batch_id, 0.95),
    (400081005284, 400081005, :extraction_batch_id, 0.95),
    (400081005285, 400081005, :extraction_batch_id, 0.95),
    (400081005286, 400081005, :extraction_batch_id, 0.95),
    (400081005287, 400081005, :extraction_batch_id, 0.95),
    (400081005288, 400081005, :extraction_batch_id, 0.95),
    (400081005289, 400081005, :extraction_batch_id, 0.95),
    (400081005290, 400081005, :extraction_batch_id, 0.95),
    (400081005291, 400081005, :extraction_batch_id, 0.95),
    (400081005292, 400081005, :extraction_batch_id, 0.95),
    (400081005293, 400081005, :extraction_batch_id, 0.95),
    (400081005294, 400081005, :extraction_batch_id, 0.95),
    (400081005295, 400081005, :extraction_batch_id, 0.95),
    (400081005296, 400081005, :extraction_batch_id, 0.95),
    (400081005297, 400081005, :extraction_batch_id, 0.95),
    (400081005298, 400081005, :extraction_batch_id, 0.95),
    (400081005299, 400081005, :extraction_batch_id, 0.95),
    (400081005300, 400081005, :extraction_batch_id, 0.95),
    (400081005301, 400081005, :extraction_batch_id, 0.95),
    (400081005302, 400081005, :extraction_batch_id, 0.95),
    (400081005303, 400081005, :extraction_batch_id, 0.95),
    (400081005304, 400081005, :extraction_batch_id, 0.95),
    (400081005305, 400081005, :extraction_batch_id, 0.95),
    (400081005306, 400081005, :extraction_batch_id, 0.95),
    (400081005307, 400081005, :extraction_batch_id, 0.95),
    (400081005308, 400081005, :extraction_batch_id, 0.95),
    (400081005309, 400081005, :extraction_batch_id, 0.95),
    (400081005310, 400081005, :extraction_batch_id, 0.95),
    (400081005311, 400081005, :extraction_batch_id, 0.95),
    (400081005312, 400081005, :extraction_batch_id, 0.95),
    (400081005313, 400081005, :extraction_batch_id, 0.95),
    (400081005314, 400081005, :extraction_batch_id, 0.95),
    (400081005315, 400081005, :extraction_batch_id, 0.95),
    (400081005316, 400081005, :extraction_batch_id, 0.95),
    (400081005317, 400081005, :extraction_batch_id, 0.95),
    (400081005318, 400081005, :extraction_batch_id, 0.95),
    (400081005319, 400081005, :extraction_batch_id, 0.95),
    (400081005320, 400081005, :extraction_batch_id, 0.95),
    (400081005321, 400081005, :extraction_batch_id, 0.95),
    (400081005322, 400081005, :extraction_batch_id, 0.95),
    (400081005323, 400081005, :extraction_batch_id, 0.95),
    (400081005324, 400081005, :extraction_batch_id, 0.95),
    (400081005325, 400081005, :extraction_batch_id, 0.95),
    (400081005326, 400081005, :extraction_batch_id, 0.95),
    (400081005327, 400081005, :extraction_batch_id, 0.95),
    (400081005328, 400081005, :extraction_batch_id, 0.95),
    (400081005329, 400081005, :extraction_batch_id, 0.95),
    (400081005330, 400081005, :extraction_batch_id, 0.95),
    (400081005331, 400081005, :extraction_batch_id, 0.95),
    (400081005332, 400081005, :extraction_batch_id, 0.95),
    (400081005333, 400081005, :extraction_batch_id, 0.95),
    (400081005334, 400081005, :extraction_batch_id, 0.95),
    (400081005335, 400081005, :extraction_batch_id, 0.95),
    (400081005336, 400081005, :extraction_batch_id, 0.95),
    (400081005337, 400081005, :extraction_batch_id, 0.95),
    (400081005338, 400081005, :extraction_batch_id, 0.95),
    (400081005339, 400081005, :extraction_batch_id, 0.95),
    (400081005340, 400081005, :extraction_batch_id, 0.95),
    (400081005341, 400081005, :extraction_batch_id, 0.95),
    (400081005342, 400081005, :extraction_batch_id, 0.95),
    (400081005343, 400081005, :extraction_batch_id, 0.95),
    (400081005344, 400081005, :extraction_batch_id, 0.95),
    (400081005345, 400081005, :extraction_batch_id, 0.95),
    (400081005346, 400081005, :extraction_batch_id, 0.95),
    (400081005347, 400081005, :extraction_batch_id, 0.95),
    (400081005348, 400081005, :extraction_batch_id, 0.95),
    (400081005349, 400081005, :extraction_batch_id, 0.95),
    (400081005350, 400081005, :extraction_batch_id, 0.95),
    (400081005351, 400081005, :extraction_batch_id, 0.95),
    (400081005352, 400081005, :extraction_batch_id, 0.95),
    (400081005353, 400081005, :extraction_batch_id, 0.95),
    (400081005354, 400081005, :extraction_batch_id, 0.95),
    (400081005355, 400081005, :extraction_batch_id, 0.95),
    (400081005356, 400081005, :extraction_batch_id, 0.95),
    (400081005357, 400081005, :extraction_batch_id, 0.95),
    (400081005358, 400081005, :extraction_batch_id, 0.95),
    (400081005359, 400081005, :extraction_batch_id, 0.95),
    (400081005360, 400081005, :extraction_batch_id, 0.95),
    (400081005361, 400081005, :extraction_batch_id, 0.95),
    (400081005362, 400081005, :extraction_batch_id, 0.95);

-- Board <-> item mapping
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
VALUES
    (400081005001, 400081005, 400081005001, 400081005001, 400081005001, 1),
    (400081005002, 400081005, 400081005001, 400081005002, 400081005001, 2),
    (400081005003, 400081005, 400081005001, 400081005003, 400081005001, 3),
    (400081005004, 400081005, 400081005001, 400081005004, 400081005001, 4),
    (400081005005, 400081005, 400081005001, 400081005005, 400081005001, 5),
    (400081005006, 400081005, 400081005001, 400081005006, 400081005001, 6),
    (400081005007, 400081005, 400081005001, 400081005007, 400081005001, 7),
    (400081005008, 400081005, 400081005001, 400081005008, 400081005001, 8),
    (400081005009, 400081005, 400081005001, 400081005009, 400081005001, 9),
    (400081005010, 400081005, 400081005001, 400081005010, 400081005001, 10),
    (400081005011, 400081005, 400081005001, 400081005011, 400081005001, 11),
    (400081005012, 400081005, 400081005001, 400081005012, 400081005001, 12),
    (400081005013, 400081005, 400081005001, 400081005013, 400081005001, 13),
    (400081005014, 400081005, 400081005001, 400081005014, 400081005001, 14),
    (400081005015, 400081005, 400081005001, 400081005015, 400081005001, 15),
    (400081005016, 400081005, 400081005001, 400081005016, 400081005001, 16),
    (400081005017, 400081005, 400081005001, 400081005017, 400081005001, 17),
    (400081005018, 400081005, 400081005001, 400081005018, 400081005001, 18),
    (400081005019, 400081005, 400081005001, 400081005019, 400081005001, 19),
    (400081005020, 400081005, 400081005001, 400081005020, 400081005001, 20),
    (400081005021, 400081005, 400081005001, 400081005021, 400081005001, 21),
    (400081005022, 400081005, 400081005001, 400081005022, 400081005001, 22),
    (400081005023, 400081005, 400081005001, 400081005023, 400081005002, 1),
    (400081005024, 400081005, 400081005001, 400081005024, 400081005002, 2),
    (400081005025, 400081005, 400081005001, 400081005025, 400081005002, 3),
    (400081005026, 400081005, 400081005001, 400081005026, 400081005002, 4),
    (400081005027, 400081005, 400081005001, 400081005027, 400081005002, 5),
    (400081005028, 400081005, 400081005001, 400081005028, 400081005002, 6),
    (400081005029, 400081005, 400081005001, 400081005029, 400081005002, 7),
    (400081005030, 400081005, 400081005001, 400081005030, 400081005002, 8),
    (400081005031, 400081005, 400081005001, 400081005031, 400081005002, 9),
    (400081005032, 400081005, 400081005001, 400081005032, 400081005002, 10),
    (400081005033, 400081005, 400081005001, 400081005033, 400081005002, 11),
    (400081005034, 400081005, 400081005001, 400081005034, 400081005003, 1),
    (400081005035, 400081005, 400081005001, 400081005035, 400081005003, 2),
    (400081005036, 400081005, 400081005001, 400081005036, 400081005003, 3),
    (400081005037, 400081005, 400081005001, 400081005037, 400081005003, 4),
    (400081005038, 400081005, 400081005001, 400081005038, 400081005003, 5),
    (400081005039, 400081005, 400081005001, 400081005039, 400081005003, 6),
    (400081005040, 400081005, 400081005001, 400081005040, 400081005003, 7),
    (400081005041, 400081005, 400081005001, 400081005041, 400081005003, 8),
    (400081005042, 400081005, 400081005001, 400081005042, 400081005003, 9),
    (400081005043, 400081005, 400081005001, 400081005043, 400081005003, 10),
    (400081005044, 400081005, 400081005001, 400081005044, 400081005003, 11),
    (400081005045, 400081005, 400081005001, 400081005045, 400081005003, 12),
    (400081005046, 400081005, 400081005001, 400081005046, 400081005003, 13),
    (400081005047, 400081005, 400081005001, 400081005047, 400081005003, 14),
    (400081005048, 400081005, 400081005001, 400081005048, 400081005003, 15),
    (400081005049, 400081005, 400081005001, 400081005049, 400081005003, 16),
    (400081005050, 400081005, 400081005001, 400081005050, 400081005003, 17),
    (400081005051, 400081005, 400081005001, 400081005051, 400081005003, 18),
    (400081005052, 400081005, 400081005001, 400081005052, 400081005003, 19),
    (400081005053, 400081005, 400081005001, 400081005053, 400081005003, 20),
    (400081005054, 400081005, 400081005001, 400081005054, 400081005003, 21),
    (400081005055, 400081005, 400081005001, 400081005055, 400081005003, 22),
    (400081005056, 400081005, 400081005001, 400081005056, 400081005003, 23),
    (400081005057, 400081005, 400081005001, 400081005057, 400081005003, 24),
    (400081005058, 400081005, 400081005001, 400081005058, 400081005003, 25),
    (400081005059, 400081005, 400081005001, 400081005059, 400081005003, 26),
    (400081005060, 400081005, 400081005001, 400081005060, 400081005003, 27),
    (400081005061, 400081005, 400081005001, 400081005061, 400081005003, 28),
    (400081005062, 400081005, 400081005001, 400081005062, 400081005004, 1),
    (400081005063, 400081005, 400081005001, 400081005063, 400081005004, 2),
    (400081005064, 400081005, 400081005001, 400081005064, 400081005004, 3),
    (400081005065, 400081005, 400081005001, 400081005065, 400081005004, 4),
    (400081005066, 400081005, 400081005001, 400081005066, 400081005004, 5),
    (400081005067, 400081005, 400081005001, 400081005067, 400081005005, 1),
    (400081005068, 400081005, 400081005001, 400081005068, 400081005005, 2),
    (400081005069, 400081005, 400081005001, 400081005069, 400081005005, 3),
    (400081005070, 400081005, 400081005001, 400081005070, 400081005005, 4),
    (400081005071, 400081005, 400081005001, 400081005071, 400081005005, 5),
    (400081005072, 400081005, 400081005001, 400081005072, 400081005005, 6),
    (400081005073, 400081005, 400081005001, 400081005073, 400081005005, 7),
    (400081005074, 400081005, 400081005001, 400081005074, 400081005005, 8),
    (400081005075, 400081005, 400081005001, 400081005075, 400081005005, 9),
    (400081005076, 400081005, 400081005001, 400081005076, 400081005005, 10),
    (400081005077, 400081005, 400081005001, 400081005077, 400081005005, 11),
    (400081005078, 400081005, 400081005001, 400081005078, 400081005005, 12),
    (400081005079, 400081005, 400081005001, 400081005079, 400081005005, 13),
    (400081005080, 400081005, 400081005001, 400081005080, 400081005005, 14),
    (400081005081, 400081005, 400081005001, 400081005081, 400081005005, 15),
    (400081005082, 400081005, 400081005001, 400081005082, 400081005005, 16),
    (400081005083, 400081005, 400081005001, 400081005083, 400081005006, 1),
    (400081005084, 400081005, 400081005001, 400081005084, 400081005006, 2),
    (400081005085, 400081005, 400081005001, 400081005085, 400081005006, 3),
    (400081005086, 400081005, 400081005001, 400081005086, 400081005006, 4),
    (400081005087, 400081005, 400081005001, 400081005087, 400081005006, 5),
    (400081005088, 400081005, 400081005001, 400081005088, 400081005006, 6),
    (400081005089, 400081005, 400081005001, 400081005089, 400081005006, 7),
    (400081005090, 400081005, 400081005001, 400081005090, 400081005007, 1),
    (400081005091, 400081005, 400081005001, 400081005091, 400081005007, 2),
    (400081005092, 400081005, 400081005001, 400081005092, 400081005007, 3),
    (400081005093, 400081005, 400081005001, 400081005093, 400081005007, 4),
    (400081005094, 400081005, 400081005001, 400081005094, 400081005008, 1),
    (400081005095, 400081005, 400081005001, 400081005095, 400081005008, 2),
    (400081005096, 400081005, 400081005001, 400081005096, 400081005008, 3),
    (400081005097, 400081005, 400081005001, 400081005097, 400081005008, 4),
    (400081005098, 400081005, 400081005001, 400081005098, 400081005008, 5),
    (400081005099, 400081005, 400081005001, 400081005099, 400081005008, 6),
    (400081005100, 400081005, 400081005001, 400081005100, 400081005009, 1),
    (400081005101, 400081005, 400081005001, 400081005101, 400081005009, 2),
    (400081005102, 400081005, 400081005001, 400081005102, 400081005009, 3),
    (400081005103, 400081005, 400081005001, 400081005103, 400081005009, 4),
    (400081005104, 400081005, 400081005001, 400081005104, 400081005009, 5),
    (400081005105, 400081005, 400081005001, 400081005105, 400081005009, 6),
    (400081005106, 400081005, 400081005001, 400081005106, 400081005009, 7),
    (400081005107, 400081005, 400081005001, 400081005107, 400081005009, 8),
    (400081005108, 400081005, 400081005001, 400081005108, 400081005009, 9),
    (400081005109, 400081005, 400081005001, 400081005109, 400081005009, 10),
    (400081005110, 400081005, 400081005001, 400081005110, 400081005010, 1),
    (400081005111, 400081005, 400081005001, 400081005111, 400081005010, 2),
    (400081005112, 400081005, 400081005001, 400081005112, 400081005010, 3),
    (400081005113, 400081005, 400081005001, 400081005113, 400081005010, 4),
    (400081005114, 400081005, 400081005001, 400081005114, 400081005010, 5),
    (400081005115, 400081005, 400081005001, 400081005115, 400081005010, 6),
    (400081005116, 400081005, 400081005001, 400081005116, 400081005010, 7),
    (400081005117, 400081005, 400081005001, 400081005117, 400081005010, 8),
    (400081005118, 400081005, 400081005001, 400081005118, 400081005010, 9),
    (400081005119, 400081005, 400081005001, 400081005119, 400081005010, 10),
    (400081005120, 400081005, 400081005001, 400081005120, 400081005011, 1),
    (400081005121, 400081005, 400081005001, 400081005121, 400081005011, 2),
    (400081005122, 400081005, 400081005001, 400081005122, 400081005011, 3),
    (400081005123, 400081005, 400081005001, 400081005123, 400081005011, 4),
    (400081005124, 400081005, 400081005001, 400081005124, 400081005011, 5),
    (400081005125, 400081005, 400081005001, 400081005125, 400081005011, 6),
    (400081005126, 400081005, 400081005001, 400081005126, 400081005011, 7),
    (400081005127, 400081005, 400081005001, 400081005127, 400081005011, 8),
    (400081005128, 400081005, 400081005001, 400081005128, 400081005011, 9),
    (400081005129, 400081005, 400081005001, 400081005129, 400081005012, 1),
    (400081005130, 400081005, 400081005001, 400081005130, 400081005012, 2),
    (400081005131, 400081005, 400081005001, 400081005131, 400081005012, 3),
    (400081005132, 400081005, 400081005001, 400081005132, 400081005012, 4),
    (400081005133, 400081005, 400081005001, 400081005133, 400081005012, 5),
    (400081005134, 400081005, 400081005001, 400081005134, 400081005012, 6),
    (400081005135, 400081005, 400081005001, 400081005135, 400081005012, 7),
    (400081005136, 400081005, 400081005001, 400081005136, 400081005012, 8),
    (400081005137, 400081005, 400081005001, 400081005137, 400081005012, 9),
    (400081005138, 400081005, 400081005001, 400081005138, 400081005012, 10),
    (400081005139, 400081005, 400081005001, 400081005139, 400081005012, 11),
    (400081005140, 400081005, 400081005001, 400081005140, 400081005012, 12),
    (400081005141, 400081005, 400081005001, 400081005141, 400081005012, 13),
    (400081005142, 400081005, 400081005001, 400081005142, 400081005012, 14),
    (400081005143, 400081005, 400081005001, 400081005143, 400081005012, 15),
    (400081005144, 400081005, 400081005001, 400081005144, 400081005013, 1),
    (400081005145, 400081005, 400081005001, 400081005145, 400081005013, 2),
    (400081005146, 400081005, 400081005001, 400081005146, 400081005013, 3),
    (400081005147, 400081005, 400081005001, 400081005147, 400081005013, 4),
    (400081005148, 400081005, 400081005001, 400081005148, 400081005013, 5),
    (400081005149, 400081005, 400081005001, 400081005149, 400081005013, 6),
    (400081005150, 400081005, 400081005001, 400081005150, 400081005013, 7),
    (400081005151, 400081005, 400081005001, 400081005151, 400081005013, 8),
    (400081005152, 400081005, 400081005001, 400081005152, 400081005013, 9),
    (400081005153, 400081005, 400081005001, 400081005153, 400081005013, 10),
    (400081005154, 400081005, 400081005001, 400081005154, 400081005013, 11),
    (400081005155, 400081005, 400081005001, 400081005155, 400081005013, 12),
    (400081005156, 400081005, 400081005001, 400081005156, 400081005013, 13),
    (400081005157, 400081005, 400081005001, 400081005157, 400081005013, 14),
    (400081005158, 400081005, 400081005001, 400081005158, 400081005013, 15),
    (400081005159, 400081005, 400081005001, 400081005159, 400081005013, 16),
    (400081005160, 400081005, 400081005001, 400081005160, 400081005013, 17),
    (400081005161, 400081005, 400081005001, 400081005161, 400081005013, 18),
    (400081005162, 400081005, 400081005001, 400081005162, 400081005013, 19),
    (400081005163, 400081005, 400081005001, 400081005163, 400081005013, 20),
    (400081005164, 400081005, 400081005001, 400081005164, 400081005013, 21),
    (400081005165, 400081005, 400081005001, 400081005165, 400081005013, 22),
    (400081005166, 400081005, 400081005001, 400081005166, 400081005013, 23),
    (400081005167, 400081005, 400081005001, 400081005167, 400081005014, 1),
    (400081005168, 400081005, 400081005001, 400081005168, 400081005014, 2),
    (400081005169, 400081005, 400081005001, 400081005169, 400081005014, 3),
    (400081005170, 400081005, 400081005001, 400081005170, 400081005014, 4),
    (400081005171, 400081005, 400081005001, 400081005171, 400081005014, 5),
    (400081005172, 400081005, 400081005001, 400081005172, 400081005014, 6),
    (400081005173, 400081005, 400081005001, 400081005173, 400081005014, 7),
    (400081005174, 400081005, 400081005001, 400081005174, 400081005014, 8),
    (400081005175, 400081005, 400081005001, 400081005175, 400081005014, 9),
    (400081005176, 400081005, 400081005001, 400081005176, 400081005014, 10),
    (400081005177, 400081005, 400081005001, 400081005177, 400081005014, 11),
    (400081005178, 400081005, 400081005001, 400081005178, 400081005014, 12),
    (400081005179, 400081005, 400081005001, 400081005179, 400081005014, 13),
    (400081005180, 400081005, 400081005001, 400081005180, 400081005014, 14),
    (400081005181, 400081005, 400081005001, 400081005181, 400081005014, 15),
    (400081005182, 400081005, 400081005001, 400081005182, 400081005014, 16),
    (400081005183, 400081005, 400081005001, 400081005183, 400081005014, 17),
    (400081005184, 400081005, 400081005001, 400081005184, 400081005014, 18),
    (400081005185, 400081005, 400081005001, 400081005185, 400081005014, 19),
    (400081005186, 400081005, 400081005001, 400081005186, 400081005014, 20),
    (400081005187, 400081005, 400081005001, 400081005187, 400081005014, 21),
    (400081005188, 400081005, 400081005001, 400081005188, 400081005014, 22),
    (400081005189, 400081005, 400081005001, 400081005189, 400081005014, 23),
    (400081005190, 400081005, 400081005001, 400081005190, 400081005015, 1),
    (400081005191, 400081005, 400081005001, 400081005191, 400081005015, 2),
    (400081005192, 400081005, 400081005001, 400081005192, 400081005015, 3),
    (400081005193, 400081005, 400081005001, 400081005193, 400081005015, 4),
    (400081005194, 400081005, 400081005001, 400081005194, 400081005015, 5),
    (400081005195, 400081005, 400081005001, 400081005195, 400081005016, 1),
    (400081005196, 400081005, 400081005001, 400081005196, 400081005016, 2),
    (400081005197, 400081005, 400081005001, 400081005197, 400081005016, 3),
    (400081005198, 400081005, 400081005001, 400081005198, 400081005016, 4),
    (400081005199, 400081005, 400081005001, 400081005199, 400081005016, 5),
    (400081005200, 400081005, 400081005001, 400081005200, 400081005016, 6),
    (400081005201, 400081005, 400081005001, 400081005201, 400081005016, 7),
    (400081005202, 400081005, 400081005001, 400081005202, 400081005016, 8),
    (400081005203, 400081005, 400081005001, 400081005203, 400081005016, 9),
    (400081005204, 400081005, 400081005001, 400081005204, 400081005016, 10),
    (400081005205, 400081005, 400081005001, 400081005205, 400081005016, 11),
    (400081005206, 400081005, 400081005001, 400081005206, 400081005016, 12),
    (400081005207, 400081005, 400081005001, 400081005207, 400081005016, 13),
    (400081005208, 400081005, 400081005001, 400081005208, 400081005016, 14),
    (400081005209, 400081005, 400081005001, 400081005209, 400081005016, 15),
    (400081005210, 400081005, 400081005001, 400081005210, 400081005016, 16),
    (400081005211, 400081005, 400081005001, 400081005211, 400081005017, 1),
    (400081005212, 400081005, 400081005001, 400081005212, 400081005017, 2),
    (400081005213, 400081005, 400081005001, 400081005213, 400081005017, 3),
    (400081005214, 400081005, 400081005001, 400081005214, 400081005017, 4),
    (400081005215, 400081005, 400081005001, 400081005215, 400081005017, 5),
    (400081005216, 400081005, 400081005001, 400081005216, 400081005018, 1),
    (400081005217, 400081005, 400081005001, 400081005217, 400081005018, 2),
    (400081005218, 400081005, 400081005001, 400081005218, 400081005018, 3),
    (400081005219, 400081005, 400081005001, 400081005219, 400081005018, 4),
    (400081005220, 400081005, 400081005001, 400081005220, 400081005018, 5),
    (400081005221, 400081005, 400081005001, 400081005221, 400081005019, 1),
    (400081005222, 400081005, 400081005001, 400081005222, 400081005019, 2),
    (400081005223, 400081005, 400081005001, 400081005223, 400081005019, 3),
    (400081005224, 400081005, 400081005001, 400081005224, 400081005019, 4),
    (400081005225, 400081005, 400081005001, 400081005225, 400081005019, 5),
    (400081005226, 400081005, 400081005001, 400081005226, 400081005019, 6),
    (400081005227, 400081005, 400081005001, 400081005227, 400081005019, 7),
    (400081005228, 400081005, 400081005001, 400081005228, 400081005019, 8),
    (400081005229, 400081005, 400081005001, 400081005229, 400081005019, 9),
    (400081005230, 400081005, 400081005001, 400081005230, 400081005019, 10),
    (400081005231, 400081005, 400081005001, 400081005231, 400081005019, 11),
    (400081005232, 400081005, 400081005001, 400081005232, 400081005019, 12),
    (400081005233, 400081005, 400081005001, 400081005233, 400081005019, 13),
    (400081005234, 400081005, 400081005001, 400081005234, 400081005019, 14),
    (400081005235, 400081005, 400081005001, 400081005235, 400081005020, 1),
    (400081005236, 400081005, 400081005001, 400081005236, 400081005020, 2),
    (400081005237, 400081005, 400081005001, 400081005237, 400081005020, 3),
    (400081005238, 400081005, 400081005001, 400081005238, 400081005020, 4),
    (400081005239, 400081005, 400081005001, 400081005239, 400081005020, 5),
    (400081005240, 400081005, 400081005001, 400081005240, 400081005020, 6),
    (400081005241, 400081005, 400081005001, 400081005241, 400081005020, 7),
    (400081005242, 400081005, 400081005001, 400081005242, 400081005020, 8),
    (400081005243, 400081005, 400081005001, 400081005243, 400081005020, 9),
    (400081005244, 400081005, 400081005001, 400081005244, 400081005020, 10),
    (400081005245, 400081005, 400081005001, 400081005245, 400081005020, 11),
    (400081005246, 400081005, 400081005001, 400081005246, 400081005020, 12),
    (400081005247, 400081005, 400081005001, 400081005247, 400081005020, 13),
    (400081005248, 400081005, 400081005001, 400081005248, 400081005020, 14),
    (400081005249, 400081005, 400081005001, 400081005249, 400081005020, 15),
    (400081005250, 400081005, 400081005001, 400081005250, 400081005020, 16),
    (400081005251, 400081005, 400081005001, 400081005251, 400081005020, 17),
    (400081005252, 400081005, 400081005001, 400081005252, 400081005020, 18),
    (400081005253, 400081005, 400081005001, 400081005253, 400081005020, 19),
    (400081005254, 400081005, 400081005001, 400081005254, 400081005020, 20),
    (400081005255, 400081005, 400081005001, 400081005255, 400081005020, 21),
    (400081005256, 400081005, 400081005001, 400081005256, 400081005020, 22),
    (400081005257, 400081005, 400081005001, 400081005257, 400081005020, 23),
    (400081005258, 400081005, 400081005001, 400081005258, 400081005020, 24),
    (400081005259, 400081005, 400081005001, 400081005259, 400081005020, 25),
    (400081005260, 400081005, 400081005001, 400081005260, 400081005020, 26),
    (400081005261, 400081005, 400081005001, 400081005261, 400081005020, 27),
    (400081005262, 400081005, 400081005001, 400081005262, 400081005020, 28),
    (400081005263, 400081005, 400081005001, 400081005263, 400081005020, 29),
    (400081005264, 400081005, 400081005001, 400081005264, 400081005020, 30),
    (400081005265, 400081005, 400081005001, 400081005265, 400081005021, 1),
    (400081005266, 400081005, 400081005001, 400081005266, 400081005021, 2),
    (400081005267, 400081005, 400081005001, 400081005267, 400081005021, 3),
    (400081005268, 400081005, 400081005001, 400081005268, 400081005021, 4),
    (400081005269, 400081005, 400081005001, 400081005269, 400081005021, 5),
    (400081005270, 400081005, 400081005001, 400081005270, 400081005021, 6),
    (400081005271, 400081005, 400081005001, 400081005271, 400081005021, 7),
    (400081005272, 400081005, 400081005001, 400081005272, 400081005021, 8),
    (400081005273, 400081005, 400081005001, 400081005273, 400081005021, 9),
    (400081005274, 400081005, 400081005001, 400081005274, 400081005021, 10),
    (400081005275, 400081005, 400081005001, 400081005275, 400081005021, 11),
    (400081005276, 400081005, 400081005001, 400081005276, 400081005021, 12),
    (400081005277, 400081005, 400081005001, 400081005277, 400081005021, 13),
    (400081005278, 400081005, 400081005001, 400081005278, 400081005021, 14),
    (400081005279, 400081005, 400081005001, 400081005279, 400081005021, 15),
    (400081005280, 400081005, 400081005001, 400081005280, 400081005021, 16),
    (400081005281, 400081005, 400081005001, 400081005281, 400081005021, 17),
    (400081005282, 400081005, 400081005001, 400081005282, 400081005021, 18),
    (400081005283, 400081005, 400081005001, 400081005283, 400081005021, 19),
    (400081005284, 400081005, 400081005001, 400081005284, 400081005021, 20),
    (400081005285, 400081005, 400081005001, 400081005285, 400081005021, 21),
    (400081005286, 400081005, 400081005001, 400081005286, 400081005021, 22),
    (400081005287, 400081005, 400081005001, 400081005287, 400081005021, 23),
    (400081005288, 400081005, 400081005001, 400081005288, 400081005021, 24),
    (400081005289, 400081005, 400081005001, 400081005289, 400081005021, 25),
    (400081005290, 400081005, 400081005001, 400081005290, 400081005022, 1),
    (400081005291, 400081005, 400081005001, 400081005291, 400081005022, 2),
    (400081005292, 400081005, 400081005001, 400081005292, 400081005022, 3),
    (400081005293, 400081005, 400081005001, 400081005293, 400081005022, 4),
    (400081005294, 400081005, 400081005001, 400081005294, 400081005022, 5),
    (400081005295, 400081005, 400081005001, 400081005295, 400081005022, 6),
    (400081005296, 400081005, 400081005001, 400081005296, 400081005022, 7),
    (400081005297, 400081005, 400081005001, 400081005297, 400081005022, 8),
    (400081005298, 400081005, 400081005001, 400081005298, 400081005022, 9),
    (400081005299, 400081005, 400081005001, 400081005299, 400081005022, 10),
    (400081005300, 400081005, 400081005001, 400081005300, 400081005023, 1),
    (400081005301, 400081005, 400081005001, 400081005301, 400081005023, 2),
    (400081005302, 400081005, 400081005001, 400081005302, 400081005023, 3),
    (400081005303, 400081005, 400081005001, 400081005303, 400081005023, 4),
    (400081005304, 400081005, 400081005001, 400081005304, 400081005023, 5),
    (400081005305, 400081005, 400081005001, 400081005305, 400081005024, 1),
    (400081005306, 400081005, 400081005001, 400081005306, 400081005024, 2),
    (400081005307, 400081005, 400081005001, 400081005307, 400081005024, 3),
    (400081005308, 400081005, 400081005001, 400081005308, 400081005024, 4),
    (400081005309, 400081005, 400081005001, 400081005309, 400081005024, 5),
    (400081005310, 400081005, 400081005001, 400081005310, 400081005024, 6),
    (400081005311, 400081005, 400081005001, 400081005311, 400081005024, 7),
    (400081005312, 400081005, 400081005001, 400081005312, 400081005024, 8),
    (400081005313, 400081005, 400081005001, 400081005313, 400081005024, 9),
    (400081005314, 400081005, 400081005001, 400081005314, 400081005025, 1),
    (400081005315, 400081005, 400081005001, 400081005315, 400081005025, 2),
    (400081005316, 400081005, 400081005001, 400081005316, 400081005025, 3),
    (400081005317, 400081005, 400081005001, 400081005317, 400081005025, 4),
    (400081005318, 400081005, 400081005001, 400081005318, 400081005025, 5),
    (400081005319, 400081005, 400081005001, 400081005319, 400081005025, 6),
    (400081005320, 400081005, 400081005001, 400081005320, 400081005025, 7),
    (400081005321, 400081005, 400081005001, 400081005321, 400081005025, 8),
    (400081005322, 400081005, 400081005001, 400081005322, 400081005025, 9),
    (400081005323, 400081005, 400081005001, 400081005323, 400081005025, 10),
    (400081005324, 400081005, 400081005001, 400081005324, 400081005025, 11),
    (400081005325, 400081005, 400081005001, 400081005325, 400081005025, 12),
    (400081005326, 400081005, 400081005001, 400081005326, 400081005025, 13),
    (400081005327, 400081005, 400081005001, 400081005327, 400081005025, 14),
    (400081005328, 400081005, 400081005001, 400081005328, 400081005026, 1),
    (400081005329, 400081005, 400081005001, 400081005329, 400081005026, 2),
    (400081005330, 400081005, 400081005001, 400081005330, 400081005026, 3),
    (400081005331, 400081005, 400081005001, 400081005331, 400081005026, 4),
    (400081005332, 400081005, 400081005001, 400081005332, 400081005026, 5),
    (400081005333, 400081005, 400081005001, 400081005333, 400081005026, 6),
    (400081005334, 400081005, 400081005001, 400081005334, 400081005027, 1),
    (400081005335, 400081005, 400081005001, 400081005335, 400081005027, 2),
    (400081005336, 400081005, 400081005001, 400081005336, 400081005027, 3),
    (400081005337, 400081005, 400081005001, 400081005337, 400081005027, 4),
    (400081005338, 400081005, 400081005001, 400081005338, 400081005027, 5),
    (400081005339, 400081005, 400081005001, 400081005339, 400081005027, 6),
    (400081005340, 400081005, 400081005001, 400081005340, 400081005027, 7),
    (400081005341, 400081005, 400081005001, 400081005341, 400081005027, 8),
    (400081005342, 400081005, 400081005001, 400081005342, 400081005028, 1),
    (400081005343, 400081005, 400081005001, 400081005343, 400081005028, 2),
    (400081005344, 400081005, 400081005001, 400081005344, 400081005028, 3),
    (400081005345, 400081005, 400081005001, 400081005345, 400081005028, 4),
    (400081005346, 400081005, 400081005001, 400081005346, 400081005028, 5),
    (400081005347, 400081005, 400081005001, 400081005347, 400081005028, 6),
    (400081005348, 400081005, 400081005001, 400081005348, 400081005028, 7),
    (400081005349, 400081005, 400081005001, 400081005349, 400081005028, 8),
    (400081005350, 400081005, 400081005001, 400081005350, 400081005028, 9),
    (400081005351, 400081005, 400081005001, 400081005351, 400081005028, 10),
    (400081005352, 400081005, 400081005001, 400081005352, 400081005028, 11),
    (400081005353, 400081005, 400081005001, 400081005353, 400081005028, 12),
    (400081005354, 400081005, 400081005001, 400081005354, 400081005029, 1),
    (400081005355, 400081005, 400081005001, 400081005355, 400081005029, 2),
    (400081005356, 400081005, 400081005001, 400081005356, 400081005029, 3),
    (400081005357, 400081005, 400081005001, 400081005357, 400081005029, 4),
    (400081005358, 400081005, 400081005001, 400081005358, 400081005029, 5);

-- === NEEDS-REVIEW ITEMS ===
-- menu_item_id 400081005032 (Tomato Omlet): restaurant is declared pure_veg, but this item's name suggests otherwise (item name contains egg keyword) -- left unset rather than trusting either signal over the other, needs manual review
-- menu_item_id 400081005077 (Toast Omlet Sandwich): restaurant is declared pure_veg, but this item's name suggests otherwise (item name contains egg keyword) -- left unset rather than trusting either signal over the other, needs manual review
-- menu_item_id 400081005104 (Mushroom Pav Bhaji / Paneer Pav Bhaji / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400081005104 (Mushroom Pav Bhaji / Paneer Pav Bhaji / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400081005124 (Paneer Seekh Kabab): restaurant is declared pure_veg, but this item's name suggests otherwise (item name contains 'mutton' keyword) -- left unset rather than trusting either signal over the other, needs manual review
-- menu_item_id 400081005125 (Veg. Seekh Kabab): restaurant is declared pure_veg, but this item's name suggests otherwise (item name contains 'mutton' keyword) -- left unset rather than trusting either signal over the other, needs manual review
-- menu_item_id 400081005129 (Paneer Masala / Paneer Butter Masala / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400081005129 (Paneer Masala / Paneer Butter Masala / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400081005135 (Paneer Bhurji / Paneer Kheema Masala): restaurant is declared pure_veg, but this item's name suggests otherwise (item name contains 'mutton' keyword) -- left unset rather than trusting either signal over the other, needs manual review
-- menu_item_id 400081005148 (Bhindi Fry / Bhendi Masala / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400081005148 (Bhindi Fry / Bhendi Masala / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400081005149 (Baigan Masala / Baigan Bharta / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400081005149 (Baigan Masala / Baigan Bharta / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400081005182 (Veg. Kheema Masala): restaurant is declared pure_veg, but this item's name suggests otherwise (item name contains 'mutton' keyword) -- left unset rather than trusting either signal over the other, needs manual review
-- menu_item_id 400081005189 (Veg. Seekh Kabab Masala): restaurant is declared pure_veg, but this item's name suggests otherwise (item name contains 'mutton' keyword) -- left unset rather than trusting either signal over the other, needs manual review
-- menu_item_id 400081005194 (Dal Palak / Regular): no price captured in source JSON (confidence 0.2)
-- menu_item_id 400081005195 (Steam Rice H/F / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400081005195 (Steam Rice H/F / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400081005196 (Jeera Rice / Jeera Rice / Regular): no price captured in source JSON (confidence 0.2)
-- menu_item_id 400081005235 (Veg. Chilly (Dry/Gravy)): ingredient split from source label 'Veg'
-- menu_item_id 400081005236 (Veg. Chilly (Dry/Gravy)): ingredient split from source label 'Pnr'
-- menu_item_id 400081005237 (Veg. Chilly (Dry/Gravy)): ingredient split from source label 'Mush'
-- menu_item_id 400081005238 (Veg. Chilly (Dry/Gravy)): blank label alongside ingredient-split labels ['Veg', 'Pnr', 'Mush', ''] -- which ingredient this price belongs to is unclear
-- menu_item_id 400081005238 (Veg. Chilly (Dry/Gravy) / Regular): blank label alongside ingredient-split labels ['Veg', 'Pnr', 'Mush', ''] -- which ingredient this price belongs to is unclear (confidence 0.3)
-- menu_item_id 400081005239 (Veg. 65 (Dry/Gravy)): ingredient split from source label 'Veg'
-- menu_item_id 400081005240 (Veg. 65 (Dry/Gravy)): ingredient split from source label 'Pnr'
-- menu_item_id 400081005241 (Veg. 65 (Dry/Gravy)): ingredient split from source label 'Mush'
-- menu_item_id 400081005242 (Veg. 65 (Dry/Gravy)): blank label alongside ingredient-split labels ['Veg', 'Pnr', 'Mush', ''] -- which ingredient this price belongs to is unclear
-- menu_item_id 400081005242 (Veg. 65 (Dry/Gravy) / Regular): blank label alongside ingredient-split labels ['Veg', 'Pnr', 'Mush', ''] -- which ingredient this price belongs to is unclear (confidence 0.3)
-- menu_item_id 400081005243 (Veg. Manchurian (Dry/Gravy)): ingredient split from source label 'Veg'
-- menu_item_id 400081005244 (Veg. Manchurian (Dry/Gravy)): ingredient split from source label 'Pnr'
-- menu_item_id 400081005245 (Veg. Manchurian (Dry/Gravy)): ingredient split from source label 'Mush'
-- menu_item_id 400081005246 (Veg. Manchurian (Dry/Gravy)): blank label alongside ingredient-split labels ['Veg', 'Pnr', 'Mush', ''] -- which ingredient this price belongs to is unclear
-- menu_item_id 400081005246 (Veg. Manchurian (Dry/Gravy) / Regular): blank label alongside ingredient-split labels ['Veg', 'Pnr', 'Mush', ''] -- which ingredient this price belongs to is unclear (confidence 0.3)
-- menu_item_id 400081005247 (Veg. Crispy (Dry/Gravy)): ingredient split from source label 'Veg'
-- menu_item_id 400081005248 (Veg. Crispy (Dry/Gravy)): non-numeric/empty price '' for 'Pnr'
-- menu_item_id 400081005248 (Veg. Crispy (Dry/Gravy) / Regular): non-numeric/empty price '' for 'Pnr' (confidence 0.2)
-- menu_item_id 400081005249 (Veg. Crispy (Dry/Gravy)): ingredient split from source label 'Mush'
-- menu_item_id 400081005250 (Veg. Crispy (Dry/Gravy)): blank label alongside ingredient-split labels ['Veg', 'Pnr', 'Mush', ''] -- which ingredient this price belongs to is unclear
-- menu_item_id 400081005250 (Veg. Crispy (Dry/Gravy) / Regular): blank label alongside ingredient-split labels ['Veg', 'Pnr', 'Mush', ''] -- which ingredient this price belongs to is unclear (confidence 0.3)
-- menu_item_id 400081005251 (Veg. Dragon): ingredient split from source label 'Veg'
-- menu_item_id 400081005252 (Veg. Dragon): non-numeric/empty price '' for 'Pnr'
-- menu_item_id 400081005252 (Veg. Dragon / Regular): non-numeric/empty price '' for 'Pnr' (confidence 0.2)
-- menu_item_id 400081005253 (Veg. Dragon): ingredient split from source label 'Mush'
-- menu_item_id 400081005254 (Veg. Dragon): blank label alongside ingredient-split labels ['Veg', 'Pnr', 'Mush', ''] -- which ingredient this price belongs to is unclear
-- menu_item_id 400081005254 (Veg. Dragon / Regular): blank label alongside ingredient-split labels ['Veg', 'Pnr', 'Mush', ''] -- which ingredient this price belongs to is unclear (confidence 0.3)
-- menu_item_id 400081005255 (Veg. Burnt Garlic): ingredient split from source label 'Veg'
-- menu_item_id 400081005256 (Veg. Burnt Garlic): non-numeric/empty price '' for 'Pnr'
-- menu_item_id 400081005256 (Veg. Burnt Garlic / Regular): non-numeric/empty price '' for 'Pnr' (confidence 0.2)
-- menu_item_id 400081005257 (Veg. Burnt Garlic): ingredient split from source label 'Mush'
-- menu_item_id 400081005258 (Veg. Burnt Garlic): blank label alongside ingredient-split labels ['Veg', 'Pnr', 'Mush', ''] -- which ingredient this price belongs to is unclear
-- menu_item_id 400081005258 (Veg. Burnt Garlic / Regular): blank label alongside ingredient-split labels ['Veg', 'Pnr', 'Mush', ''] -- which ingredient this price belongs to is unclear (confidence 0.3)
-- menu_item_id 400081005259 (Gobi Manchurian (Dry/Gravy)): ingredient split from source label 'Veg'
-- menu_item_id 400081005260 (Gobi Manchurian (Dry/Gravy)): ingredient split from source label 'Pnr'
-- menu_item_id 400081005261 (Gobi Manchurian (Dry/Gravy)): ingredient split from source label 'Mush'
-- menu_item_id 400081005262 (Gobi Manchurian (Dry/Gravy)): blank label alongside ingredient-split labels ['Veg', 'Pnr', 'Mush', ''] -- which ingredient this price belongs to is unclear
-- menu_item_id 400081005262 (Gobi Manchurian (Dry/Gravy) / Regular): blank label alongside ingredient-split labels ['Veg', 'Pnr', 'Mush', ''] -- which ingredient this price belongs to is unclear (confidence 0.3)
-- menu_item_id 400081005265 (Veg. Fried Rice / Noodles): ingredient split from source label 'Veg'
-- menu_item_id 400081005266 (Veg. Fried Rice / Noodles): ingredient split from source label 'Pnr'
-- menu_item_id 400081005267 (Veg. Fried Rice / Noodles): ingredient split from source label 'Mush'
-- menu_item_id 400081005268 (Veg. Schezwan Rice / Noodles): ingredient split from source label 'Veg'
-- menu_item_id 400081005269 (Veg. Schezwan Rice / Noodles): ingredient split from source label 'Pnr'
-- menu_item_id 400081005270 (Veg. Schezwan Rice / Noodles): ingredient split from source label 'Mush'
-- menu_item_id 400081005271 (Veg. Triple Rice / Noodles): ingredient split from source label 'Veg'
-- menu_item_id 400081005272 (Veg. Triple Rice / Noodles): ingredient split from source label 'Pnr'
-- menu_item_id 400081005273 (Veg. Triple Rice / Noodles): ingredient split from source label 'Mush'
-- menu_item_id 400081005274 (Veg. Manchurian Rice / Noodles): ingredient split from source label 'Veg'
-- menu_item_id 400081005275 (Veg. Manchurian Rice / Noodles): ingredient split from source label 'Pnr'
-- menu_item_id 400081005276 (Veg. Manchurian Rice / Noodles): ingredient split from source label 'Mush'
-- menu_item_id 400081005277 (Veg. Hong Kong Rice / Noodles): ingredient split from source label 'Veg'
-- menu_item_id 400081005278 (Veg. Hong Kong Rice / Noodles): ingredient split from source label 'Pnr'
-- menu_item_id 400081005279 (Veg. Hong Kong Rice / Noodles): ingredient split from source label 'Mush'
-- menu_item_id 400081005280 (Veg. Singapore Rice / Noodles): ingredient split from source label 'Veg'
-- menu_item_id 400081005281 (Veg. Singapore Rice / Noodles): ingredient split from source label 'Pnr'
-- menu_item_id 400081005282 (Veg. Singapore Rice / Noodles): ingredient split from source label 'Mush'
-- menu_item_id 400081005284 (Veg. Burnt Garlic Rice / Noodles): ingredient split from source label 'Veg'
-- menu_item_id 400081005285 (Veg. Burnt Garlic Rice / Noodles): ingredient split from source label 'Pnr'
-- menu_item_id 400081005286 (Veg. Burnt Garlic Rice / Noodles): ingredient split from source label 'Mush'
-- menu_item_id 400081005287 (Veg. Pot Rice): ingredient split from source label 'Veg'
-- menu_item_id 400081005288 (Veg. Pot Rice): ingredient split from source label 'Pnr'
-- menu_item_id 400081005289 (Veg. Pot Rice): ingredient split from source label 'Mush'

-- === UNMAPPED / INFORMATIONAL RESTAURANT-LEVEL NOTES ===
-- price-per-person from JSON: "₹200–400" -- no matching restaurant-level column; not inserted anywhere.
-- delivery note from JSON: "ZOMATO, SWIGGY" -- self-delivery capability/radius/minimum-order has no dedicated schema column combination that captures a distance radius; recorded here only, not inserted as structured data.
-- Delivery partners ['ZOMATO', 'SWIGGY'] looked up against delivery_provider.provider_code (uppercase, read-only); any code with no matching row inserted no restaurant_delivery_provider row for that partner -- verify the lookup table has these codes.
-- HALAL: attempted as a restaurant_tag lookup against platform_tag (tag_code='halal') above; if that tag doesn't exist yet in the live database the insert was a no-op -- verify and add the tag if it should exist.
-- 'NO BEEF' page notice: informational assurance text, not a formal dietary tag/column; not inserted anywhere.

COMMIT;