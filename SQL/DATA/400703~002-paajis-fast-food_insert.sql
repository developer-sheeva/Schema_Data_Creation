-- Khaustan menu onboarding: PAAJI'S FAST FOOD
-- Source JSON: Paajis_Fast_Food_Menu_OCR.json
-- Source image(s): paaji's fast food.jpg
-- establishment_id / restaurant_id / source_id namespace: 400703002
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
    400703002, 'PAAJI''S FAST FOOD', 'paaji''s fast food',
    'Sector 30', NULL, 'Vashi', 'Navi Mumbai',
    'Maharashtra', 'IN', '400703', 19.06511673388747, 72.998918364107
);

INSERT INTO restaurant (
    restaurant_id, establishment_id, display_name, normalized_name,
    has_bar, bar_license_type
) VALUES (
    400703002, 400703002, 'PAAJI''S FAST FOOD', 'paaji''s fast food',
    FALSE, 'none'
);

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400703002, 'ai_menu_extraction', 'Paajis_Fast_Food_Menu_OCR.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, status_code)
VALUES (nextval('khaustan_standalone_id_seq'), 400703002, 400703002, (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');
SELECT extraction_batch_id FROM menu_extraction_batch WHERE source_id = 400703002 ORDER BY extraction_batch_id DESC LIMIT 1 \gset

-- Phones
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES (nextval('khaustan_standalone_id_seq'), 400703002, '7738631313', TRUE);

-- Hours: single stated window applied to every day (JSON gives one blanket timing,
-- no per-day breakdown) -- confidence: inferred blanket application, not per-day-confirmed.
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
VALUES
    (nextval('khaustan_standalone_id_seq'), 400703002, 1, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703002, 2, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703002, 3, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703002, 4, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703002, 5, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703002, 6, 1, '08:30'::time, '22:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400703002, 7, 1, '08:30'::time, '22:00'::time);

-- Menu board: JSON has no explicit board label -- one a_la_carte board per Step 2.
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, is_active, display_sequence)
VALUES (400703002001, 400703002, 'Main Menu', 'a_la_carte', TRUE, 1);

-- Categories, in JSON/source order, verbatim leaf text (including source typos)
INSERT INTO menu_category (menu_category_id, restaurant_id, name, parent_category_id, display_sequence)
VALUES
    (400703002001, 400703002, 'FAST FOOD', NULL, 1);

-- Board <-> category mapping (menu_board_category has no standalone id column)
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (400703002, 400703002001, 400703002001, 1);

-- Canonical dish identify-or-create: no unique constraint on canonical_dish.normalized_name,
-- so NOT EXISTS, not ON CONFLICT. Whether these already exist from an earlier onboarded
-- restaurant is resolved live by this check when the script runs -- not something knowable
-- in advance, and not guessed here.
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Spl. Chole Bhature', 'spl. chole bhature'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spl. chole bhature')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Spl. Chole Bhature', 'spl. chole bhature', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Spl. Dal Rice', 'spl. dal rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spl. dal rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Spl. Dal Rice', 'spl. dal rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Spl. Rajma Rice', 'spl. rajma rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spl. rajma rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Spl. Rajma Rice', 'spl. rajma rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Spl. Chole Rice', 'spl. chole rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spl. chole rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Spl. Chole Rice', 'spl. chole rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Spl. Rice Plate', 'spl. rice plate'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spl. rice plate')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Spl. Rice Plate', 'spl. rice plate', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Spl. Thali', 'spl. thali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'spl. thali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Spl. Thali', 'spl. thali', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Only Rajma', 'only rajma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'only rajma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Only Rajma', 'only rajma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Only Chole', 'only chole'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'only chole')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Only Chole', 'only chole', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Extra Bhatura', 'extra bhatura'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra bhatura')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Extra Bhatura', 'extra bhatura', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Extra Chapati', 'extra chapati'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra chapati')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Extra Chapati', 'extra chapati', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Masala Chaas', 'masala chaas'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala chaas')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Masala Chaas', 'masala chaas', 'primary'
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
    (400703002001, 400703002, 'Spl. Chole Bhature', 'spl. chole bhature', 'FAST FOOD', 'veg', NULL, 'unverified'),
    (400703002002, 400703002, 'Spl. Dal Rice', 'spl. dal rice', 'FAST FOOD', 'veg', NULL, 'unverified'),
    (400703002003, 400703002, 'Spl. Rajma Rice', 'spl. rajma rice', 'FAST FOOD', 'veg', NULL, 'unverified'),
    (400703002004, 400703002, 'Spl. Chole Rice', 'spl. chole rice', 'FAST FOOD', 'veg', NULL, 'unverified'),
    (400703002005, 400703002, 'Spl. Rice Plate', 'spl. rice plate', 'FAST FOOD', 'veg', NULL, 'unverified'),
    (400703002006, 400703002, 'Spl. Thali', 'spl. thali', 'FAST FOOD', 'veg', NULL, 'unverified'),
    (400703002007, 400703002, 'Only Rajma', 'only rajma', 'FAST FOOD', 'veg', NULL, 'unverified'),
    (400703002008, 400703002, 'Only Chole', 'only chole', 'FAST FOOD', 'veg', NULL, 'unverified'),
    (400703002009, 400703002, 'Extra Bhatura', 'extra bhatura', 'FAST FOOD', 'veg', NULL, 'unverified'),
    (400703002010, 400703002, 'Extra Chapati', 'extra chapati', 'FAST FOOD', 'veg', NULL, 'unverified'),
    (400703002011, 400703002, 'Masala Chaas', 'masala chaas', 'FAST FOOD', 'veg', NULL, 'needs_review'),
    (400703002012, 400703002, 'Sweet Lassi', 'sweet lassi', 'FAST FOOD', 'veg', NULL, 'needs_review')
) AS x(menu_item_id, restaurant_id, name, normalized_name, raw_category_text, food_classification_code, is_jain, verification_status_code)
JOIN canonical_dish cd ON cd.normalized_name = x.normalized_name;

