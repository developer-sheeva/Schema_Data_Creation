-- Khaustan menu onboarding: Arabian Dastarkhwan Family Restaurant
-- Source JSON: arabian_dastarkhwan_menu_ocr.json
-- Source image(s): 1000468426.jpg, 1000468425.jpg
-- establishment_id / restaurant_id / source_id namespace: 400070018 (taken directly from the source JSON)
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
    400070018, 'Arabian Dastarkhwan Family Restaurant', 'arabian dastarkhwan family restaurant',
    'Lal Bahadur Shastri Marg', NULL, 'Kurla', 'Mumbai',
    'Maharashtra', 'IN', '400070', 19.080384991873295, 72.88072714906036
);

INSERT INTO restaurant (
    restaurant_id, establishment_id, display_name, normalized_name,
    veg_nonveg_status, has_bar, bar_license_type
) VALUES (
    400070018, 400070018, 'Arabian Dastarkhwan Family Restaurant', 'arabian dastarkhwan family restaurant',
    'veg_and_nonveg', FALSE, 'none'
);

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400070018, 'ai_menu_extraction', 'arabian_dastarkhwan_menu_ocr.json');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, status_code)
VALUES (nextval('khaustan_standalone_id_seq'), 400070018, 400070018, (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');
SELECT extraction_batch_id FROM menu_extraction_batch WHERE source_id = 400070018 ORDER BY extraction_batch_id DESC LIMIT 1 \gset

-- Phones
INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
VALUES
    (nextval('khaustan_standalone_id_seq'), 400070018, '9619090959', TRUE),
    (nextval('khaustan_standalone_id_seq'), 400070018, '9594222780', FALSE);

-- Hours: single stated window applied to every day (JSON gives one blanket timing,
-- no per-day breakdown) -- confidence: inferred blanket application, not per-day-confirmed.
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
VALUES
    (nextval('khaustan_standalone_id_seq'), 400070018, 1, 1, '11:00'::time, '00:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400070018, 2, 1, '11:00'::time, '00:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400070018, 3, 1, '11:00'::time, '00:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400070018, 4, 1, '11:00'::time, '00:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400070018, 5, 1, '11:00'::time, '00:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400070018, 6, 1, '11:00'::time, '00:00'::time),
    (nextval('khaustan_standalone_id_seq'), 400070018, 7, 1, '11:00'::time, '00:00'::time);

-- HALAL restaurant tag: safe lookup-only insert. If 'halal' isn't yet a platform_tag
-- tag_code, this JOIN matches zero rows and inserts nothing -- no error, no new lookup
-- row created (lookup tables are read-only for this script).
INSERT INTO restaurant_tag (restaurant_tag_id, restaurant_id, tag_id)
SELECT nextval('khaustan_standalone_id_seq'), 400070018, tag_id FROM platform_tag WHERE tag_code = 'halal';

-- Menu board: one a_la_carte board for the whole JSON source.
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code, is_active, display_sequence)
VALUES (400070018001, 400070018, 'Main Menu', 'a_la_carte', TRUE, 1);

-- Categories, in JSON/source order. Where the source nests a subcategory (e.g.
-- STARTERS -> INDIAN / CHINESE), the top-level name becomes a parent row and the
-- subcategory becomes its child via parent_category_id -- the leaf (child) is what
-- items attach to. A category name repeated across two distinct source sections (this
-- happens at least once in this batch) is kept as two separate rows, not merged --
-- these are keyed by source position, not by display name.
INSERT INTO menu_category (menu_category_id, restaurant_id, name, parent_category_id, display_sequence)
VALUES
    (400070018001, 400070018, 'SHORBA-AAT (SOUPS)', NULL, 1),
    (400070018002, 400070018, 'CHINESE SOUP', NULL, 2),
    (400070018003, 400070018, 'SALAD', NULL, 3),
    (400070018004, 400070018, 'MIX PLATERS', NULL, 4),
    (400070018005, 400070018, 'MUQABBAL-AAT CHICKEN (STARTER)', NULL, 5),
    (400070018006, 400070018, 'MUQABBAL-AAT MUTTON (STARTER)', NULL, 6),
    (400070018007, 400070018, 'AISH RICE (MUTTON MANDI)', NULL, 7),
    (400070018008, 400070018, 'AISH RICE (CHICKEN MANDI)', NULL, 8),
    (400070018009, 400070018, 'EXTRA RICE (EXTRA PCS.)', NULL, 9),
    (400070018010, 400070018, 'ARABIAN DASTARKHWAN SPECIAL THAL', NULL, 10),
    (400070018011, 400070018, 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', NULL, 11),
    (400070018012, 400070018, 'MUTTON GRAVY', NULL, 12),
    (400070018013, 400070018, 'SEA FOOD', NULL, 13),
    (400070018014, 400070018, 'VEG. STARTERS', NULL, 14),
    (400070018015, 400070018, 'VEG. GRAVY', NULL, 15),
    (400070018016, 400070018, 'Dal', NULL, 16),
    (400070018017, 400070018, 'KHABOOS (BREADS)', NULL, 17),
    (400070018018, 400070018, 'CHICKEN STARTERS', NULL, 18),
    (400070018019, 400070018, 'CHINESE RICE', NULL, 19),
    (400070018020, 400070018, 'CHINESE NOODLES', NULL, 20),
    (400070018021, 400070018, 'DESSART', NULL, 21),
    (400070018022, 400070018, 'MOCKTAIL', NULL, 22);

-- Board <-> category mapping (leaf categories only)
INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (400070018, 400070018001, 400070018001, 1),
    (400070018, 400070018001, 400070018002, 2),
    (400070018, 400070018001, 400070018003, 3),
    (400070018, 400070018001, 400070018004, 4),
    (400070018, 400070018001, 400070018005, 5),
    (400070018, 400070018001, 400070018006, 6),
    (400070018, 400070018001, 400070018007, 7),
    (400070018, 400070018001, 400070018008, 8),
    (400070018, 400070018001, 400070018009, 9),
    (400070018, 400070018001, 400070018010, 10),
    (400070018, 400070018001, 400070018011, 11),
    (400070018, 400070018001, 400070018012, 12),
    (400070018, 400070018001, 400070018013, 13),
    (400070018, 400070018001, 400070018014, 14),
    (400070018, 400070018001, 400070018015, 15),
    (400070018, 400070018001, 400070018016, 16),
    (400070018, 400070018001, 400070018017, 17),
    (400070018, 400070018001, 400070018018, 18),
    (400070018, 400070018001, 400070018019, 19),
    (400070018, 400070018001, 400070018020, 20),
    (400070018, 400070018001, 400070018021, 21),
    (400070018, 400070018001, 400070018022, 22);

-- Canonical dish identify-or-create: no unique constraint on canonical_dish.normalized_name,
-- so NOT EXISTS, not ON CONFLICT. Whether these already exist from an earlier onboarded
-- restaurant is resolved live by this check when the script runs.
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SHORBA-E-ARBIAN (AROMATIC ARABIAN DASTARKHWAN SPECIAL SOUP WITH CHICKEN)', 'shorba-e-arbian (aromatic arabian dastarkhwan special soup with chicken)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'shorba-e-arbian (aromatic arabian dastarkhwan special soup with chicken)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SHORBA-E-ARBIAN (AROMATIC ARABIAN DASTARKHWAN SPECIAL SOUP WITH CHICKEN)', 'shorba-e-arbian (aromatic arabian dastarkhwan special soup with chicken)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SHORBA-E-ARBIAN BA-AL-LAHAM (AROMATIC ARABIAN DASTARKHWAN SPECIAL SOUP WITH MUTTON)', 'shorba-e-arbian ba-al-laham (aromatic arabian dastarkhwan special soup with mutton)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'shorba-e-arbian ba-al-laham (aromatic arabian dastarkhwan special soup with mutton)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SHORBA-E-ARBIAN BA-AL-LAHAM (AROMATIC ARABIAN DASTARKHWAN SPECIAL SOUP WITH MUTTON)', 'shorba-e-arbian ba-al-laham (aromatic arabian dastarkhwan special soup with mutton)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SHORBA-E-AAB BA-AL-LAHAM (A PERSIAN SPECIAL AROMATIC SOUP WITH MUTTON AL-PERSIAN)', 'shorba-e-aab ba-al-laham (a persian special aromatic soup with mutton al-persian)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'shorba-e-aab ba-al-laham (a persian special aromatic soup with mutton al-persian)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SHORBA-E-AAB BA-AL-LAHAM (A PERSIAN SPECIAL AROMATIC SOUP WITH MUTTON AL-PERSIAN)', 'shorba-e-aab ba-al-laham (a persian special aromatic soup with mutton al-persian)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'SHORBA-E-AAB BA-AL-LAHAM (A PERSIAN SPECIAL AROMATIC SOUP WITH CHAAP)', 'shorba-e-aab ba-al-laham (a persian special aromatic soup with chaap)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'shorba-e-aab ba-al-laham (a persian special aromatic soup with chaap)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'SHORBA-E-AAB BA-AL-LAHAM (A PERSIAN SPECIAL AROMATIC SOUP WITH CHAAP)', 'shorba-e-aab ba-al-laham (a persian special aromatic soup with chaap)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'MURG YAKHNI SHORBA', 'murg yakhni shorba'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murg yakhni shorba')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'MURG YAKHNI SHORBA', 'murg yakhni shorba', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'GOSH AAB-E-HAYAT SHORBA', 'gosh aab-e-hayat shorba'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'gosh aab-e-hayat shorba')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'GOSH AAB-E-HAYAT SHORBA', 'gosh aab-e-hayat shorba', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Clears Soup', 'clears soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'clears soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Clears Soup', 'clears soup', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Manchurian Soup', 'manchurian soup'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'manchurian soup')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Manchurian Soup', 'manchurian soup', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Butter Tossed, Lebanese, Lolly Tossed, Mutton Yemeni, Mutton Malai Chaap, 4 Pcs Tandoori Roti.', 'mutton butter tossed, lebanese, lolly tossed, mutton yemeni, mutton malai chaap, 4 pcs tandoori roti.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton butter tossed, lebanese, lolly tossed, mutton yemeni, mutton malai chaap, 4 pcs tandoori roti.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Butter Tossed, Lebanese, Lolly Tossed, Mutton Yemeni, Mutton Malai Chaap, 4 Pcs Tandoori Roti.', 'mutton butter tossed, lebanese, lolly tossed, mutton yemeni, mutton malai chaap, 4 pcs tandoori roti.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Raan Butter Tossed, Mutton Yemeni, Chicken Lebanese, Lolly Tossed, Arabian Tandoori Chicken, 5 Pcs Tandoori Roti.', 'raan butter tossed, mutton yemeni, chicken lebanese, lolly tossed, arabian tandoori chicken, 5 pcs tandoori roti.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'raan butter tossed, mutton yemeni, chicken lebanese, lolly tossed, arabian tandoori chicken, 5 pcs tandoori roti.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Raan Butter Tossed, Mutton Yemeni, Chicken Lebanese, Lolly Tossed, Arabian Tandoori Chicken, 5 Pcs Tandoori Roti.', 'raan butter tossed, mutton yemeni, chicken lebanese, lolly tossed, arabian tandoori chicken, 5 pcs tandoori roti.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Lebanese, Lolly Tossed, ATC Butter Tossed, Chi. Yamani, Mutton Chaap, 4 Pcs Tandoori Roti', 'lebanese, lolly tossed, atc butter tossed, chi. yamani, mutton chaap, 4 pcs tandoori roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lebanese, lolly tossed, atc butter tossed, chi. yamani, mutton chaap, 4 pcs tandoori roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Lebanese, Lolly Tossed, ATC Butter Tossed, Chi. Yamani, Mutton Chaap, 4 Pcs Tandoori Roti', 'lebanese, lolly tossed, atc butter tossed, chi. yamani, mutton chaap, 4 pcs tandoori roti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Yemeni, Lebanese, Mutton Butter Tossed, Mutton Nalli Omani, Mutton Tandoori, Lazeez Caap, 4 Pcs Tandoori Roti', 'mutton yemeni, lebanese, mutton butter tossed, mutton nalli omani, mutton tandoori, lazeez caap, 4 pcs tandoori roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton yemeni, lebanese, mutton butter tossed, mutton nalli omani, mutton tandoori, lazeez caap, 4 pcs tandoori roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Yemeni, Lebanese, Mutton Butter Tossed, Mutton Nalli Omani, Mutton Tandoori, Lazeez Caap, 4 Pcs Tandoori Roti', 'mutton yemeni, lebanese, mutton butter tossed, mutton nalli omani, mutton tandoori, lazeez caap, 4 pcs tandoori roti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Arabian Tandoori Chicken, Dejaj Al-Omani, Lolly Tossed, Chi. Yemani, 4 Pcs Tandoori Roti', 'arabian tandoori chicken, dejaj al-omani, lolly tossed, chi. yemani, 4 pcs tandoori roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'arabian tandoori chicken, dejaj al-omani, lolly tossed, chi. yemani, 4 pcs tandoori roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Arabian Tandoori Chicken, Dejaj Al-Omani, Lolly Tossed, Chi. Yemani, 4 Pcs Tandoori Roti', 'arabian tandoori chicken, dejaj al-omani, lolly tossed, chi. yemani, 4 pcs tandoori roti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dejaj Al-Qamil (Half), Lolly Tossed, ATC Butter Tossed (Half), Crispy, 4 Pcs Tandoori Roti', 'dejaj al-qamil (half), lolly tossed, atc butter tossed (half), crispy, 4 pcs tandoori roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dejaj al-qamil (half), lolly tossed, atc butter tossed (half), crispy, 4 pcs tandoori roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dejaj Al-Qamil (Half), Lolly Tossed, ATC Butter Tossed (Half), Crispy, 4 Pcs Tandoori Roti', 'dejaj al-qamil (half), lolly tossed, atc butter tossed (half), crispy, 4 pcs tandoori roti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Algerian Whole Broasted', 'algerian whole broasted'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'algerian whole broasted')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Algerian Whole Broasted', 'algerian whole broasted', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Lebanese Whole Broasted', 'lebanese whole broasted'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lebanese whole broasted')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Lebanese Whole Broasted', 'lebanese whole broasted', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dejaj Whole Qamil Broasted', 'dejaj whole qamil broasted'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dejaj whole qamil broasted')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dejaj Whole Qamil Broasted', 'dejaj whole qamil broasted', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Moroccan Roasted', 'moroccan roasted'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'moroccan roasted')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Moroccan Roasted', 'moroccan roasted', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'ATC Butter Tossed', 'atc butter tossed'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'atc butter tossed')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'ATC Butter Tossed', 'atc butter tossed', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Turkey Tandoori', 'turkey tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'turkey tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Turkey Tandoori', 'turkey tandoori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Lazeez Tandoori', 'lazeez tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lazeez tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Lazeez Tandoori', 'lazeez tandoori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dejaj Perisan', 'dejaj perisan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dejaj perisan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dejaj Perisan', 'dejaj perisan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Smokey Tandoori', 'smokey tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'smokey tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Smokey Tandoori', 'smokey tandoori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dejaj Al Shahi Cream', 'dejaj al shahi cream'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dejaj al shahi cream')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dejaj Al Shahi Cream', 'dejaj al shahi cream', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Cheese Lapeta', 'chicken cheese lapeta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken cheese lapeta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Cheese Lapeta', 'chicken cheese lapeta', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Omani Chicken AL-Faham', 'omani chicken al-faham'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'omani chicken al-faham')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Omani Chicken AL-Faham', 'omani chicken al-faham', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Arabian Tandoori Chicken', 'arabian tandoori chicken'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'arabian tandoori chicken')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Arabian Tandoori Chicken', 'arabian tandoori chicken', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Yemini Roasted Chicken', 'yemini roasted chicken'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'yemini roasted chicken')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Yemini Roasted Chicken', 'yemini roasted chicken', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dejaj Turkey Al-Faham', 'dejaj turkey al-faham'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dejaj turkey al-faham')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dejaj Turkey Al-Faham', 'dejaj turkey al-faham', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dejaj Al Omani', 'dejaj al omani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dejaj al omani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dejaj Al Omani', 'dejaj al omani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Alishan Tandoori', 'alishan tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'alishan tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Alishan Tandoori', 'alishan tandoori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Zafrani Tandoori', 'zafrani tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'zafrani tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Zafrani Tandoori', 'zafrani tandoori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Kalmi Seekh Kabab', 'chi. kalmi seekh kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. kalmi seekh kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Kalmi Seekh Kabab', 'chi. kalmi seekh kabab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tunesian Kabab (Chi. 6p.)', 'tunesian kabab (chi. 6p.)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tunesian kabab (chi. 6p.)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tunesian Kabab (Chi. 6p.)', 'tunesian kabab (chi. 6p.)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Seek Kabab', 'chicken seek kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken seek kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Seek Kabab', 'chicken seek kabab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Banjara Tikka', 'chicken banjara tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken banjara tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Banjara Tikka', 'chicken banjara tikka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Malai Tikka', 'chicken malai tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken malai tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Malai Tikka', 'chicken malai tikka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Pahadi Tikka', 'chicken pahadi tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pahadi tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Pahadi Tikka', 'chicken pahadi tikka', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Reshmi Tikka', 'chicken reshmi tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken reshmi tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Reshmi Tikka', 'chicken reshmi tikka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Turki Tikka', 'chicken turki tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken turki tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Turki Tikka', 'chicken turki tikka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Alishan Tikka', 'alishan tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'alishan tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Alishan Tikka', 'alishan tikka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sholey Kabab', 'sholey kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sholey kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sholey Kabab', 'sholey kabab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Butter Tossed', 'laham butter tossed'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham butter tossed')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Butter Tossed', 'laham butter tossed', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Turkey Boti', 'laham turkey boti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham turkey boti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Turkey Boti', 'laham turkey boti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Lazeez Boti', 'laham lazeez boti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham lazeez boti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Lazeez Boti', 'laham lazeez boti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Jafrani Boti', 'laham jafrani boti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham jafrani boti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Jafrani Boti', 'laham jafrani boti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Persian', 'laham persian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham persian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Persian', 'laham persian', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Pashtooni Boti', 'laham pashtooni boti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham pashtooni boti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Pashtooni Boti', 'laham pashtooni boti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Turkey', 'laham turkey'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham turkey')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Turkey', 'laham turkey', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Yemeni', 'laham yemeni'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham yemeni')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Yemeni', 'laham yemeni', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Omani', 'laham omani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham omani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Omani', 'laham omani', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Tandoori Al-Faham', 'laham tandoori al-faham'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham tandoori al-faham')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Tandoori Al-Faham', 'laham tandoori al-faham', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Chatpata', 'laham chatpata'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham chatpata')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Chatpata', 'laham chatpata', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Alishan', 'laham alishan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham alishan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Alishan', 'laham alishan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Seekh Kabab', 'laham seekh kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham seekh kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Seekh Kabab', 'laham seekh kabab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Kalmi Seekh Kabab', 'laham kalmi seekh kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham kalmi seekh kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Kalmi Seekh Kabab', 'laham kalmi seekh kabab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Barrah Chaap', 'laham barrah chaap'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham barrah chaap')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Barrah Chaap', 'laham barrah chaap', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Omani Chaap', 'laham omani chaap'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham omani chaap')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Omani Chaap', 'laham omani chaap', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Yemani Chaap', 'laham yemani chaap'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham yemani chaap')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Yemani Chaap', 'laham yemani chaap', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Persian Chaap', 'laham persian chaap'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham persian chaap')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Persian Chaap', 'laham persian chaap', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Lazeez Chaap', 'laham lazeez chaap'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham lazeez chaap')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Lazeez Chaap', 'laham lazeez chaap', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Turkey Chaap', 'laham turkey chaap'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham turkey chaap')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Turkey Chaap', 'laham turkey chaap', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Yemani Raan Al-Faham', 'laham yemani raan al-faham'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham yemani raan al-faham')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Yemani Raan Al-Faham', 'laham yemani raan al-faham', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Raan Butter Tossed', 'laham raan butter tossed'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham raan butter tossed')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Raan Butter Tossed', 'laham raan butter tossed', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Tandoori Raan Al-Faham', 'laham tandoori raan al-faham'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham tandoori raan al-faham')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Tandoori Raan Al-Faham', 'laham tandoori raan al-faham', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Omani Raan', 'laham omani raan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham omani raan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Omani Raan', 'laham omani raan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Persian Raan', 'laham persian raan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham persian raan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Persian Raan', 'laham persian raan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Kalmi Raan', 'laham kalmi raan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham kalmi raan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Kalmi Raan', 'laham kalmi raan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Lazeez Raan', 'lazeez raan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lazeez raan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Lazeez Raan', 'lazeez raan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pashtooni Raan', 'pashtooni raan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pashtooni raan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pashtooni Raan', 'pashtooni raan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Turkey (Nalli Barrah)', 'laham turkey (nalli barrah)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham turkey (nalli barrah)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Turkey (Nalli Barrah)', 'laham turkey (nalli barrah)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Butter Tossed (Nalli Barrah)', 'laham butter tossed (nalli barrah)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham butter tossed (nalli barrah)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Butter Tossed (Nalli Barrah)', 'laham butter tossed (nalli barrah)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Persian (Nalli Barrah)', 'laham persian (nalli barrah)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham persian (nalli barrah)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Persian (Nalli Barrah)', 'laham persian (nalli barrah)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Omani (Nalli Barrah)', 'laham omani (nalli barrah)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham omani (nalli barrah)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Omani (Nalli Barrah)', 'laham omani (nalli barrah)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Yemani (Nalli Barrah)', 'laham yemani (nalli barrah)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham yemani (nalli barrah)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Yemani (Nalli Barrah)', 'laham yemani (nalli barrah)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Saudi Arabian Mandi', 'laham saudi arabian mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham saudi arabian mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Saudi Arabian Mandi', 'laham saudi arabian mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Turkish Mandi', 'laham turkish mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham turkish mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Turkish Mandi', 'laham turkish mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Omani Mandi', 'laham omani mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham omani mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Omani Mandi', 'laham omani mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Yemani Mandi', 'laham yemani mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham yemani mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Yemani Mandi', 'laham yemani mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Yemani Nalli Mandi', 'laham yemani nalli mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham yemani nalli mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Yemani Nalli Mandi', 'laham yemani nalli mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Tandoori Mandi', 'laham tandoori mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham tandoori mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Tandoori Mandi', 'laham tandoori mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Kalmi Saudi Arabian Mandi', 'laham kalmi saudi arabian mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham kalmi saudi arabian mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Kalmi Saudi Arabian Mandi', 'laham kalmi saudi arabian mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Kalmi Turkish Mandi', 'laham kalmi turkish mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham kalmi turkish mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Kalmi Turkish Mandi', 'laham kalmi turkish mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Lazeez Saudi Arabian Mandi', 'laham lazeez saudi arabian mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham lazeez saudi arabian mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Lazeez Saudi Arabian Mandi', 'laham lazeez saudi arabian mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Lazeez Turkish Mandi', 'laham lazeez turkish mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham lazeez turkish mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Lazeez Turkish Mandi', 'laham lazeez turkish mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Turkey Raan Mandi', 'laham turkey raan mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham turkey raan mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Turkey Raan Mandi', 'laham turkey raan mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Omani Raan Mandi', 'laham omani raan mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham omani raan mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Omani Raan Mandi', 'laham omani raan mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Raan Butter Tossed Mandi', 'laham raan butter tossed mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham raan butter tossed mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Raan Butter Tossed Mandi', 'laham raan butter tossed mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Yemani Raan Mandi', 'laham yemani raan mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham yemani raan mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Yemani Raan Mandi', 'laham yemani raan mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pashtooni Tandoori Raan Saudi Mandi', 'pashtooni tandoori raan saudi mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pashtooni tandoori raan saudi mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pashtooni Tandoori Raan Saudi Mandi', 'pashtooni tandoori raan saudi mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pashtooni Tandoori Raan Turkish Mandi', 'pashtooni tandoori raan turkish mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pashtooni tandoori raan turkish mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pashtooni Tandoori Raan Turkish Mandi', 'pashtooni tandoori raan turkish mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Tandoori Raan Mandi', 'laham tandoori raan mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham tandoori raan mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Tandoori Raan Mandi', 'laham tandoori raan mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Laham Saudi Raan Mandi', 'laham saudi raan mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'laham saudi raan mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Laham Saudi Raan Mandi', 'laham saudi raan mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Raan Kalmi Saudi Arabian Mandi', 'raan kalmi saudi arabian mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'raan kalmi saudi arabian mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Raan Kalmi Saudi Arabian Mandi', 'raan kalmi saudi arabian mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Raan Kalmi Turkish Mandi', 'raan kalmi turkish mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'raan kalmi turkish mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Raan Kalmi Turkish Mandi', 'raan kalmi turkish mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Raan Lazeez Saudi Arabian Mandi', 'raan lazeez saudi arabian mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'raan lazeez saudi arabian mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Raan Lazeez Saudi Arabian Mandi', 'raan lazeez saudi arabian mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Raan Lazeez Turkish Mandi', 'raan lazeez turkish mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'raan lazeez turkish mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Raan Lazeez Turkish Mandi', 'raan lazeez turkish mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Arabian Tandoori Chi. Saudi Mandi', 'arabian tandoori chi. saudi mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'arabian tandoori chi. saudi mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Arabian Tandoori Chi. Saudi Mandi', 'arabian tandoori chi. saudi mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Arabian Tandoori Chi. Turkey Mandi', 'arabian tandoori chi. turkey mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'arabian tandoori chi. turkey mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Arabian Tandoori Chi. Turkey Mandi', 'arabian tandoori chi. turkey mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Arabian Tandoori Chi. Omani Mandi', 'arabian tandoori chi. omani mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'arabian tandoori chi. omani mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Arabian Tandoori Chi. Omani Mandi', 'arabian tandoori chi. omani mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Lebanese Roasted Chi. Saudi Mandi', 'lebanese roasted chi. saudi mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lebanese roasted chi. saudi mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Lebanese Roasted Chi. Saudi Mandi', 'lebanese roasted chi. saudi mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Lebanese Roasted Chi. Turkey Mandi', 'lebanese roasted chi. turkey mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lebanese roasted chi. turkey mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Lebanese Roasted Chi. Turkey Mandi', 'lebanese roasted chi. turkey mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Yemeni Chi. Turkey Mandi', 'yemeni chi. turkey mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'yemeni chi. turkey mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Yemeni Chi. Turkey Mandi', 'yemeni chi. turkey mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Omani Chi. Faham Turkey Mandi', 'omani chi. faham turkey mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'omani chi. faham turkey mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Omani Chi. Faham Turkey Mandi', 'omani chi. faham turkey mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Omani Chi. Al Faham Saudi Mandi', 'omani chi. al faham saudi mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'omani chi. al faham saudi mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Omani Chi. Al Faham Saudi Mandi', 'omani chi. al faham saudi mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Turkey Chi. Al Faham Mandi', 'turkey chi. al faham mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'turkey chi. al faham mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Turkey Chi. Al Faham Mandi', 'turkey chi. al faham mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dajaj Persian Turkey Mandi', 'dajaj persian turkey mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dajaj persian turkey mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dajaj Persian Turkey Mandi', 'dajaj persian turkey mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dajaj Persian Saudi Mandi', 'dajaj persian saudi mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dajaj persian saudi mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dajaj Persian Saudi Mandi', 'dajaj persian saudi mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dajaj Kalmi Saudi Arabian Mandi', 'dajaj kalmi saudi arabian mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dajaj kalmi saudi arabian mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dajaj Kalmi Saudi Arabian Mandi', 'dajaj kalmi saudi arabian mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dajaj Kalmi Turkish Mandi', 'dajaj kalmi turkish mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dajaj kalmi turkish mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dajaj Kalmi Turkish Mandi', 'dajaj kalmi turkish mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dajaj Lazeez Saudi Arabian Mandi', 'dajaj lazeez saudi arabian mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dajaj lazeez saudi arabian mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dajaj Lazeez Saudi Arabian Mandi', 'dajaj lazeez saudi arabian mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Dajaj Lazeez Turkish Mandi', 'dajaj lazeez turkish mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dajaj lazeez turkish mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dajaj Lazeez Turkish Mandi', 'dajaj lazeez turkish mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Steamed Rice', 'steamed rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'steamed rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Steamed Rice', 'steamed rice', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Saudi Rice', 'saudi rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'saudi rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Saudi Rice', 'saudi rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Turkish Rice', 'turkish rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'turkish rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Turkish Rice', 'turkish rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Any Dajaj Pcs.', 'any dajaj pcs.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'any dajaj pcs.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Any Dajaj Pcs.', 'any dajaj pcs.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Any Laham Pcs.', 'any laham pcs.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'any laham pcs.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Any Laham Pcs.', 'any laham pcs.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton :- Mutton Turky Mandi, Arabian Tandoori, Chicken Lolly Tossed, Lebanese Chicken Rara, 5 Butter Roti, Omali 2 Pcs', 'mutton :- mutton turky mandi, arabian tandoori, chicken lolly tossed, lebanese chicken rara, 5 butter roti, omali 2 pcs'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton :- mutton turky mandi, arabian tandoori, chicken lolly tossed, lebanese chicken rara, 5 butter roti, omali 2 pcs')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton :- Mutton Turky Mandi, Arabian Tandoori, Chicken Lolly Tossed, Lebanese Chicken Rara, 5 Butter Roti, Omali 2 Pcs', 'mutton :- mutton turky mandi, arabian tandoori, chicken lolly tossed, lebanese chicken rara, 5 butter roti, omali 2 pcs', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken:- Chicken Mandi, Lebanese Chicken, Mutton Choup Crispy, Omali, Chicken Rara, 5 Tandoori Roti', 'chicken:- chicken mandi, lebanese chicken, mutton choup crispy, omali, chicken rara, 5 tandoori roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken:- chicken mandi, lebanese chicken, mutton choup crispy, omali, chicken rara, 5 tandoori roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken:- Chicken Mandi, Lebanese Chicken, Mutton Choup Crispy, Omali, Chicken Rara, 5 Tandoori Roti', 'chicken:- chicken mandi, lebanese chicken, mutton choup crispy, omali, chicken rara, 5 tandoori roti', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Chicken', 'butter chicken'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter chicken')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Chicken', 'butter chicken', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Afgani', 'chicken afgani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken afgani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Afgani', 'chicken afgani', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Korma', 'chicken korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Korma', 'chicken korma', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Patiyala', 'chicken patiyala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken patiyala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Patiyala', 'chicken patiyala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Rara', 'chicken rara'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken rara')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Rara', 'chicken rara', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Tikka Masala', 'chicken tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Tikka Masala', 'chicken tikka masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Kadai Peshawar', 'chicken kadai peshawar'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kadai peshawar')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Kadai Peshawar', 'chicken kadai peshawar', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Nargish Kofta', 'chicken nargish kofta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken nargish kofta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Nargish Kofta', 'chicken nargish kofta', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Murg Musallam H/F', 'murg musallam h/f'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murg musallam h/f')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Murg Musallam H/F', 'murg musallam h/f', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mugh Bhuna (MSL)', 'mugh bhuna (msl)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mugh bhuna (msl)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mugh Bhuna (MSL)', 'mugh bhuna (msl)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Murg Pasanda', 'murg pasanda'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murg pasanda')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Murg Pasanda', 'murg pasanda', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Murg Angara (MSL)', 'murg angara (msl)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murg angara (msl)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Murg Angara (MSL)', 'murg angara (msl)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Murg Matka Masala', 'murg matka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murg matka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Murg Matka Masala', 'murg matka masala', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Masala', 'mutton masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Masala', 'mutton masala', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Patiyala', 'mutton patiyala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton patiyala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Patiyala', 'mutton patiyala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Rara', 'mutton rara'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton rara')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Rara', 'mutton rara', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Kolhapuri', 'mutton kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Kolhapuri', 'mutton kolhapuri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Nalli Nihari', 'mutton nalli nihari'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton nalli nihari')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Nalli Nihari', 'mutton nalli nihari', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Chaap Masala', 'mutton chaap masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton chaap masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Chaap Masala', 'mutton chaap masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Seekh Kabab Masala', 'mutton seekh kabab masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton seekh kabab masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Seekh Kabab Masala', 'mutton seekh kabab masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Shikari', 'mutton shikari'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton shikari')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Shikari', 'mutton shikari', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Peshawari (MSL) Spicy', 'mutton peshawari (msl) spicy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton peshawari (msl) spicy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Peshawari (MSL) Spicy', 'mutton peshawari (msl) spicy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Badami Korma', 'mutton badami korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton badami korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Badami Korma', 'mutton badami korma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton lahori', 'mutton lahori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton lahori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton lahori', 'mutton lahori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mutton Angara(MSL)', 'mutton angara(msl)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton angara(msl)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mutton Angara(MSL)', 'mutton angara(msl)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Raan Tandoori Butter Masala Spl.', 'raan tandoori butter masala spl.'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'raan tandoori butter masala spl.')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Raan Tandoori Butter Masala Spl.', 'raan tandoori butter masala spl.', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Raan Rara Masala', 'raan rara masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'raan rara masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Raan Rara Masala', 'raan rara masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Raan Korma', 'raan korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'raan korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Raan Korma', 'raan korma', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Fish Mandi', 'fish mandi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish mandi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Fish Mandi', 'fish mandi', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pomfret Tawa Fry - 1 Pcs', 'pomfret tawa fry - 1 pcs'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pomfret tawa fry - 1 pcs')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pomfret Tawa Fry - 1 Pcs', 'pomfret tawa fry - 1 pcs', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pomfret Deep Fry - 1 Pcs', 'pomfret deep fry - 1 pcs'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pomfret deep fry - 1 pcs')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pomfret Deep Fry - 1 Pcs', 'pomfret deep fry - 1 pcs', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Surmai Tawa Fry - 1 Pcs', 'surmai tawa fry - 1 pcs'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'surmai tawa fry - 1 pcs')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Surmai Tawa Fry - 1 Pcs', 'surmai tawa fry - 1 pcs', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Surmai Deep Fry 1 Pcs', 'surmai deep fry 1 pcs'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'surmai deep fry 1 pcs')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Surmai Deep Fry 1 Pcs', 'surmai deep fry 1 pcs', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Prawns Chilli', 'prawns chilli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns chilli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Prawns Chilli', 'prawns chilli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Prawns Crispy', 'prawns crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Prawns Crispy', 'prawns crispy', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Fish Fried Rice', 'fish fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Fish Fried Rice', 'fish fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Fish Tikka', 'fish tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Fish Tikka', 'fish tikka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Prawns Tikka', 'prawns tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Prawns Tikka', 'prawns tikka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Pomfret Tandoori', 'pomfret tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pomfret tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Pomfret Tandoori', 'pomfret tandoori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Prawns Platter (2 Person)', 'prawns platter (2 person)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns platter (2 person)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Prawns Platter (2 Person)', 'prawns platter (2 person)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Prawns Platter (3 Person)', 'prawns platter (3 person)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns platter (3 person)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Prawns Platter (3 Person)', 'prawns platter (3 person)', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Malai Tikka', 'paneer malai tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer malai tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Malai Tikka', 'paneer malai tikka', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Pahadi Kabab', 'paneer pahadi kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pahadi kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Pahadi Kabab', 'paneer pahadi kabab', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Sahi Paneer', 'sahi paneer'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'sahi paneer')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Sahi Paneer', 'sahi paneer', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Malai Chilli', 'paneer malai chilli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer malai chilli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Malai Chilli', 'paneer malai chilli', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Mushroom Tandoori', 'mushroom tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mushroom Tandoori', 'mushroom tandoori', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Mushroom Chilli', 'mushroom chilli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom chilli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Mushroom Chilli', 'mushroom chilli', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Chilli Dry', 'paneer chilli dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chilli dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Chilli Dry', 'paneer chilli dry', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer 65', 'paneer 65'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer 65')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer 65', 'paneer 65', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Kadai', 'paneer kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Kadai', 'paneer kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Masala', 'paneer masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Masala', 'paneer masala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Kolhapuri', 'paneer kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Kolhapuri', 'paneer kolhapuri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Shahi Paneer', 'shahi paneer'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'shahi paneer')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Shahi Paneer', 'shahi paneer', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Paneer Makkhanwala', 'paneer makkhanwala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer makkhanwala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Paneer Makkhanwala', 'paneer makkhanwala', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg Kadai', 'veg kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg Kadai', 'veg kadai', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg Kolhapuri', 'veg kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg Kolhapuri', 'veg kolhapuri', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Veg Handi', 'veg handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Veg Handi', 'veg handi', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Dal Makhani', 'dal makhani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal makhani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Dal Makhani', 'dal makhani', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Naan', 'butter naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Naan', 'butter naan', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Plan Naan', 'plan naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'plan naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Plan Naan', 'plan naan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Garlic Naan Butter', 'garlic naan butter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic naan butter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Garlic Naan Butter', 'garlic naan butter', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Tabi Naan Butter', 'tabi naan butter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tabi naan butter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Tabi Naan Butter', 'tabi naan butter', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Cheese Naan', 'cheese naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Cheese Naan', 'cheese naan', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Butter Cheese Naan', 'butter cheese naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter cheese naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Butter Cheese Naan', 'butter cheese naan', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Lachcha Paratha', 'lachcha paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lachcha paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Lachcha Paratha', 'lachcha paratha', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Arabian Spl. Chilly Dry', 'arabian spl. chilly dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'arabian spl. chilly dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Arabian Spl. Chilly Dry', 'arabian spl. chilly dry', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Chilly Dry', 'chicken chilly dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Chilly Dry', 'chicken chilly dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Hot Garlic Dry', 'chicken hot garlic dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hot garlic dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Hot Garlic Dry', 'chicken hot garlic dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Dargan Dry', 'chicken dargan dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken dargan dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Dargan Dry', 'chicken dargan dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Hong Kong Dry', 'chicken hong kong dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hong kong dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Hong Kong Dry', 'chicken hong kong dry', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Apply Dry', 'chicken apply dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken apply dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Apply Dry', 'chicken apply dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Lolly Pop', 'chicken lolly pop'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lolly pop')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Lolly Pop', 'chicken lolly pop', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Oyster Dry', 'chicken oyster dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken oyster dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Oyster Dry', 'chicken oyster dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken 65 Dry', 'chicken 65 dry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken 65 dry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken 65 Dry', 'chicken 65 dry', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Malai Crispy', 'chicken malai crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken malai crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Malai Crispy', 'chicken malai crispy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Cheese Crispy', 'chicken cheese crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken cheese crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Cheese Crispy', 'chicken cheese crispy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Zafrani Crispy', 'chicken zafrani crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken zafrani crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Zafrani Crispy', 'chicken zafrani crispy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Lolly Tossed', 'lolly tossed'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lolly tossed')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Lolly Tossed', 'lolly tossed', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Burnt Garlic Fried Rice', 'chi. burnt garlic fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. burnt garlic fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Burnt Garlic Fried Rice', 'chi. burnt garlic fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Singapore Rice', 'chi. singapore rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. singapore rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Singapore Rice', 'chi. singapore rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Malaysian Rice', 'chi. malaysian rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. malaysian rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Malaysian Rice', 'chi. malaysian rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Hong Kong Rice', 'chi. hong kong rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. hong kong rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Hong Kong Rice', 'chi. hong kong rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Chilly Garlic Rice + Gravy', 'chi. chilly garlic rice + gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. chilly garlic rice + gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Chilly Garlic Rice + Gravy', 'chi. chilly garlic rice + gravy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Tripple Fried Rice + Gravy', 'chi. tripple fried rice + gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. tripple fried rice + gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Tripple Fried Rice + Gravy', 'chi. tripple fried rice + gravy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Manchurian Fried Rice+ Gravy', 'chi. manchurian fried rice+ gravy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. manchurian fried rice+ gravy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Manchurian Fried Rice+ Gravy', 'chi. manchurian fried rice+ gravy', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Burnt Chilly Pot Rice', 'chi. burnt chilly pot rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. burnt chilly pot rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Burnt Chilly Pot Rice', 'chi. burnt chilly pot rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chicken Dragon Pot Rice', 'chicken dragon pot rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken dragon pot rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chicken Dragon Pot Rice', 'chicken dragon pot rice', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Afghani Egg Fried Rice', 'afghani egg fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'afghani egg fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Afghani Egg Fried Rice', 'afghani egg fried rice', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Afghani Chicken Fried Rice', 'afghani chicken fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'afghani chicken fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Afghani Chicken Fried Rice', 'afghani chicken fried rice', 'primary'
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
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Schezwan Hakka Noodles', 'chi. schezwan hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. schezwan hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Schezwan Hakka Noodles', 'chi. schezwan hakka noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Burnt Garlic Noodles', 'chi. burnt garlic noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. burnt garlic noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Burnt Garlic Noodles', 'chi. burnt garlic noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Singapore Noodles', 'chi. singapore noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. singapore noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Singapore Noodles', 'chi. singapore noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi. Malaysian Noodles', 'chi. malaysian noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi. malaysian noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi. Malaysian Noodles', 'chi. malaysian noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Chi Hong Kong Noodles', 'chi hong kong noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi hong kong noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Chi Hong Kong Noodles', 'chi hong kong noodles', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'CHEESE KUNAFEH', 'cheese kunafeh'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese kunafeh')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'CHEESE KUNAFEH', 'cheese kunafeh', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'KUNAFEH', 'kunafeh'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kunafeh')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'KUNAFEH', 'kunafeh', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'OMALI', 'omali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'omali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'OMALI', 'omali', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'LEBANESE PUDDING', 'lebanese pudding'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lebanese pudding')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'LEBANESE PUDDING', 'lebanese pudding', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Lime Mojito', 'lime mojito'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lime mojito')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Lime Mojito', 'lime mojito', 'primary'
FROM new_dish;
WITH new_dish AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('khaustan_standalone_id_seq'), 'Fruit Champagne', 'fruit champagne'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fruit champagne')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('khaustan_standalone_id_seq'), canonical_dish_id, 'en', 'Fruit Champagne', 'fruit champagne', 'primary'
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
    (400070018001, 400070018, 'SHORBA-E-ARBIAN (AROMATIC ARABIAN DASTARKHWAN SPECIAL SOUP WITH CHICKEN)', 'shorba-e-arbian (aromatic arabian dastarkhwan special soup with chicken)', 'SHORBA-AAT (SOUPS)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018002, 400070018, 'SHORBA-E-ARBIAN BA-AL-LAHAM (AROMATIC ARABIAN DASTARKHWAN SPECIAL SOUP WITH MUTTON)', 'shorba-e-arbian ba-al-laham (aromatic arabian dastarkhwan special soup with mutton)', 'SHORBA-AAT (SOUPS)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018003, 400070018, 'SHORBA-E-AAB BA-AL-LAHAM (A PERSIAN SPECIAL AROMATIC SOUP WITH MUTTON AL-PERSIAN)', 'shorba-e-aab ba-al-laham (a persian special aromatic soup with mutton al-persian)', 'SHORBA-AAT (SOUPS)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018004, 400070018, 'SHORBA-E-AAB BA-AL-LAHAM (A PERSIAN SPECIAL AROMATIC SOUP WITH CHAAP)', 'shorba-e-aab ba-al-laham (a persian special aromatic soup with chaap)', 'SHORBA-AAT (SOUPS)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018005, 400070018, 'MURG YAKHNI SHORBA', 'murg yakhni shorba', 'SHORBA-AAT (SOUPS)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018006, 400070018, 'GOSH AAB-E-HAYAT SHORBA', 'gosh aab-e-hayat shorba', 'SHORBA-AAT (SOUPS)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018007, 400070018, 'Hot & Sour Soup', 'hot & sour soup', 'CHINESE SOUP', 'veg'::text, NULL::text, 'sp:hot & sour soup|(0, 1)'::text, 'needs_review'),
    (400070018008, 400070018, 'Hot & Sour Soup', 'hot & sour soup', 'CHINESE SOUP', 'non_veg'::text, NULL::text, 'sp:hot & sour soup|(0, 1)'::text, 'needs_review'),
    (400070018009, 400070018, 'Clears Soup', 'clears soup', 'CHINESE SOUP', 'veg'::text, NULL::text, 'sp:clears soup|(0, 1)'::text, 'needs_review'),
    (400070018010, 400070018, 'Clears Soup', 'clears soup', 'CHINESE SOUP', 'non_veg'::text, NULL::text, 'sp:clears soup|(0, 1)'::text, 'needs_review'),
    (400070018011, 400070018, 'Manchurian Soup', 'manchurian soup', 'CHINESE SOUP', 'veg'::text, NULL::text, 'sp:manchurian soup|(0, 1)'::text, 'needs_review'),
    (400070018012, 400070018, 'Manchurian Soup', 'manchurian soup', 'CHINESE SOUP', 'non_veg'::text, NULL::text, 'sp:manchurian soup|(0, 1)'::text, 'needs_review'),
    (400070018013, 400070018, 'GREEN SALAD', 'green salad', 'SALAD', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018014, 400070018, 'Mutton Butter Tossed, Lebanese, Lolly Tossed, Mutton Yemeni, Mutton Malai Chaap, 4 Pcs Tandoori Roti.', 'mutton butter tossed, lebanese, lolly tossed, mutton yemeni, mutton malai chaap, 4 pcs tandoori roti.', 'MIX PLATERS', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018015, 400070018, 'Raan Butter Tossed, Mutton Yemeni, Chicken Lebanese, Lolly Tossed, Arabian Tandoori Chicken, 5 Pcs Tandoori Roti.', 'raan butter tossed, mutton yemeni, chicken lebanese, lolly tossed, arabian tandoori chicken, 5 pcs tandoori roti.', 'MIX PLATERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018016, 400070018, 'Lebanese, Lolly Tossed, ATC Butter Tossed, Chi. Yamani, Mutton Chaap, 4 Pcs Tandoori Roti', 'lebanese, lolly tossed, atc butter tossed, chi. yamani, mutton chaap, 4 pcs tandoori roti', 'MIX PLATERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018017, 400070018, 'Mutton Yemeni, Lebanese, Mutton Butter Tossed, Mutton Nalli Omani, Mutton Tandoori, Lazeez Caap, 4 Pcs Tandoori Roti', 'mutton yemeni, lebanese, mutton butter tossed, mutton nalli omani, mutton tandoori, lazeez caap, 4 pcs tandoori roti', 'MIX PLATERS', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018018, 400070018, 'Arabian Tandoori Chicken, Dejaj Al-Omani, Lolly Tossed, Chi. Yemani, 4 Pcs Tandoori Roti', 'arabian tandoori chicken, dejaj al-omani, lolly tossed, chi. yemani, 4 pcs tandoori roti', 'MIX PLATERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018019, 400070018, 'Dejaj Al-Qamil (Half), Lolly Tossed, ATC Butter Tossed (Half), Crispy, 4 Pcs Tandoori Roti', 'dejaj al-qamil (half), lolly tossed, atc butter tossed (half), crispy, 4 pcs tandoori roti', 'MIX PLATERS', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070018020, 400070018, 'Algerian Whole Broasted', 'algerian whole broasted', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018021, 400070018, 'Lebanese Whole Broasted', 'lebanese whole broasted', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018022, 400070018, 'Dejaj Whole Qamil Broasted', 'dejaj whole qamil broasted', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018023, 400070018, 'Moroccan Roasted', 'moroccan roasted', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018024, 400070018, 'ATC Butter Tossed', 'atc butter tossed', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018025, 400070018, 'Turkey Tandoori', 'turkey tandoori', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018026, 400070018, 'Lazeez Tandoori', 'lazeez tandoori', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018027, 400070018, 'Dejaj Perisan', 'dejaj perisan', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018028, 400070018, 'Smokey Tandoori', 'smokey tandoori', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018029, 400070018, 'Dejaj Al Shahi Cream', 'dejaj al shahi cream', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018030, 400070018, 'Chicken Cheese Lapeta', 'chicken cheese lapeta', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018031, 400070018, 'Omani Chicken AL-Faham', 'omani chicken al-faham', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018032, 400070018, 'Arabian Tandoori Chicken', 'arabian tandoori chicken', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018033, 400070018, 'Yemini Roasted Chicken', 'yemini roasted chicken', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018034, 400070018, 'Dejaj Turkey Al-Faham', 'dejaj turkey al-faham', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018035, 400070018, 'Dejaj Al Omani', 'dejaj al omani', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018036, 400070018, 'Alishan Tandoori', 'alishan tandoori', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018037, 400070018, 'Zafrani Tandoori', 'zafrani tandoori', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018038, 400070018, 'Chi. Kalmi Seekh Kabab', 'chi. kalmi seekh kabab', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018039, 400070018, 'Tunesian Kabab (Chi. 6p.)', 'tunesian kabab (chi. 6p.)', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018040, 400070018, 'Chicken Seek Kabab', 'chicken seek kabab', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018041, 400070018, 'Chicken Banjara Tikka', 'chicken banjara tikka', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018042, 400070018, 'Chicken Malai Tikka', 'chicken malai tikka', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018043, 400070018, 'Chicken Pahadi Tikka', 'chicken pahadi tikka', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018044, 400070018, 'Chicken Tikka', 'chicken tikka', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018045, 400070018, 'Chicken Reshmi Tikka', 'chicken reshmi tikka', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018046, 400070018, 'Chicken Turki Tikka', 'chicken turki tikka', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018047, 400070018, 'Alishan Tikka', 'alishan tikka', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018048, 400070018, 'Sholey Kabab', 'sholey kabab', 'MUQABBAL-AAT CHICKEN (STARTER)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018049, 400070018, 'Laham Butter Tossed', 'laham butter tossed', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018050, 400070018, 'Laham Turkey Boti', 'laham turkey boti', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018051, 400070018, 'Laham Lazeez Boti', 'laham lazeez boti', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018052, 400070018, 'Laham Jafrani Boti', 'laham jafrani boti', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018053, 400070018, 'Laham Persian', 'laham persian', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018054, 400070018, 'Laham Pashtooni Boti', 'laham pashtooni boti', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018055, 400070018, 'Laham Turkey', 'laham turkey', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018056, 400070018, 'Laham Yemeni', 'laham yemeni', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018057, 400070018, 'Laham Omani', 'laham omani', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018058, 400070018, 'Laham Tandoori Al-Faham', 'laham tandoori al-faham', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018059, 400070018, 'Laham Chatpata', 'laham chatpata', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018060, 400070018, 'Laham Alishan', 'laham alishan', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018061, 400070018, 'Laham Alishan', 'laham alishan', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018062, 400070018, 'Laham Seekh Kabab', 'laham seekh kabab', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018063, 400070018, 'Laham Kalmi Seekh Kabab', 'laham kalmi seekh kabab', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018064, 400070018, 'Laham Barrah Chaap', 'laham barrah chaap', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018065, 400070018, 'Laham Omani Chaap', 'laham omani chaap', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018066, 400070018, 'Laham Yemani Chaap', 'laham yemani chaap', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018067, 400070018, 'Laham Persian Chaap', 'laham persian chaap', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018068, 400070018, 'Laham Lazeez Chaap', 'laham lazeez chaap', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018069, 400070018, 'Laham Turkey Chaap', 'laham turkey chaap', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018070, 400070018, 'Laham Yemani Raan Al-Faham', 'laham yemani raan al-faham', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018071, 400070018, 'Laham Raan Butter Tossed', 'laham raan butter tossed', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018072, 400070018, 'Laham Tandoori Raan Al-Faham', 'laham tandoori raan al-faham', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018073, 400070018, 'Laham Omani Raan', 'laham omani raan', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018074, 400070018, 'Laham Persian Raan', 'laham persian raan', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018075, 400070018, 'Laham Kalmi Raan', 'laham kalmi raan', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018076, 400070018, 'Lazeez Raan', 'lazeez raan', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018077, 400070018, 'Pashtooni Raan', 'pashtooni raan', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018078, 400070018, 'Laham Turkey (Nalli Barrah)', 'laham turkey (nalli barrah)', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018079, 400070018, 'Laham Butter Tossed (Nalli Barrah)', 'laham butter tossed (nalli barrah)', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018080, 400070018, 'Laham Persian (Nalli Barrah)', 'laham persian (nalli barrah)', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018081, 400070018, 'Laham Omani (Nalli Barrah)', 'laham omani (nalli barrah)', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018082, 400070018, 'Laham Yemani (Nalli Barrah)', 'laham yemani (nalli barrah)', 'MUQABBAL-AAT MUTTON (STARTER)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018083, 400070018, 'Laham Saudi Arabian Mandi', 'laham saudi arabian mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018084, 400070018, 'Laham Turkish Mandi', 'laham turkish mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018085, 400070018, 'Laham Omani Mandi', 'laham omani mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018086, 400070018, 'Laham Yemani Mandi', 'laham yemani mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018087, 400070018, 'Laham Yemani Nalli Mandi', 'laham yemani nalli mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018088, 400070018, 'Laham Tandoori Mandi', 'laham tandoori mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018089, 400070018, 'Laham Kalmi Saudi Arabian Mandi', 'laham kalmi saudi arabian mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018090, 400070018, 'Laham Kalmi Turkish Mandi', 'laham kalmi turkish mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018091, 400070018, 'Laham Lazeez Saudi Arabian Mandi', 'laham lazeez saudi arabian mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018092, 400070018, 'Laham Lazeez Turkish Mandi', 'laham lazeez turkish mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018093, 400070018, 'Laham Turkey Raan Mandi', 'laham turkey raan mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018094, 400070018, 'Laham Omani Raan Mandi', 'laham omani raan mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018095, 400070018, 'Laham Raan Butter Tossed Mandi', 'laham raan butter tossed mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018096, 400070018, 'Laham Yemani Raan Mandi', 'laham yemani raan mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018097, 400070018, 'Pashtooni Tandoori Raan Saudi Mandi', 'pashtooni tandoori raan saudi mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018098, 400070018, 'Pashtooni Tandoori Raan Turkish Mandi', 'pashtooni tandoori raan turkish mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018099, 400070018, 'Laham Tandoori Raan Mandi', 'laham tandoori raan mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018100, 400070018, 'Laham Saudi Raan Mandi', 'laham saudi raan mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018101, 400070018, 'Raan Kalmi Saudi Arabian Mandi', 'raan kalmi saudi arabian mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018102, 400070018, 'Raan Kalmi Turkish Mandi', 'raan kalmi turkish mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018103, 400070018, 'Raan Lazeez Saudi Arabian Mandi', 'raan lazeez saudi arabian mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018104, 400070018, 'Raan Lazeez Turkish Mandi', 'raan lazeez turkish mandi', 'AISH RICE (MUTTON MANDI)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018105, 400070018, 'Arabian Tandoori Chi. Saudi Mandi', 'arabian tandoori chi. saudi mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018106, 400070018, 'Arabian Tandoori Chi. Turkey Mandi', 'arabian tandoori chi. turkey mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018107, 400070018, 'Arabian Tandoori Chi. Omani Mandi', 'arabian tandoori chi. omani mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018108, 400070018, 'Lebanese Roasted Chi. Saudi Mandi', 'lebanese roasted chi. saudi mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018109, 400070018, 'Lebanese Roasted Chi. Turkey Mandi', 'lebanese roasted chi. turkey mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018110, 400070018, 'Yemeni Chi. Turkey Mandi', 'yemeni chi. turkey mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018111, 400070018, 'Omani Chi. Faham Turkey Mandi', 'omani chi. faham turkey mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018112, 400070018, 'Omani Chi. Al Faham Saudi Mandi', 'omani chi. al faham saudi mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018113, 400070018, 'Turkey Chi. Al Faham Mandi', 'turkey chi. al faham mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018114, 400070018, 'Dajaj Persian Turkey Mandi', 'dajaj persian turkey mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018115, 400070018, 'Dajaj Persian Saudi Mandi', 'dajaj persian saudi mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018116, 400070018, 'Dajaj Kalmi Saudi Arabian Mandi', 'dajaj kalmi saudi arabian mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018117, 400070018, 'Dajaj Kalmi Turkish Mandi', 'dajaj kalmi turkish mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018118, 400070018, 'Dajaj Lazeez Saudi Arabian Mandi', 'dajaj lazeez saudi arabian mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018119, 400070018, 'Dajaj Lazeez Turkish Mandi', 'dajaj lazeez turkish mandi', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018120, 400070018, 'Steamed Rice', 'steamed rice', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018121, 400070018, 'Jeera Rice', 'jeera rice', 'AISH RICE (CHICKEN MANDI)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018122, 400070018, 'Saudi Rice', 'saudi rice', 'EXTRA RICE (EXTRA PCS.)', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070018123, 400070018, 'Turkish Rice', 'turkish rice', 'EXTRA RICE (EXTRA PCS.)', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070018124, 400070018, 'Any Dajaj Pcs.', 'any dajaj pcs.', 'EXTRA RICE (EXTRA PCS.)', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018125, 400070018, 'Any Laham Pcs.', 'any laham pcs.', 'EXTRA RICE (EXTRA PCS.)', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018126, 400070018, 'Mutton :- Mutton Turky Mandi, Arabian Tandoori, Chicken Lolly Tossed, Lebanese Chicken Rara, 5 Butter Roti, Omali 2 Pcs', 'mutton :- mutton turky mandi, arabian tandoori, chicken lolly tossed, lebanese chicken rara, 5 butter roti, omali 2 pcs', 'ARABIAN DASTARKHWAN SPECIAL THAL', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018127, 400070018, 'Chicken:- Chicken Mandi, Lebanese Chicken, Mutton Choup Crispy, Omali, Chicken Rara, 5 Tandoori Roti', 'chicken:- chicken mandi, lebanese chicken, mutton choup crispy, omali, chicken rara, 5 tandoori roti', 'ARABIAN DASTARKHWAN SPECIAL THAL', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018128, 400070018, 'Butter Chicken', 'butter chicken', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018129, 400070018, 'Chicken Afgani', 'chicken afgani', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018130, 400070018, 'Chicken Handi', 'chicken handi', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018131, 400070018, 'Chicken Kadai', 'chicken kadai', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018132, 400070018, 'Chicken Kolhapuri', 'chicken kolhapuri', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018133, 400070018, 'Chicken Korma', 'chicken korma', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018134, 400070018, 'Chicken Masala', 'chicken masala', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018135, 400070018, 'Chicken Patiyala', 'chicken patiyala', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018136, 400070018, 'Chicken Rara', 'chicken rara', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018137, 400070018, 'Chicken Tikka Masala', 'chicken tikka masala', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018138, 400070018, 'Chicken Kadai Peshawar', 'chicken kadai peshawar', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018139, 400070018, 'Chicken Nargish Kofta', 'chicken nargish kofta', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018140, 400070018, 'Murg Musallam H/F', 'murg musallam h/f', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018141, 400070018, 'Mugh Bhuna (MSL)', 'mugh bhuna (msl)', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018142, 400070018, 'Murg Pasanda', 'murg pasanda', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018143, 400070018, 'Murg Angara (MSL)', 'murg angara (msl)', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018144, 400070018, 'Murg Matka Masala', 'murg matka masala', 'AL TABBAKH AL RAYEESI (MAIN COURSE) - CHICKEN GRAVY', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018145, 400070018, 'Mutton Kadai', 'mutton kadai', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018146, 400070018, 'Mutton Masala', 'mutton masala', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018147, 400070018, 'Mutton Korma', 'mutton korma', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018148, 400070018, 'Mutton Patiyala', 'mutton patiyala', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018149, 400070018, 'Mutton Rara', 'mutton rara', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018150, 400070018, 'Mutton Handi', 'mutton handi', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018151, 400070018, 'Mutton Kolhapuri', 'mutton kolhapuri', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018152, 400070018, 'Mutton Nalli Nihari', 'mutton nalli nihari', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018153, 400070018, 'Mutton Chaap Masala', 'mutton chaap masala', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018154, 400070018, 'Mutton Seekh Kabab Masala', 'mutton seekh kabab masala', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018155, 400070018, 'Mutton Shikari', 'mutton shikari', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018156, 400070018, 'Mutton Peshawari (MSL) Spicy', 'mutton peshawari (msl) spicy', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018157, 400070018, 'Mutton Badami Korma', 'mutton badami korma', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018158, 400070018, 'Mutton lahori', 'mutton lahori', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018159, 400070018, 'Mutton Angara(MSL)', 'mutton angara(msl)', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018160, 400070018, 'Raan Tandoori Butter Masala Spl.', 'raan tandoori butter masala spl.', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018161, 400070018, 'Raan Rara Masala', 'raan rara masala', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018162, 400070018, 'Raan Korma', 'raan korma', 'MUTTON GRAVY', 'non_veg'::text, 'mutton'::text, NULL::text, 'unverified'),
    (400070018163, 400070018, 'Fish Mandi', 'fish mandi', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'needs_review'),
    (400070018164, 400070018, 'Pomfret Tawa Fry - 1 Pcs', 'pomfret tawa fry - 1 pcs', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'needs_review'),
    (400070018165, 400070018, 'Pomfret Deep Fry - 1 Pcs', 'pomfret deep fry - 1 pcs', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'needs_review'),
    (400070018166, 400070018, 'Surmai Tawa Fry - 1 Pcs', 'surmai tawa fry - 1 pcs', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'needs_review'),
    (400070018167, 400070018, 'Surmai Deep Fry 1 Pcs', 'surmai deep fry 1 pcs', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070018168, 400070018, 'Prawns Chilli', 'prawns chilli', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070018169, 400070018, 'Prawns Crispy', 'prawns crispy', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070018170, 400070018, 'Prawns Fried Rice', 'prawns fried rice', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070018171, 400070018, 'Prawns Schezwan Fried Rice', 'prawns schezwan fried rice', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070018172, 400070018, 'Fish Fried Rice', 'fish fried rice', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070018173, 400070018, 'Fish Tikka', 'fish tikka', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070018174, 400070018, 'Prawns Tikka', 'prawns tikka', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070018175, 400070018, 'Pomfret Tandoori', 'pomfret tandoori', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070018176, 400070018, 'Prawns Platter (2 Person)', 'prawns platter (2 person)', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'unverified'),
    (400070018177, 400070018, 'Prawns Platter (3 Person)', 'prawns platter (3 person)', 'SEA FOOD', 'non_veg'::text, 'seafood'::text, NULL::text, 'needs_review'),
    (400070018178, 400070018, 'Paneer Malai Tikka', 'paneer malai tikka', 'VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018179, 400070018, 'Paneer Pahadi Kabab', 'paneer pahadi kabab', 'VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018180, 400070018, 'Sahi Paneer', 'sahi paneer', 'VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018181, 400070018, 'Paneer Malai Chilli', 'paneer malai chilli', 'VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018182, 400070018, 'Veg. Crispy', 'veg. crispy', 'VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018183, 400070018, 'Mushroom Tandoori', 'mushroom tandoori', 'VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018184, 400070018, 'Mushroom Chilli', 'mushroom chilli', 'VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018185, 400070018, 'Paneer Chilli Dry', 'paneer chilli dry', 'VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018186, 400070018, 'Paneer Crispy', 'paneer crispy', 'VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018187, 400070018, 'Paneer 65', 'paneer 65', 'VEG. STARTERS', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018188, 400070018, 'Paneer Butter Masala', 'paneer butter masala', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018189, 400070018, 'Paneer Kadai', 'paneer kadai', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018190, 400070018, 'Paneer Masala', 'paneer masala', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018191, 400070018, 'Paneer Kolhapuri', 'paneer kolhapuri', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018192, 400070018, 'Shahi Paneer', 'shahi paneer', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018193, 400070018, 'Paneer Makkhanwala', 'paneer makkhanwala', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018194, 400070018, 'Veg Kadai', 'veg kadai', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018195, 400070018, 'Veg Kolhapuri', 'veg kolhapuri', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018196, 400070018, 'Veg Handi', 'veg handi', 'VEG. GRAVY', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018197, 400070018, 'Dal Fry', 'dal fry', 'Dal', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018198, 400070018, 'Dal Tadka', 'dal tadka', 'Dal', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018199, 400070018, 'Dal Makhani', 'dal makhani', 'Dal', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018200, 400070018, 'Dal Khichdi', 'dal khichdi', 'Dal', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018201, 400070018, 'Tandoori Roti', 'tandoori roti', 'KHABOOS (BREADS)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018202, 400070018, 'Tandoori Butter Roti', 'tandoori butter roti', 'KHABOOS (BREADS)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018203, 400070018, 'Butter Naan', 'butter naan', 'KHABOOS (BREADS)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018204, 400070018, 'Butter Garlic Naan', 'butter garlic naan', 'KHABOOS (BREADS)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018205, 400070018, 'Plan Naan', 'plan naan', 'KHABOOS (BREADS)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018206, 400070018, 'Garlic Naan Butter', 'garlic naan butter', 'KHABOOS (BREADS)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018207, 400070018, 'Tabi Naan Butter', 'tabi naan butter', 'KHABOOS (BREADS)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018208, 400070018, 'Cheese Naan', 'cheese naan', 'KHABOOS (BREADS)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018209, 400070018, 'Butter Cheese Naan', 'butter cheese naan', 'KHABOOS (BREADS)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018210, 400070018, 'Butter Cheese Garlic Naan', 'butter cheese garlic naan', 'KHABOOS (BREADS)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018211, 400070018, 'Lachcha Paratha', 'lachcha paratha', 'KHABOOS (BREADS)', 'veg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018212, 400070018, 'Arabian Spl. Chilly Dry', 'arabian spl. chilly dry', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018213, 400070018, 'Chicken Manchurian Dry', 'chicken manchurian dry', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018214, 400070018, 'Chicken Chilly Dry', 'chicken chilly dry', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018215, 400070018, 'Chicken Hot Garlic Dry', 'chicken hot garlic dry', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018216, 400070018, 'Chicken Dargan Dry', 'chicken dargan dry', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018217, 400070018, 'Chicken Hong Kong Dry', 'chicken hong kong dry', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018218, 400070018, 'Chicken Crispy', 'chicken crispy', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018219, 400070018, 'Chicken Apply Dry', 'chicken apply dry', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018220, 400070018, 'Chicken Lolly Pop', 'chicken lolly pop', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018221, 400070018, 'Chicken Oyster Dry', 'chicken oyster dry', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018222, 400070018, 'Chicken 65 Dry', 'chicken 65 dry', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018223, 400070018, 'Chicken Malai Crispy', 'chicken malai crispy', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018224, 400070018, 'Chicken Cheese Crispy', 'chicken cheese crispy', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018225, 400070018, 'Chicken Zafrani Crispy', 'chicken zafrani crispy', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018226, 400070018, 'Lolly Tossed', 'lolly tossed', 'CHICKEN STARTERS', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018227, 400070018, 'Chicken Fried Rice', 'chicken fried rice', 'CHINESE RICE', 'veg'::text, NULL::text, 'sp:chicken fried rice|(1, 8)'::text, 'needs_review'),
    (400070018228, 400070018, 'Chicken Fried Rice', 'chicken fried rice', 'CHINESE RICE', 'non_veg'::text, 'chicken'::text, 'sp:chicken fried rice|(1, 8)'::text, 'needs_review'),
    (400070018229, 400070018, 'Chi. Schezwan Fried Rice', 'chi. schezwan fried rice', 'CHINESE RICE', 'veg'::text, NULL::text, 'sp:chi. schezwan fried rice|(1, 8)'::text, 'needs_review'),
    (400070018230, 400070018, 'Chi. Schezwan Fried Rice', 'chi. schezwan fried rice', 'CHINESE RICE', 'non_veg'::text, 'chicken'::text, 'sp:chi. schezwan fried rice|(1, 8)'::text, 'needs_review'),
    (400070018231, 400070018, 'Chi. Burnt Garlic Fried Rice', 'chi. burnt garlic fried rice', 'CHINESE RICE', 'veg'::text, NULL::text, 'sp:chi. burnt garlic fried rice|(1, 8)'::text, 'needs_review'),
    (400070018232, 400070018, 'Chi. Burnt Garlic Fried Rice', 'chi. burnt garlic fried rice', 'CHINESE RICE', 'non_veg'::text, 'chicken'::text, 'sp:chi. burnt garlic fried rice|(1, 8)'::text, 'needs_review'),
    (400070018233, 400070018, 'Chi. Singapore Rice', 'chi. singapore rice', 'CHINESE RICE', 'veg'::text, NULL::text, 'sp:chi. singapore rice|(1, 8)'::text, 'needs_review'),
    (400070018234, 400070018, 'Chi. Singapore Rice', 'chi. singapore rice', 'CHINESE RICE', 'non_veg'::text, 'chicken'::text, 'sp:chi. singapore rice|(1, 8)'::text, 'needs_review'),
    (400070018235, 400070018, 'Chi. Malaysian Rice', 'chi. malaysian rice', 'CHINESE RICE', 'veg'::text, NULL::text, 'sp:chi. malaysian rice|(1, 8)'::text, 'needs_review'),
    (400070018236, 400070018, 'Chi. Malaysian Rice', 'chi. malaysian rice', 'CHINESE RICE', 'non_veg'::text, 'chicken'::text, 'sp:chi. malaysian rice|(1, 8)'::text, 'needs_review'),
    (400070018237, 400070018, 'Chi. Hong Kong Rice', 'chi. hong kong rice', 'CHINESE RICE', 'veg'::text, NULL::text, 'sp:chi. hong kong rice|(1, 8)'::text, 'needs_review'),
    (400070018238, 400070018, 'Chi. Hong Kong Rice', 'chi. hong kong rice', 'CHINESE RICE', 'non_veg'::text, 'chicken'::text, 'sp:chi. hong kong rice|(1, 8)'::text, 'needs_review'),
    (400070018239, 400070018, 'Chi. Chilly Garlic Rice + Gravy', 'chi. chilly garlic rice + gravy', 'CHINESE RICE', 'veg'::text, NULL::text, 'sp:chi. chilly garlic rice + gravy|(1, 8)'::text, 'needs_review'),
    (400070018240, 400070018, 'Chi. Chilly Garlic Rice + Gravy', 'chi. chilly garlic rice + gravy', 'CHINESE RICE', 'non_veg'::text, 'chicken'::text, 'sp:chi. chilly garlic rice + gravy|(1, 8)'::text, 'needs_review'),
    (400070018241, 400070018, 'Chi. Tripple Fried Rice + Gravy', 'chi. tripple fried rice + gravy', 'CHINESE RICE', 'veg'::text, NULL::text, 'sp:chi. tripple fried rice + gravy|(1, 8)'::text, 'needs_review'),
    (400070018242, 400070018, 'Chi. Tripple Fried Rice + Gravy', 'chi. tripple fried rice + gravy', 'CHINESE RICE', 'non_veg'::text, 'chicken'::text, 'sp:chi. tripple fried rice + gravy|(1, 8)'::text, 'needs_review'),
    (400070018243, 400070018, 'Chi. Manchurian Fried Rice+ Gravy', 'chi. manchurian fried rice+ gravy', 'CHINESE RICE', 'veg'::text, NULL::text, 'sp:chi. manchurian fried rice+ gravy|(1, 8)'::text, 'needs_review'),
    (400070018244, 400070018, 'Chi. Manchurian Fried Rice+ Gravy', 'chi. manchurian fried rice+ gravy', 'CHINESE RICE', 'non_veg'::text, 'chicken'::text, 'sp:chi. manchurian fried rice+ gravy|(1, 8)'::text, 'needs_review'),
    (400070018245, 400070018, 'Chi. Burnt Chilly Pot Rice', 'chi. burnt chilly pot rice', 'CHINESE RICE', 'veg'::text, NULL::text, 'sp:chi. burnt chilly pot rice|(1, 8)'::text, 'needs_review'),
    (400070018246, 400070018, 'Chi. Burnt Chilly Pot Rice', 'chi. burnt chilly pot rice', 'CHINESE RICE', 'non_veg'::text, 'chicken'::text, 'sp:chi. burnt chilly pot rice|(1, 8)'::text, 'needs_review'),
    (400070018247, 400070018, 'Chicken Dragon Pot Rice', 'chicken dragon pot rice', 'CHINESE RICE', 'veg'::text, NULL::text, 'sp:chicken dragon pot rice|(1, 8)'::text, 'needs_review'),
    (400070018248, 400070018, 'Chicken Dragon Pot Rice', 'chicken dragon pot rice', 'CHINESE RICE', 'non_veg'::text, 'chicken'::text, 'sp:chicken dragon pot rice|(1, 8)'::text, 'needs_review'),
    (400070018249, 400070018, 'Egg Fried Rice', 'egg fried rice', 'CHINESE RICE', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018250, 400070018, 'Afghani Egg Fried Rice', 'afghani egg fried rice', 'CHINESE RICE', 'egg'::text, NULL::text, NULL::text, 'unverified'),
    (400070018251, 400070018, 'Afghani Chicken Fried Rice', 'afghani chicken fried rice', 'CHINESE RICE', 'non_veg'::text, 'chicken'::text, NULL::text, 'unverified'),
    (400070018252, 400070018, 'Chicken Hakka Noodles', 'chicken hakka noodles', 'CHINESE NOODLES', 'veg'::text, NULL::text, 'sp:chicken hakka noodles|(1, 9)'::text, 'needs_review'),
    (400070018253, 400070018, 'Chicken Hakka Noodles', 'chicken hakka noodles', 'CHINESE NOODLES', 'non_veg'::text, 'chicken'::text, 'sp:chicken hakka noodles|(1, 9)'::text, 'needs_review'),
    (400070018254, 400070018, 'Chi. Schezwan Hakka Noodles', 'chi. schezwan hakka noodles', 'CHINESE NOODLES', 'veg'::text, NULL::text, 'sp:chi. schezwan hakka noodles|(1, 9)'::text, 'needs_review'),
    (400070018255, 400070018, 'Chi. Schezwan Hakka Noodles', 'chi. schezwan hakka noodles', 'CHINESE NOODLES', 'non_veg'::text, 'chicken'::text, 'sp:chi. schezwan hakka noodles|(1, 9)'::text, 'needs_review'),
    (400070018256, 400070018, 'Chi. Burnt Garlic Noodles', 'chi. burnt garlic noodles', 'CHINESE NOODLES', 'veg'::text, NULL::text, 'sp:chi. burnt garlic noodles|(1, 9)'::text, 'needs_review'),
    (400070018257, 400070018, 'Chi. Burnt Garlic Noodles', 'chi. burnt garlic noodles', 'CHINESE NOODLES', 'non_veg'::text, 'chicken'::text, 'sp:chi. burnt garlic noodles|(1, 9)'::text, 'needs_review'),
    (400070018258, 400070018, 'Chi. Singapore Noodles', 'chi. singapore noodles', 'CHINESE NOODLES', 'veg'::text, NULL::text, 'sp:chi. singapore noodles|(1, 9)'::text, 'needs_review'),
    (400070018259, 400070018, 'Chi. Singapore Noodles', 'chi. singapore noodles', 'CHINESE NOODLES', 'non_veg'::text, 'chicken'::text, 'sp:chi. singapore noodles|(1, 9)'::text, 'needs_review'),
    (400070018260, 400070018, 'Chi. Malaysian Noodles', 'chi. malaysian noodles', 'CHINESE NOODLES', 'veg'::text, NULL::text, 'sp:chi. malaysian noodles|(1, 9)'::text, 'needs_review'),
    (400070018261, 400070018, 'Chi. Malaysian Noodles', 'chi. malaysian noodles', 'CHINESE NOODLES', 'non_veg'::text, 'chicken'::text, 'sp:chi. malaysian noodles|(1, 9)'::text, 'needs_review'),
    (400070018262, 400070018, 'Chi Hong Kong Noodles', 'chi hong kong noodles', 'CHINESE NOODLES', 'veg'::text, NULL::text, 'sp:chi hong kong noodles|(1, 9)'::text, 'needs_review'),
    (400070018263, 400070018, 'Chi Hong Kong Noodles', 'chi hong kong noodles', 'CHINESE NOODLES', 'non_veg'::text, NULL::text, 'sp:chi hong kong noodles|(1, 9)'::text, 'needs_review'),
    (400070018264, 400070018, 'CHEESE KUNAFEH', 'cheese kunafeh', 'DESSART', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070018265, 400070018, 'KUNAFEH', 'kunafeh', 'DESSART', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070018266, 400070018, 'OMALI', 'omali', 'DESSART', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070018267, 400070018, 'LEBANESE PUDDING', 'lebanese pudding', 'DESSART', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070018268, 400070018, 'Lime Mojito', 'lime mojito', 'MOCKTAIL', NULL::text, NULL::text, NULL::text, 'needs_review'),
    (400070018269, 400070018, 'Fruit Champagne', 'fruit champagne', 'MOCKTAIL', NULL::text, NULL::text, NULL::text, 'needs_review')
) AS x(menu_item_id, restaurant_id, name, normalized_name, raw_category_text, food_classification_code, protein_code, split_group_key, verification_status_code)
JOIN canonical_dish cd ON cd.normalized_name = x.normalized_name
LEFT JOIN protein_type pt ON pt.code = x.protein_code;

