-- =============================================================================
-- Khaustan onboarding script: Campus Veg Treat
-- Source: Campus_Veg_Treat_Menu_Transcribed.docx (docx, tab-separated paragraphs)
-- Schema: khaustan-full-platform-postgresql.sql, database "KhaustanRestaurantMenu"
-- Built with the same schema-validated pipeline used for Hanuman Veg. Treat:
--   every INSERT's column list below was checked programmatically against
--   the real DDL (table exists, every column exists, every NOT NULL column
--   with no default is present) before this file was written.
-- No psql meta-commands or client-side ":variable" binds anywhere -- this
-- runs as plain SQL in pgAdmin4, psql, or any other Postgres client.
-- Ensure your client is connected to "KhaustanRestaurantMenu" before running.
--
-- CRITICAL FIX this round: every plain item's last CTE (item_src) ended
-- with a trailing comma immediately before the final, non-CTE
-- "INSERT INTO menu_item_price_source" statement. A comma there is only
-- valid if another named CTE follows -- "INSERT" can't serve as one, being
-- a reserved word -- so this was a real syntax error on every plain item
-- in every one of the four files. Fixed: the comma is now only emitted
-- when a menu_item_availability block genuinely follows.
--
-- ID CONVENTION (per your instruction): establishment_id and restaurant_id
-- are the exact hardcoded values you gave. Every other ID this script
-- creates is <restaurant_id><counter:03d> -- a SEPARATE counter per table
-- (menu_item_id, variant_id, price_id, availability_id, menu_category_id,
-- etc. each start over at 001 for this restaurant) -- computed in Python
-- and embedded as a literal; no CREATE SEQUENCE / nextval() anywhere.
-- Lookup-table IDs (protein_type, service_mode, delivery_provider,
-- platform_tag, price_schedule) are UNCHANGED by this scheme -- those
-- already have their own real, fixed IDs in your database.
--
-- NEW THIS ROUND: menu_category and menu_board (+ menu_board_category,
-- menu_board_item) are now populated -- previously skipped in favour of
-- raw_category_text alone. See the UNMAPPED notes for the choices made
-- (flat categories, one board named "Main Menu").
--
-- LOOKUP-DATA DEPENDENCY: this script assumes protein_type, service_mode,
-- delivery_provider, and platform_tag already contain the rows you supplied.
--
-- TESTING PERFORMED: no live Postgres server is available in this build
-- environment. Every INSERT column list was checked against a parsed model
-- of your actual DDL, and -- following last round's lesson that paren/quote
-- balance alone isn't sufficient -- every CTE chain's comma placement was
-- traced by hand against the WITH-clause grammar (a named CTE needs a
-- trailing comma only when another named CTE follows it; the final
-- statement never has one before it) and confirmed programmatically by
-- reconstructing and checking every chain's comma/CTE-name sequence.
-- Please still run this against a staging database first.
-- =============================================================================

-- Ensure your pgAdmin4 Query Tool (or other client) is connected to the
-- "KhaustanRestaurantMenu" database before running this script.
--\connect "KhaustanRestaurantMenu"

BEGIN;

CREATE TEMP TABLE khaustan_onboarding_ctx (
  restaurant_id       BIGINT,
  source_id           BIGINT,
  extraction_batch_id BIGINT
) ON COMMIT DROP;
INSERT INTO khaustan_onboarding_ctx DEFAULT VALUES;

DO $do$
DECLARE
  v_establishment_id BIGINT;
  v_restaurant_id    BIGINT;
BEGIN
  SELECT establishment_id INTO v_establishment_id FROM establishment
  WHERE normalized_name = lower(trim('Campus Veg Treat')) AND postal_code = '400081';

  IF NOT FOUND THEN
    v_establishment_id := 400081001;
    INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, locality, postal_code, city, state, country_code, latitude, longitude)
    VALUES (v_establishment_id, 'Campus Veg Treat', lower(trim('Campus Veg Treat')), '90 Ft. Cross Rd.', 'Mulund (E)', '400081', 'Mumbai', 'Maharashtra', 'IN', 19.168131884203266, 72.96102640683671);
  END IF;

  SELECT restaurant_id INTO v_restaurant_id FROM restaurant
  WHERE establishment_id = v_establishment_id AND display_name = 'Campus Veg Treat';

  IF NOT FOUND THEN
    v_restaurant_id := 400081001;
    INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name, has_bar, bar_license_type, veg_nonveg_status)
    VALUES (v_restaurant_id, v_establishment_id, 'Campus Veg Treat', lower(trim('Campus Veg Treat')), FALSE, 'none', 'pure_veg');
  END IF;

  UPDATE khaustan_onboarding_ctx SET restaurant_id = v_restaurant_id;
END $do$;

DO $do$
DECLARE
  v_already_processed BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM menu_extraction_batch
    WHERE restaurant_id = (SELECT restaurant_id FROM khaustan_onboarding_ctx)
      AND source_id IN (SELECT source_id FROM source_record WHERE source_uri = 'Campus_Veg_Treat_Menu_Transcribed.docx')
      AND status_code = 'completed'
  ) INTO v_already_processed;

  IF v_already_processed THEN
    RAISE EXCEPTION 'Khaustan onboarding: % has already been fully processed for this restaurant. Aborting.', 'Campus_Veg_Treat_Menu_Transcribed.docx';
  END IF;
END $do$;

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400081001001, 'ai_menu_extraction', 'Campus_Veg_Treat_Menu_Transcribed.docx');
UPDATE khaustan_onboarding_ctx SET source_id = 400081001001;

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
SELECT 400081001001, ctx.restaurant_id, ctx.source_id, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed'
FROM khaustan_onboarding_ctx ctx;
UPDATE khaustan_onboarding_ctx SET extraction_batch_id = 400081001001;

INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
SELECT x.phone_id, ctx.restaurant_id, x.phone_number, x.is_primary
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400081001001, '7738632871', TRUE), (400081001002, '9320632871', FALSE), (400081001003, '022 25632871', FALSE)) AS x(phone_id, phone_number, is_primary);

INSERT INTO restaurant_service_mode (restaurant_id, service_mode_id, is_active, notes)
SELECT ctx.restaurant_id, sm.service_mode_id, TRUE, x.notes
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES ('delivery', 'Docx confirms "FREE HOME DELIVERY"; the docx''s own delivery-verification note confirms no third-party platform logo is named, only a generic delivery-scooter graphic.')) AS x(code, notes)
JOIN service_mode sm ON sm.code = x.code;

INSERT INTO restaurant_delivery (restaurant_id, delivery_available, self_delivery_available, self_delivery_min_order_amount)
SELECT ctx.restaurant_id, TRUE, TRUE, NULL FROM khaustan_onboarding_ctx ctx;

DO $do$
DECLARE
  v_provider_id BIGINT;
BEGIN
  SELECT delivery_provider_id INTO v_provider_id FROM delivery_provider WHERE provider_code = 'SELF';
  IF NOT FOUND THEN
    v_provider_id := 400081001001;
    INSERT INTO delivery_provider (delivery_provider_id, provider_code, provider_name, provider_type_code)
    VALUES (v_provider_id, 'SELF', 'Self Delivery', 'self');
  END IF;

  INSERT INTO restaurant_delivery_provider (restaurant_delivery_provider_id, restaurant_id, delivery_provider_id, delivery_charge_type_code, base_delivery_charge, effective_from)
  SELECT 400081001001, ctx.restaurant_id, v_provider_id, 'fixed', 0.00, (clock_timestamp() AT TIME ZONE 'UTC')
  FROM khaustan_onboarding_ctx ctx;
END $do$;

