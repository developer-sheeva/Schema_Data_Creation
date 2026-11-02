-- =============================================================================
-- Khaustan onboarding script: Hotel Parijat
-- Source: hotel_parijat_menu.json (pre-structured JSON)
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
  WHERE normalized_name = lower(trim('Hotel Parijat')) AND postal_code = '400081';

  IF NOT FOUND THEN
    v_establishment_id := 400081003;
    INSERT INTO establishment (establishment_id, name, normalized_name, address_line1, locality, postal_code, city, state, country_code, latitude, longitude)
    VALUES (v_establishment_id, 'Hotel Parijat', lower(trim('Hotel Parijat')), '2 & 3, Satnam Apartment, L.T. Road', 'Mulund (E)', '400081', 'Mumbai', 'Maharashtra', 'IN', 19.171357349071474, 72.95884578247467);
  END IF;

  SELECT restaurant_id INTO v_restaurant_id FROM restaurant
  WHERE establishment_id = v_establishment_id AND display_name = 'Hotel Parijat';

  IF NOT FOUND THEN
    v_restaurant_id := 400081003;
    INSERT INTO restaurant (restaurant_id, establishment_id, display_name, normalized_name, has_bar, bar_license_type)
    VALUES (v_restaurant_id, v_establishment_id, 'Hotel Parijat', lower(trim('Hotel Parijat')), TRUE, 'none');
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
      AND source_id IN (SELECT source_id FROM source_record WHERE source_uri = 'hotel_parijat_menu.json')
      AND status_code = 'completed'
  ) INTO v_already_processed;

  IF v_already_processed THEN
    RAISE EXCEPTION 'Khaustan onboarding: % has already been fully processed for this restaurant. Aborting.', 'hotel_parijat_menu.json';
  END IF;
END $do$;

INSERT INTO source_record (source_id, source_type_code, source_uri)
VALUES (400081003001, 'ai_menu_extraction', 'hotel_parijat_menu.json');
UPDATE khaustan_onboarding_ctx SET source_id = 400081003001;

INSERT INTO menu_extraction_batch (extraction_batch_id, restaurant_id, source_id, started_at, completed_at, status_code)
SELECT 400081003001, ctx.restaurant_id, ctx.source_id, (clock_timestamp() AT TIME ZONE 'UTC'), (clock_timestamp() AT TIME ZONE 'UTC'), 'completed'
FROM khaustan_onboarding_ctx ctx;
UPDATE khaustan_onboarding_ctx SET extraction_batch_id = 400081003001;

INSERT INTO restaurant_phone (restaurant_phone_id, restaurant_id, phone_number, is_primary)
SELECT x.phone_id, ctx.restaurant_id, x.phone_number, x.is_primary
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400081003001, '9136271504', TRUE)) AS x(phone_id, phone_number, is_primary);

INSERT INTO restaurant_service_mode (restaurant_id, service_mode_id, is_active, notes)
SELECT ctx.restaurant_id, sm.service_mode_id, TRUE, x.notes
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES ('takeaway', 'Source JSON is explicitly captured from a "Parcel Menu panel" (takeaway).')) AS x(code, notes)
JOIN service_mode sm ON sm.code = x.code;