-- Menu item source: name/existence confidence, kept separate from price confidence.
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
VALUES
    (400070018001, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018002, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018003, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018004, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018005, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018006, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018007, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018008, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018009, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018010, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018011, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018012, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018013, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018014, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018015, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018016, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018017, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018018, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018019, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018020, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018021, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018022, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018023, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018024, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018025, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018026, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018027, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018028, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018029, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018030, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018031, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018032, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018033, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018034, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018035, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018036, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018037, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018038, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018039, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018040, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018041, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018042, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018043, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018044, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018045, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018046, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018047, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018048, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018049, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018050, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018051, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018052, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018053, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018054, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018055, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018056, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018057, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018058, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018059, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018060, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018061, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018062, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018063, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018064, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018065, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018066, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018067, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018068, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018069, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018070, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018071, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018072, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018073, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018074, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018075, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018076, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018077, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018078, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018079, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018080, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018081, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018082, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018083, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018084, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018085, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018086, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018087, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018088, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018089, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018090, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018091, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018092, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018093, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018094, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018095, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018096, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018097, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018098, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018099, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018100, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018101, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018102, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018103, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018104, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018105, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018106, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018107, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018108, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018109, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018110, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018111, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018112, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018113, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018114, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018115, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018116, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018117, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018118, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018119, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018120, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018121, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018122, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018123, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018124, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018125, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018126, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018127, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018128, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018129, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018130, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018131, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018132, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018133, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018134, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018135, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018136, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018137, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018138, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018139, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018140, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018141, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018142, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018143, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018144, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018145, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018146, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018147, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018148, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018149, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018150, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018151, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018152, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018153, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018154, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018155, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018156, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018157, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018158, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018159, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018160, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018161, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018162, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018163, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018164, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018165, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018166, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018167, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018168, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018169, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018170, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018171, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018172, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018173, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018174, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018175, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018176, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018177, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018178, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018179, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018180, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018181, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018182, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018183, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018184, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018185, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018186, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018187, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018188, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018189, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018190, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018191, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018192, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018193, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018194, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018195, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018196, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018197, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018198, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018199, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018200, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018201, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018202, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018203, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018204, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018205, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018206, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018207, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018208, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018209, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018210, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018211, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018212, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018213, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018214, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018215, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018216, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018217, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018218, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018219, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018220, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018221, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018222, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018223, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018224, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018225, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018226, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018227, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018228, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018229, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018230, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018231, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018232, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018233, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018234, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018235, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018236, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018237, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018238, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018239, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018240, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018241, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018242, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018243, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018244, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018245, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018246, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018247, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018248, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018249, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018250, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018251, 400070018, :extraction_batch_id, 0.9, 'unverified'),
    (400070018252, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018253, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018254, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018255, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018256, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018257, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018258, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018259, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018260, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018261, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018262, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018263, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018264, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018265, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018266, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018267, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018268, 400070018, :extraction_batch_id, 0.9, 'needs_review'),
    (400070018269, 400070018, :extraction_batch_id, 0.9, 'needs_review');

