-- Khaustan menu onboarding: Mani's Cafe
-- Source JSON: Manis_Cafe_Menu_OCR.json
-- Source image(s): Mani1.jpg, Mani2.jpg
-- establishment_id / restaurant_id / source_id namespace: 400081006 (taken directly from the source JSON)
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
-- Brand: identify-or-create by explicit brand_id (given directly, not a read-only
-- lookup table -- brand is an actively-growing entity like canonical_dish/bar_product).
INSERT INTO brand (brand_id, name, normalized_name)
SELECT 00001100001, 'Mani''s Cafe', 'mani''s cafe'
WHERE NOT EXISTS (SELECT 1 FROM brand WHERE brand_id = 001100001);

INSERT INTO establishment (
    establishment_id, name, normalized_name, address_line1, address_line2,
    locality, city, state, country_code, postal_code, latitude, longitude
) VALUES (
    400081006, 'Mani''s Cafe', 'mani''s cafe',
    'Sainath Nagar', NULL, 'Mulund', 'Mumbai',
    'Maharashtra', 'IN', '400081', 19.168347635682967, 72.96096492892093
);

INSERT INTO restaurant (
    restaurant_id, establishment_id, brand_id, display_name, normalized_name,
    veg_nonveg_status, has_bar, bar_license_type
) VALUES (
    400081006, 400081006, 001100001, 'Mani''s Cafe', 'mani''s cafe',
    'pure_veg', FALSE, 'none'
);

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400081006, 'ai_menu_extraction', 'Manis_Cafe_Menu_OCR.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, status_code)
VALUES (nextval('khaustan_standalone_id_seq'), 400081006, 400081006, (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');
SELECT extraction_batch_id FROM menu_extraction_batch WHERE source_id = 400081006 ORDER BY extraction_batch_id DESC LIMIT 1 \gset

-- Phones
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES
    (nextval('khaustan_standalone_id_seq'), 400081006, '8451948393', TRUE);

-- Hours: single stated window applied to every day (JSON gives one blanket timing,
-- no per-day breakdown) -- confidence: inferred blanket application, not per-day-confirmed.
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
VALUES
    (nextval('khaustan_standalone_id_seq'), 400081006, 1, 1, '06:00'::time, '23:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400081006, 2, 1, '06:00'::time, '23:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400081006, 3, 1, '06:00'::time, '23:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400081006, 4, 1, '06:00'::time, '23:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400081006, 5, 1, '06:00'::time, '23:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400081006, 6, 1, '06:00'::time, '23:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400081006, 7, 1, '06:00'::time, '23:00'::time);

-- HALAL restaurant tag: safe lookup-only insert. If 'halal' isn't yet a platform_tag
-- tag_code, this JOIN matches zero rows and inserts nothing -- no error, no new lookup
-- row created (lookup tables are read-only for this script).
INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id)
SELECT nextval('khaustan_standalone_id_seq'), 400081006, tag_id FROM platform_tag WHERE tag_code = 'halal';

-- Menu board: one a_la_carte board for the whole JSON source.
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, is_active, display_sequence)
VALUES (400081006001, 400081006, 'Main Menu', 'a_la_carte', TRUE, 1);

-- Categories, in JSON/source order. Where the source nests a subcategory (e.g.
-- STARTERS -> INDIAN / CHINESE), the top-level name becomes a parent row and the
-- subcategory becomes its child via parent_category_id -- the leaf (child) is what
-- items attach to. A category name repeated across two distinct source sections (this
-- happens at least once in this batch) is kept as two separate rows, not merged --
-- these are keyed by source position, not by display name.
INSERT INTO menu_category (menu_category_id, restaurant_id, name, parent_category_id, display_sequence)
VALUES
    (400081006001, 400081006, 'SNACKS', NULL, 1),
    (400081006002, 400081006, 'MANI''S SPECIAL SNACKS', NULL, 2),
    (400081006003, 400081006, 'GHEE PODI VARIETIES', NULL, 3),
    (400081006004, 400081006, 'LUNCH', NULL, 4),
    (400081006005, 400081006, 'DOSA VARIETIES', NULL, 5),
    (400081006006, 400081006, 'PANEER DOSA VARIETIES', NULL, 6),
    (400081006007, 400081006, 'UTTAPAM VARIETIES', NULL, 7),
    (400081006008, 400081006, 'JAIN SPECIAL', NULL, 8),
    (400081006009, 400081006, 'RAWA & RAGI DOSA VARIETIES', NULL, 9),
    (400081006010, 400081006, 'MANI''S SPECIAL DOSA', NULL, 10),
    (400081006011, 400081006, 'HOT BEVERAGE', NULL, 11),
    (400081006012, 400081006, 'COLD BEVERAGE', NULL, 12),
    (400081006013, 400081006, 'EXTRA', NULL, 13),
    (400081006014, 400081006, 'FRESH JUICE', NULL, 14),
    (400081006015, 400081006, 'MOCKTAILS MOJITO BLUEBERRY', NULL, 15),
    (400081006016, 400081006, 'MILK SHAKES', NULL, 16);

-- Board <-> category mapping (leaf categories only)
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (400081006, 400081006001, 400081006001, 1),
    (400081006, 400081006001, 400081006002, 2),
    (400081006, 400081006001, 400081006003, 3),
    (400081006, 400081006001, 400081006004, 4),
    (400081006, 400081006001, 400081006005, 5),
    (400081006, 400081006001, 400081006006, 6),
    (400081006, 400081006001, 400081006007, 7),
    (400081006, 400081006001, 400081006008, 8),
    (400081006, 400081006001, 400081006009, 9),
    (400081006, 400081006001, 400081006010, 10),
    (400081006, 400081006001, 400081006011, 11),
    (400081006, 400081006001, 400081006012, 12),
    (400081006, 400081006001, 400081006013, 13),
    (400081006, 400081006001, 400081006014, 14),
    (400081006, 400081006001, 400081006015, 15),
    (400081006, 400081006001, 400081006016, 16);