-- -----------------------------------------------------------------------
-- Canonical dishes: one row per distinct normalized dish name, batched
-- into one set-based statement (safe: normalized_name is the identity
-- key and the candidate list is de-duplicated before generation).
-- -----------------------------------------------------------------------
WITH candidate_dishes(canonical_dish_id, canonical_dish_name_id, canonical_name, normalized_name, food_classification_code, protein_code) AS (
  VALUES
    (400081003001, 400081003001, 'Veg. Manchow Soup', 'veg. manchow soup', 'veg', NULL),
    (400081003002, 400081003002, 'Veg. Hot & Sour Soup', 'veg. hot & sour soup', 'veg', NULL),
    (400081003003, 400081003003, 'Veg. Clear Soup', 'veg. clear soup', 'veg', NULL),
    (400081003004, 400081003004, 'Chicken Manchow Soup', 'chicken manchow soup', 'non_veg', 'CHICKEN'),
    (400081003005, 400081003005, 'Chicken Hot & Sour Soup', 'chicken hot & sour soup', 'non_veg', 'CHICKEN'),
    (400081003006, 400081003006, 'Chicken Soup', 'chicken soup', 'non_veg', 'CHICKEN'),
    (400081003007, 400081003007, 'Chicken Clear Soup', 'chicken clear soup', 'non_veg', 'CHICKEN'),
    (400081003008, 400081003008, 'Veg. Cutlet', 'veg. cutlet', 'veg', NULL),
    (400081003009, 400081003009, 'Veg. Chinese Bhel', 'veg. chinese bhel', 'veg', NULL),
    (400081003010, 400081003010, 'Kanda Bhaji', 'kanda bhaji', 'veg', NULL),
    (400081003011, 400081003011, 'Chana Oil Fry', 'chana oil fry', 'veg', NULL),
    (400081003012, 400081003012, 'Chana Garlic Fry', 'chana garlic fry', 'veg', NULL),
    (400081003013, 400081003013, 'Chana Dry Fry', 'chana dry fry', 'veg', NULL),
    (400081003014, 400081003014, 'Green Peas Garlic Fry', 'green peas garlic fry', 'veg', NULL),
    (400081003015, 400081003015, 'Green Peas Dry Fry', 'green peas dry fry', 'veg', NULL),
    (400081003016, 400081003016, 'Aloo Chaat', 'aloo chaat', 'veg', NULL),
    (400081003017, 400081003017, 'Finger Chips', 'finger chips', 'veg', NULL),
    (400081003018, 400081003018, 'Boiled Vegetable', 'boiled vegetable', 'veg', NULL),
    (400081003019, 400081003019, 'Paneer Pakoda', 'paneer pakoda', 'veg', NULL),
    (400081003020, 400081003020, 'Schezwan Sauce', 'schezwan sauce', 'veg', NULL),
    (400081003021, 400081003021, 'Cheese Pakoda', 'cheese pakoda', 'veg', NULL),
    (400081003022, 400081003022, 'Chicken Koliwada', 'chicken koliwada', 'non_veg', 'CHICKEN'),
    (400081003023, 400081003023, 'Chicken Schezwan Finger', 'chicken schezwan finger', 'non_veg', 'CHICKEN'),
    (400081003024, 400081003024, 'Chicken Gold Coin', 'chicken gold coin', 'non_veg', 'CHICKEN'),
    (400081003025, 400081003025, 'Chicken Chinese Bhel', 'chicken chinese bhel', 'non_veg', 'CHICKEN'),
    (400081003026, 400081003026, 'Chicken Liver Oil Fry', 'chicken liver oil fry', 'non_veg', 'CHICKEN'),
    (400081003027, 400081003027, 'Prawns Koliwada', 'prawns koliwada', 'non_veg', 'SEAFOOD'),
    (400081003028, 400081003028, 'Egg Pakoda', 'egg pakoda', 'egg', 'EGG'),
    (400081003029, 400081003029, 'Egg Oil Fry', 'egg oil fry', 'egg', 'EGG'),
    (400081003030, 400081003030, 'Veg. Schezwan', 'veg. schezwan', 'veg', NULL),
    (400081003031, 400081003031, 'Veg. Crispy', 'veg. crispy', 'veg', NULL),
    (400081003032, 400081003032, 'Veg. Garlic', 'veg. garlic', 'veg', NULL),
    (400081003033, 400081003033, 'Veg. Chilly', 'veg. chilly', 'veg', NULL),
    (400081003034, 400081003034, 'Veg. Schezwan Finger', 'veg. schezwan finger', 'veg', NULL),
    (400081003035, 400081003035, 'Veg. Manchurian', 'veg. manchurian', 'veg', NULL),
    (400081003036, 400081003036, 'Paneer Chilly', 'paneer chilly', 'veg', NULL),
    (400081003037, 400081003037, 'Paneer Schezwan', 'paneer schezwan', 'veg', NULL),
    (400081003038, 400081003038, 'Paneer Kasturi', 'paneer kasturi', 'veg', NULL),
    (400081003039, 400081003039, 'Paneer Sathey', 'paneer sathey', 'veg', NULL),
    (400081003040, 400081003040, 'Paneer Crispy', 'paneer crispy', 'veg', NULL),
    (400081003041, 400081003041, 'Paneer Hariyali', 'paneer hariyali', 'veg', NULL),
    (400081003042, 400081003042, 'Mushroom Pepper', 'mushroom pepper', 'veg', NULL),
    (400081003043, 400081003043, 'Baby Corn Pepper', 'baby corn pepper', 'veg', NULL),
    (400081003044, 400081003044, 'Baby Corn Chilly', 'baby corn chilly', 'veg', NULL),
    (400081003045, 400081003045, 'Chicken Chilly', 'chicken chilly', 'non_veg', 'CHICKEN'),
    (400081003046, 400081003046, 'Chicken Manchurian', 'chicken manchurian', 'non_veg', 'CHICKEN'),
    (400081003047, 400081003047, 'Chicken Schezwan', 'chicken schezwan', 'non_veg', 'CHICKEN'),
    (400081003048, 400081003048, 'Chicken Crispy', 'chicken crispy', 'non_veg', 'CHICKEN'),
    (400081003049, 400081003049, 'Chicken 65', 'chicken 65', 'non_veg', 'CHICKEN'),
    (400081003050, 400081003050, 'Chicken Garlic', 'chicken garlic', 'non_veg', 'CHICKEN'),
    (400081003051, 400081003051, 'Chicken Chawchaw', 'chicken chawchaw', 'non_veg', 'CHICKEN'),
    (400081003052, 400081003052, 'Chicken Lollypop', 'chicken lollypop', 'non_veg', 'CHICKEN'),
    (400081003053, 400081003053, 'Chicken Lollypop Masala', 'chicken lollypop masala', 'non_veg', 'CHICKEN'),
    (400081003054, 400081003054, 'Chicken American Chopsuey', 'chicken american chopsuey', 'non_veg', 'CHICKEN'),
    (400081003055, 400081003055, 'Chicken Sathey', 'chicken sathey', 'non_veg', 'CHICKEN'),
    (400081003056, 400081003056, 'Chicken Hariyali', 'chicken hariyali', 'non_veg', 'CHICKEN'),
    (400081003057, 400081003057, 'Chicken Lamba', 'chicken lamba', 'non_veg', 'CHICKEN'),
    (400081003058, 400081003058, 'Chicken Crunchy', 'chicken crunchy', 'non_veg', 'CHICKEN'),
    (400081003059, 400081003059, 'Chicken Pepper', 'chicken pepper', 'non_veg', 'CHICKEN'),
    (400081003060, 400081003060, 'Chicken Liver Pepper', 'chicken liver pepper', 'non_veg', 'CHICKEN'),
    (400081003061, 400081003061, 'Prawns Pepper', 'prawns pepper', 'non_veg', 'SEAFOOD'),
    (400081003062, 400081003062, 'Prawns Schezwan', 'prawns schezwan', 'non_veg', 'SEAFOOD'),
    (400081003063, 400081003063, 'Prawns Chilly', 'prawns chilly', 'non_veg', 'SEAFOOD'),
    (400081003064, 400081003064, 'Fish Pompret Chilly', 'fish pompret chilly', 'non_veg', 'SEAFOOD'),
    (400081003065, 400081003065, 'Egg. Chilly', 'egg. chilly', 'egg', 'EGG'),
    (400081003066, 400081003066, 'Chilly Gravy', 'chilly gravy', 'veg', NULL),
    (400081003067, 400081003067, 'Paneer Tikka Masala', 'paneer tikka masala', 'veg', NULL),
    (400081003068, 400081003068, 'Paneer Makhanwala', 'paneer makhanwala', 'veg', NULL),
    (400081003069, 400081003069, 'Paneer Palak', 'paneer palak', 'veg', NULL),
    (400081003070, 400081003070, 'Paneer Masala', 'paneer masala', 'veg', NULL),
    (400081003071, 400081003071, 'Paneer Bhurji', 'paneer bhurji', 'veg', NULL),
    (400081003072, 400081003072, 'Paneer Mutter', 'paneer mutter', 'veg', NULL),
    (400081003073, 400081003073, 'Paneer Kofta', 'paneer kofta', 'veg', NULL),
    (400081003074, 400081003074, 'Veg. Makhanwala', 'veg. makhanwala', 'veg', NULL),
    (400081003075, 400081003075, 'Veg. Kolhapuri', 'veg. kolhapuri', 'veg', NULL),
    (400081003076, 400081003076, 'Veg. Keema', 'veg. keema', 'veg', NULL),
    (400081003077, 400081003077, 'Veg. Kofta', 'veg. kofta', 'veg', NULL),
    (400081003078, 400081003078, 'Nargis Kofta', 'nargis kofta', 'veg', NULL),
    (400081003079, 400081003079, 'Mix Vegetable', 'mix vegetable', 'veg', NULL),
    (400081003080, 400081003080, 'Mushroom Masala', 'mushroom masala', 'veg', NULL),
    (400081003081, 400081003081, 'Aloo Gobi', 'aloo gobi', 'veg', NULL),
    (400081003082, 400081003082, 'Aloo Mutter', 'aloo mutter', 'veg', NULL),
    (400081003083, 400081003083, 'Chana Masala', 'chana masala', 'veg', NULL),
    (400081003084, 400081003084, 'Tomato Bhartha', 'tomato bhartha', 'veg', NULL),
    (400081003085, 400081003085, 'Dal Kolhapuri', 'dal kolhapuri', 'veg', NULL),
    (400081003086, 400081003086, 'Dal Tadka', 'dal tadka', 'veg', NULL),
    (400081003087, 400081003087, 'Dal Fry', 'dal fry', 'veg', NULL),
    (400081003088, 400081003088, 'Plain Dal', 'plain dal', 'veg', NULL),
    (400081003089, 400081003089, 'Stuff Shimla', 'stuff shimla', 'veg', NULL),
    (400081003090, 400081003090, 'Stuff Tomato', 'stuff tomato', 'veg', NULL),
    (400081003091, 400081003091, 'Flower Tikka Masala', 'flower tikka masala', 'veg', NULL),
    (400081003092, 400081003092, 'Chicken Tikka Masala', 'chicken tikka masala', 'non_veg', 'CHICKEN'),
    (400081003093, 400081003093, 'Chicken Tandoori Masala', 'chicken tandoori masala', 'non_veg', 'CHICKEN'),
    (400081003094, 400081003094, 'Chicken Kolhapuri', 'chicken kolhapuri', 'non_veg', 'CHICKEN'),
    (400081003095, 400081003095, 'Chicken Masala Boneless', 'chicken masala boneless', 'non_veg', 'CHICKEN'),
    (400081003096, 400081003096, 'Chicken Mughlai', 'chicken mughlai', 'non_veg', 'CHICKEN'),
    (400081003097, 400081003097, 'Chicken Masala', 'chicken masala', 'non_veg', 'CHICKEN'),
    (400081003098, 400081003098, 'Chicken Liver Masala', 'chicken liver masala', 'non_veg', 'CHICKEN'),
    (400081003099, 400081003099, 'Chicken Fry', 'chicken fry', 'non_veg', 'CHICKEN'),
    (400081003100, 400081003100, 'Chicken Keema', 'chicken keema', 'non_veg', 'CHICKEN'),
    (400081003101, 400081003101, 'Chicken Boneless', 'chicken boneless', 'non_veg', 'CHICKEN'),
    (400081003102, 400081003102, 'Chicken Gravy', 'chicken gravy', 'non_veg', 'CHICKEN'),
    (400081003103, 400081003103, 'Mutton Masala', 'mutton masala', 'non_veg', 'MUTTON'),
    (400081003104, 400081003104, 'Mutton Fry', 'mutton fry', 'non_veg', 'MUTTON'),
    (400081003105, 400081003105, 'Mutton Keema', 'mutton keema', 'non_veg', 'MUTTON'),
    (400081003106, 400081003106, 'Mutton Mughlai', 'mutton mughlai', 'non_veg', 'MUTTON'),
    (400081003107, 400081003107, 'Mutton Boneless', 'mutton boneless', 'non_veg', 'MUTTON'),
    (400081003108, 400081003108, 'Pamplet Masala', 'pamplet masala', 'non_veg', 'SEAFOOD'),
    (400081003109, 400081003109, 'Pamplet Fry', 'pamplet fry', 'non_veg', 'SEAFOOD'),
    (400081003110, 400081003110, 'Pamplet Tawa', 'pamplet tawa', 'non_veg', 'SEAFOOD'),
    (400081003111, 400081003111, 'Bangda Masala', 'bangda masala', 'non_veg', 'SEAFOOD'),
    (400081003112, 400081003112, 'Bangda Fry', 'bangda fry', 'non_veg', 'SEAFOOD'),
    (400081003113, 400081003113, 'Surmai Masala', 'surmai masala', 'non_veg', 'SEAFOOD'),
    (400081003114, 400081003114, 'Surmai Fry', 'surmai fry', 'non_veg', 'SEAFOOD'),
    (400081003115, 400081003115, 'Prawns Masala', 'prawns masala', 'non_veg', 'SEAFOOD'),
    (400081003116, 400081003116, 'Prawns Fry', 'prawns fry', 'non_veg', 'SEAFOOD'),
    (400081003117, 400081003117, 'Bombil Fry', 'bombil fry', 'non_veg', 'SEAFOOD'),
    (400081003118, 400081003118, 'Egg Masala', 'egg masala', 'egg', 'EGG'),
    (400081003119, 400081003119, 'Egg Masala Fry', 'egg masala fry', 'egg', 'EGG'),
    (400081003120, 400081003120, 'Egg Ghotala', 'egg ghotala', 'egg', 'EGG'),
    (400081003121, 400081003121, 'Egg Bhurji', 'egg bhurji', 'egg', 'EGG'),
    (400081003122, 400081003122, 'Egg Omlet', 'egg omlet', 'egg', 'EGG'),
    (400081003123, 400081003123, 'Egg Cheese Omlet', 'egg cheese omlet', 'egg', 'EGG'),
    (400081003124, 400081003124, 'Egg Half Fry', 'egg half fry', 'egg', 'EGG'),
    (400081003125, 400081003125, 'Boiled Egg', 'boiled egg', 'egg', 'EGG'),
    (400081003126, 400081003126, 'Boiled Egg Bhurji', 'boiled egg bhurji', 'egg', 'EGG'),
    (400081003127, 400081003127, 'Roti', 'roti', 'veg', NULL),
    (400081003128, 400081003128, 'Butter Roti', 'butter roti', 'veg', NULL),
    (400081003129, 400081003129, 'Naan', 'naan', 'veg', NULL),
    (400081003130, 400081003130, 'Butter Naan', 'butter naan', 'veg', NULL),
    (400081003131, 400081003131, 'Paratha', 'paratha', 'veg', NULL),
    (400081003132, 400081003132, 'Butter Paratha', 'butter paratha', 'veg', NULL),
    (400081003133, 400081003133, 'Veg. Paratha', 'veg. paratha', 'veg', NULL),
    (400081003134, 400081003134, 'Garlic Naan', 'garlic naan', 'veg', NULL),
    (400081003135, 400081003135, 'Butter Garlic Naan', 'butter garlic naan', 'veg', NULL),
    (400081003136, 400081003136, 'Cheese Naan', 'cheese naan', 'veg', NULL),
    (400081003137, 400081003137, 'Cheese Butter Garlic Naan', 'cheese butter garlic naan', 'veg', NULL),
    (400081003138, 400081003138, 'Dal Khichdi Tadka', 'dal khichdi tadka', 'veg', NULL),
    (400081003139, 400081003139, 'Dal Khichdi', 'dal khichdi', 'veg', NULL),
    (400081003140, 400081003140, 'Veg. Khichdi', 'veg. khichdi', 'veg', NULL),
    (400081003141, 400081003141, 'Curd Rice', 'curd rice', 'veg', NULL),
    (400081003142, 400081003142, 'Biryani Rice', 'biryani rice', 'veg', NULL),
    (400081003143, 400081003143, 'Steam Rice', 'steam rice', 'veg', NULL),
    (400081003144, 400081003144, 'Veg. Pulav', 'veg. pulav', 'veg', NULL),
    (400081003145, 400081003145, 'Paneer Pulav', 'paneer pulav', 'veg', NULL),
    (400081003146, 400081003146, 'Paneer Biryani', 'paneer biryani', 'veg', NULL),
    (400081003147, 400081003147, 'Paneer Tikka Biryani', 'paneer tikka biryani', 'veg', NULL),
    (400081003148, 400081003148, 'Mushroom Biryani', 'mushroom biryani', 'veg', NULL),
    (400081003149, 400081003149, 'Chicken Hyderabad Biryani', 'chicken hyderabad biryani', 'non_veg', 'CHICKEN'),
    (400081003150, 400081003150, 'Chicken Tikka Biryani', 'chicken tikka biryani', 'non_veg', 'CHICKEN'),
    (400081003151, 400081003151, 'Mutton Biryani', 'mutton biryani', 'non_veg', 'MUTTON'),
    (400081003152, 400081003152, 'Prawns Biryani', 'prawns biryani', 'non_veg', 'SEAFOOD'),
    (400081003153, 400081003153, 'Egg Biryani', 'egg biryani', 'egg', 'EGG'),
    (400081003154, 400081003154, 'Boondi Raita', 'boondi raita', 'veg', NULL),
    (400081003155, 400081003155, 'Veg. Raita', 'veg. raita', 'veg', NULL),
    (400081003156, 400081003156, 'Curd', 'curd', 'veg', NULL),
    (400081003157, 400081003157, 'Green Salad', 'green salad', 'veg', NULL),
    (400081003158, 400081003158, 'Kakdi', 'kakdi', 'veg', NULL),
    (400081003159, 400081003159, 'Gajar', 'gajar', 'veg', NULL),
    (400081003160, 400081003160, 'Veg. Spring Roll', 'veg. spring roll', 'veg', NULL),
    (400081003161, 400081003161, 'Mix Spring Roll', 'mix spring roll', 'veg', NULL),
    (400081003162, 400081003162, 'Chicken Spring Roll', 'chicken spring roll', 'non_veg', 'CHICKEN'),
    (400081003163, 400081003163, 'Prawns Spring Roll', 'prawns spring roll', 'non_veg', 'SEAFOOD'),
    (400081003164, 400081003164, 'Mix Fried Rice', 'mix fried rice', 'veg', NULL),
    (400081003165, 400081003165, 'Veg. Triple Rice', 'veg. triple rice', 'veg', NULL),
    (400081003166, 400081003166, 'Veg. Manchurian Rice', 'veg. manchurian rice', 'veg', NULL),
    (400081003167, 400081003167, 'Mushroom Fried Rice', 'mushroom fried rice', 'veg', NULL),
    (400081003168, 400081003168, 'Mushroom Schezwan Fried Rice', 'mushroom schezwan fried rice', 'veg', NULL),
    (400081003169, 400081003169, 'Chicken Triple Rice', 'chicken triple rice', 'non_veg', 'CHICKEN'),
    (400081003170, 400081003170, 'Chicken Manchurian Rice', 'chicken manchurian rice', 'non_veg', 'CHICKEN'),
    (400081003171, 400081003171, 'Prawns Fried Rice', 'prawns fried rice', 'non_veg', 'SEAFOOD'),
    (400081003172, 400081003172, 'Prawns Triple Rice', 'prawns triple rice', 'non_veg', 'SEAFOOD'),
    (400081003173, 400081003173, 'Prawns Schezwan Rice', 'prawns schezwan rice', 'non_veg', 'SEAFOOD'),
    (400081003174, 400081003174, 'Egg Schezwan Fried Rice', 'egg schezwan fried rice', 'egg', 'EGG'),
    (400081003175, 400081003175, 'Egg Triple Rice', 'egg triple rice', 'egg', 'EGG'),
    (400081003176, 400081003176, 'Mix Noodles', 'mix noodles', 'veg', NULL),
    (400081003177, 400081003177, 'Veg. Schezwan Noodles', 'veg. schezwan noodles', 'veg', NULL),
    (400081003178, 400081003178, 'Veg. Triple Noodles', 'veg. triple noodles', 'veg', NULL),
    (400081003179, 400081003179, 'Chicken Triple Noodles', 'chicken triple noodles', 'non_veg', 'CHICKEN'),
    (400081003180, 400081003180, 'Chicken Schezwan Noodles', 'chicken schezwan noodles', 'non_veg', 'CHICKEN'),
    (400081003181, 400081003181, 'Egg Noodles with Rice', 'egg noodles with rice', 'egg', 'EGG'),
    (400081003182, 400081003182, 'Egg Schezwan Noodles', 'egg schezwan noodles', 'egg', 'EGG'),
    (400081003183, 400081003183, 'Bread Slice-3 Pcs', 'bread slice-3 pcs', 'veg', NULL),
    (400081003184, 400081003184, 'Bread Butter', 'bread butter', 'veg', NULL),
    (400081003185, 400081003185, 'Veg. Sandwich', 'veg. sandwich', 'veg', NULL),
    (400081003186, 400081003186, 'Cheese Sandwich', 'cheese sandwich', 'veg', NULL),
    (400081003187, 400081003187, 'Omlet Sandwich', 'omlet sandwich', 'egg', 'EGG'),
    (400081003188, 400081003188, 'Cheese Omlet Sandwich', 'cheese omlet sandwich', 'egg', 'EGG'),
    (400081003189, 400081003189, 'Chicken Sandwich', 'chicken sandwich', 'non_veg', 'CHICKEN'),
    (400081003190, 400081003190, 'Sweet Lassi', 'sweet lassi', 'veg', NULL),
    (400081003191, 400081003191, 'Butter Milk', 'butter milk', 'veg', NULL),
    (400081003192, 400081003192, 'Chicken Sukha', 'chicken sukha', 'non_veg', 'CHICKEN'),
    (400081003193, 400081003193, 'Mutton Sukha', 'mutton sukha', 'non_veg', 'MUTTON'),
    (400081003194, 400081003194, 'Prawns Sukha', 'prawns sukha', 'non_veg', 'SEAFOOD'),
    (400081003195, 400081003195, 'Pompret Masala', 'pompret masala', 'non_veg', 'SEAFOOD'),
    (400081003196, 400081003196, 'South Indian Fish Gravy Plate', 'south indian fish gravy plate', 'non_veg', 'SEAFOOD'),
    (400081003197, 400081003197, 'Fish Gravy Extra', 'fish gravy extra', 'non_veg', 'SEAFOOD'),
    (400081003198, 400081003198, 'Kori Rotti', 'kori rotti', 'non_veg', 'CHICKEN'),
    (400081003199, 400081003199, 'Chicken (Kori) Neer Dosa', 'chicken (kori) neer dosa', 'non_veg', 'CHICKEN'),
    (400081003200, 400081003200, 'Neer Dosa - 4pcs', 'neer dosa - 4pcs', 'veg', NULL),
    (400081003201, 400081003201, 'Paneer Handi', 'paneer handi', 'veg', NULL),
    (400081003202, 400081003202, 'Veg. Handi', 'veg. handi', 'veg', NULL),
    (400081003203, 400081003203, 'Veg. Kadai', 'veg. kadai', 'veg', NULL),
    (400081003204, 400081003204, 'Chicken Handi', 'chicken handi', 'non_veg', 'CHICKEN'),
    (400081003205, 400081003205, 'Butter Chicken', 'butter chicken', 'non_veg', 'CHICKEN'),
    (400081003206, 400081003206, 'Chicken Handi Boneless', 'chicken handi boneless', 'non_veg', 'CHICKEN'),
    (400081003207, 400081003207, 'Mutton Handi', 'mutton handi', 'non_veg', 'MUTTON'),
    (400081003208, 400081003208, 'Veg. Biryani', 'veg. biryani', 'veg', NULL),
    (400081003209, 400081003209, 'Chicken Boneless Biryani', 'chicken boneless biryani', 'non_veg', 'CHICKEN'),
    (400081003210, 400081003210, 'Chicken Biryani', 'chicken biryani', 'non_veg', 'CHICKEN'),
    (400081003211, 400081003211, 'Mutton Boneless Biryani', 'mutton boneless biryani', 'non_veg', 'MUTTON'),
    (400081003212, 400081003212, 'Veg. Fried Rice', 'veg. fried rice', 'veg', NULL),
    (400081003213, 400081003213, 'Veg. Schezwan Fried Rice', 'veg. schezwan fried rice', 'veg', NULL),
    (400081003214, 400081003214, 'Chicken Schezwan Rice', 'chicken schezwan rice', 'non_veg', 'CHICKEN'),
    (400081003215, 400081003215, 'Chicken Fried Rice', 'chicken fried rice', 'non_veg', 'CHICKEN'),
    (400081003216, 400081003216, 'Egg Schezwan Rice', 'egg schezwan rice', 'egg', 'EGG'),
    (400081003217, 400081003217, 'Egg Fried Rice', 'egg fried rice', 'egg', 'EGG'),
    (400081003218, 400081003218, 'Veg. Noodles', 'veg. noodles', 'veg', NULL),
    (400081003219, 400081003219, 'Chicken Noodles', 'chicken noodles', 'non_veg', 'CHICKEN'),
    (400081003220, 400081003220, 'Egg Noodles', 'egg noodles', 'egg', 'EGG'),
    (400081003221, 400081003221, 'Special Bhaji', 'special bhaji', 'veg', NULL),
    (400081003222, 400081003222, 'Extra Butter', 'extra butter', 'veg', NULL),
    (400081003223, 400081003223, 'Chicken Patiyala', 'chicken patiyala', 'non_veg', 'CHICKEN'),
    (400081003224, 400081003224, 'Chicken Lajawab', 'chicken lajawab', 'non_veg', 'CHICKEN'),
    (400081003225, 400081003225, 'Chicken Rara', 'chicken rara', 'non_veg', 'CHICKEN'),
    (400081003226, 400081003226, 'Chicken Kumari Roll', 'chicken kumari roll', 'non_veg', 'CHICKEN'),
    (400081003227, 400081003227, 'Prawns Peanut Sesmi Toast', 'prawns peanut sesmi toast', 'non_veg', 'SEAFOOD'),
    (400081003228, 400081003228, 'Mutton Rara', 'mutton rara', 'non_veg', 'MUTTON'),
    (400081003229, 400081003229, 'Lal Pari Chicken Biryani', 'lal pari chicken biryani', 'non_veg', 'CHICKEN'),
    (400081003230, 400081003230, 'Chicken Packing Rice', 'chicken packing rice', 'non_veg', 'CHICKEN'),
    (400081003231, 400081003231, 'Chicken Sherpa Rice', 'chicken sherpa rice', 'non_veg', 'CHICKEN')
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
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400081003001, 'SOUP', 1), (400081003002, 'STARTERS', 2), (400081003003, 'CHINESE DISHES', 3), (400081003004, 'CONTINUATION', 4), (400081003005, 'PANEER DISHES', 5), (400081003006, 'MAIN COURSE (CONTINUED)', 6), (400081003007, 'CHICKEN DISHES', 7), (400081003008, 'MUTTON DISHES', 8), (400081003009, 'FISH DISHES', 9), (400081003010, 'EGG DISHES', 10), (400081003011, 'ROTI / NAAN / PARATHA', 11), (400081003012, 'RICE & PULAV', 12), (400081003013, 'BIRYANI', 13), (400081003014, 'RAITA & SALAD', 14), (400081003015, 'SPRING ROLL', 15), (400081003016, 'CHINESE RICE', 16), (400081003017, 'CHINESE NOODLES', 17), (400081003018, 'SANDWICHES', 18), (400081003019, 'BEVERAGES', 19), (400081003020, 'SOUTH INDIAN DISHES', 20), (400081003021, 'MAIN COURSE', 21)) AS x(menu_category_id, name, display_sequence);

