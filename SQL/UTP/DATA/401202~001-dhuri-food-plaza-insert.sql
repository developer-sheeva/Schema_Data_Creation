/* ============================================================================
   KHAUSTAN — RESTAURANT ONBOARDING: Dhuri Food Plaza (Vasai Road West, Palghar)
   Source: Dhuri_Food_Plaza_Parcel_Menu.docx
   Target: KhaustanRestaurantMenu database.
   Rewrite #3 of this script -- see fixes below.

   FIXES IN THIS REWRITE:
   1) Bug: menu_item_price_source doesn't have a verification_status_code
      column (checked directly against the DDL just now) -- the previous
      version wrote one anyway. Removed; that table only has
      (price_id, source_id, extraction_batch_id, confidence).
   2) ID scheme replaced completely, per this request's explicit spec:
      establishment_id and restaurant_id are both hardcoded to 401202001
      (literal, not derived). Every other table's ids are that same
      9-digit restaurant id with a 3-digit per-table row counter appended
      (e.g. first menu_category = 401202001001, second = 401202001002, ...),
      restarting at 001 independently in each table -- no table-code digit
      in the middle anymore, and no runtime SQL arithmetic anywhere (that's
      what caused the previous int4-overflow bug), just precomputed literals.
      canonical_dish/canonical_dish_name are the one exception, still on
      their own separate sequence -- see the note further down.
   3) menu_category, menu_board, menu_board_category and menu_board_item
      are now populated (the previous version deferred to raw_category_text
      alone, which the methodology document allows as an option but this
      request asks for the fuller structure instead). menu_item.raw_category_text
      is now NULL and menu_category_id is set instead, matching the schema's
      own documented convention ("NULL once menu_category_id is curated").
   4) Nothing added to any lookup table (protein_type, service_mode,
      delivery_provider, platform_tag) -- confirmed already true of the
      previous version too. Every reference below uses ids already
      confirmed to exist: protein_type CHICKEN=900001, MUTTON=900002,
      SEAFOOD=900003, EGG=920009; service_mode Dine-in=1, Takeaway=3,
      Delivery=4, Bulk/Catering=5; delivery_provider ZOMATO=1, SWIGGY=2.

   FLAGGED, NOT APPLIED: the request's menu_category / menu_board_category /
   menu_board_item instruction says restaurant_id = 400070002 -- but
   establishment_id/restaurant_id earlier in the same request are
   401202001, and every one of those three tables has a composite foreign
   key back to restaurant(restaurant_id) / menu_board(restaurant_id, ...) /
   menu_category(restaurant_id, ...) that requires the SAME restaurant_id
   throughout. 400070002 is Hotel Sadanand/Rangoon Zaika's PIN block, not
   this restaurant's (401202) -- using it here would point Dhuri Food
   Plaza's categories at a restaurant this script never creates, and the
   composite FKs would reject it outright even if that weren't a
   correctness problem in its own right. Treated as a copy/paste slip;
   401202001 is used consistently instead. Say the word if 400070002 was
   actually intended and I'll rework it.
   ============================================================================ */

-- pgAdmin4 / any plain SQL client: connect to "KhaustanRestaurantMenu" directly
-- before running this (no \connect meta-command used -- not valid outside psql).
--\connect "KhaustanRestaurantMenu"

BEGIN;

-- Separate sequence for the genuinely cross-restaurant canonical_dish tables only
-- (a restaurant-id-based id isn't safe here -- see the header note above on why).
DO $do$
DECLARE v_max BIGINT;
BEGIN
  SELECT GREATEST(
    COALESCE((SELECT MAX(canonical_dish_id) FROM canonical_dish), 0),
    COALESCE((SELECT MAX(canonical_dish_name_id) FROM canonical_dish_name), 0)
  ) INTO v_max;
  EXECUTE format('CREATE SEQUENCE IF NOT EXISTS dhuri_canonical_seq START WITH %s', v_max + 1);
END $do$;

-- Re-run guard: stop if this exact docx has already been fully loaded for this restaurant.
DO $do$
DECLARE v_already_done BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM menu_extraction_batch
    WHERE restaurant_id = 401202001
      AND source_id IN (SELECT source_id FROM source_record WHERE source_uri = 'Dhuri_Food_Plaza_Parcel_Menu.docx')
      AND status_code = 'completed'
  ) INTO v_already_done;
  IF v_already_done THEN
    RAISE EXCEPTION 'Dhuri_Food_Plaza_Parcel_Menu.docx already fully loaded for restaurant 401202001 -- aborting to avoid duplicate menu items.';
  END IF;
END $do$;

-- Establishment + restaurant, identify-or-create (ids hardcoded per this request).
DO $do$
DECLARE
  v_establishment_id BIGINT;
  v_restaurant_id    BIGINT;
BEGIN
  SELECT establishment_id INTO v_establishment_id FROM establishment
  WHERE normalized_name = 'dhuri food plaza' AND postal_code = '401202';
  IF NOT FOUND THEN
    v_establishment_id := 401202001;
    INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, address_line2, locality, city, state, country_code, postal_code, latitude, longitude)
    VALUES (v_establishment_id, 'Dhuri Food Plaza', 'dhuri food plaza', 'Near Railway Station', 'Opposite Railway Station',
            'Vasai (West)', 'Vasai-Virar', 'Maharashtra', 'IN', '401202', 19.383563313276234, 72.83081983796838);
  END IF;

  SELECT restaurant_id INTO v_restaurant_id FROM restaurant
  WHERE establishment_id = v_establishment_id AND display_name = 'Dhuri Food Plaza';
  IF NOT FOUND THEN
    v_restaurant_id := 401202001;
    INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name, description, has_bar, bar_license_type)
    VALUES (v_restaurant_id, v_establishment_id, 'Dhuri Food Plaza', 'dhuri food plaza', 'Multi-concept venue: fast food, veg & non-veg à la carte, restaurant & bar, fine dine & banquet, and terrace party space. Undertakes birthday, engagement, kitty-party, get-together and corporate events.', TRUE, 'full_bar');
  END IF;
END $do$;

INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary, is_personal_number)
VALUES ('401202001001', 401202001, '9689892879', TRUE, FALSE),
       ('401202001002', 401202001, '8466687799', FALSE, FALSE);

-- Parcel-availability hours, both slots, all 7 days (see header note on confidence).
INSERT INTO restaurant_hours (restaurant_hours_id, restaurant_id, day_of_week, slot_sequence, opens_at, closes_at)
VALUES
    (401202001001, 401202001, 1, 1, '11:00'::time, '16:00'::time),
    (401202001002, 401202001, 1, 2, '18:00'::time, '23:00'::time),
    (401202001003, 401202001, 2, 1, '11:00'::time, '16:00'::time),
    (401202001004, 401202001, 2, 2, '18:00'::time, '23:00'::time),
    (401202001005, 401202001, 3, 1, '11:00'::time, '16:00'::time),
    (401202001006, 401202001, 3, 2, '18:00'::time, '23:00'::time),
    (401202001007, 401202001, 4, 1, '11:00'::time, '16:00'::time),
    (401202001008, 401202001, 4, 2, '18:00'::time, '23:00'::time),
    (401202001009, 401202001, 5, 1, '11:00'::time, '16:00'::time),
    (401202001010, 401202001, 5, 2, '18:00'::time, '23:00'::time),
    (401202001011, 401202001, 6, 1, '11:00'::time, '16:00'::time),
    (401202001012, 401202001, 6, 2, '18:00'::time, '23:00'::time),
    (401202001013, 401202001, 7, 1, '11:00'::time, '16:00'::time),
    (401202001014, 401202001, 7, 2, '18:00'::time, '23:00'::time);

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (401202001001, 'ai_menu_extraction', 'Dhuri_Food_Plaza_Parcel_Menu.docx');

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
VALUES (401202001001, 401202001, 401202001001, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed');

-- Self-delivery (phone orders): min order Rs 300, per the parcel-menu panel.
INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available, self_delivery_min_order_amount, currency_code)
VALUES (401202001, TRUE, TRUE, 300.00, 'INR');

-- Zomato + Swiggy: docx explicitly states both are verified delivery partners
-- online, even though no logo appears on the physical menu.
INSERT INTO restaurant_delivery_provider (restaurant_delivery_provider_id, restaurant_id, delivery_provider_id, delivery_charge_type_code, is_available, effective_from)
VALUES ('401202001001', 401202001, 1, 'fixed', TRUE, (clock_timestamp() AT TIME ZONE 'UTC')),
       ('401202001002', 401202001, 2, 'fixed', TRUE, (clock_timestamp() AT TIME ZONE 'UTC'));

INSERT INTO restaurant_service_mode (restaurant_id, service_mode_id, notes)
VALUES (401202001, 1, NULL),
       (401202001, 3, 'Menu is headed "PARCEL MENU"'),
       (401202001, 4, 'Zomato/Swiggy verified online; min order Rs 300 for direct/phone orders'),
       (401202001, 5, 'Undertakes birthday, engagement, kitty-party, get-together and corporate events; terrace party space');

INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code)
VALUES (401202001001, 401202001, 'Dhuri Food Plaza Menu', 'a_la_carte');

INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence)
VALUES
    (401202001001, 401202001, 'Soups (Veg)', 1),
    (401202001002, 401202001, 'Soups (Non Veg)', 2),
    (401202001003, 401202001, 'Starters (Veg)', 3),
    (401202001004, 401202001, 'Starters (Non-Veg)', 4),
    (401202001005, 401202001, 'Rice & Noodles (Veg)', 5),
    (401202001006, 401202001, 'Rice & Noodles (Non Veg)', 6),
    (401202001007, 401202001, 'Tandoori Starters', 7),
    (401202001008, 401202001, 'Main Course (Veg)', 8),
    (401202001009, 401202001, 'Paneer', 9),
    (401202001010, 401202001, 'Main Course (Non Veg)', 10),
    (401202001011, 401202001, 'Dal', 11),
    (401202001012, 401202001, 'Sea Food', 12),
    (401202001013, 401202001, 'Indian Bread', 13),
    (401202001014, 401202001, 'Salad / Raita', 14),
    (401202001015, 401202001, 'Biryani (1 Kg)', 15),
    (401202001016, 401202001, 'Rice (Veg)', 16),
    (401202001017, 401202001, 'Rice (Non Veg)', 17),
    (401202001018, 401202001, 'Sandwich & Pizza', 18);

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
VALUES
    (401202001, 401202001001, 401202001001, 1),
    (401202001, 401202001001, 401202001002, 2),
    (401202001, 401202001001, 401202001003, 3),
    (401202001, 401202001001, 401202001004, 4),
    (401202001, 401202001001, 401202001005, 5),
    (401202001, 401202001001, 401202001006, 6),
    (401202001, 401202001001, 401202001007, 7),
    (401202001, 401202001001, 401202001008, 8),
    (401202001, 401202001001, 401202001009, 9),
    (401202001, 401202001001, 401202001010, 10),
    (401202001, 401202001001, 401202001011, 11),
    (401202001, 401202001001, 401202001012, 12),
    (401202001, 401202001001, 401202001013, 13),
    (401202001, 401202001001, 401202001014, 14),
    (401202001, 401202001001, 401202001015, 15),
    (401202001, 401202001001, 401202001016, 16),
    (401202001, 401202001001, 401202001017, 17),
    (401202001, 401202001001, 401202001018, 18);

-- ----------------------------------------------------------------------------
-- Canonical dishes: 247 distinct names across 251 menu lines
-- (identify-or-create by normalized_name; no unique constraint on canonical_dish,
-- so NOT EXISTS is the correct guard, not ON CONFLICT -- see the methodology's Step 5 table).
-- ----------------------------------------------------------------------------
WITH new_dish_97400269 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Manchow', 'veg manchow'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg manchow')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Manchow', 'veg manchow', 'primary'
FROM new_dish_97400269;

WITH new_dish_35816431 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Clear', 'veg clear'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg clear')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Clear', 'veg clear', 'primary'
FROM new_dish_35816431;

WITH new_dish_8535277 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Hot & Sour', 'veg hot & sour'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg hot & sour')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Hot & Sour', 'veg hot & sour', 'primary'
FROM new_dish_8535277;

WITH new_dish_31968273 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Noodles', 'veg noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Noodles', 'veg noodles', 'primary'
FROM new_dish_31968273;

WITH new_dish_96283123 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Sweet Corn', 'veg sweet corn'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg sweet corn')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Sweet Corn', 'veg sweet corn', 'primary'
FROM new_dish_96283123;

WITH new_dish_68726910 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Lemon Coriander', 'lemon coriander'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'lemon coriander')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Lemon Coriander', 'lemon coriander', 'primary'
FROM new_dish_68726910;

WITH new_dish_1927084 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Cream Of Tomato', 'cream of tomato'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cream of tomato')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Cream Of Tomato', 'cream of tomato', 'primary'
FROM new_dish_1927084;

WITH new_dish_7677711 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Cream Of Mushroom', 'cream of mushroom'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cream of mushroom')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Cream Of Mushroom', 'cream of mushroom', 'primary'
FROM new_dish_7677711;

WITH new_dish_42332184 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Cream Of Palak', 'cream of palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cream of palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Cream Of Palak', 'cream of palak', 'primary'
FROM new_dish_42332184;

WITH new_dish_60999255 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Manchow', 'chicken manchow'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchow')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Manchow', 'chicken manchow', 'primary'
FROM new_dish_60999255;

WITH new_dish_50832780 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Clear', 'chicken clear'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken clear')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Clear', 'chicken clear', 'primary'
FROM new_dish_50832780;

WITH new_dish_61577925 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Hot & Sour', 'chicken hot & sour'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hot & sour')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Hot & Sour', 'chicken hot & sour', 'primary'
FROM new_dish_61577925;

WITH new_dish_59961771 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Sweet Corn', 'chicken sweet corn'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken sweet corn')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Sweet Corn', 'chicken sweet corn', 'primary'
FROM new_dish_59961771;

