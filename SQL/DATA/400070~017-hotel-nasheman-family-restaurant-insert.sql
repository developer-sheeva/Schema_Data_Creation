-- Khaustan menu onboarding: HOTEL NASHEMAN FAMILY RESTAURANT
-- Source JSON: Hotel-Nasheman-OCR.json
-- Source image(s): 1000468423.jpg, 1000468424.jpg
-- establishment_id / restaurant_id / source_id namespace: 400070017 (taken directly from the source JSON)
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
    400070017, 'HOTEL NASHEMAN FAMILY RESTAURANT', 'hotel nasheman family restaurant',
    '479', NULL, 'Kurla', 'Mumbai',
    'Maharashtra', 'IN', '400070', 19.068032837723436, 72.87872150614076
);

INSERT INTO restaurant (
    restaurant_id, establishment_id, display_name, normalized_name,
    veg_nonveg_status, has_bar, bar_license_type
) VALUES (
    400070017, 400070017, 'HOTEL NASHEMAN FAMILY RESTAURANT', 'hotel nasheman family restaurant',
    'veg_and_nonveg', FALSE, 'none'
);

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400070017, 'ai_menu_extraction', 'Hotel-Nasheman-OCR.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, status_code)
VALUES (nextval('khaustan_standalone_id_seq'), 400070017, 400070017, (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');
SELECT extraction_batch_id FROM menu_extraction_batch WHERE source_id = 400070017 ORDER BY extraction_batch_id DESC LIMIT 1 \gset

-- Phones
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES
    (nextval('khaustan_standalone_id_seq'), 400070017, '9004467956', TRUE),
    (nextval('khaustan_standalone_id_seq'), 400070017, '9004467957', FALSE),
    (nextval('khaustan_standalone_id_seq'), 400070017, '9004467958', FALSE);

-- Hours: single stated window applied to every day (JSON gives one blanket timing,
-- no per-day breakdown) -- confidence: inferred blanket application, not per-day-confirmed.
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
VALUES
    (nextval('khaustan_standalone_id_seq'), 400070017, 1, 1, '08:00'::time, '23:59'::time),
    (nextval('khaustan_standalone_id_seq'), 400070017, 2, 1, '08:00'::time, '23:59'::time),
    (nextval('khaustan_standalone_id_seq'), 400070017, 3, 1, '08:00'::time, '23:59'::time),
    (nextval('khaustan_standalone_id_seq'), 400070017, 4, 1, '08:00'::time, '23:59'::time),
    (nextval('khaustan_standalone_id_seq'), 400070017, 5, 1, '08:00'::time, '23:59'::time),
    (nextval('khaustan_standalone_id_seq'), 400070017, 6, 1, '08:00'::time, '23:59'::time),
    (nextval('khaustan_standalone_id_seq'), 400070017, 7, 1, '08:00'::time, '23:59'::time);

-- HALAL restaurant tag: safe lookup-only insert. If 'halal' isn't yet a platform_tag
-- tag_code, this JOIN matches zero rows and inserts nothing -- no error, no new lookup
-- row created (lookup tables are read-only for this script).
INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id)
SELECT nextval('khaustan_standalone_id_seq'), 400070017, tag_id FROM platform_tag WHERE tag_code = 'halal';

-- Menu board: one a_la_carte board for the whole JSON source.
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, is_active, display_sequence)
VALUES (400070017001, 400070017, 'Main Menu', 'a_la_carte', TRUE, 1);

-- Categories, in JSON/source order. Where the source nests a subcategory (e.g.
-- STARTERS -> INDIAN / CHINESE), the top-level name becomes a parent row and the
-- subcategory becomes its child via parent_category_id -- the leaf (child) is what
-- items attach to. A category name repeated across two distinct source sections (this
-- happens at least once in this batch) is kept as two separate rows, not merged --
-- these are keyed by source position, not by display name.
INSERT INTO menu_category (menu_category_id, restaurant_id, name, parent_category_id, display_sequence)
VALUES
    (400070017001, 400070017, 'STARTERS', NULL, 1),
    (400070017002, 400070017, 'INDIAN', 400070017001, 2),
    (400070017003, 400070017, 'CHINESE', 400070017001, 3),
    (400070017004, 400070017, 'CHICKEN DISHES', NULL, 4),
    (400070017005, 400070017, 'MUTTON KHAJANA', NULL, 5),
    (400070017006, 400070017, 'MUTTON', NULL, 6),
    (400070017007, 400070017, 'BRAIN & EGGS', NULL, 7),
    (400070017008, 400070017, 'ROTI / NAAN / PARATHA', NULL, 8),
    (400070017009, 400070017, 'VEGETABLE', NULL, 9),
    (400070017010, 400070017, 'SALAD', NULL, 10),
    (400070017011, 400070017, 'BASMATI BIRYANI / PULAV / RICE', NULL, 11),
    (400070017012, 400070017, 'CHICKEN DISHES', NULL, 12),
    (400070017013, 400070017, 'VEGETABLE DISHES', NULL, 13),
    (400070017014, 400070017, 'CHINESE SOUPS', NULL, 14),
    (400070017015, 400070017, 'FRIED RICE', NULL, 15),
    (400070017016, 400070017, 'NOODLES', NULL, 16),
    (400070017017, 400070017, 'SNACKS / PIZZA', NULL, 17),
    (400070017018, 400070017, 'SANDWICH', NULL, 18),
    (400070017019, 400070017, 'FRESH FRUIT JUICE', NULL, 19),
    (400070017020, 400070017, 'MILK SHAKES', NULL, 20),
    (400070017021, 400070017, 'FALOODA', NULL, 21),
    (400070017022, 400070017, 'SLICE & POT KULFI', NULL, 22),
    (400070017023, 400070017, 'DESSERTS', NULL, 23),
    (400070017024, 400070017, 'COLD DRINKS', NULL, 24),
    (400070017025, 400070017, 'NASHEMAN CATERERS', NULL, 25);

-- Board <-> category mapping (leaf categories only)
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (400070017, 400070017001, 400070017002, 1),
    (400070017, 400070017001, 400070017003, 2),
    (400070017, 400070017001, 400070017004, 3),
    (400070017, 400070017001, 400070017005, 4),
    (400070017, 400070017001, 400070017006, 5),
    (400070017, 400070017001, 400070017007, 6),
    (400070017, 400070017001, 400070017008, 7),
    (400070017, 400070017001, 400070017009, 8),
    (400070017, 400070017001, 400070017010, 9),
    (400070017, 400070017001, 400070017011, 10),
    (400070017, 400070017001, 400070017012, 11),
    (400070017, 400070017001, 400070017013, 12),
    (400070017, 400070017001, 400070017014, 13),
    (400070017, 400070017001, 400070017015, 14),
    (400070017, 400070017001, 400070017016, 15),
    (400070017, 400070017001, 400070017017, 16),
    (400070017, 400070017001, 400070017018, 17),
    (400070017, 400070017001, 400070017019, 18),
    (400070017, 400070017001, 400070017020, 19),
    (400070017, 400070017001, 400070017021, 20),
    (400070017, 400070017001, 400070017022, 21),
    (400070017, 400070017001, 400070017023, 22),
    (400070017, 400070017001, 400070017024, 23),
    (400070017, 400070017001, 400070017025, 24);

