-- Khaustan menu onboarding: PAV BHAJI CENTER
-- Source JSON: PAV BHAJI CENTER.json
-- Source image(s): Pav Bhaji Center.jpg
-- establishment_id / restaurant_id / source_id namespace: 400703004
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
    400703004, 'PAV BHAJI CENTER', 'pav bhaji center',
    'Sector 30', NULL, 'Vashi', 'Navi Mumbai',
    'Maharashtra', 'IN', '400703', 19.06511356503204, 72.9989062941663
);

INSERT INTO restaurant (
    restaurant_id, establishment_id, display_name, normalized_name,
    has_bar, bar_license_type
) VALUES (
    400703004, 400703004, 'PAV BHAJI CENTER', 'pav bhaji center',
    FALSE, 'none'
);

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400703004, 'ai_menu_extraction', 'PAV BHAJI CENTER.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, status_code)
VALUES (nextval('khaustan_standalone_id_seq'), 400703004, 400703004, (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');
SELECT extraction_batch_id FROM menu_extraction_batch WHERE source_id = 400703004 ORDER BY extraction_batch_id DESC LIMIT 1 \gset

-- Phones
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES (nextval('khaustan_standalone_id_seq'), 400703004, '9004335044', TRUE);

-- Hours: single stated window applied to every day (JSON gives one blanket timing,
-- no per-day breakdown) -- confidence: inferred blanket application, not per-day-confirmed.
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
VALUES
    (nextval('khaustan_standalone_id_seq'), 400703004, 1, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703004, 2, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703004, 3, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703004, 4, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703004, 5, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703004, 6, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703004, 7, 1, '08:30'::time, '22:00'::time);

-- Menu board: JSON has no explicit board label -- one a_la_carte board per Step 2.
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, is_active, display_sequence)
VALUES (400703004001, 400703004, 'Main Menu', 'a_la_carte', TRUE, 1);

-- Categories, in JSON/source order, verbatim leaf text (including source typos)
INSERT INTO menu_category (menu_category_id, restaurant_id, name, parent_category_id, display_sequence)
VALUES
    (400703004001, 400703004, 'PAV BHAJI', NULL, 1),
    (400703004002, 400703004, 'TAWA PULAO', NULL, 2),
    (400703004003, 400703004, 'MASALA PAV', NULL, 3);

-- Board <-> category mapping (menu_board_category has no standalone id column)
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (400703004, 400703004001, 400703004001, 1),
    (400703004, 400703004001, 400703004002, 2),
    (400703004, 400703004001, 400703004003, 3);

-- Canonical dish identify-or-create: no unique constraint on canonical_dish.normalized_name,
-- so NOT EXISTS, not ON CONFLICT. Whether these already exist from an earlier onboarded
-- restaurant is resolved live by this check when the script runs -- not something knowable
-- in advance, and not guessed here.
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'AMUL BUTTER PAV BHAJI', 'amul butter pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'amul butter pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'AMUL BUTTER PAV BHAJI', 'amul butter pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BUTTER PAV BHAJI', 'butter pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BUTTER PAV BHAJI', 'butter pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BUTTER CHEESE PAV BHAJI', 'butter cheese pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter cheese pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BUTTER CHEESE PAV BHAJI', 'butter cheese pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BUTTER KHADA PAV BHAJI', 'butter khada pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter khada pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BUTTER KHADA PAV BHAJI', 'butter khada pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BUTTER CHEESE KHADA PAV BHAJI', 'butter cheese khada pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter cheese khada pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BUTTER CHEESE KHADA PAV BHAJI', 'butter cheese khada pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER PAV BHAJI', 'paneer pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER PAV BHAJI', 'paneer pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER CHEESE PAV BHAJI', 'paneer cheese pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer cheese pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER CHEESE PAV BHAJI', 'paneer cheese pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN PAV BHAJI', 'jain pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN PAV BHAJI', 'jain pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN CHEESE PAV BHAJI', 'jain cheese pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain cheese pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN CHEESE PAV BHAJI', 'jain cheese pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN PANEER PAV BHAJI', 'jain paneer pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain paneer pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN PANEER PAV BHAJI', 'jain paneer pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'JAIN PANEER CHEESE PAV BHAJI', 'jain paneer cheese pav bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jain paneer cheese pav bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'JAIN PANEER CHEESE PAV BHAJI', 'jain paneer cheese pav bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ONLY BUTTER BHAJI', 'only butter bhaji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'only butter bhaji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ONLY BUTTER BHAJI', 'only butter bhaji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'EXTRA BUTTER PAV (2PCS)', 'extra butter pav (2pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra butter pav (2pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'EXTRA BUTTER PAV (2PCS)', 'extra butter pav (2pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SADA PAV (2PCS)', 'sada pav (2pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sada pav (2pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SADA PAV (2PCS)', 'sada pav (2pcs)', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER TAWA PULAO', 'paneer tawa pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tawa pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER TAWA PULAO', 'paneer tawa pulao', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'SPE. PANEER CHEESE TAWA PULAO', 'spe. paneer cheese tawa pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spe. paneer cheese tawa pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SPE. PANEER CHEESE TAWA PULAO', 'spe. paneer cheese tawa pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'BUTTER MASALA PAV', 'butter masala pav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter masala pav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'BUTTER MASALA PAV', 'butter masala pav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER MASALA PAV', 'paneer masala pav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer masala pav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER MASALA PAV', 'paneer masala pav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHEESE MASALA PAV', 'cheese masala pav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese masala pav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHEESE MASALA PAV', 'cheese masala pav', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'PANEER CHEESE MASALA PAV', 'paneer cheese masala pav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer cheese masala pav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'PANEER CHEESE MASALA PAV', 'paneer cheese masala pav', 'primary'
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
    (400703004001, 400703004, 'AMUL BUTTER PAV BHAJI', 'amul butter pav bhaji', 'PAV BHAJI', 'veg', NULL, 'unverified'),
    (400703004002, 400703004, 'BUTTER PAV BHAJI', 'butter pav bhaji', 'PAV BHAJI', 'veg', NULL, 'unverified'),
    (400703004003, 400703004, 'BUTTER CHEESE PAV BHAJI', 'butter cheese pav bhaji', 'PAV BHAJI', 'veg', NULL, 'unverified'),
    (400703004004, 400703004, 'BUTTER KHADA PAV BHAJI', 'butter khada pav bhaji', 'PAV BHAJI', 'veg', NULL, 'unverified'),
    (400703004005, 400703004, 'BUTTER CHEESE KHADA PAV BHAJI', 'butter cheese khada pav bhaji', 'PAV BHAJI', 'veg', NULL, 'unverified'),
    (400703004006, 400703004, 'PANEER PAV BHAJI', 'paneer pav bhaji', 'PAV BHAJI', 'veg', NULL, 'unverified'),
    (400703004007, 400703004, 'PANEER CHEESE PAV BHAJI', 'paneer cheese pav bhaji', 'PAV BHAJI', 'veg', NULL, 'unverified'),
    (400703004008, 400703004, 'JAIN PAV BHAJI', 'jain pav bhaji', 'PAV BHAJI', 'veg', TRUE, 'unverified'),
    (400703004009, 400703004, 'JAIN CHEESE PAV BHAJI', 'jain cheese pav bhaji', 'PAV BHAJI', 'veg', TRUE, 'unverified'),
    (400703004010, 400703004, 'JAIN PANEER PAV BHAJI', 'jain paneer pav bhaji', 'PAV BHAJI', 'veg', TRUE, 'unverified'),
    (400703004011, 400703004, 'JAIN PANEER CHEESE PAV BHAJI', 'jain paneer cheese pav bhaji', 'PAV BHAJI', 'veg', TRUE, 'unverified'),
    (400703004012, 400703004, 'ONLY BUTTER BHAJI', 'only butter bhaji', 'PAV BHAJI', 'veg', NULL, 'unverified'),
    (400703004013, 400703004, 'EXTRA BUTTER PAV (2PCS)', 'extra butter pav (2pcs)', 'PAV BHAJI', 'veg', NULL, 'unverified'),
    (400703004014, 400703004, 'SADA PAV (2PCS)', 'sada pav (2pcs)', 'PAV BHAJI', 'veg', NULL, 'unverified'),
    (400703004015, 400703004, 'TAWA PULAO', 'tawa pulao', 'TAWA PULAO', 'veg', NULL, 'unverified'),
    (400703004016, 400703004, 'PANEER TAWA PULAO', 'paneer tawa pulao', 'TAWA PULAO', 'veg', NULL, 'unverified'),
    (400703004017, 400703004, 'CHEESE TAWA PULAO', 'cheese tawa pulao', 'TAWA PULAO', 'veg', NULL, 'unverified'),
    (400703004018, 400703004, 'SPE. PANEER CHEESE TAWA PULAO', 'spe. paneer cheese tawa pulao', 'TAWA PULAO', 'veg', NULL, 'unverified'),
    (400703004019, 400703004, 'BUTTER MASALA PAV', 'butter masala pav', 'MASALA PAV', 'veg', NULL, 'unverified'),
    (400703004020, 400703004, 'PANEER MASALA PAV', 'paneer masala pav', 'MASALA PAV', 'veg', NULL, 'unverified'),
    (400703004021, 400703004, 'CHEESE MASALA PAV', 'cheese masala pav', 'MASALA PAV', 'veg', NULL, 'unverified'),
    (400703004022, 400703004, 'PANEER CHEESE MASALA PAV', 'paneer cheese masala pav', 'MASALA PAV', 'veg', NULL, 'unverified')
) AS x(menu_item_id, restaurant_id, name, normalized_name, raw_category_text, food_classification_code, is_jain, verification_status_code)
JOIN canonical_dish cd ON cd.normalized_name = x.normalized_name;

-- Menu item source: name/existence confidence, kept separate from price confidence.
-- A missing price (see below) does not lower this -- the item's identity is certain
-- either way; verification_status_code still flags the item for follow-up.
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
VALUES
    (400703004001, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004002, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004003, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004004, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004005, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004006, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004007, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004008, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004009, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004010, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004011, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004012, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004013, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004014, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004015, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004016, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004017, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004018, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004019, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004020, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004021, 400703004, :extraction_batch_id, 0.95, 'unverified'),
    (400703004022, 400703004, :extraction_batch_id, 0.95, 'unverified');

-- Variants (portion/label variants -- one menu_item, multiple menu_item_variant rows)
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
VALUES
    (400703004001, 400703004001, 'Regular', 'fixed', TRUE),
    (400703004002, 400703004002, 'Regular', 'fixed', TRUE),
    (400703004003, 400703004003, 'Regular', 'fixed', TRUE),
    (400703004004, 400703004004, 'Regular', 'fixed', TRUE),
    (400703004005, 400703004005, 'Regular', 'fixed', TRUE),
    (400703004006, 400703004006, 'Regular', 'fixed', TRUE),
    (400703004007, 400703004007, 'Regular', 'fixed', TRUE),
    (400703004008, 400703004008, 'Regular', 'fixed', TRUE),
    (400703004009, 400703004009, 'Regular', 'fixed', TRUE),
    (400703004010, 400703004010, 'Regular', 'fixed', TRUE),
    (400703004011, 400703004011, 'Regular', 'fixed', TRUE),
    (400703004012, 400703004012, 'Regular', 'fixed', TRUE),
    (400703004013, 400703004013, 'Regular', 'fixed', TRUE),
    (400703004014, 400703004014, 'Regular', 'fixed', TRUE),
    (400703004015, 400703004015, 'Half', 'fixed', TRUE),
    (400703004016, 400703004015, 'Full', 'fixed', FALSE),
    (400703004017, 400703004016, 'Half', 'fixed', TRUE),
    (400703004018, 400703004016, 'Full', 'fixed', FALSE),
    (400703004019, 400703004017, 'Half', 'fixed', TRUE),
    (400703004020, 400703004017, 'Full', 'fixed', FALSE),
    (400703004021, 400703004018, 'Half', 'fixed', TRUE),
    (400703004022, 400703004018, 'Full', 'fixed', FALSE),
    (400703004023, 400703004019, 'Regular', 'fixed', TRUE),
    (400703004024, 400703004020, 'Regular', 'fixed', TRUE),
    (400703004025, 400703004021, 'Regular', 'fixed', TRUE),
    (400703004026, 400703004022, 'Regular', 'fixed', TRUE);

-- Prices (only for variants where a price was actually captured)
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
VALUES
    (400703004001, 400703004001, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004002, 400703004002, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004003, 400703004003, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004004, 400703004004, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004005, 400703004005, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004006, 400703004006, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004007, 400703004007, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004008, 400703004008, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004009, 400703004009, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004010, 400703004010, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004011, 400703004011, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004012, 400703004012, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004013, 400703004013, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004014, 400703004014, 10.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004015, 400703004015, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004016, 400703004016, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004017, 400703004017, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004018, 400703004018, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004019, 400703004019, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004020, 400703004020, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004021, 400703004021, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004022, 400703004022, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004023, 400703004023, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004024, 400703004024, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004025, 400703004025, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified'),
    (400703004026, 400703004026, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703004, 'unverified');

-- Price source (price-specific confidence, tracked separately from item confidence)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
VALUES
    (400703004001, 400703004, :extraction_batch_id, 0.95),
    (400703004002, 400703004, :extraction_batch_id, 0.95),
    (400703004003, 400703004, :extraction_batch_id, 0.95),
    (400703004004, 400703004, :extraction_batch_id, 0.95),
    (400703004005, 400703004, :extraction_batch_id, 0.95),
    (400703004006, 400703004, :extraction_batch_id, 0.95),
    (400703004007, 400703004, :extraction_batch_id, 0.95),
    (400703004008, 400703004, :extraction_batch_id, 0.95),
    (400703004009, 400703004, :extraction_batch_id, 0.95),
    (400703004010, 400703004, :extraction_batch_id, 0.95),
    (400703004011, 400703004, :extraction_batch_id, 0.95),
    (400703004012, 400703004, :extraction_batch_id, 0.95),
    (400703004013, 400703004, :extraction_batch_id, 0.95),
    (400703004014, 400703004, :extraction_batch_id, 0.95),
    (400703004015, 400703004, :extraction_batch_id, 0.95),
    (400703004016, 400703004, :extraction_batch_id, 0.95),
    (400703004017, 400703004, :extraction_batch_id, 0.95),
    (400703004018, 400703004, :extraction_batch_id, 0.95),
    (400703004019, 400703004, :extraction_batch_id, 0.95),
    (400703004020, 400703004, :extraction_batch_id, 0.95),
    (400703004021, 400703004, :extraction_batch_id, 0.95),
    (400703004022, 400703004, :extraction_batch_id, 0.95),
    (400703004023, 400703004, :extraction_batch_id, 0.95),
    (400703004024, 400703004, :extraction_batch_id, 0.95),
    (400703004025, 400703004, :extraction_batch_id, 0.95),
    (400703004026, 400703004, :extraction_batch_id, 0.95);

-- Board <-> item mapping
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
VALUES
    (400703004001, 400703004, 400703004001, 400703004001, 400703004001, 1),
    (400703004002, 400703004, 400703004001, 400703004002, 400703004001, 2),
    (400703004003, 400703004, 400703004001, 400703004003, 400703004001, 3),
    (400703004004, 400703004, 400703004001, 400703004004, 400703004001, 4),
    (400703004005, 400703004, 400703004001, 400703004005, 400703004001, 5),
    (400703004006, 400703004, 400703004001, 400703004006, 400703004001, 6),
    (400703004007, 400703004, 400703004001, 400703004007, 400703004001, 7),
    (400703004008, 400703004, 400703004001, 400703004008, 400703004001, 8),
    (400703004009, 400703004, 400703004001, 400703004009, 400703004001, 9),
    (400703004010, 400703004, 400703004001, 400703004010, 400703004001, 10),
    (400703004011, 400703004, 400703004001, 400703004011, 400703004001, 11),
    (400703004012, 400703004, 400703004001, 400703004012, 400703004001, 12),
    (400703004013, 400703004, 400703004001, 400703004013, 400703004001, 13),
    (400703004014, 400703004, 400703004001, 400703004014, 400703004001, 14),
    (400703004015, 400703004, 400703004001, 400703004015, 400703004002, 1),
    (400703004016, 400703004, 400703004001, 400703004016, 400703004002, 2),
    (400703004017, 400703004, 400703004001, 400703004017, 400703004002, 3),
    (400703004018, 400703004, 400703004001, 400703004018, 400703004002, 4),
    (400703004019, 400703004, 400703004001, 400703004019, 400703004003, 1),
    (400703004020, 400703004, 400703004001, 400703004020, 400703004003, 2),
    (400703004021, 400703004, 400703004001, 400703004021, 400703004003, 3),
    (400703004022, 400703004, 400703004001, 400703004022, 400703004003, 4);

-- === NEEDS-REVIEW ITEMS ===
-- none

-- === PER-ITEM NOTES ===
-- none

-- === UNMAPPED RESTAURANT-LEVEL NOTES ===
-- price_range "1-200" from JSON: no matching restaurant-level column; not inserted anywhere.
-- other_text: "!!Shree Parabji Namaha!!" / "!!Shree Momaji Namaha!!" -- devotional signage text, no schema column; name and phone repeated elsewhere in other_text are redundant with structured fields already captured.

COMMIT;