-- -----------------------------------------------------------------------
-- Canonical dishes: one row per distinct normalized dish name, batched
-- into one set-based statement (safe: normalized_name is the identity
-- key and the candidate list is de-duplicated before generation).
-- -----------------------------------------------------------------------
WITH candidate_dishes(canonical_dish_id, canonical_dish_name_id, canonical_name, normalized_name, food_classification_code, protein_code) AS (
  VALUES
    (400081001001, 400081001001, 'Sada Dosa', 'sada dosa', 'veg', NULL),
    (400081001002, 400081001002, 'Neer Dosa', 'neer dosa', 'veg', NULL),
    (400081001003, 400081001003, 'Ghee Sada Dosa', 'ghee sada dosa', 'veg', NULL),
    (400081001004, 400081001004, 'Cheese Sada Dosa', 'cheese sada dosa', 'veg', NULL),
    (400081001005, 400081001005, 'Masala Dosa', 'masala dosa', 'veg', NULL),
    (400081001006, 400081001006, 'Ghee Masala Dosa', 'ghee masala dosa', 'veg', NULL),
    (400081001007, 400081001007, 'Cheese Masala Dosa', 'cheese masala dosa', 'veg', NULL),
    (400081001008, 400081001008, 'Paper Sada Dosa', 'paper sada dosa', 'veg', NULL),
    (400081001009, 400081001009, 'Ghee Paper Sada Dosa', 'ghee paper sada dosa', 'veg', NULL),
    (400081001010, 400081001010, 'Cheese Paper Sada Dosa', 'cheese paper sada dosa', 'veg', NULL),
    (400081001011, 400081001011, 'Paper Masala Dosa', 'paper masala dosa', 'veg', NULL),
    (400081001012, 400081001012, 'Ghee Paper Masala Dosa', 'ghee paper masala dosa', 'veg', NULL),
    (400081001013, 400081001013, 'Cheese Paper Masala Dosa', 'cheese paper masala dosa', 'veg', NULL),
    (400081001014, 400081001014, 'Rava Sada Dosa', 'rava sada dosa', 'veg', NULL),
    (400081001015, 400081001015, 'Ghee Rava Sada', 'ghee rava sada', 'veg', NULL),
    (400081001016, 400081001016, 'Rava Masala Dosa', 'rava masala dosa', 'veg', NULL),
    (400081001017, 400081001017, 'Ghee Rava Masala', 'ghee rava masala', 'veg', NULL),
    (400081001018, 400081001018, 'Onion Rava Sada Dosa', 'onion rava sada dosa', 'veg', NULL),
    (400081001019, 400081001019, 'Ghee Onion Rava Sada Dosa', 'ghee onion rava sada dosa', 'veg', NULL),
    (400081001020, 400081001020, 'Onion Rava Masala Dosa', 'onion rava masala dosa', 'veg', NULL),
    (400081001021, 400081001021, 'Ghee Onion Rava Masala', 'ghee onion rava masala', 'veg', NULL),
    (400081001022, 400081001022, 'Mysore Sada Dosa', 'mysore sada dosa', 'veg', NULL),
    (400081001023, 400081001023, 'Ghee Mysore Sada Dosa', 'ghee mysore sada dosa', 'veg', NULL),
    (400081001024, 400081001024, 'Mysore Masala Dosa', 'mysore masala dosa', 'veg', NULL),
    (400081001025, 400081001025, 'Ghee Mysore Masala Dosa', 'ghee mysore masala dosa', 'veg', NULL),
    (400081001026, 400081001026, 'Uttappam', 'uttappam', 'veg', NULL),
    (400081001027, 400081001027, 'Butter Uttappam', 'butter uttappam', 'veg', NULL),
    (400081001028, 400081001028, 'Cheese Uttappam', 'cheese uttappam', 'veg', NULL),
    (400081001029, 400081001029, 'Onion Uttappam', 'onion uttappam', 'veg', NULL),
    (400081001030, 400081001030, 'Butter Onion Uttappam', 'butter onion uttappam', 'veg', NULL),
    (400081001031, 400081001031, 'Cheese Onion Uttappam', 'cheese onion uttappam', 'veg', NULL),
    (400081001032, 400081001032, 'Masala Uttappam', 'masala uttappam', 'veg', NULL),
    (400081001033, 400081001033, 'Coconut Uttappam', 'coconut uttappam', 'veg', NULL),
    (400081001034, 400081001034, 'Tomato Onion Uttappam', 'tomato onion uttappam', 'veg', NULL),
    (400081001035, 400081001035, 'Tomato Omelette', 'tomato omelette', 'veg', NULL),
    (400081001036, 400081001036, 'Hot Steam Idli', 'hot steam idli', 'veg', NULL),
    (400081001037, 400081001037, 'Butter Idli', 'butter idli', 'veg', NULL),
    (400081001038, 400081001038, 'Fried Idli', 'fried idli', 'veg', NULL),
    (400081001039, 400081001039, 'Dahi Idli', 'dahi idli', 'veg', NULL),
    (400081001040, 400081001040, 'Medu Vada', 'medu vada', 'veg', NULL),
    (400081001041, 400081001041, 'Idli', 'idli', 'veg', NULL),
    (400081001042, 400081001042, 'Potato Vada', 'potato vada', 'veg', NULL),
    (400081001043, 400081001043, 'Dahi Vada', 'dahi vada', 'veg', NULL),
    (400081001044, 400081001044, 'Sabudana Vada', 'sabudana vada', 'veg', NULL),
    (400081001045, 400081001045, 'Sabudana Kachori', 'sabudana kachori', 'veg', NULL),
    (400081001046, 400081001046, 'Finger Chips', 'finger chips', 'veg', NULL),
    (400081001047, 400081001047, 'Shira', 'shira', 'veg', NULL),
    (400081001048, 400081001048, 'Upma', 'upma', 'veg', NULL),
    (400081001049, 400081001049, 'Poha', 'poha', 'veg', NULL),
    (400081001050, 400081001050, 'Sambar Only', 'sambar only', 'veg', NULL),
    (400081001051, 400081001051, 'Special Masala Dosa', 'special masala dosa', 'veg', NULL),
    (400081001052, 400081001052, 'Family Dosa', 'family dosa', 'veg', NULL),
    (400081001053, 400081001053, 'Paneer Chilli Dosa', 'paneer chilli dosa', 'veg', NULL),
    (400081001054, 400081001054, 'American Chopsuey Dosa', 'american chopsuey dosa', 'veg', NULL),
    (400081001055, 400081001055, 'Schezwan Chopsuey Dosa', 'schezwan chopsuey dosa', 'veg', NULL),
    (400081001056, 400081001056, 'Veg. Spring Dosa', 'veg. spring dosa', 'veg', NULL),
    (400081001057, 400081001057, 'Tea', 'tea', 'veg', NULL),
    (400081001058, 400081001058, 'Tea without Sugar', 'tea without sugar', 'veg', NULL),
    (400081001059, 400081001059, 'Nescafe', 'nescafe', 'veg', NULL),
    (400081001060, 400081001060, 'Filter Coffee', 'filter coffee', 'veg', NULL),
    (400081001061, 400081001061, 'Hazelnut Coffee', 'hazelnut coffee', 'veg', NULL),
    (400081001062, 400081001062, 'Veg. Sandwich', 'veg. sandwich', 'veg', NULL),
    (400081001063, 400081001063, 'Cheese Sandwich', 'cheese sandwich', 'veg', NULL),
    (400081001064, 400081001064, 'Veg. Cheese Sandwich', 'veg. cheese sandwich', 'veg', NULL),
    (400081001065, 400081001065, 'Chutney Sandwich', 'chutney sandwich', 'veg', NULL),
    (400081001066, 400081001066, 'Omelette Sandwich', 'omelette sandwich', 'veg', NULL),
    (400081001067, 400081001067, 'Omelette Toast Sandwich', 'omelette toast sandwich', 'veg', NULL),
    (400081001068, 400081001068, 'Cheese Chilli Toast Sandwich', 'cheese chilli toast sandwich', 'veg', NULL),
    (400081001069, 400081001069, 'Club Sandwich', 'club sandwich', 'veg', NULL),
    (400081001070, 400081001070, 'Tomato Sandwich', 'tomato sandwich', 'veg', NULL),
    (400081001071, 400081001071, 'Bread Butter', 'bread butter', 'veg', NULL),
    (400081001072, 400081001072, 'Toast Butter', 'toast butter', 'veg', NULL),
    (400081001073, 400081001073, 'Jam Bread Butter', 'jam bread butter', 'veg', NULL),
    (400081001074, 400081001074, 'Jam Toast Butter', 'jam toast butter', 'veg', NULL),
    (400081001075, 400081001075, 'Veg. Grill Sandwich', 'veg. grill sandwich', 'veg', NULL),
    (400081001076, 400081001076, 'Cheese Grill Sandwich', 'cheese grill sandwich', 'veg', NULL),
    (400081001077, 400081001077, 'Veg. Cheese Grill Sandwich', 'veg. cheese grill sandwich', 'veg', NULL),
    (400081001078, 400081001078, 'Russian Sandwich', 'russian sandwich', 'veg', NULL),
    (400081001079, 400081001079, 'Veg. Toast Sandwich', 'veg. toast sandwich', 'veg', NULL),
    (400081001080, 400081001080, 'Cheese Toast Sandwich', 'cheese toast sandwich', 'veg', NULL),
    (400081001081, 400081001081, 'Veg. Cheese Toast Sandwich', 'veg. cheese toast sandwich', 'veg', NULL),
    (400081001082, 400081001082, 'Veg. Burger', 'veg. burger', 'veg', NULL),
    (400081001083, 400081001083, 'Cheese Burger', 'cheese burger', 'veg', NULL),
    (400081001084, 400081001084, 'Veg. Cheese Burger', 'veg. cheese burger', 'veg', NULL),
    (400081001085, 400081001085, 'Paneer Tikka Pizza', 'paneer tikka pizza', 'veg', NULL),
    (400081001086, 400081001086, 'Paneer Chilli Pizza', 'paneer chilli pizza', 'veg', NULL),
    (400081001087, 400081001087, 'Capsicum Corn Cheese Pizza', 'capsicum corn cheese pizza', 'veg', NULL),
    (400081001088, 400081001088, 'Veg. Pizza', 'veg. pizza', 'veg', NULL),
    (400081001089, 400081001089, 'Jain Pizza', 'jain pizza', 'veg', NULL),
    (400081001090, 400081001090, 'Cheese Pizza (Only Cheese)', 'cheese pizza (only cheese)', 'veg', NULL),
    (400081001091, 400081001091, 'Pineapple Cheese Pizza', 'pineapple cheese pizza', 'veg', NULL),
    (400081001092, 400081001092, 'Mushroom Pizza', 'mushroom pizza', 'veg', NULL),
    (400081001093, 400081001093, 'Special Pizza', 'special pizza', 'veg', NULL),
    (400081001094, 400081001094, 'Dry Fruit Pizza', 'dry fruit pizza', 'veg', NULL),
    (400081001095, 400081001095, 'Pav Bhaji', 'pav bhaji', 'veg', NULL),
    (400081001096, 400081001096, 'Cheese Pav Bhaji', 'cheese pav bhaji', 'veg', NULL),
    (400081001097, 400081001097, 'Paneer Pav Bhaji', 'paneer pav bhaji', 'veg', NULL),
    (400081001098, 400081001098, 'Jain Pav Bhaji', 'jain pav bhaji', 'veg', NULL),
    (400081001099, 400081001099, 'Jain Cheese Pav Bhaji', 'jain cheese pav bhaji', 'veg', NULL),
    (400081001100, 400081001100, 'Khada Pav Bhaji', 'khada pav bhaji', 'veg', NULL),
    (400081001101, 400081001101, 'Khada Cheese Pav Bhaji', 'khada cheese pav bhaji', 'veg', NULL),
    (400081001102, 400081001102, 'Campus Special Pav Bhaji', 'campus special pav bhaji', 'veg', NULL),
    (400081001103, 400081001103, 'Only Bhaji', 'only bhaji', 'veg', NULL),
    (400081001104, 400081001104, 'Khada Bhaji', 'khada bhaji', 'veg', NULL),
    (400081001105, 400081001105, 'Jain Bhaji', 'jain bhaji', 'veg', NULL),
    (400081001106, 400081001106, 'Masala Pav', 'masala pav', 'veg', NULL),
    (400081001107, 400081001107, 'Cheese Masala Pav', 'cheese masala pav', 'veg', NULL),
    (400081001108, 400081001108, 'Plain Pav', 'plain pav', 'veg', NULL),
    (400081001109, 400081001109, 'Extra Pav', 'extra pav', 'veg', NULL),
    (400081001110, 400081001110, 'Garlic Chatni', 'garlic chatni', 'veg', NULL),
    (400081001111, 400081001111, 'Green Salad', 'green salad', 'veg', NULL),
    (400081001112, 400081001112, 'Tomato Salad', 'tomato salad', 'veg', NULL),
    (400081001113, 400081001113, 'Veg. Raita', 'veg. raita', 'veg', NULL),
    (400081001114, 400081001114, 'Bundi Raita', 'bundi raita', 'veg', NULL),
    (400081001115, 400081001115, 'Dahi Bundi Sweet', 'dahi bundi sweet', 'veg', NULL),
    (400081001116, 400081001116, 'Pineapple Raita', 'pineapple raita', 'veg', NULL),
    (400081001117, 400081001117, 'Roasted Papad', 'roasted papad', 'veg', NULL),
    (400081001118, 400081001118, 'Fried Papad', 'fried papad', 'veg', NULL),
    (400081001119, 400081001119, 'Masala Papad', 'masala papad', 'veg', NULL),
    (400081001120, 400081001120, 'Curd', 'curd', 'veg', NULL),
    (400081001121, 400081001121, 'Hara Bhara Kabab', 'hara bhara kabab', 'veg', NULL),
    (400081001122, 400081001122, 'Mushroom Pahadi Kabab', 'mushroom pahadi kabab', 'veg', NULL),
    (400081001123, 400081001123, 'Chilli Milli Kabab', 'chilli milli kabab', 'veg', NULL),
    (400081001124, 400081001124, 'Paneer Pahadi Kabab', 'paneer pahadi kabab', 'veg', NULL),
    (400081001125, 400081001125, 'Paneer Seekh Kabab', 'paneer seekh kabab', 'veg', NULL),
    (400081001126, 400081001126, 'Paneer Tikka', 'paneer tikka', 'veg', NULL),
    (400081001127, 400081001127, 'Mushroom Tikka', 'mushroom tikka', 'veg', NULL),
    (400081001128, 400081001128, 'Babycorn Tikki', 'babycorn tikki', 'veg', NULL),
    (400081001129, 400081001129, 'Paneer Pakoda', 'paneer pakoda', 'veg', NULL),
    (400081001130, 400081001130, 'Cheese Pakoda', 'cheese pakoda', 'veg', NULL),
    (400081001131, 400081001131, 'Veg. Pakoda', 'veg. pakoda', 'veg', NULL),
    (400081001132, 400081001132, 'Cream of Vegetable', 'cream of vegetable', 'veg', NULL),
    (400081001133, 400081001133, 'Cream of Tomato Soup', 'cream of tomato soup', 'veg', NULL),
    (400081001134, 400081001134, 'Cream of Mushroom', 'cream of mushroom', 'veg', NULL),
    (400081001135, 400081001135, 'Palak Soup', 'palak soup', 'veg', NULL),
    (400081001136, 400081001136, 'Alu Mutter', 'alu mutter', 'veg', NULL),
    (400081001137, 400081001137, 'Alu Gobi', 'alu gobi', 'veg', NULL),
    (400081001138, 400081001138, 'Alu Methi', 'alu methi', 'veg', NULL),
    (400081001139, 400081001139, 'Alu Palak', 'alu palak', 'veg', NULL),
    (400081001140, 400081001140, 'Alu Jeera', 'alu jeera', 'veg', NULL),
    (400081001141, 400081001141, 'Plain Palak', 'plain palak', 'veg', NULL),
    (400081001142, 400081001142, 'Chana Masala', 'chana masala', 'veg', NULL),
    (400081001143, 400081001143, 'Flower Masala', 'flower masala', 'veg', NULL),
    (400081001144, 400081001144, 'Bhindi Fry', 'bhindi fry', 'veg', NULL),
    (400081001145, 400081001145, 'Bhindi Masala', 'bhindi masala', 'veg', NULL),
    (400081001146, 400081001146, 'Baigan Bhurta', 'baigan bhurta', 'veg', NULL),
    (400081001147, 400081001147, 'Baigan Masala', 'baigan masala', 'veg', NULL),
    (400081001148, 400081001148, 'Green Peas Masala', 'green peas masala', 'veg', NULL),
    (400081001149, 400081001149, 'Green Peas Palak', 'green peas palak', 'veg', NULL),
    (400081001150, 400081001150, 'Veg. Kolhapuri', 'veg. kolhapuri', 'veg', NULL),
    (400081001151, 400081001151, 'Veg. Kurma', 'veg. kurma', 'veg', NULL),
    (400081001152, 400081001152, 'Veg. Kheema', 'veg. kheema', 'veg', NULL),
    (400081001153, 400081001153, 'Mixed Vegetables', 'mixed vegetables', 'veg', NULL),
    (400081001154, 400081001154, 'Harabhara Kabab Masala', 'harabhara kabab masala', 'veg', NULL),
    (400081001155, 400081001155, 'Chole Bhatura', 'chole bhatura', 'veg', NULL),
    (400081001156, 400081001156, 'Paneer Palak', 'paneer palak', 'veg', NULL),
    (400081001157, 400081001157, 'Paneer Mutter', 'paneer mutter', 'veg', NULL),
    (400081001158, 400081001158, 'Paneer Chana', 'paneer chana', 'veg', NULL),
    (400081001159, 400081001159, 'Paneer Methi', 'paneer methi', 'veg', NULL),
    (400081001160, 400081001160, 'Paneer Tawa', 'paneer tawa', 'veg', NULL),
    (400081001161, 400081001161, 'Paneer Kolhapuri', 'paneer kolhapuri', 'veg', NULL),
    (400081001162, 400081001162, 'Paneer Mushroom Masala', 'paneer mushroom masala', 'veg', NULL),
    (400081001163, 400081001163, 'Paneer Babycorn Masala', 'paneer babycorn masala', 'veg', NULL),
    (400081001164, 400081001164, 'Paneer Lasooni', 'paneer lasooni', 'veg', NULL),
    (400081001165, 400081001165, 'Paneer Achari', 'paneer achari', 'veg', NULL),
    (400081001166, 400081001166, 'Paneer Kurma', 'paneer kurma', 'veg', NULL),
    (400081001167, 400081001167, 'Paneer Bhurji', 'paneer bhurji', 'veg', NULL),
    (400081001168, 400081001168, 'Paneer Makhani', 'paneer makhani', 'veg', NULL),
    (400081001169, 400081001169, 'Paneer Pasanda', 'paneer pasanda', 'veg', NULL),
    (400081001170, 400081001170, 'Paneer Handi', 'paneer handi', 'veg', NULL),
    (400081001171, 400081001171, 'Paneer Kadai', 'paneer kadai', 'veg', NULL),
    (400081001172, 400081001172, 'Paneer Butter Masala', 'paneer butter masala', 'veg', NULL),
    (400081001173, 400081001173, 'Paneer Tikka Masala', 'paneer tikka masala', 'veg', NULL),
    (400081001174, 400081001174, 'Babycorn Tikka Masala', 'babycorn tikka masala', 'veg', NULL),
    (400081001175, 400081001175, 'Mushroom Tikka Masala', 'mushroom tikka masala', 'veg', NULL),
    (400081001176, 400081001176, 'Paneer Kofta', 'paneer kofta', 'veg', NULL),
    (400081001177, 400081001177, 'Kashmiri Kofta', 'kashmiri kofta', 'veg', NULL),
    (400081001178, 400081001178, 'Nargis Kofta', 'nargis kofta', 'veg', NULL),
    (400081001179, 400081001179, 'Malai Kofta', 'malai kofta', 'veg', NULL),
    (400081001180, 400081001180, 'Veg. Kofta', 'veg. kofta', 'veg', NULL),
    (400081001181, 400081001181, 'Mushroom Handi', 'mushroom handi', 'veg', NULL),
    (400081001182, 400081001182, 'Mushroom Kadai', 'mushroom kadai', 'veg', NULL),
    (400081001183, 400081001183, 'Veg. Chilli Babycorn Masala', 'veg. chilli babycorn masala', 'veg', NULL),
    (400081001184, 400081001184, 'Veg. Chop Masala', 'veg. chop masala', 'veg', NULL),
    (400081001185, 400081001185, 'Veg. Lasooni', 'veg. lasooni', 'veg', NULL),
    (400081001186, 400081001186, 'Veg. Achari', 'veg. achari', 'veg', NULL),
    (400081001187, 400081001187, 'Veg. Jalfraizi', 'veg. jalfraizi', 'veg', NULL),
    (400081001188, 400081001188, 'Veg. Jaipuri', 'veg. jaipuri', 'veg', NULL),
    (400081001189, 400081001189, 'Veg. Makhani', 'veg. makhani', 'veg', NULL),
    (400081001190, 400081001190, 'Veg. Afghani', 'veg. afghani', 'veg', NULL),
    (400081001191, 400081001191, 'Veg. Hyderabadi', 'veg. hyderabadi', 'veg', NULL),
    (400081001192, 400081001192, 'Veg. Handi', 'veg. handi', 'veg', NULL),
    (400081001193, 400081001193, 'Veg. Kadai', 'veg. kadai', 'veg', NULL),
    (400081001194, 400081001194, 'Navratan Kurma', 'navratan kurma', 'veg', NULL),
    (400081001195, 400081001195, 'Shahi Kurma', 'shahi kurma', 'veg', NULL),
    (400081001196, 400081001196, 'Palak Lasooni', 'palak lasooni', 'veg', NULL),
    (400081001197, 400081001197, 'Babycorn Masala', 'babycorn masala', 'veg', NULL),
    (400081001198, 400081001198, 'Mushroom Masala', 'mushroom masala', 'veg', NULL),
    (400081001199, 400081001199, 'Mushroom Mutter', 'mushroom mutter', 'veg', NULL),
    (400081001200, 400081001200, 'Mushroom Palak', 'mushroom palak', 'veg', NULL),
    (400081001201, 400081001201, 'Mushroom Makhani', 'mushroom makhani', 'veg', NULL),
    (400081001202, 400081001202, 'Methi Mutter', 'methi mutter', 'veg', NULL),
    (400081001203, 400081001203, 'Methi Malai Mutter', 'methi malai mutter', 'veg', NULL),
    (400081001204, 400081001204, 'Methi Lasooni', 'methi lasooni', 'veg', NULL),
    (400081001205, 400081001205, 'Dum Alu Kashmiri', 'dum alu kashmiri', 'veg', NULL),
    (400081001206, 400081001206, 'Dum Alu Punjabi', 'dum alu punjabi', 'veg', NULL),
    (400081001207, 400081001207, 'Stuffed Simla Mirch', 'stuffed simla mirch', 'veg', NULL),
    (400081001208, 400081001208, 'Stuffed Tomato', 'stuffed tomato', 'veg', NULL),
    (400081001209, 400081001209, 'Tomato Fry', 'tomato fry', 'veg', NULL),
    (400081001210, 400081001210, 'Tomato Bhurta', 'tomato bhurta', 'veg', NULL),
    (400081001211, 400081001211, 'Tomato Bhurji', 'tomato bhurji', 'veg', NULL),
    (400081001212, 400081001212, 'Veg. Do Pyaza', 'veg. do pyaza', 'veg', NULL),
    (400081001213, 400081001213, 'Veg. Bhuna Masala', 'veg. bhuna masala', 'veg', NULL),
    (400081001214, 400081001214, 'Veg. Diwani Handi', 'veg. diwani handi', 'veg', NULL),
    (400081001215, 400081001215, 'Mushroom Mazzedar', 'mushroom mazzedar', 'veg', NULL),
    (400081001216, 400081001216, 'Kaju Makhani', 'kaju makhani', 'veg', NULL),
    (400081001217, 400081001217, 'Kaju Masala', 'kaju masala', 'veg', NULL),
    (400081001218, 400081001218, 'Kaju Paneer Masala', 'kaju paneer masala', 'veg', NULL),
    (400081001219, 400081001219, 'Paneer Diwani Handi', 'paneer diwani handi', 'veg', NULL),
    (400081001220, 400081001220, 'Mushroom Diwani Handi', 'mushroom diwani handi', 'veg', NULL),
    (400081001221, 400081001221, 'Paneer Do Pyaza', 'paneer do pyaza', 'veg', NULL),
    (400081001222, 400081001222, 'Paneer Lazeez', 'paneer lazeez', 'veg', NULL),
    (400081001223, 400081001223, 'Paneer Seekh Kabab Masala', 'paneer seekh kabab masala', 'veg', NULL),
    (400081001224, 400081001224, 'Veg. Angoori Kofta', 'veg. angoori kofta', 'veg', NULL),
    (400081001225, 400081001225, 'Paneer', 'paneer', 'veg', NULL),
    (400081001226, 400081001226, 'Cheese', 'cheese', 'veg', NULL),
    (400081001227, 400081001227, 'Angoori Kofta', 'angoori kofta', 'veg', NULL),
    (400081001228, 400081001228, 'Veg. Tiranga', 'veg. tiranga', 'veg', NULL),
    (400081001229, 400081001229, 'Roti', 'roti', 'veg', NULL),
    (400081001230, 400081001230, 'Butter Roti', 'butter roti', 'veg', NULL),
    (400081001231, 400081001231, 'Palak Roti', 'palak roti', 'veg', NULL),
    (400081001232, 400081001232, 'Pudina Roti', 'pudina roti', 'veg', NULL),
    (400081001233, 400081001233, 'Missi Roti', 'missi roti', 'veg', NULL),
    (400081001234, 400081001234, 'Makkai ki Roti', 'makkai ki roti', 'veg', NULL),
    (400081001235, 400081001235, 'Paratha', 'paratha', 'veg', NULL),
    (400081001236, 400081001236, 'Butter Paratha', 'butter paratha', 'veg', NULL),
    (400081001237, 400081001237, 'Methi Paratha', 'methi paratha', 'veg', NULL),
    (400081001238, 400081001238, 'Alu Paratha', 'alu paratha', 'veg', NULL),
    (400081001239, 400081001239, 'Stuffed Paratha', 'stuffed paratha', 'veg', NULL),
    (400081001240, 400081001240, 'Naan', 'naan', 'veg', NULL),
    (400081001241, 400081001241, 'Butter Naan', 'butter naan', 'veg', NULL),
    (400081001242, 400081001242, 'Cheese Naan', 'cheese naan', 'veg', NULL),
    (400081001243, 400081001243, 'Paneer Naan', 'paneer naan', 'veg', NULL),
    (400081001244, 400081001244, 'Kashmiri Naan', 'kashmiri naan', 'veg', NULL),
    (400081001245, 400081001245, 'Garlic Naan', 'garlic naan', 'veg', NULL),
    (400081001246, 400081001246, 'Kulcha', 'kulcha', 'veg', NULL),
    (400081001247, 400081001247, 'Butter Kulcha', 'butter kulcha', 'veg', NULL),
    (400081001248, 400081001248, 'Cheese Kulcha', 'cheese kulcha', 'veg', NULL),
    (400081001249, 400081001249, 'Bhatura', 'bhatura', 'veg', NULL),
    (400081001250, 400081001250, 'Dahi Kadhi Pakoda', 'dahi kadhi pakoda', 'veg', NULL),
    (400081001251, 400081001251, 'Dal Kolhapuri', 'dal kolhapuri', 'veg', NULL),
    (400081001252, 400081001252, 'Dal Palak', 'dal palak', 'veg', NULL),
    (400081001253, 400081001253, 'Dal Tadka', 'dal tadka', 'veg', NULL),
    (400081001254, 400081001254, 'Butter Dal Fry', 'butter dal fry', 'veg', NULL),
    (400081001255, 400081001255, 'Dal Fry', 'dal fry', 'veg', NULL),
    (400081001256, 400081001256, 'Plain Dal', 'plain dal', 'veg', NULL),
    (400081001257, 400081001257, 'Steamed Rice', 'steamed rice', 'veg', NULL),
    (400081001258, 400081001258, 'Jeera Rice', 'jeera rice', 'veg', NULL),
    (400081001259, 400081001259, 'Curd Rice', 'curd rice', 'veg', NULL),
    (400081001260, 400081001260, 'Veg. Pulav', 'veg. pulav', 'veg', NULL),
    (400081001261, 400081001261, 'Green Peas Pulav', 'green peas pulav', 'veg', NULL),
    (400081001262, 400081001262, 'Veg. Kashmiri Pulav', 'veg. kashmiri pulav', 'veg', NULL),
    (400081001263, 400081001263, 'Veg. Paneer Pulav', 'veg. paneer pulav', 'veg', NULL),
    (400081001264, 400081001264, 'Veg. Biryani', 'veg. biryani', 'veg', NULL),
    (400081001265, 400081001265, 'Veg. Cheese Biryani', 'veg. cheese biryani', 'veg', NULL),
    (400081001266, 400081001266, 'Veg. Paneer Biryani', 'veg. paneer biryani', 'veg', NULL),
    (400081001267, 400081001267, 'Veg. Handi Biryani', 'veg. handi biryani', 'veg', NULL),
    (400081001268, 400081001268, 'Mushroom Biryani', 'mushroom biryani', 'veg', NULL),
    (400081001269, 400081001269, 'Hyderabadi Biryani', 'hyderabadi biryani', 'veg', NULL),
    (400081001270, 400081001270, 'Tawa Pulav', 'tawa pulav', 'veg', NULL),
    (400081001271, 400081001271, 'Paneer Tawa Pulav', 'paneer tawa pulav', 'veg', NULL),
    (400081001272, 400081001272, 'Cheese Tawa Pulav', 'cheese tawa pulav', 'veg', NULL),
    (400081001273, 400081001273, 'Dal Khichdi Tadkewali', 'dal khichdi tadkewali', 'veg', NULL),
    (400081001274, 400081001274, 'Dal Khichdi', 'dal khichdi', 'veg', NULL),
    (400081001275, 400081001275, 'Palak Khichdi', 'palak khichdi', 'veg', NULL),
    (400081001276, 400081001276, 'Veg. Asian Green Soup', 'veg. asian green soup', 'veg', NULL),
    (400081001277, 400081001277, 'Veg. Tom Yum Soup', 'veg. tom yum soup', 'veg', NULL),
    (400081001278, 400081001278, 'Veg. Sweet & Sour Soup', 'veg. sweet & sour soup', 'veg', NULL),
    (400081001279, 400081001279, 'Veg. Lung Fung Soup', 'veg. lung fung soup', 'veg', NULL),
    (400081001280, 400081001280, 'Veg. Sweet Corn Soup', 'veg. sweet corn soup', 'veg', NULL),
    (400081001281, 400081001281, 'Plain Sweet Corn Soup', 'plain sweet corn soup', 'veg', NULL),
    (400081001282, 400081001282, 'Veg. Manchow Soup', 'veg. manchow soup', 'veg', NULL),
    (400081001283, 400081001283, 'Veg. Hot-N-Sour Soup', 'veg. hot-n-sour soup', 'veg', NULL),
    (400081001284, 400081001284, 'Veg. Noodle Soup', 'veg. noodle soup', 'veg', NULL),
    (400081001285, 400081001285, 'Veg. Manchurian Soup', 'veg. manchurian soup', 'veg', NULL),
    (400081001286, 400081001286, 'Mushroom Babycorn Chilli', 'mushroom babycorn chilli', 'veg', NULL),
    (400081001287, 400081001287, 'Mushroom Manchurian', 'mushroom manchurian', 'veg', NULL),
    (400081001288, 400081001288, 'Mushroom Paneer Manchurian', 'mushroom paneer manchurian', 'veg', NULL),
    (400081001289, 400081001289, 'Mushroom Paneer Schezwan', 'mushroom paneer schezwan', 'veg', NULL),
    (400081001290, 400081001290, 'Mushroom Babycorn Manchurian', 'mushroom babycorn manchurian', 'veg', NULL),
    (400081001291, 400081001291, 'Paneer Butter Garlic', 'paneer butter garlic', 'veg', NULL),
    (400081001292, 400081001292, 'Paneer Hot Garlic', 'paneer hot garlic', 'veg', NULL),
    (400081001293, 400081001293, 'Paneer Chilli', 'paneer chilli', 'veg', NULL),
    (400081001294, 400081001294, 'Paneer Mushroom Chilli', 'paneer mushroom chilli', 'veg', NULL),
    (400081001295, 400081001295, 'Paneer Manchurian', 'paneer manchurian', 'veg', NULL),
    (400081001296, 400081001296, 'Paneer Schezwan', 'paneer schezwan', 'veg', NULL),
    (400081001297, 400081001297, 'Paneer Singapore', 'paneer singapore', 'veg', NULL),
    (400081001298, 400081001298, 'Paneer 65', 'paneer 65', 'veg', NULL),
    (400081001299, 400081001299, 'Paneer Salt & Pepper', 'paneer salt & pepper', 'veg', NULL),
    (400081001300, 400081001300, 'Paneer Splendour', 'paneer splendour', 'veg', NULL),
    (400081001301, 400081001301, 'Babycorn Splendour', 'babycorn splendour', 'veg', NULL),
    (400081001302, 400081001302, 'Mushroom Splendour', 'mushroom splendour', 'veg', NULL),
    (400081001303, 400081001303, 'Veg. Lollypop', 'veg. lollypop', 'veg', NULL),
    (400081001304, 400081001304, 'Veg. Spring Roll', 'veg. spring roll', 'veg', NULL),
    (400081001305, 400081001305, 'Veg. Finger Schezwan', 'veg. finger schezwan', 'veg', NULL),
    (400081001306, 400081001306, 'Babycorn Schezwan', 'babycorn schezwan', 'veg', NULL),
    (400081001307, 400081001307, 'Veg. Hong Kong', 'veg. hong kong', 'veg', NULL),
    (400081001308, 400081001308, 'Veg. Manchurian', 'veg. manchurian', 'veg', NULL),
    (400081001309, 400081001309, 'Flower Manchurian', 'flower manchurian', 'veg', NULL),
    (400081001310, 400081001310, 'Veg. 65', 'veg. 65', 'veg', NULL),
    (400081001311, 400081001311, 'Veg. Schezwan', 'veg. schezwan', 'veg', NULL),
    (400081001312, 400081001312, 'Veg. Crispy', 'veg. crispy', 'veg', NULL),
    (400081001313, 400081001313, 'Crispy Potato', 'crispy potato', 'veg', NULL),
    (400081001314, 400081001314, 'Veg. Gold Coin', 'veg. gold coin', 'veg', NULL),
    (400081001315, 400081001315, 'Corn Cheese Balls', 'corn cheese balls', 'veg', NULL),
    (400081001316, 400081001316, 'Corn Cheese Tokri', 'corn cheese tokri', 'veg', NULL),
    (400081001317, 400081001317, 'American Chopsuey', 'american chopsuey', 'veg', NULL),
    (400081001318, 400081001318, 'Chinese Chopsuey', 'chinese chopsuey', 'veg', NULL),
    (400081001319, 400081001319, 'Idli Chilli', 'idli chilli', 'veg', NULL),
    (400081001320, 400081001320, 'Chinese Bhel', 'chinese bhel', 'veg', NULL),
    (400081001321, 400081001321, 'Veg. Hakka Noodles', 'veg. hakka noodles', 'veg', NULL),
    (400081001322, 400081001322, 'Veg. Schezwan Noodles', 'veg. schezwan noodles', 'veg', NULL),
    (400081001323, 400081001323, 'Veg. Singapore Noodles', 'veg. singapore noodles', 'veg', NULL),
    (400081001324, 400081001324, 'Veg. Hong Kong Noodles', 'veg. hong kong noodles', 'veg', NULL),
    (400081001325, 400081001325, 'Veg. Chilli Garlic Noodles', 'veg. chilli garlic noodles', 'veg', NULL),
    (400081001326, 400081001326, 'Veg. Burnt Garlic Noodles', 'veg. burnt garlic noodles', 'veg', NULL),
    (400081001327, 400081001327, 'Veg. Malaysian Noodles', 'veg. malaysian noodles', 'veg', NULL),
    (400081001328, 400081001328, 'Veg. Triple Schezwan Noodles', 'veg. triple schezwan noodles', 'veg', NULL),
    (400081001329, 400081001329, 'Jeera Fried Rice', 'jeera fried rice', 'veg', NULL),
    (400081001330, 400081001330, 'Veg. Fried Rice', 'veg. fried rice', 'veg', NULL),
    (400081001331, 400081001331, 'Veg. Schezwan Rice', 'veg. schezwan rice', 'veg', NULL),
    (400081001332, 400081001332, 'Veg. Hongkong Rice', 'veg. hongkong rice', 'veg', NULL),
    (400081001333, 400081001333, 'Veg. Singapore Rice', 'veg. singapore rice', 'veg', NULL),
    (400081001334, 400081001334, 'Veg. Chilli Garlic Rice', 'veg. chilli garlic rice', 'veg', NULL),
    (400081001335, 400081001335, 'Veg. Burnt Garlic Rice', 'veg. burnt garlic rice', 'veg', NULL),
    (400081001336, 400081001336, 'Peas Fried Rice', 'peas fried rice', 'veg', NULL),
    (400081001337, 400081001337, 'Combination Rice', 'combination rice', 'veg', NULL),
    (400081001338, 400081001338, 'Paneer Fried Rice', 'paneer fried rice', 'veg', NULL),
    (400081001339, 400081001339, 'Mushroom Fried Rice', 'mushroom fried rice', 'veg', NULL),
    (400081001340, 400081001340, 'Mushroom Combination Rice', 'mushroom combination rice', 'veg', NULL),
    (400081001341, 400081001341, 'Schezwan Combination Rice', 'schezwan combination rice', 'veg', NULL),
    (400081001342, 400081001342, 'Mix Fried Rice', 'mix fried rice', 'veg', NULL),
    (400081001343, 400081001343, 'Peking Rice', 'peking rice', 'veg', NULL),
    (400081001344, 400081001344, 'Veg. Malaysian Rice', 'veg. malaysian rice', 'veg', NULL),
    (400081001345, 400081001345, 'Triple Schezwan Fried Rice', 'triple schezwan fried rice', 'veg', NULL),
    (400081001346, 400081001346, 'Mosambi', 'mosambi', 'veg', NULL),
    (400081001347, 400081001347, 'Water Melon', 'water melon', 'veg', NULL),
    (400081001348, 400081001348, 'Orange', 'orange', 'veg', NULL),
    (400081001349, 400081001349, 'Pineapple', 'pineapple', 'veg', NULL),
    (400081001350, 400081001350, 'Ganga Jamuna', 'ganga jamuna', 'veg', NULL),
    (400081001351, 400081001351, 'Maramari', 'maramari', 'veg', NULL),
    (400081001352, 400081001352, 'Cocktail', 'cocktail', 'veg', NULL),
    (400081001353, 400081001353, 'Apple', 'apple', 'veg', NULL),
    (400081001354, 400081001354, 'Grapes', 'grapes', 'veg', NULL),
    (400081001355, 400081001355, 'Mango (Seasonal)', 'mango (seasonal)', 'veg', NULL),
    (400081001356, 400081001356, 'Strawberry', 'strawberry', 'veg', NULL),
    (400081001357, 400081001357, 'Fresh Lime Juice', 'fresh lime juice', 'veg', NULL),
    (400081001358, 400081001358, 'Fresh Lime Soda', 'fresh lime soda', 'veg', NULL),
    (400081001359, 400081001359, 'Ginger Lemon', 'ginger lemon', 'veg', NULL),
    (400081001360, 400081001360, 'Rose Falooda', 'rose falooda', 'veg', NULL),
    (400081001361, 400081001361, 'Kesar Falooda', 'kesar falooda', 'veg', NULL),
    (400081001362, 400081001362, 'Kulfi Falooda', 'kulfi falooda', 'veg', NULL),
    (400081001363, 400081001363, 'Dry Fruits Falooda', 'dry fruits falooda', 'veg', NULL),
    (400081001364, 400081001364, 'Vanilla', 'vanilla', 'veg', NULL),
    (400081001365, 400081001365, 'Banana', 'banana', 'veg', NULL),
    (400081001366, 400081001366, 'Rose', 'rose', 'veg', NULL),
    (400081001367, 400081001367, 'Chikoo', 'chikoo', 'veg', NULL),
    (400081001368, 400081001368, 'Chocolate', 'chocolate', 'veg', NULL),
    (400081001369, 400081001369, 'Kesar', 'kesar', 'veg', NULL),
    (400081001370, 400081001370, 'Mango', 'mango', 'veg', NULL),
    (400081001371, 400081001371, 'Sitaphal', 'sitaphal', 'veg', NULL),
    (400081001372, 400081001372, 'Dry Fruit', 'dry fruit', 'veg', NULL),
    (400081001373, 400081001373, 'Pista', 'pista', 'veg', NULL),
    (400081001374, 400081001374, 'Badam', 'badam', 'veg', NULL),
    (400081001375, 400081001375, 'Kesar Badam', 'kesar badam', 'veg', NULL),
    (400081001376, 400081001376, 'Kaju Anjir', 'kaju anjir', 'veg', NULL),
    (400081001377, 400081001377, 'Cold Coffee', 'cold coffee', 'veg', NULL),
    (400081001378, 400081001378, 'Cold Coffee With Ice-cream', 'cold coffee with ice-cream', 'veg', NULL),
    (400081001379, 400081001379, 'Sweet Lassi', 'sweet lassi', 'veg', NULL),
    (400081001380, 400081001380, 'Salted Lassi', 'salted lassi', 'veg', NULL),
    (400081001381, 400081001381, 'Mango Lassi', 'mango lassi', 'veg', NULL),
    (400081001382, 400081001382, 'Rose Lassi', 'rose lassi', 'veg', NULL),
    (400081001383, 400081001383, 'Kesar Lassi', 'kesar lassi', 'veg', NULL),
    (400081001384, 400081001384, 'Chaas', 'chaas', 'veg', NULL),
    (400081001385, 400081001385, 'Aerated Waters', 'aerated waters', 'veg', NULL),
    (400081001386, 400081001386, 'Mineral Water', 'mineral water', 'veg', NULL),
    (400081001387, 400081001387, 'Fruit Salad', 'fruit salad', 'veg', NULL),
    (400081001388, 400081001388, 'Fruit Salad with Ice Cream', 'fruit salad with ice cream', 'veg', NULL),
    (400081001389, 400081001389, 'Fruit Salad with Jelly', 'fruit salad with jelly', 'veg', NULL),
    (400081001390, 400081001390, 'Fruit Salad with Jelly & Ice Cream', 'fruit salad with jelly & ice cream', 'veg', NULL),
    (400081001391, 400081001391, 'Jelly', 'jelly', 'veg', NULL),
    (400081001392, 400081001392, 'Jelly with Ice Cream', 'jelly with ice cream', 'veg', NULL),
    (400081001393, 400081001393, 'Malai Kulfi', 'malai kulfi', 'veg', NULL),
    (400081001394, 400081001394, 'Kesar Pista Kulfi', 'kesar pista kulfi', 'veg', NULL),
    (400081001395, 400081001395, 'Mango Kulfi', 'mango kulfi', 'veg', NULL),
    (400081001396, 400081001396, 'Badam Kulfi', 'badam kulfi', 'veg', NULL),
    (400081001397, 400081001397, 'Pista Kulfi', 'pista kulfi', 'veg', NULL),
    (400081001398, 400081001398, 'Sitaphal Kulfi', 'sitaphal kulfi', 'veg', NULL),
    (400081001399, 400081001399, 'Hot Chocolate Vanilla', 'hot chocolate vanilla', 'veg', NULL),
    (400081001400, 400081001400, 'Sambar', 'sambar', 'veg', NULL),
    (400081001401, 400081001401, 'Chutney', 'chutney', 'veg', NULL),
    (400081001402, 400081001402, 'Ghee', 'ghee', 'veg', NULL),
    (400081001403, 400081001403, 'Butter', 'butter', 'veg', NULL),
    (400081001404, 400081001404, 'Ice Cream Scoop', 'ice cream scoop', 'veg', NULL)
),
new_dishes AS (
  INSERT INTO canonical_dish (canonical_dish_id, canonical_name, normalized_name, food_classification_code, default_protein_type_id)
  SELECT cd.canonical_dish_id, cd.canonical_name, cd.normalized_name, cd.food_classification_code, pt.protein_type_id
  FROM candidate_dishes cd
  LEFT JOIN protein_type pt ON pt.code = cd.protein_code
  WHERE NOT EXISTS (SELECT 1 FROM canonical_dish existing WHERE existing.normalized_name = cd.normalized_name)
  RETURNING canonical_dish_id, canonical_name, normalized_name
)
INSERT INTO canonical_dish_name (canonical_dish_name_id, canonical_dish_id, language_code, name, normalized_name, name_type_code)
SELECT cd.canonical_dish_name_id, nd.canonical_dish_id, 'en', nd.canonical_name, nd.normalized_name, 'primary'
FROM new_dishes nd
JOIN candidate_dishes cd ON cd.normalized_name = nd.normalized_name;