-- Canonical dish identify-or-create: no unique constraint on canonical_dish.normalized_name,
-- so NOT EXISTS, not ON CONFLICT. Whether these already exist from an earlier onboarded
-- restaurant is resolved live by this check when the script runs.
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tandoori Spl (Full/half)', 'chicken tandoori spl (full/half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori spl (full/half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tandoori Spl (Full/half)', 'chicken tandoori spl (full/half)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Schezwan Tandoori', 'chicken schezwan tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Schezwan Tandoori', 'chicken schezwan tandoori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tandoori Leg', 'chicken tandoori leg'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori leg')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tandoori Leg', 'chicken tandoori leg', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tikka (5 Pcs)', 'chicken tikka (5 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka (5 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tikka (5 Pcs)', 'chicken tikka (5 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Malai Tikka', 'malai tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malai tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Malai Tikka', 'malai tikka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Seekh Kabab (4 Pcs)', 'chicken seekh kabab (4 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken seekh kabab (4 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Seekh Kabab (4 Pcs)', 'chicken seekh kabab (4 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Achari Kabab (5 Pcs)', 'chicken achari kabab (5 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken achari kabab (5 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Achari Kabab (5 Pcs)', 'chicken achari kabab (5 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Pahadi Kabab (5 Pcs)', 'chicken pahadi kabab (5 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pahadi kabab (5 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Pahadi Kabab (5 Pcs)', 'chicken pahadi kabab (5 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Reshmi Kabab (5 Pcs)', 'chicken reshmi kabab (5 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken reshmi kabab (5 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Reshmi Kabab (5 Pcs)', 'chicken reshmi kabab (5 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tangdi Kabab (2 Pc)', 'chicken tangdi kabab (2 pc)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tangdi kabab (2 pc)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tangdi Kabab (2 Pc)', 'chicken tangdi kabab (2 pc)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Banjara Kabab', 'chicken banjara kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken banjara kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Banjara Kabab', 'chicken banjara kabab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Pakoda', 'chicken pakoda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pakoda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Pakoda', 'chicken pakoda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Tikka Dry', 'paneer tikka dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka Dry', 'paneer tikka dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Roasted Dry', 'chicken roasted dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken roasted dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Roasted Dry', 'chicken roasted dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Lollypop (6 pcs)', 'chicken lollypop (6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lollypop (6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Lollypop (6 pcs)', 'chicken lollypop (6 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Crispy', 'chicken crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Crispy', 'chicken crispy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Dragon', 'chicken dragon'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken dragon')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Dragon', 'chicken dragon', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Chilly Dry', 'chicken chilly dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Chilly Dry', 'chicken chilly dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Manchurian Dry', 'chicken manchurian dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchurian dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Manchurian Dry', 'chicken manchurian dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chatpala Lollypop Dry', 'chatpala lollypop dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chatpala lollypop dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chatpala Lollypop Dry', 'chatpala lollypop dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Schezwan-Style Dry', 'chi. schezwan-style dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. schezwan-style dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Schezwan-Style Dry', 'chi. schezwan-style dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Crispy', 'paneer crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Crispy', 'paneer crispy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Crispy', 'veg. crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Crispy', 'veg. crispy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Chilly Dry', 'veg. chilly dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. chilly dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Chilly Dry', 'veg. chilly dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Manchurian Dry', 'veg. manchurian dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchurian dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Manchurian Dry', 'veg. manchurian dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Schezwan Style Dry', 'veg. schezwan style dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. schezwan style dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Schezwan Style Dry', 'veg. schezwan style dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Nasheman Spl.', 'chicken nasheman spl.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken nasheman spl.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Nasheman Spl.', 'chicken nasheman spl.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Murg Mussallam', 'murg mussallam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murg mussallam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Murg Mussallam', 'murg mussallam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Lara', 'chicken lara'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lara')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Lara', 'chicken lara', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Murhuba', 'chicken murhuba'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken murhuba')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Murhuba', 'chicken murhuba', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Lajawab (Boneless)', 'chicken lajawab (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lajawab (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Lajawab (Boneless)', 'chicken lajawab (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Akbari (boneless)', 'chicken akbari (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken akbari (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Akbari (boneless)', 'chicken akbari (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Angara (Boneless)', 'chicken angara (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken angara (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Angara (Boneless)', 'chicken angara (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Laziz (Boneless)', 'chicken laziz (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken laziz (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Laziz (Boneless)', 'chicken laziz (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Mumtaz (Boneless)', 'chicken mumtaz (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken mumtaz (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Mumtaz (Boneless)', 'chicken mumtaz (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tikka Kurma (Boneless)', 'chicken tikka kurma (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka kurma (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tikka Kurma (Boneless)', 'chicken tikka kurma (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Balti (Boneless)', 'chicken balti (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken balti (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Balti (Boneless)', 'chicken balti (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Hydrabadi (Boneless)', 'chicken hydrabadi (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hydrabadi (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Hydrabadi (Boneless)', 'chicken hydrabadi (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tawa (Boneless)', 'chicken tawa (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tawa (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tawa (Boneless)', 'chicken tawa (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Patyala (Boneless)', 'chicken patyala (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken patyala (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Patyala (Boneless)', 'chicken patyala (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Tikka Masala (Boneless)', 'chi. tikka masala (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. tikka masala (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Tikka Masala (Boneless)', 'chi. tikka masala (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Handi', 'chicken handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Handi', 'chicken handi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tandoori Masala', 'chicken tandoori masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tandoori Masala', 'chicken tandoori masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Lucknowi', 'chicken lucknowi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lucknowi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Lucknowi', 'chicken lucknowi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Kadai', 'chicken kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Kadai', 'chicken kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Kolhapuri', 'chicken kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Kolhapuri', 'chicken kolhapuri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Malwani', 'chicken malwani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken malwani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Malwani', 'chicken malwani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Afghani (boneless)', 'chicken afghani (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken afghani (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Afghani (boneless)', 'chicken afghani (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Chicken (Boneless)', 'butter chicken (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter chicken (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Chicken (Boneless)', 'butter chicken (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Green Masala (Boneless)', 'chi. green masala (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. green masala (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Green Masala (Boneless)', 'chi. green masala (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Do-Pyaza', 'chicken do-pyaza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken do-pyaza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Do-Pyaza', 'chicken do-pyaza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Moghlai', 'chicken moghlai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken moghlai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Moghlai', 'chicken moghlai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Rashida', 'chicken rashida'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken rashida')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Rashida', 'chicken rashida', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Korma', 'chicken korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Korma', 'chicken korma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Masala Fry', 'chicken masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Masala Fry', 'chicken masala fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Palak', 'chicken palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Palak', 'chicken palak', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Kheema', 'chicken kheema'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kheema')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Kheema', 'chicken kheema', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Nasheman Spl.', 'mutton nasheman spl.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton nasheman spl.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Nasheman Spl.', 'mutton nasheman spl.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Lajawab (Boneless)', 'mutton lajawab (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton lajawab (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Lajawab (Boneless)', 'mutton lajawab (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Mumtaz (Boneless)', 'mutton mumtaz (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton mumtaz (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Mumtaz (Boneless)', 'mutton mumtaz (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Angara (Boneless)', 'mutton angara (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton angara (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Angara (Boneless)', 'mutton angara (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Laziz (Boneless)', 'mutton laziz (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton laziz (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Laziz (Boneless)', 'mutton laziz (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Hyderabadi (Boneless)', 'mutton hyderabadi (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton hyderabadi (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Hyderabadi (Boneless)', 'mutton hyderabadi (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Balti', 'mutton balti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton balti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Balti', 'mutton balti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Handi', 'mutton handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Handi', 'mutton handi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Malwani', 'mutton malwani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton malwani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Malwani', 'mutton malwani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Tawa (Boneless)', 'mutton tawa (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton tawa (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Tawa (Boneless)', 'mutton tawa (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Dabba Gosht (B/L)', 'mutton dabba gosht (b/l)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton dabba gosht (b/l)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Dabba Gosht (B/L)', 'mutton dabba gosht (b/l)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Kolhapuri', 'mutton kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Kolhapuri', 'mutton kolhapuri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Kadai', 'mutton kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Kadai', 'mutton kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Afghani (Boneless)', 'mutton afghani (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton afghani (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Afghani (Boneless)', 'mutton afghani (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Lucknowi', 'mutton lucknowi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton lucknowi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Lucknowi', 'mutton lucknowi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Do-Pyaza', 'mutton do-pyaza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton do-pyaza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Do-Pyaza', 'mutton do-pyaza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Rogan Josh', 'mutton rogan josh'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton rogan josh')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Rogan Josh', 'mutton rogan josh', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Moghlai', 'mutton moghlai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton moghlai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Moghlai', 'mutton moghlai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Rashida', 'mutton rashida'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton rashida')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Rashida', 'mutton rashida', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Palak', 'mutton palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Palak', 'mutton palak', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Korma', 'mutton korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Korma', 'mutton korma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Gosht', 'mutton gosht'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton gosht')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Gosht', 'mutton gosht', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Masala Fry', 'mutton masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Masala Fry', 'mutton masala fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Kheema', 'mutton kheema'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kheema')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Kheema', 'mutton kheema', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Kheema Fry', 'mutton kheema fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kheema fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Kheema Fry', 'mutton kheema fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Kheema Ghotala', 'mutton kheema ghotala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kheema ghotala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Kheema Ghotala', 'mutton kheema ghotala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Extra Gravy Plain', 'extra gravy plain'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra gravy plain')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Extra Gravy Plain', 'extra gravy plain', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Brain Tomato Fry', 'brain tomato fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'brain tomato fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Brain Tomato Fry', 'brain tomato fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Brain Masala Fry', 'brain masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'brain masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Brain Masala Fry', 'brain masala fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Brain Bhurji', 'brain bhurji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'brain bhurji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Brain Bhurji', 'brain bhurji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Masala Fry (2 pcs Egg)', 'egg masala fry (2 pcs egg)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg masala fry (2 pcs egg)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Masala Fry (2 pcs Egg)', 'egg masala fry (2 pcs egg)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Bhurji', 'egg bhurji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg bhurji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Bhurji', 'egg bhurji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Omlet (Dubble)', 'egg omlet (dubble)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg omlet (dubble)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Omlet (Dubble)', 'egg omlet (dubble)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Half Fry (Dubble)', 'egg half fry (dubble)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg half fry (dubble)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Half Fry (Dubble)', 'egg half fry (dubble)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Boiled', 'egg boiled'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg boiled')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Boiled', 'egg boiled', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Boiled Fry', 'egg boiled fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg boiled fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Boiled Fry', 'egg boiled fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tandoori Roti', 'tandoori roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tandoori Roti', 'tandoori roti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tandoori Butter Roti', 'tandoori butter roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori butter roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tandoori Butter Roti', 'tandoori butter roti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tandoori Garlic Naan', 'tandoori garlic naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori garlic naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tandoori Garlic Naan', 'tandoori garlic naan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tandoori Naan', 'tandoori naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tandoori Naan', 'tandoori naan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tandoori Butter Naan', 'tandoori butter naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori butter naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tandoori Butter Naan', 'tandoori butter naan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kulcha Naan', 'kulcha naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kulcha naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kulcha Naan', 'kulcha naan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tandoori Paratha', 'tandoori paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tandoori Paratha', 'tandoori paratha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tandoori Butter Paratha', 'tandoori butter paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori butter paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tandoori Butter Paratha', 'tandoori butter paratha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tandoori Alu Paratha', 'tandoori alu paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori alu paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tandoori Alu Paratha', 'tandoori alu paratha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tandoori Stuffed Paratha', 'tandoori stuffed paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori stuffed paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tandoori Stuffed Paratha', 'tandoori stuffed paratha', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'P. Chapati', 'p. chapati'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'p. chapati')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'P. Chapati', 'p. chapati', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Nasheman Spl.', 'veg. nasheman spl.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. nasheman spl.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Nasheman Spl.', 'veg. nasheman spl.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Tikka Masala', 'paneer tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka Masala', 'paneer tikka masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Butter Masala', 'paneer butter masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer butter masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Butter Masala', 'paneer butter masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Shahi Korma', 'paneer shahi korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer shahi korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Shahi Korma', 'paneer shahi korma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Kadai', 'paneer kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Kadai', 'paneer kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Bhurji', 'paneer bhurji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer bhurji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Bhurji', 'paneer bhurji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Palak', 'paneer palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Palak', 'paneer palak', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Mutter', 'paneer mutter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer mutter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Mutter', 'paneer mutter', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Handi', 'veg. handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Handi', 'veg. handi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Kadai', 'veg. kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Kadai', 'veg. kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Balti', 'veg. balti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. balti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Balti', 'veg. balti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mushroom Kadai', 'mushroom kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mushroom Kadai', 'mushroom kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Hyderabadi', 'veg. hyderabadi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. hyderabadi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Hyderabadi', 'veg. hyderabadi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Kolhapuri', 'veg. kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Kolhapuri', 'veg. kolhapuri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mushroom Makhanwala', 'mushroom makhanwala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom makhanwala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mushroom Makhanwala', 'mushroom makhanwala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Jaipuri', 'veg. jaipuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. jaipuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Jaipuri', 'veg. jaipuri', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Kurma', 'veg. kurma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. kurma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Kurma', 'veg. kurma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Kheema', 'veg. kheema'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. kheema')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Kheema', 'veg. kheema', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Bhendi Masala Fry', 'bhendi masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bhendi masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Bhendi Masala Fry', 'bhendi masala fry', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Dal Fry', 'dal fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dal Fry', 'dal fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dal Fry with Butter', 'dal fry with butter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal fry with butter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dal Fry with Butter', 'dal fry with butter', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chana Masala', 'chana masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chana masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chana Masala', 'chana masala', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Alu Mutter', 'alu mutter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'alu mutter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Alu Mutter', 'alu mutter', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Alu Palak', 'alu palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'alu palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Alu Palak', 'alu palak', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mix. Vegetable', 'mix. vegetable'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix. vegetable')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mix. Vegetable', 'mix. vegetable', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Extra Fry Charge', 'extra fry charge'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra fry charge')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Extra Fry Charge', 'extra fry charge', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Rice Plate (only table Thali)', 'rice plate (only table thali)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rice plate (only table thali)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Rice Plate (only table Thali)', 'rice plate (only table thali)', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Bundi Raita', 'bundi raita'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bundi raita')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Bundi Raita', 'bundi raita', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Green Salad', 'green salad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green salad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Green Salad', 'green salad', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Masala Papad', 'masala papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Masala Papad', 'masala papad', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Papad', 'papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Papad', 'papad', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chinese Khabsa Rice', 'chinese khabsa rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chinese khabsa rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chinese Khabsa Rice', 'chinese khabsa rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Biryani', 'chicken biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Biryani', 'chicken biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Hydrabadi Biryani', 'chicken hydrabadi biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hydrabadi biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Hydrabadi Biryani', 'chicken hydrabadi biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tandoori Biryani', 'chicken tandoori biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tandoori Biryani', 'chicken tandoori biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Biryani', 'mutton biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Biryani', 'mutton biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Hyderabadi Biryani', 'mutton hyderabadi biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton hyderabadi biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Hyderabadi Biryani', 'mutton hyderabadi biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Biryani', 'egg biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Biryani', 'egg biryani', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Tikka Biryani', 'paneer tikka biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka Biryani', 'paneer tikka biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Pulao', 'paneer pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Pulao', 'paneer pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Pulao', 'chicken pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Pulao', 'chicken pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Pulao', 'mutton pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Pulao', 'mutton pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Pulao', 'egg pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Pulao', 'egg pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Pulao', 'veg. pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Pulao', 'veg. pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Kashmiri Pulao', 'veg. kashmiri pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. kashmiri pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Kashmiri Pulao', 'veg. kashmiri pulao', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'White Rice / Biryani Rice', 'white rice / biryani rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'white rice / biryani rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'White Rice / Biryani Rice', 'white rice / biryani rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Jeera Rice / Steam Rice', 'jeera rice / steam rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jeera rice / steam rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Jeera Rice / Steam Rice', 'jeera rice / steam rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tandoori Chicken', 'tandoori chicken'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori chicken')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tandoori Chicken', 'tandoori chicken', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Chilly', 'chicken chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Chilly', 'chicken chilly', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Manchurian', 'chicken manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Manchurian', 'chicken manchurian', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Garlic / Ginger', 'chicken garlic / ginger'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken garlic / ginger')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Garlic / Ginger', 'chicken garlic / ginger', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Garlic / Ginger Dry', 'chicken garlic / ginger dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken garlic / ginger dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Garlic / Ginger Dry', 'chicken garlic / ginger dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Sweet & Sour', 'chicken sweet & sour'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken sweet & sour')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Sweet & Sour', 'chicken sweet & sour', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Schezwan', 'chicken schezwan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Schezwan', 'chicken schezwan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Hong Kong', 'chicken hong kong'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hong kong')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Hong Kong', 'chicken hong kong', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Singapore', 'chicken singapore'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken singapore')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Singapore', 'chicken singapore', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Lollypop with Gravy', 'chi. lollypop with gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. lollypop with gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Lollypop with Gravy', 'chi. lollypop with gravy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken 65', 'chicken 65'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken 65')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken 65', 'chicken 65', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. 65', 'veg. 65'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. 65')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. 65', 'veg. 65', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Schezwan', 'veg. schezwan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. schezwan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Schezwan', 'veg. schezwan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Chilly / Manchurian', 'veg. chilly / manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. chilly / manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Chilly / Manchurian', 'veg. chilly / manchurian', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Garlic / Ginger', 'veg. garlic / ginger'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. garlic / ginger')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Garlic / Ginger', 'veg. garlic / ginger', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Sweet & Sour', 'veg. sweet & sour'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. sweet & sour')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Sweet & Sour', 'veg. sweet & sour', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Chilly', 'paneer chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Chilly', 'paneer chilly', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Manchurian', 'paneer manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Manchurian', 'paneer manchurian', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mushroom Chilly', 'mushroom chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mushroom Chilly', 'mushroom chilly', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mushroom Manchurian', 'mushroom manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mushroom Manchurian', 'mushroom manchurian', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Nasheman Spl. Soup', 'nasheman spl. soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'nasheman spl. soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Nasheman Spl. Soup', 'nasheman spl. soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Hot & Sour Soup', 'hot & sour soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hot & sour soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Hot & Sour Soup', 'hot & sour soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Manchow Soup', 'manchow soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'manchow soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Manchow Soup', 'manchow soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Noodles Soup', 'noodles soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'noodles soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Noodles Soup', 'noodles soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sweet Corn Soup', 'sweet corn soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sweet corn soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sweet Corn Soup', 'sweet corn soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Clear Soup', 'clear soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'clear soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Clear Soup', 'clear soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Lung Fung Soup', 'chicken lung fung soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lung fung soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Lung Fung Soup', 'chicken lung fung soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Clear Soup', 'mutton clear soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton clear soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Clear Soup', 'mutton clear soup', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Nasheman Spl. Fried Rice', 'chicken nasheman spl. fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken nasheman spl. fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Nasheman Spl. Fried Rice', 'chicken nasheman spl. fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Fried Rice', 'chicken fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Fried Rice', 'chicken fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Schezwan Fried Rice', 'chi. schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Schezwan Fried Rice', 'chi. schezwan fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Combination Fried Rice', 'chi. combination fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. combination fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Combination Fried Rice', 'chi. combination fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Hong Kong Fried Rice', 'chi. hong kong fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. hong kong fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Hong Kong Fried Rice', 'chi. hong kong fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mix Fried Rice', 'mix fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mix Fried Rice', 'mix fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mix Schezwan Fried Rice', 'mix schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mix Schezwan Fried Rice', 'mix schezwan fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Singapore Fried Rice', 'chi. singapore fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. singapore fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Singapore Fried Rice', 'chi. singapore fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Fried Rice', 'egg fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Fried Rice', 'egg fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Schezwan Fried Rice', 'egg schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Schezwan Fried Rice', 'egg schezwan fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Fried Rice', 'veg. fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Fried Rice', 'veg. fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Schezwan Fried Rice', 'veg. schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Schezwan Fried Rice', 'veg. schezwan fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Hong Kong Fried Rice', 'veg. hong kong fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. hong kong fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Hong Kong Fried Rice', 'veg. hong kong fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Singapore Fried Rice', 'veg. singapore fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. singapore fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Singapore Fried Rice', 'veg. singapore fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Nasheman Sp. Rice', 'veg. nasheman sp. rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. nasheman sp. rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Nasheman Sp. Rice', 'veg. nasheman sp. rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Manchurian Noodles', 'veg. manchurian noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchurian noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Manchurian Noodles', 'veg. manchurian noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Chilly Noodles', 'veg. chilly noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. chilly noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Chilly Noodles', 'veg. chilly noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Tripple Noodles', 'veg. tripple noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. tripple noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Tripple Noodles', 'veg. tripple noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. American Chopsuey', 'chi. american chopsuey'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. american chopsuey')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. American Chopsuey', 'chi. american chopsuey', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chinese Chopsuey', 'chinese chopsuey'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chinese chopsuey')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chinese Chopsuey', 'chinese chopsuey', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. American Chopsuey', 'veg. american chopsuey'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. american chopsuey')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. American Chopsuey', 'veg. american chopsuey', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Hakka Noodles', 'chicken hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Hakka Noodles', 'chicken hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Schezwan Hakka Noodles', 'chicken schezwan hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Schezwan Hakka Noodles', 'chicken schezwan hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Singapore Noodles', 'chicken singapore noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken singapore noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Singapore Noodles', 'chicken singapore noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Hong Kong Noodles', 'chi. hong kong noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. hong kong noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Hong Kong Noodles', 'chi. hong kong noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tripples Noodles', 'chicken tripples noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tripples noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tripples Noodles', 'chicken tripples noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Manchurian Noodles', 'chi. manchurian noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. manchurian noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Manchurian Noodles', 'chi. manchurian noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Chilly Noodles', 'chicken chilly noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Chilly Noodles', 'chicken chilly noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mix Hakka Noodles', 'mix hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mix Hakka Noodles', 'mix hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mix Schn. Hakka Noodles', 'mix schn. hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix schn. hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mix Schn. Hakka Noodles', 'mix schn. hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Hakka Noodles', 'egg hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Hakka Noodles', 'egg hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Schn. Hakka Noodles', 'egg schn. hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg schn. hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Schn. Hakka Noodles', 'egg schn. hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Hakka Noodles', 'veg. hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Hakka Noodles', 'veg. hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Schn. Hakka Noodles', 'veg. schn. hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. schn. hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Schn. Hakka Noodles', 'veg. schn. hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Hong Kong Noodle', 'veg. hong kong noodle'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. hong kong noodle')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Hong Kong Noodle', 'veg. hong kong noodle', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Singapore Noodles', 'veg. singapore noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. singapore noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Singapore Noodles', 'veg. singapore noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Nasheman Spl. Pizza', 'chi. nasheman spl. pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. nasheman spl. pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Nasheman Spl. Pizza', 'chi. nasheman spl. pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tikka Pizza', 'chicken tikka pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tikka Pizza', 'chicken tikka pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Cheese Pizza', 'chicken cheese pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken cheese pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Cheese Pizza', 'chicken cheese pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Tikka Pizza', 'paneer tikka pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka Pizza', 'paneer tikka pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mushroom Delight Pizza', 'mushroom delight pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom delight pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mushroom Delight Pizza', 'mushroom delight pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Pizza', 'cheese pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Pizza', 'cheese pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mix. Pizza', 'mix. pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix. pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mix. Pizza', 'mix. pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Cheese Pizza', 'veg. cheese pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. cheese pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Cheese Pizza', 'veg. cheese pizza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Extra Cheese', 'extra cheese'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra cheese')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Extra Cheese', 'extra cheese', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Sandwich', 'chicken sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Sandwich', 'chicken sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Cheese Sandwich', 'chi. cheese sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. cheese sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Cheese Sandwich', 'chi. cheese sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Grill Sandwich', 'chi. grill sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. grill sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Grill Sandwich', 'chi. grill sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Cheese Grill S/W', 'chi. cheese grill s/w'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. cheese grill s/w')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Cheese Grill S/W', 'chi. cheese grill s/w', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Omlet Sandwich', 'omlet sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'omlet sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Omlet Sandwich', 'omlet sandwich', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Sandwich', 'veg. sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Sandwich', 'veg. sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Sandwich', 'cheese sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Sandwich', 'cheese sandwich', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Cheese Grill S/W', 'veg. cheese grill s/w'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. cheese grill s/w')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Cheese Grill S/W', 'veg. cheese grill s/w', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Pakoda', 'veg. pakoda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. pakoda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Pakoda', 'veg. pakoda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Sandwich', 'egg sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Sandwich', 'egg sandwich', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Alu Chips', 'alu chips'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'alu chips')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Alu Chips', 'alu chips', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mango Juice (Seasonal)', 'mango juice (seasonal)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mango juice (seasonal)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mango Juice (Seasonal)', 'mango juice (seasonal)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Anar Juice', 'anar juice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'anar juice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Anar Juice', 'anar juice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Apple Juice', 'apple juice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'apple juice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Apple Juice', 'apple juice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pineapple Juice', 'pineapple juice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pineapple juice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pineapple Juice', 'pineapple juice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cocktail Juice', 'cocktail juice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cocktail juice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cocktail Juice', 'cocktail juice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Carrot Juice', 'carrot juice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'carrot juice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Carrot Juice', 'carrot juice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mosambi Juice', 'mosambi juice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mosambi juice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mosambi Juice', 'mosambi juice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Beet Juice', 'beet juice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'beet juice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Beet Juice', 'beet juice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mango Milk Shake', 'mango milk shake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mango milk shake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mango Milk Shake', 'mango milk shake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kesar Pista Milk Shake', 'kesar pista milk shake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kesar pista milk shake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kesar Pista Milk Shake', 'kesar pista milk shake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dry Fruit Milk Shake', 'dry fruit milk shake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dry fruit milk shake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dry Fruit Milk Shake', 'dry fruit milk shake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Apple Milk Shake', 'apple milk shake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'apple milk shake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Apple Milk Shake', 'apple milk shake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Vanilla Milk Shake', 'vanilla milk shake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vanilla milk shake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Vanilla Milk Shake', 'vanilla milk shake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Strawberry Milk Shake', 'strawberry milk shake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'strawberry milk shake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Strawberry Milk Shake', 'strawberry milk shake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chocolate Milk Shake', 'chocolate milk shake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chocolate milk shake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chocolate Milk Shake', 'chocolate milk shake', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Cold Coffee with V/Cream', 'cold coffee with v/cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cold coffee with v/cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cold Coffee with V/Cream', 'cold coffee with v/cream', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Fruit Salad with V/Cream', 'fruit salad with v/cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fruit salad with v/cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Fruit Salad with V/Cream', 'fruit salad with v/cream', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Nasheman ki Shaan', 'nasheman ki shaan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'nasheman ki shaan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Nasheman ki Shaan', 'nasheman ki shaan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Rabdi Falooda', 'rabdi falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rabdi falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Rabdi Falooda', 'rabdi falooda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mix Kulfi Falooda', 'mix kulfi falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix kulfi falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mix Kulfi Falooda', 'mix kulfi falooda', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Sp. Falooda / Kesar Falooda', 'sp. falooda / kesar falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sp. falooda / kesar falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sp. Falooda / Kesar Falooda', 'sp. falooda / kesar falooda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kaju Falooda/Rose Falooda', 'kaju falooda/rose falooda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kaju falooda/rose falooda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kaju Falooda/Rose Falooda', 'kaju falooda/rose falooda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Malai Kulfi', 'malai kulfi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malai kulfi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Malai Kulfi', 'malai kulfi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Keser Pista', 'keser pista'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'keser pista')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Keser Pista', 'keser pista', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Badam Pista', 'badam pista'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'badam pista')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Badam Pista', 'badam pista', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Caramel Custard', 'caramel custard'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'caramel custard')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Caramel Custard', 'caramel custard', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Sp. Lassi', 'sp. lassi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sp. lassi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sp. Lassi', 'sp. lassi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dry Fruit Lassi/Mango Lassi', 'dry fruit lassi/mango lassi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dry fruit lassi/mango lassi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dry Fruit Lassi/Mango Lassi', 'dry fruit lassi/mango lassi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Milk (Chaas)', 'butter milk (chaas)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter milk (chaas)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Milk (Chaas)', 'butter milk (chaas)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mineral Water', 'mineral water'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mineral water')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mineral Water', 'mineral water', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'All Soft Drinks (300 ml)', 'all soft drinks (300 ml)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'all soft drinks (300 ml)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'All Soft Drinks (300 ml)', 'all soft drinks (300 ml)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'All Soft Drinks (500 ml, 2 ltr)', 'all soft drinks (500 ml, 2 ltr)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'all soft drinks (500 ml, 2 ltr)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'All Soft Drinks (500 ml, 2 ltr)', 'all soft drinks (500 ml, 2 ltr)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Fresh Lime Juice', 'fresh lime juice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fresh lime juice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Fresh Lime Juice', 'fresh lime juice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Fresh Lime Soda', 'fresh lime soda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fresh lime soda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Fresh Lime Soda', 'fresh lime soda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sikanjbin Sharbat', 'sikanjbin sharbat'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sikanjbin sharbat')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sikanjbin Sharbat', 'sikanjbin sharbat', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Soda', 'soda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'soda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Soda', 'soda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Biryani (Per Pailee) (3 Kg Rice + 3 Kg Chicken)', 'chicken biryani (per pailee) (3 kg rice + 3 kg chicken)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken biryani (per pailee) (3 kg rice + 3 kg chicken)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Biryani (Per Pailee) (3 Kg Rice + 3 Kg Chicken)', 'chicken biryani (per pailee) (3 kg rice + 3 kg chicken)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Biryani (Per Kg) (1 Kg Rice + 1 Kg Chicken)', 'chicken biryani (per kg) (1 kg rice + 1 kg chicken)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken biryani (per kg) (1 kg rice + 1 kg chicken)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Biryani (Per Kg) (1 Kg Rice + 1 Kg Chicken)', 'chicken biryani (per kg) (1 kg rice + 1 kg chicken)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Biryani (Per Pailee) (3 Kg Rice + 3 Kg Mutton)', 'mutton biryani (per pailee) (3 kg rice + 3 kg mutton)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton biryani (per pailee) (3 kg rice + 3 kg mutton)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Biryani (Per Pailee) (3 Kg Rice + 3 Kg Mutton)', 'mutton biryani (per pailee) (3 kg rice + 3 kg mutton)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Biryani (Per Kg) (1 Kg Rice + 1 Kg Mutton)', 'mutton biryani (per kg) (1 kg rice + 1 kg mutton)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton biryani (per kg) (1 kg rice + 1 kg mutton)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Biryani (Per Kg) (1 Kg Rice + 1 Kg Mutton)', 'mutton biryani (per kg) (1 kg rice + 1 kg mutton)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tikka Biryani (1 Kg)', 'chicken tikka biryani (1 kg)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka biryani (1 kg)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tikka Biryani (1 Kg)', 'chicken tikka biryani (1 kg)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Pulao Bone (1 Kg)', 'mutton pulao bone (1 kg)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton pulao bone (1 kg)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Pulao Bone (1 Kg)', 'mutton pulao bone (1 kg)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Pulao Bone (1 Kg)', 'chicken pulao bone (1 kg)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pulao bone (1 kg)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Pulao Bone (1 Kg)', 'chicken pulao bone (1 kg)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Biryani / Veg. Pulao (1 Kg)', 'veg. biryani / veg. pulao (1 kg)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. biryani / veg. pulao (1 kg)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Biryani / Veg. Pulao (1 Kg)', 'veg. biryani / veg. pulao (1 kg)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dal Gosht (1 Kg) / Mutton Korma (1 Kg)', 'dal gosht (1 kg) / mutton korma (1 kg)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal gosht (1 kg) / mutton korma (1 kg)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dal Gosht (1 Kg) / Mutton Korma (1 Kg)', 'dal gosht (1 kg) / mutton korma (1 kg)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Fried Rice (1 Kg)', 'chicken fried rice (1 kg)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken fried rice (1 kg)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Fried Rice (1 Kg)', 'chicken fried rice (1 kg)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kheema (1 Kg)', 'kheema (1 kg)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kheema (1 kg)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kheema (1 Kg)', 'kheema (1 kg)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Korma (1 Kg)', 'chicken korma (1 kg)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken korma (1 kg)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Korma (1 Kg)', 'chicken korma (1 kg)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Jeera Rice (1 Kg)', 'jeera rice (1 kg)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jeera rice (1 kg)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Jeera Rice (1 Kg)', 'jeera rice (1 kg)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Rice (1 kg)', 'rice (1 kg)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rice (1 kg)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Rice (1 kg)', 'rice (1 kg)', 'primary'
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
    (400070017001, 400070017, 'Chicken Tandoori Spl (Full/half)', 'chicken tandoori spl (full/half)', 'INDIAN', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070017002, 400070017, 'Chicken Schezwan Tandoori', 'chicken schezwan tandoori', 'INDIAN', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070017003, 400070017, 'Chicken Tandoori Leg', 'chicken tandoori leg', 'INDIAN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017004, 400070017, 'Chicken Tikka (5 Pcs)', 'chicken tikka (5 pcs)', 'INDIAN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017005, 400070017, 'Malai Tikka', 'malai tikka', 'INDIAN', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017006, 400070017, 'Chicken Seekh Kabab (4 Pcs)', 'chicken seekh kabab (4 pcs)', 'INDIAN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017007, 400070017, 'Chicken Achari Kabab (5 Pcs)', 'chicken achari kabab (5 pcs)', 'INDIAN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017008, 400070017, 'Chicken Pahadi Kabab (5 Pcs)', 'chicken pahadi kabab (5 pcs)', 'INDIAN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017009, 400070017, 'Chicken Reshmi Kabab (5 Pcs)', 'chicken reshmi kabab (5 pcs)', 'INDIAN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017010, 400070017, 'Chicken Tangdi Kabab (2 Pc)', 'chicken tangdi kabab (2 pc)', 'INDIAN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017011, 400070017, 'Chicken Banjara Kabab', 'chicken banjara kabab', 'INDIAN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017012, 400070017, 'Chicken Pakoda', 'chicken pakoda', 'INDIAN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017013, 400070017, 'Paneer Tikka Dry', 'paneer tikka dry', 'INDIAN', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017014, 400070017, 'Chicken Roasted Dry', 'chicken roasted dry', 'CHINESE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017015, 400070017, 'Chicken Lollypop (6 pcs)', 'chicken lollypop (6 pcs)', 'CHINESE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017016, 400070017, 'Chicken Crispy', 'chicken crispy', 'CHINESE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017017, 400070017, 'Chicken Dragon', 'chicken dragon', 'CHINESE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017018, 400070017, 'Chicken Chilly Dry', 'chicken chilly dry', 'CHINESE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017019, 400070017, 'Chicken Manchurian Dry', 'chicken manchurian dry', 'CHINESE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017020, 400070017, 'Chatpala Lollypop Dry', 'chatpala lollypop dry', 'CHINESE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017021, 400070017, 'Chi. Schezwan-Style Dry', 'chi. schezwan-style dry', 'CHINESE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017022, 400070017, 'Paneer Crispy', 'paneer crispy', 'CHINESE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017023, 400070017, 'Veg. Crispy', 'veg. crispy', 'CHINESE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017024, 400070017, 'Veg. Chilly Dry', 'veg. chilly dry', 'CHINESE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017025, 400070017, 'Veg. Manchurian Dry', 'veg. manchurian dry', 'CHINESE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017026, 400070017, 'Veg. Schezwan Style Dry', 'veg. schezwan style dry', 'CHINESE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017027, 400070017, 'Chicken Nasheman Spl.', 'chicken nasheman spl.', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017028, 400070017, 'Murg Mussallam', 'murg mussallam', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017029, 400070017, 'Chicken Lara', 'chicken lara', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017030, 400070017, 'Chicken Murhuba', 'chicken murhuba', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017031, 400070017, 'Chicken Lajawab (Boneless)', 'chicken lajawab (boneless)', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017032, 400070017, 'Chicken Akbari (boneless)', 'chicken akbari (boneless)', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017033, 400070017, 'Chicken Angara (Boneless)', 'chicken angara (boneless)', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017034, 400070017, 'Chicken Laziz (Boneless)', 'chicken laziz (boneless)', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017035, 400070017, 'Chicken Mumtaz (Boneless)', 'chicken mumtaz (boneless)', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017036, 400070017, 'Chicken Tikka Kurma (Boneless)', 'chicken tikka kurma (boneless)', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017037, 400070017, 'Chicken Balti (Boneless)', 'chicken balti (boneless)', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017038, 400070017, 'Chicken Hydrabadi (Boneless)', 'chicken hydrabadi (boneless)', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017039, 400070017, 'Chicken Tawa (Boneless)', 'chicken tawa (boneless)', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017040, 400070017, 'Chicken Patyala (Boneless)', 'chicken patyala (boneless)', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017041, 400070017, 'Chi. Tikka Masala (Boneless)', 'chi. tikka masala (boneless)', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017042, 400070017, 'Chicken Handi', 'chicken handi', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017043, 400070017, 'Chicken Tandoori Masala', 'chicken tandoori masala', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017044, 400070017, 'Chicken Lucknowi', 'chicken lucknowi', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017045, 400070017, 'Chicken Kadai', 'chicken kadai', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017046, 400070017, 'Chicken Kolhapuri', 'chicken kolhapuri', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017047, 400070017, 'Chicken Malwani', 'chicken malwani', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017048, 400070017, 'Chicken Afghani (boneless)', 'chicken afghani (boneless)', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017049, 400070017, 'Butter Chicken (Boneless)', 'butter chicken (boneless)', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017050, 400070017, 'Chi. Green Masala (Boneless)', 'chi. green masala (boneless)', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017051, 400070017, 'Chicken Do-Pyaza', 'chicken do-pyaza', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017052, 400070017, 'Chicken Moghlai', 'chicken moghlai', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017053, 400070017, 'Chicken Rashida', 'chicken rashida', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017054, 400070017, 'Chicken Korma', 'chicken korma', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017055, 400070017, 'Chicken Masala Fry', 'chicken masala fry', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017056, 400070017, 'Chicken Palak', 'chicken palak', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017057, 400070017, 'Chicken Kheema', 'chicken kheema', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017058, 400070017, 'Mutton Nasheman Spl.', 'mutton nasheman spl.', 'MUTTON KHAJANA', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017059, 400070017, 'Mutton Lajawab (Boneless)', 'mutton lajawab (boneless)', 'MUTTON KHAJANA', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017060, 400070017, 'Mutton Mumtaz (Boneless)', 'mutton mumtaz (boneless)', 'MUTTON KHAJANA', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017061, 400070017, 'Mutton Angara (Boneless)', 'mutton angara (boneless)', 'MUTTON KHAJANA', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017062, 400070017, 'Mutton Laziz (Boneless)', 'mutton laziz (boneless)', 'MUTTON KHAJANA', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017063, 400070017, 'Mutton Hyderabadi (Boneless)', 'mutton hyderabadi (boneless)', 'MUTTON KHAJANA', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017064, 400070017, 'Mutton Balti', 'mutton balti', 'MUTTON KHAJANA', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017065, 400070017, 'Mutton Handi', 'mutton handi', 'MUTTON KHAJANA', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017066, 400070017, 'Mutton Malwani', 'mutton malwani', 'MUTTON KHAJANA', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017067, 400070017, 'Mutton Tawa (Boneless)', 'mutton tawa (boneless)', 'MUTTON KHAJANA', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017068, 400070017, 'Mutton Dabba Gosht (B/L)', 'mutton dabba gosht (b/l)', 'MUTTON KHAJANA', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017069, 400070017, 'Mutton Kolhapuri', 'mutton kolhapuri', 'MUTTON KHAJANA', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017070, 400070017, 'Mutton Kadai', 'mutton kadai', 'MUTTON KHAJANA', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017071, 400070017, 'Mutton Afghani (Boneless)', 'mutton afghani (boneless)', 'MUTTON KHAJANA', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017072, 400070017, 'Mutton Lucknowi', 'mutton lucknowi', 'MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017073, 400070017, 'Mutton Do-Pyaza', 'mutton do-pyaza', 'MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017074, 400070017, 'Mutton Rogan Josh', 'mutton rogan josh', 'MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017075, 400070017, 'Mutton Moghlai', 'mutton moghlai', 'MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017076, 400070017, 'Mutton Rashida', 'mutton rashida', 'MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017077, 400070017, 'Mutton Palak', 'mutton palak', 'MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017078, 400070017, 'Mutton Korma', 'mutton korma', 'MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017079, 400070017, 'Mutton Gosht', 'mutton gosht', 'MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017080, 400070017, 'Mutton Masala Fry', 'mutton masala fry', 'MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017081, 400070017, 'Mutton Kheema', 'mutton kheema', 'MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017082, 400070017, 'Mutton Kheema Fry', 'mutton kheema fry', 'MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017083, 400070017, 'Mutton Kheema Ghotala', 'mutton kheema ghotala', 'MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017084, 400070017, 'Extra Gravy Plain', 'extra gravy plain', 'MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017085, 400070017, 'Brain Tomato Fry', 'brain tomato fry', 'BRAIN & EGGS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017086, 400070017, 'Brain Masala Fry', 'brain masala fry', 'BRAIN & EGGS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017087, 400070017, 'Brain Bhurji', 'brain bhurji', 'BRAIN & EGGS', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017088, 400070017, 'Egg Masala Fry (2 pcs Egg)', 'egg masala fry (2 pcs egg)', 'BRAIN & EGGS', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017089, 400070017, 'Egg Bhurji', 'egg bhurji', 'BRAIN & EGGS', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017090, 400070017, 'Egg Omlet (Dubble)', 'egg omlet (dubble)', 'BRAIN & EGGS', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017091, 400070017, 'Egg Half Fry (Dubble)', 'egg half fry (dubble)', 'BRAIN & EGGS', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017092, 400070017, 'Egg Boiled', 'egg boiled', 'BRAIN & EGGS', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017093, 400070017, 'Egg Boiled Fry', 'egg boiled fry', 'BRAIN & EGGS', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017094, 400070017, 'Tandoori Roti', 'tandoori roti', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017095, 400070017, 'Tandoori Butter Roti', 'tandoori butter roti', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017096, 400070017, 'Tandoori Garlic Naan', 'tandoori garlic naan', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017097, 400070017, 'Tandoori Naan', 'tandoori naan', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017098, 400070017, 'Tandoori Butter Naan', 'tandoori butter naan', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017099, 400070017, 'Kulcha Naan', 'kulcha naan', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017100, 400070017, 'Tandoori Paratha', 'tandoori paratha', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017101, 400070017, 'Tandoori Butter Paratha', 'tandoori butter paratha', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017102, 400070017, 'Tandoori Alu Paratha', 'tandoori alu paratha', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017103, 400070017, 'Tandoori Stuffed Paratha', 'tandoori stuffed paratha', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017104, 400070017, 'Chapati', 'chapati', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017105, 400070017, 'P. Chapati', 'p. chapati', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017106, 400070017, 'Veg. Nasheman Spl.', 'veg. nasheman spl.', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017107, 400070017, 'Paneer Tikka Masala', 'paneer tikka masala', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017108, 400070017, 'Paneer Butter Masala', 'paneer butter masala', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017109, 400070017, 'Paneer Shahi Korma', 'paneer shahi korma', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017110, 400070017, 'Paneer Kadai', 'paneer kadai', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017111, 400070017, 'Paneer Bhurji', 'paneer bhurji', 'VEGETABLE', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017112, 400070017, 'Paneer Palak', 'paneer palak', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017113, 400070017, 'Paneer Mutter', 'paneer mutter', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017114, 400070017, 'Veg. Handi', 'veg. handi', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017115, 400070017, 'Veg. Kadai', 'veg. kadai', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017116, 400070017, 'Veg. Balti', 'veg. balti', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017117, 400070017, 'Mushroom Kadai', 'mushroom kadai', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017118, 400070017, 'Veg. Hyderabadi', 'veg. hyderabadi', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017119, 400070017, 'Veg. Kolhapuri', 'veg. kolhapuri', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017120, 400070017, 'Mushroom Makhanwala', 'mushroom makhanwala', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017121, 400070017, 'Veg. Jaipuri', 'veg. jaipuri', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017122, 400070017, 'Veg. Makhanwala', 'veg. makhanwala', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017123, 400070017, 'Veg. Kurma', 'veg. kurma', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017124, 400070017, 'Veg. Kheema', 'veg. kheema', 'VEGETABLE', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017125, 400070017, 'Bhendi Masala Fry', 'bhendi masala fry', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017126, 400070017, 'Dal Tadka', 'dal tadka', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017127, 400070017, 'Dal Fry', 'dal fry', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017128, 400070017, 'Dal Fry with Butter', 'dal fry with butter', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017129, 400070017, 'Chana Masala', 'chana masala', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017130, 400070017, 'Chana Masala Fry', 'chana masala fry', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017131, 400070017, 'Alu Mutter', 'alu mutter', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017132, 400070017, 'Alu Palak', 'alu palak', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017133, 400070017, 'Mix. Vegetable', 'mix. vegetable', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017134, 400070017, 'Extra Fry Charge', 'extra fry charge', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017135, 400070017, 'Pav Bhaji', 'pav bhaji', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017136, 400070017, 'Rice Plate (only table Thali)', 'rice plate (only table thali)', 'VEGETABLE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017137, 400070017, 'Veg. Raita', 'veg. raita', 'SALAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017138, 400070017, 'Bundi Raita', 'bundi raita', 'SALAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017139, 400070017, 'Pineapple Raita', 'pineapple raita', 'SALAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017140, 400070017, 'Green Salad', 'green salad', 'SALAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017141, 400070017, 'Masala Papad', 'masala papad', 'SALAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017142, 400070017, 'Papad', 'papad', 'SALAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017143, 400070017, 'Chinese Khabsa Rice', 'chinese khabsa rice', 'BASMATI BIRYANI / PULAV / RICE', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017144, 400070017, 'Chicken Biryani', 'chicken biryani', 'BASMATI BIRYANI / PULAV / RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017145, 400070017, 'Chicken Hydrabadi Biryani', 'chicken hydrabadi biryani', 'BASMATI BIRYANI / PULAV / RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017146, 400070017, 'Chicken Tandoori Biryani', 'chicken tandoori biryani', 'BASMATI BIRYANI / PULAV / RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017147, 400070017, 'Chicken Biryani', 'chicken biryani', 'BASMATI BIRYANI / PULAV / RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017148, 400070017, 'Mutton Biryani', 'mutton biryani', 'BASMATI BIRYANI / PULAV / RICE', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017149, 400070017, 'Mutton Hyderabadi Biryani', 'mutton hyderabadi biryani', 'BASMATI BIRYANI / PULAV / RICE', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017150, 400070017, 'Egg Biryani', 'egg biryani', 'BASMATI BIRYANI / PULAV / RICE', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017151, 400070017, 'Veg. Biryani', 'veg. biryani', 'BASMATI BIRYANI / PULAV / RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017152, 400070017, 'Paneer Tikka Biryani', 'paneer tikka biryani', 'BASMATI BIRYANI / PULAV / RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017153, 400070017, 'Paneer Pulao', 'paneer pulao', 'BASMATI BIRYANI / PULAV / RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017154, 400070017, 'Chicken Pulao', 'chicken pulao', 'BASMATI BIRYANI / PULAV / RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017155, 400070017, 'Mutton Pulao', 'mutton pulao', 'BASMATI BIRYANI / PULAV / RICE', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017156, 400070017, 'Egg Pulao', 'egg pulao', 'BASMATI BIRYANI / PULAV / RICE', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017157, 400070017, 'Veg. Pulao', 'veg. pulao', 'BASMATI BIRYANI / PULAV / RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017158, 400070017, 'Veg. Kashmiri Pulao', 'veg. kashmiri pulao', 'BASMATI BIRYANI / PULAV / RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017159, 400070017, 'Dal Khichdi', 'dal khichdi', 'BASMATI BIRYANI / PULAV / RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017160, 400070017, 'White Rice / Biryani Rice', 'white rice / biryani rice', 'BASMATI BIRYANI / PULAV / RICE', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017161, 400070017, 'Jeera Rice / Steam Rice', 'jeera rice / steam rice', 'BASMATI BIRYANI / PULAV / RICE', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017162, 400070017, 'Chicken Moghlai', 'chicken moghlai', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017163, 400070017, 'Chicken Moghlai', 'chicken moghlai', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017164, 400070017, 'Tandoori Chicken', 'tandoori chicken', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017165, 400070017, 'Chicken Chilly', 'chicken chilly', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017166, 400070017, 'Chicken Manchurian', 'chicken manchurian', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017167, 400070017, 'Chicken Garlic / Ginger', 'chicken garlic / ginger', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017168, 400070017, 'Chicken Garlic / Ginger Dry', 'chicken garlic / ginger dry', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017169, 400070017, 'Chicken Sweet & Sour', 'chicken sweet & sour', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017170, 400070017, 'Chicken Schezwan', 'chicken schezwan', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017171, 400070017, 'Chicken Hong Kong', 'chicken hong kong', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017172, 400070017, 'Chicken Singapore', 'chicken singapore', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017173, 400070017, 'Chi. Lollypop with Gravy', 'chi. lollypop with gravy', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017174, 400070017, 'Chicken 65', 'chicken 65', 'CHICKEN DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070017175, 400070017, 'Veg. 65', 'veg. 65', 'VEGETABLE DISHES', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070017176, 400070017, 'Veg. Schezwan', 'veg. schezwan', 'VEGETABLE DISHES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017177, 400070017, 'Veg. Chilly / Manchurian', 'veg. chilly / manchurian', 'VEGETABLE DISHES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017178, 400070017, 'Veg. Garlic / Ginger', 'veg. garlic / ginger', 'VEGETABLE DISHES', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070017179, 400070017, 'Veg. Sweet & Sour', 'veg. sweet & sour', 'VEGETABLE DISHES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017180, 400070017, 'Paneer Chilly', 'paneer chilly', 'VEGETABLE DISHES', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070017181, 400070017, 'Paneer Manchurian', 'paneer manchurian', 'VEGETABLE DISHES', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070017182, 400070017, 'Mushroom Chilly', 'mushroom chilly', 'VEGETABLE DISHES', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070017183, 400070017, 'Mushroom Manchurian', 'mushroom manchurian', 'VEGETABLE DISHES', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070017184, 400070017, 'Nasheman Spl. Soup', 'nasheman spl. soup', 'CHINESE SOUPS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017185, 400070017, 'Hot & Sour Soup', 'hot & sour soup', 'CHINESE SOUPS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017186, 400070017, 'Manchow Soup', 'manchow soup', 'CHINESE SOUPS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017187, 400070017, 'Noodles Soup', 'noodles soup', 'CHINESE SOUPS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017188, 400070017, 'Sweet Corn Soup', 'sweet corn soup', 'CHINESE SOUPS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017189, 400070017, 'Clear Soup', 'clear soup', 'CHINESE SOUPS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017190, 400070017, 'Chicken Lung Fung Soup', 'chicken lung fung soup', 'CHINESE SOUPS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017191, 400070017, 'Mutton Clear Soup', 'mutton clear soup', 'CHINESE SOUPS', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017192, 400070017, 'Tomato Soup', 'tomato soup', 'CHINESE SOUPS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017193, 400070017, 'Chicken Nasheman Spl. Fried Rice', 'chicken nasheman spl. fried rice', 'FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017194, 400070017, 'Chicken Fried Rice', 'chicken fried rice', 'FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017195, 400070017, 'Chi. Schezwan Fried Rice', 'chi. schezwan fried rice', 'FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017196, 400070017, 'Chi. Combination Fried Rice', 'chi. combination fried rice', 'FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017197, 400070017, 'Chi. Hong Kong Fried Rice', 'chi. hong kong fried rice', 'FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017198, 400070017, 'Mix Fried Rice', 'mix fried rice', 'FRIED RICE', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017199, 400070017, 'Mix Schezwan Fried Rice', 'mix schezwan fried rice', 'FRIED RICE', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017200, 400070017, 'Chi. Singapore Fried Rice', 'chi. singapore fried rice', 'FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017201, 400070017, 'Egg Fried Rice', 'egg fried rice', 'FRIED RICE', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017202, 400070017, 'Egg Schezwan Fried Rice', 'egg schezwan fried rice', 'FRIED RICE', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017203, 400070017, 'Veg. Fried Rice', 'veg. fried rice', 'FRIED RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017204, 400070017, 'Veg. Schezwan Fried Rice', 'veg. schezwan fried rice', 'FRIED RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017205, 400070017, 'Veg. Hong Kong Fried Rice', 'veg. hong kong fried rice', 'FRIED RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017206, 400070017, 'Veg. Singapore Fried Rice', 'veg. singapore fried rice', 'FRIED RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017207, 400070017, 'Veg. Nasheman Sp. Rice', 'veg. nasheman sp. rice', 'FRIED RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017208, 400070017, 'Veg. Manchurian Noodles', 'veg. manchurian noodles', 'FRIED RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017209, 400070017, 'Veg. Chilly Noodles', 'veg. chilly noodles', 'FRIED RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017210, 400070017, 'Veg. Tripple Noodles', 'veg. tripple noodles', 'FRIED RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017211, 400070017, 'Chi. American Chopsuey', 'chi. american chopsuey', 'FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017212, 400070017, 'Chinese Chopsuey', 'chinese chopsuey', 'FRIED RICE', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017213, 400070017, 'Veg. American Chopsuey', 'veg. american chopsuey', 'FRIED RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017214, 400070017, 'Chinese Chopsuey', 'chinese chopsuey', 'FRIED RICE', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017215, 400070017, 'Chicken Hakka Noodles', 'chicken hakka noodles', 'NOODLES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017216, 400070017, 'Chicken Schezwan Hakka Noodles', 'chicken schezwan hakka noodles', 'NOODLES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017217, 400070017, 'Chicken Singapore Noodles', 'chicken singapore noodles', 'NOODLES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017218, 400070017, 'Chi. Hong Kong Noodles', 'chi. hong kong noodles', 'NOODLES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017219, 400070017, 'Chicken Tripples Noodles', 'chicken tripples noodles', 'NOODLES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017220, 400070017, 'Chi. Manchurian Noodles', 'chi. manchurian noodles', 'NOODLES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017221, 400070017, 'Chicken Chilly Noodles', 'chicken chilly noodles', 'NOODLES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017222, 400070017, 'Mix Hakka Noodles', 'mix hakka noodles', 'NOODLES', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017223, 400070017, 'Mix Schn. Hakka Noodles', 'mix schn. hakka noodles', 'NOODLES', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017224, 400070017, 'Egg Hakka Noodles', 'egg hakka noodles', 'NOODLES', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017225, 400070017, 'Egg Schn. Hakka Noodles', 'egg schn. hakka noodles', 'NOODLES', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017226, 400070017, 'Veg. Hakka Noodles', 'veg. hakka noodles', 'NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017227, 400070017, 'Veg. Schn. Hakka Noodles', 'veg. schn. hakka noodles', 'NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017228, 400070017, 'Veg. Hong Kong Noodle', 'veg. hong kong noodle', 'NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017229, 400070017, 'Veg. Singapore Noodles', 'veg. singapore noodles', 'NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017230, 400070017, 'Chi. Nasheman Spl. Pizza', 'chi. nasheman spl. pizza', 'SNACKS / PIZZA', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017231, 400070017, 'Chicken Tikka Pizza', 'chicken tikka pizza', 'SNACKS / PIZZA', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017232, 400070017, 'Chicken Cheese Pizza', 'chicken cheese pizza', 'SNACKS / PIZZA', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017233, 400070017, 'Paneer Tikka Pizza', 'paneer tikka pizza', 'SNACKS / PIZZA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017234, 400070017, 'Mushroom Delight Pizza', 'mushroom delight pizza', 'SNACKS / PIZZA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017235, 400070017, 'Cheese Pizza', 'cheese pizza', 'SNACKS / PIZZA', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017236, 400070017, 'Mix. Pizza', 'mix. pizza', 'SNACKS / PIZZA', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017237, 400070017, 'Veg. Cheese Pizza', 'veg. cheese pizza', 'SNACKS / PIZZA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017238, 400070017, 'Extra Cheese', 'extra cheese', 'SNACKS / PIZZA', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017239, 400070017, 'Chicken Sandwich', 'chicken sandwich', 'SANDWICH', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017240, 400070017, 'Chi. Cheese Sandwich', 'chi. cheese sandwich', 'SANDWICH', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017241, 400070017, 'Chi. Grill Sandwich', 'chi. grill sandwich', 'SANDWICH', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017242, 400070017, 'Chi. Cheese Grill S/W', 'chi. cheese grill s/w', 'SANDWICH', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017243, 400070017, 'Omlet Sandwich', 'omlet sandwich', 'SANDWICH', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017244, 400070017, 'Veg. Cheese Sandwich', 'veg. cheese sandwich', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017245, 400070017, 'Veg. Sandwich', 'veg. sandwich', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017246, 400070017, 'Cheese Sandwich', 'cheese sandwich', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017247, 400070017, 'Veg. Grill Sandwich', 'veg. grill sandwich', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017248, 400070017, 'Veg. Cheese Grill S/W', 'veg. cheese grill s/w', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017249, 400070017, 'Bread Butter', 'bread butter', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017250, 400070017, 'Toast Butter', 'toast butter', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017251, 400070017, 'Veg. Pakoda', 'veg. pakoda', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017252, 400070017, 'Egg Sandwich', 'egg sandwich', 'SANDWICH', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017253, 400070017, 'Alu Chips', 'alu chips', 'SANDWICH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017254, 400070017, 'Mango Juice (Seasonal)', 'mango juice (seasonal)', 'FRESH FRUIT JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017255, 400070017, 'Anar Juice', 'anar juice', 'FRESH FRUIT JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017256, 400070017, 'Apple Juice', 'apple juice', 'FRESH FRUIT JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017257, 400070017, 'Pineapple Juice', 'pineapple juice', 'FRESH FRUIT JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017258, 400070017, 'Cocktail Juice', 'cocktail juice', 'FRESH FRUIT JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017259, 400070017, 'Carrot Juice', 'carrot juice', 'FRESH FRUIT JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017260, 400070017, 'Mosambi Juice', 'mosambi juice', 'FRESH FRUIT JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017261, 400070017, 'Beet Juice', 'beet juice', 'FRESH FRUIT JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017262, 400070017, 'Mango Milk Shake', 'mango milk shake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017263, 400070017, 'Kesar Pista Milk Shake', 'kesar pista milk shake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017264, 400070017, 'Dry Fruit Milk Shake', 'dry fruit milk shake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017265, 400070017, 'Apple Milk Shake', 'apple milk shake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017266, 400070017, 'Vanilla Milk Shake', 'vanilla milk shake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017267, 400070017, 'Strawberry Milk Shake', 'strawberry milk shake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017268, 400070017, 'Chocolate Milk Shake', 'chocolate milk shake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017269, 400070017, 'Cold Coffee', 'cold coffee', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017270, 400070017, 'Cold Coffee with V/Cream', 'cold coffee with v/cream', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017271, 400070017, 'Fruit Salad', 'fruit salad', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017272, 400070017, 'Fruit Salad with V/Cream', 'fruit salad with v/cream', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017273, 400070017, 'Nasheman ki Shaan', 'nasheman ki shaan', 'FALOODA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017274, 400070017, 'Rabdi Falooda', 'rabdi falooda', 'FALOODA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017275, 400070017, 'Mix Kulfi Falooda', 'mix kulfi falooda', 'FALOODA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017276, 400070017, 'Royal Falooda', 'royal falooda', 'FALOODA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017277, 400070017, 'Sp. Falooda / Kesar Falooda', 'sp. falooda / kesar falooda', 'FALOODA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017278, 400070017, 'Kaju Falooda/Rose Falooda', 'kaju falooda/rose falooda', 'FALOODA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017279, 400070017, 'Malai Kulfi', 'malai kulfi', 'SLICE & POT KULFI', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070017280, 400070017, 'Keser Pista', 'keser pista', 'SLICE & POT KULFI', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070017281, 400070017, 'Badam Pista', 'badam pista', 'SLICE & POT KULFI', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070017282, 400070017, 'Caramel Custard', 'caramel custard', 'DESSERTS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017283, 400070017, 'Sweet Lassi', 'sweet lassi', 'DESSERTS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017284, 400070017, 'Sp. Lassi', 'sp. lassi', 'DESSERTS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017285, 400070017, 'Dry Fruit Lassi/Mango Lassi', 'dry fruit lassi/mango lassi', 'DESSERTS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017286, 400070017, 'Butter Milk (Chaas)', 'butter milk (chaas)', 'DESSERTS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017287, 400070017, 'Mineral Water', 'mineral water', 'COLD DRINKS', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070017288, 400070017, 'All Soft Drinks (300 ml)', 'all soft drinks (300 ml)', 'COLD DRINKS', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070017289, 400070017, 'All Soft Drinks (500 ml, 2 ltr)', 'all soft drinks (500 ml, 2 ltr)', 'COLD DRINKS', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070017290, 400070017, 'Fresh Lime Juice', 'fresh lime juice', 'COLD DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017291, 400070017, 'Fresh Lime Soda', 'fresh lime soda', 'COLD DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017292, 400070017, 'Sikanjbin Sharbat', 'sikanjbin sharbat', 'COLD DRINKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017293, 400070017, 'Soda', 'soda', 'COLD DRINKS', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070017294, 400070017, 'Chicken Biryani (Per Pailee) (3 Kg Rice + 3 Kg Chicken)', 'chicken biryani (per pailee) (3 kg rice + 3 kg chicken)', 'NASHEMAN CATERERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017295, 400070017, 'Chicken Biryani (Per Kg) (1 Kg Rice + 1 Kg Chicken)', 'chicken biryani (per kg) (1 kg rice + 1 kg chicken)', 'NASHEMAN CATERERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017296, 400070017, 'Mutton Biryani (Per Pailee) (3 Kg Rice + 3 Kg Mutton)', 'mutton biryani (per pailee) (3 kg rice + 3 kg mutton)', 'NASHEMAN CATERERS', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017297, 400070017, 'Mutton Biryani (Per Kg) (1 Kg Rice + 1 Kg Mutton)', 'mutton biryani (per kg) (1 kg rice + 1 kg mutton)', 'NASHEMAN CATERERS', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017298, 400070017, 'Chicken Tikka Biryani (1 Kg)', 'chicken tikka biryani (1 kg)', 'NASHEMAN CATERERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017299, 400070017, 'Mutton Pulao Bone (1 Kg)', 'mutton pulao bone (1 kg)', 'NASHEMAN CATERERS', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017300, 400070017, 'Chicken Pulao Bone (1 Kg)', 'chicken pulao bone (1 kg)', 'NASHEMAN CATERERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017301, 400070017, 'Veg. Biryani / Veg. Pulao (1 Kg)', 'veg. biryani / veg. pulao (1 kg)', 'NASHEMAN CATERERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070017302, 400070017, 'Dal Gosht (1 Kg) / Mutton Korma (1 Kg)', 'dal gosht (1 kg) / mutton korma (1 kg)', 'NASHEMAN CATERERS', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017303, 400070017, 'Chicken Fried Rice (1 Kg)', 'chicken fried rice (1 kg)', 'NASHEMAN CATERERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017304, 400070017, 'Kheema (1 Kg)', 'kheema (1 kg)', 'NASHEMAN CATERERS', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070017305, 400070017, 'Chicken Korma (1 Kg)', 'chicken korma (1 kg)', 'NASHEMAN CATERERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070017306, 400070017, 'Jeera Rice (1 Kg)', 'jeera rice (1 kg)', 'NASHEMAN CATERERS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070017307, 400070017, 'Rice (1 kg)', 'rice (1 kg)', 'NASHEMAN CATERERS', NULL::text, NULL::text, NULL::text, 'needs_review')
) AS x(menu_item_id, restaurant_id, name, normalized_name, raw_category_text, food_classification_code, protein_code, split_group_key, verification_status_code)
JOIN canonical_dish cd ON cd.normalized_name = x.normalized_name
LEFT JOIN protein_type pt ON pt.code = x.protein_code;

-- Menu item source: name/existence confidence, kept separate from price confidence.
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
VALUES
    (400070017001, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017002, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017003, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017004, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017005, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017006, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017007, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017008, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017009, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017010, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017011, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017012, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017013, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017014, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017015, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017016, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017017, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017018, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017019, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017020, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017021, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017022, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017023, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017024, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017025, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017026, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017027, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017028, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017029, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017030, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017031, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017032, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017033, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017034, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017035, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017036, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017037, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017038, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017039, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017040, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017041, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017042, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017043, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017044, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017045, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017046, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017047, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017048, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017049, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017050, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017051, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017052, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017053, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017054, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017055, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017056, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017057, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017058, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017059, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017060, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017061, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017062, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017063, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017064, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017065, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017066, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017067, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017068, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017069, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017070, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017071, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017072, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017073, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017074, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017075, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017076, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017077, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017078, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017079, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017080, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017081, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017082, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017083, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017084, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017085, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017086, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017087, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017088, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017089, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017090, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017091, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017092, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017093, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017094, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017095, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017096, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017097, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017098, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017099, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017100, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017101, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017102, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017103, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017104, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017105, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017106, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017107, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017108, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017109, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017110, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017111, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017112, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017113, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017114, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017115, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017116, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017117, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017118, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017119, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017120, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017121, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017122, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017123, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017124, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017125, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017126, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017127, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017128, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017129, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017130, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017131, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017132, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017133, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017134, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017135, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017136, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017137, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017138, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017139, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017140, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017141, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017142, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017143, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017144, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017145, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017146, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017147, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017148, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017149, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017150, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017151, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017152, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017153, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017154, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017155, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017156, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017157, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017158, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017159, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017160, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017161, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017162, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017163, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017164, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017165, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017166, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017167, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017168, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017169, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017170, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017171, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017172, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017173, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017174, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017175, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017176, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017177, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017178, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017179, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017180, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017181, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017182, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017183, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017184, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017185, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017186, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017187, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017188, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017189, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017190, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017191, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017192, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017193, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017194, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017195, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017196, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017197, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017198, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017199, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017200, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017201, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017202, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017203, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017204, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017205, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017206, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017207, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017208, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017209, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017210, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017211, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017212, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017213, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017214, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017215, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017216, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017217, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017218, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017219, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017220, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017221, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017222, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017223, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017224, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017225, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017226, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017227, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017228, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017229, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017230, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017231, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017232, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017233, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017234, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017235, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017236, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017237, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017238, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017239, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017240, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017241, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017242, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017243, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017244, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017245, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017246, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017247, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017248, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017249, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017250, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017251, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017252, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017253, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017254, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017255, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017256, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017257, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017258, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017259, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017260, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017261, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017262, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017263, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017264, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017265, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017266, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017267, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017268, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017269, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017270, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017271, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017272, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017273, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017274, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017275, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017276, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017277, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017278, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017279, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017280, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017281, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017282, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017283, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017284, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017285, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017286, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017287, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017288, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017289, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017290, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017291, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017292, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017293, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017294, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017295, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017296, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017297, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017298, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017299, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017300, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017301, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017302, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017303, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017304, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017305, 400070017, :extraction_batch_id, 0.9, 'unverified'),
    (400070017306, 400070017, :extraction_batch_id, 0.9, 'needs_review'),
    (400070017307, 400070017, :extraction_batch_id, 0.9, 'needs_review');

-- Variants (portion/label variants -- one menu_item, multiple menu_item_variant rows;
-- a protein/veg split already became two separate menu_item rows above, so each carries
-- exactly one variant here).
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
VALUES
    (400070017001, 400070017001, 'Full', 'fixed', TRUE),
    (400070017002, 400070017001, 'Half', 'fixed', FALSE),
    (400070017003, 400070017002, 'Full', 'fixed', TRUE),
    (400070017004, 400070017002, 'Half', 'fixed', FALSE),
    (400070017005, 400070017003, 'Regular', 'fixed', TRUE),
    (400070017006, 400070017004, 'Regular', 'fixed', TRUE),
    (400070017007, 400070017005, 'Regular', 'fixed', TRUE),
    (400070017008, 400070017006, 'Regular', 'fixed', TRUE),
    (400070017009, 400070017007, 'Regular', 'fixed', TRUE),
    (400070017010, 400070017008, 'Regular', 'fixed', TRUE),
    (400070017011, 400070017009, 'Regular', 'fixed', TRUE),
    (400070017012, 400070017010, 'Regular', 'fixed', TRUE),
    (400070017013, 400070017011, 'Regular', 'fixed', TRUE),
    (400070017014, 400070017012, 'Regular', 'fixed', TRUE),
    (400070017015, 400070017013, 'Regular', 'fixed', TRUE),
    (400070017016, 400070017014, 'Regular', 'fixed', TRUE),
    (400070017017, 400070017015, 'Regular', 'fixed', TRUE),
    (400070017018, 400070017016, 'Regular', 'fixed', TRUE),
    (400070017019, 400070017017, 'Regular', 'fixed', TRUE),
    (400070017020, 400070017018, 'Regular', 'fixed', TRUE),
    (400070017021, 400070017019, 'Regular', 'fixed', TRUE),
    (400070017022, 400070017020, 'Regular', 'fixed', TRUE),
    (400070017023, 400070017021, 'Regular', 'fixed', TRUE),
    (400070017024, 400070017022, 'Regular', 'fixed', TRUE),
    (400070017025, 400070017023, 'Regular', 'fixed', TRUE),
    (400070017026, 400070017024, 'Regular', 'fixed', TRUE),
    (400070017027, 400070017025, 'Regular', 'fixed', TRUE),
    (400070017028, 400070017026, 'Regular', 'fixed', TRUE),
    (400070017029, 400070017027, 'Regular', 'fixed', TRUE),
    (400070017030, 400070017028, 'Regular', 'fixed', TRUE),
    (400070017031, 400070017029, 'Regular', 'fixed', TRUE),
    (400070017032, 400070017030, 'Regular', 'fixed', TRUE),
    (400070017033, 400070017031, 'Regular', 'fixed', TRUE),
    (400070017034, 400070017032, 'Regular', 'fixed', TRUE),
    (400070017035, 400070017033, 'Regular', 'fixed', TRUE),
    (400070017036, 400070017034, 'Regular', 'fixed', TRUE),
    (400070017037, 400070017035, 'Regular', 'fixed', TRUE),
    (400070017038, 400070017036, 'Regular', 'fixed', TRUE),
    (400070017039, 400070017037, 'Regular', 'fixed', TRUE),
    (400070017040, 400070017038, 'Regular', 'fixed', TRUE),
    (400070017041, 400070017039, 'Regular', 'fixed', TRUE),
    (400070017042, 400070017040, 'Regular', 'fixed', TRUE),
    (400070017043, 400070017041, 'Regular', 'fixed', TRUE),
    (400070017044, 400070017042, 'Regular', 'fixed', TRUE),
    (400070017045, 400070017043, 'Regular', 'fixed', TRUE),
    (400070017046, 400070017044, 'Regular', 'fixed', TRUE),
    (400070017047, 400070017045, 'Regular', 'fixed', TRUE),
    (400070017048, 400070017046, 'Regular', 'fixed', TRUE),
    (400070017049, 400070017047, 'Regular', 'fixed', TRUE),
    (400070017050, 400070017048, 'Regular', 'fixed', TRUE),
    (400070017051, 400070017049, 'Regular', 'fixed', TRUE),
    (400070017052, 400070017050, 'Regular', 'fixed', TRUE),
    (400070017053, 400070017051, 'Regular', 'fixed', TRUE),
    (400070017054, 400070017052, 'Regular', 'fixed', TRUE),
    (400070017055, 400070017053, 'Regular', 'fixed', TRUE),
    (400070017056, 400070017054, 'Regular', 'fixed', TRUE),
    (400070017057, 400070017055, 'Regular', 'fixed', TRUE),
    (400070017058, 400070017056, 'Regular', 'fixed', TRUE),
    (400070017059, 400070017057, 'Regular', 'fixed', TRUE),
    (400070017060, 400070017058, 'Regular', 'fixed', TRUE),
    (400070017061, 400070017059, 'Regular', 'fixed', TRUE),
    (400070017062, 400070017060, 'Regular', 'fixed', TRUE),
    (400070017063, 400070017061, 'Regular', 'fixed', TRUE),
    (400070017064, 400070017062, 'Regular', 'fixed', TRUE),
    (400070017065, 400070017063, 'Regular', 'fixed', TRUE),
    (400070017066, 400070017064, 'Regular', 'fixed', TRUE),
    (400070017067, 400070017065, 'Regular', 'fixed', TRUE),
    (400070017068, 400070017066, 'Regular', 'fixed', TRUE),
    (400070017069, 400070017067, 'Regular', 'fixed', TRUE),
    (400070017070, 400070017068, 'Regular', 'fixed', TRUE),
    (400070017071, 400070017069, 'Regular', 'fixed', TRUE),
    (400070017072, 400070017070, 'Regular', 'fixed', TRUE),
    (400070017073, 400070017071, 'Regular', 'fixed', TRUE),
    (400070017074, 400070017072, 'Regular', 'fixed', TRUE),
    (400070017075, 400070017073, 'Regular', 'fixed', TRUE),
    (400070017076, 400070017074, 'Regular', 'fixed', TRUE),
    (400070017077, 400070017075, 'Regular', 'fixed', TRUE),
    (400070017078, 400070017076, 'Regular', 'fixed', TRUE),
    (400070017079, 400070017077, 'Regular', 'fixed', TRUE),
    (400070017080, 400070017078, 'Regular', 'fixed', TRUE),
    (400070017081, 400070017079, 'Regular', 'fixed', TRUE),
    (400070017082, 400070017080, 'Regular', 'fixed', TRUE),
    (400070017083, 400070017081, 'Regular', 'fixed', TRUE),
    (400070017084, 400070017082, 'Regular', 'fixed', TRUE),
    (400070017085, 400070017083, 'Regular', 'fixed', TRUE),
    (400070017086, 400070017084, 'Regular', 'fixed', TRUE),
    (400070017087, 400070017085, 'Regular', 'fixed', TRUE),
    (400070017088, 400070017086, 'Regular', 'fixed', TRUE),
    (400070017089, 400070017087, 'Regular', 'fixed', TRUE),
    (400070017090, 400070017088, 'Regular', 'fixed', TRUE),
    (400070017091, 400070017089, 'Regular', 'fixed', TRUE),
    (400070017092, 400070017090, 'Regular', 'fixed', TRUE),
    (400070017093, 400070017091, 'Regular', 'fixed', TRUE),
    (400070017094, 400070017092, 'Regular', 'fixed', TRUE),
    (400070017095, 400070017093, 'Regular', 'fixed', TRUE),
    (400070017096, 400070017094, 'Regular', 'fixed', TRUE),
    (400070017097, 400070017095, 'Regular', 'fixed', TRUE),
    (400070017098, 400070017096, 'Regular', 'fixed', TRUE),
    (400070017099, 400070017097, 'Regular', 'fixed', TRUE),
    (400070017100, 400070017098, 'Regular', 'fixed', TRUE),
    (400070017101, 400070017099, 'Regular', 'fixed', TRUE),
    (400070017102, 400070017100, 'Regular', 'fixed', TRUE),
    (400070017103, 400070017101, 'Regular', 'fixed', TRUE),
    (400070017104, 400070017102, 'Regular', 'fixed', TRUE),
    (400070017105, 400070017103, 'Regular', 'fixed', TRUE),
    (400070017106, 400070017104, 'Regular', 'fixed', TRUE),
    (400070017107, 400070017105, 'Regular', 'fixed', TRUE),
    (400070017108, 400070017106, 'Regular', 'fixed', TRUE),
    (400070017109, 400070017107, 'Regular', 'fixed', TRUE),
    (400070017110, 400070017108, 'Regular', 'fixed', TRUE),
    (400070017111, 400070017109, 'Regular', 'fixed', TRUE),
    (400070017112, 400070017110, 'Regular', 'fixed', TRUE),
    (400070017113, 400070017111, 'Regular', 'fixed', TRUE),
    (400070017114, 400070017112, 'Regular', 'fixed', TRUE),
    (400070017115, 400070017113, 'Regular', 'fixed', TRUE),
    (400070017116, 400070017114, 'Regular', 'fixed', TRUE),
    (400070017117, 400070017115, 'Regular', 'fixed', TRUE),
    (400070017118, 400070017116, 'Regular', 'fixed', TRUE),
    (400070017119, 400070017117, 'Regular', 'fixed', TRUE),
    (400070017120, 400070017118, 'Regular', 'fixed', TRUE),
    (400070017121, 400070017119, 'Regular', 'fixed', TRUE),
    (400070017122, 400070017120, 'Regular', 'fixed', TRUE),
    (400070017123, 400070017121, 'Regular', 'fixed', TRUE),
    (400070017124, 400070017122, 'Regular', 'fixed', TRUE),
    (400070017125, 400070017123, 'Regular', 'fixed', TRUE),
    (400070017126, 400070017124, 'Regular', 'fixed', TRUE),
    (400070017127, 400070017125, 'Regular', 'fixed', TRUE),
    (400070017128, 400070017126, 'Regular', 'fixed', TRUE),
    (400070017129, 400070017127, 'Regular', 'fixed', TRUE),
    (400070017130, 400070017128, 'Regular', 'fixed', TRUE),
    (400070017131, 400070017129, 'Regular', 'fixed', TRUE),
    (400070017132, 400070017130, 'Regular', 'fixed', TRUE),
    (400070017133, 400070017131, 'Regular', 'fixed', TRUE),
    (400070017134, 400070017132, 'Regular', 'fixed', TRUE),
    (400070017135, 400070017133, 'Regular', 'fixed', TRUE),
    (400070017136, 400070017134, 'Regular', 'fixed', TRUE),
    (400070017137, 400070017135, 'Regular', 'fixed', TRUE),
    (400070017138, 400070017136, 'Regular', 'fixed', TRUE),
    (400070017139, 400070017137, 'Regular', 'fixed', TRUE),
    (400070017140, 400070017138, 'Regular', 'fixed', TRUE),
    (400070017141, 400070017139, 'Regular', 'fixed', TRUE),
    (400070017142, 400070017140, 'Regular', 'fixed', TRUE),
    (400070017143, 400070017141, 'Regular', 'fixed', TRUE),
    (400070017144, 400070017142, 'Regular', 'fixed', TRUE),
    (400070017145, 400070017143, 'Full', 'fixed', TRUE),
    (400070017146, 400070017143, 'Half', 'fixed', FALSE),
    (400070017147, 400070017144, 'Regular', 'fixed', TRUE),
    (400070017148, 400070017145, 'Regular', 'fixed', TRUE),
    (400070017149, 400070017146, 'Regular', 'fixed', TRUE),
    (400070017150, 400070017147, 'Regular', 'fixed', TRUE),
    (400070017151, 400070017148, 'Regular', 'fixed', TRUE),
    (400070017152, 400070017149, 'Regular', 'fixed', TRUE),
    (400070017153, 400070017150, 'Regular', 'fixed', TRUE),
    (400070017154, 400070017151, 'Regular', 'fixed', TRUE),
    (400070017155, 400070017152, 'Regular', 'fixed', TRUE),
    (400070017156, 400070017153, 'Regular', 'fixed', TRUE),
    (400070017157, 400070017154, 'Regular', 'fixed', TRUE),
    (400070017158, 400070017155, 'Regular', 'fixed', TRUE),
    (400070017159, 400070017156, 'Regular', 'fixed', TRUE),
    (400070017160, 400070017157, 'Regular', 'fixed', TRUE),
    (400070017161, 400070017158, 'Regular', 'fixed', TRUE),
    (400070017162, 400070017159, 'Regular', 'fixed', TRUE),
    (400070017163, 400070017160, 'Regular', 'fixed', TRUE),
    (400070017164, 400070017161, 'Full', 'fixed', TRUE),
    (400070017165, 400070017161, 'Half', 'fixed', FALSE),
    (400070017166, 400070017162, 'Regular', 'fixed', TRUE),
    (400070017167, 400070017163, 'Regular', 'fixed', TRUE),
    (400070017168, 400070017164, 'Regular', 'fixed', TRUE),
    (400070017169, 400070017165, 'Regular', 'fixed', TRUE),
    (400070017170, 400070017166, 'Regular', 'fixed', TRUE),
    (400070017171, 400070017167, 'Regular', 'fixed', TRUE),
    (400070017172, 400070017168, 'Regular', 'fixed', TRUE),
    (400070017173, 400070017169, 'Regular', 'fixed', TRUE),
    (400070017174, 400070017170, 'Regular', 'fixed', TRUE),
    (400070017175, 400070017171, 'Regular', 'fixed', TRUE),
    (400070017176, 400070017172, 'Regular', 'fixed', TRUE),
    (400070017177, 400070017173, 'Regular', 'fixed', TRUE),
    (400070017178, 400070017174, 'Full', 'fixed', TRUE),
    (400070017179, 400070017174, 'Half', 'fixed', FALSE),
    (400070017180, 400070017175, 'Full', 'fixed', TRUE),
    (400070017181, 400070017175, 'Half', 'fixed', FALSE),
    (400070017182, 400070017176, 'Regular', 'fixed', TRUE),
    (400070017183, 400070017177, 'Regular', 'fixed', TRUE),
    (400070017184, 400070017178, 'Full', 'fixed', TRUE),
    (400070017185, 400070017178, 'Half', 'fixed', FALSE),
    (400070017186, 400070017179, 'Regular', 'fixed', TRUE),
    (400070017187, 400070017180, 'Full', 'fixed', TRUE),
    (400070017188, 400070017180, 'Half', 'fixed', FALSE),
    (400070017189, 400070017181, 'Full', 'fixed', TRUE),
    (400070017190, 400070017181, 'Half', 'fixed', FALSE),
    (400070017191, 400070017182, 'Full', 'fixed', TRUE),
    (400070017192, 400070017182, 'Half', 'fixed', FALSE),
    (400070017193, 400070017183, 'Full', 'fixed', TRUE),
    (400070017194, 400070017183, 'Half', 'fixed', FALSE),
    (400070017195, 400070017184, 'Full', 'fixed', TRUE),
    (400070017196, 400070017184, 'Half', 'fixed', FALSE),
    (400070017197, 400070017185, 'Full', 'fixed', TRUE),
    (400070017198, 400070017185, 'Half', 'fixed', FALSE),
    (400070017199, 400070017186, 'Full', 'fixed', TRUE),
    (400070017200, 400070017186, 'Half', 'fixed', FALSE),
    (400070017201, 400070017187, 'Full', 'fixed', TRUE),
    (400070017202, 400070017187, 'Half', 'fixed', FALSE),
    (400070017203, 400070017188, 'Full', 'fixed', TRUE),
    (400070017204, 400070017188, 'Half', 'fixed', FALSE),
    (400070017205, 400070017189, 'Full', 'fixed', TRUE),
    (400070017206, 400070017189, 'Half', 'fixed', FALSE),
    (400070017207, 400070017190, 'Regular', 'fixed', TRUE),
    (400070017208, 400070017191, 'Regular', 'fixed', TRUE),
    (400070017209, 400070017192, 'Regular', 'fixed', TRUE),
    (400070017210, 400070017193, 'Regular', 'fixed', TRUE),
    (400070017211, 400070017194, 'Regular', 'fixed', TRUE),
    (400070017212, 400070017195, 'Regular', 'fixed', TRUE),
    (400070017213, 400070017196, 'Regular', 'fixed', TRUE),
    (400070017214, 400070017197, 'Regular', 'fixed', TRUE),
    (400070017215, 400070017198, 'Regular', 'fixed', TRUE),
    (400070017216, 400070017199, 'Regular', 'fixed', TRUE),
    (400070017217, 400070017200, 'Regular', 'fixed', TRUE),
    (400070017218, 400070017201, 'Regular', 'fixed', TRUE),
    (400070017219, 400070017202, 'Regular', 'fixed', TRUE),
    (400070017220, 400070017203, 'Regular', 'fixed', TRUE),
    (400070017221, 400070017204, 'Regular', 'fixed', TRUE),
    (400070017222, 400070017205, 'Regular', 'fixed', TRUE),
    (400070017223, 400070017206, 'Regular', 'fixed', TRUE),
    (400070017224, 400070017207, 'Regular', 'fixed', TRUE),
    (400070017225, 400070017208, 'Regular', 'fixed', TRUE),
    (400070017226, 400070017209, 'Regular', 'fixed', TRUE),
    (400070017227, 400070017210, 'Regular', 'fixed', TRUE),
    (400070017228, 400070017211, 'Regular', 'fixed', TRUE),
    (400070017229, 400070017212, 'Regular', 'fixed', TRUE),
    (400070017230, 400070017213, 'Regular', 'fixed', TRUE),
    (400070017231, 400070017214, 'Regular', 'fixed', TRUE),
    (400070017232, 400070017215, 'Regular', 'fixed', TRUE),
    (400070017233, 400070017216, 'Regular', 'fixed', TRUE),
    (400070017234, 400070017217, 'Regular', 'fixed', TRUE),
    (400070017235, 400070017218, 'Regular', 'fixed', TRUE),
    (400070017236, 400070017219, 'Regular', 'fixed', TRUE),
    (400070017237, 400070017220, 'Regular', 'fixed', TRUE),
    (400070017238, 400070017221, 'Regular', 'fixed', TRUE),
    (400070017239, 400070017222, 'Regular', 'fixed', TRUE),
    (400070017240, 400070017223, 'Regular', 'fixed', TRUE),
    (400070017241, 400070017224, 'Regular', 'fixed', TRUE),
    (400070017242, 400070017225, 'Regular', 'fixed', TRUE),
    (400070017243, 400070017226, 'Regular', 'fixed', TRUE),
    (400070017244, 400070017227, 'Regular', 'fixed', TRUE),
    (400070017245, 400070017228, 'Regular', 'fixed', TRUE),
    (400070017246, 400070017229, 'Regular', 'fixed', TRUE),
    (400070017247, 400070017230, 'Regular', 'fixed', TRUE),
    (400070017248, 400070017231, 'Regular', 'fixed', TRUE),
    (400070017249, 400070017232, 'Regular', 'fixed', TRUE),
    (400070017250, 400070017233, 'Regular', 'fixed', TRUE),
    (400070017251, 400070017234, 'Regular', 'fixed', TRUE),
    (400070017252, 400070017235, 'Regular', 'fixed', TRUE),
    (400070017253, 400070017236, 'Regular', 'fixed', TRUE),
    (400070017254, 400070017237, 'Regular', 'fixed', TRUE),
    (400070017255, 400070017238, 'Regular', 'fixed', TRUE),
    (400070017256, 400070017239, 'Regular', 'fixed', TRUE),
    (400070017257, 400070017240, 'Regular', 'fixed', TRUE),
    (400070017258, 400070017241, 'Regular', 'fixed', TRUE),
    (400070017259, 400070017242, 'Regular', 'fixed', TRUE),
    (400070017260, 400070017243, 'Regular', 'fixed', TRUE),
    (400070017261, 400070017244, 'Regular', 'fixed', TRUE),
    (400070017262, 400070017245, 'Regular', 'fixed', TRUE),
    (400070017263, 400070017246, 'Regular', 'fixed', TRUE),
    (400070017264, 400070017247, 'Regular', 'fixed', TRUE),
    (400070017265, 400070017248, 'Regular', 'fixed', TRUE),
    (400070017266, 400070017249, 'Regular', 'fixed', TRUE),
    (400070017267, 400070017250, 'Regular', 'fixed', TRUE),
    (400070017268, 400070017251, 'Regular', 'fixed', TRUE),
    (400070017269, 400070017252, 'Regular', 'fixed', TRUE),
    (400070017270, 400070017253, 'Regular', 'fixed', TRUE),
    (400070017271, 400070017254, 'Regular', 'fixed', TRUE),
    (400070017272, 400070017255, 'Regular', 'fixed', TRUE),
    (400070017273, 400070017256, 'Regular', 'fixed', TRUE),
    (400070017274, 400070017257, 'Regular', 'fixed', TRUE),
    (400070017275, 400070017258, 'Regular', 'fixed', TRUE),
    (400070017276, 400070017259, 'Regular', 'fixed', TRUE),
    (400070017277, 400070017260, 'Regular', 'fixed', TRUE),
    (400070017278, 400070017261, 'Regular', 'fixed', TRUE),
    (400070017279, 400070017262, 'Regular', 'fixed', TRUE),
    (400070017280, 400070017263, 'Regular', 'fixed', TRUE),
    (400070017281, 400070017264, 'Regular', 'fixed', TRUE),
    (400070017282, 400070017265, 'Regular', 'fixed', TRUE),
    (400070017283, 400070017266, 'Regular', 'fixed', TRUE),
    (400070017284, 400070017267, 'Regular', 'fixed', TRUE),
    (400070017285, 400070017268, 'Regular', 'fixed', TRUE),
    (400070017286, 400070017269, 'Regular', 'fixed', TRUE),
    (400070017287, 400070017270, 'Regular', 'fixed', TRUE),
    (400070017288, 400070017271, 'Regular', 'fixed', TRUE),
    (400070017289, 400070017272, 'Regular', 'fixed', TRUE),
    (400070017290, 400070017273, 'Regular', 'fixed', TRUE),
    (400070017291, 400070017274, 'Regular', 'fixed', TRUE),
    (400070017292, 400070017275, 'Regular', 'fixed', TRUE),
    (400070017293, 400070017276, 'Regular', 'fixed', TRUE),
    (400070017294, 400070017277, 'Regular', 'fixed', TRUE),
    (400070017295, 400070017278, 'Regular', 'fixed', TRUE),
    (400070017296, 400070017279, 'Regular', 'fixed', TRUE),
    (400070017297, 400070017280, 'Regular', 'fixed', TRUE),
    (400070017298, 400070017281, 'Regular', 'fixed', TRUE),
    (400070017299, 400070017282, 'Regular', 'fixed', TRUE),
    (400070017300, 400070017283, 'Regular', 'fixed', TRUE),
    (400070017301, 400070017284, 'Regular', 'fixed', TRUE),
    (400070017302, 400070017285, 'Regular', 'fixed', TRUE),
    (400070017303, 400070017286, 'Regular', 'fixed', TRUE),
    (400070017304, 400070017287, 'Regular', 'fixed', TRUE),
    (400070017305, 400070017288, 'Regular', 'fixed', TRUE),
    (400070017306, 400070017289, 'Regular', 'fixed', TRUE),
    (400070017307, 400070017290, 'Regular', 'fixed', TRUE),
    (400070017308, 400070017291, 'Regular', 'fixed', TRUE),
    (400070017309, 400070017292, 'Regular', 'fixed', TRUE),
    (400070017310, 400070017293, 'Regular', 'fixed', TRUE),
    (400070017311, 400070017294, 'Regular', 'fixed', TRUE),
    (400070017312, 400070017295, 'Regular', 'fixed', TRUE),
    (400070017313, 400070017296, 'Regular', 'fixed', TRUE),
    (400070017314, 400070017297, 'Regular', 'fixed', TRUE),
    (400070017315, 400070017298, 'Regular', 'fixed', TRUE),
    (400070017316, 400070017299, 'Regular', 'fixed', TRUE),
    (400070017317, 400070017300, 'Regular', 'fixed', TRUE),
    (400070017318, 400070017301, 'Regular', 'fixed', TRUE),
    (400070017319, 400070017302, 'Regular', 'fixed', TRUE),
    (400070017320, 400070017303, 'Regular', 'fixed', TRUE),
    (400070017321, 400070017304, 'Regular', 'fixed', TRUE),
    (400070017322, 400070017305, 'Regular', 'fixed', TRUE),
    (400070017323, 400070017306, 'Regular', 'fixed', TRUE),
    (400070017324, 400070017307, 'Regular', 'fixed', TRUE);

-- Prices (only for variants where a numeric price was actually captured)
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
VALUES
    (400070017001, 400070017001, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017002, 400070017002, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017003, 400070017003, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017004, 400070017004, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017005, 400070017005, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017006, 400070017006, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017007, 400070017007, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017008, 400070017008, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017009, 400070017009, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017010, 400070017010, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017011, 400070017011, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017012, 400070017012, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017013, 400070017013, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017014, 400070017014, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017015, 400070017015, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017016, 400070017016, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017017, 400070017017, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017018, 400070017018, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017019, 400070017019, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017020, 400070017020, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017021, 400070017021, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017022, 400070017022, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017023, 400070017023, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017024, 400070017024, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017025, 400070017025, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017026, 400070017026, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017027, 400070017027, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017028, 400070017028, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017029, 400070017029, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017030, 400070017030, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017031, 400070017031, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017032, 400070017032, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017033, 400070017033, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017034, 400070017034, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017035, 400070017035, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017036, 400070017036, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017037, 400070017037, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017038, 400070017038, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017039, 400070017039, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017040, 400070017040, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017041, 400070017041, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017042, 400070017042, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017043, 400070017043, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017044, 400070017044, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017045, 400070017045, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017046, 400070017046, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017047, 400070017047, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017048, 400070017048, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017049, 400070017049, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017050, 400070017050, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017051, 400070017051, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017052, 400070017052, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017053, 400070017053, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017054, 400070017054, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017055, 400070017055, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017056, 400070017056, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017057, 400070017057, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017058, 400070017058, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017059, 400070017059, 105.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017060, 400070017060, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017061, 400070017061, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017062, 400070017062, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017063, 400070017063, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017064, 400070017064, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017065, 400070017065, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017066, 400070017066, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017067, 400070017067, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017068, 400070017068, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017069, 400070017069, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017070, 400070017070, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017071, 400070017071, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017072, 400070017072, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017073, 400070017073, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017074, 400070017074, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017075, 400070017075, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017076, 400070017076, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017077, 400070017077, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017078, 400070017078, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017079, 400070017079, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017080, 400070017080, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017081, 400070017081, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017082, 400070017082, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017083, 400070017083, 115.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017084, 400070017084, 125.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017085, 400070017085, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017086, 400070017086, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017087, 400070017087, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017088, 400070017088, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017089, 400070017089, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017090, 400070017090, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017091, 400070017091, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017092, 400070017092, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017093, 400070017093, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017094, 400070017094, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017095, 400070017095, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017096, 400070017096, 12.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017097, 400070017097, 17.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017098, 400070017098, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017099, 400070017099, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017100, 400070017100, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017101, 400070017101, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017102, 400070017102, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017103, 400070017103, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017104, 400070017104, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017105, 400070017105, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017106, 400070017106, 10.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017107, 400070017107, 15.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017108, 400070017108, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017109, 400070017109, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017110, 400070017110, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017111, 400070017111, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017112, 400070017112, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017113, 400070017113, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017114, 400070017114, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017115, 400070017115, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017116, 400070017116, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017117, 400070017117, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017118, 400070017118, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017119, 400070017119, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017120, 400070017120, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017121, 400070017121, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017122, 400070017122, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017123, 400070017123, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017124, 400070017124, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017125, 400070017125, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017126, 400070017126, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017127, 400070017127, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017128, 400070017128, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017129, 400070017129, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017130, 400070017130, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017131, 400070017131, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017132, 400070017132, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017133, 400070017133, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017134, 400070017134, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017135, 400070017135, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017136, 400070017136, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017137, 400070017137, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017138, 400070017138, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017139, 400070017139, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017140, 400070017140, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017141, 400070017141, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017142, 400070017142, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017143, 400070017143, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017144, 400070017144, 15.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017145, 400070017145, 850.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017146, 400070017146, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017147, 400070017147, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017148, 400070017148, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017149, 400070017149, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017150, 400070017150, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017151, 400070017151, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017152, 400070017152, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017153, 400070017153, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017154, 400070017154, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017155, 400070017155, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017156, 400070017156, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017157, 400070017157, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017158, 400070017158, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017159, 400070017159, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017160, 400070017160, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017161, 400070017161, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017162, 400070017162, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017163, 400070017163, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017164, 400070017164, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017165, 400070017165, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017166, 400070017166, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017167, 400070017167, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017168, 400070017168, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017169, 400070017169, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017170, 400070017170, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017171, 400070017171, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017172, 400070017172, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017173, 400070017173, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017174, 400070017174, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017175, 400070017175, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017176, 400070017176, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017177, 400070017177, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017178, 400070017178, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017179, 400070017179, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017180, 400070017180, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017181, 400070017181, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017182, 400070017182, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017183, 400070017183, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017184, 400070017184, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017185, 400070017185, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017186, 400070017186, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017187, 400070017187, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017188, 400070017188, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017189, 400070017189, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017190, 400070017190, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017191, 400070017191, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017192, 400070017192, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017193, 400070017193, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017194, 400070017194, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017195, 400070017195, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017196, 400070017196, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017197, 400070017197, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017198, 400070017198, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017199, 400070017199, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017200, 400070017200, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017201, 400070017201, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017202, 400070017202, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017203, 400070017203, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017204, 400070017204, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017205, 400070017205, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017206, 400070017206, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'needs_review'),
    (400070017207, 400070017207, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017208, 400070017208, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017209, 400070017209, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017210, 400070017210, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017211, 400070017211, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017212, 400070017212, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017213, 400070017213, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017214, 400070017214, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017215, 400070017215, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017216, 400070017216, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017217, 400070017217, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017218, 400070017218, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017219, 400070017219, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017220, 400070017220, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017221, 400070017221, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017222, 400070017222, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017223, 400070017223, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017224, 400070017224, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017225, 400070017225, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017226, 400070017226, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017227, 400070017227, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017228, 400070017228, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017229, 400070017229, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017230, 400070017230, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017231, 400070017231, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017232, 400070017232, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017233, 400070017233, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017234, 400070017234, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017235, 400070017235, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017236, 400070017236, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017237, 400070017237, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017238, 400070017238, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017239, 400070017239, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017240, 400070017240, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017241, 400070017241, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017242, 400070017242, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017243, 400070017243, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017244, 400070017244, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017245, 400070017245, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017246, 400070017246, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017247, 400070017247, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017248, 400070017248, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017249, 400070017249, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017250, 400070017250, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017251, 400070017251, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017252, 400070017252, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017253, 400070017253, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017254, 400070017254, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017255, 400070017255, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017256, 400070017256, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017257, 400070017257, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017258, 400070017258, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017259, 400070017259, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017260, 400070017260, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017261, 400070017261, 45.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017262, 400070017262, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017263, 400070017263, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017264, 400070017264, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017265, 400070017265, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017266, 400070017266, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017267, 400070017267, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017268, 400070017268, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017269, 400070017269, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017270, 400070017270, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017271, 400070017271, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017272, 400070017272, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017273, 400070017273, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017274, 400070017274, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017275, 400070017275, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017276, 400070017276, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017277, 400070017277, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017278, 400070017278, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017279, 400070017279, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017280, 400070017280, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017281, 400070017281, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017282, 400070017282, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017283, 400070017283, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017284, 400070017284, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017285, 400070017285, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017286, 400070017286, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017287, 400070017287, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017288, 400070017288, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017289, 400070017289, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017290, 400070017290, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017291, 400070017291, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017292, 400070017292, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017293, 400070017293, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017294, 400070017294, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017295, 400070017295, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017296, 400070017299, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017297, 400070017300, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017298, 400070017301, 85.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017299, 400070017302, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017300, 400070017303, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017301, 400070017307, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017302, 400070017308, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017303, 400070017309, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017304, 400070017311, 2350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017305, 400070017312, 800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017306, 400070017313, 3500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017307, 400070017314, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017308, 400070017315, 1500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017309, 400070017316, 1000.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017310, 400070017317, 800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017311, 400070017318, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017312, 400070017319, 900.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017313, 400070017320, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017314, 400070017321, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017315, 400070017322, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017316, 400070017323, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified'),
    (400070017317, 400070017324, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070017, 'unverified');

-- Price source (price-specific confidence, tracked separately from item confidence)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
VALUES
    (400070017001, 400070017, :extraction_batch_id, 0.9),
    (400070017002, 400070017, :extraction_batch_id, 0.9),
    (400070017003, 400070017, :extraction_batch_id, 0.55),
    (400070017004, 400070017, :extraction_batch_id, 0.55),
    (400070017005, 400070017, :extraction_batch_id, 0.95),
    (400070017006, 400070017, :extraction_batch_id, 0.95),
    (400070017007, 400070017, :extraction_batch_id, 0.95),
    (400070017008, 400070017, :extraction_batch_id, 0.95),
    (400070017009, 400070017, :extraction_batch_id, 0.95),
    (400070017010, 400070017, :extraction_batch_id, 0.95),
    (400070017011, 400070017, :extraction_batch_id, 0.95),
    (400070017012, 400070017, :extraction_batch_id, 0.95),
    (400070017013, 400070017, :extraction_batch_id, 0.95),
    (400070017014, 400070017, :extraction_batch_id, 0.95),
    (400070017015, 400070017, :extraction_batch_id, 0.95),
    (400070017016, 400070017, :extraction_batch_id, 0.95),
    (400070017017, 400070017, :extraction_batch_id, 0.95),
    (400070017018, 400070017, :extraction_batch_id, 0.95),
    (400070017019, 400070017, :extraction_batch_id, 0.95),
    (400070017020, 400070017, :extraction_batch_id, 0.95),
    (400070017021, 400070017, :extraction_batch_id, 0.95),
    (400070017022, 400070017, :extraction_batch_id, 0.95),
    (400070017023, 400070017, :extraction_batch_id, 0.95),
    (400070017024, 400070017, :extraction_batch_id, 0.95),
    (400070017025, 400070017, :extraction_batch_id, 0.95),
    (400070017026, 400070017, :extraction_batch_id, 0.95),
    (400070017027, 400070017, :extraction_batch_id, 0.95),
    (400070017028, 400070017, :extraction_batch_id, 0.95),
    (400070017029, 400070017, :extraction_batch_id, 0.95),
    (400070017030, 400070017, :extraction_batch_id, 0.95),
    (400070017031, 400070017, :extraction_batch_id, 0.95),
    (400070017032, 400070017, :extraction_batch_id, 0.95),
    (400070017033, 400070017, :extraction_batch_id, 0.95),
    (400070017034, 400070017, :extraction_batch_id, 0.95),
    (400070017035, 400070017, :extraction_batch_id, 0.95),
    (400070017036, 400070017, :extraction_batch_id, 0.95),
    (400070017037, 400070017, :extraction_batch_id, 0.95),
    (400070017038, 400070017, :extraction_batch_id, 0.95),
    (400070017039, 400070017, :extraction_batch_id, 0.95),
    (400070017040, 400070017, :extraction_batch_id, 0.95),
    (400070017041, 400070017, :extraction_batch_id, 0.95),
    (400070017042, 400070017, :extraction_batch_id, 0.95),
    (400070017043, 400070017, :extraction_batch_id, 0.95),
    (400070017044, 400070017, :extraction_batch_id, 0.95),
    (400070017045, 400070017, :extraction_batch_id, 0.95),
    (400070017046, 400070017, :extraction_batch_id, 0.95),
    (400070017047, 400070017, :extraction_batch_id, 0.95),
    (400070017048, 400070017, :extraction_batch_id, 0.95),
    (400070017049, 400070017, :extraction_batch_id, 0.95),
    (400070017050, 400070017, :extraction_batch_id, 0.95),
    (400070017051, 400070017, :extraction_batch_id, 0.95),
    (400070017052, 400070017, :extraction_batch_id, 0.95),
    (400070017053, 400070017, :extraction_batch_id, 0.95),
    (400070017054, 400070017, :extraction_batch_id, 0.95),
    (400070017055, 400070017, :extraction_batch_id, 0.95),
    (400070017056, 400070017, :extraction_batch_id, 0.95),
    (400070017057, 400070017, :extraction_batch_id, 0.95),
    (400070017058, 400070017, :extraction_batch_id, 0.95),
    (400070017059, 400070017, :extraction_batch_id, 0.95),
    (400070017060, 400070017, :extraction_batch_id, 0.95),
    (400070017061, 400070017, :extraction_batch_id, 0.95),
    (400070017062, 400070017, :extraction_batch_id, 0.95),
    (400070017063, 400070017, :extraction_batch_id, 0.95),
    (400070017064, 400070017, :extraction_batch_id, 0.95),
    (400070017065, 400070017, :extraction_batch_id, 0.95),
    (400070017066, 400070017, :extraction_batch_id, 0.95),
    (400070017067, 400070017, :extraction_batch_id, 0.95),
    (400070017068, 400070017, :extraction_batch_id, 0.95),
    (400070017069, 400070017, :extraction_batch_id, 0.95),
    (400070017070, 400070017, :extraction_batch_id, 0.95),
    (400070017071, 400070017, :extraction_batch_id, 0.95),
    (400070017072, 400070017, :extraction_batch_id, 0.95),
    (400070017073, 400070017, :extraction_batch_id, 0.95),
    (400070017074, 400070017, :extraction_batch_id, 0.95),
    (400070017075, 400070017, :extraction_batch_id, 0.95),
    (400070017076, 400070017, :extraction_batch_id, 0.95),
    (400070017077, 400070017, :extraction_batch_id, 0.95),
    (400070017078, 400070017, :extraction_batch_id, 0.95),
    (400070017079, 400070017, :extraction_batch_id, 0.95),
    (400070017080, 400070017, :extraction_batch_id, 0.95),
    (400070017081, 400070017, :extraction_batch_id, 0.95),
    (400070017082, 400070017, :extraction_batch_id, 0.95),
    (400070017083, 400070017, :extraction_batch_id, 0.95),
    (400070017084, 400070017, :extraction_batch_id, 0.95),
    (400070017085, 400070017, :extraction_batch_id, 0.95),
    (400070017086, 400070017, :extraction_batch_id, 0.95),
    (400070017087, 400070017, :extraction_batch_id, 0.95),
    (400070017088, 400070017, :extraction_batch_id, 0.95),
    (400070017089, 400070017, :extraction_batch_id, 0.95),
    (400070017090, 400070017, :extraction_batch_id, 0.95),
    (400070017091, 400070017, :extraction_batch_id, 0.95),
    (400070017092, 400070017, :extraction_batch_id, 0.95),
    (400070017093, 400070017, :extraction_batch_id, 0.95),
    (400070017094, 400070017, :extraction_batch_id, 0.95),
    (400070017095, 400070017, :extraction_batch_id, 0.95),
    (400070017096, 400070017, :extraction_batch_id, 0.95),
    (400070017097, 400070017, :extraction_batch_id, 0.95),
    (400070017098, 400070017, :extraction_batch_id, 0.95),
    (400070017099, 400070017, :extraction_batch_id, 0.95),
    (400070017100, 400070017, :extraction_batch_id, 0.95),
    (400070017101, 400070017, :extraction_batch_id, 0.95),
    (400070017102, 400070017, :extraction_batch_id, 0.95),
    (400070017103, 400070017, :extraction_batch_id, 0.95),
    (400070017104, 400070017, :extraction_batch_id, 0.95),
    (400070017105, 400070017, :extraction_batch_id, 0.95),
    (400070017106, 400070017, :extraction_batch_id, 0.95),
    (400070017107, 400070017, :extraction_batch_id, 0.95),
    (400070017108, 400070017, :extraction_batch_id, 0.95),
    (400070017109, 400070017, :extraction_batch_id, 0.95),
    (400070017110, 400070017, :extraction_batch_id, 0.95),
    (400070017111, 400070017, :extraction_batch_id, 0.95),
    (400070017112, 400070017, :extraction_batch_id, 0.95),
    (400070017113, 400070017, :extraction_batch_id, 0.95),
    (400070017114, 400070017, :extraction_batch_id, 0.95),
    (400070017115, 400070017, :extraction_batch_id, 0.95),
    (400070017116, 400070017, :extraction_batch_id, 0.95),
    (400070017117, 400070017, :extraction_batch_id, 0.95),
    (400070017118, 400070017, :extraction_batch_id, 0.95),
    (400070017119, 400070017, :extraction_batch_id, 0.95),
    (400070017120, 400070017, :extraction_batch_id, 0.95),
    (400070017121, 400070017, :extraction_batch_id, 0.95),
    (400070017122, 400070017, :extraction_batch_id, 0.95),
    (400070017123, 400070017, :extraction_batch_id, 0.95),
    (400070017124, 400070017, :extraction_batch_id, 0.95),
    (400070017125, 400070017, :extraction_batch_id, 0.95),
    (400070017126, 400070017, :extraction_batch_id, 0.95),
    (400070017127, 400070017, :extraction_batch_id, 0.95),
    (400070017128, 400070017, :extraction_batch_id, 0.95),
    (400070017129, 400070017, :extraction_batch_id, 0.95),
    (400070017130, 400070017, :extraction_batch_id, 0.95),
    (400070017131, 400070017, :extraction_batch_id, 0.95),
    (400070017132, 400070017, :extraction_batch_id, 0.95),
    (400070017133, 400070017, :extraction_batch_id, 0.95),
    (400070017134, 400070017, :extraction_batch_id, 0.95),
    (400070017135, 400070017, :extraction_batch_id, 0.95),
    (400070017136, 400070017, :extraction_batch_id, 0.95),
    (400070017137, 400070017, :extraction_batch_id, 0.95),
    (400070017138, 400070017, :extraction_batch_id, 0.95),
    (400070017139, 400070017, :extraction_batch_id, 0.95),
    (400070017140, 400070017, :extraction_batch_id, 0.95),
    (400070017141, 400070017, :extraction_batch_id, 0.95),
    (400070017142, 400070017, :extraction_batch_id, 0.95),
    (400070017143, 400070017, :extraction_batch_id, 0.95),
    (400070017144, 400070017, :extraction_batch_id, 0.95),
    (400070017145, 400070017, :extraction_batch_id, 0.55),
    (400070017146, 400070017, :extraction_batch_id, 0.55),
    (400070017147, 400070017, :extraction_batch_id, 0.95),
    (400070017148, 400070017, :extraction_batch_id, 0.95),
    (400070017149, 400070017, :extraction_batch_id, 0.95),
    (400070017150, 400070017, :extraction_batch_id, 0.95),
    (400070017151, 400070017, :extraction_batch_id, 0.95),
    (400070017152, 400070017, :extraction_batch_id, 0.95),
    (400070017153, 400070017, :extraction_batch_id, 0.95),
    (400070017154, 400070017, :extraction_batch_id, 0.95),
    (400070017155, 400070017, :extraction_batch_id, 0.95),
    (400070017156, 400070017, :extraction_batch_id, 0.95),
    (400070017157, 400070017, :extraction_batch_id, 0.95),
    (400070017158, 400070017, :extraction_batch_id, 0.95),
    (400070017159, 400070017, :extraction_batch_id, 0.95),
    (400070017160, 400070017, :extraction_batch_id, 0.95),
    (400070017161, 400070017, :extraction_batch_id, 0.95),
    (400070017162, 400070017, :extraction_batch_id, 0.95),
    (400070017163, 400070017, :extraction_batch_id, 0.95),
    (400070017164, 400070017, :extraction_batch_id, 0.55),
    (400070017165, 400070017, :extraction_batch_id, 0.55),
    (400070017166, 400070017, :extraction_batch_id, 0.95),
    (400070017167, 400070017, :extraction_batch_id, 0.95),
    (400070017168, 400070017, :extraction_batch_id, 0.95),
    (400070017169, 400070017, :extraction_batch_id, 0.95),
    (400070017170, 400070017, :extraction_batch_id, 0.95),
    (400070017171, 400070017, :extraction_batch_id, 0.95),
    (400070017172, 400070017, :extraction_batch_id, 0.95),
    (400070017173, 400070017, :extraction_batch_id, 0.95),
    (400070017174, 400070017, :extraction_batch_id, 0.95),
    (400070017175, 400070017, :extraction_batch_id, 0.95),
    (400070017176, 400070017, :extraction_batch_id, 0.95),
    (400070017177, 400070017, :extraction_batch_id, 0.95),
    (400070017178, 400070017, :extraction_batch_id, 0.55),
    (400070017179, 400070017, :extraction_batch_id, 0.55),
    (400070017180, 400070017, :extraction_batch_id, 0.55),
    (400070017181, 400070017, :extraction_batch_id, 0.55),
    (400070017182, 400070017, :extraction_batch_id, 0.95),
    (400070017183, 400070017, :extraction_batch_id, 0.95),
    (400070017184, 400070017, :extraction_batch_id, 0.55),
    (400070017185, 400070017, :extraction_batch_id, 0.55),
    (400070017186, 400070017, :extraction_batch_id, 0.95),
    (400070017187, 400070017, :extraction_batch_id, 0.55),
    (400070017188, 400070017, :extraction_batch_id, 0.55),
    (400070017189, 400070017, :extraction_batch_id, 0.55),
    (400070017190, 400070017, :extraction_batch_id, 0.55),
    (400070017191, 400070017, :extraction_batch_id, 0.55),
    (400070017192, 400070017, :extraction_batch_id, 0.55),
    (400070017193, 400070017, :extraction_batch_id, 0.55),
    (400070017194, 400070017, :extraction_batch_id, 0.55),
    (400070017195, 400070017, :extraction_batch_id, 0.55),
    (400070017196, 400070017, :extraction_batch_id, 0.55),
    (400070017197, 400070017, :extraction_batch_id, 0.55),
    (400070017198, 400070017, :extraction_batch_id, 0.55),
    (400070017199, 400070017, :extraction_batch_id, 0.55),
    (400070017200, 400070017, :extraction_batch_id, 0.55),
    (400070017201, 400070017, :extraction_batch_id, 0.55),
    (400070017202, 400070017, :extraction_batch_id, 0.55),
    (400070017203, 400070017, :extraction_batch_id, 0.55),
    (400070017204, 400070017, :extraction_batch_id, 0.55),
    (400070017205, 400070017, :extraction_batch_id, 0.55),
    (400070017206, 400070017, :extraction_batch_id, 0.55),
    (400070017207, 400070017, :extraction_batch_id, 0.95),
    (400070017208, 400070017, :extraction_batch_id, 0.95),
    (400070017209, 400070017, :extraction_batch_id, 0.95),
    (400070017210, 400070017, :extraction_batch_id, 0.95),
    (400070017211, 400070017, :extraction_batch_id, 0.95),
    (400070017212, 400070017, :extraction_batch_id, 0.95),
    (400070017213, 400070017, :extraction_batch_id, 0.95),
    (400070017214, 400070017, :extraction_batch_id, 0.95),
    (400070017215, 400070017, :extraction_batch_id, 0.95),
    (400070017216, 400070017, :extraction_batch_id, 0.95),
    (400070017217, 400070017, :extraction_batch_id, 0.95),
    (400070017218, 400070017, :extraction_batch_id, 0.95),
    (400070017219, 400070017, :extraction_batch_id, 0.95),
    (400070017220, 400070017, :extraction_batch_id, 0.95),
    (400070017221, 400070017, :extraction_batch_id, 0.95),
    (400070017222, 400070017, :extraction_batch_id, 0.95),
    (400070017223, 400070017, :extraction_batch_id, 0.95),
    (400070017224, 400070017, :extraction_batch_id, 0.95),
    (400070017225, 400070017, :extraction_batch_id, 0.95),
    (400070017226, 400070017, :extraction_batch_id, 0.95),
    (400070017227, 400070017, :extraction_batch_id, 0.95),
    (400070017228, 400070017, :extraction_batch_id, 0.95),
    (400070017229, 400070017, :extraction_batch_id, 0.95),
    (400070017230, 400070017, :extraction_batch_id, 0.95),
    (400070017231, 400070017, :extraction_batch_id, 0.95),
    (400070017232, 400070017, :extraction_batch_id, 0.95),
    (400070017233, 400070017, :extraction_batch_id, 0.95),
    (400070017234, 400070017, :extraction_batch_id, 0.95),
    (400070017235, 400070017, :extraction_batch_id, 0.95),
    (400070017236, 400070017, :extraction_batch_id, 0.95),
    (400070017237, 400070017, :extraction_batch_id, 0.95),
    (400070017238, 400070017, :extraction_batch_id, 0.95),
    (400070017239, 400070017, :extraction_batch_id, 0.95),
    (400070017240, 400070017, :extraction_batch_id, 0.95),
    (400070017241, 400070017, :extraction_batch_id, 0.95),
    (400070017242, 400070017, :extraction_batch_id, 0.95),
    (400070017243, 400070017, :extraction_batch_id, 0.95),
    (400070017244, 400070017, :extraction_batch_id, 0.95),
    (400070017245, 400070017, :extraction_batch_id, 0.95),
    (400070017246, 400070017, :extraction_batch_id, 0.95),
    (400070017247, 400070017, :extraction_batch_id, 0.95),
    (400070017248, 400070017, :extraction_batch_id, 0.95),
    (400070017249, 400070017, :extraction_batch_id, 0.95),
    (400070017250, 400070017, :extraction_batch_id, 0.95),
    (400070017251, 400070017, :extraction_batch_id, 0.95),
    (400070017252, 400070017, :extraction_batch_id, 0.95),
    (400070017253, 400070017, :extraction_batch_id, 0.95),
    (400070017254, 400070017, :extraction_batch_id, 0.95),
    (400070017255, 400070017, :extraction_batch_id, 0.95),
    (400070017256, 400070017, :extraction_batch_id, 0.95),
    (400070017257, 400070017, :extraction_batch_id, 0.95),
    (400070017258, 400070017, :extraction_batch_id, 0.95),
    (400070017259, 400070017, :extraction_batch_id, 0.95),
    (400070017260, 400070017, :extraction_batch_id, 0.95),
    (400070017261, 400070017, :extraction_batch_id, 0.95),
    (400070017262, 400070017, :extraction_batch_id, 0.95),
    (400070017263, 400070017, :extraction_batch_id, 0.95),
    (400070017264, 400070017, :extraction_batch_id, 0.95),
    (400070017265, 400070017, :extraction_batch_id, 0.95),
    (400070017266, 400070017, :extraction_batch_id, 0.95),
    (400070017267, 400070017, :extraction_batch_id, 0.95),
    (400070017268, 400070017, :extraction_batch_id, 0.95),
    (400070017269, 400070017, :extraction_batch_id, 0.95),
    (400070017270, 400070017, :extraction_batch_id, 0.95),
    (400070017271, 400070017, :extraction_batch_id, 0.95),
    (400070017272, 400070017, :extraction_batch_id, 0.95),
    (400070017273, 400070017, :extraction_batch_id, 0.95),
    (400070017274, 400070017, :extraction_batch_id, 0.95),
    (400070017275, 400070017, :extraction_batch_id, 0.95),
    (400070017276, 400070017, :extraction_batch_id, 0.95),
    (400070017277, 400070017, :extraction_batch_id, 0.95),
    (400070017278, 400070017, :extraction_batch_id, 0.95),
    (400070017279, 400070017, :extraction_batch_id, 0.95),
    (400070017280, 400070017, :extraction_batch_id, 0.95),
    (400070017281, 400070017, :extraction_batch_id, 0.95),
    (400070017282, 400070017, :extraction_batch_id, 0.95),
    (400070017283, 400070017, :extraction_batch_id, 0.95),
    (400070017284, 400070017, :extraction_batch_id, 0.95),
    (400070017285, 400070017, :extraction_batch_id, 0.95),
    (400070017286, 400070017, :extraction_batch_id, 0.95),
    (400070017287, 400070017, :extraction_batch_id, 0.95),
    (400070017288, 400070017, :extraction_batch_id, 0.95),
    (400070017289, 400070017, :extraction_batch_id, 0.95),
    (400070017290, 400070017, :extraction_batch_id, 0.95),
    (400070017291, 400070017, :extraction_batch_id, 0.95),
    (400070017292, 400070017, :extraction_batch_id, 0.95),
    (400070017293, 400070017, :extraction_batch_id, 0.95),
    (400070017294, 400070017, :extraction_batch_id, 0.95),
    (400070017295, 400070017, :extraction_batch_id, 0.95),
    (400070017296, 400070017, :extraction_batch_id, 0.95),
    (400070017297, 400070017, :extraction_batch_id, 0.95),
    (400070017298, 400070017, :extraction_batch_id, 0.95),
    (400070017299, 400070017, :extraction_batch_id, 0.95),
    (400070017300, 400070017, :extraction_batch_id, 0.95),
    (400070017301, 400070017, :extraction_batch_id, 0.95),
    (400070017302, 400070017, :extraction_batch_id, 0.95),
    (400070017303, 400070017, :extraction_batch_id, 0.95),
    (400070017304, 400070017, :extraction_batch_id, 0.95),
    (400070017305, 400070017, :extraction_batch_id, 0.95),
    (400070017306, 400070017, :extraction_batch_id, 0.95),
    (400070017307, 400070017, :extraction_batch_id, 0.95),
    (400070017308, 400070017, :extraction_batch_id, 0.95),
    (400070017309, 400070017, :extraction_batch_id, 0.95),
    (400070017310, 400070017, :extraction_batch_id, 0.95),
    (400070017311, 400070017, :extraction_batch_id, 0.95),
    (400070017312, 400070017, :extraction_batch_id, 0.95),
    (400070017313, 400070017, :extraction_batch_id, 0.95),
    (400070017314, 400070017, :extraction_batch_id, 0.95),
    (400070017315, 400070017, :extraction_batch_id, 0.95),
    (400070017316, 400070017, :extraction_batch_id, 0.95),
    (400070017317, 400070017, :extraction_batch_id, 0.95);

-- Board <-> item mapping
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
VALUES
    (400070017001, 400070017, 400070017001, 400070017001, 400070017002, 1),
    (400070017002, 400070017, 400070017001, 400070017002, 400070017002, 2),
    (400070017003, 400070017, 400070017001, 400070017003, 400070017002, 3),
    (400070017004, 400070017, 400070017001, 400070017004, 400070017002, 4),
    (400070017005, 400070017, 400070017001, 400070017005, 400070017002, 5),
    (400070017006, 400070017, 400070017001, 400070017006, 400070017002, 6),
    (400070017007, 400070017, 400070017001, 400070017007, 400070017002, 7),
    (400070017008, 400070017, 400070017001, 400070017008, 400070017002, 8),
    (400070017009, 400070017, 400070017001, 400070017009, 400070017002, 9),
    (400070017010, 400070017, 400070017001, 400070017010, 400070017002, 10),
    (400070017011, 400070017, 400070017001, 400070017011, 400070017002, 11),
    (400070017012, 400070017, 400070017001, 400070017012, 400070017002, 12),
    (400070017013, 400070017, 400070017001, 400070017013, 400070017002, 13),
    (400070017014, 400070017, 400070017001, 400070017014, 400070017003, 1),
    (400070017015, 400070017, 400070017001, 400070017015, 400070017003, 2),
    (400070017016, 400070017, 400070017001, 400070017016, 400070017003, 3),
    (400070017017, 400070017, 400070017001, 400070017017, 400070017003, 4),
    (400070017018, 400070017, 400070017001, 400070017018, 400070017003, 5),
    (400070017019, 400070017, 400070017001, 400070017019, 400070017003, 6),
    (400070017020, 400070017, 400070017001, 400070017020, 400070017003, 7),
    (400070017021, 400070017, 400070017001, 400070017021, 400070017003, 8),
    (400070017022, 400070017, 400070017001, 400070017022, 400070017003, 9),
    (400070017023, 400070017, 400070017001, 400070017023, 400070017003, 10),
    (400070017024, 400070017, 400070017001, 400070017024, 400070017003, 11),
    (400070017025, 400070017, 400070017001, 400070017025, 400070017003, 12),
    (400070017026, 400070017, 400070017001, 400070017026, 400070017003, 13),
    (400070017027, 400070017, 400070017001, 400070017027, 400070017004, 1),
    (400070017028, 400070017, 400070017001, 400070017028, 400070017004, 2),
    (400070017029, 400070017, 400070017001, 400070017029, 400070017004, 3),
    (400070017030, 400070017, 400070017001, 400070017030, 400070017004, 4),
    (400070017031, 400070017, 400070017001, 400070017031, 400070017004, 5),
    (400070017032, 400070017, 400070017001, 400070017032, 400070017004, 6),
    (400070017033, 400070017, 400070017001, 400070017033, 400070017004, 7),
    (400070017034, 400070017, 400070017001, 400070017034, 400070017004, 8),
    (400070017035, 400070017, 400070017001, 400070017035, 400070017004, 9),
    (400070017036, 400070017, 400070017001, 400070017036, 400070017004, 10),
    (400070017037, 400070017, 400070017001, 400070017037, 400070017004, 11),
    (400070017038, 400070017, 400070017001, 400070017038, 400070017004, 12),
    (400070017039, 400070017, 400070017001, 400070017039, 400070017004, 13),
    (400070017040, 400070017, 400070017001, 400070017040, 400070017004, 14),
    (400070017041, 400070017, 400070017001, 400070017041, 400070017004, 15),
    (400070017042, 400070017, 400070017001, 400070017042, 400070017004, 16),
    (400070017043, 400070017, 400070017001, 400070017043, 400070017004, 17),
    (400070017044, 400070017, 400070017001, 400070017044, 400070017004, 18),
    (400070017045, 400070017, 400070017001, 400070017045, 400070017004, 19),
    (400070017046, 400070017, 400070017001, 400070017046, 400070017004, 20),
    (400070017047, 400070017, 400070017001, 400070017047, 400070017004, 21),
    (400070017048, 400070017, 400070017001, 400070017048, 400070017004, 22),
    (400070017049, 400070017, 400070017001, 400070017049, 400070017004, 23),
    (400070017050, 400070017, 400070017001, 400070017050, 400070017004, 24),
    (400070017051, 400070017, 400070017001, 400070017051, 400070017004, 25),
    (400070017052, 400070017, 400070017001, 400070017052, 400070017004, 26),
    (400070017053, 400070017, 400070017001, 400070017053, 400070017004, 27),
    (400070017054, 400070017, 400070017001, 400070017054, 400070017004, 28),
    (400070017055, 400070017, 400070017001, 400070017055, 400070017004, 29),
    (400070017056, 400070017, 400070017001, 400070017056, 400070017004, 30),
    (400070017057, 400070017, 400070017001, 400070017057, 400070017004, 31),
    (400070017058, 400070017, 400070017001, 400070017058, 400070017005, 1),
    (400070017059, 400070017, 400070017001, 400070017059, 400070017005, 2),
    (400070017060, 400070017, 400070017001, 400070017060, 400070017005, 3),
    (400070017061, 400070017, 400070017001, 400070017061, 400070017005, 4),
    (400070017062, 400070017, 400070017001, 400070017062, 400070017005, 5),
    (400070017063, 400070017, 400070017001, 400070017063, 400070017005, 6),
    (400070017064, 400070017, 400070017001, 400070017064, 400070017005, 7),
    (400070017065, 400070017, 400070017001, 400070017065, 400070017005, 8),
    (400070017066, 400070017, 400070017001, 400070017066, 400070017005, 9),
    (400070017067, 400070017, 400070017001, 400070017067, 400070017005, 10),
    (400070017068, 400070017, 400070017001, 400070017068, 400070017005, 11),
    (400070017069, 400070017, 400070017001, 400070017069, 400070017005, 12),
    (400070017070, 400070017, 400070017001, 400070017070, 400070017005, 13),
    (400070017071, 400070017, 400070017001, 400070017071, 400070017005, 14),
    (400070017072, 400070017, 400070017001, 400070017072, 400070017006, 1),
    (400070017073, 400070017, 400070017001, 400070017073, 400070017006, 2),
    (400070017074, 400070017, 400070017001, 400070017074, 400070017006, 3),
    (400070017075, 400070017, 400070017001, 400070017075, 400070017006, 4),
    (400070017076, 400070017, 400070017001, 400070017076, 400070017006, 5),
    (400070017077, 400070017, 400070017001, 400070017077, 400070017006, 6),
    (400070017078, 400070017, 400070017001, 400070017078, 400070017006, 7),
    (400070017079, 400070017, 400070017001, 400070017079, 400070017006, 8),
    (400070017080, 400070017, 400070017001, 400070017080, 400070017006, 9),
    (400070017081, 400070017, 400070017001, 400070017081, 400070017006, 10),
    (400070017082, 400070017, 400070017001, 400070017082, 400070017006, 11),
    (400070017083, 400070017, 400070017001, 400070017083, 400070017006, 12),
    (400070017084, 400070017, 400070017001, 400070017084, 400070017006, 13),
    (400070017085, 400070017, 400070017001, 400070017085, 400070017007, 1),
    (400070017086, 400070017, 400070017001, 400070017086, 400070017007, 2),
    (400070017087, 400070017, 400070017001, 400070017087, 400070017007, 3),
    (400070017088, 400070017, 400070017001, 400070017088, 400070017007, 4),
    (400070017089, 400070017, 400070017001, 400070017089, 400070017007, 5),
    (400070017090, 400070017, 400070017001, 400070017090, 400070017007, 6),
    (400070017091, 400070017, 400070017001, 400070017091, 400070017007, 7),
    (400070017092, 400070017, 400070017001, 400070017092, 400070017007, 8),
    (400070017093, 400070017, 400070017001, 400070017093, 400070017007, 9),
    (400070017094, 400070017, 400070017001, 400070017094, 400070017008, 1),
    (400070017095, 400070017, 400070017001, 400070017095, 400070017008, 2),
    (400070017096, 400070017, 400070017001, 400070017096, 400070017008, 3),
    (400070017097, 400070017, 400070017001, 400070017097, 400070017008, 4),
    (400070017098, 400070017, 400070017001, 400070017098, 400070017008, 5),
    (400070017099, 400070017, 400070017001, 400070017099, 400070017008, 6),
    (400070017100, 400070017, 400070017001, 400070017100, 400070017008, 7),
    (400070017101, 400070017, 400070017001, 400070017101, 400070017008, 8),
    (400070017102, 400070017, 400070017001, 400070017102, 400070017008, 9),
    (400070017103, 400070017, 400070017001, 400070017103, 400070017008, 10),
    (400070017104, 400070017, 400070017001, 400070017104, 400070017008, 11),
    (400070017105, 400070017, 400070017001, 400070017105, 400070017008, 12),
    (400070017106, 400070017, 400070017001, 400070017106, 400070017009, 1),
    (400070017107, 400070017, 400070017001, 400070017107, 400070017009, 2),
    (400070017108, 400070017, 400070017001, 400070017108, 400070017009, 3),
    (400070017109, 400070017, 400070017001, 400070017109, 400070017009, 4),
    (400070017110, 400070017, 400070017001, 400070017110, 400070017009, 5),
    (400070017111, 400070017, 400070017001, 400070017111, 400070017009, 6),
    (400070017112, 400070017, 400070017001, 400070017112, 400070017009, 7),
    (400070017113, 400070017, 400070017001, 400070017113, 400070017009, 8),
    (400070017114, 400070017, 400070017001, 400070017114, 400070017009, 9),
    (400070017115, 400070017, 400070017001, 400070017115, 400070017009, 10),
    (400070017116, 400070017, 400070017001, 400070017116, 400070017009, 11),
    (400070017117, 400070017, 400070017001, 400070017117, 400070017009, 12),
    (400070017118, 400070017, 400070017001, 400070017118, 400070017009, 13),
    (400070017119, 400070017, 400070017001, 400070017119, 400070017009, 14),
    (400070017120, 400070017, 400070017001, 400070017120, 400070017009, 15),
    (400070017121, 400070017, 400070017001, 400070017121, 400070017009, 16),
    (400070017122, 400070017, 400070017001, 400070017122, 400070017009, 17),
    (400070017123, 400070017, 400070017001, 400070017123, 400070017009, 18),
    (400070017124, 400070017, 400070017001, 400070017124, 400070017009, 19),
    (400070017125, 400070017, 400070017001, 400070017125, 400070017009, 20),
    (400070017126, 400070017, 400070017001, 400070017126, 400070017009, 21),
    (400070017127, 400070017, 400070017001, 400070017127, 400070017009, 22),
    (400070017128, 400070017, 400070017001, 400070017128, 400070017009, 23),
    (400070017129, 400070017, 400070017001, 400070017129, 400070017009, 24),
    (400070017130, 400070017, 400070017001, 400070017130, 400070017009, 25),
    (400070017131, 400070017, 400070017001, 400070017131, 400070017009, 26),
    (400070017132, 400070017, 400070017001, 400070017132, 400070017009, 27),
    (400070017133, 400070017, 400070017001, 400070017133, 400070017009, 28),
    (400070017134, 400070017, 400070017001, 400070017134, 400070017009, 29),
    (400070017135, 400070017, 400070017001, 400070017135, 400070017009, 30),
    (400070017136, 400070017, 400070017001, 400070017136, 400070017009, 31),
    (400070017137, 400070017, 400070017001, 400070017137, 400070017010, 1),
    (400070017138, 400070017, 400070017001, 400070017138, 400070017010, 2),
    (400070017139, 400070017, 400070017001, 400070017139, 400070017010, 3),
    (400070017140, 400070017, 400070017001, 400070017140, 400070017010, 4),
    (400070017141, 400070017, 400070017001, 400070017141, 400070017010, 5),
    (400070017142, 400070017, 400070017001, 400070017142, 400070017010, 6),
    (400070017143, 400070017, 400070017001, 400070017143, 400070017011, 1),
    (400070017144, 400070017, 400070017001, 400070017144, 400070017011, 2),
    (400070017145, 400070017, 400070017001, 400070017145, 400070017011, 3),
    (400070017146, 400070017, 400070017001, 400070017146, 400070017011, 4),
    (400070017147, 400070017, 400070017001, 400070017147, 400070017011, 5),
    (400070017148, 400070017, 400070017001, 400070017148, 400070017011, 6),
    (400070017149, 400070017, 400070017001, 400070017149, 400070017011, 7),
    (400070017150, 400070017, 400070017001, 400070017150, 400070017011, 8),
    (400070017151, 400070017, 400070017001, 400070017151, 400070017011, 9),
    (400070017152, 400070017, 400070017001, 400070017152, 400070017011, 10),
    (400070017153, 400070017, 400070017001, 400070017153, 400070017011, 11),
    (400070017154, 400070017, 400070017001, 400070017154, 400070017011, 12),
    (400070017155, 400070017, 400070017001, 400070017155, 400070017011, 13),
    (400070017156, 400070017, 400070017001, 400070017156, 400070017011, 14),
    (400070017157, 400070017, 400070017001, 400070017157, 400070017011, 15),
    (400070017158, 400070017, 400070017001, 400070017158, 400070017011, 16),
    (400070017159, 400070017, 400070017001, 400070017159, 400070017011, 17),
    (400070017160, 400070017, 400070017001, 400070017160, 400070017011, 18),
    (400070017161, 400070017, 400070017001, 400070017161, 400070017011, 19),
    (400070017162, 400070017, 400070017001, 400070017162, 400070017012, 1),
    (400070017163, 400070017, 400070017001, 400070017163, 400070017012, 2),
    (400070017164, 400070017, 400070017001, 400070017164, 400070017012, 3),
    (400070017165, 400070017, 400070017001, 400070017165, 400070017012, 4),
    (400070017166, 400070017, 400070017001, 400070017166, 400070017012, 5),
    (400070017167, 400070017, 400070017001, 400070017167, 400070017012, 6),
    (400070017168, 400070017, 400070017001, 400070017168, 400070017012, 7),
    (400070017169, 400070017, 400070017001, 400070017169, 400070017012, 8),
    (400070017170, 400070017, 400070017001, 400070017170, 400070017012, 9),
    (400070017171, 400070017, 400070017001, 400070017171, 400070017012, 10),
    (400070017172, 400070017, 400070017001, 400070017172, 400070017012, 11),
    (400070017173, 400070017, 400070017001, 400070017173, 400070017012, 12),
    (400070017174, 400070017, 400070017001, 400070017174, 400070017012, 13),
    (400070017175, 400070017, 400070017001, 400070017175, 400070017013, 1),
    (400070017176, 400070017, 400070017001, 400070017176, 400070017013, 2),
    (400070017177, 400070017, 400070017001, 400070017177, 400070017013, 3),
    (400070017178, 400070017, 400070017001, 400070017178, 400070017013, 4),
    (400070017179, 400070017, 400070017001, 400070017179, 400070017013, 5),
    (400070017180, 400070017, 400070017001, 400070017180, 400070017013, 6),
    (400070017181, 400070017, 400070017001, 400070017181, 400070017013, 7),
    (400070017182, 400070017, 400070017001, 400070017182, 400070017013, 8),
    (400070017183, 400070017, 400070017001, 400070017183, 400070017013, 9),
    (400070017184, 400070017, 400070017001, 400070017184, 400070017014, 1),
    (400070017185, 400070017, 400070017001, 400070017185, 400070017014, 2),
    (400070017186, 400070017, 400070017001, 400070017186, 400070017014, 3),
    (400070017187, 400070017, 400070017001, 400070017187, 400070017014, 4),
    (400070017188, 400070017, 400070017001, 400070017188, 400070017014, 5),
    (400070017189, 400070017, 400070017001, 400070017189, 400070017014, 6),
    (400070017190, 400070017, 400070017001, 400070017190, 400070017014, 7),
    (400070017191, 400070017, 400070017001, 400070017191, 400070017014, 8),
    (400070017192, 400070017, 400070017001, 400070017192, 400070017014, 9),
    (400070017193, 400070017, 400070017001, 400070017193, 400070017015, 1),
    (400070017194, 400070017, 400070017001, 400070017194, 400070017015, 2),
    (400070017195, 400070017, 400070017001, 400070017195, 400070017015, 3),
    (400070017196, 400070017, 400070017001, 400070017196, 400070017015, 4),
    (400070017197, 400070017, 400070017001, 400070017197, 400070017015, 5),
    (400070017198, 400070017, 400070017001, 400070017198, 400070017015, 6),
    (400070017199, 400070017, 400070017001, 400070017199, 400070017015, 7),
    (400070017200, 400070017, 400070017001, 400070017200, 400070017015, 8),
    (400070017201, 400070017, 400070017001, 400070017201, 400070017015, 9),
    (400070017202, 400070017, 400070017001, 400070017202, 400070017015, 10),
    (400070017203, 400070017, 400070017001, 400070017203, 400070017015, 11),
    (400070017204, 400070017, 400070017001, 400070017204, 400070017015, 12),
    (400070017205, 400070017, 400070017001, 400070017205, 400070017015, 13),
    (400070017206, 400070017, 400070017001, 400070017206, 400070017015, 14),
    (400070017207, 400070017, 400070017001, 400070017207, 400070017015, 15),
    (400070017208, 400070017, 400070017001, 400070017208, 400070017015, 16),
    (400070017209, 400070017, 400070017001, 400070017209, 400070017015, 17),
    (400070017210, 400070017, 400070017001, 400070017210, 400070017015, 18),
    (400070017211, 400070017, 400070017001, 400070017211, 400070017015, 19),
    (400070017212, 400070017, 400070017001, 400070017212, 400070017015, 20),
    (400070017213, 400070017, 400070017001, 400070017213, 400070017015, 21),
    (400070017214, 400070017, 400070017001, 400070017214, 400070017015, 22),
    (400070017215, 400070017, 400070017001, 400070017215, 400070017016, 1),
    (400070017216, 400070017, 400070017001, 400070017216, 400070017016, 2),
    (400070017217, 400070017, 400070017001, 400070017217, 400070017016, 3),
    (400070017218, 400070017, 400070017001, 400070017218, 400070017016, 4),
    (400070017219, 400070017, 400070017001, 400070017219, 400070017016, 5),
    (400070017220, 400070017, 400070017001, 400070017220, 400070017016, 6),
    (400070017221, 400070017, 400070017001, 400070017221, 400070017016, 7),
    (400070017222, 400070017, 400070017001, 400070017222, 400070017016, 8),
    (400070017223, 400070017, 400070017001, 400070017223, 400070017016, 9),
    (400070017224, 400070017, 400070017001, 400070017224, 400070017016, 10),
    (400070017225, 400070017, 400070017001, 400070017225, 400070017016, 11),
    (400070017226, 400070017, 400070017001, 400070017226, 400070017016, 12),
    (400070017227, 400070017, 400070017001, 400070017227, 400070017016, 13),
    (400070017228, 400070017, 400070017001, 400070017228, 400070017016, 14),
    (400070017229, 400070017, 400070017001, 400070017229, 400070017016, 15),
    (400070017230, 400070017, 400070017001, 400070017230, 400070017017, 1),
    (400070017231, 400070017, 400070017001, 400070017231, 400070017017, 2),
    (400070017232, 400070017, 400070017001, 400070017232, 400070017017, 3),
    (400070017233, 400070017, 400070017001, 400070017233, 400070017017, 4),
    (400070017234, 400070017, 400070017001, 400070017234, 400070017017, 5),
    (400070017235, 400070017, 400070017001, 400070017235, 400070017017, 6),
    (400070017236, 400070017, 400070017001, 400070017236, 400070017017, 7),
    (400070017237, 400070017, 400070017001, 400070017237, 400070017017, 8),
    (400070017238, 400070017, 400070017001, 400070017238, 400070017017, 9),
    (400070017239, 400070017, 400070017001, 400070017239, 400070017018, 1),
    (400070017240, 400070017, 400070017001, 400070017240, 400070017018, 2),
    (400070017241, 400070017, 400070017001, 400070017241, 400070017018, 3),
    (400070017242, 400070017, 400070017001, 400070017242, 400070017018, 4),
    (400070017243, 400070017, 400070017001, 400070017243, 400070017018, 5),
    (400070017244, 400070017, 400070017001, 400070017244, 400070017018, 6),
    (400070017245, 400070017, 400070017001, 400070017245, 400070017018, 7),
    (400070017246, 400070017, 400070017001, 400070017246, 400070017018, 8),
    (400070017247, 400070017, 400070017001, 400070017247, 400070017018, 9),
    (400070017248, 400070017, 400070017001, 400070017248, 400070017018, 10),
    (400070017249, 400070017, 400070017001, 400070017249, 400070017018, 11),
    (400070017250, 400070017, 400070017001, 400070017250, 400070017018, 12),
    (400070017251, 400070017, 400070017001, 400070017251, 400070017018, 13),
    (400070017252, 400070017, 400070017001, 400070017252, 400070017018, 14),
    (400070017253, 400070017, 400070017001, 400070017253, 400070017018, 15),
    (400070017254, 400070017, 400070017001, 400070017254, 400070017019, 1),
    (400070017255, 400070017, 400070017001, 400070017255, 400070017019, 2),
    (400070017256, 400070017, 400070017001, 400070017256, 400070017019, 3),
    (400070017257, 400070017, 400070017001, 400070017257, 400070017019, 4),
    (400070017258, 400070017, 400070017001, 400070017258, 400070017019, 5),
    (400070017259, 400070017, 400070017001, 400070017259, 400070017019, 6),
    (400070017260, 400070017, 400070017001, 400070017260, 400070017019, 7),
    (400070017261, 400070017, 400070017001, 400070017261, 400070017019, 8),
    (400070017262, 400070017, 400070017001, 400070017262, 400070017020, 1),
    (400070017263, 400070017, 400070017001, 400070017263, 400070017020, 2),
    (400070017264, 400070017, 400070017001, 400070017264, 400070017020, 3),
    (400070017265, 400070017, 400070017001, 400070017265, 400070017020, 4),
    (400070017266, 400070017, 400070017001, 400070017266, 400070017020, 5),
    (400070017267, 400070017, 400070017001, 400070017267, 400070017020, 6),
    (400070017268, 400070017, 400070017001, 400070017268, 400070017020, 7),
    (400070017269, 400070017, 400070017001, 400070017269, 400070017020, 8),
    (400070017270, 400070017, 400070017001, 400070017270, 400070017020, 9),
    (400070017271, 400070017, 400070017001, 400070017271, 400070017020, 10),
    (400070017272, 400070017, 400070017001, 400070017272, 400070017020, 11),
    (400070017273, 400070017, 400070017001, 400070017273, 400070017021, 1),
    (400070017274, 400070017, 400070017001, 400070017274, 400070017021, 2),
    (400070017275, 400070017, 400070017001, 400070017275, 400070017021, 3),
    (400070017276, 400070017, 400070017001, 400070017276, 400070017021, 4),
    (400070017277, 400070017, 400070017001, 400070017277, 400070017021, 5),
    (400070017278, 400070017, 400070017001, 400070017278, 400070017021, 6),
    (400070017279, 400070017, 400070017001, 400070017279, 400070017022, 1),
    (400070017280, 400070017, 400070017001, 400070017280, 400070017022, 2),
    (400070017281, 400070017, 400070017001, 400070017281, 400070017022, 3),
    (400070017282, 400070017, 400070017001, 400070017282, 400070017023, 1),
    (400070017283, 400070017, 400070017001, 400070017283, 400070017023, 2),
    (400070017284, 400070017, 400070017001, 400070017284, 400070017023, 3),
    (400070017285, 400070017, 400070017001, 400070017285, 400070017023, 4),
    (400070017286, 400070017, 400070017001, 400070017286, 400070017023, 5),
    (400070017287, 400070017, 400070017001, 400070017287, 400070017024, 1),
    (400070017288, 400070017, 400070017001, 400070017288, 400070017024, 2),
    (400070017289, 400070017, 400070017001, 400070017289, 400070017024, 3),
    (400070017290, 400070017, 400070017001, 400070017290, 400070017024, 4),
    (400070017291, 400070017, 400070017001, 400070017291, 400070017024, 5),
    (400070017292, 400070017, 400070017001, 400070017292, 400070017024, 6),
    (400070017293, 400070017, 400070017001, 400070017293, 400070017024, 7),
    (400070017294, 400070017, 400070017001, 400070017294, 400070017025, 1),
    (400070017295, 400070017, 400070017001, 400070017295, 400070017025, 2),
    (400070017296, 400070017, 400070017001, 400070017296, 400070017025, 3),
    (400070017297, 400070017, 400070017001, 400070017297, 400070017025, 4),
    (400070017298, 400070017, 400070017001, 400070017298, 400070017025, 5),
    (400070017299, 400070017, 400070017001, 400070017299, 400070017025, 6),
    (400070017300, 400070017, 400070017001, 400070017300, 400070017025, 7),
    (400070017301, 400070017, 400070017001, 400070017301, 400070017025, 8),
    (400070017302, 400070017, 400070017001, 400070017302, 400070017025, 9),
    (400070017303, 400070017, 400070017001, 400070017303, 400070017025, 10),
    (400070017304, 400070017, 400070017001, 400070017304, 400070017025, 11),
    (400070017305, 400070017, 400070017001, 400070017305, 400070017025, 12),
    (400070017306, 400070017, 400070017001, 400070017306, 400070017025, 13),
    (400070017307, 400070017, 400070017001, 400070017307, 400070017025, 14);

-- === NEEDS-REVIEW ITEMS ===
-- menu_item_id 400070017001 (Chicken Tandoori Spl (Full/half) / Full): Half/Full order taken from a label given in the item name (confidence 0.9)
-- menu_item_id 400070017001 (Chicken Tandoori Spl (Full/half) / Half): Half/Full order taken from a label given in the item name (confidence 0.9)
-- menu_item_id 400070017002 (Chicken Schezwan Tandoori / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017002 (Chicken Schezwan Tandoori / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017005 (Malai Tikka): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017085 (Brain Tomato Fry): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017086 (Brain Masala Fry): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017143 (Chinese Khabsa Rice): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017143 (Chinese Khabsa Rice / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017143 (Chinese Khabsa Rice / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017160 (White Rice / Biryani Rice): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017161 (Jeera Rice / Steam Rice): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017161 (Jeera Rice / Steam Rice / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017161 (Jeera Rice / Steam Rice / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017174 (Chicken 65 / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017174 (Chicken 65 / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017175 (Veg. 65 / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017175 (Veg. 65 / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017178 (Veg. Garlic / Ginger / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017178 (Veg. Garlic / Ginger / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017180 (Paneer Chilly / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017180 (Paneer Chilly / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017181 (Paneer Manchurian / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017181 (Paneer Manchurian / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017182 (Mushroom Chilly / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017182 (Mushroom Chilly / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017183 (Mushroom Manchurian / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017183 (Mushroom Manchurian / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017184 (Nasheman Spl. Soup): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017184 (Nasheman Spl. Soup / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017184 (Nasheman Spl. Soup / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017185 (Hot & Sour Soup): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017185 (Hot & Sour Soup / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017185 (Hot & Sour Soup / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017186 (Manchow Soup): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017186 (Manchow Soup / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017186 (Manchow Soup / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017187 (Noodles Soup): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017187 (Noodles Soup / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017187 (Noodles Soup / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017188 (Sweet Corn Soup): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017188 (Sweet Corn Soup / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017188 (Sweet Corn Soup / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017189 (Clear Soup): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017189 (Clear Soup / Full): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017189 (Clear Soup / Half): portion label inferred (Full/Half order assumed) -- source gave a bare slash price with no label (confidence 0.55)
-- menu_item_id 400070017192 (Tomato Soup): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017198 (Mix Fried Rice): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017199 (Mix Schezwan Fried Rice): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017212 (Chinese Chopsuey): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017214 (Chinese Chopsuey): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017222 (Mix Hakka Noodles): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017223 (Mix Schn. Hakka Noodles): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017235 (Cheese Pizza): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017236 (Mix. Pizza): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017238 (Extra Cheese): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017279 (Malai Kulfi / Regular): no price captured in source JSON (confidence 0.2)
-- menu_item_id 400070017280 (Keser Pista / Regular): no price captured in source JSON (confidence 0.2)
-- menu_item_id 400070017281 (Badam Pista / Regular): no price captured in source JSON (confidence 0.2)
-- menu_item_id 400070017287 (Mineral Water / Regular): no price captured in source JSON (confidence 0.2)
-- menu_item_id 400070017288 (All Soft Drinks (300 ml) / Regular): no price captured in source JSON (confidence 0.2)
-- menu_item_id 400070017289 (All Soft Drinks (500 ml, 2 ltr) / Regular): no price captured in source JSON (confidence 0.2)
-- menu_item_id 400070017293 (Soda / Regular): no price captured in source JSON (confidence 0.2)
-- menu_item_id 400070017306 (Jeera Rice (1 Kg)): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070017307 (Rice (1 kg)): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review

-- === UNMAPPED / INFORMATIONAL RESTAURANT-LEVEL NOTES ===
-- price-per-person from JSON: "₹200–800" -- no matching restaurant-level column; not inserted anywhere.
-- HALAL: attempted as a restaurant_tag lookup against platform_tag (tag_code='halal') above; if that tag doesn't exist yet in the live database the insert was a no-op -- verify and add the tag if it should exist.
-- 'NO BEEF' page notice: informational assurance text, not a formal dietary tag/column; not inserted anywhere.

COMMIT;