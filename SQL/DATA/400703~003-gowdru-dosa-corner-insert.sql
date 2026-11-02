-- Khaustan menu onboarding: Gowdru Dosa Corner
-- Source JSON: Gowdru_Dosa_Corner_Menu_OCR.json
-- Source image(s): Gowdru dosa Center.jpg
-- establishment_id / restaurant_id / source_id namespace: 400703003
-- Generated against json-insertscript-prompt.md (Resolved: KhaustanRestaurantMenu).
-- NOTE (schema bug, not routed around): menu_item_price's ck_menu_item_price_amount
-- CHECK compares is_market_price (boolean) to integer literals (= 1 / = 0), which
-- PostgreSQL will reject with 'operator does not exist: boolean = integer'. This
-- script does not use is_market_price = TRUE anywhere, so it is not blocked by the
-- bug, but the bug should still be fixed in the schema before relying on that path.
-- NOTE: no lookup-table resolution (protein_type, platform_tag, delivery_provider,
-- service_mode) was required for this restaurant -- see chat reply for why.

--\connect "KhaustanRestaurantMenu"
BEGIN;

-- Helper sequence for standalone IDs not covered by the mandatory establishment
-- namespace (restaurant_phone_id, restaurant_hours_id, menu_extraction_batch_id,
-- canonical_dish_id, canonical_dish_name_id). Safe to share across restaurant runs.
DO $do$
DECLARE
  v_max BIGINT;
BEGIN
  SELECT GREATEST(
    COALESCE((SELECT MAX(restaurant_phone_id) FROM restaurant_phone), 0),
    COALESCE((SELECT MAX(restaurant_hours_id) FROM restaurant_hours), 0),
    COALESCE((SELECT MAX(extraction_batch_id) FROM menu_extraction_batch), 0),
    COALESCE((SELECT MAX(canonical_dish_id) FROM canonical_dish), 0),
    COALESCE((SELECT MAX(canonical_dish_name_id) FROM canonical_dish_name), 0)
  ) INTO v_max;
  EXECUTE format('CREATE SEQUENCE IF NOT EXISTS khaustan_standalone_id_seq START WITH %s', v_max + 1);
END $do$;

-- Establishment + restaurant (explicit deterministic IDs -- never nextval() here)
INSERT INTO establishment (
    establishment_id, name, normalized_name, address_line1, address_line2,
    locality, city, state, country_code, postal_code, latitude, longitude
) VALUES (
    400703003, 'Gowdru Dosa Corner', 'gowdru dosa corner',
    'Sector 30', NULL, 'Vashi', 'Navi Mumbai',
    'Maharashtra', 'IN', '400703', 19.065118635200704, 72.9989270812864
);