-- -----------------------------------------------------------------------
-- Categories: one row per distinct raw_category_text seen in the source,
-- flat (no parent_category_id -- no hierarchy is stated anywhere in this
-- batch's sources). menu_item.menu_category_id now points here directly;
-- raw_category_text is kept too, verbatim, alongside it.
-- -----------------------------------------------------------------------
INSERT INTO menu_category (menu_category_id, restaurant_id, name, display_sequence)
SELECT x.menu_category_id, ctx.restaurant_id, x.name, x.display_sequence
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400081001001, 'TAWA KA KAMAL', 1), (400081001002, 'FROM STEAMER & FRYER', 2), (400081001003, 'SPECIAL DOSAS', 3), (400081001004, 'TEA & COFFEE', 4), (400081001005, 'SANDWICHES', 5), (400081001006, 'BURGERS', 6), (400081001007, 'PIZZAS', 7), (400081001008, 'PAV BHAJI — After 11.00 a.m.', 8), (400081001009, 'PAPADS / SALADS / RAITAS', 9), (400081001010, 'STARTERS', 10), (400081001011, 'SOUPS', 11), (400081001012, 'HARIYALI KI MAST PASAND', 12), (400081001013, 'SPECIAL SHAKAHARI DAWAT', 13), (400081001014, 'TANDOOR ROTI', 14), (400081001015, 'DAL', 15), (400081001016, 'RICE/ BIRYANI/ PULAV', 16), (400081001017, 'CHINESE DISHES — SOUPS', 17), (400081001018, 'STARTERS & CHINESE VEG.', 18), (400081001019, 'NOODLES / RICE', 19), (400081001020, 'JUICES', 20), (400081001021, 'FALOODAS', 21), (400081001022, 'MILK SHAKES', 22), (400081001023, 'COOLERS', 23), (400081001024, 'FRUIT SALADS', 24), (400081001025, 'KULFI SLICES', 25), (400081001026, 'DESSERTS', 26), (400081001027, 'EXTRAS', 27)) AS x(menu_category_id, name, display_sequence);