-- =============================================================================
-- Menu items (222 priced + 11 no-price)
-- =============================================================================

-- Source: docx/json, "SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003001, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003001, 'Veg. Manchow Soup', 'veg. manchow soup', 'SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. manchow soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003001, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003001, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003002, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003001, 'Veg. Hot & Sour Soup', 'veg. hot & sour soup', 'SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. hot & sour soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003002, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003002, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003003, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003001, 'Veg. Clear Soup', 'veg. clear soup', 'SOUP', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. clear soup'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003003, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003003, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003004, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003001, 'Chicken Manchow Soup', 'chicken manchow soup', 'SOUP', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken manchow soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003004, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003004, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003005, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003001, 'Chicken Hot & Sour Soup', 'chicken hot & sour soup', 'SOUP', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hot & sour soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003005, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003005, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003006, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003001, 'Chicken Soup', 'chicken soup', 'SOUP', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003006, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003006, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUP" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003007, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003001, 'Chicken Clear Soup', 'chicken clear soup', 'SOUP', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken clear soup' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003007, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003007, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003008, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Veg. Cutlet', 'veg. cutlet', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. cutlet'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003008, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003008, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003009, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Veg. Chinese Bhel', 'veg. chinese bhel', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chinese bhel'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003009, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003009, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003010, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Kanda Bhaji', 'kanda bhaji', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kanda bhaji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003010, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003010, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003011, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Chana Oil Fry', 'chana oil fry', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chana oil fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003011, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003011, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003012, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Chana Garlic Fry', 'chana garlic fry', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chana garlic fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003012, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003012, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003013, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Chana Dry Fry', 'chana dry fry', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chana dry fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003013, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003013, new_variant.variant_id, 180.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003014, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Green Peas Garlic Fry', 'green peas garlic fry', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green peas garlic fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003014, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003014, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003015, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Green Peas Dry Fry', 'green peas dry fry', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green peas dry fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003015, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003015, new_variant.variant_id, 190.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003016, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Aloo Chaat', 'aloo chaat', 'STARTERS', 'veg', 'split-starters-aloo-chaat-/-finger-chips', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo chaat'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003016, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003016, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081003017, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Finger Chips', 'finger chips', 'STARTERS', 'veg', 'split-starters-aloo-chaat-/-finger-chips', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'finger chips'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003017, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003017, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "STARTERS" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003018, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Boiled Vegetable', 'boiled vegetable', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'boiled vegetable'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003018, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003018, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003019, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Paneer Pakoda', 'paneer pakoda', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer pakoda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003019, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003019, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003020, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Schezwan Sauce', 'schezwan sauce', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'schezwan sauce'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003020, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003020, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003021, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Cheese Pakoda', 'cheese pakoda', 'STARTERS', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese pakoda'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003021, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003021, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003022, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Chicken Koliwada', 'chicken koliwada', 'STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken koliwada' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003022, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003022, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003023, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Chicken Schezwan Finger', 'chicken schezwan finger', 'STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken schezwan finger' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003023, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003023, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003024, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Chicken Gold Coin', 'chicken gold coin', 'STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken gold coin' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003024, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003024, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003025, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Chicken Chinese Bhel', 'chicken chinese bhel', 'STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken chinese bhel' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003025, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003025, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003026, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Chicken Liver Oil Fry', 'chicken liver oil fry', 'STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken liver oil fry' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003026, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003026, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003027, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Prawns Koliwada', 'prawns koliwada', 'STARTERS', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns koliwada' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003027, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003027, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003028, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Egg Pakoda', 'egg pakoda', 'STARTERS', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg pakoda' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003028, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003028, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003029, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003002, 'Egg Oil Fry', 'egg oil fry', 'STARTERS', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg oil fry' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003029, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003029, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003030, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003003, 'Veg. Schezwan', 'veg. schezwan', 'CHINESE DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003030, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003030, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003031, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003003, 'Veg. Crispy', 'veg. crispy', 'CHINESE DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. crispy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003031, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003031, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003032, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003003, 'Veg. Garlic', 'veg. garlic', 'CHINESE DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. garlic'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003032, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003032, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003033, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003003, 'Veg. Chilly', 'veg. chilly', 'CHINESE DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. chilly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003033, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003033, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003034, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003003, 'Veg. Schezwan Finger', 'veg. schezwan finger', 'CHINESE DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. schezwan finger'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003034, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003034, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003035, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003003, 'Veg. Manchurian', 'veg. manchurian', 'CHINESE DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. manchurian'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003035, 'Half', TRUE), (400081003036, 'Full', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003035, 'Half', 140.00, FALSE), (400081003036, 'Full', 210.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "CHINESE DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003036, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003003, 'Paneer Chilly', 'paneer chilly', 'CHINESE DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer chilly'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003037, 'Half', TRUE), (400081003038, 'Full', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003037, 'Half', 150.00, FALSE), (400081003038, 'Full', 260.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "CHINESE DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003037, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003003, 'Paneer Schezwan', 'paneer schezwan', 'CHINESE DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer schezwan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003039, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003039, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003038, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003003, 'Paneer Kasturi', 'paneer kasturi', 'CHINESE DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kasturi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003040, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003040, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003039, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Paneer Sathey', 'paneer sathey', 'CONTINUATION', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer sathey'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003041, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003041, new_variant.variant_id, 330.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003040, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Paneer Crispy', 'paneer crispy', 'CONTINUATION', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer crispy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003042, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003042, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003041, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Paneer Hariyali', 'paneer hariyali', 'CONTINUATION', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer hariyali'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003043, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003043, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003042, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Mushroom Pepper', 'mushroom pepper', 'CONTINUATION', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003044, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003044, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003043, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Baby Corn Pepper', 'baby corn pepper', 'CONTINUATION', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn pepper'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003045, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003045, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003044, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Baby Corn Chilly', 'baby corn chilly', 'CONTINUATION', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'baby corn chilly'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003046, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003046, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003045, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken Chilly', 'chicken chilly', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken chilly' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003047, 'Half', TRUE), (400081003048, 'Full', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003047, 'Half', 140.00, FALSE), (400081003048, 'Full', 240.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003046, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken Manchurian', 'chicken manchurian', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken manchurian' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003049, 'Half', TRUE), (400081003050, 'Full', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003049, 'Half', 140.00, FALSE), (400081003050, 'Full', 240.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003047, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken Schezwan', 'chicken schezwan', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken schezwan' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003051, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003051, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003048, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken Crispy', 'chicken crispy', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken crispy' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003052, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003052, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003049, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken 65', 'chicken 65', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken 65' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003053, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003053, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003050, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken Garlic', 'chicken garlic', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken garlic' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003054, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003054, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003051, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken Chawchaw', 'chicken chawchaw', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken chawchaw' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003055, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003055, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003052, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken Lollypop', 'chicken lollypop', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lollypop' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003056, 'Half', TRUE), (400081003057, 'Full', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003056, 'Half', 140.00, FALSE), (400081003057, 'Full', 240.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003053, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken Lollypop Masala', 'chicken lollypop masala', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lollypop masala' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003058, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003058, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003054, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken American Chopsuey', 'chicken american chopsuey', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken american chopsuey' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003059, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003059, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003055, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken Sathey', 'chicken sathey', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken sathey' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003060, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003060, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003056, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken Hariyali', 'chicken hariyali', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hariyali' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003061, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003061, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003057, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken Lamba', 'chicken lamba', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken lamba' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003062, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003062, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003058, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken Crunchy', 'chicken crunchy', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken crunchy' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003063, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003063, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003059, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken Pepper', 'chicken pepper', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken pepper' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003064, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003064, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003060, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chicken Liver Pepper', 'chicken liver pepper', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken liver pepper' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003065, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003065, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003061, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Prawns Pepper', 'prawns pepper', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns pepper' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003066, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003066, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003062, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Prawns Schezwan', 'prawns schezwan', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns schezwan' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003067, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003067, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003063, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Prawns Chilly', 'prawns chilly', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns chilly' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003068, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003068, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003064, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Fish Pompret Chilly', 'fish pompret chilly', 'CONTINUATION', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish pompret chilly' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003069, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081003069, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003065, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Egg. Chilly', 'egg. chilly', 'CONTINUATION', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg. chilly' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003070, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003070, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CONTINUATION" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003066, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003004, 'Chilly Gravy', 'chilly gravy', 'CONTINUATION', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chilly gravy'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003071, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003071, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PANEER DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003067, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003005, 'Paneer Tikka Masala', 'paneer tikka masala', 'PANEER DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003072, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003072, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PANEER DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003068, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003005, 'Paneer Makhanwala', 'paneer makhanwala', 'PANEER DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer makhanwala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003073, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003073, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PANEER DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003069, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003005, 'Paneer Palak', 'paneer palak', 'PANEER DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer palak'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003074, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003074, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PANEER DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003070, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003005, 'Paneer Masala', 'paneer masala', 'PANEER DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003075, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003075, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PANEER DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003071, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003005, 'Paneer Bhurji', 'paneer bhurji', 'PANEER DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer bhurji'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003076, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003076, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PANEER DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003072, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003005, 'Paneer Mutter', 'paneer mutter', 'PANEER DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003077, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003077, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PANEER DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003073, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003005, 'Paneer Kofta', 'paneer kofta', 'PANEER DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003078, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003078, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003074, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Veg. Makhanwala', 'veg. makhanwala', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. makhanwala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003079, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003079, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003075, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Veg. Kolhapuri', 'veg. kolhapuri', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kolhapuri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003080, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003080, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003076, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Veg. Keema', 'veg. keema', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. keema'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003081, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003081, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003077, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Veg. Kofta', 'veg. kofta', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003082, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003082, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003078, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Nargis Kofta', 'nargis kofta', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'nargis kofta'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003083, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003083, new_variant.variant_id, 250.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003079, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Mix Vegetable', 'mix vegetable', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix vegetable'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003084, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003084, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003080, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Mushroom Masala', 'mushroom masala', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003085, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003085, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003081, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Aloo Gobi', 'aloo gobi', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo gobi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003086, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003086, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003082, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Aloo Mutter', 'aloo mutter', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'aloo mutter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003087, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003087, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003083, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Chana Masala', 'chana masala', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'chana masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003088, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003088, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003084, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Tomato Bhartha', 'tomato bhartha', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'tomato bhartha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003089, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003089, new_variant.variant_id, 210.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003085, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Dal Kolhapuri', 'dal kolhapuri', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal kolhapuri'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003090, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003090, new_variant.variant_id, 170.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003086, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Dal Tadka', 'dal tadka', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal tadka'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003091, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003091, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003087, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Dal Fry', 'dal fry', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal fry'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003092, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003092, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003088, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Plain Dal', 'plain dal', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'plain dal'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003093, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003093, new_variant.variant_id, 60.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003089, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Stuff Shimla', 'stuff shimla', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'stuff shimla'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003094, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003094, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003090, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Stuff Tomato', 'stuff tomato', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'stuff tomato'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003095, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003095, new_variant.variant_id, 220.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003091, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Flower Tikka Masala', 'flower tikka masala', 'MAIN COURSE (CONTINUED)', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'flower tikka masala'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003096, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003096, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003092, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Tikka Masala', 'chicken tikka masala', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tikka masala' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003097, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003097, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003093, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Tandoori Masala', 'chicken tandoori masala', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tandoori masala' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003098, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003098, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003094, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Kolhapuri', 'chicken kolhapuri', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken kolhapuri' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003099, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003099, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003095, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Masala Boneless', 'chicken masala boneless', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken masala boneless' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003100, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003100, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003096, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Mughlai', 'chicken mughlai', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken mughlai' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003101, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003101, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003097, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Masala', 'chicken masala', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken masala' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003102, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003102, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003098, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Liver Masala', 'chicken liver masala', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken liver masala' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003103, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003103, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003099, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Fry', 'chicken fry', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken fry' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003104, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003104, new_variant.variant_id, 230.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003100, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Keema', 'chicken keema', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken keema' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003105, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003105, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003101, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Boneless', 'chicken boneless', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken boneless' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003106, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003106, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003102, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Gravy', 'chicken gravy', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken gravy' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003107, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003107, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003103, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Mutton Masala', 'mutton masala', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton masala' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003108, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003108, new_variant.variant_id, 295.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MUTTON DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003104, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003008, 'Mutton Fry', 'mutton fry', 'MUTTON DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton fry' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003109, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003109, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MUTTON DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003105, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003008, 'Mutton Keema', 'mutton keema', 'MUTTON DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton keema' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003110, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003110, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MUTTON DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003106, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003008, 'Mutton Mughlai', 'mutton mughlai', 'MUTTON DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton mughlai' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003111, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003111, new_variant.variant_id, 340.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "MUTTON DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003107, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003008, 'Mutton Boneless', 'mutton boneless', 'MUTTON DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton boneless' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003112, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003112, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FISH DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003108, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003009, 'Pamplet Masala', 'pamplet masala', 'FISH DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'pamplet masala' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003113, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081003113, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FISH DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003109, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003009, 'Pamplet Fry', 'pamplet fry', 'FISH DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'pamplet fry' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003114, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081003114, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FISH DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003110, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003009, 'Pamplet Tawa', 'pamplet tawa', 'FISH DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'pamplet tawa' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003115, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081003115, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FISH DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003111, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003009, 'Bangda Masala', 'bangda masala', 'FISH DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'bangda masala' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003116, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081003116, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FISH DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003112, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003009, 'Bangda Fry', 'bangda fry', 'FISH DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'bangda fry' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003117, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081003117, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FISH DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003113, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003009, 'Surmai Masala', 'surmai masala', 'FISH DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'surmai masala' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003118, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081003118, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FISH DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003114, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003009, 'Surmai Fry', 'surmai fry', 'FISH DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'surmai fry' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003119, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081003119, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "FISH DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003115, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003009, 'Prawns Masala', 'prawns masala', 'FISH DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns masala' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003120, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003120, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FISH DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003116, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003009, 'Prawns Fry', 'prawns fry', 'FISH DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns fry' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003121, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003121, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "FISH DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003117, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003009, 'Bombil Fry', 'bombil fry', 'FISH DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'bombil fry' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003122, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003122, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "EGG DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003118, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003010, 'Egg Masala', 'egg masala', 'EGG DISHES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg masala' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003123, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003123, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "EGG DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003119, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003010, 'Egg Masala Fry', 'egg masala fry', 'EGG DISHES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg masala fry' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003124, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003124, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "EGG DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003120, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003010, 'Egg Ghotala', 'egg ghotala', 'EGG DISHES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg ghotala' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003125, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003125, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "EGG DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003121, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003010, 'Egg Bhurji', 'egg bhurji', 'EGG DISHES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg bhurji' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003126, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003126, new_variant.variant_id, 110.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "EGG DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003122, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003010, 'Egg Omlet', 'egg omlet', 'EGG DISHES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg omlet' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003127, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003127, new_variant.variant_id, 85.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "EGG DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003123, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003010, 'Egg Cheese Omlet', 'egg cheese omlet', 'EGG DISHES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg cheese omlet' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003128, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003128, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "EGG DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003124, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003010, 'Egg Half Fry', 'egg half fry', 'EGG DISHES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg half fry' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003129, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003129, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "EGG DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003125, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003010, 'Boiled Egg', 'boiled egg', 'EGG DISHES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'boiled egg' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003130, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003130, new_variant.variant_id, 45.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "EGG DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003126, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003010, 'Boiled Egg Bhurji', 'boiled egg bhurji', 'EGG DISHES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'boiled egg bhurji' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003131, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003131, new_variant.variant_id, 130.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ROTI / NAAN / PARATHA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003127, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003011, 'Roti', 'roti', 'ROTI / NAAN / PARATHA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003132, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003132, new_variant.variant_id, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ROTI / NAAN / PARATHA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003128, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003011, 'Butter Roti', 'butter roti', 'ROTI / NAAN / PARATHA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter roti'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003133, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003133, new_variant.variant_id, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ROTI / NAAN / PARATHA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003129, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003011, 'Naan', 'naan', 'ROTI / NAAN / PARATHA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003134, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003134, new_variant.variant_id, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ROTI / NAAN / PARATHA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003130, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003011, 'Butter Naan', 'butter naan', 'ROTI / NAAN / PARATHA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003135, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003135, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ROTI / NAAN / PARATHA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003131, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003011, 'Paratha', 'paratha', 'ROTI / NAAN / PARATHA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003136, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003136, new_variant.variant_id, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ROTI / NAAN / PARATHA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003132, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003011, 'Butter Paratha', 'butter paratha', 'ROTI / NAAN / PARATHA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003137, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003137, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ROTI / NAAN / PARATHA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003133, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003011, 'Veg. Paratha', 'veg. paratha', 'ROTI / NAAN / PARATHA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. paratha'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003138, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003138, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ROTI / NAAN / PARATHA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003134, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003011, 'Garlic Naan', 'garlic naan', 'ROTI / NAAN / PARATHA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'garlic naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003139, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003139, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ROTI / NAAN / PARATHA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003135, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003011, 'Butter Garlic Naan', 'butter garlic naan', 'ROTI / NAAN / PARATHA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter garlic naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003140, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003140, new_variant.variant_id, 120.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ROTI / NAAN / PARATHA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003136, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003011, 'Cheese Naan', 'cheese naan', 'ROTI / NAAN / PARATHA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003141, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003141, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "ROTI / NAAN / PARATHA" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003137, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003011, 'Cheese Butter Garlic Naan', 'cheese butter garlic naan', 'ROTI / NAAN / PARATHA', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese butter garlic naan'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003142, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003142, new_variant.variant_id, 150.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE & PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003138, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003012, 'Dal Khichdi Tadka', 'dal khichdi tadka', 'RICE & PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal khichdi tadka'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003143, 'Half', TRUE), (400081003144, 'Full', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003143, 'Half', 140.00, FALSE), (400081003144, 'Full', 230.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "RICE & PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003139, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003012, 'Dal Khichdi', 'dal khichdi', 'RICE & PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'dal khichdi'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003145, 'Half', TRUE), (400081003146, 'Full', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003145, 'Half', 120.00, FALSE), (400081003146, 'Full', 200.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "RICE & PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003140, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003012, 'Veg. Khichdi', 'veg. khichdi', 'RICE & PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. khichdi'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003147, 'Half', TRUE), (400081003148, 'Full', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003147, 'Half', 120.00, FALSE), (400081003148, 'Full', 200.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "RICE & PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003141, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003012, 'Curd Rice', 'curd rice', 'RICE & PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'curd rice'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003149, 'Half', TRUE), (400081003150, 'Full', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003149, 'Half', 120.00, FALSE), (400081003150, 'Full', 200.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "RICE & PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003142, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003012, 'Biryani Rice', 'biryani rice', 'RICE & PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'biryani rice'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003151, 'Half', TRUE), (400081003152, 'Full', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003151, 'Half', 80.00, FALSE), (400081003152, 'Full', 100.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "RICE & PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003143, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003012, 'Steam Rice', 'steam rice', 'RICE & PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'steam rice'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003153, 'Half', TRUE), (400081003154, 'Full', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003153, 'Half', 60.00, FALSE), (400081003154, 'Full', 80.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "RICE & PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003144, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003012, 'Veg. Pulav', 'veg. pulav', 'RICE & PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003155, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003155, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RICE & PULAV" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003145, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003012, 'Paneer Pulav', 'paneer pulav', 'RICE & PULAV', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer pulav'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003156, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003156, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "BIRYANI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003146, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003013, 'Paneer Biryani', 'paneer biryani', 'BIRYANI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003157, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003157, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "BIRYANI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003147, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003013, 'Paneer Tikka Biryani', 'paneer tikka biryani', 'BIRYANI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer tikka biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003158, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003158, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "BIRYANI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003148, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003013, 'Mushroom Biryani', 'mushroom biryani', 'BIRYANI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom biryani'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003159, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003159, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "BIRYANI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003149, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003013, 'Chicken Hyderabad Biryani', 'chicken hyderabad biryani', 'BIRYANI', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken hyderabad biryani' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003160, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003160, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "BIRYANI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003150, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003013, 'Chicken Tikka Biryani', 'chicken tikka biryani', 'BIRYANI', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken tikka biryani' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003161, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003161, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "BIRYANI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003151, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003013, 'Mutton Biryani', 'mutton biryani', 'BIRYANI', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton biryani' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003162, 'Half', TRUE), (400081003163, 'Full', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003162, 'Half', 180.00, FALSE), (400081003163, 'Full', 330.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "BIRYANI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003152, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003013, 'Prawns Biryani', 'prawns biryani', 'BIRYANI', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns biryani' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003164, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003164, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "BIRYANI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003153, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003013, 'Egg Biryani', 'egg biryani', 'BIRYANI', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg biryani' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003165, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003165, new_variant.variant_id, 200.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RAITA & SALAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003154, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003014, 'Boondi Raita', 'boondi raita', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'boondi raita'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003166, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003166, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RAITA & SALAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003155, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003014, 'Veg. Raita', 'veg. raita', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. raita'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003167, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003167, new_variant.variant_id, 90.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RAITA & SALAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003156, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003014, 'Curd', 'curd', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'curd'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003168, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003168, new_variant.variant_id, 70.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RAITA & SALAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003157, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003014, 'Green Salad', 'green salad', 'RAITA & SALAD', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'green salad'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003169, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003169, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "RAITA & SALAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081003158, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003014, 'Kakdi', 'kakdi', 'RAITA & SALAD', 'veg', 'split-raita-&-salad-kakdi-/-gajar', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'kakdi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003170, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003170, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "RAITA & SALAD" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, split_group_key, verification_status_code)
  SELECT 400081003159, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003014, 'Gajar', 'gajar', 'RAITA & SALAD', 'veg', 'split-raita-&-salad-kakdi-/-gajar', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'gajar'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003171, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003171, new_variant.variant_id, 50.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SPRING ROLL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003160, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003015, 'Veg. Spring Roll', 'veg. spring roll', 'SPRING ROLL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. spring roll'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003172, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003172, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPRING ROLL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003161, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003015, 'Mix Spring Roll', 'mix spring roll', 'SPRING ROLL', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix spring roll'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003173, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003173, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPRING ROLL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003162, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003015, 'Chicken Spring Roll', 'chicken spring roll', 'SPRING ROLL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken spring roll' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003174, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003174, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SPRING ROLL" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003163, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003015, 'Prawns Spring Roll', 'prawns spring roll', 'SPRING ROLL', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns spring roll' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003175, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003175, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003164, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Mix Fried Rice', 'mix fried rice', 'CHINESE RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003176, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003176, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003165, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Veg. Triple Rice', 'veg. triple rice', 'CHINESE RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. triple rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003177, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003177, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003166, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Veg. Manchurian Rice', 'veg. manchurian rice', 'CHINESE RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. manchurian rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003178, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003178, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003167, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Mushroom Fried Rice', 'mushroom fried rice', 'CHINESE RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003179, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003179, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003168, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Mushroom Schezwan Fried Rice', 'mushroom schezwan fried rice', 'CHINESE RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mushroom schezwan fried rice'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003180, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003180, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003169, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Chicken Triple Rice', 'chicken triple rice', 'CHINESE RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken triple rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003181, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003181, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003170, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Chicken Manchurian Rice', 'chicken manchurian rice', 'CHINESE RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken manchurian rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003182, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003182, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003171, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Prawns Fried Rice', 'prawns fried rice', 'CHINESE RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns fried rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003183, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003183, new_variant.variant_id, 290.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003172, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Prawns Triple Rice', 'prawns triple rice', 'CHINESE RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns triple rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003184, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003184, new_variant.variant_id, 410.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003173, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Prawns Schezwan Rice', 'prawns schezwan rice', 'CHINESE RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns schezwan rice' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003185, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003185, new_variant.variant_id, 320.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003174, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Egg Schezwan Fried Rice', 'egg schezwan fried rice', 'CHINESE RICE', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg schezwan fried rice' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003186, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003186, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003175, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Egg Triple Rice', 'egg triple rice', 'CHINESE RICE', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg triple rice' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003187, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003187, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003176, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003017, 'Mix Noodles', 'mix noodles', 'CHINESE NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'mix noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003188, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003188, new_variant.variant_id, 300.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003177, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003017, 'Veg. Schezwan Noodles', 'veg. schezwan noodles', 'CHINESE NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. schezwan noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003189, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003189, new_variant.variant_id, 240.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003178, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003017, 'Veg. Triple Noodles', 'veg. triple noodles', 'CHINESE NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. triple noodles'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003190, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003190, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003179, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003017, 'Chicken Triple Noodles', 'chicken triple noodles', 'CHINESE NOODLES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken triple noodles' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003191, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003191, new_variant.variant_id, 350.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003180, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003017, 'Chicken Schezwan Noodles', 'chicken schezwan noodles', 'CHINESE NOODLES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken schezwan noodles' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003192, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003192, new_variant.variant_id, 270.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003181, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003017, 'Egg Noodles with Rice', 'egg noodles with rice', 'CHINESE NOODLES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg noodles with rice' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003193, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003193, new_variant.variant_id, 310.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "CHINESE NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003182, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003017, 'Egg Schezwan Noodles', 'egg schezwan noodles', 'CHINESE NOODLES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg schezwan noodles' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003194, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003194, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003183, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003018, 'Bread Slice-3 Pcs', 'bread slice-3 pcs', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bread slice-3 pcs'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003195, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003195, new_variant.variant_id, 15.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003184, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003018, 'Bread Butter', 'bread butter', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'bread butter'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003196, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003196, new_variant.variant_id, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003185, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003018, 'Veg. Sandwich', 'veg. sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003197, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003197, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  SELECT 400081003186, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003018, 'Cheese Sandwich', 'cheese sandwich', 'SANDWICHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'cheese sandwich'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003198, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003198, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003187, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003018, 'Omlet Sandwich', 'omlet sandwich', 'SANDWICHES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'omlet sandwich' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003199, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003199, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003188, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003018, 'Cheese Omlet Sandwich', 'cheese omlet sandwich', 'SANDWICHES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'cheese omlet sandwich' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003200, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003200, new_variant.variant_id, 140.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
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
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003189, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003018, 'Chicken Sandwich', 'chicken sandwich', 'SANDWICHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken sandwich' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003201, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003201, new_variant.variant_id, 160.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "BEVERAGES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003190, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003019, 'Sweet Lassi', 'sweet lassi', 'BEVERAGES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'sweet lassi'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003202, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003202, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "BEVERAGES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003191, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003019, 'Butter Milk', 'butter milk', 'BEVERAGES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'butter milk'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003203, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003203, new_variant.variant_id, 40.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUTH INDIAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003192, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003020, 'Chicken Sukha', 'chicken sukha', 'SOUTH INDIAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken sukha' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003204, 'Half', TRUE), (400081003205, 'Full', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003204, 'Half', 140.00, FALSE), (400081003205, 'Full', 230.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "SOUTH INDIAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003193, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003020, 'Mutton Sukha', 'mutton sukha', 'SOUTH INDIAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton sukha' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003206, 'Half', TRUE), (400081003207, 'Full', FALSE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003206, 'Half', 170.00, FALSE), (400081003207, 'Full', 310.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
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