-- Variants (portion/label variants -- one menu_item, multiple menu_item_variant rows;
-- a protein/veg split already became two separate menu_item rows above, so each carries
-- exactly one variant here).
INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
VALUES
    (400070018001, 400070018001, 'Regular', 'fixed', TRUE),
    (400070018002, 400070018002, 'Regular', 'fixed', TRUE),
    (400070018003, 400070018003, 'Regular', 'fixed', TRUE),
    (400070018004, 400070018004, 'Regular', 'fixed', TRUE),
    (400070018005, 400070018005, 'Regular', 'fixed', TRUE),
    (400070018006, 400070018006, 'Regular', 'fixed', TRUE),
    (400070018007, 400070018007, 'Regular', 'fixed', TRUE),
    (400070018008, 400070018008, 'Regular', 'fixed', TRUE),
    (400070018009, 400070018009, 'Regular', 'fixed', TRUE),
    (400070018010, 400070018010, 'Regular', 'fixed', TRUE),
    (400070018011, 400070018011, 'Regular', 'fixed', TRUE),
    (400070018012, 400070018012, 'Regular', 'fixed', TRUE),
    (400070018013, 400070018013, 'Regular', 'fixed', TRUE),
    (400070018014, 400070018014, 'Regular', 'fixed', TRUE),
    (400070018015, 400070018015, 'Regular', 'fixed', TRUE),
    (400070018016, 400070018016, 'Regular', 'fixed', TRUE),
    (400070018017, 400070018017, 'Regular', 'fixed', TRUE),
    (400070018018, 400070018018, 'Regular', 'fixed', TRUE),
    (400070018019, 400070018019, 'Regular', 'fixed', TRUE),
    (400070018020, 400070018020, 'H', 'fixed', TRUE),
    (400070018021, 400070018020, 'F', 'fixed', FALSE),
    (400070018022, 400070018021, 'H', 'fixed', TRUE),
    (400070018023, 400070018021, 'F', 'fixed', FALSE),
    (400070018024, 400070018022, 'H', 'fixed', TRUE),
    (400070018025, 400070018022, 'F', 'fixed', FALSE),
    (400070018026, 400070018023, 'H', 'fixed', TRUE),
    (400070018027, 400070018023, 'F', 'fixed', FALSE),
    (400070018028, 400070018024, 'H', 'fixed', TRUE),
    (400070018029, 400070018024, 'F', 'fixed', FALSE),
    (400070018030, 400070018025, 'H', 'fixed', TRUE),
    (400070018031, 400070018025, 'F', 'fixed', FALSE),
    (400070018032, 400070018026, 'H', 'fixed', TRUE),
    (400070018033, 400070018026, 'F', 'fixed', FALSE),
    (400070018034, 400070018027, 'H', 'fixed', TRUE),
    (400070018035, 400070018027, 'F', 'fixed', FALSE),
    (400070018036, 400070018028, 'H', 'fixed', TRUE),
    (400070018037, 400070018028, 'F', 'fixed', FALSE),
    (400070018038, 400070018029, 'H', 'fixed', TRUE),
    (400070018039, 400070018029, 'F', 'fixed', FALSE),
    (400070018040, 400070018030, 'Regular', 'fixed', TRUE),
    (400070018041, 400070018031, 'H', 'fixed', TRUE),
    (400070018042, 400070018031, 'F', 'fixed', FALSE),
    (400070018043, 400070018032, 'H', 'fixed', TRUE),
    (400070018044, 400070018032, 'F', 'fixed', FALSE),
    (400070018045, 400070018033, 'H', 'fixed', TRUE),
    (400070018046, 400070018033, 'F', 'fixed', FALSE),
    (400070018047, 400070018034, 'H', 'fixed', TRUE),
    (400070018048, 400070018034, 'F', 'fixed', FALSE),
    (400070018049, 400070018035, 'H', 'fixed', TRUE),
    (400070018050, 400070018035, 'F', 'fixed', FALSE),
    (400070018051, 400070018036, 'H', 'fixed', TRUE),
    (400070018052, 400070018036, 'F', 'fixed', FALSE),
    (400070018053, 400070018037, 'H', 'fixed', TRUE),
    (400070018054, 400070018037, 'F', 'fixed', FALSE),
    (400070018055, 400070018038, 'Regular', 'fixed', TRUE),
    (400070018056, 400070018039, 'H', 'fixed', TRUE),
    (400070018057, 400070018039, 'F', 'fixed', FALSE),
    (400070018058, 400070018040, 'Regular', 'fixed', TRUE),
    (400070018059, 400070018041, 'Regular', 'fixed', TRUE),
    (400070018060, 400070018042, 'Regular', 'fixed', TRUE),
    (400070018061, 400070018043, 'Regular', 'fixed', TRUE),
    (400070018062, 400070018044, 'Regular', 'fixed', TRUE),
    (400070018063, 400070018045, 'Regular', 'fixed', TRUE),
    (400070018064, 400070018046, 'Regular', 'fixed', TRUE),
    (400070018065, 400070018047, 'Regular', 'fixed', TRUE),
    (400070018066, 400070018048, 'Regular', 'fixed', TRUE),
    (400070018067, 400070018049, 'H', 'fixed', TRUE),
    (400070018068, 400070018049, 'F', 'fixed', FALSE),
    (400070018069, 400070018050, 'H', 'fixed', TRUE),
    (400070018070, 400070018050, 'F', 'fixed', FALSE),
    (400070018071, 400070018051, 'H', 'fixed', TRUE),
    (400070018072, 400070018051, 'F', 'fixed', FALSE),
    (400070018073, 400070018052, 'H', 'fixed', TRUE),
    (400070018074, 400070018052, 'F', 'fixed', FALSE),
    (400070018075, 400070018053, 'H', 'fixed', TRUE),
    (400070018076, 400070018053, 'F', 'fixed', FALSE),
    (400070018077, 400070018054, 'H', 'fixed', TRUE),
    (400070018078, 400070018054, 'F', 'fixed', FALSE),
    (400070018079, 400070018055, 'H', 'fixed', TRUE),
    (400070018080, 400070018055, 'F', 'fixed', FALSE),
    (400070018081, 400070018056, 'H', 'fixed', TRUE),
    (400070018082, 400070018056, 'F', 'fixed', FALSE),
    (400070018083, 400070018057, 'H', 'fixed', TRUE),
    (400070018084, 400070018057, 'F', 'fixed', FALSE),
    (400070018085, 400070018058, 'H', 'fixed', TRUE),
    (400070018086, 400070018058, 'F', 'fixed', FALSE),
    (400070018087, 400070018059, 'H', 'fixed', TRUE),
    (400070018088, 400070018059, 'F', 'fixed', FALSE),
    (400070018089, 400070018060, 'H', 'fixed', TRUE),
    (400070018090, 400070018060, 'F', 'fixed', FALSE),
    (400070018091, 400070018061, 'H', 'fixed', TRUE),
    (400070018092, 400070018061, 'F', 'fixed', FALSE),
    (400070018093, 400070018062, 'Regular', 'fixed', TRUE),
    (400070018094, 400070018063, 'Regular', 'fixed', TRUE),
    (400070018095, 400070018064, 'H', 'fixed', TRUE),
    (400070018096, 400070018064, 'F', 'fixed', FALSE),
    (400070018097, 400070018065, 'H', 'fixed', TRUE),
    (400070018098, 400070018065, 'F', 'fixed', FALSE),
    (400070018099, 400070018066, 'H', 'fixed', TRUE),
    (400070018100, 400070018066, 'F', 'fixed', FALSE),
    (400070018101, 400070018067, 'H', 'fixed', TRUE),
    (400070018102, 400070018067, 'F', 'fixed', FALSE),
    (400070018103, 400070018068, 'H', 'fixed', TRUE),
    (400070018104, 400070018068, 'F', 'fixed', FALSE),
    (400070018105, 400070018069, 'H', 'fixed', TRUE),
    (400070018106, 400070018069, 'F', 'fixed', FALSE),
    (400070018107, 400070018070, 'Regular', 'fixed', TRUE),
    (400070018108, 400070018071, 'Regular', 'fixed', TRUE),
    (400070018109, 400070018072, 'Regular', 'fixed', TRUE),
    (400070018110, 400070018073, 'Regular', 'fixed', TRUE),
    (400070018111, 400070018074, 'Regular', 'fixed', TRUE),
    (400070018112, 400070018075, 'Regular', 'fixed', TRUE),
    (400070018113, 400070018076, 'Regular', 'fixed', TRUE),
    (400070018114, 400070018077, 'Regular', 'fixed', TRUE),
    (400070018115, 400070018078, 'H', 'fixed', TRUE),
    (400070018116, 400070018078, 'F', 'fixed', FALSE),
    (400070018117, 400070018079, 'H', 'fixed', TRUE),
    (400070018118, 400070018079, 'F', 'fixed', FALSE),
    (400070018119, 400070018080, 'H', 'fixed', TRUE),
    (400070018120, 400070018080, 'F', 'fixed', FALSE),
    (400070018121, 400070018081, 'H', 'fixed', TRUE),
    (400070018122, 400070018081, 'F', 'fixed', FALSE),
    (400070018123, 400070018082, 'H', 'fixed', TRUE),
    (400070018124, 400070018082, 'F', 'fixed', FALSE),
    (400070018125, 400070018083, 'Q', 'fixed', TRUE),
    (400070018126, 400070018083, 'H', 'fixed', FALSE),
    (400070018127, 400070018083, 'F', 'fixed', FALSE),
    (400070018128, 400070018084, 'Q', 'fixed', TRUE),
    (400070018129, 400070018084, 'H', 'fixed', FALSE),
    (400070018130, 400070018084, 'F', 'fixed', FALSE),
    (400070018131, 400070018085, 'Q', 'fixed', TRUE),
    (400070018132, 400070018085, 'H', 'fixed', FALSE),
    (400070018133, 400070018085, 'F', 'fixed', FALSE),
    (400070018134, 400070018086, 'Q', 'fixed', TRUE),
    (400070018135, 400070018086, 'H', 'fixed', FALSE),
    (400070018136, 400070018086, 'F', 'fixed', FALSE),
    (400070018137, 400070018087, 'H', 'fixed', TRUE),
    (400070018138, 400070018087, 'F', 'fixed', FALSE),
    (400070018139, 400070018088, 'Q', 'fixed', TRUE),
    (400070018140, 400070018088, 'H', 'fixed', FALSE),
    (400070018141, 400070018088, 'F', 'fixed', FALSE),
    (400070018142, 400070018089, 'Q', 'fixed', TRUE),
    (400070018143, 400070018089, 'H', 'fixed', FALSE),
    (400070018144, 400070018089, 'F', 'fixed', FALSE),
    (400070018145, 400070018090, 'Q', 'fixed', TRUE),
    (400070018146, 400070018090, 'H', 'fixed', FALSE),
    (400070018147, 400070018090, 'F', 'fixed', FALSE),
    (400070018148, 400070018091, 'Q', 'fixed', TRUE),
    (400070018149, 400070018091, 'H', 'fixed', FALSE),
    (400070018150, 400070018091, 'F', 'fixed', FALSE),
    (400070018151, 400070018092, 'Q', 'fixed', TRUE),
    (400070018152, 400070018092, 'H', 'fixed', FALSE),
    (400070018153, 400070018092, 'F', 'fixed', FALSE),
    (400070018154, 400070018093, 'Regular', 'fixed', TRUE),
    (400070018155, 400070018094, 'Regular', 'fixed', TRUE),
    (400070018156, 400070018095, 'Regular', 'fixed', TRUE),
    (400070018157, 400070018096, 'Regular', 'fixed', TRUE),
    (400070018158, 400070018097, 'Regular', 'fixed', TRUE),
    (400070018159, 400070018098, 'Regular', 'fixed', TRUE),
    (400070018160, 400070018099, 'Regular', 'fixed', TRUE),
    (400070018161, 400070018100, 'Regular', 'fixed', TRUE),
    (400070018162, 400070018101, 'Regular', 'fixed', TRUE),
    (400070018163, 400070018102, 'Regular', 'fixed', TRUE),
    (400070018164, 400070018103, 'Regular', 'fixed', TRUE),
    (400070018165, 400070018104, 'Regular', 'fixed', TRUE),
    (400070018166, 400070018105, 'Q', 'fixed', TRUE),
    (400070018167, 400070018105, 'H', 'fixed', FALSE),
    (400070018168, 400070018105, 'F', 'fixed', FALSE),
    (400070018169, 400070018106, 'Q', 'fixed', TRUE),
    (400070018170, 400070018106, 'H', 'fixed', FALSE),
    (400070018171, 400070018106, 'F', 'fixed', FALSE),
    (400070018172, 400070018107, 'Q', 'fixed', TRUE),
    (400070018173, 400070018107, 'H', 'fixed', FALSE),
    (400070018174, 400070018107, 'F', 'fixed', FALSE),
    (400070018175, 400070018108, 'H', 'fixed', TRUE),
    (400070018176, 400070018108, 'F', 'fixed', FALSE),
    (400070018177, 400070018109, 'H', 'fixed', TRUE),
    (400070018178, 400070018109, 'F', 'fixed', FALSE),
    (400070018179, 400070018110, 'Q', 'fixed', TRUE),
    (400070018180, 400070018110, 'H', 'fixed', FALSE),
    (400070018181, 400070018110, 'F', 'fixed', FALSE),
    (400070018182, 400070018111, 'Regular', 'fixed', TRUE),
    (400070018183, 400070018112, 'Regular', 'fixed', TRUE),
    (400070018184, 400070018113, 'Q', 'fixed', TRUE),
    (400070018185, 400070018113, 'H', 'fixed', FALSE),
    (400070018186, 400070018113, 'F', 'fixed', FALSE),
    (400070018187, 400070018114, 'H', 'fixed', TRUE),
    (400070018188, 400070018114, 'F', 'fixed', FALSE),
    (400070018189, 400070018115, 'Regular', 'fixed', TRUE),
    (400070018190, 400070018116, 'H', 'fixed', TRUE),
    (400070018191, 400070018116, 'F', 'fixed', FALSE),
    (400070018192, 400070018117, 'H', 'fixed', TRUE),
    (400070018193, 400070018117, 'F', 'fixed', FALSE),
    (400070018194, 400070018118, 'H', 'fixed', TRUE),
    (400070018195, 400070018118, 'F', 'fixed', FALSE),
    (400070018196, 400070018119, 'H', 'fixed', TRUE),
    (400070018197, 400070018119, 'F', 'fixed', FALSE),
    (400070018198, 400070018120, 'Regular', 'fixed', TRUE),
    (400070018199, 400070018121, 'Regular', 'fixed', TRUE),
    (400070018200, 400070018122, 'Q', 'fixed', TRUE),
    (400070018201, 400070018122, 'H', 'fixed', FALSE),
    (400070018202, 400070018122, 'F', 'fixed', FALSE),
    (400070018203, 400070018123, 'Q', 'fixed', TRUE),
    (400070018204, 400070018123, 'H', 'fixed', FALSE),
    (400070018205, 400070018123, 'F', 'fixed', FALSE),
    (400070018206, 400070018124, 'Q', 'fixed', TRUE),
    (400070018207, 400070018124, 'H', 'fixed', FALSE),
    (400070018208, 400070018124, 'F', 'fixed', FALSE),
    (400070018209, 400070018125, 'Q', 'fixed', TRUE),
    (400070018210, 400070018125, 'H', 'fixed', FALSE),
    (400070018211, 400070018125, 'F', 'fixed', FALSE),
    (400070018212, 400070018126, 'Regular', 'fixed', TRUE),
    (400070018213, 400070018127, 'Regular', 'fixed', TRUE),
    (400070018214, 400070018128, 'H', 'fixed', TRUE),
    (400070018215, 400070018128, 'F', 'fixed', FALSE),
    (400070018216, 400070018129, 'H', 'fixed', TRUE),
    (400070018217, 400070018129, 'F', 'fixed', FALSE),
    (400070018218, 400070018130, 'H', 'fixed', TRUE),
    (400070018219, 400070018130, 'F', 'fixed', FALSE),
    (400070018220, 400070018131, 'H', 'fixed', TRUE),
    (400070018221, 400070018131, 'F', 'fixed', FALSE),
    (400070018222, 400070018132, 'H', 'fixed', TRUE),
    (400070018223, 400070018132, 'F', 'fixed', FALSE),
    (400070018224, 400070018133, 'H', 'fixed', TRUE),
    (400070018225, 400070018133, 'F', 'fixed', FALSE),
    (400070018226, 400070018134, 'H', 'fixed', TRUE),
    (400070018227, 400070018134, 'F', 'fixed', FALSE),
    (400070018228, 400070018135, 'H', 'fixed', TRUE),
    (400070018229, 400070018135, 'F', 'fixed', FALSE),
    (400070018230, 400070018136, 'H', 'fixed', TRUE),
    (400070018231, 400070018136, 'F', 'fixed', FALSE),
    (400070018232, 400070018137, 'H', 'fixed', TRUE),
    (400070018233, 400070018137, 'F', 'fixed', FALSE),
    (400070018234, 400070018138, 'H', 'fixed', TRUE),
    (400070018235, 400070018138, 'F', 'fixed', FALSE),
    (400070018236, 400070018139, 'H', 'fixed', TRUE),
    (400070018237, 400070018139, 'F', 'fixed', FALSE),
    (400070018238, 400070018140, 'H', 'fixed', TRUE),
    (400070018239, 400070018140, 'F', 'fixed', FALSE),
    (400070018240, 400070018141, 'H', 'fixed', TRUE),
    (400070018241, 400070018141, 'F', 'fixed', FALSE),
    (400070018242, 400070018142, 'H', 'fixed', TRUE),
    (400070018243, 400070018142, 'F', 'fixed', FALSE),
    (400070018244, 400070018143, 'H', 'fixed', TRUE),
    (400070018245, 400070018143, 'F', 'fixed', FALSE),
    (400070018246, 400070018144, 'H', 'fixed', TRUE),
    (400070018247, 400070018144, 'F', 'fixed', FALSE),
    (400070018248, 400070018145, 'H', 'fixed', TRUE),
    (400070018249, 400070018145, 'F', 'fixed', FALSE),
    (400070018250, 400070018146, 'H', 'fixed', TRUE),
    (400070018251, 400070018146, 'F', 'fixed', FALSE),
    (400070018252, 400070018147, 'H', 'fixed', TRUE),
    (400070018253, 400070018147, 'F', 'fixed', FALSE),
    (400070018254, 400070018148, 'H', 'fixed', TRUE),
    (400070018255, 400070018148, 'F', 'fixed', FALSE),
    (400070018256, 400070018149, 'H', 'fixed', TRUE),
    (400070018257, 400070018149, 'F', 'fixed', FALSE),
    (400070018258, 400070018150, 'H', 'fixed', TRUE),
    (400070018259, 400070018150, 'F', 'fixed', FALSE),
    (400070018260, 400070018151, 'H', 'fixed', TRUE),
    (400070018261, 400070018151, 'F', 'fixed', FALSE),
    (400070018262, 400070018152, 'Regular', 'fixed', TRUE),
    (400070018263, 400070018153, 'Regular', 'fixed', TRUE),
    (400070018264, 400070018154, 'Regular', 'fixed', TRUE),
    (400070018265, 400070018155, 'H', 'fixed', TRUE),
    (400070018266, 400070018155, 'F', 'fixed', FALSE),
    (400070018267, 400070018156, 'H', 'fixed', TRUE),
    (400070018268, 400070018156, 'F', 'fixed', FALSE),
    (400070018269, 400070018157, 'H', 'fixed', TRUE),
    (400070018270, 400070018157, 'F', 'fixed', FALSE),
    (400070018271, 400070018158, 'H', 'fixed', TRUE),
    (400070018272, 400070018158, 'F', 'fixed', FALSE),
    (400070018273, 400070018159, 'H', 'fixed', TRUE),
    (400070018274, 400070018159, 'F', 'fixed', FALSE),
    (400070018275, 400070018160, 'Regular', 'fixed', TRUE),
    (400070018276, 400070018161, 'Regular', 'fixed', TRUE),
    (400070018277, 400070018162, 'Regular', 'fixed', TRUE),
    (400070018278, 400070018163, 'Regular', 'fixed', TRUE),
    (400070018279, 400070018164, 'Regular', 'fixed', TRUE),
    (400070018280, 400070018165, 'Regular', 'fixed', TRUE),
    (400070018281, 400070018166, 'Regular', 'fixed', TRUE),
    (400070018282, 400070018167, 'Regular', 'fixed', TRUE),
    (400070018283, 400070018168, 'Regular', 'fixed', TRUE),
    (400070018284, 400070018169, 'Regular', 'fixed', TRUE),
    (400070018285, 400070018170, 'Regular', 'fixed', TRUE),
    (400070018286, 400070018171, 'Regular', 'fixed', TRUE),
    (400070018287, 400070018172, 'Regular', 'fixed', TRUE),
    (400070018288, 400070018173, 'Regular', 'fixed', TRUE),
    (400070018289, 400070018174, 'Regular', 'fixed', TRUE),
    (400070018290, 400070018175, 'Regular', 'fixed', TRUE),
    (400070018291, 400070018176, 'Regular', 'fixed', TRUE),
    (400070018292, 400070018177, 'Regular', 'fixed', TRUE),
    (400070018293, 400070018178, 'Regular', 'fixed', TRUE),
    (400070018294, 400070018179, 'Regular', 'fixed', TRUE),
    (400070018295, 400070018180, 'Regular', 'fixed', TRUE),
    (400070018296, 400070018181, 'Regular', 'fixed', TRUE),
    (400070018297, 400070018182, 'Regular', 'fixed', TRUE),
    (400070018298, 400070018183, 'Regular', 'fixed', TRUE),
    (400070018299, 400070018184, 'Regular', 'fixed', TRUE),
    (400070018300, 400070018185, 'Regular', 'fixed', TRUE),
    (400070018301, 400070018186, 'Regular', 'fixed', TRUE),
    (400070018302, 400070018187, 'Regular', 'fixed', TRUE),
    (400070018303, 400070018188, 'H', 'fixed', TRUE),
    (400070018304, 400070018188, 'F', 'fixed', FALSE),
    (400070018305, 400070018189, 'H', 'fixed', TRUE),
    (400070018306, 400070018189, 'F', 'fixed', FALSE),
    (400070018307, 400070018190, 'H', 'fixed', TRUE),
    (400070018308, 400070018190, 'F', 'fixed', FALSE),
    (400070018309, 400070018191, 'H', 'fixed', TRUE),
    (400070018310, 400070018191, 'F', 'fixed', FALSE),
    (400070018311, 400070018192, 'H', 'fixed', TRUE),
    (400070018312, 400070018192, 'F', 'fixed', FALSE),
    (400070018313, 400070018193, 'H', 'fixed', TRUE),
    (400070018314, 400070018193, 'F', 'fixed', FALSE),
    (400070018315, 400070018194, 'H', 'fixed', TRUE),
    (400070018316, 400070018194, 'F', 'fixed', FALSE),
    (400070018317, 400070018195, 'H', 'fixed', TRUE),
    (400070018318, 400070018195, 'F', 'fixed', FALSE),
    (400070018319, 400070018196, 'H', 'fixed', TRUE),
    (400070018320, 400070018196, 'F', 'fixed', FALSE),
    (400070018321, 400070018197, 'Regular', 'fixed', TRUE),
    (400070018322, 400070018198, 'Regular', 'fixed', TRUE),
    (400070018323, 400070018199, 'Regular', 'fixed', TRUE),
    (400070018324, 400070018200, 'Regular', 'fixed', TRUE),
    (400070018325, 400070018201, 'Regular', 'fixed', TRUE),
    (400070018326, 400070018202, 'Regular', 'fixed', TRUE),
    (400070018327, 400070018203, 'Regular', 'fixed', TRUE),
    (400070018328, 400070018204, 'Regular', 'fixed', TRUE),
    (400070018329, 400070018205, 'Regular', 'fixed', TRUE),
    (400070018330, 400070018206, 'Regular', 'fixed', TRUE),
    (400070018331, 400070018207, 'Regular', 'fixed', TRUE),
    (400070018332, 400070018208, 'Regular', 'fixed', TRUE),
    (400070018333, 400070018209, 'Regular', 'fixed', TRUE),
    (400070018334, 400070018210, 'Regular', 'fixed', TRUE),
    (400070018335, 400070018211, 'Regular', 'fixed', TRUE),
    (400070018336, 400070018212, 'Regular', 'fixed', TRUE),
    (400070018337, 400070018213, 'Regular', 'fixed', TRUE),
    (400070018338, 400070018214, 'Regular', 'fixed', TRUE),
    (400070018339, 400070018215, 'Regular', 'fixed', TRUE),
    (400070018340, 400070018216, 'Regular', 'fixed', TRUE),
    (400070018341, 400070018217, 'Regular', 'fixed', TRUE),
    (400070018342, 400070018218, 'Regular', 'fixed', TRUE),
    (400070018343, 400070018219, 'Regular', 'fixed', TRUE),
    (400070018344, 400070018220, 'Regular', 'fixed', TRUE),
    (400070018345, 400070018221, 'Regular', 'fixed', TRUE),
    (400070018346, 400070018222, 'Regular', 'fixed', TRUE),
    (400070018347, 400070018223, 'Regular', 'fixed', TRUE),
    (400070018348, 400070018224, 'Regular', 'fixed', TRUE),
    (400070018349, 400070018225, 'Regular', 'fixed', TRUE),
    (400070018350, 400070018226, 'Regular', 'fixed', TRUE),
    (400070018351, 400070018227, 'Regular', 'fixed', TRUE),
    (400070018352, 400070018228, 'Regular', 'fixed', TRUE),
    (400070018353, 400070018229, 'Regular', 'fixed', TRUE),
    (400070018354, 400070018230, 'Regular', 'fixed', TRUE),
    (400070018355, 400070018231, 'Regular', 'fixed', TRUE),
    (400070018356, 400070018232, 'Regular', 'fixed', TRUE),
    (400070018357, 400070018233, 'Regular', 'fixed', TRUE),
    (400070018358, 400070018234, 'Regular', 'fixed', TRUE),
    (400070018359, 400070018235, 'Regular', 'fixed', TRUE),
    (400070018360, 400070018236, 'Regular', 'fixed', TRUE),
    (400070018361, 400070018237, 'Regular', 'fixed', TRUE),
    (400070018362, 400070018238, 'Regular', 'fixed', TRUE),
    (400070018363, 400070018239, 'Regular', 'fixed', TRUE),
    (400070018364, 400070018240, 'Regular', 'fixed', TRUE),
    (400070018365, 400070018241, 'Regular', 'fixed', TRUE),
    (400070018366, 400070018242, 'Regular', 'fixed', TRUE),
    (400070018367, 400070018243, 'Regular', 'fixed', TRUE),
    (400070018368, 400070018244, 'Regular', 'fixed', TRUE),
    (400070018369, 400070018245, 'Regular', 'fixed', TRUE),
    (400070018370, 400070018246, 'Regular', 'fixed', TRUE),
    (400070018371, 400070018247, 'Regular', 'fixed', TRUE),
    (400070018372, 400070018248, 'Regular', 'fixed', TRUE),
    (400070018373, 400070018249, 'Regular', 'fixed', TRUE),
    (400070018374, 400070018250, 'Regular', 'fixed', TRUE),
    (400070018375, 400070018251, 'Regular', 'fixed', TRUE),
    (400070018376, 400070018252, 'Regular', 'fixed', TRUE),
    (400070018377, 400070018253, 'Regular', 'fixed', TRUE),
    (400070018378, 400070018254, 'Regular', 'fixed', TRUE),
    (400070018379, 400070018255, 'Regular', 'fixed', TRUE),
    (400070018380, 400070018256, 'Regular', 'fixed', TRUE),
    (400070018381, 400070018257, 'Regular', 'fixed', TRUE),
    (400070018382, 400070018258, 'Regular', 'fixed', TRUE),
    (400070018383, 400070018259, 'Regular', 'fixed', TRUE),
    (400070018384, 400070018260, 'Regular', 'fixed', TRUE),
    (400070018385, 400070018261, 'Regular', 'fixed', TRUE),
    (400070018386, 400070018262, 'Regular', 'fixed', TRUE),
    (400070018387, 400070018263, 'Regular', 'fixed', TRUE),
    (400070018388, 400070018264, 'Regular', 'fixed', TRUE),
    (400070018389, 400070018265, 'Regular', 'fixed', TRUE),
    (400070018390, 400070018266, 'Regular', 'fixed', TRUE),
    (400070018391, 400070018267, 'Regular', 'fixed', TRUE),
    (400070018392, 400070018268, 'Glass', 'fixed', TRUE),
    (400070018393, 400070018268, 'Jar', 'fixed', FALSE),
    (400070018394, 400070018269, 'Glass', 'fixed', TRUE),
    (400070018395, 400070018269, 'Jar', 'fixed', FALSE);