WITH new_dish_23829247 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Lemon Coriander', 'chicken lemon coriander'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lemon coriander')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Lemon Coriander', 'chicken lemon coriander', 'primary'
FROM new_dish_23829247;

WITH new_dish_93635069 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Lung Fung', 'chicken lung fung'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lung fung')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Lung Fung', 'chicken lung fung', 'primary'
FROM new_dish_93635069;

WITH new_dish_67876568 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Shorba', 'chicken shorba'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken shorba')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Shorba', 'chicken shorba', 'primary'
FROM new_dish_67876568;

WITH new_dish_41252918 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mutton Paya', 'mutton paya'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton paya')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mutton Paya', 'mutton paya', 'primary'
FROM new_dish_41252918;

WITH new_dish_66446191 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Manchurian', 'veg manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Manchurian', 'veg manchurian', 'primary'
FROM new_dish_66446191;

WITH new_dish_62625730 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Chilly', 'veg chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Chilly', 'veg chilly', 'primary'
FROM new_dish_62625730;

WITH new_dish_74186462 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Crispy', 'veg crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Crispy', 'veg crispy', 'primary'
FROM new_dish_74186462;

WITH new_dish_51772005 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Schezwan', 'veg schezwan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg schezwan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Schezwan', 'veg schezwan', 'primary'
FROM new_dish_51772005;

WITH new_dish_97504379 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Spring Roll', 'veg spring roll'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg spring roll')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Spring Roll', 'veg spring roll', 'primary'
FROM new_dish_97504379;

WITH new_dish_70361310 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Malaysian', 'veg malaysian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg malaysian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Malaysian', 'veg malaysian', 'primary'
FROM new_dish_70361310;

WITH new_dish_96695128 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Shanghai Potato', 'shanghai potato'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'shanghai potato')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Shanghai Potato', 'shanghai potato', 'primary'
FROM new_dish_96695128;

WITH new_dish_10747696 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chilly Garlic Potato', 'chilly garlic potato'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chilly garlic potato')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chilly Garlic Potato', 'chilly garlic potato', 'primary'
FROM new_dish_10747696;

WITH new_dish_79365340 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Crispy', 'paneer crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Crispy', 'paneer crispy', 'primary'
FROM new_dish_79365340;

WITH new_dish_20430676 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Manchurian', 'paneer manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Manchurian', 'paneer manchurian', 'primary'
FROM new_dish_20430676;

WITH new_dish_13293497 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Chilly', 'paneer chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Chilly', 'paneer chilly', 'primary'
FROM new_dish_13293497;

WITH new_dish_66090153 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer 65', 'paneer 65'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer 65')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer 65', 'paneer 65', 'primary'
FROM new_dish_66090153;

WITH new_dish_18012627 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Sathe', 'paneer sathe'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer sathe')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Sathe', 'paneer sathe', 'primary'
FROM new_dish_18012627;

WITH new_dish_70664169 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Schezwan', 'paneer schezwan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer schezwan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Schezwan', 'paneer schezwan', 'primary'
FROM new_dish_70664169;

WITH new_dish_29389146 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mushroom Chilly', 'mushroom chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mushroom Chilly', 'mushroom chilly', 'primary'
FROM new_dish_29389146;

WITH new_dish_87825376 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mushroom Manchurian', 'mushroom manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mushroom Manchurian', 'mushroom manchurian', 'primary'
FROM new_dish_87825376;

WITH new_dish_32423742 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Chilly', 'chicken chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Chilly', 'chicken chilly', 'primary'
FROM new_dish_32423742;

WITH new_dish_77777977 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Manchurian', 'chicken manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Manchurian', 'chicken manchurian', 'primary'
FROM new_dish_77777977;

WITH new_dish_89513286 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken 65', 'chicken 65'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken 65')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken 65', 'chicken 65', 'primary'
FROM new_dish_89513286;

WITH new_dish_57416907 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Crispy', 'chicken crispy'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken crispy')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Crispy', 'chicken crispy', 'primary'
FROM new_dish_57416907;

WITH new_dish_53068747 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Schezwan', 'chicken schezwan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Schezwan', 'chicken schezwan', 'primary'
FROM new_dish_53068747;

WITH new_dish_8956177 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Sathe', 'chicken sathe'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken sathe')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Sathe', 'chicken sathe', 'primary'
FROM new_dish_8956177;

WITH new_dish_86455042 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Spring Roll', 'chicken spring roll'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken spring roll')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Spring Roll', 'chicken spring roll', 'primary'
FROM new_dish_86455042;

WITH new_dish_87505766 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Lollypop', 'chicken lollypop'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lollypop')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Lollypop', 'chicken lollypop', 'primary'
FROM new_dish_87505766;

WITH new_dish_59467466 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Malaysian', 'chicken malaysian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken malaysian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Malaysian', 'chicken malaysian', 'primary'
FROM new_dish_59467466;

WITH new_dish_61839085 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Lemon Grass Paper', 'chicken lemon grass paper'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lemon grass paper')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Lemon Grass Paper', 'chicken lemon grass paper', 'primary'
FROM new_dish_61839085;

WITH new_dish_72703100 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Roast Chicken With Salad', 'roast chicken with salad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'roast chicken with salad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Roast Chicken With Salad', 'roast chicken with salad', 'primary'
FROM new_dish_72703100;

WITH new_dish_8725003 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Black Bean Sauce', 'chicken black bean sauce'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken black bean sauce')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Black Bean Sauce', 'chicken black bean sauce', 'primary'
FROM new_dish_8725003;

WITH new_dish_84178141 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Hot Garlic Sauce', 'chicken hot garlic sauce'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hot garlic sauce')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Hot Garlic Sauce', 'chicken hot garlic sauce', 'primary'
FROM new_dish_84178141;

WITH new_dish_83411523 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Prawns Chilly', 'prawns chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Prawns Chilly', 'prawns chilly', 'primary'
FROM new_dish_83411523;

WITH new_dish_18126246 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Prawns Manchurian', 'prawns manchurian'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns manchurian')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Prawns Manchurian', 'prawns manchurian', 'primary'
FROM new_dish_18126246;

WITH new_dish_2850886 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Prawns Schezwan', 'prawns schezwan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns schezwan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Prawns Schezwan', 'prawns schezwan', 'primary'
FROM new_dish_2850886;

WITH new_dish_28163537 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Prawns Butter Garlic', 'prawns butter garlic'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns butter garlic')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Prawns Butter Garlic', 'prawns butter garlic', 'primary'
FROM new_dish_28163537;

WITH new_dish_1310201 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Prawns Spring Roll', 'prawns spring roll'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns spring roll')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Prawns Spring Roll', 'prawns spring roll', 'primary'
FROM new_dish_1310201;

WITH new_dish_59252759 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Fish Chilly', 'fish chilly'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish chilly')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Fish Chilly', 'fish chilly', 'primary'
FROM new_dish_59252759;

WITH new_dish_12925431 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Fish Schezwan', 'fish schezwan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish schezwan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Fish Schezwan', 'fish schezwan', 'primary'
FROM new_dish_12925431;

WITH new_dish_17291474 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Fish Schezwan Finger', 'fish schezwan finger'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish schezwan finger')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Fish Schezwan Finger', 'fish schezwan finger', 'primary'
FROM new_dish_17291474;

WITH new_dish_99999073 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Dhuri Special Veg Fried Rice', 'dhuri special veg fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dhuri special veg fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Dhuri Special Veg Fried Rice', 'dhuri special veg fried rice', 'primary'
FROM new_dish_99999073;

WITH new_dish_96585093 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Fried Rice', 'fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Fried Rice', 'fried rice', 'primary'
FROM new_dish_96585093;

WITH new_dish_69071513 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Schezwan Fried Rice', 'schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Schezwan Fried Rice', 'schezwan fried rice', 'primary'
FROM new_dish_69071513;

WITH new_dish_60377339 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Tripple Schezwan Fried Rice', 'tripple schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tripple schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Tripple Schezwan Fried Rice', 'tripple schezwan fried rice', 'primary'
FROM new_dish_60377339;

WITH new_dish_96863509 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Singapore Fried Rice', 'singapore fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'singapore fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Singapore Fried Rice', 'singapore fried rice', 'primary'
FROM new_dish_96863509;

WITH new_dish_90621161 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Hongkong Fried Rice', 'hongkong fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hongkong fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Hongkong Fried Rice', 'hongkong fried rice', 'primary'
FROM new_dish_90621161;

WITH new_dish_44883101 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mushroom Fried Rice', 'mushroom fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mushroom Fried Rice', 'mushroom fried rice', 'primary'
FROM new_dish_44883101;

WITH new_dish_1723104 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Hakka Noodles', 'hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Hakka Noodles', 'hakka noodles', 'primary'
FROM new_dish_1723104;

WITH new_dish_60168462 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Schezwan Noodles', 'schezwan noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'schezwan noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Schezwan Noodles', 'schezwan noodles', 'primary'
FROM new_dish_60168462;

WITH new_dish_65292732 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Ginger Chilly Noodles (Spicy)', 'ginger chilly noodles (spicy)'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'ginger chilly noodles (spicy)')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Ginger Chilly Noodles (Spicy)', 'ginger chilly noodles (spicy)', 'primary'
FROM new_dish_65292732;

WITH new_dish_77036340 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Pan Fried Noodles', 'pan fried noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pan fried noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Pan Fried Noodles', 'pan fried noodles', 'primary'
FROM new_dish_77036340;

WITH new_dish_91229367 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Malaysian Noodles', 'malaysian noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'malaysian noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Malaysian Noodles', 'malaysian noodles', 'primary'
FROM new_dish_91229367;

WITH new_dish_96274041 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Dhuri Special Chicken Fried Rice', 'dhuri special chicken fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dhuri special chicken fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Dhuri Special Chicken Fried Rice', 'dhuri special chicken fried rice', 'primary'
FROM new_dish_96274041;

WITH new_dish_1941095 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Fried Rice', 'chicken fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Fried Rice', 'chicken fried rice', 'primary'
FROM new_dish_1941095;

WITH new_dish_23089131 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Schz Fried Rice', 'chicken schz fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schz fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Schz Fried Rice', 'chicken schz fried rice', 'primary'
FROM new_dish_23089131;

WITH new_dish_613894 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Trip Sez Fried Rice', 'chicken trip sez fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken trip sez fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Trip Sez Fried Rice', 'chicken trip sez fried rice', 'primary'
FROM new_dish_613894;

WITH new_dish_82975193 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Singapore Fried Rice', 'chicken singapore fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken singapore fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Singapore Fried Rice', 'chicken singapore fried rice', 'primary'
FROM new_dish_82975193;

WITH new_dish_12772937 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Hongkong Fried Rice', 'chicken hongkong fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hongkong fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Hongkong Fried Rice', 'chicken hongkong fried rice', 'primary'
FROM new_dish_12772937;

WITH new_dish_84316765 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Thai Pot Rice', 'chicken thai pot rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken thai pot rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Thai Pot Rice', 'chicken thai pot rice', 'primary'
FROM new_dish_84316765;

WITH new_dish_96208752 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Prawns Fried Rice', 'prawns fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Prawns Fried Rice', 'prawns fried rice', 'primary'
FROM new_dish_96208752;

WITH new_dish_87191714 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Prawns Schezwan Fried Rice', 'prawns schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Prawns Schezwan Fried Rice', 'prawns schezwan fried rice', 'primary'
FROM new_dish_87191714;

WITH new_dish_5298587 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Egg Fried Rice', 'egg fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Egg Fried Rice', 'egg fried rice', 'primary'
FROM new_dish_5298587;

WITH new_dish_58687575 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Egg Schezwan Fried Rice', 'egg schezwan fried rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg schezwan fried rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Egg Schezwan Fried Rice', 'egg schezwan fried rice', 'primary'
FROM new_dish_58687575;

WITH new_dish_10455457 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Hakka Noodles', 'chicken hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Hakka Noodles', 'chicken hakka noodles', 'primary'
FROM new_dish_10455457;

WITH new_dish_59602126 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Schezwan Noodles', 'chicken schezwan noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken schezwan noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Schezwan Noodles', 'chicken schezwan noodles', 'primary'
FROM new_dish_59602126;

WITH new_dish_7142840 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Malaysian Noodles', 'chicken malaysian noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken malaysian noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Malaysian Noodles', 'chicken malaysian noodles', 'primary'
FROM new_dish_7142840;

WITH new_dish_94108189 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Pan Fried Noodles', 'chicken pan fried noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pan fried noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Pan Fried Noodles', 'chicken pan fried noodles', 'primary'
FROM new_dish_94108189;

WITH new_dish_46978224 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Prawns Hakka Noodles', 'prawns hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Prawns Hakka Noodles', 'prawns hakka noodles', 'primary'
FROM new_dish_46978224;

WITH new_dish_97541730 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Prawns Schz Hakka Noodles', 'prawns schz hakka noodles'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns schz hakka noodles')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Prawns Schz Hakka Noodles', 'prawns schz hakka noodles', 'primary'
FROM new_dish_97541730;

WITH new_dish_71040976 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Tandoori', 'chicken tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Tandoori', 'chicken tandoori', 'primary'
FROM new_dish_71040976;

WITH new_dish_5674915 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Tandoori Schezwan', 'tandoori schezwan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'tandoori schezwan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Tandoori Schezwan', 'tandoori schezwan', 'primary'
FROM new_dish_5674915;

WITH new_dish_5248923 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Reshmi Kabab', 'chicken reshmi kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken reshmi kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Reshmi Kabab', 'chicken reshmi kabab', 'primary'
FROM new_dish_5248923;

WITH new_dish_50044926 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Seekh Kabab', 'chicken seekh kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken seekh kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Seekh Kabab', 'chicken seekh kabab', 'primary'
FROM new_dish_50044926;

WITH new_dish_78236401 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Tangdi Kabab', 'chicken tangdi kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tangdi kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Tangdi Kabab', 'chicken tangdi kabab', 'primary'
FROM new_dish_78236401;