-- Menu item source: name/existence confidence, kept separate from price confidence.
-- A missing price (see below) does not lower this -- the item's identity is certain
-- either way; verification_status_code still flags the item for follow-up.
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
VALUES
    (400703002001, 400703002, :extraction_batch_id, 0.95, 'unverified'),
    (400703002002, 400703002, :extraction_batch_id, 0.95, 'unverified'),
    (400703002003, 400703002, :extraction_batch_id, 0.95, 'unverified'),
    (400703002004, 400703002, :extraction_batch_id, 0.95, 'unverified'),
    (400703002005, 400703002, :extraction_batch_id, 0.95, 'unverified'),
    (400703002006, 400703002, :extraction_batch_id, 0.95, 'unverified'),
    (400703002007, 400703002, :extraction_batch_id, 0.95, 'unverified'),
    (400703002008, 400703002, :extraction_batch_id, 0.95, 'unverified'),
    (400703002009, 400703002, :extraction_batch_id, 0.95, 'unverified'),
    (400703002010, 400703002, :extraction_batch_id, 0.95, 'unverified'),
    (400703002011, 400703002, :extraction_batch_id, 0.95, 'needs_review'),
    (400703002012, 400703002, :extraction_batch_id, 0.95, 'needs_review');

-- Variants (portion/label variants -- one menu_item, multiple menu_item_variant rows)
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
VALUES
    (400703002001, 400703002001, 'Regular', 'fixed', TRUE),
    (400703002002, 400703002002, 'Regular', 'fixed', TRUE),
    (400703002003, 400703002003, 'Regular', 'fixed', TRUE),
    (400703002004, 400703002004, 'Regular', 'fixed', TRUE),
    (400703002005, 400703002005, 'With 2 Pcs. Chapati', 'fixed', TRUE),
    (400703002006, 400703002005, 'With 2 Pcs. Bhature', 'fixed', FALSE),
    (400703002007, 400703002006, 'With Chapati & Rajma', 'fixed', TRUE),
    (400703002008, 400703002007, 'Regular', 'fixed', TRUE),
    (400703002009, 400703002008, 'Regular', 'fixed', TRUE),
    (400703002010, 400703002009, '1 Pc.', 'fixed', TRUE),
    (400703002011, 400703002010, '1 Pc.', 'fixed', TRUE),
    (400703002012, 400703002011, 'Regular', 'fixed', TRUE),
    (400703002013, 400703002012, 'Regular', 'fixed', TRUE);