-- Source: docx/json, "SOUTH INDIAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003194, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003020, 'Prawns Sukha', 'prawns sukha', 'SOUTH INDIAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'prawns sukha' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003208, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003208, new_variant.variant_id, 280.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUTH INDIAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003195, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003020, 'Pompret Masala', 'pompret masala', 'SOUTH INDIAN DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'pompret masala' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003209, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081003209, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUTH INDIAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003196, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003020, 'Surmai Masala', 'surmai masala', 'SOUTH INDIAN DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'surmai masala' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003210, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081003210, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUTH INDIAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003197, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003020, 'Bangda Masala', 'bangda masala', 'SOUTH INDIAN DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'bangda masala' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003211, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT 400081003211, new_variant.variant_id, NULL, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'needs_review', TRUE FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'needs_review' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_price, ctx;

-- Source: docx/json, "SOUTH INDIAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003198, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003020, 'South Indian Fish Gravy Plate', 'south indian fish gravy plate', 'SOUTH INDIAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'south indian fish gravy plate' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003212, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003212, new_variant.variant_id, 100.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUTH INDIAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003199, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003020, 'Fish Gravy Extra', 'fish gravy extra', 'SOUTH INDIAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'fish gravy extra' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003213, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003213, new_variant.variant_id, 30.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUTH INDIAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003200, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003020, 'Kori Rotti', 'kori rotti', 'SOUTH INDIAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'kori rotti' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003214, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003214, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUTH INDIAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003201, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003020, 'Chicken (Kori) Neer Dosa', 'chicken (kori) neer dosa', 'SOUTH INDIAN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken (kori) neer dosa' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003215, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003215, new_variant.variant_id, 260.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "SOUTH INDIAN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003202, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003020, 'Neer Dosa - 4pcs', 'neer dosa - 4pcs', 'SOUTH INDIAN DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'neer dosa - 4pcs'
  RETURNING menu_item_id
),
new_variant AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT 400081003216, menu_item_id, 'Regular', 'fixed', TRUE FROM new_item
  RETURNING variant_id
),
new_price AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code)
  SELECT 400081003216, new_variant.variant_id, 80.00, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified' FROM new_variant, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.95, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_price.price_id, ctx.source_id, ctx.extraction_batch_id, 0.95 FROM new_price, ctx;