-- Prices (only for variants where a numeric price was actually captured)
INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
VALUES
    (400070018001, 400070018001, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018002, 400070018002, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018003, 400070018003, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018004, 400070018004, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018005, 400070018005, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018006, 400070018006, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018007, 400070018007, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018008, 400070018008, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018009, 400070018009, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018010, 400070018010, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018011, 400070018011, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018012, 400070018012, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018013, 400070018013, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018014, 400070018014, 3800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018015, 400070018015, 4000.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018016, 400070018016, 2500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018017, 400070018017, 6200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018018, 400070018018, 2000.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018019, 400070018019, 1500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018020, 400070018020, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018021, 400070018021, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018022, 400070018022, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018023, 400070018023, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018024, 400070018024, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018025, 400070018025, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018026, 400070018026, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018027, 400070018027, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018028, 400070018028, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018029, 400070018029, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018030, 400070018030, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018031, 400070018031, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018032, 400070018032, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018033, 400070018033, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018034, 400070018034, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018035, 400070018035, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018036, 400070018036, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018037, 400070018037, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018038, 400070018038, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018039, 400070018039, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018040, 400070018040, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018041, 400070018041, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018042, 400070018042, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018043, 400070018043, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018044, 400070018044, 550.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018045, 400070018045, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018046, 400070018046, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018047, 400070018047, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018048, 400070018048, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018049, 400070018049, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018050, 400070018050, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018051, 400070018051, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018052, 400070018052, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018053, 400070018053, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018054, 400070018054, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018055, 400070018055, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018056, 400070018056, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018057, 400070018057, 550.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018058, 400070018058, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018059, 400070018059, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018060, 400070018060, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018061, 400070018061, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018062, 400070018062, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018063, 400070018063, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018064, 400070018064, 450.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018065, 400070018065, 450.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018066, 400070018066, 450.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018067, 400070018067, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018068, 400070018068, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018069, 400070018069, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018070, 400070018070, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018071, 400070018071, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018072, 400070018072, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018073, 400070018073, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018074, 400070018074, 1300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018075, 400070018075, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018076, 400070018076, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018077, 400070018077, 730.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018078, 400070018078, 1350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018079, 400070018079, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018080, 400070018080, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018081, 400070018081, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018082, 400070018082, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018083, 400070018083, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018084, 400070018084, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018085, 400070018085, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018086, 400070018086, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018087, 400070018087, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018088, 400070018088, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018089, 400070018089, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018090, 400070018090, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018091, 400070018091, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018092, 400070018092, 1300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018093, 400070018093, 450.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018094, 400070018094, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018095, 400070018095, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018096, 400070018096, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018097, 400070018097, 375.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018098, 400070018098, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018099, 400070018099, 375.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018100, 400070018100, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018101, 400070018101, 375.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018102, 400070018102, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018103, 400070018103, 375.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018104, 400070018104, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018105, 400070018105, 375.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018106, 400070018106, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018107, 400070018107, 1600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018108, 400070018108, 1700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018109, 400070018109, 1600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018110, 400070018110, 1600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018111, 400070018111, 1700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018112, 400070018112, 1700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018113, 400070018113, 1700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018114, 400070018114, 1700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018115, 400070018115, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018116, 400070018116, 1300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018117, 400070018117, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018118, 400070018118, 1300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018119, 400070018119, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018120, 400070018120, 1300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018121, 400070018121, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018122, 400070018122, 1300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018123, 400070018123, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018124, 400070018124, 1300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018125, 400070018125, 550.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018126, 400070018126, 1050.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018127, 400070018127, 2000.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018128, 400070018128, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018129, 400070018129, 1100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018130, 400070018130, 2100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018131, 400070018131, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018132, 400070018132, 1100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018133, 400070018133, 2000.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018134, 400070018134, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018135, 400070018135, 1100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018136, 400070018136, 2100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018137, 400070018137, 1150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018138, 400070018138, 2200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018139, 400070018139, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018140, 400070018140, 1100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018141, 400070018141, 2100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018142, 400070018142, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018143, 400070018143, 1100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018144, 400070018144, 2000.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018145, 400070018145, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018146, 400070018146, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018147, 400070018147, 2100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018148, 400070018148, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018149, 400070018149, 1100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018150, 400070018150, 2000.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018151, 400070018151, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018152, 400070018152, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018153, 400070018153, 2100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018154, 400070018154, 2500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018155, 400070018155, 2500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018156, 400070018156, 2500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018157, 400070018157, 2500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018158, 400070018158, 2600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018159, 400070018159, 2500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018160, 400070018160, 2500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018161, 400070018161, 2300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018162, 400070018162, 2600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018163, 400070018163, 2600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018164, 400070018164, 2600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018165, 400070018165, 2600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018166, 400070018166, 450.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018167, 400070018167, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018168, 400070018168, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018169, 400070018169, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018170, 400070018170, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018171, 400070018171, 1400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018172, 400070018172, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018173, 400070018173, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018174, 400070018174, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018175, 400070018175, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018176, 400070018176, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018177, 400070018177, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018178, 400070018178, 1300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018179, 400070018179, 450.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018180, 400070018180, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018181, 400070018181, 1400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018182, 400070018182, 1500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018183, 400070018183, 1400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018184, 400070018184, 450.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018185, 400070018185, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018186, 400070018186, 1400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018187, 400070018187, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018188, 400070018188, 1400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018189, 400070018189, 1300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018190, 400070018190, 800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018191, 400070018191, 1500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018192, 400070018192, 800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018193, 400070018193, 1500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018194, 400070018194, 800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018195, 400070018195, 1500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018196, 400070018196, 800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018197, 400070018197, 1500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018198, 400070018198, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018199, 400070018199, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018200, 400070018200, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018201, 400070018201, 450.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018202, 400070018202, 800.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018203, 400070018203, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018204, 400070018204, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018205, 400070018205, 900.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018206, 400070018206, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018207, 400070018207, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018208, 400070018208, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018209, 400070018209, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018210, 400070018210, 650.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018211, 400070018211, 1200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018212, 400070018212, 4200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018213, 400070018213, 3200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018214, 400070018214, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018215, 400070018215, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018216, 400070018216, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018217, 400070018217, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018218, 400070018218, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018219, 400070018219, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018220, 400070018220, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018221, 400070018221, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018222, 400070018222, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018223, 400070018223, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018224, 400070018224, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018225, 400070018225, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018226, 400070018226, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018227, 400070018227, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018228, 400070018228, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018229, 400070018229, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018230, 400070018230, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018231, 400070018231, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018232, 400070018232, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018233, 400070018233, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018234, 400070018234, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018235, 400070018235, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018236, 400070018236, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018237, 400070018237, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018238, 400070018238, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018239, 400070018239, 1100.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018240, 400070018240, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018241, 400070018241, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018242, 400070018242, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018243, 400070018243, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018244, 400070018244, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018245, 400070018245, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018246, 400070018246, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018247, 400070018247, 700.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018248, 400070018248, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018249, 400070018249, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018250, 400070018250, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018251, 400070018251, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018252, 400070018252, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018253, 400070018253, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018254, 400070018254, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018255, 400070018255, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018256, 400070018256, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018257, 400070018257, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018258, 400070018258, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018259, 400070018259, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018260, 400070018260, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018261, 400070018261, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018262, 400070018262, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018263, 400070018263, 900.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018264, 400070018264, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018265, 400070018265, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018266, 400070018266, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018267, 400070018267, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018268, 400070018268, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018269, 400070018269, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018270, 400070018270, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018271, 400070018271, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018272, 400070018272, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018273, 400070018273, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018274, 400070018274, 750.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018275, 400070018275, 2600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018276, 400070018276, 2600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018277, 400070018277, 2600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018278, 400070018282, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018279, 400070018283, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018280, 400070018284, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018281, 400070018285, 450.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018282, 400070018286, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018283, 400070018287, 450.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018284, 400070018288, 450.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018285, 400070018289, 600.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018286, 400070018290, 900.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018287, 400070018291, 1350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018288, 400070018293, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018289, 400070018294, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018290, 400070018295, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018291, 400070018296, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018292, 400070018297, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018293, 400070018298, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018294, 400070018299, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018295, 400070018300, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018296, 400070018301, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018297, 400070018302, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018298, 400070018303, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018299, 400070018304, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018300, 400070018305, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018301, 400070018306, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018302, 400070018307, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018303, 400070018308, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018304, 400070018309, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018305, 400070018310, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018306, 400070018311, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018307, 400070018312, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018308, 400070018313, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018309, 400070018314, 500.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018310, 400070018315, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018311, 400070018316, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018312, 400070018317, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018313, 400070018318, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018314, 400070018319, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018315, 400070018320, 480.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018316, 400070018321, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018317, 400070018322, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018318, 400070018323, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018319, 400070018324, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018320, 400070018325, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018321, 400070018326, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018322, 400070018327, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018323, 400070018328, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018324, 400070018329, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018325, 400070018330, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018326, 400070018331, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018327, 400070018332, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018328, 400070018333, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018329, 400070018334, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018330, 400070018335, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018331, 400070018336, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018332, 400070018337, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018333, 400070018338, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018334, 400070018339, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018335, 400070018340, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018336, 400070018341, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018337, 400070018342, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018338, 400070018343, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018339, 400070018344, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018340, 400070018345, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018341, 400070018346, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018342, 400070018347, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018343, 400070018348, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018344, 400070018349, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018345, 400070018350, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018346, 400070018351, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018347, 400070018352, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018348, 400070018353, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018349, 400070018354, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018350, 400070018355, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018351, 400070018356, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018352, 400070018357, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018353, 400070018358, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018354, 400070018359, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018355, 400070018360, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018356, 400070018361, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018357, 400070018362, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018358, 400070018363, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018359, 400070018364, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018360, 400070018365, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018361, 400070018366, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018362, 400070018367, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018363, 400070018368, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018364, 400070018369, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018365, 400070018370, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018366, 400070018371, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018367, 400070018372, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018368, 400070018373, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018369, 400070018374, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018370, 400070018375, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018371, 400070018376, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018372, 400070018377, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018373, 400070018378, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018374, 400070018379, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018375, 400070018380, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018376, 400070018381, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018377, 400070018382, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018378, 400070018383, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018379, 400070018384, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018380, 400070018385, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018381, 400070018386, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018382, 400070018387, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018383, 400070018388, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018384, 400070018389, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018385, 400070018390, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018386, 400070018391, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018387, 400070018392, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018388, 400070018393, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018389, 400070018394, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified'),
    (400070018390, 400070018395, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), 400070018, 'unverified');