-- Canonical dish identify-or-create: no unique constraint on canonical_dish.normalized_name,
-- so NOT EXISTS, not ON CONFLICT. Whether these already exist from an earlier onboarded
-- restaurant is resolved live by this check when the script runs.
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PONGAL (ONLY MORNING)', 'pongal (only morning)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pongal (only morning)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PONGAL (ONLY MORNING)', 'pongal (only morning)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SWEET PONGAL (ONLY SUNDAY)', 'sweet pongal (only sunday)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sweet pongal (only sunday)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SWEET PONGAL (ONLY SUNDAY)', 'sweet pongal (only sunday)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KANDA POHA (ONLY MORNING)', 'kanda poha (only morning)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kanda poha (only morning)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KANDA POHA (ONLY MORNING)', 'kanda poha (only morning)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PINEAPPLE SHEERA', 'pineapple sheera'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pineapple sheera')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PINEAPPLE SHEERA', 'pineapple sheera', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'UPMA', 'upma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'upma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'UPMA', 'upma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SHEERA UPMA MIX', 'sheera upma mix'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sheera upma mix')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SHEERA UPMA MIX', 'sheera upma mix', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SHEERA POHA MIX', 'sheera poha mix'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sheera poha mix')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SHEERA POHA MIX', 'sheera poha mix', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'IDLI', 'idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'IDLI', 'idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MEDU VADA', 'medu vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'medu vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MEDU VADA', 'medu vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'IDLI VADA MIX', 'idli vada mix'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'idli vada mix')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'IDLI VADA MIX', 'idli vada mix', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'DAL VADA', 'dal vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'DAL VADA', 'dal vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA SINGLE IDLI', 'extra single idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra single idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA SINGLE IDLI', 'extra single idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA SINGLE VADA', 'extra single vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra single vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA SINGLE VADA', 'extra single vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA SINGLE DAL VADA', 'extra single dal vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra single dal vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA SINGLE DAL VADA', 'extra single dal vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'IDLI & DAL VADA MIX', 'idli & dal vada mix'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'idli & dal vada mix')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'IDLI & DAL VADA MIX', 'idli & dal vada mix', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MEDU & DAL VADA MIX', 'medu & dal vada mix'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'medu & dal vada mix')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MEDU & DAL VADA MIX', 'medu & dal vada mix', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'DAL VADA & BONDA MIX', 'dal vada & bonda mix'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal vada & bonda mix')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'DAL VADA & BONDA MIX', 'dal vada & bonda mix', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MYSORE BONDA', 'mysore bonda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mysore bonda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MYSORE BONDA', 'mysore bonda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'RASAM IDLI', 'rasam idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rasam idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'RASAM IDLI', 'rasam idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'RASAM VADA', 'rasam vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rasam vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'RASAM VADA', 'rasam vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PURI BHAJI', 'puri bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'puri bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PURI BHAJI', 'puri bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SABUDANA VADA (FASTING)', 'sabudana vada (fasting)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sabudana vada (fasting)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SABUDANA VADA (FASTING)', 'sabudana vada (fasting)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SABUDANA KHICHDI (FASTING)', 'sabudana khichdi (fasting)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sabudana khichdi (fasting)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SABUDANA KHICHDI (FASTING)', 'sabudana khichdi (fasting)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SOUTH INDIAN PLATTER', 'south indian platter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'south indian platter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SOUTH INDIAN PLATTER', 'south indian platter', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KELA BHAJI', 'kela bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kela bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KELA BHAJI', 'kela bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BUTTER IDLI', 'butter idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BUTTER IDLI', 'butter idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'COIN IDLI', 'coin idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'coin idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'COIN IDLI', 'coin idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'FRENCH FRY IDLI', 'french fry idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'french fry idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'FRENCH FRY IDLI', 'french fry idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GHEE IDLI', 'ghee idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GHEE IDLI', 'ghee idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MASALA IDLI', 'masala idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MASALA IDLI', 'masala idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'THAVA IDLI', 'thava idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'thava idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'THAVA IDLI', 'thava idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'THATTE IDLI', 'thatte idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'thatte idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'THATTE IDLI', 'thatte idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHILLI IDLI', 'chilli idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilli idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHILLI IDLI', 'chilli idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SIZZLER IDLI', 'sizzler idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sizzler idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SIZZLER IDLI', 'sizzler idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'DRY MANCHURIAN IDLI', 'dry manchurian idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dry manchurian idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'DRY MANCHURIAN IDLI', 'dry manchurian idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHEESE IDLI', 'cheese idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHEESE IDLI', 'cheese idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MASALA VADA', 'masala vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MASALA VADA', 'masala vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHILLI VADA', 'chilli vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilli vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHILLI VADA', 'chilli vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'APPAM (2 Pcs.)', 'appam (2 pcs.)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'appam (2 pcs.)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'APPAM (2 Pcs.)', 'appam (2 pcs.)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANIYARAM', 'paniyaram'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paniyaram')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANIYARAM', 'paniyaram', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MANI''S SPECIAL IDLI', 'mani''s special idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mani''s special idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MANI''S SPECIAL IDLI', 'mani''s special idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'DRY SCHEZWAN IDLI', 'dry schezwan idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dry schezwan idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'DRY SCHEZWAN IDLI', 'dry schezwan idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'DRY SCHEZWAN VADA', 'dry schezwan vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dry schezwan vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'DRY SCHEZWAN VADA', 'dry schezwan vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'DRY MANCHURIAN VADA', 'dry manchurian vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dry manchurian vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'DRY MANCHURIAN VADA', 'dry manchurian vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHEESE CHILLI VADA', 'cheese chilli vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chilli vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHEESE CHILLI VADA', 'cheese chilli vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GHEE PODI UPMA', 'ghee podi upma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee podi upma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GHEE PODI UPMA', 'ghee podi upma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GHEE PODI IDLI', 'ghee podi idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee podi idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GHEE PODI IDLI', 'ghee podi idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GHEE PODI VADA', 'ghee podi vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee podi vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GHEE PODI VADA', 'ghee podi vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GHEE PODI DOSA', 'ghee podi dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee podi dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GHEE PODI DOSA', 'ghee podi dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GHEE PODI UTTAPAM', 'ghee podi uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee podi uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GHEE PODI UTTAPAM', 'ghee podi uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GHEE PODI APPAM (2 Pcs.)', 'ghee podi appam (2 pcs.)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee podi appam (2 pcs.)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GHEE PODI APPAM (2 Pcs.)', 'ghee podi appam (2 pcs.)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GHEE ROAST DOSA', 'ghee roast dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ghee roast dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GHEE ROAST DOSA', 'ghee roast dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. BIRYANI', 'veg. biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. BIRYANI', 'veg. biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. PULAO', 'veg. pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. PULAO', 'veg. pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BISI BELE BHATH', 'bisi bele bhath'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bisi bele bhath')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BISI BELE BHATH', 'bisi bele bhath', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'TOMATO RICE', 'tomato rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'TOMATO RICE', 'tomato rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'LEMON RICE', 'lemon rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'LEMON RICE', 'lemon rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CURD RICE', 'curd rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'curd rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CURD RICE', 'curd rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER BIRYANI', 'paneer biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER BIRYANI', 'paneer biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER PULAO', 'paneer pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER PULAO', 'paneer pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHEESE BIRYANI', 'cheese biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHEESE BIRYANI', 'cheese biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHEESE PULAO', 'cheese pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHEESE PULAO', 'cheese pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'TAWA PULAO', 'tawa pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tawa pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'TAWA PULAO', 'tawa pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHEESE TAWA PULAO', 'cheese tawa pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese tawa pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHEESE TAWA PULAO', 'cheese tawa pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'POROTTA KURMA', 'porotta kurma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'porotta kurma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'POROTTA KURMA', 'porotta kurma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SADA DOSA', 'sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SADA DOSA', 'sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MASALA DOSA', 'masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MASALA DOSA', 'masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ONION SADA DOSA', 'onion sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ONION SADA DOSA', 'onion sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MYSORE SADA DOSA', 'mysore sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mysore sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MYSORE SADA DOSA', 'mysore sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SCHEZWAN SADA DOSA', 'schezwan sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SCHEZWAN SADA DOSA', 'schezwan sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KOLHAPURI SADA DOSA', 'kolhapuri sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kolhapuri sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KOLHAPURI SADA DOSA', 'kolhapuri sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GARLIC SADA DOSA', 'garlic sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GARLIC SADA DOSA', 'garlic sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ONION MYSORE SADA DOSA', 'onion mysore sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion mysore sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ONION MYSORE SADA DOSA', 'onion mysore sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ONION SCHEZWAN SADA DOSA', 'onion schezwan sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion schezwan sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ONION SCHEZWAN SADA DOSA', 'onion schezwan sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ONION MASALA DOSA', 'onion masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ONION MASALA DOSA', 'onion masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MYSORE MASALA DOSA', 'mysore masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mysore masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MYSORE MASALA DOSA', 'mysore masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SCHEZWAN MASALA DOSA', 'schezwan masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SCHEZWAN MASALA DOSA', 'schezwan masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KOLHAPURI MASALA DOSA', 'kolhapuri masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kolhapuri masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KOLHAPURI MASALA DOSA', 'kolhapuri masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GARLIC MASALA DOSA', 'garlic masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GARLIC MASALA DOSA', 'garlic masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PAPER SADA DOSA', 'paper sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paper sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PAPER SADA DOSA', 'paper sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PAPER MASALA DOSA', 'paper masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paper masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PAPER MASALA DOSA', 'paper masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MAYO MYSORE SADA DOSA', 'mayo mysore sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mayo mysore sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MAYO MYSORE SADA DOSA', 'mayo mysore sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MAYO MYSORE MASALA DOSA', 'mayo mysore masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mayo mysore masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MAYO MYSORE MASALA DOSA', 'mayo mysore masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MAYO SCHEZWAN SADA DOSA', 'mayo schezwan sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mayo schezwan sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MAYO SCHEZWAN SADA DOSA', 'mayo schezwan sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MAYO SCHEZWAN MASALA DOSA', 'mayo schezwan masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mayo schezwan masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MAYO SCHEZWAN MASALA DOSA', 'mayo schezwan masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER SADA DOSA', 'paneer sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER SADA DOSA', 'paneer sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER MASALA DOSA', 'paneer masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER MASALA DOSA', 'paneer masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER MYSORE MASALA DOSA', 'paneer mysore masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer mysore masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER MYSORE MASALA DOSA', 'paneer mysore masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER SCHEZWAN MASALA DOSA', 'paneer schezwan masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer schezwan masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER SCHEZWAN MASALA DOSA', 'paneer schezwan masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SADA UTTAPAM', 'sada uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sada uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SADA UTTAPAM', 'sada uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ONION UTTAPAM', 'onion uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ONION UTTAPAM', 'onion uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'TOMATO UTTAPAM', 'tomato uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'TOMATO UTTAPAM', 'tomato uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ONION TOMATO UTTAPAM', 'onion tomato uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion tomato uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ONION TOMATO UTTAPAM', 'onion tomato uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MASALA UTTAPAM', 'masala uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MASALA UTTAPAM', 'masala uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEGETABLE UTTAPAM', 'vegetable uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vegetable uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEGETABLE UTTAPAM', 'vegetable uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'RAGI ONION UTTAPAM', 'ragi onion uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ragi onion uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'RAGI ONION UTTAPAM', 'ragi onion uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MYSORE SADA UTTAPAM', 'mysore sada uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mysore sada uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MYSORE SADA UTTAPAM', 'mysore sada uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SCHEZWAN SADA UTTAPAM', 'schezwan sada uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan sada uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SCHEZWAN SADA UTTAPAM', 'schezwan sada uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MYSORE MASALA UTTAPAM', 'mysore masala uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mysore masala uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MYSORE MASALA UTTAPAM', 'mysore masala uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SCHEZWAN MASALA UTTAPAM', 'schezwan masala uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan masala uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SCHEZWAN MASALA UTTAPAM', 'schezwan masala uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN UPMA', 'jain upma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain upma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN UPMA', 'jain upma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN THAVA IDLI', 'jain thava idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain thava idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN THAVA IDLI', 'jain thava idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN MASALA IDLI', 'jain masala idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain masala idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN MASALA IDLI', 'jain masala idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN CHILLI IDLI', 'jain chilli idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain chilli idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN CHILLI IDLI', 'jain chilli idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN SIZZLER IDLI', 'jain sizzler idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain sizzler idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN SIZZLER IDLI', 'jain sizzler idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN MANCHURIAN IDLI', 'jain manchurian idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain manchurian idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN MANCHURIAN IDLI', 'jain manchurian idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN MASALA VADA', 'jain masala vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain masala vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN MASALA VADA', 'jain masala vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN CHILLI VADA', 'jain chilli vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain chilli vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN CHILLI VADA', 'jain chilli vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN SADA DOSA', 'jain sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN SADA DOSA', 'jain sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN MASALA DOSA', 'jain masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN MASALA DOSA', 'jain masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN MYSORE SADA DOSA', 'jain mysore sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain mysore sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN MYSORE SADA DOSA', 'jain mysore sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN MYSORE MASALA DOSA', 'jain mysore masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain mysore masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN MYSORE MASALA DOSA', 'jain mysore masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN SCHEZWAN MASALA DOSA', 'jain schezwan masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain schezwan masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN SCHEZWAN MASALA DOSA', 'jain schezwan masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN SPRING DOSA', 'jain spring dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain spring dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN SPRING DOSA', 'jain spring dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN MATKA DOSA', 'jain matka dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain matka dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN MATKA DOSA', 'jain matka dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN PLAIN UTTAPAM', 'jain plain uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain plain uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN PLAIN UTTAPAM', 'jain plain uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN TOMATO UTTAPAM', 'jain tomato uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain tomato uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN TOMATO UTTAPAM', 'jain tomato uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN MASALA UTTAPAM', 'jain masala uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain masala uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN MASALA UTTAPAM', 'jain masala uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN VEGETABLE UTTAPAM', 'jain vegetable uttapam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain vegetable uttapam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN VEGETABLE UTTAPAM', 'jain vegetable uttapam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN RAVA SADA DOSA', 'jain rava sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain rava sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN RAVA SADA DOSA', 'jain rava sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN RAVA MASALA DOSA', 'jain rava masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain rava masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN RAVA MASALA DOSA', 'jain rava masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'RAWA DOSA', 'rawa dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawa dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'RAWA DOSA', 'rawa dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'RAGI DOSA', 'ragi dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ragi dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'RAGI DOSA', 'ragi dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ONION RAWA DOSA', 'onion rawa dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion rawa dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ONION RAWA DOSA', 'onion rawa dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ONION RAGI DOSA', 'onion ragi dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion ragi dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ONION RAGI DOSA', 'onion ragi dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'RAWA MASALA DOSA', 'rawa masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawa masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'RAWA MASALA DOSA', 'rawa masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'RAGI MASALA DOSA', 'ragi masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ragi masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'RAGI MASALA DOSA', 'ragi masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ONION RAWA MASALA DOSA', 'onion rawa masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion rawa masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ONION RAWA MASALA DOSA', 'onion rawa masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ONION RAGI MASALA DOSA', 'onion ragi masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion ragi masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ONION RAGI MASALA DOSA', 'onion ragi masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MYSORE RAWA SADA DOSA', 'mysore rawa sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mysore rawa sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MYSORE RAWA SADA DOSA', 'mysore rawa sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MYSORE RAWA MASALA DOSA', 'mysore rawa masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mysore rawa masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MYSORE RAWA MASALA DOSA', 'mysore rawa masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SCHEZWAN RAWA SADA DOSA', 'schezwan rawa sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan rawa sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SCHEZWAN RAWA SADA DOSA', 'schezwan rawa sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SCHEZWAN RAWA MASALA DOSA', 'schezwan rawa masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan rawa masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SCHEZWAN RAWA MASALA DOSA', 'schezwan rawa masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'LONI (DAWANGERE) DOSA (2 Pcs.)', 'loni (dawangere) dosa (2 pcs.)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'loni (dawangere) dosa (2 pcs.)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'LONI (DAWANGERE) DOSA (2 Pcs.)', 'loni (dawangere) dosa (2 pcs.)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BENNE DOSA', 'benne dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'benne dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BENNE DOSA', 'benne dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BENNE MASALA DOSA', 'benne masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'benne masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BENNE MASALA DOSA', 'benne masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SPRING DOSA', 'spring dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spring dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SPRING DOSA', 'spring dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PAV BHAJI DOSA', 'pav bhaji dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pav bhaji dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PAV BHAJI DOSA', 'pav bhaji dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SET DOSA', 'set dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'set dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SET DOSA', 'set dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BANANA DOSA', 'banana dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'banana dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BANANA DOSA', 'banana dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SWEET COCONUT DOSA', 'sweet coconut dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sweet coconut dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SWEET COCONUT DOSA', 'sweet coconut dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'NOODLES DOSA', 'noodles dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'noodles dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'NOODLES DOSA', 'noodles dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHEESE CHILLI DOSA', 'cheese chilli dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chilli dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHEESE CHILLI DOSA', 'cheese chilli dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHEESE CORN DOSA', 'cheese corn dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese corn dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHEESE CORN DOSA', 'cheese corn dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GINI DOSA', 'gini dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'gini dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GINI DOSA', 'gini dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KERALA MASALA DOSA', 'kerala masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kerala masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KERALA MASALA DOSA', 'kerala masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHEESE LAYS DOSA', 'cheese lays dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese lays dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHEESE LAYS DOSA', 'cheese lays dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'DILKHUSH DOSA', 'dilkhush dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dilkhush dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'DILKHUSH DOSA', 'dilkhush dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GARDEN DOSA', 'garden dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garden dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GARDEN DOSA', 'garden dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PIZZA DOSA', 'pizza dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pizza dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PIZZA DOSA', 'pizza dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MATKA DOSA', 'matka dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'matka dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MATKA DOSA', 'matka dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MANI''S SPECIAL DOSA', 'mani''s special dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mani''s special dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MANI''S SPECIAL DOSA', 'mani''s special dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'UPVAS DOSA', 'upvas dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'upvas dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'UPVAS DOSA', 'upvas dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHILLI DOSA', 'chilli dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilli dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHILLI DOSA', 'chilli dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SPECIAL PANNER MASALA DOSA', 'special panner masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'special panner masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SPECIAL PANNER MASALA DOSA', 'special panner masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'AMERICAN CHOPSLUEY DOSA', 'american chopsluey dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'american chopsluey dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'AMERICAN CHOPSLUEY DOSA', 'american chopsluey dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER TIKKA DOSA', 'paneer tikka dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER TIKKA DOSA', 'paneer tikka dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GOLMAL DOSA', 'golmal dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'golmal dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GOLMAL DOSA', 'golmal dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BAHUBALI DOSA', 'bahubali dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bahubali dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BAHUBALI DOSA', 'bahubali dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'FULL TEA', 'full tea'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'full tea')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'FULL TEA', 'full tea', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BLACK TEA', 'black tea'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'black tea')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BLACK TEA', 'black tea', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'LEMON TEA', 'lemon tea'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon tea')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'LEMON TEA', 'lemon tea', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GREEN TEA', 'green tea'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green tea')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GREEN TEA', 'green tea', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'FILTER COFFEE', 'filter coffee'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'filter coffee')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'FILTER COFFEE', 'filter coffee', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BLACK COFFEE', 'black coffee'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'black coffee')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BLACK COFFEE', 'black coffee', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MILK', 'milk'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'milk')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MILK', 'milk', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KESAR UKALA', 'kesar ukala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kesar ukala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KESAR UKALA', 'kesar ukala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'HOT CHOCOLATE', 'hot chocolate'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hot chocolate')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'HOT CHOCOLATE', 'hot chocolate', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BUTTER MILK', 'butter milk'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter milk')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BUTTER MILK', 'butter milk', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'LASSI', 'lassi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lassi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'LASSI', 'lassi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KESAR LASSI', 'kesar lassi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kesar lassi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KESAR LASSI', 'kesar lassi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MANGO LASSI', 'mango lassi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mango lassi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MANGO LASSI', 'mango lassi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'DAHI IDLI', 'dahi idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dahi idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'DAHI IDLI', 'dahi idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'DAHI VADA', 'dahi vada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dahi vada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'DAHI VADA', 'dahi vada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA BUTTER', 'extra butter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra butter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA BUTTER', 'extra butter', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA GHEE', 'extra ghee'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra ghee')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA GHEE', 'extra ghee', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA PODI', 'extra podi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra podi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA PODI', 'extra podi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA MAYO', 'extra mayo'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra mayo')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA MAYO', 'extra mayo', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA PANEER', 'extra paneer'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra paneer')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA PANEER', 'extra paneer', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA CHEESE', 'extra cheese'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra cheese')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA CHEESE', 'extra cheese', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA CHATNI', 'extra chatni'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra chatni')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA CHATNI', 'extra chatni', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA SCHEZWAN', 'extra schezwan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra schezwan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA SCHEZWAN', 'extra schezwan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA SAMBHAR', 'extra sambhar'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra sambhar')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA SAMBHAR', 'extra sambhar', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA ONION', 'extra onion'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra onion')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA ONION', 'extra onion', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA RASAM', 'extra rasam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra rasam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA RASAM', 'extra rasam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA KURMA', 'extra kurma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra kurma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA KURMA', 'extra kurma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA PAPAD', 'extra papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA PAPAD', 'extra papad', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SWET BEEDA', 'swet beeda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'swet beeda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SWET BEEDA', 'swet beeda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'FRESH LEMON JUICE', 'fresh lemon juice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fresh lemon juice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'FRESH LEMON JUICE', 'fresh lemon juice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'FRESH LEMON SODA', 'fresh lemon soda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fresh lemon soda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'FRESH LEMON SODA', 'fresh lemon soda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'NANNARI SARBATH', 'nannari sarbath'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'nannari sarbath')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'NANNARI SARBATH', 'nannari sarbath', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MINT COOLER', 'mint cooler'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mint cooler')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MINT COOLER', 'mint cooler', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'TENDER COCONUT', 'tender coconut'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tender coconut')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'TENDER COCONUT', 'tender coconut', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KOKUM SARBATH', 'kokum sarbath'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kokum sarbath')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KOKUM SARBATH', 'kokum sarbath', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'LEMON ICE TEA', 'lemon ice tea'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon ice tea')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'LEMON ICE TEA', 'lemon ice tea', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ORANGE', 'orange'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'orange')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ORANGE', 'orange', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'LEMON PUDINA', 'lemon pudina'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon pudina')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'LEMON PUDINA', 'lemon pudina', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BLUEBERRY', 'blueberry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'blueberry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BLUEBERRY', 'blueberry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'COLD COFFEE', 'cold coffee'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cold coffee')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'COLD COFFEE', 'cold coffee', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ROSE MILKSHAKE', 'rose milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rose milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ROSE MILKSHAKE', 'rose milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VANILLA MILKSHAKE', 'vanilla milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'vanilla milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VANILLA MILKSHAKE', 'vanilla milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BADAM MILKSHAKE', 'badam milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'badam milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BADAM MILKSHAKE', 'badam milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'STRAWBERRY MILKSHAKE', 'strawberry milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'strawberry milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'STRAWBERRY MILKSHAKE', 'strawberry milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHOCOLATE MILKSHAKE', 'chocolate milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chocolate milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHOCOLATE MILKSHAKE', 'chocolate milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KITKAT MILKSHAKE', 'kitkat milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kitkat milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KITKAT MILKSHAKE', 'kitkat milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'OREO MILKSHAKE', 'oreo milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'oreo milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'OREO MILKSHAKE', 'oreo milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MANGO MILKSHAKE', 'mango milkshake'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mango milkshake')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MANGO MILKSHAKE', 'mango milkshake', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KESAR THANDAI', 'kesar thandai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kesar thandai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KESAR THANDAI', 'kesar thandai', 'primary'
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
    (400081006001, 400081006, 'PONGAL (ONLY MORNING)', 'pongal (only morning)', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006002, 400081006, 'SWEET PONGAL (ONLY SUNDAY)', 'sweet pongal (only sunday)', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006003, 400081006, 'KANDA POHA (ONLY MORNING)', 'kanda poha (only morning)', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006004, 400081006, 'PINEAPPLE SHEERA', 'pineapple sheera', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006005, 400081006, 'UPMA', 'upma', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006006, 400081006, 'SHEERA UPMA MIX', 'sheera upma mix', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006007, 400081006, 'SHEERA POHA MIX', 'sheera poha mix', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006008, 400081006, 'IDLI', 'idli', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006009, 400081006, 'MEDU VADA', 'medu vada', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006010, 400081006, 'IDLI VADA MIX', 'idli vada mix', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006011, 400081006, 'DAL VADA', 'dal vada', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006012, 400081006, 'EXTRA SINGLE IDLI', 'extra single idli', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006013, 400081006, 'EXTRA SINGLE VADA', 'extra single vada', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006014, 400081006, 'EXTRA SINGLE DAL VADA', 'extra single dal vada', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006015, 400081006, 'IDLI & DAL VADA MIX', 'idli & dal vada mix', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006016, 400081006, 'MEDU & DAL VADA MIX', 'medu & dal vada mix', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006017, 400081006, 'DAL VADA & BONDA MIX', 'dal vada & bonda mix', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006018, 400081006, 'MYSORE BONDA', 'mysore bonda', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006019, 400081006, 'RASAM IDLI', 'rasam idli', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006020, 400081006, 'RASAM VADA', 'rasam vada', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006021, 400081006, 'PURI BHAJI', 'puri bhaji', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006022, 400081006, 'SABUDANA VADA (FASTING)', 'sabudana vada (fasting)', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006023, 400081006, 'SABUDANA KHICHDI (FASTING)', 'sabudana khichdi (fasting)', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006024, 400081006, 'SOUTH INDIAN PLATTER', 'south indian platter', 'SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006025, 400081006, 'KELA BHAJI', 'kela bhaji', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006026, 400081006, 'BUTTER IDLI', 'butter idli', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006027, 400081006, 'COIN IDLI', 'coin idli', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006028, 400081006, 'FRENCH FRY IDLI', 'french fry idli', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006029, 400081006, 'GHEE IDLI', 'ghee idli', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006030, 400081006, 'MASALA IDLI', 'masala idli', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006031, 400081006, 'THAVA IDLI', 'thava idli', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006032, 400081006, 'THATTE IDLI', 'thatte idli', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006033, 400081006, 'CHILLI IDLI', 'chilli idli', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006034, 400081006, 'SIZZLER IDLI', 'sizzler idli', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006035, 400081006, 'DRY MANCHURIAN IDLI', 'dry manchurian idli', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006036, 400081006, 'CHEESE IDLI', 'cheese idli', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006037, 400081006, 'MASALA VADA', 'masala vada', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006038, 400081006, 'CHILLI VADA', 'chilli vada', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006039, 400081006, 'APPAM (2 Pcs.)', 'appam (2 pcs.)', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006040, 400081006, 'PANIYARAM', 'paniyaram', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006041, 400081006, 'MANI''S SPECIAL IDLI', 'mani''s special idli', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006042, 400081006, 'DRY SCHEZWAN IDLI', 'dry schezwan idli', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006043, 400081006, 'DRY SCHEZWAN VADA', 'dry schezwan vada', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006044, 400081006, 'DRY MANCHURIAN VADA', 'dry manchurian vada', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006045, 400081006, 'CHEESE CHILLI VADA', 'cheese chilli vada', 'MANI''S SPECIAL SNACKS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006046, 400081006, 'GHEE PODI UPMA', 'ghee podi upma', 'GHEE PODI VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006047, 400081006, 'GHEE PODI IDLI', 'ghee podi idli', 'GHEE PODI VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006048, 400081006, 'GHEE PODI VADA', 'ghee podi vada', 'GHEE PODI VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006049, 400081006, 'GHEE PODI DOSA', 'ghee podi dosa', 'GHEE PODI VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006050, 400081006, 'GHEE PODI UTTAPAM', 'ghee podi uttapam', 'GHEE PODI VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006051, 400081006, 'GHEE PODI APPAM (2 Pcs.)', 'ghee podi appam (2 pcs.)', 'GHEE PODI VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006052, 400081006, 'GHEE ROAST DOSA', 'ghee roast dosa', 'GHEE PODI VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006053, 400081006, 'VEG. BIRYANI', 'veg. biryani', 'LUNCH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006054, 400081006, 'VEG. PULAO', 'veg. pulao', 'LUNCH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006055, 400081006, 'BISI BELE BHATH', 'bisi bele bhath', 'LUNCH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006056, 400081006, 'TOMATO RICE', 'tomato rice', 'LUNCH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006057, 400081006, 'LEMON RICE', 'lemon rice', 'LUNCH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006058, 400081006, 'CURD RICE', 'curd rice', 'LUNCH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006059, 400081006, 'PANEER BIRYANI', 'paneer biryani', 'LUNCH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006060, 400081006, 'PANEER PULAO', 'paneer pulao', 'LUNCH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006061, 400081006, 'CHEESE BIRYANI', 'cheese biryani', 'LUNCH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006062, 400081006, 'CHEESE PULAO', 'cheese pulao', 'LUNCH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006063, 400081006, 'TAWA PULAO', 'tawa pulao', 'LUNCH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006064, 400081006, 'CHEESE TAWA PULAO', 'cheese tawa pulao', 'LUNCH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006065, 400081006, 'POROTTA KURMA', 'porotta kurma', 'LUNCH', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006066, 400081006, 'SADA DOSA', 'sada dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006067, 400081006, 'MASALA DOSA', 'masala dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006068, 400081006, 'ONION SADA DOSA', 'onion sada dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006069, 400081006, 'MYSORE SADA DOSA', 'mysore sada dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006070, 400081006, 'SCHEZWAN SADA DOSA', 'schezwan sada dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006071, 400081006, 'KOLHAPURI SADA DOSA', 'kolhapuri sada dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006072, 400081006, 'GARLIC SADA DOSA', 'garlic sada dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006073, 400081006, 'ONION MYSORE SADA DOSA', 'onion mysore sada dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006074, 400081006, 'ONION SCHEZWAN SADA DOSA', 'onion schezwan sada dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006075, 400081006, 'ONION MASALA DOSA', 'onion masala dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006076, 400081006, 'MYSORE MASALA DOSA', 'mysore masala dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006077, 400081006, 'SCHEZWAN MASALA DOSA', 'schezwan masala dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006078, 400081006, 'KOLHAPURI MASALA DOSA', 'kolhapuri masala dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006079, 400081006, 'GARLIC MASALA DOSA', 'garlic masala dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006080, 400081006, 'PAPER SADA DOSA', 'paper sada dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006081, 400081006, 'PAPER MASALA DOSA', 'paper masala dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006082, 400081006, 'MAYO MYSORE SADA DOSA', 'mayo mysore sada dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006083, 400081006, 'MAYO MYSORE MASALA DOSA', 'mayo mysore masala dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006084, 400081006, 'MAYO SCHEZWAN SADA DOSA', 'mayo schezwan sada dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006085, 400081006, 'MAYO SCHEZWAN MASALA DOSA', 'mayo schezwan masala dosa', 'DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006086, 400081006, 'PANEER SADA DOSA', 'paneer sada dosa', 'PANEER DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006087, 400081006, 'PANEER MASALA DOSA', 'paneer masala dosa', 'PANEER DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006088, 400081006, 'PANEER MYSORE MASALA DOSA', 'paneer mysore masala dosa', 'PANEER DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006089, 400081006, 'PANEER SCHEZWAN MASALA DOSA', 'paneer schezwan masala dosa', 'PANEER DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006090, 400081006, 'SADA UTTAPAM', 'sada uttapam', 'UTTAPAM VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006091, 400081006, 'ONION UTTAPAM', 'onion uttapam', 'UTTAPAM VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006092, 400081006, 'TOMATO UTTAPAM', 'tomato uttapam', 'UTTAPAM VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006093, 400081006, 'ONION TOMATO UTTAPAM', 'onion tomato uttapam', 'UTTAPAM VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006094, 400081006, 'MASALA UTTAPAM', 'masala uttapam', 'UTTAPAM VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006095, 400081006, 'VEGETABLE UTTAPAM', 'vegetable uttapam', 'UTTAPAM VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006096, 400081006, 'RAGI ONION UTTAPAM', 'ragi onion uttapam', 'UTTAPAM VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006097, 400081006, 'MYSORE SADA UTTAPAM', 'mysore sada uttapam', 'UTTAPAM VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006098, 400081006, 'SCHEZWAN SADA UTTAPAM', 'schezwan sada uttapam', 'UTTAPAM VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006099, 400081006, 'MYSORE MASALA UTTAPAM', 'mysore masala uttapam', 'UTTAPAM VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006100, 400081006, 'SCHEZWAN MASALA UTTAPAM', 'schezwan masala uttapam', 'UTTAPAM VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006101, 400081006, 'JAIN UPMA', 'jain upma', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006102, 400081006, 'JAIN THAVA IDLI', 'jain thava idli', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006103, 400081006, 'JAIN MASALA IDLI', 'jain masala idli', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006104, 400081006, 'JAIN CHILLI IDLI', 'jain chilli idli', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006105, 400081006, 'JAIN SIZZLER IDLI', 'jain sizzler idli', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006106, 400081006, 'JAIN MANCHURIAN IDLI', 'jain manchurian idli', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006107, 400081006, 'JAIN MASALA VADA', 'jain masala vada', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006108, 400081006, 'JAIN CHILLI VADA', 'jain chilli vada', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006109, 400081006, 'JAIN SADA DOSA', 'jain sada dosa', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006110, 400081006, 'JAIN MASALA DOSA', 'jain masala dosa', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006111, 400081006, 'JAIN MYSORE SADA DOSA', 'jain mysore sada dosa', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006112, 400081006, 'JAIN MYSORE MASALA DOSA', 'jain mysore masala dosa', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006113, 400081006, 'JAIN SCHEZWAN MASALA DOSA', 'jain schezwan masala dosa', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006114, 400081006, 'JAIN SPRING DOSA', 'jain spring dosa', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006115, 400081006, 'JAIN MATKA DOSA', 'jain matka dosa', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006116, 400081006, 'JAIN PLAIN UTTAPAM', 'jain plain uttapam', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006117, 400081006, 'JAIN TOMATO UTTAPAM', 'jain tomato uttapam', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006118, 400081006, 'JAIN MASALA UTTAPAM', 'jain masala uttapam', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006119, 400081006, 'JAIN VEGETABLE UTTAPAM', 'jain vegetable uttapam', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006120, 400081006, 'JAIN RAVA SADA DOSA', 'jain rava sada dosa', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006121, 400081006, 'JAIN RAVA MASALA DOSA', 'jain rava masala dosa', 'JAIN SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006122, 400081006, 'RAWA DOSA', 'rawa dosa', 'RAWA & RAGI DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006123, 400081006, 'RAGI DOSA', 'ragi dosa', 'RAWA & RAGI DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006124, 400081006, 'ONION RAWA DOSA', 'onion rawa dosa', 'RAWA & RAGI DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006125, 400081006, 'ONION RAGI DOSA', 'onion ragi dosa', 'RAWA & RAGI DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006126, 400081006, 'RAWA MASALA DOSA', 'rawa masala dosa', 'RAWA & RAGI DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006127, 400081006, 'RAGI MASALA DOSA', 'ragi masala dosa', 'RAWA & RAGI DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006128, 400081006, 'ONION RAWA MASALA DOSA', 'onion rawa masala dosa', 'RAWA & RAGI DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006129, 400081006, 'ONION RAGI MASALA DOSA', 'onion ragi masala dosa', 'RAWA & RAGI DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006130, 400081006, 'MYSORE RAWA SADA DOSA', 'mysore rawa sada dosa', 'RAWA & RAGI DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006131, 400081006, 'MYSORE RAWA MASALA DOSA', 'mysore rawa masala dosa', 'RAWA & RAGI DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006132, 400081006, 'SCHEZWAN RAWA SADA DOSA', 'schezwan rawa sada dosa', 'RAWA & RAGI DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006133, 400081006, 'SCHEZWAN RAWA MASALA DOSA', 'schezwan rawa masala dosa', 'RAWA & RAGI DOSA VARIETIES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006134, 400081006, 'LONI (DAWANGERE) DOSA (2 Pcs.)', 'loni (dawangere) dosa (2 pcs.)', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006135, 400081006, 'BENNE DOSA', 'benne dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006136, 400081006, 'BENNE MASALA DOSA', 'benne masala dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006137, 400081006, 'SPRING DOSA', 'spring dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006138, 400081006, 'PAV BHAJI DOSA', 'pav bhaji dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006139, 400081006, 'SET DOSA', 'set dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006140, 400081006, 'BANANA DOSA', 'banana dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006141, 400081006, 'SWEET COCONUT DOSA', 'sweet coconut dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006142, 400081006, 'NOODLES DOSA', 'noodles dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006143, 400081006, 'CHEESE CHILLI DOSA', 'cheese chilli dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006144, 400081006, 'CHEESE CORN DOSA', 'cheese corn dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006145, 400081006, 'GINI DOSA', 'gini dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006146, 400081006, 'KERALA MASALA DOSA', 'kerala masala dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006147, 400081006, 'CHEESE LAYS DOSA', 'cheese lays dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006148, 400081006, 'DILKHUSH DOSA', 'dilkhush dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006149, 400081006, 'GARDEN DOSA', 'garden dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006150, 400081006, 'PIZZA DOSA', 'pizza dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006151, 400081006, 'MATKA DOSA', 'matka dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006152, 400081006, 'MANI''S SPECIAL DOSA', 'mani''s special dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006153, 400081006, 'UPVAS DOSA', 'upvas dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006154, 400081006, 'CHILLI DOSA', 'chilli dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006155, 400081006, 'SPECIAL PANNER MASALA DOSA', 'special panner masala dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006156, 400081006, 'AMERICAN CHOPSLUEY DOSA', 'american chopsluey dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006157, 400081006, 'PANEER TIKKA DOSA', 'paneer tikka dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006158, 400081006, 'GOLMAL DOSA', 'golmal dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006159, 400081006, 'BAHUBALI DOSA', 'bahubali dosa', 'MANI''S SPECIAL DOSA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006160, 400081006, 'FULL TEA', 'full tea', 'HOT BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006161, 400081006, 'BLACK TEA', 'black tea', 'HOT BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006162, 400081006, 'LEMON TEA', 'lemon tea', 'HOT BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006163, 400081006, 'GREEN TEA', 'green tea', 'HOT BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006164, 400081006, 'FILTER COFFEE', 'filter coffee', 'HOT BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006165, 400081006, 'BLACK COFFEE', 'black coffee', 'HOT BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006166, 400081006, 'MILK', 'milk', 'HOT BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006167, 400081006, 'KESAR UKALA', 'kesar ukala', 'HOT BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006168, 400081006, 'HOT CHOCOLATE', 'hot chocolate', 'HOT BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006169, 400081006, 'BUTTER MILK', 'butter milk', 'COLD BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006170, 400081006, 'LASSI', 'lassi', 'COLD BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006171, 400081006, 'KESAR LASSI', 'kesar lassi', 'COLD BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006172, 400081006, 'MANGO LASSI', 'mango lassi', 'COLD BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006173, 400081006, 'DAHI IDLI', 'dahi idli', 'COLD BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006174, 400081006, 'DAHI VADA', 'dahi vada', 'COLD BEVERAGE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006175, 400081006, 'EXTRA BUTTER', 'extra butter', 'EXTRA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006176, 400081006, 'EXTRA GHEE', 'extra ghee', 'EXTRA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006177, 400081006, 'EXTRA PODI', 'extra podi', 'EXTRA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006178, 400081006, 'EXTRA MAYO', 'extra mayo', 'EXTRA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006179, 400081006, 'EXTRA PANEER', 'extra paneer', 'EXTRA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006180, 400081006, 'EXTRA CHEESE', 'extra cheese', 'EXTRA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006181, 400081006, 'EXTRA CHATNI', 'extra chatni', 'EXTRA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006182, 400081006, 'EXTRA SCHEZWAN', 'extra schezwan', 'EXTRA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006183, 400081006, 'EXTRA SAMBHAR', 'extra sambhar', 'EXTRA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006184, 400081006, 'EXTRA ONION', 'extra onion', 'EXTRA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006185, 400081006, 'EXTRA RASAM', 'extra rasam', 'EXTRA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006186, 400081006, 'EXTRA KURMA', 'extra kurma', 'EXTRA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006187, 400081006, 'EXTRA PAPAD', 'extra papad', 'EXTRA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006188, 400081006, 'SWET BEEDA', 'swet beeda', 'EXTRA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006189, 400081006, 'FRESH LEMON JUICE', 'fresh lemon juice', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006190, 400081006, 'FRESH LEMON SODA', 'fresh lemon soda', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006191, 400081006, 'NANNARI SARBATH', 'nannari sarbath', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006192, 400081006, 'MINT COOLER', 'mint cooler', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006193, 400081006, 'TENDER COCONUT', 'tender coconut', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006194, 400081006, 'KOKUM SARBATH', 'kokum sarbath', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006195, 400081006, 'LEMON ICE TEA', 'lemon ice tea', 'FRESH JUICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006196, 400081006, 'ORANGE', 'orange', 'MOCKTAILS MOJITO BLUEBERRY', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400081006197, 400081006, 'LEMON PUDINA', 'lemon pudina', 'MOCKTAILS MOJITO BLUEBERRY', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400081006198, 400081006, 'BLUEBERRY', 'blueberry', 'MOCKTAILS MOJITO BLUEBERRY', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400081006199, 400081006, 'COLD COFFEE', 'cold coffee', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006200, 400081006, 'ROSE MILKSHAKE', 'rose milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006201, 400081006, 'VANILLA MILKSHAKE', 'vanilla milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006202, 400081006, 'BADAM MILKSHAKE', 'badam milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006203, 400081006, 'STRAWBERRY MILKSHAKE', 'strawberry milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006204, 400081006, 'CHOCOLATE MILKSHAKE', 'chocolate milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006205, 400081006, 'KITKAT MILKSHAKE', 'kitkat milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006206, 400081006, 'OREO MILKSHAKE', 'oreo milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006207, 400081006, 'MANGO MILKSHAKE', 'mango milkshake', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081006208, 400081006, 'KESAR THANDAI', 'kesar thandai', 'MILK SHAKES', 'veg'::text, NULL::text, NULL::text, 'unverified')
) AS x(menu_item_id, restaurant_id, name, normalized_name, raw_category_text, food_classification_code, protein_code, split_group_key, verification_status_code)
JOIN canonical_dish cd ON cd.normalized_name = x.normalized_name
LEFT JOIN protein_type pt ON pt.code = x.protein_code;