-- Source: docx/json, "PANEER DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003203, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003005, 'Paneer Handi', 'paneer handi', 'PANEER DISHES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'paneer handi'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003217, 'Half', FALSE), (400081003218, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003217, 'Half', 260.00, FALSE), (400081003218, 'Full', 500.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003204, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003021, 'Veg. Handi', 'veg. handi', 'MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. handi'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003219, 'Half', FALSE), (400081003220, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003219, 'Half', 260.00, FALSE), (400081003220, 'Full', 450.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "MAIN COURSE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003205, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003021, 'Veg. Kadai', 'veg. kadai', 'MAIN COURSE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. kadai'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003221, 'Half', FALSE), (400081003222, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003221, 'Half', 260.00, FALSE), (400081003222, 'Full', 450.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003206, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Handi', 'chicken handi', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken handi' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003223, 'Half', FALSE), (400081003224, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003223, 'Half', 280.00, FALSE), (400081003224, 'Full', 500.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003207, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Butter Chicken', 'butter chicken', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'butter chicken' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003225, 'Half', FALSE), (400081003226, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003225, 'Half', 290.00, FALSE), (400081003226, 'Full', 520.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003208, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Handi Boneless', 'chicken handi boneless', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken handi boneless' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003227, 'Half', FALSE), (400081003228, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003227, 'Half', 300.00, FALSE), (400081003228, 'Full', 580.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "CHICKEN DISHES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003209, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Mutton Handi', 'mutton handi', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton handi' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003229, 'Half', FALSE), (400081003230, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003229, 'Half', 420.00, FALSE), (400081003230, 'Full', 800.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "BIRYANI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003210, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003013, 'Veg. Biryani', 'veg. biryani', 'BIRYANI', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. biryani'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003231, 'Half', FALSE), (400081003232, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003231, 'Half', 120.00, FALSE), (400081003232, 'Full', 200.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "BIRYANI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003211, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003013, 'Chicken Boneless Biryani', 'chicken boneless biryani', 'BIRYANI', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken boneless biryani' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003233, 'Half', FALSE), (400081003234, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003233, 'Half', 160.00, FALSE), (400081003234, 'Full', 270.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "BIRYANI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003212, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003013, 'Chicken Biryani', 'chicken biryani', 'BIRYANI', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken biryani' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003235, 'Half', FALSE), (400081003236, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003235, 'Half', 150.00, FALSE), (400081003236, 'Full', 240.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "BIRYANI" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003213, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003013, 'Mutton Boneless Biryani', 'mutton boneless biryani', 'BIRYANI', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'mutton boneless biryani' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003237, 'Half', FALSE), (400081003238, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003237, 'Half', 195.00, FALSE), (400081003238, 'Full', 370.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003214, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Veg. Fried Rice', 'veg. fried rice', 'CHINESE RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. fried rice'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003239, 'Half', FALSE), (400081003240, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003239, 'Half', 130.00, FALSE), (400081003240, 'Full', 210.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003215, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Veg. Schezwan Fried Rice', 'veg. schezwan fried rice', 'CHINESE RICE', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. schezwan fried rice'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003241, 'Half', FALSE), (400081003242, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003241, 'Half', 150.00, FALSE), (400081003242, 'Full', 230.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003216, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Chicken Schezwan Rice', 'chicken schezwan rice', 'CHINESE RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken schezwan rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003243, 'Half', FALSE), (400081003244, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003243, 'Half', 165.00, FALSE), (400081003244, 'Full', 260.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003217, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Chicken Fried Rice', 'chicken fried rice', 'CHINESE RICE', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken fried rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003245, 'Half', FALSE), (400081003246, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003245, 'Half', 145.00, FALSE), (400081003246, 'Full', 230.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003218, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Egg Schezwan Rice', 'egg schezwan rice', 'CHINESE RICE', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg schezwan rice' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003247, 'Half', FALSE), (400081003248, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003247, 'Half', 150.00, FALSE), (400081003248, 'Full', 220.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "CHINESE RICE" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003219, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Egg Fried Rice', 'egg fried rice', 'CHINESE RICE', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg fried rice' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003249, 'Half', FALSE), (400081003250, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003249, 'Half', 110.00, FALSE), (400081003250, 'Full', 190.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "CHINESE NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003220, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003017, 'Veg. Noodles', 'veg. noodles', 'CHINESE NOODLES', 'veg', 'unverified'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'veg. noodles'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003251, 'Half', FALSE), (400081003252, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003251, 'Half', 140.00, FALSE), (400081003252, 'Full', 220.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "CHINESE NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003221, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003017, 'Chicken Noodles', 'chicken noodles', 'CHINESE NOODLES', 'non_veg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'chicken noodles' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003253, 'Half', FALSE), (400081003254, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003253, 'Half', 150.00, FALSE), (400081003254, 'Full', 250.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "CHINESE NOODLES" section
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003222, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003017, 'Egg Noodles', 'egg noodles', 'CHINESE NOODLES', 'egg', pt.protein_type_id, 'unverified'
  FROM canonical_dish item_cd, protein_type pt, ctx
  WHERE item_cd.normalized_name = 'egg noodles' AND pt.code = 'EGG'
  RETURNING menu_item_id
),
new_variants AS (
  INSERT INTO menu_item_variant (variant_id, menu_item_id, variant_name, pricing_basis_code, is_default)
  SELECT x.variant_id, new_item.menu_item_id, x.variant_name, 'fixed', x.is_default
  FROM new_item CROSS JOIN (VALUES (400081003255, 'Half', FALSE), (400081003256, 'Full', TRUE)) AS x(variant_id, variant_name, is_default)
  RETURNING variant_id, variant_name
),
new_prices AS (
  INSERT INTO menu_item_price (price_id, variant_id, price_amount, effective_from, source_id, verification_status_code, is_market_price)
  SELECT x.price_id, nv.variant_id, x.price_amount, (clock_timestamp() AT TIME ZONE 'UTC'), ctx.source_id, 'unverified', x.is_market_price
  FROM new_variants nv JOIN (VALUES (400081003255, 'Half', 135.00, FALSE), (400081003256, 'Full', 230.00, FALSE)) AS x(price_id, variant_name, price_amount, is_market_price)
    ON x.variant_name = nv.variant_name, ctx
  RETURNING price_id
),
item_src AS (
  INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
  SELECT new_item.menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.90, 'unverified' FROM new_item, ctx
  RETURNING menu_item_id
)