WITH new_dish_13827250 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Rosali Kabab', 'chicken rosali kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken rosali kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Rosali Kabab', 'chicken rosali kabab', 'primary'
FROM new_dish_13827250;

WITH new_dish_11189577 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Achari Kabab', 'chicken achari kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken achari kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Achari Kabab', 'chicken achari kabab', 'primary'
FROM new_dish_11189577;

WITH new_dish_26522226 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Pahadi Kabab', 'chicken pahadi kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pahadi kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Pahadi Kabab', 'chicken pahadi kabab', 'primary'
FROM new_dish_26522226;

WITH new_dish_14056732 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Chatpata Kabab', 'chicken chatpata kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken chatpata kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Chatpata Kabab', 'chicken chatpata kabab', 'primary'
FROM new_dish_14056732;

WITH new_dish_60775589 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Tikka', 'chicken tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Tikka', 'chicken tikka', 'primary'
FROM new_dish_60775589;

WITH new_dish_50162978 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Lollypop Tandoori', 'chicken lollypop tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lollypop tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Lollypop Tandoori', 'chicken lollypop tandoori', 'primary'
FROM new_dish_50162978;

WITH new_dish_28978992 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Seekh Kabab', 'veg seekh kabab'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg seekh kabab')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Seekh Kabab', 'veg seekh kabab', 'primary'
FROM new_dish_28978992;

WITH new_dish_69965559 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Tikka', 'paneer tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Tikka', 'paneer tikka', 'primary'
FROM new_dish_69965559;

WITH new_dish_17567854 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Hariyali Tikka', 'paneer hariyali tikka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer hariyali tikka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Hariyali Tikka', 'paneer hariyali tikka', 'primary'
FROM new_dish_17567854;

WITH new_dish_45730067 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mushroom Tandoori', 'mushroom tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mushroom Tandoori', 'mushroom tandoori', 'primary'
FROM new_dish_45730067;

WITH new_dish_75316472 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Baby Corn Tandoori', 'baby corn tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'baby corn tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Baby Corn Tandoori', 'baby corn tandoori', 'primary'
FROM new_dish_75316472;

WITH new_dish_51256267 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Bhuna Masala', 'veg bhuna masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg bhuna masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Bhuna Masala', 'veg bhuna masala', 'primary'
FROM new_dish_51256267;

WITH new_dish_15859376 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Hydrabadi', 'veg hydrabadi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg hydrabadi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Hydrabadi', 'veg hydrabadi', 'primary'
FROM new_dish_15859376;

WITH new_dish_93420028 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Diwani Handi', 'veg diwani handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg diwani handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Diwani Handi', 'veg diwani handi', 'primary'
FROM new_dish_93420028;

WITH new_dish_21116058 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Maharaja', 'veg maharaja'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg maharaja')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Maharaja', 'veg maharaja', 'primary'
FROM new_dish_21116058;

WITH new_dish_62144518 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Delight', 'veg delight'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg delight')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Delight', 'veg delight', 'primary'
FROM new_dish_62144518;

WITH new_dish_42026488 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Maratha', 'veg maratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg maratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Maratha', 'veg maratha', 'primary'
FROM new_dish_42026488;

WITH new_dish_72443570 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Zill Mill', 'veg zill mill'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg zill mill')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Zill Mill', 'veg zill mill', 'primary'
FROM new_dish_72443570;

WITH new_dish_65121768 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Makhanwala', 'veg makhanwala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg makhanwala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Makhanwala', 'veg makhanwala', 'primary'
FROM new_dish_65121768;

WITH new_dish_75634583 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Handi', 'veg handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Handi', 'veg handi', 'primary'
FROM new_dish_75634583;

WITH new_dish_1582758 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Chilli Milli', 'veg chilli milli'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg chilli milli')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Chilli Milli', 'veg chilli milli', 'primary'
FROM new_dish_1582758;

WITH new_dish_65748548 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Jalfrazi', 'veg jalfrazi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg jalfrazi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Jalfrazi', 'veg jalfrazi', 'primary'
FROM new_dish_65748548;

WITH new_dish_29516650 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Kolhapuri', 'veg kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Kolhapuri', 'veg kolhapuri', 'primary'
FROM new_dish_29516650;

WITH new_dish_35302452 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Kadai', 'veg kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Kadai', 'veg kadai', 'primary'
FROM new_dish_35302452;

WITH new_dish_2604318 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Kofta', 'veg kofta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg kofta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Kofta', 'veg kofta', 'primary'
FROM new_dish_2604318;

WITH new_dish_45397528 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Makhmali', 'veg makhmali'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg makhmali')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Makhmali', 'veg makhmali', 'primary'
FROM new_dish_45397528;

WITH new_dish_90261441 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Banjara', 'veg banjara'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg banjara')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Banjara', 'veg banjara', 'primary'
FROM new_dish_90261441;

WITH new_dish_30375065 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Kheema', 'veg kheema'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg kheema')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Kheema', 'veg kheema', 'primary'
FROM new_dish_30375065;

WITH new_dish_7175336 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Chatpata', 'veg chatpata'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg chatpata')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Chatpata', 'veg chatpata', 'primary'
FROM new_dish_7175336;

WITH new_dish_87551055 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Dilruba', 'veg dilruba'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg dilruba')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Dilruba', 'veg dilruba', 'primary'
FROM new_dish_87551055;

WITH new_dish_64551085 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Alu Palak', 'alu palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'alu palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Alu Palak', 'alu palak', 'primary'
FROM new_dish_64551085;

WITH new_dish_45076969 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Alu Jeera', 'alu jeera'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'alu jeera')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Alu Jeera', 'alu jeera', 'primary'
FROM new_dish_45076969;

WITH new_dish_93082183 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Alu Methi', 'alu methi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'alu methi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Alu Methi', 'alu methi', 'primary'
FROM new_dish_93082183;

WITH new_dish_51977445 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Alu Mutter', 'alu mutter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'alu mutter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Alu Mutter', 'alu mutter', 'primary'
FROM new_dish_51977445;

WITH new_dish_86612642 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chana Masala', 'chana masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chana masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chana Masala', 'chana masala', 'primary'
FROM new_dish_86612642;

WITH new_dish_57817968 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Navratan Korma', 'navratan korma'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'navratan korma')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Navratan Korma', 'navratan korma', 'primary'
FROM new_dish_57817968;

WITH new_dish_87765514 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Methi Mutter Masala', 'methi mutter masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'methi mutter masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Methi Mutter Masala', 'methi mutter masala', 'primary'
FROM new_dish_87765514;

WITH new_dish_54391454 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Methi Malai Mutter', 'methi malai mutter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'methi malai mutter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Methi Malai Mutter', 'methi malai mutter', 'primary'
FROM new_dish_54391454;

WITH new_dish_5423261 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Green Peas Masala', 'green peas masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green peas masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Green Peas Masala', 'green peas masala', 'primary'
FROM new_dish_5423261;

WITH new_dish_25890419 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Baingan Bharta', 'baingan bharta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'baingan bharta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Baingan Bharta', 'baingan bharta', 'primary'
FROM new_dish_25890419;

WITH new_dish_33544102 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Baingan Masala', 'baingan masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'baingan masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Baingan Masala', 'baingan masala', 'primary'
FROM new_dish_33544102;

WITH new_dish_29098369 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mushroom Masala', 'mushroom masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mushroom Masala', 'mushroom masala', 'primary'
FROM new_dish_29098369;

WITH new_dish_15087460 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mushroom Mutter Masala', 'mushroom mutter masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mushroom mutter masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mushroom Mutter Masala', 'mushroom mutter masala', 'primary'
FROM new_dish_15087460;

WITH new_dish_90221020 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Baby Corn Masala', 'baby corn masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'baby corn masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Baby Corn Masala', 'baby corn masala', 'primary'
FROM new_dish_90221020;

WITH new_dish_20151342 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Baby Corn Paneer Masala', 'baby corn paneer masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'baby corn paneer masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Baby Corn Paneer Masala', 'baby corn paneer masala', 'primary'
FROM new_dish_20151342;

WITH new_dish_40562561 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Baby Corn Mushroom Masala', 'baby corn mushroom masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'baby corn mushroom masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Baby Corn Mushroom Masala', 'baby corn mushroom masala', 'primary'
FROM new_dish_40562561;

WITH new_dish_58513811 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Butter Masala', 'paneer butter masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer butter masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Butter Masala', 'paneer butter masala', 'primary'
FROM new_dish_58513811;

WITH new_dish_18673122 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Tikka Masala', 'paneer tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Tikka Masala', 'paneer tikka masala', 'primary'
FROM new_dish_18673122;

WITH new_dish_21472481 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Delight', 'paneer delight'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer delight')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Delight', 'paneer delight', 'primary'
FROM new_dish_21472481;

WITH new_dish_8029158 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Lahori', 'paneer lahori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer lahori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Lahori', 'paneer lahori', 'primary'
FROM new_dish_8029158;

WITH new_dish_26079483 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Lapeta', 'paneer lapeta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer lapeta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Lapeta', 'paneer lapeta', 'primary'
FROM new_dish_26079483;

WITH new_dish_12522197 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Hariyali Tikka Masala', 'paneer hariyali tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer hariyali tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Hariyali Tikka Masala', 'paneer hariyali tikka masala', 'primary'
FROM new_dish_12522197;

WITH new_dish_35087291 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Bhurji', 'paneer bhurji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer bhurji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Bhurji', 'paneer bhurji', 'primary'
FROM new_dish_35087291;

WITH new_dish_94622169 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Handi', 'paneer handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Handi', 'paneer handi', 'primary'
FROM new_dish_94622169;

WITH new_dish_21502217 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Saagwala', 'paneer saagwala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer saagwala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Saagwala', 'paneer saagwala', 'primary'
FROM new_dish_21502217;

WITH new_dish_84139088 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Handi', 'chicken handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Handi', 'chicken handi', 'primary'
FROM new_dish_84139088;

WITH new_dish_6275640 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Murg Musallam', 'murg musallam'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murg musallam')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Murg Musallam', 'murg musallam', 'primary'
FROM new_dish_6275640;

WITH new_dish_60092218 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Tikka Masala', 'chicken tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Tikka Masala', 'chicken tikka masala', 'primary'
FROM new_dish_60092218;

WITH new_dish_33773705 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Pahadi Tikka Masala', 'chicken pahadi tikka masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken pahadi tikka masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Pahadi Tikka Masala', 'chicken pahadi tikka masala', 'primary'
FROM new_dish_33773705;

WITH new_dish_40095599 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Hyderabadi', 'chicken hyderabadi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hyderabadi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Hyderabadi', 'chicken hyderabadi', 'primary'
FROM new_dish_40095599;

WITH new_dish_19789422 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Patiala', 'chicken patiala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken patiala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Patiala', 'chicken patiala', 'primary'
FROM new_dish_19789422;

WITH new_dish_56789591 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Moghlai', 'chicken moghlai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken moghlai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Moghlai', 'chicken moghlai', 'primary'
FROM new_dish_56789591;

WITH new_dish_39045956 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Lazeez', 'chicken lazeez'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lazeez')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Lazeez', 'chicken lazeez', 'primary'
FROM new_dish_39045956;

WITH new_dish_41920216 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Lahori', 'chicken lahori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lahori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Lahori', 'chicken lahori', 'primary'
FROM new_dish_41920216;

WITH new_dish_4498913 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Kolhapuri', 'chicken kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Kolhapuri', 'chicken kolhapuri', 'primary'
FROM new_dish_4498913;

WITH new_dish_28840129 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Lapeta', 'chicken lapeta'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken lapeta')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Lapeta', 'chicken lapeta', 'primary'
FROM new_dish_28840129;

WITH new_dish_72647298 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Peshwari', 'chicken peshwari'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken peshwari')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Peshwari', 'chicken peshwari', 'primary'
FROM new_dish_72647298;

WITH new_dish_51510200 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Amritshari', 'chicken amritshari'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken amritshari')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Amritshari', 'chicken amritshari', 'primary'
FROM new_dish_51510200;

WITH new_dish_28672749 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Murg Chaap Nargisi', 'murg chaap nargisi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'murg chaap nargisi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Murg Chaap Nargisi', 'murg chaap nargisi', 'primary'
FROM new_dish_28672749;

WITH new_dish_61064446 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Kadai', 'chicken kadai'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken kadai')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Kadai', 'chicken kadai', 'primary'
FROM new_dish_61064446;

WITH new_dish_79742211 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Masala', 'chicken masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Masala', 'chicken masala', 'primary'
FROM new_dish_79742211;

WITH new_dish_61889128 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Rara', 'chicken rara'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken rara')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Rara', 'chicken rara', 'primary'
FROM new_dish_61889128;

WITH new_dish_91469602 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Angara', 'chicken angara'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken angara')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Angara', 'chicken angara', 'primary'
FROM new_dish_91469602;

WITH new_dish_29748610 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Butter Chicken', 'butter chicken'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter chicken')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Butter Chicken', 'butter chicken', 'primary'
FROM new_dish_29748610;

WITH new_dish_65197235 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mutton Handi', 'mutton handi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton handi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mutton Handi', 'mutton handi', 'primary'
FROM new_dish_65197235;

WITH new_dish_1315090 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mutton Roganjosh', 'mutton roganjosh'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton roganjosh')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mutton Roganjosh', 'mutton roganjosh', 'primary'
FROM new_dish_1315090;

WITH new_dish_86041065 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mutton Kolhapuri', 'mutton kolhapuri'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kolhapuri')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mutton Kolhapuri', 'mutton kolhapuri', 'primary'
FROM new_dish_86041065;

WITH new_dish_41651871 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mutton Masala', 'mutton masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mutton Masala', 'mutton masala', 'primary'
FROM new_dish_41651871;

WITH new_dish_56322933 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mutton Sukha', 'mutton sukha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton sukha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mutton Sukha', 'mutton sukha', 'primary'
FROM new_dish_56322933;