-- =============================================================================
-- Menu items (412 priced)
-- =============================================================================

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001001, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Sada Dosa', 'sada dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001001, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001001, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001002, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Neer Dosa', 'neer dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'neer dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001002, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001002, new_variant.variant_id, 145.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001003, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Ghee Sada Dosa', 'ghee sada dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ghee sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001003, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001003, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001004, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Cheese Sada Dosa', 'cheese sada dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001004, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001004, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001005, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Masala Dosa', 'masala dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001005, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001005, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001006, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Ghee Masala Dosa', 'ghee masala dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ghee masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001006, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001006, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001007, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Cheese Masala Dosa', 'cheese masala dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001007, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001007, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001008, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Paper Sada Dosa', 'paper sada dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paper sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001008, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001008, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001009, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Ghee Paper Sada Dosa', 'ghee paper sada dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ghee paper sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001009, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001009, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001010, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Cheese Paper Sada Dosa', 'cheese paper sada dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese paper sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001010, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001010, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001011, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Paper Masala Dosa', 'paper masala dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paper masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001011, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001011, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001012, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Ghee Paper Masala Dosa', 'ghee paper masala dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ghee paper masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001012, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001012, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001013, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Cheese Paper Masala Dosa', 'cheese paper masala dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese paper masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001013, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001013, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001014, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Rava Sada Dosa', 'rava sada dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rava sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001014, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001014, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001015, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Ghee Rava Sada', 'ghee rava sada', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ghee rava sada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001015, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001015, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001016, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Rava Masala Dosa', 'rava masala dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rava masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001016, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001016, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001017, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Ghee Rava Masala', 'ghee rava masala', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ghee rava masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001017, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001017, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001018, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Onion Rava Sada Dosa', 'onion rava sada dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'onion rava sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001018, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001018, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001019, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Ghee Onion Rava Sada Dosa', 'ghee onion rava sada dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ghee onion rava sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001019, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001019, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001020, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Onion Rava Masala Dosa', 'onion rava masala dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'onion rava masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001020, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001020, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001021, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Ghee Onion Rava Masala', 'ghee onion rava masala', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ghee onion rava masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001021, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001021, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001022, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Mysore Sada Dosa', 'mysore sada dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mysore sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001022, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001022, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001023, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Ghee Mysore Sada Dosa', 'ghee mysore sada dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ghee mysore sada dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001023, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001023, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001024, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Mysore Masala Dosa', 'mysore masala dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mysore masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001024, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001024, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001025, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Ghee Mysore Masala Dosa', 'ghee mysore masala dosa', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ghee mysore masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001025, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001025, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001026, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Uttappam', 'uttappam', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001026, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001026, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001027, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Butter Uttappam', 'butter uttappam', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001027, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001027, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001028, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Cheese Uttappam', 'cheese uttappam', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001028, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001028, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001029, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Onion Uttappam', 'onion uttappam', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'onion uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001029, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001029, new_variant.variant_id, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001030, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Butter Onion Uttappam', 'butter onion uttappam', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter onion uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001030, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001030, new_variant.variant_id, 175.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001031, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Cheese Onion Uttappam', 'cheese onion uttappam', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese onion uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001031, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001031, new_variant.variant_id, 195.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001032, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Masala Uttappam', 'masala uttappam', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'masala uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001032, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001032, new_variant.variant_id, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001033, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Coconut Uttappam', 'coconut uttappam', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'coconut uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001033, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001033, new_variant.variant_id, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001034, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Tomato Onion Uttappam', 'tomato onion uttappam', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tomato onion uttappam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001034, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001034, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TAWA KA KAMAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001035, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001001, 'Tomato Omelette', 'tomato omelette', 'TAWA KA KAMAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tomato omelette'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001035, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001035, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001036, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Hot Steam Idli', 'hot steam idli', 'FROM STEAMER & FRYER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hot steam idli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001036, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001036, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001037, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Butter Idli', 'butter idli', 'FROM STEAMER & FRYER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter idli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001037, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001037, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001038, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Fried Idli', 'fried idli', 'FROM STEAMER & FRYER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fried idli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001038, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001038, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001039, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Dahi Idli', 'dahi idli', 'FROM STEAMER & FRYER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dahi idli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001039, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001039, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001040, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Medu Vada', 'medu vada', 'FROM STEAMER & FRYER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'medu vada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001040, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001040, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001041, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Idli', 'idli', 'FROM STEAMER & FRYER', 'veg', 'split-idli-medu-vada', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'idli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001041, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001041, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001042, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Medu Vada', 'medu vada', 'FROM STEAMER & FRYER', 'veg', 'split-idli-medu-vada', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'medu vada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001042, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001042, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001043, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Potato Vada', 'potato vada', 'FROM STEAMER & FRYER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'potato vada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001043, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001043, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001044, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Dahi Vada', 'dahi vada', 'FROM STEAMER & FRYER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dahi vada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001044, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001044, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001045, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Sabudana Vada', 'sabudana vada', 'FROM STEAMER & FRYER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sabudana vada'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001045, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001045, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001046, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Sabudana Kachori', 'sabudana kachori', 'FROM STEAMER & FRYER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sabudana kachori'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001046, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001046, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001047, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Finger Chips', 'finger chips', 'FROM STEAMER & FRYER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'finger chips'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001047, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001047, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001048, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Shira', 'shira', 'FROM STEAMER & FRYER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'shira'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001048, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001048, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001049, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Upma', 'upma', 'FROM STEAMER & FRYER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'upma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001049, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001049, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001050, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Poha', 'poha', 'FROM STEAMER & FRYER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'poha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001050, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001050, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FROM STEAMER & FRYER" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001051, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001002, 'Sambar Only', 'sambar only', 'FROM STEAMER & FRYER', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sambar only'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001051, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001051, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001052, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001003, 'Special Masala Dosa', 'special masala dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'special masala dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001052, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001052, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001053, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001003, 'Family Dosa', 'family dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'family dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001053, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001053, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001054, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001003, 'Paneer Chilli Dosa', 'paneer chilli dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilli dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001054, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001054, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001055, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001003, 'American Chopsuey Dosa', 'american chopsuey dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'american chopsuey dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001055, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001055, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001056, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001003, 'Schezwan Chopsuey Dosa', 'schezwan chopsuey dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'schezwan chopsuey dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001056, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001056, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL DOSAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001057, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001003, 'Veg. Spring Dosa', 'veg. spring dosa', 'SPECIAL DOSAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. spring dosa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001057, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001057, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TEA & COFFEE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001058, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001004, 'Tea', 'tea', 'TEA & COFFEE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tea'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001058, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001058, new_variant.variant_id, 45.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TEA & COFFEE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001059, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001004, 'Tea without Sugar', 'tea without sugar', 'TEA & COFFEE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tea without sugar'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001059, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001059, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TEA & COFFEE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001060, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001004, 'Nescafe', 'nescafe', 'TEA & COFFEE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nescafe'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001060, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001060, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TEA & COFFEE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001061, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001004, 'Filter Coffee', 'filter coffee', 'TEA & COFFEE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'filter coffee'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001061, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001061, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TEA & COFFEE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001062, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001004, 'Hazelnut Coffee', 'hazelnut coffee', 'TEA & COFFEE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hazelnut coffee'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001062, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001062, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001063, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Veg. Sandwich', 'veg. sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001063, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001063, new_variant.variant_id, 125.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001064, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Cheese Sandwich', 'cheese sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001064, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001064, new_variant.variant_id, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001065, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Veg. Cheese Sandwich', 'veg. cheese sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. cheese sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001065, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001065, new_variant.variant_id, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001066, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Chutney Sandwich', 'chutney sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chutney sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001066, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001066, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001067, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Omelette Sandwich', 'omelette sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'omelette sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001067, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001067, new_variant.variant_id, 155.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001068, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Omelette Toast Sandwich', 'omelette toast sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'omelette toast sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001068, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001068, new_variant.variant_id, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001069, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Cheese Chilli Toast Sandwich', 'cheese chilli toast sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese chilli toast sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001069, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001069, new_variant.variant_id, 185.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001070, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Club Sandwich', 'club sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'club sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001070, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001070, new_variant.variant_id, 205.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001071, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Tomato Sandwich', 'tomato sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tomato sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001071, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001071, new_variant.variant_id, 125.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001072, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Bread Butter', 'bread butter', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bread butter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001072, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001072, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001073, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Toast Butter', 'toast butter', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'toast butter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001073, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001073, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001074, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Jam Bread Butter', 'jam bread butter', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jam bread butter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001074, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001074, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001075, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Jam Toast Butter', 'jam toast butter', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jam toast butter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001075, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001075, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001076, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Veg. Grill Sandwich', 'veg. grill sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. grill sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001076, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001076, new_variant.variant_id, 185.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001077, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Cheese Grill Sandwich', 'cheese grill sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese grill sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001077, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001077, new_variant.variant_id, 215.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001078, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Veg. Cheese Grill Sandwich', 'veg. cheese grill sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. cheese grill sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001078, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001078, new_variant.variant_id, 225.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001079, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Russian Sandwich', 'russian sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'russian sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001079, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001079, new_variant.variant_id, 215.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001080, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Veg. Toast Sandwich', 'veg. toast sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. toast sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001080, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001080, new_variant.variant_id, 135.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001081, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Cheese Toast Sandwich', 'cheese toast sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese toast sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001081, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001081, new_variant.variant_id, 165.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SANDWICHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001082, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001005, 'Veg. Cheese Toast Sandwich', 'veg. cheese toast sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. cheese toast sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001082, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001082, new_variant.variant_id, 175.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "BURGERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001083, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001006, 'Veg. Burger', 'veg. burger', 'BURGERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001083, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001083, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "BURGERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001084, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001006, 'Cheese Burger', 'cheese burger', 'BURGERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001084, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001084, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "BURGERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001085, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001006, 'Veg. Cheese Burger', 'veg. cheese burger', 'BURGERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. cheese burger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001085, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001085, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PIZZAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001086, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001007, 'Paneer Tikka Pizza', 'paneer tikka pizza', 'PIZZAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001086, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001086, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PIZZAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001087, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001007, 'Paneer Chilli Pizza', 'paneer chilli pizza', 'PIZZAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilli pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001087, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001087, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PIZZAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001088, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001007, 'Capsicum Corn Cheese Pizza', 'capsicum corn cheese pizza', 'PIZZAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'capsicum corn cheese pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001088, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001088, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PIZZAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001089, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001007, 'Veg. Pizza', 'veg. pizza', 'PIZZAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001089, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001089, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PIZZAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001090, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001007, 'Jain Pizza', 'jain pizza', 'PIZZAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jain pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001090, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001090, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PIZZAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001091, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001007, 'Cheese Pizza (Only Cheese)', 'cheese pizza (only cheese)', 'PIZZAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese pizza (only cheese)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001091, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001091, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PIZZAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001092, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001007, 'Pineapple Cheese Pizza', 'pineapple cheese pizza', 'PIZZAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pineapple cheese pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001092, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001092, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PIZZAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001093, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001007, 'Mushroom Pizza', 'mushroom pizza', 'PIZZAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001093, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001093, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PIZZAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001094, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001007, 'Special Pizza', 'special pizza', 'PIZZAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'special pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001094, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001094, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PIZZAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001095, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001007, 'Dry Fruit Pizza', 'dry fruit pizza', 'PIZZAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dry fruit pizza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001095, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001095, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PAV BHAJI — After 11.00 a.m." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001096, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001008, 'Pav Bhaji', 'pav bhaji', 'PAV BHAJI — After 11.00 a.m.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001096, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001096, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
,
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT 400081001001, new_item.menu_item_id, NULL, '11:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx/json, "PAV BHAJI — After 11.00 a.m." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001097, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001008, 'Cheese Pav Bhaji', 'cheese pav bhaji', 'PAV BHAJI — After 11.00 a.m.', 'veg', 'split-cheese-paneer-pav-bhaji', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001097, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001097, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
,
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT 400081001002, new_item.menu_item_id, NULL, '11:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx/json, "PAV BHAJI — After 11.00 a.m." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001098, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001008, 'Paneer Pav Bhaji', 'paneer pav bhaji', 'PAV BHAJI — After 11.00 a.m.', 'veg', 'split-cheese-paneer-pav-bhaji', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001098, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001098, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
,
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT 400081001003, new_item.menu_item_id, NULL, '11:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx/json, "PAV BHAJI — After 11.00 a.m." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001099, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001008, 'Jain Pav Bhaji', 'jain pav bhaji', 'PAV BHAJI — After 11.00 a.m.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jain pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001099, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001099, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
,
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT 400081001004, new_item.menu_item_id, NULL, '11:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx/json, "PAV BHAJI — After 11.00 a.m." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001100, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001008, 'Jain Cheese Pav Bhaji', 'jain cheese pav bhaji', 'PAV BHAJI — After 11.00 a.m.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jain cheese pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001100, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001100, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
,
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT 400081001005, new_item.menu_item_id, NULL, '11:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx/json, "PAV BHAJI — After 11.00 a.m." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001101, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001008, 'Khada Pav Bhaji', 'khada pav bhaji', 'PAV BHAJI — After 11.00 a.m.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'khada pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001101, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001101, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
,
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT 400081001006, new_item.menu_item_id, NULL, '11:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx/json, "PAV BHAJI — After 11.00 a.m." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001102, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001008, 'Khada Cheese Pav Bhaji', 'khada cheese pav bhaji', 'PAV BHAJI — After 11.00 a.m.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'khada cheese pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001102, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001102, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
,
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT 400081001007, new_item.menu_item_id, NULL, '11:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx/json, "PAV BHAJI — After 11.00 a.m." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001103, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001008, 'Campus Special Pav Bhaji', 'campus special pav bhaji', 'PAV BHAJI — After 11.00 a.m.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'campus special pav bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001103, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001103, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
,
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT 400081001008, new_item.menu_item_id, NULL, '11:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx/json, "PAV BHAJI — After 11.00 a.m." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001104, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001008, 'Only Bhaji', 'only bhaji', 'PAV BHAJI — After 11.00 a.m.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'only bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001104, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001104, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
,
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT 400081001009, new_item.menu_item_id, NULL, '11:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx/json, "PAV BHAJI — After 11.00 a.m." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001105, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001008, 'Khada Bhaji', 'khada bhaji', 'PAV BHAJI — After 11.00 a.m.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'khada bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001105, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001105, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
,
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT 400081001010, new_item.menu_item_id, NULL, '11:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx/json, "PAV BHAJI — After 11.00 a.m." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001106, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001008, 'Jain Bhaji', 'jain bhaji', 'PAV BHAJI — After 11.00 a.m.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jain bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001106, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001106, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)
,
price_src AS (
  INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
  SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx
  RETURNING price_id
)
INSERT INTO menu_item_availability (availability_id, menu_item_id, day_of_week, start_time, end_time)
SELECT 400081001011, new_item.menu_item_id, NULL, '11:00', NULL
FROM new_item, price_src
LIMIT 1;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001107, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Masala Pav', 'masala pav', 'PAPADS / SALADS / RAITAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'masala pav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001107, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001107, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001108, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Cheese Masala Pav', 'cheese masala pav', 'PAPADS / SALADS / RAITAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese masala pav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001108, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001108, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001109, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Plain Pav', 'plain pav', 'PAPADS / SALADS / RAITAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'plain pav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001109, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001109, new_variant.variant_id, 12.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001110, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Extra Pav', 'extra pav', 'PAPADS / SALADS / RAITAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'extra pav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001110, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001110, new_variant.variant_id, 22.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001111, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Garlic Chatni', 'garlic chatni', 'PAPADS / SALADS / RAITAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'garlic chatni'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001111, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001111, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001112, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Green Salad', 'green salad', 'PAPADS / SALADS / RAITAS', 'veg', 'split-green-tomato-salad', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green salad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001112, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001112, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001113, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Tomato Salad', 'tomato salad', 'PAPADS / SALADS / RAITAS', 'veg', 'split-green-tomato-salad', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tomato salad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001113, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001113, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001114, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Veg. Raita', 'veg. raita', 'PAPADS / SALADS / RAITAS', 'veg', 'split-veg-bundi-raita', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. raita'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001114, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001114, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001115, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Bundi Raita', 'bundi raita', 'PAPADS / SALADS / RAITAS', 'veg', 'split-veg-bundi-raita', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bundi raita'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001115, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001115, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001116, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Dahi Bundi Sweet', 'dahi bundi sweet', 'PAPADS / SALADS / RAITAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dahi bundi sweet'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001116, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001116, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001117, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Pineapple Raita', 'pineapple raita', 'PAPADS / SALADS / RAITAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pineapple raita'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001117, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001117, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001118, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Roasted Papad', 'roasted papad', 'PAPADS / SALADS / RAITAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'roasted papad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001118, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001118, new_variant.variant_id, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001119, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Fried Papad', 'fried papad', 'PAPADS / SALADS / RAITAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fried papad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001119, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001119, new_variant.variant_id, 45.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001120, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Masala Papad', 'masala papad', 'PAPADS / SALADS / RAITAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'masala papad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001120, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001120, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PAPADS / SALADS / RAITAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001121, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001009, 'Curd', 'curd', 'PAPADS / SALADS / RAITAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'curd'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001121, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001121, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001122, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001010, 'Hara Bhara Kabab', 'hara bhara kabab', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hara bhara kabab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001122, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001122, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001123, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001010, 'Mushroom Pahadi Kabab', 'mushroom pahadi kabab', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom pahadi kabab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001123, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001123, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001124, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001010, 'Chilli Milli Kabab', 'chilli milli kabab', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chilli milli kabab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001124, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001124, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001125, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001010, 'Paneer Pahadi Kabab', 'paneer pahadi kabab', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer pahadi kabab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001125, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001125, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001126, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001010, 'Paneer Seekh Kabab', 'paneer seekh kabab', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer seekh kabab'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001126, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001126, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001127, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001010, 'Paneer Tikka', 'paneer tikka', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001127, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001127, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001128, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001010, 'Mushroom Tikka', 'mushroom tikka', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom tikka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001128, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001128, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001129, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001010, 'Babycorn Tikki', 'babycorn tikki', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'babycorn tikki'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001129, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001129, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001130, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001010, 'Paneer Pakoda', 'paneer pakoda', 'STARTERS', 'veg', 'split-paneer-cheese-pakoda', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer pakoda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001130, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001130, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001131, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001010, 'Cheese Pakoda', 'cheese pakoda', 'STARTERS', 'veg', 'split-paneer-cheese-pakoda', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese pakoda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001131, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001131, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001132, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001010, 'Veg. Pakoda', 'veg. pakoda', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. pakoda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001132, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001132, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001133, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001011, 'Cream of Vegetable', 'cream of vegetable', 'SOUPS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cream of vegetable'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001133, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001133, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001134, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001011, 'Cream of Tomato Soup', 'cream of tomato soup', 'SOUPS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cream of tomato soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001134, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001134, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001135, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001011, 'Cream of Mushroom', 'cream of mushroom', 'SOUPS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cream of mushroom'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001135, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001135, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001136, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001011, 'Palak Soup', 'palak soup', 'SOUPS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'palak soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001136, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001136, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001137, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Alu Mutter', 'alu mutter', 'HARIYALI KI MAST PASAND', 'veg', 'split-alu-mutter-alu-gobi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001137, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001137, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001138, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Alu Gobi', 'alu gobi', 'HARIYALI KI MAST PASAND', 'veg', 'split-alu-mutter-alu-gobi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu gobi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001138, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001138, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001139, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Alu Methi', 'alu methi', 'HARIYALI KI MAST PASAND', 'veg', 'split-alu-methi-alu-palak', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu methi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001139, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001139, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001140, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Alu Palak', 'alu palak', 'HARIYALI KI MAST PASAND', 'veg', 'split-alu-methi-alu-palak', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001140, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001140, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001141, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Alu Jeera', 'alu jeera', 'HARIYALI KI MAST PASAND', 'veg', 'split-alu-jeera-plain-palak', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu jeera'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001141, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001141, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001142, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Plain Palak', 'plain palak', 'HARIYALI KI MAST PASAND', 'veg', 'split-alu-jeera-plain-palak', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'plain palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001142, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001142, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001143, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Chana Masala', 'chana masala', 'HARIYALI KI MAST PASAND', 'veg', 'split-chana-flower-masala', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chana masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001143, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001143, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001144, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Flower Masala', 'flower masala', 'HARIYALI KI MAST PASAND', 'veg', 'split-chana-flower-masala', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'flower masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001144, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001144, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001145, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Bhindi Fry', 'bhindi fry', 'HARIYALI KI MAST PASAND', 'veg', 'split-bhindi-fry-bhindi-masala', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bhindi fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001145, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001145, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001146, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Bhindi Masala', 'bhindi masala', 'HARIYALI KI MAST PASAND', 'veg', 'split-bhindi-fry-bhindi-masala', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bhindi masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001146, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001146, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001147, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Baigan Bhurta', 'baigan bhurta', 'HARIYALI KI MAST PASAND', 'veg', 'split-baigan-bhurta-masala', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baigan bhurta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001147, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001147, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001148, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Baigan Masala', 'baigan masala', 'HARIYALI KI MAST PASAND', 'veg', 'split-baigan-bhurta-masala', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baigan masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001148, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001148, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001149, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Green Peas Masala', 'green peas masala', 'HARIYALI KI MAST PASAND', 'veg', 'split-green-peas-masala-palak', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green peas masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001149, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001149, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001150, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Green Peas Palak', 'green peas palak', 'HARIYALI KI MAST PASAND', 'veg', 'split-green-peas-masala-palak', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green peas palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001150, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001150, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001151, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Kolhapuri', 'veg. kolhapuri', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kolhapuri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001151, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001151, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001152, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Kurma', 'veg. kurma', 'HARIYALI KI MAST PASAND', 'veg', 'split-veg-kurma-kheema', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kurma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001152, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001152, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001153, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Kheema', 'veg. kheema', 'HARIYALI KI MAST PASAND', 'veg', 'split-veg-kurma-kheema', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kheema'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001153, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001153, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001154, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Mixed Vegetables', 'mixed vegetables', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mixed vegetables'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001154, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001154, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001155, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Harabhara Kabab Masala', 'harabhara kabab masala', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'harabhara kabab masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001155, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001155, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001156, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Chole Bhatura', 'chole bhatura', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chole bhatura'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001156, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001156, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001157, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Palak', 'paneer palak', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-palak-mutter', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001157, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001157, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001158, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Mutter', 'paneer mutter', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-palak-mutter', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001158, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001158, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001159, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Chana', 'paneer chana', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-chana-methi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chana'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001159, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001159, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001160, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Methi', 'paneer methi', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-chana-methi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer methi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001160, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001160, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001161, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Tawa', 'paneer tawa', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-tawa-kolhapuri', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tawa'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001161, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001161, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001162, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Kolhapuri', 'paneer kolhapuri', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-tawa-kolhapuri', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kolhapuri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001162, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001162, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001163, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Mushroom Masala', 'paneer mushroom masala', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer mushroom masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001163, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001163, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001164, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Babycorn Masala', 'paneer babycorn masala', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer babycorn masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001164, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001164, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001165, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Lasooni', 'paneer lasooni', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-lasooni-achari', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer lasooni'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001165, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001165, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001166, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Achari', 'paneer achari', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-lasooni-achari', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer achari'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001166, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001166, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001167, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Kurma', 'paneer kurma', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-kurma-bhurji', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kurma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001167, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001167, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001168, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Bhurji', 'paneer bhurji', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-kurma-bhurji', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer bhurji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001168, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001168, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001169, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Makhani', 'paneer makhani', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-makhani-pasanda', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer makhani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001169, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001169, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001170, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Pasanda', 'paneer pasanda', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-makhani-pasanda', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer pasanda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001170, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001170, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001171, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Handi', 'paneer handi', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-handi-kadai', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer handi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001171, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001171, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001172, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Kadai', 'paneer kadai', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-handi-kadai', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kadai'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001172, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001172, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001173, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Butter Masala', 'paneer butter masala', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer butter masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001173, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001173, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001174, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Tikka Masala', 'paneer tikka masala', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001174, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001174, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001175, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Babycorn Tikka Masala', 'babycorn tikka masala', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'babycorn tikka masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001175, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001175, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001176, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Mushroom Tikka Masala', 'mushroom tikka masala', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom tikka masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001176, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001176, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001177, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Paneer Kofta', 'paneer kofta', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-kashmiri-kofta', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001177, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001177, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001178, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Kashmiri Kofta', 'kashmiri kofta', 'HARIYALI KI MAST PASAND', 'veg', 'split-paneer-kashmiri-kofta', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kashmiri kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001178, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001178, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001179, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Nargis Kofta', 'nargis kofta', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nargis kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001179, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001179, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001180, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Malai Kofta', 'malai kofta', 'HARIYALI KI MAST PASAND', 'veg', 'split-malai-kofta-veg-kofta', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'malai kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001180, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001180, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001181, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Kofta', 'veg. kofta', 'HARIYALI KI MAST PASAND', 'veg', 'split-malai-kofta-veg-kofta', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001181, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001181, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001182, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Mushroom Handi', 'mushroom handi', 'HARIYALI KI MAST PASAND', 'veg', 'split-mushroom-handi-kadai', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom handi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001182, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001182, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001183, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Mushroom Kadai', 'mushroom kadai', 'HARIYALI KI MAST PASAND', 'veg', 'split-mushroom-handi-kadai', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom kadai'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001183, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001183, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001184, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Chilli Babycorn Masala', 'veg. chilli babycorn masala', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chilli babycorn masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001184, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001184, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001185, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Chop Masala', 'veg. chop masala', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chop masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001185, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001185, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001186, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Lasooni', 'veg. lasooni', 'HARIYALI KI MAST PASAND', 'veg', 'split-veg-lasooni-achari', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. lasooni'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001186, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001186, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001187, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Achari', 'veg. achari', 'HARIYALI KI MAST PASAND', 'veg', 'split-veg-lasooni-achari', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. achari'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001187, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001187, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001188, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Jalfraizi', 'veg. jalfraizi', 'HARIYALI KI MAST PASAND', 'veg', 'split-veg-jalfraizi-jaipuri', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. jalfraizi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001188, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001188, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001189, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Jaipuri', 'veg. jaipuri', 'HARIYALI KI MAST PASAND', 'veg', 'split-veg-jalfraizi-jaipuri', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. jaipuri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001189, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001189, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001190, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Makhani', 'veg. makhani', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. makhani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001190, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001190, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001191, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Afghani', 'veg. afghani', 'HARIYALI KI MAST PASAND', 'veg', 'split-veg-afghani-hyderabadi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. afghani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001191, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001191, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001192, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Hyderabadi', 'veg. hyderabadi', 'HARIYALI KI MAST PASAND', 'veg', 'split-veg-afghani-hyderabadi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hyderabadi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001192, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001192, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001193, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Handi', 'veg. handi', 'HARIYALI KI MAST PASAND', 'veg', 'split-veg-handi-kadai', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. handi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001193, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001193, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001194, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Veg. Kadai', 'veg. kadai', 'HARIYALI KI MAST PASAND', 'veg', 'split-veg-handi-kadai', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kadai'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001194, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001194, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001195, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Navratan Kurma', 'navratan kurma', 'HARIYALI KI MAST PASAND', 'veg', 'split-navratan-kurma-shahi-kurma', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'navratan kurma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001195, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001195, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001196, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Shahi Kurma', 'shahi kurma', 'HARIYALI KI MAST PASAND', 'veg', 'split-navratan-kurma-shahi-kurma', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'shahi kurma'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001196, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001196, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001197, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Palak Lasooni', 'palak lasooni', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'palak lasooni'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001197, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001197, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001198, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Babycorn Masala', 'babycorn masala', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'babycorn masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001198, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001198, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001199, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Mushroom Masala', 'mushroom masala', 'HARIYALI KI MAST PASAND', 'veg', 'split-mushroom-masala-mutter', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001199, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001199, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001200, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Mushroom Mutter', 'mushroom mutter', 'HARIYALI KI MAST PASAND', 'veg', 'split-mushroom-masala-mutter', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001200, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001200, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001201, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Mushroom Palak', 'mushroom palak', 'HARIYALI KI MAST PASAND', 'veg', 'split-mushroom-palak-makhani', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001201, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001201, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001202, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Mushroom Makhani', 'mushroom makhani', 'HARIYALI KI MAST PASAND', 'veg', 'split-mushroom-palak-makhani', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom makhani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001202, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001202, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001203, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Methi Mutter', 'methi mutter', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'methi mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001203, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001203, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001204, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Methi Malai Mutter', 'methi malai mutter', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'methi malai mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001204, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001204, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001205, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Methi Lasooni', 'methi lasooni', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'methi lasooni'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001205, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001205, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001206, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Dum Alu Kashmiri', 'dum alu kashmiri', 'HARIYALI KI MAST PASAND', 'veg', 'split-dum-alu-kashmiri-punjabi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dum alu kashmiri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001206, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001206, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001207, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Dum Alu Punjabi', 'dum alu punjabi', 'HARIYALI KI MAST PASAND', 'veg', 'split-dum-alu-kashmiri-punjabi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dum alu punjabi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001207, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001207, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001208, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Stuffed Simla Mirch', 'stuffed simla mirch', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'stuffed simla mirch'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001208, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001208, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001209, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Stuffed Tomato', 'stuffed tomato', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'stuffed tomato'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001209, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001209, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001210, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Tomato Fry', 'tomato fry', 'HARIYALI KI MAST PASAND', 'veg', 'split-tomato-fry-bhurta', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tomato fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001210, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001210, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001211, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Tomato Bhurta', 'tomato bhurta', 'HARIYALI KI MAST PASAND', 'veg', 'split-tomato-fry-bhurta', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tomato bhurta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001211, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001211, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "HARIYALI KI MAST PASAND" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001212, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001012, 'Tomato Bhurji', 'tomato bhurji', 'HARIYALI KI MAST PASAND', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tomato bhurji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001212, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001212, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001213, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Veg. Do Pyaza', 'veg. do pyaza', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. do pyaza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001213, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001213, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001214, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Veg. Bhuna Masala', 'veg. bhuna masala', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. bhuna masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001214, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001214, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001215, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Veg. Diwani Handi', 'veg. diwani handi', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. diwani handi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001215, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001215, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001216, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Mushroom Mazzedar', 'mushroom mazzedar', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom mazzedar'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001216, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001216, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001217, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Kaju Makhani', 'kaju makhani', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju makhani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001217, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001217, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001218, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Kaju Masala', 'kaju masala', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001218, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001218, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001219, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Kaju Paneer Masala', 'kaju paneer masala', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju paneer masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001219, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001219, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001220, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Paneer Diwani Handi', 'paneer diwani handi', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'split-paneer-mushroom-diwani-handi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer diwani handi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001220, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001220, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001221, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Mushroom Diwani Handi', 'mushroom diwani handi', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'split-paneer-mushroom-diwani-handi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom diwani handi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001221, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001221, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001222, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Paneer Do Pyaza', 'paneer do pyaza', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer do pyaza'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001222, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001222, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001223, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Paneer Lazeez', 'paneer lazeez', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer lazeez'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001223, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001223, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001224, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Paneer Seekh Kabab Masala', 'paneer seekh kabab masala', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer seekh kabab masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001224, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001224, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001225, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Veg. Angoori Kofta', 'veg. angoori kofta', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. angoori kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001225, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001225, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001226, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Paneer', 'paneer', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'split-paneer-cheese', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001226, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001226, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.50, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.50 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001227, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Cheese', 'cheese', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'split-paneer-cheese', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001227, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001227, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.50, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.50 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001228, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Angoori Kofta', 'angoori kofta', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'angoori kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001228, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001228, new_variant.variant_id, 380.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPECIAL SHAKAHARI DAWAT" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001229, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001013, 'Veg. Tiranga', 'veg. tiranga', 'SPECIAL SHAKAHARI DAWAT', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. tiranga'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001229, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001229, new_variant.variant_id, 400.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001230, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Roti', 'roti', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001230, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001230, new_variant.variant_id, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001231, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Butter Roti', 'butter roti', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001231, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001231, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001232, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Palak Roti', 'palak roti', 'TANDOOR ROTI', 'veg', 'split-palak-roti-pudina-roti', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'palak roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001232, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001232, new_variant.variant_id, 62.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001233, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Pudina Roti', 'pudina roti', 'TANDOOR ROTI', 'veg', 'split-palak-roti-pudina-roti', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pudina roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001233, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001233, new_variant.variant_id, 62.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001234, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Missi Roti', 'missi roti', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'missi roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001234, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001234, new_variant.variant_id, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001235, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Makkai ki Roti', 'makkai ki roti', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'makkai ki roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001235, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001235, new_variant.variant_id, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001236, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Paratha', 'paratha', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001236, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001236, new_variant.variant_id, 57.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001237, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Butter Paratha', 'butter paratha', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001237, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001237, new_variant.variant_id, 67.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001238, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Methi Paratha', 'methi paratha', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'methi paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001238, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001238, new_variant.variant_id, 75.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001239, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Alu Paratha', 'alu paratha', 'TANDOOR ROTI', 'veg', 'split-alu-paratha-stuffed-paratha', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'alu paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001239, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001239, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001240, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Stuffed Paratha', 'stuffed paratha', 'TANDOOR ROTI', 'veg', 'split-alu-paratha-stuffed-paratha', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'stuffed paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001240, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001240, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001241, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Naan', 'naan', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001241, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001241, new_variant.variant_id, 57.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001242, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Butter Naan', 'butter naan', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001242, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001242, new_variant.variant_id, 67.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001243, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Cheese Naan', 'cheese naan', 'TANDOOR ROTI', 'veg', 'split-cheese-naan-paneer-naan', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001243, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001243, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001244, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Paneer Naan', 'paneer naan', 'TANDOOR ROTI', 'veg', 'split-cheese-naan-paneer-naan', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001244, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001244, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001245, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Kashmiri Naan', 'kashmiri naan', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kashmiri naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001245, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001245, new_variant.variant_id, 95.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001246, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Garlic Naan', 'garlic naan', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'garlic naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001246, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001246, new_variant.variant_id, 57.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001247, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Kulcha', 'kulcha', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kulcha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001247, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001247, new_variant.variant_id, 67.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001248, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Butter Kulcha', 'butter kulcha', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter kulcha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001248, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001248, new_variant.variant_id, 67.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001249, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Cheese Kulcha', 'cheese kulcha', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese kulcha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001249, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001249, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "TANDOOR ROTI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001250, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001014, 'Bhatura', 'bhatura', 'TANDOOR ROTI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bhatura'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001250, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001250, new_variant.variant_id, 62.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "DAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001251, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001015, 'Dahi Kadhi Pakoda', 'dahi kadhi pakoda', 'DAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dahi kadhi pakoda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001251, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001251, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "DAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001252, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001015, 'Dal Kolhapuri', 'dal kolhapuri', 'DAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal kolhapuri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001252, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001252, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "DAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001253, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001015, 'Dal Palak', 'dal palak', 'DAL', 'veg', 'split-dal-palak-dal-tadka', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001253, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001253, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "DAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001254, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001015, 'Dal Tadka', 'dal tadka', 'DAL', 'veg', 'split-dal-palak-dal-tadka', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal tadka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001254, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001254, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "DAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001255, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001015, 'Butter Dal Fry', 'butter dal fry', 'DAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter dal fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001255, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001255, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "DAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001256, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001015, 'Dal Fry', 'dal fry', 'DAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001256, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001256, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "DAL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001257, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001015, 'Plain Dal', 'plain dal', 'DAL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'plain dal'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001257, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001257, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001258, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Steamed Rice', 'steamed rice', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'steamed rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001258, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001258, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001259, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Jeera Rice', 'jeera rice', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jeera rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001259, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001259, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001260, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Curd Rice', 'curd rice', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'curd rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001260, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001260, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001261, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Veg. Pulav', 'veg. pulav', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001261, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001261, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001262, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Green Peas Pulav', 'green peas pulav', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green peas pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001262, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001262, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001263, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Veg. Kashmiri Pulav', 'veg. kashmiri pulav', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kashmiri pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001263, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001263, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001264, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Veg. Paneer Pulav', 'veg. paneer pulav', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. paneer pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001264, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001264, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001265, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Veg. Biryani', 'veg. biryani', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001265, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001265, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001266, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Veg. Cheese Biryani', 'veg. cheese biryani', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. cheese biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001266, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001266, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001267, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Veg. Paneer Biryani', 'veg. paneer biryani', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. paneer biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001267, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001267, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001268, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Veg. Handi Biryani', 'veg. handi biryani', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. handi biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001268, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001268, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001269, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Mushroom Biryani', 'mushroom biryani', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001269, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001269, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001270, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Hyderabadi Biryani', 'hyderabadi biryani', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hyderabadi biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001270, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001270, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001271, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Tawa Pulav', 'tawa pulav', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tawa pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001271, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001271, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001272, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Paneer Tawa Pulav', 'paneer tawa pulav', 'RICE/ BIRYANI/ PULAV', 'veg', 'split-paneer-cheese-tawa-pulav', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tawa pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001272, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001272, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001273, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Cheese Tawa Pulav', 'cheese tawa pulav', 'RICE/ BIRYANI/ PULAV', 'veg', 'split-paneer-cheese-tawa-pulav', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese tawa pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001273, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001273, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001274, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Dal Khichdi Tadkewali', 'dal khichdi tadkewali', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal khichdi tadkewali'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001274, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001274, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001275, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Dal Khichdi', 'dal khichdi', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal khichdi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001275, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001275, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE/ BIRYANI/ PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001276, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001016, 'Palak Khichdi', 'palak khichdi', 'RICE/ BIRYANI/ PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'palak khichdi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001276, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001276, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES — SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001277, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001017, 'Veg. Asian Green Soup', 'veg. asian green soup', 'CHINESE DISHES — SOUPS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. asian green soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001277, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001277, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES — SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001278, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001017, 'Veg. Tom Yum Soup', 'veg. tom yum soup', 'CHINESE DISHES — SOUPS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. tom yum soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001278, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001278, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES — SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001279, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001017, 'Veg. Sweet & Sour Soup', 'veg. sweet & sour soup', 'CHINESE DISHES — SOUPS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. sweet & sour soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001279, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001279, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES — SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001280, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001017, 'Veg. Lung Fung Soup', 'veg. lung fung soup', 'CHINESE DISHES — SOUPS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. lung fung soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001280, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001280, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES — SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001281, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001017, 'Veg. Sweet Corn Soup', 'veg. sweet corn soup', 'CHINESE DISHES — SOUPS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. sweet corn soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001281, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001281, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES — SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001282, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001017, 'Plain Sweet Corn Soup', 'plain sweet corn soup', 'CHINESE DISHES — SOUPS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'plain sweet corn soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001282, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001282, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES — SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001283, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001017, 'Veg. Manchow Soup', 'veg. manchow soup', 'CHINESE DISHES — SOUPS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. manchow soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001283, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001283, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES — SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001284, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001017, 'Veg. Hot-N-Sour Soup', 'veg. hot-n-sour soup', 'CHINESE DISHES — SOUPS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hot-n-sour soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001284, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001284, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES — SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001285, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001017, 'Veg. Noodle Soup', 'veg. noodle soup', 'CHINESE DISHES — SOUPS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. noodle soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001285, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001285, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES — SOUPS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001286, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001017, 'Veg. Manchurian Soup', 'veg. manchurian soup', 'CHINESE DISHES — SOUPS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. manchurian soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001286, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001286, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001287, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Mushroom Babycorn Chilli', 'mushroom babycorn chilli', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom babycorn chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001287, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001287, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001288, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Mushroom Manchurian', 'mushroom manchurian', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001288, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001288, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001289, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Mushroom Paneer Manchurian', 'mushroom paneer manchurian', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom paneer manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001289, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001289, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001290, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Mushroom Paneer Schezwan', 'mushroom paneer schezwan', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom paneer schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001290, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001290, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001291, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Mushroom Babycorn Manchurian', 'mushroom babycorn manchurian', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom babycorn manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001291, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001291, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001292, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Paneer Butter Garlic', 'paneer butter garlic', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer butter garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001292, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001292, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001293, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Paneer Hot Garlic', 'paneer hot garlic', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer hot garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001293, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001293, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001294, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Paneer Chilli', 'paneer chilli', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001294, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001294, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001295, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Paneer Mushroom Chilli', 'paneer mushroom chilli', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer mushroom chilli'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001295, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001295, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001296, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Paneer Manchurian', 'paneer manchurian', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001296, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001296, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001297, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Paneer Schezwan', 'paneer schezwan', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001297, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001297, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001298, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Paneer Singapore', 'paneer singapore', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer singapore'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001298, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001298, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001299, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Paneer 65', 'paneer 65', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer 65'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001299, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001299, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001300, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Paneer Salt & Pepper', 'paneer salt & pepper', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer salt & pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001300, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001300, new_variant.variant_id, 360.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001301, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Paneer Splendour', 'paneer splendour', 'STARTERS & CHINESE VEG.', 'veg', 'split-paneer-babycorn-splendour', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer splendour'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001301, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001301, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001302, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Babycorn Splendour', 'babycorn splendour', 'STARTERS & CHINESE VEG.', 'veg', 'split-paneer-babycorn-splendour', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'babycorn splendour'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001302, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001302, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001303, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Paneer Splendour', 'paneer splendour', 'STARTERS & CHINESE VEG.', 'veg', 'split-paneer-mushroom-splendour', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer splendour'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001303, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001303, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001304, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Mushroom Splendour', 'mushroom splendour', 'STARTERS & CHINESE VEG.', 'veg', 'split-paneer-mushroom-splendour', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom splendour'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001304, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001304, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001305, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Babycorn Splendour', 'babycorn splendour', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'babycorn splendour'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001305, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001305, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001306, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Veg. Lollypop', 'veg. lollypop', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. lollypop'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001306, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001306, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001307, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Veg. Spring Roll', 'veg. spring roll', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. spring roll'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001307, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001307, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001308, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Veg. Finger Schezwan', 'veg. finger schezwan', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. finger schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001308, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001308, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001309, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Babycorn Schezwan', 'babycorn schezwan', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'babycorn schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001309, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001309, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001310, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Veg. Hong Kong', 'veg. hong kong', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hong kong'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001310, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001310, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001311, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Veg. Manchurian', 'veg. manchurian', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001311, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001311, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001312, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Flower Manchurian', 'flower manchurian', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'flower manchurian'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001312, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001312, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001313, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Veg. 65', 'veg. 65', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. 65'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001313, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001313, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001314, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Veg. Schezwan', 'veg. schezwan', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001314, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001314, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001315, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Veg. Crispy', 'veg. crispy', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. crispy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001315, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001315, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001316, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Crispy Potato', 'crispy potato', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'crispy potato'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001316, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001316, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001317, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Veg. Gold Coin', 'veg. gold coin', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. gold coin'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001317, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001317, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001318, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Corn Cheese Balls', 'corn cheese balls', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'corn cheese balls'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001318, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001318, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001319, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Corn Cheese Tokri', 'corn cheese tokri', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'corn cheese tokri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001319, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001319, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001320, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'American Chopsuey', 'american chopsuey', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'american chopsuey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001320, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001320, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001321, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Chinese Chopsuey', 'chinese chopsuey', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chinese chopsuey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001321, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001321, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001322, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Idli Chilli', 'idli chilli', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'idli chilli'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081001322, 'Dry', TRUE), (400081001323, 'Gravy', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081001322, 'Dry', 280.00, FALSE), (400081001323, 'Gravy', 280.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.88, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.88 FROM new_prices, ctx;

-- Source: docx/json, "STARTERS & CHINESE VEG." section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001323, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001018, 'Chinese Bhel', 'chinese bhel', 'STARTERS & CHINESE VEG.', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chinese bhel'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001324, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001324, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001324, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Hakka Noodles', 'veg. hakka noodles', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hakka noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001325, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001325, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001325, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Schezwan Noodles', 'veg. schezwan noodles', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. schezwan noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001326, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001326, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001326, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Singapore Noodles', 'veg. singapore noodles', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. singapore noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001327, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001327, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001327, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Hong Kong Noodles', 'veg. hong kong noodles', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hong kong noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001328, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001328, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001328, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Chilli Garlic Noodles', 'veg. chilli garlic noodles', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chilli garlic noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001329, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001329, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001329, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Burnt Garlic Noodles', 'veg. burnt garlic noodles', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. burnt garlic noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001330, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001330, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001330, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Malaysian Noodles', 'veg. malaysian noodles', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. malaysian noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001331, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001331, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001331, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Triple Schezwan Noodles', 'veg. triple schezwan noodles', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. triple schezwan noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001332, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001332, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001332, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Jeera Fried Rice', 'jeera fried rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jeera fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001333, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001333, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001333, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Fried Rice', 'veg. fried rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001334, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001334, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001334, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Schezwan Rice', 'veg. schezwan rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. schezwan rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001335, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001335, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001335, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Hongkong Rice', 'veg. hongkong rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hongkong rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001336, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001336, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001336, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Singapore Rice', 'veg. singapore rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. singapore rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001337, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001337, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001337, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Chilli Garlic Rice', 'veg. chilli garlic rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chilli garlic rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001338, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001338, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001338, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Burnt Garlic Rice', 'veg. burnt garlic rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. burnt garlic rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001339, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001339, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001339, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Peas Fried Rice', 'peas fried rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'peas fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001340, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001340, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001340, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Combination Rice', 'combination rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'combination rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001341, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001341, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001341, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Paneer Fried Rice', 'paneer fried rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001342, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001342, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001342, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Mushroom Fried Rice', 'mushroom fried rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001343, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001343, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001343, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Mushroom Combination Rice', 'mushroom combination rice', 'NOODLES / RICE', 'veg', 'split-mushroom-schezwan-combination-rice', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom combination rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001344, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001344, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001344, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Schezwan Combination Rice', 'schezwan combination rice', 'NOODLES / RICE', 'veg', 'split-mushroom-schezwan-combination-rice', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'schezwan combination rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001345, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001345, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001345, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Mix Fried Rice', 'mix fried rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001346, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001346, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001346, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Peking Rice', 'peking rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'peking rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001347, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001347, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001347, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Veg. Malaysian Rice', 'veg. malaysian rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. malaysian rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001348, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001348, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "NOODLES / RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001348, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001019, 'Triple Schezwan Fried Rice', 'triple schezwan fried rice', 'NOODLES / RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'triple schezwan fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001349, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001349, new_variant.variant_id, 370.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "JUICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001349, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001020, 'Mosambi', 'mosambi', 'JUICES', 'veg', 'split-mosambi-water-melon', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mosambi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001350, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001350, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "JUICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001350, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001020, 'Water Melon', 'water melon', 'JUICES', 'veg', 'split-mosambi-water-melon', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'water melon'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001351, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001351, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "JUICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001351, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001020, 'Orange', 'orange', 'JUICES', 'veg', 'split-orange-pineapple', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'orange'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001352, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001352, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "JUICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001352, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001020, 'Pineapple', 'pineapple', 'JUICES', 'veg', 'split-orange-pineapple', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pineapple'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001353, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001353, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "JUICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001353, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001020, 'Ganga Jamuna', 'ganga jamuna', 'JUICES', 'veg', 'split-ganga-jamuna-maramari', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ganga jamuna'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001354, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001354, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "JUICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001354, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001020, 'Maramari', 'maramari', 'JUICES', 'veg', 'split-ganga-jamuna-maramari', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'maramari'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001355, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001355, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "JUICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001355, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001020, 'Cocktail', 'cocktail', 'JUICES', 'veg', 'split-cocktail-apple-grapes', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cocktail'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001356, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001356, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "JUICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001356, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001020, 'Apple', 'apple', 'JUICES', 'veg', 'split-cocktail-apple-grapes', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'apple'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001357, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001357, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "JUICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001357, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001020, 'Grapes', 'grapes', 'JUICES', 'veg', 'split-cocktail-apple-grapes', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'grapes'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001358, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001358, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "JUICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001358, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001020, 'Mango (Seasonal)', 'mango (seasonal)', 'JUICES', 'veg', 'split-mango-seasonal-strawberry', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango (seasonal)'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001359, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001359, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "JUICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001359, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001020, 'Strawberry', 'strawberry', 'JUICES', 'veg', 'split-mango-seasonal-strawberry', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'strawberry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001360, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001360, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "JUICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001360, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001020, 'Fresh Lime Juice', 'fresh lime juice', 'JUICES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fresh lime juice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001361, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001361, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "JUICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001361, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001020, 'Fresh Lime Soda', 'fresh lime soda', 'JUICES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fresh lime soda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001362, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001362, new_variant.variant_id, 85.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "JUICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001362, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001020, 'Ginger Lemon', 'ginger lemon', 'JUICES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ginger lemon'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001363, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001363, new_variant.variant_id, 85.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FALOODAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001363, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001021, 'Rose Falooda', 'rose falooda', 'FALOODAS', 'veg', 'split-rose-falooda-kesar-falooda', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rose falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001364, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001364, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FALOODAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001364, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001021, 'Kesar Falooda', 'kesar falooda', 'FALOODAS', 'veg', 'split-rose-falooda-kesar-falooda', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kesar falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001365, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001365, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FALOODAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001365, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001021, 'Kulfi Falooda', 'kulfi falooda', 'FALOODAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kulfi falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001366, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001366, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FALOODAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001366, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001021, 'Dry Fruits Falooda', 'dry fruits falooda', 'FALOODAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dry fruits falooda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001367, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001367, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001367, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Vanilla', 'vanilla', 'MILK SHAKES', 'veg', 'split-vanilla-banana-rose', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'vanilla'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001368, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001368, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001368, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Banana', 'banana', 'MILK SHAKES', 'veg', 'split-vanilla-banana-rose', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'banana'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001369, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001369, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001369, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Rose', 'rose', 'MILK SHAKES', 'veg', 'split-vanilla-banana-rose', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rose'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001370, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001370, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001370, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Chikoo', 'chikoo', 'MILK SHAKES', 'veg', 'split-chikoo-pineapple', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chikoo'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001371, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001371, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001371, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Pineapple', 'pineapple', 'MILK SHAKES', 'veg', 'split-chikoo-pineapple', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pineapple'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001372, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001372, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001372, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Chocolate', 'chocolate', 'MILK SHAKES', 'veg', 'split-chocolate-kesar-apple', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chocolate'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001373, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001373, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001373, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Kesar', 'kesar', 'MILK SHAKES', 'veg', 'split-chocolate-kesar-apple', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kesar'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001374, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001374, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001374, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Apple', 'apple', 'MILK SHAKES', 'veg', 'split-chocolate-kesar-apple', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'apple'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001375, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001375, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001375, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Mango', 'mango', 'MILK SHAKES', 'veg', 'split-mango-sitaphal-strawberry', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001376, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001376, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001376, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Sitaphal', 'sitaphal', 'MILK SHAKES', 'veg', 'split-mango-sitaphal-strawberry', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sitaphal'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001377, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001377, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001377, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Strawberry', 'strawberry', 'MILK SHAKES', 'veg', 'split-mango-sitaphal-strawberry', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'strawberry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001378, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001378, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001378, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Dry Fruit', 'dry fruit', 'MILK SHAKES', 'veg', 'split-dry-fruit-pista-badam', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dry fruit'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001379, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001379, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001379, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Pista', 'pista', 'MILK SHAKES', 'veg', 'split-dry-fruit-pista-badam', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pista'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001380, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001380, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001380, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Badam', 'badam', 'MILK SHAKES', 'veg', 'split-dry-fruit-pista-badam', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'badam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001381, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001381, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001381, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Kesar Badam', 'kesar badam', 'MILK SHAKES', 'veg', 'split-kesar-badam-kaju-anjir', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kesar badam'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001382, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001382, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "MILK SHAKES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001382, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001022, 'Kaju Anjir', 'kaju anjir', 'MILK SHAKES', 'veg', 'split-kesar-badam-kaju-anjir', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kaju anjir'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001383, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001383, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "COOLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001383, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001023, 'Cold Coffee', 'cold coffee', 'COOLERS', 'veg', 'split-cold-coffee-hazelnut-coffee', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cold coffee'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001384, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001384, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "COOLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001384, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001023, 'Hazelnut Coffee', 'hazelnut coffee', 'COOLERS', 'veg', 'split-cold-coffee-hazelnut-coffee', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hazelnut coffee'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001385, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001385, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "COOLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001385, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001023, 'Cold Coffee With Ice-cream', 'cold coffee with ice-cream', 'COOLERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cold coffee with ice-cream'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001386, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001386, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "COOLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001386, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001023, 'Sweet Lassi', 'sweet lassi', 'COOLERS', 'veg', 'split-sweet-salted-lassi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001387, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001387, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "COOLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001387, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001023, 'Salted Lassi', 'salted lassi', 'COOLERS', 'veg', 'split-sweet-salted-lassi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'salted lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001388, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001388, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.85, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.85 FROM new_price, ctx;

-- Source: docx/json, "COOLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001388, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001023, 'Mango Lassi', 'mango lassi', 'COOLERS', 'veg', 'split-mango-rose-kesar-lassi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001389, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001389, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "COOLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001389, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001023, 'Rose Lassi', 'rose lassi', 'COOLERS', 'veg', 'split-mango-rose-kesar-lassi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'rose lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001390, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001390, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "COOLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001390, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001023, 'Kesar Lassi', 'kesar lassi', 'COOLERS', 'veg', 'split-mango-rose-kesar-lassi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kesar lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001391, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001391, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "COOLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001391, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001023, 'Chaas', 'chaas', 'COOLERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chaas'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001392, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001392, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "COOLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001392, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001023, 'Aerated Waters', 'aerated waters', 'COOLERS', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aerated waters'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001393, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081001393, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "COOLERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001393, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001023, 'Mineral Water', 'mineral water', 'COOLERS', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mineral water'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001394, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081001394, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FRUIT SALADS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001394, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001024, 'Fruit Salad', 'fruit salad', 'FRUIT SALADS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit salad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001395, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001395, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRUIT SALADS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001395, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001024, 'Fruit Salad with Ice Cream', 'fruit salad with ice cream', 'FRUIT SALADS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit salad with ice cream'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001396, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001396, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRUIT SALADS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001396, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001024, 'Fruit Salad with Jelly', 'fruit salad with jelly', 'FRUIT SALADS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit salad with jelly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001397, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001397, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRUIT SALADS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001397, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001024, 'Fruit Salad with Jelly & Ice Cream', 'fruit salad with jelly & ice cream', 'FRUIT SALADS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'fruit salad with jelly & ice cream'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001398, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001398, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRUIT SALADS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001398, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001024, 'Jelly', 'jelly', 'FRUIT SALADS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jelly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001399, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001399, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FRUIT SALADS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001399, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001024, 'Jelly with Ice Cream', 'jelly with ice cream', 'FRUIT SALADS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'jelly with ice cream'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001400, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001400, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "KULFI SLICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001400, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001025, 'Malai Kulfi', 'malai kulfi', 'KULFI SLICES', 'veg', 'split-malai-kesar-pista-mango', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'malai kulfi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001401, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001401, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.75, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.80 FROM new_price, ctx;

-- Source: docx/json, "KULFI SLICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001401, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001025, 'Kesar Pista Kulfi', 'kesar pista kulfi', 'KULFI SLICES', 'veg', 'split-malai-kesar-pista-mango', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kesar pista kulfi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001402, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001402, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.75, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.80 FROM new_price, ctx;

-- Source: docx/json, "KULFI SLICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001402, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001025, 'Mango Kulfi', 'mango kulfi', 'KULFI SLICES', 'veg', 'split-malai-kesar-pista-mango', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mango kulfi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001403, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001403, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.75, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.80 FROM new_price, ctx;

-- Source: docx/json, "KULFI SLICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001403, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001025, 'Badam Kulfi', 'badam kulfi', 'KULFI SLICES', 'veg', 'split-badam-pista-sitaphal-kulfi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'badam kulfi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001404, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001404, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "KULFI SLICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001404, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001025, 'Pista Kulfi', 'pista kulfi', 'KULFI SLICES', 'veg', 'split-badam-pista-sitaphal-kulfi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'pista kulfi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001405, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001405, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "KULFI SLICES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001405, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001025, 'Sitaphal Kulfi', 'sitaphal kulfi', 'KULFI SLICES', 'veg', 'split-badam-pista-sitaphal-kulfi', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sitaphal kulfi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001406, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001406, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "DESSERTS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001406, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001026, 'Hot Chocolate Vanilla', 'hot chocolate vanilla', 'DESSERTS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'hot chocolate vanilla'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001407, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001407, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "EXTRAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001407, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001027, 'Sambar', 'sambar', 'EXTRAS', 'veg', 'split-sambar-chutney', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sambar'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001408, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001408, new_variant.variant_id, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "EXTRAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001408, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001027, 'Chutney', 'chutney', 'EXTRAS', 'veg', 'split-sambar-chutney', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chutney'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001409, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001409, new_variant.variant_id, 20.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "EXTRAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001409, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001027, 'Ghee', 'ghee', 'EXTRAS', 'veg', 'split-ghee-butter', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ghee'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001410, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001410, new_variant.variant_id, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "EXTRAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081001410, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001027, 'Butter', 'butter', 'EXTRAS', 'veg', 'split-ghee-butter', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001411, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001411, new_variant.variant_id, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "EXTRAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001411, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001027, 'Cheese', 'cheese', 'EXTRAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001412, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001412, new_variant.variant_id, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "EXTRAS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081001412, ctx.restaurant_id, item_cd.canonical_dish_id, 400081001027, 'Ice Cream Scoop', 'ice cream scoop', 'EXTRAS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'ice cream scoop'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081001413, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081001413, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- -----------------------------------------------------------------------
-- One menu board per restaurant, linked to every category and every item.
-- board_type_code = 'a_la_carte': none of this batch's sources describe a
-- buffet/thali/combo-style board, just a standard printed menu.
-- -----------------------------------------------------------------------
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code)
SELECT 400081001001, ctx.restaurant_id, 'Main Menu', 'a_la_carte' FROM khaustan_onboarding_ctx ctx;

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
SELECT ctx.restaurant_id, 400081001001, x.menu_category_id, x.display_sequence
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400081001001, 1), (400081001002, 2), (400081001003, 3), (400081001004, 4), (400081001005, 5), (400081001006, 6), (400081001007, 7), (400081001008, 8), (400081001009, 9), (400081001010, 10), (400081001011, 11), (400081001012, 12), (400081001013, 13), (400081001014, 14), (400081001015, 15), (400081001016, 16), (400081001017, 17), (400081001018, 18), (400081001019, 19), (400081001020, 20), (400081001021, 21), (400081001022, 22), (400081001023, 23), (400081001024, 24), (400081001025, 25), (400081001026, 26), (400081001027, 27)) AS x(menu_category_id, display_sequence);

INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence, is_featured)
SELECT x.menu_board_item_id, ctx.restaurant_id, 400081001001, x.menu_item_id, x.menu_category_id, x.display_sequence, x.is_featured
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400081001001, 400081001001, 400081001001, 1, FALSE), (400081001002, 400081001002, 400081001001, 2, FALSE), (400081001003, 400081001003, 400081001001, 3, FALSE), (400081001004, 400081001004, 400081001001, 4, FALSE), (400081001005, 400081001005, 400081001001, 5, FALSE), (400081001006, 400081001006, 400081001001, 6, FALSE), (400081001007, 400081001007, 400081001001, 7, FALSE), (400081001008, 400081001008, 400081001001, 8, FALSE), (400081001009, 400081001009, 400081001001, 9, FALSE), (400081001010, 400081001010, 400081001001, 10, FALSE), (400081001011, 400081001011, 400081001001, 11, FALSE), (400081001012, 400081001012, 400081001001, 12, FALSE), (400081001013, 400081001013, 400081001001, 13, FALSE), (400081001014, 400081001014, 400081001001, 14, FALSE), (400081001015, 400081001015, 400081001001, 15, FALSE), (400081001016, 400081001016, 400081001001, 16, FALSE), (400081001017, 400081001017, 400081001001, 17, FALSE), (400081001018, 400081001018, 400081001001, 18, FALSE), (400081001019, 400081001019, 400081001001, 19, FALSE), (400081001020, 400081001020, 400081001001, 20, FALSE), (400081001021, 400081001021, 400081001001, 21, FALSE), (400081001022, 400081001022, 400081001001, 22, FALSE), (400081001023, 400081001023, 400081001001, 23, FALSE), (400081001024, 400081001024, 400081001001, 24, FALSE), (400081001025, 400081001025, 400081001001, 25, FALSE), (400081001026, 400081001026, 400081001001, 26, FALSE), (400081001027, 400081001027, 400081001001, 27, FALSE), (400081001028, 400081001028, 400081001001, 28, FALSE), (400081001029, 400081001029, 400081001001, 29, FALSE), (400081001030, 400081001030, 400081001001, 30, FALSE), (400081001031, 400081001031, 400081001001, 31, FALSE), (400081001032, 400081001032, 400081001001, 32, FALSE), (400081001033, 400081001033, 400081001001, 33, FALSE), (400081001034, 400081001034, 400081001001, 34, FALSE), (400081001035, 400081001035, 400081001001, 35, FALSE), (400081001036, 400081001036, 400081001002, 36, FALSE), (400081001037, 400081001037, 400081001002, 37, FALSE), (400081001038, 400081001038, 400081001002, 38, FALSE), (400081001039, 400081001039, 400081001002, 39, FALSE), (400081001040, 400081001040, 400081001002, 40, FALSE), (400081001041, 400081001041, 400081001002, 41, FALSE), (400081001042, 400081001042, 400081001002, 42, FALSE), (400081001043, 400081001043, 400081001002, 43, FALSE), (400081001044, 400081001044, 400081001002, 44, FALSE), (400081001045, 400081001045, 400081001002, 45, FALSE), (400081001046, 400081001046, 400081001002, 46, FALSE), (400081001047, 400081001047, 400081001002, 47, FALSE), (400081001048, 400081001048, 400081001002, 48, FALSE), (400081001049, 400081001049, 400081001002, 49, FALSE), (400081001050, 400081001050, 400081001002, 50, FALSE), (400081001051, 400081001051, 400081001002, 51, FALSE), (400081001052, 400081001052, 400081001003, 52, FALSE), (400081001053, 400081001053, 400081001003, 53, FALSE), (400081001054, 400081001054, 400081001003, 54, FALSE), (400081001055, 400081001055, 400081001003, 55, FALSE), (400081001056, 400081001056, 400081001003, 56, FALSE), (400081001057, 400081001057, 400081001003, 57, FALSE), (400081001058, 400081001058, 400081001004, 58, FALSE), (400081001059, 400081001059, 400081001004, 59, FALSE), (400081001060, 400081001060, 400081001004, 60, FALSE), (400081001061, 400081001061, 400081001004, 61, FALSE), (400081001062, 400081001062, 400081001004, 62, FALSE), (400081001063, 400081001063, 400081001005, 63, FALSE), (400081001064, 400081001064, 400081001005, 64, FALSE), (400081001065, 400081001065, 400081001005, 65, FALSE), (400081001066, 400081001066, 400081001005, 66, FALSE), (400081001067, 400081001067, 400081001005, 67, FALSE), (400081001068, 400081001068, 400081001005, 68, FALSE), (400081001069, 400081001069, 400081001005, 69, FALSE), (400081001070, 400081001070, 400081001005, 70, FALSE), (400081001071, 400081001071, 400081001005, 71, FALSE), (400081001072, 400081001072, 400081001005, 72, FALSE), (400081001073, 400081001073, 400081001005, 73, FALSE), (400081001074, 400081001074, 400081001005, 74, FALSE), (400081001075, 400081001075, 400081001005, 75, FALSE), (400081001076, 400081001076, 400081001005, 76, FALSE), (400081001077, 400081001077, 400081001005, 77, FALSE), (400081001078, 400081001078, 400081001005, 78, FALSE), (400081001079, 400081001079, 400081001005, 79, FALSE), (400081001080, 400081001080, 400081001005, 80, FALSE), (400081001081, 400081001081, 400081001005, 81, FALSE), (400081001082, 400081001082, 400081001005, 82, FALSE), (400081001083, 400081001083, 400081001006, 83, FALSE), (400081001084, 400081001084, 400081001006, 84, FALSE), (400081001085, 400081001085, 400081001006, 85, FALSE), (400081001086, 400081001086, 400081001007, 86, FALSE), (400081001087, 400081001087, 400081001007, 87, FALSE), (400081001088, 400081001088, 400081001007, 88, FALSE), (400081001089, 400081001089, 400081001007, 89, FALSE), (400081001090, 400081001090, 400081001007, 90, FALSE), (400081001091, 400081001091, 400081001007, 91, FALSE), (400081001092, 400081001092, 400081001007, 92, FALSE), (400081001093, 400081001093, 400081001007, 93, FALSE), (400081001094, 400081001094, 400081001007, 94, FALSE), (400081001095, 400081001095, 400081001007, 95, FALSE), (400081001096, 400081001096, 400081001008, 96, FALSE), (400081001097, 400081001097, 400081001008, 97, FALSE), (400081001098, 400081001098, 400081001008, 98, FALSE), (400081001099, 400081001099, 400081001008, 99, FALSE), (400081001100, 400081001100, 400081001008, 100, FALSE), (400081001101, 400081001101, 400081001008, 101, FALSE), (400081001102, 400081001102, 400081001008, 102, FALSE), (400081001103, 400081001103, 400081001008, 103, FALSE), (400081001104, 400081001104, 400081001008, 104, FALSE), (400081001105, 400081001105, 400081001008, 105, FALSE), (400081001106, 400081001106, 400081001008, 106, FALSE), (400081001107, 400081001107, 400081001009, 107, FALSE), (400081001108, 400081001108, 400081001009, 108, FALSE), (400081001109, 400081001109, 400081001009, 109, FALSE), (400081001110, 400081001110, 400081001009, 110, FALSE), (400081001111, 400081001111, 400081001009, 111, FALSE), (400081001112, 400081001112, 400081001009, 112, FALSE), (400081001113, 400081001113, 400081001009, 113, FALSE), (400081001114, 400081001114, 400081001009, 114, FALSE), (400081001115, 400081001115, 400081001009, 115, FALSE), (400081001116, 400081001116, 400081001009, 116, FALSE), (400081001117, 400081001117, 400081001009, 117, FALSE), (400081001118, 400081001118, 400081001009, 118, FALSE), (400081001119, 400081001119, 400081001009, 119, FALSE), (400081001120, 400081001120, 400081001009, 120, FALSE), (400081001121, 400081001121, 400081001009, 121, FALSE), (400081001122, 400081001122, 400081001010, 122, FALSE), (400081001123, 400081001123, 400081001010, 123, FALSE), (400081001124, 400081001124, 400081001010, 124, FALSE), (400081001125, 400081001125, 400081001010, 125, FALSE), (400081001126, 400081001126, 400081001010, 126, FALSE), (400081001127, 400081001127, 400081001010, 127, FALSE), (400081001128, 400081001128, 400081001010, 128, FALSE), (400081001129, 400081001129, 400081001010, 129, FALSE), (400081001130, 400081001130, 400081001010, 130, FALSE), (400081001131, 400081001131, 400081001010, 131, FALSE), (400081001132, 400081001132, 400081001010, 132, FALSE), (400081001133, 400081001133, 400081001011, 133, FALSE), (400081001134, 400081001134, 400081001011, 134, FALSE), (400081001135, 400081001135, 400081001011, 135, FALSE), (400081001136, 400081001136, 400081001011, 136, FALSE), (400081001137, 400081001137, 400081001012, 137, FALSE), (400081001138, 400081001138, 400081001012, 138, FALSE), (400081001139, 400081001139, 400081001012, 139, FALSE), (400081001140, 400081001140, 400081001012, 140, FALSE), (400081001141, 400081001141, 400081001012, 141, FALSE), (400081001142, 400081001142, 400081001012, 142, FALSE), (400081001143, 400081001143, 400081001012, 143, FALSE), (400081001144, 400081001144, 400081001012, 144, FALSE), (400081001145, 400081001145, 400081001012, 145, FALSE), (400081001146, 400081001146, 400081001012, 146, FALSE), (400081001147, 400081001147, 400081001012, 147, FALSE), (400081001148, 400081001148, 400081001012, 148, FALSE), (400081001149, 400081001149, 400081001012, 149, FALSE), (400081001150, 400081001150, 400081001012, 150, FALSE), (400081001151, 400081001151, 400081001012, 151, FALSE), (400081001152, 400081001152, 400081001012, 152, FALSE), (400081001153, 400081001153, 400081001012, 153, FALSE), (400081001154, 400081001154, 400081001012, 154, FALSE), (400081001155, 400081001155, 400081001012, 155, FALSE), (400081001156, 400081001156, 400081001012, 156, FALSE), (400081001157, 400081001157, 400081001012, 157, FALSE), (400081001158, 400081001158, 400081001012, 158, FALSE), (400081001159, 400081001159, 400081001012, 159, FALSE), (400081001160, 400081001160, 400081001012, 160, FALSE), (400081001161, 400081001161, 400081001012, 161, FALSE), (400081001162, 400081001162, 400081001012, 162, FALSE), (400081001163, 400081001163, 400081001012, 163, FALSE), (400081001164, 400081001164, 400081001012, 164, FALSE), (400081001165, 400081001165, 400081001012, 165, FALSE), (400081001166, 400081001166, 400081001012, 166, FALSE), (400081001167, 400081001167, 400081001012, 167, FALSE), (400081001168, 400081001168, 400081001012, 168, FALSE), (400081001169, 400081001169, 400081001012, 169, FALSE), (400081001170, 400081001170, 400081001012, 170, FALSE), (400081001171, 400081001171, 400081001012, 171, FALSE), (400081001172, 400081001172, 400081001012, 172, FALSE), (400081001173, 400081001173, 400081001012, 173, FALSE), (400081001174, 400081001174, 400081001012, 174, FALSE), (400081001175, 400081001175, 400081001012, 175, FALSE), (400081001176, 400081001176, 400081001012, 176, FALSE), (400081001177, 400081001177, 400081001012, 177, FALSE), (400081001178, 400081001178, 400081001012, 178, FALSE), (400081001179, 400081001179, 400081001012, 179, FALSE), (400081001180, 400081001180, 400081001012, 180, FALSE), (400081001181, 400081001181, 400081001012, 181, FALSE), (400081001182, 400081001182, 400081001012, 182, FALSE), (400081001183, 400081001183, 400081001012, 183, FALSE), (400081001184, 400081001184, 400081001012, 184, FALSE), (400081001185, 400081001185, 400081001012, 185, FALSE), (400081001186, 400081001186, 400081001012, 186, FALSE), (400081001187, 400081001187, 400081001012, 187, FALSE), (400081001188, 400081001188, 400081001012, 188, FALSE), (400081001189, 400081001189, 400081001012, 189, FALSE), (400081001190, 400081001190, 400081001012, 190, FALSE), (400081001191, 400081001191, 400081001012, 191, FALSE), (400081001192, 400081001192, 400081001012, 192, FALSE), (400081001193, 400081001193, 400081001012, 193, FALSE), (400081001194, 400081001194, 400081001012, 194, FALSE), (400081001195, 400081001195, 400081001012, 195, FALSE), (400081001196, 400081001196, 400081001012, 196, FALSE), (400081001197, 400081001197, 400081001012, 197, FALSE), (400081001198, 400081001198, 400081001012, 198, FALSE), (400081001199, 400081001199, 400081001012, 199, FALSE), (400081001200, 400081001200, 400081001012, 200, FALSE), (400081001201, 400081001201, 400081001012, 201, FALSE), (400081001202, 400081001202, 400081001012, 202, FALSE), (400081001203, 400081001203, 400081001012, 203, FALSE), (400081001204, 400081001204, 400081001012, 204, FALSE), (400081001205, 400081001205, 400081001012, 205, FALSE), (400081001206, 400081001206, 400081001012, 206, FALSE), (400081001207, 400081001207, 400081001012, 207, FALSE), (400081001208, 400081001208, 400081001012, 208, FALSE), (400081001209, 400081001209, 400081001012, 209, FALSE), (400081001210, 400081001210, 400081001012, 210, FALSE), (400081001211, 400081001211, 400081001012, 211, FALSE), (400081001212, 400081001212, 400081001012, 212, FALSE), (400081001213, 400081001213, 400081001013, 213, FALSE), (400081001214, 400081001214, 400081001013, 214, FALSE), (400081001215, 400081001215, 400081001013, 215, FALSE), (400081001216, 400081001216, 400081001013, 216, FALSE), (400081001217, 400081001217, 400081001013, 217, FALSE), (400081001218, 400081001218, 400081001013, 218, FALSE), (400081001219, 400081001219, 400081001013, 219, FALSE), (400081001220, 400081001220, 400081001013, 220, FALSE), (400081001221, 400081001221, 400081001013, 221, FALSE), (400081001222, 400081001222, 400081001013, 222, FALSE), (400081001223, 400081001223, 400081001013, 223, FALSE), (400081001224, 400081001224, 400081001013, 224, FALSE), (400081001225, 400081001225, 400081001013, 225, FALSE), (400081001226, 400081001226, 400081001013, 226, FALSE), (400081001227, 400081001227, 400081001013, 227, FALSE), (400081001228, 400081001228, 400081001013, 228, FALSE), (400081001229, 400081001229, 400081001013, 229, FALSE), (400081001230, 400081001230, 400081001014, 230, FALSE), (400081001231, 400081001231, 400081001014, 231, FALSE), (400081001232, 400081001232, 400081001014, 232, FALSE), (400081001233, 400081001233, 400081001014, 233, FALSE), (400081001234, 400081001234, 400081001014, 234, FALSE), (400081001235, 400081001235, 400081001014, 235, FALSE), (400081001236, 400081001236, 400081001014, 236, FALSE), (400081001237, 400081001237, 400081001014, 237, FALSE), (400081001238, 400081001238, 400081001014, 238, FALSE), (400081001239, 400081001239, 400081001014, 239, FALSE), (400081001240, 400081001240, 400081001014, 240, FALSE), (400081001241, 400081001241, 400081001014, 241, FALSE), (400081001242, 400081001242, 400081001014, 242, FALSE), (400081001243, 400081001243, 400081001014, 243, FALSE), (400081001244, 400081001244, 400081001014, 244, FALSE), (400081001245, 400081001245, 400081001014, 245, FALSE), (400081001246, 400081001246, 400081001014, 246, FALSE), (400081001247, 400081001247, 400081001014, 247, FALSE), (400081001248, 400081001248, 400081001014, 248, FALSE), (400081001249, 400081001249, 400081001014, 249, FALSE), (400081001250, 400081001250, 400081001014, 250, FALSE), (400081001251, 400081001251, 400081001015, 251, FALSE), (400081001252, 400081001252, 400081001015, 252, FALSE), (400081001253, 400081001253, 400081001015, 253, FALSE), (400081001254, 400081001254, 400081001015, 254, FALSE), (400081001255, 400081001255, 400081001015, 255, FALSE), (400081001256, 400081001256, 400081001015, 256, FALSE), (400081001257, 400081001257, 400081001015, 257, FALSE), (400081001258, 400081001258, 400081001016, 258, FALSE), (400081001259, 400081001259, 400081001016, 259, FALSE), (400081001260, 400081001260, 400081001016, 260, FALSE), (400081001261, 400081001261, 400081001016, 261, FALSE), (400081001262, 400081001262, 400081001016, 262, FALSE), (400081001263, 400081001263, 400081001016, 263, FALSE), (400081001264, 400081001264, 400081001016, 264, FALSE), (400081001265, 400081001265, 400081001016, 265, FALSE), (400081001266, 400081001266, 400081001016, 266, FALSE), (400081001267, 400081001267, 400081001016, 267, FALSE), (400081001268, 400081001268, 400081001016, 268, FALSE), (400081001269, 400081001269, 400081001016, 269, FALSE), (400081001270, 400081001270, 400081001016, 270, FALSE), (400081001271, 400081001271, 400081001016, 271, FALSE), (400081001272, 400081001272, 400081001016, 272, FALSE), (400081001273, 400081001273, 400081001016, 273, FALSE), (400081001274, 400081001274, 400081001016, 274, FALSE), (400081001275, 400081001275, 400081001016, 275, FALSE), (400081001276, 400081001276, 400081001016, 276, FALSE), (400081001277, 400081001277, 400081001017, 277, FALSE), (400081001278, 400081001278, 400081001017, 278, FALSE), (400081001279, 400081001279, 400081001017, 279, FALSE), (400081001280, 400081001280, 400081001017, 280, FALSE), (400081001281, 400081001281, 400081001017, 281, FALSE), (400081001282, 400081001282, 400081001017, 282, FALSE), (400081001283, 400081001283, 400081001017, 283, FALSE), (400081001284, 400081001284, 400081001017, 284, FALSE), (400081001285, 400081001285, 400081001017, 285, FALSE), (400081001286, 400081001286, 400081001017, 286, FALSE), (400081001287, 400081001287, 400081001018, 287, FALSE), (400081001288, 400081001288, 400081001018, 288, FALSE), (400081001289, 400081001289, 400081001018, 289, FALSE), (400081001290, 400081001290, 400081001018, 290, FALSE), (400081001291, 400081001291, 400081001018, 291, FALSE), (400081001292, 400081001292, 400081001018, 292, FALSE), (400081001293, 400081001293, 400081001018, 293, FALSE), (400081001294, 400081001294, 400081001018, 294, FALSE), (400081001295, 400081001295, 400081001018, 295, FALSE), (400081001296, 400081001296, 400081001018, 296, FALSE), (400081001297, 400081001297, 400081001018, 297, FALSE), (400081001298, 400081001298, 400081001018, 298, FALSE), (400081001299, 400081001299, 400081001018, 299, FALSE), (400081001300, 400081001300, 400081001018, 300, FALSE), (400081001301, 400081001301, 400081001018, 301, FALSE), (400081001302, 400081001302, 400081001018, 302, FALSE), (400081001303, 400081001303, 400081001018, 303, FALSE), (400081001304, 400081001304, 400081001018, 304, FALSE), (400081001305, 400081001305, 400081001018, 305, FALSE), (400081001306, 400081001306, 400081001018, 306, FALSE), (400081001307, 400081001307, 400081001018, 307, FALSE), (400081001308, 400081001308, 400081001018, 308, FALSE), (400081001309, 400081001309, 400081001018, 309, FALSE), (400081001310, 400081001310, 400081001018, 310, FALSE), (400081001311, 400081001311, 400081001018, 311, FALSE), (400081001312, 400081001312, 400081001018, 312, FALSE), (400081001313, 400081001313, 400081001018, 313, FALSE), (400081001314, 400081001314, 400081001018, 314, FALSE), (400081001315, 400081001315, 400081001018, 315, FALSE), (400081001316, 400081001316, 400081001018, 316, FALSE), (400081001317, 400081001317, 400081001018, 317, FALSE), (400081001318, 400081001318, 400081001018, 318, FALSE), (400081001319, 400081001319, 400081001018, 319, FALSE), (400081001320, 400081001320, 400081001018, 320, FALSE), (400081001321, 400081001321, 400081001018, 321, FALSE), (400081001322, 400081001322, 400081001018, 322, FALSE), (400081001323, 400081001323, 400081001018, 323, FALSE), (400081001324, 400081001324, 400081001019, 324, FALSE), (400081001325, 400081001325, 400081001019, 325, FALSE), (400081001326, 400081001326, 400081001019, 326, FALSE), (400081001327, 400081001327, 400081001019, 327, FALSE), (400081001328, 400081001328, 400081001019, 328, FALSE), (400081001329, 400081001329, 400081001019, 329, FALSE), (400081001330, 400081001330, 400081001019, 330, FALSE), (400081001331, 400081001331, 400081001019, 331, FALSE), (400081001332, 400081001332, 400081001019, 332, FALSE), (400081001333, 400081001333, 400081001019, 333, FALSE), (400081001334, 400081001334, 400081001019, 334, FALSE), (400081001335, 400081001335, 400081001019, 335, FALSE), (400081001336, 400081001336, 400081001019, 336, FALSE), (400081001337, 400081001337, 400081001019, 337, FALSE), (400081001338, 400081001338, 400081001019, 338, FALSE), (400081001339, 400081001339, 400081001019, 339, FALSE), (400081001340, 400081001340, 400081001019, 340, FALSE), (400081001341, 400081001341, 400081001019, 341, FALSE), (400081001342, 400081001342, 400081001019, 342, FALSE), (400081001343, 400081001343, 400081001019, 343, FALSE), (400081001344, 400081001344, 400081001019, 344, FALSE), (400081001345, 400081001345, 400081001019, 345, FALSE), (400081001346, 400081001346, 400081001019, 346, FALSE), (400081001347, 400081001347, 400081001019, 347, FALSE), (400081001348, 400081001348, 400081001019, 348, FALSE), (400081001349, 400081001349, 400081001020, 349, FALSE), (400081001350, 400081001350, 400081001020, 350, FALSE), (400081001351, 400081001351, 400081001020, 351, FALSE), (400081001352, 400081001352, 400081001020, 352, FALSE), (400081001353, 400081001353, 400081001020, 353, FALSE), (400081001354, 400081001354, 400081001020, 354, FALSE), (400081001355, 400081001355, 400081001020, 355, FALSE), (400081001356, 400081001356, 400081001020, 356, FALSE), (400081001357, 400081001357, 400081001020, 357, FALSE), (400081001358, 400081001358, 400081001020, 358, FALSE), (400081001359, 400081001359, 400081001020, 359, FALSE), (400081001360, 400081001360, 400081001020, 360, FALSE), (400081001361, 400081001361, 400081001020, 361, FALSE), (400081001362, 400081001362, 400081001020, 362, FALSE), (400081001363, 400081001363, 400081001021, 363, FALSE), (400081001364, 400081001364, 400081001021, 364, FALSE), (400081001365, 400081001365, 400081001021, 365, FALSE), (400081001366, 400081001366, 400081001021, 366, FALSE), (400081001367, 400081001367, 400081001022, 367, FALSE), (400081001368, 400081001368, 400081001022, 368, FALSE), (400081001369, 400081001369, 400081001022, 369, FALSE), (400081001370, 400081001370, 400081001022, 370, FALSE), (400081001371, 400081001371, 400081001022, 371, FALSE), (400081001372, 400081001372, 400081001022, 372, FALSE), (400081001373, 400081001373, 400081001022, 373, FALSE), (400081001374, 400081001374, 400081001022, 374, FALSE), (400081001375, 400081001375, 400081001022, 375, FALSE), (400081001376, 400081001376, 400081001022, 376, FALSE), (400081001377, 400081001377, 400081001022, 377, FALSE), (400081001378, 400081001378, 400081001022, 378, FALSE), (400081001379, 400081001379, 400081001022, 379, FALSE), (400081001380, 400081001380, 400081001022, 380, FALSE), (400081001381, 400081001381, 400081001022, 381, FALSE), (400081001382, 400081001382, 400081001022, 382, FALSE), (400081001383, 400081001383, 400081001023, 383, FALSE), (400081001384, 400081001384, 400081001023, 384, FALSE), (400081001385, 400081001385, 400081001023, 385, FALSE), (400081001386, 400081001386, 400081001023, 386, FALSE), (400081001387, 400081001387, 400081001023, 387, FALSE), (400081001388, 400081001388, 400081001023, 388, FALSE), (400081001389, 400081001389, 400081001023, 389, FALSE), (400081001390, 400081001390, 400081001023, 390, FALSE), (400081001391, 400081001391, 400081001023, 391, FALSE), (400081001392, 400081001392, 400081001023, 392, FALSE), (400081001393, 400081001393, 400081001023, 393, FALSE), (400081001394, 400081001394, 400081001024, 394, FALSE), (400081001395, 400081001395, 400081001024, 395, FALSE), (400081001396, 400081001396, 400081001024, 396, FALSE), (400081001397, 400081001397, 400081001024, 397, FALSE), (400081001398, 400081001398, 400081001024, 398, FALSE), (400081001399, 400081001399, 400081001024, 399, FALSE), (400081001400, 400081001400, 400081001025, 400, FALSE), (400081001401, 400081001401, 400081001025, 401, FALSE), (400081001402, 400081001402, 400081001025, 402, FALSE), (400081001403, 400081001403, 400081001025, 403, FALSE), (400081001404, 400081001404, 400081001025, 404, FALSE), (400081001405, 400081001405, 400081001025, 405, FALSE), (400081001406, 400081001406, 400081001026, 406, FALSE), (400081001407, 400081001407, 400081001027, 407, FALSE), (400081001408, 400081001408, 400081001027, 408, FALSE), (400081001409, 400081001409, 400081001027, 409, FALSE), (400081001410, 400081001410, 400081001027, 410, FALSE), (400081001411, 400081001411, 400081001027, 411, FALSE), (400081001412, 400081001412, 400081001027, 412, FALSE)) AS x(menu_board_item_id, menu_item_id, menu_category_id, display_sequence, is_featured);