-- Prices (only for variants where a price was actually captured)
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
VALUES
    (400703002001, 400703002001, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703002, 'unverified'),
    (400703002002, 400703002002, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703002, 'unverified'),
    (400703002003, 400703002003, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703002, 'unverified'),
    (400703002004, 400703002004, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703002, 'unverified'),
    (400703002005, 400703002005, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703002, 'unverified'),
    (400703002006, 400703002006, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703002, 'unverified'),
    (400703002007, 400703002007, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703002, 'unverified'),
    (400703002008, 400703002008, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703002, 'unverified'),
    (400703002009, 400703002009, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703002, 'unverified'),
    (400703002010, 400703002010, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703002, 'unverified'),
    (400703002011, 400703002011, 10.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400703002, 'unverified');

-- Price source (price-specific confidence, tracked separately from item confidence)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
VALUES
    (400703002001, 400703002, :extraction_batch_id, 0.95),
    (400703002002, 400703002, :extraction_batch_id, 0.95),
    (400703002003, 400703002, :extraction_batch_id, 0.95),
    (400703002004, 400703002, :extraction_batch_id, 0.95),
    (400703002005, 400703002, :extraction_batch_id, 0.95),
    (400703002006, 400703002, :extraction_batch_id, 0.95),
    (400703002007, 400703002, :extraction_batch_id, 0.95),
    (400703002008, 400703002, :extraction_batch_id, 0.95),
    (400703002009, 400703002, :extraction_batch_id, 0.95),
    (400703002010, 400703002, :extraction_batch_id, 0.95),
    (400703002011, 400703002, :extraction_batch_id, 0.95);

-- Board <-> item mapping
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
VALUES
    (400703002001, 400703002, 400703002001, 400703002001, 400703002001, 1),
    (400703002002, 400703002, 400703002001, 400703002002, 400703002001, 2),
    (400703002003, 400703002, 400703002001, 400703002003, 400703002001, 3),
    (400703002004, 400703002, 400703002001, 400703002004, 400703002001, 4),
    (400703002005, 400703002, 400703002001, 400703002005, 400703002001, 5),
    (400703002006, 400703002, 400703002001, 400703002006, 400703002001, 6),
    (400703002007, 400703002, 400703002001, 400703002007, 400703002001, 7),
    (400703002008, 400703002, 400703002001, 400703002008, 400703002001, 8),
    (400703002009, 400703002, 400703002001, 400703002009, 400703002001, 9),
    (400703002010, 400703002, 400703002001, 400703002010, 400703002001, 10),
    (400703002011, 400703002, 400703002001, 400703002011, 400703002001, 11),
    (400703002012, 400703002, 400703002001, 400703002012, 400703002001, 12);

-- === NEEDS-REVIEW ITEMS ===
-- menu_item_id 400703002011 (Masala Chaas / Regular): no price captured in source JSON (confidence 0.2)
-- menu_item_id 400703002012 (Sweet Lassi / Regular): no price captured in source JSON (confidence 0.2)

-- === PER-ITEM NOTES ===
-- none

-- === UNMAPPED RESTAURANT-LEVEL NOTES ===
-- price_range "1-200" from JSON: no matching restaurant-level column (cost_for_two represents a different concept -- meal cost for two, not an item min/max range); not inserted anywhere.
-- other_text: "Eating Chole & Rajma with your Tiffin Rs. 40/- will be Charged Extra Per Person" -- a conditional, customer-behavior-dependent surcharge, not a standard per-dish menu_item_charge; no schema home found.
-- other_text: "We use only Refined Palm Oil" -- cooking-oil disclosure, no schema column.

COMMIT;