WITH new_dish_4269212 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mutton Rara', 'mutton rara'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton rara')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mutton Rara', 'mutton rara', 'primary'
FROM new_dish_4269212;

WITH new_dish_23359483 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mutton Hydrabadi', 'mutton hydrabadi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton hydrabadi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mutton Hydrabadi', 'mutton hydrabadi', 'primary'
FROM new_dish_23359483;

WITH new_dish_43331644 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mutton Kheema', 'mutton kheema'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton kheema')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mutton Kheema', 'mutton kheema', 'primary'
FROM new_dish_43331644;

WITH new_dish_55525269 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Egg Masala', 'egg masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Egg Masala', 'egg masala', 'primary'
FROM new_dish_55525269;

WITH new_dish_25868304 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Egg Omlet', 'egg omlet'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg omlet')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Egg Omlet', 'egg omlet', 'primary'
FROM new_dish_25868304;

WITH new_dish_63945133 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Egg Bhurji', 'egg bhurji'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg bhurji')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Egg Bhurji', 'egg bhurji', 'primary'
FROM new_dish_63945133;

WITH new_dish_32629639 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Dal Fry', 'dal fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Dal Fry', 'dal fry', 'primary'
FROM new_dish_32629639;

WITH new_dish_76620140 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Dal Tadka', 'dal tadka'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal tadka')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Dal Tadka', 'dal tadka', 'primary'
FROM new_dish_76620140;

WITH new_dish_97222221 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Dal Palak', 'dal palak'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal palak')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Dal Palak', 'dal palak', 'primary'
FROM new_dish_97222221;

WITH new_dish_9401881 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Dal Methi', 'dal methi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal methi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Dal Methi', 'dal methi', 'primary'
FROM new_dish_9401881;

WITH new_dish_54820310 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Pomfret Fry', 'pomfret fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pomfret fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Pomfret Fry', 'pomfret fry', 'primary'
FROM new_dish_54820310;

WITH new_dish_62932087 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Pomfret Masala', 'pomfret masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pomfret masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Pomfret Masala', 'pomfret masala', 'primary'
FROM new_dish_62932087;

WITH new_dish_57479948 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Surmai Fry', 'surmai fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'surmai fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Surmai Fry', 'surmai fry', 'primary'
FROM new_dish_57479948;

WITH new_dish_64133199 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Surmai Masala', 'surmai masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'surmai masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Surmai Masala', 'surmai masala', 'primary'
FROM new_dish_64133199;

WITH new_dish_3875530 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Prawns Masala', 'prawns masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Prawns Masala', 'prawns masala', 'primary'
FROM new_dish_3875530;

WITH new_dish_9497257 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Prawns Koliwada', 'prawns koliwada'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns koliwada')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Prawns Koliwada', 'prawns koliwada', 'primary'
FROM new_dish_9497257;

WITH new_dish_46898773 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Rawas Fry', 'rawas fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawas fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Rawas Fry', 'rawas fry', 'primary'
FROM new_dish_46898773;

WITH new_dish_1680641 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Rawas Masala', 'rawas masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'rawas masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Rawas Masala', 'rawas masala', 'primary'
FROM new_dish_1680641;

WITH new_dish_99098388 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Bangda Fry', 'bangda fry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bangda fry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Bangda Fry', 'bangda fry', 'primary'
FROM new_dish_99098388;

WITH new_dish_3173242 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Bangda Masala', 'bangda masala'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'bangda masala')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Bangda Masala', 'bangda masala', 'primary'
FROM new_dish_3173242;

WITH new_dish_6583528 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Pomfret Tandoori', 'pomfret tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pomfret tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Pomfret Tandoori', 'pomfret tandoori', 'primary'
FROM new_dish_6583528;

WITH new_dish_97283227 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Fish Tandoori', 'fish tandoori'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish tandoori')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Fish Tandoori', 'fish tandoori', 'primary'
FROM new_dish_97283227;

WITH new_dish_69390112 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Fish Goan Curry', 'fish goan curry'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fish goan curry')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Fish Goan Curry', 'fish goan curry', 'primary'
FROM new_dish_69390112;

WITH new_dish_32355031 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Seafood Platter', 'seafood platter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'seafood platter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Seafood Platter', 'seafood platter', 'primary'
FROM new_dish_32355031;

WITH new_dish_3871699 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Roti', 'roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Roti', 'roti', 'primary'
FROM new_dish_3871699;

WITH new_dish_18956526 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Butter Roti', 'butter roti'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter roti')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Butter Roti', 'butter roti', 'primary'
FROM new_dish_18956526;

WITH new_dish_28468747 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Naan', 'naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Naan', 'naan', 'primary'
FROM new_dish_28468747;

WITH new_dish_39968195 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Butter Naan', 'butter naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Butter Naan', 'butter naan', 'primary'
FROM new_dish_39968195;

WITH new_dish_29711571 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Kulcha', 'kulcha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'kulcha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Kulcha', 'kulcha', 'primary'
FROM new_dish_29711571;

WITH new_dish_52366859 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Butter Kulcha', 'butter kulcha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'butter kulcha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Butter Kulcha', 'butter kulcha', 'primary'
FROM new_dish_52366859;

WITH new_dish_32042475 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paratha', 'paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paratha', 'paratha', 'primary'
FROM new_dish_32042475;

WITH new_dish_6211951 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Stuffed Paratha', 'stuffed paratha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'stuffed paratha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Stuffed Paratha', 'stuffed paratha', 'primary'
FROM new_dish_6211951;

WITH new_dish_12002876 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Garlic Naan', 'garlic naan'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'garlic naan')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Garlic Naan', 'garlic naan', 'primary'
FROM new_dish_12002876;

WITH new_dish_13651159 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Stuff Kulcha', 'stuff kulcha'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'stuff kulcha')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Stuff Kulcha', 'stuff kulcha', 'primary'
FROM new_dish_13651159;

WITH new_dish_9887219 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Extra Cheese', 'extra cheese'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra cheese')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Extra Cheese', 'extra cheese', 'primary'
FROM new_dish_9887219;

WITH new_dish_6902302 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Extra Butter', 'extra butter'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'extra butter')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Extra Butter', 'extra butter', 'primary'
FROM new_dish_6902302;

WITH new_dish_6496460 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Green Salad', 'green salad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'green salad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Green Salad', 'green salad', 'primary'
FROM new_dish_6496460;

WITH new_dish_44416427 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Russian Salad', 'russian salad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'russian salad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Russian Salad', 'russian salad', 'primary'
FROM new_dish_44416427;

WITH new_dish_2213559 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Non Veg Russian Salad', 'non veg russian salad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'non veg russian salad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Non Veg Russian Salad', 'non veg russian salad', 'primary'
FROM new_dish_2213559;

WITH new_dish_75134046 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Boondi Raita', 'boondi raita'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'boondi raita')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Boondi Raita', 'boondi raita', 'primary'
FROM new_dish_75134046;

WITH new_dish_53465089 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Pineapple Raita', 'pineapple raita'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'pineapple raita')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Pineapple Raita', 'pineapple raita', 'primary'
FROM new_dish_53465089;

WITH new_dish_43618738 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Raita', 'veg raita'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg raita')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Raita', 'veg raita', 'primary'
FROM new_dish_43618738;

WITH new_dish_25747881 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Roasted Papad', 'roasted papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'roasted papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Roasted Papad', 'roasted papad', 'primary'
FROM new_dish_25747881;

WITH new_dish_10338703 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Fry Papad', 'fry papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'fry papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Fry Papad', 'fry papad', 'primary'
FROM new_dish_10338703;

WITH new_dish_83101734 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Masala Papad', 'masala papad'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'masala papad')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Masala Papad', 'masala papad', 'primary'
FROM new_dish_83101734;

WITH new_dish_54724456 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Curd', 'curd'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'curd')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Curd', 'curd', 'primary'
FROM new_dish_54724456;

WITH new_dish_73526634 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Biryani', 'chicken biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Biryani', 'chicken biryani', 'primary'
FROM new_dish_73526634;

WITH new_dish_1978327 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Tikka Biryani', 'chicken tikka biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken tikka biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Tikka Biryani', 'chicken tikka biryani', 'primary'
FROM new_dish_1978327;

WITH new_dish_2878536 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mutton Biryani', 'mutton biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mutton Biryani', 'mutton biryani', 'primary'
FROM new_dish_2878536;

WITH new_dish_51608048 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Biryani', 'veg biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Biryani', 'veg biryani', 'primary'
FROM new_dish_51608048;

WITH new_dish_20486666 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Pulav', 'veg pulav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg pulav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Pulav', 'veg pulav', 'primary'
FROM new_dish_20486666;

WITH new_dish_29869901 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Steam Rice', 'steam rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'steam rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Steam Rice', 'steam rice', 'primary'
FROM new_dish_29869901;

WITH new_dish_61687673 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Jeera Rice', 'jeera rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'jeera rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Jeera Rice', 'jeera rice', 'primary'
FROM new_dish_61687673;

WITH new_dish_61363152 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Dum Biryani', 'veg dum biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg dum biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Dum Biryani', 'veg dum biryani', 'primary'
FROM new_dish_61363152;

WITH new_dish_43706409 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Hydrabadi Biryani', 'veg hydrabadi biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg hydrabadi biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Hydrabadi Biryani', 'veg hydrabadi biryani', 'primary'
FROM new_dish_43706409;

WITH new_dish_24425677 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Pulav', 'paneer pulav'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer pulav')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Pulav', 'paneer pulav', 'primary'
FROM new_dish_24425677;

WITH new_dish_77330779 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Dal Khichdi', 'dal khichdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal khichdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Dal Khichdi', 'dal khichdi', 'primary'
FROM new_dish_77330779;

WITH new_dish_60239338 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Palak Khichdi', 'palak khichdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'palak khichdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Palak Khichdi', 'palak khichdi', 'primary'
FROM new_dish_60239338;

WITH new_dish_11431869 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Curd Rice', 'curd rice'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'curd rice')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Curd Rice', 'curd rice', 'primary'
FROM new_dish_11431869;

WITH new_dish_65898955 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Dal Palak Khichdi', 'dal palak khichdi'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'dal palak khichdi')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Dal Palak Khichdi', 'dal palak khichdi', 'primary'
FROM new_dish_65898955;

WITH new_dish_11548084 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Dum Biryani', 'chicken dum biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken dum biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Dum Biryani', 'chicken dum biryani', 'primary'
FROM new_dish_11548084;

WITH new_dish_67506842 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Hydrabadi Biryani', 'chicken hydrabadi biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken hydrabadi biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Hydrabadi Biryani', 'chicken hydrabadi biryani', 'primary'
FROM new_dish_67506842;

WITH new_dish_95594697 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mutton Dum Biryani', 'mutton dum biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton dum biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mutton Dum Biryani', 'mutton dum biryani', 'primary'
FROM new_dish_95594697;

WITH new_dish_76090943 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Mutton Hydrabadi Biryani', 'mutton hydrabadi biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'mutton hydrabadi biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Mutton Hydrabadi Biryani', 'mutton hydrabadi biryani', 'primary'
FROM new_dish_76090943;

WITH new_dish_95717536 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Egg Biryani', 'egg biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'egg biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Egg Biryani', 'egg biryani', 'primary'
FROM new_dish_95717536;

WITH new_dish_99440137 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Prawns Biryani', 'prawns biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Prawns Biryani', 'prawns biryani', 'primary'
FROM new_dish_99440137;

WITH new_dish_83423684 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Prawns Dum Biryani', 'prawns dum biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns dum biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Prawns Dum Biryani', 'prawns dum biryani', 'primary'
FROM new_dish_83423684;

WITH new_dish_58757861 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Prawns Hydrabadi Biryani', 'prawns hydrabadi biryani'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'prawns hydrabadi biryani')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Prawns Hydrabadi Biryani', 'prawns hydrabadi biryani', 'primary'
FROM new_dish_58757861;

WITH new_dish_83183135 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Sandwich', 'veg sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Sandwich', 'veg sandwich', 'primary'
FROM new_dish_83183135;

WITH new_dish_92101426 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Grilled Sandwich', 'veg grilled sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg grilled sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Grilled Sandwich', 'veg grilled sandwich', 'primary'
FROM new_dish_92101426;

WITH new_dish_68722328 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Club Sandwich', 'veg club sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg club sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Club Sandwich', 'veg club sandwich', 'primary'
FROM new_dish_68722328;

WITH new_dish_6492378 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Cheese Sandwich', 'veg cheese sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg cheese sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Cheese Sandwich', 'veg cheese sandwich', 'primary'
FROM new_dish_6492378;

WITH new_dish_20038152 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Cheese Toast Sandwich', 'veg cheese toast sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg cheese toast sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Cheese Toast Sandwich', 'veg cheese toast sandwich', 'primary'
FROM new_dish_20038152;

WITH new_dish_88537823 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Cheese Grilled Sandwich', 'veg cheese grilled sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg cheese grilled sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Cheese Grilled Sandwich', 'veg cheese grilled sandwich', 'primary'
FROM new_dish_88537823;

WITH new_dish_67933040 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Cheese Chilly Toast', 'cheese chilly toast'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'cheese chilly toast')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Cheese Chilly Toast', 'cheese chilly toast', 'primary'
FROM new_dish_67933040;

WITH new_dish_61171196 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Omlet Sandwich', 'omlet sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'omlet sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Omlet Sandwich', 'omlet sandwich', 'primary'
FROM new_dish_61171196;

WITH new_dish_6935636 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chicken Sandwich', 'chicken sandwich'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chicken sandwich')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chicken Sandwich', 'chicken sandwich', 'primary'
FROM new_dish_6935636;

WITH new_dish_42245751 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Veg Cheese Pizza', 'veg cheese pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'veg cheese pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Veg Cheese Pizza', 'veg cheese pizza', 'primary'
FROM new_dish_42245751;

WITH new_dish_11792727 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Paneer Tikka Pizza', 'paneer tikka pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'paneer tikka pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Paneer Tikka Pizza', 'paneer tikka pizza', 'primary'
FROM new_dish_11792727;