INSERT INTO menu_item_price_source (price_id, source_id, extraction_batch_id, confidence)
SELECT new_prices.price_id, ctx.source_id, ctx.extraction_batch_id, 0.90 FROM new_prices, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section (NO PRICE GIVEN ANYWHERE IN THE SOURCE)
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003223, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Special Bhaji', 'special bhaji', 'MAIN COURSE (CONTINUED)', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'special bhaji'
  RETURNING menu_item_id
)
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.5, 'needs_review' FROM new_item, ctx;

-- Source: docx/json, "MAIN COURSE (CONTINUED)" section (NO PRICE GIVEN ANYWHERE IN THE SOURCE)
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, verification_status_code)
  SELECT 400081003224, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003006, 'Extra Butter', 'extra butter', 'MAIN COURSE (CONTINUED)', 'veg', 'needs_review'
  FROM canonical_dish item_cd, ctx
  WHERE item_cd.normalized_name = 'extra butter'
  RETURNING menu_item_id
)
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.5, 'needs_review' FROM new_item, ctx;

-- Source: docx/json, "CHICKEN DISHES" section (NO PRICE GIVEN ANYWHERE IN THE SOURCE)
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003225, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Patiyala', 'chicken patiyala', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, ctx, protein_type pt
  WHERE item_cd.normalized_name = 'chicken patiyala' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
)
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.5, 'needs_review' FROM new_item, ctx;

-- Source: docx/json, "CHICKEN DISHES" section (NO PRICE GIVEN ANYWHERE IN THE SOURCE)
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003226, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Lajawab', 'chicken lajawab', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, ctx, protein_type pt
  WHERE item_cd.normalized_name = 'chicken lajawab' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
)
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.5, 'needs_review' FROM new_item, ctx;

-- Source: docx/json, "CHICKEN DISHES" section (NO PRICE GIVEN ANYWHERE IN THE SOURCE)
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003227, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Rara', 'chicken rara', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, ctx, protein_type pt
  WHERE item_cd.normalized_name = 'chicken rara' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
)
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.5, 'needs_review' FROM new_item, ctx;

-- Source: docx/json, "CHICKEN DISHES" section (NO PRICE GIVEN ANYWHERE IN THE SOURCE)
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003228, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Chicken Kumari Roll', 'chicken kumari roll', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, ctx, protein_type pt
  WHERE item_cd.normalized_name = 'chicken kumari roll' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
)
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.5, 'needs_review' FROM new_item, ctx;