-- Price source (price-specific confidence, tracked separately from item confidence)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
VALUES
    (400070018001, 400070018, :extraction_batch_id, 0.95),
    (400070018002, 400070018, :extraction_batch_id, 0.95),
    (400070018003, 400070018, :extraction_batch_id, 0.95),
    (400070018004, 400070018, :extraction_batch_id, 0.95),
    (400070018005, 400070018, :extraction_batch_id, 0.95),
    (400070018006, 400070018, :extraction_batch_id, 0.95),
    (400070018007, 400070018, :extraction_batch_id, 0.95),
    (400070018008, 400070018, :extraction_batch_id, 0.95),
    (400070018009, 400070018, :extraction_batch_id, 0.95),
    (400070018010, 400070018, :extraction_batch_id, 0.95),
    (400070018011, 400070018, :extraction_batch_id, 0.95),
    (400070018012, 400070018, :extraction_batch_id, 0.95),
    (400070018013, 400070018, :extraction_batch_id, 0.95),
    (400070018014, 400070018, :extraction_batch_id, 0.95),
    (400070018015, 400070018, :extraction_batch_id, 0.95),
    (400070018016, 400070018, :extraction_batch_id, 0.95),
    (400070018017, 400070018, :extraction_batch_id, 0.95),
    (400070018018, 400070018, :extraction_batch_id, 0.95),
    (400070018019, 400070018, :extraction_batch_id, 0.95),
    (400070018020, 400070018, :extraction_batch_id, 0.95),
    (400070018021, 400070018, :extraction_batch_id, 0.95),
    (400070018022, 400070018, :extraction_batch_id, 0.95),
    (400070018023, 400070018, :extraction_batch_id, 0.95),
    (400070018024, 400070018, :extraction_batch_id, 0.95),
    (400070018025, 400070018, :extraction_batch_id, 0.95),
    (400070018026, 400070018, :extraction_batch_id, 0.95),
    (400070018027, 400070018, :extraction_batch_id, 0.95),
    (400070018028, 400070018, :extraction_batch_id, 0.95),
    (400070018029, 400070018, :extraction_batch_id, 0.95),
    (400070018030, 400070018, :extraction_batch_id, 0.95),
    (400070018031, 400070018, :extraction_batch_id, 0.95),
    (400070018032, 400070018, :extraction_batch_id, 0.95),
    (400070018033, 400070018, :extraction_batch_id, 0.95),
    (400070018034, 400070018, :extraction_batch_id, 0.95),
    (400070018035, 400070018, :extraction_batch_id, 0.95),
    (400070018036, 400070018, :extraction_batch_id, 0.95),
    (400070018037, 400070018, :extraction_batch_id, 0.95),
    (400070018038, 400070018, :extraction_batch_id, 0.95),
    (400070018039, 400070018, :extraction_batch_id, 0.95),
    (400070018040, 400070018, :extraction_batch_id, 0.95),
    (400070018041, 400070018, :extraction_batch_id, 0.95),
    (400070018042, 400070018, :extraction_batch_id, 0.95),
    (400070018043, 400070018, :extraction_batch_id, 0.95),
    (400070018044, 400070018, :extraction_batch_id, 0.95),
    (400070018045, 400070018, :extraction_batch_id, 0.95),
    (400070018046, 400070018, :extraction_batch_id, 0.95),
    (400070018047, 400070018, :extraction_batch_id, 0.95),
    (400070018048, 400070018, :extraction_batch_id, 0.95),
    (400070018049, 400070018, :extraction_batch_id, 0.95),
    (400070018050, 400070018, :extraction_batch_id, 0.95),
    (400070018051, 400070018, :extraction_batch_id, 0.95),
    (400070018052, 400070018, :extraction_batch_id, 0.95),
    (400070018053, 400070018, :extraction_batch_id, 0.95),
    (400070018054, 400070018, :extraction_batch_id, 0.95),
    (400070018055, 400070018, :extraction_batch_id, 0.95),
    (400070018056, 400070018, :extraction_batch_id, 0.95),
    (400070018057, 400070018, :extraction_batch_id, 0.95),
    (400070018058, 400070018, :extraction_batch_id, 0.95),
    (400070018059, 400070018, :extraction_batch_id, 0.95),
    (400070018060, 400070018, :extraction_batch_id, 0.95),
    (400070018061, 400070018, :extraction_batch_id, 0.95),
    (400070018062, 400070018, :extraction_batch_id, 0.95),
    (400070018063, 400070018, :extraction_batch_id, 0.95),
    (400070018064, 400070018, :extraction_batch_id, 0.95),
    (400070018065, 400070018, :extraction_batch_id, 0.95),
    (400070018066, 400070018, :extraction_batch_id, 0.95),
    (400070018067, 400070018, :extraction_batch_id, 0.95),
    (400070018068, 400070018, :extraction_batch_id, 0.95),
    (400070018069, 400070018, :extraction_batch_id, 0.95),
    (400070018070, 400070018, :extraction_batch_id, 0.95),
    (400070018071, 400070018, :extraction_batch_id, 0.95),
    (400070018072, 400070018, :extraction_batch_id, 0.95),
    (400070018073, 400070018, :extraction_batch_id, 0.95),
    (400070018074, 400070018, :extraction_batch_id, 0.95),
    (400070018075, 400070018, :extraction_batch_id, 0.95),
    (400070018076, 400070018, :extraction_batch_id, 0.95),
    (400070018077, 400070018, :extraction_batch_id, 0.95),
    (400070018078, 400070018, :extraction_batch_id, 0.95),
    (400070018079, 400070018, :extraction_batch_id, 0.95),
    (400070018080, 400070018, :extraction_batch_id, 0.95),
    (400070018081, 400070018, :extraction_batch_id, 0.95),
    (400070018082, 400070018, :extraction_batch_id, 0.95),
    (400070018083, 400070018, :extraction_batch_id, 0.95),
    (400070018084, 400070018, :extraction_batch_id, 0.95),
    (400070018085, 400070018, :extraction_batch_id, 0.95),
    (400070018086, 400070018, :extraction_batch_id, 0.95),
    (400070018087, 400070018, :extraction_batch_id, 0.95),
    (400070018088, 400070018, :extraction_batch_id, 0.95),
    (400070018089, 400070018, :extraction_batch_id, 0.95),
    (400070018090, 400070018, :extraction_batch_id, 0.95),
    (400070018091, 400070018, :extraction_batch_id, 0.95),
    (400070018092, 400070018, :extraction_batch_id, 0.95),
    (400070018093, 400070018, :extraction_batch_id, 0.95),
    (400070018094, 400070018, :extraction_batch_id, 0.95),
    (400070018095, 400070018, :extraction_batch_id, 0.95),
    (400070018096, 400070018, :extraction_batch_id, 0.95),
    (400070018097, 400070018, :extraction_batch_id, 0.95),
    (400070018098, 400070018, :extraction_batch_id, 0.95),
    (400070018099, 400070018, :extraction_batch_id, 0.95),
    (400070018100, 400070018, :extraction_batch_id, 0.95),
    (400070018101, 400070018, :extraction_batch_id, 0.95),
    (400070018102, 400070018, :extraction_batch_id, 0.95),
    (400070018103, 400070018, :extraction_batch_id, 0.95),
    (400070018104, 400070018, :extraction_batch_id, 0.95),
    (400070018105, 400070018, :extraction_batch_id, 0.95),
    (400070018106, 400070018, :extraction_batch_id, 0.95),
    (400070018107, 400070018, :extraction_batch_id, 0.95),
    (400070018108, 400070018, :extraction_batch_id, 0.95),
    (400070018109, 400070018, :extraction_batch_id, 0.95),
    (400070018110, 400070018, :extraction_batch_id, 0.95),
    (400070018111, 400070018, :extraction_batch_id, 0.95),
    (400070018112, 400070018, :extraction_batch_id, 0.95),
    (400070018113, 400070018, :extraction_batch_id, 0.95),
    (400070018114, 400070018, :extraction_batch_id, 0.95),
    (400070018115, 400070018, :extraction_batch_id, 0.95),
    (400070018116, 400070018, :extraction_batch_id, 0.95),
    (400070018117, 400070018, :extraction_batch_id, 0.95),
    (400070018118, 400070018, :extraction_batch_id, 0.95),
    (400070018119, 400070018, :extraction_batch_id, 0.95),
    (400070018120, 400070018, :extraction_batch_id, 0.95),
    (400070018121, 400070018, :extraction_batch_id, 0.95),
    (400070018122, 400070018, :extraction_batch_id, 0.95),
    (400070018123, 400070018, :extraction_batch_id, 0.95),
    (400070018124, 400070018, :extraction_batch_id, 0.95),
    (400070018125, 400070018, :extraction_batch_id, 0.95),
    (400070018126, 400070018, :extraction_batch_id, 0.95),
    (400070018127, 400070018, :extraction_batch_id, 0.95),
    (400070018128, 400070018, :extraction_batch_id, 0.95),
    (400070018129, 400070018, :extraction_batch_id, 0.95),
    (400070018130, 400070018, :extraction_batch_id, 0.95),
    (400070018131, 400070018, :extraction_batch_id, 0.95),
    (400070018132, 400070018, :extraction_batch_id, 0.95),
    (400070018133, 400070018, :extraction_batch_id, 0.95),
    (400070018134, 400070018, :extraction_batch_id, 0.95),
    (400070018135, 400070018, :extraction_batch_id, 0.95),
    (400070018136, 400070018, :extraction_batch_id, 0.95),
    (400070018137, 400070018, :extraction_batch_id, 0.95),
    (400070018138, 400070018, :extraction_batch_id, 0.95),
    (400070018139, 400070018, :extraction_batch_id, 0.95),
    (400070018140, 400070018, :extraction_batch_id, 0.95),
    (400070018141, 400070018, :extraction_batch_id, 0.95),
    (400070018142, 400070018, :extraction_batch_id, 0.95),
    (400070018143, 400070018, :extraction_batch_id, 0.95),
    (400070018144, 400070018, :extraction_batch_id, 0.95),
    (400070018145, 400070018, :extraction_batch_id, 0.95),
    (400070018146, 400070018, :extraction_batch_id, 0.95),
    (400070018147, 400070018, :extraction_batch_id, 0.95),
    (400070018148, 400070018, :extraction_batch_id, 0.95),
    (400070018149, 400070018, :extraction_batch_id, 0.95),
    (400070018150, 400070018, :extraction_batch_id, 0.95),
    (400070018151, 400070018, :extraction_batch_id, 0.95),
    (400070018152, 400070018, :extraction_batch_id, 0.95),
    (400070018153, 400070018, :extraction_batch_id, 0.95),
    (400070018154, 400070018, :extraction_batch_id, 0.95),
    (400070018155, 400070018, :extraction_batch_id, 0.95),
    (400070018156, 400070018, :extraction_batch_id, 0.95),
    (400070018157, 400070018, :extraction_batch_id, 0.95),
    (400070018158, 400070018, :extraction_batch_id, 0.95),
    (400070018159, 400070018, :extraction_batch_id, 0.95),
    (400070018160, 400070018, :extraction_batch_id, 0.95),
    (400070018161, 400070018, :extraction_batch_id, 0.95),
    (400070018162, 400070018, :extraction_batch_id, 0.95),
    (400070018163, 400070018, :extraction_batch_id, 0.95),
    (400070018164, 400070018, :extraction_batch_id, 0.95),
    (400070018165, 400070018, :extraction_batch_id, 0.95),
    (400070018166, 400070018, :extraction_batch_id, 0.95),
    (400070018167, 400070018, :extraction_batch_id, 0.95),
    (400070018168, 400070018, :extraction_batch_id, 0.95),
    (400070018169, 400070018, :extraction_batch_id, 0.95),
    (400070018170, 400070018, :extraction_batch_id, 0.95),
    (400070018171, 400070018, :extraction_batch_id, 0.95),
    (400070018172, 400070018, :extraction_batch_id, 0.95),
    (400070018173, 400070018, :extraction_batch_id, 0.95),
    (400070018174, 400070018, :extraction_batch_id, 0.95),
    (400070018175, 400070018, :extraction_batch_id, 0.95),
    (400070018176, 400070018, :extraction_batch_id, 0.95),
    (400070018177, 400070018, :extraction_batch_id, 0.95),
    (400070018178, 400070018, :extraction_batch_id, 0.95),
    (400070018179, 400070018, :extraction_batch_id, 0.95),
    (400070018180, 400070018, :extraction_batch_id, 0.95),
    (400070018181, 400070018, :extraction_batch_id, 0.95),
    (400070018182, 400070018, :extraction_batch_id, 0.95),
    (400070018183, 400070018, :extraction_batch_id, 0.95),
    (400070018184, 400070018, :extraction_batch_id, 0.95),
    (400070018185, 400070018, :extraction_batch_id, 0.95),
    (400070018186, 400070018, :extraction_batch_id, 0.95),
    (400070018187, 400070018, :extraction_batch_id, 0.95),
    (400070018188, 400070018, :extraction_batch_id, 0.95),
    (400070018189, 400070018, :extraction_batch_id, 0.95),
    (400070018190, 400070018, :extraction_batch_id, 0.95),
    (400070018191, 400070018, :extraction_batch_id, 0.95),
    (400070018192, 400070018, :extraction_batch_id, 0.95),
    (400070018193, 400070018, :extraction_batch_id, 0.95),
    (400070018194, 400070018, :extraction_batch_id, 0.95),
    (400070018195, 400070018, :extraction_batch_id, 0.95),
    (400070018196, 400070018, :extraction_batch_id, 0.95),
    (400070018197, 400070018, :extraction_batch_id, 0.95),
    (400070018198, 400070018, :extraction_batch_id, 0.95),
    (400070018199, 400070018, :extraction_batch_id, 0.95),
    (400070018200, 400070018, :extraction_batch_id, 0.95),
    (400070018201, 400070018, :extraction_batch_id, 0.95),
    (400070018202, 400070018, :extraction_batch_id, 0.95),
    (400070018203, 400070018, :extraction_batch_id, 0.95),
    (400070018204, 400070018, :extraction_batch_id, 0.95),
    (400070018205, 400070018, :extraction_batch_id, 0.95),
    (400070018206, 400070018, :extraction_batch_id, 0.95),
    (400070018207, 400070018, :extraction_batch_id, 0.95),
    (400070018208, 400070018, :extraction_batch_id, 0.95),
    (400070018209, 400070018, :extraction_batch_id, 0.95),
    (400070018210, 400070018, :extraction_batch_id, 0.95),
    (400070018211, 400070018, :extraction_batch_id, 0.95),
    (400070018212, 400070018, :extraction_batch_id, 0.95),
    (400070018213, 400070018, :extraction_batch_id, 0.95),
    (400070018214, 400070018, :extraction_batch_id, 0.95),
    (400070018215, 400070018, :extraction_batch_id, 0.95),
    (400070018216, 400070018, :extraction_batch_id, 0.95),
    (400070018217, 400070018, :extraction_batch_id, 0.95),
    (400070018218, 400070018, :extraction_batch_id, 0.95),
    (400070018219, 400070018, :extraction_batch_id, 0.95),
    (400070018220, 400070018, :extraction_batch_id, 0.95),
    (400070018221, 400070018, :extraction_batch_id, 0.95),
    (400070018222, 400070018, :extraction_batch_id, 0.95),
    (400070018223, 400070018, :extraction_batch_id, 0.95),
    (400070018224, 400070018, :extraction_batch_id, 0.95),
    (400070018225, 400070018, :extraction_batch_id, 0.95),
    (400070018226, 400070018, :extraction_batch_id, 0.95),
    (400070018227, 400070018, :extraction_batch_id, 0.95),
    (400070018228, 400070018, :extraction_batch_id, 0.95),
    (400070018229, 400070018, :extraction_batch_id, 0.95),
    (400070018230, 400070018, :extraction_batch_id, 0.95),
    (400070018231, 400070018, :extraction_batch_id, 0.95),
    (400070018232, 400070018, :extraction_batch_id, 0.95),
    (400070018233, 400070018, :extraction_batch_id, 0.95),
    (400070018234, 400070018, :extraction_batch_id, 0.95),
    (400070018235, 400070018, :extraction_batch_id, 0.95),
    (400070018236, 400070018, :extraction_batch_id, 0.95),
    (400070018237, 400070018, :extraction_batch_id, 0.95),
    (400070018238, 400070018, :extraction_batch_id, 0.95),
    (400070018239, 400070018, :extraction_batch_id, 0.95),
    (400070018240, 400070018, :extraction_batch_id, 0.95),
    (400070018241, 400070018, :extraction_batch_id, 0.95),
    (400070018242, 400070018, :extraction_batch_id, 0.95),
    (400070018243, 400070018, :extraction_batch_id, 0.95),
    (400070018244, 400070018, :extraction_batch_id, 0.95),
    (400070018245, 400070018, :extraction_batch_id, 0.95),
    (400070018246, 400070018, :extraction_batch_id, 0.95),
    (400070018247, 400070018, :extraction_batch_id, 0.95),
    (400070018248, 400070018, :extraction_batch_id, 0.95),
    (400070018249, 400070018, :extraction_batch_id, 0.95),
    (400070018250, 400070018, :extraction_batch_id, 0.95),
    (400070018251, 400070018, :extraction_batch_id, 0.95),
    (400070018252, 400070018, :extraction_batch_id, 0.95),
    (400070018253, 400070018, :extraction_batch_id, 0.95),
    (400070018254, 400070018, :extraction_batch_id, 0.95),
    (400070018255, 400070018, :extraction_batch_id, 0.95),
    (400070018256, 400070018, :extraction_batch_id, 0.95),
    (400070018257, 400070018, :extraction_batch_id, 0.95),
    (400070018258, 400070018, :extraction_batch_id, 0.95),
    (400070018259, 400070018, :extraction_batch_id, 0.95),
    (400070018260, 400070018, :extraction_batch_id, 0.95),
    (400070018261, 400070018, :extraction_batch_id, 0.95),
    (400070018262, 400070018, :extraction_batch_id, 0.95),
    (400070018263, 400070018, :extraction_batch_id, 0.95),
    (400070018264, 400070018, :extraction_batch_id, 0.95),
    (400070018265, 400070018, :extraction_batch_id, 0.95),
    (400070018266, 400070018, :extraction_batch_id, 0.95),
    (400070018267, 400070018, :extraction_batch_id, 0.95),
    (400070018268, 400070018, :extraction_batch_id, 0.95),
    (400070018269, 400070018, :extraction_batch_id, 0.95),
    (400070018270, 400070018, :extraction_batch_id, 0.95),
    (400070018271, 400070018, :extraction_batch_id, 0.95),
    (400070018272, 400070018, :extraction_batch_id, 0.95),
    (400070018273, 400070018, :extraction_batch_id, 0.95),
    (400070018274, 400070018, :extraction_batch_id, 0.95),
    (400070018275, 400070018, :extraction_batch_id, 0.95),
    (400070018276, 400070018, :extraction_batch_id, 0.95),
    (400070018277, 400070018, :extraction_batch_id, 0.95),
    (400070018278, 400070018, :extraction_batch_id, 0.95),
    (400070018279, 400070018, :extraction_batch_id, 0.95),
    (400070018280, 400070018, :extraction_batch_id, 0.95),
    (400070018281, 400070018, :extraction_batch_id, 0.95),
    (400070018282, 400070018, :extraction_batch_id, 0.95),
    (400070018283, 400070018, :extraction_batch_id, 0.95),
    (400070018284, 400070018, :extraction_batch_id, 0.95),
    (400070018285, 400070018, :extraction_batch_id, 0.95),
    (400070018286, 400070018, :extraction_batch_id, 0.95),
    (400070018287, 400070018, :extraction_batch_id, 0.95),
    (400070018288, 400070018, :extraction_batch_id, 0.95),
    (400070018289, 400070018, :extraction_batch_id, 0.95),
    (400070018290, 400070018, :extraction_batch_id, 0.95),
    (400070018291, 400070018, :extraction_batch_id, 0.95),
    (400070018292, 400070018, :extraction_batch_id, 0.95),
    (400070018293, 400070018, :extraction_batch_id, 0.95),
    (400070018294, 400070018, :extraction_batch_id, 0.95),
    (400070018295, 400070018, :extraction_batch_id, 0.95),
    (400070018296, 400070018, :extraction_batch_id, 0.95),
    (400070018297, 400070018, :extraction_batch_id, 0.95),
    (400070018298, 400070018, :extraction_batch_id, 0.95),
    (400070018299, 400070018, :extraction_batch_id, 0.95),
    (400070018300, 400070018, :extraction_batch_id, 0.95),
    (400070018301, 400070018, :extraction_batch_id, 0.95),
    (400070018302, 400070018, :extraction_batch_id, 0.95),
    (400070018303, 400070018, :extraction_batch_id, 0.95),
    (400070018304, 400070018, :extraction_batch_id, 0.95),
    (400070018305, 400070018, :extraction_batch_id, 0.95),
    (400070018306, 400070018, :extraction_batch_id, 0.95),
    (400070018307, 400070018, :extraction_batch_id, 0.95),
    (400070018308, 400070018, :extraction_batch_id, 0.95),
    (400070018309, 400070018, :extraction_batch_id, 0.95),
    (400070018310, 400070018, :extraction_batch_id, 0.95),
    (400070018311, 400070018, :extraction_batch_id, 0.95),
    (400070018312, 400070018, :extraction_batch_id, 0.95),
    (400070018313, 400070018, :extraction_batch_id, 0.95),
    (400070018314, 400070018, :extraction_batch_id, 0.95),
    (400070018315, 400070018, :extraction_batch_id, 0.95),
    (400070018316, 400070018, :extraction_batch_id, 0.95),
    (400070018317, 400070018, :extraction_batch_id, 0.95),
    (400070018318, 400070018, :extraction_batch_id, 0.95),
    (400070018319, 400070018, :extraction_batch_id, 0.95),
    (400070018320, 400070018, :extraction_batch_id, 0.95),
    (400070018321, 400070018, :extraction_batch_id, 0.95),
    (400070018322, 400070018, :extraction_batch_id, 0.95),
    (400070018323, 400070018, :extraction_batch_id, 0.95),
    (400070018324, 400070018, :extraction_batch_id, 0.95),
    (400070018325, 400070018, :extraction_batch_id, 0.95),
    (400070018326, 400070018, :extraction_batch_id, 0.95),
    (400070018327, 400070018, :extraction_batch_id, 0.95),
    (400070018328, 400070018, :extraction_batch_id, 0.95),
    (400070018329, 400070018, :extraction_batch_id, 0.95),
    (400070018330, 400070018, :extraction_batch_id, 0.95),
    (400070018331, 400070018, :extraction_batch_id, 0.95),
    (400070018332, 400070018, :extraction_batch_id, 0.95),
    (400070018333, 400070018, :extraction_batch_id, 0.95),
    (400070018334, 400070018, :extraction_batch_id, 0.95),
    (400070018335, 400070018, :extraction_batch_id, 0.95),
    (400070018336, 400070018, :extraction_batch_id, 0.95),
    (400070018337, 400070018, :extraction_batch_id, 0.95),
    (400070018338, 400070018, :extraction_batch_id, 0.95),
    (400070018339, 400070018, :extraction_batch_id, 0.95),
    (400070018340, 400070018, :extraction_batch_id, 0.95),
    (400070018341, 400070018, :extraction_batch_id, 0.95),
    (400070018342, 400070018, :extraction_batch_id, 0.95),
    (400070018343, 400070018, :extraction_batch_id, 0.95),
    (400070018344, 400070018, :extraction_batch_id, 0.95),
    (400070018345, 400070018, :extraction_batch_id, 0.95),
    (400070018346, 400070018, :extraction_batch_id, 0.95),
    (400070018347, 400070018, :extraction_batch_id, 0.95),
    (400070018348, 400070018, :extraction_batch_id, 0.95),
    (400070018349, 400070018, :extraction_batch_id, 0.95),
    (400070018350, 400070018, :extraction_batch_id, 0.95),
    (400070018351, 400070018, :extraction_batch_id, 0.95),
    (400070018352, 400070018, :extraction_batch_id, 0.95),
    (400070018353, 400070018, :extraction_batch_id, 0.95),
    (400070018354, 400070018, :extraction_batch_id, 0.95),
    (400070018355, 400070018, :extraction_batch_id, 0.95),
    (400070018356, 400070018, :extraction_batch_id, 0.95),
    (400070018357, 400070018, :extraction_batch_id, 0.95),
    (400070018358, 400070018, :extraction_batch_id, 0.95),
    (400070018359, 400070018, :extraction_batch_id, 0.95),
    (400070018360, 400070018, :extraction_batch_id, 0.95),
    (400070018361, 400070018, :extraction_batch_id, 0.95),
    (400070018362, 400070018, :extraction_batch_id, 0.95),
    (400070018363, 400070018, :extraction_batch_id, 0.95),
    (400070018364, 400070018, :extraction_batch_id, 0.95),
    (400070018365, 400070018, :extraction_batch_id, 0.95),
    (400070018366, 400070018, :extraction_batch_id, 0.95),
    (400070018367, 400070018, :extraction_batch_id, 0.95),
    (400070018368, 400070018, :extraction_batch_id, 0.95),
    (400070018369, 400070018, :extraction_batch_id, 0.95),
    (400070018370, 400070018, :extraction_batch_id, 0.95),
    (400070018371, 400070018, :extraction_batch_id, 0.95),
    (400070018372, 400070018, :extraction_batch_id, 0.95),
    (400070018373, 400070018, :extraction_batch_id, 0.95),
    (400070018374, 400070018, :extraction_batch_id, 0.95),
    (400070018375, 400070018, :extraction_batch_id, 0.95),
    (400070018376, 400070018, :extraction_batch_id, 0.95),
    (400070018377, 400070018, :extraction_batch_id, 0.95),
    (400070018378, 400070018, :extraction_batch_id, 0.95),
    (400070018379, 400070018, :extraction_batch_id, 0.95),
    (400070018380, 400070018, :extraction_batch_id, 0.95),
    (400070018381, 400070018, :extraction_batch_id, 0.95),
    (400070018382, 400070018, :extraction_batch_id, 0.95),
    (400070018383, 400070018, :extraction_batch_id, 0.95),
    (400070018384, 400070018, :extraction_batch_id, 0.95),
    (400070018385, 400070018, :extraction_batch_id, 0.95),
    (400070018386, 400070018, :extraction_batch_id, 0.95),
    (400070018387, 400070018, :extraction_batch_id, 0.95),
    (400070018388, 400070018, :extraction_batch_id, 0.95),
    (400070018389, 400070018, :extraction_batch_id, 0.95),
    (400070018390, 400070018, :extraction_batch_id, 0.95);