WITH new_dish_56745205 AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name)
  SELECT nextval('dhuri_canonical_seq'), 'Chi Tikka Pizza', 'chi tikka pizza'
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish WHERE normalized_name = 'chi tikka pizza')
  RETURNING canonical_dish_id
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT nextval('dhuri_canonical_seq'), canonical_dish_id, 'en', 'Chi Tikka Pizza', 'chi tikka pizza', 'primary'
FROM new_dish_56745205;

-- Source: docx, "Soups (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001001, 401202001, cd.canonical_dish_id, 'Veg Manchow', 'veg manchow', 401202001001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg manchow'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001001, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001001, variant_id, 150.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001001, 401202001, 401202001001, menu_item_id, 401202001001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001002, 401202001, cd.canonical_dish_id, 'Veg Clear', 'veg clear', 401202001001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg clear'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001002, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001002, variant_id, 150.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001002, 401202001, 401202001001, menu_item_id, 401202001001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001003, 401202001, cd.canonical_dish_id, 'Veg Hot & Sour', 'veg hot & sour', 401202001001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg hot & sour'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001003, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001003, variant_id, 150.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001003, 401202001, 401202001001, menu_item_id, 401202001001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001004, 401202001, cd.canonical_dish_id, 'Veg Noodles', 'veg noodles', 401202001001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001004, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001004, variant_id, 150.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001004, 401202001, 401202001001, menu_item_id, 401202001001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001005, 401202001, cd.canonical_dish_id, 'Veg Sweet Corn', 'veg sweet corn', 401202001001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg sweet corn'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001005, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001005, variant_id, 150.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001005, 401202001, 401202001001, menu_item_id, 401202001001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001006, 401202001, cd.canonical_dish_id, 'Lemon Coriander', 'lemon coriander', 401202001001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'lemon coriander'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001006, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001006, variant_id, 160.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001006, 401202001, 401202001001, menu_item_id, 401202001001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001007, 401202001, cd.canonical_dish_id, 'Cream Of Tomato', 'cream of tomato', 401202001001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cream of tomato'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001007, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001007, variant_id, 160.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001007, 401202001, 401202001001, menu_item_id, 401202001001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001008, 401202001, cd.canonical_dish_id, 'Cream Of Mushroom', 'cream of mushroom', 401202001001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cream of mushroom'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001008, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001008, variant_id, 160.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001008, 401202001, 401202001001, menu_item_id, 401202001001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001009, 401202001, cd.canonical_dish_id, 'Cream Of Palak', 'cream of palak', 401202001001, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cream of palak'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001009, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001009, variant_id, 160.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001009, 401202001, 401202001001, menu_item_id, 401202001001 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001010, 401202001, cd.canonical_dish_id, 'Chicken Manchow', 'chicken manchow', 401202001002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken manchow'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001010, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001010, variant_id, 170.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001010, 401202001, 401202001001, menu_item_id, 401202001002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001011, 401202001, cd.canonical_dish_id, 'Chicken Clear', 'chicken clear', 401202001002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken clear'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001011, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001011, variant_id, 170.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001011, 401202001, 401202001001, menu_item_id, 401202001002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001012, 401202001, cd.canonical_dish_id, 'Chicken Hot & Sour', 'chicken hot & sour', 401202001002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken hot & sour'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001012, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001012, variant_id, 170.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001012, 401202001, 401202001001, menu_item_id, 401202001002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001013, 401202001, cd.canonical_dish_id, 'Chicken Sweet Corn', 'chicken sweet corn', 401202001002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken sweet corn'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001013, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001013, variant_id, 190.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001013, 401202001, 401202001001, menu_item_id, 401202001002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001014, 401202001, cd.canonical_dish_id, 'Chicken Lemon Coriander', 'chicken lemon coriander', 401202001002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken lemon coriander'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001014, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001014, variant_id, 170.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001014, 401202001, 401202001001, menu_item_id, 401202001002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001015, 401202001, cd.canonical_dish_id, 'Chicken Lung Fung', 'chicken lung fung', 401202001002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken lung fung'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001015, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001015, variant_id, 190.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001015, 401202001, 401202001001, menu_item_id, 401202001002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001016, 401202001, cd.canonical_dish_id, 'Chicken Shorba', 'chicken shorba', 401202001002, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken shorba'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001016, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001016, variant_id, 170.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001016, 401202001, 401202001001, menu_item_id, 401202001002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Soups (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001017, 401202001, cd.canonical_dish_id, 'Mutton Paya', 'mutton paya', 401202001002, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton paya'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001017, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001017, variant_id, 220.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001017, 401202001, 401202001001, menu_item_id, 401202001002 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001018, 401202001, cd.canonical_dish_id, 'Veg Manchurian', 'veg manchurian', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg manchurian'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001018, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001018, variant_id, 240.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001018, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001019, 401202001, cd.canonical_dish_id, 'Veg Chilly', 'veg chilly', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg chilly'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001019, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001019, variant_id, 240.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001019, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001020, 401202001, cd.canonical_dish_id, 'Veg Crispy', 'veg crispy', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg crispy'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001020, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001020, variant_id, 240.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001020, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001021, 401202001, cd.canonical_dish_id, 'Veg Schezwan', 'veg schezwan', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg schezwan'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001021, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001021, variant_id, 240.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001021, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001022, 401202001, cd.canonical_dish_id, 'Veg Spring Roll', 'veg spring roll', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg spring roll'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001022, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001022, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001022, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001023, 401202001, cd.canonical_dish_id, 'Veg Malaysian', 'veg malaysian', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg malaysian'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001023, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001023, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001023, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001024, 401202001, cd.canonical_dish_id, 'Shanghai Potato', 'shanghai potato', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'shanghai potato'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001024, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001024, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001024, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001025, 401202001, cd.canonical_dish_id, 'Chilly Garlic Potato', 'chilly garlic potato', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chilly garlic potato'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001025, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001025, variant_id, 280.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001025, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001026, 401202001, cd.canonical_dish_id, 'Paneer Crispy', 'paneer crispy', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer crispy'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001026, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001026, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001026, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001027, 401202001, cd.canonical_dish_id, 'Paneer Manchurian', 'paneer manchurian', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer manchurian'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001027, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001027, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001027, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001028, 401202001, cd.canonical_dish_id, 'Paneer Chilly', 'paneer chilly', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer chilly'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001028, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001028, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001028, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001029, 401202001, cd.canonical_dish_id, 'Paneer 65', 'paneer 65', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer 65'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001029, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001029, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001029, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001030, 401202001, cd.canonical_dish_id, 'Paneer Sathe', 'paneer sathe', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer sathe'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001030, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001030, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001030, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001031, 401202001, cd.canonical_dish_id, 'Paneer Schezwan', 'paneer schezwan', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer schezwan'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001031, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001031, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001031, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001032, 401202001, cd.canonical_dish_id, 'Mushroom Chilly', 'mushroom chilly', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom chilly'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001032, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001032, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001032, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001033, 401202001, cd.canonical_dish_id, 'Mushroom Manchurian', 'mushroom manchurian', 401202001003, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom manchurian'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001033, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001033, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001033, 401202001, 401202001001, menu_item_id, 401202001003 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001034, 401202001, cd.canonical_dish_id, 'Chicken Chilly', 'chicken chilly', 401202001004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken chilly'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001034, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001034, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001034, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001035, 401202001, cd.canonical_dish_id, 'Chicken Manchurian', 'chicken manchurian', 401202001004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken manchurian'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001035, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001035, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001035, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001036, 401202001, cd.canonical_dish_id, 'Chicken 65', 'chicken 65', 401202001004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken 65'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001036, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001036, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001036, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001037, 401202001, cd.canonical_dish_id, 'Chicken Crispy', 'chicken crispy', 401202001004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken crispy'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001037, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001037, variant_id, 320.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001037, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001038, 401202001, cd.canonical_dish_id, 'Chicken Schezwan', 'chicken schezwan', 401202001004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken schezwan'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001038, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001038, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001038, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001039, 401202001, cd.canonical_dish_id, 'Chicken Sathe', 'chicken sathe', 401202001004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken sathe'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001039, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001039, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001039, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001040, 401202001, cd.canonical_dish_id, 'Chicken Spring Roll', 'chicken spring roll', 401202001004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken spring roll'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001040, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001040, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001040, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001041, 401202001, cd.canonical_dish_id, 'Chicken Lollypop', 'chicken lollypop', 401202001004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken lollypop'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001041, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001041, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001041, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001042, 401202001, cd.canonical_dish_id, 'Chicken Malaysian', 'chicken malaysian', 401202001004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken malaysian'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001042, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001042, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001042, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001043, 401202001, cd.canonical_dish_id, 'Chicken Lemon Grass Paper', 'chicken lemon grass paper', 401202001004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken lemon grass paper'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001043, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001043, variant_id, 350.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001043, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001044, 401202001, cd.canonical_dish_id, 'Roast Chicken With Salad', 'roast chicken with salad', 401202001004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'roast chicken with salad'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001044, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001044, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001044, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001045, 401202001, cd.canonical_dish_id, 'Chicken Black Bean Sauce', 'chicken black bean sauce', 401202001004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken black bean sauce'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001045, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001045, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001045, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001046, 401202001, cd.canonical_dish_id, 'Chicken Hot Garlic Sauce', 'chicken hot garlic sauce', 401202001004, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken hot garlic sauce'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001046, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001046, variant_id, 310.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001046, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001047, 401202001, cd.canonical_dish_id, 'Prawns Chilly', 'prawns chilly', 401202001004, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns chilly'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001047, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001047, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001047, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001048, 401202001, cd.canonical_dish_id, 'Prawns Manchurian', 'prawns manchurian', 401202001004, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns manchurian'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001048, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001048, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001048, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001049, 401202001, cd.canonical_dish_id, 'Prawns Schezwan', 'prawns schezwan', 401202001004, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns schezwan'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001049, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001049, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001049, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001050, 401202001, cd.canonical_dish_id, 'Prawns Butter Garlic', 'prawns butter garlic', 401202001004, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns butter garlic'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001050, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001050, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001050, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001051, 401202001, cd.canonical_dish_id, 'Prawns Spring Roll', 'prawns spring roll', 401202001004, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns spring roll'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001051, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001051, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001051, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001052, 401202001, cd.canonical_dish_id, 'Fish Chilly', 'fish chilly', 401202001004, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fish chilly'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001052, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001052, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001052, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001053, 401202001, cd.canonical_dish_id, 'Fish Schezwan', 'fish schezwan', 401202001004, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fish schezwan'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001053, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001053, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001053, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Starters (Non-Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001054, 401202001, cd.canonical_dish_id, 'Fish Schezwan Finger', 'fish schezwan finger', 401202001004, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fish schezwan finger'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001054, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001054, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001054, 401202001, 401202001001, menu_item_id, 401202001004 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001055, 401202001, cd.canonical_dish_id, 'Dhuri Special Veg Fried Rice', 'dhuri special veg fried rice', 401202001005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dhuri special veg fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001055, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001055, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001055, 401202001, 401202001001, menu_item_id, 401202001005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001056, 401202001, cd.canonical_dish_id, 'Fried Rice', 'fried rice', 401202001005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001056, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001056, variant_id, 210.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001056, 401202001, 401202001001, menu_item_id, 401202001005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001057, 401202001, cd.canonical_dish_id, 'Schezwan Fried Rice', 'schezwan fried rice', 401202001005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'schezwan fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001057, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001057, variant_id, 240.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001057, 401202001, 401202001001, menu_item_id, 401202001005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001058, 401202001, cd.canonical_dish_id, 'Tripple Schezwan Fried Rice', 'tripple schezwan fried rice', 401202001005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tripple schezwan fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001058, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001058, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001058, 401202001, 401202001001, menu_item_id, 401202001005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001059, 401202001, cd.canonical_dish_id, 'Singapore Fried Rice', 'singapore fried rice', 401202001005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'singapore fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001059, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001059, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001059, 401202001, 401202001001, menu_item_id, 401202001005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001060, 401202001, cd.canonical_dish_id, 'Hongkong Fried Rice', 'hongkong fried rice', 401202001005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hongkong fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001060, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001060, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001060, 401202001, 401202001001, menu_item_id, 401202001005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001061, 401202001, cd.canonical_dish_id, 'Mushroom Fried Rice', 'mushroom fried rice', 401202001005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001061, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001061, variant_id, 220.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001061, 401202001, 401202001001, menu_item_id, 401202001005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001062, 401202001, cd.canonical_dish_id, 'Hakka Noodles', 'hakka noodles', 401202001005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'hakka noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001062, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001062, variant_id, 230.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001062, 401202001, 401202001001, menu_item_id, 401202001005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001063, 401202001, cd.canonical_dish_id, 'Schezwan Noodles', 'schezwan noodles', 401202001005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'schezwan noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001063, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001063, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001063, 401202001, 401202001001, menu_item_id, 401202001005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001064, 401202001, cd.canonical_dish_id, 'Ginger Chilly Noodles (Spicy)', 'ginger chilly noodles (spicy)', 401202001005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'ginger chilly noodles (spicy)'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001064, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001064, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001064, 401202001, 401202001001, menu_item_id, 401202001005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001065, 401202001, cd.canonical_dish_id, 'Pan Fried Noodles', 'pan fried noodles', 401202001005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pan fried noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001065, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001065, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001065, 401202001, 401202001001, menu_item_id, 401202001005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001066, 401202001, cd.canonical_dish_id, 'Malaysian Noodles', 'malaysian noodles', 401202001005, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'malaysian noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001066, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001066, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001066, 401202001, 401202001001, menu_item_id, 401202001005 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001067, 401202001, cd.canonical_dish_id, 'Dhuri Special Chicken Fried Rice', 'dhuri special chicken fried rice', 401202001006, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dhuri special chicken fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001067, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001067, variant_id, 320.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001067, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001068, 401202001, cd.canonical_dish_id, 'Chicken Fried Rice', 'chicken fried rice', 401202001006, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001068, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001068, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001068, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001069, 401202001, cd.canonical_dish_id, 'Chicken Schz Fried Rice', 'chicken schz fried rice', 401202001006, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken schz fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001069, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001069, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001069, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001070, 401202001, cd.canonical_dish_id, 'Chicken Trip Sez Fried Rice', 'chicken trip sez fried rice', 401202001006, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken trip sez fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001070, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001070, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001070, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001071, 401202001, cd.canonical_dish_id, 'Chicken Singapore Fried Rice', 'chicken singapore fried rice', 401202001006, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken singapore fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001071, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001071, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001071, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001072, 401202001, cd.canonical_dish_id, 'Chicken Hongkong Fried Rice', 'chicken hongkong fried rice', 401202001006, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken hongkong fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001072, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001072, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001072, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001073, 401202001, cd.canonical_dish_id, 'Chicken Thai Pot Rice', 'chicken thai pot rice', 401202001006, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken thai pot rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001073, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001073, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001073, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001074, 401202001, cd.canonical_dish_id, 'Prawns Fried Rice', 'prawns fried rice', 401202001006, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001074, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001074, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001074, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001075, 401202001, cd.canonical_dish_id, 'Prawns Schezwan Fried Rice', 'prawns schezwan fried rice', 401202001006, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns schezwan fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001075, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001075, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001075, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001076, 401202001, cd.canonical_dish_id, 'Egg Fried Rice', 'egg fried rice', 401202001006, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001076, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001076, variant_id, 200.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001076, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001077, 401202001, cd.canonical_dish_id, 'Egg Schezwan Fried Rice', 'egg schezwan fried rice', 401202001006, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg schezwan fried rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001077, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001077, variant_id, 230.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001077, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001078, 401202001, cd.canonical_dish_id, 'Chicken Hakka Noodles', 'chicken hakka noodles', 401202001006, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken hakka noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001078, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001078, variant_id, 240.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001078, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001079, 401202001, cd.canonical_dish_id, 'Chicken Schezwan Noodles', 'chicken schezwan noodles', 401202001006, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken schezwan noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001079, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001079, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001079, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001080, 401202001, cd.canonical_dish_id, 'Chicken Malaysian Noodles', 'chicken malaysian noodles', 401202001006, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken malaysian noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001080, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001080, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001080, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001081, 401202001, cd.canonical_dish_id, 'Chicken Pan Fried Noodles', 'chicken pan fried noodles', 401202001006, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken pan fried noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001081, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001081, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001081, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001082, 401202001, cd.canonical_dish_id, 'Prawns Hakka Noodles', 'prawns hakka noodles', 401202001006, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns hakka noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001082, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001082, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001082, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice & Noodles (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001083, 401202001, cd.canonical_dish_id, 'Prawns Schz Hakka Noodles', 'prawns schz hakka noodles', 401202001006, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns schz hakka noodles'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001083, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001083, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001083, 401202001, 401202001001, menu_item_id, 401202001006 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001084, 401202001, cd.canonical_dish_id, 'Chicken Tandoori', 'chicken tandoori', 401202001007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tandoori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001084, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001084, variant_id, 380.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001085, menu_item_id, 'Half', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001085, variant_id, 220.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001084, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1 UNION ALL SELECT price_id FROM new_price_2) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001085, 401202001, cd.canonical_dish_id, 'Tandoori Schezwan', 'tandoori schezwan', 401202001007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'tandoori schezwan'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001086, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001086, variant_id, 430.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001087, menu_item_id, 'Half', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001087, variant_id, 240.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001085, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1 UNION ALL SELECT price_id FROM new_price_2) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001086, 401202001, cd.canonical_dish_id, 'Chicken Reshmi Kabab', 'chicken reshmi kabab', 401202001007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken reshmi kabab'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001088, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001088, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001086, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001087, 401202001, cd.canonical_dish_id, 'Chicken Seekh Kabab', 'chicken seekh kabab', 401202001007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken seekh kabab'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001089, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001089, variant_id, 280.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001087, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001088, 401202001, cd.canonical_dish_id, 'Chicken Tangdi Kabab', 'chicken tangdi kabab', 401202001007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tangdi kabab'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001090, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001090, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001088, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001089, 401202001, cd.canonical_dish_id, 'Chicken Rosali Kabab', 'chicken rosali kabab', 401202001007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken rosali kabab'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001091, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001091, variant_id, 340.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001089, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001090, 401202001, cd.canonical_dish_id, 'Chicken Achari Kabab', 'chicken achari kabab', 401202001007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken achari kabab'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001092, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001092, variant_id, 280.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001090, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001091, 401202001, cd.canonical_dish_id, 'Chicken Pahadi Kabab', 'chicken pahadi kabab', 401202001007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken pahadi kabab'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001093, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001093, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001091, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001092, 401202001, cd.canonical_dish_id, 'Chicken Chatpata Kabab', 'chicken chatpata kabab', 401202001007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken chatpata kabab'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001094, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001094, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001092, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001093, 401202001, cd.canonical_dish_id, 'Chicken Tikka', 'chicken tikka', 401202001007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tikka'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001095, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001095, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001093, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001094, 401202001, cd.canonical_dish_id, 'Chicken Lollypop Tandoori', 'chicken lollypop tandoori', 401202001007, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken lollypop tandoori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001096, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001096, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001094, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001095, 401202001, cd.canonical_dish_id, 'Veg Seekh Kabab', 'veg seekh kabab', 401202001007, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg seekh kabab'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001097, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001097, variant_id, 240.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001095, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001096, 401202001, cd.canonical_dish_id, 'Paneer Tikka', 'paneer tikka', 401202001007, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer tikka'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001098, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001098, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001096, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001097, 401202001, cd.canonical_dish_id, 'Paneer Hariyali Tikka', 'paneer hariyali tikka', 401202001007, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer hariyali tikka'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001099, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001099, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001097, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001098, 401202001, cd.canonical_dish_id, 'Mushroom Tandoori', 'mushroom tandoori', 401202001007, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom tandoori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001100, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001100, variant_id, 240.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001098, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Tandoori Starters" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001099, 401202001, cd.canonical_dish_id, 'Baby Corn Tandoori', 'baby corn tandoori', 401202001007, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'baby corn tandoori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001101, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001101, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001099, 401202001, 401202001001, menu_item_id, 401202001007 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001100, 401202001, cd.canonical_dish_id, 'Veg Bhuna Masala', 'veg bhuna masala', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg bhuna masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001102, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001102, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001100, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001101, 401202001, cd.canonical_dish_id, 'Veg Hydrabadi', 'veg hydrabadi', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg hydrabadi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001103, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001103, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001101, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001102, 401202001, cd.canonical_dish_id, 'Veg Diwani Handi', 'veg diwani handi', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg diwani handi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001104, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001104, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001102, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001103, 401202001, cd.canonical_dish_id, 'Veg Maharaja', 'veg maharaja', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg maharaja'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001105, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001105, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001103, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001104, 401202001, cd.canonical_dish_id, 'Veg Delight', 'veg delight', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg delight'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001106, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001106, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001104, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001105, 401202001, cd.canonical_dish_id, 'Veg Maratha', 'veg maratha', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg maratha'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001107, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001107, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001105, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001106, 401202001, cd.canonical_dish_id, 'Veg Zill Mill', 'veg zill mill', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg zill mill'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001108, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001108, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001106, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001107, 401202001, cd.canonical_dish_id, 'Veg Makhanwala', 'veg makhanwala', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg makhanwala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001109, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001109, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001107, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001108, 401202001, cd.canonical_dish_id, 'Veg Handi', 'veg handi', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg handi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001110, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001110, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001108, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001109, 401202001, cd.canonical_dish_id, 'Veg Chilli Milli', 'veg chilli milli', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg chilli milli'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001111, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001111, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001109, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001110, 401202001, cd.canonical_dish_id, 'Veg Jalfrazi', 'veg jalfrazi', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg jalfrazi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001112, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001112, variant_id, 280.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001110, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001111, 401202001, cd.canonical_dish_id, 'Veg Kolhapuri', 'veg kolhapuri', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg kolhapuri'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001113, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001113, variant_id, 280.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001111, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001112, 401202001, cd.canonical_dish_id, 'Veg Kadai', 'veg kadai', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg kadai'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001114, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001114, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001112, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001113, 401202001, cd.canonical_dish_id, 'Veg Kofta', 'veg kofta', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg kofta'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001115, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001115, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001113, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001114, 401202001, cd.canonical_dish_id, 'Veg Makhmali', 'veg makhmali', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg makhmali'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001116, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001116, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001114, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001115, 401202001, cd.canonical_dish_id, 'Veg Banjara', 'veg banjara', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg banjara'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001117, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001117, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001115, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001116, 401202001, cd.canonical_dish_id, 'Veg Kheema', 'veg kheema', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg kheema'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001118, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001118, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001116, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001117, 401202001, cd.canonical_dish_id, 'Veg Chatpata', 'veg chatpata', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg chatpata'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001119, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001119, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001117, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001118, 401202001, cd.canonical_dish_id, 'Veg Dilruba', 'veg dilruba', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg dilruba'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001120, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001120, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001118, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001119, 401202001, cd.canonical_dish_id, 'Alu Palak', 'alu palak', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'alu palak'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001121, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001121, variant_id, 190.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001119, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001120, 401202001, cd.canonical_dish_id, 'Alu Jeera', 'alu jeera', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'alu jeera'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001122, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001122, variant_id, 190.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001120, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001121, 401202001, cd.canonical_dish_id, 'Alu Methi', 'alu methi', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'alu methi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001123, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001123, variant_id, 180.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001121, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001122, 401202001, cd.canonical_dish_id, 'Alu Mutter', 'alu mutter', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'alu mutter'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001124, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001124, variant_id, 180.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001122, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001123, 401202001, cd.canonical_dish_id, 'Chana Masala', 'chana masala', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chana masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001125, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001125, variant_id, 190.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001123, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001124, 401202001, cd.canonical_dish_id, 'Navratan Korma', 'navratan korma', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'navratan korma'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001126, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001126, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001124, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001125, 401202001, cd.canonical_dish_id, 'Methi Mutter Masala', 'methi mutter masala', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'methi mutter masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001127, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001127, variant_id, 280.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001125, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001126, 401202001, cd.canonical_dish_id, 'Methi Malai Mutter', 'methi malai mutter', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'methi malai mutter'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001128, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001128, variant_id, 280.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001126, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001127, 401202001, cd.canonical_dish_id, 'Green Peas Masala', 'green peas masala', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'green peas masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001129, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001129, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001127, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001128, 401202001, cd.canonical_dish_id, 'Baingan Bharta', 'baingan bharta', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'baingan bharta'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001130, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001130, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001128, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001129, 401202001, cd.canonical_dish_id, 'Baingan Masala', 'baingan masala', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'baingan masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001131, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001131, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001129, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001130, 401202001, cd.canonical_dish_id, 'Mushroom Masala', 'mushroom masala', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001132, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001132, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001130, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001131, 401202001, cd.canonical_dish_id, 'Mushroom Mutter Masala', 'mushroom mutter masala', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mushroom mutter masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001133, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001133, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001131, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001132, 401202001, cd.canonical_dish_id, 'Baby Corn Masala', 'baby corn masala', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'baby corn masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001134, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001134, variant_id, 280.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001132, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001133, 401202001, cd.canonical_dish_id, 'Baby Corn Paneer Masala', 'baby corn paneer masala', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'baby corn paneer masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001135, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001135, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001133, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001134, 401202001, cd.canonical_dish_id, 'Baby Corn Mushroom Masala', 'baby corn mushroom masala', 401202001008, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'baby corn mushroom masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001136, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001136, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001134, 401202001, 401202001001, menu_item_id, 401202001008 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Paneer" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001135, 401202001, cd.canonical_dish_id, 'Paneer Butter Masala', 'paneer butter masala', 401202001009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer butter masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001137, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001137, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001135, 401202001, 401202001001, menu_item_id, 401202001009 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Paneer" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001136, 401202001, cd.canonical_dish_id, 'Paneer Tikka Masala', 'paneer tikka masala', 401202001009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer tikka masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001138, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001138, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001136, 401202001, 401202001001, menu_item_id, 401202001009 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Paneer" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001137, 401202001, cd.canonical_dish_id, 'Paneer Delight', 'paneer delight', 401202001009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer delight'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001139, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001139, variant_id, 280.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001137, 401202001, 401202001001, menu_item_id, 401202001009 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Paneer" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001138, 401202001, cd.canonical_dish_id, 'Paneer Lahori', 'paneer lahori', 401202001009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer lahori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001140, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001140, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001138, 401202001, 401202001001, menu_item_id, 401202001009 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Paneer" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001139, 401202001, cd.canonical_dish_id, 'Paneer Lapeta', 'paneer lapeta', 401202001009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer lapeta'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001141, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001141, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001139, 401202001, 401202001001, menu_item_id, 401202001009 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Paneer" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001140, 401202001, cd.canonical_dish_id, 'Paneer Hariyali Tikka Masala', 'paneer hariyali tikka masala', 401202001009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer hariyali tikka masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001142, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001142, variant_id, 280.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001140, 401202001, 401202001001, menu_item_id, 401202001009 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Paneer" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001141, 401202001, cd.canonical_dish_id, 'Paneer Bhurji', 'paneer bhurji', 401202001009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer bhurji'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001143, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001143, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001141, 401202001, 401202001001, menu_item_id, 401202001009 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Paneer" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001142, 401202001, cd.canonical_dish_id, 'Paneer Handi', 'paneer handi', 401202001009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer handi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001144, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001144, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001142, 401202001, 401202001001, menu_item_id, 401202001009 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Paneer" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001143, 401202001, cd.canonical_dish_id, 'Paneer Saagwala', 'paneer saagwala', 401202001009, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer saagwala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001145, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001145, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001143, 401202001, 401202001001, menu_item_id, 401202001009 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001144, 401202001, cd.canonical_dish_id, 'Chicken Handi', 'chicken handi', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken handi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001146, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001146, variant_id, 530.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001147, menu_item_id, 'Half', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001147, variant_id, 310.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001144, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1 UNION ALL SELECT price_id FROM new_price_2) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001145, 401202001, cd.canonical_dish_id, 'Murg Musallam', 'murg musallam', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'murg musallam'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001148, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001148, variant_id, 680.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001149, menu_item_id, 'Half', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001149, variant_id, 420.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001145, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1 UNION ALL SELECT price_id FROM new_price_2) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001146, 401202001, cd.canonical_dish_id, 'Chicken Tikka Masala', 'chicken tikka masala', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tikka masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001150, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001150, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001146, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001147, 401202001, cd.canonical_dish_id, 'Chicken Pahadi Tikka Masala', 'chicken pahadi tikka masala', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken pahadi tikka masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001151, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001151, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001147, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001148, 401202001, cd.canonical_dish_id, 'Chicken Hyderabadi', 'chicken hyderabadi', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken hyderabadi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001152, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001152, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001148, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001149, 401202001, cd.canonical_dish_id, 'Chicken Patiala', 'chicken patiala', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken patiala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001153, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001153, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001149, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001150, 401202001, cd.canonical_dish_id, 'Chicken Moghlai', 'chicken moghlai', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken moghlai'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001154, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001154, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001150, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001151, 401202001, cd.canonical_dish_id, 'Chicken Lazeez', 'chicken lazeez', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken lazeez'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001155, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001155, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001151, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001152, 401202001, cd.canonical_dish_id, 'Chicken Lahori', 'chicken lahori', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken lahori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001156, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001156, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001152, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001153, 401202001, cd.canonical_dish_id, 'Chicken Kolhapuri', 'chicken kolhapuri', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken kolhapuri'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001157, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001157, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001153, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001154, 401202001, cd.canonical_dish_id, 'Chicken Lapeta', 'chicken lapeta', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken lapeta'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001158, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001158, variant_id, 360.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001154, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001155, 401202001, cd.canonical_dish_id, 'Chicken Peshwari', 'chicken peshwari', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken peshwari'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001159, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001159, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001155, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001156, 401202001, cd.canonical_dish_id, 'Chicken Amritshari', 'chicken amritshari', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken amritshari'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001160, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001160, variant_id, 320.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001156, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001157, 401202001, cd.canonical_dish_id, 'Murg Chaap Nargisi', 'murg chaap nargisi', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'murg chaap nargisi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001161, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001161, variant_id, 310.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001157, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001158, 401202001, cd.canonical_dish_id, 'Chicken Kadai', 'chicken kadai', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken kadai'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001162, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001162, variant_id, 280.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001158, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001159, 401202001, cd.canonical_dish_id, 'Chicken Masala', 'chicken masala', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001163, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001163, variant_id, 270.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001159, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001160, 401202001, cd.canonical_dish_id, 'Chicken Rara', 'chicken rara', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken rara'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001164, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001164, variant_id, 320.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001160, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001161, 401202001, cd.canonical_dish_id, 'Chicken Angara', 'chicken angara', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken angara'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001165, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001165, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001161, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001162, 401202001, cd.canonical_dish_id, 'Butter Chicken', 'butter chicken', 401202001010, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter chicken'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001166, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001166, variant_id, 520.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001167, menu_item_id, 'Half', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001167, variant_id, 300.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001162, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1 UNION ALL SELECT price_id FROM new_price_2) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001163, 401202001, cd.canonical_dish_id, 'Mutton Handi', 'mutton handi', 401202001010, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton handi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001168, menu_item_id, 'Full', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001168, variant_id, 870.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001169, menu_item_id, 'Half', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001169, variant_id, 480.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001163, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1 UNION ALL SELECT price_id FROM new_price_2) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001164, 401202001, cd.canonical_dish_id, 'Mutton Roganjosh', 'mutton roganjosh', 401202001010, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton roganjosh'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001170, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001170, variant_id, 410.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001164, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001165, 401202001, cd.canonical_dish_id, 'Mutton Kolhapuri', 'mutton kolhapuri', 401202001010, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton kolhapuri'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001171, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001171, variant_id, 410.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001165, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001166, 401202001, cd.canonical_dish_id, 'Mutton Masala', 'mutton masala', 401202001010, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001172, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001172, variant_id, 410.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001166, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001167, 401202001, cd.canonical_dish_id, 'Mutton Sukha', 'mutton sukha', 401202001010, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton sukha'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001173, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001173, variant_id, 410.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001167, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001168, 401202001, cd.canonical_dish_id, 'Mutton Rara', 'mutton rara', 401202001010, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton rara'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001174, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001174, variant_id, 410.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001168, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001169, 401202001, cd.canonical_dish_id, 'Mutton Hydrabadi', 'mutton hydrabadi', 401202001010, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton hydrabadi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001175, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001175, variant_id, 410.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001169, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001170, 401202001, cd.canonical_dish_id, 'Mutton Kheema', 'mutton kheema', 401202001010, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton kheema'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001176, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001176, variant_id, 410.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001170, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001171, 401202001, cd.canonical_dish_id, 'Egg Masala', 'egg masala', 401202001010, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001177, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001177, variant_id, 220.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001171, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001172, 401202001, cd.canonical_dish_id, 'Egg Omlet', 'egg omlet', 401202001010, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg omlet'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001178, menu_item_id, 'Plain', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001178, variant_id, 80.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_variant_2 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001179, menu_item_id, 'Masala', 'fixed', FALSE FROM new_item
  RETURNING variant_id
),
new_price_2 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001179, variant_id, 120.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_2
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001172, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1 UNION ALL SELECT price_id FROM new_price_2) AS ps;