-- Source: docx/json, "CHICKEN DISHES" section (NO PRICE GIVEN ANYWHERE IN THE SOURCE)
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003229, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003007, 'Prawns Peanut Sesmi Toast', 'prawns peanut sesmi toast', 'CHICKEN DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, ctx, protein_type pt
  WHERE item_cd.normalized_name = 'prawns peanut sesmi toast' AND pt.code = 'SEAFOOD'
  RETURNING menu_item_id
)
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.5, 'needs_review' FROM new_item, ctx;

-- Source: docx/json, "MUTTON DISHES" section (NO PRICE GIVEN ANYWHERE IN THE SOURCE)
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003230, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003008, 'Mutton Rara', 'mutton rara', 'MUTTON DISHES', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, ctx, protein_type pt
  WHERE item_cd.normalized_name = 'mutton rara' AND pt.code = 'MUTTON'
  RETURNING menu_item_id
)
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.5, 'needs_review' FROM new_item, ctx;

-- Source: docx/json, "BIRYANI" section (NO PRICE GIVEN ANYWHERE IN THE SOURCE)
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003231, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003013, 'Lal Pari Chicken Biryani', 'lal pari chicken biryani', 'BIRYANI', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, ctx, protein_type pt
  WHERE item_cd.normalized_name = 'lal pari chicken biryani' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
)
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.5, 'needs_review' FROM new_item, ctx;

-- Source: docx/json, "CHINESE RICE" section (NO PRICE GIVEN ANYWHERE IN THE SOURCE)
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003232, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Chicken Packing Rice', 'chicken packing rice', 'CHINESE RICE', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, ctx, protein_type pt
  WHERE item_cd.normalized_name = 'chicken packing rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
)
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.5, 'needs_review' FROM new_item, ctx;

-- Source: docx/json, "CHINESE RICE" section (NO PRICE GIVEN ANYWHERE IN THE SOURCE)
WITH ctx AS (
  SELECT * FROM khaustan_onboarding_ctx
),
new_item AS (
  INSERT INTO menu_item (menu_item_id, restaurant_id, canonical_dish_id, menu_category_id, name, normalized_name, raw_category_text, food_classification_code, protein_type_id, verification_status_code)
  SELECT 400081003233, ctx.restaurant_id, item_cd.canonical_dish_id, 400081003016, 'Chicken Sherpa Rice', 'chicken sherpa rice', 'CHINESE RICE', 'non_veg', pt.protein_type_id, 'needs_review'
  FROM canonical_dish item_cd, ctx, protein_type pt
  WHERE item_cd.normalized_name = 'chicken sherpa rice' AND pt.code = 'CHICKEN'
  RETURNING menu_item_id
)
INSERT INTO menu_item_source (menu_item_id, source_id, extraction_batch_id, confidence, verification_status_code)
SELECT menu_item_id, ctx.source_id, ctx.extraction_batch_id, 0.5, 'needs_review' FROM new_item, ctx;

-- -----------------------------------------------------------------------
-- One menu board per restaurant, linked to every category and every item.
-- board_type_code = 'a_la_carte': none of this batch's sources describe a
-- buffet/thali/combo-style board, just a standard printed menu.
-- -----------------------------------------------------------------------
INSERT INTO menu_board (menu_board_id, restaurant_id, name, board_type_code)
SELECT 400081003001, ctx.restaurant_id, 'Main Menu', 'a_la_carte' FROM khaustan_onboarding_ctx ctx;

INSERT INTO menu_board_category (restaurant_id, menu_board_id, menu_category_id, display_sequence)
SELECT ctx.restaurant_id, 400081003001, x.menu_category_id, x.display_sequence
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400081003001, 1), (400081003002, 2), (400081003003, 3), (400081003004, 4), (400081003005, 5), (400081003006, 6), (400081003007, 7), (400081003008, 8), (400081003009, 9), (400081003010, 10), (400081003011, 11), (400081003012, 12), (400081003013, 13), (400081003014, 14), (400081003015, 15), (400081003016, 16), (400081003017, 17), (400081003018, 18), (400081003019, 19), (400081003020, 20), (400081003021, 21)) AS x(menu_category_id, display_sequence);

