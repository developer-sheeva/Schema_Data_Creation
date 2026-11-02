-- Khaustan menu onboarding: New Lucky Restaurant
-- Source JSON: new_lucky_restaurant_menu_ocr.json
-- Source image(s): 1000468417.jpg, 1000468416.jpg
-- establishment_id / restaurant_id / source_id namespace: 400070019 (taken directly from the source JSON)
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
    400070019, 'New Lucky Restaurant', 'new lucky restaurant',
    'Sonapur Corner', NULL, 'Kurla', 'Mumbai',
    'Maharashtra', 'IN', '400070', 19.081321995568146, 72.88140459152658
);

INSERT INTO restaurant (
    restaurant_id, establishment_id, display_name, normalized_name,
    veg_nonveg_status, has_bar, bar_license_type
) VALUES (
    400070019, 400070019, 'New Lucky Restaurant', 'new lucky restaurant',
    'veg_and_nonveg', FALSE, 'none'
);

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400070019, 'ai_menu_extraction', 'new_lucky_restaurant_menu_ocr.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, status_code)
VALUES (nextval('khaustan_standalone_id_seq'), 400070019, 400070019, (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');
SELECT extraction_batch_id FROM menu_extraction_batch WHERE source_id = 400070019 ORDER BY extraction_batch_id DESC LIMIT 1 \gset

-- Phones
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES
    (nextval('khaustan_standalone_id_seq'), 400070019, '9220308967', TRUE),
    (nextval('khaustan_standalone_id_seq'), 400070019, '9220308968', FALSE),
    (nextval('khaustan_standalone_id_seq'), 400070019, '9892974661', FALSE),
    (nextval('khaustan_standalone_id_seq'), 400070019, '9920297018', FALSE);

-- Hours: single stated window applied to every day (JSON gives one blanket timing,
-- no per-day breakdown) -- confidence: inferred blanket application, not per-day-confirmed.
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
VALUES
    (nextval('khaustan_standalone_id_seq'), 400070019, 1, 1, '05:00'::time, '23:59'::time),
    (nextval('khaustan_standalone_id_seq'), 400070019, 2, 1, '05:00'::time, '23:59'::time),
    (nextval('khaustan_standalone_id_seq'), 400070019, 3, 1, '05:00'::time, '23:59'::time),
    (nextval('khaustan_standalone_id_seq'), 400070019, 4, 1, '05:00'::time, '23:59'::time),
    (nextval('khaustan_standalone_id_seq'), 400070019, 5, 1, '05:00'::time, '23:59'::time),
    (nextval('khaustan_standalone_id_seq'), 400070019, 6, 1, '05:00'::time, '23:59'::time),
    (nextval('khaustan_standalone_id_seq'), 400070019, 7, 1, '05:00'::time, '23:59'::time);

-- HALAL restaurant tag: safe lookup-only insert. If 'halal' isn't yet a platform_tag
-- tag_code, this JOIN matches zero rows and inserts nothing -- no error, no new lookup
-- row created (lookup tables are read-only for this script).
INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id)
SELECT nextval('khaustan_standalone_id_seq'), 400070019, tag_id FROM platform_tag WHERE tag_code = 'halal';

-- Menu board: one a_la_carte board for the whole JSON source.
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, is_active, display_sequence)
VALUES (400070019001, 400070019, 'Main Menu', 'a_la_carte', TRUE, 1);

-- Categories, in JSON/source order. Where the source nests a subcategory (e.g.
-- STARTERS -> INDIAN / CHINESE), the top-level name becomes a parent row and the
-- subcategory becomes its child via parent_category_id -- the leaf (child) is what
-- items attach to. A category name repeated across two distinct source sections (this
-- happens at least once in this batch) is kept as two separate rows, not merged --
-- these are keyed by source position, not by display name.
INSERT INTO menu_category (menu_category_id, restaurant_id, name, parent_category_id, display_sequence)
VALUES
    (400070019001, 400070019, 'BREAKFAST', NULL, 1),
    (400070019002, 400070019, 'LUCKY SPECIAL', NULL, 2),
    (400070019003, 400070019, 'INDIAN STARTERS', NULL, 3),
    (400070019004, 400070019, 'LUCKY CHICKEN PAKODA', NULL, 4),
    (400070019005, 400070019, 'CHICKEN GRAVY', NULL, 5),
    (400070019006, 400070019, 'SEA FOOD', NULL, 6),
    (400070019007, 400070019, 'BRAIN & EGG', NULL, 7),
    (400070019008, 400070019, 'MUTTON GRAVY', NULL, 8),
    (400070019009, 400070019, 'VEG. GRAVY', NULL, 9),
    (400070019010, 400070019, 'ROTI / NAAN / PARATHA', NULL, 10),
    (400070019011, 400070019, 'LUCKY DAL SPECIAL', NULL, 11),
    (400070019012, 400070019, 'BIRYANI / PULAV / RICE', NULL, 12),
    (400070019013, 400070019, 'CHINESE SOUPS', NULL, 13),
    (400070019014, 400070019, 'CHINESE DRY', NULL, 14),
    (400070019015, 400070019, 'CHINESE PRAWNS', NULL, 15),
    (400070019016, 400070019, 'CHINESE VEG. STARTERS', NULL, 16),
    (400070019017, 400070019, 'CHOWMEIN / CHOUPSEY', NULL, 17),
    (400070019018, 400070019, 'CHINESE FRIED RICE', NULL, 18),
    (400070019019, 400070019, 'FRIED RICE WITH GRAVY RICE', NULL, 19),
    (400070019020, 400070019, 'NOODLES DISHES', NULL, 20),
    (400070019021, 400070019, 'HOT / COLD BEVERAGES', NULL, 21),
    (400070019022, 400070019, 'NEW LUCKY FAMILY PACK', NULL, 22),
    (400070019023, 400070019, 'SALADS & RAITA', NULL, 23);

-- Board <-> category mapping (leaf categories only)
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (400070019, 400070019001, 400070019001, 1),
    (400070019, 400070019001, 400070019002, 2),
    (400070019, 400070019001, 400070019003, 3),
    (400070019, 400070019001, 400070019004, 4),
    (400070019, 400070019001, 400070019005, 5),
    (400070019, 400070019001, 400070019006, 6),
    (400070019, 400070019001, 400070019007, 7),
    (400070019, 400070019001, 400070019008, 8),
    (400070019, 400070019001, 400070019009, 9),
    (400070019, 400070019001, 400070019010, 10),
    (400070019, 400070019001, 400070019011, 11),
    (400070019, 400070019001, 400070019012, 12),
    (400070019, 400070019001, 400070019013, 13),
    (400070019, 400070019001, 400070019014, 14),
    (400070019, 400070019001, 400070019015, 15),
    (400070019, 400070019001, 400070019016, 16),
    (400070019, 400070019001, 400070019017, 17),
    (400070019, 400070019001, 400070019018, 18),
    (400070019, 400070019001, 400070019019, 19),
    (400070019, 400070019001, 400070019020, 20),
    (400070019, 400070019001, 400070019021, 21),
    (400070019, 400070019001, 400070019022, 22),
    (400070019, 400070019001, 400070019023, 23);