-- Source: docx, "Main Course (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001173, 401202001, cd.canonical_dish_id, 'Egg Bhurji', 'egg bhurji', 401202001010, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg bhurji'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001180, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001180, variant_id, 100.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001173, 401202001, 401202001001, menu_item_id, 401202001010 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Dal" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001174, 401202001, cd.canonical_dish_id, 'Dal Fry', 'dal fry', 401202001011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal fry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001181, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001181, variant_id, 150.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001174, 401202001, 401202001001, menu_item_id, 401202001011 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Dal" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001175, 401202001, cd.canonical_dish_id, 'Dal Tadka', 'dal tadka', 401202001011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal tadka'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001182, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001182, variant_id, 180.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001175, 401202001, 401202001001, menu_item_id, 401202001011 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Dal" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001176, 401202001, cd.canonical_dish_id, 'Dal Palak', 'dal palak', 401202001011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal palak'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001183, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001183, variant_id, 180.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001176, 401202001, 401202001001, menu_item_id, 401202001011 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Dal" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001177, 401202001, cd.canonical_dish_id, 'Dal Methi', 'dal methi', 401202001011, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal methi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001184, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001184, variant_id, 180.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001177, 401202001, 401202001001, menu_item_id, 401202001011 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sea Food" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001178, 401202001, cd.canonical_dish_id, 'Pomfret Fry', 'pomfret fry', 401202001012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pomfret fry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001185, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001185, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001178, 401202001, 401202001001, menu_item_id, 401202001012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sea Food" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001179, 401202001, cd.canonical_dish_id, 'Pomfret Masala', 'pomfret masala', 401202001012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pomfret masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001186, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001186, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001179, 401202001, 401202001001, menu_item_id, 401202001012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sea Food" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001180, 401202001, cd.canonical_dish_id, 'Surmai Fry', 'surmai fry', 401202001012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'surmai fry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001187, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001187, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001180, 401202001, 401202001001, menu_item_id, 401202001012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sea Food" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001181, 401202001, cd.canonical_dish_id, 'Surmai Masala', 'surmai masala', 401202001012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'surmai masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001188, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001188, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001181, 401202001, 401202001001, menu_item_id, 401202001012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sea Food" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001182, 401202001, cd.canonical_dish_id, 'Prawns Masala', 'prawns masala', 401202001012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001189, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001189, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001182, 401202001, 401202001001, menu_item_id, 401202001012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sea Food" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001183, 401202001, cd.canonical_dish_id, 'Prawns Koliwada', 'prawns koliwada', 401202001012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns koliwada'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001190, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001190, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001183, 401202001, 401202001001, menu_item_id, 401202001012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sea Food" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001184, 401202001, cd.canonical_dish_id, 'Rawas Fry', 'rawas fry', 401202001012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rawas fry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001191, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001191, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001184, 401202001, 401202001001, menu_item_id, 401202001012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sea Food" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001185, 401202001, cd.canonical_dish_id, 'Rawas Masala', 'rawas masala', 401202001012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'rawas masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001192, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001192, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001185, 401202001, 401202001001, menu_item_id, 401202001012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sea Food" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001186, 401202001, cd.canonical_dish_id, 'Bangda Fry', 'bangda fry', 401202001012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bangda fry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001193, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001193, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001186, 401202001, 401202001001, menu_item_id, 401202001012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sea Food" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001187, 401202001, cd.canonical_dish_id, 'Bangda Masala', 'bangda masala', 401202001012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'bangda masala'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001194, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001194, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001187, 401202001, 401202001001, menu_item_id, 401202001012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sea Food" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001188, 401202001, cd.canonical_dish_id, 'Pomfret Tandoori', 'pomfret tandoori', 401202001012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pomfret tandoori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001195, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001195, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001188, 401202001, 401202001001, menu_item_id, 401202001012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sea Food" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001189, 401202001, cd.canonical_dish_id, 'Fish Tandoori', 'fish tandoori', 401202001012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fish tandoori'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001196, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001196, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001189, 401202001, 401202001001, menu_item_id, 401202001012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sea Food" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001190, 401202001, cd.canonical_dish_id, 'Fish Goan Curry', 'fish goan curry', 401202001012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fish goan curry'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001197, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001197, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001190, 401202001, 401202001001, menu_item_id, 401202001012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sea Food" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001191, 401202001, cd.canonical_dish_id, 'Seafood Platter', 'seafood platter', 401202001012, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'seafood platter'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001198, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001198, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001191, 401202001, 401202001001, menu_item_id, 401202001012 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Indian Bread" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001192, 401202001, cd.canonical_dish_id, 'Roti', 'roti', 401202001013, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'roti'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001199, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001199, variant_id, 30.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001192, 401202001, 401202001001, menu_item_id, 401202001013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Indian Bread" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001193, 401202001, cd.canonical_dish_id, 'Butter Roti', 'butter roti', 401202001013, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter roti'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001200, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001200, variant_id, 40.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001193, 401202001, 401202001001, menu_item_id, 401202001013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Indian Bread" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001194, 401202001, cd.canonical_dish_id, 'Naan', 'naan', 401202001013, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'naan'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001201, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001201, variant_id, 40.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001194, 401202001, 401202001001, menu_item_id, 401202001013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Indian Bread" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001195, 401202001, cd.canonical_dish_id, 'Butter Naan', 'butter naan', 401202001013, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter naan'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001202, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001202, variant_id, 50.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001195, 401202001, 401202001001, menu_item_id, 401202001013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Indian Bread" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001196, 401202001, cd.canonical_dish_id, 'Kulcha', 'kulcha', 401202001013, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'kulcha'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001203, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001203, variant_id, 35.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001196, 401202001, 401202001001, menu_item_id, 401202001013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Indian Bread" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001197, 401202001, cd.canonical_dish_id, 'Butter Kulcha', 'butter kulcha', 401202001013, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'butter kulcha'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001204, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001204, variant_id, 45.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001197, 401202001, 401202001001, menu_item_id, 401202001013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Indian Bread" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001198, 401202001, cd.canonical_dish_id, 'Paratha', 'paratha', 401202001013, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paratha'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001205, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001205, variant_id, 40.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001198, 401202001, 401202001001, menu_item_id, 401202001013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Indian Bread" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001199, 401202001, cd.canonical_dish_id, 'Stuffed Paratha', 'stuffed paratha', 401202001013, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'stuffed paratha'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001206, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001206, variant_id, 100.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001199, 401202001, 401202001001, menu_item_id, 401202001013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Indian Bread" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001200, 401202001, cd.canonical_dish_id, 'Garlic Naan', 'garlic naan', 401202001013, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'garlic naan'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001207, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001207, variant_id, 80.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001200, 401202001, 401202001001, menu_item_id, 401202001013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Indian Bread" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001201, 401202001, cd.canonical_dish_id, 'Stuff Kulcha', 'stuff kulcha', 401202001013, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'stuff kulcha'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001208, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001208, variant_id, 100.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001201, 401202001, 401202001001, menu_item_id, 401202001013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Indian Bread" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001202, 401202001, cd.canonical_dish_id, 'Extra Cheese', 'extra cheese', 401202001013, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'extra cheese'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001209, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001209, variant_id, 30.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001202, 401202001, 401202001001, menu_item_id, 401202001013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Indian Bread" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001203, 401202001, cd.canonical_dish_id, 'Extra Butter', 'extra butter', 401202001013, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'extra butter'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001210, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001210, variant_id, 10.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001203, 401202001, 401202001001, menu_item_id, 401202001013 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Salad / Raita" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001204, 401202001, cd.canonical_dish_id, 'Green Salad', 'green salad', 401202001014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'green salad'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001211, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001211, variant_id, 80.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001204, 401202001, 401202001001, menu_item_id, 401202001014 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Salad / Raita" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001205, 401202001, cd.canonical_dish_id, 'Russian Salad', 'russian salad', 401202001014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'russian salad'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001212, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001212, variant_id, 150.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001205, 401202001, 401202001001, menu_item_id, 401202001014 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Salad / Raita" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001206, 401202001, cd.canonical_dish_id, 'Non Veg Russian Salad', 'non veg russian salad', 401202001014, 'non_veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'non veg russian salad'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001213, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001213, variant_id, 220.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001206, 401202001, 401202001001, menu_item_id, 401202001014 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Salad / Raita" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001207, 401202001, cd.canonical_dish_id, 'Boondi Raita', 'boondi raita', 401202001014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'boondi raita'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001214, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001214, variant_id, 100.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001207, 401202001, 401202001001, menu_item_id, 401202001014 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Salad / Raita" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001208, 401202001, cd.canonical_dish_id, 'Pineapple Raita', 'pineapple raita', 401202001014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'pineapple raita'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001215, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001215, variant_id, 110.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001208, 401202001, 401202001001, menu_item_id, 401202001014 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Salad / Raita" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001209, 401202001, cd.canonical_dish_id, 'Veg Raita', 'veg raita', 401202001014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg raita'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001216, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001216, variant_id, 90.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001209, 401202001, 401202001001, menu_item_id, 401202001014 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Salad / Raita" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001210, 401202001, cd.canonical_dish_id, 'Roasted Papad', 'roasted papad', 401202001014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'roasted papad'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001217, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001217, variant_id, 25.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001210, 401202001, 401202001001, menu_item_id, 401202001014 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Salad / Raita" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001211, 401202001, cd.canonical_dish_id, 'Fry Papad', 'fry papad', 401202001014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'fry papad'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001218, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001218, variant_id, 25.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001211, 401202001, 401202001001, menu_item_id, 401202001014 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Salad / Raita" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001212, 401202001, cd.canonical_dish_id, 'Masala Papad', 'masala papad', 401202001014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'masala papad'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001219, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001219, variant_id, 50.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001212, 401202001, 401202001001, menu_item_id, 401202001014 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Salad / Raita" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001213, 401202001, cd.canonical_dish_id, 'Curd', 'curd', 401202001014, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'curd'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001220, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001220, variant_id, 80.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001213, 401202001, 401202001001, menu_item_id, 401202001014 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Biryani (1 Kg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001214, 401202001, cd.canonical_dish_id, 'Chicken Biryani', 'chicken biryani', 401202001015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001221, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001221, variant_id, 1100.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001214, 401202001, 401202001001, menu_item_id, 401202001015 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Biryani (1 Kg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001215, 401202001, cd.canonical_dish_id, 'Chicken Tikka Biryani', 'chicken tikka biryani', 401202001015, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken tikka biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001222, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001222, variant_id, 1600.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001215, 401202001, 401202001001, menu_item_id, 401202001015 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Biryani (1 Kg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001216, 401202001, cd.canonical_dish_id, 'Mutton Biryani', 'mutton biryani', 401202001015, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001223, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001223, variant_id, 2100.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001216, 401202001, 401202001001, menu_item_id, 401202001015 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Biryani (1 Kg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001217, 401202001, cd.canonical_dish_id, 'Veg Biryani', 'veg biryani', 401202001015, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001224, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001224, variant_id, 750.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001217, 401202001, 401202001001, menu_item_id, 401202001015 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Biryani (1 Kg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001218, 401202001, cd.canonical_dish_id, 'Veg Pulav', 'veg pulav', 401202001015, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg pulav'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001225, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001225, variant_id, 650.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001218, 401202001, 401202001001, menu_item_id, 401202001015 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001219, 401202001, cd.canonical_dish_id, 'Steam Rice', 'steam rice', 401202001016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'steam rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001226, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001226, variant_id, 120.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001219, 401202001, 401202001001, menu_item_id, 401202001016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001220, 401202001, cd.canonical_dish_id, 'Jeera Rice', 'jeera rice', 401202001016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'jeera rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001227, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001227, variant_id, 130.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001220, 401202001, 401202001001, menu_item_id, 401202001016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001221, 401202001, cd.canonical_dish_id, 'Veg Biryani', 'veg biryani', 401202001016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001228, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001228, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001221, 401202001, 401202001001, menu_item_id, 401202001016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001222, 401202001, cd.canonical_dish_id, 'Veg Dum Biryani', 'veg dum biryani', 401202001016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg dum biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001229, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001229, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001222, 401202001, 401202001001, menu_item_id, 401202001016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001223, 401202001, cd.canonical_dish_id, 'Veg Hydrabadi Biryani', 'veg hydrabadi biryani', 401202001016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg hydrabadi biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001230, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001230, variant_id, 280.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001223, 401202001, 401202001001, menu_item_id, 401202001016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001224, 401202001, cd.canonical_dish_id, 'Veg Pulav', 'veg pulav', 401202001016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg pulav'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001231, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001231, variant_id, 210.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001224, 401202001, 401202001001, menu_item_id, 401202001016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001225, 401202001, cd.canonical_dish_id, 'Paneer Pulav', 'paneer pulav', 401202001016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer pulav'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001232, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001232, variant_id, 250.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001225, 401202001, 401202001001, menu_item_id, 401202001016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001226, 401202001, cd.canonical_dish_id, 'Dal Khichdi', 'dal khichdi', 401202001016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal khichdi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001233, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001233, variant_id, 180.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001226, 401202001, 401202001001, menu_item_id, 401202001016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001227, 401202001, cd.canonical_dish_id, 'Palak Khichdi', 'palak khichdi', 401202001016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'palak khichdi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001234, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001234, variant_id, 180.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001227, 401202001, 401202001001, menu_item_id, 401202001016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001228, 401202001, cd.canonical_dish_id, 'Curd Rice', 'curd rice', 401202001016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'curd rice'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001235, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001235, variant_id, 180.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001228, 401202001, 401202001001, menu_item_id, 401202001016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001229, 401202001, cd.canonical_dish_id, 'Dal Palak Khichdi', 'dal palak khichdi', 401202001016, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'dal palak khichdi'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001236, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001236, variant_id, 200.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001229, 401202001, 401202001001, menu_item_id, 401202001016 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001230, 401202001, cd.canonical_dish_id, 'Chicken Biryani', 'chicken biryani', 401202001017, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001237, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001237, variant_id, 290.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001230, 401202001, 401202001001, menu_item_id, 401202001017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001231, 401202001, cd.canonical_dish_id, 'Chicken Dum Biryani', 'chicken dum biryani', 401202001017, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken dum biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001238, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001238, variant_id, 310.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001231, 401202001, 401202001001, menu_item_id, 401202001017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001232, 401202001, cd.canonical_dish_id, 'Chicken Hydrabadi Biryani', 'chicken hydrabadi biryani', 401202001017, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken hydrabadi biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001239, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001239, variant_id, 310.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001232, 401202001, 401202001001, menu_item_id, 401202001017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001233, 401202001, cd.canonical_dish_id, 'Mutton Biryani', 'mutton biryani', 401202001017, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001240, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001240, variant_id, 440.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001233, 401202001, 401202001001, menu_item_id, 401202001017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001234, 401202001, cd.canonical_dish_id, 'Mutton Dum Biryani', 'mutton dum biryani', 401202001017, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton dum biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001241, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001241, variant_id, 440.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001234, 401202001, 401202001001, menu_item_id, 401202001017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001235, 401202001, cd.canonical_dish_id, 'Mutton Hydrabadi Biryani', 'mutton hydrabadi biryani', 401202001017, 'non_veg', 900002, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'mutton hydrabadi biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001242, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001242, variant_id, 440.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001235, 401202001, 401202001001, menu_item_id, 401202001017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001236, 401202001, cd.canonical_dish_id, 'Egg Biryani', 'egg biryani', 401202001017, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'egg biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001243, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001243, variant_id, 260.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001236, 401202001, 401202001001, menu_item_id, 401202001017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001237, 401202001, cd.canonical_dish_id, 'Prawns Biryani', 'prawns biryani', 401202001017, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001244, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001244, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001237, 401202001, 401202001001, menu_item_id, 401202001017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001238, 401202001, cd.canonical_dish_id, 'Prawns Dum Biryani', 'prawns dum biryani', 401202001017, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns dum biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001245, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001245, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001238, 401202001, 401202001001, menu_item_id, 401202001017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Rice (Non Veg)" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001239, 401202001, cd.canonical_dish_id, 'Prawns Hydrabadi Biryani', 'prawns hydrabadi biryani', 401202001017, 'non_veg', 900003, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'prawns hydrabadi biryani'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001246, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001246, variant_id, NULL, TRUE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001239, 401202001, 401202001001, menu_item_id, 401202001017 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sandwich & Pizza" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001240, 401202001, cd.canonical_dish_id, 'Veg Sandwich', 'veg sandwich', 401202001018, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg sandwich'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001247, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001247, variant_id, 90.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001240, 401202001, 401202001001, menu_item_id, 401202001018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sandwich & Pizza" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001241, 401202001, cd.canonical_dish_id, 'Veg Grilled Sandwich', 'veg grilled sandwich', 401202001018, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg grilled sandwich'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001248, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001248, variant_id, 140.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001241, 401202001, 401202001001, menu_item_id, 401202001018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sandwich & Pizza" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001242, 401202001, cd.canonical_dish_id, 'Veg Club Sandwich', 'veg club sandwich', 401202001018, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg club sandwich'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001249, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001249, variant_id, 180.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001242, 401202001, 401202001001, menu_item_id, 401202001018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sandwich & Pizza" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001243, 401202001, cd.canonical_dish_id, 'Veg Cheese Sandwich', 'veg cheese sandwich', 401202001018, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg cheese sandwich'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001250, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001250, variant_id, 110.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001243, 401202001, 401202001001, menu_item_id, 401202001018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sandwich & Pizza" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001244, 401202001, cd.canonical_dish_id, 'Veg Cheese Toast Sandwich', 'veg cheese toast sandwich', 401202001018, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg cheese toast sandwich'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001251, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001251, variant_id, 120.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001244, 401202001, 401202001001, menu_item_id, 401202001018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sandwich & Pizza" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001245, 401202001, cd.canonical_dish_id, 'Veg Cheese Grilled Sandwich', 'veg cheese grilled sandwich', 401202001018, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg cheese grilled sandwich'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001252, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001252, variant_id, 160.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001245, 401202001, 401202001001, menu_item_id, 401202001018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sandwich & Pizza" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001246, 401202001, cd.canonical_dish_id, 'Cheese Chilly Toast', 'cheese chilly toast', 401202001018, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'cheese chilly toast'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001253, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001253, variant_id, 180.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001246, 401202001, 401202001001, menu_item_id, 401202001018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sandwich & Pizza" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001247, 401202001, cd.canonical_dish_id, 'Omlet Sandwich', 'omlet sandwich', 401202001018, 'egg', 920009, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'omlet sandwich'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001254, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001254, variant_id, 150.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001247, 401202001, 401202001001, menu_item_id, 401202001018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sandwich & Pizza" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001248, 401202001, cd.canonical_dish_id, 'Chicken Sandwich', 'chicken sandwich', 401202001018, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chicken sandwich'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001255, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001255, variant_id, 200.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001248, 401202001, 401202001001, menu_item_id, 401202001018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sandwich & Pizza" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001249, 401202001, cd.canonical_dish_id, 'Veg Cheese Pizza', 'veg cheese pizza', 401202001018, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'veg cheese pizza'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001256, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001256, variant_id, 220.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001249, 401202001, 401202001001, menu_item_id, 401202001018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sandwich & Pizza" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001250, 401202001, cd.canonical_dish_id, 'Paneer Tikka Pizza', 'paneer tikka pizza', 401202001018, 'veg', NULL, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'paneer tikka pizza'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001257, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001257, variant_id, 220.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001250, 401202001, 401202001001, menu_item_id, 401202001018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

-- Source: docx, "Sandwich & Pizza" section
WITH new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, name, normalized_name, menu_category_id, food_classification_code, protein_type_id, verification_status_code)
  SELECT 401202001251, 401202001, cd.canonical_dish_id, 'Chi Tikka Pizza', 'chi tikka pizza', 401202001018, 'non_veg', 900001, 'unverified'
  FROM canonical_dish cd WHERE cd.normalized_name = 'chi tikka pizza'
  RETURNING menu_item_id
),
new_variant_1 AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 401202001258, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price_1 AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, is_market_price, tax_regime_code, tax_inclusion_code, tax_rate, effective_from, source_id, verification_status_code)
  SELECT 401202001258, variant_id, 230.00, FALSE, 'GST', 'exclusive', 5.0000, (clock_timestamp() AT TIME ZONE 'UTC'), 401202001001, 'unverified' FROM new_variant_1
  RETURNING price_id
),
new_board_item AS (
  INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id)
  SELECT 401202001251, 401202001, 401202001001, menu_item_id, 401202001018 FROM new_item
  RETURNING menu_item_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT menu_item_id, 401202001001, 401202001001, 0.95, 'unverified' FROM new_item
  RETURNING menu_item_id
)
INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT price_id, 401202001001, 401202001001, 0.9 FROM (SELECT price_id FROM new_price_1) AS ps;

