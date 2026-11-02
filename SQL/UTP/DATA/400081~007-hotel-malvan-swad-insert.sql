-- Khaustan menu onboarding: Hotel Malvan Swad
-- Source JSON: Hotel_Malvan_Swad_Menu_OCR.json
-- Source image(s): Malvani 1.jpg, Malvani2.jpg
-- establishment_id / restaurant_id / source_id namespace: 400081007 (taken directly from the source JSON)
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
    400081007, 'Hotel Malvan Swad', 'hotel malvan swad',
    'Shop No. 11/12', NULL, 'Mulund', 'Mumbai',
    'Maharashtra', 'IN', '400081', 19.17129999837362, 72.95663588542875
);

INSERT INTO restaurant (
    restaurant_id, establishment_id, display_name, normalized_name,
    veg_nonveg_status, has_bar, bar_license_type
) VALUES (
    400081007, 400081007, 'Hotel Malvan Swad', 'hotel malvan swad',
    'veg_and_nonveg', FALSE, 'none'
);

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400081007, 'ai_menu_extraction', 'Hotel_Malvan_Swad_Menu_OCR.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, status_code)
VALUES (nextval('khaustan_standalone_id_seq'), 400081007, 400081007, (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');
SELECT extraction_batch_id FROM menu_extraction_batch WHERE source_id = 400081007 ORDER BY extraction_batch_id DESC LIMIT 1 \gset

-- Phones
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES
    (nextval('khaustan_standalone_id_seq'), 400081007, '022-21636715', TRUE),
    (nextval('khaustan_standalone_id_seq'), 400081007, '9030037600', FALSE),
    (nextval('khaustan_standalone_id_seq'), 400081007, '9030067600', FALSE);

-- Hours: no usable timings string in the source JSON (empty or unparseable) --
-- no restaurant_hours rows inserted rather than guessing a schedule.

-- HALAL restaurant tag: safe lookup-only insert. If 'halal' isn't yet a platform_tag
-- tag_code, this JOIN matches zero rows and inserts nothing -- no error, no new lookup
-- row created (lookup tables are read-only for this script).
INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id)
SELECT nextval('khaustan_standalone_id_seq'), 400081007, tag_id FROM platform_tag WHERE tag_code = 'halal';

-- Menu board: one a_la_carte board for the whole JSON source.
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, is_active, display_sequence)
VALUES (400081007001, 400081007, 'Main Menu', 'a_la_carte', TRUE, 1);

-- Categories, in JSON/source order. Where the source nests a subcategory (e.g.
-- STARTERS -> INDIAN / CHINESE), the top-level name becomes a parent row and the
-- subcategory becomes its child via parent_category_id -- the leaf (child) is what
-- items attach to. A category name repeated across two distinct source sections (this
-- happens at least once in this batch) is kept as two separate rows, not merged --
-- these are keyed by source position, not by display name.
INSERT INTO menu_category (menu_category_id, restaurant_id, name, parent_category_id, display_sequence)
VALUES
    (400081007001, 400081007, 'CHINESE SOUP VEG.', NULL, 1),
    (400081007002, 400081007, 'CHINESE SOUP NON-VEG.', NULL, 2),
    (400081007003, 400081007, 'SALAD', NULL, 3),
    (400081007004, 400081007, 'KURKURE ITEM''S', NULL, 4),
    (400081007005, 400081007, 'STARTING POINT', NULL, 5),
    (400081007006, 400081007, 'VEG. STARTER''S', NULL, 6),
    (400081007007, 400081007, 'EGGS', NULL, 7),
    (400081007008, 400081007, 'SPECIAL KOLIWADA DISHES', NULL, 8),
    (400081007009, 400081007, 'VEG. TANDOOR', NULL, 9),
    (400081007010, 400081007, 'MALVANI MUTTON', NULL, 10),
    (400081007011, 400081007, 'NON - VEG. STARTER''S', NULL, 11),
    (400081007012, 400081007, 'MALVANI CHICKEN', NULL, 12),
    (400081007013, 400081007, 'MALVANI FISH CURRY', NULL, 13),
    (400081007014, 400081007, 'NON - VEG. STARTER''S', NULL, 14),
    (400081007015, 400081007, 'SPECIAL INDIAN VEG.', NULL, 15),
    (400081007016, 400081007, 'SPECIAL INDAIN NON-VEG', NULL, 16),
    (400081007017, 400081007, 'VEG BIRYANI & RICE', NULL, 17),
    (400081007018, 400081007, 'ROTI''S', NULL, 18),
    (400081007019, 400081007, 'NON-VEG BIRYANI', NULL, 19),
    (400081007020, 400081007, 'DAL', NULL, 20),
    (400081007021, 400081007, 'VEG THALI', NULL, 21),
    (400081007022, 400081007, 'CHINESE VEG. RICE & NOODLES', NULL, 22),
    (400081007023, 400081007, 'NON-VEG. RICE & NOODLES', NULL, 23);

-- Board <-> category mapping (leaf categories only)
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (400081007, 400081007001, 400081007001, 1),
    (400081007, 400081007001, 400081007002, 2),
    (400081007, 400081007001, 400081007003, 3),
    (400081007, 400081007001, 400081007004, 4),
    (400081007, 400081007001, 400081007005, 5),
    (400081007, 400081007001, 400081007006, 6),
    (400081007, 400081007001, 400081007007, 7),
    (400081007, 400081007001, 400081007008, 8),
    (400081007, 400081007001, 400081007009, 9),
    (400081007, 400081007001, 400081007010, 10),
    (400081007, 400081007001, 400081007011, 11),
    (400081007, 400081007001, 400081007012, 12),
    (400081007, 400081007001, 400081007013, 13),
    (400081007, 400081007001, 400081007014, 14),
    (400081007, 400081007001, 400081007015, 15),
    (400081007, 400081007001, 400081007016, 16),
    (400081007, 400081007001, 400081007017, 17),
    (400081007, 400081007001, 400081007018, 18),
    (400081007, 400081007001, 400081007019, 19),
    (400081007, 400081007001, 400081007020, 20),
    (400081007, 400081007001, 400081007021, 21),
    (400081007, 400081007001, 400081007022, 22),
    (400081007, 400081007001, 400081007023, 23);