-- Board <-> item mapping
INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence)
VALUES
    (400070018001, 400070018, 400070018001, 400070018001, 400070018001, 1),
    (400070018002, 400070018, 400070018001, 400070018002, 400070018001, 2),
    (400070018003, 400070018, 400070018001, 400070018003, 400070018001, 3),
    (400070018004, 400070018, 400070018001, 400070018004, 400070018001, 4),
    (400070018005, 400070018, 400070018001, 400070018005, 400070018001, 5),
    (400070018006, 400070018, 400070018001, 400070018006, 400070018001, 6),
    (400070018007, 400070018, 400070018001, 400070018007, 400070018002, 1),
    (400070018008, 400070018, 400070018001, 400070018008, 400070018002, 2),
    (400070018009, 400070018, 400070018001, 400070018009, 400070018002, 3),
    (400070018010, 400070018, 400070018001, 400070018010, 400070018002, 4),
    (400070018011, 400070018, 400070018001, 400070018011, 400070018002, 5),
    (400070018012, 400070018, 400070018001, 400070018012, 400070018002, 6),
    (400070018013, 400070018, 400070018001, 400070018013, 400070018003, 1),
    (400070018014, 400070018, 400070018001, 400070018014, 400070018004, 1),
    (400070018015, 400070018, 400070018001, 400070018015, 400070018004, 2),
    (400070018016, 400070018, 400070018001, 400070018016, 400070018004, 3),
    (400070018017, 400070018, 400070018001, 400070018017, 400070018004, 4),
    (400070018018, 400070018, 400070018001, 400070018018, 400070018004, 5),
    (400070018019, 400070018, 400070018001, 400070018019, 400070018004, 6),
    (400070018020, 400070018, 400070018001, 400070018020, 400070018005, 1),
    (400070018021, 400070018, 400070018001, 400070018021, 400070018005, 2),
    (400070018022, 400070018, 400070018001, 400070018022, 400070018005, 3),
    (400070018023, 400070018, 400070018001, 400070018023, 400070018005, 4),
    (400070018024, 400070018, 400070018001, 400070018024, 400070018005, 5),
    (400070018025, 400070018, 400070018001, 400070018025, 400070018005, 6),
    (400070018026, 400070018, 400070018001, 400070018026, 400070018005, 7),
    (400070018027, 400070018, 400070018001, 400070018027, 400070018005, 8),
    (400070018028, 400070018, 400070018001, 400070018028, 400070018005, 9),
    (400070018029, 400070018, 400070018001, 400070018029, 400070018005, 10),
    (400070018030, 400070018, 400070018001, 400070018030, 400070018005, 11),
    (400070018031, 400070018, 400070018001, 400070018031, 400070018005, 12),
    (400070018032, 400070018, 400070018001, 400070018032, 400070018005, 13),
    (400070018033, 400070018, 400070018001, 400070018033, 400070018005, 14),
    (400070018034, 400070018, 400070018001, 400070018034, 400070018005, 15),
    (400070018035, 400070018, 400070018001, 400070018035, 400070018005, 16),
    (400070018036, 400070018, 400070018001, 400070018036, 400070018005, 17),
    (400070018037, 400070018, 400070018001, 400070018037, 400070018005, 18),
    (400070018038, 400070018, 400070018001, 400070018038, 400070018005, 19),
    (400070018039, 400070018, 400070018001, 400070018039, 400070018005, 20),
    (400070018040, 400070018, 400070018001, 400070018040, 400070018005, 21),
    (400070018041, 400070018, 400070018001, 400070018041, 400070018005, 22),
    (400070018042, 400070018, 400070018001, 400070018042, 400070018005, 23),
    (400070018043, 400070018, 400070018001, 400070018043, 400070018005, 24),
    (400070018044, 400070018, 400070018001, 400070018044, 400070018005, 25),
    (400070018045, 400070018, 400070018001, 400070018045, 400070018005, 26),
    (400070018046, 400070018, 400070018001, 400070018046, 400070018005, 27),
    (400070018047, 400070018, 400070018001, 400070018047, 400070018005, 28),
    (400070018048, 400070018, 400070018001, 400070018048, 400070018005, 29),
    (400070018049, 400070018, 400070018001, 400070018049, 400070018006, 1),
    (400070018050, 400070018, 400070018001, 400070018050, 400070018006, 2),
    (400070018051, 400070018, 400070018001, 400070018051, 400070018006, 3),
    (400070018052, 400070018, 400070018001, 400070018052, 400070018006, 4),
    (400070018053, 400070018, 400070018001, 400070018053, 400070018006, 5),
    (400070018054, 400070018, 400070018001, 400070018054, 400070018006, 6),
    (400070018055, 400070018, 400070018001, 400070018055, 400070018006, 7),
    (400070018056, 400070018, 400070018001, 400070018056, 400070018006, 8),
    (400070018057, 400070018, 400070018001, 400070018057, 400070018006, 9),
    (400070018058, 400070018, 400070018001, 400070018058, 400070018006, 10),
    (400070018059, 400070018, 400070018001, 400070018059, 400070018006, 11),
    (400070018060, 400070018, 400070018001, 400070018060, 400070018006, 12),
    (400070018061, 400070018, 400070018001, 400070018061, 400070018006, 13),
    (400070018062, 400070018, 400070018001, 400070018062, 400070018006, 14),
    (400070018063, 400070018, 400070018001, 400070018063, 400070018006, 15),
    (400070018064, 400070018, 400070018001, 400070018064, 400070018006, 16),
    (400070018065, 400070018, 400070018001, 400070018065, 400070018006, 17),
    (400070018066, 400070018, 400070018001, 400070018066, 400070018006, 18),
    (400070018067, 400070018, 400070018001, 400070018067, 400070018006, 19),
    (400070018068, 400070018, 400070018001, 400070018068, 400070018006, 20),
    (400070018069, 400070018, 400070018001, 400070018069, 400070018006, 21),
    (400070018070, 400070018, 400070018001, 400070018070, 400070018006, 22),
    (400070018071, 400070018, 400070018001, 400070018071, 400070018006, 23),
    (400070018072, 400070018, 400070018001, 400070018072, 400070018006, 24),
    (400070018073, 400070018, 400070018001, 400070018073, 400070018006, 25),
    (400070018074, 400070018, 400070018001, 400070018074, 400070018006, 26),
    (400070018075, 400070018, 400070018001, 400070018075, 400070018006, 27),
    (400070018076, 400070018, 400070018001, 400070018076, 400070018006, 28),
    (400070018077, 400070018, 400070018001, 400070018077, 400070018006, 29),
    (400070018078, 400070018, 400070018001, 400070018078, 400070018006, 30),
    (400070018079, 400070018, 400070018001, 400070018079, 400070018006, 31),
    (400070018080, 400070018, 400070018001, 400070018080, 400070018006, 32),
    (400070018081, 400070018, 400070018001, 400070018081, 400070018006, 33),
    (400070018082, 400070018, 400070018001, 400070018082, 400070018006, 34),
    (400070018083, 400070018, 400070018001, 400070018083, 400070018007, 1),
    (400070018084, 400070018, 400070018001, 400070018084, 400070018007, 2),
    (400070018085, 400070018, 400070018001, 400070018085, 400070018007, 3),
    (400070018086, 400070018, 400070018001, 400070018086, 400070018007, 4),
    (400070018087, 400070018, 400070018001, 400070018087, 400070018007, 5),
    (400070018088, 400070018, 400070018001, 400070018088, 400070018007, 6),
    (400070018089, 400070018, 400070018001, 400070018089, 400070018007, 7),
    (400070018090, 400070018, 400070018001, 400070018090, 400070018007, 8),
    (400070018091, 400070018, 400070018001, 400070018091, 400070018007, 9),
    (400070018092, 400070018, 400070018001, 400070018092, 400070018007, 10),
    (400070018093, 400070018, 400070018001, 400070018093, 400070018007, 11),
    (400070018094, 400070018, 400070018001, 400070018094, 400070018007, 12),
    (400070018095, 400070018, 400070018001, 400070018095, 400070018007, 13),
    (400070018096, 400070018, 400070018001, 400070018096, 400070018007, 14),
    (400070018097, 400070018, 400070018001, 400070018097, 400070018007, 15),
    (400070018098, 400070018, 400070018001, 400070018098, 400070018007, 16),
    (400070018099, 400070018, 400070018001, 400070018099, 400070018007, 17),
    (400070018100, 400070018, 400070018001, 400070018100, 400070018007, 18),
    (400070018101, 400070018, 400070018001, 400070018101, 400070018007, 19),
    (400070018102, 400070018, 400070018001, 400070018102, 400070018007, 20),
    (400070018103, 400070018, 400070018001, 400070018103, 400070018007, 21),
    (400070018104, 400070018, 400070018001, 400070018104, 400070018007, 22),
    (400070018105, 400070018, 400070018001, 400070018105, 400070018008, 1),
    (400070018106, 400070018, 400070018001, 400070018106, 400070018008, 2),
    (400070018107, 400070018, 400070018001, 400070018107, 400070018008, 3),
    (400070018108, 400070018, 400070018001, 400070018108, 400070018008, 4),
    (400070018109, 400070018, 400070018001, 400070018109, 400070018008, 5),
    (400070018110, 400070018, 400070018001, 400070018110, 400070018008, 6),
    (400070018111, 400070018, 400070018001, 400070018111, 400070018008, 7),
    (400070018112, 400070018, 400070018001, 400070018112, 400070018008, 8),
    (400070018113, 400070018, 400070018001, 400070018113, 400070018008, 9),
    (400070018114, 400070018, 400070018001, 400070018114, 400070018008, 10),
    (400070018115, 400070018, 400070018001, 400070018115, 400070018008, 11),
    (400070018116, 400070018, 400070018001, 400070018116, 400070018008, 12),
    (400070018117, 400070018, 400070018001, 400070018117, 400070018008, 13),
    (400070018118, 400070018, 400070018001, 400070018118, 400070018008, 14),
    (400070018119, 400070018, 400070018001, 400070018119, 400070018008, 15),
    (400070018120, 400070018, 400070018001, 400070018120, 400070018008, 16),
    (400070018121, 400070018, 400070018001, 400070018121, 400070018008, 17),
    (400070018122, 400070018, 400070018001, 400070018122, 400070018009, 1),
    (400070018123, 400070018, 400070018001, 400070018123, 400070018009, 2),
    (400070018124, 400070018, 400070018001, 400070018124, 400070018009, 3),
    (400070018125, 400070018, 400070018001, 400070018125, 400070018009, 4),
    (400070018126, 400070018, 400070018001, 400070018126, 400070018010, 1),
    (400070018127, 400070018, 400070018001, 400070018127, 400070018010, 2),
    (400070018128, 400070018, 400070018001, 400070018128, 400070018011, 1),
    (400070018129, 400070018, 400070018001, 400070018129, 400070018011, 2),
    (400070018130, 400070018, 400070018001, 400070018130, 400070018011, 3),
    (400070018131, 400070018, 400070018001, 400070018131, 400070018011, 4),
    (400070018132, 400070018, 400070018001, 400070018132, 400070018011, 5),
    (400070018133, 400070018, 400070018001, 400070018133, 400070018011, 6),
    (400070018134, 400070018, 400070018001, 400070018134, 400070018011, 7),
    (400070018135, 400070018, 400070018001, 400070018135, 400070018011, 8),
    (400070018136, 400070018, 400070018001, 400070018136, 400070018011, 9),
    (400070018137, 400070018, 400070018001, 400070018137, 400070018011, 10),
    (400070018138, 400070018, 400070018001, 400070018138, 400070018011, 11),
    (400070018139, 400070018, 400070018001, 400070018139, 400070018011, 12),
    (400070018140, 400070018, 400070018001, 400070018140, 400070018011, 13),
    (400070018141, 400070018, 400070018001, 400070018141, 400070018011, 14),
    (400070018142, 400070018, 400070018001, 400070018142, 400070018011, 15),
    (400070018143, 400070018, 400070018001, 400070018143, 400070018011, 16),
    (400070018144, 400070018, 400070018001, 400070018144, 400070018011, 17),
    (400070018145, 400070018, 400070018001, 400070018145, 400070018012, 1),
    (400070018146, 400070018, 400070018001, 400070018146, 400070018012, 2),
    (400070018147, 400070018, 400070018001, 400070018147, 400070018012, 3),
    (400070018148, 400070018, 400070018001, 400070018148, 400070018012, 4),
    (400070018149, 400070018, 400070018001, 400070018149, 400070018012, 5),
    (400070018150, 400070018, 400070018001, 400070018150, 400070018012, 6),
    (400070018151, 400070018, 400070018001, 400070018151, 400070018012, 7),
    (400070018152, 400070018, 400070018001, 400070018152, 400070018012, 8),
    (400070018153, 400070018, 400070018001, 400070018153, 400070018012, 9),
    (400070018154, 400070018, 400070018001, 400070018154, 400070018012, 10),
    (400070018155, 400070018, 400070018001, 400070018155, 400070018012, 11),
    (400070018156, 400070018, 400070018001, 400070018156, 400070018012, 12),
    (400070018157, 400070018, 400070018001, 400070018157, 400070018012, 13),
    (400070018158, 400070018, 400070018001, 400070018158, 400070018012, 14),
    (400070018159, 400070018, 400070018001, 400070018159, 400070018012, 15),
    (400070018160, 400070018, 400070018001, 400070018160, 400070018012, 16),
    (400070018161, 400070018, 400070018001, 400070018161, 400070018012, 17),
    (400070018162, 400070018, 400070018001, 400070018162, 400070018012, 18),
    (400070018163, 400070018, 400070018001, 400070018163, 400070018013, 1),
    (400070018164, 400070018, 400070018001, 400070018164, 400070018013, 2),
    (400070018165, 400070018, 400070018001, 400070018165, 400070018013, 3),
    (400070018166, 400070018, 400070018001, 400070018166, 400070018013, 4),
    (400070018167, 400070018, 400070018001, 400070018167, 400070018013, 5),
    (400070018168, 400070018, 400070018001, 400070018168, 400070018013, 6),
    (400070018169, 400070018, 400070018001, 400070018169, 400070018013, 7),
    (400070018170, 400070018, 400070018001, 400070018170, 400070018013, 8),
    (400070018171, 400070018, 400070018001, 400070018171, 400070018013, 9),
    (400070018172, 400070018, 400070018001, 400070018172, 400070018013, 10),
    (400070018173, 400070018, 400070018001, 400070018173, 400070018013, 11),
    (400070018174, 400070018, 400070018001, 400070018174, 400070018013, 12),
    (400070018175, 400070018, 400070018001, 400070018175, 400070018013, 13),
    (400070018176, 400070018, 400070018001, 400070018176, 400070018013, 14),
    (400070018177, 400070018, 400070018001, 400070018177, 400070018013, 15),
    (400070018178, 400070018, 400070018001, 400070018178, 400070018014, 1),
    (400070018179, 400070018, 400070018001, 400070018179, 400070018014, 2),
    (400070018180, 400070018, 400070018001, 400070018180, 400070018014, 3),
    (400070018181, 400070018, 400070018001, 400070018181, 400070018014, 4),
    (400070018182, 400070018, 400070018001, 400070018182, 400070018014, 5),
    (400070018183, 400070018, 400070018001, 400070018183, 400070018014, 6),
    (400070018184, 400070018, 400070018001, 400070018184, 400070018014, 7),
    (400070018185, 400070018, 400070018001, 400070018185, 400070018014, 8),
    (400070018186, 400070018, 400070018001, 400070018186, 400070018014, 9),
    (400070018187, 400070018, 400070018001, 400070018187, 400070018014, 10),
    (400070018188, 400070018, 400070018001, 400070018188, 400070018015, 1),
    (400070018189, 400070018, 400070018001, 400070018189, 400070018015, 2),
    (400070018190, 400070018, 400070018001, 400070018190, 400070018015, 3),
    (400070018191, 400070018, 400070018001, 400070018191, 400070018015, 4),
    (400070018192, 400070018, 400070018001, 400070018192, 400070018015, 5),
    (400070018193, 400070018, 400070018001, 400070018193, 400070018015, 6),
    (400070018194, 400070018, 400070018001, 400070018194, 400070018015, 7),
    (400070018195, 400070018, 400070018001, 400070018195, 400070018015, 8),
    (400070018196, 400070018, 400070018001, 400070018196, 400070018015, 9),
    (400070018197, 400070018, 400070018001, 400070018197, 400070018016, 1),
    (400070018198, 400070018, 400070018001, 400070018198, 400070018016, 2),
    (400070018199, 400070018, 400070018001, 400070018199, 400070018016, 3),
    (400070018200, 400070018, 400070018001, 400070018200, 400070018016, 4),
    (400070018201, 400070018, 400070018001, 400070018201, 400070018017, 1),
    (400070018202, 400070018, 400070018001, 400070018202, 400070018017, 2),
    (400070018203, 400070018, 400070018001, 400070018203, 400070018017, 3),
    (400070018204, 400070018, 400070018001, 400070018204, 400070018017, 4),
    (400070018205, 400070018, 400070018001, 400070018205, 400070018017, 5),
    (400070018206, 400070018, 400070018001, 400070018206, 400070018017, 6),
    (400070018207, 400070018, 400070018001, 400070018207, 400070018017, 7),
    (400070018208, 400070018, 400070018001, 400070018208, 400070018017, 8),
    (400070018209, 400070018, 400070018001, 400070018209, 400070018017, 9),
    (400070018210, 400070018, 400070018001, 400070018210, 400070018017, 10),
    (400070018211, 400070018, 400070018001, 400070018211, 400070018017, 11),
    (400070018212, 400070018, 400070018001, 400070018212, 400070018018, 1),
    (400070018213, 400070018, 400070018001, 400070018213, 400070018018, 2),
    (400070018214, 400070018, 400070018001, 400070018214, 400070018018, 3),
    (400070018215, 400070018, 400070018001, 400070018215, 400070018018, 4),
    (400070018216, 400070018, 400070018001, 400070018216, 400070018018, 5),
    (400070018217, 400070018, 400070018001, 400070018217, 400070018018, 6),
    (400070018218, 400070018, 400070018001, 400070018218, 400070018018, 7),
    (400070018219, 400070018, 400070018001, 400070018219, 400070018018, 8),
    (400070018220, 400070018, 400070018001, 400070018220, 400070018018, 9),
    (400070018221, 400070018, 400070018001, 400070018221, 400070018018, 10),
    (400070018222, 400070018, 400070018001, 400070018222, 400070018018, 11),
    (400070018223, 400070018, 400070018001, 400070018223, 400070018018, 12),
    (400070018224, 400070018, 400070018001, 400070018224, 400070018018, 13),
    (400070018225, 400070018, 400070018001, 400070018225, 400070018018, 14),
    (400070018226, 400070018, 400070018001, 400070018226, 400070018018, 15),
    (400070018227, 400070018, 400070018001, 400070018227, 400070018019, 1),
    (400070018228, 400070018, 400070018001, 400070018228, 400070018019, 2),
    (400070018229, 400070018, 400070018001, 400070018229, 400070018019, 3),
    (400070018230, 400070018, 400070018001, 400070018230, 400070018019, 4),
    (400070018231, 400070018, 400070018001, 400070018231, 400070018019, 5),
    (400070018232, 400070018, 400070018001, 400070018232, 400070018019, 6),
    (400070018233, 400070018, 400070018001, 400070018233, 400070018019, 7),
    (400070018234, 400070018, 400070018001, 400070018234, 400070018019, 8),
    (400070018235, 400070018, 400070018001, 400070018235, 400070018019, 9),
    (400070018236, 400070018, 400070018001, 400070018236, 400070018019, 10),
    (400070018237, 400070018, 400070018001, 400070018237, 400070018019, 11),
    (400070018238, 400070018, 400070018001, 400070018238, 400070018019, 12),
    (400070018239, 400070018, 400070018001, 400070018239, 400070018019, 13),
    (400070018240, 400070018, 400070018001, 400070018240, 400070018019, 14),
    (400070018241, 400070018, 400070018001, 400070018241, 400070018019, 15),
    (400070018242, 400070018, 400070018001, 400070018242, 400070018019, 16),
    (400070018243, 400070018, 400070018001, 400070018243, 400070018019, 17),
    (400070018244, 400070018, 400070018001, 400070018244, 400070018019, 18),
    (400070018245, 400070018, 400070018001, 400070018245, 400070018019, 19),
    (400070018246, 400070018, 400070018001, 400070018246, 400070018019, 20),
    (400070018247, 400070018, 400070018001, 400070018247, 400070018019, 21),
    (400070018248, 400070018, 400070018001, 400070018248, 400070018019, 22),
    (400070018249, 400070018, 400070018001, 400070018249, 400070018019, 23),
    (400070018250, 400070018, 400070018001, 400070018250, 400070018019, 24),
    (400070018251, 400070018, 400070018001, 400070018251, 400070018019, 25),
    (400070018252, 400070018, 400070018001, 400070018252, 400070018020, 1),
    (400070018253, 400070018, 400070018001, 400070018253, 400070018020, 2),
    (400070018254, 400070018, 400070018001, 400070018254, 400070018020, 3),
    (400070018255, 400070018, 400070018001, 400070018255, 400070018020, 4),
    (400070018256, 400070018, 400070018001, 400070018256, 400070018020, 5),
    (400070018257, 400070018, 400070018001, 400070018257, 400070018020, 6),
    (400070018258, 400070018, 400070018001, 400070018258, 400070018020, 7),
    (400070018259, 400070018, 400070018001, 400070018259, 400070018020, 8),
    (400070018260, 400070018, 400070018001, 400070018260, 400070018020, 9),
    (400070018261, 400070018, 400070018001, 400070018261, 400070018020, 10),
    (400070018262, 400070018, 400070018001, 400070018262, 400070018020, 11),
    (400070018263, 400070018, 400070018001, 400070018263, 400070018020, 12),
    (400070018264, 400070018, 400070018001, 400070018264, 400070018021, 1),
    (400070018265, 400070018, 400070018001, 400070018265, 400070018021, 2),
    (400070018266, 400070018, 400070018001, 400070018266, 400070018021, 3),
    (400070018267, 400070018, 400070018001, 400070018267, 400070018021, 4),
    (400070018268, 400070018, 400070018001, 400070018268, 400070018022, 1),
    (400070018269, 400070018, 400070018001, 400070018269, 400070018022, 2);