-- Menu item source: name/existence confidence, kept separate from price confidence.
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
VALUES
    (400081006001, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006002, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006003, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006004, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006005, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006006, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006007, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006008, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006009, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006010, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006011, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006012, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006013, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006014, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006015, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006016, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006017, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006018, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006019, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006020, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006021, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006022, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006023, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006024, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006025, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006026, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006027, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006028, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006029, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006030, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006031, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006032, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006033, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006034, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006035, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006036, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006037, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006038, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006039, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006040, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006041, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006042, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006043, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006044, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006045, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006046, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006047, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006048, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006049, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006050, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006051, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006052, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006053, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006054, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006055, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006056, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006057, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006058, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006059, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006060, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006061, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006062, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006063, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006064, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006065, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006066, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006067, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006068, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006069, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006070, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006071, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006072, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006073, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006074, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006075, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006076, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006077, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006078, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006079, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006080, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006081, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006082, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006083, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006084, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006085, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006086, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006087, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006088, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006089, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006090, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006091, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006092, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006093, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006094, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006095, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006096, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006097, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006098, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006099, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006100, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006101, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006102, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006103, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006104, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006105, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006106, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006107, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006108, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006109, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006110, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006111, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006112, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006113, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006114, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006115, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006116, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006117, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006118, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006119, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006120, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006121, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006122, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006123, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006124, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006125, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006126, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006127, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006128, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006129, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006130, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006131, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006132, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006133, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006134, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006135, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006136, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006137, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006138, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006139, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006140, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006141, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006142, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006143, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006144, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006145, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006146, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006147, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006148, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006149, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006150, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006151, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006152, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006153, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006154, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006155, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006156, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006157, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006158, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006159, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006160, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006161, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006162, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006163, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006164, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006165, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006166, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006167, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006168, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006169, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006170, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006171, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006172, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006173, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006174, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006175, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006176, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006177, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006178, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006179, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006180, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006181, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006182, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006183, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006184, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006185, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006186, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006187, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006188, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006189, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006190, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006191, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006192, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006193, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006194, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006195, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006196, 400081006, :extraction_batch_id, 0.9, 'needs_review'),
    (400081006197, 400081006, :extraction_batch_id, 0.9, 'needs_review'),
    (400081006198, 400081006, :extraction_batch_id, 0.9, 'needs_review'),
    (400081006199, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006200, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006201, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006202, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006203, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006204, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006205, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006206, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006207, 400081006, :extraction_batch_id, 0.9, 'unverified'),
    (400081006208, 400081006, :extraction_batch_id, 0.9, 'unverified');