COMMIT;

-- NEEDS_REVIEW: none of the 251 items were flagged needs_review or below 0.8
-- confidence -- the menu prints cleanly (name + numeric price or APS) throughout.
-- The 'X / Y <price>' shared-price convention is common enough on this menu that
-- it's treated as standard notation (see earlier version's header note), not
-- itemized here.

-- UNMAPPED:
--  - "Rates are subject to change" / "Order once placed can not be canceled" --
--    blanket printed disclaimers, no per-item or per-restaurant column fits either.
--  - Event-hosting capability (birthday/engagement/kitty-party/corporate events,
--    terrace party) is folded into restaurant.description and noted on the
--    bulk_catering service-mode row, since there's no dedicated events/banquet table.
--  - "FINE DINE & BANQUET" / "FAST FOOD" / "TERRACE PARTY" as separate named
--    concepts under one venue -- the schema has no sub-venue/concept table, so
--    these are folded into one restaurant row rather than split into several.
--  - Bar is asserted (has_bar = TRUE, bar_license_type = 'full_bar' as the closest
--    match to "RESTAURANT & BAR") but no bar_product/menu_item exists to attach --
--    bar_license_type is a guess at which of the schema's allowed values fits
--    "& BAR" with no further detail printed; confirm against the actual license.

-- Summary: 1 restaurant, 18 categories, 1 menu board, 251 menu items, 
-- 258 variants, 258 prices (25 market-priced), 247 canonical dishes.