-- === NEEDS-REVIEW ITEMS ===
-- menu_item_id 400070018007 (Hot & Sour Soup): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018008 (Hot & Sour Soup): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018009 (Clears Soup): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018010 (Clears Soup): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018011 (Manchurian Soup): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018012 (Manchurian Soup): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018019 (Dejaj Al-Qamil (Half), Lolly Tossed, ATC Butter Tossed (Half), Crispy, 4 Pcs Tandoori Roti): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070018122 (Saudi Rice): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070018123 (Turkish Rice): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070018163 (Fish Mandi / Regular): non-numeric price text in source: 'A.P.S.' (market/seasonal price) (confidence 0.5)
-- menu_item_id 400070018164 (Pomfret Tawa Fry - 1 Pcs / Regular): non-numeric price text in source: 'A.P.S.' (market/seasonal price) (confidence 0.5)
-- menu_item_id 400070018165 (Pomfret Deep Fry - 1 Pcs / Regular): non-numeric price text in source: 'A.P.S.' (market/seasonal price) (confidence 0.5)
-- menu_item_id 400070018166 (Surmai Tawa Fry - 1 Pcs / Regular): non-numeric price text in source: 'A.P.S.' (market/seasonal price) (confidence 0.5)
-- menu_item_id 400070018177 (Prawns Platter (3 Person) / Regular): no price captured in source JSON (confidence 0.2)
-- menu_item_id 400070018227 (Chicken Fried Rice): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018228 (Chicken Fried Rice): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018229 (Chi. Schezwan Fried Rice): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018230 (Chi. Schezwan Fried Rice): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018231 (Chi. Burnt Garlic Fried Rice): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018232 (Chi. Burnt Garlic Fried Rice): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018233 (Chi. Singapore Rice): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018234 (Chi. Singapore Rice): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018235 (Chi. Malaysian Rice): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018236 (Chi. Malaysian Rice): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018237 (Chi. Hong Kong Rice): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018238 (Chi. Hong Kong Rice): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018239 (Chi. Chilly Garlic Rice + Gravy): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018240 (Chi. Chilly Garlic Rice + Gravy): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018241 (Chi. Tripple Fried Rice + Gravy): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018242 (Chi. Tripple Fried Rice + Gravy): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018243 (Chi. Manchurian Fried Rice+ Gravy): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018244 (Chi. Manchurian Fried Rice+ Gravy): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018245 (Chi. Burnt Chilly Pot Rice): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018246 (Chi. Burnt Chilly Pot Rice): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018247 (Chicken Dragon Pot Rice): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018248 (Chicken Dragon Pot Rice): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018252 (Chicken Hakka Noodles): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018253 (Chicken Hakka Noodles): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018254 (Chi. Schezwan Hakka Noodles): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018255 (Chi. Schezwan Hakka Noodles): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018256 (Chi. Burnt Garlic Noodles): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018257 (Chi. Burnt Garlic Noodles): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018258 (Chi. Singapore Noodles): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018259 (Chi. Singapore Noodles): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018260 (Chi. Malaysian Noodles): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018261 (Chi. Malaysian Noodles): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018262 (Chi Hong Kong Noodles): veg/non-veg split from source label 'V.' (V.)
-- menu_item_id 400070018263 (Chi Hong Kong Noodles): veg/non-veg split from source label 'N.V.' (N.V.)
-- menu_item_id 400070018264 (CHEESE KUNAFEH): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070018265 (KUNAFEH): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070018266 (OMALI): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070018267 (LEBANESE PUDDING): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070018268 (Lime Mojito): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review
-- menu_item_id 400070018269 (Fruit Champagne): food classification uncertain (no confident keyword or category signal -- needs manual classification); left unset, needs manual review

-- === UNMAPPED / INFORMATIONAL RESTAURANT-LEVEL NOTES ===
-- website from JSON: "www.arabiandastarkhwan.in" -- establishment.website_url column exists; include if the executing schema pass wants it populated (kept as a note here for visibility).
-- delivery note from JSON: "Free home delivery above 1000 within 2 km" -- self-delivery capability/radius/minimum-order has no dedicated schema column combination that captures a distance radius; recorded here only, not inserted as structured data.
-- HALAL: attempted as a restaurant_tag lookup against platform_tag (tag_code='halal') above; if that tag doesn't exist yet in the live database the insert was a no-op -- verify and add the tag if it should exist.
-- 'NO BEEF' page notice: informational assurance text, not a formal dietary tag/column; not inserted anywhere.

COMMIT;