-- Variants (portion/label variants -- one menu_item, multiple menu_item_variant rows;
-- a protein/veg split already became two separate menu_item rows above, so each carries
-- exactly one variant here).
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
VALUES
    (400081006001, 400081006001, 'Regular', 'fixed', TRUE),
    (400081006002, 400081006002, 'Regular', 'fixed', TRUE),
    (400081006003, 400081006003, 'Regular', 'fixed', TRUE),
    (400081006004, 400081006004, 'Regular', 'fixed', TRUE),
    (400081006005, 400081006005, 'Regular', 'fixed', TRUE),
    (400081006006, 400081006006, 'Regular', 'fixed', TRUE),
    (400081006007, 400081006007, 'Regular', 'fixed', TRUE),
    (400081006008, 400081006008, 'Regular', 'fixed', TRUE),
    (400081006009, 400081006009, 'Regular', 'fixed', TRUE),
    (400081006010, 400081006010, 'Regular', 'fixed', TRUE),
    (400081006011, 400081006011, 'Regular', 'fixed', TRUE),
    (400081006012, 400081006012, 'Regular', 'fixed', TRUE),
    (400081006013, 400081006013, 'Regular', 'fixed', TRUE),
    (400081006014, 400081006014, 'Regular', 'fixed', TRUE),
    (400081006015, 400081006015, 'Regular', 'fixed', TRUE),
    (400081006016, 400081006016, 'Regular', 'fixed', TRUE),
    (400081006017, 400081006017, 'Regular', 'fixed', TRUE),
    (400081006018, 400081006018, 'Regular', 'fixed', TRUE),
    (400081006019, 400081006019, 'Regular', 'fixed', TRUE),
    (400081006020, 400081006020, 'Regular', 'fixed', TRUE),
    (400081006021, 400081006021, 'Regular', 'fixed', TRUE),
    (400081006022, 400081006022, 'Regular', 'fixed', TRUE),
    (400081006023, 400081006023, 'Regular', 'fixed', TRUE),
    (400081006024, 400081006024, 'Regular', 'fixed', TRUE),
    (400081006025, 400081006025, 'Regular', 'fixed', TRUE),
    (400081006026, 400081006026, 'Regular', 'fixed', TRUE),
    (400081006027, 400081006027, 'Regular', 'fixed', TRUE),
    (400081006028, 400081006028, 'Regular', 'fixed', TRUE),
    (400081006029, 400081006029, 'Regular', 'fixed', TRUE),
    (400081006030, 400081006030, 'Regular', 'fixed', TRUE),
    (400081006031, 400081006031, 'Regular', 'fixed', TRUE),
    (400081006032, 400081006032, 'Regular', 'fixed', TRUE),
    (400081006033, 400081006033, 'Regular', 'fixed', TRUE),
    (400081006034, 400081006034, 'Regular', 'fixed', TRUE),
    (400081006035, 400081006035, 'Regular', 'fixed', TRUE),
    (400081006036, 400081006036, 'Regular', 'fixed', TRUE),
    (400081006037, 400081006037, 'Regular', 'fixed', TRUE),
    (400081006038, 400081006038, 'Regular', 'fixed', TRUE),
    (400081006039, 400081006039, 'Regular', 'fixed', TRUE),
    (400081006040, 400081006040, 'Regular', 'fixed', TRUE),
    (400081006041, 400081006041, 'Regular', 'fixed', TRUE),
    (400081006042, 400081006042, 'Regular', 'fixed', TRUE),
    (400081006043, 400081006043, 'Regular', 'fixed', TRUE),
    (400081006044, 400081006044, 'Regular', 'fixed', TRUE),
    (400081006045, 400081006045, 'Regular', 'fixed', TRUE),
    (400081006046, 400081006046, 'Regular', 'fixed', TRUE),
    (400081006047, 400081006047, 'Regular', 'fixed', TRUE),
    (400081006048, 400081006048, 'Regular', 'fixed', TRUE),
    (400081006049, 400081006049, 'Regular', 'fixed', TRUE),
    (400081006050, 400081006050, 'Regular', 'fixed', TRUE),
    (400081006051, 400081006051, 'Regular', 'fixed', TRUE),
    (400081006052, 400081006052, 'Regular', 'fixed', TRUE),
    (400081006053, 400081006053, 'Regular', 'fixed', TRUE),
    (400081006054, 400081006054, 'Regular', 'fixed', TRUE),
    (400081006055, 400081006055, 'Regular', 'fixed', TRUE),
    (400081006056, 400081006056, 'Regular', 'fixed', TRUE),
    (400081006057, 400081006057, 'Regular', 'fixed', TRUE),
    (400081006058, 400081006058, 'Regular', 'fixed', TRUE),
    (400081006059, 400081006059, 'Regular', 'fixed', TRUE),
    (400081006060, 400081006060, 'Regular', 'fixed', TRUE),
    (400081006061, 400081006061, 'Regular', 'fixed', TRUE),
    (400081006062, 400081006062, 'Regular', 'fixed', TRUE),
    (400081006063, 400081006063, 'Regular', 'fixed', TRUE),
    (400081006064, 400081006064, 'Regular', 'fixed', TRUE),
    (400081006065, 400081006065, 'Regular', 'fixed', TRUE),
    (400081006066, 400081006066, 'Regular', 'fixed', TRUE),
    (400081006067, 400081006067, 'Regular', 'fixed', TRUE),
    (400081006068, 400081006068, 'Regular', 'fixed', TRUE),
    (400081006069, 400081006069, 'Regular', 'fixed', TRUE),
    (400081006070, 400081006070, 'Regular', 'fixed', TRUE),
    (400081006071, 400081006071, 'Regular', 'fixed', TRUE),
    (400081006072, 400081006072, 'Regular', 'fixed', TRUE),
    (400081006073, 400081006073, 'Regular', 'fixed', TRUE),
    (400081006074, 400081006074, 'Regular', 'fixed', TRUE),
    (400081006075, 400081006075, 'Regular', 'fixed', TRUE),
    (400081006076, 400081006076, 'Regular', 'fixed', TRUE),
    (400081006077, 400081006077, 'Regular', 'fixed', TRUE),
    (400081006078, 400081006078, 'Regular', 'fixed', TRUE),
    (400081006079, 400081006079, 'Regular', 'fixed', TRUE),
    (400081006080, 400081006080, 'Regular', 'fixed', TRUE),
    (400081006081, 400081006081, 'Regular', 'fixed', TRUE),
    (400081006082, 400081006082, 'Regular', 'fixed', TRUE),
    (400081006083, 400081006083, 'Regular', 'fixed', TRUE),
    (400081006084, 400081006084, 'Regular', 'fixed', TRUE),
    (400081006085, 400081006085, 'Regular', 'fixed', TRUE),
    (400081006086, 400081006086, 'Regular', 'fixed', TRUE),
    (400081006087, 400081006087, 'Regular', 'fixed', TRUE),
    (400081006088, 400081006088, 'Regular', 'fixed', TRUE),
    (400081006089, 400081006089, 'Regular', 'fixed', TRUE),
    (400081006090, 400081006090, 'Regular', 'fixed', TRUE),
    (400081006091, 400081006091, 'Regular', 'fixed', TRUE),
    (400081006092, 400081006092, 'Regular', 'fixed', TRUE),
    (400081006093, 400081006093, 'Regular', 'fixed', TRUE),
    (400081006094, 400081006094, 'Regular', 'fixed', TRUE),
    (400081006095, 400081006095, 'Regular', 'fixed', TRUE),
    (400081006096, 400081006096, 'Regular', 'fixed', TRUE),
    (400081006097, 400081006097, 'Regular', 'fixed', TRUE),
    (400081006098, 400081006098, 'Regular', 'fixed', TRUE),
    (400081006099, 400081006099, 'Regular', 'fixed', TRUE),
    (400081006100, 400081006100, 'Regular', 'fixed', TRUE),
    (400081006101, 400081006101, 'Regular', 'fixed', TRUE),
    (400081006102, 400081006102, 'Regular', 'fixed', TRUE),
    (400081006103, 400081006103, 'Regular', 'fixed', TRUE),
    (400081006104, 400081006104, 'Regular', 'fixed', TRUE),
    (400081006105, 400081006105, 'Regular', 'fixed', TRUE),
    (400081006106, 400081006106, 'Regular', 'fixed', TRUE),
    (400081006107, 400081006107, 'Regular', 'fixed', TRUE),
    (400081006108, 400081006108, 'Regular', 'fixed', TRUE),
    (400081006109, 400081006109, 'Regular', 'fixed', TRUE),
    (400081006110, 400081006110, 'Regular', 'fixed', TRUE),
    (400081006111, 400081006111, 'Regular', 'fixed', TRUE),
    (400081006112, 400081006112, 'Regular', 'fixed', TRUE),
    (400081006113, 400081006113, 'Regular', 'fixed', TRUE),
    (400081006114, 400081006114, 'Regular', 'fixed', TRUE),
    (400081006115, 400081006115, 'Regular', 'fixed', TRUE),
    (400081006116, 400081006116, 'Regular', 'fixed', TRUE),
    (400081006117, 400081006117, 'Regular', 'fixed', TRUE),
    (400081006118, 400081006118, 'Regular', 'fixed', TRUE),
    (400081006119, 400081006119, 'Regular', 'fixed', TRUE),
    (400081006120, 400081006120, 'Regular', 'fixed', TRUE),
    (400081006121, 400081006121, 'Regular', 'fixed', TRUE),
    (400081006122, 400081006122, 'Regular', 'fixed', TRUE),
    (400081006123, 400081006123, 'Regular', 'fixed', TRUE),
    (400081006124, 400081006124, 'Regular', 'fixed', TRUE),
    (400081006125, 400081006125, 'Regular', 'fixed', TRUE),
    (400081006126, 400081006126, 'Regular', 'fixed', TRUE),
    (400081006127, 400081006127, 'Regular', 'fixed', TRUE),
    (400081006128, 400081006128, 'Regular', 'fixed', TRUE),
    (400081006129, 400081006129, 'Regular', 'fixed', TRUE),
    (400081006130, 400081006130, 'Regular', 'fixed', TRUE),
    (400081006131, 400081006131, 'Regular', 'fixed', TRUE),
    (400081006132, 400081006132, 'Regular', 'fixed', TRUE),
    (400081006133, 400081006133, 'Regular', 'fixed', TRUE),
    (400081006134, 400081006134, 'Regular', 'fixed', TRUE),
    (400081006135, 400081006135, 'Regular', 'fixed', TRUE),
    (400081006136, 400081006136, 'Regular', 'fixed', TRUE),
    (400081006137, 400081006137, 'Regular', 'fixed', TRUE),
    (400081006138, 400081006138, 'Regular', 'fixed', TRUE),
    (400081006139, 400081006139, 'Regular', 'fixed', TRUE),
    (400081006140, 400081006140, 'Regular', 'fixed', TRUE),
    (400081006141, 400081006141, 'Regular', 'fixed', TRUE),
    (400081006142, 400081006142, 'Regular', 'fixed', TRUE),
    (400081006143, 400081006143, 'Regular', 'fixed', TRUE),
    (400081006144, 400081006144, 'Regular', 'fixed', TRUE),
    (400081006145, 400081006145, 'Regular', 'fixed', TRUE),
    (400081006146, 400081006146, 'Regular', 'fixed', TRUE),
    (400081006147, 400081006147, 'Regular', 'fixed', TRUE),
    (400081006148, 400081006148, 'Regular', 'fixed', TRUE),
    (400081006149, 400081006149, 'Regular', 'fixed', TRUE),
    (400081006150, 400081006150, 'Regular', 'fixed', TRUE),
    (400081006151, 400081006151, 'Regular', 'fixed', TRUE),
    (400081006152, 400081006152, 'Regular', 'fixed', TRUE),
    (400081006153, 400081006153, 'Regular', 'fixed', TRUE),
    (400081006154, 400081006154, 'Regular', 'fixed', TRUE),
    (400081006155, 400081006155, 'Regular', 'fixed', TRUE),
    (400081006156, 400081006156, 'Regular', 'fixed', TRUE),
    (400081006157, 400081006157, 'Regular', 'fixed', TRUE),
    (400081006158, 400081006158, 'Regular', 'fixed', TRUE),
    (400081006159, 400081006159, 'Regular', 'fixed', TRUE),
    (400081006160, 400081006160, 'Regular', 'fixed', TRUE),
    (400081006161, 400081006161, 'Regular', 'fixed', TRUE),
    (400081006162, 400081006162, 'Regular', 'fixed', TRUE),
    (400081006163, 400081006163, 'Regular', 'fixed', TRUE),
    (400081006164, 400081006164, 'Regular', 'fixed', TRUE),
    (400081006165, 400081006165, 'Regular', 'fixed', TRUE),
    (400081006166, 400081006166, 'Regular', 'fixed', TRUE),
    (400081006167, 400081006167, 'Regular', 'fixed', TRUE),
    (400081006168, 400081006168, 'Regular', 'fixed', TRUE),
    (400081006169, 400081006169, 'Regular', 'fixed', TRUE),
    (400081006170, 400081006170, 'Regular', 'fixed', TRUE),
    (400081006171, 400081006171, 'Regular', 'fixed', TRUE),
    (400081006172, 400081006172, 'Regular', 'fixed', TRUE),
    (400081006173, 400081006173, 'Regular', 'fixed', TRUE),
    (400081006174, 400081006174, 'Regular', 'fixed', TRUE),
    (400081006175, 400081006175, 'Regular', 'fixed', TRUE),
    (400081006176, 400081006176, 'Regular', 'fixed', TRUE),
    (400081006177, 400081006177, 'Regular', 'fixed', TRUE),
    (400081006178, 400081006178, 'Regular', 'fixed', TRUE),
    (400081006179, 400081006179, 'Regular', 'fixed', TRUE),
    (400081006180, 400081006180, 'Regular', 'fixed', TRUE),
    (400081006181, 400081006181, 'Regular', 'fixed', TRUE),
    (400081006182, 400081006182, 'Regular', 'fixed', TRUE),
    (400081006183, 400081006183, 'Regular', 'fixed', TRUE),
    (400081006184, 400081006184, 'Regular', 'fixed', TRUE),
    (400081006185, 400081006185, 'Regular', 'fixed', TRUE),
    (400081006186, 400081006186, 'Regular', 'fixed', TRUE),
    (400081006187, 400081006187, 'Regular', 'fixed', TRUE),
    (400081006188, 400081006188, 'Regular', 'fixed', TRUE),
    (400081006189, 400081006189, 'Regular', 'fixed', TRUE),
    (400081006190, 400081006190, 'Regular', 'fixed', TRUE),
    (400081006191, 400081006191, 'Regular', 'fixed', TRUE),
    (400081006192, 400081006192, 'Regular', 'fixed', TRUE),
    (400081006193, 400081006193, 'Regular', 'fixed', TRUE),
    (400081006194, 400081006194, 'Regular', 'fixed', TRUE),
    (400081006195, 400081006195, 'Regular', 'fixed', TRUE),
    (400081006196, 400081006196, 'Mocktails', 'fixed', TRUE),
    (400081006197, 400081006196, 'Mojito', 'fixed', FALSE),
    (400081006198, 400081006196, 'Blueberry', 'fixed', FALSE),
    (400081006199, 400081006197, 'Mocktails', 'fixed', TRUE),
    (400081006200, 400081006197, 'Mojito', 'fixed', FALSE),
    (400081006201, 400081006197, 'Blueberry', 'fixed', FALSE),
    (400081006202, 400081006198, 'Mocktails', 'fixed', TRUE),
    (400081006203, 400081006198, 'Mojito', 'fixed', FALSE),
    (400081006204, 400081006198, 'Blueberry', 'fixed', FALSE),
    (400081006205, 400081006199, 'Regular', 'fixed', TRUE),
    (400081006206, 400081006200, 'Regular', 'fixed', TRUE),
    (400081006207, 400081006201, 'Regular', 'fixed', TRUE),
    (400081006208, 400081006202, 'Regular', 'fixed', TRUE),
    (400081006209, 400081006203, 'Regular', 'fixed', TRUE),
    (400081006210, 400081006204, 'Regular', 'fixed', TRUE),
    (400081006211, 400081006205, 'Regular', 'fixed', TRUE),
    (400081006212, 400081006206, 'Regular', 'fixed', TRUE),
    (400081006213, 400081006207, 'Regular', 'fixed', TRUE),
    (400081006214, 400081006208, 'Regular', 'fixed', TRUE);