INSERT INTO restaurant (
    restaurant_id, establishment_id, display_name, normalized_name,
    has_bar, bar_license_type
) VALUES (
    400703003, 400703003, 'Gowdru Dosa Corner', 'gowdru dosa corner',
    FALSE, 'none'
);

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400703003, 'ai_menu_extraction', 'Gowdru_Dosa_Corner_Menu_OCR.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, status_code)
VALUES (nextval('khaustan_standalone_id_seq'), 400703003, 400703003, (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');
SELECT extraction_batch_id FROM menu_extraction_batch WHERE source_id = 400703003 ORDER BY extraction_batch_id DESC LIMIT 1 \gset

-- Phones
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES (nextval('khaustan_standalone_id_seq'), 400703003, '9819223963', TRUE);
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES (nextval('khaustan_standalone_id_seq'), 400703003, '9987908347', FALSE);

-- Hours: single stated window applied to every day (JSON gives one blanket timing,
-- no per-day breakdown) -- confidence: inferred blanket application, not per-day-confirmed.
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
VALUES
    (nextval('khaustan_standalone_id_seq'), 400703003, 1, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703003, 2, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703003, 3, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703003, 4, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703003, 5, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703003, 6, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703003, 7, 1, '08:30'::time, '22:00'::time);

-- Menu board: JSON has no explicit board label -- one a_la_carte board per Step 2.
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, is_active, display_sequence)
VALUES (400703003001, 400703003, 'Main Menu', 'a_la_carte', TRUE, 1);

-- Categories, in JSON/source order, verbatim leaf text (including source typos)
INSERT INTO menu_category (menu_category_id, restaurant_id, name, parent_category_id, display_sequence)
VALUES
    (400703003001, 400703003, 'IDLI WADA VARIETY', NULL, 1),
    (400703003002, 400703003, 'SADA VARIETY', NULL, 2),
    (400703003003, 400703003, 'MASALA VARYERY', NULL, 3),
    (400703003004, 400703003, 'SPECIAL VARIETY', NULL, 4),
    (400703003005, 400703003, 'UTTAPA VARYETY', NULL, 5);

-- Board <-> category mapping (menu_board_category has no standalone id column)
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (400703003, 400703003001, 400703003001, 1),
    (400703003, 400703003001, 400703003002, 2),
    (400703003, 400703003001, 400703003003, 3),
    (400703003, 400703003001, 400703003004, 4),
    (400703003, 400703003001, 400703003005, 5);

-- Canonical dish identify-or-create: no unique constraint on canonical_dish.normalized_name,
-- so NOT EXISTS, not ON CONFLICT. Whether these already exist from an earlier onboarded
-- restaurant is resolved live by this check when the script runs -- not something knowable
-- in advance, and not guessed here.
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Idli', 'idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Idli', 'idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Medu Wada', 'medu wada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'medu wada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Medu Wada', 'medu wada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dal wada', 'dal wada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal wada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dal wada', 'dal wada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Idli Wada', 'idli wada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'idli wada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Idli Wada', 'idli wada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Idli', 'butter idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Idli', 'butter idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Masala Idli', 'masala idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Masala Idli', 'masala idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Masala Idli', 'cheese masala idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese masala idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Masala Idli', 'cheese masala idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Schezwan Masala Idli', 'schezwan masala idli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan masala idli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Schezwan Masala Idli', 'schezwan masala idli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Idli Chilli', 'idli chilli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'idli chilli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Idli Chilli', 'idli chilli', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Sada Dosa', 'cheese sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Sada Dosa', 'cheese sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Panner Sada Dosa', 'panner sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Panner Sada Dosa', 'panner sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Panner Sada', 'cheese panner sada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese panner sada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Panner Sada', 'cheese panner sada', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Schzewan Sada Dosa', 'paneer schzewan sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer schzewan sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Schzewan Sada Dosa', 'paneer schzewan sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Schzewan Cheese Sada Dosa', 'schzewan cheese sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schzewan cheese sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Schzewan Cheese Sada Dosa', 'schzewan cheese sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Schzewan Cheese Paneer Sada Dosa', 'schzewan cheese paneer sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schzewan cheese paneer sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Schzewan Cheese Paneer Sada Dosa', 'schzewan cheese paneer sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Onion Sada Dosa', 'onion sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Onion Sada Dosa', 'onion sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Onion Cheese Panner Dosa', 'onion cheese panner dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion cheese panner dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Onion Cheese Panner Dosa', 'onion cheese panner dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Onion Cheese Dosa', 'onion cheese dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion cheese dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Onion Cheese Dosa', 'onion cheese dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Onion Panner Dosa', 'onion panner dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion panner dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Onion Panner Dosa', 'onion panner dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Schezwan Onion Dosa', 'schezwan onion dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan onion dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Schezwan Onion Dosa', 'schezwan onion dosa', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Mysore Sada Dosa', 'cheese mysore sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese mysore sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Mysore Sada Dosa', 'cheese mysore sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Panner Mysore Sada Dosa', 'panner mysore sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner mysore sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Panner Mysore Sada Dosa', 'panner mysore sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Panner Cheese Mysore Sada Dosa', 'panner cheese mysore sada dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner cheese mysore sada dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Panner Cheese Mysore Sada Dosa', 'panner cheese mysore sada dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Schzewan Mysore Sada Dosa (Extra Cheese 30/-)', 'schzewan mysore sada dosa (extra cheese 30/-)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schzewan mysore sada dosa (extra cheese 30/-)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Schzewan Mysore Sada Dosa (Extra Cheese 30/-)', 'schzewan mysore sada dosa (extra cheese 30/-)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chutney Powder Dosa (Extra Cheese 30/-)', 'chutney powder dosa (extra cheese 30/-)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chutney powder dosa (extra cheese 30/-)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chutney Powder Dosa (Extra Cheese 30/-)', 'chutney powder dosa (extra cheese 30/-)', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Masala Dosa', 'cheese masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Masala Dosa', 'cheese masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Panner Masala Dosa', 'panner masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Panner Masala Dosa', 'panner masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Panner Masala Dosa', 'cheese panner masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese panner masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Panner Masala Dosa', 'cheese panner masala dosa', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Schezwan Masala Dosa', 'cheese schezwan masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese schezwan masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Schezwan Masala Dosa', 'cheese schezwan masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Schezwan Cheese Paneer Masala Dosa', 'schezwan cheese paneer masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan cheese paneer masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Schezwan Cheese Paneer Masala Dosa', 'schezwan cheese paneer masala dosa', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Mysore Masala Dosa', 'cheese mysore masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese mysore masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Mysore Masala Dosa', 'cheese mysore masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Mysore Masala Dosa', 'paneer mysore masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer mysore masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Mysore Masala Dosa', 'paneer mysore masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Paneer Mysore Masala Dosa', 'cheese paneer mysore masala dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese paneer mysore masala dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Paneer Mysore Masala Dosa', 'cheese paneer mysore masala dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Schezwan Mysore Masala', 'schezwan mysore masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan mysore masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Schezwan Mysore Masala', 'schezwan mysore masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Schezwan Cheese Mysore Masala', 'schezwan cheese mysore masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan cheese mysore masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Schezwan Cheese Mysore Masala', 'schezwan cheese mysore masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Schezwan Paneer Mysore Masala', 'schezwan paneer mysore masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan paneer mysore masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Schezwan Paneer Mysore Masala', 'schezwan paneer mysore masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Schezwan Cheese Paneer Mysore Masala', 'schezwan cheese paneer mysore masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan cheese paneer mysore masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Schezwan Cheese Paneer Mysore Masala', 'schezwan cheese paneer mysore masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pav Bhaji Dosa', 'pav bhaji dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pav bhaji dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pav Bhaji Dosa', 'pav bhaji dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Pav Bhaji Dosa', 'cheese pav bhaji dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese pav bhaji dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Pav Bhaji Dosa', 'cheese pav bhaji dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Pav Bhaji Dosa', 'paneer pav bhaji dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pav bhaji dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Pav Bhaji Dosa', 'paneer pav bhaji dosa', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Panner Chilly Dosa', 'panner chilly dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner chilly dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Panner Chilly Dosa', 'panner chilly dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Chilly Dosa', 'cheese chilly dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chilly dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Chilly Dosa', 'cheese chilly dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Gowdru Special Dosa', 'gowdru special dosa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'gowdru special dosa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Gowdru Special Dosa', 'gowdru special dosa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Set Dosa (3pcs)', 'set dosa (3pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'set dosa (3pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Set Dosa (3pcs)', 'set dosa (3pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sada Uttapa', 'sada uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sada uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sada Uttapa', 'sada uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sada Cheese Uttapa', 'sada cheese uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sada cheese uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sada Cheese Uttapa', 'sada cheese uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Panner Cheese Sada Uttapa', 'panner cheese sada uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner cheese sada uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Panner Cheese Sada Uttapa', 'panner cheese sada uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Onion Uttapa', 'onion uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Onion Uttapa', 'onion uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Onion Uttapa', 'cheese onion uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese onion uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Onion Uttapa', 'cheese onion uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Panner Onion Uttapa', 'panner onion uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner onion uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Panner Onion Uttapa', 'panner onion uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tomato Uttapa', 'tomato uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tomato Uttapa', 'tomato uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Tomato Uttapa', 'cheese tomato uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese tomato uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Tomato Uttapa', 'cheese tomato uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Panner Tomato Uttapa', 'panner tomato uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner tomato uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Panner Tomato Uttapa', 'panner tomato uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Onion Capsicum Uttapa', 'onion capsicum uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion capsicum uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Onion Capsicum Uttapa', 'onion capsicum uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Onion Tomato Uttapa', 'onion tomato uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'onion tomato uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Onion Tomato Uttapa', 'onion tomato uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Onion Capsicum Uttapa', 'cheese onion capsicum uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese onion capsicum uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Onion Capsicum Uttapa', 'cheese onion capsicum uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Panner Onion Capsicum Uttapa', 'panner onion capsicum uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner onion capsicum uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Panner Onion Capsicum Uttapa', 'panner onion capsicum uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Masala Uttapa', 'masala uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Masala Uttapa', 'masala uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Masala Uttapa', 'cheese masala uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese masala uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Masala Uttapa', 'cheese masala uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Panner Masala Uttapa', 'panner masala uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner masala uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Panner Masala Uttapa', 'panner masala uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mysore Masala Uttapa', 'mysore masala uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mysore masala uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mysore Masala Uttapa', 'mysore masala uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Mysore Masala Uttapa', 'cheese mysore masala uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese mysore masala uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Mysore Masala Uttapa', 'cheese mysore masala uttapa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Panner Mysore Masala Uttapa', 'panner mysore masala uttapa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'panner mysore masala uttapa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Panner Mysore Masala Uttapa', 'panner mysore masala uttapa', 'primary'
FROM new_dish;

-- Menu items: deterministic explicit menu_item_id; canonical_dish_id resolved live
-- via join (its value isn't knowable in advance -- may be newly created above or
-- may already exist from a previously onboarded restaurant).
INSERT INTO menu_item (
    menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name,
    raw_category_text, food_classification_code, is_jain, verification_status_code
)
SELECT x.menu_item_id, x.restaurant_id, cd.canonical_dish_id, x.name, x.normalized_name,
       x.raw_category_text, x.food_classification_code, x.is_jain::boolean, x.verification_status_code
FROM (VALUES
    (400703003001, 400703003, 'Idli', 'idli', 'IDLI WADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003002, 400703003, 'Medu Wada', 'medu wada', 'IDLI WADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003003, 400703003, 'Dal wada', 'dal wada', 'IDLI WADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003004, 400703003, 'Idli Wada', 'idli wada', 'IDLI WADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003005, 400703003, 'Butter Idli', 'butter idli', 'IDLI WADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003006, 400703003, 'Masala Idli', 'masala idli', 'IDLI WADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003007, 400703003, 'Cheese Masala Idli', 'cheese masala idli', 'IDLI WADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003008, 400703003, 'Schezwan Masala Idli', 'schezwan masala idli', 'IDLI WADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003009, 400703003, 'Idli Chilli', 'idli chilli', 'IDLI WADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003010, 400703003, 'Sada Dosa', 'sada dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003011, 400703003, 'Cheese Sada Dosa', 'cheese sada dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003012, 400703003, 'Panner Sada Dosa', 'panner sada dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003013, 400703003, 'Cheese Panner Sada', 'cheese panner sada', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003014, 400703003, 'Schezwan Sada Dosa', 'schezwan sada dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003015, 400703003, 'Paneer Schzewan Sada Dosa', 'paneer schzewan sada dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003016, 400703003, 'Schzewan Cheese Sada Dosa', 'schzewan cheese sada dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003017, 400703003, 'Schzewan Cheese Paneer Sada Dosa', 'schzewan cheese paneer sada dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003018, 400703003, 'Onion Sada Dosa', 'onion sada dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003019, 400703003, 'Onion Cheese Panner Dosa', 'onion cheese panner dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003020, 400703003, 'Onion Cheese Dosa', 'onion cheese dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003021, 400703003, 'Onion Panner Dosa', 'onion panner dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003022, 400703003, 'Schezwan Onion Dosa', 'schezwan onion dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003023, 400703003, 'Mysore Sada Dosa', 'mysore sada dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003024, 400703003, 'Cheese Mysore Sada Dosa', 'cheese mysore sada dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003025, 400703003, 'Panner Mysore Sada Dosa', 'panner mysore sada dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003026, 400703003, 'Panner Cheese Mysore Sada Dosa', 'panner cheese mysore sada dosa', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003027, 400703003, 'Schzewan Mysore Sada Dosa (Extra Cheese 30/-)', 'schzewan mysore sada dosa (extra cheese 30/-)', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003028, 400703003, 'Chutney Powder Dosa (Extra Cheese 30/-)', 'chutney powder dosa (extra cheese 30/-)', 'SADA VARIETY', 'veg', NULL, 'unverified'),
    (400703003029, 400703003, 'Masala Dosa', 'masala dosa', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003030, 400703003, 'Cheese Masala Dosa', 'cheese masala dosa', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003031, 400703003, 'Panner Masala Dosa', 'panner masala dosa', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003032, 400703003, 'Cheese Panner Masala Dosa', 'cheese panner masala dosa', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003033, 400703003, 'Schezwan Masala Dosa', 'schezwan masala dosa', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003034, 400703003, 'Cheese Schezwan Masala Dosa', 'cheese schezwan masala dosa', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003035, 400703003, 'Schezwan Cheese Paneer Masala Dosa', 'schezwan cheese paneer masala dosa', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003036, 400703003, 'Mysore Masala Dosa', 'mysore masala dosa', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003037, 400703003, 'Cheese Mysore Masala Dosa', 'cheese mysore masala dosa', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003038, 400703003, 'Paneer Mysore Masala Dosa', 'paneer mysore masala dosa', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003039, 400703003, 'Cheese Paneer Mysore Masala Dosa', 'cheese paneer mysore masala dosa', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003040, 400703003, 'Schezwan Mysore Masala', 'schezwan mysore masala', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003041, 400703003, 'Schezwan Cheese Mysore Masala', 'schezwan cheese mysore masala', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003042, 400703003, 'Schezwan Paneer Mysore Masala', 'schezwan paneer mysore masala', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003043, 400703003, 'Schezwan Cheese Paneer Mysore Masala', 'schezwan cheese paneer mysore masala', 'MASALA VARYERY', 'veg', NULL, 'unverified'),
    (400703003044, 400703003, 'Pav Bhaji Dosa', 'pav bhaji dosa', 'SPECIAL VARIETY', 'veg', NULL, 'unverified'),
    (400703003045, 400703003, 'Cheese Pav Bhaji Dosa', 'cheese pav bhaji dosa', 'SPECIAL VARIETY', 'veg', NULL, 'unverified'),
    (400703003046, 400703003, 'Paneer Pav Bhaji Dosa', 'paneer pav bhaji dosa', 'SPECIAL VARIETY', 'veg', NULL, 'unverified'),
    (400703003047, 400703003, 'Jini Dosa', 'jini dosa', 'SPECIAL VARIETY', 'veg', NULL, 'unverified'),
    (400703003048, 400703003, 'Panner Chilly Dosa', 'panner chilly dosa', 'SPECIAL VARIETY', 'veg', NULL, 'unverified'),
    (400703003049, 400703003, 'Cheese Chilly Dosa', 'cheese chilly dosa', 'SPECIAL VARIETY', 'veg', NULL, 'unverified'),
    (400703003050, 400703003, 'Gowdru Special Dosa', 'gowdru special dosa', 'SPECIAL VARIETY', 'veg', NULL, 'unverified'),
    (400703003051, 400703003, 'Set Dosa (3pcs)', 'set dosa (3pcs)', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003052, 400703003, 'Sada Uttapa', 'sada uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003053, 400703003, 'Sada Cheese Uttapa', 'sada cheese uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003054, 400703003, 'Panner Cheese Sada Uttapa', 'panner cheese sada uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003055, 400703003, 'Onion Uttapa', 'onion uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003056, 400703003, 'Cheese Onion Uttapa', 'cheese onion uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003057, 400703003, 'Panner Onion Uttapa', 'panner onion uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003058, 400703003, 'Tomato Uttapa', 'tomato uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003059, 400703003, 'Cheese Tomato Uttapa', 'cheese tomato uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003060, 400703003, 'Panner Tomato Uttapa', 'panner tomato uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003061, 400703003, 'Onion Capsicum Uttapa', 'onion capsicum uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003062, 400703003, 'Onion Tomato Uttapa', 'onion tomato uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003063, 400703003, 'Cheese Onion Capsicum Uttapa', 'cheese onion capsicum uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003064, 400703003, 'Panner Onion Capsicum Uttapa', 'panner onion capsicum uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003065, 400703003, 'Masala Uttapa', 'masala uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003066, 400703003, 'Cheese Masala Uttapa', 'cheese masala uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003067, 400703003, 'Panner Masala Uttapa', 'panner masala uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003068, 400703003, 'Mysore Masala Uttapa', 'mysore masala uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003069, 400703003, 'Cheese Mysore Masala Uttapa', 'cheese mysore masala uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified'),
    (400703003070, 400703003, 'Panner Mysore Masala Uttapa', 'panner mysore masala uttapa', 'UTTAPA VARYETY', 'veg', NULL, 'unverified')
) AS x(menu_item_id, restaurant_id, name, normalized_name, raw_category_text, food_classification_code, is_jain, verification_status_code)
JOIN canonical_dish cd ON cd.normalized_name = x.normalized_name;

-- Menu item source: name/existence confidence, kept separate from price confidence.
-- A missing price (see below) does not lower this -- the item's identity is certain
-- either way; verification_status_code still flags the item for follow-up.
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
VALUES
    (400703003001, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003002, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003003, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003004, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003005, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003006, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003007, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003008, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003009, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003010, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003011, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003012, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003013, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003014, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003015, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003016, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003017, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003018, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003019, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003020, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003021, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003022, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003023, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003024, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003025, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003026, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003027, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003028, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003029, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003030, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003031, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003032, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003033, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003034, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003035, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003036, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003037, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003038, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003039, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003040, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003041, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003042, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003043, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003044, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003045, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003046, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003047, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003048, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003049, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003050, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003051, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003052, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003053, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003054, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003055, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003056, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003057, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003058, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003059, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003060, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003061, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003062, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003063, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003064, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003065, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003066, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003067, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003068, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003069, 400703003, :extraction_batch_id, 0.95, 'unverified'),
    (400703003070, 400703003, :extraction_batch_id, 0.95, 'unverified');

-- Variants (portion/label variants -- one menu_item, multiple menu_item_variant rows)
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
VALUES
    (400703003001, 400703003001, 'Regular', 'fixed', TRUE),
    (400703003002, 400703003002, 'Regular', 'fixed', TRUE),
    (400703003003, 400703003003, 'Regular', 'fixed', TRUE),
    (400703003004, 400703003004, 'Regular', 'fixed', TRUE),
    (400703003005, 400703003005, 'Regular', 'fixed', TRUE),
    (400703003006, 400703003006, 'Regular', 'fixed', TRUE),
    (400703003007, 400703003007, 'Regular', 'fixed', TRUE),
    (400703003008, 400703003008, 'Regular', 'fixed', TRUE),
    (400703003009, 400703003009, 'Regular', 'fixed', TRUE),
    (400703003010, 400703003010, 'Regular', 'fixed', TRUE),
    (400703003011, 400703003011, 'Regular', 'fixed', TRUE),
    (400703003012, 400703003012, 'Regular', 'fixed', TRUE),
    (400703003013, 400703003013, 'Regular', 'fixed', TRUE),
    (400703003014, 400703003014, 'Regular', 'fixed', TRUE),
    (400703003015, 400703003015, 'Regular', 'fixed', TRUE),
    (400703003016, 400703003016, 'Regular', 'fixed', TRUE),
    (400703003017, 400703003017, 'Regular', 'fixed', TRUE),
    (400703003018, 400703003018, 'Regular', 'fixed', TRUE),
    (400703003019, 400703003019, 'Regular', 'fixed', TRUE),
    (400703003020, 400703003020, 'Regular', 'fixed', TRUE),
    (400703003021, 400703003021, 'Regular', 'fixed', TRUE),
    (400703003022, 400703003022, 'Regular', 'fixed', TRUE),
    (400703003023, 400703003023, 'Regular', 'fixed', TRUE),
    (400703003024, 400703003024, 'Regular', 'fixed', TRUE),
    (400703003025, 400703003025, 'Regular', 'fixed', TRUE),
    (400703003026, 400703003026, 'Regular', 'fixed', TRUE),
    (400703003027, 400703003027, 'Regular', 'fixed', TRUE),
    (400703003028, 400703003028, 'Regular', 'fixed', TRUE),
    (400703003029, 400703003029, 'Regular', 'fixed', TRUE),
    (400703003030, 400703003030, 'Regular', 'fixed', TRUE),
    (400703003031, 400703003031, 'Regular', 'fixed', TRUE),
    (400703003032, 400703003032, 'Regular', 'fixed', TRUE),
    (400703003033, 400703003033, 'Regular', 'fixed', TRUE),
    (400703003034, 400703003034, 'Regular', 'fixed', TRUE),
    (400703003035, 400703003035, 'Regular', 'fixed', TRUE),
    (400703003036, 400703003036, 'Regular', 'fixed', TRUE),
    (400703003037, 400703003037, 'Regular', 'fixed', TRUE),
    (400703003038, 400703003038, 'Regular', 'fixed', TRUE),
    (400703003039, 400703003039, 'Regular', 'fixed', TRUE),
    (400703003040, 400703003040, 'Regular', 'fixed', TRUE),
    (400703003041, 400703003041, 'Regular', 'fixed', TRUE),
    (400703003042, 400703003042, 'Regular', 'fixed', TRUE),
    (400703003043, 400703003043, 'Regular', 'fixed', TRUE),
    (400703003044, 400703003044, 'Regular', 'fixed', TRUE),
    (400703003045, 400703003045, 'Regular', 'fixed', TRUE),
    (400703003046, 400703003046, 'Regular', 'fixed', TRUE),
    (400703003047, 400703003047, 'Regular', 'fixed', TRUE),
    (400703003048, 400703003048, 'Regular', 'fixed', TRUE),
    (400703003049, 400703003049, 'Regular', 'fixed', TRUE),
    (400703003050, 400703003050, 'Regular', 'fixed', TRUE),
    (400703003051, 400703003051, 'Regular', 'fixed', TRUE),
    (400703003052, 400703003052, 'Regular', 'fixed', TRUE),
    (400703003053, 400703003053, 'Regular', 'fixed', TRUE),
    (400703003054, 400703003054, 'Regular', 'fixed', TRUE),
    (400703003055, 400703003055, 'Regular', 'fixed', TRUE),
    (400703003056, 400703003056, 'Regular', 'fixed', TRUE),
    (400703003057, 400703003057, 'Regular', 'fixed', TRUE),
    (400703003058, 400703003058, 'Regular', 'fixed', TRUE),
    (400703003059, 400703003059, 'Regular', 'fixed', TRUE),
    (400703003060, 400703003060, 'Regular', 'fixed', TRUE),
    (400703003061, 400703003061, 'Regular', 'fixed', TRUE),
    (400703003062, 400703003062, 'Regular', 'fixed', TRUE),
    (400703003063, 400703003063, 'Regular', 'fixed', TRUE),
    (400703003064, 400703003064, 'Regular', 'fixed', TRUE),
    (400703003065, 400703003065, 'Regular', 'fixed', TRUE),
    (400703003066, 400703003066, 'Regular', 'fixed', TRUE),
    (400703003067, 400703003067, 'Regular', 'fixed', TRUE),
    (400703003068, 400703003068, 'Regular', 'fixed', TRUE),
    (400703003069, 400703003069, 'Regular', 'fixed', TRUE),
    (400703003070, 400703003070, 'Regular', 'fixed', TRUE);

-- Prices (only for variants where a price was actually captured)
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
VALUES
    (400703003001, 400703003001, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003002, 400703003002, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003003, 400703003003, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003004, 400703003004, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003005, 400703003005, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003006, 400703003006, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003007, 400703003007, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003008, 400703003008, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003009, 400703003009, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003010, 400703003010, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003011, 400703003011, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003012, 400703003012, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003013, 400703003013, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003014, 400703003014, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003015, 400703003015, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003016, 400703003016, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003017, 400703003017, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003018, 400703003018, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003019, 400703003019, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003020, 400703003020, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003021, 400703003021, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003022, 400703003022, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003023, 400703003023, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003024, 400703003024, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003025, 400703003025, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003026, 400703003026, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003027, 400703003027, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003028, 400703003028, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003029, 400703003029, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003030, 400703003030, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003031, 400703003031, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003032, 400703003032, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003033, 400703003033, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003034, 400703003034, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003035, 400703003035, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003036, 400703003036, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003037, 400703003037, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003038, 400703003038, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003039, 400703003039, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003040, 400703003040, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003041, 400703003041, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003042, 400703003042, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003043, 400703003043, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003044, 400703003044, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003045, 400703003045, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003046, 400703003046, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003047, 400703003047, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003048, 400703003048, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003049, 400703003049, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003050, 400703003050, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003051, 400703003051, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003052, 400703003052, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003053, 400703003053, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003054, 400703003054, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003055, 400703003055, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003056, 400703003056, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003057, 400703003057, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003058, 400703003058, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003059, 400703003059, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003060, 400703003060, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003061, 400703003061, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003062, 400703003062, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003063, 400703003063, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003064, 400703003064, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003065, 400703003065, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003066, 400703003066, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003067, 400703003067, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003068, 400703003068, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003069, 400703003069, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified'),
    (400703003070, 400703003070, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703003, 'unverified');

-- Price source (price-specific confidence, tracked separately from item confidence)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
VALUES
    (400703003001, 400703003, :extraction_batch_id, 0.95),
    (400703003002, 400703003, :extraction_batch_id, 0.95),
    (400703003003, 400703003, :extraction_batch_id, 0.95),
    (400703003004, 400703003, :extraction_batch_id, 0.95),
    (400703003005, 400703003, :extraction_batch_id, 0.95),
    (400703003006, 400703003, :extraction_batch_id, 0.95),
    (400703003007, 400703003, :extraction_batch_id, 0.95),
    (400703003008, 400703003, :extraction_batch_id, 0.95),
    (400703003009, 400703003, :extraction_batch_id, 0.95),
    (400703003010, 400703003, :extraction_batch_id, 0.95),
    (400703003011, 400703003, :extraction_batch_id, 0.95),
    (400703003012, 400703003, :extraction_batch_id, 0.95),
    (400703003013, 400703003, :extraction_batch_id, 0.95),
    (400703003014, 400703003, :extraction_batch_id, 0.95),
    (400703003015, 400703003, :extraction_batch_id, 0.95),
    (400703003016, 400703003, :extraction_batch_id, 0.95),
    (400703003017, 400703003, :extraction_batch_id, 0.95),
    (400703003018, 400703003, :extraction_batch_id, 0.95),
    (400703003019, 400703003, :extraction_batch_id, 0.95),
    (400703003020, 400703003, :extraction_batch_id, 0.95),
    (400703003021, 400703003, :extraction_batch_id, 0.95),
    (400703003022, 400703003, :extraction_batch_id, 0.95),
    (400703003023, 400703003, :extraction_batch_id, 0.95),
    (400703003024, 400703003, :extraction_batch_id, 0.95),
    (400703003025, 400703003, :extraction_batch_id, 0.95),
    (400703003026, 400703003, :extraction_batch_id, 0.95),
    (400703003027, 400703003, :extraction_batch_id, 0.95),
    (400703003028, 400703003, :extraction_batch_id, 0.95),
    (400703003029, 400703003, :extraction_batch_id, 0.95),
    (400703003030, 400703003, :extraction_batch_id, 0.95),
    (400703003031, 400703003, :extraction_batch_id, 0.95),
    (400703003032, 400703003, :extraction_batch_id, 0.95),
    (400703003033, 400703003, :extraction_batch_id, 0.95),
    (400703003034, 400703003, :extraction_batch_id, 0.95),
    (400703003035, 400703003, :extraction_batch_id, 0.95),
    (400703003036, 400703003, :extraction_batch_id, 0.95),
    (400703003037, 400703003, :extraction_batch_id, 0.95),
    (400703003038, 400703003, :extraction_batch_id, 0.95),
    (400703003039, 400703003, :extraction_batch_id, 0.95),
    (400703003040, 400703003, :extraction_batch_id, 0.95),
    (400703003041, 400703003, :extraction_batch_id, 0.95),
    (400703003042, 400703003, :extraction_batch_id, 0.95),
    (400703003043, 400703003, :extraction_batch_id, 0.95),
    (400703003044, 400703003, :extraction_batch_id, 0.95),
    (400703003045, 400703003, :extraction_batch_id, 0.95),
    (400703003046, 400703003, :extraction_batch_id, 0.95),
    (400703003047, 400703003, :extraction_batch_id, 0.95),
    (400703003048, 400703003, :extraction_batch_id, 0.95),
    (400703003049, 400703003, :extraction_batch_id, 0.95),
    (400703003050, 400703003, :extraction_batch_id, 0.95),
    (400703003051, 400703003, :extraction_batch_id, 0.95),
    (400703003052, 400703003, :extraction_batch_id, 0.95),
    (400703003053, 400703003, :extraction_batch_id, 0.95),
    (400703003054, 400703003, :extraction_batch_id, 0.95),
    (400703003055, 400703003, :extraction_batch_id, 0.95),
    (400703003056, 400703003, :extraction_batch_id, 0.95),
    (400703003057, 400703003, :extraction_batch_id, 0.95),
    (400703003058, 400703003, :extraction_batch_id, 0.95),
    (400703003059, 400703003, :extraction_batch_id, 0.95),
    (400703003060, 400703003, :extraction_batch_id, 0.95),
    (400703003061, 400703003, :extraction_batch_id, 0.95),
    (400703003062, 400703003, :extraction_batch_id, 0.95),
    (400703003063, 400703003, :extraction_batch_id, 0.95),
    (400703003064, 400703003, :extraction_batch_id, 0.95),
    (400703003065, 400703003, :extraction_batch_id, 0.95),
    (400703003066, 400703003, :extraction_batch_id, 0.95),
    (400703003067, 400703003, :extraction_batch_id, 0.95),
    (400703003068, 400703003, :extraction_batch_id, 0.95),
    (400703003069, 400703003, :extraction_batch_id, 0.95),
    (400703003070, 400703003, :extraction_batch_id, 0.95);

-- Board <-> item mapping
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
VALUES
    (400703003001, 400703003, 400703003001, 400703003001, 400703003001, 1),
    (400703003002, 400703003, 400703003001, 400703003002, 400703003001, 2),
    (400703003003, 400703003, 400703003001, 400703003003, 400703003001, 3),
    (400703003004, 400703003, 400703003001, 400703003004, 400703003001, 4),
    (400703003005, 400703003, 400703003001, 400703003005, 400703003001, 5),
    (400703003006, 400703003, 400703003001, 400703003006, 400703003001, 6),
    (400703003007, 400703003, 400703003001, 400703003007, 400703003001, 7),
    (400703003008, 400703003, 400703003001, 400703003008, 400703003001, 8),
    (400703003009, 400703003, 400703003001, 400703003009, 400703003001, 9),
    (400703003010, 400703003, 400703003001, 400703003010, 400703003002, 1),
    (400703003011, 400703003, 400703003001, 400703003011, 400703003002, 2),
    (400703003012, 400703003, 400703003001, 400703003012, 400703003002, 3),
    (400703003013, 400703003, 400703003001, 400703003013, 400703003002, 4),
    (400703003014, 400703003, 400703003001, 400703003014, 400703003002, 5),
    (400703003015, 400703003, 400703003001, 400703003015, 400703003002, 6),
    (400703003016, 400703003, 400703003001, 400703003016, 400703003002, 7),
    (400703003017, 400703003, 400703003001, 400703003017, 400703003002, 8),
    (400703003018, 400703003, 400703003001, 400703003018, 400703003002, 9),
    (400703003019, 400703003, 400703003001, 400703003019, 400703003002, 10),
    (400703003020, 400703003, 400703003001, 400703003020, 400703003002, 11),
    (400703003021, 400703003, 400703003001, 400703003021, 400703003002, 12),
    (400703003022, 400703003, 400703003001, 400703003022, 400703003002, 13),
    (400703003023, 400703003, 400703003001, 400703003023, 400703003002, 14),
    (400703003024, 400703003, 400703003001, 400703003024, 400703003002, 15),
    (400703003025, 400703003, 400703003001, 400703003025, 400703003002, 16),
    (400703003026, 400703003, 400703003001, 400703003026, 400703003002, 17),
    (400703003027, 400703003, 400703003001, 400703003027, 400703003002, 18),
    (400703003028, 400703003, 400703003001, 400703003028, 400703003002, 19),
    (400703003029, 400703003, 400703003001, 400703003029, 400703003003, 1),
    (400703003030, 400703003, 400703003001, 400703003030, 400703003003, 2),
    (400703003031, 400703003, 400703003001, 400703003031, 400703003003, 3),
    (400703003032, 400703003, 400703003001, 400703003032, 400703003003, 4),
    (400703003033, 400703003, 400703003001, 400703003033, 400703003003, 5),
    (400703003034, 400703003, 400703003001, 400703003034, 400703003003, 6),
    (400703003035, 400703003, 400703003001, 400703003035, 400703003003, 7),
    (400703003036, 400703003, 400703003001, 400703003036, 400703003003, 8),
    (400703003037, 400703003, 400703003001, 400703003037, 400703003003, 9),
    (400703003038, 400703003, 400703003001, 400703003038, 400703003003, 10),
    (400703003039, 400703003, 400703003001, 400703003039, 400703003003, 11),
    (400703003040, 400703003, 400703003001, 400703003040, 400703003003, 12),
    (400703003041, 400703003, 400703003001, 400703003041, 400703003003, 13),
    (400703003042, 400703003, 400703003001, 400703003042, 400703003003, 14),
    (400703003043, 400703003, 400703003001, 400703003043, 400703003003, 15),
    (400703003044, 400703003, 400703003001, 400703003044, 400703003004, 1),
    (400703003045, 400703003, 400703003001, 400703003045, 400703003004, 2),
    (400703003046, 400703003, 400703003001, 400703003046, 400703003004, 3),
    (400703003047, 400703003, 400703003001, 400703003047, 400703003004, 4),
    (400703003048, 400703003, 400703003001, 400703003048, 400703003004, 5),
    (400703003049, 400703003, 400703003001, 400703003049, 400703003004, 6),
    (400703003050, 400703003, 400703003001, 400703003050, 400703003004, 7),
    (400703003051, 400703003, 400703003001, 400703003051, 400703003005, 1),
    (400703003052, 400703003, 400703003001, 400703003052, 400703003005, 2),
    (400703003053, 400703003, 400703003001, 400703003053, 400703003005, 3),
    (400703003054, 400703003, 400703003001, 400703003054, 400703003005, 4),
    (400703003055, 400703003, 400703003001, 400703003055, 400703003005, 5),
    (400703003056, 400703003, 400703003001, 400703003056, 400703003005, 6),
    (400703003057, 400703003, 400703003001, 400703003057, 400703003005, 7),
    (400703003058, 400703003, 400703003001, 400703003058, 400703003005, 8),
    (400703003059, 400703003, 400703003001, 400703003059, 400703003005, 9),
    (400703003060, 400703003, 400703003001, 400703003060, 400703003005, 10),
    (400703003061, 400703003, 400703003001, 400703003061, 400703003005, 11),
    (400703003062, 400703003, 400703003001, 400703003062, 400703003005, 12),
    (400703003063, 400703003, 400703003001, 400703003063, 400703003005, 13),
    (400703003064, 400703003, 400703003001, 400703003064, 400703003005, 14),
    (400703003065, 400703003, 400703003001, 400703003065, 400703003005, 15),
    (400703003066, 400703003, 400703003001, 400703003066, 400703003005, 16),
    (400703003067, 400703003, 400703003001, 400703003067, 400703003005, 17),
    (400703003068, 400703003, 400703003001, 400703003068, 400703003005, 18),
    (400703003069, 400703003, 400703003001, 400703003069, 400703003005, 19),
    (400703003070, 400703003, 400703003001, 400703003070, 400703003005, 20);

-- === NEEDS-REVIEW ITEMS ===
-- none

-- === PER-ITEM NOTES ===
-- menu_item_id 400703003027 (Schzewan Mysore Sada Dosa (Extra Cheese 30/-)): Parenthetical add-on price (Extra Cheese 30/-) kept as literal name text; could be modeled via addon_group/addon_option if wanted -- not created here.
-- menu_item_id 400703003028 (Chutney Powder Dosa (Extra Cheese 30/-)): Parenthetical add-on price (Extra Cheese 30/-) kept as literal name text; could be modeled via addon_group/addon_option if wanted -- not created here.

-- === UNMAPPED RESTAURANT-LEVEL NOTES ===
-- price_range "1-200" from JSON: no matching restaurant-level column; not inserted anywhere.
-- other_text: "II Shree Mahadeshwarai Namah II" -- devotional signage text, no schema column.
-- other_text: "Varity Dosa" / "99 Variety" -- marketing tagline, no schema column.
-- other_text: "We Also Except Party" -- catering/party-order availability note (likely means "accept"); no restaurant-level column for a free-text capability note like this.
-- Category names "MASALA VARYERY" and "UTTAPA VARYETY" are preserved verbatim from the source JSON, including its spelling, per Step 1 (do not silently correct source text).

COMMIT;