-- Canonical dish identify-or-create: no unique constraint on canonical_dish.normalized_name,
-- so NOT EXISTS, not ON CONFLICT. Whether these already exist from an earlier onboarded
-- restaurant is resolved live by this check when the script runs.
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'OMELET DOUBLE', 'omelet double'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'omelet double')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'OMELET DOUBLE', 'omelet double', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'HALF FRY DOUBLE', 'half fry double'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'half fry double')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'HALF FRY DOUBLE', 'half fry double', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BHURJI', 'bhurji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bhurji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BHURJI', 'bhurji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KHEEMA', 'kheema'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kheema')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KHEEMA', 'kheema', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KHEEMA FRY', 'kheema fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kheema fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KHEEMA FRY', 'kheema fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KHEEMA GHOTALA', 'kheema ghotala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kheema ghotala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KHEEMA GHOTALA', 'kheema ghotala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN SCHEZWAN KEPSA', 'chicken schezwan kepsa'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan kepsa')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN SCHEZWAN KEPSA', 'chicken schezwan kepsa', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN PEPPER GRAVY', 'chicken pepper gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pepper gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN PEPPER GRAVY', 'chicken pepper gravy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN KASHMIRI MASALA', 'chicken kashmiri masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kashmiri masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN KASHMIRI MASALA', 'chicken kashmiri masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN TANDOORI (H/F)', 'chicken tandoori (h/f)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori (h/f)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN TANDOORI (H/F)', 'chicken tandoori (h/f)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI.MALAI TANDOORI (H/F)', 'chi.malai tandoori (h/f)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi.malai tandoori (h/f)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI.MALAI TANDOORI (H/F)', 'chi.malai tandoori (h/f)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN AFGHANI TANDOORI', 'chicken afghani tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken afghani tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN AFGHANI TANDOORI', 'chicken afghani tandoori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN TIKKA TANDOORI', 'chicken tikka tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN TIKKA TANDOORI', 'chicken tikka tandoori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. SCHEZWAN TANDOORI', 'chi. schezwan tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. schezwan tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. SCHEZWAN TANDOORI', 'chi. schezwan tandoori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN BUTTER TANDOORI', 'chicken butter tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken butter tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN BUTTER TANDOORI', 'chicken butter tandoori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN TANDOORI LEG', 'chicken tandoori leg'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori leg')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN TANDOORI LEG', 'chicken tandoori leg', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'LEMON TANDOORI CHICKEN', 'lemon tandoori chicken'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon tandoori chicken')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'LEMON TANDOORI CHICKEN', 'lemon tandoori chicken', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SEEKH KEBAB', 'seekh kebab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'seekh kebab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SEEKH KEBAB', 'seekh kebab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'RESHMI KEBAB', 'reshmi kebab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'reshmi kebab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'RESHMI KEBAB', 'reshmi kebab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PAHADI KEBAB', 'pahadi kebab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pahadi kebab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PAHADI KEBAB', 'pahadi kebab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ACHARI KEBAB', 'achari kebab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'achari kebab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ACHARI KEBAB', 'achari kebab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'HAZAARI KEBAB', 'hazaari kebab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hazaari kebab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'HAZAARI KEBAB', 'hazaari kebab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BANJARA KEBAB', 'banjara kebab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'banjara kebab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BANJARA KEBAB', 'banjara kebab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KERALA KEBAB', 'kerala kebab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kerala kebab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KERALA KEBAB', 'kerala kebab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'TANGDI KEBAB', 'tangdi kebab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tangdi kebab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'TANGDI KEBAB', 'tangdi kebab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MALAI KEBAB', 'malai kebab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malai kebab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MALAI KEBAB', 'malai kebab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHESLI KEBAB', 'chesli kebab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chesli kebab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHESLI KEBAB', 'chesli kebab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER TIKKA DRY (5 PCS.)', 'paneer tikka dry (5 pcs.)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka dry (5 pcs.)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER TIKKA DRY (5 PCS.)', 'paneer tikka dry (5 pcs.)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN TIKKA (5 PCS.)', 'chicken tikka (5 pcs.)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka (5 pcs.)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN TIKKA (5 PCS.)', 'chicken tikka (5 pcs.)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN PAKODA (1KG)', 'chicken pakoda (1kg)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pakoda (1kg)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN PAKODA (1KG)', 'chicken pakoda (1kg)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN PAKODA (1/2 KG)', 'chicken pakoda (1/2 kg)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pakoda (1/2 kg)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN PAKODA (1/2 KG)', 'chicken pakoda (1/2 kg)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN PAKODA (1/4 KG)', 'chicken pakoda (1/4 kg)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pakoda (1/4 kg)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN PAKODA (1/4 KG)', 'chicken pakoda (1/4 kg)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN SCHEZWAN PAKODA', 'chicken schezwan pakoda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan pakoda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN SCHEZWAN PAKODA', 'chicken schezwan pakoda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN MASALA FRY', 'chicken masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN MASALA FRY', 'chicken masala fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN MALABARI', 'chicken malabari'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken malabari')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN MALABARI', 'chicken malabari', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN AFGHANI (BONELESS)', 'chicken afghani (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken afghani (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN AFGHANI (BONELESS)', 'chicken afghani (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN ANGARA (BONELESS)', 'chicken angara (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken angara (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN ANGARA (BONELESS)', 'chicken angara (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN BARRA', 'chicken barra'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken barra')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN BARRA', 'chicken barra', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN LAZEEZ', 'chicken lazeez'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lazeez')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN LAZEEZ', 'chicken lazeez', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN WHITE', 'chicken white'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken white')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN WHITE', 'chicken white', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN BALTI (BONELESS)', 'chicken balti (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken balti (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN BALTI (BONELESS)', 'chicken balti (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN GREEN MASALA', 'chicken green masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken green masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN GREEN MASALA', 'chicken green masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. DABBA GOSHT (BONELESS)', 'chi. dabba gosht (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. dabba gosht (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. DABBA GOSHT (BONELESS)', 'chi. dabba gosht (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN SUKHA', 'chicken sukha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken sukha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN SUKHA', 'chicken sukha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN HANDI', 'chicken handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN HANDI', 'chicken handi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN KADAI', 'chicken kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN KADAI', 'chicken kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN KORMA', 'chicken korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN KORMA', 'chicken korma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN MURG MUSSALLAM', 'chicken murg mussallam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken murg mussallam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN MURG MUSSALLAM', 'chicken murg mussallam', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN MALWANI', 'chicken malwani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken malwani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN MALWANI', 'chicken malwani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN MOGHLAI', 'chicken moghlai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken moghlai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN MOGHLAI', 'chicken moghlai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN RASHIDA', 'chicken rashida'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken rashida')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN RASHIDA', 'chicken rashida', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN LUCKY SPECIAL', 'chicken lucky special'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lucky special')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN LUCKY SPECIAL', 'chicken lucky special', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN TIKKA HANDI', 'chicken tikka handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN TIKKA HANDI', 'chicken tikka handi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN PALAK', 'chicken palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN PALAK', 'chicken palak', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BUTTER CHICKEN (BONELESS)', 'butter chicken (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter chicken (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BUTTER CHICKEN (BONELESS)', 'butter chicken (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN TANDOORI MASALA', 'chicken tandoori masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN TANDOORI MASALA', 'chicken tandoori masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN KOLHAPURI', 'chicken kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN KOLHAPURI', 'chicken kolhapuri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN TIKKA MASALA', 'chicken tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN TIKKA MASALA', 'chicken tikka masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN FAMILY HANDI', 'chicken family handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken family handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN FAMILY HANDI', 'chicken family handi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'FISH FRY', 'fish fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'FISH FRY', 'fish fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'FISH CURRY', 'fish curry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish curry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'FISH CURRY', 'fish curry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'FISH TANDOORI', 'fish tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'FISH TANDOORI', 'fish tandoori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'FISH MASALA FRY', 'fish masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'FISH MASALA FRY', 'fish masala fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS KADAI', 'prawns kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS KADAI', 'prawns kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS MASALA', 'prawns masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS MASALA', 'prawns masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS MASALA FRY', 'prawns masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS MASALA FRY', 'prawns masala fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS HANDI', 'prawns handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS HANDI', 'prawns handi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EGG MASALA', 'egg masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EGG MASALA', 'egg masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EGG MASALA FRY', 'egg masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EGG MASALA FRY', 'egg masala fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EGG TOD FOD', 'egg tod fod'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg tod fod')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EGG TOD FOD', 'egg tod fod', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON MASALA', 'mutton masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON MASALA', 'mutton masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON MASALA FRY', 'mutton masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON MASALA FRY', 'mutton masala fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON ANGARA', 'mutton angara'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton angara')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON ANGARA', 'mutton angara', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON HANDI', 'mutton handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON HANDI', 'mutton handi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON KADAI', 'mutton kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON KADAI', 'mutton kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUT. DABBA GOSHT (BONELESS)', 'mut. dabba gosht (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mut. dabba gosht (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUT. DABBA GOSHT (BONELESS)', 'mut. dabba gosht (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON SUKHA', 'mutton sukha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton sukha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON SUKHA', 'mutton sukha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON MALABARI', 'mutton malabari'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton malabari')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON MALABARI', 'mutton malabari', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON AFGHANI', 'mutton afghani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton afghani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON AFGHANI', 'mutton afghani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON KORMA', 'mutton korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON KORMA', 'mutton korma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON RASHIDA', 'mutton rashida'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton rashida')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON RASHIDA', 'mutton rashida', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON PALAK', 'mutton palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON PALAK', 'mutton palak', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON TOMATO FRY (BONELESS)', 'mutton tomato fry (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton tomato fry (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON TOMATO FRY (BONELESS)', 'mutton tomato fry (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON DOPYAZA', 'mutton dopyaza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton dopyaza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON DOPYAZA', 'mutton dopyaza', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON KOLHAPURI', 'mutton kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON KOLHAPURI', 'mutton kolhapuri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON MAKHANWALA', 'mutton makhanwala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton makhanwala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON MAKHANWALA', 'mutton makhanwala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON DAL GOSHT', 'mutton dal gosht'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton dal gosht')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON DAL GOSHT', 'mutton dal gosht', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA MASALA FRY', 'extra masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA MASALA FRY', 'extra masala fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. HANDI', 'veg. handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. HANDI', 'veg. handi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. KORMA', 'veg. korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. KORMA', 'veg. korma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. KADAI', 'veg. kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. KADAI', 'veg. kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. AFGHANI', 'veg. afghani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. afghani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. AFGHANI', 'veg. afghani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. KOLHAPURI', 'veg. kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. KOLHAPURI', 'veg. kolhapuri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. MAKHANWALA', 'veg. makhanwala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. makhanwala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. MAKHANWALA', 'veg. makhanwala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MIX VEG. FRY', 'mix veg. fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix veg. fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MIX VEG. FRY', 'mix veg. fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHANA MASALA', 'chana masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chana masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHANA MASALA', 'chana masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHANA MASALA FRY', 'chana masala fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chana masala fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHANA MASALA FRY', 'chana masala fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ALU MUTTER / ALU PALAK', 'alu mutter / alu palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'alu mutter / alu palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ALU MUTTER / ALU PALAK', 'alu mutter / alu palak', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ALU MUTTER / ALU PALAK FRY', 'alu mutter / alu palak fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'alu mutter / alu palak fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ALU MUTTER / ALU PALAK FRY', 'alu mutter / alu palak fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER TIKKA MASALA', 'paneer tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER TIKKA MASALA', 'paneer tikka masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER BUTTER MASALA', 'paneer butter masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer butter masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER BUTTER MASALA', 'paneer butter masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER TAWA MASALA', 'paneer tawa masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tawa masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER TAWA MASALA', 'paneer tawa masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER KORMA', 'paneer korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER KORMA', 'paneer korma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER BHURJI', 'paneer bhurji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer bhurji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER BHURJI', 'paneer bhurji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER PALAK', 'paneer palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER PALAK', 'paneer palak', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER MUTTER', 'paneer mutter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer mutter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER MUTTER', 'paneer mutter', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER HANDI', 'paneer handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER HANDI', 'paneer handi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER KADAI', 'paneer kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER KADAI', 'paneer kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'TANDOORI ROTI', 'tandoori roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'TANDOORI ROTI', 'tandoori roti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'TANDOORI BUTTER ROTI', 'tandoori butter roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori butter roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'TANDOORI BUTTER ROTI', 'tandoori butter roti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'TANDOORI NAAN', 'tandoori naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'TANDOORI NAAN', 'tandoori naan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'TANDOORI BUTTER NAAN', 'tandoori butter naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori butter naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'TANDOORI BUTTER NAAN', 'tandoori butter naan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'TANDOORI BUTTER PARATHA', 'tandoori butter paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori butter paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'TANDOORI BUTTER PARATHA', 'tandoori butter paratha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GARLIC NAAN', 'garlic naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GARLIC NAAN', 'garlic naan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GARLIC BUTTER NAAN', 'garlic butter naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic butter naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GARLIC BUTTER NAAN', 'garlic butter naan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BUTTER NAAN KULCH', 'butter naan kulch'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter naan kulch')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BUTTER NAAN KULCH', 'butter naan kulch', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHAPATI', 'chapati'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chapati')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHAPATI', 'chapati', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SPL. CHAPATI', 'spl. chapati'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spl. chapati')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SPL. CHAPATI', 'spl. chapati', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'LUCKY SPECIAL DAL TADKA', 'lucky special dal tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lucky special dal tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'LUCKY SPECIAL DAL TADKA', 'lucky special dal tadka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'DAL TADKA', 'dal tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'DAL TADKA', 'dal tadka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'DAL FRY', 'dal fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'DAL FRY', 'dal fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'LUCKY MAKHANWALA', 'lucky makhanwala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lucky makhanwala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'LUCKY MAKHANWALA', 'lucky makhanwala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'DAL PALAK', 'dal palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'DAL PALAK', 'dal palak', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN BIRYANI', 'chicken biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN BIRYANI', 'chicken biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN TANDOORI BIRYANI', 'chicken tandoori biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN TANDOORI BIRYANI', 'chicken tandoori biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON BIRYANI', 'mutton biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON BIRYANI', 'mutton biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON KEPSA RICE', 'mutton kepsa rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kepsa rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON KEPSA RICE', 'mutton kepsa rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN KEPSA RICE', 'chicken kepsa rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kepsa rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN KEPSA RICE', 'chicken kepsa rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. TIKKA BIRYANI (BONELESS)', 'chi. tikka biryani (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. tikka biryani (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. TIKKA BIRYANI (BONELESS)', 'chi. tikka biryani (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN HYDRABADI BIRYANI', 'chicken hydrabadi biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hydrabadi biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN HYDRABADI BIRYANI', 'chicken hydrabadi biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS BIRYANI', 'prawns biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS BIRYANI', 'prawns biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EGG BIRYANI', 'egg biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EGG BIRYANI', 'egg biryani', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER BIRYANI', 'paneer biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER BIRYANI', 'paneer biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN LUCKY SPECIAL PULAV', 'chicken lucky special pulav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lucky special pulav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN LUCKY SPECIAL PULAV', 'chicken lucky special pulav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN PULAV', 'chicken pulav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pulav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN PULAV', 'chicken pulav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MUTTON PULAV', 'mutton pulav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton pulav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MUTTON PULAV', 'mutton pulav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS PULAV', 'prawns pulav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns pulav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS PULAV', 'prawns pulav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EGG PULAV', 'egg pulav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg pulav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EGG PULAV', 'egg pulav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. PULAV', 'veg. pulav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. pulav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. PULAV', 'veg. pulav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER PULAV', 'paneer pulav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pulav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER PULAV', 'paneer pulav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'DAL KHICHDI', 'dal khichdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal khichdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'DAL KHICHDI', 'dal khichdi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'WHITE RICE', 'white rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'white rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'WHITE RICE', 'white rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BIRYANI RICE', 'biryani rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'biryani rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BIRYANI RICE', 'biryani rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JEERA RICE', 'jeera rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jeera rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JEERA RICE', 'jeera rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'LUCKY SPECIAL SOUP', 'lucky special soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lucky special soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'LUCKY SPECIAL SOUP', 'lucky special soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN HOT & SOUR SOUP', 'chicken hot & sour soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hot & sour soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN HOT & SOUR SOUP', 'chicken hot & sour soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN CLEAR SOUP', 'chicken clear soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken clear soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN CLEAR SOUP', 'chicken clear soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN MANCHOW SOUP', 'chicken manchow soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchow soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN MANCHOW SOUP', 'chicken manchow soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN NOODLES SOUP', 'chicken noodles soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken noodles soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN NOODLES SOUP', 'chicken noodles soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG HOT & SOUR', 'veg hot & sour'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg hot & sour')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG HOT & SOUR', 'veg hot & sour', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG MANCHOW SOUP', 'veg manchow soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg manchow soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG MANCHOW SOUP', 'veg manchow soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'TOMATO SOUP', 'tomato soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tomato soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'TOMATO SOUP', 'tomato soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG CLEAR SOUP', 'veg clear soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg clear soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG CLEAR SOUP', 'veg clear soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN CHILLY DRY', 'chicken chilly dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN CHILLY DRY', 'chicken chilly dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN CHILLY GRAVY', 'chicken chilly gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN CHILLY GRAVY', 'chicken chilly gravy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN MANCHURIAN DRY', 'chicken manchurian dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchurian dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN MANCHURIAN DRY', 'chicken manchurian dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN MANCHURIAN GRAVY', 'chicken manchurian gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchurian gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN MANCHURIAN GRAVY', 'chicken manchurian gravy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN SCHEZWAN CHILLY', 'chicken schezwan chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN SCHEZWAN CHILLY', 'chicken schezwan chilly', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN GARLIC', 'chicken garlic'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken garlic')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN GARLIC', 'chicken garlic', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN HOT GARLIC DRY', 'chicken hot garlic dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hot garlic dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN HOT GARLIC DRY', 'chicken hot garlic dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN GINGER', 'chicken ginger'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken ginger')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN GINGER', 'chicken ginger', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN HONG KONG', 'chicken hong kong'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hong kong')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN HONG KONG', 'chicken hong kong', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN 65', 'chicken 65'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken 65')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN 65', 'chicken 65', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN CRISPY', 'chicken crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN CRISPY', 'chicken crispy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN SALT & PEPPER', 'chicken salt & pepper'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken salt & pepper')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN SALT & PEPPER', 'chicken salt & pepper', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. LOLLY POP GRAVY (6 PCS)', 'chi. lolly pop gravy (6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. lolly pop gravy (6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. LOLLY POP GRAVY (6 PCS)', 'chi. lolly pop gravy (6 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. LOLLY POP GRAVY (3 PCS)', 'chi. lolly pop gravy (3 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. lolly pop gravy (3 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. LOLLY POP GRAVY (3 PCS)', 'chi. lolly pop gravy (3 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. LOLLY POP OIL FRY (6 PCS)', 'chi. lolly pop oil fry (6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. lolly pop oil fry (6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. LOLLY POP OIL FRY (6 PCS)', 'chi. lolly pop oil fry (6 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. LOLLY POP OIL FRY (3 PCS)', 'chi. lolly pop oil fry (3 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. lolly pop oil fry (3 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. LOLLY POP OIL FRY (3 PCS)', 'chi. lolly pop oil fry (3 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS CRISPY', 'prawns crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS CRISPY', 'prawns crispy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS CHILLY', 'prawns chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS CHILLY', 'prawns chilly', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS GARLIC DRY', 'prawns garlic dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns garlic dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS GARLIC DRY', 'prawns garlic dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS GINGER DRY', 'prawns ginger dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns ginger dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS GINGER DRY', 'prawns ginger dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS MANCHURAIN', 'prawns manchurain'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns manchurain')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS MANCHURAIN', 'prawns manchurain', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS SCHEZWAN CHILLY', 'prawns schezwan chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns schezwan chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS SCHEZWAN CHILLY', 'prawns schezwan chilly', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER PAKODA', 'paneer pakoda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pakoda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER PAKODA', 'paneer pakoda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER CHILLY DRY', 'paneer chilly dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chilly dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER CHILLY DRY', 'paneer chilly dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER CRISPY', 'paneer crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER CRISPY', 'paneer crispy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. CRISPY', 'veg. crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. CRISPY', 'veg. crispy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER CHILLY GRAVY', 'paneer chilly gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chilly gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER CHILLY GRAVY', 'paneer chilly gravy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. MANCHURIAN DRY', 'veg. manchurian dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchurian dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. MANCHURIAN DRY', 'veg. manchurian dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. MANCHURIAN GRAVY', 'veg. manchurian gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchurian gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. MANCHURIAN GRAVY', 'veg. manchurian gravy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN CHOWMEIN', 'chicken chowmein'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chowmein')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN CHOWMEIN', 'chicken chowmein', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN AMERICAN CHOUPSEY', 'chicken american choupsey'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken american choupsey')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN AMERICAN CHOUPSEY', 'chicken american choupsey', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN CHINESE CHOUPSEY', 'chicken chinese choupsey'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chinese choupsey')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN CHINESE CHOUPSEY', 'chicken chinese choupsey', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MIX CHOWMEIN', 'mix chowmein'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix chowmein')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MIX CHOWMEIN', 'mix chowmein', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS CHOWMEIN', 'prawns chowmein'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns chowmein')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS CHOWMEIN', 'prawns chowmein', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. AMERICAN CHOUPSEY', 'veg. american choupsey'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. american choupsey')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. AMERICAN CHOUPSEY', 'veg. american choupsey', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. CHINESE CHOUPSEY', 'veg. chinese choupsey'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. chinese choupsey')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. CHINESE CHOUPSEY', 'veg. chinese choupsey', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. CHOWMEIN', 'veg. chowmein'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. chowmein')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. CHOWMEIN', 'veg. chowmein', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN PAKODA RICE', 'chicken pakoda rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pakoda rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN PAKODA RICE', 'chicken pakoda rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. SCHEZWAN PAKODA RICE', 'chi. schezwan pakoda rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. schezwan pakoda rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. SCHEZWAN PAKODA RICE', 'chi. schezwan pakoda rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN FRIED RICE', 'chicken fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN FRIED RICE', 'chicken fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN MIX FRIED RICE', 'chicken mix fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken mix fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN MIX FRIED RICE', 'chicken mix fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. SCHEZWAN FRIED RICE', 'chi. schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. SCHEZWAN FRIED RICE', 'chi. schezwan fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. HONG KONG FRIED RICE', 'chi. hong kong fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. hong kong fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. HONG KONG FRIED RICE', 'chi. hong kong fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. SINGAPORE FRIED RICE', 'chi. singapore fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. singapore fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. SINGAPORE FRIED RICE', 'chi. singapore fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN BURNT CHILLY RICE', 'chicken burnt chilly rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken burnt chilly rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN BURNT CHILLY RICE', 'chicken burnt chilly rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS FRIED RICE', 'prawns fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS FRIED RICE', 'prawns fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS SCHEZWAN FRIED RICE', 'prawns schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS SCHEZWAN FRIED RICE', 'prawns schezwan fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EGG FRIED RICE', 'egg fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EGG FRIED RICE', 'egg fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EGG SCHEZWAN FRIED RICE', 'egg schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EGG SCHEZWAN FRIED RICE', 'egg schezwan fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. FRIED RICE', 'veg. fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. FRIED RICE', 'veg. fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. SCHEZWAN FRIED RICE', 'veg. schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. SCHEZWAN FRIED RICE', 'veg. schezwan fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. HONG KONG FRIED RICE', 'veg. hong kong fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. hong kong fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. HONG KONG FRIED RICE', 'veg. hong kong fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. SINGAPORE FRIED RICE', 'veg. singapore fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. singapore fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. SINGAPORE FRIED RICE', 'veg. singapore fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN COMBINATION RICE', 'chicken combination rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken combination rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN COMBINATION RICE', 'chicken combination rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'LUCKY SPECIAL FIRED RICE', 'lucky special fired rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lucky special fired rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'LUCKY SPECIAL FIRED RICE', 'lucky special fired rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN TRIPLE PAKODA RICE', 'chicken triple pakoda rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken triple pakoda rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN TRIPLE PAKODA RICE', 'chicken triple pakoda rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN MALAYSIAN RICE', 'chicken malaysian rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken malaysian rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN MALAYSIAN RICE', 'chicken malaysian rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN GOLDEN RICE', 'chicken golden rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken golden rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN GOLDEN RICE', 'chicken golden rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN TRIPLE FRIED RICE', 'chicken triple fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken triple fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN TRIPLE FRIED RICE', 'chicken triple fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN CHILLY RICE', 'chicken chilly rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN CHILLY RICE', 'chicken chilly rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN MANCHURIAN RICE', 'chicken manchurian rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchurian rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN MANCHURIAN RICE', 'chicken manchurian rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN GARLIC RICE', 'chicken garlic rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken garlic rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN GARLIC RICE', 'chicken garlic rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN GINGER RICE', 'chicken ginger rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken ginger rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN GINGER RICE', 'chicken ginger rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. TRIPLE FRIED RICE', 'veg. triple fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. triple fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. TRIPLE FRIED RICE', 'veg. triple fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. MANCHURIAN', 'veg. manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. MANCHURIAN', 'veg. manchurian', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MIX. TRIPLE RICE', 'mix. triple rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix. triple rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MIX. TRIPLE RICE', 'mix. triple rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MIX. TRIPLE NOODLES', 'mix. triple noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix. triple noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MIX. TRIPLE NOODLES', 'mix. triple noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN TRIPLE NOODLES', 'chicken triple noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken triple noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN TRIPLE NOODLES', 'chicken triple noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. LUCKY SPECIAL NOODLES', 'chi. lucky special noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. lucky special noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. LUCKY SPECIAL NOODLES', 'chi. lucky special noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. TRIPLE PAKODA NOODLES', 'chi. triple pakoda noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. triple pakoda noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. TRIPLE PAKODA NOODLES', 'chi. triple pakoda noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN PAKODA NOODLES', 'chicken pakoda noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pakoda noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN PAKODA NOODLES', 'chicken pakoda noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN HAKKA NOODLES', 'chicken hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN HAKKA NOODLES', 'chicken hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. SCHEN. HAKKA NOODLES', 'chi. schen. hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. schen. hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. SCHEN. HAKKA NOODLES', 'chi. schen. hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. SCHEN. PAKODA NOODLES', 'chi. schen. pakoda noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. schen. pakoda noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. SCHEN. PAKODA NOODLES', 'chi. schen. pakoda noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN MIX HAKKA NOODLES', 'chicken mix hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken mix hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN MIX HAKKA NOODLES', 'chicken mix hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHINESE SINGAPORE NOODLES', 'chinese singapore noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chinese singapore noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHINESE SINGAPORE NOODLES', 'chinese singapore noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN CHINSES BHEL', 'chicken chinses bhel'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chinses bhel')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN CHINSES BHEL', 'chicken chinses bhel', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. CHINESE BHEL', 'veg. chinese bhel'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. chinese bhel')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. CHINESE BHEL', 'veg. chinese bhel', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHI. MANCHURIAN NOODLES', 'chi. manchurian noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. manchurian noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHI. MANCHURIAN NOODLES', 'chi. manchurian noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHICKEN CHILLY NOODLES', 'chicken chilly noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHICKEN CHILLY NOODLES', 'chicken chilly noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS HAKKA NOODLES', 'prawns hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS HAKKA NOODLES', 'prawns hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PRAWNS SCHZ HAKKA NOODLES', 'prawns schz hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns schz hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PRAWNS SCHZ HAKKA NOODLES', 'prawns schz hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EGG HAKKA NOODLES', 'egg hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EGG HAKKA NOODLES', 'egg hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EGG SCHZ HAKKA NOODLES', 'egg schz hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg schz hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EGG SCHZ HAKKA NOODLES', 'egg schz hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. HAKKA NOODLES', 'veg. hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. HAKKA NOODLES', 'veg. hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. SCHN. HAKKA NOODLES', 'veg. schn. hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. schn. hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. SCHN. HAKKA NOODLES', 'veg. schn. hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. MANCHURIAN NOODLES', 'veg. manchurian noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchurian noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. MANCHURIAN NOODLES', 'veg. manchurian noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. CHILLY NOODLES', 'veg. chilly noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. chilly noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. CHILLY NOODLES', 'veg. chilly noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ALL COLD DRINKS', 'all cold drinks'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'all cold drinks')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ALL COLD DRINKS', 'all cold drinks', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SWEET LASSI', 'sweet lassi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sweet lassi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SWEET LASSI', 'sweet lassi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BUTTER MILK/KESAR MASALA MIX.', 'butter milk/kesar masala mix.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter milk/kesar masala mix.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BUTTER MILK/KESAR MASALA MIX.', 'butter milk/kesar masala mix.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CARAMEL CUSTARD', 'caramel custard'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'caramel custard')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CARAMEL CUSTARD', 'caramel custard', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PUDDING', 'pudding'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pudding')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PUDDING', 'pudding', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'TEA / DOUBLE TEA', 'tea / double tea'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tea / double tea')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'TEA / DOUBLE TEA', 'tea / double tea', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SPL. TEA / COFFEE', 'spl. tea / coffee'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spl. tea / coffee')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SPL. TEA / COFFEE', 'spl. tea / coffee', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'HOT MILK', 'hot milk'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hot milk')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'HOT MILK', 'hot milk', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SPECIAL VEG. / NON VEG.', 'special veg. / non veg.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'special veg. / non veg.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SPECIAL VEG. / NON VEG.', 'special veg. / non veg.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GREEN SALAD', 'green salad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green salad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GREEN SALAD', 'green salad', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MASALA PAPAD', 'masala papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MASALA PAPAD', 'masala papad', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'VEG. RAITA', 'veg. raita'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. raita')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'VEG. RAITA', 'veg. raita', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PAPAD', 'papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PAPAD', 'papad', 'primary'
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
    (400070019001, 400070019, 'OMELET DOUBLE', 'omelet double', 'BREAKFAST', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019002, 400070019, 'HALF FRY DOUBLE', 'half fry double', 'BREAKFAST', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019003, 400070019, 'BHURJI', 'bhurji', 'BREAKFAST', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019004, 400070019, 'KHEEMA', 'kheema', 'BREAKFAST', 'non_veg'::text, 'mutton'::text, NULL::text, 'needs_review'),
    (400070019005, 400070019, 'KHEEMA FRY', 'kheema fry', 'BREAKFAST', 'non_veg'::text, 'mutton'::text, NULL::text, 'needs_review'),
    (400070019006, 400070019, 'KHEEMA GHOTALA', 'kheema ghotala', 'BREAKFAST', 'non_veg'::text, 'mutton'::text, NULL::text, 'needs_review'),
    (400070019007, 400070019, 'CHICKEN SCHEZWAN KEPSA', 'chicken schezwan kepsa', 'LUCKY SPECIAL', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019008, 400070019, 'CHICKEN PEPPER GRAVY', 'chicken pepper gravy', 'LUCKY SPECIAL', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019009, 400070019, 'CHICKEN KASHMIRI MASALA', 'chicken kashmiri masala', 'LUCKY SPECIAL', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019010, 400070019, 'CHICKEN TANDOORI (H/F)', 'chicken tandoori (h/f)', 'INDIAN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019011, 400070019, 'CHI.MALAI TANDOORI (H/F)', 'chi.malai tandoori (h/f)', 'INDIAN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019012, 400070019, 'CHICKEN AFGHANI TANDOORI', 'chicken afghani tandoori', 'INDIAN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019013, 400070019, 'CHICKEN TIKKA TANDOORI', 'chicken tikka tandoori', 'INDIAN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019014, 400070019, 'CHI. SCHEZWAN TANDOORI', 'chi. schezwan tandoori', 'INDIAN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019015, 400070019, 'CHICKEN BUTTER TANDOORI', 'chicken butter tandoori', 'INDIAN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019016, 400070019, 'CHICKEN TANDOORI LEG', 'chicken tandoori leg', 'INDIAN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019017, 400070019, 'LEMON TANDOORI CHICKEN', 'lemon tandoori chicken', 'INDIAN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019018, 400070019, 'SEEKH KEBAB', 'seekh kebab', 'INDIAN STARTERS', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019019, 400070019, 'RESHMI KEBAB', 'reshmi kebab', 'INDIAN STARTERS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019020, 400070019, 'PAHADI KEBAB', 'pahadi kebab', 'INDIAN STARTERS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019021, 400070019, 'ACHARI KEBAB', 'achari kebab', 'INDIAN STARTERS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019022, 400070019, 'HAZAARI KEBAB', 'hazaari kebab', 'INDIAN STARTERS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019023, 400070019, 'BANJARA KEBAB', 'banjara kebab', 'INDIAN STARTERS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019024, 400070019, 'KERALA KEBAB', 'kerala kebab', 'INDIAN STARTERS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019025, 400070019, 'TANGDI KEBAB', 'tangdi kebab', 'INDIAN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019026, 400070019, 'MALAI KEBAB', 'malai kebab', 'INDIAN STARTERS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019027, 400070019, 'CHESLI KEBAB', 'chesli kebab', 'INDIAN STARTERS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019028, 400070019, 'PANEER TIKKA DRY (5 PCS.)', 'paneer tikka dry (5 pcs.)', 'INDIAN STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019029, 400070019, 'CHICKEN TIKKA (5 PCS.)', 'chicken tikka (5 pcs.)', 'INDIAN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019030, 400070019, 'CHICKEN PAKODA (1KG)', 'chicken pakoda (1kg)', 'LUCKY CHICKEN PAKODA', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019031, 400070019, 'CHICKEN PAKODA (1/2 KG)', 'chicken pakoda (1/2 kg)', 'LUCKY CHICKEN PAKODA', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019032, 400070019, 'CHICKEN PAKODA (1/4 KG)', 'chicken pakoda (1/4 kg)', 'LUCKY CHICKEN PAKODA', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019033, 400070019, 'CHICKEN SCHEZWAN PAKODA', 'chicken schezwan pakoda', 'LUCKY CHICKEN PAKODA', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019034, 400070019, 'CHICKEN MASALA FRY', 'chicken masala fry', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019035, 400070019, 'CHICKEN MALABARI', 'chicken malabari', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019036, 400070019, 'CHICKEN AFGHANI (BONELESS)', 'chicken afghani (boneless)', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019037, 400070019, 'CHICKEN ANGARA (BONELESS)', 'chicken angara (boneless)', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019038, 400070019, 'CHICKEN BARRA', 'chicken barra', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019039, 400070019, 'CHICKEN LAZEEZ', 'chicken lazeez', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019040, 400070019, 'CHICKEN WHITE', 'chicken white', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019041, 400070019, 'CHICKEN BALTI (BONELESS)', 'chicken balti (boneless)', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019042, 400070019, 'CHICKEN GREEN MASALA', 'chicken green masala', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019043, 400070019, 'CHI. DABBA GOSHT (BONELESS)', 'chi. dabba gosht (boneless)', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019044, 400070019, 'CHICKEN SUKHA', 'chicken sukha', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019045, 400070019, 'CHICKEN HANDI', 'chicken handi', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019046, 400070019, 'CHICKEN KADAI', 'chicken kadai', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019047, 400070019, 'CHICKEN KORMA', 'chicken korma', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019048, 400070019, 'CHICKEN MURG MUSSALLAM', 'chicken murg mussallam', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019049, 400070019, 'CHICKEN MALWANI', 'chicken malwani', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019050, 400070019, 'CHICKEN MOGHLAI', 'chicken moghlai', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019051, 400070019, 'CHICKEN RASHIDA', 'chicken rashida', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019052, 400070019, 'CHICKEN LUCKY SPECIAL', 'chicken lucky special', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019053, 400070019, 'CHICKEN TIKKA HANDI', 'chicken tikka handi', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019054, 400070019, 'CHICKEN PALAK', 'chicken palak', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019055, 400070019, 'BUTTER CHICKEN (BONELESS)', 'butter chicken (boneless)', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019056, 400070019, 'CHICKEN TANDOORI MASALA', 'chicken tandoori masala', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019057, 400070019, 'CHICKEN KOLHAPURI', 'chicken kolhapuri', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019058, 400070019, 'CHICKEN TIKKA MASALA', 'chicken tikka masala', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019059, 400070019, 'CHICKEN FAMILY HANDI', 'chicken family handi', 'CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019060, 400070019, 'FISH FRY', 'fish fry', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'needs_review'),
    (400070019061, 400070019, 'FISH CURRY', 'fish curry', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'needs_review'),
    (400070019062, 400070019, 'FISH TANDOORI', 'fish tandoori', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'needs_review'),
    (400070019063, 400070019, 'FISH MASALA FRY', 'fish masala fry', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019064, 400070019, 'PRAWNS KADAI', 'prawns kadai', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019065, 400070019, 'PRAWNS MASALA', 'prawns masala', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019066, 400070019, 'PRAWNS MASALA FRY', 'prawns masala fry', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019067, 400070019, 'PRAWNS HANDI', 'prawns handi', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019068, 400070019, 'EGG MASALA', 'egg masala', 'BRAIN & EGG', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019069, 400070019, 'EGG MASALA FRY', 'egg masala fry', 'BRAIN & EGG', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019070, 400070019, 'EGG TOD FOD', 'egg tod fod', 'BRAIN & EGG', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019071, 400070019, 'MUTTON MASALA', 'mutton masala', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019072, 400070019, 'MUTTON MASALA FRY', 'mutton masala fry', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019073, 400070019, 'MUTTON ANGARA', 'mutton angara', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019074, 400070019, 'MUTTON HANDI', 'mutton handi', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019075, 400070019, 'MUTTON KADAI', 'mutton kadai', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019076, 400070019, 'MUT. DABBA GOSHT (BONELESS)', 'mut. dabba gosht (boneless)', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019077, 400070019, 'MUTTON SUKHA', 'mutton sukha', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019078, 400070019, 'MUTTON MALABARI', 'mutton malabari', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019079, 400070019, 'MUTTON AFGHANI', 'mutton afghani', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019080, 400070019, 'MUTTON KORMA', 'mutton korma', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019081, 400070019, 'MUTTON RASHIDA', 'mutton rashida', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019082, 400070019, 'MUTTON PALAK', 'mutton palak', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019083, 400070019, 'MUTTON TOMATO FRY (BONELESS)', 'mutton tomato fry (boneless)', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019084, 400070019, 'MUTTON DOPYAZA', 'mutton dopyaza', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019085, 400070019, 'MUTTON KOLHAPURI', 'mutton kolhapuri', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019086, 400070019, 'MUTTON MAKHANWALA', 'mutton makhanwala', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019087, 400070019, 'MUTTON DAL GOSHT', 'mutton dal gosht', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019088, 400070019, 'EXTRA MASALA FRY', 'extra masala fry', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019089, 400070019, 'VEG. HANDI', 'veg. handi', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019090, 400070019, 'VEG. KORMA', 'veg. korma', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019091, 400070019, 'VEG. KADAI', 'veg. kadai', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019092, 400070019, 'VEG. AFGHANI', 'veg. afghani', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019093, 400070019, 'VEG. KOLHAPURI', 'veg. kolhapuri', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019094, 400070019, 'VEG. MAKHANWALA', 'veg. makhanwala', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019095, 400070019, 'MIX VEG. FRY', 'mix veg. fry', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019096, 400070019, 'CHANA MASALA', 'chana masala', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019097, 400070019, 'CHANA MASALA FRY', 'chana masala fry', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019098, 400070019, 'ALU MUTTER / ALU PALAK', 'alu mutter / alu palak', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019099, 400070019, 'ALU MUTTER / ALU PALAK FRY', 'alu mutter / alu palak fry', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019100, 400070019, 'PANEER TIKKA MASALA', 'paneer tikka masala', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019101, 400070019, 'PANEER BUTTER MASALA', 'paneer butter masala', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019102, 400070019, 'PANEER TAWA MASALA', 'paneer tawa masala', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019103, 400070019, 'PANEER KORMA', 'paneer korma', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019104, 400070019, 'PANEER BHURJI', 'paneer bhurji', 'VEG. GRAVY', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019105, 400070019, 'PANEER PALAK', 'paneer palak', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019106, 400070019, 'PANEER MUTTER', 'paneer mutter', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019107, 400070019, 'PANEER HANDI', 'paneer handi', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019108, 400070019, 'PANEER KADAI', 'paneer kadai', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019109, 400070019, 'TANDOORI ROTI', 'tandoori roti', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019110, 400070019, 'TANDOORI BUTTER ROTI', 'tandoori butter roti', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019111, 400070019, 'TANDOORI NAAN', 'tandoori naan', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019112, 400070019, 'TANDOORI BUTTER NAAN', 'tandoori butter naan', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019113, 400070019, 'TANDOORI BUTTER PARATHA', 'tandoori butter paratha', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019114, 400070019, 'GARLIC NAAN', 'garlic naan', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019115, 400070019, 'GARLIC BUTTER NAAN', 'garlic butter naan', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019116, 400070019, 'BUTTER NAAN KULCH', 'butter naan kulch', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019117, 400070019, 'CHAPATI', 'chapati', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019118, 400070019, 'SPL. CHAPATI', 'spl. chapati', 'ROTI / NAAN / PARATHA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019119, 400070019, 'LUCKY SPECIAL DAL TADKA', 'lucky special dal tadka', 'LUCKY DAL SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019120, 400070019, 'DAL TADKA', 'dal tadka', 'LUCKY DAL SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019121, 400070019, 'DAL FRY', 'dal fry', 'LUCKY DAL SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019122, 400070019, 'LUCKY MAKHANWALA', 'lucky makhanwala', 'LUCKY DAL SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019123, 400070019, 'DAL PALAK', 'dal palak', 'LUCKY DAL SPECIAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019124, 400070019, 'CHICKEN BIRYANI', 'chicken biryani', 'BIRYANI / PULAV / RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019125, 400070019, 'CHICKEN TANDOORI BIRYANI', 'chicken tandoori biryani', 'BIRYANI / PULAV / RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019126, 400070019, 'MUTTON BIRYANI', 'mutton biryani', 'BIRYANI / PULAV / RICE', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019127, 400070019, 'MUTTON KEPSA RICE', 'mutton kepsa rice', 'BIRYANI / PULAV / RICE', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019128, 400070019, 'CHICKEN KEPSA RICE', 'chicken kepsa rice', 'BIRYANI / PULAV / RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019129, 400070019, 'CHI. TIKKA BIRYANI (BONELESS)', 'chi. tikka biryani (boneless)', 'BIRYANI / PULAV / RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019130, 400070019, 'CHICKEN HYDRABADI BIRYANI', 'chicken hydrabadi biryani', 'BIRYANI / PULAV / RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019131, 400070019, 'PRAWNS BIRYANI', 'prawns biryani', 'BIRYANI / PULAV / RICE', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019132, 400070019, 'EGG BIRYANI', 'egg biryani', 'BIRYANI / PULAV / RICE', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019133, 400070019, 'VEG. BIRYANI', 'veg. biryani', 'BIRYANI / PULAV / RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019134, 400070019, 'PANEER BIRYANI', 'paneer biryani', 'BIRYANI / PULAV / RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019135, 400070019, 'CHICKEN LUCKY SPECIAL PULAV', 'chicken lucky special pulav', 'BIRYANI / PULAV / RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019136, 400070019, 'CHICKEN PULAV', 'chicken pulav', 'BIRYANI / PULAV / RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019137, 400070019, 'MUTTON PULAV', 'mutton pulav', 'BIRYANI / PULAV / RICE', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070019138, 400070019, 'PRAWNS PULAV', 'prawns pulav', 'BIRYANI / PULAV / RICE', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019139, 400070019, 'EGG PULAV', 'egg pulav', 'BIRYANI / PULAV / RICE', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019140, 400070019, 'VEG. PULAV', 'veg. pulav', 'BIRYANI / PULAV / RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019141, 400070019, 'PANEER PULAV', 'paneer pulav', 'BIRYANI / PULAV / RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019142, 400070019, 'DAL KHICHDI', 'dal khichdi', 'BIRYANI / PULAV / RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019143, 400070019, 'WHITE RICE', 'white rice', 'BIRYANI / PULAV / RICE', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019144, 400070019, 'BIRYANI RICE', 'biryani rice', 'BIRYANI / PULAV / RICE', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019145, 400070019, 'JEERA RICE', 'jeera rice', 'BIRYANI / PULAV / RICE', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019146, 400070019, 'LUCKY SPECIAL SOUP', 'lucky special soup', 'CHINESE SOUPS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019147, 400070019, 'CHICKEN HOT & SOUR SOUP', 'chicken hot & sour soup', 'CHINESE SOUPS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019148, 400070019, 'CHICKEN CLEAR SOUP', 'chicken clear soup', 'CHINESE SOUPS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019149, 400070019, 'CHICKEN MANCHOW SOUP', 'chicken manchow soup', 'CHINESE SOUPS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019150, 400070019, 'CHICKEN NOODLES SOUP', 'chicken noodles soup', 'CHINESE SOUPS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019151, 400070019, 'VEG HOT & SOUR', 'veg hot & sour', 'CHINESE SOUPS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019152, 400070019, 'VEG MANCHOW SOUP', 'veg manchow soup', 'CHINESE SOUPS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019153, 400070019, 'TOMATO SOUP', 'tomato soup', 'CHINESE SOUPS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019154, 400070019, 'VEG CLEAR SOUP', 'veg clear soup', 'CHINESE SOUPS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019155, 400070019, 'CHICKEN CHILLY DRY', 'chicken chilly dry', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019156, 400070019, 'CHICKEN CHILLY GRAVY', 'chicken chilly gravy', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019157, 400070019, 'CHICKEN MANCHURIAN DRY', 'chicken manchurian dry', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019158, 400070019, 'CHICKEN MANCHURIAN GRAVY', 'chicken manchurian gravy', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019159, 400070019, 'CHICKEN SCHEZWAN CHILLY', 'chicken schezwan chilly', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019160, 400070019, 'CHICKEN GARLIC', 'chicken garlic', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019161, 400070019, 'CHICKEN HOT GARLIC DRY', 'chicken hot garlic dry', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019162, 400070019, 'CHICKEN GINGER', 'chicken ginger', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019163, 400070019, 'CHICKEN HONG KONG', 'chicken hong kong', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019164, 400070019, 'CHICKEN 65', 'chicken 65', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019165, 400070019, 'CHICKEN CRISPY', 'chicken crispy', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019166, 400070019, 'CHICKEN SALT & PEPPER', 'chicken salt & pepper', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019167, 400070019, 'CHI. LOLLY POP GRAVY (6 PCS)', 'chi. lolly pop gravy (6 pcs)', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019168, 400070019, 'CHI. LOLLY POP GRAVY (3 PCS)', 'chi. lolly pop gravy (3 pcs)', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019169, 400070019, 'CHI. LOLLY POP OIL FRY (6 PCS)', 'chi. lolly pop oil fry (6 pcs)', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019170, 400070019, 'CHI. LOLLY POP OIL FRY (3 PCS)', 'chi. lolly pop oil fry (3 pcs)', 'CHINESE DRY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019171, 400070019, 'PRAWNS CRISPY', 'prawns crispy', 'CHINESE PRAWNS', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019172, 400070019, 'PRAWNS CHILLY', 'prawns chilly', 'CHINESE PRAWNS', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019173, 400070019, 'PRAWNS GARLIC DRY', 'prawns garlic dry', 'CHINESE PRAWNS', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019174, 400070019, 'PRAWNS GINGER DRY', 'prawns ginger dry', 'CHINESE PRAWNS', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019175, 400070019, 'PRAWNS MANCHURAIN', 'prawns manchurain', 'CHINESE PRAWNS', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019176, 400070019, 'PRAWNS SCHEZWAN CHILLY', 'prawns schezwan chilly', 'CHINESE PRAWNS', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019177, 400070019, 'PANEER PAKODA', 'paneer pakoda', 'CHINESE VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019178, 400070019, 'PANEER CHILLY DRY', 'paneer chilly dry', 'CHINESE VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019179, 400070019, 'PANEER CRISPY', 'paneer crispy', 'CHINESE VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019180, 400070019, 'VEG. CRISPY', 'veg. crispy', 'CHINESE VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019181, 400070019, 'PANEER CHILLY GRAVY', 'paneer chilly gravy', 'CHINESE VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019182, 400070019, 'VEG. MANCHURIAN DRY', 'veg. manchurian dry', 'CHINESE VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019183, 400070019, 'VEG. MANCHURIAN GRAVY', 'veg. manchurian gravy', 'CHINESE VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019184, 400070019, 'CHICKEN CHOWMEIN', 'chicken chowmein', 'CHOWMEIN / CHOUPSEY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019185, 400070019, 'CHICKEN AMERICAN CHOUPSEY', 'chicken american choupsey', 'CHOWMEIN / CHOUPSEY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019186, 400070019, 'CHICKEN CHINESE CHOUPSEY', 'chicken chinese choupsey', 'CHOWMEIN / CHOUPSEY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019187, 400070019, 'MIX CHOWMEIN', 'mix chowmein', 'CHOWMEIN / CHOUPSEY', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019188, 400070019, 'PRAWNS CHOWMEIN', 'prawns chowmein', 'CHOWMEIN / CHOUPSEY', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019189, 400070019, 'VEG. AMERICAN CHOUPSEY', 'veg. american choupsey', 'CHOWMEIN / CHOUPSEY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019190, 400070019, 'VEG. CHINESE CHOUPSEY', 'veg. chinese choupsey', 'CHOWMEIN / CHOUPSEY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019191, 400070019, 'VEG. CHOWMEIN', 'veg. chowmein', 'CHOWMEIN / CHOUPSEY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019192, 400070019, 'CHICKEN PAKODA RICE', 'chicken pakoda rice', 'CHINESE FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019193, 400070019, 'CHI. SCHEZWAN PAKODA RICE', 'chi. schezwan pakoda rice', 'CHINESE FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019194, 400070019, 'CHICKEN FRIED RICE', 'chicken fried rice', 'CHINESE FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019195, 400070019, 'CHICKEN MIX FRIED RICE', 'chicken mix fried rice', 'CHINESE FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019196, 400070019, 'CHI. SCHEZWAN FRIED RICE', 'chi. schezwan fried rice', 'CHINESE FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019197, 400070019, 'CHI. HONG KONG FRIED RICE', 'chi. hong kong fried rice', 'CHINESE FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019198, 400070019, 'CHI. SINGAPORE FRIED RICE', 'chi. singapore fried rice', 'CHINESE FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019199, 400070019, 'CHICKEN BURNT CHILLY RICE', 'chicken burnt chilly rice', 'CHINESE FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019200, 400070019, 'PRAWNS FRIED RICE', 'prawns fried rice', 'CHINESE FRIED RICE', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019201, 400070019, 'PRAWNS SCHEZWAN FRIED RICE', 'prawns schezwan fried rice', 'CHINESE FRIED RICE', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019202, 400070019, 'EGG FRIED RICE', 'egg fried rice', 'CHINESE FRIED RICE', 'egg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070019203, 400070019, 'EGG SCHEZWAN FRIED RICE', 'egg schezwan fried rice', 'CHINESE FRIED RICE', 'egg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070019204, 400070019, 'VEG. FRIED RICE', 'veg. fried rice', 'CHINESE FRIED RICE', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070019205, 400070019, 'VEG. SCHEZWAN FRIED RICE', 'veg. schezwan fried rice', 'CHINESE FRIED RICE', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070019206, 400070019, 'VEG. HONG KONG FRIED RICE', 'veg. hong kong fried rice', 'CHINESE FRIED RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019207, 400070019, 'VEG. SINGAPORE FRIED RICE', 'veg. singapore fried rice', 'CHINESE FRIED RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019208, 400070019, 'CHICKEN COMBINATION RICE', 'chicken combination rice', 'CHINESE FRIED RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019209, 400070019, 'LUCKY SPECIAL FIRED RICE', 'lucky special fired rice', 'FRIED RICE WITH GRAVY RICE', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019210, 400070019, 'CHICKEN TRIPLE PAKODA RICE', 'chicken triple pakoda rice', 'FRIED RICE WITH GRAVY RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019211, 400070019, 'CHICKEN MALAYSIAN RICE', 'chicken malaysian rice', 'FRIED RICE WITH GRAVY RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019212, 400070019, 'CHICKEN GOLDEN RICE', 'chicken golden rice', 'FRIED RICE WITH GRAVY RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019213, 400070019, 'CHICKEN TRIPLE FRIED RICE', 'chicken triple fried rice', 'FRIED RICE WITH GRAVY RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019214, 400070019, 'CHICKEN CHILLY RICE', 'chicken chilly rice', 'FRIED RICE WITH GRAVY RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019215, 400070019, 'CHICKEN MANCHURIAN RICE', 'chicken manchurian rice', 'FRIED RICE WITH GRAVY RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019216, 400070019, 'CHICKEN GARLIC RICE', 'chicken garlic rice', 'FRIED RICE WITH GRAVY RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019217, 400070019, 'CHICKEN GINGER RICE', 'chicken ginger rice', 'FRIED RICE WITH GRAVY RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019218, 400070019, 'VEG. TRIPLE FRIED RICE', 'veg. triple fried rice', 'FRIED RICE WITH GRAVY RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019219, 400070019, 'VEG. MANCHURIAN', 'veg. manchurian', 'FRIED RICE WITH GRAVY RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019220, 400070019, 'MIX. TRIPLE RICE', 'mix. triple rice', 'FRIED RICE WITH GRAVY RICE', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019221, 400070019, 'MIX. TRIPLE NOODLES', 'mix. triple noodles', 'FRIED RICE WITH GRAVY RICE', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019222, 400070019, 'CHICKEN TRIPLE NOODLES', 'chicken triple noodles', 'FRIED RICE WITH GRAVY RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019223, 400070019, 'CHI. LUCKY SPECIAL NOODLES', 'chi. lucky special noodles', 'FRIED RICE WITH GRAVY RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019224, 400070019, 'CHI. TRIPLE PAKODA NOODLES', 'chi. triple pakoda noodles', 'FRIED RICE WITH GRAVY RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019225, 400070019, 'CHICKEN PAKODA NOODLES', 'chicken pakoda noodles', 'NOODLES DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019226, 400070019, 'CHICKEN HAKKA NOODLES', 'chicken hakka noodles', 'NOODLES DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019227, 400070019, 'CHI. SCHEN. HAKKA NOODLES', 'chi. schen. hakka noodles', 'NOODLES DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019228, 400070019, 'CHI. SCHEN. PAKODA NOODLES', 'chi. schen. pakoda noodles', 'NOODLES DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'needs_review'),
    (400070019229, 400070019, 'CHICKEN MIX HAKKA NOODLES', 'chicken mix hakka noodles', 'NOODLES DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019230, 400070019, 'CHINESE SINGAPORE NOODLES', 'chinese singapore noodles', 'NOODLES DISHES', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070019231, 400070019, 'CHICKEN CHINSES BHEL', 'chicken chinses bhel', 'NOODLES DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019232, 400070019, 'VEG. CHINESE BHEL', 'veg. chinese bhel', 'NOODLES DISHES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019233, 400070019, 'CHI. MANCHURIAN NOODLES', 'chi. manchurian noodles', 'NOODLES DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019234, 400070019, 'CHICKEN CHILLY NOODLES', 'chicken chilly noodles', 'NOODLES DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070019235, 400070019, 'PRAWNS HAKKA NOODLES', 'prawns hakka noodles', 'NOODLES DISHES', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019236, 400070019, 'PRAWNS SCHZ HAKKA NOODLES', 'prawns schz hakka noodles', 'NOODLES DISHES', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070019237, 400070019, 'EGG HAKKA NOODLES', 'egg hakka noodles', 'NOODLES DISHES', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019238, 400070019, 'EGG SCHZ HAKKA NOODLES', 'egg schz hakka noodles', 'NOODLES DISHES', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019239, 400070019, 'VEG. HAKKA NOODLES', 'veg. hakka noodles', 'NOODLES DISHES', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070019240, 400070019, 'VEG. SCHN. HAKKA NOODLES', 'veg. schn. hakka noodles', 'NOODLES DISHES', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070019241, 400070019, 'VEG. MANCHURIAN NOODLES', 'veg. manchurian noodles', 'NOODLES DISHES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019242, 400070019, 'VEG. CHILLY NOODLES', 'veg. chilly noodles', 'NOODLES DISHES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019243, 400070019, 'ALL COLD DRINKS', 'all cold drinks', 'HOT / COLD BEVERAGES', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070019244, 400070019, 'SWEET LASSI', 'sweet lassi', 'HOT / COLD BEVERAGES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019245, 400070019, 'BUTTER MILK/KESAR MASALA MIX.', 'butter milk/kesar masala mix.', 'HOT / COLD BEVERAGES', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070019246, 400070019, 'CARAMEL CUSTARD', 'caramel custard', 'HOT / COLD BEVERAGES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019247, 400070019, 'PUDDING', 'pudding', 'HOT / COLD BEVERAGES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019248, 400070019, 'TEA / DOUBLE TEA', 'tea / double tea', 'HOT / COLD BEVERAGES', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070019249, 400070019, 'SPL. TEA / COFFEE', 'spl. tea / coffee', 'HOT / COLD BEVERAGES', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070019250, 400070019, 'HOT MILK', 'hot milk', 'HOT / COLD BEVERAGES', 'veg'::text, NULL::text, NULL::text, 'needs_review'),
    (400070019251, 400070019, 'SPECIAL VEG. / NON VEG.', 'special veg. / non veg.', 'NEW LUCKY FAMILY PACK', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019252, 400070019, 'GREEN SALAD', 'green salad', 'SALADS & RAITA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019253, 400070019, 'MASALA PAPAD', 'masala papad', 'SALADS & RAITA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019254, 400070019, 'VEG. RAITA', 'veg. raita', 'SALADS & RAITA', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070019255, 400070019, 'PAPAD', 'papad', 'SALADS & RAITA', 'veg'::text, NULL::text, NULL::text, 'unverified')
) AS x(menu_item_id, restaurant_id, name, normalized_name, raw_category_text, food_classification_code, protein_code, split_group_key, verification_status_code)
JOIN canonical_dish cd ON cd.normalized_name = x.normalized_name
LEFT JOIN protein_type pt ON pt.code = x.protein_code;

-- Menu item source: name/existence confidence, kept separate from price confidence.
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
VALUES
    (400070019001, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019002, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019003, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019004, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019005, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019006, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019007, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019008, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019009, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019010, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019011, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019012, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019013, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019014, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019015, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019016, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019017, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019018, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019019, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019020, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019021, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019022, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019023, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019024, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019025, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019026, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019027, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019028, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019029, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019030, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019031, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019032, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019033, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019034, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019035, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019036, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019037, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019038, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019039, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019040, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019041, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019042, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019043, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019044, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019045, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019046, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019047, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019048, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019049, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019050, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019051, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019052, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019053, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019054, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019055, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019056, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019057, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019058, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019059, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019060, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019061, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019062, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019063, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019064, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019065, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019066, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019067, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019068, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019069, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019070, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019071, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019072, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019073, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019074, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019075, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019076, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019077, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019078, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019079, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019080, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019081, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019082, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019083, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019084, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019085, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019086, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019087, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019088, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019089, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019090, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019091, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019092, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019093, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019094, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019095, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019096, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019097, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019098, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019099, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019100, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019101, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019102, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019103, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019104, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019105, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019106, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019107, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019108, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019109, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019110, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019111, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019112, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019113, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019114, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019115, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019116, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019117, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019118, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019119, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019120, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019121, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019122, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019123, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019124, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019125, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019126, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019127, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019128, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019129, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019130, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019131, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019132, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019133, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019134, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019135, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019136, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019137, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019138, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019139, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019140, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019141, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019142, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019143, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019144, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019145, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019146, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019147, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019148, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019149, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019150, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019151, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019152, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019153, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019154, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019155, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019156, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019157, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019158, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019159, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019160, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019161, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019162, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019163, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019164, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019165, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019166, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019167, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019168, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019169, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019170, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019171, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019172, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019173, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019174, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019175, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019176, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019177, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019178, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019179, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019180, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019181, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019182, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019183, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019184, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019185, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019186, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019187, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019188, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019189, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019190, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019191, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019192, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019193, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019194, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019195, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019196, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019197, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019198, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019199, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019200, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019201, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019202, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019203, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019204, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019205, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019206, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019207, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019208, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019209, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019210, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019211, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019212, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019213, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019214, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019215, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019216, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019217, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019218, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019219, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019220, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019221, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019222, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019223, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019224, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019225, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019226, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019227, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019228, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019229, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019230, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019231, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019232, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019233, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019234, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019235, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019236, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019237, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019238, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019239, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019240, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019241, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019242, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019243, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019244, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019245, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019246, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019247, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019248, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019249, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019250, 400070019, :extraction_batch_id, 0.9, 'needs_review'),
    (400070019251, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019252, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019253, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019254, 400070019, :extraction_batch_id, 0.9, 'unverified'),
    (400070019255, 400070019, :extraction_batch_id, 0.9, 'unverified');

-- Variants (portion/label variants -- one menu_item, multiple menu_item_variant rows;
-- a protein/veg split already became two separate menu_item rows above, so each carries
-- exactly one variant here).
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
VALUES
    (400070019001, 400070019001, 'Regular', 'fixed', TRUE),
    (400070019002, 400070019002, 'Regular', 'fixed', TRUE),
    (400070019003, 400070019003, 'Regular', 'fixed', TRUE),
    (400070019004, 400070019004, 'Half', 'fixed', TRUE),
    (400070019005, 400070019004, 'Full', 'fixed', FALSE),
    (400070019006, 400070019005, 'Half', 'fixed', TRUE),
    (400070019007, 400070019005, 'Full', 'fixed', FALSE),
    (400070019008, 400070019006, 'Half', 'fixed', TRUE),
    (400070019009, 400070019006, 'Full', 'fixed', FALSE),
    (400070019010, 400070019007, 'Regular', 'fixed', TRUE),
    (400070019011, 400070019008, 'Regular', 'fixed', TRUE),
    (400070019012, 400070019009, 'Regular', 'fixed', TRUE),
    (400070019013, 400070019010, 'H', 'fixed', TRUE),
    (400070019014, 400070019010, 'F', 'fixed', FALSE),
    (400070019015, 400070019011, 'H', 'fixed', TRUE),
    (400070019016, 400070019011, 'F', 'fixed', FALSE),
    (400070019017, 400070019012, 'Regular', 'fixed', TRUE),
    (400070019018, 400070019013, 'Regular', 'fixed', TRUE),
    (400070019019, 400070019014, 'Half', 'fixed', TRUE),
    (400070019020, 400070019014, 'Full', 'fixed', FALSE),
    (400070019021, 400070019015, 'Regular', 'fixed', TRUE),
    (400070019022, 400070019016, 'Regular', 'fixed', TRUE),
    (400070019023, 400070019017, 'Regular', 'fixed', TRUE),
    (400070019024, 400070019018, 'Regular', 'fixed', TRUE),
    (400070019025, 400070019019, 'Regular', 'fixed', TRUE),
    (400070019026, 400070019020, 'Regular', 'fixed', TRUE),
    (400070019027, 400070019021, 'Regular', 'fixed', TRUE),
    (400070019028, 400070019022, 'Regular', 'fixed', TRUE),
    (400070019029, 400070019023, 'Regular', 'fixed', TRUE),
    (400070019030, 400070019024, 'Regular', 'fixed', TRUE),
    (400070019031, 400070019025, 'Regular', 'fixed', TRUE),
    (400070019032, 400070019026, 'Regular', 'fixed', TRUE),
    (400070019033, 400070019027, 'Regular', 'fixed', TRUE),
    (400070019034, 400070019028, 'Regular', 'fixed', TRUE),
    (400070019035, 400070019029, 'Regular', 'fixed', TRUE),
    (400070019036, 400070019030, 'Regular', 'fixed', TRUE),
    (400070019037, 400070019031, 'Regular', 'fixed', TRUE),
    (400070019038, 400070019032, 'Regular', 'fixed', TRUE),
    (400070019039, 400070019033, 'Regular', 'fixed', TRUE),
    (400070019040, 400070019034, 'Half', 'fixed', TRUE),
    (400070019041, 400070019034, 'Full', 'fixed', FALSE),
    (400070019042, 400070019035, 'Half', 'fixed', TRUE),
    (400070019043, 400070019035, 'Full', 'fixed', FALSE),
    (400070019044, 400070019036, 'Regular', 'fixed', TRUE),
    (400070019045, 400070019037, 'Regular', 'fixed', TRUE),
    (400070019046, 400070019038, 'Regular', 'fixed', TRUE),
    (400070019047, 400070019039, 'Regular', 'fixed', TRUE),
    (400070019048, 400070019040, 'Regular', 'fixed', TRUE),
    (400070019049, 400070019041, 'Regular', 'fixed', TRUE),
    (400070019050, 400070019042, 'Regular', 'fixed', TRUE),
    (400070019051, 400070019043, 'Regular', 'fixed', TRUE),
    (400070019052, 400070019044, 'Regular', 'fixed', TRUE),
    (400070019053, 400070019045, 'Regular', 'fixed', TRUE),
    (400070019054, 400070019046, 'Regular', 'fixed', TRUE),
    (400070019055, 400070019047, 'Regular', 'fixed', TRUE),
    (400070019056, 400070019048, 'Regular', 'fixed', TRUE),
    (400070019057, 400070019049, 'Regular', 'fixed', TRUE),
    (400070019058, 400070019050, 'Regular', 'fixed', TRUE),
    (400070019059, 400070019051, 'Regular', 'fixed', TRUE),
    (400070019060, 400070019052, 'Regular', 'fixed', TRUE),
    (400070019061, 400070019053, 'Regular', 'fixed', TRUE),
    (400070019062, 400070019054, 'Regular', 'fixed', TRUE),
    (400070019063, 400070019055, 'Regular', 'fixed', TRUE),
    (400070019064, 400070019056, 'Regular', 'fixed', TRUE),
    (400070019065, 400070019057, 'Regular', 'fixed', TRUE),
    (400070019066, 400070019058, 'Regular', 'fixed', TRUE),
    (400070019067, 400070019059, 'Regular', 'fixed', TRUE),
    (400070019068, 400070019060, 'Regular', 'fixed', TRUE),
    (400070019069, 400070019061, 'Regular', 'fixed', TRUE),
    (400070019070, 400070019062, 'Regular', 'fixed', TRUE),
    (400070019071, 400070019063, 'Regular', 'fixed', TRUE),
    (400070019072, 400070019064, 'Regular', 'fixed', TRUE),
    (400070019073, 400070019065, 'Regular', 'fixed', TRUE),
    (400070019074, 400070019066, 'Regular', 'fixed', TRUE),
    (400070019075, 400070019067, 'Regular', 'fixed', TRUE),
    (400070019076, 400070019068, 'Regular', 'fixed', TRUE),
    (400070019077, 400070019069, 'Regular', 'fixed', TRUE),
    (400070019078, 400070019070, 'Regular', 'fixed', TRUE),
    (400070019079, 400070019071, 'Regular', 'fixed', TRUE),
    (400070019080, 400070019072, 'Regular', 'fixed', TRUE),
    (400070019081, 400070019073, 'Regular', 'fixed', TRUE),
    (400070019082, 400070019074, 'Regular', 'fixed', TRUE),
    (400070019083, 400070019075, 'Regular', 'fixed', TRUE),
    (400070019084, 400070019076, 'Regular', 'fixed', TRUE),
    (400070019085, 400070019077, 'Regular', 'fixed', TRUE),
    (400070019086, 400070019078, 'Regular', 'fixed', TRUE),
    (400070019087, 400070019079, 'Regular', 'fixed', TRUE),
    (400070019088, 400070019080, 'Regular', 'fixed', TRUE),
    (400070019089, 400070019081, 'Regular', 'fixed', TRUE),
    (400070019090, 400070019082, 'Regular', 'fixed', TRUE),
    (400070019091, 400070019083, 'Regular', 'fixed', TRUE),
    (400070019092, 400070019084, 'Regular', 'fixed', TRUE),
    (400070019093, 400070019085, 'Regular', 'fixed', TRUE),
    (400070019094, 400070019086, 'Regular', 'fixed', TRUE),
    (400070019095, 400070019087, 'Regular', 'fixed', TRUE),
    (400070019096, 400070019088, 'Regular', 'fixed', TRUE),
    (400070019097, 400070019089, 'Regular', 'fixed', TRUE),
    (400070019098, 400070019090, 'Regular', 'fixed', TRUE),
    (400070019099, 400070019091, 'Regular', 'fixed', TRUE),
    (400070019100, 400070019092, 'Regular', 'fixed', TRUE),
    (400070019101, 400070019093, 'Regular', 'fixed', TRUE),
    (400070019102, 400070019094, 'Regular', 'fixed', TRUE),
    (400070019103, 400070019095, 'Regular', 'fixed', TRUE),
    (400070019104, 400070019096, 'Regular', 'fixed', TRUE),
    (400070019105, 400070019097, 'Regular', 'fixed', TRUE),
    (400070019106, 400070019098, 'Regular', 'fixed', TRUE),
    (400070019107, 400070019099, 'Regular', 'fixed', TRUE),
    (400070019108, 400070019100, 'Regular', 'fixed', TRUE),
    (400070019109, 400070019101, 'Regular', 'fixed', TRUE),
    (400070019110, 400070019102, 'Regular', 'fixed', TRUE),
    (400070019111, 400070019103, 'Regular', 'fixed', TRUE),
    (400070019112, 400070019104, 'Regular', 'fixed', TRUE),
    (400070019113, 400070019105, 'Regular', 'fixed', TRUE),
    (400070019114, 400070019106, 'Regular', 'fixed', TRUE),
    (400070019115, 400070019107, 'Regular', 'fixed', TRUE),
    (400070019116, 400070019108, 'Regular', 'fixed', TRUE),
    (400070019117, 400070019109, 'Regular', 'fixed', TRUE),
    (400070019118, 400070019110, 'Regular', 'fixed', TRUE),
    (400070019119, 400070019111, 'Regular', 'fixed', TRUE),
    (400070019120, 400070019112, 'Regular', 'fixed', TRUE),
    (400070019121, 400070019113, 'Regular', 'fixed', TRUE),
    (400070019122, 400070019114, 'Regular', 'fixed', TRUE),
    (400070019123, 400070019115, 'Regular', 'fixed', TRUE),
    (400070019124, 400070019116, 'Regular', 'fixed', TRUE),
    (400070019125, 400070019117, 'Regular', 'fixed', TRUE),
    (400070019126, 400070019118, 'Regular', 'fixed', TRUE),
    (400070019127, 400070019119, 'Regular', 'fixed', TRUE),
    (400070019128, 400070019120, 'Regular', 'fixed', TRUE),
    (400070019129, 400070019121, 'Regular', 'fixed', TRUE),
    (400070019130, 400070019122, 'Regular', 'fixed', TRUE),
    (400070019131, 400070019123, 'Regular', 'fixed', TRUE),
    (400070019132, 400070019124, 'Half', 'fixed', TRUE),
    (400070019133, 400070019124, 'Full', 'fixed', FALSE),
    (400070019134, 400070019125, 'Regular', 'fixed', TRUE),
    (400070019135, 400070019126, 'Regular', 'fixed', TRUE),
    (400070019136, 400070019127, 'Regular', 'fixed', TRUE),
    (400070019137, 400070019128, 'Regular', 'fixed', TRUE),
    (400070019138, 400070019129, 'Regular', 'fixed', TRUE),
    (400070019139, 400070019130, 'Regular', 'fixed', TRUE),
    (400070019140, 400070019131, 'Regular', 'fixed', TRUE),
    (400070019141, 400070019132, 'Regular', 'fixed', TRUE),
    (400070019142, 400070019133, 'Regular', 'fixed', TRUE),
    (400070019143, 400070019134, 'Regular', 'fixed', TRUE),
    (400070019144, 400070019135, 'Regular', 'fixed', TRUE),
    (400070019145, 400070019136, 'Regular', 'fixed', TRUE),
    (400070019146, 400070019137, 'Regular', 'fixed', TRUE),
    (400070019147, 400070019138, 'Regular', 'fixed', TRUE),
    (400070019148, 400070019139, 'Regular', 'fixed', TRUE),
    (400070019149, 400070019140, 'Regular', 'fixed', TRUE),
    (400070019150, 400070019141, 'Regular', 'fixed', TRUE),
    (400070019151, 400070019142, 'Regular', 'fixed', TRUE),
    (400070019152, 400070019143, 'Half', 'fixed', TRUE),
    (400070019153, 400070019143, 'Full', 'fixed', FALSE),
    (400070019154, 400070019144, 'Half', 'fixed', TRUE),
    (400070019155, 400070019144, 'Full', 'fixed', FALSE),
    (400070019156, 400070019145, 'Half', 'fixed', TRUE),
    (400070019157, 400070019145, 'Full', 'fixed', FALSE),
    (400070019158, 400070019146, 'Regular', 'fixed', TRUE),
    (400070019159, 400070019147, 'Regular', 'fixed', TRUE),
    (400070019160, 400070019148, 'Regular', 'fixed', TRUE),
    (400070019161, 400070019149, 'Regular', 'fixed', TRUE),
    (400070019162, 400070019150, 'Regular', 'fixed', TRUE),
    (400070019163, 400070019151, 'Regular', 'fixed', TRUE),
    (400070019164, 400070019152, 'Regular', 'fixed', TRUE),
    (400070019165, 400070019153, 'Regular', 'fixed', TRUE),
    (400070019166, 400070019154, 'Regular', 'fixed', TRUE),
    (400070019167, 400070019155, 'Half', 'fixed', TRUE),
    (400070019168, 400070019155, 'Full', 'fixed', FALSE),
    (400070019169, 400070019156, 'Half', 'fixed', TRUE),
    (400070019170, 400070019156, 'Full', 'fixed', FALSE),
    (400070019171, 400070019157, 'Half', 'fixed', TRUE),
    (400070019172, 400070019157, 'Full', 'fixed', FALSE),
    (400070019173, 400070019158, 'Half', 'fixed', TRUE),
    (400070019174, 400070019158, 'Full', 'fixed', FALSE),
    (400070019175, 400070019159, 'Half', 'fixed', TRUE),
    (400070019176, 400070019159, 'Full', 'fixed', FALSE),
    (400070019177, 400070019160, 'Regular', 'fixed', TRUE),
    (400070019178, 400070019161, 'Regular', 'fixed', TRUE),
    (400070019179, 400070019162, 'Regular', 'fixed', TRUE),
    (400070019180, 400070019163, 'Regular', 'fixed', TRUE),
    (400070019181, 400070019164, 'Regular', 'fixed', TRUE),
    (400070019182, 400070019165, 'Half', 'fixed', TRUE),
    (400070019183, 400070019165, 'Full', 'fixed', FALSE),
    (400070019184, 400070019166, 'Regular', 'fixed', TRUE),
    (400070019185, 400070019167, 'Regular', 'fixed', TRUE),
    (400070019186, 400070019168, 'Regular', 'fixed', TRUE),
    (400070019187, 400070019169, 'Regular', 'fixed', TRUE),
    (400070019188, 400070019170, 'Regular', 'fixed', TRUE),
    (400070019189, 400070019171, 'Regular', 'fixed', TRUE),
    (400070019190, 400070019172, 'Regular', 'fixed', TRUE),
    (400070019191, 400070019173, 'Regular', 'fixed', TRUE),
    (400070019192, 400070019174, 'Regular', 'fixed', TRUE),
    (400070019193, 400070019175, 'Regular', 'fixed', TRUE),
    (400070019194, 400070019176, 'Regular', 'fixed', TRUE),
    (400070019195, 400070019177, 'Regular', 'fixed', TRUE),
    (400070019196, 400070019178, 'Regular', 'fixed', TRUE),
    (400070019197, 400070019179, 'Regular', 'fixed', TRUE),
    (400070019198, 400070019180, 'Regular', 'fixed', TRUE),
    (400070019199, 400070019181, 'Regular', 'fixed', TRUE),
    (400070019200, 400070019182, 'Regular', 'fixed', TRUE),
    (400070019201, 400070019183, 'Regular', 'fixed', TRUE),
    (400070019202, 400070019184, 'Regular', 'fixed', TRUE),
    (400070019203, 400070019185, 'Regular', 'fixed', TRUE),
    (400070019204, 400070019186, 'Regular', 'fixed', TRUE),
    (400070019205, 400070019187, 'Regular', 'fixed', TRUE),
    (400070019206, 400070019188, 'Regular', 'fixed', TRUE),
    (400070019207, 400070019189, 'Regular', 'fixed', TRUE),
    (400070019208, 400070019190, 'Regular', 'fixed', TRUE),
    (400070019209, 400070019191, 'Regular', 'fixed', TRUE),
    (400070019210, 400070019192, 'H', 'fixed', TRUE),
    (400070019211, 400070019192, 'F', 'fixed', FALSE),
    (400070019212, 400070019193, 'Half', 'fixed', TRUE),
    (400070019213, 400070019193, 'Full', 'fixed', FALSE),
    (400070019214, 400070019194, 'Half', 'fixed', TRUE),
    (400070019215, 400070019194, 'Full', 'fixed', FALSE),
    (400070019216, 400070019195, 'Regular', 'fixed', TRUE),
    (400070019217, 400070019196, 'Half', 'fixed', TRUE),
    (400070019218, 400070019196, 'Full', 'fixed', FALSE),
    (400070019219, 400070019197, 'Regular', 'fixed', TRUE),
    (400070019220, 400070019198, 'Regular', 'fixed', TRUE),
    (400070019221, 400070019199, 'Regular', 'fixed', TRUE),
    (400070019222, 400070019200, 'Regular', 'fixed', TRUE),
    (400070019223, 400070019201, 'Regular', 'fixed', TRUE),
    (400070019224, 400070019202, 'Half', 'fixed', TRUE),
    (400070019225, 400070019202, 'Full', 'fixed', FALSE),
    (400070019226, 400070019203, 'Half', 'fixed', TRUE),
    (400070019227, 400070019203, 'Full', 'fixed', FALSE),
    (400070019228, 400070019204, 'Half', 'fixed', TRUE),
    (400070019229, 400070019204, 'Full', 'fixed', FALSE),
    (400070019230, 400070019205, 'Half', 'fixed', TRUE),
    (400070019231, 400070019205, 'Full', 'fixed', FALSE),
    (400070019232, 400070019206, 'Regular', 'fixed', TRUE),
    (400070019233, 400070019207, 'Regular', 'fixed', TRUE),
    (400070019234, 400070019208, 'Regular', 'fixed', TRUE),
    (400070019235, 400070019209, 'Regular', 'fixed', TRUE),
    (400070019236, 400070019210, 'Regular', 'fixed', TRUE),
    (400070019237, 400070019211, 'Regular', 'fixed', TRUE),
    (400070019238, 400070019212, 'Regular', 'fixed', TRUE),
    (400070019239, 400070019213, 'Half', 'fixed', TRUE),
    (400070019240, 400070019213, 'Full', 'fixed', FALSE),
    (400070019241, 400070019214, 'Regular', 'fixed', TRUE),
    (400070019242, 400070019215, 'Half', 'fixed', TRUE),
    (400070019243, 400070019215, 'Full', 'fixed', FALSE),
    (400070019244, 400070019216, 'Regular', 'fixed', TRUE),
    (400070019245, 400070019217, 'Regular', 'fixed', TRUE),
    (400070019246, 400070019218, 'Regular', 'fixed', TRUE),
    (400070019247, 400070019219, 'Regular', 'fixed', TRUE),
    (400070019248, 400070019220, 'Regular', 'fixed', TRUE),
    (400070019249, 400070019221, 'Regular', 'fixed', TRUE),
    (400070019250, 400070019222, 'Half', 'fixed', TRUE),
    (400070019251, 400070019222, 'Full', 'fixed', FALSE),
    (400070019252, 400070019223, 'Regular', 'fixed', TRUE),
    (400070019253, 400070019224, 'Regular', 'fixed', TRUE),
    (400070019254, 400070019225, 'Half', 'fixed', TRUE),
    (400070019255, 400070019225, 'Full', 'fixed', FALSE),
    (400070019256, 400070019226, 'Half', 'fixed', TRUE),
    (400070019257, 400070019226, 'Full', 'fixed', FALSE),
    (400070019258, 400070019227, 'Half', 'fixed', TRUE),
    (400070019259, 400070019227, 'Full', 'fixed', FALSE),
    (400070019260, 400070019228, 'Half', 'fixed', TRUE),
    (400070019261, 400070019228, 'Full', 'fixed', FALSE),
    (400070019262, 400070019229, 'Regular', 'fixed', TRUE),
    (400070019263, 400070019230, 'Regular', 'fixed', TRUE),
    (400070019264, 400070019231, 'Regular', 'fixed', TRUE),
    (400070019265, 400070019232, 'Regular', 'fixed', TRUE),
    (400070019266, 400070019233, 'Regular', 'fixed', TRUE),
    (400070019267, 400070019234, 'Regular', 'fixed', TRUE),
    (400070019268, 400070019235, 'Regular', 'fixed', TRUE),
    (400070019269, 400070019236, 'Regular', 'fixed', TRUE),
    (400070019270, 400070019237, 'Regular', 'fixed', TRUE),
    (400070019271, 400070019238, 'Regular', 'fixed', TRUE),
    (400070019272, 400070019239, 'Half', 'fixed', TRUE),
    (400070019273, 400070019239, 'Full', 'fixed', FALSE),
    (400070019274, 400070019240, 'Half', 'fixed', TRUE),
    (400070019275, 400070019240, 'Full', 'fixed', FALSE),
    (400070019276, 400070019241, 'Regular', 'fixed', TRUE),
    (400070019277, 400070019242, 'Regular', 'fixed', TRUE),
    (400070019278, 400070019243, 'Regular', 'fixed', TRUE),
    (400070019279, 400070019244, 'Regular', 'fixed', TRUE),
    (400070019280, 400070019245, 'Half', 'fixed', TRUE),
    (400070019281, 400070019245, 'Full', 'fixed', FALSE),
    (400070019282, 400070019246, 'Regular', 'fixed', TRUE),
    (400070019283, 400070019247, 'Regular', 'fixed', TRUE),
    (400070019284, 400070019248, 'Half', 'fixed', TRUE),
    (400070019285, 400070019248, 'Full', 'fixed', FALSE),
    (400070019286, 400070019249, 'Half', 'fixed', TRUE),
    (400070019287, 400070019249, 'Full', 'fixed', FALSE),
    (400070019288, 400070019250, 'Half', 'fixed', TRUE),
    (400070019289, 400070019250, 'Full', 'fixed', FALSE),
    (400070019290, 400070019251, 'Regular', 'fixed', TRUE),
    (400070019291, 400070019252, 'Regular', 'fixed', TRUE),
    (400070019292, 400070019253, 'Regular', 'fixed', TRUE),
    (400070019293, 400070019254, 'Regular', 'fixed', TRUE),
    (400070019294, 400070019255, 'Regular', 'fixed', TRUE);

-- Prices (only for variants where a numeric price was actually captured)
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
VALUES
    (400070019001, 400070019001, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019002, 400070019002, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019003, 400070019003, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019004, 400070019004, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019005, 400070019005, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019006, 400070019006, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019007, 400070019007, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019008, 400070019008, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019009, 400070019009, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019010, 400070019010, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019011, 400070019011, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019012, 400070019012, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019013, 400070019013, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019014, 400070019014, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019015, 400070019015, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019016, 400070019016, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019017, 400070019017, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019018, 400070019018, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019019, 400070019019, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019020, 400070019020, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019021, 400070019021, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019022, 400070019022, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019023, 400070019023, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019024, 400070019024, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019025, 400070019025, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019026, 400070019026, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019027, 400070019027, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019028, 400070019028, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019029, 400070019029, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019030, 400070019030, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019031, 400070019031, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019032, 400070019032, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019033, 400070019033, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019034, 400070019034, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019035, 400070019035, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019036, 400070019036, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019037, 400070019037, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019038, 400070019038, 125.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019039, 400070019039, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019040, 400070019040, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019041, 400070019041, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019042, 400070019042, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019043, 400070019043, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019044, 400070019044, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019045, 400070019045, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019046, 400070019046, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019047, 400070019047, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019048, 400070019048, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019049, 400070019049, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019050, 400070019050, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019051, 400070019051, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019052, 400070019052, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019053, 400070019053, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019054, 400070019054, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019055, 400070019055, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019056, 400070019056, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019057, 400070019057, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019058, 400070019058, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019059, 400070019059, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019060, 400070019060, 550.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019061, 400070019061, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019062, 400070019062, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019063, 400070019063, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019064, 400070019064, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019065, 400070019065, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019066, 400070019066, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019067, 400070019067, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019068, 400070019071, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019069, 400070019072, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019070, 400070019073, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019071, 400070019074, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019072, 400070019075, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019073, 400070019076, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019074, 400070019077, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019075, 400070019078, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019076, 400070019079, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019077, 400070019080, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019078, 400070019081, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019079, 400070019082, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019080, 400070019083, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019081, 400070019084, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019082, 400070019085, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019083, 400070019086, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019084, 400070019087, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019085, 400070019088, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019086, 400070019089, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019087, 400070019090, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019088, 400070019091, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019089, 400070019092, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019090, 400070019093, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019091, 400070019094, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019092, 400070019095, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019093, 400070019096, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019094, 400070019097, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019095, 400070019098, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019096, 400070019099, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019097, 400070019100, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019098, 400070019101, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019099, 400070019102, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019100, 400070019103, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019101, 400070019104, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019102, 400070019105, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019103, 400070019106, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019104, 400070019107, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019105, 400070019108, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019106, 400070019109, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019107, 400070019110, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019108, 400070019111, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019109, 400070019112, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019110, 400070019113, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019111, 400070019114, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019112, 400070019115, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019113, 400070019116, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019114, 400070019117, 12.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019115, 400070019118, 15.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019116, 400070019119, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019117, 400070019120, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019118, 400070019121, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019119, 400070019122, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019120, 400070019123, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019121, 400070019124, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019122, 400070019125, 8.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019123, 400070019126, 10.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019124, 400070019127, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019125, 400070019128, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019126, 400070019129, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019127, 400070019130, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019128, 400070019131, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019129, 400070019132, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019130, 400070019133, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019131, 400070019134, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019132, 400070019135, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019133, 400070019136, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019134, 400070019137, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019135, 400070019138, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019136, 400070019139, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019137, 400070019140, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019138, 400070019141, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019139, 400070019142, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019140, 400070019143, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019141, 400070019144, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019142, 400070019145, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019143, 400070019146, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019144, 400070019147, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019145, 400070019148, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019146, 400070019149, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019147, 400070019150, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019148, 400070019151, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019149, 400070019152, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019150, 400070019153, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019151, 400070019154, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019152, 400070019155, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019153, 400070019156, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019154, 400070019157, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019155, 400070019158, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019156, 400070019159, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019157, 400070019160, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019158, 400070019161, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019159, 400070019162, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019160, 400070019163, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019161, 400070019164, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019162, 400070019165, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019163, 400070019166, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019164, 400070019167, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019165, 400070019168, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019166, 400070019169, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019167, 400070019170, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019168, 400070019171, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019169, 400070019172, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019170, 400070019173, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019171, 400070019174, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019172, 400070019175, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019173, 400070019176, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019174, 400070019177, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019175, 400070019178, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019176, 400070019179, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019177, 400070019180, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019178, 400070019181, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019179, 400070019182, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019180, 400070019183, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019181, 400070019184, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019182, 400070019185, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019183, 400070019186, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019184, 400070019187, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019185, 400070019188, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019186, 400070019189, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019187, 400070019190, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019188, 400070019191, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019189, 400070019192, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019190, 400070019193, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019191, 400070019194, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019192, 400070019195, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019193, 400070019196, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019194, 400070019197, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019195, 400070019198, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019196, 400070019199, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019197, 400070019200, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019198, 400070019201, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019199, 400070019202, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019200, 400070019203, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019201, 400070019204, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019202, 400070019205, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019203, 400070019206, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019204, 400070019207, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019205, 400070019208, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019206, 400070019209, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019207, 400070019210, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019208, 400070019211, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019209, 400070019212, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019210, 400070019213, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019211, 400070019214, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019212, 400070019215, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019213, 400070019216, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019214, 400070019217, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019215, 400070019218, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019216, 400070019219, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019217, 400070019220, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019218, 400070019221, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019219, 400070019222, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019220, 400070019223, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019221, 400070019224, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019222, 400070019225, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019223, 400070019226, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019224, 400070019227, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019225, 400070019228, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019226, 400070019229, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019227, 400070019230, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019228, 400070019231, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019229, 400070019232, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019230, 400070019233, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019231, 400070019234, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019232, 400070019235, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019233, 400070019236, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019234, 400070019237, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019235, 400070019238, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019236, 400070019239, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019237, 400070019240, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019238, 400070019241, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019239, 400070019242, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019240, 400070019243, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019241, 400070019244, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019242, 400070019245, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019243, 400070019246, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019244, 400070019247, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019245, 400070019248, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019246, 400070019249, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019247, 400070019250, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019248, 400070019251, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019249, 400070019252, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019250, 400070019253, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019251, 400070019254, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019252, 400070019255, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019253, 400070019256, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019254, 400070019257, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019255, 400070019258, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019256, 400070019259, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019257, 400070019260, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019258, 400070019261, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019259, 400070019262, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019260, 400070019263, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019261, 400070019264, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019262, 400070019265, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019263, 400070019266, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019264, 400070019267, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019265, 400070019268, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019266, 400070019269, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019267, 400070019270, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019268, 400070019271, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019269, 400070019272, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019270, 400070019273, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019271, 400070019274, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019272, 400070019275, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019273, 400070019276, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019274, 400070019277, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019275, 400070019279, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019276, 400070019280, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019277, 400070019281, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019278, 400070019282, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019279, 400070019283, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019280, 400070019284, 15.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019281, 400070019285, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019282, 400070019286, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019283, 400070019287, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019284, 400070019288, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019285, 400070019289, 35.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'needs_review'),
    (400070019286, 400070019290, 1250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019287, 400070019291, 25.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019288, 400070019292, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019289, 400070019293, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified'),
    (400070019290, 400070019294, 10.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070019, 'unverified');

-- Price source (price-specific confidence, tracked separately from item confidence)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
VALUES
    (400070019001, 400070019, :extraction_batch_id, 0.95),
    (400070019002, 400070019, :extraction_batch_id, 0.95),
    (400070019003, 400070019, :extraction_batch_id, 0.95),
    (400070019004, 400070019, :extraction_batch_id, 0.6),
    (400070019005, 400070019, :extraction_batch_id, 0.6),
    (400070019006, 400070019, :extraction_batch_id, 0.6),
    (400070019007, 400070019, :extraction_batch_id, 0.6),
    (400070019008, 400070019, :extraction_batch_id, 0.6),
    (400070019009, 400070019, :extraction_batch_id, 0.6),
    (400070019010, 400070019, :extraction_batch_id, 0.95),
    (400070019011, 400070019, :extraction_batch_id, 0.95),
    (400070019012, 400070019, :extraction_batch_id, 0.95),
    (400070019013, 400070019, :extraction_batch_id, 0.95),
    (400070019014, 400070019, :extraction_batch_id, 0.95),
    (400070019015, 400070019, :extraction_batch_id, 0.95),
    (400070019016, 400070019, :extraction_batch_id, 0.95),
    (400070019017, 400070019, :extraction_batch_id, 0.95),
    (400070019018, 400070019, :extraction_batch_id, 0.95),
    (400070019019, 400070019, :extraction_batch_id, 0.6),
    (400070019020, 400070019, :extraction_batch_id, 0.6),
    (400070019021, 400070019, :extraction_batch_id, 0.95),
    (400070019022, 400070019, :extraction_batch_id, 0.95),
    (400070019023, 400070019, :extraction_batch_id, 0.95),
    (400070019024, 400070019, :extraction_batch_id, 0.95),
    (400070019025, 400070019, :extraction_batch_id, 0.95),
    (400070019026, 400070019, :extraction_batch_id, 0.95),
    (400070019027, 400070019, :extraction_batch_id, 0.95),
    (400070019028, 400070019, :extraction_batch_id, 0.95),
    (400070019029, 400070019, :extraction_batch_id, 0.95),
    (400070019030, 400070019, :extraction_batch_id, 0.95),
    (400070019031, 400070019, :extraction_batch_id, 0.95),
    (400070019032, 400070019, :extraction_batch_id, 0.95),
    (400070019033, 400070019, :extraction_batch_id, 0.95),
    (400070019034, 400070019, :extraction_batch_id, 0.95),
    (400070019035, 400070019, :extraction_batch_id, 0.95),
    (400070019036, 400070019, :extraction_batch_id, 0.95),
    (400070019037, 400070019, :extraction_batch_id, 0.95),
    (400070019038, 400070019, :extraction_batch_id, 0.95),
    (400070019039, 400070019, :extraction_batch_id, 0.95),
    (400070019040, 400070019, :extraction_batch_id, 0.6),
    (400070019041, 400070019, :extraction_batch_id, 0.6),
    (400070019042, 400070019, :extraction_batch_id, 0.6),
    (400070019043, 400070019, :extraction_batch_id, 0.6),
    (400070019044, 400070019, :extraction_batch_id, 0.95),
    (400070019045, 400070019, :extraction_batch_id, 0.95),
    (400070019046, 400070019, :extraction_batch_id, 0.95),
    (400070019047, 400070019, :extraction_batch_id, 0.95),
    (400070019048, 400070019, :extraction_batch_id, 0.95),
    (400070019049, 400070019, :extraction_batch_id, 0.95),
    (400070019050, 400070019, :extraction_batch_id, 0.95),
    (400070019051, 400070019, :extraction_batch_id, 0.95),
    (400070019052, 400070019, :extraction_batch_id, 0.95),
    (400070019053, 400070019, :extraction_batch_id, 0.95),
    (400070019054, 400070019, :extraction_batch_id, 0.95),
    (400070019055, 400070019, :extraction_batch_id, 0.95),
    (400070019056, 400070019, :extraction_batch_id, 0.95),
    (400070019057, 400070019, :extraction_batch_id, 0.95),
    (400070019058, 400070019, :extraction_batch_id, 0.95),
    (400070019059, 400070019, :extraction_batch_id, 0.95),
    (400070019060, 400070019, :extraction_batch_id, 0.95),
    (400070019061, 400070019, :extraction_batch_id, 0.95),
    (400070019062, 400070019, :extraction_batch_id, 0.95),
    (400070019063, 400070019, :extraction_batch_id, 0.95),
    (400070019064, 400070019, :extraction_batch_id, 0.95),
    (400070019065, 400070019, :extraction_batch_id, 0.95),
    (400070019066, 400070019, :extraction_batch_id, 0.95),
    (400070019067, 400070019, :extraction_batch_id, 0.95),
    (400070019068, 400070019, :extraction_batch_id, 0.95),
    (400070019069, 400070019, :extraction_batch_id, 0.95),
    (400070019070, 400070019, :extraction_batch_id, 0.95),
    (400070019071, 400070019, :extraction_batch_id, 0.95),
    (400070019072, 400070019, :extraction_batch_id, 0.95),
    (400070019073, 400070019, :extraction_batch_id, 0.95),
    (400070019074, 400070019, :extraction_batch_id, 0.95),
    (400070019075, 400070019, :extraction_batch_id, 0.95),
    (400070019076, 400070019, :extraction_batch_id, 0.95),
    (400070019077, 400070019, :extraction_batch_id, 0.95),
    (400070019078, 400070019, :extraction_batch_id, 0.95),
    (400070019079, 400070019, :extraction_batch_id, 0.95),
    (400070019080, 400070019, :extraction_batch_id, 0.95),
    (400070019081, 400070019, :extraction_batch_id, 0.95),
    (400070019082, 400070019, :extraction_batch_id, 0.95),
    (400070019083, 400070019, :extraction_batch_id, 0.95),
    (400070019084, 400070019, :extraction_batch_id, 0.95),
    (400070019085, 400070019, :extraction_batch_id, 0.95),
    (400070019086, 400070019, :extraction_batch_id, 0.95),
    (400070019087, 400070019, :extraction_batch_id, 0.95),
    (400070019088, 400070019, :extraction_batch_id, 0.95),
    (400070019089, 400070019, :extraction_batch_id, 0.95),
    (400070019090, 400070019, :extraction_batch_id, 0.95),
    (400070019091, 400070019, :extraction_batch_id, 0.95),
    (400070019092, 400070019, :extraction_batch_id, 0.95),
    (400070019093, 400070019, :extraction_batch_id, 0.95),
    (400070019094, 400070019, :extraction_batch_id, 0.95),
    (400070019095, 400070019, :extraction_batch_id, 0.95),
    (400070019096, 400070019, :extraction_batch_id, 0.95),
    (400070019097, 400070019, :extraction_batch_id, 0.95),
    (400070019098, 400070019, :extraction_batch_id, 0.95),
    (400070019099, 400070019, :extraction_batch_id, 0.95),
    (400070019100, 400070019, :extraction_batch_id, 0.95),
    (400070019101, 400070019, :extraction_batch_id, 0.95),
    (400070019102, 400070019, :extraction_batch_id, 0.95),
    (400070019103, 400070019, :extraction_batch_id, 0.95),
    (400070019104, 400070019, :extraction_batch_id, 0.95),
    (400070019105, 400070019, :extraction_batch_id, 0.95),
    (400070019106, 400070019, :extraction_batch_id, 0.95),
    (400070019107, 400070019, :extraction_batch_id, 0.95),
    (400070019108, 400070019, :extraction_batch_id, 0.95),
    (400070019109, 400070019, :extraction_batch_id, 0.95),
    (400070019110, 400070019, :extraction_batch_id, 0.95),
    (400070019111, 400070019, :extraction_batch_id, 0.95),
    (400070019112, 400070019, :extraction_batch_id, 0.95),
    (400070019113, 400070019, :extraction_batch_id, 0.95),
    (400070019114, 400070019, :extraction_batch_id, 0.95),
    (400070019115, 400070019, :extraction_batch_id, 0.95),
    (400070019116, 400070019, :extraction_batch_id, 0.95),
    (400070019117, 400070019, :extraction_batch_id, 0.95),
    (400070019118, 400070019, :extraction_batch_id, 0.95),
    (400070019119, 400070019, :extraction_batch_id, 0.95),
    (400070019120, 400070019, :extraction_batch_id, 0.95),
    (400070019121, 400070019, :extraction_batch_id, 0.95),
    (400070019122, 400070019, :extraction_batch_id, 0.95),
    (400070019123, 400070019, :extraction_batch_id, 0.95),
    (400070019124, 400070019, :extraction_batch_id, 0.95),
    (400070019125, 400070019, :extraction_batch_id, 0.95),
    (400070019126, 400070019, :extraction_batch_id, 0.95),
    (400070019127, 400070019, :extraction_batch_id, 0.95),
    (400070019128, 400070019, :extraction_batch_id, 0.95),
    (400070019129, 400070019, :extraction_batch_id, 0.6),
    (400070019130, 400070019, :extraction_batch_id, 0.6),
    (400070019131, 400070019, :extraction_batch_id, 0.95),
    (400070019132, 400070019, :extraction_batch_id, 0.95),
    (400070019133, 400070019, :extraction_batch_id, 0.95),
    (400070019134, 400070019, :extraction_batch_id, 0.95),
    (400070019135, 400070019, :extraction_batch_id, 0.95),
    (400070019136, 400070019, :extraction_batch_id, 0.95),
    (400070019137, 400070019, :extraction_batch_id, 0.95),
    (400070019138, 400070019, :extraction_batch_id, 0.95),
    (400070019139, 400070019, :extraction_batch_id, 0.95),
    (400070019140, 400070019, :extraction_batch_id, 0.95),
    (400070019141, 400070019, :extraction_batch_id, 0.95),
    (400070019142, 400070019, :extraction_batch_id, 0.95),
    (400070019143, 400070019, :extraction_batch_id, 0.95),
    (400070019144, 400070019, :extraction_batch_id, 0.95),
    (400070019145, 400070019, :extraction_batch_id, 0.95),
    (400070019146, 400070019, :extraction_batch_id, 0.95),
    (400070019147, 400070019, :extraction_batch_id, 0.95),
    (400070019148, 400070019, :extraction_batch_id, 0.95),
    (400070019149, 400070019, :extraction_batch_id, 0.6),
    (400070019150, 400070019, :extraction_batch_id, 0.6),
    (400070019151, 400070019, :extraction_batch_id, 0.6),
    (400070019152, 400070019, :extraction_batch_id, 0.6),
    (400070019153, 400070019, :extraction_batch_id, 0.6),
    (400070019154, 400070019, :extraction_batch_id, 0.6),
    (400070019155, 400070019, :extraction_batch_id, 0.95),
    (400070019156, 400070019, :extraction_batch_id, 0.95),
    (400070019157, 400070019, :extraction_batch_id, 0.95),
    (400070019158, 400070019, :extraction_batch_id, 0.95),
    (400070019159, 400070019, :extraction_batch_id, 0.95),
    (400070019160, 400070019, :extraction_batch_id, 0.95),
    (400070019161, 400070019, :extraction_batch_id, 0.95),
    (400070019162, 400070019, :extraction_batch_id, 0.95),
    (400070019163, 400070019, :extraction_batch_id, 0.95),
    (400070019164, 400070019, :extraction_batch_id, 0.6),
    (400070019165, 400070019, :extraction_batch_id, 0.6),
    (400070019166, 400070019, :extraction_batch_id, 0.6),
    (400070019167, 400070019, :extraction_batch_id, 0.6),
    (400070019168, 400070019, :extraction_batch_id, 0.6),
    (400070019169, 400070019, :extraction_batch_id, 0.6),
    (400070019170, 400070019, :extraction_batch_id, 0.6),
    (400070019171, 400070019, :extraction_batch_id, 0.6),
    (400070019172, 400070019, :extraction_batch_id, 0.6),
    (400070019173, 400070019, :extraction_batch_id, 0.6),
    (400070019174, 400070019, :extraction_batch_id, 0.95),
    (400070019175, 400070019, :extraction_batch_id, 0.95),
    (400070019176, 400070019, :extraction_batch_id, 0.95),
    (400070019177, 400070019, :extraction_batch_id, 0.95),
    (400070019178, 400070019, :extraction_batch_id, 0.95),
    (400070019179, 400070019, :extraction_batch_id, 0.6),
    (400070019180, 400070019, :extraction_batch_id, 0.6),
    (400070019181, 400070019, :extraction_batch_id, 0.95),
    (400070019182, 400070019, :extraction_batch_id, 0.95),
    (400070019183, 400070019, :extraction_batch_id, 0.95),
    (400070019184, 400070019, :extraction_batch_id, 0.95),
    (400070019185, 400070019, :extraction_batch_id, 0.95),
    (400070019186, 400070019, :extraction_batch_id, 0.95),
    (400070019187, 400070019, :extraction_batch_id, 0.95),
    (400070019188, 400070019, :extraction_batch_id, 0.95),
    (400070019189, 400070019, :extraction_batch_id, 0.95),
    (400070019190, 400070019, :extraction_batch_id, 0.95),
    (400070019191, 400070019, :extraction_batch_id, 0.95),
    (400070019192, 400070019, :extraction_batch_id, 0.95),
    (400070019193, 400070019, :extraction_batch_id, 0.95),
    (400070019194, 400070019, :extraction_batch_id, 0.95),
    (400070019195, 400070019, :extraction_batch_id, 0.95),
    (400070019196, 400070019, :extraction_batch_id, 0.95),
    (400070019197, 400070019, :extraction_batch_id, 0.95),
    (400070019198, 400070019, :extraction_batch_id, 0.95),
    (400070019199, 400070019, :extraction_batch_id, 0.95),
    (400070019200, 400070019, :extraction_batch_id, 0.95),
    (400070019201, 400070019, :extraction_batch_id, 0.95),
    (400070019202, 400070019, :extraction_batch_id, 0.95),
    (400070019203, 400070019, :extraction_batch_id, 0.95),
    (400070019204, 400070019, :extraction_batch_id, 0.95),
    (400070019205, 400070019, :extraction_batch_id, 0.95),
    (400070019206, 400070019, :extraction_batch_id, 0.95),
    (400070019207, 400070019, :extraction_batch_id, 0.95),
    (400070019208, 400070019, :extraction_batch_id, 0.95),
    (400070019209, 400070019, :extraction_batch_id, 0.6),
    (400070019210, 400070019, :extraction_batch_id, 0.6),
    (400070019211, 400070019, :extraction_batch_id, 0.6),
    (400070019212, 400070019, :extraction_batch_id, 0.6),
    (400070019213, 400070019, :extraction_batch_id, 0.95),
    (400070019214, 400070019, :extraction_batch_id, 0.6),
    (400070019215, 400070019, :extraction_batch_id, 0.6),
    (400070019216, 400070019, :extraction_batch_id, 0.95),
    (400070019217, 400070019, :extraction_batch_id, 0.95),
    (400070019218, 400070019, :extraction_batch_id, 0.95),
    (400070019219, 400070019, :extraction_batch_id, 0.95),
    (400070019220, 400070019, :extraction_batch_id, 0.95),
    (400070019221, 400070019, :extraction_batch_id, 0.6),
    (400070019222, 400070019, :extraction_batch_id, 0.6),
    (400070019223, 400070019, :extraction_batch_id, 0.6),
    (400070019224, 400070019, :extraction_batch_id, 0.6),
    (400070019225, 400070019, :extraction_batch_id, 0.6),
    (400070019226, 400070019, :extraction_batch_id, 0.6),
    (400070019227, 400070019, :extraction_batch_id, 0.6),
    (400070019228, 400070019, :extraction_batch_id, 0.6),
    (400070019229, 400070019, :extraction_batch_id, 0.95),
    (400070019230, 400070019, :extraction_batch_id, 0.95),
    (400070019231, 400070019, :extraction_batch_id, 0.95),
    (400070019232, 400070019, :extraction_batch_id, 0.95),
    (400070019233, 400070019, :extraction_batch_id, 0.95),
    (400070019234, 400070019, :extraction_batch_id, 0.95),
    (400070019235, 400070019, :extraction_batch_id, 0.95),
    (400070019236, 400070019, :extraction_batch_id, 0.6),
    (400070019237, 400070019, :extraction_batch_id, 0.6),
    (400070019238, 400070019, :extraction_batch_id, 0.95),
    (400070019239, 400070019, :extraction_batch_id, 0.6),
    (400070019240, 400070019, :extraction_batch_id, 0.6),
    (400070019241, 400070019, :extraction_batch_id, 0.95),
    (400070019242, 400070019, :extraction_batch_id, 0.95),
    (400070019243, 400070019, :extraction_batch_id, 0.95),
    (400070019244, 400070019, :extraction_batch_id, 0.95),
    (400070019245, 400070019, :extraction_batch_id, 0.95),
    (400070019246, 400070019, :extraction_batch_id, 0.95),
    (400070019247, 400070019, :extraction_batch_id, 0.6),
    (400070019248, 400070019, :extraction_batch_id, 0.6),
    (400070019249, 400070019, :extraction_batch_id, 0.95),
    (400070019250, 400070019, :extraction_batch_id, 0.95),
    (400070019251, 400070019, :extraction_batch_id, 0.6),
    (400070019252, 400070019, :extraction_batch_id, 0.6),
    (400070019253, 400070019, :extraction_batch_id, 0.6),
    (400070019254, 400070019, :extraction_batch_id, 0.6),
    (400070019255, 400070019, :extraction_batch_id, 0.6),
    (400070019256, 400070019, :extraction_batch_id, 0.6),
    (400070019257, 400070019, :extraction_batch_id, 0.6),
    (400070019258, 400070019, :extraction_batch_id, 0.6),
    (400070019259, 400070019, :extraction_batch_id, 0.95),
    (400070019260, 400070019, :extraction_batch_id, 0.95),
    (400070019261, 400070019, :extraction_batch_id, 0.95),
    (400070019262, 400070019, :extraction_batch_id, 0.95),
    (400070019263, 400070019, :extraction_batch_id, 0.95),
    (400070019264, 400070019, :extraction_batch_id, 0.95),
    (400070019265, 400070019, :extraction_batch_id, 0.95),
    (400070019266, 400070019, :extraction_batch_id, 0.95),
    (400070019267, 400070019, :extraction_batch_id, 0.95),
    (400070019268, 400070019, :extraction_batch_id, 0.95),
    (400070019269, 400070019, :extraction_batch_id, 0.6),
    (400070019270, 400070019, :extraction_batch_id, 0.6),
    (400070019271, 400070019, :extraction_batch_id, 0.6),
    (400070019272, 400070019, :extraction_batch_id, 0.6),
    (400070019273, 400070019, :extraction_batch_id, 0.95),
    (400070019274, 400070019, :extraction_batch_id, 0.95),
    (400070019275, 400070019, :extraction_batch_id, 0.95),
    (400070019276, 400070019, :extraction_batch_id, 0.6),
    (400070019277, 400070019, :extraction_batch_id, 0.6),
    (400070019278, 400070019, :extraction_batch_id, 0.95),
    (400070019279, 400070019, :extraction_batch_id, 0.95),
    (400070019280, 400070019, :extraction_batch_id, 0.6),
    (400070019281, 400070019, :extraction_batch_id, 0.6),
    (400070019282, 400070019, :extraction_batch_id, 0.6),
    (400070019283, 400070019, :extraction_batch_id, 0.6),
    (400070019284, 400070019, :extraction_batch_id, 0.6),
    (400070019285, 400070019, :extraction_batch_id, 0.6),
    (400070019286, 400070019, :extraction_batch_id, 0.95),
    (400070019287, 400070019, :extraction_batch_id, 0.95),
    (400070019288, 400070019, :extraction_batch_id, 0.95),
    (400070019289, 400070019, :extraction_batch_id, 0.95),
    (400070019290, 400070019, :extraction_batch_id, 0.95);

-- Board <-> item mapping
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
VALUES
    (400070019001, 400070019, 400070019001, 400070019001, 400070019001, 1),
    (400070019002, 400070019, 400070019001, 400070019002, 400070019001, 2),
    (400070019003, 400070019, 400070019001, 400070019003, 400070019001, 3),
    (400070019004, 400070019, 400070019001, 400070019004, 400070019001, 4),
    (400070019005, 400070019, 400070019001, 400070019005, 400070019001, 5),
    (400070019006, 400070019, 400070019001, 400070019006, 400070019001, 6),
    (400070019007, 400070019, 400070019001, 400070019007, 400070019002, 1),
    (400070019008, 400070019, 400070019001, 400070019008, 400070019002, 2),
    (400070019009, 400070019, 400070019001, 400070019009, 400070019002, 3),
    (400070019010, 400070019, 400070019001, 400070019010, 400070019003, 1),
    (400070019011, 400070019, 400070019001, 400070019011, 400070019003, 2),
    (400070019012, 400070019, 400070019001, 400070019012, 400070019003, 3),
    (400070019013, 400070019, 400070019001, 400070019013, 400070019003, 4),
    (400070019014, 400070019, 400070019001, 400070019014, 400070019003, 5),
    (400070019015, 400070019, 400070019001, 400070019015, 400070019003, 6),
    (400070019016, 400070019, 400070019001, 400070019016, 400070019003, 7),
    (400070019017, 400070019, 400070019001, 400070019017, 400070019003, 8),
    (400070019018, 400070019, 400070019001, 400070019018, 400070019003, 9),
    (400070019019, 400070019, 400070019001, 400070019019, 400070019003, 10),
    (400070019020, 400070019, 400070019001, 400070019020, 400070019003, 11),
    (400070019021, 400070019, 400070019001, 400070019021, 400070019003, 12),
    (400070019022, 400070019, 400070019001, 400070019022, 400070019003, 13),
    (400070019023, 400070019, 400070019001, 400070019023, 400070019003, 14),
    (400070019024, 400070019, 400070019001, 400070019024, 400070019003, 15),
    (400070019025, 400070019, 400070019001, 400070019025, 400070019003, 16),
    (400070019026, 400070019, 400070019001, 400070019026, 400070019003, 17),
    (400070019027, 400070019, 400070019001, 400070019027, 400070019003, 18),
    (400070019028, 400070019, 400070019001, 400070019028, 400070019003, 19),
    (400070019029, 400070019, 400070019001, 400070019029, 400070019003, 20),
    (400070019030, 400070019, 400070019001, 400070019030, 400070019004, 1),
    (400070019031, 400070019, 400070019001, 400070019031, 400070019004, 2),
    (400070019032, 400070019, 400070019001, 400070019032, 400070019004, 3),
    (400070019033, 400070019, 400070019001, 400070019033, 400070019004, 4),
    (400070019034, 400070019, 400070019001, 400070019034, 400070019005, 1),
    (400070019035, 400070019, 400070019001, 400070019035, 400070019005, 2),
    (400070019036, 400070019, 400070019001, 400070019036, 400070019005, 3),
    (400070019037, 400070019, 400070019001, 400070019037, 400070019005, 4),
    (400070019038, 400070019, 400070019001, 400070019038, 400070019005, 5),
    (400070019039, 400070019, 400070019001, 400070019039, 400070019005, 6),
    (400070019040, 400070019, 400070019001, 400070019040, 400070019005, 7),
    (400070019041, 400070019, 400070019001, 400070019041, 400070019005, 8),
    (400070019042, 400070019, 400070019001, 400070019042, 400070019005, 9),
    (400070019043, 400070019, 400070019001, 400070019043, 400070019005, 10),
    (400070019044, 400070019, 400070019001, 400070019044, 400070019005, 11),
    (400070019045, 400070019, 400070019001, 400070019045, 400070019005, 12),
    (400070019046, 400070019, 400070019001, 400070019046, 400070019005, 13),
    (400070019047, 400070019, 400070019001, 400070019047, 400070019005, 14),
    (400070019048, 400070019, 400070019001, 400070019048, 400070019005, 15),
    (400070019049, 400070019, 400070019001, 400070019049, 400070019005, 16),
    (400070019050, 400070019, 400070019001, 400070019050, 400070019005, 17),
    (400070019051, 400070019, 400070019001, 400070019051, 400070019005, 18),
    (400070019052, 400070019, 400070019001, 400070019052, 400070019005, 19),
    (400070019053, 400070019, 400070019001, 400070019053, 400070019005, 20),
    (400070019054, 400070019, 400070019001, 400070019054, 400070019005, 21),
    (400070019055, 400070019, 400070019001, 400070019055, 400070019005, 22),
    (400070019056, 400070019, 400070019001, 400070019056, 400070019005, 23),
    (400070019057, 400070019, 400070019001, 400070019057, 400070019005, 24),
    (400070019058, 400070019, 400070019001, 400070019058, 400070019005, 25),
    (400070019059, 400070019, 400070019001, 400070019059, 400070019005, 26),
    (400070019060, 400070019, 400070019001, 400070019060, 400070019006, 1),
    (400070019061, 400070019, 400070019001, 400070019061, 400070019006, 2),
    (400070019062, 400070019, 400070019001, 400070019062, 400070019006, 3),
    (400070019063, 400070019, 400070019001, 400070019063, 400070019006, 4),
    (400070019064, 400070019, 400070019001, 400070019064, 400070019006, 5),
    (400070019065, 400070019, 400070019001, 400070019065, 400070019006, 6),
    (400070019066, 400070019, 400070019001, 400070019066, 400070019006, 7),
    (400070019067, 400070019, 400070019001, 400070019067, 400070019006, 8),
    (400070019068, 400070019, 400070019001, 400070019068, 400070019007, 1),
    (400070019069, 400070019, 400070019001, 400070019069, 400070019007, 2),
    (400070019070, 400070019, 400070019001, 400070019070, 400070019007, 3),
    (400070019071, 400070019, 400070019001, 400070019071, 400070019008, 1),
    (400070019072, 400070019, 400070019001, 400070019072, 400070019008, 2),
    (400070019073, 400070019, 400070019001, 400070019073, 400070019008, 3),
    (400070019074, 400070019, 400070019001, 400070019074, 400070019008, 4),
    (400070019075, 400070019, 400070019001, 400070019075, 400070019008, 5),
    (400070019076, 400070019, 400070019001, 400070019076, 400070019008, 6),
    (400070019077, 400070019, 400070019001, 400070019077, 400070019008, 7),
    (400070019078, 400070019, 400070019001, 400070019078, 400070019008, 8),
    (400070019079, 400070019, 400070019001, 400070019079, 400070019008, 9),
    (400070019080, 400070019, 400070019001, 400070019080, 400070019008, 10),
    (400070019081, 400070019, 400070019001, 400070019081, 400070019008, 11),
    (400070019082, 400070019, 400070019001, 400070019082, 400070019008, 12),
    (400070019083, 400070019, 400070019001, 400070019083, 400070019008, 13),
    (400070019084, 400070019, 400070019001, 400070019084, 400070019008, 14),
    (400070019085, 400070019, 400070019001, 400070019085, 400070019008, 15),
    (400070019086, 400070019, 400070019001, 400070019086, 400070019008, 16),
    (400070019087, 400070019, 400070019001, 400070019087, 400070019008, 17),
    (400070019088, 400070019, 400070019001, 400070019088, 400070019008, 18),
    (400070019089, 400070019, 400070019001, 400070019089, 400070019009, 1),
    (400070019090, 400070019, 400070019001, 400070019090, 400070019009, 2),
    (400070019091, 400070019, 400070019001, 400070019091, 400070019009, 3),
    (400070019092, 400070019, 400070019001, 400070019092, 400070019009, 4),
    (400070019093, 400070019, 400070019001, 400070019093, 400070019009, 5),
    (400070019094, 400070019, 400070019001, 400070019094, 400070019009, 6),
    (400070019095, 400070019, 400070019001, 400070019095, 400070019009, 7),
    (400070019096, 400070019, 400070019001, 400070019096, 400070019009, 8),
    (400070019097, 400070019, 400070019001, 400070019097, 400070019009, 9),
    (400070019098, 400070019, 400070019001, 400070019098, 400070019009, 10),
    (400070019099, 400070019, 400070019001, 400070019099, 400070019009, 11),
    (400070019100, 400070019, 400070019001, 400070019100, 400070019009, 12),
    (400070019101, 400070019, 400070019001, 400070019101, 400070019009, 13),
    (400070019102, 400070019, 400070019001, 400070019102, 400070019009, 14),
    (400070019103, 400070019, 400070019001, 400070019103, 400070019009, 15),
    (400070019104, 400070019, 400070019001, 400070019104, 400070019009, 16),
    (400070019105, 400070019, 400070019001, 400070019105, 400070019009, 17),
    (400070019106, 400070019, 400070019001, 400070019106, 400070019009, 18),
    (400070019107, 400070019, 400070019001, 400070019107, 400070019009, 19),
    (400070019108, 400070019, 400070019001, 400070019108, 400070019009, 20),
    (400070019109, 400070019, 400070019001, 400070019109, 400070019010, 1),
    (400070019110, 400070019, 400070019001, 400070019110, 400070019010, 2),
    (400070019111, 400070019, 400070019001, 400070019111, 400070019010, 3),
    (400070019112, 400070019, 400070019001, 400070019112, 400070019010, 4),
    (400070019113, 400070019, 400070019001, 400070019113, 400070019010, 5),
    (400070019114, 400070019, 400070019001, 400070019114, 400070019010, 6),
    (400070019115, 400070019, 400070019001, 400070019115, 400070019010, 7),
    (400070019116, 400070019, 400070019001, 400070019116, 400070019010, 8),
    (400070019117, 400070019, 400070019001, 400070019117, 400070019010, 9),
    (400070019118, 400070019, 400070019001, 400070019118, 400070019010, 10),
    (400070019119, 400070019, 400070019001, 400070019119, 400070019011, 1),
    (400070019120, 400070019, 400070019001, 400070019120, 400070019011, 2),
    (400070019121, 400070019, 400070019001, 400070019121, 400070019011, 3),
    (400070019122, 400070019, 400070019001, 400070019122, 400070019011, 4),
    (400070019123, 400070019, 400070019001, 400070019123, 400070019011, 5),
    (400070019124, 400070019, 400070019001, 400070019124, 400070019012, 1),
    (400070019125, 400070019, 400070019001, 400070019125, 400070019012, 2),
    (400070019126, 400070019, 400070019001, 400070019126, 400070019012, 3),
    (400070019127, 400070019, 400070019001, 400070019127, 400070019012, 4),
    (400070019128, 400070019, 400070019001, 400070019128, 400070019012, 5),
    (400070019129, 400070019, 400070019001, 400070019129, 400070019012, 6),
    (400070019130, 400070019, 400070019001, 400070019130, 400070019012, 7),
    (400070019131, 400070019, 400070019001, 400070019131, 400070019012, 8),
    (400070019132, 400070019, 400070019001, 400070019132, 400070019012, 9),
    (400070019133, 400070019, 400070019001, 400070019133, 400070019012, 10),
    (400070019134, 400070019, 400070019001, 400070019134, 400070019012, 11),
    (400070019135, 400070019, 400070019001, 400070019135, 400070019012, 12),
    (400070019136, 400070019, 400070019001, 400070019136, 400070019012, 13),
    (400070019137, 400070019, 400070019001, 400070019137, 400070019012, 14),
    (400070019138, 400070019, 400070019001, 400070019138, 400070019012, 15),
    (400070019139, 400070019, 400070019001, 400070019139, 400070019012, 16),
    (400070019140, 400070019, 400070019001, 400070019140, 400070019012, 17),
    (400070019141, 400070019, 400070019001, 400070019141, 400070019012, 18),
    (400070019142, 400070019, 400070019001, 400070019142, 400070019012, 19),
    (400070019143, 400070019, 400070019001, 400070019143, 400070019012, 20),
    (400070019144, 400070019, 400070019001, 400070019144, 400070019012, 21),
    (400070019145, 400070019, 400070019001, 400070019145, 400070019012, 22),
    (400070019146, 400070019, 400070019001, 400070019146, 400070019013, 1),
    (400070019147, 400070019, 400070019001, 400070019147, 400070019013, 2),
    (400070019148, 400070019, 400070019001, 400070019148, 400070019013, 3),
    (400070019149, 400070019, 400070019001, 400070019149, 400070019013, 4),
    (400070019150, 400070019, 400070019001, 400070019150, 400070019013, 5),
    (400070019151, 400070019, 400070019001, 400070019151, 400070019013, 6),
    (400070019152, 400070019, 400070019001, 400070019152, 400070019013, 7),
    (400070019153, 400070019, 400070019001, 400070019153, 400070019013, 8),
    (400070019154, 400070019, 400070019001, 400070019154, 400070019013, 9),
    (400070019155, 400070019, 400070019001, 400070019155, 400070019014, 1),
    (400070019156, 400070019, 400070019001, 400070019156, 400070019014, 2),
    (400070019157, 400070019, 400070019001, 400070019157, 400070019014, 3),
    (400070019158, 400070019, 400070019001, 400070019158, 400070019014, 4),
    (400070019159, 400070019, 400070019001, 400070019159, 400070019014, 5),
    (400070019160, 400070019, 400070019001, 400070019160, 400070019014, 6),
    (400070019161, 400070019, 400070019001, 400070019161, 400070019014, 7),
    (400070019162, 400070019, 400070019001, 400070019162, 400070019014, 8),
    (400070019163, 400070019, 400070019001, 400070019163, 400070019014, 9),
    (400070019164, 400070019, 400070019001, 400070019164, 400070019014, 10),
    (400070019165, 400070019, 400070019001, 400070019165, 400070019014, 11),
    (400070019166, 400070019, 400070019001, 400070019166, 400070019014, 12),
    (400070019167, 400070019, 400070019001, 400070019167, 400070019014, 13),
    (400070019168, 400070019, 400070019001, 400070019168, 400070019014, 14),
    (400070019169, 400070019, 400070019001, 400070019169, 400070019014, 15),
    (400070019170, 400070019, 400070019001, 400070019170, 400070019014, 16),
    (400070019171, 400070019, 400070019001, 400070019171, 400070019015, 1),
    (400070019172, 400070019, 400070019001, 400070019172, 400070019015, 2),
    (400070019173, 400070019, 400070019001, 400070019173, 400070019015, 3),
    (400070019174, 400070019, 400070019001, 400070019174, 400070019015, 4),
    (400070019175, 400070019, 400070019001, 400070019175, 400070019015, 5),
    (400070019176, 400070019, 400070019001, 400070019176, 400070019015, 6),
    (400070019177, 400070019, 400070019001, 400070019177, 400070019016, 1),
    (400070019178, 400070019, 400070019001, 400070019178, 400070019016, 2),
    (400070019179, 400070019, 400070019001, 400070019179, 400070019016, 3),
    (400070019180, 400070019, 400070019001, 400070019180, 400070019016, 4),
    (400070019181, 400070019, 400070019001, 400070019181, 400070019016, 5),
    (400070019182, 400070019, 400070019001, 400070019182, 400070019016, 6),
    (400070019183, 400070019, 400070019001, 400070019183, 400070019016, 7),
    (400070019184, 400070019, 400070019001, 400070019184, 400070019017, 1),
    (400070019185, 400070019, 400070019001, 400070019185, 400070019017, 2),
    (400070019186, 400070019, 400070019001, 400070019186, 400070019017, 3),
    (400070019187, 400070019, 400070019001, 400070019187, 400070019017, 4),
    (400070019188, 400070019, 400070019001, 400070019188, 400070019017, 5),
    (400070019189, 400070019, 400070019001, 400070019189, 400070019017, 6),
    (400070019190, 400070019, 400070019001, 400070019190, 400070019017, 7),
    (400070019191, 400070019, 400070019001, 400070019191, 400070019017, 8),
    (400070019192, 400070019, 400070019001, 400070019192, 400070019018, 1),
    (400070019193, 400070019, 400070019001, 400070019193, 400070019018, 2),
    (400070019194, 400070019, 400070019001, 400070019194, 400070019018, 3),
    (400070019195, 400070019, 400070019001, 400070019195, 400070019018, 4),
    (400070019196, 400070019, 400070019001, 400070019196, 400070019018, 5),
    (400070019197, 400070019, 400070019001, 400070019197, 400070019018, 6),
    (400070019198, 400070019, 400070019001, 400070019198, 400070019018, 7),
    (400070019199, 400070019, 400070019001, 400070019199, 400070019018, 8),
    (400070019200, 400070019, 400070019001, 400070019200, 400070019018, 9),
    (400070019201, 400070019, 400070019001, 400070019201, 400070019018, 10),
    (400070019202, 400070019, 400070019001, 400070019202, 400070019018, 11),
    (400070019203, 400070019, 400070019001, 400070019203, 400070019018, 12),
    (400070019204, 400070019, 400070019001, 400070019204, 400070019018, 13),
    (400070019205, 400070019, 400070019001, 400070019205, 400070019018, 14),
    (400070019206, 400070019, 400070019001, 400070019206, 400070019018, 15),
    (400070019207, 400070019, 400070019001, 400070019207, 400070019018, 16),
    (400070019208, 400070019, 400070019001, 400070019208, 400070019018, 17),
    (400070019209, 400070019, 400070019001, 400070019209, 400070019019, 1),
    (400070019210, 400070019, 400070019001, 400070019210, 400070019019, 2),
    (400070019211, 400070019, 400070019001, 400070019211, 400070019019, 3),
    (400070019212, 400070019, 400070019001, 400070019212, 400070019019, 4),
    (400070019213, 400070019, 400070019001, 400070019213, 400070019019, 5),
    (400070019214, 400070019, 400070019001, 400070019214, 400070019019, 6),
    (400070019215, 400070019, 400070019001, 400070019215, 400070019019, 7),
    (400070019216, 400070019, 400070019001, 400070019216, 400070019019, 8),
    (400070019217, 400070019, 400070019001, 400070019217, 400070019019, 9),
    (400070019218, 400070019, 400070019001, 400070019218, 400070019019, 10),
    (400070019219, 400070019, 400070019001, 400070019219, 400070019019, 11),
    (400070019220, 400070019, 400070019001, 400070019220, 400070019019, 12),
    (400070019221, 400070019, 400070019001, 400070019221, 400070019019, 13),
    (400070019222, 400070019, 400070019001, 400070019222, 400070019019, 14),
    (400070019223, 400070019, 400070019001, 400070019223, 400070019019, 15),
    (400070019224, 400070019, 400070019001, 400070019224, 400070019019, 16),
    (400070019225, 400070019, 400070019001, 400070019225, 400070019020, 1),
    (400070019226, 400070019, 400070019001, 400070019226, 400070019020, 2),
    (400070019227, 400070019, 400070019001, 400070019227, 400070019020, 3),
    (400070019228, 400070019, 400070019001, 400070019228, 400070019020, 4),
    (400070019229, 400070019, 400070019001, 400070019229, 400070019020, 5),
    (400070019230, 400070019, 400070019001, 400070019230, 400070019020, 6),
    (400070019231, 400070019, 400070019001, 400070019231, 400070019020, 7),
    (400070019232, 400070019, 400070019001, 400070019232, 400070019020, 8),
    (400070019233, 400070019, 400070019001, 400070019233, 400070019020, 9),
    (400070019234, 400070019, 400070019001, 400070019234, 400070019020, 10),
    (400070019235, 400070019, 400070019001, 400070019235, 400070019020, 11),
    (400070019236, 400070019, 400070019001, 400070019236, 400070019020, 12),
    (400070019237, 400070019, 400070019001, 400070019237, 400070019020, 13),
    (400070019238, 400070019, 400070019001, 400070019238, 400070019020, 14),
    (400070019239, 400070019, 400070019001, 400070019239, 400070019020, 15),
    (400070019240, 400070019, 400070019001, 400070019240, 400070019020, 16),
    (400070019241, 400070019, 400070019001, 400070019241, 400070019020, 17),
    (400070019242, 400070019, 400070019001, 400070019242, 400070019020, 18),
    (400070019243, 400070019, 400070019001, 400070019243, 400070019021, 1),
    (400070019244, 400070019, 400070019001, 400070019244, 400070019021, 2),
    (400070019245, 400070019, 400070019001, 400070019245, 400070019021, 3),
    (400070019246, 400070019, 400070019001, 400070019246, 400070019021, 4),
    (400070019247, 400070019, 400070019001, 400070019247, 400070019021, 5),
    (400070019248, 400070019, 400070019001, 400070019248, 400070019021, 6),
    (400070019249, 400070019, 400070019001, 400070019249, 400070019021, 7),
    (400070019250, 400070019, 400070019001, 400070019250, 400070019021, 8),
    (400070019251, 400070019, 400070019001, 400070019251, 400070019022, 1),
    (400070019252, 400070019, 400070019001, 400070019252, 400070019023, 1),
    (400070019253, 400070019, 400070019001, 400070019253, 400070019023, 2),
    (400070019254, 400070019, 400070019001, 400070019254, 400070019023, 3),
    (400070019255, 400070019, 400070019001, 400070019255, 400070019023, 4);

-- === NEEDS-REVIEW ITEMS ===
-- menu_item_id 400070019001 (OMELET DOUBLE): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019004 (KHEEMA / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019004 (KHEEMA / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019005 (KHEEMA FRY / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019005 (KHEEMA FRY / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019006 (KHEEMA GHOTALA / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019006 (KHEEMA GHOTALA / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019014 (CHI. SCHEZWAN TANDOORI / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019014 (CHI. SCHEZWAN TANDOORI / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019019 (RESHMI KEBAB): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019020 (PAHADI KEBAB): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019021 (ACHARI KEBAB): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019022 (HAZAARI KEBAB): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019023 (BANJARA KEBAB): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019024 (KERALA KEBAB): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019026 (MALAI KEBAB): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019027 (CHESLI KEBAB): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019034 (CHICKEN MASALA FRY / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019034 (CHICKEN MASALA FRY / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019035 (CHICKEN MALABARI / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019035 (CHICKEN MALABARI / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019060 (FISH FRY / Regular): non-numeric price text in source: '(Seasonal Rate)' (market/seasonal price) (confidence 0.5)
-- menu_item_id 400070019061 (FISH CURRY / Regular): non-numeric price text in source: '(Seasonal Rate)' (market/seasonal price) (confidence 0.5)
-- menu_item_id 400070019062 (FISH TANDOORI / Regular): non-numeric price text in source: '(Seasonal Rate)' (market/seasonal price) (confidence 0.5)
-- menu_item_id 400070019124 (CHICKEN BIRYANI / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019124 (CHICKEN BIRYANI / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019143 (WHITE RICE): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019143 (WHITE RICE / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019143 (WHITE RICE / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019144 (BIRYANI RICE): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019144 (BIRYANI RICE / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019144 (BIRYANI RICE / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019145 (JEERA RICE): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019145 (JEERA RICE / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019145 (JEERA RICE / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019146 (LUCKY SPECIAL SOUP): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019153 (TOMATO SOUP): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019155 (CHICKEN CHILLY DRY / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019155 (CHICKEN CHILLY DRY / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019156 (CHICKEN CHILLY GRAVY / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019156 (CHICKEN CHILLY GRAVY / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019157 (CHICKEN MANCHURIAN DRY / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019157 (CHICKEN MANCHURIAN DRY / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019158 (CHICKEN MANCHURIAN GRAVY / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019158 (CHICKEN MANCHURIAN GRAVY / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019159 (CHICKEN SCHEZWAN CHILLY / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019159 (CHICKEN SCHEZWAN CHILLY / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019165 (CHICKEN CRISPY / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019165 (CHICKEN CRISPY / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019187 (MIX CHOWMEIN): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019193 (CHI. SCHEZWAN PAKODA RICE / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019193 (CHI. SCHEZWAN PAKODA RICE / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019194 (CHICKEN FRIED RICE / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019194 (CHICKEN FRIED RICE / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019196 (CHI. SCHEZWAN FRIED RICE / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019196 (CHI. SCHEZWAN FRIED RICE / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019202 (EGG FRIED RICE / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019202 (EGG FRIED RICE / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019203 (EGG SCHEZWAN FRIED RICE / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019203 (EGG SCHEZWAN FRIED RICE / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019204 (VEG. FRIED RICE / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019204 (VEG. FRIED RICE / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019205 (VEG. SCHEZWAN FRIED RICE / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019205 (VEG. SCHEZWAN FRIED RICE / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019209 (LUCKY SPECIAL FIRED RICE): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019213 (CHICKEN TRIPLE FRIED RICE / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019213 (CHICKEN TRIPLE FRIED RICE / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019215 (CHICKEN MANCHURIAN RICE / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019215 (CHICKEN MANCHURIAN RICE / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019220 (MIX. TRIPLE RICE): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019221 (MIX. TRIPLE NOODLES): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019222 (CHICKEN TRIPLE NOODLES / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019222 (CHICKEN TRIPLE NOODLES / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019225 (CHICKEN PAKODA NOODLES / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019225 (CHICKEN PAKODA NOODLES / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019226 (CHICKEN HAKKA NOODLES / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019226 (CHICKEN HAKKA NOODLES / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019227 (CHI. SCHEN. HAKKA NOODLES / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019227 (CHI. SCHEN. HAKKA NOODLES / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019228 (CHI. SCHEN. PAKODA NOODLES / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019228 (CHI. SCHEN. PAKODA NOODLES / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019230 (CHINESE SINGAPORE NOODLES): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070019239 (VEG. HAKKA NOODLES / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019239 (VEG. HAKKA NOODLES / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019240 (VEG. SCHN. HAKKA NOODLES / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019240 (VEG. SCHN. HAKKA NOODLES / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019243 (ALL COLD DRINKS / Regular): non-numeric price text in source: 'APS' (market/seasonal price) (confidence 0.5)
-- menu_item_id 400070019245 (BUTTER MILK/KESAR MASALA MIX. / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019245 (BUTTER MILK/KESAR MASALA MIX. / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019248 (TEA / DOUBLE TEA / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019248 (TEA / DOUBLE TEA / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019249 (SPL. TEA / COFFEE / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019249 (SPL. TEA / COFFEE / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019250 (HOT MILK / Half): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)
-- menu_item_id 400070019250 (HOT MILK / Full): portion label inferred as Half/Full by position -- source gave no label (confidence 0.6)

-- === UNMAPPED / INFORMATIONAL RESTAURANT-LEVEL NOTES ===
-- price-per-person from JSON: "₹1–200" -- no matching restaurant-level column; not inserted anywhere.
-- HALAL: attempted as a restaurant_tag lookup against platform_tag (tag_code='halal') above; if that tag doesn't exist yet in the live database the insert was a no-op -- verify and add the tag if it should exist.
-- 'NO BEEF' page notice: informational assurance text, not a formal dietary tag/column; not inserted anywhere.

COMMIT;