-- Prices (only for variants where a numeric price was actually captured)
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
VALUES
    (400081006001, 400081006001, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006002, 400081006002, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006003, 400081006003, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006004, 400081006004, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006005, 400081006005, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006006, 400081006006, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006007, 400081006007, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006008, 400081006008, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006009, 400081006009, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006010, 400081006010, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006011, 400081006011, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006012, 400081006012, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006013, 400081006013, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006014, 400081006014, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006015, 400081006015, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006016, 400081006016, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006017, 400081006017, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006018, 400081006018, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006019, 400081006019, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006020, 400081006020, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006021, 400081006021, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006022, 400081006022, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006023, 400081006023, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006024, 400081006024, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006025, 400081006025, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006026, 400081006026, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006027, 400081006027, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006028, 400081006028, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006029, 400081006029, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006030, 400081006030, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006031, 400081006031, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006032, 400081006032, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006033, 400081006033, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006034, 400081006034, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006035, 400081006035, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006036, 400081006036, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006037, 400081006037, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006038, 400081006038, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006039, 400081006039, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006040, 400081006040, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006041, 400081006041, 259.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006042, 400081006042, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006043, 400081006043, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006044, 400081006044, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006045, 400081006045, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006046, 400081006046, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006047, 400081006047, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006048, 400081006048, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006049, 400081006049, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006050, 400081006050, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006051, 400081006051, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006052, 400081006052, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006053, 400081006053, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006054, 400081006054, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006055, 400081006055, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006056, 400081006056, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006057, 400081006057, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006058, 400081006058, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006059, 400081006059, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006060, 400081006060, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006061, 400081006061, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006062, 400081006062, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006063, 400081006063, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006064, 400081006064, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006065, 400081006065, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006066, 400081006066, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006067, 400081006067, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006068, 400081006068, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006069, 400081006069, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006070, 400081006070, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006071, 400081006071, 105.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006072, 400081006072, 105.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006073, 400081006073, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006074, 400081006074, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006075, 400081006075, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006076, 400081006076, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006077, 400081006077, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006078, 400081006078, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006079, 400081006079, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006080, 400081006080, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006081, 400081006081, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006082, 400081006082, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006083, 400081006083, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006084, 400081006084, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006085, 400081006085, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006086, 400081006086, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006087, 400081006087, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006088, 400081006088, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006089, 400081006089, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006090, 400081006090, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006091, 400081006091, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006092, 400081006092, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006093, 400081006093, 105.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006094, 400081006094, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006095, 400081006095, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006096, 400081006096, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006097, 400081006097, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006098, 400081006098, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006099, 400081006099, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006100, 400081006100, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006101, 400081006101, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006102, 400081006102, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006103, 400081006103, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006104, 400081006104, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006105, 400081006105, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006106, 400081006106, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006107, 400081006107, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006108, 400081006108, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006109, 400081006109, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006110, 400081006110, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006111, 400081006111, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006112, 400081006112, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006113, 400081006113, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006114, 400081006114, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006115, 400081006115, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006116, 400081006116, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006117, 400081006117, 105.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006118, 400081006118, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006119, 400081006119, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006120, 400081006120, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006121, 400081006121, 125.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006122, 400081006122, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006123, 400081006123, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006124, 400081006124, 105.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006125, 400081006125, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006126, 400081006126, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006127, 400081006127, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006128, 400081006128, 125.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006129, 400081006129, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006130, 400081006130, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006131, 400081006131, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006132, 400081006132, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006133, 400081006133, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006134, 400081006134, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006135, 400081006135, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006136, 400081006136, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006137, 400081006137, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006138, 400081006138, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006139, 400081006139, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006140, 400081006140, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006141, 400081006141, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006142, 400081006142, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006143, 400081006143, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006144, 400081006144, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006145, 400081006145, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006146, 400081006146, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006147, 400081006147, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006148, 400081006148, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006149, 400081006149, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006150, 400081006150, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006151, 400081006151, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006152, 400081006152, 309.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006153, 400081006153, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006154, 400081006154, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006155, 400081006155, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006156, 400081006156, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006157, 400081006157, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006158, 400081006158, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006159, 400081006159, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006160, 400081006160, 26.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006161, 400081006161, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006162, 400081006162, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006163, 400081006163, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006164, 400081006164, 37.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006165, 400081006165, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006166, 400081006166, 37.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006167, 400081006167, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006168, 400081006168, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006169, 400081006169, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006170, 400081006170, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006171, 400081006171, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006172, 400081006172, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006173, 400081006173, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006174, 400081006174, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006175, 400081006175, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006176, 400081006176, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006177, 400081006177, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006178, 400081006178, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006179, 400081006179, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006180, 400081006180, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006181, 400081006181, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006182, 400081006182, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006183, 400081006183, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006184, 400081006184, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006185, 400081006185, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006186, 400081006186, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006187, 400081006187, 10.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006188, 400081006188, 10.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006189, 400081006189, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006190, 400081006190, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006191, 400081006191, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006192, 400081006192, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006193, 400081006193, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006194, 400081006194, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006195, 400081006195, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006196, 400081006196, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'needs_review'),
    (400081006197, 400081006197, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'needs_review'),
    (400081006198, 400081006198, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'needs_review'),
    (400081006199, 400081006199, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'needs_review'),
    (400081006200, 400081006200, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'needs_review'),
    (400081006201, 400081006201, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'needs_review'),
    (400081006202, 400081006202, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'needs_review'),
    (400081006203, 400081006203, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'needs_review'),
    (400081006204, 400081006204, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'needs_review'),
    (400081006205, 400081006205, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006206, 400081006206, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006207, 400081006207, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006208, 400081006208, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006209, 400081006209, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006210, 400081006210, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006211, 400081006211, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006212, 400081006212, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006213, 400081006213, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified'),
    (400081006214, 400081006214, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081006, 'unverified');

-- Price source (price-specific confidence, tracked separately from item confidence)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
VALUES
    (400081006001, 400081006, :extraction_batch_id, 0.95),
    (400081006002, 400081006, :extraction_batch_id, 0.95),
    (400081006003, 400081006, :extraction_batch_id, 0.95),
    (400081006004, 400081006, :extraction_batch_id, 0.95),
    (400081006005, 400081006, :extraction_batch_id, 0.95),
    (400081006006, 400081006, :extraction_batch_id, 0.95),
    (400081006007, 400081006, :extraction_batch_id, 0.95),
    (400081006008, 400081006, :extraction_batch_id, 0.95),
    (400081006009, 400081006, :extraction_batch_id, 0.95),
    (400081006010, 400081006, :extraction_batch_id, 0.95),
    (400081006011, 400081006, :extraction_batch_id, 0.95),
    (400081006012, 400081006, :extraction_batch_id, 0.95),
    (400081006013, 400081006, :extraction_batch_id, 0.95),
    (400081006014, 400081006, :extraction_batch_id, 0.95),
    (400081006015, 400081006, :extraction_batch_id, 0.95),
    (400081006016, 400081006, :extraction_batch_id, 0.95),
    (400081006017, 400081006, :extraction_batch_id, 0.95),
    (400081006018, 400081006, :extraction_batch_id, 0.95),
    (400081006019, 400081006, :extraction_batch_id, 0.95),
    (400081006020, 400081006, :extraction_batch_id, 0.95),
    (400081006021, 400081006, :extraction_batch_id, 0.95),
    (400081006022, 400081006, :extraction_batch_id, 0.95),
    (400081006023, 400081006, :extraction_batch_id, 0.95),
    (400081006024, 400081006, :extraction_batch_id, 0.95),
    (400081006025, 400081006, :extraction_batch_id, 0.95),
    (400081006026, 400081006, :extraction_batch_id, 0.95),
    (400081006027, 400081006, :extraction_batch_id, 0.95),
    (400081006028, 400081006, :extraction_batch_id, 0.95),
    (400081006029, 400081006, :extraction_batch_id, 0.95),
    (400081006030, 400081006, :extraction_batch_id, 0.95),
    (400081006031, 400081006, :extraction_batch_id, 0.95),
    (400081006032, 400081006, :extraction_batch_id, 0.95),
    (400081006033, 400081006, :extraction_batch_id, 0.95),
    (400081006034, 400081006, :extraction_batch_id, 0.95),
    (400081006035, 400081006, :extraction_batch_id, 0.95),
    (400081006036, 400081006, :extraction_batch_id, 0.95),
    (400081006037, 400081006, :extraction_batch_id, 0.95),
    (400081006038, 400081006, :extraction_batch_id, 0.95),
    (400081006039, 400081006, :extraction_batch_id, 0.95),
    (400081006040, 400081006, :extraction_batch_id, 0.95),
    (400081006041, 400081006, :extraction_batch_id, 0.95),
    (400081006042, 400081006, :extraction_batch_id, 0.95),
    (400081006043, 400081006, :extraction_batch_id, 0.95),
    (400081006044, 400081006, :extraction_batch_id, 0.95),
    (400081006045, 400081006, :extraction_batch_id, 0.95),
    (400081006046, 400081006, :extraction_batch_id, 0.95),
    (400081006047, 400081006, :extraction_batch_id, 0.95),
    (400081006048, 400081006, :extraction_batch_id, 0.95),
    (400081006049, 400081006, :extraction_batch_id, 0.95),
    (400081006050, 400081006, :extraction_batch_id, 0.95),
    (400081006051, 400081006, :extraction_batch_id, 0.95),
    (400081006052, 400081006, :extraction_batch_id, 0.95),
    (400081006053, 400081006, :extraction_batch_id, 0.95),
    (400081006054, 400081006, :extraction_batch_id, 0.95),
    (400081006055, 400081006, :extraction_batch_id, 0.95),
    (400081006056, 400081006, :extraction_batch_id, 0.95),
    (400081006057, 400081006, :extraction_batch_id, 0.95),
    (400081006058, 400081006, :extraction_batch_id, 0.95),
    (400081006059, 400081006, :extraction_batch_id, 0.95),
    (400081006060, 400081006, :extraction_batch_id, 0.95),
    (400081006061, 400081006, :extraction_batch_id, 0.95),
    (400081006062, 400081006, :extraction_batch_id, 0.95),
    (400081006063, 400081006, :extraction_batch_id, 0.95),
    (400081006064, 400081006, :extraction_batch_id, 0.95),
    (400081006065, 400081006, :extraction_batch_id, 0.95),
    (400081006066, 400081006, :extraction_batch_id, 0.95),
    (400081006067, 400081006, :extraction_batch_id, 0.95),
    (400081006068, 400081006, :extraction_batch_id, 0.95),
    (400081006069, 400081006, :extraction_batch_id, 0.95),
    (400081006070, 400081006, :extraction_batch_id, 0.95),
    (400081006071, 400081006, :extraction_batch_id, 0.95),
    (400081006072, 400081006, :extraction_batch_id, 0.95),
    (400081006073, 400081006, :extraction_batch_id, 0.95),
    (400081006074, 400081006, :extraction_batch_id, 0.95),
    (400081006075, 400081006, :extraction_batch_id, 0.95),
    (400081006076, 400081006, :extraction_batch_id, 0.95),
    (400081006077, 400081006, :extraction_batch_id, 0.95),
    (400081006078, 400081006, :extraction_batch_id, 0.95),
    (400081006079, 400081006, :extraction_batch_id, 0.95),
    (400081006080, 400081006, :extraction_batch_id, 0.95),
    (400081006081, 400081006, :extraction_batch_id, 0.95),
    (400081006082, 400081006, :extraction_batch_id, 0.95),
    (400081006083, 400081006, :extraction_batch_id, 0.95),
    (400081006084, 400081006, :extraction_batch_id, 0.95),
    (400081006085, 400081006, :extraction_batch_id, 0.95),
    (400081006086, 400081006, :extraction_batch_id, 0.95),
    (400081006087, 400081006, :extraction_batch_id, 0.95),
    (400081006088, 400081006, :extraction_batch_id, 0.95),
    (400081006089, 400081006, :extraction_batch_id, 0.95),
    (400081006090, 400081006, :extraction_batch_id, 0.95),
    (400081006091, 400081006, :extraction_batch_id, 0.95),
    (400081006092, 400081006, :extraction_batch_id, 0.95),
    (400081006093, 400081006, :extraction_batch_id, 0.95),
    (400081006094, 400081006, :extraction_batch_id, 0.95),
    (400081006095, 400081006, :extraction_batch_id, 0.95),
    (400081006096, 400081006, :extraction_batch_id, 0.95),
    (400081006097, 400081006, :extraction_batch_id, 0.95),
    (400081006098, 400081006, :extraction_batch_id, 0.95),
    (400081006099, 400081006, :extraction_batch_id, 0.95),
    (400081006100, 400081006, :extraction_batch_id, 0.95),
    (400081006101, 400081006, :extraction_batch_id, 0.95),
    (400081006102, 400081006, :extraction_batch_id, 0.95),
    (400081006103, 400081006, :extraction_batch_id, 0.95),
    (400081006104, 400081006, :extraction_batch_id, 0.95),
    (400081006105, 400081006, :extraction_batch_id, 0.95),
    (400081006106, 400081006, :extraction_batch_id, 0.95),
    (400081006107, 400081006, :extraction_batch_id, 0.95),
    (400081006108, 400081006, :extraction_batch_id, 0.95),
    (400081006109, 400081006, :extraction_batch_id, 0.95),
    (400081006110, 400081006, :extraction_batch_id, 0.95),
    (400081006111, 400081006, :extraction_batch_id, 0.95),
    (400081006112, 400081006, :extraction_batch_id, 0.95),
    (400081006113, 400081006, :extraction_batch_id, 0.95),
    (400081006114, 400081006, :extraction_batch_id, 0.95),
    (400081006115, 400081006, :extraction_batch_id, 0.95),
    (400081006116, 400081006, :extraction_batch_id, 0.95),
    (400081006117, 400081006, :extraction_batch_id, 0.95),
    (400081006118, 400081006, :extraction_batch_id, 0.95),
    (400081006119, 400081006, :extraction_batch_id, 0.95),
    (400081006120, 400081006, :extraction_batch_id, 0.95),
    (400081006121, 400081006, :extraction_batch_id, 0.95),
    (400081006122, 400081006, :extraction_batch_id, 0.95),
    (400081006123, 400081006, :extraction_batch_id, 0.95),
    (400081006124, 400081006, :extraction_batch_id, 0.95),
    (400081006125, 400081006, :extraction_batch_id, 0.95),
    (400081006126, 400081006, :extraction_batch_id, 0.95),
    (400081006127, 400081006, :extraction_batch_id, 0.95),
    (400081006128, 400081006, :extraction_batch_id, 0.95),
    (400081006129, 400081006, :extraction_batch_id, 0.95),
    (400081006130, 400081006, :extraction_batch_id, 0.95),
    (400081006131, 400081006, :extraction_batch_id, 0.95),
    (400081006132, 400081006, :extraction_batch_id, 0.95),
    (400081006133, 400081006, :extraction_batch_id, 0.95),
    (400081006134, 400081006, :extraction_batch_id, 0.95),
    (400081006135, 400081006, :extraction_batch_id, 0.95),
    (400081006136, 400081006, :extraction_batch_id, 0.95),
    (400081006137, 400081006, :extraction_batch_id, 0.95),
    (400081006138, 400081006, :extraction_batch_id, 0.95),
    (400081006139, 400081006, :extraction_batch_id, 0.95),
    (400081006140, 400081006, :extraction_batch_id, 0.95),
    (400081006141, 400081006, :extraction_batch_id, 0.95),
    (400081006142, 400081006, :extraction_batch_id, 0.95),
    (400081006143, 400081006, :extraction_batch_id, 0.95),
    (400081006144, 400081006, :extraction_batch_id, 0.95),
    (400081006145, 400081006, :extraction_batch_id, 0.95),
    (400081006146, 400081006, :extraction_batch_id, 0.95),
    (400081006147, 400081006, :extraction_batch_id, 0.95),
    (400081006148, 400081006, :extraction_batch_id, 0.95),
    (400081006149, 400081006, :extraction_batch_id, 0.95),
    (400081006150, 400081006, :extraction_batch_id, 0.95),
    (400081006151, 400081006, :extraction_batch_id, 0.95),
    (400081006152, 400081006, :extraction_batch_id, 0.95),
    (400081006153, 400081006, :extraction_batch_id, 0.95),
    (400081006154, 400081006, :extraction_batch_id, 0.95),
    (400081006155, 400081006, :extraction_batch_id, 0.95),
    (400081006156, 400081006, :extraction_batch_id, 0.95),
    (400081006157, 400081006, :extraction_batch_id, 0.95),
    (400081006158, 400081006, :extraction_batch_id, 0.95),
    (400081006159, 400081006, :extraction_batch_id, 0.95),
    (400081006160, 400081006, :extraction_batch_id, 0.95),
    (400081006161, 400081006, :extraction_batch_id, 0.95),
    (400081006162, 400081006, :extraction_batch_id, 0.95),
    (400081006163, 400081006, :extraction_batch_id, 0.95),
    (400081006164, 400081006, :extraction_batch_id, 0.95),
    (400081006165, 400081006, :extraction_batch_id, 0.95),
    (400081006166, 400081006, :extraction_batch_id, 0.95),
    (400081006167, 400081006, :extraction_batch_id, 0.95),
    (400081006168, 400081006, :extraction_batch_id, 0.95),
    (400081006169, 400081006, :extraction_batch_id, 0.95),
    (400081006170, 400081006, :extraction_batch_id, 0.95),
    (400081006171, 400081006, :extraction_batch_id, 0.95),
    (400081006172, 400081006, :extraction_batch_id, 0.95),
    (400081006173, 400081006, :extraction_batch_id, 0.95),
    (400081006174, 400081006, :extraction_batch_id, 0.95),
    (400081006175, 400081006, :extraction_batch_id, 0.95),
    (400081006176, 400081006, :extraction_batch_id, 0.95),
    (400081006177, 400081006, :extraction_batch_id, 0.95),
    (400081006178, 400081006, :extraction_batch_id, 0.95),
    (400081006179, 400081006, :extraction_batch_id, 0.95),
    (400081006180, 400081006, :extraction_batch_id, 0.95),
    (400081006181, 400081006, :extraction_batch_id, 0.95),
    (400081006182, 400081006, :extraction_batch_id, 0.95),
    (400081006183, 400081006, :extraction_batch_id, 0.95),
    (400081006184, 400081006, :extraction_batch_id, 0.95),
    (400081006185, 400081006, :extraction_batch_id, 0.95),
    (400081006186, 400081006, :extraction_batch_id, 0.95),
    (400081006187, 400081006, :extraction_batch_id, 0.95),
    (400081006188, 400081006, :extraction_batch_id, 0.95),
    (400081006189, 400081006, :extraction_batch_id, 0.95),
    (400081006190, 400081006, :extraction_batch_id, 0.95),
    (400081006191, 400081006, :extraction_batch_id, 0.95),
    (400081006192, 400081006, :extraction_batch_id, 0.95),
    (400081006193, 400081006, :extraction_batch_id, 0.95),
    (400081006194, 400081006, :extraction_batch_id, 0.95),
    (400081006195, 400081006, :extraction_batch_id, 0.95),
    (400081006196, 400081006, :extraction_batch_id, 0.6),
    (400081006197, 400081006, :extraction_batch_id, 0.6),
    (400081006198, 400081006, :extraction_batch_id, 0.6),
    (400081006199, 400081006, :extraction_batch_id, 0.6),
    (400081006200, 400081006, :extraction_batch_id, 0.6),
    (400081006201, 400081006, :extraction_batch_id, 0.6),
    (400081006202, 400081006, :extraction_batch_id, 0.6),
    (400081006203, 400081006, :extraction_batch_id, 0.6),
    (400081006204, 400081006, :extraction_batch_id, 0.6),
    (400081006205, 400081006, :extraction_batch_id, 0.95),
    (400081006206, 400081006, :extraction_batch_id, 0.95),
    (400081006207, 400081006, :extraction_batch_id, 0.95),
    (400081006208, 400081006, :extraction_batch_id, 0.95),
    (400081006209, 400081006, :extraction_batch_id, 0.95),
    (400081006210, 400081006, :extraction_batch_id, 0.95),
    (400081006211, 400081006, :extraction_batch_id, 0.95),
    (400081006212, 400081006, :extraction_batch_id, 0.95),
    (400081006213, 400081006, :extraction_batch_id, 0.95),
    (400081006214, 400081006, :extraction_batch_id, 0.95);

-- Board <-> item mapping
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
VALUES
    (400081006001, 400081006, 400081006001, 400081006001, 400081006001, 1),
    (400081006002, 400081006, 400081006001, 400081006002, 400081006001, 2),
    (400081006003, 400081006, 400081006001, 400081006003, 400081006001, 3),
    (400081006004, 400081006, 400081006001, 400081006004, 400081006001, 4),
    (400081006005, 400081006, 400081006001, 400081006005, 400081006001, 5),
    (400081006006, 400081006, 400081006001, 400081006006, 400081006001, 6),
    (400081006007, 400081006, 400081006001, 400081006007, 400081006001, 7),
    (400081006008, 400081006, 400081006001, 400081006008, 400081006001, 8),
    (400081006009, 400081006, 400081006001, 400081006009, 400081006001, 9),
    (400081006010, 400081006, 400081006001, 400081006010, 400081006001, 10),
    (400081006011, 400081006, 400081006001, 400081006011, 400081006001, 11),
    (400081006012, 400081006, 400081006001, 400081006012, 400081006001, 12),
    (400081006013, 400081006, 400081006001, 400081006013, 400081006001, 13),
    (400081006014, 400081006, 400081006001, 400081006014, 400081006001, 14),
    (400081006015, 400081006, 400081006001, 400081006015, 400081006001, 15),
    (400081006016, 400081006, 400081006001, 400081006016, 400081006001, 16),
    (400081006017, 400081006, 400081006001, 400081006017, 400081006001, 17),
    (400081006018, 400081006, 400081006001, 400081006018, 400081006001, 18),
    (400081006019, 400081006, 400081006001, 400081006019, 400081006001, 19),
    (400081006020, 400081006, 400081006001, 400081006020, 400081006001, 20),
    (400081006021, 400081006, 400081006001, 400081006021, 400081006001, 21),
    (400081006022, 400081006, 400081006001, 400081006022, 400081006001, 22),
    (400081006023, 400081006, 400081006001, 400081006023, 400081006001, 23),
    (400081006024, 400081006, 400081006001, 400081006024, 400081006001, 24),
    (400081006025, 400081006, 400081006001, 400081006025, 400081006002, 1),
    (400081006026, 400081006, 400081006001, 400081006026, 400081006002, 2),
    (400081006027, 400081006, 400081006001, 400081006027, 400081006002, 3),
    (400081006028, 400081006, 400081006001, 400081006028, 400081006002, 4),
    (400081006029, 400081006, 400081006001, 400081006029, 400081006002, 5),
    (400081006030, 400081006, 400081006001, 400081006030, 400081006002, 6),
    (400081006031, 400081006, 400081006001, 400081006031, 400081006002, 7),
    (400081006032, 400081006, 400081006001, 400081006032, 400081006002, 8),
    (400081006033, 400081006, 400081006001, 400081006033, 400081006002, 9),
    (400081006034, 400081006, 400081006001, 400081006034, 400081006002, 10),
    (400081006035, 400081006, 400081006001, 400081006035, 400081006002, 11),
    (400081006036, 400081006, 400081006001, 400081006036, 400081006002, 12),
    (400081006037, 400081006, 400081006001, 400081006037, 400081006002, 13),
    (400081006038, 400081006, 400081006001, 400081006038, 400081006002, 14),
    (400081006039, 400081006, 400081006001, 400081006039, 400081006002, 15),
    (400081006040, 400081006, 400081006001, 400081006040, 400081006002, 16),
    (400081006041, 400081006, 400081006001, 400081006041, 400081006002, 17),
    (400081006042, 400081006, 400081006001, 400081006042, 400081006002, 18),
    (400081006043, 400081006, 400081006001, 400081006043, 400081006002, 19),
    (400081006044, 400081006, 400081006001, 400081006044, 400081006002, 20),
    (400081006045, 400081006, 400081006001, 400081006045, 400081006002, 21),
    (400081006046, 400081006, 400081006001, 400081006046, 400081006003, 1),
    (400081006047, 400081006, 400081006001, 400081006047, 400081006003, 2),
    (400081006048, 400081006, 400081006001, 400081006048, 400081006003, 3),
    (400081006049, 400081006, 400081006001, 400081006049, 400081006003, 4),
    (400081006050, 400081006, 400081006001, 400081006050, 400081006003, 5),
    (400081006051, 400081006, 400081006001, 400081006051, 400081006003, 6),
    (400081006052, 400081006, 400081006001, 400081006052, 400081006003, 7),
    (400081006053, 400081006, 400081006001, 400081006053, 400081006004, 1),
    (400081006054, 400081006, 400081006001, 400081006054, 400081006004, 2),
    (400081006055, 400081006, 400081006001, 400081006055, 400081006004, 3),
    (400081006056, 400081006, 400081006001, 400081006056, 400081006004, 4),
    (400081006057, 400081006, 400081006001, 400081006057, 400081006004, 5),
    (400081006058, 400081006, 400081006001, 400081006058, 400081006004, 6),
    (400081006059, 400081006, 400081006001, 400081006059, 400081006004, 7),
    (400081006060, 400081006, 400081006001, 400081006060, 400081006004, 8),
    (400081006061, 400081006, 400081006001, 400081006061, 400081006004, 9),
    (400081006062, 400081006, 400081006001, 400081006062, 400081006004, 10),
    (400081006063, 400081006, 400081006001, 400081006063, 400081006004, 11),
    (400081006064, 400081006, 400081006001, 400081006064, 400081006004, 12),
    (400081006065, 400081006, 400081006001, 400081006065, 400081006004, 13),
    (400081006066, 400081006, 400081006001, 400081006066, 400081006005, 1),
    (400081006067, 400081006, 400081006001, 400081006067, 400081006005, 2),
    (400081006068, 400081006, 400081006001, 400081006068, 400081006005, 3),
    (400081006069, 400081006, 400081006001, 400081006069, 400081006005, 4),
    (400081006070, 400081006, 400081006001, 400081006070, 400081006005, 5),
    (400081006071, 400081006, 400081006001, 400081006071, 400081006005, 6),
    (400081006072, 400081006, 400081006001, 400081006072, 400081006005, 7),
    (400081006073, 400081006, 400081006001, 400081006073, 400081006005, 8),
    (400081006074, 400081006, 400081006001, 400081006074, 400081006005, 9),
    (400081006075, 400081006, 400081006001, 400081006075, 400081006005, 10),
    (400081006076, 400081006, 400081006001, 400081006076, 400081006005, 11),
    (400081006077, 400081006, 400081006001, 400081006077, 400081006005, 12),
    (400081006078, 400081006, 400081006001, 400081006078, 400081006005, 13),
    (400081006079, 400081006, 400081006001, 400081006079, 400081006005, 14),
    (400081006080, 400081006, 400081006001, 400081006080, 400081006005, 15),
    (400081006081, 400081006, 400081006001, 400081006081, 400081006005, 16),
    (400081006082, 400081006, 400081006001, 400081006082, 400081006005, 17),
    (400081006083, 400081006, 400081006001, 400081006083, 400081006005, 18),
    (400081006084, 400081006, 400081006001, 400081006084, 400081006005, 19),
    (400081006085, 400081006, 400081006001, 400081006085, 400081006005, 20),
    (400081006086, 400081006, 400081006001, 400081006086, 400081006006, 1),
    (400081006087, 400081006, 400081006001, 400081006087, 400081006006, 2),
    (400081006088, 400081006, 400081006001, 400081006088, 400081006006, 3),
    (400081006089, 400081006, 400081006001, 400081006089, 400081006006, 4),
    (400081006090, 400081006, 400081006001, 400081006090, 400081006007, 1),
    (400081006091, 400081006, 400081006001, 400081006091, 400081006007, 2),
    (400081006092, 400081006, 400081006001, 400081006092, 400081006007, 3),
    (400081006093, 400081006, 400081006001, 400081006093, 400081006007, 4),
    (400081006094, 400081006, 400081006001, 400081006094, 400081006007, 5),
    (400081006095, 400081006, 400081006001, 400081006095, 400081006007, 6),
    (400081006096, 400081006, 400081006001, 400081006096, 400081006007, 7),
    (400081006097, 400081006, 400081006001, 400081006097, 400081006007, 8),
    (400081006098, 400081006, 400081006001, 400081006098, 400081006007, 9),
    (400081006099, 400081006, 400081006001, 400081006099, 400081006007, 10),
    (400081006100, 400081006, 400081006001, 400081006100, 400081006007, 11),
    (400081006101, 400081006, 400081006001, 400081006101, 400081006008, 1),
    (400081006102, 400081006, 400081006001, 400081006102, 400081006008, 2),
    (400081006103, 400081006, 400081006001, 400081006103, 400081006008, 3),
    (400081006104, 400081006, 400081006001, 400081006104, 400081006008, 4),
    (400081006105, 400081006, 400081006001, 400081006105, 400081006008, 5),
    (400081006106, 400081006, 400081006001, 400081006106, 400081006008, 6),
    (400081006107, 400081006, 400081006001, 400081006107, 400081006008, 7),
    (400081006108, 400081006, 400081006001, 400081006108, 400081006008, 8),
    (400081006109, 400081006, 400081006001, 400081006109, 400081006008, 9),
    (400081006110, 400081006, 400081006001, 400081006110, 400081006008, 10),
    (400081006111, 400081006, 400081006001, 400081006111, 400081006008, 11),
    (400081006112, 400081006, 400081006001, 400081006112, 400081006008, 12),
    (400081006113, 400081006, 400081006001, 400081006113, 400081006008, 13),
    (400081006114, 400081006, 400081006001, 400081006114, 400081006008, 14),
    (400081006115, 400081006, 400081006001, 400081006115, 400081006008, 15),
    (400081006116, 400081006, 400081006001, 400081006116, 400081006008, 16),
    (400081006117, 400081006, 400081006001, 400081006117, 400081006008, 17),
    (400081006118, 400081006, 400081006001, 400081006118, 400081006008, 18),
    (400081006119, 400081006, 400081006001, 400081006119, 400081006008, 19),
    (400081006120, 400081006, 400081006001, 400081006120, 400081006008, 20),
    (400081006121, 400081006, 400081006001, 400081006121, 400081006008, 21),
    (400081006122, 400081006, 400081006001, 400081006122, 400081006009, 1),
    (400081006123, 400081006, 400081006001, 400081006123, 400081006009, 2),
    (400081006124, 400081006, 400081006001, 400081006124, 400081006009, 3),
    (400081006125, 400081006, 400081006001, 400081006125, 400081006009, 4),
    (400081006126, 400081006, 400081006001, 400081006126, 400081006009, 5),
    (400081006127, 400081006, 400081006001, 400081006127, 400081006009, 6),
    (400081006128, 400081006, 400081006001, 400081006128, 400081006009, 7),
    (400081006129, 400081006, 400081006001, 400081006129, 400081006009, 8),
    (400081006130, 400081006, 400081006001, 400081006130, 400081006009, 9),
    (400081006131, 400081006, 400081006001, 400081006131, 400081006009, 10),
    (400081006132, 400081006, 400081006001, 400081006132, 400081006009, 11),
    (400081006133, 400081006, 400081006001, 400081006133, 400081006009, 12),
    (400081006134, 400081006, 400081006001, 400081006134, 400081006010, 1),
    (400081006135, 400081006, 400081006001, 400081006135, 400081006010, 2),
    (400081006136, 400081006, 400081006001, 400081006136, 400081006010, 3),
    (400081006137, 400081006, 400081006001, 400081006137, 400081006010, 4),
    (400081006138, 400081006, 400081006001, 400081006138, 400081006010, 5),
    (400081006139, 400081006, 400081006001, 400081006139, 400081006010, 6),
    (400081006140, 400081006, 400081006001, 400081006140, 400081006010, 7),
    (400081006141, 400081006, 400081006001, 400081006141, 400081006010, 8),
    (400081006142, 400081006, 400081006001, 400081006142, 400081006010, 9),
    (400081006143, 400081006, 400081006001, 400081006143, 400081006010, 10),
    (400081006144, 400081006, 400081006001, 400081006144, 400081006010, 11),
    (400081006145, 400081006, 400081006001, 400081006145, 400081006010, 12),
    (400081006146, 400081006, 400081006001, 400081006146, 400081006010, 13),
    (400081006147, 400081006, 400081006001, 400081006147, 400081006010, 14),
    (400081006148, 400081006, 400081006001, 400081006148, 400081006010, 15),
    (400081006149, 400081006, 400081006001, 400081006149, 400081006010, 16),
    (400081006150, 400081006, 400081006001, 400081006150, 400081006010, 17),
    (400081006151, 400081006, 400081006001, 400081006151, 400081006010, 18),
    (400081006152, 400081006, 400081006001, 400081006152, 400081006010, 19),
    (400081006153, 400081006, 400081006001, 400081006153, 400081006010, 20),
    (400081006154, 400081006, 400081006001, 400081006154, 400081006010, 21),
    (400081006155, 400081006, 400081006001, 400081006155, 400081006010, 22),
    (400081006156, 400081006, 400081006001, 400081006156, 400081006010, 23),
    (400081006157, 400081006, 400081006001, 400081006157, 400081006010, 24),
    (400081006158, 400081006, 400081006001, 400081006158, 400081006010, 25),
    (400081006159, 400081006, 400081006001, 400081006159, 400081006010, 26),
    (400081006160, 400081006, 400081006001, 400081006160, 400081006011, 1),
    (400081006161, 400081006, 400081006001, 400081006161, 400081006011, 2),
    (400081006162, 400081006, 400081006001, 400081006162, 400081006011, 3),
    (400081006163, 400081006, 400081006001, 400081006163, 400081006011, 4),
    (400081006164, 400081006, 400081006001, 400081006164, 400081006011, 5),
    (400081006165, 400081006, 400081006001, 400081006165, 400081006011, 6),
    (400081006166, 400081006, 400081006001, 400081006166, 400081006011, 7),
    (400081006167, 400081006, 400081006001, 400081006167, 400081006011, 8),
    (400081006168, 400081006, 400081006001, 400081006168, 400081006011, 9),
    (400081006169, 400081006, 400081006001, 400081006169, 400081006012, 1),
    (400081006170, 400081006, 400081006001, 400081006170, 400081006012, 2),
    (400081006171, 400081006, 400081006001, 400081006171, 400081006012, 3),
    (400081006172, 400081006, 400081006001, 400081006172, 400081006012, 4),
    (400081006173, 400081006, 400081006001, 400081006173, 400081006012, 5),
    (400081006174, 400081006, 400081006001, 400081006174, 400081006012, 6),
    (400081006175, 400081006, 400081006001, 400081006175, 400081006013, 1),
    (400081006176, 400081006, 400081006001, 400081006176, 400081006013, 2),
    (400081006177, 400081006, 400081006001, 400081006177, 400081006013, 3),
    (400081006178, 400081006, 400081006001, 400081006178, 400081006013, 4),
    (400081006179, 400081006, 400081006001, 400081006179, 400081006013, 5),
    (400081006180, 400081006, 400081006001, 400081006180, 400081006013, 6),
    (400081006181, 400081006, 400081006001, 400081006181, 400081006013, 7),
    (400081006182, 400081006, 400081006001, 400081006182, 400081006013, 8),
    (400081006183, 400081006, 400081006001, 400081006183, 400081006013, 9),
    (400081006184, 400081006, 400081006001, 400081006184, 400081006013, 10),
    (400081006185, 400081006, 400081006001, 400081006185, 400081006013, 11),
    (400081006186, 400081006, 400081006001, 400081006186, 400081006013, 12),
    (400081006187, 400081006, 400081006001, 400081006187, 400081006013, 13),
    (400081006188, 400081006, 400081006001, 400081006188, 400081006013, 14),
    (400081006189, 400081006, 400081006001, 400081006189, 400081006014, 1),
    (400081006190, 400081006, 400081006001, 400081006190, 400081006014, 2),
    (400081006191, 400081006, 400081006001, 400081006191, 400081006014, 3),
    (400081006192, 400081006, 400081006001, 400081006192, 400081006014, 4),
    (400081006193, 400081006, 400081006001, 400081006193, 400081006014, 5),
    (400081006194, 400081006, 400081006001, 400081006194, 400081006014, 6),
    (400081006195, 400081006, 400081006001, 400081006195, 400081006014, 7),
    (400081006196, 400081006, 400081006001, 400081006196, 400081006015, 1),
    (400081006197, 400081006, 400081006001, 400081006197, 400081006015, 2),
    (400081006198, 400081006, 400081006001, 400081006198, 400081006015, 3),
    (400081006199, 400081006, 400081006001, 400081006199, 400081006016, 1),
    (400081006200, 400081006, 400081006001, 400081006200, 400081006016, 2),
    (400081006201, 400081006, 400081006001, 400081006201, 400081006016, 3),
    (400081006202, 400081006, 400081006001, 400081006202, 400081006016, 4),
    (400081006203, 400081006, 400081006001, 400081006203, 400081006016, 5),
    (400081006204, 400081006, 400081006001, 400081006204, 400081006016, 6),
    (400081006205, 400081006, 400081006001, 400081006205, 400081006016, 7),
    (400081006206, 400081006, 400081006001, 400081006206, 400081006016, 8),
    (400081006207, 400081006, 400081006001, 400081006207, 400081006016, 9),
    (400081006208, 400081006, 400081006001, 400081006208, 400081006016, 10);

-- === NEEDS-REVIEW ITEMS ===
-- menu_item_id 400081006196 (ORANGE / Mocktails): variant label set ['Mocktails', 'Mojito', 'Blueberry'] not a recognized size/ingredient pattern -- kept as same-dish variants by default, confirm this wasn't meant to split into separate dishes (confidence 0.6)
-- menu_item_id 400081006196 (ORANGE / Mojito): variant label set ['Mocktails', 'Mojito', 'Blueberry'] not a recognized size/ingredient pattern -- kept as same-dish variants by default, confirm this wasn't meant to split into separate dishes (confidence 0.6)
-- menu_item_id 400081006196 (ORANGE / Blueberry): variant label set ['Mocktails', 'Mojito', 'Blueberry'] not a recognized size/ingredient pattern -- kept as same-dish variants by default, confirm this wasn't meant to split into separate dishes (confidence 0.6)
-- menu_item_id 400081006197 (LEMON PUDINA / Mocktails): variant label set ['Mocktails', 'Mojito', 'Blueberry'] not a recognized size/ingredient pattern -- kept as same-dish variants by default, confirm this wasn't meant to split into separate dishes (confidence 0.6)
-- menu_item_id 400081006197 (LEMON PUDINA / Mojito): variant label set ['Mocktails', 'Mojito', 'Blueberry'] not a recognized size/ingredient pattern -- kept as same-dish variants by default, confirm this wasn't meant to split into separate dishes (confidence 0.6)
-- menu_item_id 400081006197 (LEMON PUDINA / Blueberry): variant label set ['Mocktails', 'Mojito', 'Blueberry'] not a recognized size/ingredient pattern -- kept as same-dish variants by default, confirm this wasn't meant to split into separate dishes (confidence 0.6)
-- menu_item_id 400081006198 (BLUEBERRY / Mocktails): variant label set ['Mocktails', 'Mojito', 'Blueberry'] not a recognized size/ingredient pattern -- kept as same-dish variants by default, confirm this wasn't meant to split into separate dishes (confidence 0.6)
-- menu_item_id 400081006198 (BLUEBERRY / Mojito): variant label set ['Mocktails', 'Mojito', 'Blueberry'] not a recognized size/ingredient pattern -- kept as same-dish variants by default, confirm this wasn't meant to split into separate dishes (confidence 0.6)
-- menu_item_id 400081006198 (BLUEBERRY / Blueberry): variant label set ['Mocktails', 'Mojito', 'Blueberry'] not a recognized size/ingredient pattern -- kept as same-dish variants by default, confirm this wasn't meant to split into separate dishes (confidence 0.6)

-- === UNMAPPED / INFORMATIONAL RESTAURANT-LEVEL NOTES ===
-- website from JSON: "maniscafe.co.in" -- establishment.website_url column exists; not populated by this pass (kept here for visibility).
-- price-per-person from JSON: "₹1–200" -- no matching restaurant-level column; not inserted anywhere.
-- HALAL: attempted as a restaurant_tag lookup against platform_tag (tag_code='halal') above; if that tag doesn't exist yet in the live database the insert was a no-op -- verify and add the tag if it should exist.
-- 'NO BEEF' page notice: informational assurance text, not a formal dietary tag/column; not inserted anywhere.

COMMIT;