COMMIT;

-- =============================================================================
-- REVIEW NOTES: every menu_item / menu_item_price row with
-- verification_status_code = 'needs_review', one line each.
-- =============================================================================
-- NEEDS_REVIEW [0.50] "Paneer" (SPECIAL SHAKAHARI DAWAT): Raw line 'Paneer / Cheese | 380' has no shared suffix/qualifier the way its neighbouring lines do (e.g. 'Paneer Do Pyaza', 'Paneer Lazeez') -- a dish-type word was likely dropped in transcription. Recorded as bare 'Paneer' and 'Cheese' rather than guessing what that word was; verify against the printed menu.
-- NEEDS_REVIEW [0.50] "Cheese" (SPECIAL SHAKAHARI DAWAT): Raw line 'Paneer / Cheese | 380' has no shared suffix/qualifier the way its neighbouring lines do (e.g. 'Paneer Do Pyaza', 'Paneer Lazeez') -- a dish-type word was likely dropped in transcription. Recorded as bare 'Paneer' and 'Cheese' rather than guessing what that word was; verify against the printed menu.
-- NEEDS_REVIEW [0.90] "Aerated Waters" (COOLERS): Priced 'M.R.P.' (maximum retail price) -- varies by bottle brand/size actually stocked, so is_market_price=TRUE, price left NULL.
-- NEEDS_REVIEW [0.90] "Mineral Water" (COOLERS): Priced 'M.R.P.' (maximum retail price) -- varies by bottle brand/size actually stocked, so is_market_price=TRUE, price left NULL.
-- NEEDS_REVIEW [0.75] "Malai Kulfi" (KULFI SLICES): 'Kulfi' suffix is printed on the following line ('Badam / Pista / Sitaphal Kulfi'), not repeated on this one; applied here too since both lines list flavours under the same KULFI SLICES heading.
-- NEEDS_REVIEW [0.75] "Kesar Pista Kulfi" (KULFI SLICES): 'Kulfi' suffix is printed on the following line ('Badam / Pista / Sitaphal Kulfi'), not repeated on this one; applied here too since both lines list flavours under the same KULFI SLICES heading.
-- NEEDS_REVIEW [0.75] "Mango Kulfi" (KULFI SLICES): 'Kulfi' suffix is printed on the following line ('Badam / Pista / Sitaphal Kulfi'), not repeated on this one; applied here too since both lines list flavours under the same KULFI SLICES heading.

-- =============================================================================
-- UNMAPPED: restaurant-level facts with no clean schema home, or deliberately
-- left for a human decision.
-- =============================================================================
-- UNMAPPED: "Please advice us should you be allergic to any ingredient(s) / Any dietary restriction(s)." -- an allergy notice with no per-dish allergen data given, so no allergen tagging was attempted (your real platform_tag data has NUT_FREE/GLUTEN_FREE/LACTOSE_FRIENDLY tags, tag_ids 51-53, that could carry this later if specific dishes are confirmed allergen-free).
-- UNMAPPED: "Parties & Get togethers" (footer) is ambiguous between dine-in group bookings and off-site catering, so not mapped to service_mode = 'bulk_catering'.
-- UNMAPPED: Government taxes on top of listed prices are implied by standard practice but not explicitly stated in this docx (unlike Hanuman's explicit note) -- tax fields left unset either way.