INSERT INTO menu_board_item (menu_board_item_id, restaurant_id, menu_board_id, menu_item_id, menu_category_id, display_sequence, is_featured)
SELECT x.menu_board_item_id, ctx.restaurant_id, 400081003001, x.menu_item_id, x.menu_category_id, x.display_sequence, x.is_featured
FROM khaustan_onboarding_ctx ctx CROSS JOIN (VALUES (400081003001, 400081003001, 400081003001, 1, FALSE), (400081003002, 400081003002, 400081003001, 2, FALSE), (400081003003, 400081003003, 400081003001, 3, FALSE), (400081003004, 400081003004, 400081003001, 4, FALSE), (400081003005, 400081003005, 400081003001, 5, FALSE), (400081003006, 400081003006, 400081003001, 6, FALSE), (400081003007, 400081003007, 400081003001, 7, FALSE), (400081003008, 400081003008, 400081003002, 8, FALSE), (400081003009, 400081003009, 400081003002, 9, FALSE), (400081003010, 400081003010, 400081003002, 10, FALSE), (400081003011, 400081003011, 400081003002, 11, FALSE), (400081003012, 400081003012, 400081003002, 12, FALSE), (400081003013, 400081003013, 400081003002, 13, FALSE), (400081003014, 400081003014, 400081003002, 14, FALSE), (400081003015, 400081003015, 400081003002, 15, FALSE), (400081003016, 400081003016, 400081003002, 16, FALSE), (400081003017, 400081003017, 400081003002, 17, FALSE), (400081003018, 400081003018, 400081003002, 18, FALSE), (400081003019, 400081003019, 400081003002, 19, FALSE), (400081003020, 400081003020, 400081003002, 20, FALSE), (400081003021, 400081003021, 400081003002, 21, FALSE), (400081003022, 400081003022, 400081003002, 22, FALSE), (400081003023, 400081003023, 400081003002, 23, FALSE), (400081003024, 400081003024, 400081003002, 24, FALSE), (400081003025, 400081003025, 400081003002, 25, FALSE), (400081003026, 400081003026, 400081003002, 26, FALSE), (400081003027, 400081003027, 400081003002, 27, FALSE), (400081003028, 400081003028, 400081003002, 28, FALSE), (400081003029, 400081003029, 400081003002, 29, FALSE), (400081003030, 400081003030, 400081003003, 30, FALSE), (400081003031, 400081003031, 400081003003, 31, FALSE), (400081003032, 400081003032, 400081003003, 32, FALSE), (400081003033, 400081003033, 400081003003, 33, FALSE), (400081003034, 400081003034, 400081003003, 34, FALSE), (400081003035, 400081003035, 400081003003, 35, FALSE), (400081003036, 400081003036, 400081003003, 36, FALSE), (400081003037, 400081003037, 400081003003, 37, FALSE), (400081003038, 400081003038, 400081003003, 38, FALSE), (400081003039, 400081003039, 400081003004, 39, FALSE), (400081003040, 400081003040, 400081003004, 40, FALSE), (400081003041, 400081003041, 400081003004, 41, FALSE), (400081003042, 400081003042, 400081003004, 42, FALSE), (400081003043, 400081003043, 400081003004, 43, FALSE), (400081003044, 400081003044, 400081003004, 44, FALSE), (400081003045, 400081003045, 400081003004, 45, FALSE), (400081003046, 400081003046, 400081003004, 46, FALSE), (400081003047, 400081003047, 400081003004, 47, FALSE), (400081003048, 400081003048, 400081003004, 48, FALSE), (400081003049, 400081003049, 400081003004, 49, FALSE), (400081003050, 400081003050, 400081003004, 50, FALSE), (400081003051, 400081003051, 400081003004, 51, FALSE), (400081003052, 400081003052, 400081003004, 52, FALSE), (400081003053, 400081003053, 400081003004, 53, FALSE), (400081003054, 400081003054, 400081003004, 54, FALSE), (400081003055, 400081003055, 400081003004, 55, FALSE), (400081003056, 400081003056, 400081003004, 56, FALSE), (400081003057, 400081003057, 400081003004, 57, FALSE), (400081003058, 400081003058, 400081003004, 58, FALSE), (400081003059, 400081003059, 400081003004, 59, FALSE), (400081003060, 400081003060, 400081003004, 60, FALSE), (400081003061, 400081003061, 400081003004, 61, FALSE), (400081003062, 400081003062, 400081003004, 62, FALSE), (400081003063, 400081003063, 400081003004, 63, FALSE), (400081003064, 400081003064, 400081003004, 64, FALSE), (400081003065, 400081003065, 400081003004, 65, FALSE), (400081003066, 400081003066, 400081003004, 66, FALSE), (400081003067, 400081003067, 400081003005, 67, FALSE), (400081003068, 400081003068, 400081003005, 68, FALSE), (400081003069, 400081003069, 400081003005, 69, FALSE), (400081003070, 400081003070, 400081003005, 70, FALSE), (400081003071, 400081003071, 400081003005, 71, FALSE), (400081003072, 400081003072, 400081003005, 72, FALSE), (400081003073, 400081003073, 400081003005, 73, FALSE), (400081003074, 400081003074, 400081003006, 74, FALSE), (400081003075, 400081003075, 400081003006, 75, FALSE), (400081003076, 400081003076, 400081003006, 76, FALSE), (400081003077, 400081003077, 400081003006, 77, FALSE), (400081003078, 400081003078, 400081003006, 78, FALSE), (400081003079, 400081003079, 400081003006, 79, FALSE), (400081003080, 400081003080, 400081003006, 80, FALSE), (400081003081, 400081003081, 400081003006, 81, FALSE), (400081003082, 400081003082, 400081003006, 82, FALSE), (400081003083, 400081003083, 400081003006, 83, FALSE), (400081003084, 400081003084, 400081003006, 84, FALSE), (400081003085, 400081003085, 400081003006, 85, FALSE), (400081003086, 400081003086, 400081003006, 86, FALSE), (400081003087, 400081003087, 400081003006, 87, FALSE), (400081003088, 400081003088, 400081003006, 88, FALSE), (400081003089, 400081003089, 400081003006, 89, FALSE), (400081003090, 400081003090, 400081003006, 90, FALSE), (400081003091, 400081003091, 400081003006, 91, FALSE), (400081003092, 400081003092, 400081003007, 92, FALSE), (400081003093, 400081003093, 400081003007, 93, FALSE), (400081003094, 400081003094, 400081003007, 94, FALSE), (400081003095, 400081003095, 400081003007, 95, FALSE), (400081003096, 400081003096, 400081003007, 96, FALSE), (400081003097, 400081003097, 400081003007, 97, FALSE), (400081003098, 400081003098, 400081003007, 98, FALSE), (400081003099, 400081003099, 400081003007, 99, FALSE), (400081003100, 400081003100, 400081003007, 100, FALSE), (400081003101, 400081003101, 400081003007, 101, FALSE), (400081003102, 400081003102, 400081003007, 102, FALSE), (400081003103, 400081003103, 400081003007, 103, FALSE), (400081003104, 400081003104, 400081003008, 104, FALSE), (400081003105, 400081003105, 400081003008, 105, FALSE), (400081003106, 400081003106, 400081003008, 106, FALSE), (400081003107, 400081003107, 400081003008, 107, FALSE), (400081003108, 400081003108, 400081003009, 108, FALSE), (400081003109, 400081003109, 400081003009, 109, FALSE), (400081003110, 400081003110, 400081003009, 110, FALSE), (400081003111, 400081003111, 400081003009, 111, FALSE), (400081003112, 400081003112, 400081003009, 112, FALSE), (400081003113, 400081003113, 400081003009, 113, FALSE), (400081003114, 400081003114, 400081003009, 114, FALSE), (400081003115, 400081003115, 400081003009, 115, FALSE), (400081003116, 400081003116, 400081003009, 116, FALSE), (400081003117, 400081003117, 400081003009, 117, FALSE), (400081003118, 400081003118, 400081003010, 118, FALSE), (400081003119, 400081003119, 400081003010, 119, FALSE), (400081003120, 400081003120, 400081003010, 120, FALSE), (400081003121, 400081003121, 400081003010, 121, FALSE), (400081003122, 400081003122, 400081003010, 122, FALSE), (400081003123, 400081003123, 400081003010, 123, FALSE), (400081003124, 400081003124, 400081003010, 124, FALSE), (400081003125, 400081003125, 400081003010, 125, FALSE), (400081003126, 400081003126, 400081003010, 126, FALSE), (400081003127, 400081003127, 400081003011, 127, FALSE), (400081003128, 400081003128, 400081003011, 128, FALSE), (400081003129, 400081003129, 400081003011, 129, FALSE), (400081003130, 400081003130, 400081003011, 130, FALSE), (400081003131, 400081003131, 400081003011, 131, FALSE), (400081003132, 400081003132, 400081003011, 132, FALSE), (400081003133, 400081003133, 400081003011, 133, FALSE), (400081003134, 400081003134, 400081003011, 134, FALSE), (400081003135, 400081003135, 400081003011, 135, FALSE), (400081003136, 400081003136, 400081003011, 136, FALSE), (400081003137, 400081003137, 400081003011, 137, FALSE), (400081003138, 400081003138, 400081003012, 138, FALSE), (400081003139, 400081003139, 400081003012, 139, FALSE), (400081003140, 400081003140, 400081003012, 140, FALSE), (400081003141, 400081003141, 400081003012, 141, FALSE), (400081003142, 400081003142, 400081003012, 142, FALSE), (400081003143, 400081003143, 400081003012, 143, FALSE), (400081003144, 400081003144, 400081003012, 144, FALSE), (400081003145, 400081003145, 400081003012, 145, FALSE), (400081003146, 400081003146, 400081003013, 146, FALSE), (400081003147, 400081003147, 400081003013, 147, FALSE), (400081003148, 400081003148, 400081003013, 148, FALSE), (400081003149, 400081003149, 400081003013, 149, FALSE), (400081003150, 400081003150, 400081003013, 150, FALSE), (400081003151, 400081003151, 400081003013, 151, FALSE), (400081003152, 400081003152, 400081003013, 152, FALSE), (400081003153, 400081003153, 400081003013, 153, FALSE), (400081003154, 400081003154, 400081003014, 154, FALSE), (400081003155, 400081003155, 400081003014, 155, FALSE), (400081003156, 400081003156, 400081003014, 156, FALSE), (400081003157, 400081003157, 400081003014, 157, FALSE), (400081003158, 400081003158, 400081003014, 158, FALSE), (400081003159, 400081003159, 400081003014, 159, FALSE), (400081003160, 400081003160, 400081003015, 160, FALSE), (400081003161, 400081003161, 400081003015, 161, FALSE), (400081003162, 400081003162, 400081003015, 162, FALSE), (400081003163, 400081003163, 400081003015, 163, FALSE), (400081003164, 400081003164, 400081003016, 164, FALSE), (400081003165, 400081003165, 400081003016, 165, FALSE), (400081003166, 400081003166, 400081003016, 166, FALSE), (400081003167, 400081003167, 400081003016, 167, FALSE), (400081003168, 400081003168, 400081003016, 168, FALSE), (400081003169, 400081003169, 400081003016, 169, FALSE), (400081003170, 400081003170, 400081003016, 170, FALSE), (400081003171, 400081003171, 400081003016, 171, FALSE), (400081003172, 400081003172, 400081003016, 172, FALSE), (400081003173, 400081003173, 400081003016, 173, FALSE), (400081003174, 400081003174, 400081003016, 174, FALSE), (400081003175, 400081003175, 400081003016, 175, FALSE), (400081003176, 400081003176, 400081003017, 176, FALSE), (400081003177, 400081003177, 400081003017, 177, FALSE), (400081003178, 400081003178, 400081003017, 178, FALSE), (400081003179, 400081003179, 400081003017, 179, FALSE), (400081003180, 400081003180, 400081003017, 180, FALSE), (400081003181, 400081003181, 400081003017, 181, FALSE), (400081003182, 400081003182, 400081003017, 182, FALSE), (400081003183, 400081003183, 400081003018, 183, FALSE), (400081003184, 400081003184, 400081003018, 184, FALSE), (400081003185, 400081003185, 400081003018, 185, FALSE), (400081003186, 400081003186, 400081003018, 186, FALSE), (400081003187, 400081003187, 400081003018, 187, FALSE), (400081003188, 400081003188, 400081003018, 188, FALSE), (400081003189, 400081003189, 400081003018, 189, FALSE), (400081003190, 400081003190, 400081003019, 190, FALSE), (400081003191, 400081003191, 400081003019, 191, FALSE), (400081003192, 400081003192, 400081003020, 192, FALSE), (400081003193, 400081003193, 400081003020, 193, FALSE), (400081003194, 400081003194, 400081003020, 194, FALSE), (400081003195, 400081003195, 400081003020, 195, FALSE), (400081003196, 400081003196, 400081003020, 196, FALSE), (400081003197, 400081003197, 400081003020, 197, FALSE), (400081003198, 400081003198, 400081003020, 198, FALSE), (400081003199, 400081003199, 400081003020, 199, FALSE), (400081003200, 400081003200, 400081003020, 200, FALSE), (400081003201, 400081003201, 400081003020, 201, FALSE), (400081003202, 400081003202, 400081003020, 202, FALSE), (400081003203, 400081003203, 400081003005, 203, FALSE), (400081003204, 400081003204, 400081003021, 204, FALSE), (400081003205, 400081003205, 400081003021, 205, FALSE), (400081003206, 400081003206, 400081003007, 206, FALSE), (400081003207, 400081003207, 400081003007, 207, FALSE), (400081003208, 400081003208, 400081003007, 208, FALSE), (400081003209, 400081003209, 400081003007, 209, FALSE), (400081003210, 400081003210, 400081003013, 210, FALSE), (400081003211, 400081003211, 400081003013, 211, FALSE), (400081003212, 400081003212, 400081003013, 212, FALSE), (400081003213, 400081003213, 400081003013, 213, FALSE), (400081003214, 400081003214, 400081003016, 214, FALSE), (400081003215, 400081003215, 400081003016, 215, FALSE), (400081003216, 400081003216, 400081003016, 216, FALSE), (400081003217, 400081003217, 400081003016, 217, FALSE), (400081003218, 400081003218, 400081003016, 218, FALSE), (400081003219, 400081003219, 400081003016, 219, FALSE), (400081003220, 400081003220, 400081003017, 220, FALSE), (400081003221, 400081003221, 400081003017, 221, FALSE), (400081003222, 400081003222, 400081003017, 222, FALSE), (400081003223, 400081003223, 400081003006, 223, FALSE), (400081003224, 400081003224, 400081003006, 224, FALSE), (400081003225, 400081003225, 400081003007, 225, FALSE), (400081003226, 400081003226, 400081003007, 226, FALSE), (400081003227, 400081003227, 400081003007, 227, FALSE), (400081003228, 400081003228, 400081003007, 228, FALSE), (400081003229, 400081003229, 400081003007, 229, FALSE), (400081003230, 400081003230, 400081003008, 230, FALSE), (400081003231, 400081003231, 400081003013, 231, FALSE), (400081003232, 400081003232, 400081003016, 232, FALSE), (400081003233, 400081003233, 400081003016, 233, FALSE)) AS x(menu_board_item_id, menu_item_id, menu_category_id, display_sequence, is_featured);

COMMIT;

-- =============================================================================
-- REVIEW NOTES: every menu_item / menu_item_price row with
-- verification_status_code = 'needs_review', one line each.
-- =============================================================================
-- NEEDS_REVIEW [0.90] "Fish Pompret Chilly" (CONTINUATION): Priced 'APS' (as per season/size) on the source menu -- is_market_price=TRUE, price left NULL.
-- NEEDS_REVIEW [0.90] "Pamplet Masala" (FISH DISHES): Priced 'APS' (as per season/size) on the source menu -- is_market_price=TRUE, price left NULL.
-- NEEDS_REVIEW [0.90] "Pamplet Fry" (FISH DISHES): Priced 'APS' (as per season/size) on the source menu -- is_market_price=TRUE, price left NULL.
-- NEEDS_REVIEW [0.90] "Pamplet Tawa" (FISH DISHES): Priced 'APS' (as per season/size) on the source menu -- is_market_price=TRUE, price left NULL.
-- NEEDS_REVIEW [0.90] "Bangda Masala" (FISH DISHES): Priced 'APS' (as per season/size) on the source menu -- is_market_price=TRUE, price left NULL.
-- NEEDS_REVIEW [0.90] "Bangda Fry" (FISH DISHES): Priced 'APS' (as per season/size) on the source menu -- is_market_price=TRUE, price left NULL.
-- NEEDS_REVIEW [0.90] "Surmai Masala" (FISH DISHES): Priced 'APS' (as per season/size) on the source menu -- is_market_price=TRUE, price left NULL.
-- NEEDS_REVIEW [0.90] "Surmai Fry" (FISH DISHES): Priced 'APS' (as per season/size) on the source menu -- is_market_price=TRUE, price left NULL.
-- NEEDS_REVIEW [0.90] "Pompret Masala" (SOUTH INDIAN DISHES): Priced 'APS' (as per season/size) on the source menu -- is_market_price=TRUE, price left NULL.
-- NEEDS_REVIEW [0.90] "Surmai Masala" (SOUTH INDIAN DISHES): Priced 'APS' (as per season/size) on the source menu -- is_market_price=TRUE, price left NULL.
-- NEEDS_REVIEW [0.90] "Bangda Masala" (SOUTH INDIAN DISHES): Priced 'APS' (as per season/size) on the source menu -- is_market_price=TRUE, price left NULL.

-- =============================================================================
-- UNMAPPED: restaurant-level facts with no clean schema home, or deliberately
-- left for a human decision.
-- =============================================================================
-- UNMAPPED: restaurant.has_bar = TRUE (source JSON's own restaurant.type field says "Bar & Restaurant"), but bar_license_type is left at the schema default 'none' -- no license type (beer_wine_only/full_bar) is stated anywhere, and no actual bar/liquor menu items appear in this transcription at all (BEVERAGES only lists Sweet Lassi and Butter Milk). Recommend following up with the restaurant for the real license type and, if they want it onboarded, the actual bar menu.
-- UNMAPPED: source JSON's own restaurant.delivery_partners is an explicitly empty list, and no "free home delivery" text appears anywhere -- so no restaurant_delivery / delivery_provider rows were created for this restaurant at all (unlike Campus and Kampa in this batch). If this restaurant does use Zomato/Swiggy/Dunzo (all three now exist as real delivery_provider rows, ids 1-3), say so and I'll add the restaurant_delivery_provider links.
-- UNMAPPED: "Kori" (Kori Rotti) is Tulu/Mangalorean for chicken, confirmed by the adjacent "Chicken (Kori) Neer Dosa" line explicitly glossing the word -- classified non_veg/CHICKEN rather than veg.
-- UNMAPPED: 11 dishes are confirmed present on the menu with literally no price given anywhere in the source (not even an APS/market-price marker) -- see the menu_item-only rows above with no variant/price.
-- UNMAPPED: 'Chilly Gravy' (Chinese Dishes) and 'Chicken Gravy' (Chicken Dishes) are priced far below their section's other mains -- likely gravy-only add-ons rather than full dishes, recorded as printed.