-- Canonical dish identify-or-create: no unique constraint on canonical_dish.normalized_name,
-- so NOT EXISTS, not ON CONFLICT. Whether these already exist from an earlier onboarded
-- restaurant is resolved live by this check when the script runs.
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Manchow Soup', 'veg. manchow soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchow soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Manchow Soup', 'veg. manchow soup', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Clear Soup', 'veg. clear soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. clear soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Clear Soup', 'veg. clear soup', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Manchow Soup', 'chicken manchow soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchow soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Manchow Soup', 'chicken manchow soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Hot & Sour Soup', 'chicken hot & sour soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hot & sour soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Hot & Sour Soup', 'chicken hot & sour soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Clear Soup', 'chicken clear soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken clear soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Clear Soup', 'chicken clear soup', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Raita', 'veg. raita'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. raita')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Raita', 'veg. raita', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Masala Papad', 'masala papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Masala Papad', 'masala papad', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Rice Papad', 'rice papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rice papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Rice Papad', 'rice papad', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Masala Rice Papad', 'masala rice papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala rice papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Masala Rice Papad', 'masala rice papad', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'French Fries', 'french fries'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'french fries')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'French Fries', 'french fries', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'French Fries With Cheese', 'french fries with cheese'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'french fries with cheese')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'French Fries With Cheese', 'french fries with cheese', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sweet Corn Boiled', 'sweet corn boiled'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sweet corn boiled')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sweet Corn Boiled', 'sweet corn boiled', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sweet Corn Special', 'sweet corn special'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sweet corn special')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sweet Corn Special', 'sweet corn special', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Plain Cheese Cube (2 Pcs.)', 'plain cheese cube (2 pcs.)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'plain cheese cube (2 pcs.)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Plain Cheese Cube (2 Pcs.)', 'plain cheese cube (2 pcs.)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chana Garlic', 'chana garlic'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chana garlic')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chana Garlic', 'chana garlic', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chana Kolwada', 'chana kolwada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chana kolwada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chana Kolwada', 'chana kolwada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chana Garlic Kolwada', 'chana garlic kolwada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chana garlic kolwada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chana Garlic Kolwada', 'chana garlic kolwada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Green Peas Jeera Butter Fry', 'green peas jeera butter fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green peas jeera butter fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Green Peas Jeera Butter Fry', 'green peas jeera butter fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Green Peas Jeera Garlic Butter Fry', 'green peas jeera garlic butter fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green peas jeera garlic butter fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Green Peas Jeera Garlic Butter Fry', 'green peas jeera garlic butter fry', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Boiled Vegetables', 'boiled vegetables'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'boiled vegetables')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Boiled Vegetables', 'boiled vegetables', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Pakoda', 'cheese pakoda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese pakoda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Pakoda', 'cheese pakoda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Soyabean Chilly', 'soyabean chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'soyabean chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Soyabean Chilly', 'soyabean chilly', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Crispy', 'veg. crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Crispy', 'veg. crispy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Manchurian', 'veg. manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Manchurian', 'veg. manchurian', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Chilly', 'paneer chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Chilly', 'paneer chilly', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer 65', 'paneer 65'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer 65')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer 65', 'paneer 65', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Hot Garlic', 'paneer hot garlic'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer hot garlic')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Hot Garlic', 'paneer hot garlic', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Boiled (2 Pcs)', 'egg boiled (2 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg boiled (2 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Boiled (2 Pcs)', 'egg boiled (2 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Half Fry', 'egg half fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg half fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Half Fry', 'egg half fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Burji', 'egg burji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg burji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Burji', 'egg burji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Omlet', 'egg omlet'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg omlet')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Omlet', 'egg omlet', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Pakoda', 'egg pakoda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg pakoda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Pakoda', 'egg pakoda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Chilly', 'egg chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Chilly', 'egg chilly', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Liver Potta Koliwada 250gm', 'liver potta koliwada 250gm'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'liver potta koliwada 250gm')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Liver Potta Koliwada 250gm', 'liver potta koliwada 250gm', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Lollypop 250gm', 'lollypop 250gm'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lollypop 250gm')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Lollypop 250gm', 'lollypop 250gm', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Prawns Koliwada 250gm', 'prawns koliwada 250gm'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns koliwada 250gm')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Prawns Koliwada 250gm', 'prawns koliwada 250gm', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Prawns Koliwada 150gm', 'prawns koliwada 150gm'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns koliwada 150gm')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Prawns Koliwada 150gm', 'prawns koliwada 150gm', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Rawas Koliwada 250gm', 'rawas koliwada 250gm'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawas koliwada 250gm')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Rawas Koliwada 250gm', 'rawas koliwada 250gm', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Rawas Koliwada 150gm', 'rawas koliwada 150gm'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawas koliwada 150gm')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Rawas Koliwada 150gm', 'rawas koliwada 150gm', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Bombil Koliwada', 'bombil koliwada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bombil koliwada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Bombil Koliwada', 'bombil koliwada', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Tikka / Haryali', 'paneer tikka / haryali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka / haryali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka / Haryali', 'paneer tikka / haryali', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Masala', 'mutton masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Masala', 'mutton masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Masala Handi (H) 6 Pcs.', 'mutton masala handi (h) 6 pcs.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton masala handi (h) 6 pcs.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Masala Handi (H) 6 Pcs.', 'mutton masala handi (h) 6 pcs.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Masala Handi (F) 12 Pcs.', 'mutton masala handi (f) 12 pcs.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton masala handi (f) 12 pcs.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Masala Handi (F) 12 Pcs.', 'mutton masala handi (f) 12 pcs.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Sukha', 'mutton sukha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton sukha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Sukha', 'mutton sukha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Sukha Handi (H) 6 Pcs.', 'mutton sukha handi (h) 6 pcs.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton sukha handi (h) 6 pcs.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Sukha Handi (H) 6 Pcs.', 'mutton sukha handi (h) 6 pcs.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Sukha Handi (F) 12 Pcs.', 'mutton sukha handi (f) 12 pcs.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton sukha handi (f) 12 pcs.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Sukha Handi (F) 12 Pcs.', 'mutton sukha handi (f) 12 pcs.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Lollypop (8 pcs.)', 'chicken lollypop (8 pcs.)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lollypop (8 pcs.)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Lollypop (8 pcs.)', 'chicken lollypop (8 pcs.)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Lollypop Sz. Dry', 'chicken lollypop sz. dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lollypop sz. dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Lollypop Sz. Dry', 'chicken lollypop sz. dry', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Gravy', 'chicken gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Gravy', 'chicken gravy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Chilly With Bone', 'chicken chilly with bone'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly with bone')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Chilly With Bone', 'chicken chilly with bone', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken 65', 'chicken 65'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken 65')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken 65', 'chicken 65', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Hot Garlic', 'chicken hot garlic'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hot garlic')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Hot Garlic', 'chicken hot garlic', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Roast', 'chicken roast'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken roast')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Roast', 'chicken roast', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Salt & Pepper', 'chicken salt & pepper'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken salt & pepper')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Salt & Pepper', 'chicken salt & pepper', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Lamba', 'chicken lamba'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lamba')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Lamba', 'chicken lamba', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Schezwan Roast', 'chicken schezwan roast'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan roast')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Schezwan Roast', 'chicken schezwan roast', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Prawns Chilly', 'prawns chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Prawns Chilly', 'prawns chilly', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Prawns Hot Garlic', 'prawns hot garlic'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns hot garlic')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Prawns Hot Garlic', 'prawns hot garlic', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Fish Chilly', 'fish chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Fish Chilly', 'fish chilly', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Masala', 'chicken masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Masala', 'chicken masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Masala Handi (H) 6 Pcs.', 'chicken masala handi (h) 6 pcs.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken masala handi (h) 6 pcs.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Masala Handi (H) 6 Pcs.', 'chicken masala handi (h) 6 pcs.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Masala Handi (F) 12 Pcs.', 'chicken masala handi (f) 12 pcs.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken masala handi (f) 12 pcs.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Masala Handi (F) 12 Pcs.', 'chicken masala handi (f) 12 pcs.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Sukha', 'chicken sukha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken sukha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Sukha', 'chicken sukha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Sukha Handi (H) 6 Pcs.', 'chicken sukha handi (h) 6 pcs.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken sukha handi (h) 6 pcs.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Sukha Handi (H) 6 Pcs.', 'chicken sukha handi (h) 6 pcs.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Sukha Handi (F) 12 Pcs.', 'chicken sukha handi (f) 12 pcs.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken sukha handi (f) 12 pcs.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Sukha Handi (F) 12 Pcs.', 'chicken sukha handi (f) 12 pcs.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pomfret Curry', 'pomfret curry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pomfret curry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pomfret Curry', 'pomfret curry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Surmai Curry', 'surmai curry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'surmai curry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Surmai Curry', 'surmai curry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Rawas Curry', 'rawas curry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawas curry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Rawas Curry', 'rawas curry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kolambi Masala', 'kolambi masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kolambi masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kolambi Masala', 'kolambi masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Bangda Curry', 'bangda curry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bangda curry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Bangda Curry', 'bangda curry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pomfret Tawa Fry', 'pomfret tawa fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pomfret tawa fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pomfret Tawa Fry', 'pomfret tawa fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Surmai Tawa Fry', 'surmai tawa fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'surmai tawa fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Surmai Tawa Fry', 'surmai tawa fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Rawas Tawa Fry', 'rawas tawa fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawas tawa fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Rawas Tawa Fry', 'rawas tawa fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kolambi Tawa Fry', 'kolambi tawa fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kolambi tawa fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kolambi Tawa Fry', 'kolambi tawa fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Bombil Tawa Fry / Rama Fry', 'bombil tawa fry / rama fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bombil tawa fry / rama fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Bombil Tawa Fry / Rama Fry', 'bombil tawa fry / rama fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Bangda Tawa Fry', 'bangda tawa fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bangda tawa fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Bangda Tawa Fry', 'bangda tawa fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mandeli Oil Fry', 'mandeli oil fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mandeli oil fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mandeli Oil Fry', 'mandeli oil fry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tandoori (F)', 'chicken tandoori (f)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori (f)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tandoori (F)', 'chicken tandoori (f)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tandoori (H)', 'chicken tandoori (h)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori (h)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tandoori (H)', 'chicken tandoori (h)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Green Tandoori (F)', 'chicken green tandoori (f)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken green tandoori (f)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Green Tandoori (F)', 'chicken green tandoori (f)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Green Tandoori (H)', 'chicken green tandoori (h)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken green tandoori (h)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Green Tandoori (H)', 'chicken green tandoori (h)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Kalimiri Tandoori (F)', 'chicken kalimiri tandoori (f)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kalimiri tandoori (f)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Kalimiri Tandoori (F)', 'chicken kalimiri tandoori (f)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Kalimiri Tandoori (H)', 'chicken kalimiri tandoori (h)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kalimiri tandoori (h)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Kalimiri Tandoori (H)', 'chicken kalimiri tandoori (h)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Lollipop Tandoori (8 pcs)', 'chicken lollipop tandoori (8 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lollipop tandoori (8 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Lollipop Tandoori (8 pcs)', 'chicken lollipop tandoori (8 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tangdi Kabab (2 pcs)', 'chicken tangdi kabab (2 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tangdi kabab (2 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tangdi Kabab (2 pcs)', 'chicken tangdi kabab (2 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tikka', 'chicken tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tikka', 'chicken tikka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Angara Kabab', 'chicken angara kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken angara kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Angara Kabab', 'chicken angara kabab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Kalimiri Kabab', 'chicken kalimiri kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kalimiri kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Kalimiri Kabab', 'chicken kalimiri kabab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Pahadi Kabab', 'chicken pahadi kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pahadi kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Pahadi Kabab', 'chicken pahadi kabab', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Lasooni Kabab', 'chicken lasooni kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lasooni kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Lasooni Kabab', 'chicken lasooni kabab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Rawas Tikka', 'rawas tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawas tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Rawas Tikka', 'rawas tikka', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Aloo Mutter', 'aloo mutter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo mutter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Aloo Mutter', 'aloo mutter', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Aloo Palak', 'aloo palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'aloo palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Aloo Palak', 'aloo palak', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mix Vegetables', 'mix vegetables'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mix vegetables')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mix Vegetables', 'mix vegetables', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Green Peas Masala', 'green peas masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green peas masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Green Peas Masala', 'green peas masala', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Chatpata', 'veg. chatpata'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. chatpata')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Chatpata', 'veg. chatpata', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Makhanawala', 'veg. makhanawala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. makhanawala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Makhanawala', 'veg. makhanawala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Makhanwala', 'paneer makhanwala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer makhanwala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Makhanwala', 'paneer makhanwala', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Butter Masala', 'paneer butter masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer butter masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Butter Masala', 'paneer butter masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Handi', 'paneer handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Handi', 'paneer handi', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Palak', 'paneer palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Palak', 'paneer palak', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Tikka Masala', 'paneer tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Tikka Masala', 'paneer tikka masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Burji', 'paneer burji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer burji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Burji', 'paneer burji', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kaju Masala', 'kaju masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kaju masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kaju Masala', 'kaju masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Kaju Paneer Masala', 'kaju paneer masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kaju paneer masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Kaju Paneer Masala', 'kaju paneer masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Chicken (Half)', 'butter chicken (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter chicken (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Chicken (Half)', 'butter chicken (half)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Chicken (Full)', 'butter chicken (full)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter chicken (full)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Chicken (Full)', 'butter chicken (full)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Murg Mussalam (Half)', 'murg mussalam (half)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murg mussalam (half)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Murg Mussalam (Half)', 'murg mussalam (half)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Murg Mussalam (Full)', 'murg mussalam (full)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murg mussalam (full)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Murg Mussalam (Full)', 'murg mussalam (full)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Handi (Half 6 pcs)', 'chicken handi (half 6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken handi (half 6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Handi (Half 6 pcs)', 'chicken handi (half 6 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Handi (Full 12 pcs)', 'chicken handi (full 12 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken handi (full 12 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Handi (Full 12 pcs)', 'chicken handi (full 12 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Lapeta (Half 6 pcs)', 'chicken lapeta (half 6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lapeta (half 6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Lapeta (Half 6 pcs)', 'chicken lapeta (half 6 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Lapeta (Full 12 pcs)', 'chicken lapeta (full 12 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lapeta (full 12 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Lapeta (Full 12 pcs)', 'chicken lapeta (full 12 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Masala Indian', 'chicken masala indian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken masala indian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Masala Indian', 'chicken masala indian', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Sukha Indian', 'chicken sukha indian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken sukha indian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Sukha Indian', 'chicken sukha indian', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Kolhapuri / Kadai', 'chicken kolhapuri / kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kolhapuri / kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Kolhapuri / Kadai', 'chicken kolhapuri / kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tikka / Pahadi Masala', 'chicken tikka / pahadi masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka / pahadi masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tikka / Pahadi Masala', 'chicken tikka / pahadi masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Liver / Potta Masala', 'chicken liver / potta masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken liver / potta masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Liver / Potta Masala', 'chicken liver / potta masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Liver / Potta', 'chicken liver / potta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken liver / potta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Liver / Potta', 'chicken liver / potta', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Handi (Half 6 Pcs)', 'mutton handi (half 6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton handi (half 6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Handi (Half 6 Pcs)', 'mutton handi (half 6 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Handi (Full 12 Pcs)', 'mutton handi (full 12 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton handi (full 12 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Handi (Full 12 Pcs)', 'mutton handi (full 12 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Lapeta (Half 6 Pcs)', 'mutton lapeta (half 6 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton lapeta (half 6 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Lapeta (Half 6 Pcs)', 'mutton lapeta (half 6 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Lapeta (Full 12 Pcs)', 'mutton lapeta (full 12 pcs)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton lapeta (full 12 pcs)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Lapeta (Full 12 Pcs)', 'mutton lapeta (full 12 pcs)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Kadai / Kolhapuri', 'mutton kadai / kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kadai / kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Kadai / Kolhapuri', 'mutton kadai / kolhapuri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Egg Masala / Curry', 'egg masala / curry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg masala / curry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Egg Masala / Curry', 'egg masala / curry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Steam Rice', 'steam rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'steam rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Steam Rice', 'steam rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Jeera Rice', 'jeera rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jeera rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Jeera Rice', 'jeera rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Biryani Rice', 'biryani rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'biryani rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Biryani Rice', 'biryani rice', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Dal Khichdi Tadka', 'dal khichdi tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal khichdi tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dal Khichdi Tadka', 'dal khichdi tadka', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg Pulao', 'veg pulao'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg pulao')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg Pulao', 'veg pulao', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg Biryani', 'veg biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg Biryani', 'veg biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Biryani', 'paneer biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Biryani', 'paneer biryani', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chapati', 'chapati'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chapati')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chapati', 'chapati', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Chapati', 'butter chapati'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter chapati')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Chapati', 'butter chapati', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Bhakri', 'bhakri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bhakri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Bhakri', 'bhakri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Roti', 'roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Roti', 'roti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Roti', 'butter roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Roti', 'butter roti', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Naan', 'butter naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Naan', 'butter naan', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Kulcha', 'butter kulcha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter kulcha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Kulcha', 'butter kulcha', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Paratha', 'butter paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Paratha', 'butter paratha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Garlic Naan', 'butter garlic naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter garlic naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Garlic Naan', 'butter garlic naan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Cheese Garlic Naan', 'butter cheese garlic naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter cheese garlic naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Cheese Garlic Naan', 'butter cheese garlic naan', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Biryani', 'chicken biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Biryani', 'chicken biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Dum Biryani', 'chicken dum biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken dum biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Dum Biryani', 'chicken dum biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Hyderabadi Biryani', 'chicken hyderabadi biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hyderabadi biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Hyderabadi Biryani', 'chicken hyderabadi biryani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Biryani (Boneless)', 'chicken biryani (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken biryani (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Biryani (Boneless)', 'chicken biryani (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tikka Biryani', 'chicken tikka biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tikka Biryani', 'chicken tikka biryani', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Dum Biryani', 'mutton dum biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton dum biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Dum Biryani', 'mutton dum biryani', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Biryani (Boneless)', 'mutton biryani (boneless)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton biryani (boneless)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Biryani (Boneless)', 'mutton biryani (boneless)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Prawns Biryani', 'prawns biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Prawns Biryani', 'prawns biryani', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Dal Tadka', 'dal tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dal Tadka', 'dal tadka', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Special Thali', 'veg. special thali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. special thali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Special Thali', 'veg. special thali', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Combination Rice', 'veg. combination rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. combination rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Combination Rice', 'veg. combination rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Triple Schezwan Fried Rice', 'veg. triple schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. triple schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Triple Schezwan Fried Rice', 'veg. triple schezwan fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Manchurian Fried Rice', 'veg. manchurian fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. manchurian fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Manchurian Fried Rice', 'veg. manchurian fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Sherpa Rice', 'veg. sherpa rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. sherpa rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Sherpa Rice', 'veg. sherpa rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Burnt Garlic Rice', 'veg. burnt garlic rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. burnt garlic rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Burnt Garlic Rice', 'veg. burnt garlic rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Fried Rice', 'paneer fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Fried Rice', 'paneer fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Schezwan Fried Rice', 'paneer schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Schezwan Fried Rice', 'paneer schezwan fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mushroom Fried Rice', 'mushroom fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mushroom Fried Rice', 'mushroom fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mushroom Sz. Fried Rice', 'mushroom sz. fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom sz. fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mushroom Sz. Fried Rice', 'mushroom sz. fried rice', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Hakka Noodles', 'veg. hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Hakka Noodles', 'veg. hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Schezwan Noodles', 'veg. schezwan noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. schezwan noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Schezwan Noodles', 'veg. schezwan noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg. Triple Schezwan Noodle', 'veg. triple schezwan noodle'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg. triple schezwan noodle')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg. Triple Schezwan Noodle', 'veg. triple schezwan noodle', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chic. Fried Rice', 'chic. fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chic. fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chic. Fried Rice', 'chic. fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chic. Pakoda Fried Rice', 'chic. pakoda fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chic. pakoda fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chic. Pakoda Fried Rice', 'chic. pakoda fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chic. Schezwan Fried Rice', 'chic. schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chic. schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chic. Schezwan Fried Rice', 'chic. schezwan fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chic. Combination Rice', 'chic. combination rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chic. combination rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chic. Combination Rice', 'chic. combination rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chic. Triple Schezwan Fried Rice', 'chic. triple schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chic. triple schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chic. Triple Schezwan Fried Rice', 'chic. triple schezwan fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chic. Manchurian Fried Rice', 'chic. manchurian fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chic. manchurian fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chic. Manchurian Fried Rice', 'chic. manchurian fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chic. Sherpa Rice', 'chic. sherpa rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chic. sherpa rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chic. Sherpa Rice', 'chic. sherpa rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chic. Burnt Garlic Rice', 'chic. burnt garlic rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chic. burnt garlic rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chic. Burnt Garlic Rice', 'chic. burnt garlic rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chic. Singapore Fried Rice', 'chic. singapore fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chic. singapore fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chic. Singapore Fried Rice', 'chic. singapore fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chic. Hakka Noodles', 'chic. hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chic. hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chic. Hakka Noodles', 'chic. hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chic. Schezwan Noodles', 'chic. schezwan noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chic. schezwan noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chic. Schezwan Noodles', 'chic. schezwan noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chic. Triple Schezwan Noodle', 'chic. triple schezwan noodle'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chic. triple schezwan noodle')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chic. Triple Schezwan Noodle', 'chic. triple schezwan noodle', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Prawns Fried Rice', 'prawns fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Prawns Fried Rice', 'prawns fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Prawns Schezwan Fried Rice', 'prawns schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Prawns Schezwan Fried Rice', 'prawns schezwan fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Prawns Triple Schezwan Fried Rice', 'prawns triple schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns triple schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Prawns Triple Schezwan Fried Rice', 'prawns triple schezwan fried rice', 'primary'
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
    (400081007001, 400081007, 'Veg. Manchow Soup', 'veg. manchow soup', 'CHINESE SOUP VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007002, 400081007, 'Veg. Hot & Sour Soup', 'veg. hot & sour soup', 'CHINESE SOUP VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007003, 400081007, 'Veg. Clear Soup', 'veg. clear soup', 'CHINESE SOUP VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007004, 400081007, 'Tomato Soup', 'tomato soup', 'CHINESE SOUP VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007005, 400081007, 'Chicken Manchow Soup', 'chicken manchow soup', 'CHINESE SOUP NON-VEG.', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007006, 400081007, 'Chicken Hot & Sour Soup', 'chicken hot & sour soup', 'CHINESE SOUP NON-VEG.', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007007, 400081007, 'Chicken Clear Soup', 'chicken clear soup', 'CHINESE SOUP NON-VEG.', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007008, 400081007, 'Green Salad', 'green salad', 'SALAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007009, 400081007, 'Veg. Raita', 'veg. raita', 'SALAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007010, 400081007, 'Roasted Papad', 'roasted papad', 'KURKURE ITEM''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007011, 400081007, 'Fry Papad', 'fry papad', 'KURKURE ITEM''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007012, 400081007, 'Masala Papad', 'masala papad', 'KURKURE ITEM''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007013, 400081007, 'Rice Papad', 'rice papad', 'KURKURE ITEM''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007014, 400081007, 'Masala Rice Papad', 'masala rice papad', 'KURKURE ITEM''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007015, 400081007, 'French Fries', 'french fries', 'KURKURE ITEM''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007016, 400081007, 'French Fries With Cheese', 'french fries with cheese', 'KURKURE ITEM''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007017, 400081007, 'Sweet Corn Boiled', 'sweet corn boiled', 'STARTING POINT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007018, 400081007, 'Sweet Corn Special', 'sweet corn special', 'STARTING POINT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007019, 400081007, 'Plain Cheese Cube (2 Pcs.)', 'plain cheese cube (2 pcs.)', 'STARTING POINT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007020, 400081007, 'Chana Garlic', 'chana garlic', 'STARTING POINT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007021, 400081007, 'Chana Kolwada', 'chana kolwada', 'STARTING POINT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007022, 400081007, 'Chana Garlic Kolwada', 'chana garlic kolwada', 'STARTING POINT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007023, 400081007, 'Green Peas Jeera Butter Fry', 'green peas jeera butter fry', 'STARTING POINT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007024, 400081007, 'Green Peas Jeera Garlic Butter Fry', 'green peas jeera garlic butter fry', 'STARTING POINT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007025, 400081007, 'Veg. Pakoda', 'veg. pakoda', 'STARTING POINT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007026, 400081007, 'Boiled Vegetables', 'boiled vegetables', 'STARTING POINT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007027, 400081007, 'Paneer Pakoda', 'paneer pakoda', 'STARTING POINT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007028, 400081007, 'Cheese Pakoda', 'cheese pakoda', 'STARTING POINT', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007029, 400081007, 'Soyabean Chilly', 'soyabean chilly', 'VEG. STARTER''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007030, 400081007, 'Veg. 65', 'veg. 65', 'VEG. STARTER''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007031, 400081007, 'Veg. Crispy', 'veg. crispy', 'VEG. STARTER''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007032, 400081007, 'Veg. Manchurian', 'veg. manchurian', 'VEG. STARTER''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007033, 400081007, 'Mushroom Chilly', 'mushroom chilly', 'VEG. STARTER''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007034, 400081007, 'Paneer Chilly', 'paneer chilly', 'VEG. STARTER''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007035, 400081007, 'Paneer 65', 'paneer 65', 'VEG. STARTER''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007036, 400081007, 'Paneer Crispy', 'paneer crispy', 'VEG. STARTER''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007037, 400081007, 'Paneer Hot Garlic', 'paneer hot garlic', 'VEG. STARTER''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007038, 400081007, 'Egg Boiled (2 Pcs)', 'egg boiled (2 pcs)', 'EGGS', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007039, 400081007, 'Egg Half Fry', 'egg half fry', 'EGGS', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007040, 400081007, 'Egg Burji', 'egg burji', 'EGGS', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007041, 400081007, 'Egg Omlet', 'egg omlet', 'EGGS', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007042, 400081007, 'Egg Pakoda', 'egg pakoda', 'EGGS', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007043, 400081007, 'Egg Chilly', 'egg chilly', 'EGGS', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007044, 400081007, 'Liver Potta Koliwada 250gm', 'liver potta koliwada 250gm', 'SPECIAL KOLIWADA DISHES', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400081007045, 400081007, 'Lollypop 250gm', 'lollypop 250gm', 'SPECIAL KOLIWADA DISHES', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007046, 400081007, 'Prawns Koliwada 250gm', 'prawns koliwada 250gm', 'SPECIAL KOLIWADA DISHES', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007047, 400081007, 'Prawns Koliwada 150gm', 'prawns koliwada 150gm', 'SPECIAL KOLIWADA DISHES', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007048, 400081007, 'Rawas Koliwada 250gm', 'rawas koliwada 250gm', 'SPECIAL KOLIWADA DISHES', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007049, 400081007, 'Rawas Koliwada 150gm', 'rawas koliwada 150gm', 'SPECIAL KOLIWADA DISHES', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007050, 400081007, 'Bombil Koliwada', 'bombil koliwada', 'SPECIAL KOLIWADA DISHES', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007051, 400081007, 'Paneer Tikka / Haryali', 'paneer tikka / haryali', 'VEG. TANDOOR', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007052, 400081007, 'Mushroom Tikka', 'mushroom tikka', 'VEG. TANDOOR', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007053, 400081007, 'Mutton Masala', 'mutton masala', 'MALVANI MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007054, 400081007, 'Mutton Masala Handi (H) 6 Pcs.', 'mutton masala handi (h) 6 pcs.', 'MALVANI MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007055, 400081007, 'Mutton Masala Handi (F) 12 Pcs.', 'mutton masala handi (f) 12 pcs.', 'MALVANI MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007056, 400081007, 'Mutton Sukha', 'mutton sukha', 'MALVANI MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007057, 400081007, 'Mutton Sukha Handi (H) 6 Pcs.', 'mutton sukha handi (h) 6 pcs.', 'MALVANI MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007058, 400081007, 'Mutton Sukha Handi (F) 12 Pcs.', 'mutton sukha handi (f) 12 pcs.', 'MALVANI MUTTON', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007059, 400081007, 'Chicken Lollypop (8 pcs.)', 'chicken lollypop (8 pcs.)', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007060, 400081007, 'Chicken Lollypop Sz. Dry', 'chicken lollypop sz. dry', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007061, 400081007, 'Chicken Chilly', 'chicken chilly', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007062, 400081007, 'Chicken Gravy', 'chicken gravy', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007063, 400081007, 'Chicken Chilly With Bone', 'chicken chilly with bone', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007064, 400081007, 'Chicken Manchurian', 'chicken manchurian', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007065, 400081007, 'Chicken 65', 'chicken 65', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007066, 400081007, 'Chicken Hot Garlic', 'chicken hot garlic', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007067, 400081007, 'Chicken Crispy', 'chicken crispy', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007068, 400081007, 'Chicken Roast', 'chicken roast', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007069, 400081007, 'Chicken Salt & Pepper', 'chicken salt & pepper', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007070, 400081007, 'Chicken Lamba', 'chicken lamba', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007071, 400081007, 'Chicken Schezwan Roast', 'chicken schezwan roast', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007072, 400081007, 'Prawns Chilly', 'prawns chilly', 'NON - VEG. STARTER''S', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007073, 400081007, 'Prawns Hot Garlic', 'prawns hot garlic', 'NON - VEG. STARTER''S', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007074, 400081007, 'Fish Chilly', 'fish chilly', 'NON - VEG. STARTER''S', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007075, 400081007, 'Chicken Masala', 'chicken masala', 'MALVANI CHICKEN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007076, 400081007, 'Chicken Masala Handi (H) 6 Pcs.', 'chicken masala handi (h) 6 pcs.', 'MALVANI CHICKEN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007077, 400081007, 'Chicken Masala Handi (F) 12 Pcs.', 'chicken masala handi (f) 12 pcs.', 'MALVANI CHICKEN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007078, 400081007, 'Chicken Sukha', 'chicken sukha', 'MALVANI CHICKEN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007079, 400081007, 'Chicken Sukha Handi (H) 6 Pcs.', 'chicken sukha handi (h) 6 pcs.', 'MALVANI CHICKEN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007080, 400081007, 'Chicken Sukha Handi (F) 12 Pcs.', 'chicken sukha handi (f) 12 pcs.', 'MALVANI CHICKEN', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007081, 400081007, 'Pomfret Curry', 'pomfret curry', 'MALVANI FISH CURRY', 'non_veg'::text, 'seafood'::text, NULL::text, 'needs_review'),
    (400081007082, 400081007, 'Surmai Curry', 'surmai curry', 'MALVANI FISH CURRY', 'non_veg'::text, 'seafood'::text, NULL::text, 'needs_review'),
    (400081007083, 400081007, 'Rawas Curry', 'rawas curry', 'MALVANI FISH CURRY', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007084, 400081007, 'Kolambi Masala', 'kolambi masala', 'MALVANI FISH CURRY', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007085, 400081007, 'Bangda Curry', 'bangda curry', 'MALVANI FISH CURRY', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007086, 400081007, 'Pomfret Tawa Fry', 'pomfret tawa fry', 'MALVANI FISH CURRY', 'non_veg'::text, 'seafood'::text, NULL::text, 'needs_review'),
    (400081007087, 400081007, 'Surmai Tawa Fry', 'surmai tawa fry', 'MALVANI FISH CURRY', 'non_veg'::text, 'seafood'::text, NULL::text, 'needs_review'),
    (400081007088, 400081007, 'Rawas Tawa Fry', 'rawas tawa fry', 'MALVANI FISH CURRY', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007089, 400081007, 'Kolambi Tawa Fry', 'kolambi tawa fry', 'MALVANI FISH CURRY', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007090, 400081007, 'Bombil Tawa Fry / Rama Fry', 'bombil tawa fry / rama fry', 'MALVANI FISH CURRY', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007091, 400081007, 'Bangda Tawa Fry', 'bangda tawa fry', 'MALVANI FISH CURRY', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007092, 400081007, 'Mandeli Oil Fry', 'mandeli oil fry', 'MALVANI FISH CURRY', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007093, 400081007, 'Chicken Tandoori (F)', 'chicken tandoori (f)', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007094, 400081007, 'Chicken Tandoori (H)', 'chicken tandoori (h)', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007095, 400081007, 'Chicken Green Tandoori (F)', 'chicken green tandoori (f)', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007096, 400081007, 'Chicken Green Tandoori (H)', 'chicken green tandoori (h)', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007097, 400081007, 'Chicken Kalimiri Tandoori (F)', 'chicken kalimiri tandoori (f)', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007098, 400081007, 'Chicken Kalimiri Tandoori (H)', 'chicken kalimiri tandoori (h)', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007099, 400081007, 'Chicken Lollipop Tandoori (8 pcs)', 'chicken lollipop tandoori (8 pcs)', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007100, 400081007, 'Chicken Tangdi Kabab (2 pcs)', 'chicken tangdi kabab (2 pcs)', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007101, 400081007, 'Chicken Tikka', 'chicken tikka', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007102, 400081007, 'Chicken Angara Kabab', 'chicken angara kabab', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007103, 400081007, 'Chicken Kalimiri Kabab', 'chicken kalimiri kabab', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007104, 400081007, 'Chicken Pahadi Kabab', 'chicken pahadi kabab', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007105, 400081007, 'Chicken Banjara Kabab', 'chicken banjara kabab', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007106, 400081007, 'Chicken Lasooni Kabab', 'chicken lasooni kabab', 'NON - VEG. STARTER''S', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007107, 400081007, 'Rawas Tikka', 'rawas tikka', 'NON - VEG. STARTER''S', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007108, 400081007, 'Chana Masala', 'chana masala', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007109, 400081007, 'Aloo Mutter', 'aloo mutter', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007110, 400081007, 'Aloo Palak', 'aloo palak', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007111, 400081007, 'Mix Vegetables', 'mix vegetables', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007112, 400081007, 'Veg. Kolhapuri', 'veg. kolhapuri', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007113, 400081007, 'Green Peas Masala', 'green peas masala', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007114, 400081007, 'Veg. Handi', 'veg. handi', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007115, 400081007, 'Veg. Kadai', 'veg. kadai', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007116, 400081007, 'Veg. Chatpata', 'veg. chatpata', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007117, 400081007, 'Veg. Angara', 'veg. angara', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007118, 400081007, 'Veg. Makhanawala', 'veg. makhanawala', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007119, 400081007, 'Paneer Makhanwala', 'paneer makhanwala', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007120, 400081007, 'Paneer Mutter', 'paneer mutter', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007121, 400081007, 'Paneer Butter Masala', 'paneer butter masala', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007122, 400081007, 'Paneer Handi', 'paneer handi', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007123, 400081007, 'Paneer Kadai', 'paneer kadai', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007124, 400081007, 'Paneer Palak', 'paneer palak', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007125, 400081007, 'Paneer Angara', 'paneer angara', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007126, 400081007, 'Paneer Tikka Masala', 'paneer tikka masala', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007127, 400081007, 'Paneer Burji', 'paneer burji', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007128, 400081007, 'Kaju Masala', 'kaju masala', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007129, 400081007, 'Kaju Paneer Masala', 'kaju paneer masala', 'SPECIAL INDIAN VEG.', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007130, 400081007, 'Butter Chicken (Half)', 'butter chicken (half)', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007131, 400081007, 'Butter Chicken (Full)', 'butter chicken (full)', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007132, 400081007, 'Murg Mussalam (Half)', 'murg mussalam (half)', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007133, 400081007, 'Murg Mussalam (Full)', 'murg mussalam (full)', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007134, 400081007, 'Chicken Handi (Half 6 pcs)', 'chicken handi (half 6 pcs)', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007135, 400081007, 'Chicken Handi (Full 12 pcs)', 'chicken handi (full 12 pcs)', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007136, 400081007, 'Chicken Lapeta (Half 6 pcs)', 'chicken lapeta (half 6 pcs)', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007137, 400081007, 'Chicken Lapeta (Full 12 pcs)', 'chicken lapeta (full 12 pcs)', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007138, 400081007, 'Chicken Masala Indian', 'chicken masala indian', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007139, 400081007, 'Chicken Sukha Indian', 'chicken sukha indian', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007140, 400081007, 'Chicken Kolhapuri / Kadai', 'chicken kolhapuri / kadai', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007141, 400081007, 'Chicken Tikka / Pahadi Masala', 'chicken tikka / pahadi masala', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007142, 400081007, 'Chicken Liver / Potta Masala', 'chicken liver / potta masala', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007143, 400081007, 'Chicken Liver / Potta', 'chicken liver / potta', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007144, 400081007, 'Mutton Handi (Half 6 Pcs)', 'mutton handi (half 6 pcs)', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007145, 400081007, 'Mutton Handi (Full 12 Pcs)', 'mutton handi (full 12 pcs)', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007146, 400081007, 'Mutton Lapeta (Half 6 Pcs)', 'mutton lapeta (half 6 pcs)', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007147, 400081007, 'Mutton Lapeta (Full 12 Pcs)', 'mutton lapeta (full 12 pcs)', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007148, 400081007, 'Mutton Masala', 'mutton masala', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007149, 400081007, 'Mutton Kadai / Kolhapuri', 'mutton kadai / kolhapuri', 'SPECIAL INDAIN NON-VEG', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007150, 400081007, 'Egg Masala / Curry', 'egg masala / curry', 'SPECIAL INDAIN NON-VEG', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007151, 400081007, 'Steam Rice', 'steam rice', 'VEG BIRYANI & RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007152, 400081007, 'Jeera Rice', 'jeera rice', 'VEG BIRYANI & RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007153, 400081007, 'Biryani Rice', 'biryani rice', 'VEG BIRYANI & RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007154, 400081007, 'Dal Khichdi', 'dal khichdi', 'VEG BIRYANI & RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007155, 400081007, 'Dal Khichdi Tadka', 'dal khichdi tadka', 'VEG BIRYANI & RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007156, 400081007, 'Palak Khichdi', 'palak khichdi', 'VEG BIRYANI & RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007157, 400081007, 'Veg Pulao', 'veg pulao', 'VEG BIRYANI & RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007158, 400081007, 'Veg Biryani', 'veg biryani', 'VEG BIRYANI & RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007159, 400081007, 'Paneer Biryani', 'paneer biryani', 'VEG BIRYANI & RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007160, 400081007, 'Paneer Tikka Biryani', 'paneer tikka biryani', 'VEG BIRYANI & RICE', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007161, 400081007, 'Chapati', 'chapati', 'ROTI''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007162, 400081007, 'Butter Chapati', 'butter chapati', 'ROTI''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007163, 400081007, 'Bhakri', 'bhakri', 'ROTI''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007164, 400081007, 'Roti', 'roti', 'ROTI''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007165, 400081007, 'Butter Roti', 'butter roti', 'ROTI''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007166, 400081007, 'Naan', 'naan', 'ROTI''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007167, 400081007, 'Butter Naan', 'butter naan', 'ROTI''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007168, 400081007, 'Kulcha', 'kulcha', 'ROTI''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007169, 400081007, 'Butter Kulcha', 'butter kulcha', 'ROTI''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007170, 400081007, 'Paratha', 'paratha', 'ROTI''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007171, 400081007, 'Butter Paratha', 'butter paratha', 'ROTI''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007172, 400081007, 'Butter Garlic Naan', 'butter garlic naan', 'ROTI''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007173, 400081007, 'Butter Cheese Garlic Naan', 'butter cheese garlic naan', 'ROTI''S', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007174, 400081007, 'Egg Biryani', 'egg biryani', 'NON-VEG BIRYANI', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007175, 400081007, 'Chicken Biryani', 'chicken biryani', 'NON-VEG BIRYANI', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007176, 400081007, 'Chicken Dum Biryani', 'chicken dum biryani', 'NON-VEG BIRYANI', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007177, 400081007, 'Chicken Hyderabadi Biryani', 'chicken hyderabadi biryani', 'NON-VEG BIRYANI', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007178, 400081007, 'Chicken Biryani (Boneless)', 'chicken biryani (boneless)', 'NON-VEG BIRYANI', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007179, 400081007, 'Chicken Tikka Biryani', 'chicken tikka biryani', 'NON-VEG BIRYANI', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400081007180, 400081007, 'Mutton Biryani', 'mutton biryani', 'NON-VEG BIRYANI', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007181, 400081007, 'Mutton Dum Biryani', 'mutton dum biryani', 'NON-VEG BIRYANI', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007182, 400081007, 'Mutton Hyderabadi Biryani', 'mutton hyderabadi biryani', 'NON-VEG BIRYANI', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007183, 400081007, 'Mutton Biryani (Boneless)', 'mutton biryani (boneless)', 'NON-VEG BIRYANI', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400081007184, 400081007, 'Prawns Biryani', 'prawns biryani', 'NON-VEG BIRYANI', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007185, 400081007, 'Dal Fry', 'dal fry', 'DAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007186, 400081007, 'Dal Tadka', 'dal tadka', 'DAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007187, 400081007, 'Dal Kolhapuri', 'dal kolhapuri', 'DAL', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007188, 400081007, 'Veg. Special Thali', 'veg. special thali', 'VEG THALI', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007189, 400081007, 'Veg. Fried Rice', 'veg. fried rice', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007190, 400081007, 'Veg. Schezwan Fried Rice', 'veg. schezwan fried rice', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007191, 400081007, 'Veg. Combination Rice', 'veg. combination rice', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007192, 400081007, 'Veg. Triple Schezwan Fried Rice', 'veg. triple schezwan fried rice', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007193, 400081007, 'Veg. Manchurian Fried Rice', 'veg. manchurian fried rice', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007194, 400081007, 'Veg. Sherpa Rice', 'veg. sherpa rice', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007195, 400081007, 'Veg. Burnt Garlic Rice', 'veg. burnt garlic rice', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007196, 400081007, 'Paneer Fried Rice', 'paneer fried rice', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007197, 400081007, 'Paneer Schezwan Fried Rice', 'paneer schezwan fried rice', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007198, 400081007, 'Mushroom Fried Rice', 'mushroom fried rice', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007199, 400081007, 'Mushroom Sz. Fried Rice', 'mushroom sz. fried rice', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007200, 400081007, 'Veg. Singapore Fried Rice', 'veg. singapore fried rice', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007201, 400081007, 'Veg. Hakka Noodles', 'veg. hakka noodles', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007202, 400081007, 'Veg. Schezwan Noodles', 'veg. schezwan noodles', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007203, 400081007, 'Veg. Triple Schezwan Noodle', 'veg. triple schezwan noodle', 'CHINESE VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007204, 400081007, 'Egg Fried Rice', 'egg fried rice', 'NON-VEG. RICE & NOODLES', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007205, 400081007, 'Chic. Fried Rice', 'chic. fried rice', 'NON-VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007206, 400081007, 'Chic. Pakoda Fried Rice', 'chic. pakoda fried rice', 'NON-VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007207, 400081007, 'Chic. Schezwan Fried Rice', 'chic. schezwan fried rice', 'NON-VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007208, 400081007, 'Chic. Combination Rice', 'chic. combination rice', 'NON-VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007209, 400081007, 'Chic. Triple Schezwan Fried Rice', 'chic. triple schezwan fried rice', 'NON-VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007210, 400081007, 'Chic. Manchurian Fried Rice', 'chic. manchurian fried rice', 'NON-VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007211, 400081007, 'Chic. Sherpa Rice', 'chic. sherpa rice', 'NON-VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007212, 400081007, 'Chic. Burnt Garlic Rice', 'chic. burnt garlic rice', 'NON-VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007213, 400081007, 'Chic. Singapore Fried Rice', 'chic. singapore fried rice', 'NON-VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007214, 400081007, 'Chic. Hakka Noodles', 'chic. hakka noodles', 'NON-VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007215, 400081007, 'Chic. Schezwan Noodles', 'chic. schezwan noodles', 'NON-VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007216, 400081007, 'Chic. Triple Schezwan Noodle', 'chic. triple schezwan noodle', 'NON-VEG. RICE & NOODLES', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400081007217, 400081007, 'Prawns Fried Rice', 'prawns fried rice', 'NON-VEG. RICE & NOODLES', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007218, 400081007, 'Prawns Schezwan Fried Rice', 'prawns schezwan fried rice', 'NON-VEG. RICE & NOODLES', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400081007219, 400081007, 'Prawns Triple Schezwan Fried Rice', 'prawns triple schezwan fried rice', 'NON-VEG. RICE & NOODLES', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified')
) AS x(menu_item_id, restaurant_id, name, normalized_name, raw_category_text, food_classification_code, protein_code, split_group_key, verification_status_code)
JOIN canonical_dish cd ON cd.normalized_name = x.normalized_name
LEFT JOIN protein_type pt ON pt.code = x.protein_code;

-- Menu item source: name/existence confidence, kept separate from price confidence.
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
VALUES
    (400081007001, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007002, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007003, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007004, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007005, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007006, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007007, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007008, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007009, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007010, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007011, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007012, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007013, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007014, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007015, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007016, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007017, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007018, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007019, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007020, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007021, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007022, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007023, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007024, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007025, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007026, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007027, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007028, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007029, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007030, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007031, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007032, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007033, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007034, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007035, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007036, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007037, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007038, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007039, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007040, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007041, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007042, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007043, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007044, 400081007, :extraction_batch_id, 0.9, 'needs_review'),
    (400081007045, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007046, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007047, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007048, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007049, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007050, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007051, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007052, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007053, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007054, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007055, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007056, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007057, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007058, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007059, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007060, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007061, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007062, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007063, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007064, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007065, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007066, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007067, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007068, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007069, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007070, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007071, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007072, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007073, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007074, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007075, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007076, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007077, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007078, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007079, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007080, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007081, 400081007, :extraction_batch_id, 0.9, 'needs_review'),
    (400081007082, 400081007, :extraction_batch_id, 0.9, 'needs_review'),
    (400081007083, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007084, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007085, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007086, 400081007, :extraction_batch_id, 0.9, 'needs_review'),
    (400081007087, 400081007, :extraction_batch_id, 0.9, 'needs_review'),
    (400081007088, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007089, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007090, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007091, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007092, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007093, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007094, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007095, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007096, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007097, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007098, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007099, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007100, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007101, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007102, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007103, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007104, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007105, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007106, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007107, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007108, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007109, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007110, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007111, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007112, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007113, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007114, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007115, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007116, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007117, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007118, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007119, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007120, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007121, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007122, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007123, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007124, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007125, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007126, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007127, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007128, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007129, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007130, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007131, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007132, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007133, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007134, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007135, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007136, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007137, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007138, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007139, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007140, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007141, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007142, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007143, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007144, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007145, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007146, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007147, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007148, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007149, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007150, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007151, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007152, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007153, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007154, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007155, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007156, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007157, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007158, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007159, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007160, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007161, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007162, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007163, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007164, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007165, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007166, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007167, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007168, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007169, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007170, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007171, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007172, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007173, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007174, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007175, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007176, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007177, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007178, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007179, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007180, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007181, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007182, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007183, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007184, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007185, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007186, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007187, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007188, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007189, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007190, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007191, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007192, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007193, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007194, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007195, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007196, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007197, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007198, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007199, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007200, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007201, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007202, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007203, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007204, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007205, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007206, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007207, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007208, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007209, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007210, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007211, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007212, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007213, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007214, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007215, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007216, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007217, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007218, 400081007, :extraction_batch_id, 0.9, 'unverified'),
    (400081007219, 400081007, :extraction_batch_id, 0.9, 'unverified');

-- Variants (portion/label variants -- one menu_item, multiple menu_item_variant rows;
-- a protein/veg split already became two separate menu_item rows above, so each carries
-- exactly one variant here).
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
VALUES
    (400081007001, 400081007001, 'Regular', 'fixed', TRUE),
    (400081007002, 400081007002, 'Regular', 'fixed', TRUE),
    (400081007003, 400081007003, 'Regular', 'fixed', TRUE),
    (400081007004, 400081007004, 'Regular', 'fixed', TRUE),
    (400081007005, 400081007005, 'Regular', 'fixed', TRUE),
    (400081007006, 400081007006, 'Regular', 'fixed', TRUE),
    (400081007007, 400081007007, 'Regular', 'fixed', TRUE),
    (400081007008, 400081007008, 'Regular', 'fixed', TRUE),
    (400081007009, 400081007009, 'Regular', 'fixed', TRUE),
    (400081007010, 400081007010, 'Regular', 'fixed', TRUE),
    (400081007011, 400081007011, 'Regular', 'fixed', TRUE),
    (400081007012, 400081007012, 'Regular', 'fixed', TRUE),
    (400081007013, 400081007013, 'Regular', 'fixed', TRUE),
    (400081007014, 400081007014, 'Regular', 'fixed', TRUE),
    (400081007015, 400081007015, 'Regular', 'fixed', TRUE),
    (400081007016, 400081007016, 'Regular', 'fixed', TRUE),
    (400081007017, 400081007017, 'Regular', 'fixed', TRUE),
    (400081007018, 400081007018, 'Regular', 'fixed', TRUE),
    (400081007019, 400081007019, 'Regular', 'fixed', TRUE),
    (400081007020, 400081007020, 'Regular', 'fixed', TRUE),
    (400081007021, 400081007021, 'Regular', 'fixed', TRUE),
    (400081007022, 400081007022, 'Regular', 'fixed', TRUE),
    (400081007023, 400081007023, 'Regular', 'fixed', TRUE),
    (400081007024, 400081007024, 'Regular', 'fixed', TRUE),
    (400081007025, 400081007025, 'Regular', 'fixed', TRUE),
    (400081007026, 400081007026, 'Regular', 'fixed', TRUE),
    (400081007027, 400081007027, 'Regular', 'fixed', TRUE),
    (400081007028, 400081007028, 'Regular', 'fixed', TRUE),
    (400081007029, 400081007029, 'Regular', 'fixed', TRUE),
    (400081007030, 400081007030, 'Regular', 'fixed', TRUE),
    (400081007031, 400081007031, 'Regular', 'fixed', TRUE),
    (400081007032, 400081007032, 'Regular', 'fixed', TRUE),
    (400081007033, 400081007033, 'Regular', 'fixed', TRUE),
    (400081007034, 400081007034, 'Regular', 'fixed', TRUE),
    (400081007035, 400081007035, 'Regular', 'fixed', TRUE),
    (400081007036, 400081007036, 'Regular', 'fixed', TRUE),
    (400081007037, 400081007037, 'Regular', 'fixed', TRUE),
    (400081007038, 400081007038, 'Regular', 'fixed', TRUE),
    (400081007039, 400081007039, 'Regular', 'fixed', TRUE),
    (400081007040, 400081007040, 'Regular', 'fixed', TRUE),
    (400081007041, 400081007041, 'Regular', 'fixed', TRUE),
    (400081007042, 400081007042, 'Regular', 'fixed', TRUE),
    (400081007043, 400081007043, 'Regular', 'fixed', TRUE),
    (400081007044, 400081007044, 'Regular', 'fixed', TRUE),
    (400081007045, 400081007045, 'Regular', 'fixed', TRUE),
    (400081007046, 400081007046, 'Regular', 'fixed', TRUE),
    (400081007047, 400081007047, 'Regular', 'fixed', TRUE),
    (400081007048, 400081007048, 'Regular', 'fixed', TRUE),
    (400081007049, 400081007049, 'Regular', 'fixed', TRUE),
    (400081007050, 400081007050, 'Regular', 'fixed', TRUE),
    (400081007051, 400081007051, 'Regular', 'fixed', TRUE),
    (400081007052, 400081007052, 'Regular', 'fixed', TRUE),
    (400081007053, 400081007053, 'Regular', 'fixed', TRUE),
    (400081007054, 400081007054, 'Regular', 'fixed', TRUE),
    (400081007055, 400081007055, 'Regular', 'fixed', TRUE),
    (400081007056, 400081007056, 'Regular', 'fixed', TRUE),
    (400081007057, 400081007057, 'Regular', 'fixed', TRUE),
    (400081007058, 400081007058, 'Regular', 'fixed', TRUE),
    (400081007059, 400081007059, 'Regular', 'fixed', TRUE),
    (400081007060, 400081007060, 'Regular', 'fixed', TRUE),
    (400081007061, 400081007061, 'Regular', 'fixed', TRUE),
    (400081007062, 400081007062, 'Regular', 'fixed', TRUE),
    (400081007063, 400081007063, 'Regular', 'fixed', TRUE),
    (400081007064, 400081007064, 'Regular', 'fixed', TRUE),
    (400081007065, 400081007065, 'Regular', 'fixed', TRUE),
    (400081007066, 400081007066, 'Regular', 'fixed', TRUE),
    (400081007067, 400081007067, 'Regular', 'fixed', TRUE),
    (400081007068, 400081007068, 'Regular', 'fixed', TRUE),
    (400081007069, 400081007069, 'Regular', 'fixed', TRUE),
    (400081007070, 400081007070, 'Regular', 'fixed', TRUE),
    (400081007071, 400081007071, 'Regular', 'fixed', TRUE),
    (400081007072, 400081007072, 'Regular', 'fixed', TRUE),
    (400081007073, 400081007073, 'Regular', 'fixed', TRUE),
    (400081007074, 400081007074, 'Regular', 'fixed', TRUE),
    (400081007075, 400081007075, 'Regular', 'fixed', TRUE),
    (400081007076, 400081007076, 'Regular', 'fixed', TRUE),
    (400081007077, 400081007077, 'Regular', 'fixed', TRUE),
    (400081007078, 400081007078, 'Regular', 'fixed', TRUE),
    (400081007079, 400081007079, 'Regular', 'fixed', TRUE),
    (400081007080, 400081007080, 'Regular', 'fixed', TRUE),
    (400081007081, 400081007081, 'Regular', 'fixed', TRUE),
    (400081007082, 400081007082, 'Regular', 'fixed', TRUE),
    (400081007083, 400081007083, 'Regular', 'fixed', TRUE),
    (400081007084, 400081007084, 'Regular', 'fixed', TRUE),
    (400081007085, 400081007085, 'Regular', 'fixed', TRUE),
    (400081007086, 400081007086, 'Regular', 'fixed', TRUE),
    (400081007087, 400081007087, 'Regular', 'fixed', TRUE),
    (400081007088, 400081007088, 'Regular', 'fixed', TRUE),
    (400081007089, 400081007089, 'Regular', 'fixed', TRUE),
    (400081007090, 400081007090, 'Regular', 'fixed', TRUE),
    (400081007091, 400081007091, 'Regular', 'fixed', TRUE),
    (400081007092, 400081007092, 'Regular', 'fixed', TRUE),
    (400081007093, 400081007093, 'Regular', 'fixed', TRUE),
    (400081007094, 400081007094, 'Regular', 'fixed', TRUE),
    (400081007095, 400081007095, 'Regular', 'fixed', TRUE),
    (400081007096, 400081007096, 'Regular', 'fixed', TRUE),
    (400081007097, 400081007097, 'Regular', 'fixed', TRUE),
    (400081007098, 400081007098, 'Regular', 'fixed', TRUE),
    (400081007099, 400081007099, 'Regular', 'fixed', TRUE),
    (400081007100, 400081007100, 'Regular', 'fixed', TRUE),
    (400081007101, 400081007101, 'Regular', 'fixed', TRUE),
    (400081007102, 400081007102, 'Regular', 'fixed', TRUE),
    (400081007103, 400081007103, 'Regular', 'fixed', TRUE),
    (400081007104, 400081007104, 'Regular', 'fixed', TRUE),
    (400081007105, 400081007105, 'Regular', 'fixed', TRUE),
    (400081007106, 400081007106, 'Regular', 'fixed', TRUE),
    (400081007107, 400081007107, 'Regular', 'fixed', TRUE),
    (400081007108, 400081007108, 'Regular', 'fixed', TRUE),
    (400081007109, 400081007109, 'Regular', 'fixed', TRUE),
    (400081007110, 400081007110, 'Regular', 'fixed', TRUE),
    (400081007111, 400081007111, 'Regular', 'fixed', TRUE),
    (400081007112, 400081007112, 'Regular', 'fixed', TRUE),
    (400081007113, 400081007113, 'Regular', 'fixed', TRUE),
    (400081007114, 400081007114, 'Regular', 'fixed', TRUE),
    (400081007115, 400081007115, 'Regular', 'fixed', TRUE),
    (400081007116, 400081007116, 'Regular', 'fixed', TRUE),
    (400081007117, 400081007117, 'Regular', 'fixed', TRUE),
    (400081007118, 400081007118, 'Regular', 'fixed', TRUE),
    (400081007119, 400081007119, 'Regular', 'fixed', TRUE),
    (400081007120, 400081007120, 'Regular', 'fixed', TRUE),
    (400081007121, 400081007121, 'Regular', 'fixed', TRUE),
    (400081007122, 400081007122, 'Regular', 'fixed', TRUE),
    (400081007123, 400081007123, 'Regular', 'fixed', TRUE),
    (400081007124, 400081007124, 'Regular', 'fixed', TRUE),
    (400081007125, 400081007125, 'Regular', 'fixed', TRUE),
    (400081007126, 400081007126, 'Regular', 'fixed', TRUE),
    (400081007127, 400081007127, 'Regular', 'fixed', TRUE),
    (400081007128, 400081007128, 'Regular', 'fixed', TRUE),
    (400081007129, 400081007129, 'Regular', 'fixed', TRUE),
    (400081007130, 400081007130, 'Regular', 'fixed', TRUE),
    (400081007131, 400081007131, 'Regular', 'fixed', TRUE),
    (400081007132, 400081007132, 'Regular', 'fixed', TRUE),
    (400081007133, 400081007133, 'Regular', 'fixed', TRUE),
    (400081007134, 400081007134, 'Regular', 'fixed', TRUE),
    (400081007135, 400081007135, 'Regular', 'fixed', TRUE),
    (400081007136, 400081007136, 'Regular', 'fixed', TRUE),
    (400081007137, 400081007137, 'Regular', 'fixed', TRUE),
    (400081007138, 400081007138, 'Regular', 'fixed', TRUE),
    (400081007139, 400081007139, 'Regular', 'fixed', TRUE),
    (400081007140, 400081007140, 'Regular', 'fixed', TRUE),
    (400081007141, 400081007141, 'Regular', 'fixed', TRUE),
    (400081007142, 400081007142, 'Regular', 'fixed', TRUE),
    (400081007143, 400081007143, 'Regular', 'fixed', TRUE),
    (400081007144, 400081007144, 'Regular', 'fixed', TRUE),
    (400081007145, 400081007145, 'Regular', 'fixed', TRUE),
    (400081007146, 400081007146, 'Regular', 'fixed', TRUE),
    (400081007147, 400081007147, 'Regular', 'fixed', TRUE),
    (400081007148, 400081007148, 'Regular', 'fixed', TRUE),
    (400081007149, 400081007149, 'Regular', 'fixed', TRUE),
    (400081007150, 400081007150, 'Regular', 'fixed', TRUE),
    (400081007151, 400081007151, 'Regular', 'fixed', TRUE),
    (400081007152, 400081007152, 'Regular', 'fixed', TRUE),
    (400081007153, 400081007153, 'Regular', 'fixed', TRUE),
    (400081007154, 400081007154, 'Regular', 'fixed', TRUE),
    (400081007155, 400081007155, 'Regular', 'fixed', TRUE),
    (400081007156, 400081007156, 'Regular', 'fixed', TRUE),
    (400081007157, 400081007157, 'Regular', 'fixed', TRUE),
    (400081007158, 400081007158, 'Regular', 'fixed', TRUE),
    (400081007159, 400081007159, 'Regular', 'fixed', TRUE),
    (400081007160, 400081007160, 'Regular', 'fixed', TRUE),
    (400081007161, 400081007161, 'Regular', 'fixed', TRUE),
    (400081007162, 400081007162, 'Regular', 'fixed', TRUE),
    (400081007163, 400081007163, 'Regular', 'fixed', TRUE),
    (400081007164, 400081007164, 'Regular', 'fixed', TRUE),
    (400081007165, 400081007165, 'Regular', 'fixed', TRUE),
    (400081007166, 400081007166, 'Regular', 'fixed', TRUE),
    (400081007167, 400081007167, 'Regular', 'fixed', TRUE),
    (400081007168, 400081007168, 'Regular', 'fixed', TRUE),
    (400081007169, 400081007169, 'Regular', 'fixed', TRUE),
    (400081007170, 400081007170, 'Regular', 'fixed', TRUE),
    (400081007171, 400081007171, 'Regular', 'fixed', TRUE),
    (400081007172, 400081007172, 'Regular', 'fixed', TRUE),
    (400081007173, 400081007173, 'Regular', 'fixed', TRUE),
    (400081007174, 400081007174, 'Regular', 'fixed', TRUE),
    (400081007175, 400081007175, 'Regular', 'fixed', TRUE),
    (400081007176, 400081007176, 'Regular', 'fixed', TRUE),
    (400081007177, 400081007177, 'Regular', 'fixed', TRUE),
    (400081007178, 400081007178, 'Regular', 'fixed', TRUE),
    (400081007179, 400081007179, 'Regular', 'fixed', TRUE),
    (400081007180, 400081007180, 'Regular', 'fixed', TRUE),
    (400081007181, 400081007181, 'Regular', 'fixed', TRUE),
    (400081007182, 400081007182, 'Regular', 'fixed', TRUE),
    (400081007183, 400081007183, 'Regular', 'fixed', TRUE),
    (400081007184, 400081007184, 'Regular', 'fixed', TRUE),
    (400081007185, 400081007185, 'Regular', 'fixed', TRUE),
    (400081007186, 400081007186, 'Regular', 'fixed', TRUE),
    (400081007187, 400081007187, 'Regular', 'fixed', TRUE),
    (400081007188, 400081007188, 'Regular', 'fixed', TRUE),
    (400081007189, 400081007189, 'Regular', 'fixed', TRUE),
    (400081007190, 400081007190, 'Regular', 'fixed', TRUE),
    (400081007191, 400081007191, 'Regular', 'fixed', TRUE),
    (400081007192, 400081007192, 'Regular', 'fixed', TRUE),
    (400081007193, 400081007193, 'Regular', 'fixed', TRUE),
    (400081007194, 400081007194, 'Regular', 'fixed', TRUE),
    (400081007195, 400081007195, 'Regular', 'fixed', TRUE),
    (400081007196, 400081007196, 'Regular', 'fixed', TRUE),
    (400081007197, 400081007197, 'Regular', 'fixed', TRUE),
    (400081007198, 400081007198, 'Regular', 'fixed', TRUE),
    (400081007199, 400081007199, 'Regular', 'fixed', TRUE),
    (400081007200, 400081007200, 'Regular', 'fixed', TRUE),
    (400081007201, 400081007201, 'Regular', 'fixed', TRUE),
    (400081007202, 400081007202, 'Regular', 'fixed', TRUE),
    (400081007203, 400081007203, 'Regular', 'fixed', TRUE),
    (400081007204, 400081007204, 'Regular', 'fixed', TRUE),
    (400081007205, 400081007205, 'Regular', 'fixed', TRUE),
    (400081007206, 400081007206, 'Regular', 'fixed', TRUE),
    (400081007207, 400081007207, 'Regular', 'fixed', TRUE),
    (400081007208, 400081007208, 'Regular', 'fixed', TRUE),
    (400081007209, 400081007209, 'Regular', 'fixed', TRUE),
    (400081007210, 400081007210, 'Regular', 'fixed', TRUE),
    (400081007211, 400081007211, 'Regular', 'fixed', TRUE),
    (400081007212, 400081007212, 'Regular', 'fixed', TRUE),
    (400081007213, 400081007213, 'Regular', 'fixed', TRUE),
    (400081007214, 400081007214, 'Regular', 'fixed', TRUE),
    (400081007215, 400081007215, 'Regular', 'fixed', TRUE),
    (400081007216, 400081007216, 'Regular', 'fixed', TRUE),
    (400081007217, 400081007217, 'Regular', 'fixed', TRUE),
    (400081007218, 400081007218, 'Regular', 'fixed', TRUE),
    (400081007219, 400081007219, 'Regular', 'fixed', TRUE);

-- Prices (only for variants where a numeric price was actually captured)
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
VALUES
    (400081007001, 400081007001, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007002, 400081007002, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007003, 400081007003, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007004, 400081007004, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007005, 400081007005, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007006, 400081007006, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007007, 400081007007, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007008, 400081007008, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007009, 400081007009, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007010, 400081007010, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007011, 400081007011, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007012, 400081007012, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007013, 400081007013, 55.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007014, 400081007014, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007015, 400081007015, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007016, 400081007016, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007017, 400081007017, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007018, 400081007018, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007019, 400081007019, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007020, 400081007020, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007021, 400081007021, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007022, 400081007022, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007023, 400081007023, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007024, 400081007024, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007025, 400081007025, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007026, 400081007026, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007027, 400081007027, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007028, 400081007028, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007029, 400081007029, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007030, 400081007030, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007031, 400081007031, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007032, 400081007032, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007033, 400081007033, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007034, 400081007034, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007035, 400081007035, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007036, 400081007036, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007037, 400081007037, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007038, 400081007038, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007039, 400081007039, 65.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007040, 400081007040, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007041, 400081007041, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007042, 400081007042, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007043, 400081007043, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007044, 400081007044, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007045, 400081007045, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007046, 400081007046, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007047, 400081007047, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007048, 400081007048, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007049, 400081007049, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007050, 400081007050, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007051, 400081007051, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007052, 400081007052, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007053, 400081007053, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007054, 400081007054, 550.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007055, 400081007055, 1050.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007056, 400081007056, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007057, 400081007057, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007058, 400081007058, 1100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007059, 400081007059, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007060, 400081007060, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007061, 400081007061, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007062, 400081007062, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007063, 400081007063, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007064, 400081007064, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007065, 400081007065, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007066, 400081007066, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007067, 400081007067, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007068, 400081007068, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007069, 400081007069, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007070, 400081007070, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007071, 400081007071, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007072, 400081007072, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007073, 400081007073, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007074, 400081007074, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007075, 400081007075, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007076, 400081007076, 420.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007077, 400081007077, 800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007078, 400081007078, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007079, 400081007079, 450.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007080, 400081007080, 850.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007081, 400081007083, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007082, 400081007084, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007083, 400081007085, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007084, 400081007088, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007085, 400081007089, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007086, 400081007090, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007087, 400081007091, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007088, 400081007092, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007089, 400081007093, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007090, 400081007094, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007091, 400081007095, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007092, 400081007096, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007093, 400081007097, 440.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007094, 400081007098, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007095, 400081007099, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007096, 400081007100, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007097, 400081007101, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007098, 400081007102, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007099, 400081007103, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007100, 400081007104, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007101, 400081007105, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007102, 400081007106, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007103, 400081007107, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007104, 400081007108, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007105, 400081007109, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007106, 400081007110, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007107, 400081007111, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007108, 400081007112, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007109, 400081007113, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007110, 400081007114, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007111, 400081007115, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007112, 400081007116, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007113, 400081007117, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007114, 400081007118, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007115, 400081007119, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007116, 400081007120, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007117, 400081007121, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007118, 400081007122, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007119, 400081007123, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007120, 400081007124, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007121, 400081007125, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007122, 400081007126, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007123, 400081007127, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007124, 400081007128, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007125, 400081007129, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007126, 400081007130, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007127, 400081007131, 550.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007128, 400081007132, 470.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007129, 400081007133, 800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007130, 400081007134, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007131, 400081007135, 570.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007132, 400081007136, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007133, 400081007137, 590.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007134, 400081007138, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007135, 400081007139, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007136, 400081007140, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007137, 400081007141, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007138, 400081007142, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007139, 400081007143, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007140, 400081007144, 450.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007141, 400081007145, 800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007142, 400081007146, 460.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007143, 400081007147, 800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007144, 400081007148, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007145, 400081007149, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007146, 400081007150, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007147, 400081007151, 115.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007148, 400081007152, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007149, 400081007153, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007150, 400081007154, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007151, 400081007155, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007152, 400081007156, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007153, 400081007157, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007154, 400081007158, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007155, 400081007159, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007156, 400081007160, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007157, 400081007161, 12.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007158, 400081007162, 15.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007159, 400081007163, 26.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007160, 400081007164, 27.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007161, 400081007165, 34.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007162, 400081007166, 39.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007163, 400081007167, 42.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007164, 400081007168, 42.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007165, 400081007169, 47.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007166, 400081007170, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007167, 400081007171, 45.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007168, 400081007172, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007169, 400081007173, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007170, 400081007174, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007171, 400081007175, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007172, 400081007176, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007173, 400081007177, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007174, 400081007178, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007175, 400081007179, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007176, 400081007180, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007177, 400081007181, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007178, 400081007182, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007179, 400081007183, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007180, 400081007184, 390.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007181, 400081007185, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007182, 400081007186, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007183, 400081007187, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007184, 400081007188, 199.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007185, 400081007189, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007186, 400081007190, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007187, 400081007191, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007188, 400081007192, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007189, 400081007193, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007190, 400081007194, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007191, 400081007195, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007192, 400081007196, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007193, 400081007197, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007194, 400081007198, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007195, 400081007199, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007196, 400081007200, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007197, 400081007201, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007198, 400081007202, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007199, 400081007203, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007200, 400081007204, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007201, 400081007205, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007202, 400081007206, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007203, 400081007207, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007204, 400081007208, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007205, 400081007209, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007206, 400081007210, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007207, 400081007211, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007208, 400081007212, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007209, 400081007213, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007210, 400081007214, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007211, 400081007215, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007212, 400081007216, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007213, 400081007217, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007214, 400081007218, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified'),
    (400081007215, 400081007219, 430.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400081007, 'unverified');

-- Price source (price-specific confidence, tracked separately from item confidence)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
VALUES
    (400081007001, 400081007, :extraction_batch_id, 0.95),
    (400081007002, 400081007, :extraction_batch_id, 0.95),
    (400081007003, 400081007, :extraction_batch_id, 0.95),
    (400081007004, 400081007, :extraction_batch_id, 0.95),
    (400081007005, 400081007, :extraction_batch_id, 0.95),
    (400081007006, 400081007, :extraction_batch_id, 0.95),
    (400081007007, 400081007, :extraction_batch_id, 0.95),
    (400081007008, 400081007, :extraction_batch_id, 0.95),
    (400081007009, 400081007, :extraction_batch_id, 0.95),
    (400081007010, 400081007, :extraction_batch_id, 0.95),
    (400081007011, 400081007, :extraction_batch_id, 0.95),
    (400081007012, 400081007, :extraction_batch_id, 0.95),
    (400081007013, 400081007, :extraction_batch_id, 0.95),
    (400081007014, 400081007, :extraction_batch_id, 0.95),
    (400081007015, 400081007, :extraction_batch_id, 0.95),
    (400081007016, 400081007, :extraction_batch_id, 0.95),
    (400081007017, 400081007, :extraction_batch_id, 0.95),
    (400081007018, 400081007, :extraction_batch_id, 0.95),
    (400081007019, 400081007, :extraction_batch_id, 0.95),
    (400081007020, 400081007, :extraction_batch_id, 0.95),
    (400081007021, 400081007, :extraction_batch_id, 0.95),
    (400081007022, 400081007, :extraction_batch_id, 0.95),
    (400081007023, 400081007, :extraction_batch_id, 0.95),
    (400081007024, 400081007, :extraction_batch_id, 0.95),
    (400081007025, 400081007, :extraction_batch_id, 0.95),
    (400081007026, 400081007, :extraction_batch_id, 0.95),
    (400081007027, 400081007, :extraction_batch_id, 0.95),
    (400081007028, 400081007, :extraction_batch_id, 0.95),
    (400081007029, 400081007, :extraction_batch_id, 0.95),
    (400081007030, 400081007, :extraction_batch_id, 0.95),
    (400081007031, 400081007, :extraction_batch_id, 0.95),
    (400081007032, 400081007, :extraction_batch_id, 0.95),
    (400081007033, 400081007, :extraction_batch_id, 0.95),
    (400081007034, 400081007, :extraction_batch_id, 0.95),
    (400081007035, 400081007, :extraction_batch_id, 0.95),
    (400081007036, 400081007, :extraction_batch_id, 0.95),
    (400081007037, 400081007, :extraction_batch_id, 0.95),
    (400081007038, 400081007, :extraction_batch_id, 0.95),
    (400081007039, 400081007, :extraction_batch_id, 0.95),
    (400081007040, 400081007, :extraction_batch_id, 0.95),
    (400081007041, 400081007, :extraction_batch_id, 0.95),
    (400081007042, 400081007, :extraction_batch_id, 0.95),
    (400081007043, 400081007, :extraction_batch_id, 0.95),
    (400081007044, 400081007, :extraction_batch_id, 0.95),
    (400081007045, 400081007, :extraction_batch_id, 0.95),
    (400081007046, 400081007, :extraction_batch_id, 0.95),
    (400081007047, 400081007, :extraction_batch_id, 0.95),
    (400081007048, 400081007, :extraction_batch_id, 0.95),
    (400081007049, 400081007, :extraction_batch_id, 0.95),
    (400081007050, 400081007, :extraction_batch_id, 0.95),
    (400081007051, 400081007, :extraction_batch_id, 0.95),
    (400081007052, 400081007, :extraction_batch_id, 0.95),
    (400081007053, 400081007, :extraction_batch_id, 0.95),
    (400081007054, 400081007, :extraction_batch_id, 0.95),
    (400081007055, 400081007, :extraction_batch_id, 0.95),
    (400081007056, 400081007, :extraction_batch_id, 0.95),
    (400081007057, 400081007, :extraction_batch_id, 0.95),
    (400081007058, 400081007, :extraction_batch_id, 0.95),
    (400081007059, 400081007, :extraction_batch_id, 0.95),
    (400081007060, 400081007, :extraction_batch_id, 0.95),
    (400081007061, 400081007, :extraction_batch_id, 0.95),
    (400081007062, 400081007, :extraction_batch_id, 0.95),
    (400081007063, 400081007, :extraction_batch_id, 0.95),
    (400081007064, 400081007, :extraction_batch_id, 0.95),
    (400081007065, 400081007, :extraction_batch_id, 0.95),
    (400081007066, 400081007, :extraction_batch_id, 0.95),
    (400081007067, 400081007, :extraction_batch_id, 0.95),
    (400081007068, 400081007, :extraction_batch_id, 0.95),
    (400081007069, 400081007, :extraction_batch_id, 0.95),
    (400081007070, 400081007, :extraction_batch_id, 0.95),
    (400081007071, 400081007, :extraction_batch_id, 0.95),
    (400081007072, 400081007, :extraction_batch_id, 0.95),
    (400081007073, 400081007, :extraction_batch_id, 0.95),
    (400081007074, 400081007, :extraction_batch_id, 0.95),
    (400081007075, 400081007, :extraction_batch_id, 0.95),
    (400081007076, 400081007, :extraction_batch_id, 0.95),
    (400081007077, 400081007, :extraction_batch_id, 0.95),
    (400081007078, 400081007, :extraction_batch_id, 0.95),
    (400081007079, 400081007, :extraction_batch_id, 0.95),
    (400081007080, 400081007, :extraction_batch_id, 0.95),
    (400081007081, 400081007, :extraction_batch_id, 0.95),
    (400081007082, 400081007, :extraction_batch_id, 0.95),
    (400081007083, 400081007, :extraction_batch_id, 0.95),
    (400081007084, 400081007, :extraction_batch_id, 0.95),
    (400081007085, 400081007, :extraction_batch_id, 0.95),
    (400081007086, 400081007, :extraction_batch_id, 0.95),
    (400081007087, 400081007, :extraction_batch_id, 0.95),
    (400081007088, 400081007, :extraction_batch_id, 0.95),
    (400081007089, 400081007, :extraction_batch_id, 0.95),
    (400081007090, 400081007, :extraction_batch_id, 0.95),
    (400081007091, 400081007, :extraction_batch_id, 0.95),
    (400081007092, 400081007, :extraction_batch_id, 0.95),
    (400081007093, 400081007, :extraction_batch_id, 0.95),
    (400081007094, 400081007, :extraction_batch_id, 0.95),
    (400081007095, 400081007, :extraction_batch_id, 0.95),
    (400081007096, 400081007, :extraction_batch_id, 0.95),
    (400081007097, 400081007, :extraction_batch_id, 0.95),
    (400081007098, 400081007, :extraction_batch_id, 0.95),
    (400081007099, 400081007, :extraction_batch_id, 0.95),
    (400081007100, 400081007, :extraction_batch_id, 0.95),
    (400081007101, 400081007, :extraction_batch_id, 0.95),
    (400081007102, 400081007, :extraction_batch_id, 0.95),
    (400081007103, 400081007, :extraction_batch_id, 0.95),
    (400081007104, 400081007, :extraction_batch_id, 0.95),
    (400081007105, 400081007, :extraction_batch_id, 0.95),
    (400081007106, 400081007, :extraction_batch_id, 0.95),
    (400081007107, 400081007, :extraction_batch_id, 0.95),
    (400081007108, 400081007, :extraction_batch_id, 0.95),
    (400081007109, 400081007, :extraction_batch_id, 0.95),
    (400081007110, 400081007, :extraction_batch_id, 0.95),
    (400081007111, 400081007, :extraction_batch_id, 0.95),
    (400081007112, 400081007, :extraction_batch_id, 0.95),
    (400081007113, 400081007, :extraction_batch_id, 0.95),
    (400081007114, 400081007, :extraction_batch_id, 0.95),
    (400081007115, 400081007, :extraction_batch_id, 0.95),
    (400081007116, 400081007, :extraction_batch_id, 0.95),
    (400081007117, 400081007, :extraction_batch_id, 0.95),
    (400081007118, 400081007, :extraction_batch_id, 0.95),
    (400081007119, 400081007, :extraction_batch_id, 0.95),
    (400081007120, 400081007, :extraction_batch_id, 0.95),
    (400081007121, 400081007, :extraction_batch_id, 0.95),
    (400081007122, 400081007, :extraction_batch_id, 0.95),
    (400081007123, 400081007, :extraction_batch_id, 0.95),
    (400081007124, 400081007, :extraction_batch_id, 0.95),
    (400081007125, 400081007, :extraction_batch_id, 0.95),
    (400081007126, 400081007, :extraction_batch_id, 0.95),
    (400081007127, 400081007, :extraction_batch_id, 0.95),
    (400081007128, 400081007, :extraction_batch_id, 0.95),
    (400081007129, 400081007, :extraction_batch_id, 0.95),
    (400081007130, 400081007, :extraction_batch_id, 0.95),
    (400081007131, 400081007, :extraction_batch_id, 0.95),
    (400081007132, 400081007, :extraction_batch_id, 0.95),
    (400081007133, 400081007, :extraction_batch_id, 0.95),
    (400081007134, 400081007, :extraction_batch_id, 0.95),
    (400081007135, 400081007, :extraction_batch_id, 0.95),
    (400081007136, 400081007, :extraction_batch_id, 0.95),
    (400081007137, 400081007, :extraction_batch_id, 0.95),
    (400081007138, 400081007, :extraction_batch_id, 0.95),
    (400081007139, 400081007, :extraction_batch_id, 0.95),
    (400081007140, 400081007, :extraction_batch_id, 0.95),
    (400081007141, 400081007, :extraction_batch_id, 0.95),
    (400081007142, 400081007, :extraction_batch_id, 0.95),
    (400081007143, 400081007, :extraction_batch_id, 0.95),
    (400081007144, 400081007, :extraction_batch_id, 0.95),
    (400081007145, 400081007, :extraction_batch_id, 0.95),
    (400081007146, 400081007, :extraction_batch_id, 0.95),
    (400081007147, 400081007, :extraction_batch_id, 0.95),
    (400081007148, 400081007, :extraction_batch_id, 0.95),
    (400081007149, 400081007, :extraction_batch_id, 0.95),
    (400081007150, 400081007, :extraction_batch_id, 0.95),
    (400081007151, 400081007, :extraction_batch_id, 0.95),
    (400081007152, 400081007, :extraction_batch_id, 0.95),
    (400081007153, 400081007, :extraction_batch_id, 0.95),
    (400081007154, 400081007, :extraction_batch_id, 0.95),
    (400081007155, 400081007, :extraction_batch_id, 0.95),
    (400081007156, 400081007, :extraction_batch_id, 0.95),
    (400081007157, 400081007, :extraction_batch_id, 0.95),
    (400081007158, 400081007, :extraction_batch_id, 0.95),
    (400081007159, 400081007, :extraction_batch_id, 0.95),
    (400081007160, 400081007, :extraction_batch_id, 0.95),
    (400081007161, 400081007, :extraction_batch_id, 0.95),
    (400081007162, 400081007, :extraction_batch_id, 0.95),
    (400081007163, 400081007, :extraction_batch_id, 0.95),
    (400081007164, 400081007, :extraction_batch_id, 0.95),
    (400081007165, 400081007, :extraction_batch_id, 0.95),
    (400081007166, 400081007, :extraction_batch_id, 0.95),
    (400081007167, 400081007, :extraction_batch_id, 0.95),
    (400081007168, 400081007, :extraction_batch_id, 0.95),
    (400081007169, 400081007, :extraction_batch_id, 0.95),
    (400081007170, 400081007, :extraction_batch_id, 0.95),
    (400081007171, 400081007, :extraction_batch_id, 0.95),
    (400081007172, 400081007, :extraction_batch_id, 0.95),
    (400081007173, 400081007, :extraction_batch_id, 0.95),
    (400081007174, 400081007, :extraction_batch_id, 0.95),
    (400081007175, 400081007, :extraction_batch_id, 0.95),
    (400081007176, 400081007, :extraction_batch_id, 0.95),
    (400081007177, 400081007, :extraction_batch_id, 0.95),
    (400081007178, 400081007, :extraction_batch_id, 0.95),
    (400081007179, 400081007, :extraction_batch_id, 0.95),
    (400081007180, 400081007, :extraction_batch_id, 0.95),
    (400081007181, 400081007, :extraction_batch_id, 0.95),
    (400081007182, 400081007, :extraction_batch_id, 0.95),
    (400081007183, 400081007, :extraction_batch_id, 0.95),
    (400081007184, 400081007, :extraction_batch_id, 0.95),
    (400081007185, 400081007, :extraction_batch_id, 0.95),
    (400081007186, 400081007, :extraction_batch_id, 0.95),
    (400081007187, 400081007, :extraction_batch_id, 0.95),
    (400081007188, 400081007, :extraction_batch_id, 0.95),
    (400081007189, 400081007, :extraction_batch_id, 0.95),
    (400081007190, 400081007, :extraction_batch_id, 0.95),
    (400081007191, 400081007, :extraction_batch_id, 0.95),
    (400081007192, 400081007, :extraction_batch_id, 0.95),
    (400081007193, 400081007, :extraction_batch_id, 0.95),
    (400081007194, 400081007, :extraction_batch_id, 0.95),
    (400081007195, 400081007, :extraction_batch_id, 0.95),
    (400081007196, 400081007, :extraction_batch_id, 0.95),
    (400081007197, 400081007, :extraction_batch_id, 0.95),
    (400081007198, 400081007, :extraction_batch_id, 0.95),
    (400081007199, 400081007, :extraction_batch_id, 0.95),
    (400081007200, 400081007, :extraction_batch_id, 0.95),
    (400081007201, 400081007, :extraction_batch_id, 0.95),
    (400081007202, 400081007, :extraction_batch_id, 0.95),
    (400081007203, 400081007, :extraction_batch_id, 0.95),
    (400081007204, 400081007, :extraction_batch_id, 0.95),
    (400081007205, 400081007, :extraction_batch_id, 0.95),
    (400081007206, 400081007, :extraction_batch_id, 0.95),
    (400081007207, 400081007, :extraction_batch_id, 0.95),
    (400081007208, 400081007, :extraction_batch_id, 0.95),
    (400081007209, 400081007, :extraction_batch_id, 0.95),
    (400081007210, 400081007, :extraction_batch_id, 0.95),
    (400081007211, 400081007, :extraction_batch_id, 0.95),
    (400081007212, 400081007, :extraction_batch_id, 0.95),
    (400081007213, 400081007, :extraction_batch_id, 0.95),
    (400081007214, 400081007, :extraction_batch_id, 0.95),
    (400081007215, 400081007, :extraction_batch_id, 0.95);

-- Board <-> item mapping
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
VALUES
    (400081007001, 400081007, 400081007001, 400081007001, 400081007001, 1),
    (400081007002, 400081007, 400081007001, 400081007002, 400081007001, 2),
    (400081007003, 400081007, 400081007001, 400081007003, 400081007001, 3),
    (400081007004, 400081007, 400081007001, 400081007004, 400081007001, 4),
    (400081007005, 400081007, 400081007001, 400081007005, 400081007002, 1),
    (400081007006, 400081007, 400081007001, 400081007006, 400081007002, 2),
    (400081007007, 400081007, 400081007001, 400081007007, 400081007002, 3),
    (400081007008, 400081007, 400081007001, 400081007008, 400081007003, 1),
    (400081007009, 400081007, 400081007001, 400081007009, 400081007003, 2),
    (400081007010, 400081007, 400081007001, 400081007010, 400081007004, 1),
    (400081007011, 400081007, 400081007001, 400081007011, 400081007004, 2),
    (400081007012, 400081007, 400081007001, 400081007012, 400081007004, 3),
    (400081007013, 400081007, 400081007001, 400081007013, 400081007004, 4),
    (400081007014, 400081007, 400081007001, 400081007014, 400081007004, 5),
    (400081007015, 400081007, 400081007001, 400081007015, 400081007004, 6),
    (400081007016, 400081007, 400081007001, 400081007016, 400081007004, 7),
    (400081007017, 400081007, 400081007001, 400081007017, 400081007005, 1),
    (400081007018, 400081007, 400081007001, 400081007018, 400081007005, 2),
    (400081007019, 400081007, 400081007001, 400081007019, 400081007005, 3),
    (400081007020, 400081007, 400081007001, 400081007020, 400081007005, 4),
    (400081007021, 400081007, 400081007001, 400081007021, 400081007005, 5),
    (400081007022, 400081007, 400081007001, 400081007022, 400081007005, 6),
    (400081007023, 400081007, 400081007001, 400081007023, 400081007005, 7),
    (400081007024, 400081007, 400081007001, 400081007024, 400081007005, 8),
    (400081007025, 400081007, 400081007001, 400081007025, 400081007005, 9),
    (400081007026, 400081007, 400081007001, 400081007026, 400081007005, 10),
    (400081007027, 400081007, 400081007001, 400081007027, 400081007005, 11),
    (400081007028, 400081007, 400081007001, 400081007028, 400081007005, 12),
    (400081007029, 400081007, 400081007001, 400081007029, 400081007006, 1),
    (400081007030, 400081007, 400081007001, 400081007030, 400081007006, 2),
    (400081007031, 400081007, 400081007001, 400081007031, 400081007006, 3),
    (400081007032, 400081007, 400081007001, 400081007032, 400081007006, 4),
    (400081007033, 400081007, 400081007001, 400081007033, 400081007006, 5),
    (400081007034, 400081007, 400081007001, 400081007034, 400081007006, 6),
    (400081007035, 400081007, 400081007001, 400081007035, 400081007006, 7),
    (400081007036, 400081007, 400081007001, 400081007036, 400081007006, 8),
    (400081007037, 400081007, 400081007001, 400081007037, 400081007006, 9),
    (400081007038, 400081007, 400081007001, 400081007038, 400081007007, 1),
    (400081007039, 400081007, 400081007001, 400081007039, 400081007007, 2),
    (400081007040, 400081007, 400081007001, 400081007040, 400081007007, 3),
    (400081007041, 400081007, 400081007001, 400081007041, 400081007007, 4),
    (400081007042, 400081007, 400081007001, 400081007042, 400081007007, 5),
    (400081007043, 400081007, 400081007001, 400081007043, 400081007007, 6),
    (400081007044, 400081007, 400081007001, 400081007044, 400081007008, 1),
    (400081007045, 400081007, 400081007001, 400081007045, 400081007008, 2),
    (400081007046, 400081007, 400081007001, 400081007046, 400081007008, 3),
    (400081007047, 400081007, 400081007001, 400081007047, 400081007008, 4),
    (400081007048, 400081007, 400081007001, 400081007048, 400081007008, 5),
    (400081007049, 400081007, 400081007001, 400081007049, 400081007008, 6),
    (400081007050, 400081007, 400081007001, 400081007050, 400081007008, 7),
    (400081007051, 400081007, 400081007001, 400081007051, 400081007009, 1),
    (400081007052, 400081007, 400081007001, 400081007052, 400081007009, 2),
    (400081007053, 400081007, 400081007001, 400081007053, 400081007010, 1),
    (400081007054, 400081007, 400081007001, 400081007054, 400081007010, 2),
    (400081007055, 400081007, 400081007001, 400081007055, 400081007010, 3),
    (400081007056, 400081007, 400081007001, 400081007056, 400081007010, 4),
    (400081007057, 400081007, 400081007001, 400081007057, 400081007010, 5),
    (400081007058, 400081007, 400081007001, 400081007058, 400081007010, 6),
    (400081007059, 400081007, 400081007001, 400081007059, 400081007011, 1),
    (400081007060, 400081007, 400081007001, 400081007060, 400081007011, 2),
    (400081007061, 400081007, 400081007001, 400081007061, 400081007011, 3),
    (400081007062, 400081007, 400081007001, 400081007062, 400081007011, 4),
    (400081007063, 400081007, 400081007001, 400081007063, 400081007011, 5),
    (400081007064, 400081007, 400081007001, 400081007064, 400081007011, 6),
    (400081007065, 400081007, 400081007001, 400081007065, 400081007011, 7),
    (400081007066, 400081007, 400081007001, 400081007066, 400081007011, 8),
    (400081007067, 400081007, 400081007001, 400081007067, 400081007011, 9),
    (400081007068, 400081007, 400081007001, 400081007068, 400081007011, 10),
    (400081007069, 400081007, 400081007001, 400081007069, 400081007011, 11),
    (400081007070, 400081007, 400081007001, 400081007070, 400081007011, 12),
    (400081007071, 400081007, 400081007001, 400081007071, 400081007011, 13),
    (400081007072, 400081007, 400081007001, 400081007072, 400081007011, 14),
    (400081007073, 400081007, 400081007001, 400081007073, 400081007011, 15),
    (400081007074, 400081007, 400081007001, 400081007074, 400081007011, 16),
    (400081007075, 400081007, 400081007001, 400081007075, 400081007012, 1),
    (400081007076, 400081007, 400081007001, 400081007076, 400081007012, 2),
    (400081007077, 400081007, 400081007001, 400081007077, 400081007012, 3),
    (400081007078, 400081007, 400081007001, 400081007078, 400081007012, 4),
    (400081007079, 400081007, 400081007001, 400081007079, 400081007012, 5),
    (400081007080, 400081007, 400081007001, 400081007080, 400081007012, 6),
    (400081007081, 400081007, 400081007001, 400081007081, 400081007013, 1),
    (400081007082, 400081007, 400081007001, 400081007082, 400081007013, 2),
    (400081007083, 400081007, 400081007001, 400081007083, 400081007013, 3),
    (400081007084, 400081007, 400081007001, 400081007084, 400081007013, 4),
    (400081007085, 400081007, 400081007001, 400081007085, 400081007013, 5),
    (400081007086, 400081007, 400081007001, 400081007086, 400081007013, 6),
    (400081007087, 400081007, 400081007001, 400081007087, 400081007013, 7),
    (400081007088, 400081007, 400081007001, 400081007088, 400081007013, 8),
    (400081007089, 400081007, 400081007001, 400081007089, 400081007013, 9),
    (400081007090, 400081007, 400081007001, 400081007090, 400081007013, 10),
    (400081007091, 400081007, 400081007001, 400081007091, 400081007013, 11),
    (400081007092, 400081007, 400081007001, 400081007092, 400081007013, 12),
    (400081007093, 400081007, 400081007001, 400081007093, 400081007014, 1),
    (400081007094, 400081007, 400081007001, 400081007094, 400081007014, 2),
    (400081007095, 400081007, 400081007001, 400081007095, 400081007014, 3),
    (400081007096, 400081007, 400081007001, 400081007096, 400081007014, 4),
    (400081007097, 400081007, 400081007001, 400081007097, 400081007014, 5),
    (400081007098, 400081007, 400081007001, 400081007098, 400081007014, 6),
    (400081007099, 400081007, 400081007001, 400081007099, 400081007014, 7),
    (400081007100, 400081007, 400081007001, 400081007100, 400081007014, 8),
    (400081007101, 400081007, 400081007001, 400081007101, 400081007014, 9),
    (400081007102, 400081007, 400081007001, 400081007102, 400081007014, 10),
    (400081007103, 400081007, 400081007001, 400081007103, 400081007014, 11),
    (400081007104, 400081007, 400081007001, 400081007104, 400081007014, 12),
    (400081007105, 400081007, 400081007001, 400081007105, 400081007014, 13),
    (400081007106, 400081007, 400081007001, 400081007106, 400081007014, 14),
    (400081007107, 400081007, 400081007001, 400081007107, 400081007014, 15),
    (400081007108, 400081007, 400081007001, 400081007108, 400081007015, 1),
    (400081007109, 400081007, 400081007001, 400081007109, 400081007015, 2),
    (400081007110, 400081007, 400081007001, 400081007110, 400081007015, 3),
    (400081007111, 400081007, 400081007001, 400081007111, 400081007015, 4),
    (400081007112, 400081007, 400081007001, 400081007112, 400081007015, 5),
    (400081007113, 400081007, 400081007001, 400081007113, 400081007015, 6),
    (400081007114, 400081007, 400081007001, 400081007114, 400081007015, 7),
    (400081007115, 400081007, 400081007001, 400081007115, 400081007015, 8),
    (400081007116, 400081007, 400081007001, 400081007116, 400081007015, 9),
    (400081007117, 400081007, 400081007001, 400081007117, 400081007015, 10),
    (400081007118, 400081007, 400081007001, 400081007118, 400081007015, 11),
    (400081007119, 400081007, 400081007001, 400081007119, 400081007015, 12),
    (400081007120, 400081007, 400081007001, 400081007120, 400081007015, 13),
    (400081007121, 400081007, 400081007001, 400081007121, 400081007015, 14),
    (400081007122, 400081007, 400081007001, 400081007122, 400081007015, 15),
    (400081007123, 400081007, 400081007001, 400081007123, 400081007015, 16),
    (400081007124, 400081007, 400081007001, 400081007124, 400081007015, 17),
    (400081007125, 400081007, 400081007001, 400081007125, 400081007015, 18),
    (400081007126, 400081007, 400081007001, 400081007126, 400081007015, 19),
    (400081007127, 400081007, 400081007001, 400081007127, 400081007015, 20),
    (400081007128, 400081007, 400081007001, 400081007128, 400081007015, 21),
    (400081007129, 400081007, 400081007001, 400081007129, 400081007015, 22),
    (400081007130, 400081007, 400081007001, 400081007130, 400081007016, 1),
    (400081007131, 400081007, 400081007001, 400081007131, 400081007016, 2),
    (400081007132, 400081007, 400081007001, 400081007132, 400081007016, 3),
    (400081007133, 400081007, 400081007001, 400081007133, 400081007016, 4),
    (400081007134, 400081007, 400081007001, 400081007134, 400081007016, 5),
    (400081007135, 400081007, 400081007001, 400081007135, 400081007016, 6),
    (400081007136, 400081007, 400081007001, 400081007136, 400081007016, 7),
    (400081007137, 400081007, 400081007001, 400081007137, 400081007016, 8),
    (400081007138, 400081007, 400081007001, 400081007138, 400081007016, 9),
    (400081007139, 400081007, 400081007001, 400081007139, 400081007016, 10),
    (400081007140, 400081007, 400081007001, 400081007140, 400081007016, 11),
    (400081007141, 400081007, 400081007001, 400081007141, 400081007016, 12),
    (400081007142, 400081007, 400081007001, 400081007142, 400081007016, 13),
    (400081007143, 400081007, 400081007001, 400081007143, 400081007016, 14),
    (400081007144, 400081007, 400081007001, 400081007144, 400081007016, 15),
    (400081007145, 400081007, 400081007001, 400081007145, 400081007016, 16),
    (400081007146, 400081007, 400081007001, 400081007146, 400081007016, 17),
    (400081007147, 400081007, 400081007001, 400081007147, 400081007016, 18),
    (400081007148, 400081007, 400081007001, 400081007148, 400081007016, 19),
    (400081007149, 400081007, 400081007001, 400081007149, 400081007016, 20),
    (400081007150, 400081007, 400081007001, 400081007150, 400081007016, 21),
    (400081007151, 400081007, 400081007001, 400081007151, 400081007017, 1),
    (400081007152, 400081007, 400081007001, 400081007152, 400081007017, 2),
    (400081007153, 400081007, 400081007001, 400081007153, 400081007017, 3),
    (400081007154, 400081007, 400081007001, 400081007154, 400081007017, 4),
    (400081007155, 400081007, 400081007001, 400081007155, 400081007017, 5),
    (400081007156, 400081007, 400081007001, 400081007156, 400081007017, 6),
    (400081007157, 400081007, 400081007001, 400081007157, 400081007017, 7),
    (400081007158, 400081007, 400081007001, 400081007158, 400081007017, 8),
    (400081007159, 400081007, 400081007001, 400081007159, 400081007017, 9),
    (400081007160, 400081007, 400081007001, 400081007160, 400081007017, 10),
    (400081007161, 400081007, 400081007001, 400081007161, 400081007018, 1),
    (400081007162, 400081007, 400081007001, 400081007162, 400081007018, 2),
    (400081007163, 400081007, 400081007001, 400081007163, 400081007018, 3),
    (400081007164, 400081007, 400081007001, 400081007164, 400081007018, 4),
    (400081007165, 400081007, 400081007001, 400081007165, 400081007018, 5),
    (400081007166, 400081007, 400081007001, 400081007166, 400081007018, 6),
    (400081007167, 400081007, 400081007001, 400081007167, 400081007018, 7),
    (400081007168, 400081007, 400081007001, 400081007168, 400081007018, 8),
    (400081007169, 400081007, 400081007001, 400081007169, 400081007018, 9),
    (400081007170, 400081007, 400081007001, 400081007170, 400081007018, 10),
    (400081007171, 400081007, 400081007001, 400081007171, 400081007018, 11),
    (400081007172, 400081007, 400081007001, 400081007172, 400081007018, 12),
    (400081007173, 400081007, 400081007001, 400081007173, 400081007018, 13),
    (400081007174, 400081007, 400081007001, 400081007174, 400081007019, 1),
    (400081007175, 400081007, 400081007001, 400081007175, 400081007019, 2),
    (400081007176, 400081007, 400081007001, 400081007176, 400081007019, 3),
    (400081007177, 400081007, 400081007001, 400081007177, 400081007019, 4),
    (400081007178, 400081007, 400081007001, 400081007178, 400081007019, 5),
    (400081007179, 400081007, 400081007001, 400081007179, 400081007019, 6),
    (400081007180, 400081007, 400081007001, 400081007180, 400081007019, 7),
    (400081007181, 400081007, 400081007001, 400081007181, 400081007019, 8),
    (400081007182, 400081007, 400081007001, 400081007182, 400081007019, 9),
    (400081007183, 400081007, 400081007001, 400081007183, 400081007019, 10),
    (400081007184, 400081007, 400081007001, 400081007184, 400081007019, 11),
    (400081007185, 400081007, 400081007001, 400081007185, 400081007020, 1),
    (400081007186, 400081007, 400081007001, 400081007186, 400081007020, 2),
    (400081007187, 400081007, 400081007001, 400081007187, 400081007020, 3),
    (400081007188, 400081007, 400081007001, 400081007188, 400081007021, 1),
    (400081007189, 400081007, 400081007001, 400081007189, 400081007022, 1),
    (400081007190, 400081007, 400081007001, 400081007190, 400081007022, 2),
    (400081007191, 400081007, 400081007001, 400081007191, 400081007022, 3),
    (400081007192, 400081007, 400081007001, 400081007192, 400081007022, 4),
    (400081007193, 400081007, 400081007001, 400081007193, 400081007022, 5),
    (400081007194, 400081007, 400081007001, 400081007194, 400081007022, 6),
    (400081007195, 400081007, 400081007001, 400081007195, 400081007022, 7),
    (400081007196, 400081007, 400081007001, 400081007196, 400081007022, 8),
    (400081007197, 400081007, 400081007001, 400081007197, 400081007022, 9),
    (400081007198, 400081007, 400081007001, 400081007198, 400081007022, 10),
    (400081007199, 400081007, 400081007001, 400081007199, 400081007022, 11),
    (400081007200, 400081007, 400081007001, 400081007200, 400081007022, 12),
    (400081007201, 400081007, 400081007001, 400081007201, 400081007022, 13),
    (400081007202, 400081007, 400081007001, 400081007202, 400081007022, 14),
    (400081007203, 400081007, 400081007001, 400081007203, 400081007022, 15),
    (400081007204, 400081007, 400081007001, 400081007204, 400081007023, 1),
    (400081007205, 400081007, 400081007001, 400081007205, 400081007023, 2),
    (400081007206, 400081007, 400081007001, 400081007206, 400081007023, 3),
    (400081007207, 400081007, 400081007001, 400081007207, 400081007023, 4),
    (400081007208, 400081007, 400081007001, 400081007208, 400081007023, 5),
    (400081007209, 400081007, 400081007001, 400081007209, 400081007023, 6),
    (400081007210, 400081007, 400081007001, 400081007210, 400081007023, 7),
    (400081007211, 400081007, 400081007001, 400081007211, 400081007023, 8),
    (400081007212, 400081007, 400081007001, 400081007212, 400081007023, 9),
    (400081007213, 400081007, 400081007001, 400081007213, 400081007023, 10),
    (400081007214, 400081007, 400081007001, 400081007214, 400081007023, 11),
    (400081007215, 400081007, 400081007001, 400081007215, 400081007023, 12),
    (400081007216, 400081007, 400081007001, 400081007216, 400081007023, 13),
    (400081007217, 400081007, 400081007001, 400081007217, 400081007023, 14),
    (400081007218, 400081007, 400081007001, 400081007218, 400081007023, 15),
    (400081007219, 400081007, 400081007001, 400081007219, 400081007023, 16);

-- === NEEDS-REVIEW ITEMS ===
-- menu_item_id 400081007044 (Liver Potta Koliwada 250gm): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400081007081 (Pomfret Curry / Regular): non-numeric price text in source: 'APS' (market/seasonal price) (confidence 0.5)
-- menu_item_id 400081007082 (Surmai Curry / Regular): non-numeric price text in source: 'APS' (market/seasonal price) (confidence 0.5)
-- menu_item_id 400081007086 (Pomfret Tawa Fry / Regular): non-numeric price text in source: 'APS' (market/seasonal price) (confidence 0.5)
-- menu_item_id 400081007087 (Surmai Tawa Fry / Regular): non-numeric price text in source: 'APS' (market/seasonal price) (confidence 0.5)

-- === UNMAPPED / INFORMATIONAL RESTAURANT-LEVEL NOTES ===
-- Page text mentions "...KITCHEN & BAR" but no bar/alcohol menu items appear anywhere in this JSON -- bar_license_type defaulted to 'none' per the prompt's stated default rule (missing in JSON -> 'none'); verify whether this restaurant actually serves alcohol and needs has_bar/bar_license_type set explicitly.
-- HALAL: attempted as a restaurant_tag lookup against platform_tag (tag_code='halal') above; if that tag doesn't exist yet in the live database the insert was a no-op -- verify and add the tag if it should exist.
-- 'NO BEEF' page notice: informational assurance text, not a formal dietary tag/column; not inserted anywhere.

COMMIT;